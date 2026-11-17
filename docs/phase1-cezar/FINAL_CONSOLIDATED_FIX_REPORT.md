# Phase 1 Final Consolidated Fix Wave Report

- **Task Order / Unit:** `c4687096-14b0-4165-b6b5-f4737f885210` (eighth / last unique child; zero nested workers/reviewers)
- **Logical Roles & Execution Mode:** `נועם (noam) | Engineering` + `תומר (tomer) | Integration` (`MAIN_SESSION`)
- **Worktree / Branch:** `cez/c4687096`
- **Base Commit SHA:** `cc020cc02104324b6fc0f846861f4f653d0639f8`
- **Original Phase 1 Baseline SHA:** `4065feef11bd5a8997ea34364516468105778688`
- **Combined Source Commit / Tree:** `a316f0167d62a57e505c0f99c2e8694414d6e0de` (`Source` tree `45a956ff63f48b641f07369064dbb960c7e254a8`, matching `HEAD:Source` and `84b533700c6f6401750e3f4f45d89123b55751fb:Source`)
- **Result Commit SHA:** Recorded on branch `cez/c4687096` at commit creation and reported in `cez task report`
- **Whole-Branch Review Authority:** `docs/phase1-cezar/WHOLE_BRANCH_INDEPENDENT_REVIEW.md` (`207093515dd850f4cfd036273311dc2444921c8f`) & `docs/phase1-cezar/FINAL_CONSOLIDATED_FIX_PACKET.md`

---

## 1. Per-Finding Dispositions (F1–F8)

