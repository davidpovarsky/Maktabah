# Upstream Hunk Migration Ledger — Complete 106-Path & 1479-Hunk Inventory

**Baseline:** Pinned Upstream `a0ed0df908a6cb38bc459d4baaeb400f447b2fc4`, Pre-merge Fork `65ecf2972821e13047b21c9ce04fe6141ca9387f`, Audited Fork `c8defbf812d34dd22ea1b7b63b1a356c0e96fa8f`.
**Total Divergent Upstream Paths:** 106 | **Total Hunks Cataloged:** 1479

## Programmatic Category Summary

| Category | Hunk Count | % of Total | Description |
|---|---|---|---|
| `CONFIG_OR_LOCALIZATION` | 733 | 49.6% | Localization strings in Source/Localizable.xcstrings and InfoPlist |
| `DOWNSTREAM_EXTRACT` | 553 | 37.4% | Downstream features designed for extraction to fork-owned ChavrusaText layers (READY_FOR_HOOK / NOT_IN_APP) |
| `LEGACY_UNREVIEWED` | 14 | 0.9% | Historical pre-merge debt awaiting disposition |
| `UPSTREAM_RESTORE` | 1 | 0.1% | Upstream regression to restore (iOSReaderView.swift:119 unconditional hide removal) |
| `VENDOR_OR_SHARED_SEAM` | 178 | 12.0% | Controlled composition seams: project.pbxproj, entitlements, models with TextLocator |

**Classification Rigor:** 3 hunks manually traced and verified in depth (P0 regressions & audited seams); 1237 hunks classified by deterministic path/module rules; 239 hunks classified by static structural heuristic (REVIEW_REQUIRED before Batch B migration).

## Divergent Path Summary Table (All 106 Paths)

| # | Path | Area | Hunks | Category | Target Replacement / Seam | Review Status |
|---|---|---|---|---|---|---|
| 1 | `.github/jules-review-rules.md` | Build / CI | 1 | `VENDOR_OR_SHARED_SEAM` | `Configuration / Integration files` | `RULES_BASED` |
| 2 | `.github/workflows/codeql.yml` | Build / CI | 2 | `VENDOR_OR_SHARED_SEAM` | `Configuration / Integration files` | `RULES_BASED` |
| 3 | `.github/workflows/pr-review.yml` | Build / CI | 2 | `VENDOR_OR_SHARED_SEAM` | `Configuration / Integration files` | `RULES_BASED` |
| 4 | `.github/workflows/release.yml` | Build / CI | 15 | `VENDOR_OR_SHARED_SEAM` | `Configuration / Integration files` | `RULES_BASED` |
| 5 | `.gitignore` | Other | 1 | `VENDOR_OR_SHARED_SEAM` | `Configuration / Integration files` | `RULES_BASED` |
| 6 | `CLAUDE.md` | Other | 1 | `VENDOR_OR_SHARED_SEAM` | `Configuration / Integration files` | `RULES_BASED` |
| 7 | `GEMINI.md` | Other | 1 | `VENDOR_OR_SHARED_SEAM` | `Configuration / Integration files` | `RULES_BASED` |
| 8 | `Maktabah.xcodeproj/project.pbxproj` | Build / CI | 1 | `VENDOR_OR_SHARED_SEAM` | `Controlled integration seam (project.pbxproj)` | `RULES_BASED` |
| 9 | `Source/Core/CloudKit/AnnotationSyncHandler.swift` | Database + Sync | 4 | `VENDOR_OR_SHARED_SEAM` | `Source/ChavrusaText/Storage/` | `RULES_BASED` |
| 10 | `Source/Core/CloudKit/CloudKitCoreManager.swift` | Database + Sync | 13 | `VENDOR_OR_SHARED_SEAM` | `Source/ChavrusaText/Storage/` | `RULES_BASED` |
| 11 | `Source/Core/Configuration/UserDefaults.swift` | Core | 2 | `LEGACY_UNREVIEWED` | `TBD via owner review` | `HEURISTIC` |
| 12 | `Source/Core/Database/BookConnection.swift` | Database + Sync | 33 | `VENDOR_OR_SHARED_SEAM` | `Source/ChavrusaText/Storage/` | `RULES_BASED` |
| 13 | `Source/Core/Database/CloudKitSyncManager.swift` | Database + Sync | 7 | `VENDOR_OR_SHARED_SEAM` | `Source/ChavrusaText/Storage/` | `RULES_BASED` |
| 14 | `Source/Core/Database/CoreDatabaseDownloader.swift` | Database + Sync | 2 | `VENDOR_OR_SHARED_SEAM` | `Source/ChavrusaText/Storage/` | `RULES_BASED` |
| 15 | `Source/Core/Database/DatabaseManager.swift` | Database + Sync | 13 | `VENDOR_OR_SHARED_SEAM` | `Source/ChavrusaText/Storage/` | `RULES_BASED` |
| 16 | `Source/Core/Database/SQLiteDatabase.swift` | Database + Sync | 9 | `VENDOR_OR_SHARED_SEAM` | `Source/ChavrusaText/Storage/` | `RULES_BASED` |
| 17 | `Source/Core/Database/ZstdShim.swift` | Database + Sync | 4 | `VENDOR_OR_SHARED_SEAM` | `Source/ChavrusaText/Storage/` | `RULES_BASED` |
| 18 | `Source/Core/SearchEngine/SearchMode.swift` | Upstream Search | 2 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/` | `HEURISTIC` |
| 19 | `Source/Core/TextProcessing/ArabicTextRenderer.swift` | Core | 14 | `VENDOR_OR_SHARED_SEAM` | `Source/ChavrusaText/ReaderRendering/` | `RULES_BASED` |
| 20 | `Source/Core/TextProcessing/String+TextCleaning.swift` | Core | 4 | `VENDOR_OR_SHARED_SEAM` | `Source/ChavrusaText/ReaderRendering/` | `RULES_BASED` |
| 21 | `Source/Core/TextProcessing/StringExt.swift` | Core | 1 | `VENDOR_OR_SHARED_SEAM` | `Source/ChavrusaText/ReaderRendering/` | `RULES_BASED` |
| 22 | `Source/Core/TextProcessing/TextStorage.swift` | Core | 4 | `VENDOR_OR_SHARED_SEAM` | `Source/ChavrusaText/ReaderRendering/` | `RULES_BASED` |
| 23 | `Source/Core/TextProcessing/TextViewState.swift` | Core | 3 | `VENDOR_OR_SHARED_SEAM` | `Source/ChavrusaText/ReaderRendering/` | `RULES_BASED` |
| 24 | `Source/Features/Annotations/Coordinator/AnnotationCoordinator.swift` | Upstream Annotations | 6 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/Annotations/BackendAnnotationBridge.swift` | `RULES_BASED` |
| 25 | `Source/Features/Annotations/Database/AnnotationRepository.swift` | Upstream Annotations | 7 | `VENDOR_OR_SHARED_SEAM` | `Source/ChavrusaText/Annotations/` | `RULES_BASED` |
| 26 | `Source/Features/Annotations/Models/Annotation.swift` | Upstream Annotations | 3 | `VENDOR_OR_SHARED_SEAM` | `Source/ChavrusaText/Annotations/` | `RULES_BASED` |
| 27 | `Source/Features/Annotations/Models/AnnotationJsonSerializer.swift` | Upstream Annotations | 5 | `VENDOR_OR_SHARED_SEAM` | `Source/ChavrusaText/Annotations/` | `RULES_BASED` |
| 28 | `Source/Features/Annotations/iOS/AnnotationContentView.swift` | Upstream Annotations | 5 | `LEGACY_UNREVIEWED` | `TBD via owner review` | `HEURISTIC` |
| 29 | `Source/Features/Annotations/iOS/AnnotationViewControllerWrapper.swift` | Upstream Annotations | 1 | `LEGACY_UNREVIEWED` | `TBD via owner review` | `HEURISTIC` |
| 30 | `Source/Features/Annotations/macOS/OutlineView/AnnotationRowHeightCalculator.swift` | Upstream Annotations | 1 | `LEGACY_UNREVIEWED` | `TBD via owner review` | `HEURISTIC` |
| 31 | `Source/Features/Annotations/macOS/OutlineView/AnnotationsOutlineDelegate.swift` | Upstream Annotations | 1 | `LEGACY_UNREVIEWED` | `TBD via owner review` | `HEURISTIC` |
| 32 | `Source/Features/History/ViewModel/Extensions/History+Core.swift` | Upstream History | 1 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/Library/History/` | `RULES_BASED` |
| 33 | `Source/Features/History/ViewModel/Extensions/History+Database.swift` | Upstream History | 2 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/Library/History/` | `RULES_BASED` |
| 34 | `Source/Features/History/ViewModel/HistoryViewModel.swift` | Upstream History | 2 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/Library/History/` | `RULES_BASED` |
| 35 | `Source/Features/History/iOS/HistoryComponents.swift` | Upstream History | 5 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/Library/History/` | `RULES_BASED` |
| 36 | `Source/Features/History/iOS/HistoryFavoriteSections.swift` | Upstream History | 2 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/Library/History/` | `RULES_BASED` |
| 37 | `Source/Features/Library/Database/LibraryDataManager.swift` | Upstream Library | 27 | `DOWNSTREAM_EXTRACT` | `Source/LibraryBackend/LibraryDataManagerAdapter.swift` | `RULES_BASED` |
| 38 | `Source/Features/Library/Models/BooksData.swift` | Upstream Library | 6 | `VENDOR_OR_SHARED_SEAM` | `Source/LibraryBackend/` | `RULES_BASED` |
| 39 | `Source/Features/Library/Models/CategoryData.swift` | Upstream Library | 4 | `VENDOR_OR_SHARED_SEAM` | `Source/LibraryBackend/` | `RULES_BASED` |
| 40 | `Source/Features/Library/ViewModel/Extensions/BulkActionLibrary.swift` | Upstream Library | 3 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/Library/` | `RULES_BASED` |
| 41 | `Source/Features/Library/ViewModel/Extensions/FilterLibrary.swift` | Upstream Library | 3 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/Library/` | `RULES_BASED` |
| 42 | `Source/Features/Library/ViewModel/Extensions/ObserversLibrary.swift` | Upstream Library | 1 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/Library/` | `RULES_BASED` |
| 43 | `Source/Features/Library/ViewModel/LibraryViewModel.swift` | Upstream Library | 13 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/Library/` | `RULES_BASED` |
| 44 | `Source/Features/Library/iOS/AuthorModeView.swift` | Upstream Library | 6 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/Library/` | `RULES_BASED` |
| 45 | `Source/Features/Library/iOS/LibraryViewControllerWrapper.swift` | Upstream Library | 5 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/Library/` | `RULES_BASED` |
| 46 | `Source/Features/Library/iOS/iOSLibraryView.swift` | Upstream Library | 3 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/Library/` | `RULES_BASED` |
| 47 | `Source/Features/Library/iOS/iOSLibraryViewController.swift` | Upstream Library | 2 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/` | `HEURISTIC` |
| 48 | `Source/Features/Narrator/ViewModel/NarratorViewModel.swift` | Other | 4 | `LEGACY_UNREVIEWED` | `TBD via owner review` | `HEURISTIC` |
| 49 | `Source/Features/Reader/Cache/BookPageCache.swift` | Upstream Reader | 1 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/` | `HEURISTIC` |
| 50 | `Source/Features/Reader/Models/BookContent.swift` | Upstream Reader | 3 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/` | `HEURISTIC` |
| 51 | `Source/Features/Reader/Models/CleanedTextKey.swift` | Upstream Reader | 1 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/` | `HEURISTIC` |
| 52 | `Source/Features/Reader/Models/OpenBookOptions.swift` | Upstream Reader | 3 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/` | `HEURISTIC` |
| 53 | `Source/Features/Reader/Models/ProcessedArabicContent.swift` | Upstream Reader | 3 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/` | `HEURISTIC` |
| 54 | `Source/Features/Reader/Models/ReaderState.swift` | Upstream Reader | 5 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/` | `HEURISTIC` |
| 55 | `Source/Features/Reader/Models/TOC.swift` | Upstream Reader | 2 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/` | `HEURISTIC` |
| 56 | `Source/Features/Reader/Models/TOCNode.swift` | Upstream Reader | 3 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/` | `HEURISTIC` |
| 57 | `Source/Features/Reader/ViewModel/BookTOCViewModel.swift` | Upstream Reader | 12 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/` | `HEURISTIC` |
| 58 | `Source/Features/Reader/ViewModel/Extensions/Reader+Annotation.swift` | Upstream Reader | 8 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/Annotations/BackendAnnotationBridge.swift` | `RULES_BASED` |
| 59 | `Source/Features/Reader/ViewModel/Extensions/Reader+Content.swift` | Upstream Reader | 5 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/Annotations/BackendAnnotationBridge.swift` | `RULES_BASED` |
| 60 | `Source/Features/Reader/ViewModel/Extensions/Reader+Navigation.swift` | Upstream Reader | 5 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/` | `HEURISTIC` |
| 61 | `Source/Features/Reader/ViewModel/Extensions/Reader+iOS.swift` | Upstream Reader | 6 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/` | `HEURISTIC` |
| 62 | `Source/Features/Reader/ViewModel/ReaderViewModel.swift` | Upstream Reader | 24 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/` | `HEURISTIC` |
| 63 | `Source/Features/Reader/iOS/Toolbar/TOCNodeRow.swift` | Upstream Reader | 4 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/` | `HEURISTIC` |
| 64 | `Source/Features/Reader/iOS/Toolbar/iOSBookSearchView.swift` | Upstream Reader | 6 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/` | `HEURISTIC` |
| 65 | `Source/Features/Reader/iOS/Toolbar/iOSReaderBottomToolbarView.swift` | Upstream Reader | 9 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/` | `HEURISTIC` |
| 66 | `Source/Features/Reader/iOS/Toolbar/iOSReaderNavigationPopoverView.swift` | Upstream Reader | 14 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/` | `HEURISTIC` |
| 67 | `Source/Features/Reader/iOS/Toolbar/iOSReaderTabsPopoverView.swift` | Upstream Reader | 1 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/` | `HEURISTIC` |
| 68 | `Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift` | Upstream Reader | 9 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/` | `HEURISTIC` |
| 69 | `Source/Features/Reader/iOS/ViewOptionsView.swift` | Upstream Reader | 4 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/` | `HEURISTIC` |
| 70 | `Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift` | Upstream Reader | 20 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/` | `HEURISTIC` |
| 71 | `Source/Features/Reader/iOS/iOSBookInfoView.swift` | Upstream Reader | 13 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/` | `HEURISTIC` |
| 72 | `Source/Features/Reader/iOS/iOSReaderTabView.swift` | Upstream Reader | 8 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/` | `HEURISTIC` |
| 73 | `Source/Features/Reader/iOS/iOSReaderView.swift` | Upstream Reader | 22 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/ReaderHost/iOSReaderHostView.swift` | `RULES_BASED` |
| 74 | `Source/Features/Search/Models/CopyableResult.swift` | Upstream Search | 2 | `VENDOR_OR_SHARED_SEAM` | `Source/ChavrusaText/Search/` | `RULES_BASED` |
| 75 | `Source/Features/Search/Models/SearchResultItem.swift` | Upstream Search | 9 | `VENDOR_OR_SHARED_SEAM` | `Source/ChavrusaText/Search/` | `RULES_BASED` |
| 76 | `Source/Features/Search/ViewModel/Extensions/Search+Execution.swift` | Upstream Search | 5 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/Search/` | `RULES_BASED` |
| 77 | `Source/Features/Search/ViewModel/Extensions/Search+Library.swift` | Upstream Search | 2 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/` | `HEURISTIC` |
| 78 | `Source/Features/Search/ViewModel/Extensions/Search+Observers.swift` | Upstream Search | 1 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/` | `HEURISTIC` |
| 79 | `Source/Features/Search/ViewModel/Extensions/Search+iOS.swift` | Upstream Search | 1 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/` | `HEURISTIC` |
| 80 | `Source/Features/Search/ViewModel/SearchViewModel.swift` | Upstream Search | 1 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/` | `HEURISTIC` |
| 81 | `Source/Features/Search/iOS/SearchComponents.swift` | Upstream Search | 24 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/Search/` | `RULES_BASED` |
| 82 | `Source/Features/Search/iOS/SearchModeView.swift` | Upstream Search | 23 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/Search/` | `RULES_BASED` |
| 83 | `Source/Features/Search/iOS/SearchResultsListView.swift` | Upstream Search | 19 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/Search/` | `RULES_BASED` |
| 84 | `Source/Features/Search/iOS/iOSSearchFilterViewController.swift` | Upstream Search | 8 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/` | `HEURISTIC` |
| 85 | `Source/Features/Search/macOS/OptionSearchVC.swift` | Upstream Search | 1 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/` | `HEURISTIC` |
| 86 | `Source/Features/Setting/SettingsView.swift` | Upstream Settings | 12 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/AppShell/SettingsHostView.swift` | `RULES_BASED` |
| 87 | `Source/Localizable.xcstrings` | Localization | 733 | `CONFIG_OR_LOCALIZATION` | `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift` | `RULES_BASED` |
| 88 | `Source/Maktabah.entitlements` | Other | 1 | `VENDOR_OR_SHARED_SEAM` | `App capabilities / metadata seam` | `RULES_BASED` |
| 89 | `Source/MaktabahDirect.entitlements` | Other | 1 | `VENDOR_OR_SHARED_SEAM` | `App capabilities / metadata seam` | `RULES_BASED` |
| 90 | `Source/UI/iOS/MaktabahApp.swift` | iOS App Shell | 11 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/` | `HEURISTIC` |
| 91 | `Source/UI/iOS/Managers/BootstrapManager.swift` | iOS App Shell | 22 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/AppShell/BootstrapAdapter.swift` | `RULES_BASED` |
| 92 | `Source/UI/iOS/Managers/iOSNavigationManager.swift` | iOS App Shell | 23 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/Navigation/BackendNavigationAdapter.swift + ReaderSessionCoordinator.swift` | `RULES_BASED` |
| 93 | `Source/UI/iOS/Views/Bootstrap/BootstrapView.swift` | iOS App Shell | 8 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/AppShell/BootstrapAdapter.swift` | `RULES_BASED` |
| 94 | `Source/UI/iOS/Views/Common/BaseHierarchicalListViewController.swift` | iOS App Shell | 1 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/` | `HEURISTIC` |
| 95 | `Source/UI/iOS/Views/Common/ListContentView.swift` | iOS App Shell | 9 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/` | `HEURISTIC` |
| 96 | `Source/UI/iOS/Views/Common/iOSHierarchicalCollectionViewController.swift` | iOS App Shell | 30 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/` | `HEURISTIC` |
| 97 | `Source/UI/iOS/Views/iOSMainView.swift` | iOS App Shell | 13 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/AppShell/` | `RULES_BASED` |
| 98 | `Source/UI/iOS/Views/iPadLayout.swift` | iOS App Shell | 16 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/AppShell/` | `RULES_BASED` |
| 99 | `Source/UI/iOS/Views/iPhoneLayout.swift` | iOS App Shell | 5 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/AppShell/` | `RULES_BASED` |
| 100 | `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift` | Upstream Reader | 22 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/ReaderRendering/ReaderPullNavigationStateMachine.swift + ReaderSelectionRangeMapper.swift` | `RULES_BASED` |
| 101 | `Source/UI/macOS/AppDelegate.swift` | macOS UI | 5 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/AppShell/macOS/` | `RULES_BASED` |
| 102 | `Source/UI/macOS/Modal+Overlay/CoreDownloadProgressView.swift` | macOS UI | 18 | `DOWNSTREAM_EXTRACT` | `Source/ChavrusaText/AppShell/macOS/` | `RULES_BASED` |
| 103 | `Source/ar.lproj/InfoPlist.strings` | Other | 1 | `VENDOR_OR_SHARED_SEAM` | `App capabilities / metadata seam` | `RULES_BASED` |
| 104 | `Source/en.lproj/InfoPlist.strings` | Other | 1 | `VENDOR_OR_SHARED_SEAM` | `App capabilities / metadata seam` | `RULES_BASED` |
| 105 | `Source/iOS-Info.plist` | Other | 2 | `VENDOR_OR_SHARED_SEAM` | `App capabilities / metadata seam` | `RULES_BASED` |
| 106 | `Source/id.lproj/InfoPlist.strings` | Other | 1 | `VENDOR_OR_SHARED_SEAM` | `App capabilities / metadata seam` | `RULES_BASED` |

## Detailed Hunk Ledger by Area

### Workstream Area: Build / CI (21 hunks)

#### `.github/jules-review-rules.md`

- **Hunk 1/1**: `.github/jules-review-rules.md`
  - Lines: upstream L97-L96 → fork L97-L100 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Configuration / Integration files`
  - Contract: Preserve CI/agent configuration
  - Approval: `LEGACY_UNREVIEWED`

#### `.github/workflows/codeql.yml`

