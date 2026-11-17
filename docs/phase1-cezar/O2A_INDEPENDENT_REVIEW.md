# O2-A Independent Task Review Report

- **Review Unit / Run:** `03b64140-30df-47ca-80fc-edf696dc726f` (`kind: review`)
- **Acting Logical Identities & Mode:** `רוני (roni) | QA & Evidence` + `דנה (dana) | Security & Privacy` (`MAIN_SESSION`; zero nested subagents)
- **Reviewed Implementation Branch:** `cez/c5124cd6` (`O2-A` worktree `c5124cd6-3896-4554-9c83-adf3722f6050`)
- **Reviewed Base SHA:** `1472fdea2aa61f4c4c830822758ea75a8c76e08b`
- **Reviewed Head SHA:** `6fcae66429845fdddaff6a83a7e12671a22785bc`
- **Review Worktree / Branch:** `cez/03b64140` forked from `1472fdea2aa61f4c4c830822758ea75a8c76e08b`
- **Specification Baseline:** `docs/phase1-cezar/O2A_WORK_PACKET.md`, `docs/phase1-cezar/O2_EXECUTION_PLAN.md`, `docs/architecture/UPSTREAM_INTEGRITY_POLICY.md`

---

## 1. Executive Verdicts

| Review Axis | Verdict | Basis |
|---|---|---|
| **Spec-Compliance Verdict** | **PASS** *(Portable/Source Spec-Compliant; Native Apple/POSIX Runtime Gates `NOT_RUN`)* | Strictly confined to the 7 frozen paths; preserves real `simctl openurl` transport, credential-free ack schema, same-PID/refusal/replay/receipt assertions, normal-path runner behavior, bounded UDID-fenced cleanup, and Release-invariant content-free `#if DEBUG` adapter diagnostics; honestly keeps Apple SDK/UI/POSIX runtime gates `NOT_RUN`. |
| **Code-Quality Verdict** | **PASS WITH MINOR FINDINGS** *(0 Critical, 0 Important, 6 Minor)* | Clean, well-factored shared interruption controller, fail-closed SpringBoard confirmation/teardown, and zero-leak DEBUG logging. Six minor hardening/cleanliness items are documented below with exact head file/line references. |
| **Recommended Cezar Merge Verdict** | **`approve`** *(for local manager-branch integration only)* | Zero blocking defects found in source/portable verification. Local merge into the manager branch is justified; **Phase 1 Native acceptance remains `NOT_RUN` / `NOT_READY`** until macOS/Xcode 27 compilation, live iOS 27 Simulator routing, and live macOS POSIX interruption checks execute. |

---

## 2. Scope, Upstream Boundary & Diff Proportionality

### 2.1 Frozen Writable Paths & Protected File Verification

`git diff --name-status 1472fdea2aa61f4c4c830822758ea75a8c76e08b 6fcae66429845fdddaff6a83a7e12671a22785bc` modifies **only** the 7 paths authorized in `docs/phase1-cezar/O2A_WORK_PACKET.md`:

1. `M` `Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift`
2. `M` `Scripts/CI/run-faithful-ipad-matrix.py`
3. `M` `Scripts/CI/runtime27.py`
4. `A` `Scripts/CI/runtime27_interruption.py`
5. `M` `Source/Otzaria/Compatibility/OtzariaGenericBackendAdapter.swift`
6. `A` `docs/phase1-cezar/O2A_IMPLEMENTATION_REPORT.md`
7. `A` `tools/test_runtime27_interruption.py`

