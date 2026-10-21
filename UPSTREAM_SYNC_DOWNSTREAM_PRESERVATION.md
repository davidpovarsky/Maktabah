# Maktabah Upstream v4.2 Integration — Downstream Preservation Report

**Date:** 2026-10-21  
**Worktree:** `C:\Users\DAVID\Code\Maktabah-v42-integration`  
**Branch:** `sync/upstream-v42-full-integration`  
**Downstream Baseline:** `65ecf2972821e13047b21c9ce04fe6141ca9387f`  

---

## 1. Preserved Subsystems & Inventories

All downstream fork subsystems remain 100% operational, intact, and integrated with upstream v4.2:

### A. Otzaria Integrated Backend & Reader Engine
- **Source Paths:** `Source/Otzaria/**` (74 tracked Swift files and assets)
- **Key Components:**
  - `OtzariaAppContainer.swift` & `OtzariaBootstrapAdapter.swift`: Initialization and profile detection.
  - `OtzariaSQLiteConnection.swift`, `OtzariaSQLiteLibraryRepository.swift`, `OtzariaSQLiteBookTextRepository.swift`: High-performance SQLite engine with generation-tagged caches.
  - `OtzariaReadingUnitService.swift` & `OtzariaReadingUnit.swift`: Reading units and line-anchor indexing.
  - `OtzariaReaderSourcesInspectorHost.swift` & `OtzariaLineSourcesInspectorView.swift`: 3-detent linked source inspector.
  - `OtzariaSecurityScopedAccess.swift`: Sandboxed bookmark access for external book archives.
  - `OtzariaTantivySearchRepository.swift`: Full-text search over indexed Otzaria corpora.
  - `OtzariaSearchArtifactService.swift` & manifest: Seamless download and matching of prebuilt search indices.
- **Status:** **PRESERVED & FULLY LINKED**.

### B. Zayit Rust Search Engine & Port
- **Source Paths:** `Source/Zayit/**` and `Vendor/ZayitSearchPort/**`
- **Key Components:**
  - `MaktabahZayitSearch.xcframework`: Compiled binary framework linked in Xcode project.
  - `ZayitSearchEngineBridge.swift` & `ZayitSearchRepository.swift`: Safe Swift-Rust FFI wrapper.
  - `UnifiedSearchSessionController.swift` & `UnifiedSearchWorkspaceView.swift`: Multi-backend search interface.
  - `ZayitSearchModels.swift` & `ZayitSearchDataValidator.swift`: Verification of database schemas and hit offsets.
- **Status:** **PRESERVED & FULLY LINKED**.

### C. Sefaria Backend & Offline Catalog
- **Source Paths:** `Source/LibraryBackend/**`
- **Key Components:**
  - `SefariaModels.swift`, `SefariaHTTPClient.swift`, `SefariaOfflineStore.swift`, `SefariaHybridStore.swift`.
  - `SefariaBundleDownloadService.swift` & `SefariaPackageManager.swift`.
  - `LibraryBackendProtocols.swift` & `BackendCoordinator.swift`: Pluggable backend architecture.
- **Status:** **PRESERVED & FULLY LINKED**.

### D. TorahInspectorKit Integration
- **Source Paths:** `Reading/MaktabahTorahInspectorAdapter.swift`, `Reading/OtzariaInspectorRelationshipsProvider.swift`, `Reading/OtzariaRelationshipClassifier.swift`
- **Package Pin:** Pinned revision `157676f511990756fa4cd8337c744903d4dc9ef6` intact.
- **Capabilities:** Semantic relationship classification (Rashi, Tosafot, Ramban, Kitzur, Shulchan Aruch).
- **Status:** **PRESERVED & FULLY LINKED**.

### E. Native iPad 3-Column UI & Reader Workspace
- **Source Paths:** `Source/UI/iOS/Views/iPadLayout.swift`, `Source/UI/iOS/Views/Reader/iOSReaderWorkspaceView.swift`, `Source/UI/iOS/Views/Reader/iOSBookInfoAnchoredCard.swift`
- **Design Invariant:** Maktabah remains the primary native UI. Otzaria acts as the content/search engine without replacing native SwiftUI navigation.
- **Layout:** Native `NavigationSplitView` (Library / TOC / Reader) with adaptive Study presentation and floating anchored cards.
- **Status:** **PRESERVED & FULLY LINKED**.

### F. Hebrew Typography & RTL Layout
- **Font Assets:** `ScheherazadeNew-Regular.ttf`, `Lateef-Regular.ttf`, `Lateef-Bold.ttf`, `UthmanTN1-Ver10.otf`.
- **Bidirectional Text:** Natural text alignment, paragraph boundary detection, and forceRightToLeft semantic content attributes.
- **Status:** **PRESERVED & FULLY LINKED**.

---

## 2. Xcode Target Membership & Linkage Verification

| Item | Xcode Target | Build Phase | Verification |
|---|---|---|:---:|
| `iOSReaderSessionManager.swift` | `Maktabah` (iOS) | Sources | Confirmed |
| `iOSReaderSessionTests.swift` | `MaktabahTests` | Sources | Confirmed |
| `MaktabahZayitSearch.xcframework` | `Maktabah` (iOS) | Frameworks | Confirmed |
| `TorahInspectorKit` | `Maktabah` (iOS) | Package Product | Confirmed |
| `AnchoredPopup` / `FloatingPanel` | `Maktabah` (iOS) | Frameworks | Confirmed |
| Otzaria / Zayit Sources | `Maktabah` (iOS) | Sources | Confirmed |
| Fonts (Lateef, Scheherazade) | `Maktabah` (iOS) | Resources | Confirmed |
