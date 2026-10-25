# BUILD 8401: PROTECTED HUNK OWNER APPROVAL PACKAGE (PASS 5 RECONCILED)

**Date:** 2026-10-26  
**Baseline Git SHAs Verified:**
- Baseline Candidate Commit: `031df35710ab2c6015efb1acd1e65154dbcd3f24` (`031df35`)
- Pinned Upstream Remote Ref: `a0ed0df908a6cb38bc459d4baaeb400f447b2fc4` (`a0ed0df`)
- Candidate Validation Branch: `validation/maktabah-build-8401-repair-production-20261025`
- Protected Upstream Branches (`main`, `Maktabah-v42-integration`): **`PROTECTED_TREES_UNTOUCHED`**
- Approval Gate Status: **`GATE_OPEN_OWNER_APPROVAL_REQUIRED`** (Fail-closed: no self-approval, zero faked signatures)

---

## 1. Executive Summary & Policy Authority

Per `docs/architecture/UPSTREAM_INTEGRITY_POLICY.md` (canonical owner directive 2026-10-22):
- All Maktabah upstream-owned files, project file (`Maktabah.xcodeproj/project.pbxproj`), and CI workflows are **READ-ONLY for downstream feature work by default**.
- Any unavoidable edit to protected upstream-owned files requires explicit owner permission for its exact file and hunk.
- **Environment Distinction**:
  1. **Candidate Validation Branch** (`validation/maktabah-build-8401-repair-production-20261025`): Operates in an isolated worktree (`C:\Users\DAVID\Code\Maktabah-build-8401-candidate`) where the proposed patches are applied to permit clean compilation, local Swift test suites (208 assertions across 20 suites), and end-to-end iPad Simulator XCUITest execution in GitHub Actions CI.
  2. **Protected Upstream Branches** (`main`, `Maktabah-v42-integration`): Remain **100% untouched, unapplied, and unmerged**. No candidate branch commit will be merged to `main` without explicit owner approval and attestation.
- The **14 patches** below are stored as reproducible standalone files in `docs/architecture/build-8401-patches/`.
- All core logic is implemented in downstream-owned modules (`Source/ChavrusaText/`, `Source/LibraryBackend/`, `Source/Sefaria/`, `Source/Otzaria/`, `Source/ZayitSearch/`).

---

## 2. Complete Protected Seams & Patch Manifest (14 Proposals)