Verified untouched at `6fcae66429845fdddaff6a83a7e12671a22785bc`:
- `tools/verify_upstream_boundary.py --base 1472fdea2aa61f4c4c830822758ea75a8c76e08b --head 6fcae66429845fdddaff6a83a7e12671a22785bc` -> **`PASS`** (`Changes detected: 7, Violations: 0, Warnings: 0`).
- `Maktabah-iOSUITests/R27NativeInteractionAcceptanceTests.swift`: `lf_sha256=d4ff446db4acdbb61e0ad19c14696e5194bafbba239ef86876e85a2de30e70cc` (exact match to `runtime27.py:279`).
- `docs/hq-integration/runtime27/R27_CASES.json`: `lf_sha256=d6ebe07d681e54440f58ce1b8b4945075f7047c8bce0b3a76fa98fd6fcf06875` (exact match).
- Settled owner-approved files (`iPadLayout.swift`, `iOSTOCView.swift`, `ListContentView.swift`): exact `lf_sha256` and Git blob matches (`1426ef3f...`, `6330874e...`, `084f8d15...`).
- Zero changes in `Source/UI/`, `Source/Features/`, `Source/Core/`, `Source/Extensions/`, `.github/workflows/`, `Maktabah.xcodeproj/`, `Package.resolved`, or `PROJECT_BOARD.md`.

### 2.2 Diff-Size Assessment (Smallest Safe Repair)

Although raw `git diff --stat` shows `1856 insertions(+), 508 deletions(-)`, inspecting `git diff -w` proves most of the churn in the two large modified product/CI files is structural re-indentation:
- `Scripts/CI/run-faithful-ipad-matrix.py`: drops from `927` raw diff lines to **`183` `-w` lines** (wrapping top-level module execution in `def main():` + `try/finally` for `InterruptController`).
- `Source/Otzaria/Compatibility/OtzariaGenericBackendAdapter.swift`: drops from `204` raw diff lines to **`106` `-w` lines** (wrapping the `Task.detached` body in `do { ... } catch` for `#if DEBUG` error-category logging).
- `Scripts/CI/runtime27_interruption.py` (`178` lines) replaces duplicated process-group teardown in `runtime27.py` (`runtime27.stop_owned_process_group` is re-exported cleanly and added to `helper_inputs_sha256`) rather than duplicating `os.killpg` logic across runners.
- Remaining additions are `NativeRoutingAcceptanceTests.swift` (`103` lines), `tools/test_runtime27_interruption.py` (`694` lines), and `docs/phase1-cezar/O2A_IMPLEMENTATION_REPORT.md` (`142` lines).

Within the constraints of wrapping a top-level runner in `main()` and isolating portable regression tests in a standalone temp-sandbox suite, this remains a minimal, localized downstream repair.

---

## 3. Detailed Technical Assessment by Requirement

### 3.1 System URL Confirmation, Fail-Closed Guards, Refusal, Replay & Same-PID (`Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift`)

- **Real transport & canonical assertions preserved (`:128-207`, `:245-345`):** Retains `.runningForeground` wait (`15s`), `originalPID` capture, `r27-url-<token>-<nonce>.request.json`/`.ack.json` protocol, strict 5-key credential-free ack schema (`udid`, `transport`, `delivered`, `nonce`, `time`) with token-redaction check, foreground wait (`15s`), `actualPID == originalPID` assertion, refusal (`"Unable to open link"`), replay exact-one `[NativeNavigationReceipt]` check, and `workspaceSidecarURL()` scene match.
- **Exact SpringBoard dialog selection & fail-closed behavior (`:13-16`, `:92-127`, `:136-140`, `:176-188`):**
  - Pre-existing SpringBoard alert (`springboard.alerts.count > 0` before request) fails closed immediately (`"preexisting-springboard-alert"`, `XCTFail`, `throw`).
  - `dialogOrDirectDelivery` (`:176-185`) waits up to `10s` for `sb.alerts.count > 0`, target `"Unable to open link"`, or `(!hadHistoryBefore && targetApp.navigationBars["History & Favorites"].exists)`. Setting `hadHistoryBefore` before URL dispatch prevents `testReplayCannotIssueSecondNativeReceipt`'s second `openInExistingProcess` call (when History is already visible) from short-circuiting the wait before SpringBoard/refusal appears.
  - `confirmSpringBoardOpenDialog(springboard:)` requires `alerts.count == 1`, title match against `{"Open in \u{201C}ChavrusaText\u{201D}?", "Open in \"ChavrusaText\"?"}` (matching the exact `"Open in “ChavrusaText”?"` alert title observed in CI `43891893650` `test-simulator-11-reader.log:1980`), unique hittable `"Open"` button (`count == 1`, `exists && isHittable`), taps `"Open"`, waits `10s` for `springboard.alerts` `count == 0`, and attaches `"actual-system-open-confirmation"`. Never treats `"Cancel"` or dismissal as delivery.
  - Cross-test isolation (`:30-67`): `tearDownWithError()` runs `cleanupLeftoverSpringBoardOpenAlertsInTeardown()`, captures `"native-route-teardown-springboard"` hierarchy/screenshot, cancels only up to 8 alerts matching `expectedSpringBoardOpenTitles` (`guard titleMatches else { break }`), and **unconditionally calls `XCTFail(...)`** whenever `initialCount > 0`.
