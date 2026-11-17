# Whole-Branch Independent Review — Phase 1 Local Repair Candidate (`4065feef..39077cf8`)

- **Review Unit / Run:** `b777cd73-0910-4aa4-8c69-90453f4f0b9a` (`kind: review`)
- **Acting Logical Identities & Mode:** `רוני (roni) | QA & Evidence` + `דנה (dana) | Security & Privacy` + `איתן (eitan) | Architecture` (`MAIN_SESSION`; zero nested subagents invoked)
- **Reviewed Manager Branch:** `cez/f51775d6` (worktree `cez/b777cd73` forked from `39077cf86e86af57226a9f3e28033545be2a2be0`)
- **Reviewed Range:** `4065feef11bd5a8997ea34364516468105778688..39077cf86e86af57226a9f3e28033545be2a2be0`
- **Combined Source Integration Checkpoint:** `84b533700c6f6401750e3f4f45d89123b55751fb` (`84b53370..39077cf8` touches only `docs/phase1-cezar/O2_EXECUTION_PLAN.md` and `docs/phase1-cezar/WHOLE_BRANCH_REVIEW_PACKET.md`)
- **Upstream & Policy Authority:** `docs/phase1-cezar/WHOLE_BRANCH_REVIEW_PACKET.md`, `docs/phase1-cezar/O2_EXECUTION_PLAN.md`, `docs/phase1-cezar/NATIVE_EXECUTION_GATE.md`, `O2A_WORK_PACKET.md`, `O2A_FIX_ROUND1.md`, `O2B_WORK_PACKET.md`, `O2B_FIX_ROUND1.md`, and `docs/architecture/UPSTREAM_INTEGRITY_POLICY.md`

---

## 1. Executive Verdicts

| Axis | Verdict | Basis |
|---|---|---|
| **Source / Spec-Compliance Verdict** *(O2-A + O2-B Work Packets, Portable Scope)* | **`approve`** *(Apple SDK / UI / POSIX runtime gates remain `NOT_RUN`)* | Strictly confined to the frozen O2-A + O2-B paths and docs; protected `Source/UI/`, `Source/Features/`, `Source/Core/`, `Source/Extensions/`, `Vendor/`, `Maktabah.xcodeproj/`, workflows, `R27_CASES.json`, `R27NativeInteractionAcceptanceTests.swift`, and `ReaderSidebarPageCoordinator.swift` are verified untouched. Prior blocking O2-A `#5` and O2-B `#1` are cleanly integrated. All `#if DEBUG` diagnostics are content-free and Release-invariant; `hq-stage2-focused-apple.inputs.json` was intentionally frozen read-only during O2. |
| **Whole-Branch Code-Quality & O3-Integration Verdict** | **`changes`** *(0 Critical, 2 Important, 6 Minor)* | **Important #1 (Combined-Branch O3 Pin Blocker):** `Scripts/CI/hq-stage2-focused-apple.inputs.json` still pins `Source` to `431748950e3285e600aa9d98d0c252856b429262` (`4065feef`), whereas `HEAD:Source` is `45a956ff63f48b641f07369064dbb960c7e254a8`; `hq-stage2-focused-apple.py --preflight-only` fails closed (`RuntimeError: Application tree drift: Source`), blocking `runtime27.py` and `hq-stage2-focused` until reconciled in a consolidated pre-O3 commit. **Important #2 (Reassessed A Deferred #1):** `confirmSpringBoardOpenDialog` evaluates `openButton.isHittable` synchronously right after `sb.alerts.count > 0`, risking SpringBoard animation flakiness across 8 URL tests on CI. Six consolidated Minor findings (A `#2`, `#3`, `#4`, `#6`, B `#3`, and non-atomic `write_matrix_report`) are ready for the single eighth fix wave. |
| **Original Phase 1 Acceptance Status** | **`NOT READY`** | **Body paging (`Contents -> Library` LTR `#21`) remains unfixed** (diagnostics only); `#22`/`#23` `book:3891|line:523` `invalidLocator` root cause remains unverified; **0 of 27** `R27_CASES.json` cases have run on the combined branch; real Xcode 27 Apple SDK builds and macOS POSIX cleanup remain `NOT_RUN`. Local repaired commits are not on GitHub (`no-push` / `no-manual-paid-CI`). |

---

## 2. Ownership, Scope & Upstream Boundary Verification (`4065feef..39077cf8`)

### 2.1 Complete Changed File Inventory (26 Paths: 10 Code/Test, 16 Doc/Board)

