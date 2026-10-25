# BUILD 8401: SEVEN DEFECTS ROOT CAUSE MATRIX

**Date:** 2026-10-25  
**Baseline Git SHAs Verified:**
- Pre-merge Fork Baseline: `65ecf2972821e13047b21c9ce04fe6141ca9387f` (`65ecf29`)
- Post-v4.2 Merge Baseline: `c8defbf812d34dd22ea1b7b63b1a356c0e96fa8f` (`c8defbf`)
- Build 8401 Candidate (Tested App Code): `031df35198ec5c26b901a1c9779df5156a0050ae` (`031df35`)
- Pinned Upstream Remote Ref: `a0ed0df908a6cb38bc459d4baaeb400f447b2fc4` (`a0ed0df`)
- Current Branch HEAD: `a45445e377318ac2f6e9dbda624d1cd86c9a3fc9` (`a45445e`, docs-only commit)

---

## 1. Executive Root Cause Matrix

| Defect ID | User Symptom & Screenshot | Historical Classification | Introduced Commit | Proven Root Cause Mechanism | Downstream-Owned Seam | Protected Upstream Seam (Requires Owner Approval) | Required Regression Test |
|:---:|---|---|:---:|---|---|---|:---:|
| **#1** | **Search / segment content not highlighted** after opening result; transient blue UIKit selection disappears. | v4.2 Merge Regression & Design Flaw | `c8defbf` | 1. `RenderCacheKey` in `iOSIbarotTextView.swift` omits `selectedSegmentRange` and `highlightTerms`. Cached rendered content is returned on re-render.<br>2. `didSelectSearch` sets `LibraryReaderDestination(sectionLocator: loc, focusLocator: loc)`. `loadBackendContentInternal` treats equal locators as `isExplicitSegmentFocus = false`, resetting `selectedSegmentLocator = nil`. | `ReaderDestinationResolver.swift`<br>`ReaderSelectionRangeMapper.swift`<br>`ReaderSearchHighlightPolicy` | `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift:712-765`<br>`Source/Features/Reader/ViewModel/Extensions/Reader+Content.swift:108-114`<br>`Source/Features/Reader/ViewModel/Extensions/Reader+iOS.swift:68-87` | **H1**, **H2**, **H5** |
| **#2** | **Bottom search-clear `X` button disappeared** next to magnifying glass after opening result. | v4.2 Merge Regression & Search Context Lifecycle Flaw | `c8defbf` / Batch B | 1. `hasActiveSearchHighlight` only checks `!searchText.isEmpty \|\| highlightTerms?.isEmpty == false`; ignores `selectedSegmentLocator` / `searchHighlightFocusLocator`.<br>2. `UnifiedSearchSessionController.openResult` sets `item.page` (which is `0` for Sefaria), passing empty or detached context.<br>3. `presentReader` sets `searchEvent: nil` in `OpenBookOptions`, overwriting existing tab's `searchEvent`.<br>4. `ReaderViewModel.updateContentState` clears `searchEvent` because `searchEvent.contentId != content.id`.<br>5. `onManualScrollAwayFromSearchResult` in `iOSReaderView` prematurely triggers `clearSearchHighlight()` on programmatic scroll. | `ReaderSearchContextCoordinator.swift`<br>`UnifiedSearchSessionController.swift:370-384`<br>`MaktabahBackendAdapter.swift:105-135` | `Source/Features/Reader/iOS/Toolbar/iOSReaderBottomToolbarView.swift:64-72`<br>`Source/Features/Reader/ViewModel/Extensions/Reader+iOS.swift:89-103`<br>`Source/Features/Reader/ViewModel/ReaderViewModel.swift:290-295`<br>`Source/UI/iOS/Managers/iOSNavigationManager.swift:530-587` | **H3**, **H4** |
| **#3** | **Pull-to-previous/next:**<br>• Sefaria: top/bottom overscroll does not navigate.<br>• Otzaria: first pull unexpectedly jumps to first page of book. | Verified v4.2 Merge Regression | `c8defbf` | 1. In `65ecf29`, `goToNextPage()` / `goToPrevPage()` called `loadBackendContent(backendSection.next/prev)`. In `c8defbf`, upstream replaced them with calls to `BookConnection.getNextPage()`. `BookConnection` returns `nil` for Sefaria books (overscroll dead).<br>2. For Otzaria, `currentID` on initial load is a synthetic `LegacyIdentityRegistry` ID or `0`. `OtzariaMaktabahBridge.getNextContent(after: currentId)` fails to locate sequence position and resets to line 0 / page 1. | `ReaderBackendPagingCoordinator.swift`<br>`OtzariaMaktabahBridge.swift` | `Source/Features/Reader/ViewModel/Extensions/Reader+Navigation.swift:16-41`<br>`Source/Features/Reader/iOS/iOSReaderView.swift:266-267` | **P1**, **P2**, **P3**, **P4** |
| **#4** | **Otzaria ↔ Sefaria switching fails** (at least one real user route). | Batch B Candidate Architecture Gap | `031df35` | 1. `SettingsView.swift:239` calls `backendCoordinator.commit(requestedBackend)` synchronously.<br>2. Synchronous `commit` invokes `prepareTransition` which calls `DefaultTargetBackendBookResolver.resolveBook`.<br>3. `DefaultTargetBackendBookResolver` looks up target books in `LibraryDataManager.shared.booksById`. In Otzaria mode, `booksById` has NOT loaded Sefaria books, throwing `unresolvableBook`.<br>4. `commit` catches error, returns `false`, and fails silently. | `BackendCoordinator.swift:316-360`<br>`DefaultTargetBackendBookResolver.swift`<br>`MaktabahBackendAdapter.swift:195-254` | `Source/Features/Setting/SettingsView.swift:225-251`<br>`Source/UI/iOS/Managers/iOSNavigationManager.swift:631-705, 982-1025` | **B1**, **B2**, **B3** |
| **#5** | **Otzaria TOC current-location tracking fails** when moving by gestures/arrows. | Pre-existing Fork Limitation & Missing UI Observation | `65ecf29` / `c8defbf` | 1. `iOSTOCView.swift:170-176` calls `scrollSelected(proxy:)` ONLY on `.onAppear` and `.onChange(of: tocRanges.count)`. It never observes `selectedId`.<br>2. `BookTOCViewModel.findNode(for locator:)` requires exact `TextLocator` equality (`$0.backendLocator == locator`). Otzaria TOC nodes are chapter/subchapter headings; intermediate reading positions never equal heading locators.<br>3. `tocRanges` are constructed with `start: $0.id, end: $0.id` using synthetic IDs, breaking range lookups. | `TOCReadingLocationTracker.swift`<br>`BackendTOCRangeMapper.swift` | `Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift:170-192`<br>`Source/Features/Reader/ViewModel/BookTOCViewModel.swift:234-255`<br>`Source/Features/Reader/iOS/iOSReaderWorkspaceView.swift:186-192` | **T1**, **T2** |
| **#6** | **Sefaria result / linked-source opening is too granular:** Rashi shows single segment with white screen (Screenshot A). | Pre-existing Fork Architectural Conflation | `65ecf29` / `c8defbf` | 1. `iOSNavigationManager+OtzariaLinkedSource.swift:46-47` passes exact segment locator (`Rashi on Berakhot 15b:3:1`) as `initialContentId`.<br>2. `UnifiedSearchSessionController` sets `targetContentId = item.page = 0`.<br>3. `Reader+Content.swift:42-55` loads `target = initialLocator` directly from backend.<br>4. Remote/offline store returns single segment text for `15b.3.1` instead of folio `15b`.<br>5. `LibraryReaderDestination` conflates `sectionLocator` and `focusLocator`. | `ReaderDestinationResolver.swift`<br>`SefariaRef.swift`<br>`UnifiedSearchSessionController.swift:359-425`<br>`iOSNavigationManager+OtzariaLinkedSource.swift:20-49` | `Source/Features/Reader/ViewModel/Extensions/Reader+Content.swift:42-140`<br>`Source/Features/Reader/ViewModel/Extensions/Reader+iOS.swift:68-87` | **S1**, **S2** |
| **#7** | **Sefaria TOC is partly English** (`Chapters`, `12a`, `12b`), and displays `אין תוכן עניינים` when loading/empty (Screenshots B & C). | Pre-existing Localization Gap & Missing Asynchronous Loading State | `65ecf29` / `c8defbf` | 1. `SefariaNavigationParser.swift:72` falls back to raw English `key` (`"Chapters"`).<br>2. `chapterDisplayTitle` returns `SefariaRef.talmudAddress` (`"12a"`, `"12b"`) unconditionally for Talmud, ignoring `prefersHebrew`.<br>3. In `iOSTOCView.swift:117-128`, while TOC is loading asynchronously, `loadFailure == nil` and `identifiableNodes.isEmpty == true`. The view immediately renders `ContentUnavailableView("No Table of Contents")` (`אין תוכן עניינים`). | `SefariaNavigationParser.swift:31-79, 410-420`<br>`ChavrusaTextLocalizationResolver.swift`<br>`TalmudHebrewAddressFormatter.swift` | `Source/Features/Reader/ViewModel/BookTOCViewModel.swift:50-105`<br>`Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift:117-128` | **L1**, **L2**, **L3** |

