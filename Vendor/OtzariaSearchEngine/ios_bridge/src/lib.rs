use libc::c_char;
use search_engine::api::search_engine::{
    DocumentInput, ResultsOrder, SearchEngine, SearchResult,
};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::ffi::{CStr, CString};
use std::ptr;
use std::sync::Mutex;

struct EngineHandle {
    engine: Mutex<SearchEngine>,
}

#[derive(Debug, Deserialize)]
struct BridgeDocument {
    id: u64,
    title: String,
    reference: String,
    topics: String,
    text: String,
    segment: u64,
    is_pdf: bool,
    file_path: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct BridgeSearchRequest {
    query: String,
    mode: String,
    facets: Vec<String>,
    limit: u32,
    offset: u32,
    order: String,
    distance: Option<u32>,
    custom_spacing: Option<HashMap<String, String>>,
    alternative_words: Option<HashMap<u32, Vec<String>>>,
    search_options: Option<HashMap<String, HashMap<String, bool>>>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct BridgeSearchResult {
    title: String,
    reference: String,
    text: String,
    id: u64,
    segment: u64,
    is_pdf: bool,
    file_path: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct BridgeResponse<T: Serialize> {
    ok: bool,
    value: Option<T>,
    error: Option<String>,
}

fn c_str_to_string(ptr: *const c_char) -> Result<String, String> {
    if ptr.is_null() {
        return Err("null pointer".to_string());
    }
    unsafe { CStr::from_ptr(ptr) }
        .to_str()
        .map(|s| s.to_string())
        .map_err(|e| e.to_string())
}

fn to_c_string<T: Serialize>(value: &T) -> *mut c_char {
    let json = serde_json::to_string(value).unwrap_or_else(|_| {
        r#"{"ok":false,"value":null,"error":"failed to serialize response"}"#.to_string()
    });
    CString::new(json).unwrap_or_else(|_| CString::new("{\"ok\":false,\"value\":null,\"error\":\"nul byte in response\"}").unwrap()).into_raw()
}

fn ok<T: Serialize>(value: T) -> *mut c_char {
    to_c_string(&BridgeResponse { ok: true, value: Some(value), error: None })
}

fn err(message: impl ToString) -> *mut c_char {
    to_c_string(&BridgeResponse::<serde_json::Value> {
        ok: false,
        value: None,
        error: Some(message.to_string()),
    })
}

fn result_to_bridge(result: SearchResult) -> BridgeSearchResult {
    BridgeSearchResult {
        title: result.title,
        reference: result.reference,
        text: result.text,
        id: result.id,
        segment: result.segment,
        is_pdf: result.is_pdf,
        file_path: result.file_path,
    }
}

fn order_from_string(order: &str) -> ResultsOrder {
    match order {
        "relevance" | "Relevance" => ResultsOrder::Relevance,
        _ => ResultsOrder::Catalogue,
    }
}

#[no_mangle]
pub extern "C" fn otzaria_search_engine_new(index_path: *const c_char) -> *mut EngineHandle {
    let path = match c_str_to_string(index_path) {
        Ok(path) => path,
        Err(_) => return ptr::null_mut(),
    };
    let engine = SearchEngine::new(&path);
    Box::into_raw(Box::new(EngineHandle { engine: Mutex::new(engine) }))
}

#[no_mangle]
pub extern "C" fn otzaria_search_engine_free(handle: *mut EngineHandle) {
    if handle.is_null() {
        return;
    }
    unsafe { drop(Box::from_raw(handle)); }
}

#[no_mangle]
pub extern "C" fn otzaria_search_engine_add_documents_json(handle: *mut EngineHandle, documents_json: *const c_char) -> *mut c_char {
    if handle.is_null() {
        return err("engine handle is null");
    }
    let raw = match c_str_to_string(documents_json) {
        Ok(raw) => raw,
        Err(e) => return err(e),
    };
    let docs: Vec<BridgeDocument> = match serde_json::from_str(&raw) {
        Ok(docs) => docs,
        Err(e) => return err(e),
    };
    let inputs: Vec<DocumentInput> = docs.into_iter().map(|d| DocumentInput {
        id: d.id,
        title: d.title,
        reference: d.reference,
        topics: d.topics,
        text: d.text,
        segment: d.segment,
        is_pdf: d.is_pdf,
        file_path: d.file_path,
    }).collect();
    let handle_ref = unsafe { &*handle };
    let mut engine = match handle_ref.engine.lock() {
        Ok(engine) => engine,
        Err(_) => return err("engine mutex poisoned"),
    };
    match engine.add_documents_batch(inputs) {
        Ok(_) => ok(true),
        Err(e) => err(format!("{e:#}")),
    }
}

#[no_mangle]
pub extern "C" fn otzaria_search_engine_search_json(handle: *mut EngineHandle, request_json: *const c_char) -> *mut c_char {
    if handle.is_null() {
        return err("engine handle is null");
    }
    let raw = match c_str_to_string(request_json) {
        Ok(raw) => raw,
        Err(e) => return err(e),
    };
    let req: BridgeSearchRequest = match serde_json::from_str(&raw) {
        Ok(req) => req,
        Err(e) => return err(e),
    };
    let order = order_from_string(&req.order);
    let handle_ref = unsafe { &*handle };
    let engine = match handle_ref.engine.lock() {
        Ok(engine) => engine,
        Err(_) => return err("engine mutex poisoned"),
    };
    let result = match req.mode.as_str() {
        "fuzzy" => engine.search_fuzzy(
            req.query,
            req.facets,
            req.limit,
            req.offset,
            req.distance.unwrap_or(1).min(2) as u8,
            order,
        ),
        "advanced" => engine.search_advanced(
            req.query,
            req.facets,
            req.limit,
            req.offset,
            req.distance.unwrap_or(0),
            req.custom_spacing.unwrap_or_default(),
            req.alternative_words.unwrap_or_default(),
            req.search_options.unwrap_or_default(),
            order,
        ),
        _ => engine.search_exact(
            req.query,
            req.facets,
            req.limit,
            req.offset,
            order,
        ),
    };
    match result {
        Ok(results) => ok(results.into_iter().map(result_to_bridge).collect::<Vec<_>>()),
        Err(e) => err(format!("{e:#}")),
    }
}

#[no_mangle]
pub extern "C" fn otzaria_search_engine_clear(handle: *mut EngineHandle) -> *mut c_char {
    if handle.is_null() { return err("engine handle is null"); }
    let handle_ref = unsafe { &*handle };
    let mut engine = match handle_ref.engine.lock() { Ok(engine) => engine, Err(_) => return err("engine mutex poisoned") };
    match engine.clear() { Ok(_) => ok(true), Err(e) => err(format!("{e:#}")) }
}

#[no_mangle]
pub extern "C" fn otzaria_search_engine_commit(handle: *mut EngineHandle) -> *mut c_char {
    if handle.is_null() { return err("engine handle is null"); }
    let handle_ref = unsafe { &*handle };
    let mut engine = match handle_ref.engine.lock() { Ok(engine) => engine, Err(_) => return err("engine mutex poisoned") };
    match engine.commit() { Ok(_) => ok(true), Err(e) => err(format!("{e:#}")) }
}

#[no_mangle]
pub extern "C" fn otzaria_search_engine_optimize(handle: *mut EngineHandle) -> *mut c_char {
    if handle.is_null() { return err("engine handle is null"); }
    let handle_ref = unsafe { &*handle };
    let mut engine = match handle_ref.engine.lock() { Ok(engine) => engine, Err(_) => return err("engine mutex poisoned") };
    match engine.optimize() { Ok(_) => ok(true), Err(e) => err(format!("{e:#}")) }
}

#[no_mangle]
pub extern "C" fn otzaria_search_engine_document_count(handle: *mut EngineHandle) -> *mut c_char {
    if handle.is_null() { return err("engine handle is null"); }
    let handle_ref = unsafe { &*handle };
    let engine = match handle_ref.engine.lock() { Ok(engine) => engine, Err(_) => return err("engine mutex poisoned") };
    ok(engine.get_document_count())
}

#[no_mangle]
pub extern "C" fn otzaria_search_engine_indexed_file_paths(handle: *mut EngineHandle) -> *mut c_char {
    if handle.is_null() { return err("engine handle is null"); }
    let handle_ref = unsafe { &*handle };
    let engine = match handle_ref.engine.lock() { Ok(engine) => engine, Err(_) => return err("engine mutex poisoned") };
    match engine.get_indexed_file_paths() {
        Ok(paths) => ok(paths),
        Err(e) => err(format!("{e:#}")),
    }
}

#[no_mangle]
pub extern "C" fn otzaria_search_engine_free_string(value: *mut c_char) {
    if value.is_null() { return; }
    unsafe { drop(CString::from_raw(value)); }
}