**10 Non-Doc Code/Test Paths:**
1. `M` `Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift` (`+103`) — O2-A SpringBoard Open-in confirmation & fail-closed teardown.
2. `M` `Scripts/CI/run-faithful-ipad-matrix.py` (`+563/-400` raw; `183` `-w` delta lines) — O2-A `main()` + `SIGINT`/`SIGTERM` interruption & bounded simulator cleanup.
3. `M` `Scripts/CI/runtime27.py` (`+165` delta) — O2-A `InterruptController` integration across all 5 `run_logged` calls & `finally:` `collect_cases` persistence.
4. `A` `Scripts/CI/runtime27_interruption.py` (`+203`) — O2-A shared `InterruptController`, `stop_owned_process_group`, `stop_owned_subprocess`, `run_isolated_cleanup_step`.
5. `M` `Source/Otzaria/Compatibility/OtzariaGenericBackendAdapter.swift` (`+204` raw; `106` `-w` delta lines) — O2-A `#if DEBUG` content-free stage & error-category logs in `section(at:)`.
6. `A` `tools/test_runtime27_interruption.py` (`+1242`) — O2-A portable interruption regression suite (`9` tests).
7. `M` `Source/ChavrusaText/Search/UI/GlobalSearchHistoryContent.swift` (`+3`) — O2-B `.foregroundStyle(.primary)` on `Text("חיפושים אחרונים")`.
8. `M` `Source/ChavrusaText/ReaderHost/ReaderSidebarPager.swift` (`+146` delta) — O2-B `ReaderSidebarPolicy.debugRounded(_:)` + `#if DEBUG` content-free sidebar breadcrumbs.
9. `M` `tools/test_native_sidebar_policy.swift` (`+30`) — O2-B 8 boundary assertions + 20 `debugRounded` assertions (`55` total).
10. `A` `tools/test_o2b_native_ux.py` (`+380`) — O2-B portable source-contract, `#if DEBUG` isolation, SDK-slice parse, and numeric regression suite (`5` tests).

**16 Documentation / Board Paths (Read-Only Verified Consistent):**
- `PROJECT_BOARD.md` (`+2` discovery note on canonical JSON hashing in `verify_xcresult_zero_skips.py`, pre-O2 at `e183e19d`).
- 15 files under `docs/phase1-cezar/`: `APP_SOURCE_GAP_MATRIX.md`, `CI_NATIVE_FORENSICS.md`, `MANAGER_EVIDENCE_REVIEW.md`, `NATIVE_EXECUTION_GATE.md`, `O1B_INDEPENDENT_SOURCE_AUDIT.md`, `O2A_FIX_ROUND1.md`, `O2A_IMPLEMENTATION_REPORT.md`, `O2A_INDEPENDENT_REVIEW.md`, `O2A_WORK_PACKET.md`, `O2B_FIX_ROUND1.md`, `O2B_IMPLEMENTATION_REPORT.md`, `O2B_INDEPENDENT_REVIEW.md`, `O2B_WORK_PACKET.md`, `O2_EXECUTION_PLAN.md`, `WHOLE_BRANCH_REVIEW_PACKET.md`.

### 2.2 Protected Trees, Pinned SHA-256s & Upstream Guard Results
- `git diff --name-status 4065feef..39077cf8 -- Source/UI Source/Features Source/Core Source/Extensions Vendor Maktabah.xcodeproj .github/workflows docs/hq-integration/runtime27/R27_CASES.json Maktabah-iOSUITests/R27NativeInteractionAcceptanceTests.swift Source/ChavrusaText/ReaderHost/ReaderSidebarPageCoordinator.swift` -> **empty** (`0` modifications).
- `git diff --name-status 84b53370..39077cf8` -> ONLY `M docs/phase1-cezar/O2_EXECUTION_PLAN.md`, `A docs/phase1-cezar/WHOLE_BRANCH_REVIEW_PACKET.md`.
- `tools/verify_upstream_boundary.py --base 4065feef --head HEAD` -> **`PASS`** (`Changes detected: 26, Violations: 0, Warnings: 0`) against both pinned `a0ed0df9` and `d46af139`. `Scripts/CI/verify-upstream-boundary.py --base 4065feef --head HEAD` -> **`PASS`** (`Violations: 0, Warnings: 0`).
- `Scripts/CI/verify-otzaria-xcode-project.py` -> **`PASS`** (`142` Otzaria Swift files, search frameworks, dictionaries).
- Protected/pinned `lf_sha256` directly recomputed at `39077cf8`:
  - `Source/UI/iOS/Views/iPadLayout.swift`: `1426ef3f6894e2a3c031f971152f1f60872b0fd6b833b4b0231f5b283297108c` (unchanged)
  - `Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift`: `6330874e885c4fd193ede4938d34f54c42e88e54b7ddd3d95eba1c45ab70aa3f` (unchanged)
  - `Source/UI/iOS/Views/Common/ListContentView.swift`: `084f8d15e37655bf5ccd42cbdc9e308ecddd9c1cfc399a12d58089737ec8f2b1` (unchanged)
  - `Source/ChavrusaText/ReaderHost/ReaderSidebarPageCoordinator.swift`: `df1bdb92cebf8a10b7bd1de6c2d17c151b5d1105c023cb0497e79fd04417eac2` (unchanged)
  - `Maktabah-iOSUITests/R27NativeInteractionAcceptanceTests.swift`: `d4ff446db4acdbb61e0ad19c14696e5194bafbba239ef86876e85a2de30e70cc` (unchanged)
  - `docs/hq-integration/runtime27/R27_CASES.json`: `d6ebe07d681e54440f58ce1b8b4945075f7047c8bce0b3a76fa98fd6fcf06875` (unchanged)

