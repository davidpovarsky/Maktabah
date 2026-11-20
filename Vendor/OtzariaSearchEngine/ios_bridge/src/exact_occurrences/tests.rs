use super::*;
use crate::*;
use std::ffi::{CStr, CString};
use std::sync::{mpsc, MutexGuard};
use std::thread;
use tempfile::TempDir;

// These cases exercise the process-global C token registry exclusively.
// Existing legacy bridge tests do not use that new registry.
static SERIAL: Mutex<()> = Mutex::new(());

fn serial() -> MutexGuard<'static, ()> {
    SERIAL
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner())
}

fn decode(raw: *mut c_char) -> Value {
    assert!(!raw.is_null());
    let bytes = unsafe { CStr::from_ptr(raw) }.to_bytes().to_owned();
    otzaria_search_engine_free_string(raw);
    serde_json::from_slice(&bytes).unwrap()
}

fn error_code(value: &Value, expected: &str) {
    assert_eq!(value["ok"], false, "{value}");
    assert!(value["value"].is_null(), "{value}");
    assert_eq!(value["error"]["code"], expected, "{value}");
    assert!(value.get("occurrences").is_none(), "{value}");
}

struct Fixture {
    handle: *mut EngineHandle,
    _directory: TempDir,
}

impl Fixture {
    fn new() -> Self {
        let directory = tempfile::Builder::new()
            .prefix("otzaria-occurrence-ffi-")
            .tempdir()
            .unwrap();
        let path = CString::new(directory.path().to_str().unwrap()).unwrap();
        let handle = otzaria_search_engine_new(path.as_ptr());
        assert!(!handle.is_null());
        Self {
            handle,
            _directory: directory,
        }
    }

    fn add(&self, id: u64, text: &str, extra_facets: &[&str]) {
        let book = CString::new(
            json!({
                "title": format!("occurrence fixture {id}"),
                "topics": "/fixtures",
                "filePath": format!("otzaria-book:{id}"),
                "catalogueOrder": id,
                "text": text,
                "extraFacets": extra_facets
            })
            .to_string(),
        )
        .unwrap();
        let added = decode(otzaria_search_engine_add_text_book_json(
            self.handle,
            book.as_ptr(),
        ));
        assert_eq!(added["ok"], true, "{added}");
    }

    fn commit(&self) {
        let committed = decode(otzaria_search_engine_commit(self.handle));
        assert_eq!(committed["ok"], true, "{committed}");
    }

    fn with_two_occurrences() -> Self {
        let fixture = Self::new();
        fixture.add(1, "משה משה", &["/book/1", "/author/a"]);
        fixture.commit();
        fixture
    }

    fn count(&self, request: &Token) -> Value {
        decode(otzaria_search_engine_count_occurrences_json(
            self.handle,
            request.0,
        ))
    }

    fn lock(&self) -> MutexGuard<'_, search_engine::api::search_engine::SearchEngine> {
        unsafe { &*self.handle }.engine.lock().unwrap()
    }
}

impl Drop for Fixture {
    fn drop(&mut self) {
        otzaria_search_engine_free(self.handle);
    }
}

struct Token(u64);
impl Token {
    fn new(input: Value) -> Self {
        let bytes = serde_json::to_vec(&input).unwrap();
        let mut error = ptr::null_mut();
        let id =
            otzaria_search_engine_occurrence_request_new(bytes.as_ptr(), bytes.len(), &mut error);
        if id == 0 {
            panic!("request creation failed: {}", decode(error));
        }
        assert!(error.is_null());
        Self(id)
    }
}

impl Drop for Token {
    fn drop(&mut self) {
        otzaria_search_engine_occurrence_request_release(self.0);
    }
}

fn input() -> Value {
    json!({ "version": 1, "mode": "exact", "query": "משה", "timeoutMs": 5000 })
}

fn rejected(input: Value, code: &str) {
    let bytes = serde_json::to_vec(&input).unwrap();
    rejected_bytes(bytes.as_ptr(), bytes.len(), code);
}

