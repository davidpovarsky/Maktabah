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

#[test]
#[ignore = "Requires explicitly reconstructed and SHA256-verified isolated production v32 fixture"]
fn production_v32_queries_and_paging_through_real_c_abi() {
    use maktabah_zayit_search::{ffi::*, models::SearchPage};
    use std::collections::HashMap;
    let root = Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../..")
        .canonicalize()
        .unwrap();
    let fixture = root
        .join("build/hq-search-v32-fixture-20261115")
        .canonicalize()
        .unwrap();
    let marker = Path::new(
        &std::env::var("MAKTABAH_V32_FIXTURE_READY").expect("explicit fixture marker required"),
    )
    .canonicalize()
    .unwrap();
    assert_eq!(marker, fixture.join("fixture-ready.json"));
    let ready: serde_json::Value =
        serde_json::from_slice(&std::fs::read(&marker).unwrap()).unwrap();
    let manifest: serde_json::Value = serde_json::from_slice(
        &std::fs::read(root.join("docs/hq-search/manifests/zayit-search-manifest.json")).unwrap(),
    )
    .unwrap();
    assert_eq!(ready["manifestIdentity"], manifest["artifactIdentity"]);
    let path = |key: &str| {
        let path = Path::new(ready[key].as_str().unwrap())
            .canonicalize()
            .unwrap();
        assert!(
            path.starts_with(&fixture),
            "production test may only open its isolated fixture"
        );
        path.to_string_lossy().into_owned()
    };
    let paths = DataPaths {
        seforim_db: path("database"),
        lexical_db: path("lexical"),
        index_dir: path("index"),
    };
    let db = Connection::open_with_flags(
        &paths.seforim_db,
        rusqlite::OpenFlags::SQLITE_OPEN_READ_ONLY,
    )
    .unwrap();
    let has_file_path = {
        let mut columns = db.prepare("PRAGMA table_info(book)").unwrap();
        let names = columns
            .query_map([], |row| row.get::<_, String>(1))
            .unwrap()
            .collect::<Result<Vec<_>, _>>()
            .unwrap();
        names.iter().any(|name| name == "filePath")
    };
    let key_projection = if has_file_path {
        "COALESCE(NULLIF(b.filePath,''),'book:'||b.id)"
    } else {
        "'book:'||b.id"
    };
    let identity_sql = format!("SELECT l.bookId,l.lineIndex,{key_projection} FROM line l JOIN book b ON b.id=l.bookId WHERE l.id=?1");
    let mut report = serde_json::json!({"kind":"REAL_PRODUCTION_V32_SQLITE_INDEX_C_ABI", "artifactIdentity":manifest["artifactIdentity"],
        "result":"IN_PROGRESS_NOT_A_PASS", "totalSemantics":"raw matching index documents, not occurrence counts", "databaseHasFilePathColumn":has_file_path, "queries":[], "paging":[]});
    let report_path = root.join("docs/hq-search/wave-v32-real-ffi.json");
    std::fs::write(&report_path, serde_json::to_vec_pretty(&report).unwrap()).unwrap();
    unsafe {
        let encoded = CString::new(serde_json::to_string(&paths).unwrap()).unwrap();
        let opened = ffi_json(mzayit_engine_create(encoded.as_ptr()));
        let id = opened["engine_id"]
            .as_u64()
            .unwrap_or_else(|| panic!("real production engine open failed: {opened}"));
        for text in ["משה", "שלום", "בראשית", "לחתוך צנון בסכין בשרי"]
        {
            let query = SearchRequest {
                query: text.into(),
                near: 5,
                offset: 0,
                limit: 50,
                filters: SearchFilters::default(),
            };
            let input = CString::new(serde_json::to_string(&query).unwrap()).unwrap();
            let raw = ffi_json(mzayit_engine_search(id, input.as_ptr()));
            let page: SearchPage = serde_json::from_value(raw.clone())
                .unwrap_or_else(|error| panic!("production search failed: {raw}; {error}"));
            assert!(
                !page.hits.is_empty(),
                "known corpus Hebrew query returned no results: {text}"
            );
            let selected = page.hits[0].book_id;
            let filtered = SearchRequest {
                filters: SearchFilters {
                    book_ids: vec![selected],
                    ..SearchFilters::default()
                },
                ..query.clone()
            };
            let input = CString::new(serde_json::to_string(&filtered).unwrap()).unwrap();
            let scoped: SearchPage =
                serde_json::from_value(ffi_json(mzayit_engine_search(id, input.as_ptr()))).unwrap();
            report["queries"].as_array_mut().unwrap().push(serde_json::json!({"query":text,"near":5,"offset":0,"limit":50,"total":page.total_hits,"returned":page.hits.len(),"firstBook":selected,"filteredReturned":scoped.hits.len(),"sample":page.hits.first()}));
            std::fs::write(&report_path, serde_json::to_vec_pretty(&report).unwrap()).unwrap();
            assert!(!scoped.hits.is_empty(), "same query lost its own matching source book: query={text}, selectedBook={selected}, unfilteredTotal={}, filteredTotal={}", page.total_hits, scoped.total_hits);
            assert!(scoped.hits.iter().all(|hit| hit.book_id == selected));
            let input = CString::new(serde_json::to_string(&query).unwrap()).unwrap();
            let repeated: SearchPage =
                serde_json::from_value(ffi_json(mzayit_engine_search(id, input.as_ptr()))).unwrap();
            assert_eq!(
                repeated.total_hits, page.total_hits,
                "warm query changed the matching corpus for {text}"
            );
            assert_eq!(
                repeated
                    .hits
                    .iter()
                    .map(|hit| hit.line_id)
                    .collect::<Vec<_>>(),
                page.hits.iter().map(|hit| hit.line_id).collect::<Vec<_>>(),
                "warm query changed stable first-page IDs for {text}"
            );
        }
        let mut identities = HashMap::new();
        let mut first_page_ids = Vec::new();
        let mut paging_total = None;
        for offset in [0, 50, 100] {
            let query = SearchRequest {
                query: "משה".into(),
                near: 0,
                offset,
                limit: 50,
                filters: SearchFilters::default(),
            };
            let input = CString::new(serde_json::to_string(&query).unwrap()).unwrap();
            let page: SearchPage =
                serde_json::from_value(ffi_json(mzayit_engine_search(id, input.as_ptr()))).unwrap();
            assert_eq!(page.hits.len(), 50);
            assert!(page.total_hits > 150 && !page.is_last_page);
            if offset == 0 {
                first_page_ids = page.hits.iter().map(|hit| hit.line_id).collect();
                paging_total = Some(page.total_hits);
            } else {
                assert_eq!(
                    Some(page.total_hits),
                    paging_total,
                    "paging changed the selected lexical meaning"
                );
            }
            for hit in &page.hits {
                let (book, line, key): (i64, i32, String) = db
                    .query_row(&identity_sql, [hit.line_id], |row| {
                        Ok((row.get(0)?, row.get(1)?, row.get(2)?))
                    })
                    .unwrap();
                assert_eq!(
                    (hit.book_id, hit.line_index, hit.stable_book_key.as_str()),
                    (book, line, key.as_str())
                );
                if let Some(old) = identities.insert(hit.line_id, (book, line, key.clone())) {
                    assert_eq!(old, (book, line, key));
                }
                assert!(!hit.snippet_html.is_empty());
                assert!(!hit.matched_terms.is_empty());
            }
            report["paging"].as_array_mut().unwrap().push(serde_json::json!({"query":"משה","near":0,"limit":50,"offset":offset,"returned":page.hits.len(),"total":page.total_hits,"lastPage":page.is_last_page}));
        }
        assert!(
            identities.len() > 100,
            "150 source rows must provide over 100 distinct genuine corpus locators"
        );
        report["uniqueVerifiedLineIDs"] = serde_json::json!(identities.len());
        mzayit_engine_destroy(id);
        let reopened = ffi_json(mzayit_engine_create(encoded.as_ptr()));
        let reopened_id = reopened["engine_id"]
            .as_u64()
            .expect("production index must reopen without rebuild");
        let reopened_request = SearchRequest {
            query: "משה".into(),
            near: 0,
            offset: 0,
            limit: 50,
            filters: SearchFilters::default(),
        };
        let input = CString::new(serde_json::to_string(&reopened_request).unwrap()).unwrap();
        let page: SearchPage =
            serde_json::from_value(ffi_json(mzayit_engine_search(reopened_id, input.as_ptr())))
                .unwrap();
        assert!(!page.hits.is_empty());
        assert_eq!(
            Some(page.total_hits),
            paging_total,
            "engine reopen changed the matching corpus"
        );
        assert_eq!(
            page.hits.iter().map(|hit| hit.line_id).collect::<Vec<_>>(),
            first_page_ids,
            "engine reopen changed stable first-page IDs"
        );
        mzayit_engine_destroy(reopened_id);
    }
    report["result"] = serde_json::json!("EXECUTED_PASS");
    std::fs::write(
        root.join("docs/hq-search/wave-v32-real-ffi.json"),
        serde_json::to_vec_pretty(&report).unwrap(),
    )
    .unwrap();
}
