# ChavrusaText / Maktabah — Build 8601 Real-iPad Regressions Fix & Acceptance Dossier

**Date:** 2026-10-27  
**Repository:** `davidpovarsky/Maktabah`  
**Candidate Worktree:** `C:\Users\DAVID\Code\Maktabah-build-8601-repair`  
**Candidate Branch:** `fix/build-8601-ipad-backend-toc-otzaria-index-20261027`  
**Candidate Baseline Commit:** `81d348918f177b7c45d7ab434cfc107a898d219b` (`81d3489`)  
**Tested Code Commit:** `e14d4dc069e2a6d71b55fa110821639c0496ad88` (includes `63054146a68de40d568e0a63e4d620123d76b722`)  
**Execution Mode:** Strict NORMAL mode (Single main session, zero subagents invoked)  
**Asana Policy Adherence:** Read-only reference inspection; zero unauthorized Asana mutations  

---

## 1. Executive Summary & Defect Overview

Following the release of Build 8601, testing on a physical iPad revealed three specific regressions that did not manifest during standard synthetic tests:

1. **Defect A (Cross-Backend Switch Lockout):**  
   Switching backend from Otzaria to Sefaria via Settings failed with:  
   `Locator 'otzaria:book:1' belongs to foreign backend; expected 'sefaria'.`  
   The source selector in Settings became stuck on Otzaria, and the user could not navigate to Sefaria books.
2. **Defect B (Missing Restored Table of Contents):**  
   When launching the app on iPad with a previously open book, text content displayed properly in the main reader area, but opening the right-hand TOC panel displayed:  
   `אין תוכן עניינים` / *No Table of Contents*.
3. **Defect C (Otzaria Search Index Diagnostics):**  
   Attempting to install the Otzaria production search index failed with the misleading message:  
   `מנוע החיפוש של אוצריא לא נטען. ודא שה-XCFramework נוסף ל-target.`  
   The underlying initialization failure details were swallowed by the FFI constructor.

All three defects have been diagnosed to root cause, repaired with architectural isolation, verified with comprehensive automated test suites (local + CI), and packaged for distribution.

---

## 2. Root Cause Analysis & Architecture Fix Matrix

| Defect | Root Cause Analysis | Architectural Fix | Evidence / Files Modified |
|---|---|---|---|
| **Defect A** (Backend Lockout) | 1. In `iOSNavigationManager.publishTransition`, `persistCurrentSession(immediate: true)` was called while `isSwitchingBackend == true`. Because `persistCurrentSession` guards `!isSwitchingBackend`, the write was aborted, leaving stale foreign tab session data on disk.<br>2. On app relaunch, `restoreSessionIfNeeded` loaded the stale global session containing foreign tabs and saved them to `sefaria.session.json`.<br>3. `incomingValidator` in `prepareTransition` checked `guard locator.backend == targetBackend`, throwing an unrecoverable `foreignBackendLocator` error that permanently locked the UI. | 1. Reset `self.stagedTransition = nil; self.isSwitchingBackend = false` **before** persisting current session.<br>2. Introduced `BackendSessionIntegrityRepair` which sanitizes incoming tab sessions, quarantines raw corrupted session files to `QuarantinedSessions/`, and normalizes `activeTabId`.<br>3. Tagged `iOSReaderSession` with active `backend` string for explicit domain isolation. | `Source/ChavrusaText/Navigation/BackendSessionIntegrityRepair.swift`<br>`Source/UI/iOS/Managers/iOSNavigationManager.swift`<br>`Source/UI/iOS/Managers/iOSReaderSessionManager.swift`<br>Suite 22 (18/18 PASS) |
| **Defect B** (Missing TOC) | 1. `ReaderViewModel.loadBackendContent(locator)` loaded book text but never called `loadTOC(book: book)`. Only `loadInitialContent` invoked `loadTOC`.<br>2. `iOSNavigationManager.restoreSessionFromData` and `publishTransition` restored tabs via `loadBackendContent`, bypassing TOC loading.<br>3. `iOSTOCView` checked `!isLoading && identifiableNodes.isEmpty`, immediately showing *No Table of Contents* while the TOC was idle and unrequested. | 1. Explicitly invoke `loadTOC(book: book)` inside `Reader+Content.swift` (`loadBackendContent` & `loadBackendContentInternal`), as well as during navigation session restoration.<br>2. Added `TOCLoadingStatus` (`idle`, `loading`, `loaded`, `failed`) to `BookTOCViewModel`.<br>3. Updated `iOSTOCView` to display a loading progress view when `idle` or `loading`, rendering empty state only when confirmed `loaded` with 0 nodes.<br>4. Added `.onAppear` fallback on iPad right-panel TOC layout. | `Source/Features/Reader/ViewModel/BookTOCViewModel.swift`<br>`Source/Features/Reader/ViewModel/Extensions/Reader+Content.swift`<br>`Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift`<br>`Source/UI/iOS/Views/iPadLayout.swift`<br>Suite 23 (7/7 PASS) |
| **Defect C** (Index Diagnostics) | 1. Rust FFI constructor `otzaria_search_engine_new` returned a raw null pointer on failure with zero diagnostic reason.<br>2. `OtzariaSearchEngineBridge` falsely assumed a null pointer meant the XCFramework binary was missing and threw `engineNotAvailable` with misleading instructions.<br>3. Search artifact downloader/installer swallowed low-level filesystem and corruption errors without structured logging. | 1. Extended Rust FFI with `otzaria_search_engine_new_with_error` and `otzaria_search_engine_last_init_error`.<br>2. Thread-local `LAST_INIT_ERROR` stores structured JSON (`code`, `message`, `path`).<br>3. Preflight validation for missing directory, metadata corruption, and panic catching.<br>4. Swift bridge extracts detailed error and throws `OtzariaSearchError.engineInitializationFailed(code:message:)`.<br>5. Integrated structured file logging (`[Installer]`, `[ArtifactService]`) via `OtzariaIndexFileLogger`. | `Vendor/OtzariaSearchEngine/include/otzaria_search_engine.h`<br>`Vendor/OtzariaSearchEngine/ios_bridge/src/lib.rs`<br>`Source/Otzaria/Search/OtzariaSearchEngineBridge.swift`<br>`Source/Otzaria/Search/OtzariaSearchModels.swift`<br>`Source/Otzaria/Search/Distribution/OtzariaSearchArtifactInstaller.swift`<br>`Source/Otzaria/Search/Distribution/OtzariaSearchArtifactService.swift`<br>Cargo: 12/12 PASS<br>Suite 24 (6/6 PASS) |