fn rejected_bytes(pointer: *const u8, length: usize, code: &str) {
    let mut error = ptr::null_mut();
    assert_eq!(
        otzaria_search_engine_occurrence_request_new(pointer, length, &mut error),
        0,
    );
    assert!(!error.is_null());
    error_code(&decode(error), code);
}

// The borrow and Drop join keep the C engine owner alive even when a timing
// assertion fails. Release only this fixture's held lock before joining.
struct CountWorker<'a> {
    _owner: &'a Fixture,
    held: Option<MutexGuard<'a, search_engine::api::search_engine::SearchEngine>>,
    worker: Option<thread::JoinHandle<()>>,
    response: mpsc::Receiver<Value>,
}

impl CountWorker<'_> {
    fn finish(mut self) {
        drop(self.held.take());
        self.worker.take().unwrap().join().unwrap();
    }
}

impl Drop for CountWorker<'_> {
    fn drop(&mut self) {
        drop(self.held.take());
        if let Some(worker) = self.worker.take() {
            let _ = worker.join();
        }
    }
}

fn spawn_count(fixture: &Fixture, token: u64, hold_engine_lock: bool) -> CountWorker<'_> {
    let held = if hold_engine_lock {
        Some(fixture.lock())
    } else {
        None
    };
    let handle = fixture.handle as usize;
    let (sender, response) = mpsc::channel();
    let worker = thread::spawn(move || {
        sender
            .send(decode(otzaria_search_engine_count_occurrences_json(
                handle as *mut EngineHandle,
                token,
            )))
            .unwrap();
    });
    CountWorker {
        _owner: fixture,
        held,
        worker: Some(worker),
        response,
    }
}

fn await_actual_mutex_wait(request: &Arc<Request>) {
    let deadline = Instant::now() + Duration::from_secs(2);
    while !request.waiting_for_engine.load(Ordering::Acquire) {
        assert!(
            Instant::now() < deadline,
            "request never attempted the actually held mutex"
        );
        thread::sleep(Duration::from_millis(1));
    }
}

#[test]
fn ffi_counts_two_positions_separately_from_one_matching_document() {
    let _serial = serial();
    let fixture = Fixture::with_two_occurrences();
    let request = Token::new(input());
    let value = fixture.count(&request);
    assert_eq!(value["ok"], true, "{value}");
    assert_eq!(value["value"]["occurrences"], 2);
    assert_eq!(value["value"]["matchingLiveDocuments"], 1);
    assert_eq!(
        value["value"]["proof"]["countKind"],
        "distinctTokenPositions"
    );
    assert_eq!(value["value"]["proof"]["exact"], true);
    assert_eq!(value["value"]["proof"]["requestToken"], request.0);
    assert_eq!(value["value"]["proof"]["analyzedToken"], "משה");
    assert_eq!(
        value["value"]["proof"]["engineCommit"],
        env!("OTZARIA_UPSTREAM_COMMIT")
    );
    assert_eq!(
        value["value"]["proof"]["engineRepository"],
        env!("OTZARIA_ENGINE_REPOSITORY")
    );
    assert_eq!(
        value["value"]["proof"]["engineBranch"],
        env!("OTZARIA_ENGINE_BRANCH")
    );
    assert_eq!(value["value"]["proof"]["indexSchemaVersion"], 4);
    assert!(
        value["value"]["proof"]["searcherGeneration"]["segments"]
            .as_array()
            .unwrap()
            .len()
            > 0
    );
    let query = CString::new(
        json!({
            "query": "משה", "mode": "exact", "facets": ["/"], "limit": 100
        })
        .to_string(),
    )
    .unwrap();
    let old = decode(otzaria_search_engine_search_json(
        fixture.handle,
        query.as_ptr(),
    ));
    assert_eq!(old["ok"], true, "{old}");
    assert_eq!(old["value"]["totalCount"], 1);
    let build = decode(otzaria_search_engine_build_info());
    assert_eq!(
        build["value"]["upstreamCommit"],
        value["value"]["proof"]["engineCommit"]
    );
    assert_eq!(
        build["value"]["upstreamRepository"],
        value["value"]["proof"]["engineRepository"]
    );
}

