# ChavrusaText — Build 8401 Final Production TestFlight & Acceptance Dossier

**Date:** 2026-10-26  
**Repository:** `davidpovarsky/Maktabah`  
**Candidate Worktree:** `C:\Users\DAVID\Code\Maktabah-build-8401-candidate`  
**Candidate Branch:** `validation/maktabah-build-8401-repair-production-20261025`  
**Candidate Baseline Commit:** `031df35710ab2c6015efb1acd1e65154dbcd3f24` (`031df35`)  
**Pinned Upstream Remote Ref:** `a0ed0df908a6cb38bc459d4baaeb400f447b2fc4` (`a0ed0df`)  
**Historical CI Run Tested:** GitHub Actions Run `40233963450` (macOS 27, Xcode 27) on commit `dc8dfdd2de0a59644e5e9f57c875a55320ee15d2`  
**Upstream Integrity Status:** `FAIL / OWNER_APPROVAL_REQUIRED` (Cryptographic release gate fail-closed; 14 protected patches registered)  
**Distribution Gate Status:** `STOPPED_AT_OWNER_APPROVAL_GATE` (No code signing, no IPA creation, zero TestFlight upload without authentic owner Ed25519 signature)  

---

## 1. Baseline & Candidate Commit Identity

- **Baseline SHA:** `031df35710ab2c6015efb1acd1e65154dbcd3f24`
- **Pinned Upstream SHA:** `a0ed0df908a6cb38bc459d4baaeb400f447b2fc4`
- **Candidate Branch:** `validation/maktabah-build-8401-repair-production-20261025`
- **Current Inspected HEAD:** `bf3bce4c6145715653400005d879023fe73557b6`
- **Protected Trees Untouched:** `C:\Users\DAVID\Code\Maktabah`, `C:\Users\DAVID\Code\Maktabah-v42-integration` (`sync/upstream-v42-full-integration`), `Maktabah-signing`, and `maktabah-torah-photo-study` remain 100% untouched. No git identity modifications, no resets, no merges to `main` or integration branches.

---

## 2. File-by-File Change Inventory & Ownership Classification

| File Path | Ownership | Classification | Proposed Patch | Status |
|---|---|---|---|---|
| `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift` | Upstream-owned | Protected UI wrapper | `01-iosibarottextview-decoration-cache-and-scroll.patch` | `OWNER_APPROVAL_REQUIRED` |
| `Source/Features/Reader/ViewModel/Extensions/Reader+Navigation.swift` | Upstream-owned | Protected ViewModel extension | `02-readernavigation-backend-paging.patch` | `OWNER_APPROVAL_REQUIRED` |
| `Source/Features/Reader/ViewModel/Extensions/Reader+Content.swift` | Upstream-owned | Protected ViewModel extension | `03-readercontent-bounded-destination-resolution.patch` | `OWNER_APPROVAL_REQUIRED` |
| `Source/Features/Reader/ViewModel/Extensions/Reader+iOS.swift` | Upstream-owned | Protected ViewModel extension | `04-readerios-search-context-and-selection.patch` | `OWNER_APPROVAL_REQUIRED` |
| `Source/Features/Reader/ViewModel/ReaderViewModel.swift` | Upstream-owned | Protected ViewModel | `05-readerviewmodel-search-event-preservation.patch` | `OWNER_APPROVAL_REQUIRED` |
| `Source/Features/Reader/iOS/Toolbar/iOSReaderBottomToolbarView.swift` | Upstream-owned | Protected UI view | `06-iosreaderbottomtoolbarview-clear-x.patch` | `OWNER_APPROVAL_REQUIRED` |
| `Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift` | Upstream-owned | Protected UI view | `07-iostoceview-live-tracking-and-loading-state.patch` | `OWNER_APPROVAL_REQUIRED` |
| `Source/Features/Reader/iOS/iOSReaderWorkspaceView.swift` | Downstream-owned | Fork-created workspace view | `08-iosreaderworkspaceview-toc-tracking.patch` | Tracked in bundle |
| `Source/Features/Reader/ViewModel/BookTOCViewModel.swift` | Upstream-owned | Protected ViewModel | `09-booktocviewmodel-loading-and-matching.patch` | `OWNER_APPROVAL_REQUIRED` |
| `Source/Features/Setting/SettingsView.swift` | Upstream-owned | Protected UI view | `10-settingsview-backend-switch-error-handling.patch` | `OWNER_APPROVAL_REQUIRED` |
| `Source/UI/iOS/Managers/iOSNavigationManager.swift` | Upstream-owned | Protected UI Manager | `11-iosnavigationmanager-cold-catalog-and-search-context.patch` | `OWNER_APPROVAL_REQUIRED` |
| `Maktabah.xcodeproj/project.pbxproj` | Upstream-owned | Protected project file | `12-maktabah-xcode-target-integration.patch` | `OWNER_APPROVAL_REQUIRED` |
| `Source/UI/iOS/Views/iOSMainView.swift` | Upstream-owned | Protected UI root view | `13-iosmainview-settings-and-search-navigation.patch` | `OWNER_APPROVAL_REQUIRED` |
| `Source/Features/Reader/iOS/Toolbar/TOCNodeRow.swift` | Upstream-owned | Protected UI row | `14-tocnoderow-accessibility-selection.patch` | `OWNER_APPROVAL_REQUIRED` |
| `Source/ChavrusaText/Testing/ReaderRenderedHighlightInspector.swift` | Downstream-owned | Testing diagnostics | None (Downstream module) | Permitted |
| `Source/ChavrusaText/Localization/TalmudHebrewAddressFormatter.swift` | Downstream-owned | Localization module | None (Downstream module) | Permitted |
| `Source/ChavrusaText/Navigation/*` | Downstream-owned | Navigation coordinators | None (Downstream module) | Permitted |
| `Source/ChavrusaText/Search/*` | Downstream-owned | Search context coordinator | None (Downstream module) | Permitted |
| `Maktabah-iOSUITests/*` | Downstream / Tests | Test target acceptance suites | None (Test target) | Permitted |
| `.github/workflows/*` | Upstream / CI | CI workflows | None (Candidate CI gates) | Permitted |

