use crate::{
    magic_dictionary_index::MagicDictionaryIndex,
    models::*,
    query_builder::{build_query_plan, ngrams4},
    snippet_builder::build_snippet,
};
use anyhow::{Context, Result};
use rusqlite::{Connection, OpenFlags};
use std::{path::Path, sync::Arc};
use tantivy::{
    collector::{Count, TopDocs},
    query::{BooleanQuery, BoostQuery, FuzzyTermQuery, Occur, PhraseQuery, Query, TermQuery},
    schema::{Field, IndexRecordOption, Value},
    Index, ReloadPolicy, Term,
};

pub struct ZayitSearchEngine {
    paths: DataPaths,
    index: Index,
    reader: tantivy::IndexReader,
    dictionary: Arc<MagicDictionaryIndex>,
}

impl ZayitSearchEngine {
    pub fn open(paths: DataPaths) -> Result<Self> {
        let report = validate_paths(&paths)?;
        anyhow::ensure!(
            report.valid,
            "invalid Zayit data folder: {:?}",
            report.missing
        );
        let index =
            Index::open_in_dir(&paths.index_dir).context("open prebuilt Zayit search index")?;
        let reader = index
            .reader_builder()
            .reload_policy(ReloadPolicy::Manual)
            .try_into()?;
        let dictionary = Arc::new(MagicDictionaryIndex::open(&paths.lexical_db)?);
        Ok(Self {
            paths,
            index,
            reader,
            dictionary,
        })
    }

    pub fn search(&self, request: &SearchRequest) -> Result<SearchPage> {
        let plan = build_query_plan(&request.query, request.near, &self.dictionary)?;
        anyhow::ensure!(
            !plan.tokens.is_empty() || !plan.exact_phrases.is_empty(),
            "empty search query"
        );
        let schema = self.index.schema();
        let fields = Fields::new(&schema)?;
        let query = build_runtime_query(&plan, &request.filters, &fields);
        let searcher = self.reader.searcher();
        let total_hits = searcher.search(query.as_ref(), &Count)? as u64;
        let take = request.offset.saturating_add(request.limit.max(1));
        let top = searcher.search(query.as_ref(), &TopDocs::with_limit(take))?;
        let conn =
            Connection::open_with_flags(&self.paths.seforim_db, OpenFlags::SQLITE_OPEN_READ_ONLY)?;
        conn.pragma_update(None, "query_only", "ON")?;

        let mut highlight_terms = plan.tokens.clone();
        for alternatives in plan.alternatives.values() {
            highlight_terms.extend(
                alternatives
                    .iter()
                    .filter(|s| s.chars().count() > 2)
                    .cloned(),
            );
        }
        highlight_terms.extend(
            plan.exact_phrases
                .iter()
                .flat_map(|phrase| phrase.split_whitespace().map(str::to_owned)),
        );
        highlight_terms.sort_by_key(|s| std::cmp::Reverse(s.chars().count()));
        highlight_terms.dedup();

        let mut hits = Vec::new();
        for (score, addr) in top.into_iter().skip(request.offset) {
            let doc = searcher.doc::<tantivy::schema::TantivyDocument>(addr)?;
            let book_id = i64v(&doc, fields.book_id);
            let line_id = i64v(&doc, fields.line_id);
            let line_index = i64v(&doc, fields.line_index) as i32;
            let title = textv(&doc, fields.book_title);
            let is_base = i64v(&doc, fields.is_base_book) == 1;
            let order = i64v(&doc, fields.order_index);
            let raw = load_line_text(&conn, line_id).unwrap_or_default();
            let snippet = build_snippet(&raw, &highlight_terms, &highlight_terms, 220);
            let factor = if is_base {
                1.0 + ((120 - order).max(0) as f32 / 60.0)
            } else {
                1.0
            };
            hits.push(LineHit {
                book_id,
                book_title: title,
                line_id,
                line_index,
                snippet_html: snippet,
                score: score * factor,
                is_base_book: is_base,
            });
        }
        hits.sort_by(|a, b| b.score.total_cmp(&a.score));
        Ok(SearchPage {
            is_last_page: request.offset + hits.len() >= total_hits as usize,
            hits,
            total_hits,
        })
    }
}

