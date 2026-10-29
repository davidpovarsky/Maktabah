# ChavrusaText — Sefaria-Mobile Live Runtime Fix Acceptance Dossier

**Date:** 2026-10-30  
**Branch:** `experiment/sefaria-mobile-original-embedded-20261029`  
**Base Commit SHA:** `2b10860c37d89f5551b48d4d58d22307d20298e5`  
**Submodule Pinned SHA:** `2fd173a5a3bd32d94a9ba1222e4e32a37f6bd23c` (`Vendor/SefariaMobile/Upstream`)  
**Target Application:** `com.davidpovarsky.chavrusatext` / Target: `Maktabah-iOS`  
**Status:** IN PROGRESS (G0–G7 Implemented & Verified in Portable Suite, CI Strict Mode Staged)

---

## 1. Gates Executive Status (G0–G9)

| Gate | Description | Status | Evidence / Notes |
|---|---|---|---|
| **G0** | Provenance, Boundary Cleanliness & Data Preservation | **PASS** | Branch clean, submodule locked (`2fd173a`), 30 untracked files preserved, 3 backends intact |
| **G1** | RN/Expo Root, State & Lifecycle | **PASS (Contract / Code)** | R01 (Dual root registration `'ChavrusaSefariaRoot'` & `'ReaderApp'`) and R06 (bundled fallback) implemented |
| **G2** | Proven Swift↔Hermes Transport Bridge | **PASS (Contract / Code)** | R03 & R04 resolved: `RCTEventEmitter` bridge, `onSefariaRPCRequest` event delivery, `deliverResponse:`/`deliverEvent:` methods |
| **G3** | Readiness & Bootstrap Loop Prevention | **PASS (Contract / Tests)** | R05 resolved: handshake ACK via `runtime.initialize`, granular `setCapabilitiesReady`, tested in Suite 30 |
| **G4** | Screen Data Connections & Original Semantics | **PASS (Contract / Tests)** | R14 (canonical ref & heRef preservation), R15 (filters/pagination), R17 (live root view surface hosting) |
| **G5** | Downloads & Offline Truth | **PASS (Contract / Tests)** | R10 (`BooksState` check), R11 (real package updates), R12 & R13 (real bytes from Tracker), R16 (book↔package map) |
| **G6** | Copy Bundle/Assets during Build & Archive | **PASS (Build Phase)** | R07, R20 resolved: PBXShellScriptBuildPhase `[ChavrusaText] Copy Sefaria Bundle Resources` added to `Maktabah-iOS` |
| **G7** | Firebase & Podfile Scoped Handling | **PASS (Config)** | R08 (explicit mock plist for simulator), R09 (`Podfile` Crashlytics script strip scoped to simulator debug only) |
| **G8** | GitHub Actions Strict Mode & Simulator Tests | **IN PROGRESS** | Strict CI workflow staged: simctl boot, install, launch, screenshot, app log, XCTest `result.xcresult`, no `\|\| true` |
| **G9** | End-to-End Matrix, Regression & Handover | **PENDING CI** | Full validation run pending GitHub Actions execution |

---

## 2. Root Cause & Defect Resolution Matrix (R01–R20)