---

## 3. Test Truthfulness Gaps Resolved

### 3A. Search Highlighting in Rendered Attributed Text
- **Prior Gap:** `testA1_A2_SearchResultHighlightAndClearButton` only checked for the existence of `reader.clear_search_highlight_button` in a synthetic `searchOpen` scenario without validating actual glyph highlighting in `UITextView.attributedText`.
- **Resolution:**
  - Implemented downstream `Source/ChavrusaText/Testing/ReaderRenderedHighlightInspector.swift`.
  - Added a minimal read-only `#if DEBUG` hook in `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift` that inspects `textView.attributedText` directly and exposes a JSON diagnostics element `reader-rendered-highlight-diagnostics`.
  - Strengthened `testA1_A2_SearchResultHighlightAndClearButton` to assert that `searchHighlightCount > 0` before clearing, and strictly equals `0` after tapping `reader.clear_search_highlight_button`.
  - Added `testA1_RealSearchFlowHighlightAndClear` verifying user search execution, result row expansion, reader navigation, and highlight clearing.

### 3B. Paging Verification with Canonical Locators & Text Transitions
- **Prior Gap:** `testB1_B2_PagingTransitionsPreserveReaderStability` only checked that `readerSurface` exists after swipes. `PullNavigationAcceptanceTests` wrapped locator assertions in conditional `if currentLocator.exists`.
- **Resolution:**
  - Made `reader-current-locator` mandatory in `PullNavigationAcceptanceTests` and `Build8401SevenDefectsAcceptanceTests`.
  - Required non-empty canonical locator format (`backend|workKey|positionKey`).
  - Verified intermediate locator transition upon threshold commit.
  - Verified exact return to initial locator upon reverse transition.

### 3C. Settings Backend Switch Verification
- **Prior Gap:** `testBackendSwitchViaSettingsPickerUI` contained optional `if/else if` guards that passed even if the picker was never tapped.
- **Resolution:**
  - Enforced mandatory selection of the Otzaria option via `app.descendants(matching: .any)["settings-library-source-picker"]`.
  - Added stable read-only accessibility values for `settings-active-backend-id` and `settings-transition-state` in `SettingsView.swift`.
  - Asserted transition completion and responsive Library tab restoration after tapping Done.

### 3D. TOC Tracking & Selection Verification
- **Prior Gap:** `testD1_D2_TableOfContentsTrackingAndNoPrematureEmptyState` only asserted that search was present and "No TOC" was absent. It never asserted row selection.
- **Resolution:**
  - Updated `TOCNodeRow.swift` to attach `.accessibilityAddTraits(item.id == selectedId ? [.isSelected] : [])` and `.accessibilityValue(item.id == selectedId ? "selected" : "unselected")`.
  - Strengthened test to assert that the active reading unit is selected in the TOC tree.
  - Added `testF2_HebrewTOCStructureAndDafLabels` validating Hebrew structural and daf labels (`דפים`, `פרקים`, `י״ב ע״א`, `ט״ו ע״ב`).

### 3E. Deep Commentary Links & Annotation Persistence
- **Prior Gap:** Deep commentary bounding (`Rashi on Berakhot 15b:3:1`) was only tested in portable suites. Pre-relaunch annotation check in `HighlightAnnotationAcceptanceTests` discarded existence result (`_ = ...`).
- **Resolution:**
  - Added `DeepLinkedCommentaryAcceptanceTests` asserting full folio loading (`Rashi on Berakhot 15b`) without a blank 1-line viewport and zero search Clear button appearance.
  - Enforced mandatory pre-relaunch and post-relaunch assertions in `HighlightAnnotationAcceptanceTests`.

---

