# BUILD 8401: SEVEN DEFECTS FIX AND TEST REPORT

**Date:** 2026-10-25  
**Candidate Baseline Commit:** `031df35198ec5c26b901a1c9779df5156a0050ae` (`031df35`)  
**Pinned Upstream Remote Ref:** `a0ed0df908a6cb38bc459d4baaeb400f447b2fc4` (`a0ed0df`)  
**Test Runner Toolchain:** Windows Swift 6.3.3 / Portable Local Assertions  
**Candidate HEAD Commit:** `dc8dfdd2de0a59644e5e9f57c875a55320ee15d2`  
**Candidate Branch:** `validation/maktabah-build-8401-repair-production-20261025`  
**CI Verification Run:** GitHub Actions Run `40233963450` (macOS 27, Xcode 27) — **100% GREEN**  
**Component Tests:** **208 of 208 assertions PASSED (0 failures)** across 20 suites  
**Genuine iPad Simulator Acceptance Tests:** **16 of 16 tests PASSED (100%, 0 failures)**  
**iphoneos Release Compilation:** **PASSED (100% clean, 0 errors)**  
**Upstream Tree State:** `PROTECTED_TREES_UNTOUCHED` (All 12 proposed patches stored in `docs/architecture/build-8401-patches/`)  

---

## 1. Defect-by-Defect Repair & Verification Details

### Defect 1: Selected search/segment content is not visibly highlighted after opening a result
- **Original Symptom & Evidence:** Opening a search hit or segment displays unhighlighted text or transient blue UIKit selection that vanishes upon interaction.
- **Root Cause:**
  1. `RenderCacheKey` in `iOSIbarotTextView.swift:761` omitted `selectedSegmentRange` and `highlightTerms`. When selection changed without base text alteration, `lastKey == currentKey` returned `lastRenderedContent` without repainting.
  2. `didSelectSearch` set `sectionLocator == focusLocator`. `loadBackendContentInternal` evaluated `isExplicitSegmentFocus = focusLocator != locator` as `false`, resetting `selectedSegmentLocator = nil`.
- **Downstream Implementation:**
  - Implemented `ReaderDestinationResolver.swift` which separates bounded reading units from segment focus.
  - Implemented `ReaderSearchContextCoordinator.swift` maintaining active search and segment highlights across asynchronous section loads.
- **Proposed Protected Upstream Hook:**
  - `docs/architecture/build-8401-patches/01-iosibarottextview-decoration-cache-and-scroll.patch` (SHA256: `a8553bb41cce...`) adds `selectedSegmentRange` and `highlightTerms` to `RenderCacheKey`.
  - `docs/architecture/build-8401-patches/03-readercontent-bounded-destination-resolution.patch` (SHA256: `62356eee456d...`) preserves segment focus in `loadBackendContentInternal`.
  - `docs/architecture/build-8401-patches/04-readerios-search-context-and-selection.patch` (SHA256: `f50d05761b20...`) routes `didSelectSearch` through `ReaderDestinationResolver`.
- **Evidence & Verification:**
  - `Suite 11` (ReaderDestinationResolver): Asserted Rashi 15b:3:1 resolves `sectionLocator = "Rashi on Berakhot 15b"`, `focusLocator = "Rashi on Berakhot 15b:3:1"`, `isSegmentLevelFocus = true`.
  - `Suite 13` (ReaderSearchContextCoordinator): Asserted active search highlight is detected with `focusLocator` and `selectedSegmentLocator`.
- **Status:** `IMPLEMENTED_DOWNSTREAM | PROPOSED_PROTECTED_HUNK | VERIFIED_LOCAL | PENDING_OWNER_DEVICE_QA`

---

### Defect 2: Bottom-reader search highlight clear `X` button disappeared
- **Original Symptom & Evidence:** The Clear Highlights button (`xmark.circle`) adjacent to the search icon in the bottom toolbar disappeared after opening a result.
- **Root Cause:**
  1. `viewModel.hasActiveSearchHighlight` tested only `!searchText.isEmpty || highlightTerms?.isEmpty == false`, ignoring `selectedSegmentLocator` and `searchHighlightFocusLocator`.
  2. `UnifiedSearchSessionController.openResult` set `targetContentId = item.page = 0`, passing empty search context.
  3. `presentReader` passed `searchEvent: nil`, overwriting active tab's search event.
  4. `ReaderViewModel.updateContentState` wiped `searchEvent` because `searchEvent.contentId != content.id`.
  5. `onManualScrollAwayFromSearchResult` cleared highlights during programmatic scrolling.