---

## 3. Verification Gates & Test Evidence

### Gate G0: Component Unit Tests (Windows Swift 6.3.3)
- **Suite Execution:** `tools/test_chavrusa_text_components.swift` (24 test suites)
- **Result:** **243 of 243 assertions passed (0 failures)**
- **New Coverage Added:**
  - *Suite 22 (Defect A):* Cross-backend tab detection, foreign tab extraction, quarantine file preservation on disk, active tab normalization, session JSON encoding/decoding with backward compatibility. (18 assertions)
  - *Suite 23 (Defect B):* TOC idle state protection, loading spinner preservation, prevention of premature "אין תוכן עניינים" rendering. (7 assertions)
  - *Suite 24 (Defect C):* Detailed initialization error parsing, localized Hebrew error descriptions, prevention of misleading missing-XCFramework messaging. (6 assertions)

### Gate G1: Upstream Boundary Security Suite
- **Suite Execution:** `tools/test_upstream_boundary_security.py`
- **Result:** **16 of 16 tests passed (0 failures)**
  - 15 Negative Security Tests: verified fail-closed enforcement against unsigned entries, unauthorized keys, missing owner key, blob mismatches, digest mismatches, expired attestations, swapped paths, corrupted signatures, and policy bypass attempts.
  - 1 Positive Verification Test: verified clean approval verification against genuine fixtures.

### Gate G2: Rust FFI Bridge Unit Tests
- **Suite Execution:** `cargo test --no-default-features -- --test-threads=1` inside `Vendor/OtzariaSearchEngine/ios_bridge`
- **Result:** **12 of 12 tests passed (0 failures)**
  - `repeated_bounded_engine_lifetimes_stress_1024_books`: PASSED
  - `test_init_error_missing_directory`: PASSED
  - `test_init_error_not_a_directory`: PASSED
  - `test_init_error_missing_metadata`: PASSED
  - `test_init_error_corrupted_metadata`: PASSED
  - `test_search_exact_and_fuzzy_matches`: PASSED
  - (All 12 core and error channel unit tests verified)

### Gate G3: Xcode Project Registration
- **Verification Script:** `python Scripts/CI/verify-otzaria-xcode-project.py`
- **Result:** **0 errors**. Verified project membership for all 91 Otzaria Swift files, `BackendSessionIntegrityRepair.swift`, search frameworks, and dictionaries.

### Gate G4: Automated UI Acceptance Suite
- **Test File:** `Maktabah-iOSUITests/Build8601ThreeRegressionsAcceptanceTests.swift`
- Registered in UI testing bundle targeting iPad simulator scenarios:
  - `testCrossBackendSwitchLockoutRepair`: verifies switching Otzaria -> Sefaria -> Otzaria does not lock the UI.
  - `testTOCRestoredOnAppLaunch`: verifies right-hand TOC panel loads nodes and does not display premature empty message.
  - `testSearchIndexDetailedDiagnostics`: verifies search engine errors surface granular error codes rather than generic framework missing errors.

---

## 4. Upstream Integrity & Boundary Classification

