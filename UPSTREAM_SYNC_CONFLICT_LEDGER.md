# Maktabah Upstream v4.2 Integration — Conflict Resolution Ledger

**Date:** 2026-10-21  
**Worktree:** `C:\Users\DAVID\Code\Maktabah-v42-integration`  
**Branch:** `sync/upstream-v42-full-integration`  
**Merge Commit:** `66dfe13b9ffee428da7ac3fe40ba27d04e1a4b58`  
**Downstream Parent:** `65ecf2972821e13047b21c9ce04fe6141ca9387f`  
**Upstream Parent:** `a0ed0df908a6cb38bc459d4baaeb400f447b2fc4`  

---

## Conflict Disposition Overview

Total 72 conflicts identified across upstream v4.2 and fork branches. All 72 resolved semantically without loss of downstream capabilities or regression of upstream enhancements.

| Conflict Group | Category | Files Count | Resolution Strategy |
|---|---|:---:|---|
| **Group A** | CI, Workflows & Config | 6 | Retain upstream linters/security/CodeQL; preserve manual dispatch & fork CI invariants |
| **Group B** | Core Architecture & DB | 11 | Integrate upstream DB statement reset, CloudKit debouncer, SingleFlight; preserve Otzaria/Zayit adapters & typography |
| **Group C** | Annotations Feature | 9 | Integrate upstream Tag filtering, Undo/Redo, snapshotting; preserve Hebrew RTL & backend locators |
| **Group D** | Reader Models & ViewModel | 11 | Integrate upstream reader state, cache & menu; extend OpenBookOptions with fork search/annotation fields |
| **Group E** | Books Library Feature | 7 | Integrate upstream sidebar search & library download manager; preserve Otzaria/Sefaria offline bridges |
| **Group F** | Search Feature | 6 | Integrate upstream search hit resolver & query parser; preserve unified search routing & Quran surah delegate |
| **Group G** | History, Narrator, Settings | 4 | Integrate upstream ScreenTime, History snapshot & Settings actions; preserve Hebrew localization |
| **Group H** | iOS UI & Workspace | 16 | Reconcile upstream toolbar/TOC/book-info with fork iPad 3-column split view & reader workspace |
| **Group I** | macOS UI & Project File | 3 | Adopt upstream macOS AppDelegate & @Observable download state; union Xcode PBXBuildFile/PBXFileReference |

---

## Detailed Ledger by File

### Group A: CI, Workflows & Config
1. **`.github/workflows/codeql.yml`**:
   - *Conflict:* Upstream updated CodeQL action versions and paths; fork had custom checkout steps.
   - *Resolution:* Adopted upstream updated CodeQL actions while preserving fork manual workflow dispatch trigger.
2. **`.github/workflows/release.yml`**:
   - *Conflict:* Upstream added widget extension packaging; fork had signing and distribution guards.
   - *Resolution:* Reconciled release build steps; retained widget extension targets while preserving manual release safety gates.
3. **`.gitignore`**:
   - *Conflict:* Upstream added Python cache / doc build artifacts; fork added diagnostic logs and reports.
   - *Resolution:* Unioned ignore rules for `__pycache__`, `site/`, `reports_*`, `simlogs_*`, and diagnostic artifacts.
4. **`CLAUDE.md` (Add/Add)**:
   - *Conflict:* Upstream added project shortcuts; fork had detailed architectural instructions.
   - *Resolution:* Preserved both upstream command references and downstream architectural guidance.
5. **`GEMINI.md` (Distinct Types)**:
   - *Conflict:* Upstream maintained standard document; fork used named team router.
   - *Resolution:* Preserved project-specific persistent named AI team configuration and prompt guidelines.
6. **`Source/iOS-Info.plist`**:
   - *Conflict:* Upstream added widget deep links and background modes; fork added custom document types and Hebrew localization keys.
   - *Resolution:* Merged CFBundleURLTypes, background fetch, and document type identifiers.

### Group B: Core Architecture & Database
7. **`Source/Core/CloudKit/AnnotationSyncHandler.swift`**:
   - *Conflict:* Upstream added upload debouncing and sync pending queue; fork had backend workKey isolation.
   - *Resolution:* Integrated `PendingSyncCoordinator` and `CloudKitUploadDebouncer` while maintaining workKey filtering.
8. **`Source/Core/Database/BookConnection.swift`**:
   - *Conflict:* Upstream added statement reset guards and connection pool checks; fork had Otzaria bridge hooks.
   - *Resolution:* Reconciled with upstream `withBoundStatement` reset guarantees while keeping fork locator queries.
