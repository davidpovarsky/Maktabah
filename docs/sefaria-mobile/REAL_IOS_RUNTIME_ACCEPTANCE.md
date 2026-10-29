# ChavrusaText — Sefaria-Mobile Real iOS Runtime Acceptance Dossier

**Branch:** `experiment/sefaria-mobile-original-embedded-20261029`  
**Submodule Pinned SHA:** `2fd173a5a3bd32d94a9ba1222e4e32a37f6bd23c` (`Vendor/SefariaMobile/Upstream`)  
**Target Application:** `com.davidpovarsky.chavrusatext` / Target: `Maktabah-iOS`  
**Platform:** iOS/iPadOS 18.6+ | React Native 0.81.6 | Expo SDK 54 | Hermes  
**Date:** 2026-10-29  

---

## 1. Gates Executive Status & Evidence Matrix

| Gate | Description | Status | Evidence / Verification Provenance | Blockers / Next Step |
|---|---|---|---|---|
| **Gate 0** | Preparation, Safety & Isolation | **PASS** | Branch clean, submodule locked (`2fd173a`), 3 backends distinct, legacy storage untouched | None. Completed |
| **Gate 1** | Build Graph: Node, Pods, Xcode | **PASS (CI BUILD)** | Podfile targeting `Maktabah-iOS`, platform 18.0, RN New Architecture, `xcodebuild` clean build in CI Run `40958024654` | None. 100% verified on Apple Silicon runner |
| **Gate 2** | Sefaria Resources in App Bundle | **PASS (CI VERIFIED)** | 7 JSON files + `main.jsbundle` verified in built `Maktabah.app` by `verify-sefaria-bundle-resources.py` (Run `40958024654`) | Artifacts uploaded to GitHub Actions |
| **Gate 3** | Hermes, Expo & Native Host | **PASS (CI BUILD / VERIFIED)** | `SefariaExpoLifecycleAdapter` concrete implementation with `ExpoReactNativeFactory`, headless root window compiled cleanly into app | Live UI on physical iPad pending TestFlight |
| **Gate 4** | Bidirectional RPC & Concurrency | **UNIT PASS (317/317)** | `ChavrusaSefariaBridgeModule.m` exported, actor-isolated `SefariaJSRPCBridge`, Suite 1–30 PASS (Run `40958024654`) | Live Hermes round-trip on physical iPad |
| **Gate 5** | Original Upstream Capabilities | **PASS (CONTRACT / COMPILED)** | Upstream TOC schema/alts, `loadText` segments, `@sefaria/search`, `DownloadControl` tuple handling integrated in bundle | Live iPad verification |
| **Gate 6** | Offline, Isolation & History | **UNIT PASS (317/317)** | Session repair isolation, `persistenceKey` collision prevention, zero legacy migration verified | Physical iPad airplane mode test |
| **Gate 7** | CI Workflow & Truthful Declaration | **PASS** | Workflow `.github/workflows/sefaria-embedded-validation.yml` completed in 16m50s on `xcode-27` (Run `40958024654`), commit `3f57a95` | Ready for Physical iPad Testing |

---

## 2. Upstream Resource Manifest (Gate 2 Evidence)

All 7 upstream JSON resources required by Sefaria-Mobile's `openFileInSources` were scanned, validated for JSON syntax, and checksummed via `Scripts/verify-sefaria-bundle-resources.py`:

| Resource File | Target Bundle Path | Size (Bytes) | SHA-256 Checksum | Syntax Check |
|---|---|---|---|---|
| `calendar.json` | `<AppBundle>/sources/calendar.json` | 1,651,059 | `9613a13f8ce57d206f0e3408c6cf67f339678e72fa5d487227ba1da7925a1762` | **VALID JSON** |
| `hebrew_categories.json` | `<AppBundle>/sources/hebrew_categories.json` | 16,121 | `f3dd97c47a9a4dad0c36098251e604f2dd7b6451e3fe1a221415fbf17ee8d340` | **VALID JSON** |
| `packages.json` | `<AppBundle>/sources/packages.json` | 238,990 | `3c472a17c87169299ee8397a783777f98e6a2613d5cf59b66946059e798e0bb8` | **VALID JSON** |
| `people.json` | `<AppBundle>/sources/people.json` | 52,354 | `b9befdeea0c67a0acb7b62ca7091da3c0b05b9da3a8d1aa3a18a0e08f5d033f2` | **VALID JSON** |
| `search_toc.json` | `<AppBundle>/sources/search_toc.json` | 829,599 | `6d90cc6d333333f81e3d2331590fc081f267a57a1a2b271d1825fa738ebdc6df` | **VALID JSON** |
| `toc.json` | `<AppBundle>/sources/toc.json` | 4,172,545 | `0622b6567fd9e5d166c303f08ca7c6f0928f6b86dcf3da9a293ebf16dc6b60ad` | **VALID JSON** |
| `topic_toc.json` | `<AppBundle>/sources/topic_toc.json` | 1,810,962 | `282603e38c227de9e93b1aa0e5a6ef6c18f3a3bf42861c28c86d38eebcb46892` | **VALID JSON** |

---

## 3. Structural & Architectural Resolutions (F01–F10)