| Finding | Severity | Disposition | Implemented Resolution |
|---|---|---|---|
| **F1** (`Scripts/CI/hq-stage2-focused-apple.inputs.json`) | Important | **FIXED (Portable Source/Input Pin Verified)** | Updated **only** `application_source_sha` to `a316f0167d62a57e505c0f99c2e8694414d6e0de` and `application_trees.Source` to `45a956ff63f48b641f07369064dbb960c7e254a8` (verified equal to `HEAD:Source` and `a316f016...:Source`). Kept `Vendor`, `Maktabah.xcodeproj`, `engine_producer_sha`, `engine_trees`, `sefaria_gitlink`, `resource_producer_sha`, `resource_bundle_sha256`, `resources`, `artifacts`, `embedded_js_overlay_paths`, and `rebuild_zayit_framework` byte-for-value identical. `hq-stage2-focused-apple.py --preflight-only` now exits `0`; negative `EXPECTED_CHECKOUT_SHA`, wrong `Source`/`Vendor` tree, and wrong `sefaria_gitlink` drift checks still fail closed. |
| **F2** (`Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift`) | Important | **FIXED (Source Contract & Swift 6 Parse Verified; Native UI `NOT_RUN`)** | Added a bounded `2` second `XCTNSPredicateExpectation` settling wait inside `confirmSpringBoardOpenDialog(springboard:)` using actor-safe `MainActor.assumeIsolated` with a local `XCUIApplication(bundleIdentifier: "com.apple.springboard")` (no non-`Sendable` capture), waiting for `alerts.count == 1`, `matchesExpectedSpringBoardOpenTitle(alert)`, unique `"Open"` button (`openMatches.count == 1`), and `openButton.exists && openButton.isHittable`. Re-evaluates all conditions and fail-closed guards before tapping `"Open"`. Preserved real `simctl` sidecar transport, 5-key credential-free ack check, same-PID proof, refusal (`"Unable to open link"`), replay, and `[NativeNavigationReceipt]` assertions unchanged. |
| **F3** (`Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift`) | Minor | **FIXED (Source Contract & Swift 6 Parse Verified; Native UI `NOT_RUN`)** | Updated `cleanupLeftoverSpringBoardOpenAlertsInTeardown()` to capture `beforeCount = alerts.count` and require `XCTWaiter.wait(for: [reduced], timeout: 5) == .completed` before incrementing `cancelledCount`, breaking immediately when dismissal makes no confirmed progress instead of burning 8x5s on one stuck prompt and inflating `cancelledChavrusaPrompts`. When `count == 0` after confirmed dismissal, waits up to `0.5s` for queued sequential prompts. Preserves `matchesExpectedSpringBoardOpenTitle` filtering and unconditional `XCTFail(...)` whenever `initialCount > 0`. |
| **F4** (`Scripts/CI/run-faithful-ipad-matrix.py`) | Minor | **FIXED & VERIFIED (Portable Subprocess Tests)** | Cleared each normal-path helper local (`native_url_delivery`, `hid_comparison`, `palette_log_stream`, `recording`, `recording_log`, plus `active_xcodebuild` and helpers in `run_interrupted_cleanup()`) to `None` immediately after `.stop()`/`.wait()`/`.close()`. Replaced unconditional `"SKIPPED_ON_INTERRUPTION"` overwrite with `device.setdefault("paletteInputDiagnosticExitCode", "SKIPPED_ON_INTERRUPTION")`. Guarded interrupted `shutdown`/`delete` on `udid is not None and (device is None or device.get("ownedSimulatorCleanup") != "PASS")`, preventing duplicate deletion/status degradation after normal simulator deletion already succeeded. |
| **F5** (`Scripts/CI/run-faithful-ipad-matrix.py`) | Minor | **FIXED & VERIFIED (Portable Subprocess Tests)** | Initialized `udid = None`, `device = None`, and all helper handles before `create_compatible_ipad(...)` inside each scenario iteration, passed `on_created=_record_created_udid` so `udid` is captured immediately upon `simctl create` returning `0`, and moved `create_compatible_ipad` + `device` setup inside the guarded `try/except/finally` scope. Wrapped `run_interrupted_cleanup()` in `with controller.cleanup_scope():`. Preserved zero `shutdown`/`delete` calls when interrupted before a known `udid` exists, and preserved `SystemExit` propagation if `create_compatible_ipad` fails with `device is None`. |
| **F6** (`tools/test_runtime27_interruption.py`, `Scripts/CI/runtime27.py`) | Minor | **FIXED & VERIFIED (Portable Tests)** | Removed the dead Test 6 dummy-file setup, unused `fake_collect_cases`, unused `collect_cases` patch, and unused `report` assignment. Updated `FakeProcess.terminate` to honor `recording_exit_on_terminate`, configured Test 4 Case 2 (`recording_timeout_and_second_signal`) with `"recording_exit_on_sigint": False` and `"recording_exit_on_terminate": False` so `recording` genuinely reaches `TimeoutExpired` -> `popen_kill` on Windows and POSIX, asserted `dev["cleanupErrors"]` (`palette_log_stream` `OSError`) in Test 4 Case 1, and added `test_runtime27_unsignaled_supervisor_propagates_matrix_exit_130` exercising `runtime27.py:337-344`. `Scripts/CI/runtime27.py` required zero code changes. |
| **F7** (`tools/test_o2b_native_ux.py`) | Minor | **FIXED & VERIFIED (Portable Tests)** | Replaced naive `"DEBUG" in cond and "!" not in cond` substring checks in `line_in_debug_guard` with a conservative 3-valued Swift conditional AST evaluator (`True`/`False`/`Unknown` evaluated at `DEBUG=False` and `DEBUG=True`) tracking accumulated prior-branch negation (`#if` / `#elseif` / `#else` / `#endif`) so non-DEBUG `#else` never becomes DEBUG-only and `DEBUG || X` / `false && DEBUG` / dead branches are rejected. Added `"restore "` to required diagnostic markers. Removed the hardcoded personal `C:\Users\...\6.3.3` path and replaced it with `discover_windows_sdk()` honoring explicit `SDKROOT` or discovering a compatible existing Windows SDK relative to active `swiftc` / `%LOCALAPPDATA%` / `%ProgramFiles%` via `SDKSettings.json` without personal paths or installs. |
| **F8** (`Scripts/CI/runtime27_interruption.py`, `Scripts/CI/run-faithful-ipad-matrix.py`) | Minor | **FIXED & VERIFIED (Portable Subprocess Tests)** | Added `write_json_atomic(target_path, payload, indent=2)` in `runtime27_interruption.py` writing to a same-directory sibling `.tmp` via `tempfile.mkstemp` + `os.fdopen` + `flush()` + `os.fsync()` + `Path.replace()`, unlinking any partial `.tmp` on failure. Switched all `faithful-ipad-matrix.json` writes (`write_matrix_report` and outer `except KeyboardInterrupt:`) to `write_json_atomic`. Guarded the normal-cleanup pre-delete `write_matrix_report()` so an `OSError` cannot bypass owned `shutdown`/`simctl delete`, marks `device["status"] = "FAIL"`, and re-raises to prevent silent `PASS`. |