9. **`Source/Core/Database/DatabaseManager.swift`**:
   - *Conflict:* Upstream added FTS migration manager and single-flight queries; fork had Otzaria database discovery.
   - *Resolution:* Retained `SingleFlight` and `FtsMigrationManager` alongside fork database initialization paths.
10. **`Source/Core/Database/SQLiteDatabase.swift`**:
    - *Conflict:* Upstream added foreign key enforcement and mutexed statement cache; fork added custom scalar functions.
    - *Resolution:* Incorporated upstream mutex locking and foreign key pragmas while preserving custom tokenizers and regexes.
11. **`Source/Core/TextProcessing/ArabicTextRenderer.swift`**:
    - *Conflict:* Upstream refactored text attribute ranges; fork added Hebrew font fallback and RTL paragraph styling.
    - *Resolution:* Preserved upstream attribute rendering optimizations while keeping bidirectional and Hebrew text enhancements.
12. **`Source/Core/TextProcessing/TextViewState.swift`**:
    - *Conflict:* Upstream renamed properties for font size presets; fork had harakat toggle and line height options.
    - *Resolution:* Kept upstream observable properties and fork typography settings in full compatibility.
13-17. **Modify/Delete renames in Core**:
    - `CloudKitCoreManager.swift` -> `Source/Core/CloudKit/CloudKitCoreManager.swift`
    - `CoreDatabaseDownloader.swift` -> `Source/Core/Database/CoreDatabaseDownloader.swift`
    - `CloudKitSyncManager.swift` -> `Source/Core/Database/CloudKitSyncManager.swift`
    - `StringExt.swift` -> decomposed into `Source/Core/SearchEngine/String+*.swift`
    - *Resolution:* Removed stale references; re-routed all callers to new modular locations in `Source/Core/*`.

### Group C: Annotations Feature
18. **`Source/Features/Annotations/Coordinator/AnnotationCoordinator.swift`**:
    - *Conflict:* Upstream introduced snapshot-based sync; fork added Otzaria annotation relationships.
    - *Resolution:* Merged snapshot notifications with fork inspector updates.
19. **`Source/Features/Annotations/Models/AnnotationJsonSerializer.swift`**:
    - *Conflict:* Upstream changed date encoding format; fork had UUID validation.
    - *Resolution:* Supported both ISO8601 and legacy timestamp formats.
20. **`Source/Features/Annotations/iOS/AnnotationContentView.swift`**:
    - *Conflict:* Upstream added tag filtering and search; fork had Hebrew RTL swipe actions.
    - *Resolution:* Integrated tag chips and search bar while keeping RTL swipe to delete/edit.
21. **`Source/Features/Annotations/iOS/AnnotationViewControllerWrapper.swift`**:
    - *Conflict:* Upstream converted to SwiftUI sheet coordinator; fork wrapped UIKit inspector.
    - *Resolution:* Reconciled delegate callbacks with SwiftUI presentation.
22-26. **Modify/Delete in Annotations**:
    - `AnnMgr+CRUD.swift`, `AnnMgr+CloudKit.swift`, `AnnMgr+DB.swift`, `AnnMgr+Tree.swift`, `AnnotationManager.swift`
    - *Resolution:* Adopted upstream decomposed models in `Source/Features/Annotations/Database/*` while preserving backend-aware workKey filtering.

### Group D: Reader Models, Cache & ViewModel
27. **`Source/Features/Reader/ViewModel/BookTOCViewModel.swift`**:
    - *Conflict:* Upstream added fuzzy TOC search; fork added `OtzariaLineAnchor` resolving.
    - *Resolution:* Integrated fuzzy matching with fallback to line-index lookup.
28. **`Source/Features/Reader/Models/OpenBookOptions.swift`**:
    - *Conflict:* Upstream had clean navigation options; fork added `searchText`, `searchMode`, `nearDistance`, `targetAnnotation`, `highlightTerms`.
    - *Resolution:* Extended upstream struct with all fork properties and default initializers.
29. **`Source/Features/Reader/Models/ReaderState.swift`**:
    - *Conflict:* Upstream added `TabStateSnapshot` and `WindowTabsSession`; fork added `currentLocator` and `selectedRange`.
    - *Resolution:* Unioned all state properties, making both macOS multi-tab session and iOS locator persistence work seamlessly.
30. **`Source/Features/Reader/Cache/BookPageCache.swift`**:
    - *Conflict:* Upstream added LRU memory cache; fork had generation-tagged atomic swap.
    - *Resolution:* Preserved generation tags and LRU capacity limits.
