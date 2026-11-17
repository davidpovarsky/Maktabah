# O1-B Independent Source & Evidence Audit (Phase 1 Consolidated)

- **Deliverable:** `docs/phase1-cezar/O1B_INDEPENDENT_SOURCE_AUDIT.md`
- **Review Run / Kind / Role / Execution Mode:** Cezar Run `31f9bae5-254d-409e-97b1-2c97aa947455` | `kind: review` | `רוני (roni) | QA & Evidence` (`MAIN_SESSION`; zero nested subagents invoked)
- **Audit Branch / Base:** `cez/31f9bae5` forked off `e183e19d2217820118cf8ba973e420ca5df3b60c`
- **Pinned Evaluated Source Commit:** `4065feef11bd5a8997ea34364516468105778688` (verified byte-for-byte identical to `e183e19d2217820118cf8ba973e420ca5df3b60c` across all 23 audited source, UI-test, and CI files; `4065_eq_e183=true`)
- **Upstream Reference:** `refs/remotes/upstream/main = d46af139b3a265399c16d87f5923acd8e3444024` (plus legacy register base `a0ed0df9` cited in `docs/architecture/UPSTREAM_EXCEPTION_REGISTER.json`)
- **Evaluated Native CI Run:** [`43891893650`](https://github.com/davidpovarsky/Maktabah/actions/runs/43891893650) on `4065feef` (`xcode-27`: `macOS 27.0.1`, `Xcode 27.1` `27A9275`, `Apple Swift 6.4`, `iPhoneSimulator27.1.sdk`, `iOS 27.2 / 24B8117`, `iPad Pro 11-inch (M5) (12GB)`)
- **Aggregate Phase 1 Readiness Verdict:** **`NOT_READY` / `FAIL`** (Windows cannot compile or validate Apple frameworks/iOS Simulator UI; `43891893650` ended **`cancelled`** at `16:38:49.467Z` (`UNATTRIBUTED`) with `runtime27/result.json` and `built_binary_sha256` absent, and `VERIFIED_NATIVE_43891893650.json` records `9 PASS, 13 FAIL, 1 STARTED_INTERRUPTED, 4 NOT_RUN`, including one `#2` `PASS` achieved via an inactive-hit-test early return at `FaithfulReaderUIAcceptanceTests.swift:193`).

> **Epistemic Discipline:** Every claim below separates **Observed Facts** (directly inspected source, Git hashes/diffs, `xcresult` logs, AX trees, and `otzaria-reader.log`), **Inferences / Hypotheses** (explicitly labeled working explanations), and **Unknowns / Unverified Gaps**. Protected upstream files and settled owner approvals (`EXACT_OWNER_HOOK_FINAL_VERIFICATION.json`) remain strictly read-only.

---

## 1. Independent Critique of Manager & Predecessor Reports

Inputs reviewed critically as claims requiring falsification (not accepted at face value):
- `docs/phase1-cezar/CI_NATIVE_FORENSICS.md` (`8d7fdde2`, O1-A `19efbb02`)
- `docs/phase1-cezar/MANAGER_EVIDENCE_REVIEW.md` (`e183e19d`)
- `docs/phase1-cezar/APP_SOURCE_GAP_MATRIX.md` (`e183e19d`)

### 1.1 Claims Verified Accurate Against Primary Evidence
- **Run `43891893650` per-case counts:** Matches `VERIFIED_NATIVE_43891893650.json:11-16` (`PASS: 9`, `FAIL: 13`, `STARTED_INTERRUPTED: 1`, `NOT_RUN: 4`) and `test-simulator-11-reader.log` (`11-reader`: `9 Passed, 13 Failed, 0 Skipped`). Historical `43863125434` (`51e2b7aa`, `14 Pass / 10 Fail / 3 NOT_RUN`) is superseded.
- **LF SHA-256 & Git blob fingerprints:** Match `4065feef` (`== e183e19d`) and `EXACT_OWNER_HOOK_FINAL_VERIFICATION.json` (`allVerified: true` for `iPadLayout.swift`, `iOSTOCView.swift`, `ListContentView.swift`).
- **Cluster A (`#15`), Cluster B (`#21` LTR `:292`), and Cluster C (7 warm/bg/version/wrong-backend/replay URL tests):** Supported by `test-simulator-11-reader.log`, `F89034B9-450C-47C1-ABD3-D7B3CD768592.txt`, `1E753D2E-0E63-47FC-8776-9FF66256263B.txt`, `url-delivery-11-reader.jsonl`, and `otzaria-reader.log`.

### 1.2 Rejected / Unsupported Claims & Source Corrections

1. **Cluster D (`R27NativePadTests` `#1`, `#2`, `#3`) Classified as a Confirmed `d9ab40fb` Landscape `product` Regression (`CI_NATIVE_FORENSICS.md:164-175`, manager summaries) — `UNSUBSTANTIATED`:**
   - **Observed Facts:**
     - Immediately before `R27NativePadTests`, the 7 failing `NativeRoutingAcceptanceTests` (`#25, #27, #8, #6, #5, #4, #26`) executed `xcrun simctl openurl`, queuing **7 sequential `"Open in “ChavrusaText”?"` SpringBoard alerts** (`test-simulator-11-reader.log:1980-2267`).
     - In `otzaria-reader.log`, `#3` (`pid=25623` @ `:35`), `#2` (`pid=28076` @ `:40`), and `#1` (`pid=30153` @ `:45`) all logged `event=mount ... foreground=false` and **never logged `foreground=true`**.
     - None of `#1`, `#2`, or `#3` synthesized a tap before `capture()`, so XCTest's `UIInterruptionMonitor` never ran (`test-simulator-11-reader.log:1620-1915`), and `dismissAlertsIfNeeded()` only queries `app.alerts` (never `com.apple.springboard`).
     - `#2 Legacy` (`test-simulator-11-reader.log:1772-1774`) did **not** verify the bottom toolbar: `FaithfulReaderUIAcceptanceTests.swift:193` (`guard reader.exists && reader.isHittable else { return true }`) returned early when `reader-text.isHittable` was `false`.
     - `#1 Otzaria` (`pid=30153`, same `foreground=false`) **passed** Portrait `capture()` (`t=27.57s..28.81s`, `4` Find calls for `reader-more-menu`, lines `1829-1835`), then failed Landscape `capture()` (`t=42.62s..59.94s`, lines `1869-1912`) when `isHittable` filtering dropped `reader-more-menu` — even though `0AAF305F-4B07-4B0E-9C40-28790B0224C5.txt:219` shows `reader-more-menu` inside `appFrame=(0.0, 0.0, 1210.0, 834.0)` at `{{14.0, 774.0}, {38.0, 36.0}}` (with `Toolbar {{0.0, 32.0}, {1210.0, 802.0}}`, `reader-detail-column {{0.0, 32.0}, {1210.0, 802.0}}`, and sibling `Other 0x11606a080 {{0.0, 32.0}, {1210.0, 802.0}}` at `:153,182,222`).
     - Immediately after `#1`, `#24` (`testOriginalBottomTOCActionUsesActualSidebarPage`, `pid=32768`) mounted `foreground=false` (`otzaria-reader.log:147`), tapped `reader-sidebar-page-0` (`test-simulator-11-reader.log:1972`), triggered `UIInterruptionMonitor` 7 times dismissing all 7 SpringBoard alerts (`1980-2267`), became `foreground=true` (`otzaria-reader.log:174`, `16:18:29.491Z`), tapped `reader-more-menu` (`2280`), tapped `reader-toc-toggle` (`2297`), and **PASSED Landscape `capture()`** (`candidate-original-bottom-toc-action`, lines `2320-2326`) on the identical `d9ab40fb` Otzaria screen.
   - **Corrected Classification:** Cluster D (`#1/#2/#3`) is **`CONTAMINATED / UNVERIFIED`**, NOT proven to be a `d9ab40fb` Landscape product regression. Whether `foreground=false` under SpringBoard alerts affects Portrait vs Landscape `isHittable` differently, or whether `Embedded` has an independent defect, is **`UNKNOWN`** until tested alert-free.

2. **URL Entry Handler File Misattribution (`CI_NATIVE_FORENSICS.md:159`, `APP_SOURCE_GAP_MATRIX.md`):**
   - `CI_NATIVE_FORENSICS.md:159` attributes app URL intake to `MaktabahApp.swift`, and `APP_SOURCE_GAP_MATRIX.md` omits `iOSMainView.swift`.
   - **Observed Fact:** `.onOpenURL` -> `handleOpenURL` -> `MaktabahNativeURLHandler.handle(url, manager: bManager)` is in upstream-owned `Source/UI/iOS/Views/iOSMainView.swift:108-110,182-184` (falling back to `WidgetDeepLink.parse` only if `handle` returns `false`).

3. **`Scripts/CI/runtime27.py` Missing `start_new_session` / `os.killpg` Diagnosis (`CI_NATIVE_FORENSICS.md:105`, manager docs):**
   - `CI_NATIVE_FORENSICS.md:105` and manager summaries treat `runtime27.py` as lacking process-group isolation/kill.
   - **Observed Fact:** `Scripts/CI/runtime27.py:63-137,219-226` **already** runs child steps with `start_new_session=(sys.platform == "darwin")`, handles `SIGINT`/`SIGTERM`, and calls `stop_owned_process_group(grace_seconds=5, kill_wait_seconds=2)` using `os.killpg`. Recommending duplicate `start_new_session`/`killpg` wiring in `runtime27.py` is redundant; the true teardown defect is in the `5s` grace window + `run-faithful-ipad-matrix.py` signal/simulator cleanup behavior (Section 6).

4. **`Source/Features/` Protected Namespace vs `d46af139` Diff Nuance:**
   - Manager/CI tables track `in_upstream_d46a`. `Source/Features/Reader/iOS/iOSReaderWorkspaceView.swift` is absent in `d46af139`, **yet** `Scripts/CI/verify-upstream-boundary.py:23` places all of `Source/Features/` inside `PROTECTED_NAMESPACES` and `UPSTREAM_EXCEPTION_REGISTER.json:101-112` records `BUILD_8401_PATCH_08` against `a0ed0df9`. O2 writers must treat all `Source/Features/` paths as **`BLOCKED_OWNER`** unless explicit owner approval is granted.

---

## 2. Current-v1 History URL Path End-to-End Audit

### 2.1 Observed End-to-End Call Chain
1. **System Intake (`iOSMainView.swift:108-110,182-184`):** `.onOpenURL` calls `MaktabahNativeURLHandler.handle(url, manager: bManager)`. If it returns `false`, `WidgetDeepLink.parse(from: url)` retains legacy behavior.
2. **Scheme/Host Filter (`MaktabahNativeURLHandler.swift:11-33`):** Accepts `scheme == "maktabah-debug"` (`DEBUG`) or `"maktabah"` (`Release`) with `host == "action"` and returns `true`; legacy `"history"`/`"annotation"` or unknown hosts return `false` (`NativeRouteURL.decode` also handles `.legacy(url)` at `:23`, though `MaktabahNativeURLHandler` pre-filters `host == "action"` at `:17`). Failures map to bounded error codes (`UIRouteError.code ?? NativeIntentOutcome.code ?? "native_link_not_acknowledged"`), log `[NativeNavigationFailure] code=...`, and set `manager.alertMessage` (`title: "Unable to open link"`).
3. **Envelope Decode (`NativeRouteURL.swift:14-45`):** Enforces `maximumURLBytes = 6_144`, strips/forbids user/password/port/fragment, requires path `/v1/<destination>` (`url_version_unsupported` otherwise), canonical query `route=<base64url>` (`noncanonical_route_query`), strict base64url round-trip (`invalid_route_encoding`), `UIRouteCodec.decodePublic(bytes, registry:)`, and route/path destination equality (`conflicting_url_destination`).
4. **Disabled Future V2 Bindings (`MaktabahNativeRoutingComposition.swift:12,107-111`):** `static let futurePublicBindingsEnabled = false`; `configureFuturePublicBinding(..., enabled: Bool = false)` throws `UIRouteError(.notSupported, "future_public_binding_disabled")`. No active caller opts in; canonical `ActionExecutor` (`core`), `NativeSceneDirectory`, `NativeNavigationAuthority`, and `NativeSceneNavigationOrchestrator` remain authoritative.
5. **Mount, Foreground Activation & Stale Cancellation (`MaktabahNativeRoutingHost.swift:35-100`, `MaktabahNativeRoutingComposition.swift:57-102,148-159,176-228`, `NativeNavigationAuthority.swift:27-70`):**
   - `MaktabahNativeRoutingHost` mounts `MaktabahNativeSceneSession` once `MaktabahApp.isIpad && (!ChavrusaTextReaderUI.isEnabled || workspace?.attached == true) && !sceneID.isEmpty` (`:35`).
   - `open(url:manager:)` computes a 5s deadline (`:261-264`), logs `[NativeSceneLifecycle] event=url`, and awaits `waitForMount(managerID:)` (`:205-228` with `withTaskCancellationHandler` cancelling pending `mountWaiters`).
   - Rejects non-foreground or non-unique scene matches with `.requiresForeground` (`:191-192`), checks `route.backend == snapshot.backend` or returns `.requiresBackendSwitch(requested)` (`:194`), issues a single-flight `ActionExecutionContext` (`origin: .deepLink`, `scopes: [.navigation, .discovery]`), and delegates to `orchestrator.commit`.
   - `setForeground(false)`, `unmount`, or `workspaceProjectionDidUpdate` -> `invalidateContext` (`MaktabahNativeRoutingComposition.swift:83-102,136-147`) advance `NativeNavigationAuthority` revision, clear active `context`, and call `session.presentation.revoke()`, cancelling stale in-flight navigations (`staleState`).
6. **Replay Ledger, Core Authorization & Visible Receipt (`NativeSceneNavigationOrchestrator.swift:176-266`, `MaktabahNativeSceneSession.swift:64-93`, `MaktabahNativeSceneBindings.swift:20-29`):**
   - `dispatches[requestID]` (bounded `capacity = 256`, preserved across scene remounts in `unregister` `:58-65`) rejects duplicate `requestId`s (`native_request_replay_conflict` / `native_request_already_finished` / `native_effect_requires_reconciliation`) and marks `dispatches[requestID]?.dispatched = true` immediately before `driver.apply` (`:237`) so uncertain failures never retry or roll back.
   - `validateSurface` enforces `route.content == nil`, `presentation.kind == .currentTab` for `native.history`, and `HistoryViewModel.shared.searchText.isEmpty` (`MaktabahNativeSceneSession.swift:77-78`, matching `assess` at `MaktabahNativeRoutingComposition.swift:257`).
   - `command.prepareNavigation(using: core, context: context)` + `authorizeCommit` -> `MaktabahNativeSceneBindings.apply` (`showSettings = false`, `selectedTab = .history`, `manager.switchToMode(.history)`) -> `NativePresentationObserver` visibility wait -> `prepared.validateCompletion(receipt:observed:)` -> `[NativeNavigationReceipt]` (`MaktabahNativeRoutingComposition.swift:265-270`).

### 2.2 Runtime Verification Status on `4065feef` (`43891893650`)
- **Verified (Observed Fact):** `#7 testColdHistoryURLWaitsForActualSceneMount` **PASSED** (`39.259s`): `otzaria-reader.log:13-22` confirms `pid=11726` `event=mount foreground=false` -> `event=url` -> `await-mount` -> `foreground=true` -> `[NativeSurfaceWitness]` (`visible=true`, `pending=false`) -> `[NativeNavigationReceipt] destination=native.history presentation=currentTab`.
- **Unverified / Blocked by Test Harness (`#4, #5, #6, #8, #25, #26, #27`):** `url-delivery-11-reader.jsonl` logged 7 `simctl openurl` calls returning `delivered: true`, **yet `otzaria-reader.log:23-34` recorded 0 `event=url` lines**, `pid=12049` lost foreground focus (`foreground=false` at `16:08:32.024Z`), and `#24` later dismissed 7 queued SpringBoard `"Open in “ChavrusaText”?"` alerts (`test-simulator-11-reader.log:1980-2267`).
- **Unknowns:** Warm Otzaria/Legacy/Embedded History URL routing, unknown-version URL error UI, post-background URL recovery + visible receipt, wrong-backend `.requiresBackendSwitch` refusal, and replay (`dispatches[requestID]`) rejection remain **unverified at runtime on `4065feef`**.

---

## 3. Subsystem Audit (Search, TOC, Sidebar Paging, Reader, Rotation, HID/Window, AX)

| Subsystem | Verified `43891893650` Outcome (`4065feef`) | Observed Source & Log Facts | Inferences / Unknowns |
|---|---|---|---|
| **GlobalSearch Contrast & Geometry** | `#9..#14 PASS`; **`#15 FAIL`** (`84.500s` @ `GlobalSearchNativeAcceptanceTests.swift:466`) | Dynamic Type failure from `43863125434` is resolved (`ListContentView.swift` in `d9ab40fb`). Audit now fails on `Contrast failed for SwiftUI.AccessibilityNode` at `StaticText label: 'חיפושים אחרונים'` (`F89034B9-450C-47C1-ABD3-D7B3CD768592.txt:1-3`). In `Source/ChavrusaText/Search/UI/GlobalSearchHistoryContent.swift:31`, `Text("חיפושים אחרונים")` has no `.foregroundStyle(...)`, unlike row labels (`:21` `.foregroundStyle(.primary)`), inside `List` with `.listRowBackground(Color.appBackground)` (`:41`) & `.background(Color.appBackground)` (`:46`); light `Color.appBackground` is `RGB(237/255, 217/255, 184/255)` (`MaktabahApp.swift:339-348`). | **Inference:** SwiftUI plain-list section header uses lower-contrast secondary style against `Color.appBackground`. Purely fixable in downstream `GlobalSearchHistoryContent.swift`. |
| **Sidebar Shared Search & Original Bottom TOC Action** | `#24 PASS` (`74.692s`); Search portion of `#21` passed | `iPadLayout.swift:110-124` & `ReaderSidebarPager.swift:45-59,115-122` wrap one `TabView(.page)` inside one `NavigationStack` (`ReaderSidebarSearchSurface`) with `.searchable`. In `#21`, both `'Search Library'` and `'Search Contents'` verified cleanly (`test-simulator-11-reader.log`, `CI_NATIVE_FORENSICS.md:134-135`). In `#24` (`pid=32768`), after `UIInterruptionMonitor` cleared 7 alerts (`foreground=true`), `reader-more-menu` -> `reader-toc-toggle` selected `page-1` (`toc-column`), kept `reader-text` width/locator intact, and passed Landscape `capture()` (`2320-2326`). | Bottom TOC action and shared sidebar search field pass on Otzaria Landscape when alert-free (`#24`); Search on RTL (`#22`) & Scene/Background/Rotation (`#23`) remain unverified due to startup `invalidLocator`. |
| **Sidebar Body Paging (LTR / RTL)** | **`#21 LTR FAIL`** (`231.119s` @ `:292`); **`#22 RTL FAIL`** (`60.925s` @ `:363`); **`#23 FAIL`** (`171.791s` @ `:363`) | `#21 LTR` Swipe 1 (`Library -> Contents`, `[0.75,0.50]->[0.25,0.50]`, `500 px/s`) selected `page-1`. Swipe 2 (`[0.25,0.50]->[0.75,0.50]`, `500 px/s`) kept `page-1` selected (`1E753D2E.txt:49-68`, `test-simulator-11-reader.log:2689-2783`). In `ReaderSidebarPager.swift:38-59,165-189,290-366`, `ReaderSidebarSplitConfiguration` (`bodyPan`) attaches to `split.viewController(for: .primary)?.viewIfLoaded`, forces `otherGestureRecognizer is UIPanGestureRecognizer` to wait via `shouldBeRequiredToFailBy`, triggers only on `.ended`, and emits **zero** gesture-state logs. `#22` & `#23` aborted at startup `assertReaderHasText()`. | **Inference:** Inside single `NavigationStack` (`d9ab40fb`), rightward drag on `page-1` conflicts with `NavigationStack`/column pan or fails `bodyPan` state transition before `.ended`. **Unknown:** RTL body paging (`#22`) and state survival (`#23`) behavior on `4065feef`. |
| **Native Reader, Rotation, `11-window`, HID** | `#1/#3 FAIL` (contaminated); `#2 PASS` (`:193` skip); `#19 STARTED_INTERRUPTED`; `#20 NOT_RUN` | See Section 1.2 for Cluster D alert contamination. In `11-window`, `43891893650` was cancelled before `11-window` completed (`#19` started post-cancel `16:42:09Z..16:46:35Z`; `#20` `NOT_RUN`). No `built_binary_sha256` recorded. | **Unknown:** True Landscape bottom-toolbar/rotation behavior across Otzaria/Legacy/Embedded when alert-free; full `11-window` resize, palette, inspector, and `runtime27-hid.py` HID comparison on `4065feef`. |

---

## 4. Original `reader6` Baseline & Deep Trace of `line:523` `invalidLocator`

### 4.1 Original `reader6` Baseline Status on `4065feef`
- **Definition (`PHASE_1_INTEGRATION_LEDGER.json:5383-5403`):** `original_reader6` = 3 `R27NativePadTests` (`#1 Otzaria`, `#2 Legacy`, `#3 Embedded`) + 3 `R27NativePhoneTests` (`#16 Otzaria`, `#17 Legacy`, `#18 Embedded`).
- **Observed Status (`43891893650`):**
  - `R27NativePadTests`: **0 cleanly verified passes.** `#1` & `#3` failed Landscape `capture()` while `foreground=false` under 7 SpringBoard alerts; `#2` passed only via `FaithfulReaderUIAcceptanceTests.swift:193` early return (`reader-text.isHittable == false`). Note in `#1`, Portrait `isHittable` passed at `t=27.57s` while Landscape `isHittable` failed at `t=42.62s` under the same `foreground=false` condition; `#24` later passed Landscape `capture()` once alerts cleared (`foreground=true`).
  - `R27NativePhoneTests`: **3/3 `NOT_RUN`** (also `NOT_RUN` in `43863125434` and `43883029218`).

### 4.2 Deep Trace of `line:523` `invalidLocator` (`#22` & `#23`)
- **Observed Facts:**
  1. Earlier launches in the exact same `11-reader` CI run (`pid=30153` @ `16:16:48.628Z`, `pid=32768` @ `16:18:00.561Z`/`.603Z`, `pid=35221` @ `16:19:13.224Z`/`.231Z`) all succeeded on `bookId=3891 lineIndex=523`:
     `[OtzariaReadingUnitService] readingUnit bookId=3891 lineIndex=523 mode=paragraph result=ok modeUnitId=toc:643037 startLineIndex=522 endLineIndex=526`.
  2. Immediately after `#21` (`pid=35221`), `#22 testSidebarBodyPagingRTL` (`pid=42214`) and `#23 testSidebarSceneStateSurvivesBackgroundAndRotation` (`pid=44252` + relaunch `16:25:12Z`) launched in Landscape and failed `assertReaderHasText()` (`FaithfulReaderUIAcceptanceTests.swift:363`, `>= 31` chars).
  3. Attached AX trees (`9DC6D110.txt:160,166`, `131F95CA.txt:40-41`, `27B95F9C.txt`) show `reader-header-title = 'ספר החינוך'`, `reader-header-subtitle = 'מצוה קב'`, `reader-current-locator = 'otzaria|book:3891|line:523'`, and `reader-text = 'מיקום הטקסט השמור אינו תקין.'` (`LibraryBackendError.invalidLocator`, `Localizable.xcstrings:13419`, 28 chars).
  4. In `otzaria-reader.log`: `#22` (`pid=42214`) logged `readingUnit bookId=3891 lineIndex=522 mode=paragraph result=ok` at `16:23:04.209Z` (**before** `event=mount pid=42214 foreground=true` at `16:23:04.700Z`); `#23` (`pid=44252`) logged `getAvailableReadingUnitModes start/done bookId=3891 count=3` (`:515-559`). Neither `#22` nor `#23` logged `readingUnit` for `lineIndex=523`.
  5. **Call-Path Verification (`OtzariaGenericBackendAdapter.swift:46-95`, `OtzariaReadingUnitService.swift:207-214`, `OtzariaMaktabahBridge+ReadingUnits.swift:24-39`, `OtzariaAppContainer.swift:676-682`):**
     - `OtzariaReadingUnitService.readingUnit` calls `try readingUnitWithoutFallback(...) ?? fallbackUnit(...)` (`:207`) *before* logging `readingUnit ...` (`:213`), so missing `readingUnit` alone does not prove `getReadingUnit` wasn't called.
     - **However**, `OtzariaMaktabahBridge+ReadingUnits.swift:24-39` logs `[OtzariaMaktabahBridge] getReadingUnit start` **unconditionally BEFORE** calling `service.readingUnit` (and `OtzariaFileLogger` captures `[OtzariaMaktabahBridge]` logs in `otzaria-reader.log`, proven by lines `46-49`). Zero `getReadingUnit start` lines appear anywhere in `otzaria-reader.log` (`1-559`). Thus `OtzariaGenericBackendAdapter.section(at:)` lines `:71-95` (`getReadingUnit` / `guard let content` at `:95`) did **not** execute in any logged process.
- **Inferences / Unknowns:**
  - `OtzariaGenericBackendAdapter.section(at:)` also throws `LibraryBackendError.invalidLocator` earlier without calling `getReadingUnit` at `:51` (backend/position mismatch or nil position) and `:65` (`bookID <= 0`), and `Reader+Content.swift` / session restore may receive `invalidLocator` from another path or persisted state left by `#21`. Exact failure line and root trigger remain **`UNKNOWN`** pending bounded O2-A diagnostics.

---

## 5. Verified Git Hashes, Owner Approvals & Upstream Boundary Table

Verified on pinned `4065feef` (`== e183e19d` for all 23 paths) against `refs/remotes/upstream/main = d46af139` and `EXACT_OWNER_HOOK_FINAL_VERIFICATION.json`:

| Path | Git `blob` SHA (`4065feef`) | `lf_sha256` (macOS / Git LF) | `in_upstream_d46a` | `eq_upstream` | Boundary / Owner Gate Status |
|---|---|---|---|---|---|
| `Source/UI/iOS/Views/iPadLayout.swift` | `f03f6f85045afc3f73961894782c4cd3c0f24aa1` | `1426ef3f6894e2a3c031f971152f1f60872b0fd6b833b4b0231f5b283297108c` | `true` | `false` | **SETTLED_OWNER_APPROVED** (`cb59d6f5`/`d9ab40fb`, `EXACT_OWNER_HOOK_FINAL_VERIFICATION.json:28-30`). **Preserve untouched (`BLOCKED_OWNER` for new changes).** |
| `Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift` | `42287267c7d73858fa58c0da52baab863a2f0ac9` | `6330874e885c4fd193ede4938d34f54c42e88e54b7ddd3d95eba1c45ab70aa3f` | `true` | `false` | **SETTLED_OWNER_APPROVED** (`4fc4058c`, `EXACT_OWNER_HOOK_FINAL_VERIFICATION.json:34-36`). **Preserve untouched (`BLOCKED_OWNER` for new changes).** |
| `Source/UI/iOS/Views/Common/ListContentView.swift` | `df6e248cee2391caf0a9c193c2ec343ce5ab2f45` | `084f8d15e37655bf5ccd42cbdc9e308ecddd9c1cfc399a12d58089737ec8f2b1` | `true` | `false` | **SETTLED_OWNER_APPROVED** (`cb59d6f5`/`d9ab40fb`, `EXACT_OWNER_HOOK_FINAL_VERIFICATION.json:40-42`). **Preserve untouched (`BLOCKED_OWNER` for new changes).** |
| `Source/UI/iOS/Views/iOSMainView.swift` | `d71fd38912710378d385d2658fd4e676017f937b` | `70caa8ea50b4e8717a096824bbfab5a8968caa7dec86554ff5a58d2a99366235` | `true` | `false` | **`BLOCKED_OWNER`** (Upstream-owned; hosts `.onOpenURL` at `:108-110,182-184`) |
| `Source/UI/iOS/MaktabahApp.swift` | `465c81c9af7c75136898e0afe92fb80b35178d7c` | `1954ba44e312863a2a9c82641eb295365c8294ce86330e5c9e9a862780eb2647` | `true` | `false` | **`BLOCKED_OWNER`** (Upstream-owned; `UIColor.appBackground` at `:339-348`) |
| `Source/UI/iOS/Managers/iOSNavigationManager.swift` | `17ac03d083571da1c5abcb033facd23140dcc8d6` | `b8e6648cb1c6efd4942aadfe2e3aec3177fcd85fee8f502933d3f048d3311611` | `true` | `false` | **`BLOCKED_OWNER`** (Upstream-owned) |
| `Source/Features/Reader/iOS/iOSReaderView.swift` | `67146db4a47746c8412a8ee7d8b16328ff951e19` | `dfe8260afcbea2131f88da68a90374ff1fbdf1d5e11af68dbd0b4f62f95fdaba` | `true` | `false` | **`BLOCKED_OWNER`** (Upstream-owned) |
| `Source/Features/Reader/iOS/Toolbar/iOSReaderBottomToolbarView.swift` | `de504b55304909dc804606aa7e4b3c80a52f5bc5` | `82b7b64d21cfdd6a2f8dd8bbfd94bf95a81da218c37a6f81d378f399c6e13b9a` | `true` | `false` | **`BLOCKED_OWNER`** (Upstream-owned) |
| `Source/Features/Reader/ViewModel/Extensions/Reader+Content.swift` | `37d284f626ef86a235d6af76bb7a619750297064` | `d1d32d62aac760130846f6fd69026c07c995099d6ffff4f03da2dc92074bedbe` | `true` | `false` | **`BLOCKED_OWNER`** (Upstream-owned) |
| `Source/Features/Reader/ViewModel/Extensions/Reader+Navigation.swift` | `4b8a88bb9001fe58836d1bfedacb3e53a21ccc0d` | `16ca9a3c196bdc1e0f39efd862f6e6577467a01bce87c5b008a615be5c9d7778` | `true` | `false` | **`BLOCKED_OWNER`** (Upstream-owned) |
| `Source/Features/Search/iOS/SearchModeView.swift` | `ab9688a22482fe08cf546cccbc7a9871d95c3977` | `ff58883e3a9abd67289757dc6ebdd95083c9d329689fd7b61cab130de5b64eac` | `true` | `false` | **`BLOCKED_OWNER`** (Upstream-owned) |
| `Source/Features/Reader/iOS/iOSReaderWorkspaceView.swift` | `005860a415963af2fbcdd90028b6bae75a87e4a7` | `32322d10685b04a40a844070acd9373529a2a44f30bcea41830e8e8d3b27711f` | `false` | `false` | **`BLOCKED_OWNER`** (Protected `Source/Features/` namespace at `verify-upstream-boundary.py:23`; `BUILD_8401_PATCH_08` exception vs `a0ed0df9`) |
| `Source/ChavrusaText/Search/UI/GlobalSearchHistoryContent.swift` | `cbe1ad7febe5d439de1bc11f71b26b77afc32172` | `3687d11438b54cac5257c7206c75b33cff041c8072f6a0c404625d8a1ce95023` | `false` | — | **DOWNSTREAM_WRITABLE** (`O2-B`) |
| `Source/ChavrusaText/Search/UI/GlobalSearchHeader.swift` | `f3955e1945696120f46b1293bf9e067a9e923877` | `4d8595b82e1d9045fbe30a0f001d8251d9c067447d188f8dbcced6a0128eb11e` | `false` | — | **DOWNSTREAM_OWNED** |
| `Source/ChavrusaText/ReaderHost/ReaderSidebarPager.swift` | `74c1350f63369c802f4bd5f79bdda45ea9683a20` | `76cae03249b1620ed6b40046fd086e03e4235b585cd773387ff4547e8540f688` | `false` | — | **DOWNSTREAM_WRITABLE** (`O2-B`) |
| `Source/ChavrusaText/ReaderHost/ReaderSidebarPageCoordinator.swift` | `956ebb145ae173346d0b23487a3f78c3cc04d2d7` | `df1bdb92cebf8a10b7bd1de6c2d17c151b5d1105c023cb0497e79fd04417eac2` | `false` | — | **DOWNSTREAM_WRITABLE** (`O2-B`) |
| `Source/Otzaria/Compatibility/OtzariaGenericBackendAdapter.swift` | `46d39867d81e611fd91059312ade764ff45db36f` | `ff73293e17b8c78298b8d45b35760f1e78ab5a8bd75d87ff04cc71f9bd36fb3d` | `false` | — | **DOWNSTREAM_WRITABLE** (`O2-A`) |
| `Source/Otzaria/Reading/OtzariaReadingUnitService.swift` | `9804af3a15b1cf3607201b24c0af3da02d188e1f` | `f7f4e7be19e9bccc520e0cbd8af22f10fa22922774d6a9ca1f8fb5301d322f64` | `false` | — | **DOWNSTREAM_WRITABLE** (`O2-A`) |
| `Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeURLHandler.swift` | `8994f0de81ab2c1cf07e9b20d5977455bd094188` | `c6e98002d2a2ecce23fbeb4b8aea1057fd2c4c58f2263aea5176dc9eea0f8202` | `false` | — | **DOWNSTREAM_WRITABLE** (`O2-A`) |
| `Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeRoutingComposition.swift` | `5ed48c56d90961ba8cf000fafbd131d5b3bad7b3` | `a5700ca83fa6688c7a10e6d33b089aba00f500b668c662003e28fb51bd12d276` | `false` | — | **DOWNSTREAM_WRITABLE** (`O2-A`) |
| `Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift` | `591c798f48cd7789b57bfe834c2ddc412236e131` | `1ddb48e617f004138e98cb8ed3437aea3b62207a8cf9e87918adc1ba5353bb13` | `false` | — | **DOWNSTREAM_WRITABLE** (`O2-A`; not hash-pinned) |
| `Scripts/CI/runtime27.py` | `c9fc401c1d542e4c2410d95acff579978f5e9214` | `0830eeb6d04f017e4d9e275839e5e4d36af02f871c1793b8d4f69c671a77031b` | `false` | — | **DOWNSTREAM_WRITABLE** (`O2-A`) |
| `Scripts/CI/run-faithful-ipad-matrix.py` | `fd2c6a1f8f44daade1fd955b014dbbb7ef026b97` | `7d0915a3e3ae440454eafef15e16eda3874eaff7e160ce19358803855bd04d01` | `false` | — | **DOWNSTREAM_WRITABLE** (`O2-A`) |

*Hash-pinned test guard:* `Maktabah-iOSUITests/R27NativeInteractionAcceptanceTests.swift` (`lf_sha256` `d4ff446db4acdbb61e0ad19c14696e5194bafbba239ef86876e85a2de30e70cc`) is hash-pinned at `Scripts/CI/runtime27.py:322`; do not modify.

---

## 6. `runtime27.py` / `run-faithful-ipad-matrix.py` Signal & Simulator Teardown Diagnosis

- **Observed Facts in `Scripts/CI/runtime27.py:63-137,219-226`:**
  - `main()` traps `SIGINT` and `SIGTERM` to raise `KeyboardInterrupt`.
  - `run_logged()` launches child commands with `start_new_session=(sys.platform == "darwin")`.
  - On `BaseException`, `run_logged()` writes the `INTERRUPTED_CHILD_UNVERIFIED` marker and calls `stop_owned_process_group(process, grace_seconds=5, kill_wait_seconds=2)` using `os.killpg(pgid, signal.SIGINT)` followed after 5s by `SIGKILL`.
- **Observed Facts in `Scripts/CI/run-faithful-ipad-matrix.py:157-404`:**
  - Main execution uses `except (Exception, SystemExit)` — it does **not** catch `KeyboardInterrupt`.
  - Its `finally:` block synchronously executes `stop()`, `collect-runtime27-palette-log.py` (60s timeout), `shutdown-faithful-simulator.py` (300s timeout), and `xcrun simctl delete` (120s timeout).
- **Root Mechanism (Diagnosis):**
  1. Do **not** add duplicate `start_new_session` / `os.killpg` logic in `runtime27.py` — it is already implemented.
  2. When GHA cancels Step 10 (`43883029218`, `43891893650`), `run-faithful-ipad-matrix.py`'s multi-hundred-second `finally:` simulator cleanup exceeds `grace_seconds=5` before `SIGKILL` terminates the Python wrapper (or GHA terminates the step directly), leaving child `xcodebuild` / `DTServiceHub` / `simctl` / `launchd_sim` orphaned (`CoreSimulator` processes live outside the Python child's Unix `pgid`), and `runtime27.py` exits without writing `build/artifacts/runtime27/result.json`, `junit.xml`, or `cases.html`.
