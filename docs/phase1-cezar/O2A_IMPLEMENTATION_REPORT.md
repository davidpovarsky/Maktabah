# Phase 1 O2-A Implementation Report

- **Task Order / Unit:** `O2-A` (`c5124cd6-3896-4554-9c83-adf3722f6050`)
- **Logical Role & Execution Mode:** `noam | Engineering` (`MAIN_SESSION`)
- **Worktree Branch:** `cez/c5124cd6`
- **Base Commit SHA:** `1472fdea2aa61f4c4c830822758ea75a8c76e08b`
- **Result Commit SHA:** Recorded on branch `cez/c5124cd6` at commit creation and reported in `cez task report`

---

## 1. Authorized Scope & Changed Paths

Changes are strictly confined to the 7 writable paths authorized by `docs/phase1-cezar/O2A_WORK_PACKET.md`:

1. `Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift` — SpringBoard Open-in dialog detection/confirmation, fail-closed checks, and teardown isolation.
2. `Scripts/CI/runtime27_interruption.py` — Shared interruption controller, owned process-group/subprocess termination, and isolated cleanup helpers.
3. `Scripts/CI/runtime27.py` — `InterruptController` integration, `runtime27_interruption.py` provenance hashing, `runpy.run_path` hoisting in `collect_cases`, matrix `INTERRUPTED_UI_UNVERIFIED` propagation, and `BaseException`-safe `result.json` persistence.
4. `Scripts/CI/run-faithful-ipad-matrix.py` — `main()` entrypoint, `SIGINT`/`SIGTERM` handling across pre-UDID/simulator/XCTest/`largeText`/cleanup phases, device-loop halt on interruption, `INTERRUPTED` overwrite guard against stale `EXECUTED_PASS`, bounded cleanup (`5s` shutdown / `5s` delete, skip `collect-runtime27-palette-log.py`), and preserved normal path.
5. `tools/test_runtime27_interruption.py` — Pre-repair RED reproduction and post-repair GREEN portable regression suite (7 tests).
6. `Source/Otzaria/Compatibility/OtzariaGenericBackendAdapter.swift` — Bounded, `#if DEBUG`-only, content-free stage and error-category diagnostics inside `section(at:)`.
7. `docs/phase1-cezar/O2A_IMPLEMENTATION_REPORT.md` — This implementation and verification report.

No files in `Source/UI/`, `Source/Features/`, `docs/hq-integration/runtime27/R27_CASES.json`, `Maktabah-iOSUITests/R27NativeInteractionAcceptanceTests.swift`, `PROJECT_BOARD.md`, `.github/workflows/`, or Asana were modified.

---

## 2. Sub-Part Summary

### 2.1 System URL Transport & SpringBoard `"Open"` Confirmation (`Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift`)