#[test]
fn ffi_keeps_original_book_and_facet_scope_dimensions() {
    let _serial = serial();
    let fixture = Fixture::new();
    fixture.add(1, "משה משה", &["/book/1", "/author/a"]);
    fixture.add(2, "משה", &["/book/2", "/author/b"]);
    fixture.add(3, "משה משה משה", &["/book/3", "/author/a"]);
    fixture.commit();
    let mut request = input();
    request["bookIds"] = json!([1, 2]);
    assert_eq!(
        fixture.count(&Token::new(request.clone()))["value"]["occurrences"],
        3
    );
    request["facets"] = json!(["/author/a"]);
    let scoped = fixture.count(&Token::new(request));
    assert_eq!(scoped["value"]["occurrences"], 2);
    assert_eq!(scoped["value"]["matchingLiveDocuments"], 1);
    assert_eq!(
        scoped["value"]["proof"]["requestedFacets"],
        json!(["/author/a", "/book/1", "/book/2"])
    );
}

#[test]
fn ffi_excludes_actual_deleted_postings_and_returns_delete_snapshot() {
    let _serial = serial();
    let fixture = Fixture::new();
    fixture.add(1, "משה משה משה", &["/book/1"]);
    fixture.add(2, "משה", &["/book/2"]);
    fixture.commit();
    assert_eq!(
        decode(otzaria_search_engine_optimize(fixture.handle))["ok"],
        true
    );
    let before = fixture.count(&Token::new(input()));
    assert_eq!(before["value"]["occurrences"], 4);
    let files = CString::new(json!(["otzaria-book:1"]).to_string()).unwrap();
    assert_eq!(
        decode(otzaria_search_engine_delete_file_paths_json(
            fixture.handle,
            files.as_ptr(),
        ))["ok"],
        true
    );
    fixture.commit();
    let after = fixture.count(&Token::new(input()));
    assert_eq!(after["value"]["occurrences"], 1);
    assert_eq!(after["value"]["matchingLiveDocuments"], 1);
    assert_eq!(after["value"]["proof"]["liveIndexDocuments"], 1);
    assert!(after["value"]["proof"]["searcherGeneration"]["segments"]
        .as_array()
        .unwrap()
        .iter()
        .any(|s| !s["deleteOpstamp"].is_null()));
    assert_ne!(
        before["value"]["proof"]["searcherGeneration"],
        after["value"]["proof"]["searcherGeneration"]
    );
}

#[test]
fn ffi_uses_original_hebrew_analyzer_and_exact_zero() {
    let _serial = serial();
    let fixture = Fixture::new();
    fixture.add(1, "מֹשֶׁה משה משהל", &[]);
    fixture.commit();
    assert_eq!(
        fixture.count(&Token::new(input()))["value"]["occurrences"],
        2
    );
    let mut zero = input();
    zero["query"] = json!("זרובבל");
    let value = fixture.count(&Token::new(zero));
    assert_eq!(value["ok"], true);
    assert_eq!(value["value"]["occurrences"], 0);
    assert_eq!(value["value"]["matchingLiveDocuments"], 0);
}

#[test]
fn ffi_rejects_unsupported_modes_options_and_multiple_analyzed_tokens() {
    let _serial = serial();
    for mode in ["fuzzy", "advanced", "regex", "phrase", "semantic", ""] {
        let mut request = input();
        request["mode"] = json!(mode);
        rejected(request, "unsupported_query");
    }
    for key in [
        "offset",
        "limit",
        "matchNikud",
        "scope",
        "negativeQuery",
        "grouping",
    ] {
        let mut request = input();
        request[key] = json!(0);
        rejected(request, "invalid_request");
    }
    let mut version = input();
    version["version"] = json!(2);
    rejected(version, "unsupported_query");
    let fixture = Fixture::with_two_occurrences();
    for query in ["משה משה", ""] {
        let mut request = input();
        request["query"] = json!(query);
        error_code(&fixture.count(&Token::new(request)), "unsupported_query");
    }
}

