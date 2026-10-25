# BUILD 8401: PROTECTED HUNK OWNER APPROVAL PACKAGE

**Date:** 2026-10-25  
**Baseline Git SHAs Verified:**
- Baseline Candidate Commit: `031df35710ab2c6015efb1acd1e65154dbcd3f24` (`031df35`)
- Pinned Upstream Remote Ref: `a0ed0df908a6cb38bc459d4baaeb400f447b2fc4` (`a0ed0df`)
- Candidate Validation Branch: `validation/maktabah-build-8401-repair-production-20261025` (Contains applied candidate hunks in isolated worktree for automated verification)
- Protected Upstream Branches (`main`, `Maktabah-v42-integration`): **`PROTECTED_TREES_UNTOUCHED`**
- Approval Gate Status: **`GATE_OPEN_OWNER_APPROVAL_REQUIRED`** (No self-approval, zero faked signatures)

---

## 1. Executive Summary & Policy Authority

Per `docs/architecture/UPSTREAM_INTEGRITY_POLICY.md` (canonical owner directive 2026-10-22):
- All Maktabah upstream-owned files, project file (`Maktabah.xcodeproj/project.pbxproj`), and CI workflows are **READ-ONLY for downstream feature work by default**.
- Any unavoidable edit to protected upstream-owned files requires explicit owner permission for its exact file and hunk.
- **Environment Distinction**:
  1. **Candidate Validation Branch** (`validation/maktabah-build-8401-repair-production-20261025`): Operates in an isolated worktree (`C:\Users\DAVID\Code\Maktabah-build-8401-candidate`) where the proposed patches are applied to permit clean compilation, local Swift test suites (208 assertions across 20 suites), and end-to-end iPad Simulator XCUITest execution in GitHub Actions CI.
  2. **Protected Upstream Branches** (`main`, `Maktabah-v42-integration`): Remain **100% untouched, unapplied, and unmerged**. No candidate branch commit will be merged to `main` without explicit owner approval and attestation.
- The **12 patches** below are stored as reproducible standalone files in `docs/architecture/build-8401-patches/`.
- All core logic is implemented in downstream-owned modules (`Source/ChavrusaText/`, `Source/LibraryBackend/`, `Source/Sefaria/`, `Source/Otzaria/`, `Source/ZayitSearch/`).

---

## 2. Proposed Protected Seams & Patch Manifest (12 Proposals)