---

## 2. Commit Blobs & Historical Verification

### Defect 1: Decoration Inputs in Cache Key
- `65ecf29:Source/UI/iOS/Wrappers/iOSIbarotTextView.swift` contained `DecorationSignature` computing `hasher.combine(selectedSegmentRange)` and `hasher.combine(highlightTerms)`.
- `c8defbf:Source/UI/iOS/Wrappers/iOSIbarotTextView.swift:761` introduced `struct RenderCacheKey: Equatable` containing only:
  ```swift
  bookId: Int?, contentId: Int, text: String, annotations: [Annotation],
  searchEventId: UUID?, showHarakat: Bool, clickableAnnotation: Bool,
  enhancedUnderline: Bool, isMultiLanguage: Bool, isImported: Bool,
  fontName: String, fontSize: CGFloat, lineHeight: Double
  ```
  `selectedSegmentRange` and `highlightTerms` were omitted, causing `lastRenderedContent` to be returned when selection changed.

### Defect 2: Search Context Destruction
- `031df35:Source/Features/Reader/ViewModel/ReaderViewModel.swift:290-292`:
  ```swift
  if let searchEvent, searchEvent.contentId != content.id {
      self.searchEvent = nil
  }
  ```
  `searchEvent.contentId` was populated with `result.bookId` (or 0), while `content.id` was the section identifier. This wiped `searchEvent` on every section transition.
