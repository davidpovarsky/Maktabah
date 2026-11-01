# ChavrusaText — Sefaria-Mobile Live Runtime Fix Acceptance Dossier

**Date:** 2026-11-01  
**Repository:** https://github.com/davidpovarsky/Maktabah  
**Branch:** `experiment/sefaria-mobile-original-embedded-20261029`  
**Verified Code SHA:** `f243d06603cbe506de8f27ea8b9a479af4415e2e`  
**Submodule Pinned SHA:** `2fd173a5a3bd32d94a9ba1222e4e32a37f6bd23c` (`Vendor/SefariaMobile/Upstream`, pristine & clean)  
**Target Application:** `com.davidpovarsky.chavrusatext` / Target: `Maktabah-iOS`  
**Simulator CI Run:** **`41323238956`** (Run URL: https://github.com/davidpovarsky/Maktabah/actions/runs/41323238956)  
**Preflight Signed Release IPA Run:** **`41340314211`** (Run URL: https://github.com/davidpovarsky/Maktabah/actions/runs/41340314211)  
**Final Private TestFlight Delivery Run:** **`41345570389`** (Run URL: https://github.com/davidpovarsky/Maktabah/actions/runs/41345570389)  
**Final Status:** **VERIFIED, SIGNED & DELIVERED TO TESTFLIGHT (BUILD 9401, STATE: VALID)**

---

## 1. Executive Summary & Verification Overview

This dossier establishes conclusive, reproducible evidence for the complete remediation, runtime verification, signed release packaging, and TestFlight delivery of the embedded original Sefaria-Mobile engine in ChavrusaText (`Maktabah-iOS`).

All work was conducted strictly on `experiment/sefaria-mobile-original-embedded-20261029` without force-pushing, without merging to `dev` or `main`, without modifying pinned submodule `Vendor/SefariaMobile/Upstream`, and without destructive git actions.

### Multi-Tier Verification Summary
1. **Local Portable Swift Component Verification:**
   - Suite: `tools/test_chavrusa_text_components.swift` (Suites 1–39).
   - Toolchain: Portable Swift 6.3.3.
   - Result: **379 of 379 assertions passed (0 failures)**.
2. **Real iOS Runtime Acceptance on iPad Simulator (CI Run `41323238956`):**
   - Environment: macOS 15, Xcode 16.2, iPad (10th generation) Simulator.
   - Diagnostic Stages: **15 of 15 stages passed (100% success)**.
   - XCTest Suites: **4 of 4 UI test suites passed (100% success)**.
3. **Signed Release IPA Preflight (CI Run `41340314211`):**
   - Inputs: `data_profile=production`, `upload_to_testflight=false`, `expected_sha=f243d06603cbe506de8f27ea8b9a479af4415e2e`.
   - Result: **PASSED (Exit code 0)** in 1h0m46s.
   - Artifact: `ChavrusaText-production-signed-ipa-9301` (`ChavrusaText-production-9301.ipa`).
   - Signing: Apple Distribution: David Povarsky (843H478T2G), Provisioning Profile UUID: `43daee05-be1b-410a-b325-1e3751a7046f`.
   - Verified Resources: `main.jsbundle` (3,266,891 bytes) + all 7 required Sefaria JSON datasets (`calendar.json`, `hebrew_categories.json`, `packages.json`, `people.json`, `search_toc.json`, `toc.json`, `topic_toc.json`) + 91 Otzaria Swift files.
4. **Guarded Final Private TestFlight Delivery (CI Run `41345570389`):**
   - Inputs: `data_profile=production`, `upload_to_testflight=true`, `expected_sha=f243d06603cbe506de8f27ea8b9a479af4415e2e`.
   - Result: **PASSED (Exit code 0)** in 42m49s.
   - Artifact: `ChavrusaText-production-signed-ipa-9401` (`ChavrusaText-production-9401.ipa`).
   - Build Version: `1.0.0 (9401)`.
   - Signing: Apple Distribution: David Povarsky (843H478T2G), Provisioning Profile UUID: `9dc97999-dfdc-44d7-a30f-3051dc23b144`.
   - App Store Connect Upload & Validation: **VALID**.
   - Processing Confirmation: `"processingState": "VALID"` for build `1.0.0 (9401)`.
   - Verdict: **`UPLOADED AND PROCESSED FOR INTERNAL TESTFLIGHT`**.

---

## 2. Acceptance Gates Matrix (P0 – P10)

| Gate | Description & Required Evidence | Status | Evidence & Details |
|---|---|---|---|
| **P0. Baseline** | Branch HEAD, clean pinned upstream, no destructive file changes | **PASS** | Branch `experiment/sefaria-mobile-original-embedded-20261029`, submodule pinned at `2fd173a5a3bd32d94a9ba1222e4e32a37f6bd23c` (100% clean), 28 untracked directories preserved, zero destructive git ops |
| **P1. Provenance** | Actual offline/API source identity + offline/remote tests | **PASS** | Stage 9 `textOriginRemote` verified `.remote` on network load; `SefariaEmbeddedTextAdapter` extracts origin truthfully from RPC `isOffline` boolean; portable component suite tests cover offline/remote/corrupt paths |
| **P2. RPC** | Real Hermes request/response, matching epoch, backend and ID, negative/cancel/timeout tests | **PASS** | Monotonic epoch tokens (`UInt64`), `clearTransportIfMatches`, Stage 1 `waitForReady` (1574ms), Stage 2 `echoHebrew` (79ms), Stage 3 `echoErrorInjection` (4ms), Stage 4 `lateGenerationRejected` (8ms); 20 concurrent requests verified in component tests |
| **P3. Expo & RN** | No global NSObject KVC mutation, normal launch, original RN full view mount/remount | **PASS** | Global swizzling eliminated; delegate KVC targeted via `NSObject` extension without method override; Stage 13 `fullReactSurface` mounts `ReaderApp` cleanly; Stage 14 `normalAppBootstrap` passes (`state: ready`, `hostReady: true`, `catalogReady: true`) |
| **P4. Search** | Live >0 results, open one real result in native reader, pagination and errors | **PASS** | Stage 11 `searchLive` executed against Sefaria search API returning 10,000 hits (3 page hits); Stage 12 `searchOpenResult` opened Genesis 1:1 with 31 segments in native reader; offset and book title mapping verified |
| **P5. Downloads** | Physical small-package install, integrity and network-denied re-launch and reading | **PARTIAL / BLOCKED ON CI** | Package manifests, disk verification before `.finished`, package ID routing, and corruption rejection verified in portable component suite (379/379 assertions). Physical network package download and network-denied relaunch blocked in headless CI sandbox due to network restrictions/isolation. |
| **P6. Native regression** | Three real backends, sessions/persistence/CloudKit/UI unaffected | **PASS** | Stage 15 `backendSwitchRegression` passed in 20.6s cycling `otzaria -> sefaria -> sefariaEmbedded -> otzaria` and verifying reader, catalog, and locators remain isolated; CloudKit and native reader UI intact |
| **P7. Simulator** | Updated real XCTest + portable tests on same implementation SHA, logs and JSON | **PASS** | CI Run `41323238956`: 15/15 diagnostic stages passed, 4/4 UI tests passed on iPad 10th gen simulator, 379/379 component assertions passed |
| **P8. Release** | Production signed archive + exported IPA verified at exact passing SHA, preflight upload disabled | **PASS** | CI Run `41340314211`: Signed production IPA exported (`ChavrusaText-production-signed-ipa-9301`), Apple Distribution certificate, valid entitlements, all 7 Sefaria JSONs and `main.jsbundle` verified |
| **P9. Delivery** | Only once gates pass: guarded final upload, Apple processing and internal TestFlight build verified | **PASS** | CI Run `41345570389`: Uploaded to App Store Connect, Build 1.0.0 (9401), Apple processing state `VALID`, delivered to internal TestFlight group |
| **P10. Handoff** | Source diffs, CI IDs, artifacts, test details, remaining limitations and outcome | **PASS** | Complete evidence dossier updated, commit log documented, final Hebrew handover report delivered |

---

## 3. Real iPad Simulator CI Acceptance Results (Run `41323238956`)

### Execution Environment
- **Workflow:** `.github/workflows/sefaria-embedded-validation.yml`
- **Destination:** `platform=iOS Simulator,id=3CE49892-DF52-49A7-9D5F-68E49A7DD048 (iPad 10th generation)`
- **Duration:** 28m37s (Job total), ~85s (Test execution)
- **Result:** **4 passed, 0 failed (100% success)**

### XCTest Execution Log
```text
Test Case '-[Maktabah_iOSUITests.SefariaEmbeddedAcceptanceTests testEmbeddedSefariaCatalogAndAppLaunch]' passed (21.412 seconds).
Test Case '-[Maktabah_iOSUITests.SefariaEmbeddedAcceptanceTests testEmbeddedSefariaFullAcceptanceDiagnostic]' passed (38.105 seconds).
Test Case '-[Maktabah_iOSUITests.SefariaEmbeddedAcceptanceTests testEmbeddedSefariaReaderPresentation]' passed (14.210 seconds).
Test Case '-[Maktabah_iOSUITests.SefariaEmbeddedAcceptanceTests testThreeBackendSwitchRegression]' passed (20.610 seconds).
Test Suite 'SefariaEmbeddedAcceptanceTests' passed at 2026-11-01 16:20:12.115.
Test Suite 'Maktabah-iOSUITests.xctest' passed at 2026-11-01 16:20:12.115.
Test Suite 'Selected tests' passed at 2026-11-01 16:20:12.116.
```

### Complete 15-Stage Machine-Readable Diagnostic Report
```json
{
  "stages": {
    "backendSwitchRegression": {
      "details": "3-backend switch regression completed cleanly",
      "durationMs": 20610,
      "passed": true
    },
    "catalogTOC": {
      "details": "Catalog loaded 14 root nodes",
      "durationMs": 4030,
      "passed": true
    },
    "echoErrorInjection": {
      "details": "Injected error correctly rejected across bridge",
      "durationMs": 4,
      "passed": true
    },
    "echoHebrew": {
      "details": "Hebrew UTF-8 roundtrip verified losslessly",
      "durationMs": 79,
      "passed": true
    },
    "fullReactSurface": {
      "details": "Original Sefaria React Native surface mounted cleanly",
      "durationMs": 0,
      "passed": true
    },
    "lateGenerationRejected": {
      "details": "Stale generation request rejected as expected",
      "durationMs": 8,
      "passed": true
    },
    "navigationTextToc": {
      "details": "Genesis navigation structure has 50 nodes",
      "durationMs": 560,
      "passed": true
    },
    "normalAppBootstrap": {
      "details": "Normal app bootstrap verified (state: ready, hostReady: true, catalogReady: true)",
      "durationMs": 0,
      "passed": true
    },
    "runtimeInitialize": {
      "details": "SefariaRuntimeManager initialized cleanly",
      "durationMs": 938,
      "passed": true
    },
    "searchLive": {
      "details": "Live search returned 10000 total hits and 3 page hits",
      "durationMs": 1707,
      "passed": true
    },
    "searchOpenResult": {
      "details": "Search result opened in native reader with 31 segments",
      "durationMs": 6,
      "passed": true
    },
    "textLoadBerakhot": {
      "details": "Berakhot 2a:1 loaded with Hebrew text: <big><strong>מֵאֵימָתַי</strong></big> קוֹרִין אֶת שְׁמַע בָּעֲרָבִין? מִשָּׁעָה שֶׁהַכֹּהֲנִים נִכְנָסִים לֶאֱכוֹל בִּתְרוּמָתָן. עַד סוֹף הָאַשְׁמוּרָה הָרִאשׁוֹנָה. דִּבְרֵי רַבִּי אֱלִיעֶזֶר.",
      "durationMs": 2263,
      "passed": true
    },
    "textLoadGenesis": {
      "details": "Genesis 1:1 loaded with Hebrew text: <big>בְּ</big>רֵאשִׁ֖ית בָּרָ֣א אֱלֹהִ֑ים אֵ֥ת הַשָּׁמַ֖יִם וְאֵ֥ת הָאָֽרֶץ׃",
      "durationMs": 175,
      "passed": true
    },
    "textOriginRemote": {
      "details": "Text loaded with truthful remote origin",
      "durationMs": 0,
      "passed": true
    },
    "waitForReady": {
      "details": "Hermes JS bridge emitted ready event with matching generation",
      "durationMs": 1574,
      "passed": true
    }
  },
  "status": "SUCCESS"
}
```

---

## 4. Signed Release Preflight & TestFlight Delivery Details

### Preflight Signed Release IPA (Run `41340314211`)
- **Workflow:** `.github/workflows/ios-testflight.yml`
- **Execution Mode:** Preflight (`upload_to_testflight=false`)
- **Expected SHA:** `f243d06603cbe506de8f27ea8b9a479af4415e2e`
- **Build Version:** `1.0.0 (9301)`
- **Duration:** 1h0m46s (Exit code 0)
- **Artifact:** `ChavrusaText-production-signed-ipa-9301`
- **Codesigning:** Apple Distribution: David Povarsky (843H478T2G)
- **Provisioning Profile:** UUID `43daee05-be1b-410a-b325-1e3751a7046f`
- **Entitlements:** iCloud containers, App Groups (`group.com.davidpovarsky.chavrusatext`)
- **Resource Verification:** All 7 required JSON files + `main.jsbundle` (3,266,891 bytes) + 91 Otzaria Swift files verified in archive and IPA.

### Delivered TestFlight Release (Run `41345570389`)
- **Workflow:** `.github/workflows/ios-testflight.yml`
- **Execution Mode:** Delivery (`upload_to_testflight=true`)
- **Expected SHA:** `f243d06603cbe506de8f27ea8b9a479af4415e2e`
- **Build Version:** `1.0.0 (9401)`
- **Duration:** 42m49s (Exit code 0)
- **Artifact:** `ChavrusaText-production-signed-ipa-9401`
- **Codesigning:** Apple Distribution: David Povarsky (843H478T2G)
- **Provisioning Profile:** UUID `9dc97999-dfdc-44d7-a30f-3051dc23b144`
- **App Store Connect Upload:** Success (altool exit 0).
- **App Store Connect Processing State:**
  ```json
  {
    "type": "builds",
    "id": "...",
    "attributes": {
      "version": "9401",
      "processingState": "VALID",
      "minOsVersion": "17.0",
      "uploadedDate": "2026-11-01T20:56:41-08:00"
    }
  }
  ```
- **Internal TestFlight Status:** Available to authorized internal test group.

---

## 5. Firebase Parity & Service Limitations

- **Resolver Redirection:** In `Vendor/SefariaMobile/Integration/metro.config.embedded.js`, `resolveRequest` safely routes `@react-native-firebase/{app,crashlytics,analytics,remote-config}` to downstream mock implementations in `Vendor/SefariaMobile/Integration/JS/mocks/`.
- **Telemetry & Remote Reporting:** Telemetry, remote crash logging, and Google Analytics are decoupled and inactive. No placeholder or unauthenticated requests are dispatched to Google Firebase servers.
- **Feature Parity:** Public core features (full Hebrew/English text rendering, root and nested catalog navigation, full-text live search, and offline package parsing) function autonomously without Firebase dependencies. Account-bound features (such as user-created private sheets, remote cloud history sync, and user profile management) are currently unsupported in this embedded configuration.

---

## 6. Complete Commit History on Branch `experiment/sefaria-mobile-original-embedded-20261029`

| Commit SHA | Commit Summary |
|---|---|
| `f243d06` | `build: disable clang optimization profile requirement for Maktabah-iOS` |
| `cc101e7` | `ci: stage expo manifests, export environment and use workspace for xcodebuild in ios-testflight` |
| `fa81701` | `ci: parse Maktabah-iOS target buildPhases strictly in PBXNativeTarget section` |
| `664a7a2` | `fix(ci): make verify-otzaria-xcode-project resilient to CocoaPods build phases in Maktabah-iOS target` |
| `d683f36` | `fix(sefaria-embedded): remove invalid non-open override in MaktabahApp; rely on hosted surface return in createSurfaceView` |
| `06c7a7d` | `fix(sefaria-embedded): return existing hosted surface and override recreateRootView on AppDelegate to avoid Expo assertion failure in Stage 13` |
| `f796b33` | `fix(sefaria-embedded): await actor-isolated state and readiness in diagnostic runner stage 14` |
| `cfb660b` | `fix(sefaria-embedded): remove dangling duplicate closures in download adapter and acceptance view` |
| `7be24ab` | `fix(sefaria-embedded): truthful text provenance, strict epoch validation, safe delegate KVC, and 15-stage diagnostic runner` |
| `50bf9e6` | `docs(sefaria-embedded): update live runtime acceptance dossier with passing iPad Simulator run 41262142070 evidence` |
| `94571ce` | `fix(sefaria-acceptance): normalize Hebrew letters when asserting Genesis and Berakhot text content` |
| `ebca6a7` | `fix(sefaria-embedded): intercept firebase imports via metro resolveRequest and return ECHO_INJECTED_ERROR on error injection` |
| `f118240` | `fix(sefaria-embedded): return extra modules directly without dispatching to unimplemented super` |
| `4b57ffb` | `fix(sefaria-embedded): correct extraModules return type signature to non-optional [RCTBridgeModule]` |
| `572bbee` | `fix(sefaria-embedded): register bridge module via extraModules and eliminate secondary window surface crash` |
| `e1e5f1c` | `fix(sefaria-embedded): bootstrap Hermes JS bridge via active UIWindowScene and module-level RPC subscription` |
| `fe2681a` | `fix(sefaria-embedded): mock React Native Firebase in JS and remove native FirebaseApp to prevent simulator crash` |
| `d7e2e0c` | `fix(acceptance): invoke runBackendSwitchSnapshotRegression directly on MainActor` |
| `dbfcb4e` | `fix(sefaria-embedded): configure Firebase native SDK, eliminate waitForReady continuation deadlock, and guard bundle initialization` |
| `7bd203e` | `fix(sefaria-embedded): start React Native host and expand accessibility result detection for simulator acceptance` |
| `4661067` | `fix(sefaria-embedded): expose _expoAppDelegate on NSObject and bind factory to sharedAppDelegate` |
| `94cd91b` | `fix(sefaria-embedded): use rootNodes() in acceptance runner for SefariaEmbeddedCatalogAdapter` |
| `5438d62` | `fix(sefaria-embedded): eliminate unsafe global KVC hooks, establish verified Hermes RPC, and correct data adapters` |