- **XCTest Swift 6 isolation & API correctness:**
  - `Maktabah.xcodeproj/project.pbxproj:5619-5622` configures `Maktabah-iOSUITests` with `SWIFT_VERSION = 6.0`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES` (corresponding to `Scripts/CI/typecheck-faithful-ui-tests.py:40-41`: `MemberImportVisibility`, `InferIsolatedConformances`, `NonisolatedNonsendingByDefault`, with no `SWIFT_DEFAULT_ACTOR_ISOLATION`).
  - `dialogOrDirectDelivery` captures only `Sendable` `hadHistoryBefore: Bool` and instantiates `XCUIApplication(bundleIdentifier:)` inside `MainActor.assumeIsolated`, matching the existing pattern in `FaithfulReaderUIAcceptanceTests.swift:186-204` and `GlobalSearchNativeAcceptanceTests.swift:51-53`.
  - `tearDownWithError()`, `cleanupLeftoverSpringBoardOpenAlertsInTeardown()`, and `captureSystemDialogEvidence(...)` stay `nonisolated`, matching base `tearDownWithError()` and `GlobalSearchNativeAcceptanceTests.swift:10-22` / `R27NativeInteractionAcceptanceTests.swift:35-50` which compiled and executed under `Xcode 27.1` in run `43891893650`.
  - `swiftc -parse -swift-version 6` (Release and `-D DEBUG`) passes, and a portable Swift 6 typecheck probe of the exact actor-isolation / closure-capture shape passes under Windows SDK; however, **real `XCUIAutomation` / `XCTest` iOS SDK compilation remains `NOT_RUN`** on Windows.

### 3.2 Interruption Boundary, Repeated Signals, Cleanup Bounds & Normal-Path Invariance (`runtime27_interruption.py`, `run-faithful-ipad-matrix.py`, `runtime27.py`)

- **Signal handling & repeat-signal safety (`runtime27_interruption.py:20-60`):** `InterruptController` installs both `SIGINT` and `SIGTERM`, converts the first external signal to `KeyboardInterrupt`, suppresses repeat signals (`self.repeat_signals += 1; return`) whenever `self.interrupted or self.cleanup_active`, and restores prior handlers in `finally:`.
- **No subsequent device advancement or false pass (`run-faithful-ipad-matrix.py:111-124`, `:185-272`, `:481-497`, `:536-543`):**
  - Interruption before `report` creation writes `PRE_REPORT_SETUP` interrupted JSON and exits `130`.
  - Interruption during `create_compatible_ipad` records `BEFORE_SIMULATOR_CREATED`, `status="INTERRUPTED_UI_UNVERIFIED"`, `interrupted=True`, breaks without calling `shutdown` or `delete`, and exits `130`.
  - Interruption after device creation (including during `largeText` after main `xcodebuild` passed, or during normal `else:` teardown) calls `mark_device_interrupted` and `run_interrupted_cleanup()`, forcing `device["status"] = "INTERRUPTED"` (overwriting any prior `"EXECUTED_PASS"`), `device["largeText"]["status"] = "INTERRUPTED"` unless `largeText` already completed `EXECUTED_PASS`, `report["status"] = "INTERRUPTED_UI_UNVERIFIED"`, and breaking out of the `scenarios` loop so subsequent devices (`13`, `phone`) never start.
- **Owned-target fencing & bounded cleanup (`runtime27_interruption.py:63-178`, `run-faithful-ipad-matrix.py:210-270`, `runtime27.py:70-100`, `:316-358`):**
  - `stop_owned_process_group` targets only `process.pid` (`start_new_session=True`), catches transient `OSError` (such as `PermissionError`) on `killpg(pgid, 0)` so the bounded `SIGKILL` fallback is not skipped, never returns `GONE_CHECKED` when `not gone or send_errors`, and explicitly records `"off_group_simulator_agents": "NOT_INDEPENDENTLY_VERIFIED"`.
  - `run_interrupted_cleanup()` stops only owned `active_xcodebuild`, `native_url_delivery`, `hid_comparison`, `palette_log_stream`, `recording`, and `recording_log` via `run_isolated_cleanup_step`, skips the `60s` `collect-runtime27-palette-log.py` call (`"SKIPPED_ON_INTERRUPTION"`), persists `faithful-ipad-matrix.json` before and after `5s` `shutdown` + `5s` `delete` of the single newly created `udid`, and captures cleanup failures in `device["cleanupErrors"]` / `device["ownedSimulatorCleanup"] = "FAIL"`.
  - `runtime27.py` propagates matrix `INTERRUPTED_UI_UNVERIFIED` (`return 130`) and wraps `collect_cases` inside `main()`'s `finally:` in `except BaseException:` so `build/artifacts/runtime27/result.json` is persisted even if `collect_cases` itself is interrupted.
- **Normal-path invariance:** Non-interrupted execution preserves original timeouts (`recording` `30s`/`15s`, `collect-runtime27-palette-log.py` `60s`, `shutdown` `300s`, `delete` `120s`), device-failure continuation across `11` -> `13` -> `phone`, `largeText` restoration, and `EXECUTED_PASS` / `SELECTED_UI_EXECUTED_PASS` logic (while fixing a pre-existing `result` local variable overwrite during `largeText` via `large_proc` at `run-faithful-ipad-matrix.py:460`).
- **Test quality (`tools/test_runtime27_interruption.py`):** Tests 1–5 invoke the actual `Scripts/CI/run-faithful-ipad-matrix.py` and `Scripts/CI/runtime27_interruption.py` in a real Python subprocess and inject real `SIGINT`/`SIGTERM` signals across hook points while stubbing only external `xcrun`/`xcodebuild`/`git`/oracle binaries; Tests 6–7 exercise real `runtime27.run_logged`, `stop_owned_process_group`, and `runtime27.main()` control flow with mocked `os.killpg` and Xcode commands. These genuinely verify Python signal/cleanup/receipt control flow, while **never substituting for live macOS POSIX `os.killpg` / `xcodebuild` / `simctl` behavior (`NOT_RUN`)**.

### 3.3 Bounded Reader Diagnostics & Release Invariance (`Source/Otzaria/Compatibility/OtzariaGenericBackendAdapter.swift`)

- **Privacy & bounds (`:48-67`, `:83-87`, `:106-165`, `:175-214`):** All new instrumentation is gated by `#if DEBUG` / `#if os(iOS) && DEBUG`. Logged fields are strictly structural/categorical (`stage`, `backend.rawValue`, `positionKind`, `workKeyKind` [`bookPrefix`/`numeric`/`stableKey` without raw `workKey`], integer `bookId` / `lineIndex`, `mode.storageValue`, `cancelled`, `genMatch`, and static `debugErrorCategory` or `nsError.domain:code`). Zero Hebrew text, `nash`, `heRef`, URLs, payloads, or credentials are logged.
- **Exhaustiveness & Release invariance:** `debugErrorCategory(_:)` switches exhaustively over all 9 cases of `LibraryBackendError` (`LibraryBackendModels.swift:842-851`, ignoring associated message strings) and `OtzariaReadingUnitError.inconsistentSourceLines` (`OtzariaReadingUnitService.swift:3-5`). In Release (`!DEBUG`), all `#if DEBUG` blocks compile out and `do { ... } catch { throw error }` inside `Task.detached` preserves the exact base execution order, cancellation checks, `generationSnapshot()` / `currentReadingUnitMode` fences, and thrown error values. No speculative fix to `#22/#23` `book:3891|line:523` `invalidLocator` was introduced.