- **Downstream Implementation:**
  - `ReaderSearchContextCoordinator.swift` governs `hasActiveSearchHighlight`, `clearTransientSearchState`, and `shouldClearAfterScroll`.
  - `UnifiedSearchSessionController.swift` preserves canonical locator and search context without dropping to zero.
- **Proposed Protected Upstream Hook:**
  - `docs/architecture/build-8401-patches/04-readerios-search-context-and-selection.patch` delegates `hasActiveSearchHighlight` and `clearSearchHighlight`.
  - `docs/architecture/build-8401-patches/05-readerviewmodel-search-event-preservation.patch` prevents clearing `searchEvent` for backend books.
  - `docs/architecture/build-8401-patches/06-iosreaderbottomtoolbarview-clear-x.patch` adds accessibility identifier for automated UI verification.
  - `docs/architecture/build-8401-patches/11-iosnavigationmanager-cold-catalog-and-search-context.patch` passes active `searchEvent` through `presentReader`.
- **Evidence & Verification:**
  - `Suite 13`: Verified programmatic scroll (`isManualUserDrag: false`) NEVER clears search highlight.
  - `Suite 13`: Verified manual scroll below threshold does not clear; above threshold clears cleanly.
  - `Suite 13`: Verified `clearTransientSearchState` clears all search context without deleting annotations.
- **Status:** `IMPLEMENTED_DOWNSTREAM | PROPOSED_PROTECTED_HUNK | VERIFIED_LOCAL | PENDING_OWNER_DEVICE_QA`

---

### Defect 3: Pull-to-previous/next: Sefaria overscroll does not navigate; Otzaria jumps to the first page of the book on the first pull
- **Original Symptom & Evidence:** In Sefaria, top/bottom overscroll does nothing. In Otzaria, overscroll navigates, but the first pull unexpectedly jumps to page 1 / line 1 of the book.
- **Root Cause:**
  1. Verified v4.2 merge regression: `goToNextPage()` and `goToPrevPage()` in `Reader+Navigation.swift` replaced pre-merge `backendSection?.next/previous` checks with direct calls to `BookConnection.getNextPage()`. `BookConnection` returns `nil` for Sefaria (dead navigation).
  2. For Otzaria, `currentID` on initial load is synthetic or 0. `OtzariaMaktabahBridge.getNextContent(after: currentId)` failed sequence lookup and reset to page 1 / line 0.
- **Downstream Implementation:**
  - `ReaderBackendPagingCoordinator.swift` determines paging action from `backendSection.next/previous` and ordered `navigationItems`.
  - Boundary encounters are handled as explicit safe no-ops (`.noOpBoundaryReached`).
- **Proposed Protected Upstream Hook:**
  - `docs/architecture/build-8401-patches/02-readernavigation-backend-paging.patch` (SHA256: `6ef8a5be2a80...`) routes `goToNextPage()` and `goToPrevPage()` through `ReaderBackendPagingCoordinator`.
- **Evidence & Verification:**
  - `Suite 12`: Verified next action loads `backendSectionNext` with `.top` scroll target.
  - `Suite 12`: Verified prev action loads `backendSectionPrevious` with `.bottom` scroll target.
  - `Suite 12`: Verified boundary reached returns `.noOpBoundaryReached` without jumping to page 1.
  - `Suite 12`: Verified non-backend books cleanly fall back to legacy `BookConnection`.
- **Status:** `IMPLEMENTED_DOWNSTREAM | PROPOSED_PROTECTED_HUNK | VERIFIED_LOCAL | PENDING_OWNER_DEVICE_QA`

---

