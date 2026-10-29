# QA & Acceptance Evidence — Sefaria-Mobile Embedded Integration

**Date:** October 29, 2026  
**Host Repository:** `https://github.com/davidpovarsky/Maktabah`  
**Base Commit:** `349a021321322ade0a1f16700bf8c1e44192f49c`  
**Branch:** `experiment/sefaria-mobile-original-embedded-20261029`  
**Upstream Repository:** `https://github.com/Sefaria/Sefaria-Mobile` (`2fd173a5a3bd32d94a9ba1222e4e32a37f6bd23c`)  
**Target:** iOS/iPadOS ChavrusaText (`com.davidpovarsky.chavrusatext`)

---

## 1. Truthful Status of Execution Gates (Per Policy K20)

| Gate | Description | Status | Evidence & Concrete Findings |
|---|---|:---:|---|
| **Gate A** | Original project provenance & build configuration | **PASS** | Pinned submodule at `2fd173a5a3bd32d94a9ba1222e4e32a37f6bd23c` verified in `.gitmodules` and initialized locally. `Podfile` updated to target `Maktabah-iOS` (iOS 18.6) rather than macOS `Maktabah`. Metro production bundle generation in `.github/workflows/ios-testflight.yml` hardened without `\|\| true`. |
| **Gate B** | React Native state/lifecycle & bidirectional bridge | **VERIFIED IN CONTRACT / BLOCKED FOR MACOS RUNNER** | `ChavrusaRoot.js` mounts `GlobalStateContext`, `DispatchContext`, `SafeAreaProvider`, `ErrorBoundary`. `ChavrusaSefariaBridgeModule` implements registered JS dispatchers and callable module hooks. Wire schema unified with `paramsJson`/`resultJson`. Local runtime execution requires macOS Xcode environment; static and portable test contracts verified. |
| **Gate C** | 3-source identity & persistence isolation | **PASS** | `BackendID.otzaria`, `.sefaria`, `.sefariaEmbedded` verified. Raw values immutable (`"sefaria"` preserved for legacy). `TextLocator.persistenceKey` distinct. `BackendSessionIntegrityRepair` tested with 3-source mixed sessions. Round-trip JSON persistence verified in portable suite (Suites 25 & 26). |
| **Gate D** | Native screens using original engine contracts | **VERIFIED IN CODE CONTRACTS / NOT_RUN ON SIMULATOR** | All 6 downstream adapters conform strictly to `LibraryBackendProtocols`: Catalog (recursive category/book hierarchy), Text (`textContent.content` segment array), Navigation (`textToc` schema & alts), Search (`start`/`size` queryProps), Relationships (`links` and `topics`), Downloads (`DownloadControl.js` exact 2-arg signature). Live simulator rendering requires macOS CI. |
| **Gate E** | Build, release & performance safeguards | **CONFIGURED / PENDING CI DISPATCH** | Single-flight `SefariaRuntimeManager` actor prevents concurrent startup. Non-blocking RPC bridge with actor-owned in-flight map and leak-free cancellation/timeout handling. Metro bundle step made non-optional in CI. TestFlight upload set to `false` by default. |
| **Gate F** | Licensing, privacy & Apple policy | **PASS** | GPL-3.0 attribution preserved. No hardcoded credentials or private keys. Privacy-safe RPC error logging. |
| **Physical QA** | Physical iPad Acceptance Testing | **PENDING** | Explicitly pending owner execution on physical iPad hardware. |

---

## 2. Test Execution Details

### 2.1 Portable Test Suite (`tools/test_chavrusa_text_components.swift`)
- **Toolchain:** Windows Swift 6.3.3
- **Executable:** `scratch/chavrusa_tests.exe`
- **Total Assertions:** 307
- **Passed:** 307 (100%)
- **Failed:** 0
- **Suites:** 29 complete test suites covering:
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
  - **Suite 27: SefariaRPC Wire Models & JSON Boundary Roundtrip**
  - **Suite 28: SefariaEmbedded Protocol & Model Conformance**
  - **Suite 29: SefariaEmbedded Text & Relationship Structures**

### 2.2 XCTest Target (`MaktabahTests/ChavrusaTextComponentTests.swift`)
- Added unit tests:
  - `testThreeSourceBackendIdentityAndLocalization()`
  - `testThreeSourceTextLocatorPersistenceAndSessionIsolation()`
  - `testSefariaRPCWireModelsAndDecodeResult()`
  - `testSefariaEmbeddedOfflineAndSearchModels()`
  - `testSefariaEmbeddedTextAndRelationshipsStructures()`
- All registered in `Maktabah.xcodeproj/project.pbxproj`.
