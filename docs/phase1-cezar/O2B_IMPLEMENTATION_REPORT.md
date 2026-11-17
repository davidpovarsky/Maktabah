# Phase 1 O2-B Implementation & Diagnostic Report

- **Task Order / Unit:** `O2-B` (`335b7590-a7cb-41bf-92fb-9d47612d1d48`)
- **Logical Roles & Execution Mode:** `maya | Native UX` + `noam | Engineering` (`MAIN_SESSION`; zero nested subagents invoked)
- **Worktree / Branch:** `cez/335b7590`
- **Base Commit SHA:** `63eea4200420972344c22334149dc33a663c2ef1` (O2-A locally integrated at `9c4842691ecd86087867698fc2eeb9a374d05b7f`)
- **Result Commit SHA:** Recorded on branch `cez/335b7590` at commit creation and reported in `cez task report`

---

## 1. Authorized Scope & Changed Paths

Changes are strictly confined to 5 of the 6 writable paths authorized by `docs/phase1-cezar/O2B_WORK_PACKET.md`:

1. `Source/ChavrusaText/Search/UI/GlobalSearchHistoryContent.swift` — Added explicit dynamic `.foregroundStyle(.primary)` to `Text("חיפושים אחרונים")` inside the History `Section` `header` against `Color.appBackground`, matching `GlobalSearchHeader.swift:65-67`.
2. `Source/ChavrusaText/ReaderHost/ReaderSidebarPager.swift` — Added bounded, `#if DEBUG`-only, content-free gesture/lifecycle breadcrumbs (`attach`, `restore`, `shouldReceive`, `shouldBegin`, `requireFail`, `panState`, `swipeDecision`, `pageChanged`) routed via `OtzariaFileLogger.shared.log("[ReaderSidebarPager] ...")` outside the standalone `ReaderSidebarSplitConfiguration` and `ReaderSidebarNativeSearchSDK` extraction slices. Preserved `ReaderSidebarPolicy` thresholds/directions and UIKit gesture delegate behavior unchanged.
3. `tools/test_native_sidebar_policy.swift` — Appended 8 boundary assertions on `ReaderSidebarPolicy.swipeSelectsContents` (exact `44pt` LTR/RTL forward/return thresholds, diagonal `51/40` boundary, `.nan` vertical and `.infinity` horizontal rejection) without altering or weakening any existing assertion.
4. `tools/test_o2b_native_ux.py` — Added narrow O2-B source-contract, `#if DEBUG` isolation, SDK-slice self-containment, Swift 6 frontend syntax-parse (Release and `-D DEBUG`), and portable policy harness with explicit non-native claim limits.
5. `docs/phase1-cezar/O2B_IMPLEMENTATION_REPORT.md` — This implementation, diagnostic, and verification report.

`Source/ChavrusaText/ReaderHost/ReaderSidebarPageCoordinator.swift` was inspected and **left untouched** (zero concrete cause required editing it). No files in `Source/UI/`, `Source/Features/`, O2-A paths, `Maktabah-iOSUITests/`, `docs/hq-integration/runtime27/R27_CASES.json`, `.github/workflows/`, `PROJECT_BOARD.md`, shared HQ, or Asana were modified.

---

## 2. Workstream Findings & Changes

### 2.1 History Section Heading Contrast (`Source/ChavrusaText/Search/UI/GlobalSearchHistoryContent.swift`)

- **Observed Failure (`43891893650`):** `F89034B9-450C-47C1-ABD3-D7B3CD768592.txt` from `GlobalSearchNativeAcceptanceTests/testHeaderAndHistoryNativeAccessibilityAudit` (`GlobalSearchNativeAcceptanceTests.swift:466`) reported `Contrast failed for SwiftUI.AccessibilityNode` on `StaticText` label `'חיפושים אחרונים'` (`GlobalSearchHistoryContent.swift:31`).
- **Source Pattern Match:** `GlobalSearchHistoryContent` renders a `.listStyle(.plain)` `List` over `Color.appBackground` (`RGB(237,217,184)` in custom light sepia theme). Row labels already applied `.foregroundStyle(.primary)` (`line 21`), whereas `Text("חיפושים אחרונים")` (`line 31`) inherited SwiftUI's subdued section-header foreground style. `GlobalSearchHeader.swift:65-67` resolved the analogous contrast gap on `Color.appBackground` with `.foregroundStyle(.primary)`.
- **Change:** Applied `.foregroundStyle(.primary)` directly to `Text("חיפושים אחרונים")` inside the `Section` `header:` builder, preserving `List`/`Section`, RTL layout, localization, Dynamic Type, `ContentUnavailableView`, `"נקה הכול"`, row actions, and all existing accessibility identifiers.
- **Claim Limit:** Local source-contract and Swift 6 syntax checks establish only that `.foregroundStyle(.primary)` is explicitly present and syntactically valid; actual iOS contrast/AX audit acceptance remains `NOT_RUN` / `OPEN`.