### Defect 4: Otzaria ↔ Sefaria switching suddenly fails
- **Original Symptom & Evidence:** Switching from Otzaria to Sefaria fails silently; UI remains in Otzaria mode.
- **Root Cause:**
  1. `SettingsView.swift:239` called synchronous `backendCoordinator.commit(requestedBackend)`.
  2. `DefaultTargetBackendBookResolver.resolveBook` required `ldm.booksById` to already contain the incoming target backend books. When switching from Otzaria to Sefaria, `ldm.booksById` only had Otzaria books, throwing `unresolvableBook`.
  3. `commit` caught the error, aborted the transition, and returned `false`. `SettingsView` ignored the return value.
- **Downstream Implementation:**
  - `ChavrusaTextTargetBackendBookResolver.swift` provides cold-catalog synthesization via `MaktabahBackendAdapter.resolveBook(for:in:)`, guaranteeing valid `BooksData` with stable identities.
  - `BackendCoordinator.swift` records `lastTransitionErrorMessage` and supports async commit.
- **Proposed Protected Upstream Hook:**
  - `docs/architecture/build-8401-patches/10-settingsview-backend-switch-error-handling.patch` (SHA256: `b4d48408ac16...`) handles async commit and failure reporting.
  - `docs/architecture/build-8401-patches/11-iosnavigationmanager-cold-catalog-and-search-context.patch` (SHA256: `25f2a00fb64e...`) delegates `DefaultTargetBackendBookResolver` to `ChavrusaTextTargetBackendBookResolver.shared`.
- **Evidence & Verification:**
  - `Suite 9` (Coordinator Switch Orchestration): Verified cold-catalog resolution, rollback safety on corrupted snapshots, tabs preservation, and atomic switch with pre-resolved retained books.
- **Status:** `IMPLEMENTED_DOWNSTREAM | PROPOSED_PROTECTED_HUNK | VERIFIED_LOCAL | PENDING_OWNER_DEVICE_QA`

---

### Defect 5: Otzaria TOC current-location tracking fails when moving by gestures/arrows
- **Original Symptom & Evidence:** When paging through Otzaria books via pull gestures or toolbar buttons, the open TOC sidebar does not highlight the active section and does not auto-scroll.
- **Root Cause:**
  1. `iOSTOCView.swift:170-176` called `scrollSelected(proxy:)` only on `.onAppear` and `.onChange(of: tocViewModel.tocRanges.count)`. It never observed `.onChange(of: selectedId)`.
  2. `BookTOCViewModel.findNode(for locator:)` checked exact locator equality (`$0.backendLocator == locator`). Otzaria TOC nodes are chapter headings at specific line anchors; intermediate reading positions never matched.
- **Downstream Implementation:**
  - `TOCReadingLocationTracker.swift` matches current reading unit to the deepest visible heading (greatest heading line index <= current line index).
  - Handles Sefaria canonical ref ancestors.
- **Proposed Protected Upstream Hook:**
  - `docs/architecture/build-8401-patches/07-iostoceview-live-tracking-and-loading-state.patch` adds `.onChange(of: selectedId)`.
  - `docs/architecture/build-8401-patches/08-iosreaderworkspaceview-toc-tracking.patch` routes `selectedTOCNode` through `findMatchingNode`.
  - `docs/architecture/build-8401-patches/09-booktocviewmodel-loading-and-matching.patch` implements `findMatchingNode` delegating to `TOCReadingLocationTracker`.
- **Evidence & Verification:**
  - `Suite 14`: Verified line 125 matches Section B at line 100 in Otzaria TOC tree.
  - `Suite 14`: Verified `Rashi on Berakhot 15b:3:1` matches TOC node 15b (ancestor).
- **Status:** `IMPLEMENTED_DOWNSTREAM | PROPOSED_PROTECTED_HUNK | VERIFIED_LOCAL | PENDING_OWNER_DEVICE_QA`

---

### Defect 6: Sefaria result / linked-source opening is too granular (Rashi shows single segment with white screen)
- **Original Symptom & Evidence:** Screenshot (A) showed a tiny excerpt of `Rashi on Berakhot 15b` at the top and the remainder of the reader white, rather than the complete 15b folio with target emphasized.
- **Root Cause:**
  1. `iOSNavigationManager+OtzariaLinkedSource.swift:46-47` passed segment locator `Rashi on Berakhot 15b:3:1` as `initialContentId`.
  2. `UnifiedSearchSessionController` set `targetContentId = item.page = 0`.
  3. `Reader+Content.swift:42-55` loaded `target = initialLocator` directly from backend.
  4. Sefaria API returned only that single segment, leaving the rest of the folio white.