- **Workflow Filtering & Build Constraints (Observed):**
  - Pre-test `--build-for-testing` takes `~52m` even on `actions/cache` hit (`1515 MB`, `runtime27-derived-v2-...`) because `hq-stage2-focused-apple.py --build-for-testing` rebuilds Zayit Rust XCFramework, Metro `main.jsbundle`, CocoaPods, and `xcodebuild build-for-testing`.
  - `.github/workflows/sefaria-embedded-validation.yml:109` rejects `runtime27` when `ui_diagnostic_cases != ''`, whereas `Scripts/CI/runtime27.py:29-52` already supports selective execution via `docs/hq-integration/runtime27/R27_CASES.json` (`execution_case_ids` / `execution_groups`). Running `runtime27_mode=off` (`validate-sefaria-embedded`) skips `runtime27-fixture-oracle.py` (`R27_EXPECTED_OTZARIA_WORK_KEY`), breaking `Sidebar11201AcceptanceTests` / `R27NativePadTests` on `XCTUnwrap`.

---

## 7. Disjoint O2 Execution Plan, Rejected Fixes & Remaining Native Gates

### 7.1 Strictly Disjoint Downstream Writer Scopes (O2-A vs O2-B)

Both O2 writers are restricted to downstream paths (`Source/ChavrusaText/`, `Source/Otzaria/`, `Maktabah-iOSUITests/`, `Scripts/CI/`). **Zero edits** are allowed in `Source/UI/`, `Source/Features/`, `R27NativeInteractionAcceptanceTests.swift`, `.github/workflows/`, or settled files (`iPadLayout.swift`, `iOSTOCView.swift`, `ListContentView.swift`) without an explicit owner gate.

