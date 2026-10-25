# BUILD 8401: PROTECTED HUNK OWNER APPROVAL PACKAGE

**Date:** 2026-10-25  
**Baseline Git SHAs Verified:**
- Baseline Candidate Commit: `031df35710ab2c6015efb1acd1e65154dbcd3f24` (`031df35`)
- Pinned Upstream Remote Ref: `a0ed0df908a6cb38bc459d4baaeb400f447b2fc4` (`a0ed0df`)
- Current Working Tree Status: `PROTECTED_TREES_UNTOUCHED`
- Approval Gate Status: **`GATE_OPEN_OWNER_APPROVAL_REQUIRED`** (No self-approval, zero faked signatures)

---

## 1. Executive Summary & Policy Authority

Per `docs/architecture/UPSTREAM_INTEGRITY_POLICY.md` (canonical owner directive 2026-10-22):
- All Maktabah upstream-owned files, project file (`Maktabah.xcodeproj/project.pbxproj`), and CI workflows are **READ-ONLY for downstream feature work by default**.
- Any unavoidable edit to protected upstream-owned files requires explicit owner permission for its exact file and hunk.
- The **12 patches** below are **unapplied proposals** stored in `docs/architecture/build-8401-patches/`.
- All core logic has been implemented in downstream-owned modules (`Source/ChavrusaText/`, `Source/LibraryBackend/`, `Source/Sefaria/`, `Source/Otzaria/`, `Source/ZayitSearch/`).
- The protected files in the active source tree remain **strictly untouched** until the repository owner explicitly grants attestation and signature for these specific hunks.
- The eight previously pending Batch B exceptions remain pending unless independently approved; this package adds the repaired 12-patch proposals for Build 8401.

---

## 2. Proposed Protected Seams & Patch Manifest (12 Proposals)