---

## 3. Combined Technical & Cross-Task Integration Review

### 3.1 Verification of Previously Addressed Blocking Findings (`O2-A #5`, `O2-B #1`)
1. **O2-A `#5` (Timeout cleanup signal protection in `runtime27.py`) — `ADDRESSED & VERIFIED INTEGRATED`:**
   - `runtime27_interruption.py:51-85` implements `cleanup_scope()` (preserving/restoring nested `cleanup_active`), `apply_metadata()`, and `_handle_signal()` recording the first signal before returning when `cleanup_active` is `True`.
   - `runtime27.py:71-118, 262-376` threads `interrupt_controller=controller` into all 5 production `run_logged` calls, wraps both `run_logged`'s `except BaseException:` cleanup and `main()`'s `finally:` `collect_cases` block in `cleanup_scope()`, keeps `TimeoutExpired` `status="FAIL"` (`exit 1`) even if signalled during cleanup, preserves `EXECUTED_PASS` on normal runs and 3-arg standalone `run_logged` compatibility, and registers `runtime27_interruption.py` in `helper_inputs_sha256` (`:306`).
2. **O2-B `#1` (Non-trapping `#if DEBUG` numeric formatting in `ReaderSidebarPager.swift`) — `ADDRESSED & VERIFIED INTEGRATED`:**
   - `ReaderSidebarPolicy.debugRounded(_ value: Double) -> String` (`:20-26`) uses `Int(exactly: value.rounded()).map(String.init) ?? String(describing: value)` with pure Swift stdlib inside the policy block.
   - Both `selectPage` (`:140-141`) and `ReaderSidebarSplitConfigurationController.debugRounded(_:)` (`:477-479`) delegate to it under `#if DEBUG`; `rg -n 'Int\(|rounded\('` shows no remaining `Int(value.rounded())` call site.

### 3.2 Signal, Timeout, Cleanup Bounds & Partial-Receipt Truthfulness
- `run-faithful-ipad-matrix.py` (`main()`, `:24-575`) catches `SIGINT`/`SIGTERM` via `InterruptController`, halts device advancement (`break` at `:112, 536`), overwrites prior `EXECUTED_PASS` on an interrupted device (`largeText` interruption -> `device["status"] = "INTERRUPTED"` at `:189, 199`), skips the 60s `collect-runtime27-palette-log.py`, bounds interrupted simulator shutdown/delete to `5s`/`5s`, records `cleanupErrors` / `ownedSimulatorCleanup = "FAIL"` on teardown failure, and returns `130` (`INTERRUPTED_UI_UNVERIFIED`).
- `runtime27_interruption.stop_owned_process_group` (`:88-149`) targets only `process.pid` (`start_new_session=True`), handles transient probe `OSError` without skipping `SIGKILL`, requires `not send_errors` for `GONE_CHECKED`, and explicitly keeps `"off_group_simulator_agents": "NOT_INDEPENDENTLY_VERIFIED"`.
- Cross-script check: `runtime27.py:336-344` propagates matrix `INTERRUPTED_UI_UNVERIFIED` (`return 130`), and `runtime27.py:364-373` catches `BaseException` around `collect_cases` so `result.json` is still written. Three deferred/hardening gaps remain in `run-faithful-ipad-matrix.py` (Findings 5, 6, 8 below).

