use anyhow::{bail, Context, Result};
use maktabah_zayit_search::{
    hebrew_text_utils::normalize_hebrew, index_schema::*, query_builder::ngrams4,
};
use regex::Regex;
use rusqlite::{Connection, OpenFlags};
use serde::Serialize;
use std::{
    collections::HashMap,
    env, fs,
    path::Path,
    time::{SystemTime, UNIX_EPOCH},
};
use tantivy::{doc, Index};

#[derive(Debug, Serialize)]
struct IndexMetadata {
    format: &'static str,
    schema_version: u32,
    created_unix_seconds: u64,
    source_db_path: String,
    source_db_size: u64,
    source_db_modified_unix_seconds: u64,
    books_indexed: u64,
    lines_indexed: u64,
    title_documents: u64,
    builder_version: &'static str,
}

#[derive(Debug)]
struct BookRow {
    id: i64,
    category_id: i64,
    title: String,
    order_index: i64,
    is_base_book: bool,
}

fn main() -> Result<()> {
    let args = env::args().skip(1).collect::<Vec<_>>();
    if args.len() != 2 {
        eprintln!("Usage: zayit-index-builder <seforim.db> <output-index-directory>");
        std::process::exit(2);
    }
    build_index(Path::new(&args[0]), Path::new(&args[1]))
}

fn build_index(db_path: &Path, output_dir: &Path) -> Result<()> {
    if !db_path.is_file() {
        bail!("seforim.db not found: {}", db_path.display());
    }
    if output_dir.exists() {
        fs::remove_dir_all(output_dir)
            .with_context(|| format!("remove old index {}", output_dir.display()))?;
    }
    fs::create_dir_all(output_dir)?;

    let conn = Connection::open_with_flags(db_path, OpenFlags::SQLITE_OPEN_READ_ONLY)
        .with_context(|| format!("open {}", db_path.display()))?;
    conn.pragma_update(None, "query_only", "ON")?;
    validate_source_schema(&conn)?;

    let category_parents = load_category_parents(&conn)?;
    let schema = expected_schema();
    let index = Index::create_in_dir(output_dir, schema.clone())?;
    let mut writer = index.writer(256_000_000)?;

    let f_type = schema.get_field(FIELD_TYPE)?;
    let f_book_id = schema.get_field(FIELD_BOOK_ID)?;
    let f_category_id = schema.get_field(FIELD_CATEGORY_ID)?;
    let f_ancestor_ids = schema.get_field(FIELD_ANCESTOR_CATEGORY_IDS)?;
    let f_book_title = schema.get_field(FIELD_BOOK_TITLE)?;
    let f_line_id = schema.get_field(FIELD_LINE_ID)?;
    let f_line_index = schema.get_field(FIELD_LINE_INDEX)?;
    let f_text = schema.get_field(FIELD_TEXT)?;
    let f_text_ng4 = schema.get_field(FIELD_TEXT_NG4)?;
    let f_title = schema.get_field(FIELD_TITLE)?;
    let f_order = schema.get_field(FIELD_ORDER_INDEX)?;
    let f_is_base = schema.get_field(FIELD_IS_BASE_BOOK)?;

    let books = load_books(&conn)?;
    let mut lines_indexed = 0u64;
    let mut title_documents = 0u64;
    let html = Regex::new(r"(?is)<[^>]+>")?;
    let whitespace = Regex::new(r"\s+")?;

    for (book_no, book) in books.iter().enumerate() {
        let effective_order = if book.is_base_book {
            (book.order_index - 5).max(1)
        } else {
            book.order_index
        };
        let title_terms = load_title_terms(&conn, book.id, &book.title)?;
        for term in title_terms {
            writer.add_document(doc!(
                f_type => TYPE_BOOK_TITLE,
                f_book_id => book.id,
                f_category_id => book.category_id,
                f_book_title => book.title.clone(),
                f_title => normalize_hebrew(&term),
                f_order => effective_order,
                f_is_base => if book.is_base_book { 1i64 } else { 0i64 },
            ))?;
            title_documents += 1;
        }

        let ancestors = category_ancestors(book.category_id, &category_parents);
        let mut stmt = conn.prepare(
            "SELECT id, lineIndex, content FROM line WHERE bookId=?1 ORDER BY lineIndex",
        )?;
        let rows = stmt.query_map([book.id], |r| {
            Ok((
                r.get::<_, i64>(0)?,
                r.get::<_, i64>(1)?,
                r.get::<_, String>(2)?,
            ))
        })?;
        for row in rows {
            let (line_id, line_index, raw_html) = row?;
            let plain = clean_html(&raw_html, &html, &whitespace);
            let normalized = normalize_hebrew(&plain);
            if normalized.is_empty() {
                continue;
            }
            let grams = normalized
                .split_whitespace()
                .flat_map(ngrams4)
                .collect::<Vec<_>>()
                .join(" ");
            let mut document = doc!(
                f_type => TYPE_LINE,
                f_book_id => book.id,
                f_category_id => book.category_id,
                f_book_title => book.title.clone(),
                f_line_id => line_id,
                f_line_index => line_index,
                f_text => normalized,
                f_text_ng4 => grams,
                f_order => effective_order,
                f_is_base => if book.is_base_book { 1i64 } else { 0i64 },
            );
            for ancestor in &ancestors {
                document.add_i64(f_ancestor_ids, *ancestor);
            }
            writer.add_document(document)?;
            lines_indexed += 1;
            if lines_indexed % 100_000 == 0 {
                eprintln!("Indexed {lines_indexed} lines...");
                writer.commit()?;
            }
        }
        eprintln!(
            "[{}/{}] {} (book id {})",
            book_no + 1,
            books.len(),
            book.title,
            book.id
        );
    }

    writer.commit()?;
    writer.wait_merging_threads()?;

    let source_meta = fs::metadata(db_path)?;
    let modified = source_meta
        .modified()
        .unwrap_or(SystemTime::UNIX_EPOCH)
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs();
    let created = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs();
    let metadata = IndexMetadata {
        format: "maktabah-zayit-search-tantivy",
        schema_version: 1,
        created_unix_seconds: created,
        source_db_path: db_path.display().to_string(),
        source_db_size: source_meta.len(),
        source_db_modified_unix_seconds: modified,
        books_indexed: books.len() as u64,
        lines_indexed,
        title_documents,
        builder_version: env!("CARGO_PKG_VERSION"),
    };
    fs::write(
        output_dir.join("zayit-index-metadata.json"),
        serde_json::to_vec_pretty(&metadata)?,
    )?;
    eprintln!("Completed: {} lines, {} books", lines_indexed, books.len());
    Ok(())
}