| Patch ID | Protected File Path | Target Defect / Purpose | Patch File | Size (Bytes) | SHA-256 Digest | Base Blob SHA | Status |
|:---:|---|:---:|---|:---:|---|:---:|:---:|
| **BUILD_8401_PATCH_01** | `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift` | Defect #1, #2 | `01-iosibarottextview-decoration-cache-and-scroll.patch` | 1,868 | `588b111a226e93243be4c1387eeed687cf6da0813c5b142fd33ae84844adb8a8` | `fa5430a8ee65318f65fbcdfd0e5d5f68a0f4b912` | `OWNER_APPROVAL_REQUIRED` |
| **BUILD_8401_PATCH_02** | `Source/Features/Reader/ViewModel/Extensions/Reader+Navigation.swift` | Defect #3 | `02-readernavigation-backend-paging.patch` | 2,589 | `4db28ba23460b351964caf271785ab1079ff1e2f6fc67f3313b5966f18f72de8` | `8584cc718dbb7888a1cde7e24fcf61b957100898` | `OWNER_APPROVAL_REQUIRED` |
| **BUILD_8401_PATCH_03** | `Source/Features/Reader/ViewModel/Extensions/Reader+Content.swift` | Defect #1, #6 | `03-readercontent-bounded-destination-resolution.patch` | 3,425 | `8ab35d43c69a6fcca32f2cfb3b2b6095449af7a540b9f7c7e5cd955e94d0dd2f` | `11caf78e533c0a88b8ee2d9d0472165371da6676` | `OWNER_APPROVAL_REQUIRED` |
| **BUILD_8401_PATCH_04** | `Source/Features/Reader/ViewModel/Extensions/Reader+iOS.swift` | Defect #1, #2 | `04-readerios-search-context-and-selection.patch` | 1,760 | `28a36e0bd79ffae0c081c8897318a3081ea4e33c604673dc11f9478a4d774f52` | `ba2a051005cfdef04c33dd6e800295453dc47449` | `OWNER_APPROVAL_REQUIRED` |
| **BUILD_8401_PATCH_05** | `Source/Features/Reader/ViewModel/ReaderViewModel.swift` | Defect #2 | `05-readerviewmodel-search-event-preservation.patch` | 752 | `c5ef6257581ba4887cb3fce269a153e006ac4ae0d4afaa83ff9f1b669e1339c1` | `7ab42dbf00653317dbaaa266385729353b99d323` | `OWNER_APPROVAL_REQUIRED` |
| **BUILD_8401_PATCH_06** | `Source/Features/Reader/iOS/Toolbar/iOSReaderBottomToolbarView.swift` | Defect #2 | `06-iosreaderbottomtoolbarview-clear-x.patch` | 706 | `5ea782f34f538f1eeffed9415b8f591a436037b5b66d09bd0ad001513372c58a` | `daa0abfe16ce0ef23366dd1a2fb71402544127be` | `OWNER_APPROVAL_REQUIRED` |
| **BUILD_8401_PATCH_07** | `Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift` | Defect #5, #7 | `07-iostoceview-live-tracking-and-loading-state.patch` | 1,488 | `11d17f08d4fce0a4ec6d21e0e7713213901e759aba1c2d762602af791339be8e` | `6920c2e41f163b04cebb05eb0a0bc58deacd2ad4` | `OWNER_APPROVAL_REQUIRED` |
| **BUILD_8401_PATCH_08** | `Source/Features/Reader/iOS/iOSReaderWorkspaceView.swift` | Defect #5 | `08-iosreaderworkspaceview-toc-tracking.patch` | 768 | `028cdb1628f3b1937a4e1f66e491a91f92558c8e307dcd9557bb54334655b19d` | `1a136ebdd29f8a4c46bbf59bc4b2a5a2bdf6d4f0` | `OWNER_APPROVAL_REQUIRED` |
| **BUILD_8401_PATCH_09** | `Source/Features/Reader/ViewModel/BookTOCViewModel.swift` | Defect #5, #7 | `09-booktocviewmodel-loading-and-matching.patch` | 1,955 | `2b71346624e4d4e8a725910cee703b908c06e630f4e1bdb40f1de68bdd8d4cff` | `173bfe8a68fd2c6b46967f58e863fcd1e7db77f2` | `OWNER_APPROVAL_REQUIRED` |
| **BUILD_8401_PATCH_10** | `Source/Features/Setting/SettingsView.swift` | Defect #4 (Hazard 1) | `10-settingsview-backend-switch-error-handling.patch` | 2,323 | `22a1fafc82b89ee0c836a09a7a28464b0bc06539732c5010937ee53b2b032734` | `47aa588f3ca41fffb303e823e44958b2627e8df1` | `OWNER_APPROVAL_REQUIRED` |
| **BUILD_8401_PATCH_11** | `Source/UI/iOS/Managers/iOSNavigationManager.swift` | Defect #4, #6 | `11-iosnavigationmanager-cold-catalog-and-search-context.patch` | 3,373 | `90a227d7ff6b7ee3b88dbd71ec5cb073a7c267578be9ea90094a304775b4b752` | `32046c0b2c468fa4e7b312b1474b582c751da1aa` | `OWNER_APPROVAL_REQUIRED` |
| **BUILD_8401_PATCH_12** | `Maktabah.xcodeproj/project.pbxproj` | Xcode Integration | `12-maktabah-xcode-target-integration.patch` | 10,739 | `6b754147e15d2c6b3c9dc548e46dd20426a18ee1b69d47bc4606d2bf4560b14c` | `8a332467292ba7a0198be11966fa7147c0edcc42` | `OWNER_APPROVAL_REQUIRED` |

---

## 3. Detailed Hunk Justifications, Alternatives & Scoped Rollback