### 3.3 URL Delivery, PID, Scene, Refusal & Replay Assertions (`NativeRoutingAcceptanceTests.swift`)
- Preserves real `simctl openurl` sidecar transport, 5-key credential-free ack check, token-redaction check, `originalPID == actualPID` same-process proof, refusal (`"Unable to open link"`), replay exact-one `[NativeNavigationReceipt]` check, and `workspaceSidecarURL()` scene validation.
- Rejects pre-existing SpringBoard alerts (`:136-140`), restricts confirmation to exact `"Open in “ChavrusaText”?"` / `"Open in \"ChavrusaText\"?"` titles (`:13-16`) and `"Open"` action (never `"Cancel"`), waits via `MainActor.assumeIsolated` without capturing non-`Sendable` elements (`:176-184`, with `hadHistoryBefore` avoiding `testReplay` short-circuiting), and fails closed in `tearDownWithError()` while cancelling up to 8 leftover Chavrusa Open-in alerts (`:30-54`).
- `test-simulator-11-reader.log:1980-2004` from `43891893650` confirms SpringBoard's exact alert title `"Open in “ChavrusaText”?"` and `"Cancel"` button label on `iOS 27.2`. One animation-timing flakiness hazard in `confirmSpringBoardOpenDialog` warrants upgrade to `Important` (Finding 2 below), and real iOS 27 execution remains `NOT_RUN`.

### 3.4 Swift DEBUG / Release / SDK Slices, Contrast & Diagnostic Privacy
- **Release invariance:** All diagnostics in `OtzariaGenericBackendAdapter.swift` (`:48-58, 64-66, 83-85, ... , 186-214`) and `ReaderSidebarPager.swift` (`:68, 125-129, 137-143, 166-188, 286-288, ... , 476-496`) compile out completely when `!DEBUG`. `GlobalSearchHistoryContent.swift:34` uses standard SwiftUI `.foregroundStyle(.primary)` matching `GlobalSearchHeader.swift:67` (iOS 26.2 target, already used on row labels at `:21`).
- **SDK slices & Swift 6 concurrency:** `ReaderSidebarDebugLog` and `ReaderSidebarPageDiagnosticObserver` sit above `// BEGIN SELF-CONTAINED SIDEBAR SEARCH ADAPTERS` (`:190`) and `ReaderSidebarSplitConfiguration:` (`:284`). Extracted `ReaderSidebarSplit.swift` (`runtime27.py:268-277`, `typecheck-faithful-ui-tests.py:96-105`) and `ReaderSidebarNativeSearchSDK.swift` (`typecheck-faithful-ui-tests.py:70-80`) contain zero `OtzariaFileLogger` / `iOSNavigationManager` / `ReaderSidebarPageCoordinator` references and pass Swift 6 frontend parse in both Release and `-D DEBUG`. Portable Swift 6.3.3 concurrency probes (`MemberImportVisibility`, `InferIsolatedConformances`, `NonisolatedNonsendingByDefault`) pass for `OtzariaGenericBackendAdapter`, `ReaderSidebarSplitConfiguration`, and `NativeRoutingAcceptanceTests` isolation shapes; `debugTypeName(Optional<Subclass>)` unwraps cleanly to concrete dynamic type names (`SubView` / `"nil"`). Real Apple `SwiftUI`/`UIKit`/`XCUIAutomation` SDK compilation remains **`NOT_RUN`**.
- **Privacy (`dana`):** Zero raw URLs, search queries, book titles, `heRef`, `nash`, `stableKey`, or credentials enter logs. `OtzariaGenericBackendAdapter.debugErrorCategory` maps errors to fixed enum names or `nsError:<domain>:<code>`, and `ReaderSidebarPager` skips `.changed` events (`:466`) and logs only geometry, boolean flags, enum states, and runtime class names.

---

## 4. All Actionable Findings (Whole-Branch)

### 1. `[Important — Blocks O3 / `runtime27` Preflight]` `Scripts/CI/hq-stage2-focused-apple.inputs.json` Source Tree Pin Drift
- **Location:** `Scripts/CI/hq-stage2-focused-apple.inputs.json:2-4` (`"application_source_sha"`, `"application_trees.Source"`) vs `Scripts/CI/hq-stage2-focused-apple.py:68-71`, `Scripts/CI/runtime27.py:314-316`, and `Scripts/CI/verify-runtime27-release-gate.py:59`.
- **Evidence / Reproducer:** Executed `python.exe Scripts/CI/hq-stage2-focused-apple.py --preflight-only` on `39077cf8` -> exited **`1`** with `RuntimeError: Application tree drift: Source`. `hq-stage2-focused-apple.inputs.json` still pins `"Source": "431748950e3285e600aa9d98d0c252856b429262"` (`d9ab40fb` / `4065feef`), whereas combined `HEAD:Source` is **`45a956ff63f48b641f07369064dbb960c7e254a8`**.
- **Consequence:** While O2 packets intentionally froze `hq-stage2-focused-apple.inputs.json`, any O3 `runtime27.py` or `hq-stage2-focused` build on this combined branch will fail immediately at `preflight()` before building `Maktabah.app`.
- **Minimal Correction:** In the consolidated pre-O3 integration commit (after any final source edits settle), update `Scripts/CI/hq-stage2-focused-apple.inputs.json` `"application_source_sha"` and `"application_trees.Source"` to match the final combined tree (`git rev-parse HEAD:Source`), verify `hq-stage2-focused-apple.py --preflight-only` exits `0`, and keep `Vendor`, `Maktabah.xcodeproj`, `artifacts`, and `resources` unchanged.

