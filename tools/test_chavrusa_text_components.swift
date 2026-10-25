import Foundation

var totalAssertions = 0
var passedAssertions = 0

func assertCondition(_ condition: Bool, _ message: String, file: StaticString = #file, line: UInt = #line) {
    totalAssertions += 1
    if !condition {
        print("❌ FAILED: \(message) at \(file):\(line)")
        exit(1)
    } else {
        passedAssertions += 1
        print("  [PASS] \(message)")
    }
}

@main
struct TestRunner {
    @MainActor
    static func main() {
        print("=== ChavrusaText Component Tests — Batch B Final Repair Gate ===")
        print("Toolchain: Windows Swift 6.3.3 | Target: Foundation-portable smoke test")

        // 1. SerializedSessionWriter Tests (including Defect 4 atomic clear & failure paths)
        print("\n--- 1. Testing SerializedSessionWriter ---")
        do {
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_writer_\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }

            let targetURL = tempDir.appendingPathComponent("session.json")
            let writer = SerializedSessionWriter(queueLabel: "test.writer.queue")

            // Atomic write
            let initialData = "{\"rev\": 1, \"user\": \"test\"}".data(using: .utf8)!
            try writer.saveImmediately(to: targetURL) { initialData }
            let read1 = try Data(contentsOf: targetURL)
            assertCondition(read1 == initialData, "Initial atomic write verified on disk")

            // Last-good preservation on error
            struct CustomError: Error {}
            do {
                try writer.saveImmediately(to: targetURL) { throw CustomError() }
                assertCondition(false, "Should have thrown CustomError")
            } catch {
                assertCondition(true, "CustomError propagated from saveImmediately")
            }
            let readAfterFail = try Data(contentsOf: targetURL)
            assertCondition(readAfterFail == initialData, "Last-good file preserved after failure")

            // Concurrency: delayed write rev 1 must NOT overwrite newer immediate write rev 2
            let staleData = "{\"stale\": true}".data(using: .utf8)!
            writer.scheduleSave(to: targetURL, debounceInterval: 0.1) { staleData }

            let freshData = "{\"fresh\": true}".data(using: .utf8)!
            try writer.saveImmediately(to: targetURL) { freshData }

            Thread.sleep(forTimeInterval: 0.25)
            let finalData = try Data(contentsOf: targetURL)
            assertCondition(finalData == freshData, "Stale delayed write dropped; fresh data preserved")

            // P3-2 Delayed write error observability
            final class ErrorBox: @unchecked Sendable {
                var reportedRev: UInt64? = nil
            }
            let box = ErrorBox()
            writer.onDelayedWriteError = { rev, err in
                box.reportedRev = rev
            }
            writer.scheduleSave(to: targetURL, debounceInterval: 0.05) {
                throw CustomError()
            }
            let errorDeadline = Date().addingTimeInterval(2.0)
            while box.reportedRev == nil && Date() < errorDeadline {
                Thread.sleep(forTimeInterval: 0.02)
            }
            assertCondition(box.reportedRev != nil, "onDelayedWriteError triggered on async failure")
            assertCondition(writer.lastDelayedWriteError != nil, "lastDelayedWriteError recorded")

            // Defect 4: Atomic clearSession canceling pending delayed save
            let pendingClearData = "{\"should_be_cleared\": true}".data(using: .utf8)!
            writer.scheduleSave(to: targetURL, debounceInterval: 0.2) { pendingClearData }
            try writer.clear(at: targetURL)
            assertCondition(!FileManager.default.fileExists(atPath: targetURL.path), "Target file deleted on atomic clear")

            Thread.sleep(forTimeInterval: 0.3)
            assertCondition(!FileManager.default.fileExists(atPath: targetURL.path), "Canceled delayed save did NOT resurrect file after clear")

            // Defect 4: Clearing non-existent file succeeds cleanly without error
            let nonExistentURL = tempDir.appendingPathComponent("no_such_file.json")
            try writer.clear(at: nonExistentURL)
            assertCondition(!FileManager.default.fileExists(atPath: nonExistentURL.path), "Clearing non-existent file is safe and idempotent")
        } catch {
            assertCondition(false, "SerializedSessionWriter failed with: \(error)")
        }

        // 2. ReaderSelectionRangeMapper Tests
        print("\n--- 2. Testing ReaderSelectionRangeMapper ---")
        let mapper = ReaderSelectionRangeMapper()
        let sampleText = "שלום עליכם" // 10 UTF-16 code units

        // Valid
        let res1 = mapper.mapSelection(displayedRange: NSRange(location: 0, length: 4), sourceText: sampleText)
        switch res1 {
        case .success(let m):
            assertCondition(m.selectedText == "שלום", "Extracted text matches 'שלום'")
            assertCondition(m.sourceRange == NSRange(location: 0, length: 4), "Range matches [0..<4]")
        case .failure(let e):
            assertCondition(false, "Valid range failed: \(e)")
        }

        // Empty selection
        let emptyRes = mapper.mapSelection(displayedRange: NSRange(location: 0, length: 0), sourceText: sampleText)
        assertCondition(emptyRes == .failure(.emptySelection), "Empty range rejected")

        // Negative location
        let negRes = mapper.mapSelection(displayedRange: NSRange(location: -5, length: 2), sourceText: sampleText)
        assertCondition(negRes == .failure(.negativeLocation(-5)), "Negative location rejected")

        // Arithmetic overflow
        let maxInt = Int.max
        let overflowRes = mapper.mapSelection(displayedRange: NSRange(location: maxInt - 2, length: 10), sourceText: sampleText)
        if case .failure(.integerOverflow(let loc, let len)) = overflowRes {
            assertCondition(loc == maxInt - 2 && len == 10, "Overflow detected: loc \(loc), len \(len)")
        } else {
            assertCondition(false, "Expected integerOverflow error, got \(overflowRes)")
        }

        // Out of bounds
        let oobRes = mapper.mapSelection(displayedRange: NSRange(location: 8, length: 5), sourceText: sampleText)
        if case .failure(.outOfBounds(let loc, let len, _, _)) = oobRes {
            assertCondition(loc == 8 && len == 5, "Out of bounds rejected: loc \(loc), len \(len)")
        } else {
            assertCondition(false, "Expected outOfBounds error, got \(oobRes)")
        }

        // Surrogate pair split protection
        let emojiText = "א\u{1F600}ב" // 'א' at 0, emoji at 1..2 (surrogates), 'ב' at 3
        let splitRes1 = mapper.mapSelection(displayedRange: NSRange(location: 2, length: 2), sourceText: emojiText)
        if case .failure(.invalidUnicodeBoundary) = splitRes1 {
            assertCondition(true, "Split surrogate pair at start rejected")
        } else {
            assertCondition(false, "Expected invalidUnicodeBoundary error, got \(splitRes1)")
        }

        let splitRes2 = mapper.mapSelection(displayedRange: NSRange(location: 0, length: 2), sourceText: emojiText)
        if case .failure(.invalidUnicodeBoundary) = splitRes2 {
            assertCondition(true, "Split surrogate pair at end rejected")
        } else {
            assertCondition(false, "Expected invalidUnicodeBoundary error, got \(splitRes2)")
        }

        // P3-3: Different render without mapping provider rejects
        let differentRenderRes = mapper.mapSelection(
            displayedRange: NSRange(location: 0, length: 5),
            sourceText: sampleText,
            displayedText: "Transformed Text Here",
            mappingProvider: nil
        )
        assertCondition(differentRenderRes == .failure(.mappingRequiredAcrossDifferentRenders), "Rejects mismatched render without provider")

        // P3-3: Custom mapping provider success
        let mockProvider = ClosureRangeMappingProvider { displayed in
            NSRange(location: displayed.location + 5, length: displayed.length)
        }
        let mappedRes = mapper.mapSelection(
            displayedRange: NSRange(location: 0, length: 5),
            sourceText: sampleText,
            displayedText: "Transformed Text",
            mappingProvider: mockProvider
        )
        switch mappedRes {
        case .success(let m):
            assertCondition(m.sourceRange == NSRange(location: 5, length: 5), "ClosureRangeMappingProvider remapped range correctly")
            assertCondition(m.selectedText == "עליכם", "Extracted remapped source substring correctly")
        case .failure(let e):
            assertCondition(false, "Mapping provider failed: \(e)")
        }

        // 3. ReaderPullNavigationStateMachine Tests
        print("\n--- 3. Testing ReaderPullNavigationStateMachine ---")
        let sm = ReaderPullNavigationStateMachine(pullThreshold: 80.0)
        assertCondition(sm.state == .idle, "Initial state is idle")

        // Pull top past threshold
        _ = sm.handleScroll(topOverscroll: 40.0, bottomOverscroll: 0, isTracking: true, isRestoringScroll: false)
        assertCondition(sm.state == .dragging(direction: .prev, overscroll: 40.0, progress: 0.5), "State is dragging prev at 0.5")

        let armedRes = sm.handleScroll(topOverscroll: 85.0, bottomOverscroll: 0, isTracking: true, isRestoringScroll: false)
        assertCondition(armedRes.shouldTriggerHaptic == true, "Haptic triggered on arming")
        assertCondition(sm.state == .armed(direction: .prev, overscroll: 85.0), "State is armed prev")

        // Non-tracking bounce deceleration must PRESERVE armed state
        _ = sm.handleScroll(topOverscroll: 70.0, bottomOverscroll: 0, isTracking: false, isRestoringScroll: false)
        assertCondition(sm.state == .armed(direction: .prev, overscroll: 85.0), "Armed state preserved during bounce scroll")

        // Commit navigation
        let committed = sm.handleEndDragging(willDecelerate: false)
        assertCondition(committed == .prev, "Committed direction is prev")
        assertCondition(sm.state == .idle, "State reset to idle after commit")