| Patch ID | Protected File Path | Target Defect / Purpose | Patch File | Size (Bytes) | SHA-256 Digest | Base Blob SHA | Status |
|:---:|---|:---:|---|:---:|---|:---:|:---:|
| **BUILD_8401_PATCH_01** | `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift` | Decorates search highlights, preserves selection range, and exposes read-only #if DEBUG diagnostics snapshot | `01-iosibarottextview-decoration-cache-and-scroll.patch` | 3,345 | `fd59a96009a07b2113ae8bd67dd777a582cc780d30f95314c2fc0fae14b714be` | `fa5430a8ee` | `OWNER_APPROVAL_REQUIRED` |
| **BUILD_8401_PATCH_02** | `Source/Features/Reader/ViewModel/Extensions/Reader+Navigation.swift` | Delegates reader paging to ReaderBackendPagingCoordinator and preserves scroll target | `02-readernavigation-backend-paging.patch` | 2,621 | `34b40f8baea61c7f2d05c1c051a10e3aebba740ec4057bad0bced76a48189d52` | `8584cc718d` | `OWNER_APPROVAL_REQUIRED` |
| **BUILD_8401_PATCH_03** | `Source/Features/Reader/ViewModel/Extensions/Reader+Content.swift` | Enforces generation tokens and bounded reading destination resolution to eliminate stale async overwrite races | `03-readercontent-bounded-destination-resolution.patch` | 6,080 | `5cd5923ac01179af1a46e58429f843c688bd1e4024b49a42c072f42775e67bbe` | `11caf78e53` | `OWNER_APPROVAL_REQUIRED` |
| **BUILD_8401_PATCH_04** | `Source/Features/Reader/ViewModel/Extensions/Reader+iOS.swift` | Preserves search context and active highlight terms across iOS reader state updates | `04-readerios-search-context-and-selection.patch` | 1,760 | `28a36e0bd79ffae0c081c8897318a3081ea4e33c604673dc11f9478a4d774f52` | `ba2a051005` | `OWNER_APPROVAL_REQUIRED` |
| **BUILD_8401_PATCH_05** | `Source/Features/Reader/ViewModel/ReaderViewModel.swift` | Maintains search event lifecycle and prevents premature highlight discarding | `05-readerviewmodel-search-event-preservation.patch` | 2,158 | `a3da7d01ff3be86d13c0503e2d7555c2527207f760e273209191e935f1598ee8` | `7ab42dbf00` | `OWNER_APPROVAL_REQUIRED` |
| **BUILD_8401_PATCH_06** | `Source/Features/Reader/iOS/Toolbar/iOSReaderBottomToolbarView.swift` | Renders Clear 'X' button next to search button when active search highlight exists | `06-iosreaderbottomtoolbarview-clear-x.patch` | 706 | `5ea782f34f538f1eeffed9415b8f591a436037b5b66d09bd0ad001513372c58a` | `daa0abfe16` | `OWNER_APPROVAL_REQUIRED` |
| **BUILD_8401_PATCH_07** | `Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift` | Provides live location tracking, auto-scroll to selected node, and eliminates premature empty states | `07-iostoceview-live-tracking-and-loading-state.patch` | 1,488 | `11d17f08d4fce0a4ec6d21e0e7713213901e759aba1c2d762602af791339be8e` | `6920c2e41f` | `OWNER_APPROVAL_REQUIRED` |
| **BUILD_8401_PATCH_08** | `Source/Features/Reader/iOS/iOSReaderWorkspaceView.swift` | Propagates current locator and canonical reader metadata to TOC and accessibility overlay | `08-iosreaderworkspaceview-toc-tracking.patch` | 3,781 | `3e0d0be43bf47ff1ece26de42e43dd630f202d32cf996bdb6d35ef4fdff2b362` | `1a136ebdd2` | `OWNER_APPROVAL_REQUIRED` |
| **BUILD_8401_PATCH_09** | `Source/Features/Reader/ViewModel/BookTOCViewModel.swift` | Structural TOC matching eliminating false-positive prefix hits and handling asynchronous loading states | `09-booktocviewmodel-loading-and-matching.patch` | 4,648 | `f48d826698cba715d8b0122bc49f3eae43d0b51b8436ee0c7ac1509e04ad24a4` | `173bfe8a68` | `OWNER_APPROVAL_REQUIRED` |
| **BUILD_8401_PATCH_10** | `Source/Features/Setting/SettingsView.swift` | Async backend switch commit, transition progress, and stable accessibility indicators | `10-settingsview-backend-switch-error-handling.patch` | 3,055 | `6032922fd8075e96487c9087be75d92552b2a11f7de51c389bcfb38fd21a9a62` | `47aa588f3c` | `OWNER_APPROVAL_REQUIRED` |
| **BUILD_8401_PATCH_11** | `Source/UI/iOS/Managers/iOSNavigationManager.swift` | Prevents cold catalog failure and preserves search context across openBook calls | `11-iosnavigationmanager-cold-catalog-and-search-context.patch` | 3,373 | `90a227d7ff6b7ee3b88dbd71ec5cb073a7c267578be9ea90094a304775b4b752` | `32046c0b2c` | `OWNER_APPROVAL_REQUIRED` |
| **BUILD_8401_PATCH_12** | `Maktabah.xcodeproj/project.pbxproj` | Registers ChavrusaText component files in iOS, macOS, and test build phases | `12-maktabah-xcode-target-integration.patch` | 12,958 | `7c53ed58272d4753d07201d49eeb5700bacd8d082d4289bd0c95ced26641be44` | `8a33246729` | `OWNER_APPROVAL_REQUIRED` |
| **BUILD_8401_PATCH_13** | `Source/UI/iOS/Views/iOSMainView.swift` | Accessibility identifiers for settings buttons and tab switching in searchOpen scenario | `13-iosmainview-settings-and-search-navigation.patch` | 1,386 | `b6dc9ee8b2ba4983e332a965eab545a7eb2e3424f77d4a7cbd8f02b798f8784f` | `14475c6a84` | `OWNER_APPROVAL_REQUIRED` |
| **BUILD_8401_PATCH_14** | `Source/Features/Reader/iOS/Toolbar/TOCNodeRow.swift` | Exposes genuine .isSelected trait and value='selected' on the active TOC row | `14-tocnoderow-accessibility-selection.patch` | 564 | `b445028df943660eab3ad1bfd9f23176fae70be41025db21e7242413d94a3563` | `357400e811` | `OWNER_APPROVAL_REQUIRED` |

---

## 3. Detailed Hunk Justifications, Alternatives & Scoped Rollback