### 2.2 Sidebar Body-Swipe Investigation & Bounded `DEBUG` Diagnostics (`Source/ChavrusaText/ReaderHost/ReaderSidebarPager.swift`)

- **Observed Failure (`43891893650`):** In `Sidebar11201AcceptanceTests/testSidebarBodyPagingLTR` (`test-simulator-11-reader.log:2689-2783`), Swipe 1 (`Library -> Contents`, `[0.75, 0.50] -> [0.25, 0.50]`, `500 px/s`) switched to `page-1` (`022DC794-AEA3-4BE6-95CD-00FFD61A307A.txt`: `toc-column` visible, `reader-sidebar-page-1` selected), whereas Swipe 2 (`Contents -> Library`, `[0.25, 0.50] -> [0.75, 0.50]`, `500 px/s`) kept `reader-sidebar-page-1` selected (`1E753D2E-0E63-47FC-8776-9FF66256263B.txt`) and timed out at `Sidebar11201AcceptanceTests.swift:292`. `#22` (`testSidebarBodyPagingRTL`) and `#23` (`testSidebarSceneStateSurvivesBackgroundAndRotation`) failed earlier at `FaithfulReaderUIAcceptanceTests.swift:363` (`invalidLocator`), leaving RTL body paging and rotation/background persistence unexecuted on `4065feef`.
- **Authoritative UIKit Delegate Semantics Verification:**
  - Read-only `apple-api UIKit UIGestureRecognizerDelegate` (`davidpovarsky/apple-devtools` run `44085790390`, `apple-sdk-info` run `44085783929`) and Apple Developer Documentation confirm that `gestureRecognizer(_:shouldBeRequiredToFailBy:)` returning `true` makes `otherGestureRecognizer` wait for `gestureRecognizer` (`bodyPan`) to fail before recognizing.
  - Thus `ReaderSidebarSplitConfigurationController`'s delegate arbitration direction (`otherView === host || otherView.isDescendant(of: host)`) matches its documented intent: horizontal `bodyPan` precedes vertical/page pans in `primary`, and `ReaderSidebarPolicy.swipeSelectsContents` maps `horizontal > 0` in LTR (`isRTL == false`) to `false` (`.library`) and `horizontal < 0` to `true` (`.contents`).
- **Why No Gesture/Layout Behavior Was Mutated:**
  - On `4065feef`, `ReaderSidebarPager.swift` emits zero runtime gesture breadcrumbs. Source inspection alone cannot distinguish on Windows between competing iOS 27 runtime hypotheses for Swipe 2 failure (e.g. `NavigationStack` / `UINavigationController` `interactiveContentPopGestureRecognizer` competing on rightward LTR drags after `5620838d` wrapped `TabView` in `NavigationStack`; `bodyPan` `shouldReceive` / `shouldBegin` / `.cancelled` before `.ended` while `TabView(.page)` was blocked by `shouldBeRequiredToFailBy`; or `TabView(.page)` vs `toc-column` interaction). Per `O2B_WORK_PACKET.md`, no speculative gesture/layout rewrite was invented.