        // Retreat below threshold disarms
        _ = sm.handleScroll(topOverscroll: 90.0, bottomOverscroll: 0, isTracking: true, isRestoringScroll: false)
        _ = sm.handleScroll(topOverscroll: 0.0, bottomOverscroll: 0, isTracking: true, isRestoringScroll: false)
        assertCondition(sm.state == .idle, "Retreating below threshold while tracking disarms to idle")
        assertCondition(sm.handleEndDragging(willDecelerate: false) == nil, "No navigation dispatched after retreat")

        // 4. ReaderSessionRestoreCoordinator Tests
        print("\n--- 4. Testing ReaderSessionRestoreCoordinator ---")
        struct DummyTab: Identifiable, Equatable {
            let id: UUID
            let name: String
        }
        let t1 = DummyTab(id: UUID(), name: "One")
        let t2 = DummyTab(id: UUID(), name: "Two")
        let tabs = [t1, t2]
        let coord = ReaderSessionRestoreCoordinator()

        // Valid ID
        let resValid = coord.resolveActiveTab(savedActiveId: t2.id, restoredTabs: tabs)
        assertCondition(resValid.activeTabId == t2.id, "Valid saved ID resolved")
        assertCondition(!resValid.wasStaleIdNormalized, "No normalization for valid ID")

        // Stale ID
        let staleId = UUID()
        let resStale = coord.resolveActiveTab(savedActiveId: staleId, restoredTabs: tabs)
        assertCondition(resStale.activeTabId == t1.id, "Stale ID safely normalized to tab 1")
        assertCondition(resStale.wasStaleIdNormalized, "wasStaleIdNormalized is true")

        // Empty
        let resEmpty = coord.resolveActiveTab(savedActiveId: staleId, restoredTabs: [DummyTab]())
        assertCondition(resEmpty.activeTabId == nil, "Empty tabs resolve to nil active tab")

        // 5. BackendAnnotationBridge Tests (including Defect 1 Int non-optional validation)
        print("\n--- 5. Testing BackendAnnotationBridge ---")
        let bridge = BackendAnnotationBridge.shared
        do {
            let loc = try bridge.resolveLocator(bookId: 101, workKey: "berakhot", backendID: "otzaria", contentId: 42)
            assertCondition(loc.backend == .otzaria, "Backend is otzaria")
            assertCondition(loc.workKey == "berakhot", "WorkKey is berakhot")
            assertCondition(loc.position == .legacyLine(42), "Position is legacyLine(42)")

            // Defect 1: Valid non-optional Int contentId >= 0 resolves correctly
            let validContentId: Int = 15
            let locValid = try bridge.resolveLocator(bookId: 202, workKey: nil, backendID: "otzaria", contentId: validContentId)
            assertCondition(locValid.workKey == "book:202", "Fallback canonical workKey is book:202")
            assertCondition(locValid.position == .legacyLine(15), "Position is legacyLine(15)")

            // Defect 1: Sentinel contentId check simulation: contentId < 0 must return nil
            func simulatedAnnotationLocator(bookId: Int, contentId: Int) -> TextLocator? {
                guard contentId >= 0 else { return nil }
                return try? bridge.resolveLocator(bookId: bookId, workKey: nil, backendID: "otzaria", contentId: contentId)
            }
            assertCondition(simulatedAnnotationLocator(bookId: 100, contentId: 5) != nil, "Valid contentId >= 0 returns locator")
            assertCondition(simulatedAnnotationLocator(bookId: 100, contentId: -1) == nil, "Sentinel contentId -1 cleanly rejected with nil")

            // P3-3: nil contentId throws missingContentPosition
            do {
                _ = try bridge.resolveLocator(bookId: 101, workKey: "berakhot", backendID: "otzaria", contentId: nil)
                assertCondition(false, "Should have thrown missingContentPosition")
            } catch AnnotationBridgeError.missingContentPosition {
                assertCondition(true, "missingContentPosition thrown for nil contentId")
            }

            // P3-3: invalid backend throws missingLocator
            do {
                _ = try bridge.resolveLocator(bookId: 101, workKey: "berakhot", backendID: "invalid_backend", contentId: 42)
                assertCondition(false, "Should have thrown missingLocator for invalid backend")
            } catch AnnotationBridgeError.missingLocator {
                assertCondition(true, "missingLocator thrown for unknown backendID")
            }

            // Missing locator validation
            do {
                try bridge.validateTarget(range: NSRange(location: 0, length: 5), sourceLength: 20, locator: nil)
                assertCondition(false, "Should have failed missing locator")
            } catch {
                assertCondition(true, "Missing locator properly rejected")
            }

            // In-memory persistence adapter
            let adapter = InMemoryAnnotationPersistenceAdapter()
            let rec = try adapter.persistAnnotation(locator: loc, range: NSRange(location: 0, length: 5), text: "hello", colorHex: "#FFFF00")
            assertCondition(rec.selectedText == "hello", "Persisted record text matches")
            let list = try adapter.fetchAnnotations(for: loc)
            assertCondition(list.count == 1 && list.first?.id == rec.id, "Readback matches persisted record")
        } catch {
            assertCondition(false, "BackendAnnotationBridge test failed: \(error)")
        }

        // 6. ChavrusaTextLocalizationResolver Tests
        print("\n--- 6. Testing ChavrusaTextLocalizationResolver ---")
        assertCondition(ChavrusaTextLocalizationResolver.resolveTabTitle(for: .history, forcedLocaleIdentifier: "he") == "היסטוריה", "History in Hebrew is היסטוריה")
        assertCondition(ChavrusaTextLocalizationResolver.resolveTabTitle(for: .library, forcedLocaleIdentifier: "he") == "ספרייה", "Library in Hebrew is ספרייה")
        assertCondition(ChavrusaTextLocalizationResolver.resolveTabTitle(for: .search, forcedLocaleIdentifier: "he") == "חיפוש", "Search in Hebrew is חיפוש")
        assertCondition(ChavrusaTextLocalizationResolver.resolveTabTitle(for: .narrators, forcedLocaleIdentifier: "he") == "מוסרים", "Narrators in Hebrew is מוסרים")
        assertCondition(ChavrusaTextLocalizationResolver.resolveTabTitle(for: .annotations, forcedLocaleIdentifier: "he") == "הערות", "Annotations in Hebrew is הערות")

        assertCondition(ChavrusaTextLocalizationResolver.resolveTabTitle(for: .history, forcedLocaleIdentifier: "en") == "History", "History in English is History")
        assertCondition(ChavrusaTextLocalizationResolver.resolveTabTitle(for: .library, forcedLocaleIdentifier: "en") == "Library", "Library in English is Library")
        assertCondition(ChavrusaTextLocalizationResolver.resolveTabTitle(for: .search, forcedLocaleIdentifier: "en") == "Search", "Search in English is Search")
        assertCondition(ChavrusaTextLocalizationResolver.resolveTabTitle(for: .narrators, forcedLocaleIdentifier: "en") == "Narrators", "Narrators in English is Narrators")
        assertCondition(ChavrusaTextLocalizationResolver.resolveTabTitle(for: .annotations, forcedLocaleIdentifier: "en") == "Annotations", "Annotations in English is Annotations")

        // 7. BackendNavigationAdapter Tests (including Defect 3 transactional switch & failure injection)
        print("\n--- 7. Testing BackendNavigationAdapter ---")
        do {
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_backend_nav_\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }

            let navAdapter = BackendNavigationAdapter(storageDirectory: tempDir)
            let otzariaData = "{\"tabs\": [1, 2]}".data(using: .utf8)!
            let sefariaData = "{\"tabs\": [3, 4]}".data(using: .utf8)!

            try navAdapter.saveBackendSessionSnapshot(backendID: "otzaria", sessionData: otzariaData)
            try navAdapter.saveBackendSessionSnapshot(backendID: "sefaria", sessionData: sefariaData)

            let retrievedOtz = navAdapter.retrieveBackendSessionSnapshot(backendID: "otzaria")
            let retrievedSef = navAdapter.retrieveBackendSessionSnapshot(backendID: "sefaria")
            assertCondition(retrievedOtz == otzariaData, "Retrieved Otzaria snapshot matches")
            assertCondition(retrievedSef == sefariaData, "Retrieved Sefaria snapshot matches")

            // Clear Otzaria
            try navAdapter.clearBackendSessionSnapshot(backendID: "otzaria")
            assertCondition(navAdapter.retrieveBackendSessionSnapshot(backendID: "otzaria") == nil, "Otzaria snapshot cleared")
            assertCondition(navAdapter.retrieveBackendSessionSnapshot(backendID: "sefaria") == sefariaData, "Sefaria snapshot preserved after Otzaria cleared")

            // P3-2: validateBackendID rejects path traversal
            do {
                _ = try navAdapter.validateBackendID("../../evil")
                assertCondition(false, "Should have rejected path traversal")
            } catch BackendNavigationAdapterError.invalidBackendID {
                assertCondition(true, "validateBackendID rejects path traversal attacks")
            }

            // Defect 3: Transactional switch preparation (success)
            let prepClean = try navAdapter.prepareTransition(
                outgoingBackend: .sefaria,
                outgoingSession: { sefariaData },
                incomingBackend: .otzaria
            )
            assertCondition(prepClean.isCleanDestination, "First visit to otzaria after clear is clean destination")
            assertCondition(navAdapter.transitionState == .outgoingSnapshotPersisted(outgoing: .sefaria, incoming: .otzaria), "Transition state is outgoingSnapshotPersisted")

            navAdapter.commitTransition(incomingBackend: .otzaria)
            assertCondition(navAdapter.transitionState == .uiTransitionCommitted(incoming: .otzaria), "Transition state committed")