### BUILD_8401_PATCH_01: `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift`
- **Why Needed:** `RenderCacheKey` previously omitted `selectedSegmentRange` and `highlightTerms`. When a user navigates to a search hit, `lastRenderKey == currentKey` matched and stale unhighlighted content was returned from cache. User scroll clearing was falsely triggered by programmatic scroll. In addition, read-only `#if DEBUG` diagnostics snapshot `ReaderRenderedHighlightInspector.updateDiagnostics` is attached to expose actual rendered text attributed highlights without exposing user note text.
- **Downstream Alternative Attempted:** External repainting via view modifiers failed because `iOSIbarotTextView` manages its own internal `UITextView.attributedText` cache asynchronously. Adding decoration inputs to `RenderCacheKey` and the single `#if DEBUG` diagnostics hook is the minimal connection point.
- **Scoped Rollback:** `git apply -R --whitespace=error docs/architecture/build-8401-patches/01-iosibarottextview-decoration-cache-and-scroll.patch`

### BUILD_8401_PATCH_02: `Source/Features/Reader/ViewModel/Extensions/Reader+Navigation.swift`
- **Why Needed:** `goToNextPage()` and `goToPrevPage()` directly called `BookConnection.getNextPage`, which returns `nil` for Sefaria books (breaking pull-to-navigate completely) and jumps Otzaria books back to the beginning on first pull from the middle of a work.
- **Downstream Alternative Attempted:** Intercepting navigation outside `ReaderViewModel` was rejected because toolbar buttons and pull-to-navigate share these exact methods. Paging logic is delegated to downstream `ReaderBackendPagingCoordinator`.
- **Scoped Rollback:** `git apply -R --whitespace=error docs/architecture/build-8401-patches/02-readernavigation-backend-paging.patch`

### BUILD_8401_PATCH_03: `Source/Features/Reader/ViewModel/Extensions/Reader+Content.swift`
- **Why Needed:** Bounded destination resolution for deep commentary references (e.g. `Rashi on Berakhot 15b:3:1`) was missing. Async race conditions allowed stale section loading tasks to overwrite newer active pages when navigating within the same book (`workKey` shared across pages). Integrated `ReaderContentLoadCoordinator` token validation.
- **Downstream Alternative Attempted:** View-level cancellation in SwiftUI `.task` failed because fast consecutive taps queued multiple concurrent engine calls. Token generation must be validated inside the ViewModel before updating state.
- **Scoped Rollback:** `git apply -R --whitespace=error docs/architecture/build-8401-patches/03-readercontent-bounded-destination-resolution.patch`

### BUILD_8401_PATCH_04: `Source/Features/Reader/ViewModel/Extensions/Reader+iOS.swift`
- **Why Needed:** When opening a search hit, `ReaderViewModel.searchEvent` was populated but `ReaderViewModel.highlightTerms` was cleared, causing search highlights to vanish upon rendering.
- **Downstream Alternative Attempted:** Setting highlight terms directly in the view layer was rejected because navigation transitions trigger ViewModel state resets.
- **Scoped Rollback:** `git apply -R --whitespace=error docs/architecture/build-8401-patches/04-readerios-search-context-and-selection.patch`

### BUILD_8401_PATCH_05: `Source/Features/Reader/ViewModel/ReaderViewModel.swift`
- **Why Needed:** In `loadContent(id:)`, `self.searchEvent = nil` was unconditionally called at the end of content loading, clearing active search highlights immediately after displaying the target section.
- **Downstream Alternative Attempted:** Intercepting in `iOSCustomIbarotTextView` failed because ViewModel cleared the search event before layout completed.
- **Scoped Rollback:** `git apply -R --whitespace=error docs/architecture/build-8401-patches/05-readerviewmodel-search-event-preservation.patch`

### BUILD_8401_PATCH_06: `Source/Features/Reader/iOS/Toolbar/iOSReaderBottomToolbarView.swift`
- **Why Needed:** The Clear 'X' button (`reader.clear_search_highlight_button`) was missing from the bottom toolbar when an active search highlight was present.
- **Downstream Alternative Attempted:** Placing the button in an overlay obscured reader text and broke toolbar layout. Adding it conditionally next to the search button in `iOSReaderBottomToolbarView` adheres to HIG and preserves layout.
- **Scoped Rollback:** `git apply -R --whitespace=error docs/architecture/build-8401-patches/06-iosreaderbottomtoolbarview-clear-x.patch`

### BUILD_8401_PATCH_07: `Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift`
- **Why Needed:** When a user scrolled through a book, the TOC did not update its selected row to track reading location, displayed a premature 'No Table of Contents' while loading, and failed to auto-scroll the selected node into view.
- **Downstream Alternative Attempted:** External scroll proxy failed because `ThemeList` layout is encapsulated in `iOSTOCView`.
- **Scoped Rollback:** `git apply -R --whitespace=error docs/architecture/build-8401-patches/07-iostoceview-live-tracking-and-loading-state.patch`