### F01 — Native Host Startup & Expo Lifecycle
- **Implementation:** `Source/SefariaEmbedded/Runtime/SefariaExpoLifecycleAdapter.swift`
- In iOS builds (`#if canImport(UIKit) && canImport(React) && canImport(Expo)`), instantiates `ChavrusaReactNativeDelegate: ExpoReactNativeFactoryDelegate` and `ExpoReactNativeFactory`.
- Creates and retains a background root view (`ChavrusaSefariaRoot`) with `isHidden = true`, `alpha = 0.001`, `isUserInteractionEnabled = false`.
- Bootstraps JavaScript contexts and native module dispatchers without overtaking the SwiftUI window hierarchy or presenting duplicate windows.

### F02 — App Bundle Staged Resources & Metro Bundle
- **Implementation:**
  - `Scripts/copy-sefaria-bundle-resources.sh`: Automates copying `sources/*.json` and `main.jsbundle` into `$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH`.
  - `Scripts/verify-sefaria-bundle-resources.py`: Validates non-empty status, JSON integrity, and produces a verifiable SHA256 manifest.
  - CI validation checks built `.app` DerivedData path and fails fast if resources are missing.

### F03 — Native Module Export in React Native New Architecture
- **Implementation:**
  - Added `Vendor/SefariaMobile/Integration/iOS/ChavrusaSefariaBridgeModule.m` with `RCT_EXTERN_MODULE(ChavrusaSefariaBridgeModule, NSObject)` and `RCT_EXTERN_METHOD`.
  - Extended `ChavrusaSefariaBridgeModule.swift` to conform to `RCTBridgeModule` with `requiresMainQueueSetup() -> Bool`.
  - Guarantees React Native runtime discovery in `NativeModules.ChavrusaSefariaBridgeModule` across New Architecture bridgeless and bridge modes.

### F04 — Granular Health & Capability Readiness
- **Implementation:** `Source/SefariaEmbedded/Runtime/SefariaRuntimeManager.swift`
- Replaced monolithic ready state with `SefariaCapabilityReadiness`:
  - `hostReady`: Native factory and root view initialized.
  - `catalogReady`: `runtime.initialize` succeeded, TOC and index available.
  - `searchReady`: `runtime.postInitSearch` completed.
  - `packagesReady`: `runtime.postInit` completed.
  - `isFullyReady`: All 4 capabilities confirmed.
- `SefariaEmbeddedSearchAdapter` awaits `ensureSearchReady()`.
- `SefariaEmbeddedDownloadAdapter` awaits `ensurePackagesReady()`.
- Sub-tasks track errors explicitly rather than swallowing them in unmonitored detached tasks.

### F05 — Dedicated Validation CI Workflow
- **Implementation:** `.github/workflows/sefaria-embedded-validation.yml`
- Runs submodule checkout (`submodules: recursive`), `npm ci`, Metro production bundle generation, source verification, `pod install`, portable Swift tests, iPad Simulator build, and unit tests without TestFlight upload or distribution certificate requirements.

### F06 — DownloadControl & Update Semantics Parity
- **Implementation:** `Vendor/SefariaMobile/Integration/JS/chavrusaRPCFacade.js` & `SefariaEmbeddedDownloadAdapter.swift`
- `updates.check`: Handles the 2-element tuple `[allBooksToDownload, booksNotDownloaded]` returned by upstream `checkUpdatesFromServer()`.
- `downloads.remove`: Calls upstream `Package.unclick()` on target packages to update AsyncStorage selection and calculate books to delete, followed by `DownloadControl.deleteBooks()`.

---

## 4. Test Evidence & Assertions

```
==========================================
SUMMARY: 317 of 317 assertions passed (0 failures).
RESULT: ALL SUITES PASSED SUCCESSFULLY
==========================================
```

- **Suite 1–24:** Core ChavrusaText session restoration, pull navigation, selection range mapping, and Otzaria search error models (245 assertions).
- **Suite 25:** Three-source backend identity (`otzaria`, `sefaria`, `sefariaEmbedded`), rawValue immutability, Hebrew display titles (10 assertions).
- **Suite 26:** TextLocator persistence isolation and foreign tab sanitization across the 3 independent backends (15 assertions).
- **Suite 27:** SefariaRPC wire models, `paramsJson`, UTF-8 Hebrew preservation, `decodeResult` (10 assertions).
- **Suite 28:** `OfflinePackage`, `OfflineInstallProgress`, `OfflineUpdateSummary`, `LibrarySearchHit` protocol conformances (17 assertions).
- **Suite 29:** `LibraryTextSegment`, `LibraryTextSection`, `LibraryRelatedSource` with `anchorRefs: [String]` (10 assertions).
- **Suite 30:** `SefariaCapabilityReadiness` granular transitions and full readiness verification (10 assertions).

---

## 5. Truthful Status & Execution Declaration

- **Local Host Environment:** Windows Workstation (No native macOS / Xcode GUI).
- **Portable Swift Verification:** **PASS (317/317 assertions in 30 suites)**.
- **Resource Syntax & Checksum Verification:** **PASS (7/7 files validated + main.jsbundle)**.
- **Xcode / iPad Simulator Build Execution:** **PASS (GitHub Actions Run `40958024654`, macOS / Xcode 27, commit `3f57a95`)**.
- **Application Bundle Resource Staging:** **PASS (Maktabah.app fully staged and verified)**.
- **Physical Device iPad Acceptance:** **PENDING PHYSICAL IPAD** (Requires TestFlight distribution or USB sideloading to physical iPad to verify 60fps scrolling and gesture response).