### 2. `[Important — Reassessed from A Deferred #1]` Single-Shot `openButton.isHittable` Check Without Settling Wait
- **Location:** `Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift:92-113` (`confirmSpringBoardOpenDialog`) and `:176-188` (`openInExistingProcess`).
- **Evidence:** `dialogOrDirectDelivery` (`:176-185`) returns as soon as `sb.alerts.count > 0`, and `:186-187` immediately invokes `confirmSpringBoardOpenDialog`, which performs a single synchronous snapshot (`alerts.count == 1`, title match, `openButton.exists && openButton.isHittable`) and fails closed (`XCTFail` + `throw`) with no wait for SpringBoard alert presentation animation settling.
- **Consequence:** Never causes a false pass, but across 8 sequential URL deliveries (`#4, #5, #6, #8, #25, #26`, plus `2x` in `#27`) on `iOS 27.2` Simulator, a single transient `isHittable == false` during SpringBoard's presentation transition will fail a ~90-minute `runtime27` CI run.
- **Minimal Correction:** Inside `confirmSpringBoardOpenDialog`, wait briefly (e.g., `2s` `XCTNSPredicateExpectation` / `XCTWaiter`) for `springboard.alerts.count == 1` and a unique `Open` button satisfying `exists && isHittable` before failing closed with `captureSystemDialogEvidence`.

### 3. `[Minor — A Deferred #2]` Teardown Cancellation Loop Ignores `.timedOut` on `reduced` Expectation
- **Location:** `Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift:46-52`.
- **Evidence:** `_ = XCTWaiter.wait(for: [reduced], timeout: 5)` ignores timeout failure and unconditionally runs `cancelledCount += 1` up to 8 iterations. Note `43891893650` (`test-simulator-11-reader.log:1979-2025`) also showed SpringBoard presenting queued prompts sequentially (`alerts.count == 1` before and after cancel).
- **Consequence:** If a leftover prompt fails to dismiss, teardown stalls up to `40s` and logs an inflated `cancelledChavrusaPrompts` value (still fails closed unconditionally at `:53`).
- **Minimal Correction:** Break out of the loop and do not increment `cancelledCount` unless `XCTWaiter.wait(for: [reduced], timeout: 5) == .completed` (if sequential queued alerts still leave `alerts.count == 1` transiently, check or briefly settle before breaking).

### 4. `[Minor — A Deferred #3]` Normal Teardown Retains Helper Handles and Overwrites Post-Deletion Cleanup/Diagnostic Status on Late Signal
- **Location:** `Scripts/CI/run-faithful-ipad-matrix.py:498-535` vs `:210-270`.
- **Evidence:** Normal cleanup (`:500-513`) calls `.stop()`/`.close()` on `native_url_delivery`, `hid_comparison`, `palette_log_stream`, `recording`, and `recording_log` without resetting those locals to `None`. If `SIGINT`/`SIGTERM` arrives later in `:516-532` (e.g., during 60s `collect-runtime27-palette-log.py`, 300s `shutdown`, 120s `delete`, or `write_matrix_report`), `except KeyboardInterrupt:` (`:533-535`) calls `run_interrupted_cleanup()`, which double-stops already-closed helpers (`PaletteLogStream.stop()` rewrites `palette-input-11-window-stream.json`), overwrites `device["paletteInputDiagnosticExitCode"]` with `"SKIPPED_ON_INTERRUPTION"` (`:240`), and re-runs `shutdown`/`delete` (`:249-260`) on an already-deleted UDID, turning `ownedSimulatorCleanup = "PASS"` into `"FAIL"`.
- **Minimal Correction:** Assign each helper variable to `None` immediately after stopping/closing it at `:500-513`, use `device.setdefault("paletteInputDiagnosticExitCode", ...)` at `:240`, and skip `shutdown`/`delete` at `:249-260` when `device.get("ownedSimulatorCleanup") == "PASS"`.