fn build_runtime_query(
    plan: &crate::query_builder::QueryPlan,
    filters: &SearchFilters,
    f: &Fields,
) -> Box<dyn Query> {
    let mut root: Vec<(Occur, Box<dyn Query>)> = vec![(
        Occur::Must,
        Box::new(TermQuery::new(
            Term::from_field_text(f.kind, "line"),
            IndexRecordOption::Basic,
        )),
    )];

    for phrase in &plan.exact_phrases {
        let terms = phrase
            .split_whitespace()
            .map(|x| Term::from_field_text(f.text, x))
            .collect::<Vec<_>>();
        if terms.len() == 1 {
            root.push((
                Occur::Must,
                Box::new(TermQuery::new(
                    terms[0].clone(),
                    IndexRecordOption::WithFreqsAndPositions,
                )),
            ));
        } else if !terms.is_empty() {
            root.push((Occur::Must, Box::new(PhraseQuery::new(terms))));
        }
    }

    for token in &plan.tokens {
        let alternatives = plan
            .alternatives
            .get(token)
            .cloned()
            .unwrap_or_else(|| vec![token.clone()]);
        let clauses = alternatives
            .iter()
            .map(|term| {
                (
                    Occur::Should,
                    Box::new(TermQuery::new(
                        Term::from_field_text(f.text, term),
                        IndexRecordOption::WithFreqsAndPositions,
                    )) as Box<dyn Query>,
                )
            })
            .collect();
        root.push((Occur::Must, Box::new(BooleanQuery::new(clauses))));

        root.push((
            Occur::Should,
            Box::new(BoostQuery::new(
                Box::new(TermQuery::new(
                    Term::from_field_text(f.text, token),
                    IndexRecordOption::WithFreqsAndPositions,
                )),
                2.0,
            )),
        ));
        for alternative in alternatives.into_iter().filter(|value| value != token) {
            root.push((
                Occur::Should,
                Box::new(BoostQuery::new(
                    Box::new(TermQuery::new(
                        Term::from_field_text(f.text, &alternative),
                        IndexRecordOption::WithFreqsAndPositions,
                    )),
                    1.5,
                )),
            ));
        }
    }

    if plan.tokens.len() >= 2 {
        let phrase_terms = plan
            .tokens
            .iter()
            .map(|x| Term::from_field_text(f.text, x))
            .collect::<Vec<_>>();
        root.push((
            if plan.near == 0 {
                Occur::Must
            } else {
                Occur::Should
            },
            Box::new(BoostQuery::new(
                Box::new(PhraseQuery::new(phrase_terms)),
                50.0,
            )),
        ));
    }

    if plan.near > 0 {
        let grams = plan
            .tokens
            .iter()
            .flat_map(|token| ngrams4(token))
            .collect::<Vec<_>>();
        if !grams.is_empty() {
            let clauses = grams
                .into_iter()
                .map(|gram| {
                    (
                        Occur::Must,
                        Box::new(TermQuery::new(
                            Term::from_field_text(f.text_ng4, &gram),
                            IndexRecordOption::WithFreqs,
                        )) as Box<dyn Query>,
                    )
                })
                .collect();
            root.push((Occur::Should, Box::new(BooleanQuery::new(clauses))));
        }
        let fuzzy_tokens = plan
            .tokens
            .iter()
            .filter(|token| token.chars().count() >= 4)
            .collect::<Vec<_>>();
        if !fuzzy_tokens.is_empty() {
            let clauses = fuzzy_tokens
                .into_iter()
                .map(|token| {
                    (
                        Occur::Must,
                        Box::new(FuzzyTermQuery::new(
                            Term::from_field_text(f.text, token),
                            1,
                            true,
                        )) as Box<dyn Query>,
                    )
                })
                .collect();
            root.push((Occur::Should, Box::new(BooleanQuery::new(clauses))));
        }
    }

    add_filters(&mut root, filters, f);
    Box::new(BooleanQuery::new(root))
}