| Patch ID | Protected File Path | Target Defect / Purpose | Patch File | Size (Bytes) | SHA-256 Digest | Base Blob SHA | Status |
|:---:|---|:---:|---|:---:|---|:---:|:---:|
| **BUILD_8401_PATCH_01** | `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift` | Defect #1, #2 | `01-iosibarottextview-decoration-cache-and-scroll.patch` | 2,319 | `9871cd93976872bf12b768a3a1474de09f3a0e01d6f5ca427803f9c33a23f22e` | `fa5430a8ee65318f65fbcdfd0e5d5f68a0f4b912` | `OWNER_APPROVAL_REQUIRED` |
| **BUILD_8401_PATCH_02** | `Source/Features/Reader/ViewModel/Extensions/Reader+Navigation.swift` | Defect #3 | `02-readernavigation-backend-paging.patch` | 2,621 | `34b40f8baea61c7f2d05c1c051a10e3aebba740ec4057bad0bced76a48189d52` | `8584cc718dbb7888a1cde7e24fcf61b957100898` | `OWNER_APPROVAL_REQUIRED` |
| **BUILD_8401_PATCH_03** | `Source/Features/Reader/ViewModel/Extensions/Reader+Content.swift` | Defect #1, #6, Race Condition | `03-readercontent-bounded-destination-resolution.patch` | 6,080 | `5cd5923ac01179af1a46e58429f843c688bd1e4024b49a42c072f42775e67bbe` | `11caf78e533c0a88b8ee2d9d0472165371da6676` | `OWNER_APPROVAL_REQUIRED` |
| **BUILD_8401_PATCH_04** | `Source/Features/Reader/ViewModel/Extensions/Reader+iOS.swift` | Defect #1, #2 | `04-readerios-search-context-and-selection.patch` | 1,760 | `28a36e0bd79ffae0c081c8897318a3081ea4e33c604673dc11f9478a4d774f52` | `ba2a051005cfdef04c33dd6e800295453dc47449` | `OWNER_APPROVAL_REQUIRED` |
| **BUILD_8401_PATCH_05** | `Source/Features/Reader/ViewModel/ReaderViewModel.swift` | Defect #2, Race Target | `05-readerviewmodel-search-event-preservation.patch` | 2,158 | `a3da7d01ff3be86d13c0503e2d7555c2527207f760e273209191e935f1598ee8` | `7ab42dbf00653317dbaaa266385729353b99d323` | `OWNER_APPROVAL_REQUIRED` |
| **BUILD_8401_PATCH_06** | `Source/Features/Reader/iOS/Toolbar/iOSReaderBottomToolbarView.swift` | Defect #2 | `06-iosreaderbottomtoolbarview-clear-x.patch` | 706 | `5ea782f34f538f1eeffed9415b8f591a436037b5b66d09bd0ad001513372c58a` | `daa0abfe16ce0ef23366dd1a2fb71402544127be` | `OWNER_APPROVAL_REQUIRED` |
| **BUILD_8401_PATCH_07** | `Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift` | Defect #5, #7 | `07-iostoceview-live-tracking-and-loading-state.patch` | 1,488 | `11d17f08d4fce0a4ec6d21e0e7713213901e759aba1c2d762602af791339be8e` | `6920c2e41f163b04cebb05eb0a0bc58deacd2ad4` | `OWNER_APPROVAL_REQUIRED` |
| **BUILD_8401_PATCH_08** | `Source/Features/Reader/iOS/iOSReaderWorkspaceView.swift` | Defect #5, UI Test Accessibility | `08-iosreaderworkspaceview-toc-tracking.patch` | 1,347 | `c99b06082c04366137d89e87f1c13973dc1c9b748101d778ad50ccdc6d83b0ed` | `1a136ebdd29f8a4c46bbf59bc4b2a5a2bdf6d4f0` | `OWNER_APPROVAL_REQUIRED` |
| **BUILD_8401_PATCH_09** | `Source/Features/Reader/ViewModel/BookTOCViewModel.swift` | Defect #5, #7, TOC Sorting | `09-booktocviewmodel-loading-and-matching.patch` | 4,648 | `f48d826698cba715d8b0122bc49f3eae43d0b51b8436ee0c7ac1509e04ad24a4` | `173bfe8a68fd2c6b46967f58e863fcd1e7db77f2` | `OWNER_APPROVAL_REQUIRED` |
| **BUILD_8401_PATCH_10** | `Source/Features/Setting/SettingsView.swift` | Defect #4 (Hazard 1) | `10-settingsview-backend-switch-error-handling.patch` | 2,395 | `90f4a654534495528a8bfbaf0ad8e17ec6f6bd02358c061e58e3322893840060` | `47aa588f3ca41fffb303e823e44958b2627e8df1` | `OWNER_APPROVAL_REQUIRED` |
| **BUILD_8401_PATCH_11** | `Source/UI/iOS/Managers/iOSNavigationManager.swift` | Defect #4, #6 | `11-iosnavigationmanager-cold-catalog-and-search-context.patch` | 3,373 | `90a227d7ff6b7ee3b88dbd71ec5cb073a7c267578be9ea90094a304775b4b752` | `32046c0b2c468fa4e7b312b1474b582c751da1aa` | `OWNER_APPROVAL_REQUIRED` |
| **BUILD_8401_PATCH_12** | `Maktabah.xcodeproj/project.pbxproj` | Xcode Integration | `12-maktabah-xcode-target-integration.patch` | 11,826 | `f8bceb73a36fed95d38deb954ba8655f4cea60c5af64a58b50d5bc3149389ef4` | `8a332467292ba7a0198be11966fa7147c0edcc42` | `OWNER_APPROVAL_REQUIRED` |

---

## 3. Detailed Hunk Justifications, Alternatives & Scoped Rollback

