use anyhow::{bail, Context, Result};
use rusqlite::{types::Value, Connection};
use std::collections::HashMap;

pub const MAX_DECOMPRESSED_LINE_BYTES: usize = 16 * 1024 * 1024;

pub fn table_exists(conn: &Connection, name: &str) -> bool {
    conn.query_row(
        "SELECT count(*) FROM sqlite_master WHERE type='table' AND name=?1",
        [name],
        |r| r.get::<_, i64>(0),
    )
    .map(|n| n == 1)
    .unwrap_or(false)
}

pub fn table_columns(conn: &Connection, table: &str) -> Result<Vec<String>> {
    let mut statement = conn.prepare(&format!("PRAGMA table_info({table})"))?;
    let rows = statement.query_map([], |row| row.get::<_, String>(1))?;
    rows.collect::<rusqlite::Result<Vec<_>>>()
        .map_err(Into::into)
}

pub struct LineContentSource {
    pub sql: String,
}

pub fn line_content_source(conn: &Connection) -> Result<LineContentSource> {
    let line_columns = table_columns(conn, "line")?;
    if line_columns.iter().any(|column| column == "content") {
        return Ok(LineContentSource {
            sql: "SELECT id, lineIndex, content FROM line WHERE bookId=?1 ORDER BY lineIndex"
                .to_owned(),
        });
    }
    if !table_exists(conn, "line_content") {
        bail!("seforim.db has neither line.content nor line_content");
    }
    Ok(LineContentSource {
        sql: "SELECT l.id, l.lineIndex, lc.content FROM line l JOIN line_content lc ON lc.id=l.id WHERE l.bookId=?1 ORDER BY l.lineIndex".to_owned(),
    })
}

pub fn load_zstd_dictionaries(conn: &Connection) -> Result<HashMap<u32, Vec<u8>>> {
    if !table_exists(conn, "zstd_dict") {
        return Ok(HashMap::new());
    }
    let mut statement = conn.prepare("SELECT dict FROM zstd_dict")?;
    let rows = statement.query_map([], |row| row.get::<_, Vec<u8>>(0))?;
    let mut dictionaries = HashMap::new();
    for row in rows {
        let dictionary = row?;
        let id = zstd::zstd_safe::get_dict_id_from_dict(&dictionary)
            .context("zstd_dict row has no dictionary ID")?
            .get();
        dictionaries.insert(id, dictionary);
    }
    Ok(dictionaries)
}

pub fn decode_line_content(value: Value, dictionaries: &HashMap<u32, Vec<u8>>) -> Result<String> {
    match value {
        Value::Null => Ok(String::new()),
        Value::Text(text) => Ok(text),
        Value::Blob(frame) => {
            let decoded = if let Some(id) = zstd::zstd_safe::get_dict_id_from_frame(&frame) {
                let dictionary = dictionaries
                    .get(&id.get())
                    .with_context(|| format!("missing zstd dictionary {}", id.get()))?;
                let mut decompressor = zstd::bulk::Decompressor::with_dictionary(dictionary)?;
                decompressor.decompress(&frame, MAX_DECOMPRESSED_LINE_BYTES)?
            } else {
                zstd::bulk::decompress(&frame, MAX_DECOMPRESSED_LINE_BYTES)?
            };
            String::from_utf8(decoded).context("decoded line content is not UTF-8")
        }
        other => bail!("unsupported SQLite line content type: {other:?}"),
    }
}

#[derive(Clone, Debug)]
pub struct LineDecoder {
    dictionaries: HashMap<u32, Vec<u8>>,
    single_line_sql: String,
}

impl LineDecoder {
    pub fn new(conn: &Connection) -> Result<Self> {
        let dictionaries = load_zstd_dictionaries(conn)?;
        let line_columns = table_columns(conn, "line").unwrap_or_default();
        let has_content_col = line_columns.iter().any(|c| c == "content");
        let has_he_ref_col = line_columns.iter().any(|c| c == "heRef");
        let has_line_content_table = table_exists(conn, "line_content");

        let he_ref_part = if has_he_ref_col {
            "COALESCE(l.heRef, '')"
        } else {
            "''"
        };

        let single_line_sql = if has_content_col {
            let ref_part = if has_he_ref_col {
                "COALESCE(heRef, '')"
            } else {
                "''"
            };
            format!("SELECT content, {ref_part} FROM line WHERE id=?1")
        } else if has_line_content_table {
            format!("SELECT lc.content, {he_ref_part} FROM line l JOIN line_content lc ON lc.id=l.id WHERE l.id=?1")
        } else {
            "SELECT content, '' FROM line WHERE id=?1".to_owned()
        };

        Ok(Self {
            dictionaries,
            single_line_sql,
        })
    }

    pub fn decode(&self, value: Value) -> Result<String> {
        decode_line_content(value, &self.dictionaries)
    }

    pub fn load_line(&self, conn: &Connection, id: i64) -> Result<(String, String)> {
        if let Ok(mut stmt) = conn.prepare(&self.single_line_sql) {
            if let Ok(res) = stmt.query_row([id], |row| Ok((row.get(0)?, row.get(1)?))) {
                let (raw_val, reference): (Value, String) = res;
                let raw = self.decode(raw_val)?;
                return Ok((raw, reference));
            }
        }
        for sql in [
            "SELECT content, COALESCE(heRef, '') FROM line WHERE id=?1",
            "SELECT lc.content, COALESCE(l.heRef, '') FROM line l JOIN line_content lc ON lc.id=l.id WHERE l.id=?1",
            "SELECT content, '' FROM line WHERE id=?1",
            "SELECT content, '' FROM lines WHERE id=?1",
            "SELECT text, '' FROM line WHERE id=?1",
        ] {
            if let Ok(mut stmt) = conn.prepare(sql) {
                if let Ok(res) = stmt.query_row([id], |row| Ok((row.get(0)?, row.get(1)?))) {
                    let (raw_val, reference): (Value, String) = res;
                    let raw = self.decode(raw_val)?;
                    return Ok((raw, reference));
                }
            }
        }
        anyhow::bail!("line text not found for id {id}")
    }

    pub fn dictionaries(&self) -> &HashMap<u32, Vec<u8>> {
        &self.dictionaries
    }
}
