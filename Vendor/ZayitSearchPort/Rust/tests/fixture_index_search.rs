use maktabah_zayit_search::{
    engine::ZayitSearchEngine,
    models::{DataPaths, SearchFilters, SearchRequest},
};
use rusqlite::{params, Connection};
use std::collections::HashSet;
use std::ffi::{CStr, CString};
use std::{path::Path, process::Command};
use tempfile::tempdir;

#[test]
fn builds_and_searches_a_real_sqlite_fixture() {
    let fixture = tempdir().expect("create fixture directory");
    let seforim_db = fixture.path().join("seforim.db");
    let lexical_db = fixture.path().join("lexical.db");
    let index_dir = fixture
        .path()
        .join("ZayitSearchData")
        .join("zayit-search-index");

    create_seforim_fixture(&seforim_db);
    create_lexical_fixture(&lexical_db);

    let output = Command::new(env!("CARGO_BIN_EXE_zayit-index-builder"))
        .arg(&seforim_db)
        .arg(&index_dir)
        .output()
        .expect("run zayit-index-builder");
    assert!(
        output.status.success(),
        "builder failed\nstdout:\n{}\nstderr:\n{}",
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    assert!(index_dir.join("meta.json").is_file());
    assert!(index_dir.join("zayit-index-metadata.json").is_file());

    let engine = ZayitSearchEngine::open(DataPaths {
        seforim_db: seforim_db.to_string_lossy().into_owned(),
        lexical_db: lexical_db.to_string_lossy().into_owned(),
        index_dir: index_dir.to_string_lossy().into_owned(),
    })
    .expect("open generated index");

    let exact_term = engine
        .search(&request("מיוחד", SearchFilters::default()))
        .expect("search exact term");
    assert_eq!(exact_term.hits.len(), 1);
    assert_eq!(exact_term.hits[0].line_id, 101);
    assert_eq!(exact_term.hits[0].stable_book_key, "demo/sefer-yesod");
    assert!(!exact_term.hits[0].matched_terms.is_empty());

    let quoted_phrase = engine
        .search(&request("\"שלום בית\"", SearchFilters::default()))
        .expect("search quoted phrase");
    assert!(quoted_phrase.hits.iter().any(|hit| hit.line_id == 101));

    let lexical_variant = engine
        .search(&request("שלוה", SearchFilters::default()))
        .expect("search lexical variant");
    assert!(lexical_variant.hits.iter().any(|hit| hit.line_id == 101));

    let boosted = engine
        .search(&request("שלום", SearchFilters::default()))
        .expect("search base-book boost");
    assert_eq!(boosted.hits.len(), 2);
    assert_eq!(boosted.hits[0].book_id, 10);
    assert!(boosted.hits[0].is_base_book);
    assert!(boosted.hits[0].score > boosted.hits[1].score);
    assert!(boosted.hits[0].snippet_html.contains("<b>"));
    assert!(boosted.hits[0].snippet_html.contains("</b>"));

    let filtered = engine
        .search(&request(
            "שלום",
            SearchFilters {
                book_id: Some(20),
                ..SearchFilters::default()
            },
        ))
        .expect("search with book filter");
    assert_eq!(filtered.hits.len(), 1);
    assert_eq!(filtered.hits[0].book_id, 20);

    // Execute the public C ABI used by the Swift wrapper, not a mocked
    // repository. All DB/index paths belong to this disposable fixture.
    let paths = DataPaths {
        seforim_db: seforim_db.to_string_lossy().into_owned(),
        lexical_db: lexical_db.to_string_lossy().into_owned(),
        index_dir: index_dir.to_string_lossy().into_owned(),
    };
    unsafe {
        use maktabah_zayit_search::ffi::*;
        let encoded = CString::new(serde_json::to_string(&paths).unwrap()).unwrap();
        let opened = ffi_json(mzayit_engine_create(encoded.as_ptr()));
        let engine_id = opened["engine_id"]
            .as_u64()
            .expect("FFI opens real generated index");
        let mut ids = HashSet::new();
        for (offset, count, last) in [(0, 50, false), (50, 50, false), (100, 25, true)] {
            let query = SearchRequest {
                query: "מבחןעימוד".into(),
                near: 0,
                limit: 50,
                offset,
                filters: SearchFilters {
                    book_ids: vec![10],
                    ..SearchFilters::default()
                },
            };
            let input = CString::new(serde_json::to_string(&query).unwrap()).unwrap();
            let value = ffi_json(mzayit_engine_search(engine_id, input.as_ptr()));
            let page: maktabah_zayit_search::models::SearchPage =
                serde_json::from_value(value).expect("FFI page shape");
            assert_eq!(page.total_hits, 125);
            assert_eq!(page.hits.len(), count);
            assert_eq!(page.is_last_page, last);
            for hit in page.hits {
                assert!(
                    ids.insert(hit.line_id),
                    "paging returned a duplicate stable hit ID"
                );
                assert_eq!(hit.book_id, 10);
                assert_eq!(hit.line_index as i64, hit.line_id - 1000);
                assert_eq!(hit.stable_book_key, "demo/sefer-yesod");
                assert!(hit.snippet_html.contains("מבחןעימוד"));
                assert!(!hit.matched_terms.is_empty());
            }
        }
        assert_eq!(ids.len(), 125);
        // Three distinct known-match Hebrew queries both unfiltered and with
        // the actual source book filter; these are fixture, not corpus proofs.
        for text in ["מיוחד", "שלום", "מבחןעימוד"] {
            for filters in [
                SearchFilters::default(),
                SearchFilters {
                    book_ids: vec![10],
                    ..SearchFilters::default()
                },
            ] {
                let input =
                    CString::new(serde_json::to_string(&request(text, filters)).unwrap()).unwrap();
                let page: maktabah_zayit_search::models::SearchPage = serde_json::from_value(
                    ffi_json(mzayit_engine_search(engine_id, input.as_ptr())),
                )
                .unwrap();
                assert!(
                    !page.hits.is_empty(),
                    "known fixture query returned empty: {text}"
                );
            }
        }
        mzayit_engine_destroy(engine_id);
        let query = CString::new(
            serde_json::to_string(&request("שלום", SearchFilters::default())).unwrap(),
        )
        .unwrap();
        let stale = ffi_json(mzayit_engine_search(engine_id, query.as_ptr()));
        assert!(
            stale.get("error").is_some(),
            "closed engine must return an error, not a zero-hit page"
        );
        let reopened = ffi_json(mzayit_engine_create(encoded.as_ptr()));
        let reopened_id = reopened["engine_id"].as_u64().expect("FFI reopens index");
        let page: maktabah_zayit_search::models::SearchPage =
            serde_json::from_value(ffi_json(mzayit_engine_search(reopened_id, query.as_ptr())))
                .unwrap();
        assert!(!page.hits.is_empty());
        mzayit_engine_destroy(reopened_id);
    }
}

unsafe fn ffi_json(pointer: *mut std::os::raw::c_char) -> serde_json::Value {
    assert!(!pointer.is_null(), "FFI returned a null JSON string");
    let bytes = CStr::from_ptr(pointer).to_bytes().to_vec();
    maktabah_zayit_search::ffi::mzayit_string_free(pointer);
    serde_json::from_slice(&bytes).expect("FFI returns valid JSON")
}

fn request(query: &str, filters: SearchFilters) -> SearchRequest {
    SearchRequest {
        query: query.to_owned(),
        near: 0,
        limit: 20,
        offset: 0,
        filters,
    }
}

fn create_seforim_fixture(path: &Path) {
    let conn = Connection::open(path).expect("create seforim fixture");
    conn.execute_batch(
        "
        CREATE TABLE category(id INTEGER PRIMARY KEY, parentId INTEGER);
        CREATE TABLE book(
            id INTEGER PRIMARY KEY,
            categoryId INTEGER NOT NULL,
            title TEXT NOT NULL,
            orderIndex INTEGER,
            isBaseBook INTEGER
        );
        CREATE TABLE line(
            id INTEGER PRIMARY KEY,
            bookId INTEGER NOT NULL,
            lineIndex INTEGER NOT NULL,
            content TEXT NOT NULL
        );
        ",
    )
    .expect("create seforim schema");
    conn.execute("INSERT INTO category VALUES (1, NULL)", [])
        .unwrap();
    conn.execute("INSERT INTO category VALUES (2, 1)", [])
        .unwrap();
    conn.execute("INSERT INTO category VALUES (3, 1)", [])
        .unwrap();
    conn.execute(
        "INSERT INTO book(id,categoryId,title,orderIndex,isBaseBook) VALUES (?1, ?2, ?3, ?4, ?5)",
        params![10, 2, "ספר יסוד", 100, 1],
    )
    .unwrap();
    conn.execute("ALTER TABLE book ADD COLUMN filePath TEXT", [])
        .unwrap();
    conn.execute(
        "UPDATE book SET filePath=CASE id WHEN 10 THEN 'demo/sefer-yesod' ELSE 'demo/sefer-acher' END",
        [],
    )
    .unwrap();
    conn.execute(
        "INSERT INTO book(id,categoryId,title,orderIndex,isBaseBook) VALUES (?1, ?2, ?3, ?4, ?5)",
        params![20, 3, "ספר אחר", 100, 0],
    )
    .unwrap();
    conn.execute(
        "UPDATE book SET filePath='demo/sefer-acher' WHERE id=20",
        [],
    )
    .unwrap();
    conn.execute(
        "INSERT INTO line VALUES (?1, ?2, ?3, ?4)",
        params![101, 10, 0, "<p>שָׁלוֹם בַּיִת מיוחד ואור גדול</p>"],
    )
    .unwrap();
    conn.execute(
        "INSERT INTO line VALUES (?1, ?2, ?3, ?4)",
        params![201, 20, 0, "שלום בית ואור גדול"],
    )
    .unwrap();
    for line in 1..=125 {
        conn.execute(
            "INSERT INTO line VALUES (?1, 10, ?2, ?3)",
            params![1000 + line, line, format!("מבחןעימוד רשומה {line}")],
        )
        .unwrap();
    }
}

fn create_lexical_fixture(path: &Path) {
    let conn = Connection::open(path).expect("create lexical fixture");
    conn.execute_batch(
        "
        CREATE TABLE base(id INTEGER PRIMARY KEY, value TEXT NOT NULL);
        CREATE TABLE surface(id INTEGER PRIMARY KEY, base_id INTEGER NOT NULL, value TEXT NOT NULL);
        CREATE TABLE variant(id INTEGER PRIMARY KEY, value TEXT NOT NULL);
        CREATE TABLE surface_variant(surface_id INTEGER NOT NULL, variant_id INTEGER NOT NULL);
        INSERT INTO base VALUES (1, 'שלום');
        INSERT INTO surface VALUES (1, 1, 'שלום');
        INSERT INTO variant VALUES (1, 'שלוה');
        INSERT INTO surface_variant VALUES (1, 1);
        ",
    )
    .expect("create lexical schema");
}
