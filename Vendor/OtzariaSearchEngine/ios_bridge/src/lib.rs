//! Thin, panic-safe C/JSON adapter over the pinned Otzaria search engine.
//!
//! Search semantics, normalization, highlighting, grouping, compatibility,
//! fingerprints and semantic fusion deliberately remain in upstream.

use base64::{engine::general_purpose::STANDARD as BASE64, Engine as _};
use libc::c_char;
use search_engine::api::search_engine::{
    check_index_compatibility, compute_book_fingerprint, generate_highlight_pattern,
    generate_literal_highlight_pattern, normalize_pdf_text_for_indexing,
    normalize_text_for_indexing, sanitize_query, split_query_words, IndexCompatibility,
    MergedSibling, PdfPageInput, ResultGrouping, ResultsOrder, SearchEngine, SearchPageResult,
    SearchResult, SearchScope, SemanticBookInput, SemanticBookLineInput, SemanticConfigInput,
    SemanticExecutedMode, SemanticGroupingMode, SemanticLexicalMode, SemanticResultSource,
    SemanticRetrievalMode, SemanticSearchResponse, SemanticStatus, WordMatchMode,
};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::collections::HashMap;
use std::ffi::{CStr, CString};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::ptr;
use std::sync::Mutex;

pub struct EngineHandle {
    engine: Mutex<SearchEngine>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct BridgeResponse<T: Serialize> {
    ok: bool,
    value: Option<T>,
    error: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct BridgeSearchRequest {
    query: String,
    #[serde(default)]
    mode: String,
    #[serde(default = "root_facet")]
    facets: Vec<String>,
    #[serde(default = "default_limit")]
    limit: u32,
    #[serde(default)]
    offset: u32,
    #[serde(default)]
    order: String,
    #[serde(default)]
    distance: u32,
    #[serde(default)]
    negative_query: String,
    #[serde(default)]
    negative_distance: u32,
    #[serde(default)]
    scope: String,
    #[serde(default)]
    negative_scope: String,
    #[serde(default)]
    custom_spacing: HashMap<String, String>,
    #[serde(default)]
    negative_custom_spacing: HashMap<String, String>,
    #[serde(default)]
    alternative_words: HashMap<u32, Vec<String>>,
    #[serde(default)]
    negative_alternative_words: HashMap<u32, Vec<String>>,
    #[serde(default)]
    search_options: HashMap<String, HashMap<String, bool>>,
    #[serde(default)]
    negative_search_options: HashMap<String, HashMap<String, bool>>,
    #[serde(default)]
    match_nikud: bool,
    #[serde(default)]
    match_taamim: bool,
    grouping: Option<String>,
    #[serde(default)]
    word_match_mode: String,
    word_match_count: Option<u32>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct BridgeTextBook {
    title: String,
    topics: String,
    file_path: String,
    catalogue_order: u32,
    #[serde(default = "default_generation_order")]
    generation_order: u32,
    text: Option<String>,
    text_base64: Option<String>,
    extra_facets: Option<Vec<String>>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct BridgePdfPage {
    reference: String,
    text: String,
    page_index: u32,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct BridgePdfBook {
    title: String,
    topics: String,
    file_path: String,
    catalogue_order: u32,
    #[serde(default = "default_generation_order")]
    generation_order: u32,
    pages: Vec<BridgePdfPage>,
    extra_facets: Option<Vec<String>>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct DictionaryPaths {
    magic: Option<String>,
    translation: Option<String>,
    acronyms: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct HelperRequest {
    operation: String,
    #[serde(default)]
    input: String,
    #[serde(default)]
    title: String,
    #[serde(default)]
    topics: String,
    #[serde(default)]
    catalogue_order: u32,
    #[serde(default = "default_generation_order")]
    generation_order: u32,
    extra_facets: Option<Vec<String>>,
    #[serde(default)]
    distance: u32,
    #[serde(default)]
    custom_spacing: HashMap<String, String>,
    #[serde(default)]
    alternative_words: HashMap<u32, Vec<String>>,
    #[serde(default)]
    search_options: HashMap<String, HashMap<String, bool>>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct SemanticRequest {
    operation: String,
    root_dir: Option<String>,
    model_path: Option<String>,
    model_id: Option<String>,
    embedding_dim: Option<u32>,
    query: Option<String>,
    facets: Option<Vec<String>>,
    limit: Option<u32>,
    offset: Option<u32>,
    lexical_mode: Option<String>,
    fuzzy_max_distance: Option<u8>,
    retrieval_mode: Option<String>,
    grouping: Option<String>,
    match_nikud: Option<bool>,
    match_taamim: Option<bool>,
    source_book_keys: Option<Vec<String>>,
    books: Option<Vec<BridgeSemanticBook>>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct BridgeSemanticBook {
    source_book_key: String,
    title: String,
    content_fingerprint: u64,
    is_pdf: bool,
    topics: String,
    #[serde(default)]
    extra_facets: Vec<String>,
    #[serde(default)]
    lines: Vec<BridgeSemanticLine>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct BridgeSemanticLine {
    line_id: u64,
    section_id: u64,
    text: String,
    line_hash: u64,
    reference: String,
    segment: u64,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct BridgeMergedSibling {
    title: String,
    reference: String,
    id: u64,
    segment: u64,
    is_pdf: bool,
    file_path: String,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct BridgeSearchResult {
    title: String,
    reference: String,
    text: String,
    id: u64,
    segment: u64,
    is_pdf: bool,
    file_path: String,
    merged_count: u32,
    merged: Vec<BridgeMergedSibling>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct BridgeSearchPage {
    total_count: u32,
    group_count: Option<u32>,
    truncated: bool,
    results: Vec<BridgeSearchResult>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct BridgeCompatibility {
    compatible: bool,
    status: String,
    found_schema_version: Option<u32>,
    required_schema_version: u32,
    engine_version: String,
    metadata_path: String,
    reason: Option<String>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct BridgeBuildInfo {
    upstream_repository: &'static str,
    upstream_branch: &'static str,
    upstream_commit: &'static str,
    engine_version: String,
    index_schema_version: u32,
    default_generation_order: u32,
    semantic_enabled: bool,
    semantic_sidecar_revision: &'static str,
    synced_at: &'static str,
    adapter_version: &'static str,
    resource_hashes: HashMap<String, String>,
}

fn root_facet() -> Vec<String> {
    vec!["/".to_string()]
}

fn default_limit() -> u32 {
    100
}

fn default_generation_order() -> u32 {
    env!("OTZARIA_DEFAULT_GENERATION_ORDER")
        .parse()
        .expect("validated default generation order")
}

fn c_str_to_string(value: *const c_char) -> Result<String, String> {
    if value.is_null() {
        return Err("null C string".to_string());
    }
    unsafe { CStr::from_ptr(value) }
        .to_str()
        .map(str::to_owned)
        .map_err(|error| format!("invalid UTF-8 C string: {error}"))
}

fn panic_text(payload: Box<dyn std::any::Any + Send>) -> String {
    if let Some(message) = payload.downcast_ref::<&str>() {
        (*message).to_owned()
    } else if let Some(message) = payload.downcast_ref::<String>() {
        message.clone()
    } else {
        "non-string panic".to_string()
    }
}

fn to_c_string<T: Serialize>(response: &BridgeResponse<T>) -> *mut c_char {
    let json = serde_json::to_string(response).unwrap_or_else(|error| {
        format!(
            "{{\"ok\":false,\"value\":null,\"error\":\"response serialization failed: {}\"}}",
            error.to_string().replace('"', "'")
        )
    });
    match CString::new(json) {
        Ok(value) => value.into_raw(),
        Err(_) => CString::new(
            "{\"ok\":false,\"value\":null,\"error\":\"response contained a NUL byte\"}",
        )
        .expect("static JSON has no NUL")
        .into_raw(),
    }
}

fn ok<T: Serialize>(value: T) -> *mut c_char {
    to_c_string(&BridgeResponse {
        ok: true,
        value: Some(value),
        error: None,
    })
}

fn err(message: impl ToString) -> *mut c_char {
    to_c_string(&BridgeResponse::<Value> {
        ok: false,
        value: None,
        error: Some(message.to_string()),
    })
}

fn boundary<T, F>(operation: &'static str, body: F) -> *mut c_char
where
    T: Serialize,
    F: FnOnce() -> Result<T, String>,
{
    match catch_unwind(AssertUnwindSafe(body)) {
        Ok(Ok(value)) => ok(value),
        Ok(Err(error)) => err(format!("{operation}: {error}")),
        Err(payload) => err(format!("{operation} panicked: {}", panic_text(payload))),
    }
}

fn with_engine<T>(
    handle: *mut EngineHandle,
    body: impl FnOnce(&mut SearchEngine) -> Result<T, String>,
) -> Result<T, String> {
    if handle.is_null() {
        return Err("engine handle is null".to_string());
    }
    let handle = unsafe { &*handle };
    let mut engine = handle
        .engine
        .lock()
        .map_err(|_| "engine mutex is poisoned".to_string())?;
    body(&mut engine)
}

fn parse_json<T: for<'de> Deserialize<'de>>(value: *const c_char) -> Result<T, String> {
    serde_json::from_str(&c_str_to_string(value)?).map_err(|error| error.to_string())
}

fn order(value: &str) -> ResultsOrder {
    if value.eq_ignore_ascii_case("relevance") {
        ResultsOrder::Relevance
    } else {
        ResultsOrder::Catalogue
    }
}

fn scope(value: &str) -> Result<SearchScope, String> {
    match value {
        "" | "wordDistance" | "word_distance" => Ok(SearchScope::WordDistance),
        "sameParagraph" | "same_paragraph" => Ok(SearchScope::SameParagraph),
        "sameSection" | "same_section" => Ok(SearchScope::SameSection),
        other => Err(format!("unknown search scope '{other}'")),
    }
}

fn grouping(value: Option<&str>) -> Result<Option<ResultGrouping>, String> {
    match value {
        None | Some("") | Some("none") => Ok(None),
        Some("sameSection") | Some("same_section") => Ok(Some(ResultGrouping::SameSection)),
        Some("identicalText") | Some("identical_text") => Ok(Some(ResultGrouping::IdenticalText)),
        Some(other) => Err(format!("unknown grouping '{other}'")),
    }
}

fn word_match(value: &str) -> Result<Option<WordMatchMode>, String> {
    match value {
        "" | "all" => Ok(Some(WordMatchMode::All)),
        "anyWord" | "any_word" => Ok(Some(WordMatchMode::AnyWord)),
        "mostWords" | "most_words" => Ok(Some(WordMatchMode::MostWords)),
        "atLeast" | "at_least" => Ok(Some(WordMatchMode::AtLeast)),
        other => Err(format!("unknown word-match mode '{other}'")),
    }
}

fn bridge_sibling(value: MergedSibling) -> BridgeMergedSibling {
    BridgeMergedSibling {
        title: value.title,
        reference: value.reference,
        id: value.id,
        segment: value.segment,
        is_pdf: value.is_pdf,
        file_path: value.file_path,
    }
}

fn bridge_result(value: SearchResult) -> BridgeSearchResult {
    BridgeSearchResult {
        title: value.title,
        reference: value.reference,
        text: value.text,
        id: value.id,
        segment: value.segment,
        is_pdf: value.is_pdf,
        file_path: value.file_path,
        merged_count: value.merged_count,
        merged: value.merged.into_iter().map(bridge_sibling).collect(),
    }
}

fn bridge_page(value: SearchPageResult) -> BridgeSearchPage {
    BridgeSearchPage {
        total_count: value.total_count,
        group_count: value.group_count,
        truncated: value.truncated,
        results: value.results.into_iter().map(bridge_result).collect(),
    }
}

fn bridge_compatibility(value: IndexCompatibility) -> BridgeCompatibility {
    BridgeCompatibility {
        compatible: value.compatible,
        status: value.status,
        found_schema_version: value.found_schema_version,
        required_schema_version: value.required_schema_version,
        engine_version: value.engine_version,
        metadata_path: value.metadata_path,
        reason: value.reason,
    }
}

fn run_search(
    engine: &SearchEngine,
    request: BridgeSearchRequest,
) -> Result<BridgeSearchPage, String> {
    let selected_grouping = grouping(request.grouping.as_deref())?;
    let result = match request.mode.as_str() {
        "fuzzy" => engine.search_and_count_fuzzy(
            request.query,
            request.facets,
            request.limit,
            request.offset,
            request.distance.min(2) as u8,
            order(&request.order),
            request.match_nikud,
            request.match_taamim,
            selected_grouping,
        ),
        "advanced" => engine.search_and_count_advanced(
            request.query,
            request.negative_query,
            request.facets,
            request.limit,
            request.offset,
            request.distance,
            request.negative_distance,
            request.custom_spacing,
            request.negative_custom_spacing,
            request.alternative_words,
            request.negative_alternative_words,
            request.search_options,
            request.negative_search_options,
            order(&request.order),
            request.match_nikud,
            request.match_taamim,
            scope(&request.scope)?,
            scope(&request.negative_scope)?,
            selected_grouping,
            word_match(&request.word_match_mode)?,
            request.word_match_count,
        ),
        "" | "exact" => engine.search_and_count_exact(
            request.query,
            request.facets,
            request.limit,
            request.offset,
            order(&request.order),
            request.match_nikud,
            request.match_taamim,
            selected_grouping,
        ),
        other => return Err(format!("unknown search mode '{other}'")),
    };
    result
        .map(bridge_page)
        .map_err(|error| format!("{error:#}"))
}

fn run_book_counts(engine: &SearchEngine, request: BridgeSearchRequest) -> Result<Value, String> {
    let result = match request.mode.as_str() {
        "fuzzy" => engine.count_by_book_fuzzy_with_status(
            request.query,
            request.facets,
            request.distance.min(2) as u8,
            request.match_nikud,
            request.match_taamim,
        ),
        "advanced" => engine.count_by_book_advanced_with_status(
            request.query,
            request.negative_query,
            request.facets,
            request.distance,
            request.negative_distance,
            request.custom_spacing,
            request.negative_custom_spacing,
            request.alternative_words,
            request.negative_alternative_words,
            request.search_options,
            request.negative_search_options,
            request.match_nikud,
            request.match_taamim,
            scope(&request.scope)?,
            scope(&request.negative_scope)?,
            word_match(&request.word_match_mode)?,
            request.word_match_count,
        ),
        "" | "exact" => engine.count_by_book_exact_with_status(
            request.query,
            request.facets,
            request.match_nikud,
            request.match_taamim,
        ),
        other => return Err(format!("unknown search mode '{other}'")),
    }
    .map_err(|error| format!("{error:#}"))?;
    Ok(json!({ "counts": result.counts, "truncated": result.truncated }))
}

fn run_facet_counts(
    engine: &SearchEngine,
    request: BridgeSearchRequest,
    facet_prefix: String,
) -> Result<Value, String> {
    let result = match request.mode.as_str() {
        "fuzzy" => engine.get_facet_counts_fuzzy_with_status(
            request.query,
            request.facets,
            facet_prefix,
            request.distance.min(2) as u8,
            request.match_nikud,
            request.match_taamim,
        ),
        "advanced" => engine.get_facet_counts_advanced_with_status(
            request.query,
            request.negative_query,
            request.facets,
            facet_prefix,
            request.distance,
            request.negative_distance,
            request.custom_spacing,
            request.negative_custom_spacing,
            request.alternative_words,
            request.negative_alternative_words,
            request.search_options,
            request.negative_search_options,
            request.match_nikud,
            request.match_taamim,
            scope(&request.scope)?,
            scope(&request.negative_scope)?,
            word_match(&request.word_match_mode)?,
            request.word_match_count,
        ),
        "" | "exact" => engine.get_facet_counts_exact_with_status(
            request.query,
            request.facets,
            facet_prefix,
            request.match_nikud,
            request.match_taamim,
        ),
        other => return Err(format!("unknown search mode '{other}'")),
    }
    .map_err(|error| format!("{error:#}"))?;
    let counts: Vec<Value> = result
        .counts
        .into_iter()
        .map(|entry| json!({ "path": entry.path, "count": entry.count }))
        .collect();
    Ok(json!({ "counts": counts, "truncated": result.truncated }))
}

fn semantic_status_json(value: SemanticStatus) -> Value {
    json!({
        "enabled": value.enabled,
        "available": value.available,
        "modelLoaded": value.model_loaded,
        "indexedBookCount": value.indexed_book_count,
        "vectorCount": value.vector_count,
        "modelId": value.model_id,
        "embeddingDim": value.embedding_dim,
        "embeddingBackend": value.embedding_backend,
        "vectorBackend": value.vector_backend,
        "vectorsPersisted": value.vectors_persisted,
        "needsFullReindex": value.needs_full_reindex,
        "lastError": value.last_error
    })
}

fn semantic_grouping(value: Option<&str>) -> Result<Option<SemanticGroupingMode>, String> {
    match value {
        None | Some("") | Some("none") => Ok(None),
        Some("sameSection") | Some("same_section") => Ok(Some(SemanticGroupingMode::SameSection)),
        Some("identicalText") | Some("identical_text") => {
            Ok(Some(SemanticGroupingMode::IdenticalText))
        }
        Some(other) => Err(format!("unknown semantic grouping '{other}'")),
    }
}

fn semantic_response_json(value: SemanticSearchResponse) -> Value {
    let requested = match value.requested_mode {
        SemanticRetrievalMode::Hybrid => "hybrid",
        SemanticRetrievalMode::SemanticOnly => "semanticOnly",
        SemanticRetrievalMode::LexicalOnly => "lexicalOnly",
    };
    let executed = match value.executed_mode {
        SemanticExecutedMode::Disabled => "disabled",
        SemanticExecutedMode::Hybrid => "hybrid",
        SemanticExecutedMode::SemanticOnly => "semanticOnly",
        SemanticExecutedMode::LexicalOnly => "lexicalOnly",
    };
    let results: Vec<Value> = value
        .results
        .into_iter()
        .map(|result| {
            let source = match result.source {
                SemanticResultSource::Lexical => "lexical",
                SemanticResultSource::Semantic => "semantic",
                SemanticResultSource::Both => "both",
            };
            json!({
                "title": result.title, "reference": result.reference,
                "text": result.snippet_html, "isHighlighted": result.is_highlighted,
                "id": result.id, "segment": result.segment, "isPdf": result.is_pdf,
                "filePath": result.file_path, "mergedCount": result.merged_count,
                "merged": result.merged.into_iter().map(bridge_sibling).collect::<Vec<_>>(),
                "lexicalScore": result.lexical_score, "semanticScore": result.semantic_score,
                "fusedScore": result.fused_score, "source": source,
                "needsHydration": result.needs_hydration
            })
        })
        .collect();
    json!({
        "results": results, "totalCount": value.total_count,
        "lexicalTotalCount": value.lexical_total_count, "groupCount": value.group_count,
        "countsAreExact": value.counts_are_exact, "requestedMode": requested,
        "executedMode": executed, "semanticAvailable": value.semantic_available,
        "fallbackReason": value.fallback_reason, "latencyMs": value.latency_ms,
        "candidateWindowTruncated": value.candidate_window_truncated,
        "truncated": value.truncated
    })
}

#[no_mangle]
pub extern "C" fn otzaria_search_engine_new(index_path: *const c_char) -> *mut EngineHandle {
    match catch_unwind(AssertUnwindSafe(|| {
        let path = c_str_to_string(index_path)?;
        Ok::<_, String>(Box::into_raw(Box::new(EngineHandle {
            engine: Mutex::new(SearchEngine::new(&path)),
        })))
    })) {
        Ok(Ok(handle)) => handle,
        _ => ptr::null_mut(),
    }
}

#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)] // C owns only handles returned by `new`.
pub extern "C" fn otzaria_search_engine_free(handle: *mut EngineHandle) {
    let _ = catch_unwind(AssertUnwindSafe(|| {
        if !handle.is_null() {
            unsafe { drop(Box::from_raw(handle)) };
        }
    }));
}

#[no_mangle]
pub extern "C" fn otzaria_search_engine_search_json(
    handle: *mut EngineHandle,
    request_json: *const c_char,
) -> *mut c_char {
    boundary("search", || {
        let request = parse_json(request_json)?;
        with_engine(handle, |engine| run_search(engine, request))
    })
}

#[no_mangle]
pub extern "C" fn otzaria_search_engine_book_counts_json(
    handle: *mut EngineHandle,
    request_json: *const c_char,
) -> *mut c_char {
    boundary("book_counts", || {
        let request = parse_json(request_json)?;
        with_engine(handle, |engine| run_book_counts(engine, request))
    })
}

#[no_mangle]
pub extern "C" fn otzaria_search_engine_facet_counts_json(
    handle: *mut EngineHandle,
    request_json: *const c_char,
    facet_prefix: *const c_char,
) -> *mut c_char {
    boundary("facet_counts", || {
        let request = parse_json(request_json)?;
        let prefix = c_str_to_string(facet_prefix)?;
        with_engine(handle, |engine| run_facet_counts(engine, request, prefix))
    })
}

#[no_mangle]
pub extern "C" fn otzaria_search_engine_add_text_book_json(
    handle: *mut EngineHandle,
    book_json: *const c_char,
) -> *mut c_char {
    boundary("add_text_book", || {
        let book: BridgeTextBook = parse_json(book_json)?;
        with_engine(handle, |engine| {
            if let Some(encoded) = book.text_base64 {
                let bytes = BASE64.decode(encoded).map_err(|error| error.to_string())?;
                engine.add_text_book_bytes(
                    book.title,
                    book.topics,
                    book.file_path,
                    book.catalogue_order,
                    book.generation_order,
                    bytes,
                    book.extra_facets,
                )
            } else {
                engine.add_text_book(
                    book.title,
                    book.topics,
                    book.file_path,
                    book.catalogue_order,
                    book.generation_order,
                    book.text.unwrap_or_default(),
                    book.extra_facets,
                )
            }
            .map_err(|error| format!("{error:#}"))
        })
    })
}

#[no_mangle]
pub extern "C" fn otzaria_search_engine_add_pdf_book_json(
    handle: *mut EngineHandle,
    book_json: *const c_char,
) -> *mut c_char {
    boundary("add_pdf_book", || {
        let book: BridgePdfBook = parse_json(book_json)?;
        let pages = book
            .pages
            .into_iter()
            .map(|page| PdfPageInput {
                reference: page.reference,
                text: page.text,
                page_index: page.page_index,
            })
            .collect();
        with_engine(handle, |engine| {
            engine
                .add_pdf_book(
                    book.title,
                    book.topics,
                    book.file_path,
                    book.catalogue_order,
                    book.generation_order,
                    pages,
                    book.extra_facets,
                )
                .map_err(|error| format!("{error:#}"))
        })
    })
}

#[no_mangle]
pub extern "C" fn otzaria_search_engine_set_bulk_indexing(
    handle: *mut EngineHandle,
    enabled: bool,
) -> *mut c_char {
    boundary("set_bulk_indexing", || {
        with_engine(handle, |engine| {
            engine
                .set_bulk_indexing(enabled)
                .map(|_| true)
                .map_err(|error| format!("{error:#}"))
        })
    })
}

macro_rules! engine_command {
    ($name:ident, $operation:literal, $method:ident) => {
        #[no_mangle]
        pub extern "C" fn $name(handle: *mut EngineHandle) -> *mut c_char {
            boundary($operation, || {
                with_engine(handle, |engine| {
                    engine
                        .$method()
                        .map(|_| true)
                        .map_err(|error| format!("{error:#}"))
                })
            })
        }
    };
}

engine_command!(otzaria_search_engine_clear, "clear", clear);
engine_command!(otzaria_search_engine_commit, "commit", commit);
engine_command!(otzaria_search_engine_rollback, "rollback", rollback);
engine_command!(otzaria_search_engine_optimize, "optimize", optimize);

#[no_mangle]
pub extern "C" fn otzaria_search_engine_document_count(handle: *mut EngineHandle) -> *mut c_char {
    boundary("document_count", || {
        with_engine(handle, |engine| Ok(engine.get_document_count()))
    })
}

#[no_mangle]
pub extern "C" fn otzaria_search_engine_indexed_file_paths(
    handle: *mut EngineHandle,
) -> *mut c_char {
    boundary("indexed_file_paths", || {
        with_engine(handle, |engine| {
            engine
                .get_indexed_file_paths()
                .map_err(|error| format!("{error:#}"))
        })
    })
}

#[no_mangle]
pub extern "C" fn otzaria_search_engine_book_fingerprints(
    handle: *mut EngineHandle,
) -> *mut c_char {
    boundary("book_fingerprints", || {
        with_engine(handle, |engine| {
            engine
                .get_book_fingerprints()
                .map_err(|error| format!("{error:#}"))
        })
    })
}

#[no_mangle]
pub extern "C" fn otzaria_search_engine_delete_file_paths_json(
    handle: *mut EngineHandle,
    file_paths_json: *const c_char,
) -> *mut c_char {
    boundary("delete_file_paths", || {
        let file_paths: Vec<String> = parse_json(file_paths_json)?;
        with_engine(handle, |engine| {
            engine
                .delete_documents_by_file_paths(file_paths)
                .map(|_| true)
                .map_err(|error| format!("{error:#}"))
        })
    })
}

#[no_mangle]
pub extern "C" fn otzaria_search_engine_check_compatibility(
    index_path: *const c_char,
) -> *mut c_char {
    boundary("check_index_compatibility", || {
        Ok(bridge_compatibility(check_index_compatibility(
            c_str_to_string(index_path)?,
        )))
    })
}

#[no_mangle]
pub extern "C" fn otzaria_search_engine_build_info() -> *mut c_char {
    boundary("build_info", || {
        let compatibility = check_index_compatibility(String::new());
        Ok(BridgeBuildInfo {
            upstream_repository: "Otzaria/otzaria_search_engine",
            upstream_branch: "refactor",
            upstream_commit: env!("OTZARIA_UPSTREAM_COMMIT"),
            engine_version: compatibility.engine_version,
            index_schema_version: compatibility.required_schema_version,
            default_generation_order: default_generation_order(),
            semantic_enabled: cfg!(feature = "semantic"),
            semantic_sidecar_revision: env!("OTZARIA_SEMANTIC_REVISION"),
            synced_at: env!("OTZARIA_SYNCED_AT"),
            adapter_version: env!("CARGO_PKG_VERSION"),
            resource_hashes: serde_json::from_str(env!("OTZARIA_RESOURCE_HASHES"))
                .map_err(|error| error.to_string())?,
        })
    })
}

#[no_mangle]
pub extern "C" fn otzaria_search_engine_set_dictionaries_json(
    handle: *mut EngineHandle,
    paths_json: *const c_char,
) -> *mut c_char {
    boundary("set_dictionaries", || {
        let paths: DictionaryPaths = parse_json(paths_json)?;
        with_engine(handle, |engine| {
            let magic = paths
                .magic
                .map(|path| engine.set_magic_dictionary_path(path))
                .unwrap_or_else(|| engine.has_magic_dictionary());
            let translation = paths
                .translation
                .map(|path| engine.set_translation_dictionary_path(path))
                .unwrap_or_else(|| engine.has_translation_dictionary());
            let acronyms = paths
                .acronyms
                .map(|path| engine.set_acronyms_dictionary_path(path))
                .unwrap_or_else(|| engine.has_acronyms_dictionary());
            Ok(json!({ "magic": magic, "translation": translation, "acronyms": acronyms }))
        })
    })
}

#[no_mangle]
pub extern "C" fn otzaria_search_engine_helper_json(request_json: *const c_char) -> *mut c_char {
    boundary("helper", || {
        let request: HelperRequest = parse_json(request_json)?;
        match request.operation.as_str() {
            "sanitizeQuery" => Ok(json!(sanitize_query(request.input))),
            "splitQueryWords" => Ok(json!(split_query_words(request.input))),
            "normalizeTextForIndexing" => Ok(json!(normalize_text_for_indexing(request.input))),
            "normalizePdfTextForIndexing" => {
                Ok(json!(normalize_pdf_text_for_indexing(request.input)))
            }
            "literalHighlightPattern" => {
                Ok(json!(generate_literal_highlight_pattern(request.input)))
            }
            "highlightPattern" => Ok(
                match generate_highlight_pattern(
                    request.input,
                    request.distance,
                    request.custom_spacing,
                    request.alternative_words,
                    request.search_options,
                ) {
                    Some(pattern) => {
                        json!({ "combinedPattern": pattern.combined_pattern, "wordPatterns": pattern.word_patterns, "wordBoundaryEligible": pattern.word_boundary_eligible })
                    }
                    None => Value::Null,
                },
            ),
            "computeBookFingerprint" => Ok(json!(compute_book_fingerprint(
                request.input,
                request.title,
                request.topics,
                request.catalogue_order,
                request.generation_order,
                request.extra_facets
            ))),
            other => Err(format!("unknown helper operation '{other}'")),
        }
    })
}

#[no_mangle]
pub extern "C" fn otzaria_search_engine_semantic_json(
    handle: *mut EngineHandle,
    request_json: *const c_char,
) -> *mut c_char {
    boundary("semantic", || {
        let request: SemanticRequest = parse_json(request_json)?;
        with_engine(handle, |engine| {
            match request.operation.as_str() {
            "configure" => engine.configure_semantic(SemanticConfigInput {
                root_dir: request.root_dir.ok_or("missing rootDir")?,
                model_path: request.model_path.ok_or("missing modelPath")?,
                model_id: request.model_id.ok_or("missing modelId")?,
                embedding_dim: request.embedding_dim.ok_or("missing embeddingDim")?,
            }).map(semantic_status_json).map_err(|error| format!("{error:#}")),
            "disable" => { engine.disable_semantic(); Ok(semantic_status_json(engine.semantic_status())) }
            "status" => Ok(semantic_status_json(engine.semantic_status())),
            "diff" => engine.semantic_index_diff().map(|value| json!({
                "enabled": value.enabled, "newBooks": value.new_books,
                "changedBooks": value.changed_books, "unverifiableBooks": value.unverifiable_books,
                "removedBooks": value.removed_books, "modelMismatch": value.model_mismatch,
                "chunkingMismatch": value.chunking_mismatch, "normalizationMismatch": value.normalization_mismatch
            })).map_err(|error| format!("{error:#}")),
            "reset" => engine.reset_semantic_index().map(|value| json!({ "enabled": value.enabled, "vectorsRemoved": value.vectors_removed })).map_err(|error| format!("{error:#}")),
            "remove" => engine.remove_semantic_books(request.source_book_keys.unwrap_or_default()).map(|value| json!({ "enabled": value.enabled, "vectorsRemoved": value.vectors_removed })).map_err(|error| format!("{error:#}")),
            "index" => {
                let books = request.books.unwrap_or_default().into_iter().map(|book| SemanticBookInput {
                    source_book_key: book.source_book_key, title: book.title,
                    content_fingerprint: book.content_fingerprint, is_pdf: book.is_pdf,
                    topics: book.topics, extra_facets: book.extra_facets,
                    lines: book.lines.into_iter().map(|line| SemanticBookLineInput {
                        line_id: line.line_id, section_id: line.section_id, text: line.text,
                        line_hash: line.line_hash, reference: line.reference, segment: line.segment,
                    }).collect(),
                }).collect();
                engine.semantic_index_books(books).map(|value| json!({
                    "enabled": value.enabled, "booksIndexed": value.books_indexed,
                    "booksSkipped": value.books_skipped, "booksEmpty": value.books_empty,
                    "chunksWritten": value.chunks_written
                })).map_err(|error| format!("{error:#}"))
            }
            "search" => {
                let lexical_mode = match request.lexical_mode.as_deref().unwrap_or("exact") {
                    "exact" => SemanticLexicalMode::Exact,
                    "fuzzy" => SemanticLexicalMode::Fuzzy,
                    other => return Err(format!("unknown semantic lexical mode '{other}'")),
                };
                let retrieval_mode = match request.retrieval_mode.as_deref().unwrap_or("hybrid") {
                    "hybrid" => SemanticRetrievalMode::Hybrid,
                    "semanticOnly" | "semantic_only" => SemanticRetrievalMode::SemanticOnly,
                    "lexicalOnly" | "lexical_only" => SemanticRetrievalMode::LexicalOnly,
                    other => return Err(format!("unknown semantic retrieval mode '{other}'")),
                };
                engine.search_semantic(
                    request.query.unwrap_or_default(), request.facets.unwrap_or_else(root_facet),
                    request.limit.unwrap_or_else(default_limit), request.offset.unwrap_or_default(),
                    lexical_mode, request.fuzzy_max_distance.unwrap_or_default().min(2), retrieval_mode,
                    semantic_grouping(request.grouping.as_deref())?, request.match_nikud.unwrap_or(false),
                    request.match_taamim.unwrap_or(false),
                ).map(semantic_response_json).map_err(|error| format!("{error:#}"))
            }
            other => Err(format!("unknown semantic operation '{other}'")),
        }
        })
    })
}

#[no_mangle]
pub extern "C" fn otzaria_search_engine_test_panic_boundary() -> *mut c_char {
    boundary::<Value, _>("panic_test", || panic!("intentional bridge panic"))
}

#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)] // C owns only strings returned by this adapter.
pub extern "C" fn otzaria_search_engine_free_string(value: *mut c_char) {
    let _ = catch_unwind(AssertUnwindSafe(|| {
        if !value.is_null() {
            unsafe { drop(CString::from_raw(value)) };
        }
    }));
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{SystemTime, UNIX_EPOCH};

    fn decode_ffi(raw: *mut c_char) -> Value {
        assert!(!raw.is_null());
        let json = unsafe { CStr::from_ptr(raw) }
            .to_string_lossy()
            .into_owned();
        otzaria_search_engine_free_string(raw);
        serde_json::from_str(&json).unwrap()
    }

    fn temporary_index() -> std::path::PathBuf {
        let nonce = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        std::env::temp_dir().join(format!(
            "otzaria-ios-adapter-{}-{nonce}",
            std::process::id()
        ))
    }

    #[test]
    fn panic_is_returned_as_structured_error() {
        let raw = otzaria_search_engine_test_panic_boundary();
        assert!(!raw.is_null());
        let json = unsafe { CStr::from_ptr(raw) }
            .to_string_lossy()
            .into_owned();
        otzaria_search_engine_free_string(raw);
        let value: Value = serde_json::from_str(&json).unwrap();
        assert_eq!(value["ok"], false);
        assert!(value["error"]
            .as_str()
            .unwrap()
            .contains("intentional bridge panic"));
    }

    #[test]
    fn build_info_matches_pinned_commit() {
        let raw = otzaria_search_engine_build_info();
        let json = unsafe { CStr::from_ptr(raw) }
            .to_string_lossy()
            .into_owned();
        otzaria_search_engine_free_string(raw);
        let value: Value = serde_json::from_str(&json).unwrap();
        assert_eq!(
            value["value"]["upstreamCommit"],
            env!("OTZARIA_UPSTREAM_COMMIT")
        );
        assert_eq!(value["value"]["indexSchemaVersion"], 3);
        assert_eq!(value["value"]["defaultGenerationOrder"], 5);
    }

    #[test]
    fn bundled_required_dictionaries_load_without_optional_lexical_database() {
        let index = temporary_index();
        std::fs::create_dir_all(&index).unwrap();
        let index_path = CString::new(index.to_string_lossy().as_bytes()).unwrap();
        let handle = otzaria_search_engine_new(index_path.as_ptr());
        assert!(!handle.is_null());

        let resources = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../Resources");
        let valid = CString::new(
            json!({
                "magic": null,
                "translation": resources.join("dictionary.json").to_string_lossy(),
                "acronyms": resources.join("Acronyms.json").to_string_lossy()
            })
            .to_string(),
        )
        .unwrap();
        let status = decode_ffi(otzaria_search_engine_set_dictionaries_json(
            handle,
            valid.as_ptr(),
        ));
        assert_eq!(status["ok"], true, "{status}");
        assert_eq!(status["value"]["magic"], false);
        assert_eq!(status["value"]["translation"], true);
        assert_eq!(status["value"]["acronyms"], true);

        let malformed = index.join("malformed-dictionary.json");
        std::fs::write(&malformed, b"{not-json").unwrap();
        let invalid = CString::new(
            json!({
                "magic": null,
                "translation": malformed.to_string_lossy(),
                "acronyms": resources.join("Acronyms.json").to_string_lossy()
            })
            .to_string(),
        )
        .unwrap();
        let invalid_status = decode_ffi(otzaria_search_engine_set_dictionaries_json(
            handle,
            invalid.as_ptr(),
        ));
        assert_eq!(invalid_status["ok"], true, "{invalid_status}");
        assert_eq!(invalid_status["value"]["translation"], false);
        assert_eq!(invalid_status["value"]["acronyms"], true);

        otzaria_search_engine_free(handle);
        std::fs::remove_dir_all(index).unwrap();
    }

    #[test]
    fn omitted_generation_order_uses_the_pinned_upstream_default() {
        let text: BridgeTextBook = serde_json::from_value(json!({
            "title": "default", "topics": "/", "filePath": "default",
            "catalogueOrder": 0, "text": "fixture"
        }))
        .unwrap();
        let pdf: BridgePdfBook = serde_json::from_value(json!({
            "title": "default", "topics": "/", "filePath": "default-pdf",
            "catalogueOrder": 0, "pages": []
        }))
        .unwrap();
        assert_eq!(text.generation_order, 5);
        assert_eq!(pdf.generation_order, 5);
    }

    #[test]
    fn rollback_discards_uncommitted_book_and_reopen_is_clean() {
        let index = temporary_index();
        std::fs::create_dir_all(&index).unwrap();
        let path = CString::new(index.to_string_lossy().as_bytes()).unwrap();
        let handle = otzaria_search_engine_new(path.as_ptr());
        assert!(!handle.is_null());
        let book = CString::new(
            json!({
                "title": "rollback fixture", "topics": "/fixtures",
                "filePath": "otzaria-book:rollback", "catalogueOrder": 0,
                "text": "uncommitted text"
            })
            .to_string(),
        )
        .unwrap();
        assert_eq!(
            decode_ffi(otzaria_search_engine_add_text_book_json(
                handle,
                book.as_ptr()
            ))["ok"],
            true
        );
        assert_eq!(
            decode_ffi(otzaria_search_engine_rollback(handle))["ok"],
            true
        );
        otzaria_search_engine_free(handle);

        let reopened = otzaria_search_engine_new(path.as_ptr());
        assert!(!reopened.is_null());
        assert_eq!(
            decode_ffi(otzaria_search_engine_document_count(reopened))["value"],
            0
        );
        otzaria_search_engine_free(reopened);
        std::fs::remove_dir_all(index).unwrap();
    }

    #[test]
    fn commit_failure_is_structured_and_corrupt_metadata_requires_rebuild() {
        let failed_commit = decode_ffi(otzaria_search_engine_commit(ptr::null_mut()));
        assert_eq!(failed_commit["ok"], false);
        assert!(failed_commit["error"]
            .as_str()
            .unwrap()
            .contains("handle is null"));

        let index = temporary_index();
        std::fs::create_dir_all(&index).unwrap();
        std::fs::write(index.join("otzaria_index_meta.json"), b"{not-json").unwrap();
        let path = CString::new(index.to_string_lossy().as_bytes()).unwrap();
        let compatibility = decode_ffi(otzaria_search_engine_check_compatibility(path.as_ptr()));
        assert_eq!(compatibility["ok"], true);
        assert_eq!(compatibility["value"]["compatible"], false);
        assert!(compatibility["value"]["reason"]
            .as_str()
            .unwrap()
            .contains("parse"));
        std::fs::remove_dir_all(index).unwrap();
    }

    #[test]
    fn repeated_bounded_engine_lifetimes_stress_1024_books() {
        const BOOKS: u32 = 1024;
        const BATCH: u32 = 16;
        let index = temporary_index();
        std::fs::create_dir_all(&index).unwrap();
        let path = CString::new(index.to_string_lossy().as_bytes()).unwrap();

        for start in (0..BOOKS).step_by(BATCH as usize) {
            let handle = otzaria_search_engine_new(path.as_ptr());
            assert!(!handle.is_null());
            assert_eq!(
                decode_ffi(otzaria_search_engine_set_bulk_indexing(handle, true))["ok"],
                true
            );
            for id in start..(start + BATCH).min(BOOKS) {
                let book = CString::new(
                    json!({
                        "title": format!("stress {id}"),
                        "topics": "/stress",
                        "filePath": format!("otzaria-book:{id}"),
                        "catalogueOrder": id,
                        "text": format!("bounded lifetime stress fixture {id}")
                    })
                    .to_string(),
                )
                .unwrap();
                assert_eq!(
                    decode_ffi(otzaria_search_engine_add_text_book_json(
                        handle,
                        book.as_ptr()
                    ))["ok"],
                    true
                );
            }
            assert_eq!(decode_ffi(otzaria_search_engine_commit(handle))["ok"], true);
            otzaria_search_engine_free(handle);
        }

        let handle = otzaria_search_engine_new(path.as_ptr());
        assert!(!handle.is_null());
        assert_eq!(
            decode_ffi(otzaria_search_engine_set_bulk_indexing(handle, false))["ok"],
            true
        );
        assert_eq!(decode_ffi(otzaria_search_engine_commit(handle))["ok"], true);
        assert_eq!(
            decode_ffi(otzaria_search_engine_optimize(handle))["ok"],
            true
        );
        assert_eq!(
            decode_ffi(otzaria_search_engine_indexed_file_paths(handle))["value"]
                .as_array()
                .unwrap()
                .len(),
            BOOKS as usize
        );
        let count_before = decode_ffi(otzaria_search_engine_document_count(handle))["value"]
            .as_u64()
            .unwrap();

        let replay_id = BOOKS - 1;
        let replay_path = format!("otzaria-book:{replay_id}");
        let paths = CString::new(json!([replay_path]).to_string()).unwrap();
        assert_eq!(
            decode_ffi(otzaria_search_engine_delete_file_paths_json(
                handle,
                paths.as_ptr()
            ))["ok"],
            true
        );
        let replay = CString::new(
            json!({
                "title": format!("stress {replay_id}"), "topics": "/stress",
                "filePath": replay_path, "catalogueOrder": replay_id,
                "text": format!("bounded lifetime stress fixture {replay_id}")
            })
            .to_string(),
        )
        .unwrap();
        assert_eq!(
            decode_ffi(otzaria_search_engine_add_text_book_json(
                handle,
                replay.as_ptr()
            ))["ok"],
            true
        );
        assert_eq!(decode_ffi(otzaria_search_engine_commit(handle))["ok"], true);
        assert_eq!(
            decode_ffi(otzaria_search_engine_document_count(handle))["value"],
            count_before
        );
        otzaria_search_engine_free(handle);
        let compatibility = decode_ffi(otzaria_search_engine_check_compatibility(path.as_ptr()));
        assert_eq!(compatibility["value"]["compatible"], true);
        std::fs::remove_dir_all(index).unwrap();
    }

    #[test]
    fn c_json_adapter_preserves_upstream_search_status_and_grouping() {
        let index = temporary_index();
        std::fs::create_dir_all(&index).unwrap();
        let path = CString::new(index.to_string_lossy().as_bytes()).unwrap();
        let handle = otzaria_search_engine_new(path.as_ptr());
        assert!(!handle.is_null());

        let book = CString::new(
            json!({
                "title": "ספר בדיקה",
                "topics": "/fixtures",
                "filePath": "otzaria-book:1",
                "catalogueOrder": 0,
                "generationOrder": 5,
                "text": "<h1>פרק ראשון</h1>\nשָׁלוֹם עולם\nשלום וברכה\n<h1>פרק שני</h1>\nשלום רע",
                "extraFacets": ["/author/בודק"]
            })
            .to_string(),
        )
        .unwrap();
        let add = decode_ffi(otzaria_search_engine_add_text_book_json(
            handle,
            book.as_ptr(),
        ));
        assert_eq!(add["ok"], true);
        assert!(add["value"].as_u64().unwrap() >= 3);
        assert_eq!(decode_ffi(otzaria_search_engine_commit(handle))["ok"], true);

        for request in [
            json!({
                "query": "שלום", "mode": "exact", "facets": ["/"],
                "limit": 20, "offset": 0, "order": "catalogue",
                "matchNikud": false, "matchTaamim": false
            }),
            json!({
                "query": "שלם", "mode": "fuzzy", "facets": ["/"],
                "limit": 20, "offset": 0, "order": "relevance", "distance": 1
            }),
            json!({
                "query": "שלום", "negativeQuery": "רע", "mode": "advanced",
                "facets": ["/"], "limit": 20, "offset": 0,
                "order": "catalogue", "distance": 0, "negativeDistance": 0,
                "scope": "wordDistance", "negativeScope": "wordDistance",
                "wordMatchMode": "all", "grouping": "sameSection"
            }),
        ] {
            let request = CString::new(request.to_string()).unwrap();
            let response = decode_ffi(otzaria_search_engine_search_json(handle, request.as_ptr()));
            assert_eq!(response["ok"], true, "{response}");
            let page = &response["value"];
            assert!(page["totalCount"].as_u64().unwrap() > 0, "{page}");
            assert!(page["truncated"].is_boolean());
            assert!(page["results"].as_array().unwrap()[0]["mergedCount"].is_number());
        }

        let exact_request = CString::new(
            json!({
                "query": "×©×œ×•×", "mode": "exact", "facets": ["/"],
                "limit": 20, "offset": 0, "order": "catalogue"
            })
            .to_string(),
        )
        .unwrap();
        let book_counts = decode_ffi(otzaria_search_engine_book_counts_json(
            handle,
            exact_request.as_ptr(),
        ));
        assert_eq!(book_counts["ok"], true);
        assert!(book_counts["value"]["counts"].is_object());
        assert!(book_counts["value"]["truncated"].is_boolean());
        let root = CString::new("/").unwrap();
        let facet_counts = decode_ffi(otzaria_search_engine_facet_counts_json(
            handle,
            exact_request.as_ptr(),
            root.as_ptr(),
        ));
        assert_eq!(facet_counts["ok"], true);
        assert!(facet_counts["value"]["counts"].is_array());

        let fingerprints = decode_ffi(otzaria_search_engine_book_fingerprints(handle));
        assert_ne!(fingerprints["value"]["otzaria-book:1"], 0);

        let count_before = decode_ffi(otzaria_search_engine_document_count(handle))["value"]
            .as_u64()
            .unwrap();
        let paths = CString::new(json!(["otzaria-book:1"]).to_string()).unwrap();
        assert_eq!(
            decode_ffi(otzaria_search_engine_delete_file_paths_json(
                handle,
                paths.as_ptr()
            ))["ok"],
            true
        );
        assert_eq!(
            decode_ffi(otzaria_search_engine_add_text_book_json(
                handle,
                book.as_ptr()
            ))["ok"],
            true
        );
        assert_eq!(decode_ffi(otzaria_search_engine_commit(handle))["ok"], true);
        let count_after = decode_ffi(otzaria_search_engine_document_count(handle))["value"]
            .as_u64()
            .unwrap();
        assert_eq!(count_after, count_before);
        otzaria_search_engine_free(handle);

        let compatibility = decode_ffi(otzaria_search_engine_check_compatibility(path.as_ptr()));
        assert_eq!(compatibility["value"]["compatible"], true);
        assert_eq!(compatibility["value"]["requiredSchemaVersion"], 3);
        std::fs::remove_dir_all(index).unwrap();
    }
}