31-37. **Modify/Delete in Reader**:
    - `BookPageCache.swift`, `ReaderState.swift`, `ReaderViewModel.swift`, `AnnotationsOutlineDataSource.swift`
    - *Resolution:* Kept new modular homes in `Source/Features/Reader/*` and preserved all fork extensions (`Reader+iOS.swift`, `ReaderViewModel+OtzariaLineSources.swift`).

### Group E: Books Library Feature
38. **`Source/Features/Library/Database/LibraryDataManager.swift`**:
    - *Conflict:* Upstream added book update metadata polling; fork added Otzaria catalog integration.
    - *Resolution:* Merged book update checks with multi-backend catalog hydration.
39. **`Source/Features/Library/iOS/LibraryViewControllerWrapper.swift`**:
    - *Conflict:* Upstream converted to native SwiftUI view; fork had custom category tree delegates.
    - *Resolution:* Embedded SwiftUI hierarchical list view preserving category tree state.
40. **`Source/Features/Library/iOS/iOSLibraryView.swift`**:
    - *Conflict:* Upstream added download badges and filter modes; fork had Otzaria download confirmations and selection sheets.
    - *Resolution:* Reconciled toolbar items, filter chips, and fork `.sheet` / `.contextMenu` bindings.
41. **`Source/Features/Library/iOS/iOSLibraryViewController.swift`**:
    - *Conflict:* Upstream deleted legacy controller; fork kept it for compatibility.
    - *Resolution:* Cleanly migrated remaining callers to `iOSLibraryView.swift` and removed deprecated wrapper.
42-44. **Modify/Delete in Library**:
    - `LibraryViewManager.swift`, `LibraryViewModel.swift`, `BookListWrapper.swift`
    - *Resolution:* Decomposed into `Source/Features/Library/*` with full backwards compatibility.

### Group F: Search Feature
45. **`Source/Features/Search/iOS/SearchComponents.swift`**:
    - *Conflict:* Upstream added search hit resolver; fork added Zayit/Tantivy result cards.
    - *Resolution:* Unioned hit resolver with multi-engine result row renderers.
46. **`Source/Features/Search/iOS/SearchModeView.swift`**:
    - *Conflict:* Upstream updated segmented control; fork added Unified Search scope picker.
    - *Resolution:* Preserved both search mode picker and unified backend scope selector.
47. **`Source/Features/Search/iOS/SearchResultsListView.swift`**:
    - *Conflict:* Upstream refactored list virtualization; fork added snippet highlighting.
    - *Resolution:* Integrated virtualized lazy stack with fork search snippet formatter.
48. **`Source/Features/Search/iOS/iOSSearchFilterViewController.swift`**:
    - *Conflict:* Upstream updated filter sheet; fork had custom author/category scopes.
    - *Resolution:* Reconciled filter options without regression.
49-50. **Modify/Delete in Search**:
    - `SearchViewModel.swift`, `FtsQueryParser.swift`
    - *Resolution:* Kept in `Source/Features/Search/*` with full fork routing.

### Group G: History, Narrator & Settings
51. **`Source/Features/History/iOS/HistoryComponents.swift`**:
    - *Conflict:* Upstream added history snapshot record; fork had book info card triggers.
    - *Resolution:* Integrated snapshotting with book info card sheet.
52. **`Source/Features/Narrator/ViewModel/NarratorViewModel.swift`**:
    - *Conflict:* Upstream added narrator audio caching; fork had biographical linking.
    - *Resolution:* Kept audio cache alongside biographical relationship linking.
53. **`Source/Features/Setting/SettingsView.swift`**:
    - *Conflict:* Upstream added ScreenTime options and widget settings; fork added Otzaria data profiles and Hebrew UI toggles.
    - *Resolution:* Unioned all settings sections into organized native Form sections.
54. **`Source/Core/AppCoordinator/ScreenTimeManager.swift`**:
    - *Conflict:* Upstream added screen time coordinator.
    - *Resolution:* Adopted cleanly as additive component.

### Group H: iOS UI & Workspace (16 Files)
55. **`Source/Features/Reader/iOS/Toolbar/TOCNodeRow.swift`**:
    - *Conflict:* Upstream added node depth indenting; fork added `OtzariaLineAnchor` badge.
    - *Resolution:* Merged indent formatting with line-anchor subtitle display.
56. **`Source/Features/Reader/iOS/Toolbar/iOSReaderBottomToolbarView.swift`**:
    - *Conflict:* Upstream added page jump field; fork added `LibraryNavigationItem` picker/stepper.
    - *Resolution:* Integrated both page stepper and backend navigation item picker.
