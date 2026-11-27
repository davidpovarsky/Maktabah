# Active host log gate for cold R08 after Books Updates

This is a host observer for the already registered selector:

```
Maktabah-iOSUITests/PublishedProductionSearchAfterBooksUpdateTests/testOriginalBooksUpdateRetainsV40PackagesButRejectsTheirReadinessAndQueries
```

It does not launch the app, install a corpus/index, provide results, write the app's trace, change a backend or alter the network. It must be started before the original XCTest and stopped only after the actual native case and its attachment have finished. The existing UI case remains responsible for visible original Search Data statuses, both original attempted queries, exact visible mismatch errors, retained files and unchanged positive trace prefix. The observer adds the actual fresh app process and accepted-submit evidence; absence of appended provider events alone is never sufficient.

## Controller API

Import `Scripts/CI/study-ui-search-log.py` with `importlib.util` or `runpy`.

```python
capture = SearchLogCapture(
    udid=actual_owned_simulator_udid,
    namespace=qualified_settings_receipt["traceBaseline"]["namespace"],
    output_dir=output / "r08-active-log",  # fresh under this checkout/build/artifacts
    image_path_resolver=resolve_current_actual_macho,
)
try:
    capture.start()
    # Execute the one original case, then verify its actual Passed result,
    # exact one test, zero skips, same UDID/source/build, and export manifest.
    # Select this exact case's one original attachment by the export manifest:
    # production-search-after-books-update-original-ui-and-trace-boundary
    witness = capture.stop_and_verify(
        actual_exported_attachment_path,
        expected_attachment_sha256=qualified_attachment_sha256,
    )
finally:
    capture.abort()  # idempotent owned cleanup; does not overwrite a final result
```

The zero-argument resolver returns **one canonical absolute Mach-O executable path string**. The root controller resolves the current actual `simctl get_app_container ... app`, reads its real `CFBundleExecutable`, and retains its existing same-build image/source admission. It must handle an actual XCTest app-bundle relocation, without substituting a guessed suffix. It is called repeatedly during sampling and should do bounded read-only work; expensive image hashing can be retained in the controller's existing source/image closure. The observer records each resolved path and binds it to the actual `ps` command and `processImagePath` of both log records.

`start()` checks that this helper and the existing `runtime27_interruption.py` exactly match current committed files. It returns only after attributing the created runtime log child. The controller must start the native UI **after this call returns**. It receives no permission to use another simulator or operate any app lifecycle through this module.

`stop_and_verify()` returns the FileWitness `{path, bytes, sha256}` for its final `RESULT.json` only on success; a failed gate writes its result and raises. The controller still qualifies the actual passing XCTest/exported attachment before calling it. A digest alone does not establish a test's provenance. An original case/export failure calls `abort()` and receives no positive log receipt.

## Actual observation and bounds

The only created command is:

```
xcrun simctl spawn <owned UDID> log stream --style ndjson --level debug --predicate <owned predicate>
```

The predicate selects the original `[GlobalSearch] submit ` and `[GlobalSearchNativeObservation]` messages. A unique exact-message alternative, never emitted by the helper or app, makes the runtime log child's actual command attributable for cleanup. It does not synthesize an event. `--ignore-dropped` is never used.

The original submit message is:

```
[GlobalSearch] submit revision=%d generation=%d backend=%@ scope=%@
```

The gate requires exactly two actual records, in order: revision 1/backend `otzaria`/scope `exact`, then revision 2/backend `otzaria`/scope `zayit`, with advancing positive generations. Each original timestamp must fall between that attempt's `startedAtUnix` immediately before native Return and its `rejectedAtUnix` after the real visible error. `submittedAtUnix` is when `typeText` returned; the original log is legitimately earlier than that return and is not incorrectly constrained to occur after it.

The two log records must have one exact PID and executable path. The PID must differ from the retained v40 trace-prefix PID. Actual repeated `ps -A -ww -o pid=,ppid=,lstart=,command=` observations bind that fresh process's PID, parent, UTC start time, executable and original production launch arguments, including the same trace namespace. A cold process that predates the original launch is rejected. Actual query-interval samples must retain one app identity and command. All samples must retain the created capture and its owned runtime log process with no observation gap over three seconds. The raw log capture remains active past the native final attachment; the app may finish after that native timestamp.

Both observed submit records and the original UI attachment are needed. Missing/extra submissions, wrong backend/scope/revision, wrong namespace/PID/image, source or UI observation write failures, loss/drop records, malformed/unknown NDJSON, duplicate JSON keys, nonfinite times, truncation, premature stdout EOF, process death, stderr diagnostics or failed owned cleanup all fail. An unexpected actual log-stream format/banner is retained and fails instead of being silently discarded. The first real Apple run must qualify the format; these source controls do not claim that run.

Limits are 16 MiB of raw stdout, 128 KiB stderr, 128 KiB per JSON line, a 2,400-second deadline, a two-second `ps` subprocess timeout, and bounded cleanup/join waits. Only matching app/process rows are retained; the complete host `ps` inventory and other owners' arguments are not written to evidence.

## Cleanup ownership

The original `runtime27_interruption.stop_owned_process_group` and `stop_owned_subprocess` run first, only against the `Popen` created by this object. A Simulator runtime child may be outside that process group. Its unique original command, PID, parent and start time are therefore observed before readiness and rechecked immediately before any targeted SIGINT/SIGKILL fallback. An unrelated log stream or changed process identity is never signalled. Final `ps` observation must find no exact owned runtime command and the created group/leader must be gone; otherwise the gate fails. The module does not claim to clean up arbitrary CoreSimulator agents or own the simulator itself.

The evidence-write operation immediately after `Popen` is inside the cleanup scope. A synthetic ENOSPC control verifies that an initial `LAUNCH.json` write failure invokes owned cleanup even when `start()` cannot return its handle.

## Evidence and validation scope

Outputs retain `LAUNCH.json`, `READY.json`, bounded original stdout/stderr, `PROCESS_SAMPLES.json`, `CLEANUP.json`, and `RESULT.json` or an abort receipt. The final result binds the exact native attachment and every lifecycle/raw-log file by size/SHA. It records the actual fresh process, both submit records and observation bounds. Native attachment fields are consumed from the existing shared R08 contract; no competing Settings envelope is introduced.

The accompanying controls are explicitly synthetic Python parser/lifetime/cleanup controls. They exercise silence, missing/extra/foreign submissions, timestamp boundaries, the original `typeText` timing, wrong scope, source errors, existing-prefix changes, process identity changes, dropped/truncated streams, dead captures, fixture overrides and cleanup ownership. No Simulator, native UI, real log stream, process signal or positive production envelope is executed/generated by those controls. This checkpoint adds no app Source change and makes no offline or warm same-process update claim.

Reproduce the focused source controls from the checkout root with:

```
python3 docs/hq-integration/wave2-20261127/search/post-update-log/source-controls.py Scripts/CI/study-ui-search-log.py
```