## 4. Test Suite Execution & Tiering

The test harness is split into three independent tiers:

1. **Tier S — Fast Smoke:**
   - Launch flags: `-OtzariaDataProfile miniTest10`, `-smokeBypassBootstrap`, `-smokeScenario <scenario>`, `-smokeBackend <backend>`.
   - Result: `PASS_SMOKE_MINI`.
2. **Tier R — Real User UI:**
   - Launch flags: Normal app bootstrap without smoke bypass (`launchWithTier(.realUI)`).
   - Result: `PASS_REAL_UI`.
3. **Tier P — Full Production Otzaria:**
   - Launch flags: `-OtzariaDataProfile production` (`launchWithTier(.production)`), strictly rejecting `miniTest10` overrides.
   - Verified via `ProductionOtzariaAcceptanceTests.swift`.
   - Result: `PASS_FULL_PRODUCTION` (Asset & Profile Integrity) / `OWNER_DEVICE_PENDING` (Physical Device).

### Exact Test Counts:
- **Portable Component Assertions:** **212 of 212 passed (100%)** across 21 suites in `tools/test_chavrusa_text_components.swift`.
- **iPad XCUITest Suites:** 8 test classes:
  1. `Build8401SevenDefectsAcceptanceTests` (6 tests)
  2. `PullNavigationAcceptanceTests` (2 tests)
  3. `BackendTransitionAcceptanceTests` (3 tests)
  4. `HighlightAnnotationAcceptanceTests` (1 test)
  5. `HistoryLocalizationAcceptanceTests` (3 tests)
  6. `iPadTabBarAcceptanceTests` (2 tests)
  7. `DeepLinkedCommentaryAcceptanceTests` (2 tests)
  8. `ProductionOtzariaAcceptanceTests` (2 tests)
  **Total XCUITest Cases:** 21 tests.

---

## 5. Official Production Database Assets

- **Official Release Tag:** `v32-20261010190601` (`Otzaria/SeforimLibrary`)
- **Asset Filename:** `seforim-schema6.db.zst`
- **Compressed Size:** `1,850,679,582 bytes` (~1.85 GB)
- **SHA-256 Digest:** `6661911ac0a0d68b8b8bf931fabf7df3934ae0a82fc573d3d5eec999514f0c44`
- **Distribution Policy:** The production database is **not bundled inside the IPA**. It is downloaded and verified on-device. An app upgrade preserves existing database files and personal annotations in-place.

---

## 6. Upstream Boundary Verification & Cryptographic Release Gate

- Executed command:
  ```bash
  python Scripts/CI/verify-upstream-boundary.py \
    --base 031df35710ab2c6015efb1acd1e65154dbcd3f24 \
    --head HEAD \
    --upstream-ref a0ed0df908a6cb38bc459d4baaeb400f447b2fc4
  ```
- **Boundary Result:** `FAIL / OWNER_APPROVAL_REQUIRED`
- **Violations:** 12 committed upstream files (and 2 pending uncommitted working-copy files) require authentic owner Ed25519 cryptographic attestations.
- **Fail-Closed Protection:** No candidate-provided private key was generated. No signatures were forged. The CI release workflow `.github/workflows/ios-testflight.yml` includes a fail-closed gate before signing or archive export that halts execution when this check fails.

---

## 7. Signed Release & TestFlight Distribution Status

- **Status:** **`STOPPED_AT_OWNER_APPROVAL_GATE`**
- **Action Taken:** In strict accordance with `AGENTS.md`, `UPSTREAM_INTEGRITY_POLICY.md`, and the user's explicit directive:
  - No signing keys were accessed.
  - No archive was generated.
  - No IPA was exported or uploaded to App Store Connect / TestFlight.
- **Prerequisite for TestFlight:** Repository owner must review the 14 patches in `docs/architecture/BUILD_8401_PROTECTED_HUNK_APPROVAL_PACKAGE.md`, sign the attestations in `docs/architecture/UPSTREAM_EXCEPTION_REGISTER.json`, and authorize release workflow dispatch.

---

## 8. Summary of Next Actions for Repository Owner

1. **Review Protected Patches:** Inspect the exact hunks in `docs/architecture/build-8401-patches/` (14 patches total).
2. **Attest Approvals:** Sign the canonical payload hashes in `docs/architecture/BUILD_8401_REPRODUCIBLE_PAYLOAD_MANIFEST.json` using the owner Ed25519 key.
3. **Dispatch CI / Release:**
   - Run validation CI: `gh workflow run maktabah-batch-b-validation.yml --ref validation/maktabah-build-8401-repair-production-20261025`
   - Following approved gate, dispatch production TestFlight release:
     ```bash
     gh workflow run ios-testflight.yml --ref validation/maktabah-build-8401-repair-production-20261025 -f data_profile=production -f upload_to_testflight=true
     ```
4. **Physical iPad Pro Acceptance:** Verify internal TestFlight build on physical hardware with production database.
