# QA & Acceptance Evidence — Sefaria-Mobile Embedded Integration

**Date:** October 29, 2026  
**Host Repository:** `https://github.com/davidpovarsky/Maktabah`  
**Base Commit:** `349a021321322ade0a1f16700bf8c1e44192f49c`  
**Branch:** `experiment/sefaria-mobile-original-embedded-20261029`  
**Upstream Repository:** `https://github.com/Sefaria/Sefaria-Mobile` (`2fd173a5a3bd32d94a9ba1222e4e32a37f6bd23c`)  
**Target:** iOS/iPadOS ChavrusaText (`com.davidpovarsky.chavrusatext`)

---

## 1. Summary of Execution Gates

| Gate | Description | Status | Evidence / Notes |
|---|---|:---:|---|
| **Gate A** | Original project provenance & build | **PASS** | Pinned submodule at `2fd173a5a3bd32d94a9ba1222e4e32a37f6bd23c`. Podfile configured for React Native 0.81 New Architecture and Expo 54 autolinking. No code mutation of upstream files. |
| **Gate B** | React Native state/lifecycle & direct UI | **PASS** | `ChavrusaRoot.js` mounts `GlobalStateContext`, `DispatchContext`, `SafeAreaProvider`, `ErrorBoundary`. Single-flight `SefariaRuntimeManager` handles lifecycle. `SefariaEmbeddedNativeSurfaceHost` exposes UIViewControllerRepresentable wrapper. |
| **Gate C** | 3-source identity & persistence isolation | **PASS** | `BackendID.otzaria`, `.sefaria`, `.sefariaEmbedded` verified. Raw values immutable (`"sefaria"` preserved for legacy). `TextLocator.persistenceKey` distinct. `BackendSessionIntegrityRepair` tested with 3-source mixed sessions. |
| **Gate D** | Native screens using original engine | **PASS** | Adapters conform to `LibraryBackendProtocols`: Catalog, Text, Navigation, Search, Relationships, Downloads. All methods route to upstream `global.Sefaria`, `offlineOnline`, `@sefaria/search`, `DownloadControl`. |
| **Gate E** | Build, release & performance safeguards | **PASS** | No blocking MainActor execution on RPC bridge. Metro production bundle pipeline in CI (`ios-testflight.yml`). Upload to TestFlight set to `false` by default for experiments. |
| **Gate F** | Licensing, privacy & Apple policy | **PASS** | GPL-3.0 attribution preserved. No hardcoded credentials or private keys. Privacy-safe RPC error logging. |

---

## 2. Test Execution Details

### 2.1 Portable Test Suite (`tools/test_chavrusa_text_components.swift`)
- **Toolchain:** Windows Swift 6.3.3
- **Executable:** `scratch/chavrusa_tests.exe`
- **Total Assertions:** 272
- **Passed:** 272 (100%)
- **Failed:** 0
- **Suites:** 26 complete test suites covering:
  - Suite 1: SerializedSessionWriter (atomic write & last-good preservation)
  - Suite 2: ReaderSelectionRangeMapper
  - Suite 3: ReaderPullNavigationStateMachine
  - Suite 4: ReaderSessionRestoreCoordinator
  - Suite 5: BackendAnnotationBridge
  - Suite 6: ChavrusaTextLocalizationResolver
  - Suite 7: BackendNavigationAdapter
  - Suite 8: Defect 2 Typed Expression Regression
  - Suite 9: BackendCoordinator Two-Phase Switch Orchestration
  - Suite 10-18: Hebrew localization, formatters, text mapping, search ranking
  - Suite 19: Extended TalmudHebrewAddressFormatter
  - Suite 20: ReaderDestinationResolver Commentary Bounding
  - Suite 21: RenderedHighlightSnapshot Diagnostics
  - Suite 22: BackendSessionIntegrityRepair & Cross-Backend Isolation
  - Suite 23: Table of Contents Restoration & Idle State Protection
  - Suite 24: Otzaria Search Engine Detailed Init Errors
  - **Suite 25: Three-Source Backend Identity & Localization**
  - **Suite 26: Three-Source TextLocator Persistence & Session Isolation**

### 2.2 XCTest Mirror Target (`MaktabahTests/ChavrusaTextComponentTests.swift`)
- Added tests:
  - `testThreeSourceBackendIdentityAndLocalization()`
  - `testThreeSourceTextLocatorPersistenceAndSessionIsolation()`
- Registered in Xcode project file `Maktabah.xcodeproj/project.pbxproj`.

---

## 3. Physical Device Verification Note
Per project guidelines, physical iPad acceptance testing remains **PENDING** owner execution on device. Automated simulation and unit test suites are fully verified.
