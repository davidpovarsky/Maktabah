use crate::{
    engine::{validate_paths, ZayitSearchEngine},
    models::{DataPaths, SearchRequest},
};
use once_cell::sync::Lazy;
use parking_lot::Mutex;
use std::{
    collections::HashMap,
    ffi::{c_char, CStr, CString},
    sync::Arc,
};
static ENGINES: Lazy<Mutex<HashMap<u64, Arc<ZayitSearchEngine>>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));
static NEXT: Lazy<Mutex<u64>> = Lazy::new(|| Mutex::new(1));
fn out(s: String) -> *mut c_char {
    CString::new(s.replace('\0', " ")).unwrap().into_raw()
}
fn err(e: impl ToString) -> *mut c_char {
    out(serde_json::json!({"ok":false,"error":{"message":e.to_string()}}).to_string())
}
unsafe fn input<'a>(p: *const c_char) -> Result<&'a str, String> {
    if p.is_null() {
        return Err("null input".into());
    }
    CStr::from_ptr(p).to_str().map_err(|e| e.to_string())
}
#[no_mangle]
pub unsafe extern "C" fn mzayit_validate_paths(json: *const c_char) -> *mut c_char {
    let r = (|| {
        let p: DataPaths = serde_json::from_str(input(json)?).map_err(|e| e.to_string())?;
        validate_paths(&p).map_err(|e| e.to_string())
    })();
    match r {
        Ok(v) => out(serde_json::to_string(&v).unwrap()),
        Err(e) => err(e),
    }
}
#[no_mangle]
pub unsafe extern "C" fn mzayit_engine_create(json: *const c_char) -> *mut c_char {
    let r = (|| {
        let p: DataPaths = serde_json::from_str(input(json)?).map_err(|e| e.to_string())?;
        let e = Arc::new(ZayitSearchEngine::open(p).map_err(|e| e.to_string())?);
        let mut n = NEXT.lock();
        let id = *n;
        *n += 1;
        ENGINES.lock().insert(id, e);
        Ok::<_, String>(id)
    })();
    match r {
        Ok(id) => out(serde_json::json!({"ok":true,"engine_id":id}).to_string()),
        Err(e) => err(e),
    }
}
#[no_mangle]
pub unsafe extern "C" fn mzayit_engine_search(id: u64, json: *const c_char) -> *mut c_char {
    let r = (|| {
        let req: SearchRequest = serde_json::from_str(input(json)?).map_err(|e| e.to_string())?;
        let e = ENGINES.lock().get(&id).cloned().ok_or("engine not found")?;
        e.search(&req).map_err(|e| e.to_string())
    })();
    match r {
        Ok(v) => out(serde_json::to_string(&v).unwrap()),
        Err(e) => err(e),
    }
}
#[no_mangle]
pub extern "C" fn mzayit_engine_destroy(id: u64) {
    ENGINES.lock().remove(&id);
}
#[no_mangle]
pub unsafe extern "C" fn mzayit_string_free(p: *mut c_char) {
    if !p.is_null() {
        drop(CString::from_raw(p));
    }
}