- **Downstream Implementation:**
  - `ReaderDestinationResolver.swift` bounds Bavli and commentaries to their containing daf/amud (e.g. `Rashi on Berakhot 15b`), and chapter books to their containing chapter (e.g. `Genesis 1`), preserving exact segment in `focusLocator`.
  - `iOSNavigationManager+OtzariaLinkedSource.swift` updated to route through `ReaderDestinationResolver`.
  - `UnifiedSearchSessionController.swift` updated to resolve bounded section identity and book data.
- **Proposed Protected Upstream Hook:**
  - `docs/architecture/build-8401-patches/03-readercontent-bounded-destination-resolution.patch` separates section loading from segment focus.
  - `docs/architecture/build-8401-patches/04-readerios-search-context-and-selection.patch` resolves bounded destinations for in-book search.
- **Evidence & Verification:**
  - `Suite 11`: Rashi 15b:3:1 resolves `sectionLocator = "Rashi on Berakhot 15b"`, `focusLocator = "Rashi on Berakhot 15b:3:1"`.
  - `Suite 11`: Genesis 1:3 resolves `sectionLocator = "Genesis 1"`, `focusLocator = "Genesis 1:3"`.
- **Status:** `IMPLEMENTED_DOWNSTREAM | PROPOSED_PROTECTED_HUNK | VERIFIED_LOCAL | PENDING_OWNER_DEVICE_QA`

---

### Defect 7: Sefaria TOC is partly English under Hebrew UI (`Chapters`, `12a`, `12b`), and displays `אין תוכן עניינים` when loading/empty
- **Original Symptom & Evidence:** Screenshot (B) showed TOC displaying `Chapters` and `12a`, `12b`. Screenshot (C) showed Eruvin displaying `אין תוכן עניינים`.
- **Root Cause:**
  1. `SefariaNavigationParser.swift:72` fell back to raw English key (`"Chapters"`).
  2. `chapterDisplayTitle` returned `SefariaRef.talmudAddress(offset:)` (`"12a"`, `"12b"`) unconditionally for Talmud, ignoring `prefersHebrew`.
  3. In `iOSTOCView.swift:117-128`, while TOC was loading asynchronously, `loadFailure == nil` and `identifiableNodes.isEmpty == true`. The view immediately displayed `ContentUnavailableView("No Table of Contents")` (`אין תוכן עניינים`).
- **Downstream Implementation:**
  - Created `TalmudHebrewAddressFormatter.swift` providing traditional Hebrew daf/amud notation (`י״ב ע״א`, `י״ב ע״ב`, `ט״ו ע״ב`, `ט״ז ע״א`).
  - Expanded `ChavrusaTextLocalizationResolver.swift` mapping navigation structures (`Chapters` -> `פרקים`, `Folios` -> `דפים`, `Parashot` -> `פרשות`, `Halakhot` -> `הלכות`, etc.).
  - Updated downstream `SefariaNavigationParser.swift` to use `TalmudHebrewAddressFormatter` and `ChavrusaTextLocalizationResolver`.
- **Proposed Protected Upstream Hook:**
  - `docs/architecture/build-8401-patches/07-iostoceview-live-tracking-and-loading-state.patch` introduces loading state check in `iOSTOCView`, replacing premature `אין תוכן עניינים` flash with a progress view.
  - `docs/architecture/build-8401-patches/09-booktocviewmodel-loading-and-matching.patch` adds `isLoading` lifecycle tracking to `BookTOCViewModel`.
- **Evidence & Verification:**
  - `Suite 10`: Verified `12a` -> `י״ב ע״א`, `12b` -> `י״ב ע״ב`, `15b` -> `ט״ו ע״ב`, `16a` -> `ט״ז ע״א`.
  - `Suite 10`: Verified `Chapters` in Hebrew -> `פרקים`, `Folios` in Hebrew -> `דפים`.
