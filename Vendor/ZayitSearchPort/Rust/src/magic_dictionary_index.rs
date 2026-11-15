use crate::hebrew_text_utils::normalize_hebrew;
use anyhow::{Context, Result};
use parking_lot::Mutex;
use rusqlite::{Connection, OpenFlags};
use serde::{Deserialize, Serialize};
use std::{
    collections::{HashMap, VecDeque},
    path::Path,
};

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct Expansion {
    pub surface: Vec<String>,
    pub variants: Vec<String>,
    pub base: Vec<String>,
}

pub struct MagicDictionaryIndex {
    conn: Mutex<Connection>,
    cache: Mutex<SimpleLru>,
}

impl MagicDictionaryIndex {
    pub fn open(path: impl AsRef<Path>) -> Result<Self> {
        let conn = Connection::open_with_flags(path.as_ref(), OpenFlags::SQLITE_OPEN_READ_ONLY)
            .with_context(|| format!("open lexical database {}", path.as_ref().display()))?;
        conn.pragma_update(None, "query_only", "ON")?;
        validate_schema(&conn)?;
        Ok(Self {
            conn: Mutex::new(conn),
            cache: Mutex::new(SimpleLru::new(1024)),
        })
    }

    pub fn expansion_for(&self, token: &str) -> Result<Option<Expansion>> {
        let normalized = normalize_hebrew(token);
        if normalized.is_empty() {
            return Ok(None);
        }
        if let Some(v) = self.cache.lock().get(&normalized) {
            return Ok(v.first().cloned());
        }
        let values = self.expansions_for_token(token, &normalized)?;
        let best = values
            .iter()
            .find(|e| e.base.iter().any(|b| b == &normalized))
            .cloned()
            .or_else(|| values.iter().max_by_key(|e| e.surface.len()).cloned());
        // Cache the selected meaning, not hash-map-ordered candidates. Returning
        // candidates.first() on a cache hit can change an identical query's
        // meaning (and turn its own scoped/paged follow-up into zero results).
        self.cache
            .lock()
            .put(normalized, best.clone().into_iter().collect());
        Ok(best)
    }

    fn expansions_for_token(&self, raw: &str, normalized: &str) -> Result<Vec<Expansion>> {
        let mut by_base: HashMap<i64, Expansion> = HashMap::new();
        for candidate in lookup_candidates(raw, normalized) {
            let conn = self.conn.lock();
            let mut stmt = conn.prepare(LOOKUP_SQL)?;
            let rows = stmt.query_map([&candidate, &candidate, &candidate], |r| {
                Ok((
                    r.get::<_, i64>(0)?,
                    r.get::<_, String>(1)?,
                    r.get::<_, Option<String>>(2)?,
                    r.get::<_, Option<String>>(3)?,
                ))
            })?;
            for row in rows {
                let (id, base, surface, variant) = row?;
                let e = by_base.entry(id).or_insert_with(|| Expansion {
                    surface: vec![],
                    variants: vec![],
                    base: vec![],
                });
                push_unique(&mut e.base, normalize_hebrew(&base));
                if let Some(v) = surface {
                    push_unique(&mut e.surface, normalize_hebrew(&v));
                }
                if let Some(v) = variant {
                    push_unique(&mut e.variants, normalize_hebrew(&v));
                }
            }
        }
        Ok(by_base.into_values().collect())
    }

    pub fn load_hashem_surfaces(&self) -> Result<Vec<String>> {
        let conn = self.conn.lock();
        let mut stmt = conn.prepare(
            "SELECT s.value FROM surface s JOIN base b ON s.base_id=b.id WHERE b.value='יהוה'",
        )?;
        let surfaces = stmt
            .query_map([], |r| r.get::<_, String>(0))?
            .filter_map(Result::ok)
            .collect();
        Ok(surfaces)
    }
}

fn push_unique(v: &mut Vec<String>, s: String) {
    if !s.is_empty() && !v.contains(&s) {
        v.push(s);
    }
}
fn final_form(s: &str) -> String {
    let mut c: Vec<char> = s.chars().collect();
    if let Some(last) = c.last_mut() {
        *last = match *last {
            'כ' => 'ך',
            'מ' => 'ם',
            'נ' => 'ן',
            'פ' => 'ף',
            'צ' => 'ץ',
            x => x,
        };
    }
    c.into_iter().collect()
}
fn lookup_candidates(raw: &str, norm: &str) -> Vec<String> {
    let mut v = vec![raw.into(), norm.into(), final_form(raw), final_form(norm)];
    v.retain(|s| !s.trim().is_empty());
    v.dedup();
    v
}