### BUILD_8401_PATCH_01: `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift`
- **Why Needed:** `RenderCacheKey` previously omitted `selectedSegmentRange` and `highlightTerms`. When a user navigates to a search hit, `lastRenderKey == currentKey` matched and stale unhighlighted content was returned from cache. In addition, user scroll clearing was falsely triggered by programmatic scroll.
- **Downstream Alternative Attempted:** External repainting via view modifiers failed because `iOSIbarotTextView` manages its own internal `UITextView.attributedText` cache asynchronously. Adding decoration inputs to `RenderCacheKey` is the minimal 6-line connection point.
- **Preflight Base Hash:** `fa5430a8ee65318f65fbcdfd0e5d5f68a0f4b912`
- **Post-Apply Hash:** `39cbe0dcaeefbca1bbfe96417532d5e75da7c293`
- **Scoped Rollback:**  
  ```bash
  git apply -R --whitespace=error docs/architecture/build-8401-patches/01-iosibarottextview-decoration-cache-and-scroll.patch
  ```
  *(Never use `git checkout <path>` or `git restore` on dirty working copies).*
- **Regression Tests:** `H1`, `H2`, `H4`

### BUILD_8401_PATCH_02: `Source/Features/Reader/ViewModel/Extensions/Reader+Navigation.swift`
- **Why Needed:** `goToNextPage()` and `goToPrevPage()` directly called `BookConnection.getNextPage`, which returns `nil` for Sefaria books (breaking pull-to-navigate completely) and jumps Otzaria books back to the beginning on first pull from the middle of a work.
- **Downstream Alternative Attempted:** Intercepting navigation outside `ReaderViewModel` was rejected because toolbar buttons and pull-to-navigate share these exact methods. Paging logic is delegated to `ReaderBackendPagingCoordinator`.
- **Preflight Base Hash:** `8584cc718dbb7888a1cde7e24fcf61b957100898`
- **Post-Apply Hash:** `c95dbfba3418cf9bc6fb8e154fec7b3c22fcba37`
- **Scoped Rollback:**  
  ```bash
  git apply -R --whitespace=error docs/architecture/build-8401-patches/02-readernavigation-backend-paging.patch
  ```
- **Regression Tests:** `P1`, `P2`, `P3`, `P4`

### BUILD_8401_PATCH_03: `Source/Features/Reader/ViewModel/Extensions/Reader+Content.swift`
- **Why Needed:** Bounded destination resolution for deep commentary references (e.g. `Rashi on Berakhot 15b:3:1`) was missing. `loadBackendContentInternal` treated `focusLocator != locator` as a condition for clearing explicit segment focus, resulting in lost focus on deep commentary.
- **Downstream Alternative Attempted:** Destination resolution is implemented downstream in `ReaderDestinationResolver.swift`. This 12-line hook connects the resolver to `loadBackendContentInternal`.
- **Preflight Base Hash:** `11caf78e533c0a88b8ee2d9d0472165371da6676`
- **Post-Apply Hash:** `323e9cbafaa0b98eb9894e6503c51ffbe0d867c4`
- **Scoped Rollback:**  
  ```bash
  git apply -R --whitespace=error docs/architecture/build-8401-patches/03-readercontent-bounded-destination-resolution.patch
  ```
- **Regression Tests:** `H1`, `S1`, `S2`

### BUILD_8401_PATCH_04: `Source/Features/Reader/ViewModel/Extensions/Reader+iOS.swift`
- **Why Needed:** `didSelectSearch` previously passed identical `sectionLocator` and `focusLocator`. `hasActiveSearchHighlight` ignored `focusLocator`.
- **Downstream Alternative Attempted:** Evaluation logic is fully encapsulated in downstream `ReaderSearchContextCoordinator.swift`. This hook forwards search context and evaluates active search highlighting.
- **Preflight Base Hash:** `ba2a051005cfdef04c33dd6e800295453dc47449`
- **Post-Apply Hash:** `9bebaee1a96c4293f94da9bfb557bfa37b120fdb`
- **Scoped Rollback:**  
  ```bash
  git apply -R --whitespace=error docs/architecture/build-8401-patches/04-readerios-search-context-and-selection.patch
  ```