- `031df35:Source/UI/iOS/Managers/iOSNavigationManager.swift:533`:
  `OpenBookOptions(contentId: initialContentId, searchEvent: nil, ...)` explicitly passed `nil` searchEvent.

### Defect 3: Navigation Next/Previous Regression
- `65ecf29:Source/Managers/ViewModels/ReaderViewModel.swift:520-554`:
  ```swift
  func goToNextPage() {
      if let locator = backendSection?.next {
          #if os(iOS)
          pendingReaderScrollTarget = .top
          #endif
          loadBackendContent(locator)
          return
      }
      ...
  }
  ```
- `c8defbf:Source/Features/Reader/ViewModel/Extensions/Reader+Navigation.swift:33-41`:
  ```swift
  func goToNextPage() {
      guard let content = navigateToPage(direction: .next) else { return }
      updateContentState(with: content)
  }
  ```
  Where `navigateToPage` called `bookConnection.getNextPage(...)`. `backendSection?.next` was completely deleted.

### Defect 4: Synchronous Switch Failure
- `031df35:Source/Features/Setting/SettingsView.swift:239`:
  Called `backendCoordinator.commit(requestedBackend)`.
- `031df35:Source/LibraryBackend/BackendCoordinator.swift:316`:
  Synchronous `commit` ran `performTwoPhaseSwitch` -> `participant.prepareTransition`.
- `031df35:Source/UI/iOS/Managers/iOSNavigationManager.swift:982-1025`:
  `DefaultTargetBackendBookResolver.resolveBook` required `ldm.booksById[id]` or `ldm.booksById.values.first(where: { $0.backendLocator?.workKey == locator })`.
  In Otzaria mode, `ldm.booksById` contains only Otzaria books. Sefaria was never found, throwing `BackendTransitionError.unresolvableBook`.

### Defect 5: TOC Location Tracking
- `031df35:Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift:170-176`:
  ```swift
  .onAppear { scrollSelected(proxy: proxy) }
  .onChange(of: tocViewModel.tocRanges.count) { _, _ in scrollSelected(proxy: proxy) }
  ```
  Missing `.onChange(of: selectedId)`.
- `031df35:Source/Features/Reader/ViewModel/BookTOCViewModel.swift:252-255`:
  `allNodes.first { $0.backendLocator == locator }` exact equality only.

### Defect 6: Passage vs Bounded Reading Unit
- `031df35:Source/Otzaria/Reading/iOSNavigationManager+OtzariaLinkedSource.swift:46-47`:
  ```swift
  let initialContentId = LegacyIdentityRegistry.shared.id(for: targetLocator)
  openBookInNewTab(book, initialContentId: initialContentId)
  ```
  Passed segment locator `Rashi on Berakhot 15b:3:1` as initial content ID.
- `031df35:Source/Features/Reader/ViewModel/Extensions/Reader+Content.swift:108-114`:
  ```swift
  let isExplicitSegmentFocus = focusLocator != nil && focusLocator != locator
  currentDestination = LibraryReaderDestination(
      sectionLocator: locator,
      focusLocator: isExplicitSegmentFocus ? focusLocator : nil
  )
  selectedSegmentLocator = isExplicitSegmentFocus ? focusLocator : nil
  ```
  Equal locators disabled segment focus.

### Defect 7: English Sefaria TOC & `אין תוכן עניינים` Flash
- `031df35:Source/Sefaria/Domain/SefariaNavigationParser.swift:72`:
  ```swift
  } else {
      title = key
  }
  ```
  `"Chapters"` mapped to `"Chapters"`.
- `031df35:Source/Sefaria/Domain/SefariaNavigationParser.swift:410-413`:
  ```swift
  static func chapterDisplayTitle(offset: Int, type: String?, prefersHebrew: Bool) -> String {
      if type == "Talmud" {
          return SefariaRef.talmudAddress(offset: offset)
      }
  ...
  ```
  Returned `"12a"`, `"12b"` regardless of `prefersHebrew`.
- `031df35:Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift:123-128`:
  ```swift
  } else if identifiableNodes.isEmpty {
      ContentUnavailableView(String(localized: "No Table of Contents"), systemImage: "list.bullet.rectangle")
  }
  ```
  Displayed `אין תוכן עניינים` while `identifiableNodes` were still asynchronously fetching.