| Workstream | Disjoint Writable Scope (Downstream Only) | Goal & Verification Obligations | Conditional `BLOCKED_OWNER` Escalation Trigger |
|---|---|---|---|
| **O2-A** (URL Delivery, `invalidLocator` Triage, Harness Teardown) | `Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift`; `Source/Otzaria/**` (`OtzariaGenericBackendAdapter.swift`, `OtzariaReadingUnitService.swift`, `OtzariaDatabaseAccessController.swift`, `OtzariaAppContainer.swift`); `Source/ChavrusaText/UIRoutingHost/**`; `Scripts/CI/runtime27.py`; `Scripts/CI/run-faithful-ipad-matrix.py` | 1. Handle SpringBoard `"Open in “ChavrusaText”?"` alert in `openInExistingProcess(_:)` by confirming **`"Open"`** (fail closed if `Cancel` or no URL reaches process; preserve all receipt/PID/refusal/replay assertions). Ensure clean tearDown alert state.<br>2. Add bounded diagnostics around `OtzariaGenericBackendAdapter.section(at:)` (`:51,:65,:95`) / startup restoration to isolate `#22/#23` `book:3891|line:523` `invalidLocator` and fix downstream adapter/container bugs if located there.<br>3. Catch `KeyboardInterrupt` in `run-faithful-ipad-matrix.py`, bound interrupted `finally:` log collection, and ensure owned simulator UDID shutdown on cancel without duplicating `runtime27.py`'s `os.killpg`. | Stop and mark `BLOCKED_OWNER` if warm URL behavior, Landscape `isHittable`, or `invalidLocator` requires modifying `iOSMainView.swift`, `MaktabahApp.swift`, `iOSNavigationManager.swift`, `Reader+Content.swift`, `ReaderViewModel.swift`, or any file in `Source/UI/` or `Source/Features/`. |
| **O2-B** (GlobalSearch AX Contrast & Sidebar Body Paging) | `Source/ChavrusaText/Search/UI/GlobalSearchHistoryContent.swift`; `Source/ChavrusaText/ReaderHost/**` (`ReaderSidebarPager.swift`, `ReaderSidebarPageCoordinator.swift`, `CompactStudyWorkspaceHostModifier.swift`) | 1. Set explicit accessible dynamic high-contrast foreground styling on `Text("חיפושים אחרונים")` (`GlobalSearchHistoryContent.swift:31`) against `Color.appBackground`.<br>2. Add bounded `bodyPan` gesture-state diagnostics (`shouldBegin`, `ended`/`cancelled`, pan conflict) in `ReaderSidebarPager.swift` and fix Contents -> Library LTR return drag (`[0.25,0.50]->[0.75,0.50]`) inside single `NavigationStack` without breaking scrolling or `iPadLayout.swift`. | Stop and mark `BLOCKED_OWNER` if Sidebar return swipe, `GlobalSearch`, or Landscape toolbar requires editing `iPadLayout.swift`, `iOSTOCView.swift`, `ListContentView.swift`, `SearchModeView.swift`, `iOSReaderWorkspaceView.swift`, `iOSReaderBottomToolbarView.swift`, or `iOSReaderView.swift`. |