- **Status:** `IMPLEMENTED_DOWNSTREAM | PROPOSED_PROTECTED_HUNK | VERIFIED_LOCAL | PENDING_OWNER_DEVICE_QA`


---

## 2. Genuine iPad Simulator Acceptance Tests Verification (CI Run 40233963450)

All 16 genuine UI acceptance tests passed on the iOS 27 runtime on iPad Pro 13-inch simulator:

| # | Test Suite | Test Case | Duration | Status | Verified Functionality |
|:---:|---|---|:---:|:---:|---|
| 1 | `BackendTransitionAcceptanceTests` | `testBackendSwitchRegressionScenario` | 28.6s | **PASS** | Automated background backend switch snapshot regression |
| 2 | `BackendTransitionAcceptanceTests` | `testBackendSwitchViaSettingsPickerUI` | 50.3s | **PASS** | Backend switch via real Settings picker UI interaction |
| 3 | `BackendTransitionAcceptanceTests` | `testRoundTripBackendSwitchPersistsTabs` | 58.9s | **PASS** | Round-trip switch persists all open tabs and active states |
| 4 | `Build8401SevenDefectsAcceptanceTests` | `testA1_A2_SearchResultHighlightAndClearButton` | 37.1s | **PASS** | Search hit opens reader with yellow highlight & clear 'X' button; tapping 'X' dismisses button |
| 5 | `Build8401SevenDefectsAcceptanceTests` | `testA3_OrdinaryReaderHasNoClearSearchHighlightButton` | 22.6s | **PASS** | Normal reader mode does not show clear 'X' button without search origin |
| 6 | `Build8401SevenDefectsAcceptanceTests` | `testB1_B2_PagingTransitionsPreserveReaderStability` | 28.9s | **PASS** | Forward and backward paging transitions maintain reader surface & title stability |
| 7 | `Build8401SevenDefectsAcceptanceTests` | `testD1_D2_TableOfContentsTrackingAndNoPrematureEmptyState` | 21.7s | **PASS** | Live TOC auto-tracking active and no premature "אין תוכן עניינים" during load |
| 8 | `Build8401SevenDefectsAcceptanceTests` | `testF1_SefariaHebrewLocaleRTLAndHebrewHeaders` | 36.4s | **PASS** | Sefaria reader localized in Hebrew with RTL layout and Hebrew headers |
| 9 | `HighlightAnnotationAcceptanceTests` | `testAnnotationCreationPersistenceAndRelaunch` | 65.1s | **PASS** | Note creation in study notes tool, save, verification in Annotations tab, and relaunch survival |
| 10 | `HistoryLocalizationAcceptanceTests` | `testHistoryTabLocalizedInEnglishWithLTRLayout` | 23.7s | **PASS** | History tab localized in English with LTR layout |
| 11 | `HistoryLocalizationAcceptanceTests` | `testHistoryTabLocalizedInHebrewWithRTLLayout` | 21.8s | **PASS** | History tab localized in Hebrew with RTLLayout |
| 12 | `HistoryLocalizationAcceptanceTests` | `testSelectedTabRestorationAfterRelaunch` | 41.5s | **PASS** | Selected tab state restoration across app termination and relaunch |
| 13 | `PullNavigationAcceptanceTests` | `testPullNavigationCommitBothDirectionsWithoutDuplicates` | 36.0s | **PASS** | Downward & upward pull navigation commits without duplicate transitions or title blanks |
| 14 | `PullNavigationAcceptanceTests` | `testPullNavigationRetreatCancelDoesNotChangeContent` | 28.7s | **PASS** | Sub-threshold gesture retreat/cancel retains initial content and locator intact |
| 15 | `iPadTabBarAcceptanceTests` | `testiPadTabBarPersistsAcrossTOCAndInspectorTransitions` | 29.8s | **PASS** | iPad tab bar remains visible and responsive across TOC and study tool transitions |
| 16 | `iPadTabBarAcceptanceTests` | `testiPadTabBarVisibleAndHittableInReader` | 23.3s | **PASS** | iPad tab bar is visible and hittable in reader mode |

**Result:** 16 of 16 tests PASSED (100% success rate, 0 failures).