- **Bounded `DEBUG` Diagnostic Instrumentation Added:**
  - `ReaderSidebarPager` (`ReaderSidebarDebugLog.log` -> `OtzariaFileLogger.shared.log("[ReaderSidebarPager] ...")`, compiled under `#if DEBUG` only):
    - `swipeDecision page=<library|contents> isRTL=<bool> dx=<int> dy=<int> target=<library|contents|nil>`
    - `pageChanged from=<library|contents> to=<library|contents>` (via `ReaderSidebarPageDiagnosticObserver`)
  - `ReaderSidebarSplitConfiguration` / `ReaderSidebarSplitConfigurationController` (standalone `SwiftUI`/`UIKit` slice passes an optional `#if DEBUG var onDiagnostic: (@MainActor (String) -> Void)? = nil`, preserving `Scripts/CI/runtime27.py:268-277` and `Scripts/CI/typecheck-faithful-ui-tests.py:95-115` zero-app-dependency extraction):
    - `attach` (only when `bodySwipeHost` attaches/changes): host type, `viewBounds`, `hostBounds`, `collapsed`, `tiles`.
    - `restore` (only when `bodySwipeHost != nil || configuredSplit != nil`).
    - `shouldReceive` (once per touch down): `eligible`, `hasWindow`, `hidden`, `alphaPositive`, `inBounds`, integer `loc`, `bounds`, and `touchView` class name.
    - `shouldBegin` (once per recognition check): `allowed`, rounded `vx`/`vy`, direction (`left`/`right`/`zero`/`nonFinite`).
    - `requireFail` (only when `otherGestureRecognizer !== bodyPan && otherGestureRecognizer is UIPanGestureRecognizer`): `result`, `other` recognizer class, `otherView` class, `inHost`, `enabled`, `state`.
    - `panState` (in `bodyPanEnded`, explicitly skipping `sender.state == .changed`): logs continuous target-action states (`began`, `ended`, `cancelled`) with `hasWindow` and non-trapping `dx`/`dy`. A continuous `UIPanGestureRecognizer` target-action does not emit `.failed` directly from `.possible` (pre-recognition rejection is observed via `shouldReceive`/`shouldBegin`/`requireFail`, while `debugStateName` formats all `UIGestureRecognizer.State` cases exhaustively for both `requireFail` and `panState`).
  - All breadcrumbs are `#if DEBUG`-gated, content-free (zero search queries, book titles, text payloads, URLs, or accessibility labels), and never log `.changed` events.

---

## 3. Portable Verification Evidence (Windows Host)

Toolchain: `C:\Users\DAVID\AppData\Local\Programs\Python\Python312\python.exe` (`Python 3.12.5`) and `Swift version 6.3.3` (`x86_64-unknown-windows-msvc` with user `SDKROOT=C:\Users\DAVID\AppData\Local\Programs\Swift\Platforms\6.3.3\Windows.platform\Developer\SDKs\Windows.sdk`).

### 3.1 Pre-Repair RED Run (Unmodified `63eea420`)

Command:
`python.exe tools\test_o2b_native_ux.py -v`
- Result: `Ran 4 tests in 1.498s` -> `FAILED (failures=2)`
  - `test_history_heading_uses_dynamic_primary_foreground`: `FAIL` (`Text("חיפושים אחרונים")` lacked `.foregroundStyle(.primary)`).
  - `test_sidebar_diagnostics_are_debug_gated_bounded_and_content_free`: `FAIL` (`Missing expected sidebar diagnostic marker: 'attach '`).
  - `test_existing_portable_sidebar_policy_passes`: `ok`
  - `test_sidebar_sdk_slices_stay_self_contained_and_parse`: `ok`

### 3.2 Post-Repair GREEN Verification (Latest Commands on Final Edits)

- `python.exe -m py_compile tools\test_o2b_native_ux.py` -> exit `0`
- `python.exe tools\test_o2b_native_ux.py -v` -> `Ran 4 tests in 1.561s` -> `OK` (exit `0`):
  - Verifies `GlobalSearchHistoryContent` heading `.foregroundStyle(.primary)` + structure/IDs; `#if DEBUG` gating, non-`.changed` guard, content-free rules, and preserved direction/arbitration invariants in `ReaderSidebarPager.swift`; standalone `ReaderSidebarSplit.swift` and `ReaderSidebarNativeSearchSDK.swift` extraction and Swift 6 `-frontend -parse` (Release and `-D DEBUG`, Windows and active `#if true` Apple branch); and `Scripts/CI/test-native-sidebar-policy.py`.