### 7.2 Rejected Unsupported Fixes (Must Not Apply)
1. **Weakening `FaithfulReaderUIAcceptanceTests.swift:193-221` or editing hash-pinned `R27NativeInteractionAcceptanceTests.swift`.**
2. **Dismissing SpringBoard URL prompts with `Cancel` instead of `"Open"`, or replacing real system URL delivery with synthetic internal calls.**
3. **Re-opening or re-requesting settled owner approvals in `iPadLayout.swift`, `iOSTOCView.swift`, or `ListContentView.swift`.**
4. **Adding duplicate `start_new_session` / `os.killpg` logic to `Scripts/CI/runtime27.py`.**
5. **Treating Cluster D (`#1/#2/#3`) as a confirmed `d9ab40fb` Landscape product regression prior to clean alert-free re-test, or blindly editing `iOSReaderBottomToolbarView.swift`.**
6. **Using `runtime27_mode=off` (`validate-sefaria-embedded`) to validate `Sidebar11201AcceptanceTests` / `R27NativePadTests` (breaks `R27_EXPECTED_OTZARIA_WORK_KEY` fixture oracle).**
7. **Treating Windows Swift checks or static source audits as proof of iOS runtime/UI acceptance.**

### 7.3 Proposal for One Bounded O2 Verification Dispatch (Not Triggered Here)
- After O2-A + O2-B merge cleanly, dispatch **one** `workflow_dispatch` on existing `.github/workflows/sefaria-embedded-validation.yml` (`validation_runner=xcode-27`, `runtime27_mode=ui`, `run_simulator_tests=true`, `run_production_release=false`, `hq_stage2_expected_sha=<merged-O2-SHA>`) using `R27_CASES.json` `execution_case_ids` + `11-reader` (`hid_comparison: false`) covering the 15 target selectors (`#15`, `#4-#6, #8, #25-#27`, `#1, #2, #3`, `#21, #22, #23, #24`) before restoring all 27 cases in O3.

### 7.4 Remaining Unverified / `NOT_RUN` Native Acceptance Gates (O2/O3 Required)
- Warm/Background/Unknown-Version/Wrong-Backend/Replay URL cases (`#4, #5, #6, #8, #25, #26, #27`) — `0` real URLs reached app process in `43891893650`.
- `GlobalSearch` contrast audit (`#15`) after fix.
- `Sidebar11201` LTR Swipe 2 (`#21`), RTL body paging (`#22`), and background/rotation state (`#23`) after unblocking `invalidLocator`.
- Clean alert-free `original_reader6` Pad verification (`#1, #2, #3`, ensuring `#2` evaluates `reader-more-menu` with `reader-text.isHittable == true`).
- Clean `original_reader6` Phone verification (`#16, #17, #18`) — **`3/3 NOT_RUN` across all runs**.
- `11-window` verification (`#19` Resize/Palette/Inspector `STARTED_INTERRUPTED`, `#20` Palette HID Comparison `NOT_RUN`) — **`0/2 completed` on `4065feef`**.
- Complete non-cancelled `runtime27` run producing `runtime27/result.json`, `built_binary_sha256`, and zero-skip `verify_xcresult_zero_skips.py` confirmation on the final SHA.
