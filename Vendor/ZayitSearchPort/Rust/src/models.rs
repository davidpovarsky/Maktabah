use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DataPaths {
    pub seforim_db: String,
    pub lexical_db: String,
    pub index_dir: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct SearchFilters {
    pub book_id: Option<i64>,
    pub category_id: Option<i64>,
    pub book_ids: Vec<i64>,
    pub line_ids: Vec<i64>,
    pub base_book_only: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchRequest {
    pub query: String,
    pub near: u32,
    pub limit: usize,
    pub offset: usize,
    #[serde(default)]
    pub filters: SearchFilters,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LineHit {
    pub book_id: i64,
    pub book_title: String,
    pub line_id: i64,
    pub line_index: i32,
    pub snippet_html: String,
    pub score: f32,
    pub is_base_book: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchPage {
    pub hits: Vec<LineHit>,
    pub total_hits: u64,
    pub is_last_page: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ValidationReport {
    pub valid: bool,
    pub missing: Vec<String>,
    pub errors: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EngineErrorPayload {
    pub code: String,
    pub message: String,
}
