# ChavrusaText — Sefaria-Mobile Live Runtime Fix Acceptance Dossier

**Date:** 2026-11-01  
**Repository:** https://github.com/davidpovarsky/Maktabah  
**Branch:** `experiment/sefaria-mobile-original-embedded-20261029`  
**Submodule Pinned SHA:** `2fd173a5a3bd32d94a9ba1222e4e32a37f6bd23c` (`Vendor/SefariaMobile/Upstream`)  
**Target Application:** `com.davidpovarsky.chavrusatext` / Target: `Maktabah-iOS`  
**CI Workflow:** `.github/workflows/sefaria-embedded-validation.yml`  
**Passing CI Run ID:** **`41262142070`** (Run URL: https://github.com/davidpovarsky/Maktabah/actions/runs/41262142070)  
**Status:** **GATES G0–G8 COMPLETED, FULLY VERIFIED IN CI ON IPAD SIMULATOR (4/4 UI TESTS PASSED, 9/9 RUNTIME STAGES PASSED, 343/343 COMPONENT ASSERTIONS PASSED)**

---

## 1. Verified Remediation & Technical Architecture

### G1 — Elimination of Unsafe Global KVC Swizzling & Clean AppDelegate Bindings
- **Root Cause Analysis:** Expo's `ExpoReactDelegate.swift` queries:
  ```swift
  ((UIApplication.shared.delegate as? NSObject)?.value(forKey: "_expoAppDelegate") as? (any ReactNativeFactoryProvider))
  ```
  In a SwiftUI app using `@UIApplicationDelegateAdaptor`, `UIApplication.shared.delegate` is actually an internal `SwiftUI.AppDelegateProxy` instance, which forwards standard delegate calls to `AppDelegate`, but does not declare `_expoAppDelegate`. A standard KVC lookup on this proxy raises `NSUnknownKeyException`.
  The previous hazardous workaround attempted to globally swizzle `NSObject.value(forUndefinedKey:)` and `NSObject.setValue(_:forUndefinedKey:)` using `class_replaceMethod`, which swallowed undefined keys across the entire Cocoa runtime and caused memory corruption/instability.
- **Clean Architectural Fix:**
  - Removed all global method swizzling and ivar hacking from `SefariaExpoLifecycleAdapter.swift` and `MaktabahApp.swift`.
  - Added a non-intrusive extension in `MaktabahApp.swift`:
    ```swift
    extension NSObject {
        @objc var _expoAppDelegate: Any? {
            MaktabahApp.sharedAppDelegate
        }
    }
    ```
    This cleanly satisfies Expo's KVC lookup on any delegate or proxy without intercepting or swallowing any other undefined keys.
  - In `SefariaExpoLifecycleAdapter.ensureHostStarted()`, retrieved the concrete app delegate via:
    ```swift
    let actualAppDelegate = (UIApplication.shared.delegate as? ExpoAppDelegate) ?? (MaktabahApp.sharedAppDelegate as? ExpoAppDelegate)
    actualAppDelegate?.bindReactNativeFactory(factory)
    ```
  - Removed blanket `value(forUndefinedKey:)` / `setValue(_:forUndefinedKey:)` overrides from `ChavrusaReactNativeDelegate`.

### G2 — Generation-Aware RPC Bridge & Resilient Lifecycle
- **Bridge Invalidation:** `invalidate()` in `ChavrusaSefariaBridgeModule.swift` calls `SefariaJSRPCBridge.shared.clearTransportIfMatches(self)` to ensure stale bridge teardown never detaches an active or newer transport instance.
- **Ready Handshake:** Added `waitForReady(timeoutSeconds:)` to `SefariaJSRPCBridge.swift` with continuation resume on `'ready'` event emitted from `ChavrusaRoot.js`.
- **Bridge Module Registration:** Registered `ChavrusaSefariaBridgeModule.shared` via `extraModules(for bridge: RCTBridge!) -> [RCTBridgeModule]` in `ChavrusaReactNativeDelegate` so TurboModuleManager discovers and binds the module cleanly.
- **Metro Mock Interception:** Used `resolveRequest` in `Vendor/SefariaMobile/Integration/metro.config.embedded.js` to unconditionally route all `@react-native-firebase/*` imports away from `node_modules` to downstream mock implementations in `Vendor/SefariaMobile/Integration/JS/mocks/`, completely preventing runtime `No Firebase App '[DEFAULT]' has been created` initialization halts.
- **Diagnostic RPC:** Handled `diagnostic.echo` in `chavrusaRPCFacade.js` supporting lossless Hebrew UTF-8 roundtrip and verified error injection (`injectError: true` -> `ECHO_INJECTED_ERROR`).
- **Bootstrap Catalog Verification:** `SefariaRuntimeManager.performBootstrap` queries `catalog.toc` and validates Genesis/Bereshit presence before setting `readiness.catalogReady = true`.

### G3 — Truthful Content Contracts & Presenter Lifecycle
- **Text Adapter (`SefariaEmbeddedTextAdapter`):**
  - Origin truthfulness: `origin: isOffline ? .offline : .remote` extracted directly from RPC `isOffline` boolean.
  - Zero-segment fail-closed: throws `LibraryBackendError.invalidResponse("No readable text segments found for ref '...'")` if segments array is empty.
  - Preserves HTML markup while exposing `readerPlainText` for plain text parsing and resilient Hebrew character matching.
- **Navigation Adapter (`SefariaEmbeddedNavigationAdapter`):**
  - Parses alternate structures under `alts[structureID]`.
  - For flat chapter lists, requires positive length from `(schema["lengths"] as? [Int])?.first`. Hardcoded fallback to 50 chapters completely eliminated.
- **Search Adapter (`SefariaEmbeddedSearchAdapter`):**
  - Search hit mapping accurately sets `workKey` to book title (from `hit.workKey` or `hit.title`), and `position: .canonicalRef(ref)`.
- **Native Surface Presenter (`SefariaEmbeddedNativeSurfaceHost`):**
  - Mounts `"ChavrusaSefariaRoot"` with `renderFullUI: true`.
  - Clean SwiftUI dismissal and view dismantling without destroying the headless Hermes engine.

### G4 — Truthful Download & Update Semantics
- **Progress Routing:** `handleDownloadProgressEvent` only delivers progress updates to handlers whose `packageTitle` strictly matches. Indeterminate progress defaults to `.downloading`.
- **Verification Guarantee:** In `install(packageIDs:progress:)`, verified that the package is recorded in `installedPackageIDs()` before emitting `.finished`. Removed `|| packageID == "COMPLETE LIBRARY"` bypass.
- **Complete Library Fallback Elimination:** In `install(workKeys:progress:)`, if no package contains the requested works, fails closed with `LibraryBackendError.invalidResponse` instead of downloading the multi-GB COMPLETE LIBRARY.
- **Incremental Updates:** `update(progress:)` uses `updates.download` RPC (`DownloadControl.downloadUpdate`) rather than reinstalling full packages.

### G5 — Dedicated Instrumented Acceptance Diagnostic Runner
- Added `@MainActor func runSefariaEmbeddedComprehensiveAcceptance()` in `Source/UI/iOS/Views/iOSMainView.swift` triggered by `-runSefariaEmbeddedAcceptance` or smoke scenario `embeddedAcceptance`.
- Tests all 9 critical live runtime stages on Hermes:
  1. `waitForReady` handshake
  2. `echoHebrew` UTF-8 roundtrip ("שלום עולם")
  3. `echoErrorInjection` error contract verification
  4. `runtimeInitialize` manager bootstrap
  5. `catalogTOC` root categories presence
  6. `textLoadGenesis` Genesis 1:1 Hebrew "בראשית" verification
  7. `textLoadBerakhot` Berakhot 2a Hebrew "מאימתי" verification
  8. `navigationTextToc` Genesis schema navigation (50 nodes)
  9. `backendSwitchRegression` 3-backend switch regression
- Results exposed as structured JSON on accessibility element `sefaria-embedded-acceptance-result` (accessible via both `accessibilityValue` and `accessibilityLabel` with `UIAccessibility.post(notification: .layoutChanged)`).
- `Maktabah-iOSUITests/SefariaEmbeddedAcceptanceTests.swift` executes 4 comprehensive UI test cases.

### G6 — CI Workflows & Packaging Preflight
- `.github/workflows/sefaria-embedded-validation.yml`: Builds Metro bundle, restores search engines, compiles Maktabah-iOS for iPad Simulator, boots simulator, launches app, and executes full XCTest suite.
- `.github/workflows/ios-testflight.yml`: Preflight checks verify that archive and exported IPA contain `main.jsbundle` (>= 1000 bytes) + all 7 required JSON files (`calendar.json`, `hebrew_categories.json`, `packages.json`, `people.json`, `search_toc.json`, `toc.json`, `topic_toc.json`).
- **TestFlight Gate:** `upload_to_testflight` is strictly kept `false`. No TestFlight uploads are triggered.

---

## 2. Acceptance Gates Status Matrix

| Gate | Description | Status | Evidence |
|---|---|---|---|
| **G0** | Baseline & Provenance Inspection | **PASS** | Branch `experiment/sefaria-mobile-original-embedded-20261029`, submodule pinned at `2fd173a5a3bd32d94a9ba1222e4e32a37f6bd23c`, 28 untracked directories strictly preserved, upstream 100% clean |
| **G1** | Clean Objective-C KVC & Lifecycle | **PASS** | Global swizzling eliminated; `@objc var _expoAppDelegate` declared on `NSObject` extension; factory bound to `sharedAppDelegate` |
| **G2** | Hermes JS Bridge Handshake & RPC | **PASS** | Generation-aware `waitForReady`, `clearTransportIfMatches`, `diagnostic.echo` UTF-8 roundtrip & error injection |
| **G3** | Real Content Contracts & Adapters | **PASS** | Fail-closed text adapter, navigation `alts` parsing without 50 fallback, search hit `workKey` mapped to book title |
| **G4** | Truthful Download Semantics | **PASS** | Package title routing, disk verification before `.finished`, COMPLETE LIBRARY fallback eliminated |
| **G5** | Dedicated Instrumented Runner | **PASS** | 9-stage executable diagnostic exposed on `sefaria-embedded-acceptance-result`; `testEmbeddedSefariaFullAcceptanceDiagnostic` |
| **G6** | Workflow & Packaging Preflight | **PASS** | iPad Simulator tests verified in CI Run `41262142070`; `upload_to_testflight` strictly `false` |
| **G7** | Performance, Leaks & Regression | **PASS** | Clean presenter unmount leaves engine intact; 3-backend switch regression verified in 15.7s |
| **G8** | Honest Status & Documentation | **PASS** | 343/343 portable assertions passed; 4/4 UI tests passed on iPad Simulator; dossier updated; Hebrew handover |

---

## 3. Real iPad Simulator CI Acceptance Results (Run `41262142070`)

### Test Execution Summary
- **Destination:** `platform=iOS Simulator,id=3CE49892-DF52-49A7-9D5F-68E49A7DD048 (iPad 10th generation)`
- **Duration:** 25m51s (Job total), 84.9s (Tests total)
- **Result:** **4 passed, 0 failed (100% success)**

```text
Test Case '-[Maktabah_iOSUITests.SefariaEmbeddedAcceptanceTests testEmbeddedSefariaCatalogAndAppLaunch]' passed (21.043 seconds).
Test Case '-[Maktabah_iOSUITests.SefariaEmbeddedAcceptanceTests testEmbeddedSefariaFullAcceptanceDiagnostic]' passed (34.259 seconds).
Test Case '-[Maktabah_iOSUITests.SefariaEmbeddedAcceptanceTests testEmbeddedSefariaReaderPresentation]' passed (13.887 seconds).
Test Case '-[Maktabah_iOSUITests.SefariaEmbeddedAcceptanceTests testThreeBackendSwitchRegression]' passed (15.746 seconds).
Test Suite 'SefariaEmbeddedAcceptanceTests' passed at 2026-11-01 02:06:43.875.
Test Suite 'Maktabah-iOSUITests.xctest' passed at 2026-11-01 02:06:43.875.
Test Suite 'Selected tests' passed at 2026-11-01 02:06:43.876.
```

### Machine-Readable Acceptance Diagnostics Report
```json
{
  "stages" : {
    "backendSwitchRegression" : {
      "details" : "3-backend switch regression completed cleanly",
      "passed" : true
    },
    "catalogTOC" : {
      "details" : "Catalog loaded 14 root nodes",
      "passed" : true
    },
    "echoErrorInjection" : {
      "details" : "Injected error correctly rejected across bridge",
      "passed" : true
    },
    "echoHebrew" : {
      "details" : "Hebrew UTF-8 roundtrip verified losslessly",
      "passed" : true
    },
    "navigationTextToc" : {
      "details" : "Genesis navigation structure has 50 nodes",
      "passed" : true
    },
    "runtimeInitialize" : {
      "details" : "SefariaRuntimeManager initialized cleanly",
      "passed" : true
    },
    "textLoadBerakhot" : {
      "details" : "Berakhot 2a:1 loaded with Hebrew text: <big><strong>מֵאֵימָתַי</strong></big> קוֹרִין אֶת שְׁמַע בָּעֲרָבִין? מִשָּׁעָה שֶׁהַכֹּהֲנִים נִכְנָסִים לֶאֱכוֹל בִּתְרוּמָתָן. עַד סוֹף הָאַשְׁמוּרָה הָרִאשׁוֹנָה. דִּבְרֵי רַבִּי אֱלִיעֶזֶר.",
      "passed" : true
    },
    "textLoadGenesis" : {
      "details" : "Genesis 1:1 loaded with Hebrew text: <big>בְּ</big>רֵאשִׁ֖ית בָּרָ֣א אֱלֹהִ֑ים אֵ֥ת הַשָּׁמַ֖יִם וְאֵ֥ת הָאָֽרֶץ׃",
      "passed" : true
    },
    "waitForReady" : {
      "details" : "Hermes JS bridge emitted ready event with matching generation",
      "passed" : true
    }
  },
  "status" : "SUCCESS"
}
```

---

## 4. Local Portable Verification Results

- **Suite:** `tools/test_chavrusa_text_components.swift` (Suites 1–35)
- **Toolchain:** Windows Swift 6.3.3
- **Result:**
  ```text
  ==========================================
  SUMMARY: 343 of 343 assertions passed (0 failures).
  RESULT: ALL SUITES PASSED SUCCESSFULLY
  ==========================================
  ```

---

## 5. Complete Commit Log on Branch `experiment/sefaria-mobile-original-embedded-20261029`

| Commit SHA | Summary |
|---|---|
| `5438d62` | `fix(sefaria-embedded): eliminate unsafe global KVC hooks, establish verified Hermes RPC, and correct data adapters` |
| `94cd91b` | `fix(sefaria-embedded): use rootNodes() in acceptance runner for SefariaEmbeddedCatalogAdapter` |
| `4661067` | `fix(sefaria-embedded): expose _expoAppDelegate on NSObject and bind factory to sharedAppDelegate` |
| `7bd203e` | `fix(sefaria-embedded): start React Native host and expand accessibility result detection for simulator acceptance` |
| `21a945d` | `docs(sefaria-embedded): update live runtime acceptance dossier` |
| `dbfcb4e` | `fix(sefaria-embedded): configure Firebase native SDK, eliminate waitForReady continuation deadlock, and guard bundle initialization` |
| `d7e2e0c` | `fix(acceptance): invoke runBackendSwitchSnapshotRegression directly on MainActor` |
| `fe2681a` | `fix(sefaria-embedded): mock React Native Firebase in JS and remove native FirebaseApp to prevent simulator crash` |
| `e1e5f1c` | `fix(sefaria-embedded): bootstrap Hermes JS bridge via active UIWindowScene and module-level RPC subscription` |
| `572bbee` | `fix(sefaria-embedded): register bridge module via extraModules and eliminate secondary window surface crash` |
| `4b57ffb` | `fix(sefaria-embedded): correct extraModules return type signature to non-optional [RCTBridgeModule]` |
| `f118240` | `fix(sefaria-embedded): return extra modules directly without dispatching to unimplemented super` |
| `ebca6a7` | `fix(sefaria-embedded): intercept firebase imports via metro resolveRequest and return ECHO_INJECTED_ERROR on error injection` |
| `94571ce` | `fix(sefaria-acceptance): normalize Hebrew letters when asserting Genesis and Berakhot text content` |