- **Observed Root Cause:** Prior CI forensics (`43891893650`, `test-simulator-11-reader.log` and `otzaria-reader.log`) established that `runtime27-url-delivery.py` (`simctl openurl`) acknowledged transport (`"delivered": true`), while SpringBoard presented `"Open in \u{201C}ChavrusaText\u{201D}?"` alerts that were never confirmed (`"Open"`). Warm/security tests failed with zero `event=url` lines, and prompts stacked up for later tests.
- **Implementation:**
  - `openInExistingProcess(_:)` retains the existing `.runningForeground` wait (`15s`), `originalPID` capture, `r27-url-<token>-<nonce>.request.json` / `.ack.json` write/wait (`20s`), strict credential-free schema (`{"udid", "transport", "delivered", "nonce", "time"}`), `nonce`/`udid`/`transport`/`delivered` assertions, `"actual-system-url-transport-only"` attachment, foreground re-wait (`15s`), and `actualPID == originalPID` proof.
  - Added pre-delivery guard failing closed if `springboard.alerts.count > 0` before dispatch.
  - Added `dialogOrDirectDelivery` (`XCTWaiter` timeout `10s`) using `MainActor.assumeIsolated` inside `NSPredicate` (instantiating `XCUIApplication` locally so no non-`Sendable` element is captured) waiting for SpringBoard alerts, target `"Unable to open link"` refusal alert, or direct `"History & Favorites"` transition.
  - Added `confirmSpringBoardOpenDialog(springboard:)` requiring `alerts.count == 1`, exact title match against `expectedSpringBoardOpenTitles` (`"Open in \u{201C}ChavrusaText\u{201D}?"` / `"Open in \"ChavrusaText\"?"`), unique hittable `"Open"` button (`openMatches.count == 1`, `exists && isHittable`), tap + `10s` wait for `springboard.alerts` `count == 0`, and attaching `"actual-system-open-confirmation"`.
  - Added `cleanupLeftoverSpringBoardOpenAlertsInTeardown()` invoked from `tearDownWithError()` when any SpringBoard alert remains. It captures `"native-route-teardown-springboard"` hierarchy/screenshot evidence, dismisses up to 8 leftover Chavrusa Open-in alerts with `"Cancel"` (`5s` reduction wait per alert) to avoid cross-test prompt leakage, and unconditionally calls `XCTFail(...)`.

| SpringBoard / Target State | Behavior in `openInExistingProcess(_:)` / Teardown | Failure / Receipt Outcome |
|---|---|---|
| `springboard.alerts.count > 0` before URL dispatch | Captures `"preexisting-springboard-alert"`, calls `XCTFail` | Throws `SystemURLConfirmationError.unexpectedOrAmbiguousDialog` |
| `alerts.count == 1`, title matches `expectedSpringBoardOpenTitles`, unique hittable `"Open"` button | Taps `"Open"`, waits `10s` for dismissal, attaches `"actual-system-open-confirmation"` | Continues to foreground + same-PID + UI/log assertions |
| `alerts.count != 1` during confirmation | Captures `"ambiguous-springboard-alerts"`, calls `XCTFail` | Throws `SystemURLConfirmationError.unexpectedOrAmbiguousDialog` |
| `alerts.count == 1` with non-Chavrusa title | Captures `"unexpected-springboard-alert"`, calls `XCTFail`, never taps | Throws `SystemURLConfirmationError.unexpectedOrAmbiguousDialog` |
| Missing/non-hittable/non-unique `"Open"` button | Captures `"missing-springboard-open-button"`, calls `XCTFail` | Throws `SystemURLConfirmationError.missingOpenAction` |
| Dialog stays open `> 10s` after tapping `"Open"` | Captures `"springboard-open-alert-stuck"`, calls `XCTFail` | Throws `SystemURLConfirmationError.dialogDidNotDismiss` |
| Target `"Unable to open link"` alert on invalid/malformed URL | Wait completes directly without SpringBoard alert | Handled by caller refusal test assertions |
| Leftover SpringBoard alert(s) at `tearDownWithError()` | Captures `"native-route-teardown-springboard"`, cancels up to 8 matching Chavrusa prompts (`"Cancel"`), ALWAYS calls `XCTFail` | Fails current test while preventing prompt leakage into next test |

### 2.2 Interruption Boundary & Owned Cleanup (`Scripts/CI/runtime27_interruption.py`, `runtime27.py`, `run-faithful-ipad-matrix.py`)