### 5. `[Minor — A Deferred #4]` Unguarded Window Between `simctl create` UDID Creation and Inner Device `try:` Block
- **Location:** `Scripts/CI/run-faithful-ipad-matrix.py:100-126` vs `:273`.
- **Evidence:** `create_compatible_ipad(size)` (`:100-103`) returns a freshly created simulator `udid` before `device` dict creation (`:125-126`) and nested function definitions (`:134-272`) reach `try:` at `:273`. A `SIGTERM` arriving right after `simctl create` returns or during `:125-272` unwinds to outer `except KeyboardInterrupt:` (`:554`) without shutting down or deleting that newly created simulator.
- **Minimal Correction:** Initialize `udid = None` and helper variables before `create_compatible_ipad` inside the `try:`/`finally:` scope (and wrap `run_interrupted_cleanup` using `with controller.cleanup_scope():`), guarding `shutdown`/`delete` on `if udid is not None:`.

### 6. `[Minor — A Deferred #6 + New Observation]` Dead Stubs and Unreachable `recording_wait_error` Escalation in `tools/test_runtime27_interruption.py`
- **Location:** `tools/test_runtime27_interruption.py:126-128, 147-151, 410-415, 511-555`.
- **Evidence:**
  1. Test 6 (`:538-552`) contains dead `fake_collect_cases`, unused `collect_cases` patch, and unused `report` assignment (plus unused stub files at `:511-536`).
  2. In Test 4 (`:410-415`, `"recording_timeout_and_second_signal"`), `"recording_wait_error": "timeout"` never actually triggers `TimeoutExpired` or `popen_kill` on `recording`: `FakeProcess.terminate` (`:151`, used on Windows) and `FakeProcess.send_signal` (default `recording_exit_on_sigint=True` at `:147-148`) set `self._terminated = True` before `wait()` (`:127`) checks `if not self._terminated:`. Direct observation confirmed `A_TEST4_RECORDING_EVENTS = ['popen', 'popen_terminate', 'popen_wait']` and `A_TEST4_CLEANUP_ERRORS = None`. *(Note: `stop_owned_subprocess` `kill()` escalation is still genuinely tested via `xcodebuild` in Test 1.)*
  3. Test 4 case 1 does not assert `dev["cleanupErrors"]` keys, and `runtime27.py:337-344` (non-signaled parent propagating matrix exit `130` + `INTERRUPTED_UI_UNVERIFIED`) lacks a dedicated unit test.
- **Minimal Correction:** Remove dead setup (`:511-536, 538-552`), add `"recording_exit_on_sigint": False` / non-terminating recording branch in Test 4 (and assert `dev["cleanupErrors"]` + `recording` `popen_kill`), and add a small test for `runtime27.py:337-344`.

### 7. `[Minor — B Deferred #3]` Fragile `#else` / Compound-Condition Parsing, Missing `"restore "` Marker, and Hardcoded SDK Path in `tools/test_o2b_native_ux.py`
- **Location:** `tools/test_o2b_native_ux.py:28-37`, `:55-75`, and `:114-122`.
- **Evidence (reproduced directly):**
  - `line_in_debug_guard(['#if canImport(UIKit)', 'let a = 1', '#else', 'let b = 2', '#endif'], 3)` returned **`True`**; `line_in_debug_guard(['#if false && DEBUG', ...], 1)` and `line_in_debug_guard(['#if DEBUG || FEATURE_X', ...], 1)` both returned **`True`**.
  - Lines `114-122` omit `"restore "` from the required marker tuple (though `:155-166` still scans `onDiagnostic?("restore ...")`).
  - `WINDOWS_SDK_CANDIDATE` (`:28-30`) hardcodes Swift `6.3.3` under `C:\Users\DAVID\...` when `SDKROOT` is unset.
- **Consequence:** Accurate on current `ReaderSidebarPager.swift`, but weakens future `#if DEBUG` guard regression checks and portability if another Swift version is installed without `SDKROOT`.
- **Minimal Correction:** Track exact positive/negated `DEBUG` stack state in `line_in_debug_guard` (never flipping non-DEBUG `#if` `#else` to `True`, and requiring `DEBUG` not combined with `||` or `false &&`), add `"restore "` to `:114-122`, and discover installed `%LOCALAPPDATA%\Programs\Swift\Platforms\*\Windows.platform\Developer\SDKs\Windows.sdk` when `SDKROOT` is unset.