- `python.exe Scripts\CI\test-native-sidebar-policy.py` -> exit `0` (`PASS: 35 actual sidebar width/RTL/gesture policy assertions; no device UI claim`)
- `python.exe tools\hq-sidebar-check.py` -> exit `0` (`PASS: 35 actual sidebar width/RTL/gesture policy assertions; no device UI claim` / `PASS: five changed/prepared Swift files parsed, including the pager Apple branch; diff whitespace clean` / `NOT_RUN: Apple typecheck, app build, simulator/device, gesture arbitration and visual acceptance`)
- `python.exe tools\global-search-presentation-tests.py` -> exit `0` (`PASS: 42 Global Search presentation/orchestration assertions...` + `PASS: 18 ACTUAL Search+Execution paging/cancellation assertions...` — executed on final `GlobalSearchHistoryContent.swift` and `ReaderSidebarPager.swift` code)
- `python.exe tools\test_verify_xcresult_zero_skips.py` -> baseline `10/10 OK` (no test/CI files modified by O2-B)
- `python.exe tools\test_runtime27_interruption.py` -> baseline `9/9 OK` (no test/CI files modified by O2-B)

---

## 4. Protected & Frozen File Integrity

- `python.exe tools\verify_upstream_boundary.py --base 63eea4200420972344c22334149dc33a663c2ef1 --head WORKTREE` -> `Boundary Verification Result: PASS` (`Changes detected: 4, Violations: 0, Warnings: 0`, before committing this report).
- `git diff --check` -> exit `0`.
- Unchanged protected/frozen SHA-256 verification:
  - `Source/UI/iOS/Views/iPadLayout.swift`: `lf_sha256=1426ef3f6894e2a3c031f971152f1f60872b0fd6b833b4b0231f5b283297108c` (`wt_sha256=8277600a0dd7c783021bed90c49d0d5321bec0cecb4c5c65dcf90d677f46fdef`)
  - `Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift`: `lf_sha256=6330874e885c4fd193ede4938d34f54c42e88e54b7ddd3d95eba1c45ab70aa3f` (`wt_sha256=9baa3e9ff76aacd2daf3ebbb3c263022bab1b73f87fd1eba74ad5cbd6a21c693`)
  - `Source/UI/iOS/Views/Common/ListContentView.swift`: `lf_sha256=084f8d15e37655bf5ccd42cbdc9e308ecddd9c1cfc399a12d58089737ec8f2b1` (`wt_sha256=b11bddccba15e5e9c70736c30c958e74f052a24b701a69a9cd8404f4c8b16df1`)
  - `Source/ChavrusaText/ReaderHost/ReaderSidebarPageCoordinator.swift`: `lf_sha256=df1bdb92cebf8a10b7bd1de6c2d17c151b5d1105c023cb0497e79fd04417eac2` (`wt_sha256=847b3ffe0b6a89a44ec3e680f6cfe40a7b112e5c0164b2edf02ef2aaf7660f45`)
  - `Maktabah-iOSUITests/R27NativeInteractionAcceptanceTests.swift`: `lf_sha256=d4ff446db4acdbb61e0ad19c14696e5194bafbba239ef86876e85a2de30e70cc` (`wt_sha256=21b859725028bf37b0203b5b265ffc714b9b229945799672a2b5ee4a2bded2de`)
  - `docs/hq-integration/runtime27/R27_CASES.json`: `lf_sha256=d6ebe07d681e54440f58ce1b8b4945075f7047c8bce0b3a76fa98fd6fcf06875` (`wt_sha256=11be4ff3c425f45c00ae593f8f2687ee7a6155d1c867cab2363b5b41c3f22efc`)

---

## 5. Unresolved Native & Acceptance Gates (`NOT_RUN` / `OPEN`)

Windows cannot typecheck `SwiftUI`/`UIKit`, compile `Maktabah.app`, or execute iOS Simulator AX/gesture tests (`apple-doctor --json`: `portable_swift_only=true`). All native gates remain **`NOT_RUN` / `OPEN`**:

