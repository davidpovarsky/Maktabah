use maktabah_zayit_search::line_decoder::*;
use rusqlite::{params, Connection};
use std::collections::HashMap;

#[test]
fn decodes_plain_text_and_blob_without_dictionary() {
    let raw_text = "שלום עליכם מלאכי השרת";
    let compressed = zstd::bulk::compress(raw_text.as_bytes(), 3).expect("compress text");
    let dicts = HashMap::new();

    // Plain text Value::Text
    let decoded_text =
        decode_line_content(rusqlite::types::Value::Text(raw_text.to_string()), &dicts)
            .expect("decode text");
    assert_eq!(decoded_text, raw_text);

    // Compressed Value::Blob
    let decoded_blob = decode_line_content(rusqlite::types::Value::Blob(compressed), &dicts)
        .expect("decode compressed blob");
    assert_eq!(decoded_blob, raw_text);
}

#[test]
fn decodes_zstd_dictionary_compressed_blob() {
    let samples: Vec<Vec<u8>> = (0..50)
        .map(|i| format!("שלום עליכם מלאכי השלום פרק מספר {i} ותורה ואור ומצוה").into_bytes())
        .collect();
    let dict_bytes = zstd::dict::from_samples(&samples, 4096).expect("train dict");
    let dict_id = zstd::zstd_safe::get_dict_id_from_dict(&dict_bytes)
        .expect("dict id from dict")
        .get();

    let mut encoder = zstd::bulk::Compressor::with_dictionary(3, &dict_bytes).expect("compressor");
    let original = "שלום עליכם מלאכי השרת";
    let compressed_frame = encoder
        .compress(original.as_bytes())
        .expect("compress with dict");

    assert_eq!(
        zstd::zstd_safe::get_dict_id_from_frame(&compressed_frame).map(|id| id.get()),
        Some(dict_id)
    );

    let mut dicts = HashMap::new();
    dicts.insert(dict_id, dict_bytes.clone());

    let decoded = decode_line_content(rusqlite::types::Value::Blob(compressed_frame), &dicts)
        .expect("decode with dictionary");
    assert_eq!(decoded, original);
}

#[test]
fn line_decoder_loads_from_sqlite_with_various_schemas() {
    // Schema 1: line table with content (BLOB) and heRef
    let conn1 = Connection::open_in_memory().expect("open sqlite 1");
    conn1.execute(
        "CREATE TABLE line (id INTEGER PRIMARY KEY, bookId INTEGER, lineIndex INTEGER, content BLOB, heRef TEXT)",
        [],
    )
    .expect("create table line");

    let compressed = zstd::bulk::compress("בראשית ברא אלהים".as_bytes(), 3).unwrap();
    conn1
        .execute(
            "INSERT INTO line (id, bookId, lineIndex, content, heRef) VALUES (?1, ?2, ?3, ?4, ?5)",
            params![10, 1, 1, compressed, "בראשית א, א"],
        )
        .expect("insert line");

    let decoder1 = LineDecoder::new(&conn1).expect("init decoder 1");
    let (raw1, ref1) = decoder1.load_line(&conn1, 10).expect("load line 10");
    assert_eq!(raw1, "בראשית ברא אלהים");
    assert_eq!(ref1, "בראשית א, א");

    // Schema 2: line_content separate table (Otzaria v32/6 style)
    let conn2 = Connection::open_in_memory().expect("open sqlite 2");
    conn2.execute(
        "CREATE TABLE line (id INTEGER PRIMARY KEY, bookId INTEGER, lineIndex INTEGER, heRef TEXT)",
        [],
    )
    .expect("create table line 2");
    conn2
        .execute(
            "CREATE TABLE line_content (id INTEGER PRIMARY KEY, content BLOB)",
            [],
        )
        .expect("create table line_content");
    conn2
        .execute("CREATE TABLE zstd_dict (dict BLOB)", [])
        .expect("create table zstd_dict");

    let samples: Vec<Vec<u8>> = (0..50)
        .map(|i| format!("torah content sample {i} repeating phrases").into_bytes())
        .collect();
    let dict_bytes = zstd::dict::from_samples(&samples, 4096).expect("train dict");
    let dict_id = zstd::zstd_safe::get_dict_id_from_dict(&dict_bytes)
        .expect("dict id")
        .get();

    conn2
        .execute(
            "INSERT INTO zstd_dict (dict) VALUES (?1)",
            params![dict_bytes],
        )
        .expect("insert dict");

    let mut compressor = zstd::bulk::Compressor::with_dictionary(3, &dict_bytes).unwrap();
    let text2 = "ויאמר אלהים יהי אור ויהי אור";
    let comp2 = compressor.compress(text2.as_bytes()).unwrap();

    conn2
        .execute(
            "INSERT INTO line (id, bookId, lineIndex, heRef) VALUES (?1, ?2, ?3, ?4)",
            params![20, 1, 3, "בראשית א, ג"],
        )
        .expect("insert line 2");
    conn2
        .execute(
            "INSERT INTO line_content (id, content) VALUES (?1, ?2)",
            params![20, comp2],
        )
        .expect("insert line_content 2");

    let decoder2 = LineDecoder::new(&conn2).expect("init decoder 2");
    assert!(decoder2.dictionaries().contains_key(&dict_id));

    let (raw2, ref2) = decoder2.load_line(&conn2, 20).expect("load line 20");
    assert_eq!(raw2, text2);
    assert_eq!(ref2, "בראשית א, ג");
}
