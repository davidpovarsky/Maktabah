use anyhow::{Context, Result};
use maktabah_zayit_search::{
    engine::ZayitSearchEngine,
    models::{DataPaths, SearchFilters, SearchRequest},
};
use std::env;

fn main() -> Result<()> {
    let arguments = env::args().skip(1).collect::<Vec<_>>();
    if arguments.len() != 4 {
        eprintln!("Usage: zayit-query <seforim.db> <lexical.db> <index-directory> <query>");
        std::process::exit(2);
    }
    let engine = ZayitSearchEngine::open(DataPaths {
        seforim_db: arguments[0].clone(),
        lexical_db: arguments[1].clone(),
        index_dir: arguments[2].clone(),
    })?;
    let page = engine.search(&SearchRequest {
        query: arguments[3].clone(),
        near: 5,
        limit: 25,
        offset: 0,
        filters: SearchFilters::default(),
    })?;
    anyhow::ensure!(!page.hits.is_empty(), "golden query returned no results");
    anyhow::ensure!(
        page.hits.iter().all(|hit| !hit.stable_book_key.is_empty()),
        "a result is missing stable book identity"
    );
    println!(
        "{}",
        serde_json::to_string_pretty(&page).context("serialize search page")?
    );
    Ok(())
}