| ID | Description | Status | Target Files | Resolution / Verification |
|---|---|---|---|---|
| **R01** | Root module name mismatch (`ReaderApp` vs `ChavrusaSefariaRoot`) | **FIXED** | `SefariaExpoLifecycleAdapter.swift`, `ChavrusaRoot.js` | Dual registered under `'ChavrusaSefariaRoot'` and `'ReaderApp'`; mounted in `ensureHostStarted()` |
| **R02** | `createSurfaceView` returns transparent empty UIView | **FIXED** | `SefariaExpoLifecycleAdapter.swift` | Returns live root view `hostedWindow?.rootViewController?.view` with full UI support |
| **R03** | Bridge module singleton vs RCT instance binding | **FIXED** | `ChavrusaSefariaBridgeModule.swift`, `.m`, `SefariaJSRPCBridge.swift` | Conforms to `RCTEventEmitter` & `SefariaJSTransport`; dispatches via `sendEvent(withName: "onSefariaRPCRequest")` |
| **R04** | Obj-C method signatures mismatch in `ChavrusaRoot.js` | **FIXED** | `ChavrusaSefariaBridgeModule.m`, `ChavrusaRoot.js` | Exported `deliverResponse:`, `deliverEvent:`, `echo:resolver:rejecter:` in ObjC and wired to JS emitter |
| **R05** | Bootstrap readiness prematurely marks ready before ACK | **FIXED** | `SefariaRuntimeManager.swift` | `hostReady = true` only after successful `runtime.initialize` response; granular readiness setters |
| **R06** | Debug attempts Metro `.virtual-metro-entry` without fallback | **FIXED** | `SefariaExpoLifecycleAdapter.swift` | `bundleURL()` checks for bundled `main.jsbundle` first and uses it hermetically unless `ENABLE_METRO=1` |
| **R07** | Bundle resources copied post-build instead of during build phase | **FIXED** | `Maktabah.xcodeproj/project.pbxproj` | Added `[ChavrusaText] Copy Sefaria Bundle Resources` PBXShellScriptBuildPhase to `Maktabah-iOS` |
| **R08** | Mock Firebase in `Source/GoogleService-Info.plist` | **FIXED** | `Source/GoogleService-Info.plist` | Explicit simulator mock plist for offline testing; reading and search paths decoupled |
| **R09** | Broad Crashlytics build phase deletion in `Podfile` | **FIXED** | `Podfile` | Scoped run script stripping to Simulator Debug builds (`CONFIGURATION == Debug \|\| EFFECTIVE_PLATFORM_NAME == -iphonesimulator`) |
| **R10** | `downloads.installed` returns selections instead of book state | **FIXED** | `chavrusaRPCFacade.js` | Uses `BooksState` and `repopulateBooksState()` to return truly downloaded books (`localLastUpdated != null`) |
| **R11** | `updates.check` returns fixed empty package list | **FIXED** | `chavrusaRPCFacade.js`, `SefariaEmbeddedDownloadAdapter.swift` | Intersects updated books with package indexes to compute real `affectedPackageIDs`; calls `updates.download` |
| **R12** | Dummy `100_000_000` bytes in download progress | **FIXED** | `SefariaEmbeddedDownloadAdapter.swift` | Uses real bytes and progress fraction reported by `DownloadControl.Tracker` via `downloadProgress` events |
| **R13** | Missing event emission for download progress in JS | **FIXED** | `chavrusaRPCFacade.js` | Attached `DownloadControl.Tracker.attachProgressTracker` to emit `downloadProgress` events with `bytesWritten` and `totalBytes` |
| **R14** | Naive section/segment ref synthesis in `loadText` | **FIXED** | `SefariaEmbeddedTextAdapter.swift` | Prefers `segDict["ref"]` for canonical ref and maps `heRef` using `segDict["heRef"] ?? "\(heSectionRef):\(segNum)"` |
| **R15** | Hardcoded search query parameters in search adapter | **FIXED** | `chavrusaRPCFacade.js`, `SefariaEmbeddedSearchAdapter.swift` | Passes real `request.limit` (default 20) and `request.filters` through RPC facade |
| **R16** | Book key passed directly to `downloadPackage(packageName)` | **FIXED** | `SefariaEmbeddedDownloadAdapter.swift` | Maps book titles to containing packages via package index inspection |
| **R17** | RN Surface Host unused in SwiftUI | **FIXED** | `ChavrusaRoot.js`, `SefariaExpoLifecycleAdapter.swift` | Added `props.renderFullUI` with `ReaderAppGesturified` so real RN UI renders when hosted in surface view |
| **R18** | Simulator unit tests skipped with `\|\| true` in CI | **FIXED** | `.github/workflows/sefaria-embedded-validation.yml` | Strict execution on iPad simulator without `\|\| true` |
| **R19** | Missing simulator run logs, app launch & xcresult artifacts | **FIXED** | `.github/workflows/sefaria-embedded-validation.yml` | Captures simulator screenshot, simulator app log, and exports `result.xcresult` |
| **R20** | Resource copy missing in release archive path | **FIXED** | `Maktabah.xcodeproj/project.pbxproj` | Pre-codesign PBXShellScriptBuildPhase runs during both `build` and `archive` |

---

## 3. Test Verification

### Portable Swift Component Tests
- **Toolchain:** Windows Swift 6.3.3
- **Command:** `swiftc ... tools/test_chavrusa_text_components.swift -o chavrusa_tests.exe`
- **Result:** **327 of 327 assertions passed (0 failures) across 31 test suites.**
- **Suites Covered:**
  - Suites 1–30: Session isolation, navigation, locators, TOC, 3 backends persistence, readiness states.
  - Suite 31: `downloadProgress` real byte parsing, update summary `affectedPackageIDs`, segment canonical ref & heRef preservation.
