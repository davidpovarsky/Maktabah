# Native CI Archaeology & Forensics Report (`43863125434`, `43883029218`, `43891893650`)

- **Report Path:** `docs/phase1-cezar/CI_NATIVE_FORENSICS.md`
- **Logical Role & Execution Mode:** `רוני (roni) | QA & Evidence` (`MAIN_SESSION`; read-only product audit on unit `O1-A PROBE_UNKNOWN`, child run `19efbb02-ad93-42f1-9d3c-71af01b63955`)
- **Worktree / Branch / Base SHA:** Branch `cez/19efbb02`, base `4065feef11bd5a8997ea34364516468105778688` (clean checkout of `codex/otzaria-phase1-consolidated-20261116`; zero source/test/script/workflow edits performed)
- **Authoritative Manifest:** [`docs/hq-integration/runtime27/R27_CASES.json`](../hq-integration/runtime27/R27_CASES.json) (`lf_sha256 = d6ebe07d681e54440f58ce1b8b4945075f7047c8bce0b3a76fa98fd6fcf06875`, 27 total manifest cases across `11-reader` [22], `11-window` [2], and `phone` [3])

> **Strict Separation of Facts, Inferences, and Unknowns:**
> - **Observed Facts** are taken directly from immutable CI artifacts, Xcode `xcresult` summaries/logs, accessibility trees, `otzaria-reader.log`, Git history/hashes, and GitHub API run metadata inspected on disk and via read-only `gh` queries.
> - **Inferences / Root-Cause Judgments** are explicitly labeled as **Inference** and cite the exact facts supporting them.
> - **Unproved Attribution / Gaps** are explicitly marked **`UNATTRIBUTED`** or **`UNKNOWN`**.
> - **No Pooling Rule:** Counts are reported strictly per immutable run and per commit SHA. Runs `43883029218` and `43891893650` ended **`cancelled`** with zero aggregate acceptance. Prior owner approvals (`4fc4058c` / `bacd3db4` verified in `cb59d6f5` and applied in `d9ab40fb`) remain settled in source and **must not** be re-requested.

---

## 1. Per-Run Summary & Source-Qualified 27-Case Matrix

### 1.1 Immutable Run Totals (Never Pooled Across SHAs)

