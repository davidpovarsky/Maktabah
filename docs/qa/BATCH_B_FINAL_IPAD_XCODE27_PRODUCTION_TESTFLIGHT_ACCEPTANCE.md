# MAKTABAH / CHAVRUSATEXT — BATCH B FINAL iPAD QA, XCODE 27 & PRODUCTION TESTFLIGHT ACCEPTANCE REPORT

**Date:** 2026-10-25  
**Candidate Branch:** [`validation/maktabah-batch-b-xcode27-20261025`](https://github.com/davidpovarsky/Maktabah/tree/validation/maktabah-batch-b-xcode27-20261025)  
**Release Candidate Branch:** [`rc/maktabah-batch-b-xcode27-20261025`](https://github.com/davidpovarsky/Maktabah/tree/rc/maktabah-batch-b-xcode27-20261025)  
**Release Candidate Commit SHA:** `031df35198ec5c26b901a1c9779df5156a0050ae`  
**Baseline Commit:** `c8defbf812d34dd22ea1b7b63b1a356c0e96fa8f`  
**Pinned Upstream Remote Ref:** `a0ed0df908a6cb38bc459d4baaeb400f447b2fc4`  
**Target Runner / Toolchain:** macOS 27.0 (arm64 Apple Silicon) / Xcode 27.1 / iOS 27.1 SDK  
**Test Simulator Target:** `iPad Pro 13-inch (M5)` (iOS 27.0)  
**Owner Integration Worktree:** `C:\Users\DAVID\Code\Maktabah-v42-integration` on `sync/upstream-v42-full-integration` (untouched, unmodified)  
**iPad Simulator QA Run:** [Run 40178179484](https://github.com/davidpovarsky/Maktabah/actions/runs/40178179484)  
**Production TestFlight Release Run:** [Run 40179808443](https://github.com/davidpovarsky/Maktabah/actions/runs/40179808443)

---

## 1. Executive Summary & Quality Gates Matrix

| Gate ID | Quality Gate | Requirement | Status | Evidence / Notes |
|:---:|---|---|:---:|---|
| **GATE-1** | `CODE_BUILD` | Clean compilation of Maktabah-iOS for Debug iphonesimulator & Release iphoneos | **PASS** | Debug Simulator and Release iphoneos device builds clean on Xcode 27.1 (4m56s); zero compiler warnings in new/repaired modules. |
| **GATE-2** | `PORTABLE_TESTS` | 100% pass on standalone Foundation-portable assertions in `tools/test_chavrusa_text_components.swift` | **PASS** | **119 of 119 passed (0 failures)** across 9 comprehensive test suites on Windows Swift and on macOS 27 CI runner. |
| **GATE-3** | `XCODE_TESTS` | Real XCTest/XCUITest target registered in `Maktabah.xcodeproj` and `Maktabah-iOS.xcscheme`; build-for-testing without `continue-on-error` or `\|\| true` | **PASS** | `Maktabah-iOSUITests` target and `<Testables>` reference executed with fail-closed enforcement; full test execution succeeded in 18m45s. |
| **GATE-4** | `IPAD_UI` | Genuine iPad Pro 13-inch simulator execution asserting all 4 regressions (Tab Bar, Pull Nav, Annotations, History Localization) | **PASS** | **10 of 10 UI tests PASSED (0 failures)** on `iPad Pro 13-inch (M5)` under iOS 27 runtime in 351.464s. |
| **GATE-5** | `SESSION_RESTORE` | Two-phase transactional switch with `retainedBook`; zero tab dropping or partial restore | **PASS** | Implemented `retainedBook: (any AnyObject & Sendable)?` in `BackendCoordinator.swift` & `iOSNavigationManager.swift`. All session restoration assertions pass. |
| **GATE-6** | `TRUSTED_APPROVAL` | Reconcile exact Git blob SHAs & canonical diff digests in `UPSTREAM_EXCEPTION_REGISTER.json` and `BATCH_B_PAYLOAD_MANIFEST.json` | **VERIFIED_RECONCILED** | All 8 exception blobs and patch digests mechanically verified against Git tree; 23/23 boundary guard fixtures passed; status maintained as `OWNER_APPROVAL_REQUIRED` without faked keys. |
| **GATE-7** | `RELEASE_SIGNING` | Apple distribution certificate, provisioning profile, and entitlements validated for release candidate | **PASS** | Signed using Apple Distribution Certificate (`NA6HPWARQ2`) and App Store Provisioning Profile; `get-task-allow: false`, `aps-environment: production`, `beta-reports-active: true`. |
| **GATE-8** | `IPA_PRODUCTION_PROFILE` | Mandatory data profile `production` using `seforim.db.zst` (no `miniTest10` fixture in release IPA) | **PASS** | `OtzariaDefaultDataProfile == production` verified in `Info.plist`; no embedded SQLite database files. |
| **GATE-9** | `TESTFLIGHT_UPLOAD` | App Store Connect delivery of signed production IPA | **PASS** | Exported signed IPA `ChavrusaText-production-8401.ipa` delivered via `altool` without errors. Delivery UUID: `aaad950b-80ef-4a05-aa09-a1b6a3f6d1c3`. |
| **GATE-10** | `APP_STORE_CONNECT_PROCESSING` | App Store Connect build processing and availability for internal testers | **PASS (VALID)** | Apple App Store Connect processing completed successfully; build status verified as **`VALID`** (App ID: `6809559414`, Build: `1.0.0 (8401)`). |

---

## 2. Priority A: Real iPad XCTest & UI Acceptance Suite (10 of 10 Passed)

### A1. Target & Runner Configuration
- Dedicated native UI test target `Maktabah-iOSUITests` (`F30578012FA46222005732C6`) registered in `Maktabah.xcodeproj`.
- Configured `<Testables>` reference in `Maktabah-iOS.xcscheme`.
- Automated dynamic simulator discovery targeting `iPad Pro 13-inch (M5)` via `xcrun simctl list devices available -j`.
- Booted device and executed tests using `xcodebuild test-without-building` with ad-hoc codesigning (`CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=YES`).
- Zero tolerance for masking flags: no `continue-on-error`, no `|| true`.

### A2. Test Suite Execution Results (Run 40178179484)
```
Test Suite 'Maktabah-iOSUITests.xctest' passed at 2026-10-25 09:09:46.795.
Executed 10 tests, with 0 failures (0 unexpected) in 351.464 (351.510) seconds
```

| Test Class | Test Case | Duration | Status | Verified Functionality |
|---|---|:---:|:---:|---|
| `BackendTransitionAcceptanceTests` | `testBackendSwitchRegressionScenario` | 45.610s | **PASS** | Synthetic Otzaria ↔ Sefaria switch preserves tabs, recovers library, and presents valid viewer. |
| `BackendTransitionAcceptanceTests` | `testRoundTripBackendSwitchPersistsTabs` | 62.018s | **PASS** | Launch in Sefaria → Switch to Otzaria → Switch back to Sefaria preserves active reader surface. |
| `HighlightAnnotationAcceptanceTests` | `testAnnotationCreationPersistenceAndRelaunch` | 29.416s | **PASS** | Creates Hebrew annotation note, terminates app, and asserts note persists across relaunch. |
| `HistoryLocalizationAcceptanceTests` | `testHistoryTabLocalizedInEnglishWithLTRLayout` | 46.794s | **PASS** | English locale: asserts History tab is "History", Library is "Library", Hebrew label absent. |
| `HistoryLocalizationAcceptanceTests` | `testHistoryTabLocalizedInHebrewWithRTLLayout` | 36.145s | **PASS** | Hebrew locale: asserts History tab is "היסטוריה", Library tab is "ספרייה", validates RTL geometry. |
| `HistoryLocalizationAcceptanceTests` | `testSelectedTabRestorationAfterRelaunch` | 40.856s | **PASS** | Switches to History tab, terminates app, relaunches and asserts History tab restored. |
| `PullNavigationAcceptanceTests` | `testPullNavigationCommitBothDirectionsWithoutDuplicates` | 25.345s | **PASS** | Pulls down to previous chapter and up to next chapter; commits transition cleanly without duplicates. |
| `PullNavigationAcceptanceTests` | `testPullNavigationRetreatCancelDoesNotChangeContent` | 22.879s | **PASS** | Sub-threshold drag and retreat; asserts content and header title remain unchanged. |
| `iPadTabBarAcceptanceTests` | `testiPadTabBarPersistsAcrossTOCAndInspectorTransitions` | 24.005s | **PASS** | iPad Tab Bar remains visible and accessible across opening/closing Table of Contents and Study Inspector. |
| `iPadTabBarAcceptanceTests` | `testiPadTabBarVisibleAndHittableInReader` | 18.398s | **PASS** | Asserts Library and History tab buttons exist with valid geometry alongside active reader surface. |

---

## 3. Priority B: Atomic Two-Phase Backend Restoration

### B1. Problem & Architecture
- **Defect:** `publishTransition` previously called throwing `targetBackendResolver.resolveBook` in a loop; dropped tabs on resolution errors and wrote partial state to disk.
- **Repair:**
  1. Staged tabs carry pre-resolved, retained books: `retainedBook: (any AnyObject & Sendable)?` in `PreparedBackendTransition.StagedTabSession`.
  2. Single-phase resolution in `prepareTransition`; deterministic, non-throwing extraction in `publishTransition`.
  3. Atomic verification (`allSucceeded && restoredTabs.count == activeTransition.stagedTabs.count`); rolls back to prior state if any mismatch occurs.

### B2. Assertions
- `tools/test_chavrusa_text_components.swift`: 119/119 assertions passed.
- Both backend transition acceptance tests passed on genuine iPad simulator.

---

## 4. Priority C: Protected Approvals & Boundary Reconciliation

### C1. Reconciled Hashes & Register Status
All 8 registered exceptions in `docs/architecture/UPSTREAM_EXCEPTION_REGISTER.json` have exact blob SHAs and canonical diff digests matching the Git tree:

| Patch ID | Target Path | Git Blob SHA | Patch Diff SHA-256 | Status |
|---|---|---|---|---|
| `BATCH_B_PATCH_01` | `Maktabah.xcodeproj/project.pbxproj` | `8a332467292b...` | `7534045587b2...` | `OWNER_APPROVAL_REQUIRED` |
| `BATCH_B_PATCH_02` | `Source/Features/Reader/iOS/iOSReaderView.swift` | `3da6586c0241...` | `97abbfe5d548...` | `OWNER_APPROVAL_REQUIRED` |
| `BATCH_B_PATCH_03` | `Source/UI/iOS/Views/iOSMainView.swift` | `14475c6a8454...` | `563ad9e20188...` | `OWNER_APPROVAL_REQUIRED` |
| `BATCH_B_PATCH_04_05` | `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift` | `fa5430a8ee65...` | `ce92efaf0554...` | `OWNER_APPROVAL_REQUIRED` |
| `BATCH_B_PATCH_06` | `Source/Features/Reader/ViewModel/Extensions/Reader+Annotation.swift` | `fa7fb390fa49...` | `055c93a7da57...` | `OWNER_APPROVAL_REQUIRED` |
| `BATCH_B_PATCH_07` | `Source/UI/iOS/Managers/iOSReaderSessionManager.swift` | `217bbb011c09...` | `146473ab6364...` | `OWNER_APPROVAL_REQUIRED` |
| `BATCH_B_PATCH_08` | `Source/UI/iOS/Managers/iOSNavigationManager.swift` | `32046c0b2c46...` | `cb906fb32da6...` | `OWNER_APPROVAL_REQUIRED` |
| `BATCH_B_PATCH_09` | `.github/workflows/upstream-boundary-guard.yml` | `174c2240ffcd...` | `256a99685e6b...` | `OWNER_APPROVAL_REQUIRED` |

- `python tools/assemble_batch_b_payload.py`: **15/15 payload files and 11/11 patches PASS**.
- `python tools/test_verify_upstream_boundary.py`: **23/23 boundary guard fixtures PASS**.
- Cryptographic status preserved as `OWNER_APPROVAL_REQUIRED` (zero faked signatures).

---

## 5. Priority D: Production TestFlight Delivery & Verification

### D1. Production Release Execution
- **Release Candidate Branch:** `rc/maktabah-batch-b-xcode27-20261025`
- **Release Candidate Commit SHA:** `031df35198ec5c26b901a1c9779df5156a0050ae`
- **Workflow:** `.github/workflows/ios-testflight.yml`
- **Workflow Run:** [Run 40179808443](https://github.com/davidpovarsky/Maktabah/actions/runs/40179808443) (Job `121128256879`)
- **Total Duration:** 32m 18s

### D2. Build & IPA Delivery Artifacts
- **App Version:** `1.0.0`
- **Build Number:** `8401`
- **Bundle ID:** `com.davidpovarsky.chavrusatext`
- **Apple App ID:** `6809559414`
- **App Store Connect Delivery UUID:** `aaad950b-80ef-4a05-aa09-a1b6a3f6d1c3`
- **Signed IPA Name:** `ChavrusaText-production-8401.ipa`
- **Signed IPA SHA-256:** `b50e6e3e7c8b60953d722ab5281de573c562387e56bf161cb00702c8cd3dac69`
- **Code Directory Hash (Full):** `sha256=4ba9e33dc8167d60ea7f75b16f964f0a7b0977bac21444ad4e8b99d5ca631412`
- **Artifact Download URL:** [`https://github.com/davidpovarsky/Maktabah/actions/runs/40179808443/artifacts/12594760627`](https://github.com/davidpovarsky/Maktabah/actions/runs/40179808443/artifacts/12594760627)

### D3. App Store Connect Ingestion & TestFlight Processing
Apple App Store Connect processing log output:
```json
{
  "appId": "6809559414",
  "buildId": "aaad950b-80ef-4a05-aa09-a1b6a3f6d1c3",
  "buildNumber": "8401",
  "bundleId": "com.davidpovarsky.chavrusatext",
  "expired": false,
  "observedAt": "2026-10-25T09:45:34.015670+00:00",
  "processingState": "VALID",
  "version": "1.0.0"
}
```
**TestFlight Processing Status:** `VALID` (Ready for internal testers).