fn validate_source_schema(conn: &Connection) -> Result<()> {
    for table in ["book", "category", "line"] {
        let found: i64 = conn.query_row(
            "SELECT count(*) FROM sqlite_master WHERE type='table' AND name=?1",
            [table],
            |r| r.get(0),
        )?;
        if found != 1 {
            bail!("seforim.db is missing required table: {table}");
        }
    }
    Ok(())
}

fn load_category_parents(conn: &Connection) -> Result<HashMap<i64, Option<i64>>> {
    let mut stmt = conn.prepare("SELECT id, parentId FROM category")?;
    let rows = stmt.query_map([], |r| {
        Ok((r.get::<_, i64>(0)?, r.get::<_, Option<i64>>(1)?))
    })?;
    let mut map = HashMap::new();
    for row in rows {
        let (id, parent) = row?;
        map.insert(id, parent);
    }
    Ok(map)
}

fn category_ancestors(category_id: i64, parents: &HashMap<i64, Option<i64>>) -> Vec<i64> {
    let mut result = Vec::new();
    let mut current = Some(category_id);
    let mut guard = 0usize;
    while let Some(id) = current {
        if result.contains(&id) || guard > 128 {
            break;
        }
        result.push(id);
        current = parents.get(&id).copied().flatten();
        guard += 1;
    }
    result
}

fn load_books(conn: &Connection) -> Result<Vec<BookRow>> {
    let mut stmt = conn.prepare(
        "SELECT id, categoryId, title, COALESCE(orderIndex,999), COALESCE(isBaseBook,0) FROM book ORDER BY COALESCE(orderIndex,999), id"
    )?;
    let rows = stmt.query_map([], |r| {
        Ok(BookRow {
            id: r.get(0)?,
            category_id: r.get(1)?,
            title: r.get(2)?,
            order_index: r.get(3)?,
            is_base_book: r.get::<_, i64>(4)? == 1,
        })
    })?;
    rows.collect::<rusqlite::Result<Vec<_>>>()
        .map_err(Into::into)
}

fn table_exists(conn: &Connection, name: &str) -> bool {
    conn.query_row(
        "SELECT count(*) FROM sqlite_master WHERE type='table' AND name=?1",
        [name],
        |r| r.get::<_, i64>(0),
    )
    .map(|n| n == 1)
    .unwrap_or(false)
}

fn load_title_terms(conn: &Connection, book_id: i64, title: &str) -> Result<Vec<String>> {
    let mut terms = vec![title.to_owned(), sanitize_acronym_term(title)];
    if table_exists(conn, "acronym") {
        for sql in [
            "SELECT acronym FROM acronym WHERE bookId=?1",
            "SELECT value FROM acronym WHERE bookId=?1",
            "SELECT text FROM acronym WHERE bookId=?1",
        ] {
            if let Ok(mut stmt) = conn.prepare(sql) {
                if let Ok(rows) = stmt.query_map([book_id], |r| r.get::<_, String>(0)) {
                    terms.extend(rows.filter_map(Result::ok));
                    break;
                }
            }
        }
    }
    terms.retain(|s| !s.trim().is_empty());
    terms.sort();
    terms.dedup();
    Ok(terms)
}

fn sanitize_acronym_term(value: &str) -> String {
    value.replace(['״', '׳', '"', '\''], "")
}

fn clean_html(input: &str, html: &Regex, whitespace: &Regex) -> String {
    let expanded = input
        .replace("<br>", " ")
        .replace("<br/>", " ")
        .replace("<br />", " ")
        .replace("</p>", " ")
        .replace("</h1>", " ")
        .replace("</h2>", " ");
    let no_tags = html.replace_all(&expanded, " ");
    let decoded = no_tags
        .replace("&nbsp;", " ")
        .replace("&quot;", "\"")
        .replace("&#39;", "'")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&amp;", "&");
    whitespace.replace_all(decoded.trim(), " ").into_owned()
}