| GitHub Run ID | Checkout SHA | GitHub Conclusion / Workflow Mode | `11-reader` (22 cases) | `11-window` (2 cases) | `phone` (3 cases) | Terminal `runtime27/result.json` & Acceptance Status |
|---|---|---|---|---|---|---|
| [`43863125434`](https://github.com/davidpovarsky/Maktabah/actions/runs/43863125434) | `51e2b7aab8d7374a013ae7685dd82e86759a8443` | `failure` (`runtime27_mode=ui`) | `12 Passed`, `10 Failed`, `0 Skipped` (`ownedSimulatorCleanup`: historical run before matrix field expansion; step failed after `11-window` cleanup) | `2 Passed`, `0 Failed` (`293.0469s`, `184.8331s`) | `3 NOT_RUN` (aborted in `11-window` cleanup `simctl list devices -j` 45s timeout) | Present (`status="FAIL"`, `executed_ui_pass=14`, `executed_ui_fail=10`, `executed_ui_skip=0`, `ui_not_run=3`). **Historical evidence only (`51e2b7aa`); superseded source.** |
| [`43883029218`](https://github.com/davidpovarsky/Maktabah/actions/runs/43883029218) | `ca0a7a3ff961bfd2152b51739c27411c5f29b85c` | `cancelled` (`runtime27_mode=ui`) | `2 Passed` (orphan post-cancel), `1 STARTED/INTERRUPTED` (`14:54:59.107Z`), `19 NOT_RUN` | `2 NOT_RUN` | `3 NOT_RUN` | **ABSENT** (`CANCELLED_PARTIAL_NATIVE`). Step 10 cancelled at `14:46:36.041Z`; orphan tests ran `14:49:16Z..14:56:21Z`. **Zero acceptance (`25 NOT_COMPLETED`).** |
| [`43891893650`](https://github.com/davidpovarsky/Maktabah/actions/runs/43891893650) | `4065feef11bd5a8997ea34364516468105778688` | `cancelled` (`runtime27_mode=ui`) | **`9 Passed`, `13 Failed`, `0 Skipped`** (`verified-11-reader.summary.json`; `ownedSimulatorCleanup="PASS"`, finished `16:28:28Z` pre-cancel) | `1 STARTED/INTERRUPTED` (`phaseStartedAt=16:42:09.664Z` post-cancel; killed `16:46:35Z`), `1 NOT_RUN` | `3 NOT_RUN` | **ABSENT** (`build/hq-stage2/result.json` passed; `verified-11-reader.json` = `FAIL` `"xcresult summary did not pass"`). Step 10 cancelled at `16:38:49.467Z`. **Zero aggregate acceptance.** |

> **Application Source Relationship Across Runs:**
> - `51e2b7aa` (`43863125434`) preceded `5620838d` (owned `simctl openurl` warm URL fixture + test updates) and `cb59d6f5`/`d9ab40fb` (owner-approved single `NavigationStack` sidebar search container in `ReaderSidebarPager.swift` / `iPadLayout.swift` + Dynamic Type scaling in `ListContentView.swift`).
> - `ca0a7a3f` (`43883029218`) and `4065feef` (`43891893650`) share the **exact same `Source/` application commit (`d9ab40fb` / `Source` tree `431748950e3285e600aa9d98d0c252856b429262`)** and identical UI-test / CI-helper code (`4065feef` was documentation/inventory reconciliation only).

---

### 1.2 Complete 27-Case Outcomes Table

All 27 selectors from `docs/hq-integration/runtime27/R27_CASES.json` (`11-reader` executed alphabetically by XCTest within `43891893650`, listed below in manifest order `#1..#27`):

| # | Group | Case Selector (`Suite/testMethod`) | `43863125434` (`51e2b7aa`) | `43883029218` (`ca0a7a3f`) | `43891893650` (`4065feef`) |
|---:|---|---|---|---|---|
| 1 | `11-reader` | `R27NativePadTests/testNormalBootstrapOtzariaRotationPreservesExactLocator` | **PASSED** (`73.528s`) | `NOT_RUN` | **FAILED** (`68.300s`) @ `FaithfulReaderUIAcceptanceTests.swift:220` — `XCTWaiterResult(2) != (1)` (Landscape `capture` timeout) |
| 2 | `11-reader` | `R27NativePadTests/testNormalBootstrapLegacyGenesisAndRotation` | **PASSED** (`51.977s`) | `NOT_RUN` | **PASSED** (`60.607s`) *(Note: line 193 short-circuited `reader-more-menu` check via `reader.isHittable == false`)* |
| 3 | `11-reader` | `R27NativePadTests/testNormalBootstrapEmbeddedGenesisAndRotation` | **PASSED** (`87.388s`) | `NOT_RUN` | **FAILED** (`77.531s`) @ `FaithfulReaderUIAcceptanceTests.swift:220` — `XCTWaiterResult(2) != (1)` (Landscape `capture` timeout) |
| 4 | `11-reader` | `NativeRoutingAcceptanceTests/testWarmHistoryURLUsesOtzariaNativeScene` | **FAILED** (`17.802s`) @ `NativeRoutingAcceptanceTests.swift:53` — `The iOS system must accept the actual URL` | `NOT_RUN` | **FAILED** (`45.423s`) @ `NativeRoutingAcceptanceTests.swift:150` — `Exact History surface was not displayed` |
| 5 | `11-reader` | `NativeRoutingAcceptanceTests/testWarmHistoryURLUsesLegacyNativeScene` | **FAILED** (`22.620s`) @ `NativeRoutingAcceptanceTests.swift:53` — `The iOS system must accept the actual URL` | `NOT_RUN` | **FAILED** (`76.198s`) @ `NativeRoutingAcceptanceTests.swift:150` — `Exact History surface was not displayed` |
| 6 | `11-reader` | `NativeRoutingAcceptanceTests/testWarmHistoryURLUsesEmbeddedNativeScene` | **FAILED** (`17.506s`) @ `NativeRoutingAcceptanceTests.swift:53` — `The iOS system must accept the actual URL` | `NOT_RUN` | **FAILED** (`57.003s`) @ `NativeRoutingAcceptanceTests.swift:150` — `Exact History surface was not displayed` |
| 7 | `11-reader` | `NativeRoutingAcceptanceTests/testColdHistoryURLWaitsForActualSceneMount` | **PASSED** (`32.194s`) | `NOT_RUN` | **PASSED** (`39.259s`) |
| 8 | `11-reader` | `NativeRoutingAcceptanceTests/testUnknownURLVersionShowsErrorWithoutNavigatingToHistory` | **FAILED** (`18.353s`) @ `NativeRoutingAcceptanceTests.swift:53` — `The iOS system must accept the actual URL` | `NOT_RUN` | **FAILED** (`52.165s`) @ `NativeRoutingAcceptanceTests.swift:184` — `XCTAssertTrue failed` (`Unable to open link` alert absent) |
| 9 | `11-reader` | `GlobalSearchNativeAcceptanceTests/testHebrewHeaderUsesActualRTLGeometry` | **PASSED** (`34.509s`) | `NOT_RUN` | **PASSED** (`60.127s`) |
| 10 | `11-reader` | `GlobalSearchNativeAcceptanceTests/testEnglishHeaderUsesActualLTRGeometry` | **PASSED** (`66.828s`) | **PASSED (orphan post-cancel)** (`152.539s`, `14:49:16.711Z`) | **PASSED** (`58.501s`) |
| 11 | `11-reader` | `GlobalSearchNativeAcceptanceTests/testTypingKeepsInlineHistoryAndSingleNativeFieldWithRealClear` | **PASSED** (`36.275s`) | `NOT_RUN` | **PASSED** (`49.188s`) |
| 12 | `11-reader` | `GlobalSearchNativeAcceptanceTests/testOtzariaDefaultAdvancedFormExposesRealConditionalControls` | **PASSED** (`66.186s`) | `NOT_RUN` | **PASSED** (`86.784s`) |
| 13 | `11-reader` | `GlobalSearchNativeAcceptanceTests/testExactAndFuzzyHideAdvancedOtzariaBindings` | **PASSED** (`96.615s`) | **PASSED (orphan post-cancel)** (`189.851s`, `14:51:49.250Z`) | **PASSED** (`88.831s`) |
| 14 | `11-reader` | `GlobalSearchNativeAcceptanceTests/testOptionsDismissalReturnsToSameQueryWithoutSubmission` | **PASSED** (`66.679s`) | `NOT_RUN` | **PASSED** (`108.521s`) |
| 15 | `11-reader` | `GlobalSearchNativeAcceptanceTests/testHeaderAndHistoryNativeAccessibilityAudit` | **FAILED** (`51.989s`) @ `GlobalSearchNativeAcceptanceTests.swift:466` — `Dynamic Type font sizes are partially unsupported` | **STARTED/INTERRUPTED (orphan)** (started `14:54:59.107Z`, killed at orphan cleanup) | **FAILED** (`84.500s`) @ `GlobalSearchNativeAcceptanceTests.swift:466` — `Contrast failed` (`'חיפושים אחרונים'`) |
| 16 | `phone` | `R27NativePhoneTests/testNormalBootstrapOtzariaBackgroundAndColdRestoration` | `NOT_RUN` | `NOT_RUN` | `NOT_RUN` |
| 17 | `phone` | `R27NativePhoneTests/testNormalBootstrapLegacyGenesisAndRotation` | `NOT_RUN` | `NOT_RUN` | `NOT_RUN` |
| 18 | `phone` | `R27NativePhoneTests/testNormalBootstrapEmbeddedGenesisAndRotation` | `NOT_RUN` | `NOT_RUN` | `NOT_RUN` |
| 19 | `11-window` | `R27NativePadTests/testNormalBootstrapNativeWindowResizePaletteAndInspector` | **PASSED** (`293.0469s`) | `NOT_RUN` | **STARTED/INTERRUPTED (post-cancel)** (`11-window` `RUNNING_NATIVE_XCTEST` `phaseStartedAt=16:42:09.664Z`, killed `16:46:35Z`) |
| 20 | `11-window` | `R27NativePadTests/testNormalBootstrapPaletteHIDComparison` | **PASSED** (`184.8331s`) | `NOT_RUN` | `NOT_RUN` |
| 21 | `11-reader` | `Sidebar11201AcceptanceTests/testSidebarBodyPagingLTR` | **FAILED** (`69.653s`) @ `Sidebar11201AcceptanceTests.swift:306` — `("0") != ("1") One visible native search field` | `NOT_RUN` | **FAILED** (`231.119s`) @ `Sidebar11201AcceptanceTests.swift:292` — `XCTWaiterResult(2) != (1)` (return swipe `Contents -> Library`) |
| 22 | `11-reader` | `Sidebar11201AcceptanceTests/testSidebarBodyPagingRTL` | **FAILED** (`68.842s`) @ `Sidebar11201AcceptanceTests.swift:306` — `("0") != ("1") One visible native search field` | `NOT_RUN` | **FAILED** (`60.925s`) @ `FaithfulReaderUIAcceptanceTests.swift:363` — `Wait for a populated reader` (`מיקום הטקסט השמור אינו תקין.`) |
| 23 | `11-reader` | `Sidebar11201AcceptanceTests/testSidebarSceneStateSurvivesBackgroundAndRotation` | **PASSED** (`65.470s`) | `NOT_RUN` | **FAILED** (`171.791s`) @ `FaithfulReaderUIAcceptanceTests.swift:363` — `Wait for a populated reader` (`מיקום הטקסט השמור אינו תקין.`) |
| 24 | `11-reader` | `Sidebar11201AcceptanceTests/testOriginalBottomTOCActionUsesActualSidebarPage` | **PASSED** (`55.726s`) | `NOT_RUN` | **PASSED** (`74.692s`) *(UIInterruptionMonitor cancelled 7 queued SpringBoard `"Open in “ChavrusaText”?"` alerts)* |
| 25 | `11-reader` | `NativeRoutingAcceptanceTests/testHistoryURLAfterBackgroundRequiresActualVisibleReceipt` | **FAILED** (`18.279s`) @ `NativeRoutingAcceptanceTests.swift:53` — `The iOS system must accept the actual URL` | `NOT_RUN` | **FAILED** (`50.769s`) @ `NativeRoutingAcceptanceTests.swift:200` — `XCTAssertTrue failed` (`history.waitForExistence`) |
| 26 | `11-reader` | `NativeRoutingAcceptanceTests/testWrongBackendURLCannotNavigateOrIssueNativeReceipt` | **FAILED** (`30.528s`) @ `NativeRoutingAcceptanceTests.swift:53` — `The iOS system must accept the actual URL` | `NOT_RUN` | **FAILED** (`39.450s`) @ `NativeRoutingAcceptanceTests.swift:213` — `XCTAssertTrue failed` (`Unable to open link` alert absent) |
| 27 | `11-reader` | `NativeRoutingAcceptanceTests/testReplayCannotIssueSecondNativeReceipt` | **FAILED** (`14.622s`) @ `NativeRoutingAcceptanceTests.swift:53` — `The iOS system must accept the actual URL` | `NOT_RUN` | **FAILED** (`47.456s`) @ `NativeRoutingAcceptanceTests.swift:235` — `XCTAssertTrue failed` (`history.waitForExistence`) |

*(Note: `testNormalBootstrapGlobalHistoryUsesActualSubmit` in `R27_CASES.json` `cases[]` is replaced in active execution by `execution_case_ids` via the 7 `GlobalSearchNativeAcceptanceTests` cases; `execution_groups` partitions all 27 `execution_case_ids` across `11-reader` [22], `11-window` [2], and `phone` [3].)*

---

## 2. Cancellation Causes & Infrastructure Timeline Facts

### 2.1 Attribution Standard

GitHub REST API metadata (`gh run view` / `gh api repos/davidpovarsky/Maktabah/actions/runs/<id>` / `gh run list`) records only `event: "workflow_dispatch"`, triggering user `davidpovarsky`, step conclusion `cancelled`, and `##[error]The operation was canceled.` Neither the GitHub API nor runner logs record who or what issued the cancel signal, and neither cancelled run reached its `timeout-minutes: 180` workflow limit (`sefaria-embedded-validation.yml:104`). Nor was either run cancelled by `concurrency.cancel-in-progress: true`: no overlapping run existed when either was cancelled (`43891893650` was created `15:01:09Z`, **4 minutes after** `43883029218` completed at `14:56:57Z` and **14 minutes after** Step 10 cancelled at `14:46:36Z`; zero runs exist after `43891893650`).

Therefore, **the cancellation actor/cause for BOTH `43883029218` and `43891893650` is `UNATTRIBUTED`.**

### 2.2 Exact Verified Timelines

1. **`43883029218` (`ca0a7a3ff961bfd2152b51739c27411c5f29b85c`) — Cancelled (`UNATTRIBUTED`) + Post-Cancel Orphan Tests:**
   - `14:10:47Z` — Workflow dispatched (`createdAt`).
   - `14:10:51Z` — Job `R27 real UI environment and acceptance` started on `xcode-27`.
   - `14:12:22Z` — Step 10 (`python3 Scripts/CI/runtime27.py`) started.
   - `14:46:36.041Z` — Step 10 cancelled (`##[error]The operation was canceled.`, elapsed **34m 14s** vs `180m` step/job timeout). Cause: **`UNATTRIBUTED`**.
   - `14:49:16.711Z..14:54:59Z` — Orphan child processes from `run_logged` (`start_new_session=True` in `Scripts/CI/runtime27.py:100`) executed on `11-reader` *after* Step 10 cancellation: passed `testEnglishHeaderUsesActualLTRGeometry` (`152.539s`) and `testExactAndFuzzyHideAdvancedOtzariaBindings` (`189.851s`), then started `testHeaderAndHistoryNativeAccessibilityAudit` at `14:54:59.107Z`.
   - `14:56:21Z..14:56:49Z` — GitHub Actions post-job orphan cleanup terminated `pid 85332 (DTServiceHub)`, `83684 (xcodebuild)`, `83682 (simctl)`, `83661 (Python)`, `81047 (Python)`. Job completed `14:56:57Z`.

2. **`43891893650` (`4065feef11bd5a8997ea34364516468105778688`) — Cancelled (`UNATTRIBUTED`) + Post-Cancel Orphan Start:**
   - `15:01:09Z` — Workflow dispatched (`createdAt`); runner picked up job at `15:04:37Z` on `xcode-27`.
   - `15:05:01Z..15:05:54Z` — Restored `actions/cache` key `runtime27-derived-v2-779913b2...` (~`1515 MB`, 53s).
   - `15:05:54.532Z` — Step 10 (`python3 Scripts/CI/runtime27.py`) started:
     - `hq-stage2-focused-apple.py --build-for-testing` rebuilt Zayit Rust XCFramework, React Native Metro bundle (`6ed1fee3...`), CocoaPods, and `xcodebuild build-for-testing` (`** TEST BUILD SUCCEEDED **`, `~52m`).
     - `11-reader` (`36912578-CF04-4F57-A0C0-87375B2E25A4`, iPad Pro 11-inch (M5), `iOS 27.2 / 24B8117`): Attempt 1 timed out on `xcrun simctl get_app_container ... app` (45s), collected diagnostics, rebooted owned simulator; Attempt 2 installed cleanly. `xcodebuild test-without-building` ran `15:58:30.120Z..16:26:39.418Z` (`28m 09s`), executing all **22** tests (`9 Passed, 13 Failed, 0 Skipped`, `exit code 65`). Simulator deleted cleanly (`ownedSimulatorCleanup: PASS` at `16:28:28.558Z`).
     - `11-window` (`478C0798-9990-497B-B736-ECB294C97B52`): Booted, installed `Maktabah.app`, provisioned `miniTest10` fixture, then hit `subprocess.TimeoutExpired` on `xcrun simctl terminate` (60s). `runtime27-fixture-recovery.py` triggered owned simulator shutdown and reboot before `RUNNING_NATIVE_XCTEST`.
   - **`16:38:49.467Z`** — Step 10 cancelled (`##[error]The operation was canceled.`, elapsed **92m 55s** vs `180m` timeout). Cause: **`UNATTRIBUTED`**.
   - `16:40:13Z..16:45:55Z` — `Retain real runtime evidence including failure` (`if: always()`) uploaded artifact `runtime27-evidence` (`14248590924`, `523,803,588 bytes`).
   - Meanwhile (during artifact upload!), orphan `run-faithful-ipad-matrix.py` (`pid 94769`, launched in a separate session via `start_new_session=True` by `runtime27.py:100`) continued into `11-window`: `phaseStartedAt = 16:42:09.664Z` (`RUNNING_NATIVE_XCTEST`), starting `testNormalBootstrapNativeWindowResizePaletteAndInspector` (`~16:44:08Z`). Because `runtime27.py` was killed directly without completing its teardown/writeback, **`build/artifacts/runtime27/result.json`, `junit.xml`, and `cases.html` were never written**, and `478C0798` never reached `ownedSimulatorCleanup`.
   - `16:46:07Z..16:46:35Z` — Runner orphan cleanup terminated `pids 56412 (DTServiceHub), 54131 (simctl), 54132 (simctl), 54133 (xcodebuild), 54127 (Python), 54006 (idb_companion), 94769 (Python)`. Job completed `16:46:39Z`.

3. **Contrast with `43863125434` (`51e2b7aa`) — Aborted in `11-window` Cleanup (Not Cancelled):**
   - Step 10 ran `12:04:23Z..13:20:22Z` (`conclusion=failure`). Completed all 22 `11-reader` cases (`12 Passed, 10 Failed`) and both `11-window` cases (`2 Passed`). Aborted before `phone` because `Scripts/CI/shutdown-faithful-simulator.py` timed out after 45s on read-only `xcrun simctl list devices -j` during `11-window` cleanup (later hardened in `run-faithful-ipad-matrix.py` / `shutdown-faithful-simulator.py`).

### 2.3 Harness Timing & Simulator Instability Patterns Observed Across Runs

1. **Orphan process group survival (`Scripts/CI/runtime27.py:98-137`):** `run_logged` spawns `run-faithful-ipad-matrix.py` with `start_new_session=True`. When GitHub Actions cancels Step 10 (`SIGINT`/`SIGTERM`/`SIGKILL`), either `runtime27.py` does not complete `stop_owned_process_group()` before forced exit or misses cleanup after `KeyboardInterrupt`, leaving `run-faithful-ipad-matrix.py` and `xcodebuild` running as background orphans (observed in both `43883029218` and `43891893650`) and losing `runtime27/result.json`.
2. **Pre-test build duration (~52m even on cache hit):** Even with `actions/cache/restore` hitting `runtime27-derived-v2-...`, `hq-stage2-focused-apple.py --build-for-testing` runs submodule checkout, `npm ci`, full Rust Zayit XCFramework rebuild, Metro bundle, CocoaPods, and `xcodebuild build-for-testing` before UI tests begin.
3. **CoreSimulator sluggishness on `xcode-27` (`iOS 27.2`):** Observed `simctl get_app_container` (45s) timeout on `11-reader` attempt 1 and `simctl terminate` (60s) timeout on `11-window` fixture install (both cleanly recovered by the harness, adding ~3-4 minutes overhead).

---

## 3. Root-Cause Classification: Historical 10 (`43863125434`) & Current 13 (`43891893650`)

### 3.1 Cluster A — Dynamic Type Fix Applied (`d9ab40fb`) -> Unmasked Header Contrast Failure (`product`)

- **Affected case:** #15 `GlobalSearchNativeAcceptanceTests/testHeaderAndHistoryNativeAccessibilityAudit`
- **Historical `43863125434` (`51e2b7aa`) failure:** Failed at `GlobalSearchNativeAcceptanceTests.swift:466` with `"Dynamic Type font sizes are partially unsupported"` (`ListContentView.swift` fixed-point font without `UIFontMetrics` scaling and `numberOfLines = 1`).
- **Already-applied repair (`d9ab40fb`):** Owner-approved hunk (`bacd3db4`) in `Source/UI/iOS/Views/Common/ListContentView.swift` added `label.adjustsFontForContentSizeCategory = true`, `UIFontMetrics(forTextStyle: .body).scaledFont(...)`, and `label.numberOfLines = 0`.
- **Current `43891893650` (`4065feef`) outcome (`FAILED 84.500s` at `:466`):**
  - Dynamic Type failure is **gone** (fixed by `d9ab40fb`).
  - Unfiltered `app.performAccessibilityAudit` now reaches and fails on **`"Contrast failed"`** (`F89034B9-450C-47C1-ABD3-D7B3CD768592.txt`):
    - `element = Attributes: StaticText, 0x10baadcc0, {{0.0, 360.0}, {834.0, 40.5}}, label: 'חיפושים אחרונים'`
    - Origin: `Source/ChavrusaText/Search/UI/GlobalSearchHistoryContent.swift:31` (`Text("חיפושים אחרונים")` inside `.listStyle(.plain)` section header relies on SwiftUI default secondary section-header color against `Color.appBackground`, failing WCAG contrast).
- **Classification:** Historical failure = **already fixed (`d9ab40fb`)**; current `43891893650` failure = **`product`** (UI foreground contrast in downstream `GlobalSearchHistoryContent.swift`).

---

### 3.2 Cluster B — Sidebar Search Fixed (`d9ab40fb`), LTR Return Swipe Fails (`product`)

- **Affected case:** #21 `Sidebar11201AcceptanceTests/testSidebarBodyPagingLTR`
- **Historical `43863125434` (`51e2b7aa`) failure:** Both `#21 LTR` and `#22 RTL` failed first at `Sidebar11201AcceptanceTests.swift:306` (`XCTAssertEqual("0", "1") - One visible native search field in the actual sidebar column`) because `.searchable` inside `ReaderSidebarPager` had no enclosing `NavigationStack` (each inner page had a separate or missing stack).
- **Already-applied repair (`d9ab40fb`):** Owner-approved hunk (`bacd3db4`) in `Source/UI/iOS/Views/iPadLayout.swift` removed the inner stacks and `ReaderSidebarPager.swift` (`ReaderSidebarSearchSurface`) wrapped the `TabView` in a single `NavigationStack`.
- **Current `43891893650` (`4065feef`) outcome (`FAILED 231.119s` at `Sidebar11201AcceptanceTests.swift:292`):**
  - Observed progress in `test-simulator-11-reader.log`:
    1. Search field verification **PASSED** on Library (`page-0`, `'Search Library'` functional empty/match/exclude/clear verified).
    2. Swipe 1 (`Library -> Contents`, `t=185.50s` drag `[0.75, 0.50] -> [0.25, 0.50]`, `500 px/s`) **PASSED**: `reader-sidebar-page-1` became `Selected`, `toc-column` appeared, `'Table of Contents'` + subtitle `'ספר החינוך'` + single `'Search Contents'` search field verified (`022DC794`).
    3. Swipe 2 (`Contents -> Library`, `t=202.24s` drag `[0.25, 0.50] -> [0.75, 0.50]`, `500 px/s`) failed to switch back to `page-0`: `reader-sidebar-page-0` stayed unselected (`isSelected == 0`) through timeout at line `292` (`XCTWaiterResult(2) != XCTWaiterResult(1)`).
- **Classification:** Historical `:306` search-field failure = **already fixed (`d9ab40fb`)**; current `:292` return-swipe failure = **`product`** (downstream gesture/paging interaction in `Source/ChavrusaText/ReaderHost/ReaderSidebarPager.swift` / `ReaderSidebarSplitConfigurationController` — **Inference:** Wrapping `TabView` in `NavigationStack` or `UISplitViewController` primary-column layout changed gesture/view hierarchy or pan arbitration relative to `.background { ReaderSidebarSplitConfiguration(...) }`, preventing rightward drag from triggering `bodyPan` on Contents page).

---

### 3.3 Cluster C — Seven Warm/Post-Background/Security URL Tests (`harness` SpringBoard Alert Gate)

- **Affected 7 cases (`NativeRoutingAcceptanceTests`):**
  - `#4` `testWarmHistoryURLUsesOtzariaNativeScene` (`45.423s` @ `:150`)
  - `#5` `testWarmHistoryURLUsesLegacyNativeScene` (`76.198s` @ `:150`)
  - `#6` `testWarmHistoryURLUsesEmbeddedNativeScene` (`57.003s` @ `:150`)
  - `#8` `testUnknownURLVersionShowsErrorWithoutNavigatingToHistory` (`52.165s` @ `:184`)
  - `#25` `testHistoryURLAfterBackgroundRequiresActualVisibleReceipt` (`50.769s` @ `:200`)
  - `#26` `testWrongBackendURLCannotNavigateOrIssueNativeReceipt` (`39.450s` @ `:213`)
  - `#27` `testReplayCannotIssueSecondNativeReceipt` (`47.456s` @ `:235`)
  - *(Note: `#7 testColdHistoryURLWaitsForActualSceneMount` uses `app.open(url)` after `app.terminate()`, logged `event=url pid=11726`, and **PASSED** in both `43863125434` [`32.194s`] and `43891893650` [`39.259s`].)*
- **Historical `43863125434` (`51e2b7aa`) failure:** All 7 failed at `NativeRoutingAcceptanceTests.swift:53` (`XCTAssertTrue failed - The iOS system must accept the actual URL`) because `UIApplication.open` from the background XCTest runner was rejected by SpringBoard (`FBSOpenApplicationErrorDomain Code=3`).
- **Repair attempt (`5620838d`):** Replaced `UIApplication.open` with `Scripts/CI/runtime27-url-delivery.py`, which listens for file requests and executes `xcrun simctl openurl <udid> <url>` on the host (`simctl-system-openurl`).
- **Current `43891893650` (`4065feef`) forensic proof:**
  1. `url-delivery-11-reader.jsonl` shows **7** requests (`nonces`: `7AF80491...`, `F76220F6...`, `3A573AA9...`, `17A20CC2...`, `064AAF30...`, `35745E9D...`, `E9C3AC89...`), all returning `"delivered": true` and preserving identical before/after app PID in `openInExistingProcess`.
  2. Yet `native-routing-logs-11-reader/otzaria-reader.log` shows **ZERO `[NativeSceneLifecycle] event=url` lines** for all 7 warm tests (`event=url` appears ONLY in cold test `pid=11726` at `16:07:56.636Z`). Furthermore, `pid=12049` (`testHistoryURLAfterBackground`) logged `foreground=false` at `16:08:32.024Z` (`0.72s` after `simctl openurl` at `16:08:31.305Z`), showing the app lost foreground focus.
  3. In the very next test that synthesized a tap (`Sidebar11201AcceptanceTests/testOriginalBottomTOCActionUsesActualSidebarPage`, `test-simulator-11-reader.log` `t=32.94s..47.47s`, lines `1980-2235`), XCTest's `UIInterruptionMonitor` encountered and dismissed **7 sequential stacked system alerts**:
     `"Open in “ChavrusaText”?" Alert from Application 'com.apple.springboard'` (tapping `"cancel-button"`).
- **Exact mechanism (Observed Fact):** `xcrun simctl openurl` on `iOS 27.2` causes `com.apple.springboard` to present an interactive `"Open in “ChavrusaText”?"` confirmation alert rather than forwarding the custom scheme URL immediately to the running app. `NativeRoutingAcceptanceTests.openInExistingProcess` does not interact with SpringBoard (`com.apple.springboard` alerts are never tapped/confirmed), so all 7 URLs stayed queued at the OS confirmation prompt and **never reached the app's URL handler** (`MaktabahApp.swift`).
- **Classification:** **`harness`** (`simctl openurl` OS confirmation prompt unhandled by `NativeRoutingAcceptanceTests` / `runtime27-url-delivery.py`). **Critical caveat:** Because no URL actually entered the running app during the 7 warm tests on `4065feef`, **in-process warm URL handling/receipt/refusal/replay product behavior on `4065feef` (`d9ab40fb`) remains `UNVERIFIED` runtime behavior** until the SpringBoard confirmation alert is accepted (`"Open"`).

---

### 3.4 Cluster D — New Regressions in `R27NativePadTests` Orientation Capture (`product`)

- **Affected cases:**
  - `#1` `R27NativePadTests/testNormalBootstrapOtzariaRotationPreservesExactLocator` (`43863125434`: **PASSED** `73.528s` -> `43891893650`: **FAILED** `68.300s` @ `FaithfulReaderUIAcceptanceTests.swift:220`)
  - `#3` `R27NativePadTests/testNormalBootstrapEmbeddedGenesisAndRotation` (`43863125434`: **PASSED** `87.388s` -> `43891893650`: **FAILED** `77.531s` @ `FaithfulReaderUIAcceptanceTests.swift:220`)
  - *(Note: `#2 testNormalBootstrapLegacyGenesisAndRotation` **PASSED** in `43891893650` [`60.607s`] only because `reader-text` reported `isHittable == false`, causing `FaithfulReaderUIAcceptanceTests.swift:193` `guard reader.exists && reader.isHittable else { return true }` to return `true` before checking `reader-more-menu`.)*
- **Exact log & AX-tree facts (`43891893650`):**
  1. In `testNormalBootstrapOtzariaRotationPreservesExactLocator`, **Portrait `capture()` PASSED (`t=27.57s..28.40s`)**: `reader-more-menu` resolved `1` element, passed `!frame.isEmpty`, `frame.intersects(frame)`, `isHittable`, and `frame.contains(bottomMenu.frame)` (`4` `Find the "reader-more-menu" Button` log entries).
  2. After rotating to **Landscape (`orientation=3`)**, both `Embedded` (`t=52.12s..69.89s`) and `Otzaria` (`t=42.62s..59.94s`) repeatedly timed out waiting for `settled` (`FaithfulReaderUIAcceptanceTests.swift:220` `"Capture only after native rotation and the original bottom toolbar settle inside the window"`).
  3. On every Landscape poll iteration (`1656-1660`, `1869-1873`), `reader-more-menu` logged `Get all elements ...` followed by **3** `Find the "reader-more-menu" Button` entries (`!$0.frame.isEmpty`, `$0.frame.intersects(frame)`, `$0.isHittable`), then evaluated `BottomOverflowBarButtonItem` (`0` matches), and **never reached** `bottomMenu.frame` (`4th` Find). Yet the exported failing AX tree `0AAF305F-4B07-4B0E-9C40-28790B0224C5.txt` (`r27-otzaria-native-landscape-ui-tree`) confirms `Button 0x116069cc0, {{14.0, 774.0}, {38.0, 36.0}}, identifier: 'reader-more-menu'` (wrapping an inner un-identified `Button 0x116069e00` of identical frame) **does exist inside `appFrame=(0.0, 0.0, 1210.0, 834.0)`**.
  4. **Observed code delta (`51e2b7aa..4065feef`):** Both `43863125434` and `43891893650` ran on the same OS/build (`iOS 27.2 / 24B8117`, `Xcode 27.1 / 27A9275`). Between `51e2b7aa` and `4065feef`, `Source/` changed **only** in `ReaderSidebarPager.swift`, `iPadLayout.swift` (`d9ab40fb` single-`NavigationStack`), and `ListContentView.swift` (`d9ab40fb`).
- **Classification:** **`product`** (iPadOS Landscape bottom toolbar / `reader-more-menu` `isHittable == false` regression introduced between `51e2b7aa` and `4065feef`; **Inference:** either overlapping detail/toolbar container hit-testing or SwiftUI Landscape layout obstruction after the `NavigationStack` hierarchy change — exact obstructing view/layer requires inspection in O2).

---

### 3.5 Cluster E — New Startup Reader Failure in `Sidebar11201` Tests (`unknown`)

- **Affected cases:**
  - `#22` `Sidebar11201AcceptanceTests/testSidebarBodyPagingRTL` (`43863125434`: failed later at `:306` -> `43891893650`: **FAILED** `60.925s` @ `FaithfulReaderUIAcceptanceTests.swift:363`)
  - `#23` `Sidebar11201AcceptanceTests/testSidebarSceneStateSurvivesBackgroundAndRotation` (`43863125434`: **PASSED** `65.470s` -> `43891893650`: **FAILED** `171.791s` @ `FaithfulReaderUIAcceptanceTests.swift:363`)
- **Exact log & AX-tree facts (`43891893650`):**
  1. Both tests launch in Landscape (`orientation = .landscapeLeft`) directly after `#21 testSidebarBodyPagingLTR` (`pid=35221`, which read `otzaria|book:3891|line:522`).
  2. Immediately on launch — **before any swipe, tap, or backgrounding** — `assertReaderHasText()` (`FaithfulReaderUIAcceptanceTests.swift:363`) timed out waiting for `reader-text.value` length `>= 31` (`XCTWaiterResult(2) != XCTWaiterResult(1)`).
  3. Attached AX trees (`9DC6D110-32F4-4BA5-8F2F-F201148E6730.txt` and `131F95CA-315C-46AF-B76A-68B61FCAF72E.txt` for `pid=42214` [`#22`], and `27B95F9C-BD50-4FDD-8DD7-C64111A863BE.txt` [`#23`]) show:
     - `reader-header-subtitle` = `'מצוה קב'`
     - `reader-current-locator` = `'otzaria|book:3891|line:523'` (`9DC6D110` line 166)
     - `reader-text` displaying **`'מיקום הטקסט השמור אינו תקין.'`** (`LibraryBackendError.invalidLocator`).
  4. In `otzaria-reader.log`: earlier launches (`pid=30153`, `32768`, `35221`) logged `[OtzariaReadingUnitService] readingUnit bookId=3891 lineIndex=523 mode=paragraph result=ok modeUnitId=toc:643037 startLineIndex=522 endLineIndex=526`. In contrast, `pid=42214` (`16:23:04.209Z`, *before* `16:23:04.700Z [NativeSceneLifecycle] event=mount pid=42214`) logged `readingUnit bookId=3891 lineIndex=522 ... result=ok`, and **neither `pid=42214` nor `pid=44252` ever logged a `readingUnit` lookup for `lineIndex=523`**.
- **Classification:** **`unknown`** (reproducible Landscape launch failure yielding `invalidLocator` on `otzaria|book:3891|line:523`; **unknown** whether caused by persisted/stale session state from `#21 testSidebarBodyPagingLTR`, an Otzaria container/DB startup race, or `OtzariaGenericBackendAdapter` / `Reader+Content` section loading; requires bounded runtime repro logging in O2).

---

## 4. Exact `4065feef` File Hashes, App/Xcode Fingerprints & Ownership Matrix

### 4.1 Build, Simulator, Xcode & Dependency Fingerprints (`43891893650`)

From `scratch/run_43891893650/hq-stage2/result.json` & `artifacts/runtime27/`:
- **Checkout Commit:** `4065feef11bd5a8997ea34364516468105778688` (matched `checkout.txt`)
- **Application Source Commit:** `d9ab40fbfa9d357dc07af8afbc847f6d7a4bbc1b` (`hq-stage2`: `SIMULATOR_BUILD_FOR_REAL_UI_PASS`)
- **macOS Host / Xcode / Swift / SDK:** `macOS 27.0.1` (`environmentDescription`), `Xcode 27.1` (`Build version 27A9275`), `Apple Swift version 6.4 (swiftlang-6.4.0.34.1 clang-2100.3.34.1)` (`arm64-apple-macosx27.0.0`), `iPhoneSimulator27.1.sdk`
- **Simulator Device & Runtime (`11-reader` & `11-window`):** `iPad Pro 11-inch (M5)` (`com.apple.CoreSimulator.SimDeviceType.iPad-Pro-11-inch-M5-12GB`), `iOS 27.2` (`24B8117`); `11-reader` UDID `36912578-CF04-4F57-A0C0-87375B2E25A4`; `11-window` UDID `478C0798-9990-497B-B736-ECB294C97B52`. *(Note: `43863125434` also executed on `iPad Pro 11-inch (M5)` / `iOS 27.2` `24B8117`.)*
- **Git Tree SHAs on `4065feef`:**
  - `Source`: `431748950e3285e600aa9d98d0c252856b429262`
  - `Vendor`: `cd543975eadf99ff8385a0a478d137a7d4b55035`
  - `Maktabah.xcodeproj`: `9abc23ee0feab18b211c85a0e2293fbc5bdce178`
  - `Maktabah-iOSUITests`: `d2e03536f29a48951c3db22858f41404a03103f9` (`test-tree.txt`)
  - `docs/hq-integration/runtime27`: `09e5092a6aa8a92b9422e3a8f7c82bbee1a3`
- **Embedded / Zayit / Package Pins (`43891893650` `hq-stage2/result.json`):**
  - Zayit (`REBUILD_EXACT_REVIEWED_RUST`, `rustc 1.100.0`): `ios-arm64/libmaktabah_zayit_search.a` `2f381b3858a55eaa8f1eeb36d5ba0176545a1b0007a7bb806d05e7b891551064`; `ios-arm64_x86_64-simulator/libmaktabah_zayit_search.a` `1a93a637d9dd689b198c262bb720a3c6c72403e404c770894b8e5ed19543a630`
  - Embedded Metro `main.jsbundle`: `6ed1fee31285b96164acc8a17ab1d9d97cbde1394e8dcdd3a1d557fe0ce377ce` (`chavrusaRPCFacade.js` `a79d71a3ccd96831818e35625eb28479d8b876b08c67d951cf46f836a47c7a6e`)
  - `Package.resolved`: `c9959df672bb641a4a5cfb729574a6c83840dabeb067d2db79ddeee0bd8adc7e` (`anchoredpopup` `f93c51e...`, `floatingpanel` `3db567a...`, `sparkle` `066e75a...`, `torahinspectorkit` `19d1b35...`, `zipfoundation` `22787ff...`, `zstd` `f8745da...`)
  - **Compiled Mach-O Binary SHAs (`built_binary_sha256`):** **ABSENT on `43891893650`** because `runtime27/result.json` was not written prior to cancellation. *(Historical `43863125434` on `51e2b7aa` recorded `Maktabah.app` = `d08b0c96486999d297287077cdc8ed62ad8902f78c73f5327cde1c3e3f75f499`, `Runner.app` = `265cf5cabad79acd24e81d8d67e985d6ac68c52ed49e101b9ff84b49d944fb83`, `Maktabah-iOSUITests.xctest` = `9c40f350c5f4d7bb179abdbbe2999eb2d7acd08bdbf2d1880fabc72e7b8b9199`.)*

### 4.2 Exact Source, Test, CI Script SHA-256 Hashes & Upstream Ownership (`4065feef`)

*(Windows Git checkout adds CRLF on disk (`wt_sha256`); Git index and macOS runners use LF (`lf_sha256`). Ownership verified against pinned upstream `d46af139b3a265399c16d87f5923acd8e3444024` and `UPSTREAM_EXCEPTION_REGISTER.md`.)*

| Repository Path | `lf_sha256` (macOS / Git LF) | `wt_sha256` (Windows CRLF) | Git `blob` SHA | Ownership / Exception Status |
|---|---|---|---|---|
| `Source/UI/iOS/Views/iPadLayout.swift` | `1426ef3f6894e2a3c031f971152f1f60872b0fd6b833b4b0231f5b283297108c` | `8277600a0dd7c783021bed90c49d0d5321bec0cecb4c5c65dcf90d677f46fdef` | `f03f6f85045afc3f73961894782c4cd3c0f24aa1` | **UPSTREAM_OWNED** (`d46af139=True`); **Owner-approved hooks applied (`4fc4058c`, `bacd3db4` -> `cb59d6f5`/`d9ab40fb`). Preserve untouched.** |
| `Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift` | `6330874e885c4fd193ede4938d34f54c42e88e54b7ddd3d95eba1c45ab70aa3f` | `9baa3e9ff76aacd2daf3ebbb3c263022bab1b73f87fd1eba74ad5cbd6a21c693` | `42287267c7d73858fa58c0da52baab863a2f0ac9` | **UPSTREAM_OWNED** (`d46af139=True`); **Owner-approved hook applied (`4fc4058c`). Preserve untouched.** |
| `Source/UI/iOS/Views/Common/ListContentView.swift` | `084f8d15e37655bf5ccd42cbdc9e308ecddd9c1cfc399a12d58089737ec8f2b1` | `b11bddccba15e5e9c70736c30c958e74f052a24b701a69a9cd8404f4c8b16df1` | `df6e248cee2391caf0a9c193c2ec343ce5ab2f45` | **UPSTREAM_OWNED** (`d46af139=True`); **Owner-approved hook applied (`bacd3db4` -> `cb59d6f5`/`d9ab40fb`). Preserve untouched.** |
| `Source/UI/iOS/Managers/iOSNavigationManager.swift` | `b8e6648cb1c6efd4942aadfe2e3aec3177fcd85fee8f502933d3f048d3311611` | `0d55b345a011d1ade0be2da44f1b9d576f16c1efb67fb16b049062aa9a3ad687` | `17ac03d083571da1c5abcb033facd23140dcc8d6` | **UPSTREAM_OWNED (`LEGACY_UNREVIEWED`)** (`d46af139=True`); Read-only without new owner approval. |
| `Source/UI/iOS/MaktabahApp.swift` | `1954ba44e312863a2a9c82641eb295365c8294ce86330e5c9e9a862780eb2647` | `70739b551a7e2eb18a5ca2b4ab310a792bcf3ade6c07588b6c810a4d8f69c4d7` | `465c81c9af7c75136898e0afe92fb80b35178d7c` | **UPSTREAM_OWNED** (`d46af139=True`); Read-only without new owner approval. |
| `Source/ChavrusaText/ReaderHost/ReaderSidebarPager.swift` | `76cae03249b1620ed6b40046fd086e03e4235b585cd773387ff4547e8540f688` | `0ab8cdabd63e8cf8f5c8c08187a42ed0e7e7bb0cad2547a1e153252f3f21e523` | `74c1350f63369c802f4bd5f79bdda45ea9683a20` | **DOWNSTREAM_OWNED** (`d46af139=False`, `Source/ChavrusaText/`) |
| `Source/ChavrusaText/Search/UI/GlobalSearchHistoryContent.swift` | `3687d11438b54cac5257c7206c75b33cff041c8072f6a0c404625d8a1ce95023` | `de2985142e3c83480d2d134091e1dfc2ab582356e4369a599de365e712636493` | `cbe1ad7febe5d439de1bc11f71b26b77afc32172` | **DOWNSTREAM_OWNED** (`d46af139=False`, `Source/ChavrusaText/`) |
| `Maktabah-iOSUITests/R27NativeInteractionAcceptanceTests.swift` | `d4ff446db4acdbb61e0ad19c14696e5194bafbba239ef86876e85a2de30e70cc` | `21b859725028bf37b0203b5b265ffc714b9b229945799672a2b5ee4a2bded2de` | `1b5ea3bd576777ba5b9a9b760bdac6b906a86a32` | **DOWNSTREAM_OWNED** (`d46af139=False`, hash-pinned in `runtime27.py:322`) |
| `Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift` | `1ddb48e617f004138e98cb8ed3437aea3b62207a8cf9e87918adc1ba5353bb13` | `69ebac168023bb834f286cada4389b6a9beff8cdc8f5e31e3ec55851181e8433` | `591c798f48cd7789b57bfe834c2ddc412236e131` | **DOWNSTREAM_OWNED** (`d46af139=False`) |
| `Maktabah-iOSUITests/Sidebar11201AcceptanceTests.swift` | `bde5eaafa0df6c151d403ad780c84f3c349af5a573324764b7ab998aa5062765` | `ae388419305295d636bb9195ee0fd239166660f677f9d6c9e9e370453949bbdf` | `403ea0e5168acddee7dbc5ceb75d6b3af248a8b6` | **DOWNSTREAM_OWNED** (`d46af139=False`) |
| `Maktabah-iOSUITests/FaithfulReaderUIAcceptanceTests.swift` | `afcb63e7b3da86bdef079afd10b30642980ecbb075df26ff1c1445e046763800` | `f19f6d93d55e9a953104e8cc3b6d15da897f0c7aa16761f925c65225f8517841` | `2ae4f2ab93a9429ad2e67dae7f210da707432f83` | **DOWNSTREAM_OWNED** (`d46af139=False`) |
| `Maktabah-iOSUITests/GlobalSearchNativeAcceptanceTests.swift` | `2827541302836a905deb80fb7ecf0ce126dbd0f907d3208c16728f8a31394374` | `14337f998534ed16197798c2b58e52101079b67c2269fe13687ec06b681dbd75` | `7235b5695297826a3307aa1bde519e4eff67fdce` | **DOWNSTREAM_OWNED** (`d46af139=False`) |
| `docs/hq-integration/runtime27/R27_CASES.json` | `d6ebe07d681e54440f58ce1b8b4945075f7047c8bce0b3a76fa98fd6fcf06875` | `11be4ff3c425f45c00ae593f8f2687ee7a6155d1c867cab2363b5b41c3f22efc` | `29a228de9710aa739a646d75d35cf40a5760fd4f` | **DOWNSTREAM_OWNED** (`d46af139=False`) |
| `Scripts/CI/runtime27.py` | `0830eeb6d04f017e4d9e275839e5e4d36af02f871c1793b8d4f69c671a77031b` | `f989d5f71b819ea45fef2800e400cd0aa0b9c5c78a2dc2778d7c8f11fb053ca3` | `c9fc401c1d542e4c2410d95acff579978f5e9214` | **DOWNSTREAM_OWNED** (`d46af139=False`) |
| `Scripts/CI/hq-stage2-focused-apple.inputs.json` | `1cf83359c70136991db0bd66b03be3cd1de5bc90918bc711634f9e3ee76cdf47` | `22f4f40c978bdf6e4823c9b93379274ff5c9442c5f5bc785c10b48b6b4808c7d` | `af21ca831d7930567afa3547b6fd34fc9b6ff843` | **DOWNSTREAM_OWNED** (`d46af139=False`) |

*(Also verified `DOWNSTREAM_OWNED` (`d46af139=False`): `Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeRoutingHost.swift`, `Source/ChavrusaText/ReaderHost/ReaderSidebarPageCoordinator.swift`, `Source/Otzaria/Compatibility/OtzariaGenericBackendAdapter.swift`, `Source/Otzaria/Reading/OtzariaReadingUnitService.swift`, `Scripts/CI/runtime27-url-delivery.py`, `Scripts/CI/run-faithful-ipad-matrix.py`. Verified `UPSTREAM_OWNED` (`d46af139=True`, read-only without new owner approval): `Source/Features/Reader/iOS/Toolbar/iOSReaderBottomToolbarView.swift`, `Source/Features/Reader/ViewModel/Extensions/Reader+Content.swift`, `Source/Features/Reader/ViewModel/Extensions/Reader+Navigation.swift`, `Source/Features/Reader/iOS/iOSReaderView.swift`.)*

---

## 5. Minimal O2 Path Candidates & Required Owner Gates

Under [`docs/architecture/UPSTREAM_INTEGRITY_POLICY.md`](../architecture/UPSTREAM_INTEGRITY_POLICY.md):
- **Settled Approvals — Do NOT Re-Request:** `cb59d6f5` / `d9ab40fb` hunks in `iPadLayout.swift`, `iOSTOCView.swift`, and `ListContentView.swift` (`EXACT_OWNER_HOOK_FINAL_VERIFICATION.json`: `"allVerified": true`). Preserve these exact files untouched.
- **Disjoint O2 Scope Separation (two non-overlapping paths):**

1. **O2-A (Warm/Replay/Refusal URL Delivery + Harness Orphan Process Fix):**
   - **Target files (`DOWNSTREAM_OWNED`, zero owner gate needed):**
     - `Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift`: In `openInExistingProcess(_:)`, explicitly detect and confirm the `com.apple.springboard` `"Open in “ChavrusaText”?"` alert (`"Open"` button — never weaken receipt/PID/refusal/replay assertions; fail closed if dialog does not complete URL delivery or triggers `"cancel-button"`). Note also `R27NativeInteractionAcceptanceTests.swift` is hash-pinned at `Scripts/CI/runtime27.py:322`, whereas `NativeRoutingAcceptanceTests.swift` is not hash-pinned.
     - `Scripts/CI/runtime27.py` (narrow driver fix): Ensure `stop_owned_process_group()` cleanly terminates the `run-faithful-ipad-matrix.py` process group on GHA `SIGTERM`/`SIGINT` before exiting so post-cancel orphan tests cannot consume runner minutes or lose `runtime27/result.json`.
   - **Conditional Owner Gate (`BLOCKED_OWNER` trigger):** Only after SpringBoard's `"Open"` prompt actually delivers `maktabah-debug://` to the running process can warm URL product behavior be observed on `4065feef`. Any downstream fix should first target `Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeRoutingHost.swift` (`DOWNSTREAM_OWNED`). Editing `Source/UI/iOS/MaktabahApp.swift` or `Source/UI/iOS/Managers/iOSNavigationManager.swift` (`UPSTREAM_OWNED`) is **blocked unless explicit owner hunk approval is obtained first**.

2. **O2-B (Global Search Contrast, Sidebar LTR Return Swipe, Landscape `isHittable`, and `invalidLocator` Triage):**
   - **Target files (`DOWNSTREAM_OWNED`, zero owner gate needed for initial candidate paths):**
     - `Source/ChavrusaText/Search/UI/GlobalSearchHistoryContent.swift`: Apply explicit high-contrast dynamic foreground styling (matching the header controls contrast fix) to `Text("חיפושים אחרונים")` (`line 31`) against `Color.appBackground`.
     - `Source/ChavrusaText/ReaderHost/ReaderSidebarPager.swift` (and `ReaderSidebarPageCoordinator.swift` if needed): Diagnose and fix `Contents -> Library` LTR body drag (`[0.25, 0.50] -> [0.75, 0.50]`) failing to select `page-0` inside the `NavigationStack`-wrapped `TabView`, preserving native scrolling and `iPadLayout.swift`.
     - Landscape `reader-more-menu` `isHittable == false` (`#1`, `#3`) & `#22/#23` `invalidLocator` (`"מיקום הטקסט השמור אינו תקין."` on `otzaria|book:3891|line:523`): Triage strictly inside downstream `ReaderSidebarPager.swift`, `OtzariaGenericBackendAdapter.swift`, `OtzariaReadingUnitService.swift`, and (for test/oracle inspection only, preserving strict user-visible assertions) `FaithfulReaderUIAcceptanceTests.swift`. Notice `R27NativePadTests` uses `FaithfulReaderUIAcceptanceTests.capture()` (`line 184`). Do **not** weaken line 194-221 hit-test assertions in `FaithfulReaderUIAcceptanceTests.swift`.
   - **Conditional Owner Gate (`BLOCKED_OWNER` trigger):** If Landscape `reader-more-menu` `isHittable == false` or `invalidLocator` requires editing `Source/Features/Reader/iOS/Toolbar/iOSReaderBottomToolbarView.swift`, `Source/Features/Reader/iOS/iOSReaderView.swift`, `Source/Features/Reader/ViewModel/...`, or re-modifying `Source/UI/iOS/Views/iPadLayout.swift`, stop and mark **`BLOCKED_OWNER`** with exact minimal patch + rejected downstream alternatives before editing protected upstream files.

---

## 6. Proposal for ONE Bounded Focused Native CI Execution (Do NOT Trigger Now)

### 6.1 Verified Workflow Filtering Constraints in `4065feef`

- **`runtime27` job (`.github/workflows/sefaria-embedded-validation.yml:100-210`):** Currently rejects `ui_diagnostic_cases != ''` (`CONFLICT` check at `line 109`). However, **`Scripts/CI/runtime27.py:29-52` ALREADY reads `"execution_case_ids"` and `"execution_groups"` from `docs/hq-integration/runtime27/R27_CASES.json`**, and this job caches `build/DerivedData` (`runtime27-derived-v2-...`, 53s restore in `43891893650`) and provides `runtime27-fixture-oracle.py` (`R27_EXPECTED_OTZARIA_WORK_KEY`, `HQ_SIDEBAR_*`), `NativeURLDelivery`, video recording, and `verify_xcresult_zero_skips.py`.
- **`validate-sefaria-embedded` job (`.github/workflows/sefaria-embedded-validation.yml:303-694`):** Accepts `ui_diagnostic_cases` (`runtime27_mode='off'`), **but** `Scripts/CI/run-faithful-ipad-matrix.py:232-239` gates `runtime27-fixture-oracle.py` (`R27_EXPECTED_OTZARIA_WORK_KEY`) on `FAITHFUL_RUNTIME27_MANIFEST` (`runtime27_contract`), runs `test-faithful-tabs-in-app.py` + `build-faithful-prototype-reference.py` overhead, and lacks `build/DerivedData` caching (~60+ min cold build). Thus `Sidebar11201AcceptanceTests` and `R27NativePadTests` **would fail on `XCTUnwrap(...["R27_EXPECTED_OTZARIA_WORK_KEY"])`** under `runtime27_mode='off'`.

### 6.2 Recommended Single Bounded Execution (Post O2-A + O2-B Merge, on Existing Workflow)

Dispatch `.github/workflows/sefaria-embedded-validation.yml` **once** against the O2 merged manager SHA (`<merged-O2-SHA>`) in **O2-bounded subset mode**:

- **Workflow file:** `.github/workflows/sefaria-embedded-validation.yml` (existing `workflow_dispatch`, no workflow YAML edit required)
- **Runner / OS / Xcode / SDK / Simulator:** `xcode-27` (`macOS 27.0.1` host, `Xcode 27.1` `Build 27A9275`, `iPhoneSimulator27.1.sdk`, `iOS 27.2 / 24B8117`, `iPad Pro 11-inch (M5) (12GB)`)
- **Dispatch Inputs:**
  - `validation_runner`: `xcode-27`
  - `runtime27_mode`: `ui`
  - `hq_stage2_expected_sha`: `<merged-40-char-O2-SHA>`
  - `run_simulator_tests`: `true`
  - `run_production_release`: `false`
  - `ui_sdk_check_only`: `false`
  - `hq_stage2_focused`: `false`
  - `books_updates_check_only`: `false`
  - `source_ref`: `''`
  - `ui_diagnostic_cases`: `''`
- **Bounded Case Selection (`R27_CASES.json` `execution_case_ids` + single `11-reader` group with `hid_comparison: false` — omitting unchanged `11-reader` passes, `11-window`, and `phone` for this focused verification, to be restored to all 27 cases in O3 final gate):**
  1. `GlobalSearchNativeAcceptanceTests/testHeaderAndHistoryNativeAccessibilityAudit`
  2. `NativeRoutingAcceptanceTests/testWarmHistoryURLUsesOtzariaNativeScene`
  3. `NativeRoutingAcceptanceTests/testWarmHistoryURLUsesLegacyNativeScene`
  4. `NativeRoutingAcceptanceTests/testWarmHistoryURLUsesEmbeddedNativeScene`
  5. `NativeRoutingAcceptanceTests/testUnknownURLVersionShowsErrorWithoutNavigatingToHistory`
  6. `NativeRoutingAcceptanceTests/testHistoryURLAfterBackgroundRequiresActualVisibleReceipt`
  7. `NativeRoutingAcceptanceTests/testWrongBackendURLCannotNavigateOrIssueNativeReceipt`
  8. `NativeRoutingAcceptanceTests/testReplayCannotIssueSecondNativeReceipt`
  9. `R27NativePadTests/testNormalBootstrapOtzariaRotationPreservesExactLocator`
  10. `R27NativePadTests/testNormalBootstrapEmbeddedGenesisAndRotation`
  11. `Sidebar11201AcceptanceTests/testSidebarBodyPagingLTR`
  12. `Sidebar11201AcceptanceTests/testSidebarBodyPagingRTL`
  13. `Sidebar11201AcceptanceTests/testSidebarSceneStateSurvivesBackgroundAndRotation`

  *(Alternative Zero-File-Edit Pre-O2 Option if an 8-case Routing/Search diagnostic is ever needed before editing `R27_CASES.json`: `sefaria-embedded-validation.yml` with `runtime27_mode='off'`, `run_simulator_tests=true`, `validation_runner='xcode-27'`, and `ui_diagnostic_cases` set to cases `#1..#8` above — valid only because those 8 tests do not read `R27_EXPECTED_OTZARIA_WORK_KEY` or `R27_HID_TOKEN`, but slower due to missing DerivedData cache.)*

- **Expected Verifiable Receipts (`runtime27-evidence` artifact):**
  1. `artifacts/runtime27/checkout.txt` == exact `<merged-40-char-O2-SHA>` and `hq-stage2/result.json` == `SIMULATOR_BUILD_FOR_REAL_UI_PASS`.
  2. `artifacts/runtime27/verified-11-reader.summary.json`: `passedTests == 13`, `failedTests == 0`, `skippedTests == 0`, `totalTestCount == 13`.
  3. `artifacts/runtime27/verified-11-reader.json`: `verify_xcresult_zero_skips.py --scope focused-ui` `PASS` on `os_major == 27`.
  4. `artifacts/native-routing-logs-11-reader/otzaria-reader.log` + `artifacts/runtime27/url-delivery-11-reader.jsonl`: `[NativeSceneLifecycle] event=url` for each confirmed warm/post-background URL, exactly one `[NativeNavigationReceipt]` per accepted warm/post-background case, zero receipts for `testUnknownURLVersion`, `testWrongBackendURL`, and second replay attempt.
  5. `artifacts/faithful-ipad-matrix.json`: `ownedSimulatorCleanup == "PASS"`.
  6. `artifacts/runtime27/result.json`: cleanly emitted with `executed_ui_pass == 13`, `executed_ui_fail == 0`, `executed_ui_skip == 0`.
  7. **Explicit Non-Acceptance Boundary:** A 13/13 focused pass only clears the O2 fixes; final Phase 1 O3 acceptance still requires restoring all **27** cases (`11-reader` [22] + `11-window` [2] + `phone` [3]) on one final coherent O3 SHA.