### BUILD_8401_PATCH_08: `Source/Features/Reader/iOS/iOSReaderWorkspaceView.swift`
- **Why Needed:** Reader workspace required stable, non-empty canonical locator and visible header title accessibility identifiers for XCUITest automation, and live propagation of current locator to the TOC sheet.
- **Downstream Alternative Attempted:** This file is fork-created / downstream-owned, but tracked in the patch package for complete reproducibility.
- **Scoped Rollback:** `git apply -R --whitespace=error docs/architecture/build-8401-patches/08-iosreaderworkspaceview-toc-tracking.patch`

### BUILD_8401_PATCH_09: `Source/Features/Reader/ViewModel/BookTOCViewModel.swift`
- **Why Needed:** `findClosestRange(for:textPosition:)` performed raw string prefix matching, falsely matching `Genesis 10:1` against `Genesis 1`. In addition, asynchronous TOC loading states produced race conditions. Delegated to `TOCReadingLocationTracker`.
- **Downstream Alternative Attempted:** Modifying TOC tree data was rejected to prevent data corruption. Structural matching is encapsulated downstream.
- **Scoped Rollback:** `git apply -R --whitespace=error docs/architecture/build-8401-patches/09-booktocviewmodel-loading-and-matching.patch`

### BUILD_8401_PATCH_10: `Source/Features/Setting/SettingsView.swift`
- **Why Needed:** Switching library backends via the settings picker previously performed synchronous coordinator commits that deadlocked or raced with active readers, and lacked accessibility identifiers for automated validation.
- **Downstream Alternative Attempted:** Custom settings view was rejected because `SettingsView` is the user-facing settings screen. Added `commitAsync` and `#if DEBUG` active backend accessibility elements.
- **Scoped Rollback:** `git apply -R --whitespace=error docs/architecture/build-8401-patches/10-settingsview-backend-switch-error-handling.patch`

### BUILD_8401_PATCH_11: `Source/UI/iOS/Managers/iOSNavigationManager.swift`
- **Why Needed:** Opening books from cold start before catalog indexing completed threw unhandled errors, and search hits opened via navigation manager lost their search context.
- **Downstream Alternative Attempted:** Wrapping call sites failed because deep links bypass the UI wrapper. Centralizing in `iOSNavigationManager` guarantees safe book resolution.
- **Scoped Rollback:** `git apply -R --whitespace=error docs/architecture/build-8401-patches/11-iosnavigationmanager-cold-catalog-and-search-context.patch`

### BUILD_8401_PATCH_12: `Maktabah.xcodeproj/project.pbxproj`
- **Why Needed:** Registers the 11 ChavrusaText component files into the Xcode project build phases (`Maktabah (iOS)`, `Maktabah (macOS)`, and `MaktabahTests`).
- **Downstream Alternative Attempted:** SwiftPM package was considered, but Xcode project targets require direct source membership to maintain XCFramework and precompiled bridging dependencies.
- **Scoped Rollback:** `git apply -R --whitespace=error docs/architecture/build-8401-patches/12-maktabah-xcode-target-integration.patch`

### BUILD_8401_PATCH_13: `Source/UI/iOS/Views/iOSMainView.swift`
- **Why Needed:** Reconciles the missing accessibility identifiers (`settings-done-button` and `main-settings-button`) on settings buttons and ensures `selectedTab = .viewer` in DEBUG `searchOpen` smoke fixture.
- **Downstream Alternative Attempted:** View modifiers outside `iOSMainView` cannot attach identifiers to toolbar navigation items.
- **Scoped Rollback:** `git apply -R --whitespace=error docs/architecture/build-8401-patches/13-iosmainview-settings-and-search-navigation.patch`

### BUILD_8401_PATCH_14: `Source/Features/Reader/iOS/Toolbar/TOCNodeRow.swift`
- **Why Needed:** Exposes genuine `.isSelected` accessibility trait and `value="selected"` on the active TOC row when `item.id == selectedId`, allowing truthful XCUITest validation of TOC tracking.
- **Downstream Alternative Attempted:** Injecting selection in parent view failed because accessibility traits must be attached to the interactive button element itself.
- **Scoped Rollback:** `git apply -R --whitespace=error docs/architecture/build-8401-patches/14-tocnoderow-accessibility-selection.patch`

---

## 4. Verification & Attestation Instructions for Repository Owner

To review and cryptographically approve this package:
1. Verify the diffs in `docs/architecture/build-8401-patches/*.patch`.
2. Generate Ed25519 signatures using the authorized owner private key over the canonical payload bytes:
   ```bash
   python3 Scripts/CI/sign-approval.py --manifest docs/architecture/BUILD_8401_REPRODUCIBLE_PAYLOAD_MANIFEST.json
   ```
3. Commit the signed attestations to `docs/architecture/UPSTREAM_EXCEPTION_REGISTER.json`.
4. Run `Scripts/CI/verify-upstream-boundary.py` to confirm that the release gate passes.