### BUILD_8401_PATCH_01: `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift`
- **Why Needed:** `RenderCacheKey` previously omitted `selectedSegmentRange` and `highlightTerms`. When a user navigates to a search hit, `lastRenderKey == currentKey` matched and stale unhighlighted content was returned from cache. In addition, user scroll clearing was falsely triggered by programmatic scroll.
- **Downstream Alternative Attempted:** External repainting via view modifiers failed because `iOSIbarotTextView` manages its own internal `UITextView.attributedText` cache asynchronously. Adding decoration inputs to `RenderCacheKey` is the minimal connection point.
- **Preflight Base Hash:** `fa5430a8ee65318f65fbcdfd0e5d5f68a0f4b912`
- **Scoped Rollback:**  
  ```bash
  git apply -R --whitespace=error docs/architecture/build-8401-patches/01-iosibarottextview-decoration-cache-and-scroll.patch
  ```
- **Regression Tests:** `H1`, `H2`, `H4`

### BUILD_8401_PATCH_02: `Source/Features/Reader/ViewModel/Extensions/Reader+Navigation.swift`
- **Why Needed:** `goToNextPage()` and `goToPrevPage()` directly called `BookConnection.getNextPage`, which returns `nil` for Sefaria books (breaking pull-to-navigate completely) and jumps Otzaria books back to the beginning on first pull from the middle of a work.
- **Downstream Alternative Attempted:** Intercepting navigation outside `ReaderViewModel` was rejected because toolbar buttons and pull-to-navigate share these exact methods. Paging logic is delegated to downstream `ReaderBackendPagingCoordinator`.
- **Preflight Base Hash:** `8584cc718dbb7888a1cde7e24fcf61b957100898`
- **Scoped Rollback:**  
  ```bash
  git apply -R --whitespace=error docs/architecture/build-8401-patches/02-readernavigation-backend-paging.patch
  ```
- **Regression Tests:** `P1`, `P2`, `P3`, `P4`

### BUILD_8401_PATCH_03: `Source/Features/Reader/ViewModel/Extensions/Reader+Content.swift`
- **Why Needed:** 
  1. Bounded destination resolution for deep commentary references (e.g. `Rashi on Berakhot 15b:3:1`) was missing.
  2. Async race conditions allowed stale section loading tasks to overwrite newer active pages when navigating within the same book (`workKey` shared across pages). Integrated `ReaderContentLoadCoordinator` token validation.
  3. Prevented cancelled loads from clobbering active state with errors or resetting active `backendLoadTask`.
- **Downstream Alternative Attempted:** Destination resolution and token tracking are implemented downstream in `ReaderDestinationResolver.swift` and `ReaderContentLoadCoordinator.swift`.
- **Preflight Base Hash:** `11caf78e533c0a88b8ee2d9d0472165371da6676`
- **Scoped Rollback:**  
  ```bash
  git apply -R --whitespace=error docs/architecture/build-8401-patches/03-readercontent-bounded-destination-resolution.patch
  ```
- **Regression Tests:** `H1`, `S1`, `S2`, `RaceConditionTests`

### BUILD_8401_PATCH_04: `Source/Features/Reader/ViewModel/Extensions/Reader+iOS.swift`
- **Why Needed:** `didSelectSearch` previously passed identical `sectionLocator` and `focusLocator`. `hasActiveSearchHighlight` ignored `focusLocator`.
- **Downstream Alternative Attempted:** Evaluation logic is fully encapsulated in downstream `ReaderSearchContextCoordinator.swift`. This hook forwards search context and evaluates active search highlighting.
- **Preflight Base Hash:** `ba2a051005cfdef04c33dd6e800295453dc47449`
- **Scoped Rollback:**  
  ```bash
  git apply -R --whitespace=error docs/architecture/build-8401-patches/04-readerios-search-context-and-selection.patch
  ```
- **Regression Tests:** `H1`, `H3`

### BUILD_8401_PATCH_05: `Source/Features/Reader/ViewModel/ReaderViewModel.swift`
- **Why Needed:** 
  1. `updateContentState` prematurely cleared `searchEvent` on initial load because `searchEvent.contentId != content.id`.
  2. Added `pendingReaderScrollTarget` locator bounding and `consumePendingReaderScrollTarget(for:)` to prevent stale consumption.
