# Maktabah Upstream v4.2 Integration — Feature Parity Report (F01–F09)

**Date:** 2026-10-21  
**Worktree:** `C:\Users\DAVID\Code\Maktabah-v42-integration`  
**Branch:** `sync/upstream-v42-full-integration`  
**Commit SHA:** `654efdc3ef141dd93f2f5348982ef2b9b5f54fc0`  

---

## Feature Parity Matrix

| ID | Feature Name | Upstream Reference | Source Implementation & Fork Hooks | Verification Status |
|---|---|---|---|:---:|
| **F01** | Durable iOS Reader Session Persistence | `b26d5ca42` (macOS), `0e44f135` (scroll cache) | `iOSReaderSessionManager.swift`, `iOSNavigationManager.swift`, `iOSMainView.swift`, `iOSReaderSessionTests.swift` | **PASS (Implemented & Tested)** |
| **F02** | Annotation Long-Press Edit/Delete | `e2462561` | `iOSBookAnnotationsView.swift`, `iOSAnnotationEditorSheet.swift`, `AnnotationCoordinator.swift` | **PASS (Verified)** |
| **F03** | Long-Press Book Info Card Trigger | `f319965f` | `iOSLibraryView.swift`, `HistoryComponents.swift`, `iOSBookInfoView.swift`, `iOSBookInfoAnchoredCard.swift` | **PASS (Verified)** |
| **F04** | Anchored Arabic/Hebrew Popovers & Overlays | `fc8d8810` | `ArabicTextRenderer.swift`, `iOSIbarotTextView.swift` (adjustedContentInset, semanticContentAttribute) | **PASS (Verified)** |
| **F05** | Annotation Sheet State Retention | `e2462561e` | `BookAnnotationsViewModel.swift`, `ReaderViewModel.swift` (`var bookAnnotationsViewModel`) | **PASS (Verified)** |
| **F06** | TOC Navigation & Line-Anchor Mapping | `f3ae62cf` | `BookTOCViewModel.swift`, `TOCNodeRow.swift`, `iOSTOCView.swift`, `OtzariaLineAnchor.swift` | **PASS (Verified)** |
| **F07** | Bottom Toolbar Layout & Navigation Stepper | `caf00054` | `iOSReaderBottomToolbarView.swift`, `LibraryNavigationItem` picker, dynamic compact/wide split | **PASS (Verified)** |
| **F08** | Non-Stale Download & Archive Progress | `a699dee9`, `15086a0c` | `CoreDatabaseDownloader.swift`, `CoreDownloadProgressView.swift` (@Observable state, cancel/retry) | **PASS (Verified)** |
| **F09** | SQLite, FTS & CloudKit Correctness | `d949effe`, `98c31415`, `4c040b5e` | `BookConnection.swift` (reset), `SingleFlight.swift`, `CloudKitUploadDebouncer.swift`, `PendingSyncCoordinator.swift` | **PASS (Verified)** |

---

## Detailed Evidence by Feature

### F01: Durable iOS Reader Session Persistence (P0 Release Blocker)
- **Problem:** User reported that closing and relaunching the app caused all open tabs, book locators, and reading positions to disappear.
- **Root Cause:** Upstream v4.2 implemented multi-tab session persistence in `ReaderStateManager` and `AppDelegate` exclusively for macOS (`WindowTabsSession`). On iOS, `iOSNavigationManager` kept tabs strictly in memory (`@State`).
- **Implementation:**
  - Created `iOSReaderSessionManager.swift`: atomic, debounced serialization of `iOSReaderSession` to Application Support `Maktabah/States/ios_reader_session.json`.
  - Captures stable tab UUIDs, active tab, book IDs, backend locators (`TextLocator`), content IDs, reading anchors, scroll positions (presentation hint), selected text ranges, TOC expanded state, and search filters.
  - Wired into `iOSNavigationManager.swift`: saves on tab addition, tab close, active tab switch, and `UIApplication.didEnterBackgroundNotification`.
  - Wired into `iOSMainView.swift`: saves immediately on `.inactive` / `.background` scene phases; restores seamlessly on `.onAppear` via `restoreSessionIfNeeded()`.
  - Added dedicated Swift Testing suite `MaktabahTests/iOSReaderSessionTests.swift` verifying complete Codable roundtrip and resilience against missing/corrupted fields.
- **Status:** **PASS (Resolved, Verified & Committed)**.

### F02: Annotation Long-Press Edit/Delete Actions
- **Implementation:** `Source/Features/Reader/iOS/Toolbar/iOSBookAnnotationsView.swift` includes `.contextMenu` with options to edit (`editingAnnotation = ann`) presenting `iOSAnnotationEditorSheet`, and delete (`deleteAnnotation(ann)`) with confirmation and coordinator synchronization.
- **Status:** **PASS**.

### F03: Long-Press Book Info Card Trigger
- **Implementation:** Both `iOSLibraryView.swift` and `HistoryComponents.swift` bind `.contextMenu` and long-press interactions to `selectedBookForInfo`, presenting `iOSBookInfoView` and anchored card previews for all books across Maktabah, Otzaria, and Sefaria backends.
- **Status:** **PASS**.

### F04: Anchored Text Selection & Popovers
- **Implementation:** `iOSIbarotTextView.swift` calculates highlight paths via `calculateHighlightPath` and adjusts for dynamic top safe area insets and RTL semantics (`forceRightToLeft`), preventing anchor drift during rotation or scrolling.
- **Status:** **PASS**.

### F05: Annotation Sheet Search & Filter Preservation
- **Implementation:** `BookAnnotationsViewModel` is held as an instance property on `ReaderViewModel` per tab. When the sheet is dismissed and reopened, query text and selected tag filters remain active without re-querying or clearing.
- **Status:** **PASS**.

### F06: TOC Navigation & Line-Anchor Mapping
- **Implementation:** `iOSTOCView.swift` and `BookTOCViewModel.swift` support fuzzy title matching, hierarchy expansion, and deep navigation to Otzaria line-anchors (`OtzariaLineAnchor`) and canonical `TextLocator` targets.
- **Status:** **PASS**.

### F07: Bottom Toolbar Layout & Navigation Stepper
- **Implementation:** `iOSReaderBottomToolbarView.swift` combines page navigation steppers with `LibraryNavigationItem` pickers for non-legacy books, adjusting spacing and control visibility automatically for iPad split columns and compact iPhones.
- **Status:** **PASS**.

### F08: Download & Archive Progress Tracking
- **Implementation:** `CoreDownloadProgressView.swift` migrated to pure `@Observable` state handling, showing byte-accurate download progress, decompression phase, retry actions, and graceful cancellation without MainActor thread stalls.
- **Status:** **PASS**.

### F09: SQLite Statement Reset, Concurrency & CloudKit Synchronization
- **Implementation:** Integrated upstream `SingleFlight` concurrency deduplication, `PendingSyncCoordinator` queue race protection, `CloudKitUploadDebouncer` echo-back suppression, and strict statement resets on all SQLite connections.
- **Status:** **PASS**.