            navAdapter.completeTransition(incomingBackend: .otzaria)
            assertCondition(navAdapter.transitionState == .incomingSnapshotRestored(incoming: .otzaria), "Transition state restored")

            // Defect 3 Failure injection: Outgoing snapshot failure rolls back and preserves state
            struct OutgoingFailureError: Error {}
            do {
                _ = try navAdapter.prepareTransition(
                    outgoingBackend: .sefaria,
                    outgoingSession: { throw OutgoingFailureError() },
                    incomingBackend: .otzaria
                )
                assertCondition(false, "Should have thrown on outgoing snapshot failure")
            } catch {
                if case .failed(let err, let rolledBack) = navAdapter.transitionState {
                    assertCondition(rolledBack, "Transition state marked rolledBack: true on failure")
                    assertCondition(!err.isEmpty, "Observable error message recorded on failure")
                } else {
                    assertCondition(false, "Transition state should be .failed")
                }
            }

            // Defect 3 Failure injection: Incoming snapshot corrupted JSON decode failure
            let corruptedData = "{corrupted json data".data(using: .utf8)!
            try navAdapter.saveBackendSessionSnapshot(backend: .otzaria, sessionData: corruptedData)
            do {
                _ = try navAdapter.prepareTransition(
                    outgoingBackend: .sefaria,
                    outgoingSession: { sefariaData },
                    incomingBackend: .otzaria,
                    incomingValidator: { data in
                        throw NSError(domain: "test.json.corrupt", code: -1)
                    }
                )
                assertCondition(false, "Should have thrown corruptedSnapshot error")
            } catch BackendNavigationAdapterError.corruptedSnapshot {
                assertCondition(true, "corruptedSnapshot error thrown when incoming snapshot is invalid")
                if case .failed(_, let rolledBack) = navAdapter.transitionState {
                    assertCondition(rolledBack, "Transition rolled back on corrupted incoming snapshot")
                } else {
                    assertCondition(false, "State should be failed rolledBack")
                }
            }

