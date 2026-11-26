use std::collections::HashSet;
use anyhow::{ensure, Result};
use maktabah_zayit_search::{
    engine::ZayitSearchEngine,
    models::{DataPaths, SearchFilters, SearchRequest},
};
use rusqlite::{Connection, OpenFlags};

fn main() -> Result<()> {
    let args: Vec<_> = std::env::args().collect();
    ensure!(args.len() == 6, "expected DB, lexical DB, index, query and receipt paths");
    let engine = ZayitSearchEngine::open(DataPaths {
        seforim_db: args[1].clone(),
        lexical_db: args[2].clone(),
        index_dir: args[3].clone(),
    })?;
    let db = Connection::open_with_flags(&args[1], OpenFlags::SQLITE_OPEN_READ_ONLY)?;
    let mut row = db.prepare("SELECT bookId,lineIndex FROM line WHERE id=?")?;
    let mut keys = HashSet::new();
    let mut all = Vec::new();
    let mut previous_total = None;
    for offset in [0, 50, 100] {
        let request = SearchRequest {
            query: args[4].clone(),
            near: 5,
            limit: 50,
            offset,
            filters: SearchFilters::default(),
        };
        let result = engine.search(&request)?;
        ensure!(result.hits.len() == 50, "short page at {offset}");
        if let Some(total) = previous_total {
            ensure!(total == result.total_hits, "unstable total hits");
        }
        previous_total = Some(result.total_hits);
        for hit in result.hits {
            let (book, line): (i64, i32) = row.query_row([hit.line_id], |r| Ok((r.get(0)?,r.get(1)?)))?;
            ensure!((book, line) == (hit.book_id, hit.line_index), "wrong source metadata at line {}",hit.line_id);
            ensure!(!hit.stable_book_key.is_empty() && keys.insert((hit.book_id,hit.line_id)), "missing or duplicate source identity");
            all.push(hit);
        }
        println!("PASS offset={offset} returned=50 accumulated={} total={}",all.len(),result.total_hits);
    }
    std::fs::write(&args[5],serde_json::to_string_pretty(&all)?)?;
    Ok(())
}