---

## 2. Writable-Path Scope, Protected Trees & Other-Input Integrity

### 2.1 Changed Paths (8 of 9 Permitted Paths; `Scripts/CI/runtime27.py` Untouched)
1. `M` `Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift` (F2, F3)
2. `M` `Scripts/CI/run-faithful-ipad-matrix.py` (F4, F5, F8)
3. `M` `Scripts/CI/runtime27_interruption.py` (F8 shared `write_json_atomic` helper)
4. `M` `Scripts/CI/hq-stage2-focused-apple.inputs.json` (F1: only `application_source_sha` and `application_trees.Source`)
5. `M` `tools/test_runtime27_interruption.py` (F4, F5, F6, F8 tests + dead Test 6 setup removal)
6. `M` `tools/test_o2b_native_ux.py` (F7 conservative `#if DEBUG` parser, `"restore "` marker, portable Windows SDK discovery + regressions)
7. `A` `tools/test_final_integration_contracts.py` (F1 positive/negative preflight contracts + F2/F3 source contracts & Swift 6 syntax parse)
8. `A` `docs/phase1-cezar/FINAL_CONSOLIDATED_FIX_REPORT.md` (this report)
- `Scripts/CI/runtime27.py` was inspected and left **untouched**.

### 2.2 Protected & Pinned Integrity Evidence
- `Source/`, `Vendor/`, `Maktabah.xcodeproj/`, `.github/workflows/`, `docs/hq-integration/runtime27/R27_CASES.json`, `Maktabah-iOSUITests/R27NativeInteractionAcceptanceTests.swift`, `PROJECT_BOARD.md`, HQ docs, and Asana have **zero** modifications (`git diff cc020cc02104324b6fc0f846861f4f653d0639f8..HEAD` touches only the permitted paths above).
- Non-Source fields in `Scripts/CI/hq-stage2-focused-apple.inputs.json` (`Vendor`, `Maktabah.xcodeproj`, `engine_producer_sha`, `engine_trees`, `sefaria_gitlink`, `resource_producer_sha`, `resource_bundle_sha256`, `resources`, `artifacts`, `embedded_js_overlay_paths`, `rebuild_zayit_framework`) are verified identical to `cc020cc02104324b6fc0f846861f4f653d0639f8`.
- Upstream boundary guards (`--base 4065feef11bd5a8997ea34364516468105778688 --head WORKTREE` and `--head HEAD`): both `tools/verify_upstream_boundary.py` and `Scripts/CI/verify-upstream-boundary.py` -> **`PASS` (`Violations: 0, Warnings: 0`)**.
- Pinned `lf_sha256` verification:
  - `Source/UI/iOS/Views/iPadLayout.swift`: `1426ef3f6894e2a3c031f971152f1f60872b0fd6b833b4b0231f5b283297108c`
  - `Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift`: `6330874e885c4fd193ede4938d34f54c42e88e54b7ddd3d95eba1c45ab70aa3f`
  - `Source/UI/iOS/Views/Common/ListContentView.swift`: `084f8d15e37655bf5ccd42cbdc9e308ecddd9c1cfc399a12d58089737ec8f2b1`
  - `Source/ChavrusaText/ReaderHost/ReaderSidebarPageCoordinator.swift`: `df1bdb92cebf8a10b7bd1de6c2d17c151b5d1105c023cb0497e79fd04417eac2`
  - `Maktabah-iOSUITests/R27NativeInteractionAcceptanceTests.swift`: `d4ff446db4acdbb61e0ad19c14696e5194bafbba239ef86876e85a2de30e70cc`
  - `docs/hq-integration/runtime27/R27_CASES.json`: `d6ebe07d681e54440f58ce1b8b4945075f7047c8bce0b3a76fa98fd6fcf06875`