- **Shared Helper (`Scripts/CI/runtime27_interruption.py`):**
  - `InterruptController`: registers `SIGINT` and `SIGTERM`, converts the first external signal to `KeyboardInterrupt`, tracks repeat signals while `interrupted` or `cleanup_active` is set without aborting cleanup/receipt persistence, and restores prior handlers cleanly.
  - `stop_owned_process_group`: single canonical helper (re-exported as `runtime27.stop_owned_process_group`, removing duplicate `killpg` code). Reaps leader via `process.poll()`, probes `killpg(pgid, 0)`, treats transient probe `OSError` (such as `PermissionError`) as still-alive so bounded `SIGKILL` fallback is never skipped, and explicitly marks `"off_group_simulator_agents": "NOT_INDEPENDENTLY_VERIFIED"`.
  - `stop_owned_subprocess`: terminates only an explicitly owned subprocess (`SIGINT` when `prefer_sigint and sys.platform != "win32"`, else `.terminate()`), waits `INTERRUPTED_PROCESS_GRACE_SECONDS = 1.0`, escalates to `.kill()` + `INTERRUPTED_PROCESS_KILL_WAIT_SECONDS = 0.5`.
  - `run_isolated_cleanup_step`: isolates individual helper `.stop()` / `.close()` exceptions (`Exception`, `KeyboardInterrupt`) into `cleanupErrors`.
  - Bounded interrupted simulator timeouts: `INTERRUPTED_SIM_SHUTDOWN_TIMEOUT = 5`, `INTERRUPTED_SIM_DELETE_TIMEOUT = 5`.
- **Matrix Runner (`Scripts/CI/run-faithful-ipad-matrix.py`):**
  - Wrapped script in `main()` under `InterruptController` (`SIGINT` + `SIGTERM`).
  - Handles interruption before report setup (`PRE_REPORT_SETUP`) and during `create_compatible_ipad` (`BEFORE_SIMULATOR_CREATED`) without invoking `shutdown` or `delete` when no `udid` exists.
  - `mark_device_interrupted` and `run_interrupted_cleanup` enforce `device["status"] = "INTERRUPTED"` (overwriting any earlier `"EXECUTED_PASS"` if interrupted during `largeText` or teardown), mark unfinished `device["largeText"]["status"] = "INTERRUPTED"`, set `report["status"] = "INTERRUPTED_UI_UNVERIFIED"` / `report["interrupted"] = True`, and `break` out of the `scenarios` loop so later devices never start.
  - On interruption, stops only owned `active_xcodebuild`, `native_url_delivery`, `hid_comparison`, `palette_log_stream`, `recording`, and `recording_log` via `run_isolated_cleanup_step`, skips the `60s` `collect-runtime27-palette-log.py` call (`"SKIPPED_ON_INTERRUPTION"`), persists `faithful-ipad-matrix.json` both before and after bounded `5s` shutdown + `5s` delete of the single owned `udid`, and exits `130`.
  - Preserves existing normal-path behavior and timeouts unchanged (`recording` `30s`/`15s`, `collect-runtime27-palette-log.py` `60s`, `shutdown` `300s`, `delete` `120s`, continuation across device failures).
- **Supervisor (`Scripts/CI/runtime27.py`):**
  - Uses `InterruptController`, hashes `"Scripts/CI/runtime27_interruption.py"` in `helper_inputs_sha256`, hoists `runpy.run_path` out of `visit()` in `collect_cases`, propagates matrix `INTERRUPTED_UI_UNVERIFIED` (`return 130`), and handles `KeyboardInterrupt` / `BaseException` inside `finally:` `collect_cases` (`case_collection_error`) so `result.json` is still written.

### 2.3 Bounded Reader Diagnostics (`Source/Otzaria/Compatibility/OtzariaGenericBackendAdapter.swift`)

- **Root Cause Status:** `O2A_WORK_PACKET.md` documents the `#22`/`#23` `book:3891|line:523` `invalidLocator` failure as unresolved because `OtzariaGenericBackendAdapter.section(at:)` invoked `OtzariaReadingUnitService` directly without wrapper stage logs. No speculative reader/restoration semantic edits were made.
- **Implementation:**
  - Added `#if DEBUG` `Self.debugLog(...)` stage breadcrumbs in `section(at:)`: `enter` (with `backend`, `positionKind`, `workKeyKind`), `reject_locator`, `reject_book_id`, `adjacent_stale`, `unit_fence_stale`, `unit_hit`, `unit_nil` (`cancelled`, `genMatch`), `fallback_nil`, `fallback_fence_stale`, `fallback_hit`, `background_error`, and `outer_fence_stale`.
  - Added `#if os(iOS) && DEBUG` helpers `debugLog(_:)` (forwarding to `OtzariaFileLogger.shared.log`) and `debugErrorCategory(_:)` (mapping `CancellationError`, `LibraryBackendError`, `OtzariaReadingUnitError`, and `NSError` domain/code without logging any Hebrew/text content).
  - Cancellation checks, generation/mode fences, and thrown error values remain identical to base `1472fdea2aa61f4c4c830822758ea75a8c76e08b`.

