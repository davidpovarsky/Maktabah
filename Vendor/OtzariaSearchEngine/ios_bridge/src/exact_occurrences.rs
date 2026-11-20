//! Exact original-engine occurrence counting through a bounded C request lifetime.
//! No existing C function or search behavior is changed by this module.
use crate::{panic_text, resolve_facets, root_facet, EngineHandle};
use libc::c_char;
use search_engine::exact_occurrences::{
    ExactOccurrenceCancellation, ExactOccurrenceControl, ExactOccurrenceError,
    ExactOccurrenceLimits, ExactTokenOccurrenceCount,
};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::collections::HashMap;
use std::ffi::CString;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::ptr;
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::sync::{Arc, Mutex, OnceLock, TryLockError};
use std::time::{Duration, Instant};

const MAX_REQUEST_BYTES: usize = 512 * 1024;
const MAX_RESPONSE_BYTES: usize = 1024 * 1024;
const MAX_REQUESTS: usize = 64;
const MAX_TIMEOUT_MS: u64 = 60_000;

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct Failure {
    code: &'static str,
    message: String,
}

impl Failure {
    fn new(code: &'static str, message: impl Into<String>) -> Self {
        Self {
            code,
            message: message.into(),
        }
    }
}

impl From<ExactOccurrenceError> for Failure {
    fn from(error: ExactOccurrenceError) -> Self {
        let code = match &error {
            ExactOccurrenceError::SingleAnalyzedTokenRequired { .. } => "unsupported_query",
            ExactOccurrenceError::QueryTooLong | ExactOccurrenceError::InvalidFacets => {
                "invalid_request"
            }
            ExactOccurrenceError::InvalidLimits => "invalid_limits",
            ExactOccurrenceError::PositionsUnavailable => "positions_unavailable",
            ExactOccurrenceError::InvalidPositions => "invalid_positions",
            ExactOccurrenceError::BudgetExceeded(_) => "budget_exceeded",
            ExactOccurrenceError::CountOverflow => "count_overflow",
            ExactOccurrenceError::Cancelled => "cancelled",
            ExactOccurrenceError::DeadlineExceeded => "deadline_exceeded",
            ExactOccurrenceError::Engine(_) => "engine_error",
        };
        Self::new(code, error.to_string())
    }
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields, default)]
struct Limits {
    max_candidate_documents: u64,
    max_positions: u64,
    max_positions_per_document: u32,
    max_segments: usize,
}