- **Regression Tests:** `H1`, `H3`

### BUILD_8401_PATCH_05: `Source/Features/Reader/ViewModel/ReaderViewModel.swift`
- **Why Needed:** `updateContentState` prematurely cleared `searchEvent` on initial load because `searchEvent.contentId != content.id`.
- **Downstream Alternative Attempted:** Downstream `ReaderSearchContextCoordinator` maintains search context, but `ReaderViewModel.searchEvent` drives UIKit text view highlighting.
- **Preflight Base Hash:** `7ab42dbf00653317dbaaa266385729353b99d323`
- **Post-Apply Hash:** `8649733ef522300ff01b6c3d9a16f2c733f38016`
- **Scoped Rollback:**  
  ```bash
  git apply -R --whitespace=error docs/architecture/build-8401-patches/05-readerviewmodel-search-event-preservation.patch
  ```
- **Regression Tests:** `H1`, `H2`

### BUILD_8401_PATCH_06: `Source/Features/Reader/iOS/Toolbar/iOSReaderBottomToolbarView.swift`
- **Why Needed:** Adds explicit accessibility identifier `reader_clear_search_highlight_button` to the clear 'X' button for automated XCUITest verification.
- **Downstream Alternative Attempted:** None (UI element is in upstream view).
- **Preflight Base Hash:** `daa0abfe16ce0ef23366dd1a2fb71402544127be`
- **Post-Apply Hash:** `1dd68da177651a5113bb53907c08a9cfa234479f`
- **Scoped Rollback:**  
  ```bash
  git apply -R --whitespace=error docs/architecture/build-8401-patches/06-iosreaderbottomtoolbarview-clear-x.patch
  ```
- **Regression Tests:** `H3`

### BUILD_8401_PATCH_07: `Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift`
- **Why Needed:** `iOSTOCView` missed `.onChange(of: selectedId)` live tracking and rendered "אין תוכן עניינים" while asynchronous TOC loading was pending (e.g. Tractate Eruvin).
- **Downstream Alternative Attempted:** None (SwiftUI view lifecycle hook).
- **Preflight Base Hash:** `6920c2e41f163b04cebb05eb0a0bc58deacd2ad4`
- **Post-Apply Hash:** `d999083818e98305ff62551469e3ea9549f50e90`
- **Scoped Rollback:**  
  ```bash
  git apply -R --whitespace=error docs/architecture/build-8401-patches/07-iostoceview-live-tracking-and-loading-state.patch
  ```
- **Regression Tests:** `T1`, `L3`

### BUILD_8401_PATCH_08: `Source/Features/Reader/iOS/iOSReaderWorkspaceView.swift`
- **Why Needed:** `selectedTOCNode` fallback used content ID ranges which fail for backend books. Routes node lookup to downstream `TOCReadingLocationTracker`.
- **Downstream Alternative Attempted:** Routed to `TOCReadingLocationTracker.shared`.
- **Preflight Base Hash:** `1a136ebdd29f8a4c46bbf59bc4b2a5a2bdf6d4f0`
- **Post-Apply Hash:** `e415b3c2bb6f0b094ea511c57e53f19119fc9b4d`
- **Scoped Rollback:**  
  ```bash
  git apply -R --whitespace=error docs/architecture/build-8401-patches/08-iosreaderworkspaceview-toc-tracking.patch
  ```
- **Regression Tests:** `T1`, `T2`

### BUILD_8401_PATCH_09: `Source/Features/Reader/ViewModel/BookTOCViewModel.swift`
- **Why Needed:** Adds `@Observable` loading state and `findMatchingNode` method delegating to `TOCReadingLocationTracker`.
- **Downstream Alternative Attempted:** Wrapped inside `BookTOCViewModel`.
- **Preflight Base Hash:** `173bfe8a68fd2c6b46967f58e863fcd1e7db77f2`
- **Post-Apply Hash:** `171e2efab3e6605a968df72e2cf573b9e4a3c109`
- **Scoped Rollback:**  
  ```bash
  git apply -R --whitespace=error docs/architecture/build-8401-patches/09-booktocviewmodel-loading-and-matching.patch
  ```