---

## 3. Portable Verification Evidence

### 3.1 Pre-Repair RED Reproduction (`tools/test_runtime27_interruption.py`)

Executed earlier in this session on unmodified base `runtime27.py` + `run-faithful-ipad-matrix.py` via `C:\Users\DAVID\AppData\Local\Programs\Python\Python312\python.exe tools/test_runtime27_interruption.py`:
- Result: `Ran 7 tests in 3.612s` -> `FAILED (failures=7)` (7 interruption defect assertions failed against unmodified scripts; `test_normal_path_cleanup_and_failure_continuation_remain_unchanged` passed).
- Reproduced defects:
  1. Missing `SIGTERM` handler in `run-faithful-ipad-matrix.py` exited `3` without `finally:`, receipt, or cleanup.
  2. `KeyboardInterrupt` during `13-inch` `largeText` left `devices[1]["status"] == "EXECUTED_PASS"` or exited `3221225786`.
  3. Helper `.stop()` `OSError` and 2nd `SIGINT` aborted cleanup before writing `faithful-ipad-matrix.json`; diagnostics (`60s`) and shutdown/delete (`300s`/`120s`) were unbounded on interruption.
  4. Transient `PermissionError` in `os.killpg(pgid, 0)` skipped `SIGKILL` in `runtime27.py`.
  5. `KeyboardInterrupt` inside `collect_cases` in `runtime27.py`'s `finally:` prevented writing `result.json`.

### 3.2 Post-Repair GREEN Verification (Latest Commands on Final Edited Code)

Executed with `C:\Users\DAVID\AppData\Local\Programs\Python\Python312\python.exe` and `Swift version 6.3.3` on Windows:

- **Swift 6 Syntax Parse (Release & `-D DEBUG`):**
  - `swiftc -parse -swift-version 6 Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift` -> exit `0`
  - `swiftc -parse -D DEBUG -swift-version 6 Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift` -> exit `0`
  - `swiftc -parse -swift-version 6 Source/Otzaria/Compatibility/OtzariaGenericBackendAdapter.swift` -> exit `0`
  - `swiftc -parse -D DEBUG -swift-version 6 Source/Otzaria/Compatibility/OtzariaGenericBackendAdapter.swift` -> exit `0`
- **Python Bytecode Compile:**
  - `python.exe -m py_compile Scripts/CI/runtime27_interruption.py Scripts/CI/runtime27.py Scripts/CI/run-faithful-ipad-matrix.py tools/test_runtime27_interruption.py` -> exit `0`
- **Interruption & Normal-Path Regression Tests (`python.exe tools/test_runtime27_interruption.py -v`):**
  - `test_cleanup_failure_and_second_signal_preserve_interrupted_receipt_and_skip_slow_diagnostics` ... `ok`
  - `test_interruption_after_xcodebuild_pass_never_records_executed_pass` ... `ok`
  - `test_interruption_before_udid_creation_never_calls_shutdown_or_delete` ... `ok`
  - `test_normal_path_cleanup_and_failure_continuation_remain_unchanged` ... `ok`
  - `test_sigterm_halts_device_advancement_stops_owned_xcodebuild_and_runs_bounded_cleanup` ... `ok`
  - `test_runtime27_main_writes_result_json_even_if_collect_cases_interrupted` ... `ok`
  - `test_runtime27_stop_owned_process_group_and_interrupted_result_preserved` ... `ok`
  - Summary: `Ran 7 tests in 8.968s` -> `OK` (exit `0`)