impl Default for Limits {
    fn default() -> Self {
        let limits = ExactOccurrenceLimits::default();
        Self {
            max_candidate_documents: limits.max_candidate_documents,
            max_positions: limits.max_positions,
            max_positions_per_document: limits.max_positions_per_document,
            max_segments: limits.max_segments,
        }
    }
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct Input {
    version: u32,
    mode: String,
    query: String,
    #[serde(default = "root_facet")]
    facets: Vec<String>,
    #[serde(default)]
    book_ids: Vec<u64>,
    timeout_ms: u64,
    #[serde(default)]
    limits: Limits,
}

// Capacity follows the final Request/Arc lifetime, including released requests
// that are still unwinding engine work. A token release cannot reopen capacity
// while its input strings are retained by an in-flight call.
static LIVE_REQUESTS: AtomicUsize = AtomicUsize::new(0);

struct CapacityReservation;

impl CapacityReservation {
    fn reserve() -> Result<Self, Failure> {
        LIVE_REQUESTS
            .fetch_update(Ordering::AcqRel, Ordering::Acquire, |count| {
                (count < MAX_REQUESTS).then_some(count + 1)
            })
            .map(|_| Self)
            .map_err(|_| {
                Failure::new(
                    "request_capacity",
                    "Occurrence request capacity is still in use",
                )
            })
    }
}

impl Drop for CapacityReservation {
    fn drop(&mut self) {
        let previous = LIVE_REQUESTS.fetch_sub(1, Ordering::AcqRel);
        debug_assert!(previous > 0);
    }
}

struct Request {
    query: String,
    facets: Vec<String>,
    control: ExactOccurrenceControl,
    cancellation: ExactOccurrenceCancellation,
    deadline: Instant,
    executed: AtomicBool,
    #[cfg(test)]
    waiting_for_engine: AtomicBool,
    // Scheduling only: cannot replace an engine, query, counter, or proof.
    #[cfg(test)]
    after_serialization: Mutex<Option<Box<dyn FnOnce() + Send>>>,
    // Last field: owned input storage is dropped before its slot becomes free.
    _capacity: CapacityReservation,
}

impl Request {
    fn check(&self) -> Result<(), Failure> {
        if self.cancellation.is_cancelled() {
            return Err(Failure::new(
                "cancelled",
                "Occurrence request was cancelled",
            ));
        }
        if Instant::now() >= self.deadline {
            return Err(Failure::new(
                "deadline_exceeded",
                "Occurrence request deadline elapsed",
            ));
        }
        Ok(())
    }
}

struct Registry {
    next_id: u64,
    requests: HashMap<u64, Arc<Request>>,
}

impl Default for Registry {
    fn default() -> Self {
        Self {
            next_id: 1,
            requests: HashMap::new(),
        }
    }
}

impl Registry {
    fn insert(&mut self, request: Arc<Request>) -> Result<u64, Failure> {
        if self.requests.len() >= MAX_REQUESTS {
            return Err(Failure::new(
                "request_capacity",
                "Release an existing occurrence request",
            ));
        }
        let id = self.next_id;
        let next = id.checked_add(1).ok_or_else(|| {
            Failure::new("request_id_exhausted", "Occurrence request IDs exhausted")
        })?;
        // Zero is reserved, and exhausted IDs never wrap or re-enter the registry.
        if id == 0 {
            return Err(Failure::new(
                "request_id_exhausted",
                "Occurrence request IDs exhausted",
            ));
        }
        self.next_id = next;
        self.requests.insert(id, request);
        Ok(id)
    }
}

static REQUESTS: OnceLock<Mutex<Registry>> = OnceLock::new();

fn registry() -> &'static Mutex<Registry> {
    REQUESTS.get_or_init(|| Mutex::new(Registry::default()))
}

fn find_request(id: u64) -> Result<Arc<Request>, Failure> {
    let registry = registry()
        .lock()
        .map_err(|_| Failure::new("internal_error", "Occurrence registry is poisoned"))?;
    registry.requests.get(&id).cloned().ok_or_else(|| {
        Failure::new(
            "unknown_request",
            "Occurrence request is absent or released",
        )
    })
}

fn prepare_request(bytes: &[u8], started: Instant) -> Result<Arc<Request>, Failure> {
    let capacity = CapacityReservation::reserve()?;
    let input: Input = serde_json::from_slice(bytes).map_err(|error| {
        Failure::new(
            "invalid_request",
            format!("Invalid occurrence JSON: {error}"),
        )
    })?;
    if input.version != 1 || input.mode != "exact" {
        return Err(Failure::new(
            "unsupported_query",
            "Only version 1 exact single-analyzed-token occurrence queries are supported",
        ));
    }
    if input.query.chars().take(1001).count() > 1000 {
        return Err(Failure::new(
            "invalid_request",
            "Occurrence query exceeds 1000 characters",
        ));
    }
    if input.facets.len() > 200
        || input.book_ids.len() > 200
        || input
            .facets
            .iter()
            .any(|facet| facet.is_empty() || facet.chars().take(513).count() > 512)
    {
        return Err(Failure::new(
            "invalid_request",
            "Occurrence facet filters exceed the supported bound",
        ));
    }
    let facets = resolve_facets(input.facets, &input.book_ids);
    if facets.len() > 200 {
        return Err(Failure::new(
            "invalid_request",
            "Resolved occurrence facets exceed 200",
        ));
    }
    if input.timeout_ms > MAX_TIMEOUT_MS {
        return Err(Failure::new(
            "invalid_limits",
            "Occurrence timeout exceeds 60000 milliseconds",
        ));
    }
    let deadline = started
        .checked_add(Duration::from_millis(input.timeout_ms))
        .ok_or_else(|| Failure::new("invalid_limits", "Occurrence deadline overflow"))?;
    let cancellation = ExactOccurrenceCancellation::default();
    let limits = ExactOccurrenceLimits {
        max_candidate_documents: input.limits.max_candidate_documents,
        max_positions: input.limits.max_positions,
        max_positions_per_document: input.limits.max_positions_per_document,
        max_segments: input.limits.max_segments,
    };
    let control = ExactOccurrenceControl::new(limits, deadline, cancellation.clone())?;
    Ok(Arc::new(Request {
        query: input.query,
        facets,
        control,
        cancellation,
        deadline,
        executed: AtomicBool::new(false),
        #[cfg(test)]
        waiting_for_engine: AtomicBool::new(false),
        #[cfg(test)]
        after_serialization: Mutex::new(None),
        _capacity: capacity,
    }))
}