fn validate_schema(conn: &Connection) -> Result<()> {
    for table in ["surface", "variant", "base", "surface_variant"] {
        let found: i64 = conn.query_row(
            "SELECT count(*) FROM sqlite_master WHERE type='table' AND name=?1",
            [table],
            |r| r.get(0),
        )?;
        anyhow::ensure!(found == 1, "lexical.db missing required table {table}");
    }
    Ok(())
}

const LOOKUP_SQL: &str = r#"
WITH matches AS (
 SELECT s.base_id FROM surface s WHERE s.value=?1
 UNION SELECT b.id FROM base b WHERE b.value=?2
 UNION SELECT s.base_id FROM variant v
 JOIN surface_variant sv ON sv.variant_id=v.id
 JOIN surface s ON sv.surface_id=s.id WHERE v.value=?3
)
SELECT b.id,b.value,s.value,v.value FROM base b
JOIN matches m ON m.base_id=b.id
LEFT JOIN surface s ON s.base_id=b.id
LEFT JOIN surface_variant sv ON sv.surface_id=s.id
LEFT JOIN variant v ON sv.variant_id=v.id
"#;

struct SimpleLru {
    cap: usize,
    order: VecDeque<String>,
    map: HashMap<String, Vec<Expansion>>,
}
impl SimpleLru {
    fn new(cap: usize) -> Self {
        Self {
            cap,
            order: VecDeque::new(),
            map: HashMap::new(),
        }
    }
    fn get(&mut self, k: &str) -> Option<Vec<Expansion>> {
        self.map.get(k).cloned()
    }
    fn put(&mut self, k: String, v: Vec<Expansion>) {
        if !self.map.contains_key(&k) {
            self.order.push_back(k.clone());
        }
        self.map.insert(k, v);
        while self.map.len() > self.cap {
            if let Some(old) = self.order.pop_front() {
                self.map.remove(&old);
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn repeated_ambiguous_lookup_retains_the_selected_base_meaning() {
        let fixture = tempfile::tempdir().unwrap();
        let path = fixture.path().join("lexical.db");
        let conn = Connection::open(&path).unwrap();
        conn.execute_batch("CREATE TABLE base(id INTEGER PRIMARY KEY,value TEXT); CREATE TABLE surface(id INTEGER PRIMARY KEY,base_id INTEGER,value TEXT); CREATE TABLE variant(id INTEGER PRIMARY KEY,value TEXT); CREATE TABLE surface_variant(surface_id INTEGER,variant_id INTEGER);").unwrap();
        for index in 0..64_i64 {
            let token = format!("מילה{index}");
            let selected = index * 2 + 1;
            let alternative = selected + 1;
            conn.execute(
                "INSERT INTO base VALUES(?1,?2)",
                rusqlite::params![selected, token],
            )
            .unwrap();
            conn.execute(
                "INSERT INTO base VALUES(?1,?2)",
                rusqlite::params![alternative, format!("אחר{index}")],
            )
            .unwrap();
            conn.execute(
                "INSERT INTO surface VALUES(?1,?1,?2)",
                rusqlite::params![selected, token],
            )
            .unwrap();
            conn.execute(
                "INSERT INTO surface VALUES(?1,?1,?2)",
                rusqlite::params![alternative, format!("חלופה{index}")],
            )
            .unwrap();
            conn.execute(
                "INSERT INTO variant VALUES(?1,?2)",
                rusqlite::params![alternative, token],
            )
            .unwrap();
            conn.execute("INSERT INTO surface_variant VALUES(?1,?1)", [alternative])
                .unwrap();
        }
        drop(conn);
        let dictionary = MagicDictionaryIndex::open(path).unwrap();
        for index in 0..64 {
            let token = format!("מילה{index}");
            let first = dictionary.expansion_for(&token).unwrap().unwrap();
            assert!(first.base.contains(&token));
            for _ in 0..3 {
                assert_eq!(
                    dictionary.expansion_for(&token).unwrap().as_ref(),
                    Some(&first),
                    "warm lexical cache changed the selected meaning for {token}"
                );
            }
        }
    }
}