- **Existing Guard Tests (`python.exe tools/test_verify_xcresult_zero_skips.py -v`):**
  - All 10 existing tests (`test_actual_device_and_os_required`, `test_actual_xcode27_execute_footer_and_build_only_refusal`, `test_metadata_probe_does_not_satisfy_required_ui_case`, `test_named_real_result_and_log_pass`, `test_original_owner_false_greens_rejected_by_cli`, `test_reject_duplicate_case`, `test_reject_failed_retry_hidden_by_parent`, `test_reject_false_green_variants`, `test_reject_tree_failures_and_non_ui_bundle`, `test_unit_bundle_never_counts_as_ui`) -> `Ran 10 tests in 0.507s` -> `OK` (exit `0`)

---

## 4. Self-Review Summary

- **Cancellation & Interruption:** Verified across pre-UDID creation, active `xcodebuild`, post-pass `largeText`, helper `.stop()` `OSError`, repeat signal during cleanup, and `collect_cases` interruption. `result.json` and `faithful-ipad-matrix.json` are always persisted as interrupted/unverified (`130`).
- **Unexpected Dialogs / Refusal / Replay:** `confirmSpringBoardOpenDialog` fails closed on `alerts.count != 1`, title mismatch, missing/disabled `"Open"`, or failed dismissal (`XCTFail` + typed throw + SpringBoard/app screenshots and view hierarchies). Refusal (`"Unable to open link"`) and replay tests remain intact without mistaking `"Cancel"` for delivery.
- **Partial Teardown Failure:** Individual helper stop/close failures are isolated in `cleanupErrors`; `faithful-ipad-matrix.json` is written before and after bounded `5s` `shutdown` + `5s` `delete`; leftover SpringBoard alerts at teardown are cancelled strictly for Chavrusa Open-in prompts (`max 8`) and always trigger `XCTFail`.
- **Normal-Path Invariance:** Normal non-interrupted completion retains original timeouts (`30s`/`15s` recording, `60s` palette diagnostic, `300s` shutdown, `120s` delete), device failure continuation, and `EXECUTED_PASS` reporting; `OtzariaGenericBackendAdapter.section(at:)` diagnostics are wrapped in `#if DEBUG` / `#if os(iOS) && DEBUG` and alter zero Release instructions or concurrency fences.

---

## 5. Protected & Hash-Pinned File Integrity

- `python.exe tools/verify_upstream_boundary.py --base 1472fdea2aa61f4c4c830822758ea75a8c76e08b --head WORKTREE` -> `Boundary Verification Result: PASS` (`Changes detected: 6, Violations: 0, Warnings: 0`, before adding this report).
- `git diff --check` -> exit `0`.
- `git diff --name-only HEAD -- Source/UI Source/Features Maktabah-iOSUITests/R27NativeInteractionAcceptanceTests.swift docs/hq-integration/runtime27/R27_CASES.json` -> empty (0 modifications).
- Pinned SHA-256 verification:
  - `Maktabah-iOSUITests/R27NativeInteractionAcceptanceTests.swift`: `lf_sha256=d4ff446db4acdbb61e0ad19c14696e5194bafbba239ef86876e85a2de30e70cc` (`raw_sha256=21b859725028bf37b0203b5b265ffc714b9b229945799672a2b5ee4a2bded2de`).
  - `docs/hq-integration/runtime27/R27_CASES.json`: `lf_sha256=d6ebe07d681e54440f58ce1b8b4945075f7047c8bce0b3a76fa98fd6fcf06875` (`raw_sha256=11be4ff3c425f45c00ae593f8f2687ee7a6155d1c867cab2363b5b41c3f22efc`).

---

## 6. Remaining `NOT_RUN` Native Gates (`BLOCKED_EXTERNAL` on Windows)