### 8. `[Minor — New Integration Hardening]` Non-Atomic `faithful-ipad-matrix.json` Overwrites Under `SIGKILL`
- **Location:** `Scripts/CI/run-faithful-ipad-matrix.py:77-79` (`write_matrix_report`), invoked at `:206, 244, 267`.
- **Evidence:** `write_matrix_report()` uses `.write_text(...)` directly instead of temp-file + `.replace(...)` (used by `runtime27-url-delivery.py:110-113` and `runtime27-hid.py:169-172`). Because `runtime27.py`'s `stop_owned_process_group` (`grace_seconds=5`) sends uncaught `SIGKILL` to the matrix process group if cleanup exceeds `5s` (e.g., `5s` shutdown + `5s` delete), a `SIGKILL` landing during `.write_text(...)` at `:244` or `:267` can truncate the already-flushed `:206` receipt.
- **Minimal Correction:** Write JSON to `faithful-ipad-matrix.json.tmp` and call `.replace(artifacts / "faithful-ipad-matrix.json")`.

---

## 5. Deferred-Item Explicit Disposition Ledger

| Source & Item | Historic Label | Reassessed Severity | Final Disposition |
|---|---|---|---|
| `O2A` `#1` (`NativeRoutingAcceptanceTests.swift:107-113`) | Minor | **Important** | **`FIX_IN_CONSOLIDATED_WAVE`** — 8 sequential SpringBoard confirmations amplify transient `isHittable` animation-race risk on ~90m native CI. |
| `O2A` `#2` (`NativeRoutingAcceptanceTests.swift:46-52`) | Minor | Minor | **`FIX_IF_CONSOLIDATED_WAVE_OPEN`** — Check `== .completed` before incrementing `cancelledCount` / continuing loop. |
| `O2A` `#3` (`run-faithful-ipad-matrix.py:498-535`) | Minor | Minor | **`FIX_IF_CONSOLIDATED_WAVE_OPEN`** — Clear helper locals to `None` and guard post-deletion `shutdown`/`delete` & exit code. |
| `O2A` `#4` (`run-faithful-ipad-matrix.py:116-126,273`) | Minor | Minor | **`FIX_IF_CONSOLIDATED_WAVE_OPEN`** — Close post-`simctl create` pre-`try:` UDID leak window. |
| `O2A` `#6` (`test_runtime27_interruption.py:538-552,...`) | Minor | Minor | **`FIX_IF_CONSOLIDATED_WAVE_OPEN`** — Remove dead stubs, fix `recording_wait_error` test no-op (`Test 4`), assert `cleanupErrors` + matrix-130 propagation. |
| `O2B` `#3` (`test_o2b_native_ux.py:28-37,55-75,114-122`) | Minor | Minor | **`FIX_IF_CONSOLIDATED_WAVE_OPEN`** — Tighten `line_in_debug_guard`, add `"restore "`, generalize Windows SDK discovery. |
| *Prior blockers:* `O2A` `#5`, `O2B` `#1` | Important | — | **`ADDRESSED & VERIFIED`** on combined branch `39077cf8` (and `O2B` `#2` report wording corrected). |

---

## 6. Checks Actually Performed & Scope Limits