- **Hunk 1/2**: `.github/workflows/codeql.yml`
  - Lines: upstream L4-L5 → fork L4-L3 (`delete`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Configuration / Integration files`
  - Contract: Preserve CI/agent configuration
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/2**: `.github/workflows/codeql.yml`
  - Lines: upstream L7-L8 → fork L5-L4 (`delete`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Configuration / Integration files`
  - Contract: Preserve CI/agent configuration
  - Approval: `LEGACY_UNREVIEWED`

#### `.github/workflows/pr-review.yml`

- **Hunk 1/2**: `.github/workflows/pr-review.yml`
  - Lines: upstream L23-L22 → fork L23-L23 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Configuration / Integration files`
  - Contract: Preserve CI/agent configuration
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/2**: `.github/workflows/pr-review.yml`
  - Lines: upstream L27-L26 → fork L28-L35 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Configuration / Integration files`
  - Contract: Preserve CI/agent configuration
  - Approval: `LEGACY_UNREVIEWED`

#### `.github/workflows/release.yml`

- **Hunk 1/15**: `.github/workflows/release.yml`
  - Lines: upstream L26-L25 → fork L26-L26 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Configuration / Integration files`
  - Contract: Preserve CI/agent configuration
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/15**: `.github/workflows/release.yml`
  - Lines: upstream L40-L40 → fork L41-L48 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Configuration / Integration files`
  - Contract: Preserve CI/agent configuration
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/15**: `.github/workflows/release.yml`
  - Lines: upstream L47-L46 → fork L55-L62 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Configuration / Integration files`
  - Contract: Preserve CI/agent configuration
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/15**: `.github/workflows/release.yml`
  - Lines: upstream L53-L52 → fork L69-L76 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Configuration / Integration files`
  - Contract: Preserve CI/agent configuration
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/15**: `.github/workflows/release.yml`
  - Lines: upstream L62-L61 → fork L86-L93 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Configuration / Integration files`
  - Contract: Preserve CI/agent configuration
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/15**: `.github/workflows/release.yml`
  - Lines: upstream L86-L85 → fork L118-L125 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Configuration / Integration files`
  - Contract: Preserve CI/agent configuration
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/15**: `.github/workflows/release.yml`
  - Lines: upstream L91-L90 → fork L131-L138 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Configuration / Integration files`
  - Contract: Preserve CI/agent configuration
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 8/15**: `.github/workflows/release.yml`
  - Lines: upstream L105-L104 → fork L153-L160 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Configuration / Integration files`
  - Contract: Preserve CI/agent configuration
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 9/15**: `.github/workflows/release.yml`
  - Lines: upstream L119-L118 → fork L175-L182 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Configuration / Integration files`
  - Contract: Preserve CI/agent configuration
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 10/15**: `.github/workflows/release.yml`
  - Lines: upstream L194-L193 → fork L258-L265 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Configuration / Integration files`
  - Contract: Preserve CI/agent configuration
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 11/15**: `.github/workflows/release.yml`
  - Lines: upstream L228-L227 → fork L300-L307 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Configuration / Integration files`
  - Contract: Preserve CI/agent configuration
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 12/15**: `.github/workflows/release.yml`
  - Lines: upstream L266-L265 → fork L346-L353 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Configuration / Integration files`
  - Contract: Preserve CI/agent configuration
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 13/15**: `.github/workflows/release.yml`
  - Lines: upstream L287-L286 → fork L375-L382 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Configuration / Integration files`
  - Contract: Preserve CI/agent configuration
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 14/15**: `.github/workflows/release.yml`
  - Lines: upstream L294-L293 → fork L390-L397 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Configuration / Integration files`
  - Contract: Preserve CI/agent configuration
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 15/15**: `.github/workflows/release.yml`
  - Lines: upstream L408-L407 → fork L512-L520 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Configuration / Integration files`
  - Contract: Preserve CI/agent configuration
  - Approval: `LEGACY_UNREVIEWED`

#### `Maktabah.xcodeproj/project.pbxproj`

- **Hunk 1/1**: `Maktabah.xcodeproj/project.pbxproj`
  - Lines: upstream L1-L1 → fork L1-L1 (`modify`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Controlled integration seam (project.pbxproj)`
  - Contract: Preserve target, bundle, and framework settings
  - Approval: `LEGACY_UNREVIEWED`

### Workstream Area: Core (28 hunks)

#### `Source/Core/Configuration/UserDefaults.swift`

- **Hunk 1/2**: `Source/Core/Configuration/UserDefaults.swift`
  - Lines: upstream L58-L57 → fork L58-L68 (`insert`)
  - Category: `LEGACY_UNREVIEWED` | Rigor: `heuristic` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `TBD via owner review`
  - Contract: Legacy divergence prior to clean layer policy
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/2**: `Source/Core/Configuration/UserDefaults.swift`
  - Lines: upstream L394-L393 → fork L405-L405 (`insert`)
  - Category: `LEGACY_UNREVIEWED` | Rigor: `heuristic` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `TBD via owner review`
  - Contract: Legacy divergence prior to clean layer policy
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Core/TextProcessing/ArabicTextRenderer.swift`

- **Hunk 1/14**: `Source/Core/TextProcessing/ArabicTextRenderer.swift`
  - Lines: upstream L20-L19 → fork L20-L49 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/`
  - Contract: Preserve Arabic rendering and string utilities
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/14**: `Source/Core/TextProcessing/ArabicTextRenderer.swift`
  - Lines: upstream L30-L33 → fork L60-L62 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/`
  - Contract: Preserve Arabic rendering and string utilities
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/14**: `Source/Core/TextProcessing/ArabicTextRenderer.swift`
  - Lines: upstream L116-L116 → fork L145-L146 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/`
  - Contract: Preserve Arabic rendering and string utilities
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/14**: `Source/Core/TextProcessing/ArabicTextRenderer.swift`
  - Lines: upstream L145-L145 → fork L175-L177 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/`
  - Contract: Preserve Arabic rendering and string utilities
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/14**: `Source/Core/TextProcessing/ArabicTextRenderer.swift`
  - Lines: upstream L149-L149 → fork L181-L181 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/`
  - Contract: Preserve Arabic rendering and string utilities
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/14**: `Source/Core/TextProcessing/ArabicTextRenderer.swift`
  - Lines: upstream L156-L156 → fork L188-L190 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/`
  - Contract: Preserve Arabic rendering and string utilities
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/14**: `Source/Core/TextProcessing/ArabicTextRenderer.swift`
  - Lines: upstream L158-L157 → fork L192-L192 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/`
  - Contract: Preserve Arabic rendering and string utilities
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 8/14**: `Source/Core/TextProcessing/ArabicTextRenderer.swift`
  - Lines: upstream L159-L160 → fork L194-L195 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/`
  - Contract: Preserve Arabic rendering and string utilities
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 9/14**: `Source/Core/TextProcessing/ArabicTextRenderer.swift`
  - Lines: upstream L166-L165 → fork L201-L201 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/`
  - Contract: Preserve Arabic rendering and string utilities
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 10/14**: `Source/Core/TextProcessing/ArabicTextRenderer.swift`
  - Lines: upstream L179-L179 → fork L215-L215 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/`
  - Contract: Preserve Arabic rendering and string utilities
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 11/14**: `Source/Core/TextProcessing/ArabicTextRenderer.swift`
  - Lines: upstream L185-L185 → fork L221-L223 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/`
  - Contract: Preserve Arabic rendering and string utilities
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 12/14**: `Source/Core/TextProcessing/ArabicTextRenderer.swift`
  - Lines: upstream L193-L193 → fork L231-L233 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/`
  - Contract: Preserve Arabic rendering and string utilities
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 13/14**: `Source/Core/TextProcessing/ArabicTextRenderer.swift`
  - Lines: upstream L202-L202 → fork L242-L244 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/`
  - Contract: Preserve Arabic rendering and string utilities
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 14/14**: `Source/Core/TextProcessing/ArabicTextRenderer.swift`
  - Lines: upstream L207-L207 → fork L249-L249 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/`
  - Contract: Preserve Arabic rendering and string utilities
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Core/TextProcessing/String+TextCleaning.swift`

- **Hunk 1/4**: `Source/Core/TextProcessing/String+TextCleaning.swift`
  - Lines: upstream L20-L19 → fork L20-L32 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/`
  - Contract: Preserve Arabic rendering and string utilities
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/4**: `Source/Core/TextProcessing/String+TextCleaning.swift`
  - Lines: upstream L98-L97 → fork L111-L130 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/`
  - Contract: Preserve Arabic rendering and string utilities
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/4**: `Source/Core/TextProcessing/String+TextCleaning.swift`
  - Lines: upstream L197-L196 → fork L230-L230 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/`
  - Contract: Preserve Arabic rendering and string utilities
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/4**: `Source/Core/TextProcessing/String+TextCleaning.swift`
  - Lines: upstream L200-L200 → fork L234-L235 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/`
  - Contract: Preserve Arabic rendering and string utilities
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Core/TextProcessing/StringExt.swift`

- **Hunk 1/1**: `Source/Core/TextProcessing/StringExt.swift`
  - Lines: upstream L101-L100 → fork L101-L123 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/`
  - Contract: Preserve Arabic rendering and string utilities
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Core/TextProcessing/TextStorage.swift`

- **Hunk 1/4**: `Source/Core/TextProcessing/TextStorage.swift`
  - Lines: upstream L20-L20 → fork L20-L21 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/`
  - Contract: Preserve Arabic rendering and string utilities
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/4**: `Source/Core/TextProcessing/TextStorage.swift`
  - Lines: upstream L24-L24 → fork L25-L25 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/`
  - Contract: Preserve Arabic rendering and string utilities
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/4**: `Source/Core/TextProcessing/TextStorage.swift`
  - Lines: upstream L26-L25 → fork L27-L35 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/`
  - Contract: Preserve Arabic rendering and string utilities
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/4**: `Source/Core/TextProcessing/TextStorage.swift`
  - Lines: upstream L39-L40 → fork L49-L53 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/`
  - Contract: Preserve Arabic rendering and string utilities
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Core/TextProcessing/TextViewState.swift`

- **Hunk 1/3**: `Source/Core/TextProcessing/TextViewState.swift`
  - Lines: upstream L82-L81 → fork L82-L85 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/`
  - Contract: Preserve Arabic rendering and string utilities
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/3**: `Source/Core/TextProcessing/TextViewState.swift`
  - Lines: upstream L157-L156 → fork L161-L161 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/`
  - Contract: Preserve Arabic rendering and string utilities
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/3**: `Source/Core/TextProcessing/TextViewState.swift`
  - Lines: upstream L194-L193 → fork L199-L202 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/`
  - Contract: Preserve Arabic rendering and string utilities
  - Approval: `LEGACY_UNREVIEWED`

### Workstream Area: Database + Sync (85 hunks)

#### `Source/Core/CloudKit/AnnotationSyncHandler.swift`

- **Hunk 1/4**: `Source/Core/CloudKit/AnnotationSyncHandler.swift`
  - Lines: upstream L19-L19 → fork L19-L18 (`delete`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/4**: `Source/Core/CloudKit/AnnotationSyncHandler.swift`
  - Lines: upstream L38-L37 → fork L37-L40 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/4**: `Source/Core/CloudKit/AnnotationSyncHandler.swift`
  - Lines: upstream L56-L56 → fork L59-L60 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/4**: `Source/Core/CloudKit/AnnotationSyncHandler.swift`
  - Lines: upstream L81-L80 → fork L85-L89 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Core/CloudKit/CloudKitCoreManager.swift`

- **Hunk 1/13**: `Source/Core/CloudKit/CloudKitCoreManager.swift`
  - Lines: upstream L26-L27 → fork L26-L29 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/13**: `Source/Core/CloudKit/CloudKitCoreManager.swift`
  - Lines: upstream L29-L28 → fork L31-L34 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/13**: `Source/Core/CloudKit/CloudKitCoreManager.swift`
  - Lines: upstream L43-L45 → fork L49-L48 (`delete`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/13**: `Source/Core/CloudKit/CloudKitCoreManager.swift`
  - Lines: upstream L48-L47 → fork L51-L98 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/13**: `Source/Core/CloudKit/CloudKitCoreManager.swift`
  - Lines: upstream L57-L57 → fork L108-L107 (`delete`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/13**: `Source/Core/CloudKit/CloudKitCoreManager.swift`
  - Lines: upstream L103-L102 → fork L153-L156 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/13**: `Source/Core/CloudKit/CloudKitCoreManager.swift`
  - Lines: upstream L122-L121 → fork L176-L179 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 8/13**: `Source/Core/CloudKit/CloudKitCoreManager.swift`
  - Lines: upstream L144-L143 → fork L202-L205 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 9/13**: `Source/Core/CloudKit/CloudKitCoreManager.swift`
  - Lines: upstream L152-L152 → fork L214-L213 (`delete`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 10/13**: `Source/Core/CloudKit/CloudKitCoreManager.swift`
  - Lines: upstream L215-L215 → fork L276-L275 (`delete`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 11/13**: `Source/Core/CloudKit/CloudKitCoreManager.swift`
  - Lines: upstream L238-L239 → fork L298-L297 (`delete`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 12/13**: `Source/Core/CloudKit/CloudKitCoreManager.swift`
  - Lines: upstream L258-L258 → fork L316-L315 (`delete`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 13/13**: `Source/Core/CloudKit/CloudKitCoreManager.swift`
  - Lines: upstream L289-L288 → fork L346-L356 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Core/Database/BookConnection.swift`

- **Hunk 1/33**: `Source/Core/Database/BookConnection.swift`
  - Lines: upstream L1-L0 → fork L1-L1 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/33**: `Source/Core/Database/BookConnection.swift`
  - Lines: upstream L68-L67 → fork L69-L73 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/33**: `Source/Core/Database/BookConnection.swift`
  - Lines: upstream L107-L107 → fork L113-L116 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/33**: `Source/Core/Database/BookConnection.swift`
  - Lines: upstream L139-L138 → fork L148-L148 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/33**: `Source/Core/Database/BookConnection.swift`
  - Lines: upstream L147-L149 → fork L157-L160 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/33**: `Source/Core/Database/BookConnection.swift`
  - Lines: upstream L154-L156 → fork L165-L164 (`delete`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/33**: `Source/Core/Database/BookConnection.swift`
  - Lines: upstream L170-L169 → fork L178-L181 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 8/33**: `Source/Core/Database/BookConnection.swift`
  - Lines: upstream L183-L182 → fork L195-L198 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 9/33**: `Source/Core/Database/BookConnection.swift`
  - Lines: upstream L192-L191 → fork L208-L208 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 10/33**: `Source/Core/Database/BookConnection.swift`
  - Lines: upstream L199-L198 → fork L216-L216 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 11/33**: `Source/Core/Database/BookConnection.swift`
  - Lines: upstream L202-L201 → fork L220-L220 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 12/33**: `Source/Core/Database/BookConnection.swift`
  - Lines: upstream L275-L274 → fork L294-L297 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 13/33**: `Source/Core/Database/BookConnection.swift`
  - Lines: upstream L291-L290 → fork L314-L320 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 14/33**: `Source/Core/Database/BookConnection.swift`
  - Lines: upstream L311-L310 → fork L341-L347 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 15/33**: `Source/Core/Database/BookConnection.swift`
  - Lines: upstream L334-L333 → fork L371-L377 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 16/33**: `Source/Core/Database/BookConnection.swift`
  - Lines: upstream L368-L368 → fork L412-L411 (`delete`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 17/33**: `Source/Core/Database/BookConnection.swift`
  - Lines: upstream L370-L369 → fork L413-L416 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 18/33**: `Source/Core/Database/BookConnection.swift`
  - Lines: upstream L406-L406 → fork L453-L452 (`delete`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 19/33**: `Source/Core/Database/BookConnection.swift`
  - Lines: upstream L408-L408 → fork L454-L457 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 20/33**: `Source/Core/Database/BookConnection.swift`
  - Lines: upstream L412-L412 → fork L461-L464 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 21/33**: `Source/Core/Database/BookConnection.swift`
  - Lines: upstream L429-L429 → fork L481-L480 (`delete`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 22/33**: `Source/Core/Database/BookConnection.swift`
  - Lines: upstream L431-L430 → fork L482-L485 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 23/33**: `Source/Core/Database/BookConnection.swift`
  - Lines: upstream L432-L431 → fork L487-L487 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 24/33**: `Source/Core/Database/BookConnection.swift`
  - Lines: upstream L443-L442 → fork L499-L499 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 25/33**: `Source/Core/Database/BookConnection.swift`
  - Lines: upstream L469-L468 → fork L526-L526 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 26/33**: `Source/Core/Database/BookConnection.swift`
  - Lines: upstream L473-L473 → fork L531-L530 (`delete`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 27/33**: `Source/Core/Database/BookConnection.swift`
  - Lines: upstream L476-L475 → fork L533-L534 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 28/33**: `Source/Core/Database/BookConnection.swift`
  - Lines: upstream L479-L478 → fork L538-L538 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 29/33**: `Source/Core/Database/BookConnection.swift`
  - Lines: upstream L481-L480 → fork L541-L543 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 30/33**: `Source/Core/Database/BookConnection.swift`
  - Lines: upstream L484-L484 → fork L547-L546 (`delete`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 31/33**: `Source/Core/Database/BookConnection.swift`
  - Lines: upstream L486-L487 → fork L548-L562 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 32/33**: `Source/Core/Database/BookConnection.swift`
  - Lines: upstream L489-L492 → fork L564-L563 (`delete`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 33/33**: `Source/Core/Database/BookConnection.swift`
  - Lines: upstream L549-L548 → fork L620-L620 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Core/Database/CloudKitSyncManager.swift`

- **Hunk 1/7**: `Source/Core/Database/CloudKitSyncManager.swift`
  - Lines: upstream L216-L215 → fork L216-L219 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/7**: `Source/Core/Database/CloudKitSyncManager.swift`
  - Lines: upstream L235-L235 → fork L239-L239 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/7**: `Source/Core/Database/CloudKitSyncManager.swift`
  - Lines: upstream L1072-L1071 → fork L1076-L1076 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/7**: `Source/Core/Database/CloudKitSyncManager.swift`
  - Lines: upstream L1076-L1076 → fork L1081-L1086 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/7**: `Source/Core/Database/CloudKitSyncManager.swift`
  - Lines: upstream L1088-L1087 → fork L1098-L1098 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/7**: `Source/Core/Database/CloudKitSyncManager.swift`
  - Lines: upstream L1096-L1096 → fork L1107-L1112 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/7**: `Source/Core/Database/CloudKitSyncManager.swift`
  - Lines: upstream L1100-L1099 → fork L1116-L1116 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Core/Database/CoreDatabaseDownloader.swift`

- **Hunk 1/2**: `Source/Core/Database/CoreDatabaseDownloader.swift`
  - Lines: upstream L530-L529 → fork L530-L535 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/2**: `Source/Core/Database/CoreDatabaseDownloader.swift`
  - Lines: upstream L532-L531 → fork L538-L538 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Core/Database/DatabaseManager.swift`

- **Hunk 1/13**: `Source/Core/Database/DatabaseManager.swift`
  - Lines: upstream L83-L82 → fork L83-L88 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/13**: `Source/Core/Database/DatabaseManager.swift`
  - Lines: upstream L197-L196 → fork L203-L205 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/13**: `Source/Core/Database/DatabaseManager.swift`
  - Lines: upstream L231-L230 → fork L240-L242 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/13**: `Source/Core/Database/DatabaseManager.swift`
  - Lines: upstream L247-L246 → fork L259-L259 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/13**: `Source/Core/Database/DatabaseManager.swift`
  - Lines: upstream L256-L255 → fork L269-L269 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/13**: `Source/Core/Database/DatabaseManager.swift`
  - Lines: upstream L265-L264 → fork L279-L281 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/13**: `Source/Core/Database/DatabaseManager.swift`
  - Lines: upstream L278-L277 → fork L295-L297 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 8/13**: `Source/Core/Database/DatabaseManager.swift`
  - Lines: upstream L315-L314 → fork L335-L335 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 9/13**: `Source/Core/Database/DatabaseManager.swift`
  - Lines: upstream L322-L321 → fork L343-L343 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 10/13**: `Source/Core/Database/DatabaseManager.swift`
  - Lines: upstream L329-L328 → fork L351-L353 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 11/13**: `Source/Core/Database/DatabaseManager.swift`
  - Lines: upstream L342-L341 → fork L367-L367 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 12/13**: `Source/Core/Database/DatabaseManager.swift`
  - Lines: upstream L368-L367 → fork L394-L394 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 13/13**: `Source/Core/Database/DatabaseManager.swift`
  - Lines: upstream L394-L393 → fork L421-L421 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Core/Database/SQLiteDatabase.swift`

- **Hunk 1/9**: `Source/Core/Database/SQLiteDatabase.swift`
  - Lines: upstream L18-L22 → fork L18-L27 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/9**: `Source/Core/Database/SQLiteDatabase.swift`
  - Lines: upstream L29-L28 → fork L34-L37 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/9**: `Source/Core/Database/SQLiteDatabase.swift`
  - Lines: upstream L106-L105 → fork L115-L121 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/9**: `Source/Core/Database/SQLiteDatabase.swift`
  - Lines: upstream L122-L121 → fork L138-L138 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/9**: `Source/Core/Database/SQLiteDatabase.swift`
  - Lines: upstream L124-L123 → fork L141-L141 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/9**: `Source/Core/Database/SQLiteDatabase.swift`
  - Lines: upstream L132-L131 → fork L150-L150 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/9**: `Source/Core/Database/SQLiteDatabase.swift`
  - Lines: upstream L134-L133 → fork L153-L153 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 8/9**: `Source/Core/Database/SQLiteDatabase.swift`
  - Lines: upstream L192-L192 → fork L212-L215 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 9/9**: `Source/Core/Database/SQLiteDatabase.swift`
  - Lines: upstream L203-L203 → fork L226-L229 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Core/Database/ZstdShim.swift`

- **Hunk 1/4**: `Source/Core/Database/ZstdShim.swift`
  - Lines: upstream L11-L12 → fork L11-L25 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/4**: `Source/Core/Database/ZstdShim.swift`
  - Lines: upstream L16-L15 → fork L29-L31 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/4**: `Source/Core/Database/ZstdShim.swift`
  - Lines: upstream L30-L29 → fork L46-L74 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/4**: `Source/Core/Database/ZstdShim.swift`
  - Lines: upstream L57-L56 → fork L102-L120 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Storage/`
  - Contract: Preserve native Maktabah SQLite database path; ensure zero user DB loss
  - Approval: `LEGACY_UNREVIEWED`

### Workstream Area: Localization (733 hunks)

#### `Source/Localizable.xcstrings`

- **Hunk 1/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2-L5 → fork L2-L6 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L7-L8 → fork L8-L9 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L10-L16 → fork L11-L17 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L19-L22 → fork L20-L23 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L25-L28 → fork L26-L35 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L33-L39 → fork L40-L46 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L42-L45 → fork L49-L52 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 8/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L48-L51 → fork L55-L58 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 9/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L56-L62 → fork L63-L69 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 10/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L65-L68 → fork L72-L75 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 11/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L71-L74 → fork L78-L81 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 12/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L79-L85 → fork L86-L92 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 13/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L88-L91 → fork L95-L98 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 14/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L94-L97 → fork L101-L104 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 15/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L102-L108 → fork L109-L115 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 16/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L111-L114 → fork L118-L121 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 17/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L117-L120 → fork L124-L127 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 18/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L125-L131 → fork L132-L138 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 19/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L134-L137 → fork L141-L144 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 20/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L140-L143 → fork L147-L150 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 21/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L148-L154 → fork L155-L161 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 22/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L157-L160 → fork L164-L167 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 23/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L163-L166 → fork L170-L173 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 24/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L171-L177 → fork L178-L184 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 25/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L180-L183 → fork L187-L190 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 26/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L186-L189 → fork L193-L196 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 27/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L194-L200 → fork L201-L207 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 28/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L203-L206 → fork L210-L213 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 29/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L209-L212 → fork L216-L219 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 30/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L217-L223 → fork L224-L230 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 31/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L226-L229 → fork L233-L236 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 32/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L232-L235 → fork L239-L242 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 33/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L240-L246 → fork L247-L253 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 34/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L249-L252 → fork L256-L259 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 35/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L255-L258 → fork L262-L265 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 36/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L263-L269 → fork L270-L276 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 37/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L272-L275 → fork L279-L282 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 38/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L278-L281 → fork L285-L288 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 39/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L286-L292 → fork L293-L299 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 40/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L295-L298 → fork L302-L305 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 41/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L301-L304 → fork L308-L311 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 42/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L309-L315 → fork L316-L322 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 43/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L318-L321 → fork L325-L328 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 44/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L324-L327 → fork L331-L334 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 45/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L332-L338 → fork L339-L345 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 46/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L341-L344 → fork L348-L351 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 47/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L347-L350 → fork L354-L357 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 48/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L355-L361 → fork L362-L368 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 49/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L364-L367 → fork L371-L374 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 50/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L370-L373 → fork L377-L380 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 51/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L378-L384 → fork L385-L391 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 52/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L387-L390 → fork L394-L397 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 53/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L393-L396 → fork L400-L403 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 54/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L401-L407 → fork L408-L414 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 55/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L410-L413 → fork L417-L420 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 56/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L416-L419 → fork L423-L426 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 57/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L424-L430 → fork L431-L437 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 58/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L433-L436 → fork L440-L443 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 59/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L439-L442 → fork L446-L449 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 60/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L447-L453 → fork L454-L460 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 61/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L456-L459 → fork L463-L466 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 62/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L462-L465 → fork L469-L472 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 63/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L470-L476 → fork L477-L483 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 64/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L479-L482 → fork L486-L489 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 65/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L485-L488 → fork L492-L495 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 66/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L493-L499 → fork L500-L506 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 67/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L502-L505 → fork L509-L512 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 68/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L508-L511 → fork L515-L518 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 69/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L516-L522 → fork L523-L529 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 70/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L525-L528 → fork L532-L535 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 71/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L531-L534 → fork L538-L541 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 72/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L539-L545 → fork L546-L552 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 73/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L548-L551 → fork L555-L558 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 74/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L554-L557 → fork L561-L564 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 75/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L562-L568 → fork L569-L575 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 76/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L571-L574 → fork L578-L581 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 77/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L577-L580 → fork L584-L587 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 78/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L585-L591 → fork L592-L598 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 79/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L594-L597 → fork L601-L604 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 80/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L600-L603 → fork L607-L616 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 81/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L608-L614 → fork L621-L627 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 82/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L617-L620 → fork L630-L633 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 83/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L623-L626 → fork L636-L639 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 84/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L631-L637 → fork L644-L650 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 85/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L640-L643 → fork L653-L656 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 86/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L646-L649 → fork L659-L662 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 87/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L654-L659 → fork L667-L672 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 88/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L662-L665 → fork L675-L684 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 89/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L670-L671 → fork L689-L691 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 90/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L673-L674 → fork L693-L695 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 91/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L676-L681 → fork L697-L702 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 92/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L685-L685 → fork L706-L706 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 93/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L687-L692 → fork L708-L713 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 94/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L696-L696 → fork L717-L717 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 95/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L698-L699 → fork L719-L721 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 96/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L701-L706 → fork L723-L728 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 97/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L709-L712 → fork L731-L734 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 98/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L715-L718 → fork L737-L746 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 99/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L723-L724 → fork L751-L753 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 100/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L726-L727 → fork L755-L757 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 101/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L729-L730 → fork L759-L761 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 102/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L732-L737 → fork L763-L768 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 103/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L740-L743 → fork L771-L774 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 104/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L746-L749 → fork L777-L786 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 105/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L754-L760 → fork L791-L797 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 106/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L763-L766 → fork L800-L803 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 107/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L769-L772 → fork L806-L815 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 108/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L777-L782 → fork L820-L825 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 109/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L785-L788 → fork L828-L831 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 110/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L791-L794 → fork L834-L843 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 111/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L799-L804 → fork L848-L853 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 112/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L807-L810 → fork L856-L865 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 113/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L815-L820 → fork L870-L875 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 114/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L823-L826 → fork L878-L881 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 115/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L829-L832 → fork L884-L893 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 116/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L837-L843 → fork L898-L904 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 117/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L846-L849 → fork L907-L910 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 118/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L852-L855 → fork L913-L916 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 119/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L860-L866 → fork L921-L927 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 120/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L869-L872 → fork L930-L933 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 121/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L875-L878 → fork L936-L945 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 122/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L883-L889 → fork L950-L956 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 123/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L892-L895 → fork L959-L962 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 124/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L898-L901 → fork L965-L974 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 125/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L906-L911 → fork L979-L984 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 126/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L914-L917 → fork L987-L990 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 127/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L920-L923 → fork L993-L1002 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 128/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L928-L933 → fork L1007-L1012 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 129/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L936-L939 → fork L1015-L1018 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 130/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L942-L945 → fork L1021-L1030 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 131/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L950-L958 → fork L1035-L1041 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 132/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L961-L964 → fork L1044-L1047 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 133/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L967-L970 → fork L1050-L1059 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 134/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L975-L980 → fork L1064-L1069 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 135/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L983-L986 → fork L1072-L1075 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 136/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L989-L992 → fork L1078-L1087 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 137/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L997-L1003 → fork L1092-L1098 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 138/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1006-L1009 → fork L1101-L1110 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 139/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1014-L1019 → fork L1115-L1120 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 140/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1022-L1025 → fork L1123-L1132 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 141/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1030-L1035 → fork L1137-L1142 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 142/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1038-L1041 → fork L1145-L1154 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 143/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1046-L1054 → fork L1159-L1165 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 144/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1057-L1060 → fork L1168-L1171 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 145/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1063-L1066 → fork L1174-L1183 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 146/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1071-L1077 → fork L1188-L1194 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 147/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1080-L1083 → fork L1197-L1206 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 148/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1088-L1093 → fork L1211-L1216 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 149/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1096-L1099 → fork L1219-L1222 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 150/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1102-L1105 → fork L1225-L1234 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 151/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1110-L1115 → fork L1239-L1244 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 152/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1118-L1121 → fork L1247-L1256 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 153/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1126-L1132 → fork L1261-L1267 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 154/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1135-L1138 → fork L1270-L1279 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 155/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1143-L1148 → fork L1284-L1289 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 156/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1151-L1154 → fork L1292-L1301 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 157/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1159-L1164 → fork L1306-L1311 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 158/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1167-L1170 → fork L1314-L1323 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 159/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1175-L1180 → fork L1328-L1333 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 160/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1183-L1186 → fork L1336-L1345 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 161/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1191-L1196 → fork L1350-L1355 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 162/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1199-L1202 → fork L1358-L1361 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 163/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1205-L1208 → fork L1364-L1373 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 164/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1213-L1218 → fork L1378-L1383 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 165/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1221-L1224 → fork L1386-L1389 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 166/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1227-L1230 → fork L1392-L1401 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 167/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1235-L1240 → fork L1406-L1411 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 168/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1243-L1246 → fork L1414-L1423 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 169/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1251-L1256 → fork L1428-L1433 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 170/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1259-L1262 → fork L1436-L1439 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 171/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1265-L1268 → fork L1442-L1451 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 172/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1273-L1279 → fork L1456-L1462 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 173/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1282-L1285 → fork L1465-L1468 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 174/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1288-L1291 → fork L1471-L1480 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 175/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1296-L1301 → fork L1485-L1490 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 176/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1304-L1307 → fork L1493-L1496 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 177/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1310-L1313 → fork L1499-L1508 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 178/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1318-L1323 → fork L1513-L1518 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 179/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1326-L1329 → fork L1521-L1524 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 180/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1332-L1335 → fork L1527-L1536 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 181/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1340-L1346 → fork L1541-L1547 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 182/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1349-L1352 → fork L1550-L1559 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 183/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1357-L1362 → fork L1564-L1569 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 184/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1365-L1368 → fork L1572-L1575 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 185/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1371-L1374 → fork L1578-L1587 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 186/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1379-L1385 → fork L1592-L1598 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 187/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1388-L1391 → fork L1601-L1604 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 188/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1394-L1397 → fork L1607-L1616 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 189/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1402-L1407 → fork L1621-L1626 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 190/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1410-L1413 → fork L1629-L1632 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 191/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1416-L1419 → fork L1635-L1644 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 192/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1424-L1430 → fork L1649-L1655 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 193/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1433-L1436 → fork L1658-L1661 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 194/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1439-L1442 → fork L1664-L1673 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 195/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1447-L1453 → fork L1678-L1684 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 196/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1456-L1459 → fork L1687-L1690 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 197/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1462-L1465 → fork L1693-L1702 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 198/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1470-L1476 → fork L1707-L1713 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 199/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1479-L1482 → fork L1716-L1719 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 200/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1485-L1488 → fork L1722-L1731 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 201/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1493-L1499 → fork L1736-L1742 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 202/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1502-L1505 → fork L1745-L1748 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 203/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1508-L1511 → fork L1751-L1760 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 204/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1516-L1522 → fork L1765-L1771 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 205/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1525-L1528 → fork L1774-L1777 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 206/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1531-L1534 → fork L1780-L1789 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 207/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1539-L1545 → fork L1794-L1800 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 208/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1548-L1551 → fork L1803-L1806 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 209/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1554-L1557 → fork L1809-L1818 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 210/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1562-L1567 → fork L1823-L1828 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 211/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1570-L1573 → fork L1831-L1834 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 212/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1576-L1579 → fork L1837-L1846 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 213/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1584-L1589 → fork L1851-L1856 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 214/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1592-L1595 → fork L1859-L1862 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 215/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1598-L1601 → fork L1865-L1874 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 216/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1606-L1612 → fork L1879-L1885 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 217/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1615-L1618 → fork L1888-L1891 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 218/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1621-L1624 → fork L1894-L1903 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 219/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1629-L1635 → fork L1908-L1914 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 220/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1638-L1641 → fork L1917-L1920 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 221/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1644-L1647 → fork L1923-L1932 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 222/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1652-L1658 → fork L1937-L1943 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 223/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1661-L1664 → fork L1946-L1949 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 224/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1667-L1670 → fork L1952-L1961 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 225/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1675-L1682 → fork L1966-L1973 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 226/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1685-L1688 → fork L1976-L1979 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 227/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1691-L1694 → fork L1982-L1991 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 228/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1699-L1704 → fork L1996-L2001 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 229/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1707-L1710 → fork L2004-L2013 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 230/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1715-L1720 → fork L2018-L2023 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 231/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1723-L1726 → fork L2026-L2035 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 232/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1731-L1736 → fork L2040-L2045 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 233/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1739-L1742 → fork L2048-L2057 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 234/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1747-L1752 → fork L2062-L2067 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 235/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1755-L1758 → fork L2070-L2079 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 236/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1763-L1768 → fork L2084-L2089 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 237/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1771-L1774 → fork L2092-L2101 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 238/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1779-L1788 → fork L2106-L2113 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 239/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1791-L1794 → fork L2116-L2125 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 240/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1799-L1805 → fork L2130-L2136 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 241/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1808-L1811 → fork L2139-L2142 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 242/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1816-L1821 → fork L2147-L2152 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 243/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1824-L1827 → fork L2155-L2164 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 244/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1832-L1837 → fork L2169-L2174 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 245/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1840-L1843 → fork L2177-L2186 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 246/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1848-L1853 → fork L2191-L2196 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 247/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1856-L1859 → fork L2199-L2208 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 248/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1864-L1869 → fork L2213-L2218 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 249/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1872-L1875 → fork L2221-L2230 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 250/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1880-L1886 → fork L2235-L2241 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 251/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1889-L1892 → fork L2244-L2253 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 252/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1897-L1902 → fork L2258-L2263 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 253/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1905-L1908 → fork L2266-L2269 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 254/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1913-L1918 → fork L2274-L2279 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 255/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1921-L1924 → fork L2282-L2285 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 256/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1927-L1930 → fork L2288-L2297 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 257/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1935-L1940 → fork L2302-L2307 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 258/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1943-L1946 → fork L2310-L2319 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 259/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1951-L1957 → fork L2324-L2330 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 260/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1960-L1963 → fork L2333-L2342 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 261/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1968-L1973 → fork L2347-L2352 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 262/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1976-L1979 → fork L2355-L2358 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 263/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1982-L1985 → fork L2361-L2370 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 264/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1990-L1995 → fork L2375-L2380 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 265/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L1998-L2001 → fork L2383-L2392 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 266/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2006-L2011 → fork L2397-L2402 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 267/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2014-L2017 → fork L2405-L2408 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 268/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2020-L2023 → fork L2411-L2414 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 269/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2028-L2033 → fork L2419-L2424 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 270/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2037-L2037 → fork L2428-L2428 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 271/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2039-L2045 → fork L2430-L2436 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 272/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2048-L2051 → fork L2439-L2442 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 273/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2054-L2057 → fork L2445-L2454 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 274/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2062-L2068 → fork L2459-L2465 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 275/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2071-L2074 → fork L2468-L2471 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 276/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2077-L2080 → fork L2474-L2483 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 277/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2085-L2091 → fork L2488-L2494 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 278/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2094-L2097 → fork L2497-L2500 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 279/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2100-L2103 → fork L2503-L2512 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 280/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2108-L2113 → fork L2517-L2522 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 281/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2116-L2119 → fork L2525-L2528 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 282/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2122-L2125 → fork L2531-L2540 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 283/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2130-L2135 → fork L2545-L2550 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 284/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2138-L2141 → fork L2553-L2556 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 285/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2144-L2147 → fork L2559-L2568 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 286/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2152-L2158 → fork L2573-L2579 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 287/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2161-L2164 → fork L2582-L2585 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 288/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2167-L2170 → fork L2588-L2597 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 289/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2175-L2181 → fork L2602-L2608 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 290/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2184-L2187 → fork L2611-L2614 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 291/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2190-L2193 → fork L2617-L2626 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 292/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2198-L2204 → fork L2631-L2637 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 293/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2207-L2210 → fork L2640-L2643 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 294/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2213-L2216 → fork L2646-L2655 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 295/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2221-L2227 → fork L2660-L2666 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 296/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2230-L2233 → fork L2669-L2672 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 297/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2236-L2239 → fork L2675-L2684 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 298/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2244-L2250 → fork L2689-L2695 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 299/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2253-L2256 → fork L2698-L2701 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 300/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2259-L2262 → fork L2704-L2713 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 301/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2267-L2272 → fork L2718-L2723 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 302/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2275-L2278 → fork L2726-L2729 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 303/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2281-L2284 → fork L2732-L2741 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 304/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2289-L2295 → fork L2746-L2752 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 305/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2298-L2301 → fork L2755-L2758 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 306/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2304-L2307 → fork L2761-L2770 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 307/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2312-L2318 → fork L2775-L2781 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 308/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2321-L2324 → fork L2784-L2787 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 309/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2327-L2330 → fork L2790-L2799 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 310/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2335-L2341 → fork L2804-L2810 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 311/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2344-L2347 → fork L2813-L2816 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 312/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2350-L2353 → fork L2819-L2828 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 313/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2358-L2364 → fork L2833-L2839 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 314/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2367-L2370 → fork L2842-L2845 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 315/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2373-L2376 → fork L2848-L2857 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 316/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2381-L2387 → fork L2862-L2868 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 317/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2390-L2393 → fork L2871-L2874 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 318/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2396-L2399 → fork L2877-L2886 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 319/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2404-L2410 → fork L2891-L2897 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 320/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2413-L2416 → fork L2900-L2903 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 321/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2419-L2422 → fork L2906-L2915 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 322/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2427-L2432 → fork L2920-L2925 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 323/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2435-L2438 → fork L2928-L2931 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 324/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2441-L2444 → fork L2934-L2937 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 325/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2449-L2454 → fork L2942-L2947 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 326/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2457-L2460 → fork L2950-L2959 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 327/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2465-L2470 → fork L2964-L2969 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 328/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2473-L2476 → fork L2972-L2975 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 329/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2479-L2482 → fork L2978-L2987 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 330/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2487-L2492 → fork L2992-L2997 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 331/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2495-L2498 → fork L3000-L3003 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 332/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2501-L2504 → fork L3006-L3015 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 333/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2509-L2514 → fork L3020-L3025 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 334/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2517-L2520 → fork L3028-L3031 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 335/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2523-L2526 → fork L3034-L3043 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 336/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2531-L2536 → fork L3048-L3053 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 337/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2539-L2542 → fork L3056-L3065 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 338/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2547-L2552 → fork L3070-L3075 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 339/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2555-L2558 → fork L3078-L3087 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 340/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2563-L2569 → fork L3092-L3098 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 341/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2572-L2575 → fork L3101-L3104 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 342/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2578-L2581 → fork L3107-L3116 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 343/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2586-L2591 → fork L3121-L3126 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 344/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2594-L2597 → fork L3129-L3138 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 345/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2602-L2607 → fork L3143-L3148 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 346/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2610-L2613 → fork L3151-L3154 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 347/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2616-L2619 → fork L3157-L3166 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 348/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2624-L2629 → fork L3171-L3176 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 349/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2632-L2635 → fork L3179-L3182 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 350/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2638-L2641 → fork L3185-L3194 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 351/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2646-L2652 → fork L3199-L3205 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 352/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2655-L2658 → fork L3208-L3211 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 353/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2663-L2669 → fork L3216-L3222 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 354/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2672-L2675 → fork L3225-L3228 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 355/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2678-L2681 → fork L3231-L3234 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 356/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2686-L2692 → fork L3239-L3245 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 357/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2695-L2698 → fork L3248-L3257 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 358/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2703-L2708 → fork L3262-L3267 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 359/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2711-L2714 → fork L3270-L3273 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 360/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2717-L2720 → fork L3276-L3285 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 361/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2725-L2730 → fork L3290-L3295 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 362/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2733-L2736 → fork L3298-L3307 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 363/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2741-L2746 → fork L3312-L3317 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `manual` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; verify Hebrew translations for navigation tabs (Manual audit)
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 364/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2749-L2752 → fork L3320-L3323 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `manual` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; verify Hebrew translations for navigation tabs (Manual audit)
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 365/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2755-L2758 → fork L3326-L3335 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 366/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2763-L2768 → fork L3340-L3345 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 367/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2771-L2774 → fork L3348-L3357 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 368/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2779-L2780 → fork L3362-L3364 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 369/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2782-L2787 → fork L3366-L3371 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 370/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2790-L2793 → fork L3374-L3383 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 371/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2798-L2803 → fork L3388-L3393 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 372/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2806-L2809 → fork L3396-L3399 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 373/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2812-L2815 → fork L3402-L3405 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 374/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2820-L2826 → fork L3410-L3416 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 375/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2829-L2832 → fork L3419-L3422 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 376/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2835-L2838 → fork L3425-L3434 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 377/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2843-L2848 → fork L3439-L3444 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 378/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2851-L2854 → fork L3447-L3456 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 379/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2859-L2864 → fork L3461-L3466 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 380/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2867-L2870 → fork L3469-L3472 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 381/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2873-L2876 → fork L3475-L3484 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 382/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2881-L2886 → fork L3489-L3494 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 383/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2889-L2892 → fork L3497-L3500 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 384/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2895-L2898 → fork L3503-L3512 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 385/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2903-L2908 → fork L3517-L3522 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 386/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2911-L2914 → fork L3525-L3528 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 387/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2917-L2920 → fork L3531-L3540 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 388/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2925-L2930 → fork L3545-L3550 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 389/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2933-L2936 → fork L3553-L3562 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 390/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2941-L2946 → fork L3567-L3572 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 391/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2949-L2952 → fork L3575-L3578 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 392/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2955-L2958 → fork L3581-L3590 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 393/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2963-L2968 → fork L3595-L3600 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 394/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2971-L2974 → fork L3603-L3612 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 395/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2979-L2984 → fork L3617-L3622 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 396/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2987-L2990 → fork L3625-L3628 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 397/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L2993-L2996 → fork L3631-L3640 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 398/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3001-L3007 → fork L3645-L3651 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 399/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3010-L3013 → fork L3654-L3657 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 400/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3016-L3019 → fork L3660-L3663 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 401/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3024-L3030 → fork L3668-L3674 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 402/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3033-L3036 → fork L3677-L3680 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 403/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3039-L3042 → fork L3683-L3692 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 404/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3047-L3053 → fork L3697-L3703 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 405/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3056-L3059 → fork L3706-L3709 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 406/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3062-L3065 → fork L3712-L3721 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 407/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3070-L3076 → fork L3726-L3732 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 408/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3079-L3082 → fork L3735-L3738 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 409/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3085-L3088 → fork L3741-L3750 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 410/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3093-L3098 → fork L3755-L3760 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 411/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3101-L3104 → fork L3763-L3766 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 412/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3107-L3110 → fork L3769-L3778 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 413/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3115-L3120 → fork L3783-L3788 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 414/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3123-L3126 → fork L3791-L3794 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 415/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3129-L3132 → fork L3797-L3806 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 416/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3137-L3142 → fork L3811-L3816 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 417/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3145-L3148 → fork L3819-L3822 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 418/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3151-L3154 → fork L3825-L3834 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 419/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3159-L3164 → fork L3839-L3844 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 420/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3167-L3170 → fork L3847-L3856 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 421/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3175-L3180 → fork L3861-L3866 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 422/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3183-L3186 → fork L3869-L3878 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 423/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3191-L3196 → fork L3883-L3888 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 424/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3199-L3202 → fork L3891-L3900 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 425/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3207-L3212 → fork L3905-L3910 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 426/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3215-L3218 → fork L3913-L3922 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 427/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3223-L3229 → fork L3927-L3933 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 428/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3232-L3235 → fork L3936-L3939 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 429/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3238-L3241 → fork L3942-L3951 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 430/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3246-L3251 → fork L3956-L3961 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 431/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3254-L3257 → fork L3964-L3967 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 432/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3260-L3263 → fork L3970-L3979 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 433/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3268-L3273 → fork L3984-L3989 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 434/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3276-L3279 → fork L3992-L3995 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 435/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3282-L3285 → fork L3998-L4007 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 436/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3290-L3296 → fork L4012-L4018 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 437/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3299-L3302 → fork L4021-L4024 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 438/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3305-L3308 → fork L4027-L4030 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 439/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3313-L3319 → fork L4035-L4041 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 440/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3322-L3325 → fork L4044-L4047 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 441/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3328-L3331 → fork L4050-L4053 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 442/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3336-L3342 → fork L4058-L4064 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 443/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3345-L3348 → fork L4067-L4070 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 444/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3351-L3354 → fork L4073-L4076 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 445/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3359-L3365 → fork L4081-L4087 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 446/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3368-L3371 → fork L4090-L4093 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 447/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3374-L3377 → fork L4096-L4105 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 448/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3382-L3387 → fork L4110-L4115 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 449/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3390-L3393 → fork L4118-L4127 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 450/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3398-L3403 → fork L4132-L4137 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 451/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3406-L3409 → fork L4140-L4149 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 452/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3414-L3419 → fork L4154-L4159 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 453/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3422-L3425 → fork L4162-L4165 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 454/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3428-L3431 → fork L4168-L4177 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 455/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3436-L3441 → fork L4182-L4187 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 456/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3444-L3447 → fork L4190-L4193 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 457/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3450-L3453 → fork L4196-L4205 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 458/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3458-L3463 → fork L4210-L4215 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 459/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3466-L3469 → fork L4218-L4227 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 460/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3474-L3479 → fork L4232-L4237 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 461/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3482-L3485 → fork L4240-L4249 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 462/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3490-L3496 → fork L4254-L4260 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 463/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3499-L3502 → fork L4263-L4266 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 464/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3505-L3508 → fork L4269-L4278 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 465/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3513-L3519 → fork L4283-L4289 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 466/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3522-L3525 → fork L4292-L4295 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 467/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3528-L3531 → fork L4298-L4307 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 468/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3536-L3541 → fork L4312-L4317 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 469/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3544-L3547 → fork L4320-L4323 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 470/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3550-L3553 → fork L4326-L4335 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 471/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3558-L3563 → fork L4340-L4345 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 472/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3566-L3569 → fork L4348-L4351 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 473/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3572-L3575 → fork L4354-L4363 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 474/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3580-L3585 → fork L4368-L4373 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 475/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3588-L3591 → fork L4376-L4379 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 476/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3594-L3597 → fork L4382-L4391 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 477/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3602-L3607 → fork L4396-L4401 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 478/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3610-L3613 → fork L4404-L4413 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 479/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3618-L3624 → fork L4418-L4424 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 480/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3627-L3630 → fork L4427-L4430 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 481/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3633-L3636 → fork L4433-L4436 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 482/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3641-L3646 → fork L4441-L4446 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 483/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3649-L3652 → fork L4449-L4458 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 484/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3657-L3662 → fork L4463-L4468 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 485/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3665-L3668 → fork L4471-L4474 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 486/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3671-L3674 → fork L4477-L4486 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 487/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3679-L3684 → fork L4491-L4496 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 488/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3687-L3690 → fork L4499-L4502 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 489/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3693-L3696 → fork L4505-L4508 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 490/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3701-L3707 → fork L4513-L4519 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 491/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3710-L3713 → fork L4522-L4525 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 492/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3716-L3719 → fork L4528-L4537 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 493/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3724-L3730 → fork L4542-L4548 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 494/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3733-L3736 → fork L4551-L4560 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 495/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3741-L3746 → fork L4565-L4570 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 496/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3749-L3752 → fork L4573-L4582 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 497/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3757-L3763 → fork L4587-L4593 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 498/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3766-L3769 → fork L4596-L4605 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 499/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3774-L3780 → fork L4610-L4616 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 500/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3784-L3784 → fork L4620-L4620 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 501/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3786-L3792 → fork L4622-L4628 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 502/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3795-L3798 → fork L4631-L4634 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 503/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3801-L3804 → fork L4637-L4646 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 504/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3809-L3815 → fork L4651-L4657 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 505/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3818-L3821 → fork L4660-L4669 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 506/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3826-L3831 → fork L4674-L4679 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 507/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3834-L3837 → fork L4682-L4685 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 508/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3840-L3843 → fork L4688-L4691 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 509/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3848-L3853 → fork L4696-L4701 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 510/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3856-L3859 → fork L4704-L4707 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 511/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3862-L3865 → fork L4710-L4719 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 512/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3870-L3876 → fork L4724-L4730 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 513/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3879-L3882 → fork L4733-L4736 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 514/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3885-L3888 → fork L4739-L4742 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 515/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3893-L3898 → fork L4747-L4752 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 516/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3901-L3904 → fork L4755-L4758 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 517/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3907-L3910 → fork L4761-L4770 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 518/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3915-L3921 → fork L4775-L4781 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 519/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3924-L3927 → fork L4784-L4793 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 520/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3932-L3938 → fork L4798-L4804 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 521/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3941-L3944 → fork L4807-L4810 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 522/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3949-L3954 → fork L4815-L4820 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 523/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3957-L3960 → fork L4823-L4832 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 524/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3965-L3970 → fork L4837-L4842 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 525/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3973-L3976 → fork L4845-L4854 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 526/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3981-L3986 → fork L4859-L4864 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 527/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3989-L3992 → fork L4867-L4870 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 528/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L3995-L3998 → fork L4873-L4882 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 529/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4003-L4008 → fork L4887-L4892 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 530/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4011-L4014 → fork L4895-L4898 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 531/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4017-L4020 → fork L4901-L4910 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 532/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4025-L4030 → fork L4915-L4920 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 533/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4033-L4036 → fork L4923-L4926 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 534/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4039-L4042 → fork L4929-L4938 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 535/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4047-L4052 → fork L4943-L4948 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 536/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4055-L4058 → fork L4951-L4960 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 537/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4063-L4069 → fork L4965-L4971 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 538/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4072-L4075 → fork L4974-L4977 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 539/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4078-L4081 → fork L4980-L4989 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 540/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4086-L4092 → fork L4994-L5000 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 541/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4095-L4098 → fork L5003-L5006 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 542/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4101-L4104 → fork L5009-L5018 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 543/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4109-L4114 → fork L5023-L5028 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 544/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4117-L4120 → fork L5031-L5040 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 545/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4125-L4130 → fork L5045-L5050 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 546/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4133-L4136 → fork L5053-L5062 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 547/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4141-L4146 → fork L5067-L5072 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 548/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4149-L4152 → fork L5075-L5078 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 549/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4155-L4158 → fork L5081-L5090 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 550/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4163-L4168 → fork L5095-L5100 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 551/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4171-L4174 → fork L5103-L5112 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 552/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4179-L4184 → fork L5117-L5122 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 553/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4187-L4190 → fork L5125-L5134 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 554/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4195-L4200 → fork L5139-L5144 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 555/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4203-L4206 → fork L5147-L5150 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 556/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4209-L4212 → fork L5153-L5162 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 557/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4217-L4222 → fork L5167-L5172 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 558/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4225-L4228 → fork L5175-L5184 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 559/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4233-L4238 → fork L5189-L5194 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 560/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4241-L4244 → fork L5197-L5200 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 561/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4247-L4250 → fork L5203-L5212 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 562/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4255-L4260 → fork L5217-L5222 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 563/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4263-L4266 → fork L5225-L5234 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 564/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4271-L4276 → fork L5239-L5244 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 565/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4279-L4282 → fork L5247-L5256 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 566/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4287-L4292 → fork L5261-L5266 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 567/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4295-L4298 → fork L5269-L5278 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 568/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4303-L4308 → fork L5283-L5288 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 569/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4311-L4314 → fork L5291-L5294 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 570/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4317-L4320 → fork L5297-L5306 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 571/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4325-L4330 → fork L5311-L5316 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 572/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4333-L4336 → fork L5319-L5322 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 573/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4339-L4342 → fork L5325-L5334 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 574/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4347-L4352 → fork L5339-L5344 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 575/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4355-L4358 → fork L5347-L5356 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 576/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4363-L4368 → fork L5361-L5366 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 577/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4371-L4374 → fork L5369-L5372 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 578/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4377-L4380 → fork L5375-L5384 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 579/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4385-L4390 → fork L5389-L5394 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 580/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4393-L4396 → fork L5397-L5406 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 581/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4401-L4406 → fork L5411-L5416 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 582/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4409-L4412 → fork L5419-L5428 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 583/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4417-L4422 → fork L5433-L5438 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 584/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4425-L4428 → fork L5441-L5444 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 585/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4431-L4434 → fork L5447-L5456 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 586/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4439-L4444 → fork L5461-L5466 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 587/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4447-L4450 → fork L5469-L5472 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 588/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4453-L4456 → fork L5475-L5484 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 589/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4461-L4467 → fork L5489-L5495 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 590/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4470-L4473 → fork L5498-L5507 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 591/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4478-L4483 → fork L5512-L5517 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 592/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4486-L4489 → fork L5520-L5529 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 593/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4494-L4499 → fork L5534-L5539 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 594/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4502-L4505 → fork L5542-L5545 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 595/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4508-L4511 → fork L5548-L5557 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 596/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4516-L4521 → fork L5562-L5567 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 597/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4524-L4527 → fork L5570-L5573 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 598/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4530-L4533 → fork L5576-L5585 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 599/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4538-L4544 → fork L5590-L5596 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 600/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4547-L4550 → fork L5599-L5602 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 601/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4553-L4556 → fork L5605-L5614 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 602/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4561-L4567 → fork L5619-L5625 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 603/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4570-L4573 → fork L5628-L5631 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 604/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4576-L4579 → fork L5634-L5643 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 605/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4584-L4589 → fork L5648-L5653 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 606/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4592-L4595 → fork L5656-L5665 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 607/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4600-L4605 → fork L5670-L5675 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 608/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4608-L4611 → fork L5678-L5687 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 609/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4616-L4621 → fork L5692-L5697 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 610/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4624-L4627 → fork L5700-L5709 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 611/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4632-L4637 → fork L5714-L5719 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 612/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4640-L4643 → fork L5722-L5731 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 613/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4648-L4653 → fork L5736-L5741 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 614/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4656-L4659 → fork L5744-L5747 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 615/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4662-L4665 → fork L5750-L5759 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 616/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4670-L4675 → fork L5764-L5769 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 617/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4678-L4681 → fork L5772-L5781 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 618/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4686-L4691 → fork L5786-L5791 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 619/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4694-L4697 → fork L5794-L5803 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 620/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4702-L4708 → fork L5808-L5814 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 621/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4711-L4714 → fork L5817-L5820 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 622/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4717-L4720 → fork L5823-L5832 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 623/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4725-L4731 → fork L5837-L5843 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 624/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4734-L4737 → fork L5846-L5849 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 625/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4740-L4743 → fork L5852-L5861 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 626/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4748-L4753 → fork L5866-L5871 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 627/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4756-L4759 → fork L5874-L5883 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 628/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4764-L4769 → fork L5888-L5893 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 629/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4772-L4775 → fork L5896-L5899 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 630/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4778-L4781 → fork L5902-L5911 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 631/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4786-L4791 → fork L5916-L5921 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 632/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4794-L4797 → fork L5924-L5927 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 633/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4800-L4803 → fork L5930-L5939 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 634/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4808-L4813 → fork L5944-L5949 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 635/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4816-L4819 → fork L5952-L5955 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 636/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4822-L4825 → fork L5958-L5961 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 637/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4830-L4835 → fork L5966-L5971 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 638/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4838-L4841 → fork L5974-L5977 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 639/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4844-L4847 → fork L5980-L5989 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 640/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4852-L4857 → fork L5994-L5999 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 641/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4860-L4863 → fork L6002-L6005 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 642/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4866-L4869 → fork L6008-L6017 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 643/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4874-L4880 → fork L6022-L6028 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 644/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4883-L4886 → fork L6031-L6040 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 645/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4891-L4896 → fork L6045-L6050 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 646/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4899-L4902 → fork L6053-L6056 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 647/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4905-L4908 → fork L6059-L6068 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 648/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4913-L4918 → fork L6073-L6078 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 649/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4921-L4924 → fork L6081-L6084 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 650/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4927-L4930 → fork L6087-L6096 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 651/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4935-L4940 → fork L6101-L6106 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 652/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4943-L4946 → fork L6109-L6112 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 653/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4949-L4952 → fork L6115-L6124 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 654/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4957-L4962 → fork L6129-L6134 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 655/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4965-L4968 → fork L6137-L6140 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 656/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4971-L4974 → fork L6143-L6152 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 657/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4979-L4984 → fork L6157-L6162 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 658/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4987-L4990 → fork L6165-L6168 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 659/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L4993-L4996 → fork L6171-L6180 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 660/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5001-L5006 → fork L6185-L6190 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 661/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5009-L5012 → fork L6193-L6196 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 662/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5015-L5018 → fork L6199-L6208 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 663/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5023-L5028 → fork L6213-L6218 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 664/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5031-L5034 → fork L6221-L6230 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 665/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5039-L5044 → fork L6235-L6240 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 666/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5047-L5050 → fork L6243-L6246 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 667/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5053-L5056 → fork L6249-L6258 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 668/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5061-L5066 → fork L6263-L6268 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 669/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5069-L5072 → fork L6271-L6274 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 670/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5075-L5078 → fork L6277-L6286 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 671/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5083-L5088 → fork L6291-L6296 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 672/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5091-L5094 → fork L6299-L6302 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 673/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5097-L5100 → fork L6305-L6314 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 674/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5105-L5110 → fork L6319-L6324 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 675/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5113-L5116 → fork L6327-L6330 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 676/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5119-L5122 → fork L6333-L6342 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 677/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5127-L5133 → fork L6347-L6353 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 678/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5136-L5139 → fork L6356-L6359 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 679/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5144-L5150 → fork L6364-L6370 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 680/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5153-L5156 → fork L6373-L6376 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 681/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5159-L5162 → fork L6379-L6388 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 682/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5167-L5172 → fork L6393-L6398 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 683/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5175-L5178 → fork L6401-L6410 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 684/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5183-L5188 → fork L6415-L6420 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 685/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5191-L5194 → fork L6423-L6426 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 686/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5197-L5200 → fork L6429-L6438 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 687/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5205-L5211 → fork L6443-L6449 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 688/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5214-L5217 → fork L6452-L6461 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 689/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5222-L5228 → fork L6466-L6472 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 690/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5231-L5234 → fork L6475-L6478 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 691/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5239-L5244 → fork L6483-L6488 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 692/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5247-L5250 → fork L6491-L6500 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 693/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5255-L5260 → fork L6505-L6510 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 694/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5263-L5266 → fork L6513-L6522 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 695/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5271-L5276 → fork L6527-L6532 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 696/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5279-L5282 → fork L6535-L6544 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 697/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5287-L5292 → fork L6549-L6554 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 698/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5295-L5298 → fork L6557-L6566 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 699/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5303-L5308 → fork L6571-L6576 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 700/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5311-L5314 → fork L6579-L6588 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 701/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5319-L5324 → fork L6593-L6598 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 702/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5327-L5330 → fork L6601-L6604 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 703/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5333-L5336 → fork L6607-L6616 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 704/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5341-L5346 → fork L6621-L6626 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 705/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5349-L5352 → fork L6629-L6632 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 706/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5355-L5358 → fork L6635-L6644 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 707/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5363-L5368 → fork L6649-L6654 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 708/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5371-L5374 → fork L6657-L6660 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 709/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5377-L5380 → fork L6663-L6672 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 710/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5385-L5391 → fork L6677-L6683 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 711/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5394-L5397 → fork L6686-L6695 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 712/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5402-L5407 → fork L6700-L6705 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 713/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5410-L5413 → fork L6708-L6711 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 714/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5416-L5419 → fork L6714-L6723 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 715/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5424-L5425 → fork L6728-L6730 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 716/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5427-L5428 → fork L6732-L6734 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 717/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5430-L5435 → fork L6736-L6741 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 718/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5438-L5441 → fork L6744-L6747 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 719/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5444-L5447 → fork L6750-L6753 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 720/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5452-L5457 → fork L6758-L6763 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 721/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5460-L5463 → fork L6766-L6769 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 722/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5466-L5469 → fork L6772-L6781 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 723/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5474-L5475 → fork L6786-L6788 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 724/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5477-L5482 → fork L6790-L6795 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 725/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5485-L5488 → fork L6798-L6801 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 726/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5491-L5494 → fork L6804-L6813 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 727/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5499-L5504 → fork L6818-L6823 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 728/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5507-L5510 → fork L6826-L6829 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 729/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5513-L5516 → fork L6832-L6835 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 730/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5521-L5526 → fork L6840-L6845 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 731/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5529-L5532 → fork L6848-L6851 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 732/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5535-L5538 → fork L6854-L13555 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 733/733**: `Source/Localizable.xcstrings`
  - Lines: upstream L5544-L5544 → fork L13561-L13561 (`replace`)
  - Category: `CONFIG_OR_LOCALIZATION` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - Contract: Preserve upstream catalog; route tab titles to Localizable
  - Approval: `LEGACY_UNREVIEWED`

### Workstream Area: Other (14 hunks)

#### `.gitignore`

- **Hunk 1/1**: `.gitignore`
  - Lines: upstream L1-L1 → fork L1-L1 (`modify`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Configuration / Integration files`
  - Contract: Preserve CI/agent configuration
  - Approval: `LEGACY_UNREVIEWED`

#### `CLAUDE.md`

- **Hunk 1/1**: `CLAUDE.md`
  - Lines: upstream L108-L107 → fork L108-L175 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Configuration / Integration files`
  - Contract: Preserve CI/agent configuration
  - Approval: `LEGACY_UNREVIEWED`

#### `GEMINI.md`

- **Hunk 1/1**: `GEMINI.md`
  - Lines: upstream L1-L1 → fork L1-L28 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Configuration / Integration files`
  - Contract: Preserve CI/agent configuration
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Narrator/ViewModel/NarratorViewModel.swift`

- **Hunk 1/4**: `Source/Features/Narrator/ViewModel/NarratorViewModel.swift`
  - Lines: upstream L137-L136 → fork L137-L140 (`insert`)
  - Category: `LEGACY_UNREVIEWED` | Rigor: `heuristic` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `TBD via owner review`
  - Contract: Legacy divergence prior to clean layer policy
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/4**: `Source/Features/Narrator/ViewModel/NarratorViewModel.swift`
  - Lines: upstream L144-L143 → fork L148-L151 (`insert`)
  - Category: `LEGACY_UNREVIEWED` | Rigor: `heuristic` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `TBD via owner review`
  - Contract: Legacy divergence prior to clean layer policy
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/4**: `Source/Features/Narrator/ViewModel/NarratorViewModel.swift`
  - Lines: upstream L149-L148 → fork L157-L160 (`insert`)
  - Category: `LEGACY_UNREVIEWED` | Rigor: `heuristic` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `TBD via owner review`
  - Contract: Legacy divergence prior to clean layer policy
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/4**: `Source/Features/Narrator/ViewModel/NarratorViewModel.swift`
  - Lines: upstream L216-L215 → fork L228-L228 (`insert`)
  - Category: `LEGACY_UNREVIEWED` | Rigor: `heuristic` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `TBD via owner review`
  - Contract: Legacy divergence prior to clean layer policy
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Maktabah.entitlements`

- **Hunk 1/1**: `Source/Maktabah.entitlements`
  - Lines: upstream L1-L1 → fork L1-L1 (`modify`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `App capabilities / metadata seam`
  - Contract: Preserve app entitlements and identifiers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/MaktabahDirect.entitlements`

- **Hunk 1/1**: `Source/MaktabahDirect.entitlements`
  - Lines: upstream L1-L1 → fork L1-L1 (`modify`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `App capabilities / metadata seam`
  - Contract: Preserve app entitlements and identifiers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/ar.lproj/InfoPlist.strings`

- **Hunk 1/1**: `Source/ar.lproj/InfoPlist.strings`
  - Lines: upstream L1-L1 → fork L1-L1 (`modify`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `App capabilities / metadata seam`
  - Contract: Preserve app entitlements and identifiers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/en.lproj/InfoPlist.strings`

- **Hunk 1/1**: `Source/en.lproj/InfoPlist.strings`
  - Lines: upstream L1-L1 → fork L1-L1 (`modify`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `App capabilities / metadata seam`
  - Contract: Preserve app entitlements and identifiers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/iOS-Info.plist`

- **Hunk 1/2**: `Source/iOS-Info.plist`
  - Lines: upstream L5-L4 → fork L5-L16 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `App capabilities / metadata seam`
  - Contract: Preserve app entitlements and identifiers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/2**: `Source/iOS-Info.plist`
  - Lines: upstream L22-L23 → fork L34-L33 (`delete`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `App capabilities / metadata seam`
  - Contract: Preserve app entitlements and identifiers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/id.lproj/InfoPlist.strings`

- **Hunk 1/1**: `Source/id.lproj/InfoPlist.strings`
  - Lines: upstream L1-L1 → fork L1-L1 (`modify`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `App capabilities / metadata seam`
  - Contract: Preserve app entitlements and identifiers
  - Approval: `LEGACY_UNREVIEWED`

### Workstream Area: Upstream Annotations (29 hunks)

#### `Source/Features/Annotations/Coordinator/AnnotationCoordinator.swift`

- **Hunk 1/6**: `Source/Features/Annotations/Coordinator/AnnotationCoordinator.swift`
  - Lines: upstream L9-L8 → fork L9-L22 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Annotations/BackendAnnotationBridge.swift`
  - Contract: Preserve original Annotation schema; isolate backend locator bridge
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/6**: `Source/Features/Annotations/Coordinator/AnnotationCoordinator.swift`
  - Lines: upstream L21-L20 → fork L35-L83 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Annotations/BackendAnnotationBridge.swift`
  - Contract: Preserve original Annotation schema; isolate backend locator bridge
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/6**: `Source/Features/Annotations/Coordinator/AnnotationCoordinator.swift`
  - Lines: upstream L76-L75 → fork L139-L157 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Annotations/BackendAnnotationBridge.swift`
  - Contract: Preserve original Annotation schema; isolate backend locator bridge
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/6**: `Source/Features/Annotations/Coordinator/AnnotationCoordinator.swift`
  - Lines: upstream L77-L76 → fork L159-L238 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Annotations/BackendAnnotationBridge.swift`
  - Contract: Preserve original Annotation schema; isolate backend locator bridge
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/6**: `Source/Features/Annotations/Coordinator/AnnotationCoordinator.swift`
  - Lines: upstream L89-L89 → fork L251-L250 (`delete`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Annotations/BackendAnnotationBridge.swift`
  - Contract: Preserve original Annotation schema; isolate backend locator bridge
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/6**: `Source/Features/Annotations/Coordinator/AnnotationCoordinator.swift`
  - Lines: upstream L115-L115 → fork L276-L277 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Annotations/BackendAnnotationBridge.swift`
  - Contract: Preserve original Annotation schema; isolate backend locator bridge
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Annotations/Database/AnnotationRepository.swift`

- **Hunk 1/7**: `Source/Features/Annotations/Database/AnnotationRepository.swift`
  - Lines: upstream L31-L30 → fork L31-L31 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Annotations/`
  - Contract: Preserve TextLocator extension and Codable schema backwards compatibility
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/7**: `Source/Features/Annotations/Database/AnnotationRepository.swift`
  - Lines: upstream L157-L156 → fork L158-L160 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Annotations/`
  - Contract: Preserve TextLocator extension and Codable schema backwards compatibility
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/7**: `Source/Features/Annotations/Database/AnnotationRepository.swift`
  - Lines: upstream L212-L211 → fork L216-L220 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Annotations/`
  - Contract: Preserve TextLocator extension and Codable schema backwards compatibility
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/7**: `Source/Features/Annotations/Database/AnnotationRepository.swift`
  - Lines: upstream L229-L229 → fork L238-L239 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Annotations/`
  - Contract: Preserve TextLocator extension and Codable schema backwards compatibility
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/7**: `Source/Features/Annotations/Database/AnnotationRepository.swift`
  - Lines: upstream L246-L247 → fork L256-L257 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Annotations/`
  - Contract: Preserve TextLocator extension and Codable schema backwards compatibility
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/7**: `Source/Features/Annotations/Database/AnnotationRepository.swift`
  - Lines: upstream L266-L265 → fork L276-L277 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Annotations/`
  - Contract: Preserve TextLocator extension and Codable schema backwards compatibility
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/7**: `Source/Features/Annotations/Database/AnnotationRepository.swift`
  - Lines: upstream L349-L348 → fork L361-L368 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Annotations/`
  - Contract: Preserve TextLocator extension and Codable schema backwards compatibility
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Annotations/Models/Annotation.swift`

- **Hunk 1/3**: `Source/Features/Annotations/Models/Annotation.swift`
  - Lines: upstream L13-L13 → fork L13-L13 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Annotations/`
  - Contract: Preserve TextLocator extension and Codable schema backwards compatibility
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/3**: `Source/Features/Annotations/Models/Annotation.swift`
  - Lines: upstream L28-L27 → fork L28-L28 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Annotations/`
  - Contract: Preserve TextLocator extension and Codable schema backwards compatibility
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/3**: `Source/Features/Annotations/Models/Annotation.swift`
  - Lines: upstream L60-L59 → fork L61-L179 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Annotations/`
  - Contract: Preserve TextLocator extension and Codable schema backwards compatibility
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Annotations/Models/AnnotationJsonSerializer.swift`

- **Hunk 1/5**: `Source/Features/Annotations/Models/AnnotationJsonSerializer.swift`
  - Lines: upstream L54-L53 → fork L54-L58 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Annotations/`
  - Contract: Preserve TextLocator extension and Codable schema backwards compatibility
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/5**: `Source/Features/Annotations/Models/AnnotationJsonSerializer.swift`
  - Lines: upstream L76-L75 → fork L81-L81 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Annotations/`
  - Contract: Preserve TextLocator extension and Codable schema backwards compatibility
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/5**: `Source/Features/Annotations/Models/AnnotationJsonSerializer.swift`
  - Lines: upstream L77-L76 → fork L83-L83 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Annotations/`
  - Contract: Preserve TextLocator extension and Codable schema backwards compatibility
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/5**: `Source/Features/Annotations/Models/AnnotationJsonSerializer.swift`
  - Lines: upstream L125-L124 → fork L132-L134 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Annotations/`
  - Contract: Preserve TextLocator extension and Codable schema backwards compatibility
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/5**: `Source/Features/Annotations/Models/AnnotationJsonSerializer.swift`
  - Lines: upstream L143-L143 → fork L153-L154 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Annotations/`
  - Contract: Preserve TextLocator extension and Codable schema backwards compatibility
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Annotations/iOS/AnnotationContentView.swift`

- **Hunk 1/5**: `Source/Features/Annotations/iOS/AnnotationContentView.swift`
  - Lines: upstream L128-L128 → fork L128-L128 (`replace`)
  - Category: `LEGACY_UNREVIEWED` | Rigor: `heuristic` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `TBD via owner review`
  - Contract: Legacy divergence prior to clean layer policy
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/5**: `Source/Features/Annotations/iOS/AnnotationContentView.swift`
  - Lines: upstream L153-L154 → fork L153-L155 (`replace`)
  - Category: `LEGACY_UNREVIEWED` | Rigor: `heuristic` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `TBD via owner review`
  - Contract: Legacy divergence prior to clean layer policy
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/5**: `Source/Features/Annotations/iOS/AnnotationContentView.swift`
  - Lines: upstream L156-L156 → fork L157-L157 (`replace`)
  - Category: `LEGACY_UNREVIEWED` | Rigor: `heuristic` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `TBD via owner review`
  - Contract: Legacy divergence prior to clean layer policy
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/5**: `Source/Features/Annotations/iOS/AnnotationContentView.swift`
  - Lines: upstream L160-L160 → fork L161-L161 (`replace`)
  - Category: `LEGACY_UNREVIEWED` | Rigor: `heuristic` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `TBD via owner review`
  - Contract: Legacy divergence prior to clean layer policy
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/5**: `Source/Features/Annotations/iOS/AnnotationContentView.swift`
  - Lines: upstream L162-L162 → fork L163-L163 (`replace`)
  - Category: `LEGACY_UNREVIEWED` | Rigor: `heuristic` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `TBD via owner review`
  - Contract: Legacy divergence prior to clean layer policy
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Annotations/iOS/AnnotationViewControllerWrapper.swift`

- **Hunk 1/1**: `Source/Features/Annotations/iOS/AnnotationViewControllerWrapper.swift`
  - Lines: upstream L89-L88 → fork L89-L127 (`insert`)
  - Category: `LEGACY_UNREVIEWED` | Rigor: `heuristic` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `TBD via owner review`
  - Contract: Legacy divergence prior to clean layer policy
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Annotations/macOS/OutlineView/AnnotationRowHeightCalculator.swift`

- **Hunk 1/1**: `Source/Features/Annotations/macOS/OutlineView/AnnotationRowHeightCalculator.swift`
  - Lines: upstream L91-L91 → fork L91-L91 (`replace`)
  - Category: `LEGACY_UNREVIEWED` | Rigor: `heuristic` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `TBD via owner review`
  - Contract: Legacy divergence prior to clean layer policy
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Annotations/macOS/OutlineView/AnnotationsOutlineDelegate.swift`

- **Hunk 1/1**: `Source/Features/Annotations/macOS/OutlineView/AnnotationsOutlineDelegate.swift`
  - Lines: upstream L84-L84 → fork L84-L84 (`replace`)
  - Category: `LEGACY_UNREVIEWED` | Rigor: `heuristic` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `TBD via owner review`
  - Contract: Legacy divergence prior to clean layer policy
  - Approval: `LEGACY_UNREVIEWED`

### Workstream Area: Upstream History (12 hunks)

#### `Source/Features/History/ViewModel/Extensions/History+Core.swift`

- **Hunk 1/1**: `Source/Features/History/ViewModel/Extensions/History+Core.swift`
  - Lines: upstream L173-L172 → fork L173-L195 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/History/`
  - Contract: Preserve history tracking; isolate backend-specific queries
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/History/ViewModel/Extensions/History+Database.swift`

- **Hunk 1/2**: `Source/Features/History/ViewModel/Extensions/History+Database.swift`
  - Lines: upstream L62-L61 → fork L62-L77 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/History/`
  - Contract: Preserve history tracking; isolate backend-specific queries
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/2**: `Source/Features/History/ViewModel/Extensions/History+Database.swift`
  - Lines: upstream L63-L62 → fork L79-L79 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/History/`
  - Contract: Preserve history tracking; isolate backend-specific queries
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/History/ViewModel/HistoryViewModel.swift`

- **Hunk 1/2**: `Source/Features/History/ViewModel/HistoryViewModel.swift`
  - Lines: upstream L6-L6 → fork L6-L6 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/History/`
  - Contract: Preserve history tracking; isolate backend-specific queries
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/2**: `Source/Features/History/ViewModel/HistoryViewModel.swift`
  - Lines: upstream L112-L111 → fork L112-L116 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/History/`
  - Contract: Preserve history tracking; isolate backend-specific queries
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/History/iOS/HistoryComponents.swift`

- **Hunk 1/5**: `Source/Features/History/iOS/HistoryComponents.swift`
  - Lines: upstream L101-L101 → fork L101-L101 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/History/`
  - Contract: Preserve history tracking; isolate backend-specific queries
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/5**: `Source/Features/History/iOS/HistoryComponents.swift`
  - Lines: upstream L110-L109 → fork L110-L116 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/History/`
  - Contract: Preserve history tracking; isolate backend-specific queries
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/5**: `Source/Features/History/iOS/HistoryComponents.swift`
  - Lines: upstream L226-L226 → fork L233-L233 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/History/`
  - Contract: Preserve history tracking; isolate backend-specific queries
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/5**: `Source/Features/History/iOS/HistoryComponents.swift`
  - Lines: upstream L235-L235 → fork L242-L242 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/History/`
  - Contract: Preserve history tracking; isolate backend-specific queries
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/5**: `Source/Features/History/iOS/HistoryComponents.swift`
  - Lines: upstream L285-L285 → fork L292-L292 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/History/`
  - Contract: Preserve history tracking; isolate backend-specific queries
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/History/iOS/HistoryFavoriteSections.swift`

- **Hunk 1/2**: `Source/Features/History/iOS/HistoryFavoriteSections.swift`
  - Lines: upstream L45-L45 → fork L45-L45 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/History/`
  - Contract: Preserve history tracking; isolate backend-specific queries
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/2**: `Source/Features/History/iOS/HistoryFavoriteSections.swift`
  - Lines: upstream L54-L53 → fork L54-L93 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/History/`
  - Contract: Preserve history tracking; isolate backend-specific queries
  - Approval: `LEGACY_UNREVIEWED`

### Workstream Area: Upstream Library (73 hunks)

#### `Source/Features/Library/Database/LibraryDataManager.swift`

- **Hunk 1/27**: `Source/Features/Library/Database/LibraryDataManager.swift`
  - Lines: upstream L24-L23 → fork L24-L25 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/LibraryDataManagerAdapter.swift`
  - Contract: Preserve original SQLite catalog loading; extract BackendCoordinator hooks
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/27**: `Source/Features/Library/Database/LibraryDataManager.swift`
  - Lines: upstream L26-L25 → fork L28-L30 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/LibraryDataManagerAdapter.swift`
  - Contract: Preserve original SQLite catalog loading; extract BackendCoordinator hooks
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/27**: `Source/Features/Library/Database/LibraryDataManager.swift`
  - Lines: upstream L54-L53 → fork L59-L66 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/LibraryDataManagerAdapter.swift`
  - Contract: Preserve original SQLite catalog loading; extract BackendCoordinator hooks
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/27**: `Source/Features/Library/Database/LibraryDataManager.swift`
  - Lines: upstream L56-L58 → fork L69-L78 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/LibraryDataManagerAdapter.swift`
  - Contract: Preserve original SQLite catalog loading; extract BackendCoordinator hooks
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/27**: `Source/Features/Library/Database/LibraryDataManager.swift`
  - Lines: upstream L61-L61 → fork L81-L83 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/LibraryDataManagerAdapter.swift`
  - Contract: Preserve original SQLite catalog loading; extract BackendCoordinator hooks
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/27**: `Source/Features/Library/Database/LibraryDataManager.swift`
  - Lines: upstream L64-L64 → fork L86-L88 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/LibraryDataManagerAdapter.swift`
  - Contract: Preserve original SQLite catalog loading; extract BackendCoordinator hooks
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/27**: `Source/Features/Library/Database/LibraryDataManager.swift`
  - Lines: upstream L66-L67 → fork L90-L134 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/LibraryDataManagerAdapter.swift`
  - Contract: Preserve original SQLite catalog loading; extract BackendCoordinator hooks
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 8/27**: `Source/Features/Library/Database/LibraryDataManager.swift`
  - Lines: upstream L69-L69 → fork L136-L138 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/LibraryDataManagerAdapter.swift`
  - Contract: Preserve original SQLite catalog loading; extract BackendCoordinator hooks
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 9/27**: `Source/Features/Library/Database/LibraryDataManager.swift`
  - Lines: upstream L78-L77 → fork L147-L163 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/LibraryDataManagerAdapter.swift`
  - Contract: Preserve original SQLite catalog loading; extract BackendCoordinator hooks
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 10/27**: `Source/Features/Library/Database/LibraryDataManager.swift`
  - Lines: upstream L82-L81 → fork L168-L181 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/LibraryDataManagerAdapter.swift`
  - Contract: Preserve original SQLite catalog loading; extract BackendCoordinator hooks
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 11/27**: `Source/Features/Library/Database/LibraryDataManager.swift`
  - Lines: upstream L107-L127 → fork L207-L206 (`delete`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/LibraryDataManagerAdapter.swift`
  - Contract: Preserve original SQLite catalog loading; extract BackendCoordinator hooks
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 12/27**: `Source/Features/Library/Database/LibraryDataManager.swift`
  - Lines: upstream L133-L135 → fork L212-L213 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/LibraryDataManagerAdapter.swift`
  - Contract: Preserve original SQLite catalog loading; extract BackendCoordinator hooks
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 13/27**: `Source/Features/Library/Database/LibraryDataManager.swift`
  - Lines: upstream L137-L139 → fork L215-L217 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/LibraryDataManagerAdapter.swift`
  - Contract: Preserve original SQLite catalog loading; extract BackendCoordinator hooks
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 14/27**: `Source/Features/Library/Database/LibraryDataManager.swift`
  - Lines: upstream L141-L146 → fork L219-L222 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/LibraryDataManagerAdapter.swift`
  - Contract: Preserve original SQLite catalog loading; extract BackendCoordinator hooks
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 15/27**: `Source/Features/Library/Database/LibraryDataManager.swift`
  - Lines: upstream L148-L149 → fork L224-L224 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/LibraryDataManagerAdapter.swift`
  - Contract: Preserve original SQLite catalog loading; extract BackendCoordinator hooks
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 16/27**: `Source/Features/Library/Database/LibraryDataManager.swift`
  - Lines: upstream L160-L160 → fork L235-L236 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/LibraryDataManagerAdapter.swift`
  - Contract: Preserve original SQLite catalog loading; extract BackendCoordinator hooks
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 17/27**: `Source/Features/Library/Database/LibraryDataManager.swift`
  - Lines: upstream L162-L162 → fork L238-L240 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/LibraryDataManagerAdapter.swift`
  - Contract: Preserve original SQLite catalog loading; extract BackendCoordinator hooks
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 18/27**: `Source/Features/Library/Database/LibraryDataManager.swift`
  - Lines: upstream L221-L220 → fork L299-L301 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/LibraryDataManagerAdapter.swift`
  - Contract: Preserve original SQLite catalog loading; extract BackendCoordinator hooks
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 19/27**: `Source/Features/Library/Database/LibraryDataManager.swift`
  - Lines: upstream L222-L221 → fork L303-L304 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/LibraryDataManagerAdapter.swift`
  - Contract: Preserve original SQLite catalog loading; extract BackendCoordinator hooks
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 20/27**: `Source/Features/Library/Database/LibraryDataManager.swift`
  - Lines: upstream L288-L287 → fork L371-L384 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/LibraryDataManagerAdapter.swift`
  - Contract: Preserve original SQLite catalog loading; extract BackendCoordinator hooks
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 21/27**: `Source/Features/Library/Database/LibraryDataManager.swift`
  - Lines: upstream L465-L464 → fork L562-L577 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/LibraryDataManagerAdapter.swift`
  - Contract: Preserve original SQLite catalog loading; extract BackendCoordinator hooks
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 22/27**: `Source/Features/Library/Database/LibraryDataManager.swift`
  - Lines: upstream L804-L803 → fork L917-L917 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/LibraryDataManagerAdapter.swift`
  - Contract: Preserve original SQLite catalog loading; extract BackendCoordinator hooks
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 23/27**: `Source/Features/Library/Database/LibraryDataManager.swift`
  - Lines: upstream L817-L816 → fork L931-L941 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/LibraryDataManagerAdapter.swift`
  - Contract: Preserve original SQLite catalog loading; extract BackendCoordinator hooks
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 24/27**: `Source/Features/Library/Database/LibraryDataManager.swift`
  - Lines: upstream L820-L823 → fork L945-L944 (`delete`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/LibraryDataManagerAdapter.swift`
  - Contract: Preserve original SQLite catalog loading; extract BackendCoordinator hooks
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 25/27**: `Source/Features/Library/Database/LibraryDataManager.swift`
  - Lines: upstream L879-L879 → fork L1000-L1000 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/LibraryDataManagerAdapter.swift`
  - Contract: Preserve original SQLite catalog loading; extract BackendCoordinator hooks
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 26/27**: `Source/Features/Library/Database/LibraryDataManager.swift`
  - Lines: upstream L882-L882 → fork L1003-L1005 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/LibraryDataManagerAdapter.swift`
  - Contract: Preserve original SQLite catalog loading; extract BackendCoordinator hooks
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 27/27**: `Source/Features/Library/Database/LibraryDataManager.swift`
  - Lines: upstream L897-L896 → fork L1020-L1020 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/LibraryDataManagerAdapter.swift`
  - Contract: Preserve original SQLite catalog loading; extract BackendCoordinator hooks
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Library/Models/BooksData.swift`

- **Hunk 1/6**: `Source/Features/Library/Models/BooksData.swift`
  - Lines: upstream L11-L10 → fork L11-L11 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/`
  - Contract: Preserve backendLocator on BooksData for library lookup
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/6**: `Source/Features/Library/Models/BooksData.swift`
  - Lines: upstream L15-L14 → fork L16-L19 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/`
  - Contract: Preserve backendLocator on BooksData for library lookup
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/6**: `Source/Features/Library/Models/BooksData.swift`
  - Lines: upstream L20-L19 → fork L25-L26 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/`
  - Contract: Preserve backendLocator on BooksData for library lookup
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/6**: `Source/Features/Library/Models/BooksData.swift`
  - Lines: upstream L42-L42 → fork L49-L58 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/`
  - Contract: Preserve backendLocator on BooksData for library lookup
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/6**: `Source/Features/Library/Models/BooksData.swift`
  - Lines: upstream L48-L47 → fork L64-L65 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/`
  - Contract: Preserve backendLocator on BooksData for library lookup
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/6**: `Source/Features/Library/Models/BooksData.swift`
  - Lines: upstream L51-L50 → fork L69-L72 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/`
  - Contract: Preserve backendLocator on BooksData for library lookup
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Library/Models/CategoryData.swift`

- **Hunk 1/4**: `Source/Features/Library/Models/CategoryData.swift`
  - Lines: upstream L14-L13 → fork L14-L14 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/`
  - Contract: Preserve backendLocator on BooksData for library lookup
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/4**: `Source/Features/Library/Models/CategoryData.swift`
  - Lines: upstream L17-L17 → fork L18-L18 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/`
  - Contract: Preserve backendLocator on BooksData for library lookup
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/4**: `Source/Features/Library/Models/CategoryData.swift`
  - Lines: upstream L23-L22 → fork L24-L24 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/`
  - Contract: Preserve backendLocator on BooksData for library lookup
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/4**: `Source/Features/Library/Models/CategoryData.swift`
  - Lines: upstream L30-L30 → fork L32-L33 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/LibraryBackend/`
  - Contract: Preserve backendLocator on BooksData for library lookup
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Library/ViewModel/Extensions/BulkActionLibrary.swift`

- **Hunk 1/3**: `Source/Features/Library/ViewModel/Extensions/BulkActionLibrary.swift`
  - Lines: upstream L15-L15 → fork L15-L21 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/`
  - Contract: Preserve upstream collection view; isolate multi-source filtering
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/3**: `Source/Features/Library/ViewModel/Extensions/BulkActionLibrary.swift`
  - Lines: upstream L22-L21 → fork L28-L30 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/`
  - Contract: Preserve upstream collection view; isolate multi-source filtering
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/3**: `Source/Features/Library/ViewModel/Extensions/BulkActionLibrary.swift`
  - Lines: upstream L30-L29 → fork L39-L67 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/`
  - Contract: Preserve upstream collection view; isolate multi-source filtering
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Library/ViewModel/Extensions/FilterLibrary.swift`

- **Hunk 1/3**: `Source/Features/Library/ViewModel/Extensions/FilterLibrary.swift`
  - Lines: upstream L24-L24 → fork L24-L24 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/`
  - Contract: Preserve upstream collection view; isolate multi-source filtering
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/3**: `Source/Features/Library/ViewModel/Extensions/FilterLibrary.swift`
  - Lines: upstream L65-L65 → fork L65-L65 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/`
  - Contract: Preserve upstream collection view; isolate multi-source filtering
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/3**: `Source/Features/Library/ViewModel/Extensions/FilterLibrary.swift`
  - Lines: upstream L127-L126 → fork L127-L148 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/`
  - Contract: Preserve upstream collection view; isolate multi-source filtering
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Library/ViewModel/Extensions/ObserversLibrary.swift`

- **Hunk 1/1**: `Source/Features/Library/ViewModel/Extensions/ObserversLibrary.swift`
  - Lines: upstream L74-L73 → fork L74-L99 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/`
  - Contract: Preserve upstream collection view; isolate multi-source filtering
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Library/ViewModel/LibraryViewModel.swift`

- **Hunk 1/13**: `Source/Features/Library/ViewModel/LibraryViewModel.swift`
  - Lines: upstream L34-L33 → fork L34-L37 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/`
  - Contract: Preserve upstream collection view; isolate multi-source filtering
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/13**: `Source/Features/Library/ViewModel/LibraryViewModel.swift`
  - Lines: upstream L131-L131 → fork L135-L148 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/`
  - Contract: Preserve upstream collection view; isolate multi-source filtering
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/13**: `Source/Features/Library/ViewModel/LibraryViewModel.swift`
  - Lines: upstream L142-L141 → fork L159-L159 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/`
  - Contract: Preserve upstream collection view; isolate multi-source filtering
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/13**: `Source/Features/Library/ViewModel/LibraryViewModel.swift`
  - Lines: upstream L143-L143 → fork L161-L164 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/`
  - Contract: Preserve upstream collection view; isolate multi-source filtering
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/13**: `Source/Features/Library/ViewModel/LibraryViewModel.swift`
  - Lines: upstream L149-L148 → fork L170-L170 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/`
  - Contract: Preserve upstream collection view; isolate multi-source filtering
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/13**: `Source/Features/Library/ViewModel/LibraryViewModel.swift`
  - Lines: upstream L150-L149 → fork L172-L175 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/`
  - Contract: Preserve upstream collection view; isolate multi-source filtering
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/13**: `Source/Features/Library/ViewModel/LibraryViewModel.swift`
  - Lines: upstream L152-L151 → fork L178-L179 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/`
  - Contract: Preserve upstream collection view; isolate multi-source filtering
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 8/13**: `Source/Features/Library/ViewModel/LibraryViewModel.swift`
  - Lines: upstream L154-L153 → fork L182-L185 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/`
  - Contract: Preserve upstream collection view; isolate multi-source filtering
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 9/13**: `Source/Features/Library/ViewModel/LibraryViewModel.swift`
  - Lines: upstream L158-L157 → fork L190-L190 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/`
  - Contract: Preserve upstream collection view; isolate multi-source filtering
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 10/13**: `Source/Features/Library/ViewModel/LibraryViewModel.swift`
  - Lines: upstream L159-L158 → fork L192-L195 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/`
  - Contract: Preserve upstream collection view; isolate multi-source filtering
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 11/13**: `Source/Features/Library/ViewModel/LibraryViewModel.swift`
  - Lines: upstream L161-L160 → fork L198-L208 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/`
  - Contract: Preserve upstream collection view; isolate multi-source filtering
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 12/13**: `Source/Features/Library/ViewModel/LibraryViewModel.swift`
  - Lines: upstream L167-L169 → fork L215-L214 (`delete`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/`
  - Contract: Preserve upstream collection view; isolate multi-source filtering
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 13/13**: `Source/Features/Library/ViewModel/LibraryViewModel.swift`
  - Lines: upstream L175-L174 → fork L220-L221 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/`
  - Contract: Preserve upstream collection view; isolate multi-source filtering
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Library/iOS/AuthorModeView.swift`

- **Hunk 1/6**: `Source/Features/Library/iOS/AuthorModeView.swift`
  - Lines: upstream L5-L4 → fork L5-L5 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/`
  - Contract: Preserve upstream collection view; isolate multi-source filtering
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/6**: `Source/Features/Library/iOS/AuthorModeView.swift`
  - Lines: upstream L7-L6 → fork L8-L13 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/`
  - Contract: Preserve upstream collection view; isolate multi-source filtering
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/6**: `Source/Features/Library/iOS/AuthorModeView.swift`
  - Lines: upstream L8-L8 → fork L15-L25 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/`
  - Contract: Preserve upstream collection view; isolate multi-source filtering
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/6**: `Source/Features/Library/iOS/AuthorModeView.swift`
  - Lines: upstream L10-L9 → fork L27-L28 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/`
  - Contract: Preserve upstream collection view; isolate multi-source filtering
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/6**: `Source/Features/Library/iOS/AuthorModeView.swift`
  - Lines: upstream L45-L46 → fork L64-L65 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/`
  - Contract: Preserve upstream collection view; isolate multi-source filtering
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/6**: `Source/Features/Library/iOS/AuthorModeView.swift`
  - Lines: upstream L60-L61 → fork L79-L80 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/`
  - Contract: Preserve upstream collection view; isolate multi-source filtering
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Library/iOS/LibraryViewControllerWrapper.swift`

- **Hunk 1/5**: `Source/Features/Library/iOS/LibraryViewControllerWrapper.swift`
  - Lines: upstream L28-L27 → fork L28-L30 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/`
  - Contract: Preserve upstream collection view; isolate multi-source filtering
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/5**: `Source/Features/Library/iOS/LibraryViewControllerWrapper.swift`
  - Lines: upstream L31-L42 → fork L34-L53 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/`
  - Contract: Preserve upstream collection view; isolate multi-source filtering
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/5**: `Source/Features/Library/iOS/LibraryViewControllerWrapper.swift`
  - Lines: upstream L59-L59 → fork L70-L72 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/`
  - Contract: Preserve upstream collection view; isolate multi-source filtering
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/5**: `Source/Features/Library/iOS/LibraryViewControllerWrapper.swift`
  - Lines: upstream L76-L75 → fork L89-L93 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/`
  - Contract: Preserve upstream collection view; isolate multi-source filtering
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/5**: `Source/Features/Library/iOS/LibraryViewControllerWrapper.swift`
  - Lines: upstream L82-L81 → fork L100-L100 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/`
  - Contract: Preserve upstream collection view; isolate multi-source filtering
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Library/iOS/iOSLibraryView.swift`

- **Hunk 1/3**: `Source/Features/Library/iOS/iOSLibraryView.swift`
  - Lines: upstream L87-L89 → fork L87-L90 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/`
  - Contract: Preserve upstream collection view; isolate multi-source filtering
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/3**: `Source/Features/Library/iOS/iOSLibraryView.swift`
  - Lines: upstream L111-L136 → fork L112-L115 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/`
  - Contract: Preserve upstream collection view; isolate multi-source filtering
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/3**: `Source/Features/Library/iOS/iOSLibraryView.swift`
  - Lines: upstream L247-L267 → fork L226-L225 (`delete`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Library/`
  - Contract: Preserve upstream collection view; isolate multi-source filtering
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Library/iOS/iOSLibraryViewController.swift`

- **Hunk 1/2**: `Source/Features/Library/iOS/iOSLibraryViewController.swift`
  - Lines: upstream L22-L22 → fork L22-L22 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/2**: `Source/Features/Library/iOS/iOSLibraryViewController.swift`
  - Lines: upstream L25-L25 → fork L25-L25 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

### Workstream Area: Upstream Reader (213 hunks)

#### `Source/Features/Reader/Cache/BookPageCache.swift`

- **Hunk 1/1**: `Source/Features/Reader/Cache/BookPageCache.swift`
  - Lines: upstream L45-L45 → fork L45-L45 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Reader/Models/BookContent.swift`

- **Hunk 1/3**: `Source/Features/Reader/Models/BookContent.swift`
  - Lines: upstream L16-L15 → fork L16-L17 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/3**: `Source/Features/Reader/Models/BookContent.swift`
  - Lines: upstream L17-L17 → fork L19-L28 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/3**: `Source/Features/Reader/Models/BookContent.swift`
  - Lines: upstream L22-L21 → fork L33-L36 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Reader/Models/CleanedTextKey.swift`

- **Hunk 1/1**: `Source/Features/Reader/Models/CleanedTextKey.swift`
  - Lines: upstream L12-L11 → fork L12-L19 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Reader/Models/OpenBookOptions.swift`

- **Hunk 1/3**: `Source/Features/Reader/Models/OpenBookOptions.swift`
  - Lines: upstream L15-L14 → fork L15-L19 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/3**: `Source/Features/Reader/Models/OpenBookOptions.swift`
  - Lines: upstream L20-L20 → fork L25-L30 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/3**: `Source/Features/Reader/Models/OpenBookOptions.swift`
  - Lines: upstream L26-L25 → fork L36-L40 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Reader/Models/ProcessedArabicContent.swift`

- **Hunk 1/3**: `Source/Features/Reader/Models/ProcessedArabicContent.swift`
  - Lines: upstream L19-L18 → fork L19-L20 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/3**: `Source/Features/Reader/Models/ProcessedArabicContent.swift`
  - Lines: upstream L27-L27 → fork L29-L31 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/3**: `Source/Features/Reader/Models/ProcessedArabicContent.swift`
  - Lines: upstream L36-L35 → fork L40-L41 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Reader/Models/ReaderState.swift`

- **Hunk 1/5**: `Source/Features/Reader/Models/ReaderState.swift`
  - Lines: upstream L24-L23 → fork L24-L25 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/5**: `Source/Features/Reader/Models/ReaderState.swift`
  - Lines: upstream L72-L71 → fork L74-L74 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/5**: `Source/Features/Reader/Models/ReaderState.swift`
  - Lines: upstream L90-L90 → fork L93-L93 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/5**: `Source/Features/Reader/Models/ReaderState.swift`
  - Lines: upstream L100-L99 → fork L103-L103 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/5**: `Source/Features/Reader/Models/ReaderState.swift`
  - Lines: upstream L133-L132 → fork L137-L137 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Reader/Models/TOC.swift`

- **Hunk 1/2**: `Source/Features/Reader/Models/TOC.swift`
  - Lines: upstream L8-L8 → fork L8-L8 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/2**: `Source/Features/Reader/Models/TOC.swift`
  - Lines: upstream L13-L12 → fork L13-L23 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Reader/Models/TOCNode.swift`

- **Hunk 1/3**: `Source/Features/Reader/Models/TOCNode.swift`
  - Lines: upstream L13-L12 → fork L13-L14 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/3**: `Source/Features/Reader/Models/TOCNode.swift`
  - Lines: upstream L14-L13 → fork L16-L18 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/3**: `Source/Features/Reader/Models/TOCNode.swift`
  - Lines: upstream L22-L21 → fork L27-L39 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Reader/ViewModel/BookTOCViewModel.swift`

- **Hunk 1/12**: `Source/Features/Reader/ViewModel/BookTOCViewModel.swift`
  - Lines: upstream L21-L20 → fork L21-L34 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/12**: `Source/Features/Reader/ViewModel/BookTOCViewModel.swift`
  - Lines: upstream L25-L24 → fork L39-L41 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/12**: `Source/Features/Reader/ViewModel/BookTOCViewModel.swift`
  - Lines: upstream L31-L30 → fork L48-L48 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/12**: `Source/Features/Reader/ViewModel/BookTOCViewModel.swift`
  - Lines: upstream L40-L39 → fork L58-L113 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/12**: `Source/Features/Reader/ViewModel/BookTOCViewModel.swift`
  - Lines: upstream L58-L58 → fork L132-L132 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/12**: `Source/Features/Reader/ViewModel/BookTOCViewModel.swift`
  - Lines: upstream L63-L66 → fork L137-L137 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/12**: `Source/Features/Reader/ViewModel/BookTOCViewModel.swift`
  - Lines: upstream L75-L75 → fork L146-L146 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 8/12**: `Source/Features/Reader/ViewModel/BookTOCViewModel.swift`
  - Lines: upstream L86-L85 → fork L157-L196 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 9/12**: `Source/Features/Reader/ViewModel/BookTOCViewModel.swift`
  - Lines: upstream L141-L140 → fork L252-L256 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 10/12**: `Source/Features/Reader/ViewModel/BookTOCViewModel.swift`
  - Lines: upstream L167-L166 → fork L283-L302 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 11/12**: `Source/Features/Reader/ViewModel/BookTOCViewModel.swift`
  - Lines: upstream L176-L180 → fork L312-L312 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 12/12**: `Source/Features/Reader/ViewModel/BookTOCViewModel.swift`
  - Lines: upstream L190-L189 → fork L322-L327 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Reader/ViewModel/Extensions/Reader+Annotation.swift`

- **Hunk 1/8**: `Source/Features/Reader/ViewModel/Extensions/Reader+Annotation.swift`
  - Lines: upstream L14-L16 → fork L14-L19 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Annotations/BackendAnnotationBridge.swift`
  - Contract: Preserve original Annotation schema; isolate backend locator bridge
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/8**: `Source/Features/Reader/ViewModel/Extensions/Reader+Annotation.swift`
  - Lines: upstream L24-L24 → fork L27-L27 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Annotations/BackendAnnotationBridge.swift`
  - Contract: Preserve original Annotation schema; isolate backend locator bridge
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/8**: `Source/Features/Reader/ViewModel/Extensions/Reader+Annotation.swift`
  - Lines: upstream L27-L28 → fork L30-L30 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Annotations/BackendAnnotationBridge.swift`
  - Contract: Preserve original Annotation schema; isolate backend locator bridge
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/8**: `Source/Features/Reader/ViewModel/Extensions/Reader+Annotation.swift`
  - Lines: upstream L39-L39 → fork L41-L46 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Annotations/BackendAnnotationBridge.swift`
  - Contract: Preserve original Annotation schema; isolate backend locator bridge
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/8**: `Source/Features/Reader/ViewModel/Extensions/Reader+Annotation.swift`
  - Lines: upstream L50-L50 → fork L57-L58 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Annotations/BackendAnnotationBridge.swift`
  - Contract: Preserve original Annotation schema; isolate backend locator bridge
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/8**: `Source/Features/Reader/ViewModel/Extensions/Reader+Annotation.swift`
  - Lines: upstream L54-L53 → fork L62-L104 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Annotations/BackendAnnotationBridge.swift`
  - Contract: Preserve original Annotation schema; isolate backend locator bridge
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/8**: `Source/Features/Reader/ViewModel/Extensions/Reader+Annotation.swift`
  - Lines: upstream L62-L61 → fork L113-L113 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Annotations/BackendAnnotationBridge.swift`
  - Contract: Preserve original Annotation schema; isolate backend locator bridge
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 8/8**: `Source/Features/Reader/ViewModel/Extensions/Reader+Annotation.swift`
  - Lines: upstream L65-L64 → fork L117-L141 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Annotations/BackendAnnotationBridge.swift`
  - Contract: Preserve original Annotation schema; isolate backend locator bridge
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Reader/ViewModel/Extensions/Reader+Content.swift`

- **Hunk 1/5**: `Source/Features/Reader/ViewModel/Extensions/Reader+Content.swift`
  - Lines: upstream L7-L6 → fork L7-L7 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Annotations/BackendAnnotationBridge.swift`
  - Contract: Preserve original Annotation schema; isolate backend locator bridge
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/5**: `Source/Features/Reader/ViewModel/Extensions/Reader+Content.swift`
  - Lines: upstream L14-L13 → fork L15-L19 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Annotations/BackendAnnotationBridge.swift`
  - Contract: Preserve original Annotation schema; isolate backend locator bridge
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/5**: `Source/Features/Reader/ViewModel/Extensions/Reader+Content.swift`
  - Lines: upstream L21-L21 → fork L27-L26 (`delete`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Annotations/BackendAnnotationBridge.swift`
  - Contract: Preserve original Annotation schema; isolate backend locator bridge
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/5**: `Source/Features/Reader/ViewModel/Extensions/Reader+Content.swift`
  - Lines: upstream L34-L33 → fork L39-L163 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Annotations/BackendAnnotationBridge.swift`
  - Contract: Preserve original Annotation schema; isolate backend locator bridge
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/5**: `Source/Features/Reader/ViewModel/Extensions/Reader+Content.swift`
  - Lines: upstream L80-L79 → fork L210-L243 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Annotations/BackendAnnotationBridge.swift`
  - Contract: Preserve original Annotation schema; isolate backend locator bridge
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Reader/ViewModel/Extensions/Reader+Navigation.swift`

- **Hunk 1/5**: `Source/Features/Reader/ViewModel/Extensions/Reader+Navigation.swift`
  - Lines: upstream L57-L56 → fork L57-L57 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/5**: `Source/Features/Reader/ViewModel/Extensions/Reader+Navigation.swift`
  - Lines: upstream L62-L62 → fork L63-L63 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/5**: `Source/Features/Reader/ViewModel/Extensions/Reader+Navigation.swift`
  - Lines: upstream L65-L66 → fork L66-L67 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/5**: `Source/Features/Reader/ViewModel/Extensions/Reader+Navigation.swift`
  - Lines: upstream L84-L85 → fork L85-L86 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/5**: `Source/Features/Reader/ViewModel/Extensions/Reader+Navigation.swift`
  - Lines: upstream L102-L102 → fork L103-L103 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Reader/ViewModel/Extensions/Reader+iOS.swift`

- **Hunk 1/6**: `Source/Features/Reader/ViewModel/Extensions/Reader+iOS.swift`
  - Lines: upstream L20-L19 → fork L20-L41 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/6**: `Source/Features/Reader/ViewModel/Extensions/Reader+iOS.swift`
  - Lines: upstream L27-L29 → fork L49-L49 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/6**: `Source/Features/Reader/ViewModel/Extensions/Reader+iOS.swift`
  - Lines: upstream L33-L32 → fork L53-L57 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/6**: `Source/Features/Reader/ViewModel/Extensions/Reader+iOS.swift`
  - Lines: upstream L40-L41 → fork L65-L85 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/6**: `Source/Features/Reader/ViewModel/Extensions/Reader+iOS.swift`
  - Lines: upstream L45-L44 → fork L89-L104 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/6**: `Source/Features/Reader/ViewModel/Extensions/Reader+iOS.swift`
  - Lines: upstream L46-L45 → fork L106-L106 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Reader/ViewModel/ReaderViewModel.swift`

- **Hunk 1/24**: `Source/Features/Reader/ViewModel/ReaderViewModel.swift`
  - Lines: upstream L22-L21 → fork L22-L22 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/24**: `Source/Features/Reader/ViewModel/ReaderViewModel.swift`
  - Lines: upstream L32-L33 → fork L33-L32 (`delete`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/24**: `Source/Features/Reader/ViewModel/ReaderViewModel.swift`
  - Lines: upstream L49-L48 → fork L48-L105 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/24**: `Source/Features/Reader/ViewModel/ReaderViewModel.swift`
  - Lines: upstream L55-L55 → fork L112-L111 (`delete`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/24**: `Source/Features/Reader/ViewModel/ReaderViewModel.swift`
  - Lines: upstream L57-L57 → fork L113-L112 (`delete`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/24**: `Source/Features/Reader/ViewModel/ReaderViewModel.swift`
  - Lines: upstream L59-L59 → fork L114-L113 (`delete`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/24**: `Source/Features/Reader/ViewModel/ReaderViewModel.swift`
  - Lines: upstream L61-L61 → fork L115-L114 (`delete`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 8/24**: `Source/Features/Reader/ViewModel/ReaderViewModel.swift`
  - Lines: upstream L63-L63 → fork L116-L115 (`delete`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 9/24**: `Source/Features/Reader/ViewModel/ReaderViewModel.swift`
  - Lines: upstream L65-L65 → fork L117-L116 (`delete`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 10/24**: `Source/Features/Reader/ViewModel/ReaderViewModel.swift`
  - Lines: upstream L78-L77 → fork L129-L129 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 11/24**: `Source/Features/Reader/ViewModel/ReaderViewModel.swift`
  - Lines: upstream L110-L110 → fork L162-L161 (`delete`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 12/24**: `Source/Features/Reader/ViewModel/ReaderViewModel.swift`
  - Lines: upstream L115-L115 → fork L166-L165 (`delete`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 13/24**: `Source/Features/Reader/ViewModel/ReaderViewModel.swift`
  - Lines: upstream L117-L116 → fork L167-L175 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 14/24**: `Source/Features/Reader/ViewModel/ReaderViewModel.swift`
  - Lines: upstream L118-L118 → fork L177-L177 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 15/24**: `Source/Features/Reader/ViewModel/ReaderViewModel.swift`
  - Lines: upstream L120-L121 → fork L179-L180 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 16/24**: `Source/Features/Reader/ViewModel/ReaderViewModel.swift`
  - Lines: upstream L123-L123 → fork L182-L182 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 17/24**: `Source/Features/Reader/ViewModel/ReaderViewModel.swift`
  - Lines: upstream L126-L126 → fork L185-L185 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 18/24**: `Source/Features/Reader/ViewModel/ReaderViewModel.swift`
  - Lines: upstream L172-L171 → fork L231-L231 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 19/24**: `Source/Features/Reader/ViewModel/ReaderViewModel.swift`
  - Lines: upstream L201-L200 → fork L261-L261 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 20/24**: `Source/Features/Reader/ViewModel/ReaderViewModel.swift`
  - Lines: upstream L208-L207 → fork L269-L269 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 21/24**: `Source/Features/Reader/ViewModel/ReaderViewModel.swift`
  - Lines: upstream L211-L211 → fork L273-L275 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 22/24**: `Source/Features/Reader/ViewModel/ReaderViewModel.swift`
  - Lines: upstream L237-L236 → fork L301-L301 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 23/24**: `Source/Features/Reader/ViewModel/ReaderViewModel.swift`
  - Lines: upstream L240-L239 → fork L305-L307 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 24/24**: `Source/Features/Reader/ViewModel/ReaderViewModel.swift`
  - Lines: upstream L243-L242 → fork L311-L351 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Reader/iOS/Toolbar/TOCNodeRow.swift`

- **Hunk 1/4**: `Source/Features/Reader/iOS/Toolbar/TOCNodeRow.swift`
  - Lines: upstream L48-L48 → fork L48-L48 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/4**: `Source/Features/Reader/iOS/Toolbar/TOCNodeRow.swift`
  - Lines: upstream L81-L80 → fork L81-L84 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/4**: `Source/Features/Reader/iOS/Toolbar/TOCNodeRow.swift`
  - Lines: upstream L86-L86 → fork L90-L91 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/4**: `Source/Features/Reader/iOS/Toolbar/TOCNodeRow.swift`
  - Lines: upstream L91-L90 → fork L96-L96 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Reader/iOS/Toolbar/iOSBookSearchView.swift`

- **Hunk 1/6**: `Source/Features/Reader/iOS/Toolbar/iOSBookSearchView.swift`
  - Lines: upstream L12-L12 → fork L12-L12 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/6**: `Source/Features/Reader/iOS/Toolbar/iOSBookSearchView.swift`
  - Lines: upstream L18-L17 → fork L18-L21 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/6**: `Source/Features/Reader/iOS/Toolbar/iOSBookSearchView.swift`
  - Lines: upstream L26-L25 → fork L30-L34 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/6**: `Source/Features/Reader/iOS/Toolbar/iOSBookSearchView.swift`
  - Lines: upstream L30-L30 → fork L39-L39 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/6**: `Source/Features/Reader/iOS/Toolbar/iOSBookSearchView.swift`
  - Lines: upstream L44-L44 → fork L53-L57 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/6**: `Source/Features/Reader/iOS/Toolbar/iOSBookSearchView.swift`
  - Lines: upstream L93-L93 → fork L106-L106 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Reader/iOS/Toolbar/iOSReaderBottomToolbarView.swift`

- **Hunk 1/9**: `Source/Features/Reader/iOS/Toolbar/iOSReaderBottomToolbarView.swift`
  - Lines: upstream L12-L11 → fork L12-L13 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/9**: `Source/Features/Reader/iOS/Toolbar/iOSReaderBottomToolbarView.swift`
  - Lines: upstream L62-L61 → fork L64-L73 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/9**: `Source/Features/Reader/iOS/Toolbar/iOSReaderBottomToolbarView.swift`
  - Lines: upstream L74-L75 → fork L86-L91 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/9**: `Source/Features/Reader/iOS/Toolbar/iOSReaderBottomToolbarView.swift`
  - Lines: upstream L80-L80 → fork L96-L101 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/9**: `Source/Features/Reader/iOS/Toolbar/iOSReaderBottomToolbarView.swift`
  - Lines: upstream L92-L91 → fork L113-L132 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/9**: `Source/Features/Reader/iOS/Toolbar/iOSReaderBottomToolbarView.swift`
  - Lines: upstream L95-L94 → fork L136-L137 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/9**: `Source/Features/Reader/iOS/Toolbar/iOSReaderBottomToolbarView.swift`
  - Lines: upstream L96-L96 → fork L139-L139 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 8/9**: `Source/Features/Reader/iOS/Toolbar/iOSReaderBottomToolbarView.swift`
  - Lines: upstream L107-L108 → fork L150-L151 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 9/9**: `Source/Features/Reader/iOS/Toolbar/iOSReaderBottomToolbarView.swift`
  - Lines: upstream L115-L115 → fork L158-L161 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Reader/iOS/Toolbar/iOSReaderNavigationPopoverView.swift`

- **Hunk 1/14**: `Source/Features/Reader/iOS/Toolbar/iOSReaderNavigationPopoverView.swift`
  - Lines: upstream L18-L17 → fork L18-L18 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/14**: `Source/Features/Reader/iOS/Toolbar/iOSReaderNavigationPopoverView.swift`
  - Lines: upstream L20-L19 → fork L21-L21 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/14**: `Source/Features/Reader/iOS/Toolbar/iOSReaderNavigationPopoverView.swift`
  - Lines: upstream L23-L22 → fork L25-L29 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/14**: `Source/Features/Reader/iOS/Toolbar/iOSReaderNavigationPopoverView.swift`
  - Lines: upstream L26-L29 → fork L33-L140 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/14**: `Source/Features/Reader/iOS/Toolbar/iOSReaderNavigationPopoverView.swift`
  - Lines: upstream L32-L36 → fork L143-L147 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/14**: `Source/Features/Reader/iOS/Toolbar/iOSReaderNavigationPopoverView.swift`
  - Lines: upstream L38-L39 → fork L149-L150 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/14**: `Source/Features/Reader/iOS/Toolbar/iOSReaderNavigationPopoverView.swift`
  - Lines: upstream L43-L50 → fork L154-L164 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 8/14**: `Source/Features/Reader/iOS/Toolbar/iOSReaderNavigationPopoverView.swift`
  - Lines: upstream L52-L52 → fork L166-L165 (`delete`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 9/14**: `Source/Features/Reader/iOS/Toolbar/iOSReaderNavigationPopoverView.swift`
  - Lines: upstream L54-L54 → fork L167-L167 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 10/14**: `Source/Features/Reader/iOS/Toolbar/iOSReaderNavigationPopoverView.swift`
  - Lines: upstream L57-L56 → fork L170-L170 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 11/14**: `Source/Features/Reader/iOS/Toolbar/iOSReaderNavigationPopoverView.swift`
  - Lines: upstream L58-L57 → fork L172-L172 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 12/14**: `Source/Features/Reader/iOS/Toolbar/iOSReaderNavigationPopoverView.swift`
  - Lines: upstream L59-L103 → fork L174-L173 (`delete`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 13/14**: `Source/Features/Reader/iOS/Toolbar/iOSReaderNavigationPopoverView.swift`
  - Lines: upstream L114-L113 → fork L184-L186 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 14/14**: `Source/Features/Reader/iOS/Toolbar/iOSReaderNavigationPopoverView.swift`
  - Lines: upstream L151-L150 → fork L224-L239 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Reader/iOS/Toolbar/iOSReaderTabsPopoverView.swift`

- **Hunk 1/1**: `Source/Features/Reader/iOS/Toolbar/iOSReaderTabsPopoverView.swift`
  - Lines: upstream L43-L43 → fork L43-L43 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift`

- **Hunk 1/9**: `Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift`
  - Lines: upstream L14-L13 → fork L14-L16 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/9**: `Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift`
  - Lines: upstream L20-L20 → fork L23-L30 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/9**: `Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift`
  - Lines: upstream L23-L22 → fork L33-L35 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/9**: `Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift`
  - Lines: upstream L24-L23 → fork L37-L54 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/9**: `Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift`
  - Lines: upstream L51-L60 → fork L82-L109 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/9**: `Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift`
  - Lines: upstream L62-L61 → fork L111-L114 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/9**: `Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift`
  - Lines: upstream L63-L68 → fork L116-L174 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 8/9**: `Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift`
  - Lines: upstream L72-L77 → fork L178-L177 (`delete`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 9/9**: `Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift`
  - Lines: upstream L80-L79 → fork L180-L181 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Reader/iOS/ViewOptionsView.swift`

- **Hunk 1/4**: `Source/Features/Reader/iOS/ViewOptionsView.swift`
  - Lines: upstream L6-L5 → fork L6-L7 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/4**: `Source/Features/Reader/iOS/ViewOptionsView.swift`
  - Lines: upstream L56-L55 → fork L58-L78 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/4**: `Source/Features/Reader/iOS/ViewOptionsView.swift`
  - Lines: upstream L62-L62 → fork L85-L84 (`delete`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/4**: `Source/Features/Reader/iOS/ViewOptionsView.swift`
  - Lines: upstream L120-L119 → fork L142-L148 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift`

- **Hunk 1/20**: `Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift`
  - Lines: upstream L7-L8 → fork L7-L8 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/20**: `Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift`
  - Lines: upstream L14-L13 → fork L14-L16 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/20**: `Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift`
  - Lines: upstream L49-L50 → fork L52-L90 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/20**: `Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift`
  - Lines: upstream L100-L100 → fork L140-L139 (`delete`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/20**: `Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift`
  - Lines: upstream L104-L104 → fork L143-L143 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/20**: `Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift`
  - Lines: upstream L123-L122 → fork L162-L174 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/20**: `Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift`
  - Lines: upstream L128-L127 → fork L180-L181 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 8/20**: `Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift`
  - Lines: upstream L131-L130 → fork L185-L186 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 9/20**: `Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift`
  - Lines: upstream L138-L137 → fork L194-L213 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 10/20**: `Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift`
  - Lines: upstream L143-L142 → fork L219-L221 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 11/20**: `Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift`
  - Lines: upstream L144-L144 → fork L223-L238 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 12/20**: `Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift`
  - Lines: upstream L159-L160 → fork L253-L409 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 13/20**: `Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift`
  - Lines: upstream L166-L165 → fork L415-L415 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 14/20**: `Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift`
  - Lines: upstream L171-L172 → fork L421-L426 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 15/20**: `Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift`
  - Lines: upstream L179-L178 → fork L433-L441 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 16/20**: `Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift`
  - Lines: upstream L180-L179 → fork L443-L449 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 17/20**: `Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift`
  - Lines: upstream L183-L186 → fork L453-L465 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 18/20**: `Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift`
  - Lines: upstream L198-L198 → fork L477-L477 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 19/20**: `Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift`
  - Lines: upstream L206-L206 → fork L485-L485 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 20/20**: `Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift`
  - Lines: upstream L208-L207 → fork L487-L495 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Reader/iOS/iOSBookInfoView.swift`

- **Hunk 1/13**: `Source/Features/Reader/iOS/iOSBookInfoView.swift`
  - Lines: upstream L28-L27 → fork L28-L29 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/13**: `Source/Features/Reader/iOS/iOSBookInfoView.swift`
  - Lines: upstream L33-L32 → fork L35-L38 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/13**: `Source/Features/Reader/iOS/iOSBookInfoView.swift`
  - Lines: upstream L34-L33 → fork L40-L48 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/13**: `Source/Features/Reader/iOS/iOSBookInfoView.swift`
  - Lines: upstream L55-L57 → fork L70-L74 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/13**: `Source/Features/Reader/iOS/iOSBookInfoView.swift`
  - Lines: upstream L59-L58 → fork L76-L87 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/13**: `Source/Features/Reader/iOS/iOSBookInfoView.swift`
  - Lines: upstream L60-L62 → fork L89-L88 (`delete`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/13**: `Source/Features/Reader/iOS/iOSBookInfoView.swift`
  - Lines: upstream L67-L67 → fork L93-L99 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 8/13**: `Source/Features/Reader/iOS/iOSBookInfoView.swift`
  - Lines: upstream L74-L74 → fork L106-L109 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 9/13**: `Source/Features/Reader/iOS/iOSBookInfoView.swift`
  - Lines: upstream L77-L77 → fork L112-L114 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 10/13**: `Source/Features/Reader/iOS/iOSBookInfoView.swift`
  - Lines: upstream L95-L97 → fork L132-L144 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 11/13**: `Source/Features/Reader/iOS/iOSBookInfoView.swift`
  - Lines: upstream L99-L101 → fork L146-L151 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 12/13**: `Source/Features/Reader/iOS/iOSBookInfoView.swift`
  - Lines: upstream L107-L107 → fork L157-L157 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 13/13**: `Source/Features/Reader/iOS/iOSBookInfoView.swift`
  - Lines: upstream L110-L110 → fork L160-L160 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Reader/iOS/iOSReaderTabView.swift`

- **Hunk 1/8**: `Source/Features/Reader/iOS/iOSReaderTabView.swift`
  - Lines: upstream L6-L6 → fork L6-L7 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/8**: `Source/Features/Reader/iOS/iOSReaderTabView.swift`
  - Lines: upstream L8-L9 → fork L9-L14 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/8**: `Source/Features/Reader/iOS/iOSReaderTabView.swift`
  - Lines: upstream L12-L12 → fork L17-L21 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/8**: `Source/Features/Reader/iOS/iOSReaderTabView.swift`
  - Lines: upstream L18-L21 → fork L27-L28 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/8**: `Source/Features/Reader/iOS/iOSReaderTabView.swift`
  - Lines: upstream L24-L24 → fork L31-L33 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/8**: `Source/Features/Reader/iOS/iOSReaderTabView.swift`
  - Lines: upstream L27-L26 → fork L36-L46 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/8**: `Source/Features/Reader/iOS/iOSReaderTabView.swift`
  - Lines: upstream L40-L52 → fork L60-L59 (`delete`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 8/8**: `Source/Features/Reader/iOS/iOSReaderTabView.swift`
  - Lines: upstream L55-L70 → fork L62-L61 (`delete`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Reader/iOS/iOSReaderView.swift`

- **Hunk 1/22**: `Source/Features/Reader/iOS/iOSReaderView.swift`
  - Lines: upstream L1-L0 → fork L1-L7 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderHost/iOSReaderHostView.swift`
  - Contract: Move custom inspector/tab toolbar to fork-owned reader host
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/22**: `Source/Features/Reader/iOS/iOSReaderView.swift`
  - Lines: upstream L6-L5 → fork L13-L15 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderHost/iOSReaderHostView.swift`
  - Contract: Move custom inspector/tab toolbar to fork-owned reader host
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/22**: `Source/Features/Reader/iOS/iOSReaderView.swift`
  - Lines: upstream L15-L14 → fork L25-L28 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderHost/iOSReaderHostView.swift`
  - Contract: Move custom inspector/tab toolbar to fork-owned reader host
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/22**: `Source/Features/Reader/iOS/iOSReaderView.swift`
  - Lines: upstream L18-L17 → fork L32-L32 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderHost/iOSReaderHostView.swift`
  - Contract: Move custom inspector/tab toolbar to fork-owned reader host
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/22**: `Source/Features/Reader/iOS/iOSReaderView.swift`
  - Lines: upstream L19-L22 → fork L34-L40 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderHost/iOSReaderHostView.swift`
  - Contract: Move custom inspector/tab toolbar to fork-owned reader host
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/22**: `Source/Features/Reader/iOS/iOSReaderView.swift`
  - Lines: upstream L25-L24 → fork L43-L44 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderHost/iOSReaderHostView.swift`
  - Contract: Move custom inspector/tab toolbar to fork-owned reader host
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/22**: `Source/Features/Reader/iOS/iOSReaderView.swift`
  - Lines: upstream L26-L25 → fork L46-L91 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderHost/iOSReaderHostView.swift`
  - Contract: Move custom inspector/tab toolbar to fork-owned reader host
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 8/22**: `Source/Features/Reader/iOS/iOSReaderView.swift`
  - Lines: upstream L52-L51 → fork L118-L118 (`insert`)
  - Category: `UPSTREAM_RESTORE` | Rigor: `manual` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderHost/iOSTabBarVisibilityHost.swift`
  - Contract: Remove conflicting upstream .toolbar(.hidden, for: .tabBar) at line 119; apply fork host policy (BUG-01 manual audit)
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 9/22**: `Source/Features/Reader/iOS/iOSReaderView.swift`
  - Lines: upstream L53-L52 → fork L120-L130 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderHost/iOSReaderHostView.swift`
  - Contract: Move custom inspector/tab toolbar to fork-owned reader host
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 10/22**: `Source/Features/Reader/iOS/iOSReaderView.swift`
  - Lines: upstream L54-L54 → fork L132-L146 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderHost/iOSReaderHostView.swift`
  - Contract: Move custom inspector/tab toolbar to fork-owned reader host
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 11/22**: `Source/Features/Reader/iOS/iOSReaderView.swift`
  - Lines: upstream L64-L65 → fork L156-L155 (`delete`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderHost/iOSReaderHostView.swift`
  - Contract: Move custom inspector/tab toolbar to fork-owned reader host
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 12/22**: `Source/Features/Reader/iOS/iOSReaderView.swift`
  - Lines: upstream L72-L72 → fork L162-L162 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderHost/iOSReaderHostView.swift`
  - Contract: Move custom inspector/tab toolbar to fork-owned reader host
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 13/22**: `Source/Features/Reader/iOS/iOSReaderView.swift`
  - Lines: upstream L74-L74 → fork L164-L164 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderHost/iOSReaderHostView.swift`
  - Contract: Move custom inspector/tab toolbar to fork-owned reader host
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 14/22**: `Source/Features/Reader/iOS/iOSReaderView.swift`
  - Lines: upstream L79-L78 → fork L169-L173 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderHost/iOSReaderHostView.swift`
  - Contract: Move custom inspector/tab toolbar to fork-owned reader host
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 15/22**: `Source/Features/Reader/iOS/iOSReaderView.swift`
  - Lines: upstream L82-L82 → fork L177-L181 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderHost/iOSReaderHostView.swift`
  - Contract: Move custom inspector/tab toolbar to fork-owned reader host
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 16/22**: `Source/Features/Reader/iOS/iOSReaderView.swift`
  - Lines: upstream L87-L87 → fork L186-L186 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderHost/iOSReaderHostView.swift`
  - Contract: Move custom inspector/tab toolbar to fork-owned reader host
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 17/22**: `Source/Features/Reader/iOS/iOSReaderView.swift`
  - Lines: upstream L95-L97 → fork L194-L193 (`delete`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderHost/iOSReaderHostView.swift`
  - Contract: Move custom inspector/tab toolbar to fork-owned reader host
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 18/22**: `Source/Features/Reader/iOS/iOSReaderView.swift`
  - Lines: upstream L107-L112 → fork L203-L205 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderHost/iOSReaderHostView.swift`
  - Contract: Move custom inspector/tab toolbar to fork-owned reader host
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 19/22**: `Source/Features/Reader/iOS/iOSReaderView.swift`
  - Lines: upstream L115-L120 → fork L208-L210 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderHost/iOSReaderHostView.swift`
  - Contract: Move custom inspector/tab toolbar to fork-owned reader host
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 20/22**: `Source/Features/Reader/iOS/iOSReaderView.swift`
  - Lines: upstream L147-L148 → fork L237-L240 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderHost/iOSReaderHostView.swift`
  - Contract: Move custom inspector/tab toolbar to fork-owned reader host
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 21/22**: `Source/Features/Reader/iOS/iOSReaderView.swift`
  - Lines: upstream L162-L161 → fork L254-L259 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderHost/iOSReaderHostView.swift`
  - Contract: Move custom inspector/tab toolbar to fork-owned reader host
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 22/22**: `Source/Features/Reader/iOS/iOSReaderView.swift`
  - Lines: upstream L183-L182 → fork L281-L282 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderHost/iOSReaderHostView.swift`
  - Contract: Move custom inspector/tab toolbar to fork-owned reader host
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift`

- **Hunk 1/22**: `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift`
  - Lines: upstream L10-L9 → fork L10-L26 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/ReaderPullNavigationStateMachine.swift + ReaderSelectionRangeMapper.swift`
  - Contract: Preserve native UITextView wrapper; extract pull state machine and range mapper
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/22**: `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift`
  - Lines: upstream L24-L24 → fork L41-L40 (`delete`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/ReaderPullNavigationStateMachine.swift + ReaderSelectionRangeMapper.swift`
  - Contract: Preserve native UITextView wrapper; extract pull state machine and range mapper
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/22**: `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift`
  - Lines: upstream L43-L42 → fork L59-L156 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/ReaderPullNavigationStateMachine.swift + ReaderSelectionRangeMapper.swift`
  - Contract: Preserve native UITextView wrapper; extract pull state machine and range mapper
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/22**: `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift`
  - Lines: upstream L70-L75 → fork L184-L184 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/ReaderPullNavigationStateMachine.swift + ReaderSelectionRangeMapper.swift`
  - Contract: Preserve native UITextView wrapper; extract pull state machine and range mapper
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/22**: `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift`
  - Lines: upstream L274-L274 → fork L383-L383 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/ReaderPullNavigationStateMachine.swift + ReaderSelectionRangeMapper.swift`
  - Contract: Preserve native UITextView wrapper; extract pull state machine and range mapper
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/22**: `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift`
  - Lines: upstream L359-L358 → fork L468-L535 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/ReaderPullNavigationStateMachine.swift + ReaderSelectionRangeMapper.swift`
  - Contract: Preserve native UITextView wrapper; extract pull state machine and range mapper
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/22**: `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift`
  - Lines: upstream L363-L364 → fork L540-L543 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/ReaderPullNavigationStateMachine.swift + ReaderSelectionRangeMapper.swift`
  - Contract: Preserve native UITextView wrapper; extract pull state machine and range mapper
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 8/22**: `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift`
  - Lines: upstream L374-L373 → fork L553-L554 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/ReaderPullNavigationStateMachine.swift + ReaderSelectionRangeMapper.swift`
  - Contract: Preserve native UITextView wrapper; extract pull state machine and range mapper
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 9/22**: `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift`
  - Lines: upstream L390-L389 → fork L571-L571 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/ReaderPullNavigationStateMachine.swift + ReaderSelectionRangeMapper.swift`
  - Contract: Preserve native UITextView wrapper; extract pull state machine and range mapper
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 10/22**: `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift`
  - Lines: upstream L393-L392 → fork L575-L586 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/ReaderPullNavigationStateMachine.swift + ReaderSelectionRangeMapper.swift`
  - Contract: Preserve native UITextView wrapper; extract pull state machine and range mapper
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 11/22**: `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift`
  - Lines: upstream L447-L447 → fork L641-L658 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/ReaderPullNavigationStateMachine.swift + ReaderSelectionRangeMapper.swift`
  - Contract: Preserve native UITextView wrapper; extract pull state machine and range mapper
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 12/22**: `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift`
  - Lines: upstream L595-L595 → fork L806-L808 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/ReaderPullNavigationStateMachine.swift + ReaderSelectionRangeMapper.swift`
  - Contract: Preserve native UITextView wrapper; extract pull state machine and range mapper
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 13/22**: `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift`
  - Lines: upstream L615-L614 → fork L828-L849 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/ReaderPullNavigationStateMachine.swift + ReaderSelectionRangeMapper.swift`
  - Contract: Preserve native UITextView wrapper; extract pull state machine and range mapper
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 14/22**: `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift`
  - Lines: upstream L668-L667 → fork L903-L910 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/ReaderPullNavigationStateMachine.swift + ReaderSelectionRangeMapper.swift`
  - Contract: Preserve native UITextView wrapper; extract pull state machine and range mapper
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 15/22**: `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift`
  - Lines: upstream L696-L695 → fork L939-L947 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/ReaderPullNavigationStateMachine.swift + ReaderSelectionRangeMapper.swift`
  - Contract: Preserve native UITextView wrapper; extract pull state machine and range mapper
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 16/22**: `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift`
  - Lines: upstream L699-L699 → fork L951-L966 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/ReaderPullNavigationStateMachine.swift + ReaderSelectionRangeMapper.swift`
  - Contract: Preserve native UITextView wrapper; extract pull state machine and range mapper
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 17/22**: `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift`
  - Lines: upstream L711-L710 → fork L978-L980 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/ReaderPullNavigationStateMachine.swift + ReaderSelectionRangeMapper.swift`
  - Contract: Preserve native UITextView wrapper; extract pull state machine and range mapper
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 18/22**: `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift`
  - Lines: upstream L728-L727 → fork L998-L1060 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/ReaderPullNavigationStateMachine.swift + ReaderSelectionRangeMapper.swift`
  - Contract: Preserve native UITextView wrapper; extract pull state machine and range mapper
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 19/22**: `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift`
  - Lines: upstream L729-L728 → fork L1062-L1066 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/ReaderPullNavigationStateMachine.swift + ReaderSelectionRangeMapper.swift`
  - Contract: Preserve native UITextView wrapper; extract pull state machine and range mapper
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 20/22**: `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift`
  - Lines: upstream L735-L734 → fork L1073-L1083 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/ReaderPullNavigationStateMachine.swift + ReaderSelectionRangeMapper.swift`
  - Contract: Preserve native UITextView wrapper; extract pull state machine and range mapper
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 21/22**: `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift`
  - Lines: upstream L826-L825 → fork L1175-L1175 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/ReaderPullNavigationStateMachine.swift + ReaderSelectionRangeMapper.swift`
  - Contract: Preserve native UITextView wrapper; extract pull state machine and range mapper
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 22/22**: `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift`
  - Lines: upstream L843-L842 → fork L1193-L1193 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/ReaderRendering/ReaderPullNavigationStateMachine.swift + ReaderSelectionRangeMapper.swift`
  - Contract: Preserve native UITextView wrapper; extract pull state machine and range mapper
  - Approval: `LEGACY_UNREVIEWED`

### Workstream Area: Upstream Search (98 hunks)

#### `Source/Core/SearchEngine/SearchMode.swift`

- **Hunk 1/2**: `Source/Core/SearchEngine/SearchMode.swift`
  - Lines: upstream L10-L10 → fork L10-L10 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/2**: `Source/Core/SearchEngine/SearchMode.swift`
  - Lines: upstream L26-L25 → fork L26-L34 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Search/Models/CopyableResult.swift`

- **Hunk 1/2**: `Source/Features/Search/Models/CopyableResult.swift`
  - Lines: upstream L25-L28 → fork L25-L32 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve TextLocator search result payload schema
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/2**: `Source/Features/Search/Models/CopyableResult.swift`
  - Lines: upstream L30-L30 → fork L34-L43 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve TextLocator search result payload schema
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Search/Models/SearchResultItem.swift`

- **Hunk 1/9**: `Source/Features/Search/Models/SearchResultItem.swift`
  - Lines: upstream L25-L24 → fork L25-L29 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve TextLocator search result payload schema
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/9**: `Source/Features/Search/Models/SearchResultItem.swift`
  - Lines: upstream L35-L36 → fork L40-L53 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve TextLocator search result payload schema
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/9**: `Source/Features/Search/Models/SearchResultItem.swift`
  - Lines: upstream L46-L45 → fork L63-L67 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve TextLocator search result payload schema
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/9**: `Source/Features/Search/Models/SearchResultItem.swift`
  - Lines: upstream L55-L55 → fork L77-L82 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve TextLocator search result payload schema
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/9**: `Source/Features/Search/Models/SearchResultItem.swift`
  - Lines: upstream L63-L62 → fork L90-L94 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve TextLocator search result payload schema
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/9**: `Source/Features/Search/Models/SearchResultItem.swift`
  - Lines: upstream L75-L74 → fork L107-L112 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve TextLocator search result payload schema
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/9**: `Source/Features/Search/Models/SearchResultItem.swift`
  - Lines: upstream L89-L88 → fork L127-L131 (`insert`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve TextLocator search result payload schema
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 8/9**: `Source/Features/Search/Models/SearchResultItem.swift`
  - Lines: upstream L98-L100 → fork L141-L141 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve TextLocator search result payload schema
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 9/9**: `Source/Features/Search/Models/SearchResultItem.swift`
  - Lines: upstream L104-L106 → fork L145-L168 (`replace`)
  - Category: `VENDOR_OR_SHARED_SEAM` | Rigor: `rules_based` | State: `PRESERVED_SEAM`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve TextLocator search result payload schema
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Search/ViewModel/Extensions/Search+Execution.swift`

- **Hunk 1/5**: `Source/Features/Search/ViewModel/Extensions/Search+Execution.swift`
  - Lines: upstream L9-L8 → fork L9-L73 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/5**: `Source/Features/Search/ViewModel/Extensions/Search+Execution.swift`
  - Lines: upstream L42-L41 → fork L107-L164 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/5**: `Source/Features/Search/ViewModel/Extensions/Search+Execution.swift`
  - Lines: upstream L93-L92 → fork L216-L220 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/5**: `Source/Features/Search/ViewModel/Extensions/Search+Execution.swift`
  - Lines: upstream L94-L93 → fork L222-L222 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/5**: `Source/Features/Search/ViewModel/Extensions/Search+Execution.swift`
  - Lines: upstream L101-L100 → fork L230-L233 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Search/ViewModel/Extensions/Search+Library.swift`

- **Hunk 1/2**: `Source/Features/Search/ViewModel/Extensions/Search+Library.swift`
  - Lines: upstream L34-L33 → fork L34-L34 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/2**: `Source/Features/Search/ViewModel/Extensions/Search+Library.swift`
  - Lines: upstream L35-L39 → fork L36-L42 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Search/ViewModel/Extensions/Search+Observers.swift`

- **Hunk 1/1**: `Source/Features/Search/ViewModel/Extensions/Search+Observers.swift`
  - Lines: upstream L55-L54 → fork L55-L83 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Search/ViewModel/Extensions/Search+iOS.swift`

- **Hunk 1/1**: `Source/Features/Search/ViewModel/Extensions/Search+iOS.swift`
  - Lines: upstream L22-L24 → fork L22-L29 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Search/ViewModel/SearchViewModel.swift`

- **Hunk 1/1**: `Source/Features/Search/ViewModel/SearchViewModel.swift`
  - Lines: upstream L36-L35 → fork L36-L50 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Search/iOS/SearchComponents.swift`

- **Hunk 1/24**: `Source/Features/Search/iOS/SearchComponents.swift`
  - Lines: upstream L8-L7 → fork L8-L8 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/24**: `Source/Features/Search/iOS/SearchComponents.swift`
  - Lines: upstream L18-L18 → fork L19-L20 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/24**: `Source/Features/Search/iOS/SearchComponents.swift`
  - Lines: upstream L20-L20 → fork L22-L26 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/24**: `Source/Features/Search/iOS/SearchComponents.swift`
  - Lines: upstream L86-L87 → fork L92-L93 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/24**: `Source/Features/Search/iOS/SearchComponents.swift`
  - Lines: upstream L89-L89 → fork L95-L95 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/24**: `Source/Features/Search/iOS/SearchComponents.swift`
  - Lines: upstream L91-L90 → fork L97-L103 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/24**: `Source/Features/Search/iOS/SearchComponents.swift`
  - Lines: upstream L109-L109 → fork L122-L122 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 8/24**: `Source/Features/Search/iOS/SearchComponents.swift`
  - Lines: upstream L122-L121 → fork L135-L135 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 9/24**: `Source/Features/Search/iOS/SearchComponents.swift`
  - Lines: upstream L123-L122 → fork L137-L142 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 10/24**: `Source/Features/Search/iOS/SearchComponents.swift`
  - Lines: upstream L162-L161 → fork L182-L182 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 11/24**: `Source/Features/Search/iOS/SearchComponents.swift`
  - Lines: upstream L175-L174 → fork L196-L308 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 12/24**: `Source/Features/Search/iOS/SearchComponents.swift`
  - Lines: upstream L178-L178 → fork L312-L312 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 13/24**: `Source/Features/Search/iOS/SearchComponents.swift`
  - Lines: upstream L183-L182 → fork L317-L336 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 14/24**: `Source/Features/Search/iOS/SearchComponents.swift`
  - Lines: upstream L185-L185 → fork L339-L339 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 15/24**: `Source/Features/Search/iOS/SearchComponents.swift`
  - Lines: upstream L222-L221 → fork L376-L377 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 16/24**: `Source/Features/Search/iOS/SearchComponents.swift`
  - Lines: upstream L224-L225 → fork L380-L381 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 17/24**: `Source/Features/Search/iOS/SearchComponents.swift`
  - Lines: upstream L229-L234 → fork L385-L386 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 18/24**: `Source/Features/Search/iOS/SearchComponents.swift`
  - Lines: upstream L237-L244 → fork L389-L390 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 19/24**: `Source/Features/Search/iOS/SearchComponents.swift`
  - Lines: upstream L247-L264 → fork L393-L394 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 20/24**: `Source/Features/Search/iOS/SearchComponents.swift`
  - Lines: upstream L268-L267 → fork L398-L477 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 21/24**: `Source/Features/Search/iOS/SearchComponents.swift`
  - Lines: upstream L306-L306 → fork L516-L516 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 22/24**: `Source/Features/Search/iOS/SearchComponents.swift`
  - Lines: upstream L339-L338 → fork L549-L549 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 23/24**: `Source/Features/Search/iOS/SearchComponents.swift`
  - Lines: upstream L416-L416 → fork L627-L627 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 24/24**: `Source/Features/Search/iOS/SearchComponents.swift`
  - Lines: upstream L492-L491 → fork L703-L992 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Search/iOS/SearchModeView.swift`

- **Hunk 1/23**: `Source/Features/Search/iOS/SearchModeView.swift`
  - Lines: upstream L9-L12 → fork L9-L9 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/23**: `Source/Features/Search/iOS/SearchModeView.swift`
  - Lines: upstream L16-L15 → fork L13-L18 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/23**: `Source/Features/Search/iOS/SearchModeView.swift`
  - Lines: upstream L17-L16 → fork L20-L20 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/23**: `Source/Features/Search/iOS/SearchModeView.swift`
  - Lines: upstream L18-L22 → fork L22-L63 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/23**: `Source/Features/Search/iOS/SearchModeView.swift`
  - Lines: upstream L25-L51 → fork L66-L98 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/23**: `Source/Features/Search/iOS/SearchModeView.swift`
  - Lines: upstream L53-L59 → fork L100-L118 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/23**: `Source/Features/Search/iOS/SearchModeView.swift`
  - Lines: upstream L61-L67 → fork L120-L120 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 8/23**: `Source/Features/Search/iOS/SearchModeView.swift`
  - Lines: upstream L70-L75 → fork L123-L126 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 9/23**: `Source/Features/Search/iOS/SearchModeView.swift`
  - Lines: upstream L77-L78 → fork L128-L143 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 10/23**: `Source/Features/Search/iOS/SearchModeView.swift`
  - Lines: upstream L81-L85 → fork L146-L146 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 11/23**: `Source/Features/Search/iOS/SearchModeView.swift`
  - Lines: upstream L96-L96 → fork L157-L156 (`delete`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 12/23**: `Source/Features/Search/iOS/SearchModeView.swift`
  - Lines: upstream L100-L100 → fork L160-L161 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 13/23**: `Source/Features/Search/iOS/SearchModeView.swift`
  - Lines: upstream L105-L119 → fork L166-L173 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 14/23**: `Source/Features/Search/iOS/SearchModeView.swift`
  - Lines: upstream L121-L148 → fork L175-L187 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 15/23**: `Source/Features/Search/iOS/SearchModeView.swift`
  - Lines: upstream L151-L150 → fork L190-L191 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 16/23**: `Source/Features/Search/iOS/SearchModeView.swift`
  - Lines: upstream L153-L159 → fork L194-L197 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 17/23**: `Source/Features/Search/iOS/SearchModeView.swift`
  - Lines: upstream L162-L162 → fork L200-L202 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 18/23**: `Source/Features/Search/iOS/SearchModeView.swift`
  - Lines: upstream L164-L164 → fork L204-L203 (`delete`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 19/23**: `Source/Features/Search/iOS/SearchModeView.swift`
  - Lines: upstream L167-L170 → fork L206-L214 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 20/23**: `Source/Features/Search/iOS/SearchModeView.swift`
  - Lines: upstream L172-L172 → fork L216-L216 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 21/23**: `Source/Features/Search/iOS/SearchModeView.swift`
  - Lines: upstream L175-L175 → fork L219-L219 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 22/23**: `Source/Features/Search/iOS/SearchModeView.swift`
  - Lines: upstream L181-L201 → fork L225-L224 (`delete`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 23/23**: `Source/Features/Search/iOS/SearchModeView.swift`
  - Lines: upstream L204-L204 → fork L227-L227 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Search/iOS/SearchResultsListView.swift`

- **Hunk 1/19**: `Source/Features/Search/iOS/SearchResultsListView.swift`
  - Lines: upstream L3-L2 → fork L3-L12 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/19**: `Source/Features/Search/iOS/SearchResultsListView.swift`
  - Lines: upstream L4-L4 → fork L14-L14 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/19**: `Source/Features/Search/iOS/SearchResultsListView.swift`
  - Lines: upstream L6-L5 → fork L16-L19 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/19**: `Source/Features/Search/iOS/SearchResultsListView.swift`
  - Lines: upstream L11-L10 → fork L25-L27 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/19**: `Source/Features/Search/iOS/SearchResultsListView.swift`
  - Lines: upstream L15-L14 → fork L32-L56 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/19**: `Source/Features/Search/iOS/SearchResultsListView.swift`
  - Lines: upstream L16-L26 → fork L58-L105 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/19**: `Source/Features/Search/iOS/SearchResultsListView.swift`
  - Lines: upstream L28-L27 → fork L107-L158 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 8/19**: `Source/Features/Search/iOS/SearchResultsListView.swift`
  - Lines: upstream L34-L33 → fork L165-L166 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 9/19**: `Source/Features/Search/iOS/SearchResultsListView.swift`
  - Lines: upstream L37-L36 → fork L170-L173 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 10/19**: `Source/Features/Search/iOS/SearchResultsListView.swift`
  - Lines: upstream L42-L41 → fork L179-L209 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 11/19**: `Source/Features/Search/iOS/SearchResultsListView.swift`
  - Lines: upstream L43-L44 → fork L211-L212 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 12/19**: `Source/Features/Search/iOS/SearchResultsListView.swift`
  - Lines: upstream L47-L52 → fork L215-L216 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 13/19**: `Source/Features/Search/iOS/SearchResultsListView.swift`
  - Lines: upstream L55-L60 → fork L219-L265 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 14/19**: `Source/Features/Search/iOS/SearchResultsListView.swift`
  - Lines: upstream L64-L69 → fork L269-L274 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 15/19**: `Source/Features/Search/iOS/SearchResultsListView.swift`
  - Lines: upstream L72-L72 → fork L277-L277 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 16/19**: `Source/Features/Search/iOS/SearchResultsListView.swift`
  - Lines: upstream L92-L94 → fork L297-L298 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 17/19**: `Source/Features/Search/iOS/SearchResultsListView.swift`
  - Lines: upstream L98-L127 → fork L302-L301 (`delete`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 18/19**: `Source/Features/Search/iOS/SearchResultsListView.swift`
  - Lines: upstream L129-L129 → fork L303-L427 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 19/19**: `Source/Features/Search/iOS/SearchResultsListView.swift`
  - Lines: upstream L131-L130 → fork L429-L434 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Search/`
  - Contract: Preserve upstream SearchViewModel; route unified backend search via fork Search controllers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Search/iOS/iOSSearchFilterViewController.swift`

- **Hunk 1/8**: `Source/Features/Search/iOS/iOSSearchFilterViewController.swift`
  - Lines: upstream L11-L11 → fork L11-L11 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/8**: `Source/Features/Search/iOS/iOSSearchFilterViewController.swift`
  - Lines: upstream L28-L28 → fork L28-L28 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/8**: `Source/Features/Search/iOS/iOSSearchFilterViewController.swift`
  - Lines: upstream L31-L31 → fork L31-L31 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/8**: `Source/Features/Search/iOS/iOSSearchFilterViewController.swift`
  - Lines: upstream L113-L113 → fork L113-L114 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/8**: `Source/Features/Search/iOS/iOSSearchFilterViewController.swift`
  - Lines: upstream L115-L115 → fork L116-L116 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/8**: `Source/Features/Search/iOS/iOSSearchFilterViewController.swift`
  - Lines: upstream L117-L116 → fork L118-L121 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/8**: `Source/Features/Search/iOS/iOSSearchFilterViewController.swift`
  - Lines: upstream L136-L138 → fork L141-L141 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 8/8**: `Source/Features/Search/iOS/iOSSearchFilterViewController.swift`
  - Lines: upstream L214-L213 → fork L217-L339 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/Features/Search/macOS/OptionSearchVC.swift`

- **Hunk 1/1**: `Source/Features/Search/macOS/OptionSearchVC.swift`
  - Lines: upstream L684-L684 → fork L684-L684 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

### Workstream Area: Upstream Settings (12 hunks)

#### `Source/Features/Setting/SettingsView.swift`

- **Hunk 1/12**: `Source/Features/Setting/SettingsView.swift`
  - Lines: upstream L12-L11 → fork L12-L12 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/SettingsHostView.swift`
  - Contract: Extract multi-backend settings into fork host
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/12**: `Source/Features/Setting/SettingsView.swift`
  - Lines: upstream L26-L26 → fork L27-L29 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/SettingsHostView.swift`
  - Contract: Extract multi-backend settings into fork host
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/12**: `Source/Features/Setting/SettingsView.swift`
  - Lines: upstream L67-L69 → fork L70-L75 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/SettingsHostView.swift`
  - Contract: Extract multi-backend settings into fork host
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/12**: `Source/Features/Setting/SettingsView.swift`
  - Lines: upstream L72-L73 → fork L78-L81 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/SettingsHostView.swift`
  - Contract: Extract multi-backend settings into fork host
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/12**: `Source/Features/Setting/SettingsView.swift`
  - Lines: upstream L93-L93 → fork L101-L101 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/SettingsHostView.swift`
  - Contract: Extract multi-backend settings into fork host
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/12**: `Source/Features/Setting/SettingsView.swift`
  - Lines: upstream L95-L98 → fork L103-L110 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/SettingsHostView.swift`
  - Contract: Extract multi-backend settings into fork host
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/12**: `Source/Features/Setting/SettingsView.swift`
  - Lines: upstream L105-L104 → fork L117-L118 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/SettingsHostView.swift`
  - Contract: Extract multi-backend settings into fork host
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 8/12**: `Source/Features/Setting/SettingsView.swift`
  - Lines: upstream L106-L106 → fork L120-L121 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/SettingsHostView.swift`
  - Contract: Extract multi-backend settings into fork host
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 9/12**: `Source/Features/Setting/SettingsView.swift`
  - Lines: upstream L113-L113 → fork L128-L128 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/SettingsHostView.swift`
  - Contract: Extract multi-backend settings into fork host
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 10/12**: `Source/Features/Setting/SettingsView.swift`
  - Lines: upstream L118-L119 → fork L133-L136 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/SettingsHostView.swift`
  - Contract: Extract multi-backend settings into fork host
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 11/12**: `Source/Features/Setting/SettingsView.swift`
  - Lines: upstream L167-L166 → fork L184-L194 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/SettingsHostView.swift`
  - Contract: Extract multi-backend settings into fork host
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 12/12**: `Source/Features/Setting/SettingsView.swift`
  - Lines: upstream L197-L196 → fork L225-L263 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/SettingsHostView.swift`
  - Contract: Extract multi-backend settings into fork host
  - Approval: `LEGACY_UNREVIEWED`

### Workstream Area: iOS App Shell (138 hunks)

#### `Source/UI/iOS/MaktabahApp.swift`

- **Hunk 1/11**: `Source/UI/iOS/MaktabahApp.swift`
  - Lines: upstream L22-L21 → fork L22-L24 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/11**: `Source/UI/iOS/MaktabahApp.swift`
  - Lines: upstream L24-L23 → fork L27-L35 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/11**: `Source/UI/iOS/MaktabahApp.swift`
  - Lines: upstream L27-L28 → fork L39-L45 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/11**: `Source/UI/iOS/MaktabahApp.swift`
  - Lines: upstream L62-L76 → fork L79-L82 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/11**: `Source/UI/iOS/MaktabahApp.swift`
  - Lines: upstream L78-L87 → fork L84-L127 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/11**: `Source/UI/iOS/MaktabahApp.swift`
  - Lines: upstream L92-L92 → fork L132-L132 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/11**: `Source/UI/iOS/MaktabahApp.swift`
  - Lines: upstream L100-L100 → fork L140-L140 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 8/11**: `Source/UI/iOS/MaktabahApp.swift`
  - Lines: upstream L102-L102 → fork L142-L144 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 9/11**: `Source/UI/iOS/MaktabahApp.swift`
  - Lines: upstream L108-L109 → fork L150-L154 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 10/11**: `Source/UI/iOS/MaktabahApp.swift`
  - Lines: upstream L116-L115 → fork L161-L163 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 11/11**: `Source/UI/iOS/MaktabahApp.swift`
  - Lines: upstream L118-L117 → fork L166-L166 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/UI/iOS/Managers/BootstrapManager.swift`

- **Hunk 1/22**: `Source/UI/iOS/Managers/BootstrapManager.swift`
  - Lines: upstream L11-L10 → fork L11-L20 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/BootstrapAdapter.swift`
  - Contract: Upstream bootstrap remains native; multi-backend setup moves to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/22**: `Source/UI/iOS/Managers/BootstrapManager.swift`
  - Lines: upstream L18-L18 → fork L28-L30 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/BootstrapAdapter.swift`
  - Contract: Upstream bootstrap remains native; multi-backend setup moves to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/22**: `Source/UI/iOS/Managers/BootstrapManager.swift`
  - Lines: upstream L28-L27 → fork L40-L42 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/BootstrapAdapter.swift`
  - Contract: Upstream bootstrap remains native; multi-backend setup moves to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/22**: `Source/UI/iOS/Managers/BootstrapManager.swift`
  - Lines: upstream L30-L30 → fork L45-L62 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/BootstrapAdapter.swift`
  - Contract: Upstream bootstrap remains native; multi-backend setup moves to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/22**: `Source/UI/iOS/Managers/BootstrapManager.swift`
  - Lines: upstream L33-L32 → fork L65-L72 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/BootstrapAdapter.swift`
  - Contract: Upstream bootstrap remains native; multi-backend setup moves to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/22**: `Source/UI/iOS/Managers/BootstrapManager.swift`
  - Lines: upstream L55-L55 → fork L95-L95 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/BootstrapAdapter.swift`
  - Contract: Upstream bootstrap remains native; multi-backend setup moves to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/22**: `Source/UI/iOS/Managers/BootstrapManager.swift`
  - Lines: upstream L60-L60 → fork L100-L109 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/BootstrapAdapter.swift`
  - Contract: Upstream bootstrap remains native; multi-backend setup moves to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 8/22**: `Source/UI/iOS/Managers/BootstrapManager.swift`
  - Lines: upstream L62-L70 → fork L111-L117 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/BootstrapAdapter.swift`
  - Contract: Upstream bootstrap remains native; multi-backend setup moves to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 9/22**: `Source/UI/iOS/Managers/BootstrapManager.swift`
  - Lines: upstream L74-L73 → fork L121-L164 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/BootstrapAdapter.swift`
  - Contract: Upstream bootstrap remains native; multi-backend setup moves to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 10/22**: `Source/UI/iOS/Managers/BootstrapManager.swift`
  - Lines: upstream L75-L74 → fork L166-L169 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/BootstrapAdapter.swift`
  - Contract: Upstream bootstrap remains native; multi-backend setup moves to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 11/22**: `Source/UI/iOS/Managers/BootstrapManager.swift`
  - Lines: upstream L76-L76 → fork L171-L174 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/BootstrapAdapter.swift`
  - Contract: Upstream bootstrap remains native; multi-backend setup moves to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 12/22**: `Source/UI/iOS/Managers/BootstrapManager.swift`
  - Lines: upstream L78-L85 → fork L176-L184 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/BootstrapAdapter.swift`
  - Contract: Upstream bootstrap remains native; multi-backend setup moves to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 13/22**: `Source/UI/iOS/Managers/BootstrapManager.swift`
  - Lines: upstream L87-L87 → fork L186-L274 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/BootstrapAdapter.swift`
  - Contract: Upstream bootstrap remains native; multi-backend setup moves to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 14/22**: `Source/UI/iOS/Managers/BootstrapManager.swift`
  - Lines: upstream L90-L89 → fork L277-L368 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/BootstrapAdapter.swift`
  - Contract: Upstream bootstrap remains native; multi-backend setup moves to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 15/22**: `Source/UI/iOS/Managers/BootstrapManager.swift`
  - Lines: upstream L91-L90 → fork L370-L389 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/BootstrapAdapter.swift`
  - Contract: Upstream bootstrap remains native; multi-backend setup moves to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 16/22**: `Source/UI/iOS/Managers/BootstrapManager.swift`
  - Lines: upstream L97-L98 → fork L396-L400 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/BootstrapAdapter.swift`
  - Contract: Upstream bootstrap remains native; multi-backend setup moves to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 17/22**: `Source/UI/iOS/Managers/BootstrapManager.swift`
  - Lines: upstream L100-L99 → fork L402-L403 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/BootstrapAdapter.swift`
  - Contract: Upstream bootstrap remains native; multi-backend setup moves to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 18/22**: `Source/UI/iOS/Managers/BootstrapManager.swift`
  - Lines: upstream L103-L103 → fork L407-L410 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/BootstrapAdapter.swift`
  - Contract: Upstream bootstrap remains native; multi-backend setup moves to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 19/22**: `Source/UI/iOS/Managers/BootstrapManager.swift`
  - Lines: upstream L180-L180 → fork L487-L535 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/BootstrapAdapter.swift`
  - Contract: Upstream bootstrap remains native; multi-backend setup moves to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 20/22**: `Source/UI/iOS/Managers/BootstrapManager.swift`
  - Lines: upstream L190-L196 → fork L545-L549 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/BootstrapAdapter.swift`
  - Contract: Upstream bootstrap remains native; multi-backend setup moves to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 21/22**: `Source/UI/iOS/Managers/BootstrapManager.swift`
  - Lines: upstream L198-L197 → fork L551-L551 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/BootstrapAdapter.swift`
  - Contract: Upstream bootstrap remains native; multi-backend setup moves to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 22/22**: `Source/UI/iOS/Managers/BootstrapManager.swift`
  - Lines: upstream L200-L200 → fork L554-L554 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/BootstrapAdapter.swift`
  - Contract: Upstream bootstrap remains native; multi-backend setup moves to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/UI/iOS/Managers/iOSNavigationManager.swift`

- **Hunk 1/23**: `Source/UI/iOS/Managers/iOSNavigationManager.swift`
  - Lines: upstream L37-L36 → fork L37-L37 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Navigation/BackendNavigationAdapter.swift + ReaderSessionCoordinator.swift`
  - Contract: Preserve original navigation semantics; route multi-backend session in fork adapter
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/23**: `Source/UI/iOS/Managers/iOSNavigationManager.swift`
  - Lines: upstream L44-L43 → fork L45-L52 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Navigation/BackendNavigationAdapter.swift + ReaderSessionCoordinator.swift`
  - Contract: Preserve original navigation semantics; route multi-backend session in fork adapter
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/23**: `Source/UI/iOS/Managers/iOSNavigationManager.swift`
  - Lines: upstream L47-L46 → fork L56-L56 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Navigation/BackendNavigationAdapter.swift + ReaderSessionCoordinator.swift`
  - Contract: Preserve original navigation semantics; route multi-backend session in fork adapter
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/23**: `Source/UI/iOS/Managers/iOSNavigationManager.swift`
  - Lines: upstream L101-L100 → fork L111-L140 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Navigation/BackendNavigationAdapter.swift + ReaderSessionCoordinator.swift`
  - Contract: Preserve original navigation semantics; route multi-backend session in fork adapter
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/23**: `Source/UI/iOS/Managers/iOSNavigationManager.swift`
  - Lines: upstream L124-L123 → fork L164-L164 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Navigation/BackendNavigationAdapter.swift + ReaderSessionCoordinator.swift`
  - Contract: Preserve original navigation semantics; route multi-backend session in fork adapter
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/23**: `Source/UI/iOS/Managers/iOSNavigationManager.swift`
  - Lines: upstream L142-L141 → fork L183-L206 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Navigation/BackendNavigationAdapter.swift + ReaderSessionCoordinator.swift`
  - Contract: Preserve original navigation semantics; route multi-backend session in fork adapter
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/23**: `Source/UI/iOS/Managers/iOSNavigationManager.swift`
  - Lines: upstream L171-L170 → fork L236-L236 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Navigation/BackendNavigationAdapter.swift + ReaderSessionCoordinator.swift`
  - Contract: Preserve original navigation semantics; route multi-backend session in fork adapter
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 8/23**: `Source/UI/iOS/Managers/iOSNavigationManager.swift`
  - Lines: upstream L175-L176 → fork L241-L246 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Navigation/BackendNavigationAdapter.swift + ReaderSessionCoordinator.swift`
  - Contract: Preserve original navigation semantics; route multi-backend session in fork adapter
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 9/23**: `Source/UI/iOS/Managers/iOSNavigationManager.swift`
  - Lines: upstream L183-L182 → fork L253-L253 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Navigation/BackendNavigationAdapter.swift + ReaderSessionCoordinator.swift`
  - Contract: Preserve original navigation semantics; route multi-backend session in fork adapter
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 10/23**: `Source/UI/iOS/Managers/iOSNavigationManager.swift`
  - Lines: upstream L189-L188 → fork L260-L260 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Navigation/BackendNavigationAdapter.swift + ReaderSessionCoordinator.swift`
  - Contract: Preserve original navigation semantics; route multi-backend session in fork adapter
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 11/23**: `Source/UI/iOS/Managers/iOSNavigationManager.swift`
  - Lines: upstream L198-L197 → fork L270-L270 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Navigation/BackendNavigationAdapter.swift + ReaderSessionCoordinator.swift`
  - Contract: Preserve original navigation semantics; route multi-backend session in fork adapter
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 12/23**: `Source/UI/iOS/Managers/iOSNavigationManager.swift`
  - Lines: upstream L201-L200 → fork L274-L284 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Navigation/BackendNavigationAdapter.swift + ReaderSessionCoordinator.swift`
  - Contract: Preserve original navigation semantics; route multi-backend session in fork adapter
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 13/23**: `Source/UI/iOS/Managers/iOSNavigationManager.swift`
  - Lines: upstream L235-L234 → fork L319-L354 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Navigation/BackendNavigationAdapter.swift + ReaderSessionCoordinator.swift`
  - Contract: Preserve original navigation semantics; route multi-backend session in fork adapter
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 14/23**: `Source/UI/iOS/Managers/iOSNavigationManager.swift`
  - Lines: upstream L292-L291 → fork L412-L414 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Navigation/BackendNavigationAdapter.swift + ReaderSessionCoordinator.swift`
  - Contract: Preserve original navigation semantics; route multi-backend session in fork adapter
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 15/23**: `Source/UI/iOS/Managers/iOSNavigationManager.swift`
  - Lines: upstream L295-L294 → fork L418-L436 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Navigation/BackendNavigationAdapter.swift + ReaderSessionCoordinator.swift`
  - Contract: Preserve original navigation semantics; route multi-backend session in fork adapter
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 16/23**: `Source/UI/iOS/Managers/iOSNavigationManager.swift`
  - Lines: upstream L315-L314 → fork L457-L465 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Navigation/BackendNavigationAdapter.swift + ReaderSessionCoordinator.swift`
  - Contract: Preserve original navigation semantics; route multi-backend session in fork adapter
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 17/23**: `Source/UI/iOS/Managers/iOSNavigationManager.swift`
  - Lines: upstream L329-L328 → fork L480-L483 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Navigation/BackendNavigationAdapter.swift + ReaderSessionCoordinator.swift`
  - Contract: Preserve original navigation semantics; route multi-backend session in fork adapter
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 18/23**: `Source/UI/iOS/Managers/iOSNavigationManager.swift`
  - Lines: upstream L375-L374 → fork L530-L553 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Navigation/BackendNavigationAdapter.swift + ReaderSessionCoordinator.swift`
  - Contract: Preserve original navigation semantics; route multi-backend session in fork adapter
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 19/23**: `Source/UI/iOS/Managers/iOSNavigationManager.swift`
  - Lines: upstream L381-L380 → fork L560-L560 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Navigation/BackendNavigationAdapter.swift + ReaderSessionCoordinator.swift`
  - Contract: Preserve original navigation semantics; route multi-backend session in fork adapter
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 20/23**: `Source/UI/iOS/Managers/iOSNavigationManager.swift`
  - Lines: upstream L389-L388 → fork L569-L581 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Navigation/BackendNavigationAdapter.swift + ReaderSessionCoordinator.swift`
  - Contract: Preserve original navigation semantics; route multi-backend session in fork adapter
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 21/23**: `Source/UI/iOS/Managers/iOSNavigationManager.swift`
  - Lines: upstream L409-L408 → fork L602-L606 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Navigation/BackendNavigationAdapter.swift + ReaderSessionCoordinator.swift`
  - Contract: Preserve original navigation semantics; route multi-backend session in fork adapter
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 22/23**: `Source/UI/iOS/Managers/iOSNavigationManager.swift`
  - Lines: upstream L417-L416 → fork L615-L615 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Navigation/BackendNavigationAdapter.swift + ReaderSessionCoordinator.swift`
  - Contract: Preserve original navigation semantics; route multi-backend session in fork adapter
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 23/23**: `Source/UI/iOS/Managers/iOSNavigationManager.swift`
  - Lines: upstream L422-L421 → fork L621-L759 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/Navigation/BackendNavigationAdapter.swift + ReaderSessionCoordinator.swift`
  - Contract: Preserve original navigation semantics; route multi-backend session in fork adapter
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/UI/iOS/Views/Bootstrap/BootstrapView.swift`

- **Hunk 1/8**: `Source/UI/iOS/Views/Bootstrap/BootstrapView.swift`
  - Lines: upstream L9-L8 → fork L9-L9 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/BootstrapAdapter.swift`
  - Contract: Upstream bootstrap remains native; multi-backend setup moves to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/8**: `Source/UI/iOS/Views/Bootstrap/BootstrapView.swift`
  - Lines: upstream L12-L11 → fork L13-L13 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/BootstrapAdapter.swift`
  - Contract: Upstream bootstrap remains native; multi-backend setup moves to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/8**: `Source/UI/iOS/Views/Bootstrap/BootstrapView.swift`
  - Lines: upstream L27-L26 → fork L29-L39 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/BootstrapAdapter.swift`
  - Contract: Upstream bootstrap remains native; multi-backend setup moves to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/8**: `Source/UI/iOS/Views/Bootstrap/BootstrapView.swift`
  - Lines: upstream L28-L33 → fork L41-L59 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/BootstrapAdapter.swift`
  - Contract: Upstream bootstrap remains native; multi-backend setup moves to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/8**: `Source/UI/iOS/Views/Bootstrap/BootstrapView.swift`
  - Lines: upstream L40-L40 → fork L66-L66 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/BootstrapAdapter.swift`
  - Contract: Upstream bootstrap remains native; multi-backend setup moves to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/8**: `Source/UI/iOS/Views/Bootstrap/BootstrapView.swift`
  - Lines: upstream L46-L45 → fork L72-L86 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/BootstrapAdapter.swift`
  - Contract: Upstream bootstrap remains native; multi-backend setup moves to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/8**: `Source/UI/iOS/Views/Bootstrap/BootstrapView.swift`
  - Lines: upstream L47-L47 → fork L88-L88 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/BootstrapAdapter.swift`
  - Contract: Upstream bootstrap remains native; multi-backend setup moves to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 8/8**: `Source/UI/iOS/Views/Bootstrap/BootstrapView.swift`
  - Lines: upstream L98-L97 → fork L139-L261 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/BootstrapAdapter.swift`
  - Contract: Upstream bootstrap remains native; multi-backend setup moves to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/UI/iOS/Views/Common/BaseHierarchicalListViewController.swift`

- **Hunk 1/1**: `Source/UI/iOS/Views/Common/BaseHierarchicalListViewController.swift`
  - Lines: upstream L101-L101 → fork L101-L101 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/UI/iOS/Views/Common/ListContentView.swift`

- **Hunk 1/9**: `Source/UI/iOS/Views/Common/ListContentView.swift`
  - Lines: upstream L54-L57 → fork L54-L53 (`delete`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/9**: `Source/UI/iOS/Views/Common/ListContentView.swift`
  - Lines: upstream L61-L61 → fork L57-L57 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/9**: `Source/UI/iOS/Views/Common/ListContentView.swift`
  - Lines: upstream L77-L77 → fork L73-L73 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/9**: `Source/UI/iOS/Views/Common/ListContentView.swift`
  - Lines: upstream L84-L84 → fork L80-L80 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/9**: `Source/UI/iOS/Views/Common/ListContentView.swift`
  - Lines: upstream L87-L87 → fork L83-L83 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/9**: `Source/UI/iOS/Views/Common/ListContentView.swift`
  - Lines: upstream L141-L141 → fork L137-L141 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/9**: `Source/UI/iOS/Views/Common/ListContentView.swift`
  - Lines: upstream L144-L143 → fork L144-L146 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 8/9**: `Source/UI/iOS/Views/Common/ListContentView.swift`
  - Lines: upstream L147-L147 → fork L150-L150 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 9/9**: `Source/UI/iOS/Views/Common/ListContentView.swift`
  - Lines: upstream L152-L153 → fork L155-L155 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/UI/iOS/Views/Common/iOSHierarchicalCollectionViewController.swift`

- **Hunk 1/30**: `Source/UI/iOS/Views/Common/iOSHierarchicalCollectionViewController.swift`
  - Lines: upstream L6-L5 → fork L6-L19 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/30**: `Source/UI/iOS/Views/Common/iOSHierarchicalCollectionViewController.swift`
  - Lines: upstream L7-L8 → fork L21-L22 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/30**: `Source/UI/iOS/Views/Common/iOSHierarchicalCollectionViewController.swift`
  - Lines: upstream L13-L14 → fork L27-L28 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/30**: `Source/UI/iOS/Views/Common/iOSHierarchicalCollectionViewController.swift`
  - Lines: upstream L21-L22 → fork L35-L36 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/30**: `Source/UI/iOS/Views/Common/iOSHierarchicalCollectionViewController.swift`
  - Lines: upstream L29-L30 → fork L43-L45 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/30**: `Source/UI/iOS/Views/Common/iOSHierarchicalCollectionViewController.swift`
  - Lines: upstream L32-L38 → fork L47-L48 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/30**: `Source/UI/iOS/Views/Common/iOSHierarchicalCollectionViewController.swift`
  - Lines: upstream L54-L55 → fork L64-L66 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 8/30**: `Source/UI/iOS/Views/Common/iOSHierarchicalCollectionViewController.swift`
  - Lines: upstream L57-L56 → fork L68-L70 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 9/30**: `Source/UI/iOS/Views/Common/iOSHierarchicalCollectionViewController.swift`
  - Lines: upstream L87-L87 → fork L101-L101 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 10/30**: `Source/UI/iOS/Views/Common/iOSHierarchicalCollectionViewController.swift`
  - Lines: upstream L90-L90 → fork L104-L104 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 11/30**: `Source/UI/iOS/Views/Common/iOSHierarchicalCollectionViewController.swift`
  - Lines: upstream L132-L132 → fork L146-L146 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 12/30**: `Source/UI/iOS/Views/Common/iOSHierarchicalCollectionViewController.swift`
  - Lines: upstream L136-L136 → fork L150-L150 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 13/30**: `Source/UI/iOS/Views/Common/iOSHierarchicalCollectionViewController.swift`
  - Lines: upstream L157-L156 → fork L171-L183 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 14/30**: `Source/UI/iOS/Views/Common/iOSHierarchicalCollectionViewController.swift`
  - Lines: upstream L164-L164 → fork L191-L200 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 15/30**: `Source/UI/iOS/Views/Common/iOSHierarchicalCollectionViewController.swift`
  - Lines: upstream L171-L175 → fork L207-L218 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 16/30**: `Source/UI/iOS/Views/Common/iOSHierarchicalCollectionViewController.swift`
  - Lines: upstream L188-L194 → fork L231-L231 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 17/30**: `Source/UI/iOS/Views/Common/iOSHierarchicalCollectionViewController.swift`
  - Lines: upstream L196-L197 → fork L233-L236 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 18/30**: `Source/UI/iOS/Views/Common/iOSHierarchicalCollectionViewController.swift`
  - Lines: upstream L199-L201 → fork L238-L259 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 19/30**: `Source/UI/iOS/Views/Common/iOSHierarchicalCollectionViewController.swift`
  - Lines: upstream L203-L213 → fork L261-L261 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 20/30**: `Source/UI/iOS/Views/Common/iOSHierarchicalCollectionViewController.swift`
  - Lines: upstream L217-L217 → fork L265-L269 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 21/30**: `Source/UI/iOS/Views/Common/iOSHierarchicalCollectionViewController.swift`
  - Lines: upstream L219-L221 → fork L271-L273 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 22/30**: `Source/UI/iOS/Views/Common/iOSHierarchicalCollectionViewController.swift`
  - Lines: upstream L223-L229 → fork L275-L282 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 23/30**: `Source/UI/iOS/Views/Common/iOSHierarchicalCollectionViewController.swift`
  - Lines: upstream L231-L231 → fork L284-L286 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 24/30**: `Source/UI/iOS/Views/Common/iOSHierarchicalCollectionViewController.swift`
  - Lines: upstream L254-L254 → fork L309-L309 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 25/30**: `Source/UI/iOS/Views/Common/iOSHierarchicalCollectionViewController.swift`
  - Lines: upstream L258-L258 → fork L313-L314 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 26/30**: `Source/UI/iOS/Views/Common/iOSHierarchicalCollectionViewController.swift`
  - Lines: upstream L260-L259 → fork L316-L317 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 27/30**: `Source/UI/iOS/Views/Common/iOSHierarchicalCollectionViewController.swift`
  - Lines: upstream L265-L264 → fork L323-L437 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 28/30**: `Source/UI/iOS/Views/Common/iOSHierarchicalCollectionViewController.swift`
  - Lines: upstream L274-L276 → fork L447-L449 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 29/30**: `Source/UI/iOS/Views/Common/iOSHierarchicalCollectionViewController.swift`
  - Lines: upstream L294-L294 → fork L467-L467 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 30/30**: `Source/UI/iOS/Views/Common/iOSHierarchicalCollectionViewController.swift`
  - Lines: upstream L302-L301 → fork L475-L490 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `heuristic` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/`
  - Contract: Extract downstream customizations to fork layers
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/UI/iOS/Views/iOSMainView.swift`

- **Hunk 1/13**: `Source/UI/iOS/Views/iOSMainView.swift`
  - Lines: upstream L4-L8 → fork L4-L14 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/`
  - Contract: Move tab bar selection, 3-column navigation, and backend routing to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/13**: `Source/UI/iOS/Views/iOSMainView.swift`
  - Lines: upstream L14-L13 → fork L20-L26 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/`
  - Contract: Move tab bar selection, 3-column navigation, and backend routing to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/13**: `Source/UI/iOS/Views/iOSMainView.swift`
  - Lines: upstream L16-L17 → fork L29-L30 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/`
  - Contract: Move tab bar selection, 3-column navigation, and backend routing to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/13**: `Source/UI/iOS/Views/iOSMainView.swift`
  - Lines: upstream L27-L27 → fork L40-L40 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/`
  - Contract: Move tab bar selection, 3-column navigation, and backend routing to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/13**: `Source/UI/iOS/Views/iOSMainView.swift`
  - Lines: upstream L37-L37 → fork L50-L50 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/`
  - Contract: Move tab bar selection, 3-column navigation, and backend routing to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/13**: `Source/UI/iOS/Views/iOSMainView.swift`
  - Lines: upstream L41-L40 → fork L54-L71 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/`
  - Contract: Move tab bar selection, 3-column navigation, and backend routing to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/13**: `Source/UI/iOS/Views/iOSMainView.swift`
  - Lines: upstream L114-L113 → fork L145-L147 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/`
  - Contract: Move tab bar selection, 3-column navigation, and backend routing to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 8/13**: `Source/UI/iOS/Views/iOSMainView.swift`
  - Lines: upstream L116-L116 → fork L150-L152 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/`
  - Contract: Move tab bar selection, 3-column navigation, and backend routing to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 9/13**: `Source/UI/iOS/Views/iOSMainView.swift`
  - Lines: upstream L119-L118 → fork L155-L157 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/`
  - Contract: Move tab bar selection, 3-column navigation, and backend routing to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 10/13**: `Source/UI/iOS/Views/iOSMainView.swift`
  - Lines: upstream L121-L120 → fork L160-L164 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/`
  - Contract: Move tab bar selection, 3-column navigation, and backend routing to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 11/13**: `Source/UI/iOS/Views/iOSMainView.swift`
  - Lines: upstream L161-L162 → fork L205-L210 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/`
  - Contract: Move tab bar selection, 3-column navigation, and backend routing to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 12/13**: `Source/UI/iOS/Views/iOSMainView.swift`
  - Lines: upstream L194-L194 → fork L242-L241 (`delete`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/`
  - Contract: Move tab bar selection, 3-column navigation, and backend routing to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 13/13**: `Source/UI/iOS/Views/iOSMainView.swift`
  - Lines: upstream L210-L209 → fork L257-L746 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/`
  - Contract: Move tab bar selection, 3-column navigation, and backend routing to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/UI/iOS/Views/iPadLayout.swift`

- **Hunk 1/16**: `Source/UI/iOS/Views/iPadLayout.swift`
  - Lines: upstream L4-L3 → fork L4-L4 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/`
  - Contract: Move tab bar selection, 3-column navigation, and backend routing to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/16**: `Source/UI/iOS/Views/iPadLayout.swift`
  - Lines: upstream L14-L14 → fork L15-L14 (`delete`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/`
  - Contract: Move tab bar selection, 3-column navigation, and backend routing to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/16**: `Source/UI/iOS/Views/iPadLayout.swift`
  - Lines: upstream L16-L50 → fork L16-L19 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/`
  - Contract: Move tab bar selection, 3-column navigation, and backend routing to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/16**: `Source/UI/iOS/Views/iPadLayout.swift`
  - Lines: upstream L53-L73 → fork L22-L24 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/`
  - Contract: Move tab bar selection, 3-column navigation, and backend routing to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/16**: `Source/UI/iOS/Views/iPadLayout.swift`
  - Lines: upstream L75-L76 → fork L26-L45 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/`
  - Contract: Move tab bar selection, 3-column navigation, and backend routing to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/16**: `Source/UI/iOS/Views/iPadLayout.swift`
  - Lines: upstream L78-L77 → fork L47-L48 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/`
  - Contract: Move tab bar selection, 3-column navigation, and backend routing to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/16**: `Source/UI/iOS/Views/iPadLayout.swift`
  - Lines: upstream L81-L91 → fork L52-L57 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/`
  - Contract: Move tab bar selection, 3-column navigation, and backend routing to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 8/16**: `Source/UI/iOS/Views/iPadLayout.swift`
  - Lines: upstream L93-L95 → fork L59-L61 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/`
  - Contract: Move tab bar selection, 3-column navigation, and backend routing to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 9/16**: `Source/UI/iOS/Views/iPadLayout.swift`
  - Lines: upstream L97-L106 → fork L63-L64 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/`
  - Contract: Move tab bar selection, 3-column navigation, and backend routing to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 10/16**: `Source/UI/iOS/Views/iPadLayout.swift`
  - Lines: upstream L108-L117 → fork L66-L94 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/`
  - Contract: Move tab bar selection, 3-column navigation, and backend routing to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 11/16**: `Source/UI/iOS/Views/iPadLayout.swift`
  - Lines: upstream L122-L134 → fork L99-L110 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/`
  - Contract: Move tab bar selection, 3-column navigation, and backend routing to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 12/16**: `Source/UI/iOS/Views/iPadLayout.swift`
  - Lines: upstream L136-L135 → fork L112-L133 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/`
  - Contract: Move tab bar selection, 3-column navigation, and backend routing to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 13/16**: `Source/UI/iOS/Views/iPadLayout.swift`
  - Lines: upstream L137-L142 → fork L135-L233 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/`
  - Contract: Move tab bar selection, 3-column navigation, and backend routing to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 14/16**: `Source/UI/iOS/Views/iPadLayout.swift`
  - Lines: upstream L148-L155 → fork L239-L254 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/`
  - Contract: Move tab bar selection, 3-column navigation, and backend routing to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 15/16**: `Source/UI/iOS/Views/iPadLayout.swift`
  - Lines: upstream L159-L166 → fork L258-L276 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/`
  - Contract: Move tab bar selection, 3-column navigation, and backend routing to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 16/16**: `Source/UI/iOS/Views/iPadLayout.swift`
  - Lines: upstream L170-L181 → fork L280-L313 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/`
  - Contract: Move tab bar selection, 3-column navigation, and backend routing to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/UI/iOS/Views/iPhoneLayout.swift`

- **Hunk 1/5**: `Source/UI/iOS/Views/iPhoneLayout.swift`
  - Lines: upstream L18-L17 → fork L18-L18 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/`
  - Contract: Move tab bar selection, 3-column navigation, and backend routing to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/5**: `Source/UI/iOS/Views/iPhoneLayout.swift`
  - Lines: upstream L25-L26 → fork L26-L29 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/`
  - Contract: Move tab bar selection, 3-column navigation, and backend routing to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/5**: `Source/UI/iOS/Views/iPhoneLayout.swift`
  - Lines: upstream L29-L30 → fork L32-L35 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/`
  - Contract: Move tab bar selection, 3-column navigation, and backend routing to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/5**: `Source/UI/iOS/Views/iPhoneLayout.swift`
  - Lines: upstream L46-L46 → fork L51-L66 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/`
  - Contract: Move tab bar selection, 3-column navigation, and backend routing to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/5**: `Source/UI/iOS/Views/iPhoneLayout.swift`
  - Lines: upstream L49-L50 → fork L69-L80 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/`
  - Contract: Move tab bar selection, 3-column navigation, and backend routing to fork AppShell
  - Approval: `LEGACY_UNREVIEWED`

### Workstream Area: macOS UI (23 hunks)

#### `Source/UI/macOS/AppDelegate.swift`

- **Hunk 1/5**: `Source/UI/macOS/AppDelegate.swift`
  - Lines: upstream L64-L63 → fork L64-L64 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/macOS/`
  - Contract: Preserve macOS native flow; isolate multi-backend bootstrap
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/5**: `Source/UI/macOS/AppDelegate.swift`
  - Lines: upstream L67-L67 → fork L68-L70 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/macOS/`
  - Contract: Preserve macOS native flow; isolate multi-backend bootstrap
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/5**: `Source/UI/macOS/AppDelegate.swift`
  - Lines: upstream L160-L159 → fork L163-L163 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/macOS/`
  - Contract: Preserve macOS native flow; isolate multi-backend bootstrap
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/5**: `Source/UI/macOS/AppDelegate.swift`
  - Lines: upstream L162-L162 → fork L166-L167 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/macOS/`
  - Contract: Preserve macOS native flow; isolate multi-backend bootstrap
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/5**: `Source/UI/macOS/AppDelegate.swift`
  - Lines: upstream L172-L172 → fork L177-L179 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/macOS/`
  - Contract: Preserve macOS native flow; isolate multi-backend bootstrap
  - Approval: `LEGACY_UNREVIEWED`

#### `Source/UI/macOS/Modal+Overlay/CoreDownloadProgressView.swift`

- **Hunk 1/18**: `Source/UI/macOS/Modal+Overlay/CoreDownloadProgressView.swift`
  - Lines: upstream L11-L10 → fork L11-L56 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/macOS/`
  - Contract: Preserve macOS native flow; isolate multi-backend bootstrap
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 2/18**: `Source/UI/macOS/Modal+Overlay/CoreDownloadProgressView.swift`
  - Lines: upstream L16-L15 → fork L62-L63 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/macOS/`
  - Contract: Preserve macOS native flow; isolate multi-backend bootstrap
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 3/18**: `Source/UI/macOS/Modal+Overlay/CoreDownloadProgressView.swift`
  - Lines: upstream L40-L46 → fork L88-L88 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/macOS/`
  - Contract: Preserve macOS native flow; isolate multi-backend bootstrap
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 4/18**: `Source/UI/macOS/Modal+Overlay/CoreDownloadProgressView.swift`
  - Lines: upstream L55-L54 → fork L97-L121 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/macOS/`
  - Contract: Preserve macOS native flow; isolate multi-backend bootstrap
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 5/18**: `Source/UI/macOS/Modal+Overlay/CoreDownloadProgressView.swift`
  - Lines: upstream L86-L85 → fork L153-L164 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/macOS/`
  - Contract: Preserve macOS native flow; isolate multi-backend bootstrap
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 6/18**: `Source/UI/macOS/Modal+Overlay/CoreDownloadProgressView.swift`
  - Lines: upstream L91-L91 → fork L170-L170 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/macOS/`
  - Contract: Preserve macOS native flow; isolate multi-backend bootstrap
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 7/18**: `Source/UI/macOS/Modal+Overlay/CoreDownloadProgressView.swift`
  - Lines: upstream L95-L95 → fork L174-L176 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/macOS/`
  - Contract: Preserve macOS native flow; isolate multi-backend bootstrap
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 8/18**: `Source/UI/macOS/Modal+Overlay/CoreDownloadProgressView.swift`
  - Lines: upstream L111-L111 → fork L192-L192 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/macOS/`
  - Contract: Preserve macOS native flow; isolate multi-backend bootstrap
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 9/18**: `Source/UI/macOS/Modal+Overlay/CoreDownloadProgressView.swift`
  - Lines: upstream L124-L126 → fork L205-L205 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/macOS/`
  - Contract: Preserve macOS native flow; isolate multi-backend bootstrap
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 10/18**: `Source/UI/macOS/Modal+Overlay/CoreDownloadProgressView.swift`
  - Lines: upstream L130-L132 → fork L209-L227 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/macOS/`
  - Contract: Preserve macOS native flow; isolate multi-backend bootstrap
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 11/18**: `Source/UI/macOS/Modal+Overlay/CoreDownloadProgressView.swift`
  - Lines: upstream L134-L133 → fork L229-L234 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/macOS/`
  - Contract: Preserve macOS native flow; isolate multi-backend bootstrap
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 12/18**: `Source/UI/macOS/Modal+Overlay/CoreDownloadProgressView.swift`
  - Lines: upstream L148-L148 → fork L249-L249 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/macOS/`
  - Contract: Preserve macOS native flow; isolate multi-backend bootstrap
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 13/18**: `Source/UI/macOS/Modal+Overlay/CoreDownloadProgressView.swift`
  - Lines: upstream L157-L161 → fork L258-L266 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/macOS/`
  - Contract: Preserve macOS native flow; isolate multi-backend bootstrap
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 14/18**: `Source/UI/macOS/Modal+Overlay/CoreDownloadProgressView.swift`
  - Lines: upstream L163-L164 → fork L268-L267 (`delete`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/macOS/`
  - Contract: Preserve macOS native flow; isolate multi-backend bootstrap
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 15/18**: `Source/UI/macOS/Modal+Overlay/CoreDownloadProgressView.swift`
  - Lines: upstream L167-L167 → fork L270-L270 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/macOS/`
  - Contract: Preserve macOS native flow; isolate multi-backend bootstrap
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 16/18**: `Source/UI/macOS/Modal+Overlay/CoreDownloadProgressView.swift`
  - Lines: upstream L195-L194 → fork L298-L306 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/macOS/`
  - Contract: Preserve macOS native flow; isolate multi-backend bootstrap
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 17/18**: `Source/UI/macOS/Modal+Overlay/CoreDownloadProgressView.swift`
  - Lines: upstream L199-L213 → fork L311-L335 (`replace`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/macOS/`
  - Contract: Preserve macOS native flow; isolate multi-backend bootstrap
  - Approval: `LEGACY_UNREVIEWED`

- **Hunk 18/18**: `Source/UI/macOS/Modal+Overlay/CoreDownloadProgressView.swift`
  - Lines: upstream L216-L215 → fork L338-L359 (`insert`)
  - Category: `DOWNSTREAM_EXTRACT` | Rigor: `rules_based` | State: `READY_FOR_HOOK / NOT_IN_APP`
  - Wired in App: `False` | Build Verified: `False` | Device Verified: `False`
  - Target Replacement: `Source/ChavrusaText/AppShell/macOS/`
  - Contract: Preserve macOS native flow; isolate multi-backend bootstrap
  - Approval: `LEGACY_UNREVIEWED`

