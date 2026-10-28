# ChavrusaText — Sefaria-Mobile Original Embedded Integration Baseline

**Date:** 2026-10-29  
**Host Repository:** `https://github.com/davidpovarsky/Maktabah`  
**Verified Base Branch:** `fix/build-8601-ipad-backend-toc-otzaria-index-20261027`  
**Verified Base Commit:** `349a021321322ade0a1f16700bf8c1e44192f49c`  
**Experiment Branch:** `experiment/sefaria-mobile-original-embedded-20261029`  
**Target Bundle ID:** `com.davidpovarsky.chavrusatext`  
**Official Sefaria Repository:** `https://github.com/Sefaria/Sefaria-Mobile`  
**Pinned Official Sefaria Commit:** `2fd173a5a3bd32d94a9ba1222e4e32a37f6bd23c` on `master`  
**Sefaria Stack:** React `19.1.4`, React Native `0.81.6`, Expo `~54.0.0`, `@sefaria/search` `^0.10.0`

---

## 1. Verified Baseline Test Status

### 1.1 Portable Swift Component Tests (Local Windows Workstation)
- **Toolchain:** Swift 6.3.3 (`x86_64-unknown-windows-msvc`)
- **Command:**
  ```powershell
  swiftc -parse-as-library -o scratch/chavrusa_tests.exe tools/test_chavrusa_text_components.swift `
    Source/ChavrusaText/ReaderRendering/ReaderPullNavigationStateMachine.swift `
    Source/ChavrusaText/ReaderRendering/ReaderSelectionRangeMapper.swift `
    Source/ChavrusaText/Annotations/BackendAnnotationBridge.swift `
    Source/ChavrusaText/Navigation/ReaderSessionRestoreCoordinator.swift `
    Source/ChavrusaText/Navigation/SerializedSessionWriter.swift `
    Source/ChavrusaText/Navigation/BackendNavigationAdapter.swift `
    Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift `
    Source/ChavrusaText/Localization/TalmudHebrewAddressFormatter.swift `
    Source/ChavrusaText/Navigation/ReaderDestinationResolver.swift `
    Source/ChavrusaText/Navigation/ReaderBackendPagingCoordinator.swift `
    Source/ChavrusaText/Navigation/ReaderContentLoadCoordinator.swift `
    Source/ChavrusaText/Search/ReaderSearchContextCoordinator.swift `
    Source/ChavrusaText/Navigation/TOCReadingLocationTracker.swift `
    Source/ChavrusaText/Navigation/TargetBackendBookResolver.swift `
    Source/ChavrusaText/Testing/ReaderRenderedHighlightInspector.swift `
    Source/Sefaria/Domain/SefariaModels.swift `
    Source/Sefaria/Offline/SefariaExportModels.swift `
    Source/Sefaria/Offline/SefariaOfflinePaths.swift `
    Source/LibraryBackend/LibraryBackendProtocols.swift `
    Source/LibraryBackend/LibraryBackendModels.swift `
    Source/LibraryBackend/LibraryPresentationPolicy+Display.swift `
    Source/LibraryBackend/LegacyIdentityRegistry.swift `
    Source/LibraryBackend/BackendCoordinator.swift `
    Source/ChavrusaText/Navigation/BackendSessionIntegrityRepair.swift `
    Source/Otzaria/Search/OtzariaSearchMode.swift `
    Source/Otzaria/Search/OtzariaSearchModels.swift
  ./scratch/chavrusa_tests.exe
  ```
- **Execution Result:**
  - 24 suites executed
  - **243 of 243 assertions passed (0 failures)**
  - All regression tests (Build 8401, 8601, 8701) passing.

### 1.2 Prior CI & TestFlight Baseline
- **Build 8701:** Validated in CI Run 40233963450 with 24/24 iPad simulator UI tests passed.
- **Physical Device Gate:** Physical iPad testing status remains recorded as `PENDING_OWNER_DEVICE_QA`.

---

## 2. Three-Source Architecture & Identity Contracts

### 2.1 Backend IDs and Labels
| Source Label (Hebrew) | Source Label (English) | `BackendID.rawValue` | Implementation | Storage Path |
|---|---|---|---|---|
| **אוצריא** | `Otzaria` | `otzaria` | `OtzariaGenericBackendAdapter` | `Application Support/Maktabah/otzaria/` |
| **ספריא (ישן)** | `Sefaria (Legacy)` | `sefaria` | `SefariaBackend` (Existing Swift hybrid) | `Application Support/Maktabah/SefariaOffline/` |
| **ספריא** | `Sefaria` | `sefariaEmbedded` | Sefaria-Mobile React Native / Expo Runtime | `expo-file-system` (`Documents/library/`, `Cache/tmp/`) |

### 2.2 Inviolable Isolation Rules
1. `.sefaria.rawValue == "sefaria"` remains strictly mapped to the existing Swift implementation.
2. No automated or forced migration of `.sefaria` user data to `.sefariaEmbedded`.
3. Separate namespaces in `TextLocator.persistenceKey`, `BackendNavigationAdapter` session snapshots, annotations, history, and downloads.
4. Switching backends using `BackendCoordinator`'s two-phase protocol maintains clean state restoration without cross-contamination.

---

## 3. Vendored Upstream Provenance
- Cloned whole upstream repository to `Vendor/SefariaMobile/Upstream` at commit `2fd173a5a3bd32d94a9ba1222e4e32a37f6bd23c`.
- ChavrusaText integration bridge and facade placed in `Vendor/SefariaMobile/Integration/` and `Source/SefariaEmbedded/`.
- Zero selective copies or modifications of upstream Sefaria business logic.