1. **Apple SDK Typecheck & App Build (`NOT_RUN`):** Swift 6 + iOS 27 SDK compilation of `GlobalSearchHistoryContent.swift`, `ReaderSidebarPager.swift`, and extracted `ReaderSidebarSplit.swift` (`Release` and `DEBUG`).
2. **History Accessibility Contrast Audit (`OPEN` / `NOT_RUN`):** Live iOS Simulator `GlobalSearchNativeAcceptanceTests/testHeaderAndHistoryNativeAccessibilityAudit` re-run verifying `'חיפושים אחרונים'` passes `performAccessibilityAudit`.
3. **Sidebar Body Paging LTR/RTL & Scene State (`OPEN` / `NOT_RUN`):**
   - `Sidebar11201AcceptanceTests/testSidebarBodyPagingLTR` (`Contents -> Library` drag failure remains **unfixed**; O2-B delivers `#if DEBUG` diagnostics only, not a swipe repair).
   - `Sidebar11201AcceptanceTests/testSidebarBodyPagingRTL` (previously blocked at startup `invalidLocator`, unverified).
   - `Sidebar11201AcceptanceTests/testSidebarSceneStateSurvivesBackgroundAndRotation` (previously blocked at startup `invalidLocator`, unverified).
4. **O2-A / Full 27-Case Matrix (`OPEN` / `NOT_RUN`):** Warm/security URL routing, alert-free rotation (`#1`–`#3`), `11-window`, `phone`, and final zero-skip `runtime27` acceptance remain `NOT_RUN`. **Phase 1 is NOT READY.**

---

## 6. Fix Round 1 — Non-Trapping Diagnostic Number Formatting

- **Round 1 Fix Base SHA:** `63906e196e2b7870d84fbdab26102d7dbeeae233`
- **Round 1 Code & Test Commit SHA:** `a316f0167d62a57e505c0f99c2e8694414d6e0de` (`O2-B round 1: non-trapping debugRounded formatting and numeric regressions`)
- **Report Commit:** Recorded at `HEAD` on `cez/335b7590` immediately above `a316f0167d62a57e505c0f99c2e8694414d6e0de` and reported in `cez task report`
- **Changed Files in Round 1 (`63906e19..HEAD`):**
  1. `Source/ChavrusaText/ReaderHost/ReaderSidebarPager.swift` — Added `ReaderSidebarPolicy.debugRounded(_ value: Double) -> String` using `Int(exactly: value.rounded())` with `String(describing: value)` fallback (`policy` section, zero extra imports so standalone SDK extraction slices remain self-contained), and updated both `selectPage` (`dx`/`dy`) and `ReaderSidebarSplitConfigurationController.debugRounded(_ value: CGFloat)` to delegate to it inside `#if DEBUG`. Preserved ordinary rounding, content-free logging, `#if DEBUG` isolation of all diagnostic emissions, and untouched paging/gesture/layout/delegate logic (`ReaderSidebarPageCoordinator.swift` left untouched).
  2. `tools/test_native_sidebar_policy.swift` — Appended 20 assertions (35 -> 55 total) exercising `ReaderSidebarPolicy.debugRounded(_:)` across ordinary positive/negative fractional values (`0.0`, `-0.0`, `0.4`, `-0.4`, `0.5`, `-0.5`, `1.5`, `-1.5`, `43.6`, `-120.2`), `Double(Int.max).nextDown`, `Double(Int.max)`, `Double(Int.min)`, `Double(Int.min).nextDown`, `-1e20`, `+/-Double.greatestFiniteMagnitude`, `.nan`, and `+/-.infinity`.
  3. `tools/test_o2b_native_ux.py` — Added `test_diagnostic_number_formatting_never_traps_and_preserves_rounding`, which compiles and executes in Swift 6 (`-D DEBUG`) the actual `selectPage` `dx`/`dy` formatting statements and controller `debugRounded(_:)` implementation extracted directly from `ReaderSidebarPager.swift` across all ordinary, integer-boundary, out-of-range, greatest-finite, NaN, and infinity cases.
  4. `docs/phase1-cezar/O2B_IMPLEMENTATION_REPORT.md` — Corrected Minor #2 wording (`bodyPanEnded` continuous target-action states) and appended this Fix Round 1 record. Minor #3 (`line_in_debug_guard` parser/SDK fallback) remains explicitly deferred per `O2B_FIX_ROUND1.md`.