---

## 4. Actionable Findings (All Minor; 0 Critical, 0 Important)

1. **[Minor] Single-shot synchronous `openButton.isHittable` check immediately after `alerts.count > 0`**
   - **Location:** `Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift:107-113` (`confirmSpringBoardOpenDialog(springboard:)`)
   - **Evidence / Reproducer:** `openInExistingProcess(_:)` exits `dialogOrDirectDelivery` (`:176-185`) as soon as `sb.alerts.count > 0` returns `true` and immediately calls `confirmSpringBoardOpenDialog`, which checks `openButton.exists && openButton.isHittable` once without waiting for alert presentation animation settling.
   - **Consequence:** Never causes a false pass or taps a wrong button (it fails closed with `"missing-springboard-open-button"` + screenshot/hierarchy + `XCTFail`), but could cause transient flakiness on Simulator if `isHittable` is briefly `false` during SpringBoard's alert appear animation.
   - **Smallest Correction:** Wait briefly (e.g., `1-2s` predicate for `openMatches.count == 1 && openButton.exists && openButton.isHittable`) inside `confirmSpringBoardOpenDialog` before failing closed.

2. **[Minor] Teardown alert cancellation loop ignores `.timedOut` on `reduced` expectation**
   - **Location:** `Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift:46-51` (`cleanupLeftoverSpringBoardOpenAlertsInTeardown()`)
   - **Evidence / Reproducer:** After `cancelButton.tap()`, `_ = XCTWaiter.wait(for: [reduced], timeout: 5)` ignores the wait result and unconditionally runs `cancelledCount += 1` across all 8 iterations.
   - **Consequence:** If a leftover prompt fails to dismiss after `Cancel`, teardown spends up to `40s` retrying the same alert and logs an inflated `cancelledChavrusaPrompts` number in `XCTFail(...)` (still fails closed unconditionally).
   - **Smallest Correction:** Break out of the loop and avoid incrementing `cancelledCount` unless `XCTWaiter.wait(for: [reduced], timeout: 5) == .completed`.