#[test]
fn ffi_validates_json_utf8_length_and_input_bounds_before_index_work() {
    let _serial = serial();
    rejected_bytes(ptr::null(), 0, "invalid_request");
    // Oversized length is rejected before any input pointer access.
    rejected_bytes(ptr::null(), MAX_REQUEST_BYTES + 1, "request_too_large");
    rejected_bytes(b"{".as_ptr(), 1, "invalid_request");
    rejected_bytes([0xffu8].as_ptr(), 1, "invalid_request");
    rejected_bytes(b"{}\0".as_ptr(), 3, "invalid_request");
    let mut long = input();
    long["query"] = json!("מ".repeat(1001));
    rejected(long, "invalid_request");
    let mut facets = input();
    facets["facets"] = json!(vec!["/book/1"; 201]);
    rejected(facets, "invalid_request");
    let mut facets = input();
    facets["facets"] = json!([""]);
    rejected(facets, "invalid_request");
    let mut facets = input();
    facets["facets"] = json!([format!("/{}", "a".repeat(512))]);
    rejected(facets, "invalid_request");
    let mut books = input();
    books["bookIds"] = json!(vec![1; 201]);
    rejected(books, "invalid_request");
    let mut combined = input();
    combined["facets"] = json!((0..200).map(|i| format!("/author/{i}")).collect::<Vec<_>>());
    combined["bookIds"] = json!([1]);
    rejected(combined, "invalid_request");
}

#[test]
fn ffi_preserves_all_budget_failures_without_partial_numeric_value() {
    let _serial = serial();
    let fixture = Fixture::with_two_occurrences();
    for (field, value) in [
        ("maxCandidateDocuments", 0),
        ("maxPositions", 1),
        ("maxPositionsPerDocument", 1),
        ("maxSegments", 0),
    ] {
        let mut request = input();
        request["limits"] = json!({field: value});
        error_code(&fixture.count(&Token::new(request)), "budget_exceeded");
    }
}

#[test]
fn ffi_rejects_overflowing_or_excessive_control_limits() {
    let _serial = serial();
    let mut timeout = input();
    timeout["timeoutMs"] = json!(60_001);
    rejected(timeout, "invalid_limits");
    for field in ["maxCandidateDocuments", "maxPositions", "maxSegments"] {
        let mut request = input();
        request["limits"] = json!({field: u64::MAX});
        rejected(request, "invalid_limits");
    }
    let mut invalid = input();
    invalid["limits"] = json!({"maxPositionsPerDocument": u32::MAX});
    rejected(invalid, "invalid_limits");
    let mut unknown = input();
    unknown["limits"] = json!({"unbounded": true});
    rejected(unknown, "invalid_request");
}

#[test]
fn ffi_request_tokens_are_one_use_and_release_is_idempotently_safe() {
    let _serial = serial();
    let fixture = Fixture::with_two_occurrences();
    let request = Token::new(input());
    assert_eq!(fixture.count(&request)["ok"], true);
    error_code(&fixture.count(&request), "request_already_executed");
    assert!(otzaria_search_engine_occurrence_request_release(request.0));
    assert!(!otzaria_search_engine_occurrence_request_release(request.0));
    assert!(!otzaria_search_engine_occurrence_request_cancel(request.0));
    error_code(&fixture.count(&request), "unknown_request");
    let next = Token::new(input());
    assert!(next.0 > request.0);
    assert!(!otzaria_search_engine_occurrence_request_cancel(u64::MAX));
    assert!(!otzaria_search_engine_occurrence_request_release(0));
}

#[test]
fn ffi_registry_capacity_is_strict_and_released_capacity_recovers() {
    let _serial = serial();
    let mut requests = Vec::new();
    for _ in 0..MAX_REQUESTS {
        requests.push(Token::new(input()));
    }
    rejected(input(), "request_capacity");
    let highest = requests.last().unwrap().0;
    let released = requests.pop().unwrap();
    assert!(otzaria_search_engine_occurrence_request_release(released.0));
    let next = Token::new(input());
    assert!(next.0 > highest);
    rejected(input(), "request_capacity");
}