fn failure_reply(error: Failure) -> *mut c_char {
    let body = json!({ "ok": false, "value": null, "error": error });
    let encoded = serde_json::to_vec(&body).unwrap_or_else(|_| {
        br#"{"ok":false,"value":null,"error":{"code":"internal_error","message":"Error serialization failed"}}"#.to_vec()
    });
    CString::new(encoded).unwrap_or_else(|_| {
        CString::new(
            r#"{"ok":false,"value":null,"error":{"code":"internal_error","message":"Invalid error encoding"}}"#
        ).expect("static JSON has no NUL")
    }).into_raw()
}

fn caught_panic(payload: Box<dyn std::any::Any + Send>) -> Failure {
    Failure::new(
        "internal_error",
        panic_text(payload).chars().take(512).collect::<String>(),
    )
}

/// The caller supplies a valid readable buffer of exactly request_length bytes
/// for this synchronous call, and a valid writable out_error_json or null.
/// No NUL terminator is required. Returned errors use the existing free_string.
#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
pub extern "C" fn otzaria_search_engine_occurrence_request_new(
    request_json: *const u8,
    request_length: usize,
    out_error_json: *mut *mut c_char,
) -> u64 {
    let started = Instant::now();
    let result = catch_unwind(AssertUnwindSafe(|| {
        if !out_error_json.is_null() {
            unsafe { *out_error_json = ptr::null_mut() };
        }
        // Reject oversized lengths before touching the caller's input pointer.
        if request_length > MAX_REQUEST_BYTES {
            return Err(Failure::new(
                "request_too_large",
                "Occurrence JSON exceeds 512 KiB",
            ));
        }
        if request_json.is_null() {
            return Err(Failure::new(
                "invalid_request",
                "Occurrence JSON pointer is null",
            ));
        }
        let bytes = unsafe { std::slice::from_raw_parts(request_json, request_length) };
        let request = prepare_request(bytes, started)?;
        // Only bounded registry metadata is locked. Parsing, engine work,
        // engine-lock waits, serialization and test scheduling occur outside it.
        registry()
            .lock()
            .map_err(|_| Failure::new("internal_error", "Occurrence registry is poisoned"))?
            .insert(request)
    }));
    match result {
        Ok(Ok(id)) => id,
        other => {
            let error = match other {
                Ok(Err(error)) => error,
                Err(payload) => caught_panic(payload),
                Ok(Ok(_)) => unreachable!(),
            };
            if !out_error_json.is_null() {
                unsafe { *out_error_json = failure_reply(error) };
            }
            0
        }
    }
}

/// Cancellation and release never acquire the engine mutex.
#[no_mangle]
pub extern "C" fn otzaria_search_engine_occurrence_request_cancel(id: u64) -> bool {
    catch_unwind(AssertUnwindSafe(|| {
        if let Ok(request) = find_request(id) {
            request.cancellation.cancel();
            true
        } else {
            false
        }
    }))
    .unwrap_or(false)
}

/// Removing a token also cancels an Arc already retained by an executing call.
/// Invalid/double release is harmless. Token IDs are never reused.
#[no_mangle]
pub extern "C" fn otzaria_search_engine_occurrence_request_release(id: u64) -> bool {
    catch_unwind(AssertUnwindSafe(|| {
        let request = match registry().lock() {
            Ok(mut registry) => registry.requests.remove(&id),
            Err(_) => return false,
        };
        if let Some(request) = request {
            request.cancellation.cancel();
            true
        } else {
            false
        }
    }))
    .unwrap_or(false)
}