- **Regression Tests:** `T1`, `L3`

### BUILD_8401_PATCH_10: `Source/Features/Setting/SettingsView.swift`
- **Why Needed:** Hardens backend switch to a single observable asynchronous `commitAsync` operation with error banner display. Eliminates the dangerous hazard of an automatic synchronous retry after async failure.
- **Downstream Alternative Attempted:** `BackendCoordinator.lastTransitionErrorMessage` exposes observable structured errors.
- **Preflight Base Hash:** `47aa588f3ca41fffb303e823e44958b2627e8df1`
- **Post-Apply Hash:** `9ceae28c0529d4c4ca4d2aa80b39aa030c69ea47`
- **Scoped Rollback:**  
  ```bash
  git apply -R --whitespace=error docs/architecture/build-8401-patches/10-settingsview-backend-switch-error-handling.patch
  ```
- **Regression Tests:** `B1`, `B2`

### BUILD_8401_PATCH_11: `Source/UI/iOS/Managers/iOSNavigationManager.swift`
- **Why Needed:** `DefaultTargetBackendBookResolver.resolveBook` threw `unresolvableBook` on cold catalog switches; `presentReader` passed `searchEvent: nil`. Delegated book resolution to `ChavrusaTextTargetBackendBookResolver.shared` and search context handling to `ReaderSearchContextCoordinator.shared`.
- **Downstream Alternative Attempted:** Delegated resolution to downstream resolver.
- **Preflight Base Hash:** `32046c0b2c468fa4e7b312b1474b582c751da1aa`
- **Post-Apply Hash:** `e0ec65365538eec9aa3bfcfcbdfc1a4e1d75f2ee`
- **Scoped Rollback:**  
  ```bash
  git apply -R --whitespace=error docs/architecture/build-8401-patches/11-iosnavigationmanager-cold-catalog-and-search-context.patch
  ```
- **Regression Tests:** `B1`, `B2`, `H1`

### BUILD_8401_PATCH_12: `Maktabah.xcodeproj/project.pbxproj`
- **Why Needed:** Registers the 6 new Swift helper files with PBXFileReference, PBXBuildFile, and target membership for `Maktabah-iOS` (and helper targets `Maktabah`, `Maktabah-Direct`), ensuring they are compiled during Xcode builds.
  1. `Source/ChavrusaText/Localization/TalmudHebrewAddressFormatter.swift`
  2. `Source/ChavrusaText/Navigation/ReaderBackendPagingCoordinator.swift`
  3. `Source/ChavrusaText/Navigation/ReaderDestinationResolver.swift`
  4. `Source/ChavrusaText/Navigation/TOCReadingLocationTracker.swift`
  5. `Source/ChavrusaText/Navigation/TargetBackendBookResolver.swift`
  6. `Source/ChavrusaText/Search/ReaderSearchContextCoordinator.swift`
- **Downstream Alternative Attempted:** Project uses explicit PBXFileReference registrations rather than synchronized source groups. Without this patch, Xcode builds would fail with "unresolved identifier" errors.
- **Preflight Base Hash:** `8a332467292ba7a0198be11966fa7147c0edcc42`
- **Post-Apply Hash:** `993649479e0a0a5fe0429f939e6a00c609593257`
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

All 12 proposed patches are stored as unapplied `.patch` files.  
Status for each item: **`OWNER_APPROVAL_REQUIRED`**.  
The protected upstream working tree is **100% UNMODIFIED**.  
No CI push, commit, or TestFlight release may proceed without explicit owner approval.