### 6.1 Round 1 Pre-Repair RED Reproduction (`63906e19` production expressions)

Command (run with `tools/test_o2b_native_ux.py` against unmodified `ReaderSidebarPager.swift` from `63906e19`):
`python.exe tools\test_o2b_native_ux.py -v`
- Result: `Ran 5 tests in 10.869s` -> `FAILED (failures=2)`
  - `(path='selectPage')`: `FAIL` (`rc=3221225501`, `Swift/IntegerTypes.swift:8841: Fatal error: Double value cannot be converted to Int because the result would be greater than Int.max`)
  - `(path='debugRounded')`: `FAIL` (`rc=3221225501`, `Swift/IntegerTypes.swift:8841: Fatal error: Double value cannot be converted to Int because the result would be greater than Int.max`)

### 6.2 Round 1 Post-Repair GREEN Verification (`a316f0167d62a57e505c0f99c2e8694414d6e0de`)

Executed with `C:\Users\DAVID\AppData\Local\Programs\Python\Python312\python.exe` and Swift `6.3.3` (`SDKROOT=C:\Users\DAVID\AppData\Local\Programs\Swift\Platforms\6.3.3\Windows.platform\Developer\SDKs\Windows.sdk`):

- `python.exe -m py_compile tools\test_o2b_native_ux.py` -> exit `0`
- `python.exe tools\test_o2b_native_ux.py -v` -> `Ran 5 tests in 3.413s` -> `OK` (exit `0`; both `selectPage` and `debugRounded` formatted all 20 scalar vectors + asymmetric pairs cleanly without trap, plus history contrast contract, `#if DEBUG`/content-free guards, standalone `ReaderSidebarSplit.swift`/`ReaderSidebarNativeSearchSDK.swift` extraction and Swift 6 syntax parse in Release and `-D DEBUG`, and portable policy test)
- `python.exe Scripts\CI\test-native-sidebar-policy.py` -> exit `0` (`PASS: 55 actual sidebar width/RTL/gesture policy assertions; no device UI claim`)
- Compiled portable policy binary under `-D DEBUG` (`swiftc -D DEBUG -parse-as-library ReaderSidebarPager.swift tools/test_native_sidebar_policy.swift`) -> exit `0` (`PASS: 55 actual sidebar width/RTL/gesture policy assertions; no device UI claim`)
- `python.exe tools\hq-sidebar-check.py` -> exit `0` (`PASS: 55 actual sidebar width/RTL/gesture policy assertions; no device UI claim` / `PASS: five changed/prepared Swift files parsed, including the pager Apple branch; diff whitespace clean` / `NOT_RUN: Apple typecheck, app build, simulator/device, gesture arbitration and visual acceptance`)
- `python.exe tools\verify_upstream_boundary.py --base 63eea4200420972344c22334149dc33a663c2ef1 --head HEAD` -> `Boundary Verification Result: PASS` (`Changes detected: 5, Violations: 0, Warnings: 0`)
- `python.exe tools\global-search-presentation-tests.py` -> exit `0` (`PASS: 42 ...` + `PASS: 18 ...`, `native NOT_RUN`)
- `python.exe tools\test_verify_xcresult_zero_skips.py -v` -> `Ran 10 tests in 0.503s` -> `OK`
- `python.exe tools\test_runtime27_interruption.py -v` -> `Ran 9 tests in 11.605s` -> `OK`
- Protected/frozen LF SHA-256 hashes verified unchanged against `4065feef` (`iPadLayout.swift`, `iOSTOCView.swift`, `ListContentView.swift`, `ReaderSidebarPageCoordinator.swift`, `R27NativeInteractionAcceptanceTests.swift`, `R27_CASES.json`).
- Apple SDK typecheck, `Maktabah.app` build, History AX contrast audit (`testHeaderAndHistoryNativeAccessibilityAudit`), sidebar body paging LTR/RTL, scene state / rotation, and the full 27-case matrix remain `OPEN` / `NOT_RUN`. **Phase 1 is NOT READY.**