`apple-doctor --json` reports `{"apple_sdk_available":false,"platform":"Windows","portable_swift_only":true,"swiftc":"Swift version 6.3.3"}`. The following native gates were **NOT RUN** and require macOS/Xcode/iOS Simulator verification in a later phase/runner:

1. Full Xcode compilation (`build-for-testing`) of `Maktabah-iOSUITests` (`NativeRoutingAcceptanceTests.swift`) and `Maktabah.app` (`OtzariaGenericBackendAdapter.swift`) under Swift 6 + iOS SDK (`NOT_RUN`).
2. Live iOS 27 Simulator execution of `NativeRoutingAcceptanceTests` confirming SpringBoard `"Open in \u{201C}ChavrusaText\u{201D}?"` / `"Open"` UI delivery and same-PID warm routing receipts (`NOT_RUN`).
3. Live macOS POSIX `SIGINT`/`SIGTERM` process-group signaling of `xcodebuild` / `simctl` runners via `runtime27.py` and `run-faithful-ipad-matrix.py` (`NOT_RUN`).
4. Live reproduction and root-cause triage of `#22`/`#23` (`book:3891|line:523` `invalidLocator`) from the newly added `#if DEBUG` `[OtzariaGenericBackendAdapter]` logs (`NOT_RUN`).

---

## 7. Fix Round 1 — Timeout/Signal Cleanup Propagation (`#5`)

- **Round 1 Fix Base SHA:** `6fcae66429845fdddaff6a83a7e12671a22785bc`
- **Round 1 Code & Test Commit SHA:** `7d713dc3f66b097a86863d33c8dfd1eced37664a` (`O2-A round 1: propagate InterruptController into runtime27.run_logged timeout cleanup`)
- **Report Commit:** Recorded at `HEAD` on `cez/c5124cd6` immediately above `7d713dc3f66b097a86863d33c8dfd1eced37664a` and reported in the final Cezar report.
- **Changed Files in Round 1 (`6fcae664..HEAD`):**
  1. `Scripts/CI/runtime27_interruption.py` — Updated `InterruptController._handle_signal` so the first external signal arriving while `cleanup_active` is `True` truthfully records `interrupted=True`, `signal_number`, and `signal_name` (without falsely incrementing `repeat_signals` or raising `KeyboardInterrupt` during cleanup), while subsequent signals increment `repeat_signals` and return without aborting cleanup; added `InterruptController.cleanup_scope()` (preserving/restoring prior `cleanup_active` state) and `InterruptController.apply_metadata(target)`.
  2. `Scripts/CI/runtime27.py` — Updated `run_logged(command, name, timeout, interrupt_controller=None)` (preserving 3-argument standalone compatibility) to refuse spawning a new child if `interrupt_controller.interrupted` is already `True`, guard the `except BaseException:` owned cleanup block (`stop_owned_process_group` / `stop_owned_subprocess` and `.interrupted.json` persistence) with `cleanup_scope()`, mark synthetic `KeyboardInterrupt` via `mark_interrupted`, and record truthful interruption metadata via `apply_metadata(marker)`. Wired `interrupt_controller=controller` into all 5 `run_logged(...)` calls inside `main()`, guarded `main()`'s `finally:` with `controller.cleanup_scope()`, and recorded `controller.apply_metadata(report)` onto `result.json` while keeping timeout failures non-PASS (`status="FAIL"`, `returncode=1`).
  3. `tools/test_runtime27_interruption.py` — Added `Runtime27SupervisorInterruptionTests` regressions exercising the real `main()` -> `InterruptController` -> `run_logged` -> `stop_owned_process_group` wiring across `TimeoutExpired` + first `SIGTERM`/`SIGINT` + repeat signal during cleanup, `TimeoutExpired` without signal, already-interrupted cleanup + repeat signal, pre-existing `cleanup_active=True` preservation, pre-interrupted child-spawn refusal, standalone 3-arg compatibility, and unchanged normal-path `EXECUTED_PASS` wiring (plus `interrupt_controller=None` on `fake_run_logged` in Test 7 to match the real signature).
  4. `docs/phase1-cezar/O2A_IMPLEMENTATION_REPORT.md` — Appended this Round 1 record.