- **Downstream Alternative Attempted:** Downstream `ReaderSearchContextCoordinator` maintains search context, but `ReaderViewModel.searchEvent` drives UIKit text view highlighting.
- **Preflight Base Hash:** `7ab42dbf00653317dbaaa266385729353b99d323`
- **Scoped Rollback:**  
  ```bash
  git apply -R --whitespace=error docs/architecture/build-8401-patches/05-readerviewmodel-search-event-preservation.patch
  ```
- **Regression Tests:** `H1`, `H2`

### BUILD_8401_PATCH_06: `Source/Features/Reader/iOS/Toolbar/iOSReaderBottomToolbarView.swift`
- **Why Needed:** Adds explicit accessibility identifier `reader.clear_search_highlight_button` to the clear 'X' button for automated XCUITest verification.
- **Downstream Alternative Attempted:** None (UI element is in upstream view).
- **Preflight Base Hash:** `daa0abfe16ce0ef23366dd1a2fb71402544127be`
- **Scoped Rollback:**  
  ```bash
  git apply -R --whitespace=error docs/architecture/build-8401-patches/06-iosreaderbottomtoolbarview-clear-x.patch
  ```
- **Regression Tests:** `H3`

### BUILD_8401_PATCH_07: `Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift`
- **Why Needed:** `iOSTOCView` missed `.onChange(of: selectedId)` live tracking and rendered "אין תוכן עניינים" while asynchronous TOC loading was pending (e.g. Tractate Eruvin).
- **Downstream Alternative Attempted:** None (SwiftUI view lifecycle hook).
- **Preflight Base Hash:** `6920c2e41f163b04cebb05eb0a0bc58deacd2ad4`
- **Scoped Rollback:**  
  ```bash
  git apply -R --whitespace=error docs/architecture/build-8401-patches/07-iostoceview-live-tracking-and-loading-state.patch
  ```
- **Regression Tests:** `T1`, `L3`

### BUILD_8401_PATCH_08: `Source/Features/Reader/iOS/iOSReaderWorkspaceView.swift`
- **Why Needed:** 
  1. `selectedTOCNode` fallback used content ID ranges which fail for backend books. Routes node lookup to downstream `TOCReadingLocationTracker`.
  2. Resolves dual accessibility identifier collision: `reader-header-title` was assigned to both a transparent 1x1 overlay and the visible header toolbar text. Disambiguated 1x1 overlay to `reader-current-locator` so automated UI tests target the visible title.
- **Downstream Alternative Attempted:** Routed to `TOCReadingLocationTracker.shared`.
- **Preflight Base Hash:** `1a136ebdd29f8a4c46bbf59bc4b2a5a2bdf6d4f0`
- **Scoped Rollback:**  
  ```bash
  git apply -R --whitespace=error docs/architecture/build-8401-patches/08-iosreaderworkspaceview-toc-tracking.patch
  ```
- **Regression Tests:** `T1`, `T2`, `UI-PullNav-1`

### BUILD_8401_PATCH_09: `Source/Features/Reader/ViewModel/BookTOCViewModel.swift`
- **Why Needed:** 
  1. Adds `@Observable` loading state and `findMatchingNode` method delegating to `TOCReadingLocationTracker`.
  2. Removed arbitrary `.sorted { $0.id < $1.id }` in `flattenNodes` which scrambled depth-first document hierarchy.
  3. Added cancellation check and state reset on `loadTOC` to prevent empty flash and duplicate callbacks.
- **Downstream Alternative Attempted:** Wrapped inside `BookTOCViewModel`.
- **Preflight Base Hash:** `173bfe8a68fd2c6b46967f58e863fcd1e7db77f2`
- **Scoped Rollback:**  
  ```bash
  git apply -R --whitespace=error docs/architecture/build-8401-patches/09-booktocviewmodel-loading-and-matching.patch
  ```
- **Regression Tests:** `T1`, `L3`, `TOC-Depth-First`

### BUILD_8401_PATCH_10: `Source/Features/Setting/SettingsView.swift`
- **Why Needed:** 
  1. Hardens backend switch to a single observable asynchronous `commitAsync` operation with error banner display. Eliminates the dangerous hazard of an automatic synchronous retry after async failure.
  2. Adds `.accessibilityIdentifier("settings-library-source-picker")` for automated acceptance tests.