#[test]
fn token_allocator_never_wraps_or_reuses_exhausted_ids() {
    let _serial = serial();
    let bytes = serde_json::to_vec(&input()).unwrap();
    let request = prepare_request(&bytes, Instant::now()).unwrap();
    let mut registry = Registry {
        next_id: u64::MAX,
        requests: HashMap::new(),
    };
    assert_eq!(
        registry.insert(request).unwrap_err().code,
        "request_id_exhausted"
    );
    assert_eq!(registry.next_id, u64::MAX);
    assert!(registry.requests.is_empty());
}

#[test]
fn ffi_cancel_finishes_while_actual_engine_mutex_remains_held() {
    let _serial = serial();
    let fixture = Fixture::with_two_occurrences();
    let request = Token::new(input());
    let state = find_request(request.0).unwrap();
    let call = spawn_count(&fixture, request.0, true);
    await_actual_mutex_wait(&state);
    assert!(otzaria_search_engine_occurrence_request_cancel(request.0));
    let result = call
        .response
        .recv_timeout(Duration::from_secs(2))
        .expect("cancel blocked on engine mutex");
    error_code(&result, "cancelled");
    call.finish();
}

#[test]
fn ffi_deadline_finishes_while_actual_engine_mutex_remains_held() {
    let _serial = serial();
    let fixture = Fixture::with_two_occurrences();
    let mut payload = input();
    payload["timeoutMs"] = json!(500);
    let request = Token::new(payload);
    let state = find_request(request.0).unwrap();
    let call = spawn_count(&fixture, request.0, true);
    await_actual_mutex_wait(&state);
    let result = call
        .response
        .recv_timeout(Duration::from_secs(2))
        .expect("deadline blocked on engine mutex");
    error_code(&result, "deadline_exceeded");
    call.finish();
}

#[test]
fn ffi_release_cancels_retained_inflight_arc_without_dereferencing_freed_memory() {
    let _serial = serial();
    let fixture = Fixture::with_two_occurrences();
    let request = Token::new(input());
    let state = find_request(request.0).unwrap();
    let call = spawn_count(&fixture, request.0, true);
    await_actual_mutex_wait(&state);
    assert!(otzaria_search_engine_occurrence_request_release(request.0));
    assert!(state.cancellation.is_cancelled());
    let result = call
        .response
        .recv_timeout(Duration::from_secs(2))
        .expect("release did not cancel retained request");
    error_code(&result, "cancelled");
    call.finish();
    error_code(&fixture.count(&request), "unknown_request");
}

#[test]
fn ffi_concurrent_duplicate_execute_cannot_start_a_second_count() {
    let _serial = serial();
    let fixture = Fixture::with_two_occurrences();
    let request = Token::new(input());
    let state = find_request(request.0).unwrap();
    let call = spawn_count(&fixture, request.0, true);
    await_actual_mutex_wait(&state);
    error_code(&fixture.count(&request), "request_already_executed");
    assert!(otzaria_search_engine_occurrence_request_cancel(request.0));
    error_code(
        &call.response.recv_timeout(Duration::from_secs(2)).unwrap(),
        "cancelled",
    );
    call.finish();
}

#[test]
fn ffi_post_count_cancellation_discards_already_serialized_success() {
    let _serial = serial();
    let fixture = Fixture::with_two_occurrences();
    let request = Token::new(input());
    let state = find_request(request.0).unwrap();
    let token = request.0;
    let reached = Arc::new(AtomicBool::new(false));
    let observed = reached.clone();
    *state.after_serialization.lock().unwrap() = Some(Box::new(move || {
        observed.store(true, Ordering::Release);
        assert!(otzaria_search_engine_occurrence_request_cancel(token));
    }));
    error_code(&fixture.count(&request), "cancelled");
    assert!(
        reached.load(Ordering::Acquire),
        "the original count did not complete"
    );
}