---

## 3. RED -> GREEN Verification Receipts

All Python checks executed with `C:\Users\DAVID\AppData\Local\Programs\Python\Python312\python.exe` (`Python 3.12.5`) and `Swift version 6.3.3 (swift-6.3.3-RELEASE)`.

### 3.1 Pre-Fix RED Reproductions (Before Production Fixes)
1. **F1 preflight baseline on `cc020cc0`:**
   - `python Scripts/CI/hq-stage2-focused-apple.py --preflight-only` -> **`exit 1`** (`RuntimeError: Application tree drift: Source`).
2. **F1 / F2 / F3 RED (`tools/test_final_integration_contracts.py -v` on unmodified production files):**
   - `exit 1` (`FAILED`): `test_confirm_dialog_waits_bounded_2s_and_revalidates_before_tap` (`AssertionError: 'MainActor.assumeIsolated' not found`), `test_teardown_cancellation_checks_wait_completion_and_fails_unconditionally` (`_ = XCTWaiter.wait` present), `test_inputs_json_pins_actual_source_commit_and_preserves_other_inputs`, `test_real_preflight_only_passes`, `test_negative_drift_and_checkout_checks_fail_closed`.
3. **F7 RED (`tools/test_o2b_native_ux.py -v` with new guard/SDK tests on old helper):**
   - `exit 1` (`FAILED (failures=9)`): `non_debug_else`, `debug_or_feature`, `feature_or_debug`, `false_and_debug`, `debug_and_false`, `debug_and_not_debug`, `nested_debug_then_false`, `nested_uikit_ios_else`, and hardcoded personal path check failed.
4. **F4 / F5 / F8 RED (`tools/test_runtime27_interruption.py -v` with new regressions on unmodified `run-faithful-ipad-matrix.py`):**
   - `exit 1` (`FAILED (failures=3, errors=2)`):
     - `interrupt_during_palette_diagnostic`: `AssertionError: 2 != 1 : Already-stopped palette stream must not be stopped twice`
     - `interrupt_after_normal_delete`: `AssertionError: 'SKIPPED_ON_INTERRUPTION' != 0 : Prior paletteInputDiagnosticExitCode must not be overwritten on late interruption`
     - `test_interruption_right_after_udid_return_before_boot_cleans_up_owned_simulator`: `AssertionError: 0 != 1 : Known UDID 00000000-0000-4000-8000-000000000001 must be shut down on post-create interruption`
     - `mid_write_fault_preserves_prior_valid_json` & `normal_cleanup_write_failure_runs_cleanup_and_fails_nonzero`: `json.decoder.JSONDecodeError` (non-atomic `.write_text` truncated `faithful-ipad-matrix.json`).
5. **F6 baseline (`WHOLE_BRANCH_INDEPENDENT_REVIEW.md` & `FakeProcess.terminate` analysis):**
   - On unmodified `FakeProcess.terminate`, `recording_wait_error="timeout"` never reached `TimeoutExpired` or `popen_kill` (`['popen', 'popen_terminate', 'popen_wait']` only).

