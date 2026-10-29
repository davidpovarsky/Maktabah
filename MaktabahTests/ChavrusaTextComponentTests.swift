//
//  ChavrusaTextComponentTests.swift
//  MaktabahTests
//
//  Hardened unit tests for ChavrusaText fork-owned components (Batch A - Pass 3).
//

import Foundation
@testable import Maktabah_Debug
import Testing

@Suite("ChavrusaText Component Hardening Suite (Batch A Pass 3)")
struct ChavrusaTextComponentTests {

    // MARK: - 1. SerializedSessionWriter Tests
    @Test("SerializedSessionWriter: Atomic write and last-good preservation")
    func testSerializedSessionWriterAtomicAndPreservation() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let targetURL = tempDir.appendingPathComponent("session.json")
        let writer = SerializedSessionWriter(queueLabel: "test.writer.atomic")

        // 1. Initial write
        let initialData = "{\"rev\": 1}".data(using: .utf8)!
        try writer.saveImmediately(to: targetURL) { initialData }
        let read1 = try Data(contentsOf: targetURL)
        #expect(read1 == initialData)

        // 2. Failed write must NOT delete or corrupt last-good file
        struct TestDiskError: Error {}
        do {
            try writer.saveImmediately(to: targetURL) {
                throw TestDiskError()
            }
            #expect(Bool(false), "Should have thrown TestDiskError")
        } catch {
            // Expected
        }
        let readAfterFailure = try Data(contentsOf: targetURL)
        #expect(readAfterFailure == initialData)
    }

    @Test("SerializedSessionWriter: Concurrency and stale write rejection")
    func testSerializedSessionWriterConcurrency() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let targetURL = tempDir.appendingPathComponent("session.json")
        let writer = SerializedSessionWriter(queueLabel: "test.writer.concurrency")

        // Schedule a debounced write for rev 1
        let staleData = "{\"stale\": true}".data(using: .utf8)!
        writer.scheduleSave(to: targetURL, debounceInterval: 0.1) {
            staleData
        }

        // Immediately execute rev 2
        let freshData = "{\"fresh\": true}".data(using: .utf8)!
        try writer.saveImmediately(to: targetURL) {
            freshData
        }

        // Wait for debounce interval to pass
        Thread.sleep(forTimeInterval: 0.2)

        // Target file must contain freshData, not overwritten by delayed staleData
        let finalData = try Data(contentsOf: targetURL)
        #expect(finalData == freshData)

        // Delayed write error tracking
        struct AsyncError: Error {}
        var reportedRev: UInt64? = nil
        writer.onDelayedWriteError = { rev, _ in
            reportedRev = rev
        }
        writer.scheduleSave(to: targetURL, debounceInterval: 0.05) {
            throw AsyncError()
        }
        Thread.sleep(forTimeInterval: 0.15)
        #expect(reportedRev != nil)
        #expect(writer.lastDelayedWriteError != nil)
    }

    // MARK: - 2. ReaderSelectionRangeMapper Tests
    @Test("ReaderSelectionRangeMapper: Valid mapping and bounds checks")
    func testReaderSelectionRangeMapper() {
        let mapper = ReaderSelectionRangeMapper()
        let sample = "שלום עליכם" // 10 UTF-16 code units

        // Valid
        let res = mapper.mapSelection(displayedRange: NSRange(location: 0, length: 4), sourceText: sample)
        switch res {
        case .success(let mapped):
            #expect(mapped.selectedText == "שלום")
            #expect(mapped.sourceRange == NSRange(location: 0, length: 4))
        case .failure(let err):
            #expect(Bool(false), "Unexpected failure: \(err)")
        }

        // Empty selection
        let emptyRes = mapper.mapSelection(displayedRange: NSRange(location: 0, length: 0), sourceText: sample)
        #expect(emptyRes == .failure(.emptySelection))

        // Negative location
        let negRes = mapper.mapSelection(displayedRange: NSRange(location: -1, length: 3), sourceText: sample)
        #expect(negRes == .failure(.negativeLocation(-1)))

        // Overflow
        let ovfRes = mapper.mapSelection(displayedRange: NSRange(location: Int.max - 1, length: 5), sourceText: sample)
        if case .failure(.integerOverflow) = ovfRes {
            #expect(true)
        } else {
            #expect(Bool(false), "Expected integerOverflow")
        }

        // Out of bounds
        let oobRes = mapper.mapSelection(displayedRange: NSRange(location: 8, length: 5), sourceText: sample)
        if case .failure(.outOfBounds) = oobRes {
            #expect(true)
        } else {
            #expect(Bool(false), "Expected outOfBounds")
        }

        // Mismatched render requires provider
        let diffRes = mapper.mapSelection(
            displayedRange: NSRange(location: 0, length: 2),
            sourceText: sample,
            displayedText: "வேறு உரை",
            mappingProvider: nil
        )
        #expect(diffRes == .failure(.mappingRequiredAcrossDifferentRenders))

        // Custom closure mapping provider
        let mockProvider = ClosureRangeMappingProvider { r in
            NSRange(location: r.location + 5, length: r.length)
        }
        let providerRes = mapper.mapSelection(
            displayedRange: NSRange(location: 0, length: 5),
            sourceText: sample,
            displayedText: "வேறு உரை",
            mappingProvider: mockProvider
        )
        switch providerRes {
        case .success(let m):
            #expect(m.sourceRange == NSRange(location: 5, length: 5))
            #expect(m.selectedText == "עליכם")
        case .failure(let err):
            #expect(Bool(false), "Unexpected failure with provider: \(err)")
        }
    }

    @Test("ReaderSelectionRangeMapper: Unicode surrogate pair integrity")
    func testSurrogatePairIntegrity() {
        let mapper = ReaderSelectionRangeMapper()
        // String with 4-byte emoji (surrogate pair in UTF-16): "א😀ב"
        // 'א' = 1 code unit (index 0)
        // '😀' = 2 code units: 0xD83D, 0xDE00 (indices 1, 2)
        // 'ב' = 1 code unit (index 3)
        let sample = "א\u{1F600}ב"

        // Selecting starting at index 2 (middle of emoji) must fail with invalidUnicodeBoundary
        let splitStart = mapper.mapSelection(displayedRange: NSRange(location: 2, length: 2), sourceText: sample)
        if case .failure(.invalidUnicodeBoundary) = splitStart {
            #expect(true)
        } else {
            #expect(Bool(false), "Expected invalidUnicodeBoundary for start splitting surrogate pair")
        }

        // Selecting ending at index 2 (middle of emoji) must fail with invalidUnicodeBoundary
        let splitEnd = mapper.mapSelection(displayedRange: NSRange(location: 0, length: 2), sourceText: sample)
        if case .failure(.invalidUnicodeBoundary) = splitEnd {
            #expect(true)
        } else {
            #expect(Bool(false), "Expected invalidUnicodeBoundary for end splitting surrogate pair")
        }
    }

    // MARK: - 3. ReaderPullNavigationStateMachine Tests
    @Test("ReaderPullNavigationStateMachine: Pull prev, next, bounce and retreat")
    func testPullStateMachine() {
        let sm = ReaderPullNavigationStateMachine(pullThreshold: 80.0)

        // Top drag past threshold
        _ = sm.handleScroll(topOverscroll: 40.0, bottomOverscroll: 0, isTracking: true, isRestoringScroll: false)
        #expect(sm.state == .dragging(direction: .prev, overscroll: 40.0, progress: 0.5))

        let armedRes = sm.handleScroll(topOverscroll: 85.0, bottomOverscroll: 0, isTracking: true, isRestoringScroll: false)
        #expect(armedRes.shouldTriggerHaptic == true)
        #expect(sm.state == .armed(direction: .prev, overscroll: 85.0))

        // Non-tracking bounce scroll callback MUST NOT clear armed state (BUG-02 fix)
        _ = sm.handleScroll(topOverscroll: 70.0, bottomOverscroll: 0, isTracking: false, isRestoringScroll: false)
        #expect(sm.state == .armed(direction: .prev, overscroll: 85.0))

        // End dragging commits
        let committed = sm.handleEndDragging(willDecelerate: false)
        #expect(committed == .prev)
        #expect(sm.state == .idle)

        // Retreat disarm
        _ = sm.handleScroll(topOverscroll: 90.0, bottomOverscroll: 0, isTracking: true, isRestoringScroll: false)
        #expect(sm.state == .armed(direction: .prev, overscroll: 90.0))
        _ = sm.handleScroll(topOverscroll: 0.0, bottomOverscroll: 0, isTracking: true, isRestoringScroll: false)
        #expect(sm.state == .idle)
        #expect(sm.handleEndDragging(willDecelerate: false) == nil)
    }

    // MARK: - 4. ReaderSessionRestoreCoordinator Tests
    @Test("ReaderSessionRestoreCoordinator: Stale and valid ID resolution")
    func testSessionRestoreCoordinator() {
        struct DummyTab: Identifiable, Equatable {
            let id: UUID
            let name: String
        }

        let coord = ReaderSessionRestoreCoordinator()
        let id1 = UUID()
        let id2 = UUID()
        let tabs = [DummyTab(id: id1, name: "One"), DummyTab(id: id2, name: "Two")]

        // Valid ID
        let resValid = coord.resolveActiveTab(savedActiveId: id2, restoredTabs: tabs)
        #expect(resValid.activeTabId == id2)
        #expect(!resValid.wasStaleIdNormalized)

        // Stale ID
        let staleId = UUID()
        let resStale = coord.resolveActiveTab(savedActiveId: staleId, restoredTabs: tabs)
        #expect(resStale.activeTabId == id1)
        #expect(resStale.wasStaleIdNormalized)

        // Empty tabs
        let resEmpty = coord.resolveActiveTab(savedActiveId: staleId, restoredTabs: [DummyTab]())
        #expect(resEmpty.activeTabId == nil)
    }

    // MARK: - 5. BackendAnnotationBridge Tests
    @Test("BackendAnnotationBridge: Target validation and persistence mock")
    func testBackendAnnotationBridge() throws {
        let bridge = BackendAnnotationBridge.shared
        let locator = try bridge.resolveLocator(bookId: 101, workKey: "berakhot", backendID: "otzaria", contentId: 42)
        #expect(locator.backend == .otzaria)
        #expect(locator.workKey == "berakhot")
        #expect(locator.position == .legacyLine(42))

        // Nil contentId throws
        #expect(throws: AnnotationBridgeError.missingContentPosition) {
            _ = try bridge.resolveLocator(bookId: 101, workKey: "berakhot", backendID: "otzaria", contentId: nil)
        }

        // Invalid backend throws
        #expect(throws: AnnotationBridgeError.missingLocator) {
            _ = try bridge.resolveLocator(bookId: 101, workKey: "berakhot", backendID: "nonexistent", contentId: 42)
        }

        // Target validation
        #expect(throws: AnnotationBridgeError.missingLocator) {
            try bridge.validateTarget(range: NSRange(location: 0, length: 5), sourceLength: 20, locator: nil)
        }

        #expect(throws: AnnotationBridgeError.self) {
            let emptyWorkLocator = TextLocator(backend: .otzaria, workKey: "", position: .legacyLine(1))
            try bridge.validateTarget(range: NSRange(location: 0, length: 5), sourceLength: 20, locator: emptyWorkLocator)
        }

        // Persistence adapter test
        let adapter = InMemoryAnnotationPersistenceAdapter()
        let record = try adapter.persistAnnotation(locator: locator, range: NSRange(location: 2, length: 10), text: "highlight", colorHex: "#FF0000")
        #expect(record.selectedText == "highlight")

        let fetched = try adapter.fetchAnnotations(for: locator)
        #expect(fetched.count == 1)
        #expect(fetched.first?.id == record.id)
    }

    // MARK: - 6. ChavrusaTextLocalizationResolver Tests
    @Test("ChavrusaTextLocalizationResolver: Exact Hebrew and English titles")
    func testLocalizationResolver() {
        // Forced Hebrew
        #expect(ChavrusaTextLocalizationResolver.resolveTabTitle(for: .history, forcedLocaleIdentifier: "he") == "היסטוריה")
        #expect(ChavrusaTextLocalizationResolver.resolveTabTitle(for: .library, forcedLocaleIdentifier: "he") == "ספרייה")
        #expect(ChavrusaTextLocalizationResolver.resolveTabTitle(for: .search, forcedLocaleIdentifier: "he") == "חיפוש")
        #expect(ChavrusaTextLocalizationResolver.resolveTabTitle(for: .narrators, forcedLocaleIdentifier: "he") == "מוסרים")
        #expect(ChavrusaTextLocalizationResolver.resolveTabTitle(for: .annotations, forcedLocaleIdentifier: "he") == "הערות")

        // Forced English
        #expect(ChavrusaTextLocalizationResolver.resolveTabTitle(for: .history, forcedLocaleIdentifier: "en") == "History")
        #expect(ChavrusaTextLocalizationResolver.resolveTabTitle(for: .library, forcedLocaleIdentifier: "en") == "Library")
        #expect(ChavrusaTextLocalizationResolver.resolveTabTitle(for: .search, forcedLocaleIdentifier: "en") == "Search")
        #expect(ChavrusaTextLocalizationResolver.resolveTabTitle(for: .narrators, forcedLocaleIdentifier: "en") == "Narrators")
        #expect(ChavrusaTextLocalizationResolver.resolveTabTitle(for: .annotations, forcedLocaleIdentifier: "en") == "Annotations")
    }

    // MARK: - 7. BackendNavigationAdapter Tests
    @Test("BackendNavigationAdapter: Persistent disk-backed snapshot isolation")
    func testBackendNavigationAdapter() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let adapter = BackendNavigationAdapter(storageDirectory: tempDir)
        let otzariaData = "{\"backend\": \"otzaria\"}".data(using: .utf8)!
        let sefariaData = "{\"backend\": \"sefaria\"}".data(using: .utf8)!

        try adapter.saveBackendSessionSnapshot(backendID: "otzaria", sessionData: otzariaData)
        try adapter.saveBackendSessionSnapshot(backendID: "sefaria", sessionData: sefariaData)

        #expect(adapter.retrieveBackendSessionSnapshot(backendID: "otzaria") == otzariaData)
        #expect(adapter.retrieveBackendSessionSnapshot(backendID: "sefaria") == sefariaData)

        // Clear otzaria
        try adapter.clearBackendSessionSnapshot(backendID: "otzaria")
        #expect(adapter.retrieveBackendSessionSnapshot(backendID: "otzaria") == nil)
        #expect(adapter.retrieveBackendSessionSnapshot(backendID: "sefaria") == sefariaData)

        // Path traversal rejection
        #expect(throws: BackendNavigationAdapterError.invalidBackendID("../traversal")) {
            _ = try adapter.validateBackendID("../traversal")
        }

        // Canonical enum overload
        try adapter.saveBackendSessionSnapshot(backend: .otzaria, sessionData: otzariaData)
        #expect(adapter.retrieveBackendSessionSnapshot(backend: .otzaria) == otzariaData)
    }

    // MARK: - 8. BackendCoordinator Two-Phase Switch Orchestration Tests
    @Test("BackendCoordinator: Two-phase switch orchestration and rollback")
    func testBackendCoordinatorTwoPhaseSwitch() throws {
        let suiteName = "test.coordinator.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        final class MockParticipant: BackendSwitchParticipant {
            var shouldFailPrepare = false
            var prepareCalledCount = 0
            var publishCalledCount = 0
            var completeCalledCount = 0
            var abortCalledCount = 0
            var openTabs: [String] = ["tab1", "tab2"]

            func prepareTransition(from currentBackend: BackendID, to targetBackend: BackendID, token: UInt64) throws -> PreparedBackendTransition? {
                prepareCalledCount += 1
                if shouldFailPrepare {
                    throw BackendNavigationAdapterError.writeFailed("prepare failure")
                }
                return PreparedBackendTransition(
                    transitionToken: token,
                    outgoingBackend: currentBackend,
                    incomingBackend: targetBackend,
                    outgoingSnapshotData: nil,
                    incomingSnapshotData: nil,
                    isCleanDestination: false,
                    stagedTabs: [
                        .init(id: UUID(), bookId: 1, bookTitle: "new1", backendLocator: nil),
                        .init(id: UUID(), bookId: 2, bookTitle: "new2", backendLocator: nil)
                    ],
                    targetActiveTabId: nil
                )
            }

            func publishTransition(to targetBackend: BackendID, transition: PreparedBackendTransition?) {
                publishCalledCount += 1
                if let transition = transition {
                    openTabs = transition.stagedTabs.map(\.bookTitle)
                }
            }

            func completeTransition(to targetBackend: BackendID) {
                completeCalledCount += 1
            }

            func abortTransition(from currentBackend: BackendID, to targetBackend: BackendID, error: Error) {
                abortCalledCount += 1
            }
        }

        let coordinator = BackendCoordinator(defaults: defaults)
        let participant = MockParticipant()
        coordinator.addSwitchParticipant(participant)

        #expect(coordinator.activeBackendID == .otzaria)
        let initialGen = coordinator.generation

        // 1. Prepare failure fails closed without destroying tabs
        participant.shouldFailPrepare = true
        #expect(throws: BackendNavigationAdapterError.writeFailed("prepare failure")) {
            try coordinator.commitChecked(.sefaria)
        }
        #expect(participant.prepareCalledCount == 1)
        #expect(participant.publishCalledCount == 0)
        #expect(participant.abortCalledCount == 1)
        #expect(participant.openTabs == ["tab1", "tab2"])
        #expect(coordinator.activeBackendID == .otzaria)
        #expect(coordinator.generation == initialGen)

        // 2. Successful switch installs tabs in non-throwing publish
        participant.shouldFailPrepare = false
        participant.abortCalledCount = 0
        let success = coordinator.commit(.sefaria)
        #expect(success)
        #expect(coordinator.activeBackendID == .sefaria)
        #expect(coordinator.generation == initialGen + 1)
        #expect(participant.publishCalledCount == 1)
        #expect(participant.completeCalledCount == 1)
        #expect(participant.openTabs == ["new1", "new2"])
    }

    // MARK: - 10. Three-Source Backend Identity & Localization
    @Test("Three-Source Backend: Identity, rawValue immutability, and display names")
    func testThreeSourceBackendIdentityAndLocalization() throws {
        #expect(BackendID.allCases.count == 3)
        #expect(BackendID.otzaria.rawValue == "otzaria")
        #expect(BackendID.sefaria.rawValue == "sefaria")
        #expect(BackendID.sefariaEmbedded.rawValue == "sefariaEmbedded")

        #expect(BackendID.otzaria.displayName == "אוצריא")
        #expect(BackendID.sefaria.displayName == "ספריא (ישן)")
        #expect(BackendID.sefariaEmbedded.displayName == "ספריא")

        #expect(ChavrusaTextLocalizationResolver.resolveBackendTitle(for: .otzaria, forcedLocaleIdentifier: "en") == "Otzaria")
        #expect(ChavrusaTextLocalizationResolver.resolveBackendTitle(for: .sefaria, forcedLocaleIdentifier: "en") == "Sefaria (Legacy)")
        #expect(ChavrusaTextLocalizationResolver.resolveBackendTitle(for: .sefariaEmbedded, forcedLocaleIdentifier: "en") == "Sefaria")

        #expect(BackendID(rawValue: "sefaria") == .sefaria)
        #expect(BackendID(rawValue: "sefariaEmbedded") == .sefariaEmbedded)

        let decodedLegacy = try JSONDecoder().decode(BackendID.self, from: "\"sefaria\"".data(using: .utf8)!)
        #expect(decodedLegacy == .sefaria)
        let decodedEmbedded = try JSONDecoder().decode(BackendID.self, from: "\"sefariaEmbedded\"".data(using: .utf8)!)
        #expect(decodedEmbedded == .sefariaEmbedded)
    }

    // MARK: - 11. Three-Source TextLocator Persistence & Session Isolation
    @Test("Three-Source Backend: TextLocator persistence and session repair isolation")
    func testThreeSourceTextLocatorPersistenceAndSessionIsolation() throws {
        let locOtzaria = TextLocator(backend: .otzaria, workKey: "book:103", position: .legacyLine(2034))
        let locSefariaLegacy = TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 1:1"))
        let locSefariaEmbedded = TextLocator(backend: .sefariaEmbedded, workKey: "Genesis", position: .canonicalRef("Genesis 1:1"))

        #expect(locOtzaria.persistenceKey == "otzaria|book:103|line:2034")
        #expect(locSefariaLegacy.persistenceKey == "sefaria|Genesis|ref:Genesis 1:1")
        #expect(locSefariaEmbedded.persistenceKey == "sefariaEmbedded|Genesis|ref:Genesis 1:1")
        #expect(locSefariaLegacy.persistenceKey != locSefariaEmbedded.persistenceKey)

        let tabOtzaria = iOSReaderTabSession(id: UUID(), bookId: 103, locator: locOtzaria)
        let tabLegacy = iOSReaderTabSession(id: UUID(), bookId: 200, locator: locSefariaLegacy)
        let tabEmbedded = iOSReaderTabSession(id: UUID(), bookId: 300, locator: locSefariaEmbedded)

        #expect(BackendSessionIntegrityRepair.shared.detectTabBackend(tabOtzaria) == .otzaria)
        #expect(BackendSessionIntegrityRepair.shared.detectTabBackend(tabLegacy) == .sefaria)
        #expect(BackendSessionIntegrityRepair.shared.detectTabBackend(tabEmbedded) == .sefariaEmbedded)

        let mixedSession = iOSReaderSession(
            activeTabId: tabEmbedded.id,
            tabs: [tabOtzaria, tabLegacy, tabEmbedded]
        )

        let embeddedRepair = BackendSessionIntegrityRepair.shared.repairSessionSnapshot(
            session: mixedSession,
            targetBackend: .sefariaEmbedded
        )
        #expect(embeddedRepair.sanitizedSession.tabs.count == 1)
        #expect(embeddedRepair.sanitizedSession.tabs.first?.locator?.backend == .sefariaEmbedded)
        #expect(embeddedRepair.foreignTabs.count == 2)
        #expect(embeddedRepair.sanitizedSession.backend == "sefariaEmbedded")

        let legacyRepair = BackendSessionIntegrityRepair.shared.repairSessionSnapshot(
            session: mixedSession,
            targetBackend: .sefaria
        )
        #expect(legacyRepair.sanitizedSession.tabs.count == 1)
        #expect(legacyRepair.sanitizedSession.tabs.first?.locator?.backend == .sefaria)
        #expect(legacyRepair.foreignTabs.count == 2)
        #expect(legacyRepair.sanitizedSession.backend == "sefaria")
    }

    // MARK: - 12. SefariaRPC Wire Models & JSON Boundary Roundtrip
    @Test("SefariaRPC: Wire models, UTF-8 Hebrew preservation, and decodeResult")
    func testSefariaRPCWireModelsAndDecodeResult() throws {
        let sampleParams = ["ref": "Genesis 1:1", "language": "he", "text": "בְּרֵאשִׁית בָּרָא אֱלֹהִים"]
        let paramsData = try JSONSerialization.data(withJSONObject: sampleParams)
        let paramsJson = String(data: paramsData, encoding: .utf8)!

        let envelope = SefariaRPCEnvelope(
            protocolVersion: "1.0",
            requestID: "req-1234",
            method: "text.load",
            paramsJson: paramsJson,
            backendID: "sefariaEmbedded",
            sessionGeneration: 42,
            timeoutMs: 15000
        )

        let envData = try JSONEncoder().encode(envelope)
        let envJsonStr = String(data: envData, encoding: .utf8)!
        #expect(!envJsonStr.contains("paramsData"))
        #expect(envJsonStr.contains("בְּרֵאשִׁית"))

        let decodedEnv = try JSONDecoder().decode(SefariaRPCEnvelope.self, from: envData)
        #expect(decodedEnv.requestID == "req-1234")
        #expect(decodedEnv.sessionGeneration == 42)
        #expect(decodedEnv.backendID == "sefariaEmbedded")

        struct SampleTextResult: Codable, Equatable {
            let sectionRef: String
            let heSectionRef: String
        }
        let sampleResult = SampleTextResult(sectionRef: "Genesis 1", heSectionRef: "בראשית א׳")
        let resultData = try JSONEncoder().encode(sampleResult)
        let resultJsonStr = String(data: resultData, encoding: .utf8)!

        let response = SefariaRPCResponse(
            protocolVersion: "1.0",
            requestID: "req-1234",
            status: "success",
            resultJson: resultJsonStr,
            error: nil,
            sessionGeneration: 42
        )
        #expect(response.isSuccess)
        let decodedResult = try response.decodeResult(SampleTextResult.self)
        #expect(decodedResult == sampleResult)

        let rpcError = SefariaRPCError(code: "NOT_FOUND", message: "Section not found", retryable: false)
        let errResponse = SefariaRPCResponse(
            protocolVersion: "1.0",
            requestID: "req-5678",
            status: "error",
            resultJson: nil,
            error: rpcError,
            sessionGeneration: 42
        )
        #expect(!errResponse.isSuccess)
        #expect(errResponse.error?.code == "NOT_FOUND")
    }

    // MARK: - 13. SefariaEmbedded Offline & Search Models Conformance
    @Test("SefariaEmbedded: Offline & search models protocol conformance")
    func testSefariaEmbeddedOfflineAndSearchModels() {
        let pkg = OfflinePackage(
            id: "Torah",
            title: "Torah",
            heTitle: "תורה",
            parentID: "COMPLETE LIBRARY",
            compressedSize: 52428800,
            indexTitles: ["Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy"],
            isCompleteLibrary: false
        )
        #expect(pkg.id == "Torah")
        #expect(pkg.compressedSize == 52428800)
        #expect(pkg.indexTitles?.count == 5)
        #expect(!pkg.isCompleteLibrary)

        let completePkg = OfflinePackage(
            id: "COMPLETE LIBRARY",
            title: "Complete Library",
            heTitle: "כל הספרייה",
            parentID: nil,
            compressedSize: 1048576000,
            indexTitles: nil,
            isCompleteLibrary: true
        )
        #expect(completePkg.isCompleteLibrary)

        let progress = OfflineInstallProgress(
            phase: .downloading,
            packageID: "Torah",
            completedBytes: 26214400,
            totalBytes: 52428800
        )
        #expect(progress.phase == .downloading)
        #expect(progress.completedBytes == 26214400)

        let summary = OfflineUpdateSummary(
            changedWorkCount: 3,
            affectedPackageIDs: ["Torah", "Talmud"]
        )
        #expect(summary.hasUpdates)
        #expect(summary.changedWorkCount == 3)
        #expect(summary.affectedPackageIDs.contains("Torah"))

        let emptySummary = OfflineUpdateSummary(changedWorkCount: 0, affectedPackageIDs: [])
        #expect(!emptySummary.hasUpdates)

        let searchHit = LibrarySearchHit(
            locator: TextLocator(backend: .sefariaEmbedded, workKey: "Genesis 1:1", position: .canonicalRef("Genesis 1:1")),
            displayRef: "Genesis 1:1",
            heRef: "בראשית א׳:א׳",
            snippet: "<b>בְּרֵאשִׁית</b> בָּרָא",
            score: 1.45,
            versionTitle: "Miqra according to the Masorah",
            language: "hebrew"
        )
        #expect(searchHit.displayRef == "Genesis 1:1")
        #expect(searchHit.locator.backend == .sefariaEmbedded)

        let searchPage = LibrarySearchPage(hits: [searchHit], total: 100, nextOffset: 20)
        #expect(searchPage.hits.count == 1)
        #expect(searchPage.total == 100)
        #expect(searchPage.nextOffset == 20)
    }

    // MARK: - 14. SefariaEmbedded Text & Relationship Structures
    @Test("SefariaEmbedded: Text & relationship structures mapping")
    func testSefariaEmbeddedTextAndRelationshipsStructures() {
        let segLocator = TextLocator(backend: .sefariaEmbedded, workKey: "Genesis", position: .canonicalRef("Genesis 1:1"))
        let segment = LibraryTextSegment(
            locator: segLocator,
            heRef: "בראשית א׳:א׳",
            primaryText: "בְּרֵאשִׁית בָּרָא אֱלֹהִים",
            translation: "In the beginning God created"
        )
        #expect(segment.primaryText.contains("בְּרֵאשִׁית"))
        #expect(segment.translation == "In the beginning God created")
        #expect(segment.sourceText == segment.primaryText)

        let section = LibraryTextSection(
            locator: TextLocator(backend: .sefariaEmbedded, workKey: "Genesis", position: .canonicalRef("Genesis 1")),
            displayRef: "Genesis 1",
            heRef: "בראשית פרק א׳",
            segments: [segment],
            previous: nil,
            next: TextLocator(backend: .sefariaEmbedded, workKey: "Genesis", position: .canonicalRef("Genesis 2")),
            versions: [],
            links: [],
            origin: .offline
        )
        #expect(section.displayRef == "Genesis 1")
        #expect(section.segments.count == 1)
        #expect(section.next?.position == .canonicalRef("Genesis 2"))
        #expect(section.origin == .offline)

        let related = LibraryRelatedSource(
            locator: TextLocator(backend: .sefariaEmbedded, workKey: "Rashi on Genesis 1:1:1", position: .canonicalRef("Rashi on Genesis 1:1:1")),
            displayRef: "Rashi on Genesis 1:1:1",
            heRef: "רש״י על בראשית א׳:א׳:א׳",
            category: "Commentary",
            type: "Commentary",
            collectiveTitle: "Rashi",
            heCollectiveTitle: "רש״י",
            primaryText: "בראשית ברא",
            translation: nil,
            versionTitle: nil,
            heVersionTitle: nil,
            license: nil,
            anchorRefs: ["Genesis 1:1"]
        )
        #expect(related.collectiveTitle == "Rashi")
        #expect(related.heCollectiveTitle == "רש״י")
        #expect(related.anchorRefs == ["Genesis 1:1"])
    }
}