- **Downstream Alternative Attempted:** `BackendCoordinator.lastTransitionErrorMessage` exposes observable structured errors.
- **Preflight Base Hash:** `47aa588f3ca41fffb303e823e44958b2627e8df1`
- **Scoped Rollback:**  
  ```bash
  git apply -R --whitespace=error docs/architecture/build-8401-patches/10-settingsview-backend-switch-error-handling.patch
  ```
- **Regression Tests:** `B1`, `B2`, `UI-BackendSwitch-Picker`

### BUILD_8401_PATCH_11: `Source/UI/iOS/Managers/iOSNavigationManager.swift`
- **Why Needed:** `DefaultTargetBackendBookResolver.resolveBook` threw `unresolvableBook` on cold catalog switches; `presentReader` passed `searchEvent: nil`. Delegated book resolution to `ChavrusaTextTargetBackendBookResolver.shared` and search context handling to `ReaderSearchContextCoordinator.shared`.
- **Downstream Alternative Attempted:** Delegated resolution to downstream resolver.
- **Preflight Base Hash:** `32046c0b2c468fa4e7b312b1474b582c751da1aa`
- **Scoped Rollback:**  
  ```bash
  git apply -R --whitespace=error docs/architecture/build-8401-patches/11-iosnavigationmanager-cold-catalog-and-search-context.patch
  ```
- **Regression Tests:** `B1`, `B2`, `H1`

### BUILD_8401_PATCH_12: `Maktabah.xcodeproj/project.pbxproj`
- **Why Needed:** Registers the 7 new Swift helper files with PBXFileReference, PBXBuildFile, and target membership for `Maktabah-iOS` (and helper targets `Maktabah`, `Maktabah-Direct`), ensuring they are compiled during Xcode builds:
  1. `Source/ChavrusaText/Localization/TalmudHebrewAddressFormatter.swift`
  2. `Source/ChavrusaText/Navigation/ReaderBackendPagingCoordinator.swift`
  3. `Source/ChavrusaText/Navigation/ReaderContentLoadCoordinator.swift`
  4. `Source/ChavrusaText/Navigation/ReaderDestinationResolver.swift`
  5. `Source/ChavrusaText/Navigation/TOCReadingLocationTracker.swift`
  6. `Source/ChavrusaText/Navigation/TargetBackendBookResolver.swift`
  7. `Source/ChavrusaText/Search/ReaderSearchContextCoordinator.swift`
- **Downstream Alternative Attempted:** Project uses explicit PBXFileReference registrations rather than synchronized source groups. Without this patch, Xcode builds would fail with "unresolved identifier" errors.
- **Preflight Base Hash:** `8a332467292ba7a0198be11966fa7147c0edcc42`
- **Scoped Rollback:**  
  ```bash
  git apply -R --whitespace=error docs/architecture/build-8401-patches/12-maktabah-xcode-target-integration.patch
  ```
- **Regression Tests:** `X1`, `X2`

---

## 4. Scoped Rollback and Verification Runbook

To safely verify and rollback the 12 patches without mutating the working tree:

```bash
# 1. Verification in disposable worktree:
git worktree add ../Maktabah-scratch 031df35710ab2c6015efb1acd1e65154dbcd3f24 --detach
cd ../Maktabah-scratch

# 2. Cumulative application:
for p in docs/architecture/build-8401-patches/*.patch; do
    git apply --whitespace=error "$p"
done

# 3. Verify clean diff:
git diff --check

# 4. Scoped rollback in reverse order:
for p in $(ls -r docs/architecture/build-8401-patches/*.patch); do
    git apply -R --whitespace=error "$p"
done

# 5. Teardown:
cd ../Maktabah
git worktree remove --force ../Maktabah-scratch
```

---

## 5. Current Approval Gate State

All 12 proposed patches are documented with their exact preflight base blob hashes and cryptographic SHA-256 digests.  
Status for each item: **`OWNER_APPROVAL_REQUIRED`**.  
The protected upstream working trees (`main`, `Maktabah-v42-integration`) remain **100% UNMODIFIED and UNAPPLIED**.  
No CI push, commit, or TestFlight release may merge to `main` without explicit owner approval.