3. **[Minor] Normal cleanup branch leaves helper handles populated before late-teardown `KeyboardInterrupt` fallback**
   - **Location:** `Scripts/CI/run-faithful-ipad-matrix.py:498-535` (vs `:210-246`)
   - **Evidence / Reproducer:** Lines `500-513` call `.stop()` on `native_url_delivery`, `hid_comparison`, `palette_log_stream`, `recording`, and `.close()` on `recording_log` without setting those local variables to `None`. If `SIGINT`/`SIGTERM` arrives later during `collect-runtime27-palette-log.py` (`:516`) or `shutdown`/`delete` (`:523-525`), `except KeyboardInterrupt:` (`:533`) calls `run_interrupted_cleanup()` (`:535`), invoking `.stop()`/`.close()` on those already-stopped helpers a second time (and re-running `PaletteLogStream.stop()`'s file read/JSON write and overwriting `paletteInputDiagnosticExitCode` with `"SKIPPED_ON_INTERRUPTION"`).
   - **Consequence:** Inspected `.stop()`/`.close()` implementations tolerate repeated calls without raising, so this does not break cleanup or receipt integrity, but causes redundant I/O and clobbers prior `paletteInputDiagnosticExitCode` if interrupted late in teardown.
   - **Smallest Correction:** Set each helper variable (`native_url_delivery`, `hid_comparison`, `palette_log_stream`, `recording`, `recording_log`) to `None` immediately after stopping/closing it in the normal `else:` cleanup block.

4. **[Minor] Tiny unguarded bytecode window between UDID return and inner device `try:` block**
   - **Location:** `Scripts/CI/run-faithful-ipad-matrix.py:116-126` vs `:273`
   - **Evidence / Reproducer:** `udid, device_type, runtime, failures = create_compatible_ipad(size)` (`:116`) returns a freshly created simulator UDID before `device` construction (`:125-126`) and nested `def` statements (`:134-272`) enter `try:` at `:273`.
   - **Consequence:** While `create_compatible_ipad` itself is protected (`BEFORE_SIMULATOR_CREATED`), an asynchronous `SIGTERM` arriving specifically during the non-blocking Python assignments at `:125-272` would unwind to outer `except KeyboardInterrupt:` (`:554`) and skip `run_interrupted_cleanup()` for that newly created `udid`.
   - **Smallest Correction:** Initialize `udid = None` and helper variables before `create_compatible_ipad`, or place the `try ... finally` boundary immediately around `create_compatible_ipad` (guarding `shutdown`/`delete` on `if udid is not None:`).

5. **[Minor] `runtime27.run_logged` `TimeoutExpired` path leaves `controller.cleanup_active = False` during `stop_owned_process_group`**
   - **Location:** `Scripts/CI/runtime27.py:77-100`
   - **Evidence / Reproducer:** When `process.wait(timeout=timeout)` raises `subprocess.TimeoutExpired` (not `KeyboardInterrupt`), `controller.interrupted` is still `False` and `controller.cleanup_active` is not set until `main()`'s `finally:` (`:342`).
   - **Consequence:** Same pre-existing exposure as base `1472fdea`: an external `SIGTERM` arriving during the 5-second `stop_owned_process_group` wait after a child timeout would raise `KeyboardInterrupt` out of `stop_owned_process_group` before `SIGKILL` runs (though `main()`'s `finally:` still writes `result.json`).
   - **Smallest Correction:** Guard `run_logged`'s teardown block with `previous_cleanup = controller.cleanup_active; controller.cleanup_active = True` (restored in `finally:`, or pass `controller` / set `cleanup_active` only when invoked under `main()`).

6. **[Minor] Dead stub lines and minor coverage omissions in `tools/test_runtime27_interruption.py`**
   - **Location:** `tools/test_runtime27_interruption.py:538-552`, `:327-354`, `:403-431`
   - **Evidence / Reproducer:** Lines `538-552` define `fake_collect_cases`, patch `rt.collect_cases`, and assign unused `report = ...` inside `test_runtime27_stop_owned_process_group_and_interrupted_result_preserved` (superseded by `test_runtime27_main_writes_result_json_even_if_collect_cases_interrupted`). In addition, `runtime27.py:319-324` (parent not signaled while matrix subprocess returns `130` with `INTERRUPTED_UI_UNVERIFIED`) is verified by inspection rather than a dedicated unit test, and `test_cleanup_failure_and_second_signal_...` does not directly assert `dev["cleanupErrors"]` keys or `recording` `popen_kill` events.
   - **Consequence:** Cosmetic dead setup in Test 6 and small unit-coverage omissions; does not invalidate the 7 passing regression assertions.
   - **Smallest Correction:** Remove unused lines `538-552` in Test 6 and optionally assert `dev["cleanupErrors"]` + `runtime27.py:319-324` propagation.

---

## 5. Declined to Judge / Out of Scope

- Unmodified upstream files (`Source/UI/`, `Source/Features/`, `iPadLayout.swift`, `iOSTOCView.swift`, `ListContentView.swift`, `iOSMainView.swift`, `MaktabahApp.swift`, `iOSNavigationManager.swift`) — read-only under `O2A_WORK_PACKET.md` and `UPSTREAM_INTEGRITY_POLICY.md`.
- O2-B defects (`GlobalSearchHistoryContent.swift` contrast `#15`, `ReaderSidebarPager.swift` LTR/RTL swipe `#21/#22`, Landscape `reader-more-menu` `#1/#3`) — assigned to disjoint O2-B packet.
- Root-cause resolution of `#22/#23` (`otzaria|book:3891|line:523` `invalidLocator`) — intentionally diagnostic-only in O2-A until live `#if DEBUG` logs are captured on iOS 27 Simulator.

---

## 6. Checks Performed & Unverified Platform Gates

### 6.1 Checks Directly Executed by This Reviewer (on exact `1472fdea..6fcae664`)

| Check | Command / Target | Outcome | Scope Limit |
|---|---|---|---|
| Frozen path list | `git -C <impl> diff --name-status 1472fdea..6fcae664` | **PASS** (7 exact paths) | Git metadata only |
| Whitespace / conflict markers | `git -C <impl> diff --check 1472fdea..6fcae664` | **PASS** (`exit=0`) | Git diff only |
| Upstream boundary guard | `python312 tools/verify_upstream_boundary.py --base 1472fdea --head 6fcae664` | **PASS** (`7 changes, 0 violations, 0 warnings`) | Policy path/hash guard |
| Whitespace-ignored diff audit | `git -C <impl> diff -w --stat 1472fdea..6fcae664` | **PASS** (`1429+ / 81-`) | Structural audit |
| Protected & pinned SHA-256 audit | Python `hashlib.sha256` on `git show 6fcae664:<path>` for `R27NativeInteractionAcceptanceTests.swift`, `R27_CASES.json`, `iPadLayout.swift`, `iOSTOCView.swift`, `ListContentView.swift` | **PASS** (all 5 exact match) | Blob integrity only |
| Swift 6 syntax parse (Release & `-D DEBUG`) | `swiftc -parse [-D DEBUG] -swift-version 6` on `NativeRoutingAcceptanceTests.swift` and `OtzariaGenericBackendAdapter.swift` (Swift 6.3.3 Windows) | **PASS** (`exit=0` x4) | **Syntax parse only; NOT Apple SDK typecheck** |
| Portable Swift 6 concurrency probes | `swiftc -typecheck -sdk Windows.sdk -swift-version 6 -enable-upcoming-feature MemberImportVisibility ...` on isolated scratch probes modeling `NativeRoutingAcceptanceTests` & `OtzariaGenericBackendAdapter` patterns | **PASS** (`exit=0` x2) | Portable model only; cannot prove `XCUIAutomation`/`UIKit` `@MainActor` signatures |
| Toolchain capability check | `apple-doctor --json` | `apple_sdk_available: false`, `portable_swift_only: true` | Windows workstation |

### 6.2 Independently Executed Parent Checks (Cited from Frozen Review Package, Not Re-Run Redundantly)

- `C:\Users\DAVID\AppData\Local\Programs\Python\Python312\python.exe tools/test_runtime27_interruption.py -v` on exact `c5124cd6`: **7/7 PASS** (`9.354s`; portable/mocked control flow only).
- `C:\Users\DAVID\AppData\Local\Programs\Python\Python312\python.exe tools/test_verify_xcresult_zero_skips.py -v` on exact `c5124cd6`: **10/10 PASS** (`0.727s`).

### 6.3 Remaining `NOT_RUN` Native Platform Gates (Distinct from Code Defects)

1. **Full Xcode 27.1 / iOS 27 SDK Compilation (`NOT_RUN`):** `Scripts/CI/typecheck-faithful-ui-tests.py` and `xcodebuild build-for-testing` for `Maktabah-iOSUITests` (`NativeRoutingAcceptanceTests.swift`) and `Maktabah-iOS` (`OtzariaGenericBackendAdapter.swift` in Debug and Release).
2. **Live iOS 27 Simulator Routing & SpringBoard UI Acceptance (`NOT_RUN`):** Executing `NativeRoutingAcceptanceTests` (`#4, #5, #6, #7, #8, #25, #26, #27`) to prove `"Open in “ChavrusaText”?"` / `"Open"` confirmation, same-PID warm delivery, refusal UI, replay guard, and exact-one `[NativeNavigationReceipt]` under `4065feef`/`6fcae664`.
3. **Live macOS POSIX Process-Group Signaling (`NOT_RUN`):** Real `os.killpg` / `SIGTERM` / `SIGINT` cancellation of live `xcodebuild` / `simctl` / `CoreSimulator` runners via `runtime27.py` and `run-faithful-ipad-matrix.py` (off-group `CoreSimulator` agents remain explicitly `"NOT_INDEPENDENTLY_VERIFIED"`).
4. **Live `#22/#23` `book:3891|line:523` `invalidLocator` Reproduction (`NOT_RUN`):** Capturing the new `#if DEBUG` `[OtzariaGenericBackendAdapter]` stage breadcrumbs on iOS 27 Simulator to establish root cause before any reader/backend repair.