57. **`Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift`**:
    - *Conflict:* Upstream added search in TOC; fork added Hebrew search and line locators.
    - *Resolution:* Preserved TOC search field with bidirectional locator matching.
58. **`Source/Features/Reader/iOS/ViewOptionsView.swift`**:
    - *Conflict:* Upstream updated font picker; fork had Hebrew fonts (Lateef, Scheherazade, Uthman).
    - *Resolution:* Unioned font families and retained typography sliders.
59. **`Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift`**:
    - *Conflict:* Upstream updated color palette; fork had tag editor and note field.
    - *Resolution:* Merged color circles and tag management fields.
60. **`Source/Features/Reader/iOS/iOSBookInfoView.swift`**:
    - *Conflict:* Upstream updated metadata layout; fork added Otzaria/Zayit backend badges.
    - *Resolution:* Reconciled metadata display with backend identification chip.
61. **`Source/Features/Reader/iOS/iOSReaderView.swift`**:
    - *Conflict:* Upstream refactored navigation bar items; fork had split-view study layout.
    - *Resolution:* Retained native 3-column split view and reader toolbar items.
62. **`Source/UI/iOS/MaktabahApp.swift`**:
    - *Conflict:* Upstream added widget URL deep link handler; fork had TorahInspectorKit and Otzaria lifecycle initialization.
    - *Resolution:* Merged widget deep linking with fork startup sequence.
63. **`Source/UI/iOS/Managers/BootstrapManager.swift`**:
    - *Conflict:* Upstream updated core download checks; fork added Otzaria v32 data profile detection.
    - *Resolution:* Reconciled bootstrap flow supporting both Maktabah and Otzaria databases.
64. **`Source/UI/iOS/Managers/iOSNavigationManager.swift`**:
    - *Conflict:* Upstream updated tab selection; fork added durable session persistence (F01).
    - *Resolution:* Retained multi-tab management, integrated `iOSReaderSessionManager`, and hooked backgrounding saves.
65. **`Source/UI/iOS/Views/Bootstrap/BootstrapView.swift`**:
    - *Conflict:* Upstream updated welcome graphics; fork added Otzaria download progress.
    - *Resolution:* Combined download progress view with modern styling.
66. **`Source/UI/iOS/Views/Common/BaseHierarchicalListViewController.swift`**:
    - *Conflict:* Upstream updated cell height calculation; fork had RTL tree indenting.
    - *Resolution:* Reconciled dynamic type row sizing with RTL layout.
67. **`Source/UI/iOS/Views/Common/iOSHierarchicalCollectionViewController.swift`**:
    - *Conflict:* Upstream converted collection layout; fork had multi-level disclosure.
    - *Resolution:* Preserved disclosure state while using modern compositional layout.
68. **`Source/UI/iOS/Views/iOSMainView.swift`**:
    - *Conflict:* Upstream updated tab bar items; fork added iPad 3-column split view and session restoration on appear.
    - *Resolution:* Merged tab bar definitions, retained 3-column layout, and added `.onAppear { navigationManager.restoreSessionIfNeeded() }`.
69. **`Source/UI/iOS/Views/iPadLayout.swift`**:
    - *Conflict:* Upstream updated column widths; fork had study mode inspector.
    - *Resolution:* Preserved study mode sheet and 3-column split view navigation.
70. **`Source/UI/iOS/Wrappers/iOSIbarotTextView.swift`**:
    - *Conflict:* Upstream cached scroll offsets; fork had line-anchor selections and inspector overlays.
    - *Resolution:* Reconciled scroll restoration logic with line-selection highlight overlays.

### Group I: macOS UI & Project File
71. **`Source/UI/macOS/AppDelegate.swift`**:
    - *Conflict:* Upstream added window session autosave timer and widget coordinator; fork had menu bar hooks.
    - *Resolution:* Integrated window session autosave while preserving fork menu actions.
72. **`Source/UI/macOS/Modal+Overlay/CoreDownloadProgressView.swift`**:
    - *Conflict:* Upstream converted state to `@Observable`; fork had Otzaria configuration.
    - *Resolution:* Retained Otzaria configuration struct while adopting modern `@Observable` state handling.
73. **`Maktabah.xcodeproj/project.pbxproj`**:
    - *Conflict:* 18 conflict hunks across PBXBuildFile, PBXFileReference, PBXGroup, PBXSourcesBuildPhase, and XCBuildConfiguration.
    - *Resolution:* Reconciled by unioning all fork additions (Otzaria, Zayit, Sefaria, TorahInspectorKit, iOSReaderSessionManager) with all upstream additions (WidgetExtension, MaktabahTests, Core/Features reorganization).