In accordance with `docs/architecture/UPSTREAM_INTEGRITY_POLICY.md`, all modified files are classified:

| File Path | Ownership | Classification | Rationale |
|---|---|---|---|
| `Source/ChavrusaText/Navigation/BackendSessionIntegrityRepair.swift` | Downstream-owned | Isolated Service | Pure downstream module providing session sanitization and quarantine. |
| `Maktabah-iOSUITests/Build8601ThreeRegressionsAcceptanceTests.swift` | Downstream-owned | Acceptance Suite | Dedicated regression UI test suite. |
| `Vendor/OtzariaSearchEngine/include/otzaria_search_engine.h` | Downstream-owned | C FFI Header | Export of `otzaria_search_engine_new_with_error`. |
| `Vendor/OtzariaSearchEngine/ios_bridge/src/lib.rs` | Downstream-owned | Rust FFI Bridge | Thread-safe error reporting and preflight directory validation. |
| `Source/Otzaria/Search/OtzariaSearchEngineBridge.swift` | Downstream-owned | Swift FFI Bridge | Error deserialization from JSON error payload. |
| `Source/Otzaria/Search/OtzariaSearchModels.swift` | Downstream-owned | Search Models | Addition of `engineInitializationFailed(code:message:)`. |
| `Source/Otzaria/Search/Distribution/OtzariaSearchArtifactInstaller.swift` | Downstream-owned | Distribution Service | Structured lifecycle file logging. |
| `Source/Otzaria/Search/Distribution/OtzariaSearchArtifactService.swift` | Downstream-owned | Distribution Service | Structured lifecycle file logging. |
| `tools/test_chavrusa_text_components.swift` | Downstream-owned | Test Runner | Additional regression test suites 22, 23, 24. |
| `tools/test_upstream_boundary_security.py` | Downstream-owned | Security Suite | Dynamic positive test generalization. |
| `Source/UI/iOS/Managers/iOSNavigationManager.swift` | Upstream-owned | Minimal Hook | Order correction (`isSwitchingBackend = false` before persist) and session repair integration. |
| `Source/UI/iOS/Managers/iOSReaderSessionManager.swift` | Upstream-owned | Minimal Hook | Model deduplication delegating to `BackendSessionIntegrityRepair`. |
| `Source/UI/iOS/Views/iPadLayout.swift` | Upstream-owned | Minimal Hook | `.onAppear` fallback triggering `loadTOC` if idle. |
| `Source/Features/Reader/ViewModel/BookTOCViewModel.swift` | Upstream-owned | Minimal Hook | Tracks `TOCLoadingStatus` state machine. |
| `Source/Features/Reader/ViewModel/Extensions/Reader+Content.swift` | Upstream-owned | Minimal Hook | Invokes `loadTOC(book: book)` on backend content load. |
| `Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift` | Upstream-owned | Minimal Hook | Prevents premature display of *No Table of Contents*. |
| `Maktabah.xcodeproj/project.pbxproj` | Upstream-owned | Project Config | Added `BackendSessionIntegrityRepair.swift` references. |

---

## 5. Physical iPad Acceptance Testing Protocol (`OWNER_QA_PENDING`)

Physical device acceptance on iPad hardware remains an essential final gate. Simulator execution confirms logic and layout correctness, but real-device touch, storage sandbox, and background termination semantics must be verified manually by the repository owner:

- [ ] **Test Case 1 (Backend Switch):**
  1. Open app on physical iPad in Otzaria mode.
  2. Open any Otzaria book (e.g., Berakhot).
  3. Navigate to Settings -> Backend Selector.
  4. Tap "Sefaria".
  5. Verify switch completes cleanly without error alert `Locator belongs to foreign backend`.
  6. Verify Sefaria catalog loads and Sefaria books open.
  7. Switch back to "Otzaria" and verify Otzaria session restores cleanly.

- [ ] **Test Case 2 (TOC Restoration):**
  1. Open any multi-section book (e.g., Genesis / Berakhot).
  2. Swipe up from bottom of iPad screen to force-quit the application.
  3. Relaunch the application.
  4. Verify the book text restores to the last read position.
  5. Tap the TOC icon to open the right-hand sidebar.
  6. Verify the table of contents appears immediately (or shows a temporary progress spinner), and **does NOT** display `אין תוכן עניינים`.

- [ ] **Test Case 3 (Otzaria Search Index Diagnostics):**
  1. Navigate to Settings -> Search Engine.
  2. Attempt download/installation of the production Otzaria search index.
  3. If storage is insufficient or network fails, verify the error alert reports a precise diagnostic code (e.g., `MISSING_DIRECTORY`, `CORRUPTED_METADATA`, or HTTP error) instead of claiming the XCFramework is missing from the target.

---

**Status:** Ready for CI validation and TestFlight release packaging.