            // Defect 3: Restore from fresh adapter instance verifies durability across launches
            let freshAdapter = BackendNavigationAdapter(storageDirectory: tempDir)
            let persistedSefaria = freshAdapter.retrieveBackendSessionSnapshot(backend: .sefaria)
            assertCondition(persistedSefaria == sefariaData, "Fresh adapter instance reads persisted snapshot from disk")
        } catch {
            assertCondition(false, "BackendNavigationAdapter failed with: \(error)")
        }

        // 8. Defect 2 Typed Expression Regression Tests
        print("\n--- 8. Testing Defect 2 Typed Expression Regression ---")
        do {
            // Function mirroring createTabSessions selection logic:
            func resolveSessionContentId(
                vmCurrentID: Int?,
                tabInitialContentId: Int?,
                stateCurrentID: Int?,
                vmCurrentContentId: Int
            ) -> Int? {
                vmCurrentID ?? tabInitialContentId ?? stateCurrentID ?? (vmCurrentContentId > 0 ? vmCurrentContentId : nil)
            }

            // Case A: vmCurrentID present
            assertCondition(resolveSessionContentId(vmCurrentID: 10, tabInitialContentId: 20, stateCurrentID: 30, vmCurrentContentId: 40) == 10, "vmCurrentID takes precedence")

            // Case B: vmCurrentID nil, tabInitialContentId present
            assertCondition(resolveSessionContentId(vmCurrentID: nil, tabInitialContentId: 20, stateCurrentID: 30, vmCurrentContentId: 40) == 20, "tabInitialContentId selected when vmCurrentID nil")

            // Case C: stateCurrentID selected
            assertCondition(resolveSessionContentId(vmCurrentID: nil, tabInitialContentId: nil, stateCurrentID: 30, vmCurrentContentId: 40) == 30, "stateCurrentID selected when earlier are nil")

            // Case D: vmCurrentContentId > 0 fallback
            assertCondition(resolveSessionContentId(vmCurrentID: nil, tabInitialContentId: nil, stateCurrentID: nil, vmCurrentContentId: 40) == 40, "vmCurrentContentId fallback when > 0")

            // Case E: vmCurrentContentId == 0 (sentinel/unloaded) returns nil
            assertCondition(resolveSessionContentId(vmCurrentID: nil, tabInitialContentId: nil, stateCurrentID: nil, vmCurrentContentId: 0) == nil, "vmCurrentContentId == 0 cleanly produces nil")

            // Case F: vmCurrentContentId == -1 returns nil
            assertCondition(resolveSessionContentId(vmCurrentID: nil, tabInitialContentId: nil, stateCurrentID: nil, vmCurrentContentId: -1) == nil, "vmCurrentContentId < 0 cleanly produces nil")
        }

        // 9. BackendCoordinator & BackendSwitchParticipant Two-Phase Boundary Tests (BLOCKER A)
        // 9. BackendCoordinator Two-Phase Switch Orchestration & Catalog Resolution Tests
        print("\n--- 9. Testing BackendCoordinator Two-Phase Switch Orchestration ---")
        do {
            let suiteName = "test.coordinator.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName)!
            defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

            final class NotificationTracker: @unchecked Sendable {
                var count = 0
            }

            final class MockTargetCatalogResolver: @unchecked Sendable {
                var resolvableBooks: [BackendID: Set<Int>] = [
                    .otzaria: [101, 102],
                    .sefaria: [201, 202]
                ]
                var shouldFailCatalog = false

                func resolveBook(id: Int, backendLocator: String?, title: String?, in backend: BackendID) throws -> (id: Int, title: String) {
                    if shouldFailCatalog {
                        throw BackendTransitionError.missingTargetCatalog(backend)
                    }
                    if let locator = backendLocator {
                        if backend == .otzaria && locator.hasPrefix("sefaria:") {
                            throw BackendTransitionError.foreignBackendLocator(locator: locator, expectedBackend: .otzaria)
                        }
                        if backend == .sefaria && locator.hasPrefix("otzaria:") {
                            throw BackendTransitionError.foreignBackendLocator(locator: locator, expectedBackend: .sefaria)
                        }
                    }
                    guard let set = resolvableBooks[backend], set.contains(id) else {
                        throw BackendTransitionError.unresolvableBook(bookId: id, title: title ?? "Unknown", locator: backendLocator)
                    }
                    return (id, title ?? "Book \(id)")
                }
            }

            final class MockCoordinatorParticipant: BackendSwitchParticipant {
                var shouldFailPrepare = false
                var prepareCalledCount = 0
                var publishCalledCount = 0
                var completeCalledCount = 0
                var abortCalledCount = 0
                var lastAbortedError: Error?
                var openTabsSimulated: [String] = ["tab1", "tab2"]

                func prepareTransition(from currentBackend: BackendID, to targetBackend: BackendID, token: UInt64) throws -> PreparedBackendTransition? {
                    prepareCalledCount += 1
                    if shouldFailPrepare {
                        throw BackendNavigationAdapterError.writeFailed("Simulated prepare failure")
                    }
                    return PreparedBackendTransition(
                        transitionToken: token,
                        outgoingBackend: currentBackend,
                        incomingBackend: targetBackend,
                        outgoingSnapshotData: "{\"tabs\": [1, 2]}".data(using: .utf8),
                        incomingSnapshotData: "{\"tabs\": [3, 4]}".data(using: .utf8),
                        isCleanDestination: false,
                        stagedTabs: [
                            .init(id: UUID(), bookId: 201, bookTitle: "Sefaria Genesis", backendLocator: "sefaria:Genesis", scrollPosition: CGPoint(x: 0, y: 42.0)),
                            .init(id: UUID(), bookId: 202, bookTitle: "Sefaria Exodus", backendLocator: "sefaria:Exodus", scrollPosition: CGPoint(x: 0, y: 100.5))
                        ],
                        targetActiveTabId: nil
                    )
                }

                func publishTransition(to targetBackend: BackendID, transition: PreparedBackendTransition?) {
                    publishCalledCount += 1
                    if let transition = transition {
                        openTabsSimulated = transition.stagedTabs.map(\.bookTitle)
                    }
                }

                func completeTransition(to targetBackend: BackendID) {
                    completeCalledCount += 1
                }

                func abortTransition(from currentBackend: BackendID, to targetBackend: BackendID, error: Error) {
                    abortCalledCount += 1
                    lastAbortedError = error
                    // DO NOT TOUCH openTabsSimulated: preserved intact!
                }
            }

            let coordinator = BackendCoordinator(defaults: defaults)
            let participant = MockCoordinatorParticipant()
            coordinator.addSwitchParticipant(participant)

            let initialBackend = coordinator.activeBackendID
            let initialGen = coordinator.generation
            assertCondition(initialBackend == .otzaria, "Initial backend is .otzaria")

            // Test 9.1: Outgoing write failure injection in prepare
            participant.shouldFailPrepare = true
            let tracker = NotificationTracker()
            let observer = NotificationCenter.default.addObserver(forName: .activeLibraryBackendDidChange, object: nil, queue: nil) { _ in
                tracker.count += 1
            }
            defer { NotificationCenter.default.removeObserver(observer) }

            do {
                try coordinator.commitChecked(.sefaria)
                assertCondition(false, "Should have thrown prepare failure")
            } catch BackendNavigationAdapterError.writeFailed {
                assertCondition(true, "Prepare write failure properly propagated")
            } catch {
                assertCondition(false, "Unexpected error: \(error)")
            }

            assertCondition(participant.prepareCalledCount == 1, "Participant prepare called once")
            assertCondition(participant.publishCalledCount == 0, "Participant publish NOT called on prepare failure")
            assertCondition(participant.abortCalledCount == 1, "Participant abort called on prepare failure")
            assertCondition(coordinator.activeBackendID == initialBackend, "Coordinator remains on initial backend after prepare failure")
            assertCondition(coordinator.generation == initialGen, "Generation unchanged after prepare failure")
            assertCondition(tracker.count == 0, "Notification NOT posted on prepare failure")
            assertCondition(defaults.string(forKey: BackendCoordinator.selectionDefaultsKey) == nil, "Defaults unchanged on prepare failure")
            assertCondition(participant.openTabsSimulated == ["tab1", "tab2"], "User tabs completely preserved on prepare failure")

            // Test 9.2: Corrupt incoming snapshot during prepare preflight
            participant.shouldFailPrepare = false
            final class CorruptedIncomingParticipant: BackendSwitchParticipant {
                var tabs = ["user_tab"]
                var abortCalled = false
                func prepareTransition(from currentBackend: BackendID, to targetBackend: BackendID, token: UInt64) throws -> PreparedBackendTransition? {
                    throw BackendNavigationAdapterError.corruptedSnapshot("Corrupt target snapshot")
                }
                func publishTransition(to targetBackend: BackendID, transition: PreparedBackendTransition?) {
                    tabs = ["corrupted_installed"]
                }
                func completeTransition(to targetBackend: BackendID) {}
                func abortTransition(from currentBackend: BackendID, to targetBackend: BackendID, error: Error) {
                    abortCalled = true
                }
            }
            let corruptParticipant = CorruptedIncomingParticipant()
            coordinator.addSwitchParticipant(corruptParticipant)

            do {
                try coordinator.commitChecked(.sefaria)
                assertCondition(false, "Should have thrown corruptedSnapshot failure")
            } catch BackendNavigationAdapterError.corruptedSnapshot {
                assertCondition(true, "Corrupted snapshot in prepare rejected fail-closed")
            } catch {
                assertCondition(false, "Unexpected error: \(error)")
            }

            assertCondition(corruptParticipant.abortCalled, "Participant abort called on corrupt snapshot")
            assertCondition(corruptParticipant.tabs == ["user_tab"], "Existing tabs untouched after corrupt snapshot in prepare")
            assertCondition(coordinator.activeBackendID == initialBackend, "Coordinator remains on initial backend")
            coordinator.removeSwitchParticipant(corruptParticipant)

            // Test 9.3: Preflight capability unavailable failure
            final class UnregisteredCoordinatorParticipant: BackendSwitchParticipant {
                func prepareTransition(from currentBackend: BackendID, to targetBackend: BackendID, token: UInt64) throws -> PreparedBackendTransition? {
                    throw BackendTransitionError.capabilityUnavailable(targetBackend)
                }
                func publishTransition(to targetBackend: BackendID, transition: PreparedBackendTransition?) {}
                func completeTransition(to targetBackend: BackendID) {}
                func abortTransition(from currentBackend: BackendID, to targetBackend: BackendID, error: Error) {}
            }
            let failingParticipant = UnregisteredCoordinatorParticipant()
            coordinator.addSwitchParticipant(failingParticipant)

            do {
                try coordinator.commitChecked(.sefaria)
                assertCondition(false, "Should have thrown capabilityUnavailable")
            } catch BackendTransitionError.capabilityUnavailable {
                assertCondition(true, "Capability unavailable failure cleanly rejected")
            } catch {
                assertCondition(false, "Unexpected error: \(error)")
            }
            assertCondition(coordinator.activeBackendID == initialBackend, "Coordinator remains on initial backend after capabilityUnavailable")
            coordinator.removeSwitchParticipant(failingParticipant)

            // Test 9.4: Injected Unresolved Book in target catalog -> FAIL PREPARE
            final class CatalogValidatingParticipant: BackendSwitchParticipant {
                let resolver: MockTargetCatalogResolver
                var tabs = ["initial_book_101"]
                var abortCalled = false
                init(resolver: MockTargetCatalogResolver) { self.resolver = resolver }

                func prepareTransition(from currentBackend: BackendID, to targetBackend: BackendID, token: UInt64) throws -> PreparedBackendTransition? {
                    // Inject book 999 which does NOT exist in target catalog
                    _ = try resolver.resolveBook(id: 999, backendLocator: "sefaria:Nonexistent", title: "Missing Book", in: targetBackend)
                    return nil
                }
                func publishTransition(to targetBackend: BackendID, transition: PreparedBackendTransition?) {
                    tabs = ["should_not_be_called"]
                }
                func abortTransition(from currentBackend: BackendID, to targetBackend: BackendID, error: Error) {
                    abortCalled = true
                }
            }
            let resolver = MockTargetCatalogResolver()
            let catalogValidator = CatalogValidatingParticipant(resolver: resolver)
            coordinator.addSwitchParticipant(catalogValidator)

            do {
                try coordinator.commitChecked(.sefaria)
                assertCondition(false, "Should have thrown unresolvableBook")
            } catch BackendTransitionError.unresolvableBook(let id, _, _) {
                assertCondition(id == 999, "Unresolved book correctly rejected during preflight")
            } catch {
                assertCondition(false, "Unexpected error: \(error)")
            }
            assertCondition(catalogValidator.abortCalled, "Participant aborted on unresolvable book")
            assertCondition(catalogValidator.tabs == ["initial_book_101"], "Tabs preserved on unresolvable book")
            coordinator.removeSwitchParticipant(catalogValidator)

            // Test 9.5: Injected Foreign Backend Locator -> FAIL PREPARE
            final class ForeignLocatorParticipant: BackendSwitchParticipant {
                let resolver: MockTargetCatalogResolver
                var abortCalled = false
                init(resolver: MockTargetCatalogResolver) { self.resolver = resolver }

                func prepareTransition(from currentBackend: BackendID, to targetBackend: BackendID, token: UInt64) throws -> PreparedBackendTransition? {
                    // Inject Otzaria locator into Sefaria target
                    _ = try resolver.resolveBook(id: 201, backendLocator: "otzaria:SomePath", title: "Mismatched", in: targetBackend)
                    return nil
                }
                func publishTransition(to targetBackend: BackendID, transition: PreparedBackendTransition?) {}
                func abortTransition(from currentBackend: BackendID, to targetBackend: BackendID, error: Error) {
                    abortCalled = true
                }
            }
            let foreignParticipant = ForeignLocatorParticipant(resolver: resolver)
            coordinator.addSwitchParticipant(foreignParticipant)

            do {
                try coordinator.commitChecked(.sefaria)
                assertCondition(false, "Should have thrown foreignBackendLocator")
            } catch BackendTransitionError.foreignBackendLocator {
                assertCondition(true, "Foreign backend locator cleanly rejected fail-closed")
            } catch {
                assertCondition(false, "Unexpected error: \(error)")
            }
            assertCondition(foreignParticipant.abortCalled, "Foreign locator participant aborted")
            coordinator.removeSwitchParticipant(foreignParticipant)

            // Test 9.6: Injected Target Catalog Failure -> FAIL PREPARE
            final class CatalogFailureParticipant: BackendSwitchParticipant {
                let resolver: MockTargetCatalogResolver
                var abortCalled = false
                init(resolver: MockTargetCatalogResolver) { self.resolver = resolver }

                func prepareTransition(from currentBackend: BackendID, to targetBackend: BackendID, token: UInt64) throws -> PreparedBackendTransition? {
                    resolver.shouldFailCatalog = true
                    _ = try resolver.resolveBook(id: 201, backendLocator: "sefaria:Genesis", title: "Genesis", in: targetBackend)
                    return nil
                }
                func publishTransition(to targetBackend: BackendID, transition: PreparedBackendTransition?) {}
                func abortTransition(from currentBackend: BackendID, to targetBackend: BackendID, error: Error) {
                    abortCalled = true
                }
            }
            let catalogFailParticipant = CatalogFailureParticipant(resolver: resolver)
            coordinator.addSwitchParticipant(catalogFailParticipant)

            do {
                try coordinator.commitChecked(.sefaria)
                assertCondition(false, "Should have thrown missingTargetCatalog")
            } catch BackendTransitionError.missingTargetCatalog {
                assertCondition(true, "Missing target catalog failure cleanly rejected")
            } catch {
                assertCondition(false, "Unexpected error: \(error)")
            }
            assertCondition(catalogFailParticipant.abortCalled, "Catalog failure participant aborted")
            coordinator.removeSwitchParticipant(catalogFailParticipant)
            resolver.shouldFailCatalog = false

            // Test 9.7: Successful two-phase switch with pre-staged tabs & single notification
            participant.shouldFailPrepare = false
            participant.prepareCalledCount = 0
            participant.publishCalledCount = 0
            participant.completeCalledCount = 0
            participant.abortCalledCount = 0
            tracker.count = 0

            let switchSuccess = coordinator.commit(.sefaria)
            assertCondition(switchSuccess, "Coordinator commit returns true on successful switch")
            assertCondition(coordinator.activeBackendID == .sefaria, "Coordinator transitioned to .sefaria")
            assertCondition(coordinator.generation == initialGen + 1, "Generation incremented by 1")
            assertCondition(participant.prepareCalledCount == 1, "Participant prepare called on success")
            assertCondition(participant.publishCalledCount == 1, "Participant publish called on success")
            assertCondition(participant.completeCalledCount == 1, "Participant complete called on success")
            assertCondition(participant.abortCalledCount == 0, "Participant abort NOT called on success")
            assertCondition(participant.openTabsSimulated == ["Sefaria Genesis", "Sefaria Exodus"], "Pre-staged tabs installed during non-throwing publish")
            assertCondition(tracker.count == 1, "Notification posted EXACTLY ONCE on successful switch")
            assertCondition(defaults.string(forKey: BackendCoordinator.selectionDefaultsKey) == "sefaria", "Defaults persisted on successful switch")

            // Test 9.8: Rapid A -> B -> A switching
            let rapid1 = coordinator.commit(.otzaria)
            let rapid2 = coordinator.commit(.sefaria)
            assertCondition(rapid1, "Switch back to .otzaria succeeded")
            assertCondition(rapid2, "Switch back to .sefaria succeeded")
            assertCondition(coordinator.activeBackendID == .sefaria, "Final backend after rapid switch is .sefaria")
            assertCondition(coordinator.generation == initialGen + 3, "Generation incremented for each successful switch")

            // Test 9.9: End-to-end integration with real BackendNavigationAdapter
            let navTempDir = FileManager.default.temporaryDirectory.appendingPathComponent("nav_coord_\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: navTempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: navTempDir) }

            let realNavAdapter = BackendNavigationAdapter(storageDirectory: navTempDir)
            try realNavAdapter.saveBackendSessionSnapshot(backend: .otzaria, sessionData: "{\"tab\": 1}".data(using: .utf8)!)
            try realNavAdapter.saveBackendSessionSnapshot(backend: .sefaria, sessionData: "{\"tab\": 2}".data(using: .utf8)!)

            final class RealNavAdapterParticipant: BackendSwitchParticipant {
                let adapter: BackendNavigationAdapter
                init(adapter: BackendNavigationAdapter) {
                    self.adapter = adapter
                }
                func prepareTransition(from currentBackend: BackendID, to targetBackend: BackendID, token: UInt64) throws -> PreparedBackendTransition? {
                    return try adapter.prepareTransition(
                        outgoingBackend: currentBackend,
                        outgoingSession: { "{\"tabs\": []}".data(using: .utf8) },
                        incomingBackend: targetBackend,
                        token: token
                    )
                }
                func publishTransition(to targetBackend: BackendID, transition: PreparedBackendTransition?) {
                    adapter.commitTransition(incomingBackend: targetBackend)
                }
                func completeTransition(to targetBackend: BackendID) {
                    adapter.completeTransition(incomingBackend: targetBackend)
                }
                func abortTransition(from currentBackend: BackendID, to targetBackend: BackendID, error: Error) {
                    adapter.resetTransition()
                }
            }

            let realNavParticipant = RealNavAdapterParticipant(adapter: realNavAdapter)
            coordinator.addSwitchParticipant(realNavParticipant)

            let realSwitchSuccess = coordinator.commit(.otzaria)
            assertCondition(realSwitchSuccess, "End-to-end switch using real BackendNavigationAdapter participant succeeded")
            assertCondition(coordinator.activeBackendID == .otzaria, "Backend coordinator active backend updated to .otzaria")
            assertCondition(realNavAdapter.transitionState == .uiTransitionCommitted(incoming: .otzaria) || realNavAdapter.transitionState == .incomingSnapshotRestored(incoming: .otzaria), "BackendNavigationAdapter state restored for otzaria")

            // Test 9.10: Atomic Tab Restoration with pre-resolved retained books (Priority B1/B2)
            final class AtomicRestorationParticipant: BackendSwitchParticipant {
                final class MockBook: @unchecked Sendable {
                    let id: Int
                    let title: String
                    init(id: Int, title: String) { self.id = id; self.title = title }
                }

                var openTabs: [String] = ["outgoing_tab_1", "outgoing_tab_2"]
                var simulatedResolverChanged = false
                var abortCalled = false

                func prepareTransition(from currentBackend: BackendID, to targetBackend: BackendID, token: UInt64) throws -> PreparedBackendTransition? {
                    let book1 = MockBook(id: 301, title: "Retained Book 1")
                    let book2 = MockBook(id: 302, title: "Retained Book 2")
                    return PreparedBackendTransition(
                        transitionToken: token,
                        outgoingBackend: currentBackend,
                        incomingBackend: targetBackend,
                        outgoingSnapshotData: nil,
                        incomingSnapshotData: nil,
                        isCleanDestination: false,
                        stagedTabs: [
                            .init(id: UUID(), bookId: 301, bookTitle: "Title 1", backendLocator: nil, retainedBook: book1),
                            .init(id: UUID(), bookId: 302, bookTitle: "Title 2", backendLocator: nil, retainedBook: book2)
                        ],
                        targetActiveTabId: nil
                    )
                }

                func publishTransition(to targetBackend: BackendID, transition: PreparedBackendTransition?) {
                    guard let transition, !transition.stagedTabs.isEmpty else { return }
                    var restored: [String] = []
                    for tab in transition.stagedTabs {
                        if let book = tab.retainedBook as? MockBook {
                            restored.append(book.title)
                        } else if !simulatedResolverChanged {
                            restored.append(tab.bookTitle)
                        }
                    }
                    guard restored.count == transition.stagedTabs.count else { return }
                    openTabs = restored
                }

                func completeTransition(to targetBackend: BackendID) {}
                func abortTransition(from currentBackend: BackendID, to targetBackend: BackendID, error: Error) {
                    abortCalled = true
                }
            }

            let atomicParticipant = AtomicRestorationParticipant()
            atomicParticipant.simulatedResolverChanged = true
            coordinator.addSwitchParticipant(atomicParticipant)
            let atomicSwitchSuccess = coordinator.commit(.sefaria)
            assertCondition(atomicSwitchSuccess, "Atomic switch with pre-resolved retained books succeeded")
            assertCondition(atomicParticipant.openTabs == ["Retained Book 1", "Retained Book 2"], "Pre-resolved books installed without re-resolution")
            coordinator.removeSwitchParticipant(atomicParticipant)

            // Test 9.11: Partial restoration count mismatch fails-closed (Priority B2)
            final class PartialMismatchParticipant: BackendSwitchParticipant {
                var openTabs: [String] = ["saved_tab_1", "saved_tab_2"]
                var abortCalled = false

                func prepareTransition(from currentBackend: BackendID, to targetBackend: BackendID, token: UInt64) throws -> PreparedBackendTransition? {
                    return PreparedBackendTransition(
                        transitionToken: token,
                        outgoingBackend: currentBackend,
                        incomingBackend: targetBackend,
                        outgoingSnapshotData: nil,
                        incomingSnapshotData: nil,
                        isCleanDestination: false,
                        stagedTabs: [
                            .init(id: UUID(), bookId: 401, bookTitle: "Valid 1", backendLocator: nil, retainedBook: "Book1" as (any AnyObject & Sendable)),
                            .init(id: UUID(), bookId: 402, bookTitle: "Corrupt 2", backendLocator: nil, retainedBook: nil)
                        ],
                        targetActiveTabId: nil
                    )
                }

                func publishTransition(to targetBackend: BackendID, transition: PreparedBackendTransition?) {
                    guard let transition else { return }
                    var restored: [String] = []
                    for tab in transition.stagedTabs {
                        if let book = tab.retainedBook as? String {
                            restored.append(book)
                        }
                    }
                    guard restored.count == transition.stagedTabs.count else { return }
                    openTabs = restored
                }

                func completeTransition(to targetBackend: BackendID) {}
                func abortTransition(from currentBackend: BackendID, to targetBackend: BackendID, error: Error) {
                    abortCalled = true
                }
            }

            let mismatchParticipant = PartialMismatchParticipant()
            coordinator.addSwitchParticipant(mismatchParticipant)
            _ = coordinator.commit(.otzaria)
            assertCondition(mismatchParticipant.openTabs == ["saved_tab_1", "saved_tab_2"], "Tabs preserved after partial restoration mismatch")
            coordinator.removeSwitchParticipant(mismatchParticipant)
        } catch {
            assertCondition(false, "Suite 9 failed with error: \(error)")
        }

        // 10. TalmudHebrewAddressFormatter & Expanded Localization (Defect #7, L1/L2)
        print("\n--- 10. Testing TalmudHebrewAddressFormatter & Localization ---")
        assertCondition(TalmudHebrewAddressFormatter.format(offset: 20) == "י״ב ע״א", "12a offset 20 -> י״ב ע״א")
        assertCondition(TalmudHebrewAddressFormatter.format(offset: 21) == "י״ב ע״ב", "12b offset 21 -> י״ב ע״ב")
        assertCondition(TalmudHebrewAddressFormatter.format(offset: 27) == "ט״ו ע״ב", "15b offset 27 -> ט״ו ע״ב (special 15 handling)")
        assertCondition(TalmudHebrewAddressFormatter.format(offset: 28) == "ט״ז ע״א", "16a offset 28 -> ט״ז ע״א (special 16 handling)")
        assertCondition(TalmudHebrewAddressFormatter.format(address: "12a") == "י״ב ע״א", "address '12a' -> י״ב ע״א")
        assertCondition(TalmudHebrewAddressFormatter.format(address: "15b") == "ט״ו ע״ב", "address '15b' -> ט״ו ע״ב")
        assertCondition(TalmudHebrewAddressFormatter.format(address: "2a") == "ב׳ ע״א", "address '2a' -> ב׳ ע״א with gersh")
        assertCondition(ChavrusaTextLocalizationResolver.resolveNavigationStructureTitle(for: "Chapters", prefersHebrew: true) == "פרקים", "Chapters in Hebrew is פרקים")
        assertCondition(ChavrusaTextLocalizationResolver.resolveNavigationStructureTitle(for: "Chapters", prefersHebrew: false) == "Chapters", "Chapters in English is Chapters")
        assertCondition(ChavrusaTextLocalizationResolver.resolveNavigationStructureTitle(for: "Folios", prefersHebrew: true) == "דפים", "Folios in Hebrew is דפים")
        assertCondition(ChavrusaTextLocalizationResolver.resolveNavigationStructureTitle(for: "Parashot", prefersHebrew: true) == "פרשות", "Parashot in Hebrew is פרשות")
        assertCondition(ChavrusaTextLocalizationResolver.resolveNavigationStructureTitle(for: "Halakhot", prefersHebrew: true) == "הלכות", "Halakhot in Hebrew is הלכות")

        // 11. ReaderDestinationResolver (Defect #6 & #1, S1/S2/H1)
        print("\n--- 11. Testing ReaderDestinationResolver ---")
        let rashiHit = TextLocator(backend: .sefaria, workKey: "Rashi on Berakhot", position: .canonicalRef("Rashi on Berakhot 15b:3:1"))
        let resolvedRashi = ReaderDestinationResolver.resolve(locator: rashiHit)
        assertCondition(resolvedRashi.isSegmentLevelFocus, "Rashi 15b:3:1 is detected as segment-level focus")
        assertCondition(resolvedRashi.sectionLocator.position == .canonicalRef("Rashi on Berakhot 15b"), "Rashi sectionLocator bounded to containing daf 15b")
        assertCondition(resolvedRashi.focusLocator?.position == .canonicalRef("Rashi on Berakhot 15b:3:1"), "Rashi focusLocator preserves exact segment hit")

        let genesisHit = TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 1:3"))
        let resolvedGenesis = ReaderDestinationResolver.resolve(locator: genesisHit)
        assertCondition(resolvedGenesis.isSegmentLevelFocus, "Genesis 1:3 is detected as segment-level focus")
        assertCondition(resolvedGenesis.sectionLocator.position == .canonicalRef("Genesis 1"), "Genesis sectionLocator bounded to chapter 1")
        assertCondition(resolvedGenesis.focusLocator?.position == .canonicalRef("Genesis 1:3"), "Genesis focusLocator preserves verse 3")

        let dafSection = TextLocator(backend: .sefaria, workKey: "Berakhot", position: .canonicalRef("Berakhot 15b"))
        let resolvedDaf = ReaderDestinationResolver.resolve(locator: dafSection)
        assertCondition(!resolvedDaf.isSegmentLevelFocus, "Berakhot 15b is already a section, not a segment")
        assertCondition(resolvedDaf.sectionLocator.position == .canonicalRef("Berakhot 15b"), "Section locator is Berakhot 15b")
        assertCondition(resolvedDaf.focusLocator == nil, "Focus locator is nil for section-level locator")

        // 12. ReaderBackendPagingCoordinator (Defect #3, P1/P2/P3/P4)
        print("\n--- 12. Testing ReaderBackendPagingCoordinator ---")
        let nextLoc = TextLocator(backend: .sefaria, workKey: "Berakhot", position: .canonicalRef("Berakhot 16a"))
        let prevLoc = TextLocator(backend: .sefaria, workKey: "Berakhot", position: .canonicalRef("Berakhot 15a"))
        let actionNext = ReaderBackendPagingCoordinator.resolvePagingAction(
            direction: .next,
            isBackendBook: true,
            currentLocator: dafSection,
            backendSectionNext: nextLoc,
            backendSectionPrevious: prevLoc,
            navigationItems: []
        )
        assertCondition(actionNext == .loadBackendLocator(nextLoc, scrollTarget: .top), "Next action loads next section with .top scroll target")

        let actionPrev = ReaderBackendPagingCoordinator.resolvePagingAction(
            direction: .previous,
            isBackendBook: true,
            currentLocator: dafSection,
            backendSectionNext: nextLoc,
            backendSectionPrevious: prevLoc,
            navigationItems: []
        )
        assertCondition(actionPrev == .loadBackendLocator(prevLoc, scrollTarget: .bottom), "Prev action loads prev section with .bottom scroll target")

        let actionBoundary = ReaderBackendPagingCoordinator.resolvePagingAction(
            direction: .next,
            isBackendBook: true,
            currentLocator: dafSection,
            backendSectionNext: nil,
            backendSectionPrevious: prevLoc,
            navigationItems: []
        )
        assertCondition(actionBoundary == .noOpBoundaryReached, "Boundary reached is safe no-op (no jump to first page)")

        let actionLegacy = ReaderBackendPagingCoordinator.resolvePagingAction(
            direction: .next,
            isBackendBook: false,
            currentLocator: nil,
            backendSectionNext: nil,
            backendSectionPrevious: nil,
            navigationItems: []
        )
        assertCondition(actionLegacy == .performLegacyFallback, "Non-backend book performs legacy fallback")

        // 13. ReaderSearchContextCoordinator (Defect #2 & #1, H3/H4)
        print("\n--- 13. Testing ReaderSearchContextCoordinator ---")
        assertCondition(
            ReaderSearchContextCoordinator.hasActiveSearchHighlight(searchText: "shalom", highlightTerms: nil, focusLocator: nil, selectedSegmentLocator: nil),
            "Active search highlight detected with search text"
        )
        assertCondition(
            ReaderSearchContextCoordinator.hasActiveSearchHighlight(searchText: "", highlightTerms: ["term"], focusLocator: nil, selectedSegmentLocator: nil),
            "Active search highlight detected with highlight terms"
        )
        assertCondition(
            ReaderSearchContextCoordinator.hasActiveSearchHighlight(searchText: "shalom", highlightTerms: ["term"], focusLocator: rashiHit, selectedSegmentLocator: nil),
            "Active search highlight detected with search text, terms, and focus locator"
        )
        assertCondition(
            !ReaderSearchContextCoordinator.hasActiveSearchHighlight(searchText: "", highlightTerms: nil, focusLocator: rashiHit, selectedSegmentLocator: nil, isSearchOrigin: false),
            "Ordinary linked commentary focus without search origin does NOT trigger search highlight"
        )
        assertCondition(
            !ReaderSearchContextCoordinator.hasActiveSearchHighlight(searchText: "", highlightTerms: nil, focusLocator: nil, selectedSegmentLocator: rashiHit),
            "Ordinary reader segment selection does NOT trigger search highlight"
        )
        assertCondition(
            !ReaderSearchContextCoordinator.hasActiveSearchHighlight(searchText: "", highlightTerms: nil, focusLocator: nil, selectedSegmentLocator: nil),
            "No active search highlight when all fields are empty"
        )

        // Programmatic scroll never clears
        let progClear = ReaderSearchContextCoordinator.shouldClearAfterScroll(
            startOffsetY: 0,
            currentOffsetY: 500,
            viewportHeight: 600,
            isManualUserDrag: false,
            hasActiveHighlight: true
        )
        assertCondition(!progClear, "Programmatic scroll NEVER clears search highlight")

        // Manual drag below threshold does not clear
        let subThresholdClear = ReaderSearchContextCoordinator.shouldClearAfterScroll(
            startOffsetY: 100,
            currentOffsetY: 120,
            viewportHeight: 600,
            isManualUserDrag: true,
            hasActiveHighlight: true
        )
        assertCondition(!subThresholdClear, "Manual scroll below threshold does not clear search highlight")

        // Manual drag above threshold clears
        let supraThresholdClear = ReaderSearchContextCoordinator.shouldClearAfterScroll(
            startOffsetY: 100,
            currentOffsetY: 250,
            viewportHeight: 600,
            isManualUserDrag: true,
            hasActiveHighlight: true
        )
        assertCondition(supraThresholdClear, "Manual scroll above threshold clears search highlight")

        // Clearing transient search state
        var sText = "hello"
        var hTerms: [String]? = ["a", "b"]
        var fLoc: TextLocator? = rashiHit
        var sLoc: TextLocator? = rashiHit
        var sMode: LibrarySearchMode? = .phrase
        ReaderSearchContextCoordinator.clearTransientSearchState(
            searchText: &sText,
            highlightTerms: &hTerms,
            focusLocator: &fLoc,
            selectedSegmentLocator: &sLoc,
            searchMode: &sMode
        )
        assertCondition(sText.isEmpty && hTerms == nil && fLoc == nil && sLoc == nil && sMode == nil, "Clear transient search state cleanly clears all search context")

        // 14. TOCReadingLocationTracker (Defect #5, T1/T2)
        print("\n--- 14. Testing TOCReadingLocationTracker ---")
        let otzariaNodes: [FlattenedTOCItem] = [
            FlattenedTOCItem(id: 1, title: "Chapter 1", level: 1, locator: TextLocator(backend: .otzaria, workKey: "book:100", position: .legacyLine(0))),
            FlattenedTOCItem(id: 2, title: "Section A", level: 2, locator: TextLocator(backend: .otzaria, workKey: "book:100", position: .legacyLine(50))),
            FlattenedTOCItem(id: 3, title: "Section B", level: 2, locator: TextLocator(backend: .otzaria, workKey: "book:100", position: .legacyLine(100))),
            FlattenedTOCItem(id: 4, title: "Chapter 2", level: 1, locator: TextLocator(backend: .otzaria, workKey: "book:100", position: .legacyLine(200)))
        ]
        let currentReadingAtLine125 = TextLocator(backend: .otzaria, workKey: "book:100", position: .legacyLine(125))
        let matchedNodeId = TOCReadingLocationTracker.findMatchingNodeID(for: currentReadingAtLine125, in: otzariaNodes)
        assertCondition(matchedNodeId == 3, "Line 125 matches Section B at line 100 (closest heading at or before 125)")

        let sefariaTOCNodes: [FlattenedTOCItem] = [
            FlattenedTOCItem(id: 10, title: "15a", level: 1, locator: TextLocator(backend: .sefaria, workKey: "Rashi on Berakhot", position: .canonicalRef("Rashi on Berakhot 15a"))),
            FlattenedTOCItem(id: 11, title: "15b", level: 1, locator: TextLocator(backend: .sefaria, workKey: "Rashi on Berakhot", position: .canonicalRef("Rashi on Berakhot 15b"))),
            FlattenedTOCItem(id: 12, title: "16a", level: 1, locator: TextLocator(backend: .sefaria, workKey: "Rashi on Berakhot", position: .canonicalRef("Rashi on Berakhot 16a")))
        ]
        let matchedSefariaTOC = TOCReadingLocationTracker.findMatchingNodeID(for: rashiHit, in: sefariaTOCNodes)
        assertCondition(matchedSefariaTOC == 11, "Rashi on Berakhot 15b:3:1 matches TOC node 15b (ancestor)")

        // 15. SefariaBookIdentityValidator (Defect #4, B2)
        print("\n--- 15. Testing SefariaBookIdentityValidator ---")
        let nonExistentWorkKey = "DefinitelyNotARealSefariaWorkXYZ"
        let nonExistentLocator = TextLocator(backend: .sefaria, workKey: nonExistentWorkKey, position: .canonicalRef(nonExistentWorkKey))

        // Negative test 1: Nonexistent archive URL (.isFileURL is true for file scheme, but file does NOT exist)
        let nonExistentArchiveURL = SefariaOfflinePaths().standaloneArchive(for: nonExistentWorkKey)
        assertCondition(nonExistentArchiveURL.isFileURL, "standaloneArchive URL has isFileURL true by scheme")
        assertCondition(!FileManager.default.fileExists(atPath: nonExistentArchiveURL.path), "Actual file does NOT exist on disk")
        assertCondition(!SefariaBookIdentityValidator.isAuthoritative(workKey: nonExistentWorkKey, id: 9999, textLocator: nonExistentLocator), "Nonexistent archive URL rejected fail-closed")

        // Negative test 2: Placeholder strings rejected
        let placeholderWorkKey = "Book 9999"
        let placeholderLocator = TextLocator(backend: .sefaria, workKey: placeholderWorkKey, position: .canonicalRef(placeholderWorkKey))
        assertCondition(!SefariaBookIdentityValidator.isAuthoritative(workKey: placeholderWorkKey, id: 9999, textLocator: placeholderLocator), "Placeholder 'Book 9999' rejected fail-closed")

        // Negative test 3: Foreign Otzaria legacy ID does not validate Sefaria work
        let otzariaOnlyId = -777
        _ = LegacyIdentityRegistry.shared.id(for: TextLocator(backend: .otzaria, workKey: "book:777", position: .legacyLine(0)), title: "Otzaria Book 777")
        assertCondition(!SefariaBookIdentityValidator.isAuthoritative(workKey: "SomeRandomWork", id: otzariaOnlyId, textLocator: TextLocator(backend: .sefaria, workKey: "SomeRandomWork", position: .canonicalRef("SomeRandomWork"))), "Foreign Otzaria ID rejected fail-closed for Sefaria work")

        // Positive test 4: Legitimate registered Sefaria work in LegacyIdentityRegistry
        let sefariaWorkKey = "Genesis"
        let sefariaGenesisLocator = TextLocator(backend: .sefaria, workKey: sefariaWorkKey, position: .canonicalRef(sefariaWorkKey))
        let registeredSefariaId = LegacyIdentityRegistry.shared.id(for: sefariaGenesisLocator, title: "Genesis")
        assertCondition(SefariaBookIdentityValidator.isAuthoritative(workKey: sefariaWorkKey, id: registeredSefariaId, textLocator: sefariaGenesisLocator), "Authoritative registered Sefaria work in LegacyIdentityRegistry validated successfully")

        // Positive test 5: Cross-backend canonical ID match
        let crossBackendWorkKey = "Berakhot"
        let crossBackendLocator = TextLocator(backend: .sefaria, workKey: crossBackendWorkKey, position: .canonicalRef(crossBackendWorkKey))
        CrossBackendBookIdentityIndex.shared.register(
            LibraryWork(locator: crossBackendLocator, title: "Berakhot", heTitle: "ברכות", categories: ["Talmud"], description: nil),
            canonicalID: 200
        )
        assertCondition(SefariaBookIdentityValidator.isAuthoritative(workKey: crossBackendWorkKey, id: 200, textLocator: crossBackendLocator), "Cross-backend registered Sefaria work validated successfully")

        // Positive test 6: Real file on disk validation
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("SefariaTest_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let mockOfflinePaths = SefariaOfflinePaths(root: tempDir)
        let testWork = "TestOfflineWork"
        let testArchiveURL = mockOfflinePaths.standaloneArchive(for: testWork)
        try? FileManager.default.createDirectory(at: testArchiveURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? "mock zip content".data(using: .utf8)?.write(to: testArchiveURL)
        let testWorkLocator = TextLocator(backend: .sefaria, workKey: testWork, position: .canonicalRef(testWork))
        assertCondition(SefariaBookIdentityValidator.isAuthoritative(workKey: testWork, id: 300, textLocator: testWorkLocator, offlinePaths: mockOfflinePaths), "Real file present on disk validated successfully")
        try? FileManager.default.removeItem(at: tempDir)

        // 16. ReaderContentLoadCoordinator & Out-of-Order Async Protection (Section 2)
        print("\n--- 16. Testing ReaderContentLoadCoordinator ---")
        let loadCoordinator = ReaderContentLoadCoordinator()
        let tokenA = loadCoordinator.beginRequest(
            backend: .sefaria,
            workKey: "Berakhot",
            sectionLocator: TextLocator(backend: .sefaria, workKey: "Berakhot", position: .canonicalRef("Berakhot 2a"))
        )
        assertCondition(tokenA.generation == 1, "Token A has generation 1")
        assertCondition(loadCoordinator.isTokenActive(tokenA), "Token A is initially active")

        let tokenB = loadCoordinator.beginRequest(
            backend: .sefaria,
            workKey: "Berakhot",
            sectionLocator: TextLocator(backend: .sefaria, workKey: "Berakhot", position: .canonicalRef("Berakhot 2b"))
        )
        assertCondition(tokenB.generation == 2, "Token B has generation 2")
        assertCondition(!loadCoordinator.isTokenActive(tokenA), "Token A is superseded when B begins")
        assertCondition(loadCoordinator.isTokenActive(tokenB), "Token B is active")

        let tokenC = loadCoordinator.beginRequest(
            backend: .sefaria,
            workKey: "Berakhot",
            sectionLocator: TextLocator(backend: .sefaria, workKey: "Berakhot", position: .canonicalRef("Berakhot 3a"))
        )
        assertCondition(tokenC.generation == 3, "Token C has generation 3")
        assertCondition(!loadCoordinator.isTokenActive(tokenB), "Token B is superseded when C begins")
        assertCondition(loadCoordinator.isTokenActive(tokenC), "Token C is active")

        // Out-of-order delivery simulation: Token A finishes NOW (after C)
        let currentBerakhotLocator = TextLocator(backend: .sefaria, workKey: "Berakhot", position: .canonicalRef("Berakhot 3a"))
        assertCondition(!loadCoordinator.canApplyContent(token: tokenA, currentBookLocator: currentBerakhotLocator), "Stale response A cannot apply content to current book")
        assertCondition(!loadCoordinator.canApplyContent(token: tokenB, currentBookLocator: currentBerakhotLocator), "Stale response B cannot apply content to current book")
        assertCondition(loadCoordinator.canApplyContent(token: tokenC, currentBookLocator: currentBerakhotLocator), "Fresh response C successfully applies content")

        // Secondary navigation items request isolation
        let navGen1 = loadCoordinator.beginNavigationItemsRequest(for: "Berakhot")
        assertCondition(loadCoordinator.isNavigationItemsRequestActive(generation: navGen1, workKey: "Berakhot"), "Navigation items request 1 is active")
        let navGen2 = loadCoordinator.beginNavigationItemsRequest(for: "Shabbat")
        assertCondition(!loadCoordinator.isNavigationItemsRequestActive(generation: navGen1, workKey: "Berakhot"), "Navigation items request 1 invalidated by request 2")
        assertCondition(loadCoordinator.isNavigationItemsRequestActive(generation: navGen2, workKey: "Shabbat"), "Navigation items request 2 is active")

        // Invalidation on book switch
        loadCoordinator.invalidate()
        assertCondition(!loadCoordinator.isTokenActive(tokenC), "Token C invalidated on coordinator reset")
        assertCondition(!loadCoordinator.isNavigationItemsRequestActive(generation: navGen2, workKey: "Shabbat"), "Nav request invalidated on coordinator reset")

        // 17. TOC Structural Matching & Negative False-Positive Elimination (Section 8)
        print("\n--- 17. Testing Structural TOC Matching & False-Positive Elimination ---")
        let testTOCNodes = [
            FlattenedTOCItem(id: 1, title: "Genesis 1", level: 1, locator: TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 1"))),
            FlattenedTOCItem(id: 2, title: "Genesis 10", level: 1, locator: TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 10"))),
            FlattenedTOCItem(id: 3, title: "Genesis 11", level: 1, locator: TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 11"))),
            FlattenedTOCItem(id: 20, title: "Berakhot 2a", level: 1, locator: TextLocator(backend: .sefaria, workKey: "Berakhot", position: .canonicalRef("Berakhot 2a"))),
            FlattenedTOCItem(id: 21, title: "Berakhot 20a", level: 1, locator: TextLocator(backend: .sefaria, workKey: "Berakhot", position: .canonicalRef("Berakhot 20a")))
        ]

        // CRITICAL CHECK: "Genesis 10:1" must NOT match "Genesis 1"
        let gen10Locator = TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 10:1"))
        let matchedGen10 = TOCReadingLocationTracker.findMatchingNodeID(for: gen10Locator, in: testTOCNodes)
        assertCondition(matchedGen10 == 2, "Genesis 10:1 matches node 2 (Genesis 10), NEVER node 1 (Genesis 1)")
        assertCondition(matchedGen10 != 1, "Genesis 10:1 strictly eliminated from false-positive prefix match on Genesis 1")

        // "Berakhot 20a" must NOT match "Berakhot 2a"
        let berakhot20Locator = TextLocator(backend: .sefaria, workKey: "Berakhot", position: .canonicalRef("Berakhot 20a:5"))
        let matchedBerakhot20 = TOCReadingLocationTracker.findMatchingNodeID(for: berakhot20Locator, in: testTOCNodes)
        assertCondition(matchedBerakhot20 == 21, "Berakhot 20a:5 matches node 21 (Berakhot 20a)")
        assertCondition(matchedBerakhot20 != 20, "Berakhot 20a:5 strictly eliminated from false-positive match on Berakhot 2a")

        // Cross-work rejection
        let foreignWorkLocator = TextLocator(backend: .sefaria, workKey: "Exodus", position: .canonicalRef("Exodus 1:1"))
        let matchedForeign = TOCReadingLocationTracker.findMatchingNodeID(for: foreignWorkLocator, in: testTOCNodes)
        assertCondition(matchedForeign == nil, "Exodus locator rejected with nil against Genesis/Berakhot TOC nodes")

        // 18. ReaderBackendPagingCoordinator Structural Paging & Boundary Safety (Section 3)
        print("\n--- 18. Testing ReaderBackendPagingCoordinator Structural Paging ---")
        let otzariaNavItems = [
            LibraryNavigationItem(locator: TextLocator(backend: .otzaria, workKey: "book:100", position: .legacyLine(0)), title: "Chapter 1", index: 0),
            LibraryNavigationItem(locator: TextLocator(backend: .otzaria, workKey: "book:100", position: .legacyLine(100)), title: "Chapter 2", index: 1),
            LibraryNavigationItem(locator: TextLocator(backend: .otzaria, workKey: "book:100", position: .legacyLine(200)), title: "Chapter 3", index: 2)
        ]

        // Mid-book position: User is at line 125 (inside Chapter 2 at line 100)
        let midBookLocator = TextLocator(backend: .otzaria, workKey: "book:100", position: .legacyLine(125))
        let nextPagingAction = ReaderBackendPagingCoordinator.resolvePagingAction(
            direction: .next,
            isBackendBook: true,
            currentLocator: midBookLocator,
            backendSectionNext: nil,
            backendSectionPrevious: nil,
            navigationItems: otzariaNavItems
        )
        assertCondition(
            nextPagingAction == .loadBackendLocator(otzariaNavItems[2].locator, scrollTarget: .top),
            "Next from line 125 advances to Chapter 3 at line 200"
        )

        let prevPagingAction = ReaderBackendPagingCoordinator.resolvePagingAction(
            direction: .previous,
            isBackendBook: true,
            currentLocator: midBookLocator,
            backendSectionNext: nil,
            backendSectionPrevious: nil,
            navigationItems: otzariaNavItems
        )
        assertCondition(
            prevPagingAction == .loadBackendLocator(otzariaNavItems[0].locator, scrollTarget: .bottom),
            "Prev from line 125 retreats to Chapter 1 at line 0"
        )

        // Boundary protection: First page prev is no-op (NEVER jump or legacy fallback)
        let firstPageLocator = TextLocator(backend: .otzaria, workKey: "book:100", position: .legacyLine(0))
        let firstPagePrev = ReaderBackendPagingCoordinator.resolvePagingAction(
            direction: .previous,
            isBackendBook: true,
            currentLocator: firstPageLocator,
            backendSectionNext: nil,
            backendSectionPrevious: nil,
            navigationItems: otzariaNavItems
        )
        assertCondition(firstPagePrev == .noOpBoundaryReached, "Prev from first page is safe no-op boundary reached")

        // Boundary protection: Last page next is no-op
        let lastPageLocator = TextLocator(backend: .otzaria, workKey: "book:100", position: .legacyLine(200))
        let lastPageNext = ReaderBackendPagingCoordinator.resolvePagingAction(
            direction: .next,
            isBackendBook: true,
            currentLocator: lastPageLocator,
            backendSectionNext: nil,
            backendSectionPrevious: nil,
            navigationItems: otzariaNavItems
        )
        assertCondition(lastPageNext == .noOpBoundaryReached, "Next from last page is safe no-op boundary reached")

        // 19. Extended TalmudHebrewAddressFormatter Boundaries & High Numbers (Section 11)
        print("\n--- 19. Testing Extended TalmudHebrewAddressFormatter ---")
        assertCondition(TalmudHebrewAddressFormatter.hebrewDafNumeral(from: 100) == "ק׳", "100 is ק׳ with single gersh")
        assertCondition(TalmudHebrewAddressFormatter.hebrewDafNumeral(from: 101) == "ק״א", "101 is ק״א")
        assertCondition(TalmudHebrewAddressFormatter.hebrewDafNumeral(from: 110) == "ק״י", "110 is ק״י")
        assertCondition(TalmudHebrewAddressFormatter.hebrewDafNumeral(from: 115) == "קט״ו", "115 is special קט״ו")
        assertCondition(TalmudHebrewAddressFormatter.hebrewDafNumeral(from: 116) == "קט״ז", "116 is special קט״ז")
        assertCondition(TalmudHebrewAddressFormatter.hebrewDafNumeral(from: 200) == "ר׳", "200 is ר׳")
        assertCondition(TalmudHebrewAddressFormatter.format(offset: 227) == "קט״ו ע״ב", "Offset 227 (115b) is קט״ו ע״ב")
        assertCondition(TalmudHebrewAddressFormatter.format(offset: 228) == "קט״ז ע״א", "Offset 228 (116a) is קט״ז ע״א")
        assertCondition(TalmudHebrewAddressFormatter.format(address: "115b") == "קט״ו ע״ב", "Address '115b' formatted correctly")
        assertCondition(TalmudHebrewAddressFormatter.format(address: "InvalidAddress") == "InvalidAddress", "Unparseable address falls back gracefully")

        // 20. ReaderDestinationResolver Commentary & Granularity Bounding (Section 7)
        print("\n--- 20. Testing ReaderDestinationResolver Commentary Bounding ---")
        let rashiDafSection = TextLocator(backend: .sefaria, workKey: "Rashi on Berakhot", position: .canonicalRef("Rashi on Berakhot 15b"))
        let rashiSegmentHit = TextLocator(backend: .sefaria, workKey: "Rashi on Berakhot", position: .canonicalRef("Rashi on Berakhot 15b:3:1"))
        let resolvedRashiCommentary = ReaderDestinationResolver.resolve(locator: rashiSegmentHit)
        assertCondition(resolvedRashiCommentary.isSegmentLevelFocus, "Rashi 15b:3:1 has isSegmentLevelFocus true")
        assertCondition(resolvedRashiCommentary.sectionLocator == rashiDafSection, "Rashi 15b:3:1 bounded to containing folio section 15b")
        assertCondition(resolvedRashiCommentary.focusLocator == rashiSegmentHit, "Rashi 15b:3:1 preserves exact segment hit as focus locator")

        let tanakhVerseHit = TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 1:3"))
        let resolvedTanakhCommentary = ReaderDestinationResolver.resolve(locator: tanakhVerseHit)
        assertCondition(resolvedTanakhCommentary.isSegmentLevelFocus, "Genesis 1:3 has isSegmentLevelFocus true")
        assertCondition(resolvedTanakhCommentary.sectionLocator == TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 1")), "Genesis 1:3 bounded to chapter 1")
        assertCondition(resolvedTanakhCommentary.focusLocator == tanakhVerseHit, "Genesis 1:3 preserves verse 3 as focus")

        let alreadySectionLoc = TextLocator(backend: .sefaria, workKey: "Berakhot", position: .canonicalRef("Berakhot 15b"))
        let resolvedSectionLoc = ReaderDestinationResolver.resolve(locator: alreadySectionLoc)
        assertCondition(!resolvedSectionLoc.isSegmentLevelFocus, "Berakhot 15b is not segment-level focus")
        assertCondition(resolvedSectionLoc.sectionLocator == alreadySectionLoc, "Berakhot 15b section is self")
        assertCondition(resolvedSectionLoc.focusLocator == nil, "Berakhot 15b focus locator is nil")

        // 21. RenderedHighlightSnapshot Serialization & Provenance (Section 1A)
        print("\n--- 21. Testing RenderedHighlightSnapshot Diagnostics ---")
        let item1 = RenderedHighlightItem(location: 10, length: 5, colorHex: "#FFFF00", provenance: "search")
        let item2 = RenderedHighlightItem(location: 30, length: 8, colorHex: "#0000FF", provenance: "selection")
        let testSnapshot = RenderedHighlightSnapshot(
            searchHighlightCount: 1,
            annotationHighlightCount: 0,
            segmentSelectionCount: 1,
            totalHighlights: 2,
            locator: "sefaria|Berakhot|ref:Berakhot 15b",
            renderGeneration: 4,
            highlights: [item1, item2]
        )
        let jsonStr = testSnapshot.toJSONString()
        assertCondition(!jsonStr.isEmpty && jsonStr.contains("searchHighlightCount"), "Snapshot encodes valid JSON")
        let decoded = RenderedHighlightSnapshot.fromJSONString(jsonStr)
        assertCondition(decoded == testSnapshot, "Snapshot decodes losslessly with exact counts and items")
        assertCondition(decoded?.searchHighlightCount == 1, "Decoded searchHighlightCount matches")
        assertCondition(decoded?.highlights.first?.provenance == "search", "Decoded provenance matches search")

        print("\n==========================================")
        print("SUMMARY: \(passedAssertions) of \(totalAssertions) assertions passed (0 failures).")
        print("RESULT: ALL SUITES PASSED SUCCESSFULLY")
        print("==========================================")
    }
}