fn encode_success(id: u64, count: ExactTokenOccurrenceCount) -> Result<CString, Failure> {
    let generation = &count.proof.searcher_generation;
    let segments: Vec<Value> = generation.segments().iter().map(|(segment, deleted)| {
        json!({ "segmentId": segment.uuid_string(), "deleteOpstamp": deleted })
    }).collect();
    let response = json!({
        "ok": true,
        "value": {
            "occurrences": count.occurrences,
            "matchingLiveDocuments": count.matching_live_documents,
            "proof": {
                "requestToken": id,
                "countKind": "distinctTokenPositions",
                "exact": true,
                "analyzedToken": count.proof.analyzed_token,
                "requestedFacets": count.proof.requested_facets,
                "searcherGeneration": {
                    "generationId": generation.generation_id(),
                    "segments": segments
                },
                "liveIndexDocuments": count.proof.live_index_documents,
                "indexSchemaVersion": count.proof.index_schema_version,
                "enginePackageVersion": count.proof.engine_package_version,
                "engineCommit": env!("OTZARIA_UPSTREAM_COMMIT"),
                "originalUpstreamBase": env!("OTZARIA_ORIGINAL_UPSTREAM_BASE"),
                "engineRepository": env!("OTZARIA_ENGINE_REPOSITORY"),
                "engineBranch": env!("OTZARIA_ENGINE_BRANCH")
            },
            "work": {
                "visitedCandidateDocuments": count.work.visited_candidate_documents,
                "inspectedPositions": count.work.inspected_positions,
                "visitedSegments": count.work.visited_segments
            }
        },
        "error": null
    });
    let encoded = serde_json::to_vec(&response)
        .map_err(|error| Failure::new("internal_error", error.to_string()))?;
    if encoded.len() > MAX_RESPONSE_BYTES {
        return Err(Failure::new(
            "response_too_large",
            "Occurrence proof exceeds 1 MiB",
        ));
    }
    CString::new(encoded)
        .map_err(|_| Failure::new("internal_error", "Invalid occurrence JSON encoding"))
}

fn execute(handle: *mut EngineHandle, id: u64) -> Result<CString, Failure> {
    let request = find_request(id)?;
    if request
        .executed
        .compare_exchange(false, true, Ordering::AcqRel, Ordering::Acquire)
        .is_err()
    {
        return Err(Failure::new(
            "request_already_executed",
            "Occurrence requests execute only once",
        ));
    }
    request.check()?;
    if handle.is_null() {
        return Err(Failure::new("invalid_engine", "Engine handle is null"));
    }
    // This preserves the existing engine ABI ownership rule: the caller keeps
    // a genuine handle alive and does not call engine_free until execution joins.
    let handle = unsafe { &*handle };
    let count = loop {
        request.check()?;
        match handle.engine.try_lock() {
            Ok(engine) => {
                request.check()?;
                let count = engine.count_exact_token_occurrences(
                    &request.query,
                    &request.facets,
                    &request.control,
                )?;
                request.check()?;
                break count;
            }
            Err(TryLockError::Poisoned(_)) => {
                return Err(Failure::new(
                    "engine_unavailable",
                    "Engine mutex is poisoned",
                ));
            }
            Err(TryLockError::WouldBlock) => {
                #[cfg(test)]
                request.waiting_for_engine.store(true, Ordering::Release);
                request.check()?;
                let remaining = request.deadline.saturating_duration_since(Instant::now());
                std::thread::sleep(Duration::from_millis(1).min(remaining));
            }
        }
    };
    // The exact count/proof owns its snapshot metadata; the engine lock has
    // been released before serialization. Cancellation still guards publication.
    let encoded = encode_success(id, count)?;
    #[cfg(test)]
    {
        let hook = request
            .after_serialization
            .lock()
            .map_err(|_| Failure::new("internal_error", "Test scheduling hook poisoned"))?
            .take();
        if let Some(hook) = hook {
            hook();
        }
    }
    request.check()?;
    Ok(encoded)
}

/// Synchronous, potentially blocking work: callers must use a worker thread.
/// The request timeout begins at request_new, including time before this call.
/// A successful response linearizes at the final cancellation/deadline check;
/// cancellation after this point cannot retroactively revoke returned memory.
#[no_mangle]
pub extern "C" fn otzaria_search_engine_count_occurrences_json(
    handle: *mut EngineHandle,
    request: u64,
) -> *mut c_char {
    match catch_unwind(AssertUnwindSafe(|| execute(handle, request))) {
        Ok(Ok(reply)) => reply.into_raw(),
        Ok(Err(error)) => failure_reply(error),
        Err(payload) => failure_reply(caught_panic(payload)),
    }
}

#[cfg(test)]
mod tests;