### 3.2 Post-Fix GREEN Verification (On Final Files / Committed `HEAD`)
1. `C:\Users\DAVID\AppData\Local\Programs\Python\Python312\python.exe Scripts/CI/hq-stage2-focused-apple.py --preflight-only` -> **`exit 0`** (`checkout_sha == HEAD`, `application_source_sha == a316f0167d62a57e505c0f99c2e8694414d6e0de`, `application_trees.Source == 45a956ff63f48b641f07369064dbb960c7e254a8`).
2. `C:\Users\DAVID\AppData\Local\Programs\Python\Python312\python.exe tools/test_final_integration_contracts.py -v` -> **`6/6 OK`** (with `SDKROOT` unset, exercising portable SDK discovery + negative drift/checkout failures + F2/F3 source contracts + Swift 6 frontend syntax parse Release & `-D DEBUG`).
3. `C:\Users\DAVID\AppData\Local\Programs\Python\Python312\python.exe tools/test_o2b_native_ux.py -v` -> **`7/7 OK`** (with `SDKROOT` unset).
4. `C:\Users\DAVID\AppData\Local\Programs\Python\Python312\python.exe tools/test_runtime27_interruption.py -v` -> **`13/13 OK`** (including F4 late teardown idempotency/preservation, F5 known-UDID post-return cleanup, F6 recording `popen_kill` + `cleanupErrors` + unsignaled matrix-130 propagation, and F8 atomic receipt fault-preservation + non-bypassed cleanup).
5. `C:\Users\DAVID\AppData\Local\Programs\Python\Python312\python.exe tools/test_verify_xcresult_zero_skips.py -v` -> **`10/10 OK`**.
6. `C:\Users\DAVID\AppData\Local\Programs\Python\Python312\python.exe tools/hq-sidebar-check.py` (with per-command `SDKROOT`) -> **`PASS`** (`55` compiled assertions + 5 Swift files syntax-parsed + `git diff --check`).
7. `C:\Users\DAVID\AppData\Local\Programs\Python\Python312\python.exe Scripts/CI/test-runtime27-release-gate.py` -> **`17/17 OK`**, plus CI helper suites (`test-runtime27-url-delivery.py` `10/10`, `test-runtime27-hid.py` `14/14`, `test-runtime27-fixture-oracle.py` `7/7`, `test-runtime27-fixture-recovery.py` `4/4`, `test-shutdown-faithful-simulator.py` `5/5`).
8. `swiftc -frontend -parse -swift-version 6 -enable-upcoming-feature MemberImportVisibility -enable-upcoming-feature InferIsolatedConformances -enable-upcoming-feature NonisolatedNonsendingByDefault -D DEBUG Maktabah-iOSUITests/MaktabahUITestBase.swift Maktabah-iOSUITests/FaithfulReaderUIAcceptanceTests.swift Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift` -> **`exit 0`**, plus portable Swift 6 isolation model probe compiled with `swiftc -c` -> **`exit 0`**.
9. `C:\Users\DAVID\AppData\Local\Programs\Python\Python312\python.exe Scripts/CI/verify-otzaria-xcode-project.py` -> **`PASS`**, both upstream boundary scripts -> **`PASS` (`Violations: 0, Warnings: 0`)**, `git diff --check` -> **`exit 0`**.

---

## 4. Remaining Unresolved / `NOT_RUN` / `OPEN` Gates (Phase 1 Remains `NOT READY`)

This wave establishes **portable Python & Swift syntax/source-contract verification only**. The following gates remain **`OPEN` / `NOT_RUN` (`BLOCKED_EXTERNAL` on Windows)**:

1. **Apple Xcode 27 SDK Compilation (`NOT_RUN`):** `Maktabah.app`, `Maktabah-iOSUITests` (including updated `NativeRoutingAcceptanceTests.swift`), `ReaderSidebarSplit`, `ReaderSidebarNativeSearchSDK`, `Phase1SidebarSDK`, `FaithfulToolbarSDK`.
2. **All 27 Native `R27_CASES.json` Cases (`NOT_RUN`):** Live SpringBoard Open-in confirmation (`#4, #5, #6, #8, #25, #26, #27`), History AX contrast audit (`#15`), alert-free `original_reader6` Pad (`#1, #2, #3`) & Phone (`#16, #17, #18`), `11-window` (`#19, #20`), and live macOS POSIX `os.killpg` / `SIGTERM` / `SIGINT` cleanup (`off_group_simulator_agents: NOT_INDEPENDENTLY_VERIFIED`).
3. **Unfixed Product Defects (`OPEN`):** Body paging (`Contents -> Library` LTR `#21`, diagnostics only) and `#22`/`#23` `book:3891|line:523` `invalidLocator` root cause.
4. **Remote Checkout / Owner Release / Main Merge Gates (`OPEN / BLOCKED_OWNER`):** Local-only commits are not pushed (`no-push`, `no-manual-paid-CI`). **Phase 1 remains `NOT READY`.**