#[test]
fn ffi_post_count_deadline_discards_already_serialized_success() {
    let _serial = serial();
    let fixture = Fixture::with_two_occurrences();
    let mut payload = input();
    payload["timeoutMs"] = json!(500);
    let request = Token::new(payload);
    let state = find_request(request.0).unwrap();
    let deadline = state.deadline;
    let reached = Arc::new(AtomicBool::new(false));
    let observed = reached.clone();
    *state.after_serialization.lock().unwrap() = Some(Box::new(move || {
        observed.store(true, Ordering::Release);
        thread::sleep(
            deadline.saturating_duration_since(Instant::now()) + Duration::from_millis(2),
        );
    }));
    error_code(&fixture.count(&request), "deadline_exceeded");
    assert!(
        reached.load(Ordering::Acquire),
        "the original count did not complete"
    );
}

#[test]
fn ffi_release_after_serialization_cancels_the_still_owned_call() {
    let _serial = serial();
    let fixture = Fixture::with_two_occurrences();
    let request = Token::new(input());
    let state = find_request(request.0).unwrap();
    let token = request.0;
    *state.after_serialization.lock().unwrap() = Some(Box::new(move || {
        assert!(otzaria_search_engine_occurrence_request_release(token));
    }));
    error_code(&fixture.count(&request), "cancelled");
    assert!(find_request(token).is_err());
}

#[test]
fn ffi_request_deadline_includes_time_before_execute() {
    let _serial = serial();
    let fixture = Fixture::with_two_occurrences();
    let mut payload = input();
    payload["timeoutMs"] = json!(0);
    let request = Token::new(payload);
    error_code(&fixture.count(&request), "deadline_exceeded");
}

#[test]
fn ffi_null_and_poisoned_engine_fail_without_scalar() {
    let _serial = serial();
    let request = Token::new(input());
    error_code(
        &decode(otzaria_search_engine_count_occurrences_json(
            ptr::null_mut(),
            request.0,
        )),
        "invalid_engine",
    );
    let fixture = Fixture::with_two_occurrences();
    let _ = catch_unwind(AssertUnwindSafe(|| {
        let _held = fixture.lock();
        panic!("owned fixture poison");
    }));
    error_code(&fixture.count(&Token::new(input())), "engine_unavailable");
}

#[test]
fn ffi_panics_stay_inside_the_new_boundary_without_numeric_success() {
    let _serial = serial();
    let fixture = Fixture::with_two_occurrences();
    let request = Token::new(input());
    let state = find_request(request.0).unwrap();
    *state.after_serialization.lock().unwrap() =
        Some(Box::new(|| panic!("owned after-count scheduling panic")));
    error_code(&fixture.count(&request), "internal_error");
}

#[test]
fn ffi_released_inflight_request_keeps_capacity_until_final_arc_drop() {
    let _serial = serial();
    let fixture = Fixture::with_two_occurrences();
    let request = Token::new(input());
    let others: Vec<_> = (1..MAX_REQUESTS).map(|_| Token::new(input())).collect();
    let (entered, entered_rx) = mpsc::channel();
    let (resume, resume_rx) = mpsc::channel();
    let state = find_request(request.0).unwrap();
    *state.after_serialization.lock().unwrap() = Some(Box::new(move || {
        entered.send(()).unwrap();
        resume_rx.recv_timeout(Duration::from_secs(2)).unwrap();
    }));
    drop(state);
    let call = spawn_count(&fixture, request.0, false);
    entered_rx.recv_timeout(Duration::from_secs(2)).unwrap();
    assert!(otzaria_search_engine_occurrence_request_release(request.0));
    rejected(input(), "request_capacity");
    resume.send(()).unwrap();
    error_code(
        &call.response.recv_timeout(Duration::from_secs(2)).unwrap(),
        "cancelled",
    );
    call.finish();
    let next = Token::new(input());
    assert!(next.0 > request.0);
    assert_eq!(others.len() + 1, MAX_REQUESTS);
}