- No Swift/native test files, `Scripts/CI/run-faithful-ipad-matrix.py`, or deferred minor review findings were modified in Round 1.

### 7.1 Round 1 Pre-Repair RED Reproduction (`6fcae664` production scripts)

Executed with `C:\Users\DAVID\AppData\Local\Programs\Python\Python312\python.exe` against unmodified `Scripts/CI/runtime27.py` and `Scripts/CI/runtime27_interruption.py` from `6fcae664`:

- Focused new tests command:
  `python.exe tools/test_runtime27_interruption.py -v Runtime27SupervisorInterruptionTests.test_runtime27_main_timeout_cleanup_handles_first_sigterm_sigint_and_repeat_signals Runtime27SupervisorInterruptionTests.test_runtime27_main_timeout_without_signal_and_already_interrupted_paths`
  -> `Ran 2 tests in 2.024s` -> `FAILED (failures=5)`:
  - `case='sigterm_then_repeat_sigint'`: `AssertionError: False is not True : sigterm_then_repeat_sigint: main/controller must set cleanup_active=True during run_logged timeout cleanup`
  - `case='sigint_then_repeat_sigterm'`: `AssertionError: False is not True : sigint_then_repeat_sigterm: main/controller must set cleanup_active=True during run_logged timeout cleanup`
  - `case='timeout_without_signal'`: `AssertionError: False is not True` (`cleanup_active_during_kill` was `False`)
  - `case='already_interrupted_during_wait_plus_repeat_signal'`: `AssertionError: False is not True` (`cleanup_active_before_repeat` was `False`)
  - `case='preexisting_cleanup_active_and_preinterrupted_and_standalone'`: `TypeError: run_logged() got an unexpected keyword argument 'interrupt_controller'`

### 7.2 Round 1 Post-Repair GREEN Verification (`7d713dc3f66b097a86863d33c8dfd1eced37664a`)

Executed with `C:\Users\DAVID\AppData\Local\Programs\Python\Python312\python.exe`:

- `python.exe -m py_compile Scripts/CI/runtime27_interruption.py Scripts/CI/runtime27.py Scripts/CI/run-faithful-ipad-matrix.py tools/test_runtime27_interruption.py` -> exit `0`
- `python.exe tools/test_runtime27_interruption.py -v` -> `Ran 9 tests in 11.780s` -> `OK` (exit `0`; all 7 prior tests + both new `main/controller/run_logged` suites)
- `python.exe tools/test_verify_xcresult_zero_skips.py -v` -> `Ran 10 tests in 0.479s` -> `OK` (exit `0`)
- `python.exe tools/verify_upstream_boundary.py --base 1472fdea2aa61f4c4c830822758ea75a8c76e08b --head 7d713dc3f66b097a86863d33c8dfd1eced37664a` -> `Boundary Verification Result: PASS` (`Changes detected: 7, Violations: 0, Warnings: 0`)
- `git diff --name-status 6fcae66429845fdddaff6a83a7e12671a22785bc 7d713dc3f66b097a86863d33c8dfd1eced37664a` -> `M Scripts/CI/runtime27.py`, `M Scripts/CI/runtime27_interruption.py`, `M tools/test_runtime27_interruption.py` (`git diff --check` exit `0`)
- Pinned LF SHA-256 unchanged (`R27NativeInteractionAcceptanceTests.swift` = `d4ff446db4acdbb61e0ad19c14696e5194bafbba239ef86876e85a2de30e70cc`, `R27_CASES.json` = `d6ebe07d681e54440f58ce1b8b4945075f7047c8bce0b3a76fa98fd6fcf06875`).
- Native Apple SDK / iOS Simulator / live macOS POSIX process-group execution remain `NOT_RUN` on Windows.