### 6.1 Checks Executed Directly by This Reviewer on `39077cf8` (Read-Only)
| Check | Command / Target | Outcome | Scope Limit |
|---|---|---|---|
| Range & post-checkpoint delta | `git diff --name-status 4065feef..HEAD` & `84b53370..39077cf8` | **PASS** (26 paths; `84b53370..39077cf8` doc-only) | Git metadata only |
| Protected trees & whitespace | `git diff --name-status ... -- Source/UI Source/Features ...` & `git diff --check` | **PASS** (`0` protected changes; `exit 0`) | Git diff only |
| Upstream boundary guard (`a0ed` & `d46a`) | `python.exe tools/verify_upstream_boundary.py` & `Scripts/CI/verify-upstream-boundary.py` | **PASS** (`26` changes, `0` violations, `0` warnings) | Policy path/hash guard |
| Xcode target membership | `python.exe Scripts/CI/verify-otzaria-xcode-project.py` | **PASS** (`142` Otzaria files, frameworks, dictionaries) | `project.pbxproj` parser |
| Stage-2 build-input preflight | `python.exe Scripts/CI/hq-stage2-focused-apple.py --preflight-only` | **FAIL (`exit=1`)** (`Application tree drift: Source`) | Pin `43174895` != `HEAD:Source` `45a956ff` |
| Protected / pinned `lf_sha256` audit | Python `hashlib.sha256` (6 paths) | **PASS** (all 6 exact match) | File integrity only |
| Python bytecode compile | `python.exe -m py_compile` (5 CI/test `.py` files) | **PASS** (`exit=0`) | Syntax/bytecode only |
| Swift 6 syntax parse (Release & `-D DEBUG`) | `swiftc -parse [-D DEBUG] -swift-version 6` on 4 Swift files + `#if true` Apple pager + extracted `ReaderSidebarSplit` & `ReaderSidebarNativeSearchSDK` | **PASS** (`exit=0`) | **Syntax parse only; NOT Apple SDK typecheck** |
| Focused Swift 6 concurrency & `debugTypeName` probes | Scratch probes with `-swift-version 6 -enable-upcoming-feature MemberImportVisibility -enable-upcoming-feature InferIsolatedConformances -enable-upcoming-feature NonisolatedNonsendingByDefault` (`Release` & `-D DEBUG`) | **PASS** (`exit=0`; `SubView`, `"nil"`) | Portable model only; NOT Apple `SwiftUI`/`UIKit`/`XCUIAutomation` SDK |
| Focused Python `B #3` & `A Test 4` probes | Scratch `probe_py.py` inspecting `line_in_debug_guard` and Test 4 `recording_wait_error` events | **REPRODUCED** (`#else` -> `True`, `recording` `['popen', 'popen_terminate', 'popen_wait']`) | Portable Python probe |

### 6.2 Parent Post-Merge Checks Cited (Not Redundantly Re-Run)
Executed on combined branch (`84b53370`/`39077cf8`) with Python 3.12 and per-command Windows `SDKROOT`: `tools/test_runtime27_interruption.py -v` (`9/9 PASS`, `11.429s`), `tools/test_verify_xcresult_zero_skips.py -v` (`10/10 PASS`, `0.628s`), `tools/test_o2b_native_ux.py -v` (`5/5 PASS`, `5.980s`), `tools/hq-sidebar-check.py` (`55` compiled policy assertions + syntax checks `PASS`), `tools/global-search-presentation-tests.py` (`42+18 PASS` on final B code).

---

## 7. Unmet Original Phase 1 Native & Owner Gates (`NOT READY`)

1. **Remote Checkout & `hq-stage2` Source Pin Gates:** `NATIVE_EXECUTION_GATE.md` records local-only commits (`no-push`, `no-manual-paid-CI`, prior `9c484269` HTTP 422 on GitHub), and `Scripts/CI/hq-stage2-focused-apple.inputs.json` currently blocks `hq-stage2-focused-apple.py --preflight-only` / `runtime27.py` due to `Source` tree drift (`45a956ff` != `43174895`).
2. **Apple Xcode 27 SDK Compilation (`NOT_RUN`):** `Maktabah.app`, `Maktabah-iOSUITests`, `ReaderSidebarSplit`, `ReaderSidebarNativeSearchSDK`, `Phase1SidebarSDK`, `FaithfulToolbarSDK` (Debug & Release).
3. **All 27 Native `R27_CASES.json` Cases (`NOT_RUN` on combined branch; historical `4065feef` run `43891893650` cancelled at `9 PASS / 13 FAIL / 1 STARTED_INTERRUPTED / 4 NOT_RUN`):**
   - Warm/post-background/unknown-version/wrong-backend/replay URL delivery (`#4, #5, #6, #8, #25, #26, #27`): **`NOT_RUN`**.
   - History AX contrast audit (`#15`, `'חיפושים אחרונים'`): **`NOT_RUN / OPEN`**.
   - Sidebar LTR `Contents -> Library` body swipe (`#21`): **UNFIXED** (diagnostics only) & **`NOT_RUN / OPEN`**.
   - Sidebar RTL paging (`#22`) & scene state (`#23`) + `book:3891|line:523` `invalidLocator` root cause: **`NOT_RUN / OPEN`**.
   - Clean alert-free `original_reader6` Pad (`#1, #2, #3`, ensuring `#2` evaluates `reader-more-menu` with `reader-text.isHittable == true`) & Phone (`#16, #17, #18`): **`NOT_RUN / OPEN`**.
   - `11-window` (`#19, #20`) & live macOS POSIX `os.killpg` / `SIGTERM` / `SIGINT` cleanup (`off_group_simulator_agents`: `NOT_INDEPENDENTLY_VERIFIED`): **`NOT_RUN / OPEN`**.
4. **Physical iPad / Owner Release / Main Merge Gates:** Remain **`OPEN / BLOCKED_OWNER`**. **Phase 1 is NOT READY.**