fn add_filters(root: &mut Vec<(Occur, Box<dyn Query>)>, filters: &SearchFilters, f: &Fields) {
    if let Some(id) = filters.book_id {
        root.push((Occur::Must, numeric_term_query(f.book_id, id)));
    }
    if let Some(id) = filters.category_id {
        let category = numeric_term_query(f.category_id, id);
        let ancestor = numeric_term_query(f.ancestor_category_ids, id);
        root.push((
            Occur::Must,
            Box::new(BooleanQuery::new(vec![
                (Occur::Should, category),
                (Occur::Should, ancestor),
            ])),
        ));
    }
    if !filters.book_ids.is_empty() {
        root.push((Occur::Must, numeric_set_query(f.book_id, &filters.book_ids)));
    }
    if !filters.line_ids.is_empty() {
        root.push((Occur::Must, numeric_set_query(f.line_id, &filters.line_ids)));
    }
    if filters.base_book_only {
        root.push((Occur::Must, numeric_term_query(f.is_base_book, 1)));
    }
}

fn numeric_term_query(field: Field, value: i64) -> Box<dyn Query> {
    Box::new(TermQuery::new(
        Term::from_field_i64(field, value),
        IndexRecordOption::Basic,
    ))
}

fn numeric_set_query(field: Field, values: &[i64]) -> Box<dyn Query> {
    Box::new(BooleanQuery::new(
        values
            .iter()
            .map(|value| (Occur::Should, numeric_term_query(field, *value)))
            .collect(),
    ))
}

pub fn validate_paths(paths: &DataPaths) -> Result<ValidationReport> {
    let mut missing = Vec::new();
    let mut errors = Vec::new();
    for (name, p, is_dir) in [
        ("seforim.db", &paths.seforim_db, false),
        ("lexical.db", &paths.lexical_db, false),
        ("zayit-search-index", &paths.index_dir, true),
    ] {
        let path = Path::new(p);
        if (is_dir && !path.is_dir()) || (!is_dir && !path.is_file()) {
            missing.push(name.into());
        }
    }
    if missing.is_empty() {
        let metadata = Path::new(&paths.index_dir).join("zayit-index-metadata.json");
        if !metadata.is_file() {
            errors.push("zayit-index-metadata.json is missing; rebuild the prebuilt index".into());
        }
    }
    Ok(ValidationReport {
        valid: missing.is_empty() && errors.is_empty(),
        missing,
        errors,
    })
}

struct Fields {
    kind: Field,
    book_id: Field,
    category_id: Field,
    ancestor_category_ids: Field,
    book_title: Field,
    line_id: Field,
    line_index: Field,
    text: Field,
    text_ng4: Field,
    is_base_book: Field,
    order_index: Field,
}
impl Fields {
    fn new(s: &tantivy::schema::Schema) -> Result<Self> {
        Ok(Self {
            kind: s.get_field("type")?,
            book_id: s.get_field("book_id")?,
            category_id: s.get_field("category_id")?,
            ancestor_category_ids: s.get_field("ancestor_category_ids")?,
            book_title: s.get_field("book_title")?,
            line_id: s.get_field("line_id")?,
            line_index: s.get_field("line_index")?,
            text: s.get_field("text")?,
            text_ng4: s.get_field("text_ng4")?,
            is_base_book: s.get_field("is_base_book")?,
            order_index: s.get_field("order_index")?,
        })
    }
}
fn i64v(d: &tantivy::schema::TantivyDocument, f: Field) -> i64 {
    d.get_first(f).and_then(|v| v.as_i64()).unwrap_or_default()
}
fn textv(d: &tantivy::schema::TantivyDocument, f: Field) -> String {
    d.get_first(f)
        .and_then(|v| v.as_str())
        .unwrap_or_default()
        .into()
}
fn load_line_text(c: &Connection, id: i64) -> Result<String> {
    for sql in [
        "SELECT content FROM line WHERE id=?1",
        "SELECT content FROM lines WHERE id=?1",
        "SELECT text FROM line WHERE id=?1",
    ] {
        if let Ok(v) = c.query_row(sql, [id], |r| r.get(0)) {
            return Ok(v);
        }
    }
    anyhow::bail!("line text not found")
}
