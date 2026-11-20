import Foundation
import XCTest
import OtzariaActionCore
import OtzariaUIRouting
@testable import ChavrusaUIRoutingHost

// The COMPLETE original Service, Core executor/resolver, policy, grants and
// semantic sequence execute here. Catalog rows, source changes and native UI
// receipts are explicit in-memory doubles. This is not AppIntents/UIKit proof.
@MainActor final class NativeReaderCompoundIntentTests: XCTestCase, @unchecked Sendable {
    func testDefaultAndExplicitNilKeepOriginalSingleMetadataPath() async throws {
        for explicit in [false, true] {
            let f = CompoundIntentFixture(), service = try f.service(), ids = try f.identifiers()
            let value: UISceneAcknowledgement
            if explicit {
                value = try await service.open(workIdentifier: ids.base, locationIdentifier: ids.location,
                    windowIdentifier: "selected-window", newTab: false,
                    commentaryWorkIdentifier: nil, proposedText: nil)
            } else {
                value = try await service.open(workIdentifier: ids.base, locationIdentifier: ids.location,
                    windowIdentifier: "selected-window", newTab: false)
            }
            XCTAssertEqual(value, .queued(handle: "original-navigation-double"))
            XCTAssertEqual(f.metadata.map(\.action), ["catalog.resolveReference"])
            XCTAssertEqual(f.navigated.count, 1); XCTAssertNil(f.navigated[0].commentaryDraft)
            XCTAssertFalse(f.navigated[0].newTab); XCTAssertEqual(f.navigated[0].locator, f.base)
            XCTAssertTrue(f.nativeRequests.isEmpty)
        }
    }

    func testExplicitPairUsesActualCoreMetadataAndTwoSeparateAdmissions() async throws {
        let f = CompoundIntentFixture(), service = try f.service(), ids = try f.identifiers()
        let proposal = "הערה e\u{0301}\nsecond line"
        let result = try await service.open(workIdentifier: ids.base, locationIdentifier: ids.location,
            windowIdentifier: "selected-window", newTab: true,
            commentaryWorkIdentifier: ids.commentary, proposedText: proposal)
        try NativeIntentOutcome.requireVisibleAcknowledgement(result)
        XCTAssertEqual(result, .acknowledged(try XCTUnwrap(f.receipts.last)))
        XCTAssertEqual(f.metadata.map(\.action), ["catalog.resolveReference", "catalog.resolveWork"])
        XCTAssertEqual(f.nativeRequests.map(\.action), ["reader.openCommentary", "notes.prepareDraft"])
        XCTAssertNotEqual(f.nativeRequests[0].requestId, f.nativeRequests[1].requestId)
        XCTAssertEqual(f.receipts.count, 2); XCTAssertEqual(f.readerCalls, 1); XCTAssertEqual(f.noteCalls, 1)
        XCTAssertEqual(f.displayedDraft?.locator, f.focus); XCTAssertNotEqual(f.displayedDraft?.locator, f.base)
        XCTAssertEqual(Array(try XCTUnwrap(f.displayedDraft?.proposedText).utf8), Array(proposal.utf8))
        XCTAssertNil(f.displayedDraft?.selectedText)
        XCTAssertEqual(f.navigationContext.origin, .appIntent)
        XCTAssertEqual(f.navigationContext.scopes, [.navigation, .discovery])
        XCTAssertTrue(f.navigationContext.contentRights.isEmpty)
        XCTAssertEqual(f.headlessSearchCalls, 0)
    }

    func testIncompletePairFailsBeforeMetadataOrNativeWork() async throws {
        for includeWork in [false, true] {
            let f = CompoundIntentFixture(), service = try f.service(), ids = try f.identifiers()
            do {
                _ = try await service.open(workIdentifier: ids.base, locationIdentifier: ids.location,
                    windowIdentifier: "selected-window", newTab: true,
                    commentaryWorkIdentifier: includeWork ? ids.commentary : nil,
                    proposedText: includeWork ? nil : "proposal")
                XCTFail("Incomplete intent became an ordinary reader open")
            } catch { XCTAssertEqual((error as? UIRouteError)?.code, "incomplete_intent_commentary_draft") }
            XCTAssertTrue(f.metadata.isEmpty); XCTAssertTrue(f.navigated.isEmpty)
        }
    }

    func testCompoundCannotReplaceTheBaseTab() async throws {
        let f = CompoundIntentFixture(), service = try f.service(), ids = try f.identifiers()
        do {
            _ = try await service.open(workIdentifier: ids.base, locationIdentifier: ids.location,
                windowIdentifier: "selected-window", newTab: false,
                commentaryWorkIdentifier: ids.commentary, proposedText: "proposal")
            XCTFail("Same-tab mutation accepted")
        } catch { XCTAssertEqual((error as? UIRouteError)?.code, "intent_commentary_requires_new_tab") }
        XCTAssertTrue(f.metadata.isEmpty); XCTAssertTrue(f.navigated.isEmpty)
    }

    func testOversizedProposalCannotOpenReaderBeforeDraftRefusal() async throws {
        let f = CompoundIntentFixture(), service = try f.service(), ids = try f.identifiers()
        do {
            _ = try await service.open(workIdentifier: ids.base, locationIdentifier: ids.location,
                windowIdentifier: "selected-window", newTab: true,
                commentaryWorkIdentifier: ids.commentary, proposedText: String(repeating: "א", count: 10_001))
            XCTFail("Oversized note reached a UI action")
        } catch { XCTAssertEqual((error as? UIRouteError)?.code, "invalid_intent_note_proposal") }
        XCTAssertTrue(f.metadata.isEmpty); XCTAssertTrue(f.navigated.isEmpty)
    }

    func testBlankExplicitProposalRemainsAnUnsavedBlankDraft() async throws {
        let f = CompoundIntentFixture()
        _ = try await f.open(proposal: "")
        XCTAssertEqual(f.displayedDraft?.proposedText, "")
        XCTAssertEqual(f.journey?.steps.last?.data?["saved"], .bool(false))
    }

    func testWrongBackendCommentaryFailsBeforeMetadata() async throws {
        let f = CompoundIntentFixture(), service = try f.service(), ids = try f.identifiers()
        let other = try NativeReaderIntentService.Work(reference: .init(backend: .sefaria, workKey: f.commentary.workKey), title: "Same title")
        do {
            _ = try await service.open(workIdentifier: ids.base, locationIdentifier: ids.location,
                windowIdentifier: "selected-window", newTab: true,
                commentaryWorkIdentifier: other.id, proposedText: "proposal")
            XCTFail("Cross-backend metadata became authority")
        } catch { XCTAssertEqual((error as? UIRouteError)?.code, "intent_commentary_backend_mismatch") }
        XCTAssertTrue(f.metadata.isEmpty); XCTAssertTrue(f.navigated.isEmpty)
    }

    func testNoncanonicalCommentaryEntityCannotReachCore() async throws {
        let f = CompoundIntentFixture(), service = try f.service(), ids = try f.identifiers()
        do {
            _ = try await service.open(workIdentifier: ids.base, locationIdentifier: ids.location,
                windowIdentifier: "selected-window", newTab: true,
                commentaryWorkIdentifier: ids.commentary + "=", proposedText: "proposal")
            XCTFail("Noncanonical entity accepted")
        } catch { XCTAssertTrue(error is UIRouteError) }
        XCTAssertTrue(f.metadata.isEmpty); XCTAssertTrue(f.navigated.isEmpty)
    }

    func testRemovedCommentaryStopsBeforeAnyNativeStep() async throws {
        let f = CompoundIntentFixture(); f.removeCommentaryOnSecondMetadata = true
        do { _ = try await f.open(); XCTFail("Removed commentary navigated") }
        catch { XCTAssertEqual((error as? UIRouteError)?.code, "intent_commentary_no_longer_available") }
        XCTAssertEqual(f.metadata.count, 2); XCTAssertTrue(f.navigated.isEmpty)
        XCTAssertEqual(f.readerCalls + f.noteCalls, 0)
    }

    func testGenerationChangeBetweenMetadataCallsStopsBeforeNavigate() async throws {
        let f = CompoundIntentFixture()
        f.afterMetadata = { request in
            if request.action == "catalog.resolveReference" { f.current = .init(backend: .otzaria, generation: 8) }
        }
        do { _ = try await f.open(); XCTFail("Mixed source snapshots navigated") }
        catch { XCTAssertEqual((error as? UIRouteError)?.code, "intent_source_generation_changed") }
        XCTAssertTrue(f.navigated.isEmpty)
    }

    func testChangedCachedBaseLocationCannotReachCommentaryLookup() async throws {
        let f = CompoundIntentFixture(), service = try f.service(), ids = try f.identifiers()
        f.resolvedBase = .init(backend: .otzaria, workKey: f.base.workKey, position: .legacyLine(13))
        do {
            _ = try await service.open(workIdentifier: ids.base, locationIdentifier: ids.location,
                windowIdentifier: "selected-window", newTab: true,
                commentaryWorkIdentifier: ids.commentary, proposedText: "proposal")
            XCTFail("Cached locator changed")
        } catch { XCTAssertEqual((error as? UIRouteError)?.code, "intent_location_identity_changed") }
        XCTAssertEqual(f.metadata.count, 1); XCTAssertTrue(f.navigated.isEmpty)
    }

    func testCancellationDuringCommentaryMetadataStopsBeforeNavigate() async throws {
        let f = CompoundIntentFixture()
        f.afterMetadata = { request in
            if request.action == "catalog.resolveWork" { withUnsafeCurrentTask { $0?.cancel() } }
        }
        let task = Task { try await f.open() }
        do { _ = try await task.value; XCTFail("Cancelled metadata navigated") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertTrue(f.navigated.isEmpty)
    }

    func testPrecancelledPairDoesNoMetadataOrNativeWork() async throws {
        let f = CompoundIntentFixture()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await f.open()
        }
        do { _ = try await task.value; XCTFail("Cancelled caller admitted") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertTrue(f.metadata.isEmpty); XCTAssertTrue(f.navigated.isEmpty)
    }

    func testOriginalCoreDeniesReadWithoutConsentDespiteValidMetadata() async throws {
        let f = CompoundIntentFixture(), core = try f.makeCore()
        let metadata = await core.execute(.init(action: "catalog.resolveWork",
            arguments: ["workRef": try .encoded(f.commentary)], expectedBackend: .otzaria), context: f.metadataContext)
        XCTAssertEqual(metadata.status, .completed)
        let read = await core.execute(.init(action: "search.query", arguments: ["text": .string("word")],
            expectedBackend: .otzaria), context: f.navigationContext)
        XCTAssertNotEqual(read.status, .completed); XCTAssertEqual(f.headlessSearchCalls, 0)
        let count = await f.makeJourney(core: core).countThenOpenResults(.init(backend: .otzaria, text: "word", scopeWorkRefs: [f.baseWork]))
        XCTAssertEqual(count.steps.first?.error?.code, "trusted_read_authority_unavailable")
        XCTAssertTrue(f.nativeRequests.isEmpty)
    }

    func testMissingAndExtraReceiptsNeverBecomeCompletion() async throws {
        let f = CompoundIntentFixture(); _ = try await f.open()
        try assertRefused(f, receipts: [])
        try assertRefused(f, receipts: Array(f.receipts.prefix(1)))
        try assertRefused(f, receipts: f.receipts + [f.receipts[1]])
    }

    func testSwappedOrReplayedReceiptCannotCompleteDifferentStep() async throws {
        let f = CompoundIntentFixture(); _ = try await f.open()
        try assertRefused(f, receipts: Array(f.receipts.reversed()))
        try assertRefused(f, receipts: [f.receipts[0], f.receipts[0]])
        try assertRefused(f, receipts: [f.receipts[1], f.receipts[1]])
    }

    func testWrongSceneOrSnapshotReceiptIsRejected() async throws {
        let f = CompoundIntentFixture(); _ = try await f.open()
        let original = f.receipts[1]
        try assertRefused(f, receipts: [f.receipts[0], f.copy(original, scene: UIStableID(rawValue: "other-scene")!)])
        try assertRefused(f, receipts: [f.receipts[0], f.copy(original, snapshot: .init(backend: .otzaria, generation: 8))])
    }

    func testReceiptRouteMustRetainOwnRequestBackendSceneAndRevision() async throws {
        let f = CompoundIntentFixture(); _ = try await f.open()
        let original = f.receipts[1], route = original.route
        let routes = [
            RouteSpec(requestId: UUID(), destination: route.destination, backend: route.backend,
                presentation: route.presentation, state: route.state, scene: route.scene, expectedBackendSnapshot: route.expectedBackendSnapshot),
            RouteSpec(requestId: route.requestId, destination: route.destination, backend: .sefaria,
                presentation: route.presentation, state: route.state, scene: route.scene, expectedBackendSnapshot: route.expectedBackendSnapshot),
            RouteSpec(requestId: route.requestId, destination: route.destination, backend: route.backend,
                presentation: route.presentation, state: route.state, scene: .init(kind: .specific, sceneID: .init(rawValue: "other-scene")),
                expectedBackendSnapshot: route.expectedBackendSnapshot),
            RouteSpec(requestId: route.requestId, destination: route.destination, backend: route.backend,
                presentation: route.presentation, state: route.state, scene: route.scene,
                expectedBackendSnapshot: .init(backend: .otzaria, generation: 8))
        ]
        for changed in routes { try assertRefused(f, receipts: [f.receipts[0], f.copy(original, route: changed)]) }
        try assertRefused(f, receipts: [f.receipts[0], f.copy(original, applied: original.basedOnSceneRevision)])
    }

    func testWrongNativeDestinationOrWorkspaceCannotBeRelabelledAsNote() async throws {
        let f = CompoundIntentFixture(); _ = try await f.open()
        let original = f.receipts[1], route = original.route
        for changed in [
            RouteSpec(requestId: route.requestId, destination: .init(rawValue: "native.search.results")!,
                backend: route.backend, presentation: route.presentation, state: route.state,
                scene: route.scene, expectedBackendSnapshot: route.expectedBackendSnapshot),
            RouteSpec(requestId: route.requestId, destination: route.destination,
                backend: route.backend, presentation: route.presentation,
                state: .init(workspaceID: .init(rawValue: "other-workspace")),
                scene: route.scene, expectedBackendSnapshot: route.expectedBackendSnapshot)
        ] {
            try assertRefused(f, receipts: [f.receipts[0], f.copy(original, route: changed)])
        }
    }

    func testReaderCannotChangeTheExplicitCommentaryWork() async throws {
        let f = CompoundIntentFixture(); _ = try await f.open()
        let request = try XCTUnwrap(f.navigated.last)
        let wrong = NativeReaderIntentService.OpenRequest(locator: request.locator, expectedSnapshot: request.expectedSnapshot,
            windowIdentifier: request.windowIdentifier, newTab: true,
            commentaryDraft: .init(workRef: .init(backend: .otzaria, workKey: "book:3"), proposedText: "proposal"))
        XCTAssertThrowsError(try NativeReaderIntentService.commentaryDraftAcknowledgement(
            XCTUnwrap(f.journey), receipts: f.receipts, request: wrong))
    }

    func testMissingSelectionRetainsCompletedReaderAndRefusesDraft() async throws {
        let f = CompoundIntentFixture(); f.notesAvailable = false
        do { _ = try await f.open(); XCTFail("Missing selection manufactured a note") }
        catch let error as NativeReaderIntentService.CommentaryDraftFailure {
            XCTAssertEqual(error.journey.steps.map(\.status), [.completed, .unavailable])
            XCTAssertEqual(error.code, "exact_note_selection_unavailable")
            XCTAssertEqual(error.receipts.count, 1)
        }
        XCTAssertEqual(f.readerCalls, 1); XCTAssertEqual(f.noteCalls, 0)
    }

    func testSourceABAAfterReaderStopsBeforeDraftAndRetainsFirstEffect() async throws {
        let f = CompoundIntentFixture()
        f.afterNative = { if $0 == "reader.openCommentary" { f.sourceRevision += 2 } }
        do { _ = try await f.open(); XCTFail("Stale source continued to note") }
        catch let error as NativeReaderIntentService.CommentaryDraftFailure {
            XCTAssertEqual(error.journey.steps[0].status, .completed)
            XCTAssertEqual(error.journey.steps[1].status, .staleState)
            XCTAssertEqual(error.receipts.count, 1)
        }
        XCTAssertEqual(f.readerCalls, 1); XCTAssertEqual(f.noteCalls, 0)
    }

    func testOriginalCoreFinalNoteVisibilityRefusalRemainsUncertain() async throws {
        let f = CompoundIntentFixture(); f.noteVisible = false
        do { _ = try await f.open(); XCTFail("Hidden note became completed") }
        catch let error as NativeReaderIntentService.CommentaryDraftFailure {
            XCTAssertEqual(error.journey.steps[0].status, .completed)
            XCTAssertEqual(error.code, "native_effect_uncertain")
            XCTAssertEqual(error.journey.steps[1].error?.retryable, false)
            XCTAssertEqual(error.receipts.count, 1)
        }
        XCTAssertEqual(f.readerCalls, 1); XCTAssertEqual(f.noteCalls, 1)
    }

    func testOriginalCoreRejectsSavedNoteReceiptWithoutClaimingSuccess() async throws {
        let f = CompoundIntentFixture(); f.savedNote = true
        do { _ = try await f.open(); XCTFail("Saved note substituted for draft") }
        catch let error as NativeReaderIntentService.CommentaryDraftFailure {
            XCTAssertEqual(error.code, "native_effect_uncertain"); XCTAssertFalse(error.journey.isComplete)
        }
        XCTAssertEqual(f.readerCalls, 1); XCTAssertEqual(f.noteCalls, 1)
    }


    func testCompletedMetadataAloneDoesNotClaimACommentaryWasOpened() async throws {
        let f = CompoundIntentFixture(), core = try f.makeCore()
        let result = await f.makeJourney(core: core).resolveCommentaryThenPrepareDraft(
            backend: .otzaria, baseWorkQuery: "Base", section: "missing",
            commentaryQuery: "Commentary", proposedText: "proposal")
        XCTAssertEqual(result.steps.map(\.action), ["catalog.resolveWork", "catalog.resolveReference"])
        XCTAssertEqual(result.steps.first?.status, .completed); XCTAssertEqual(f.readerCalls, 0)
        let request = NativeReaderIntentService.OpenRequest(locator: f.base, expectedSnapshot: f.current,
            windowIdentifier: "selected-window", newTab: true,
            commentaryDraft: .init(workRef: f.commentary, proposedText: "proposal"))
        do {
            _ = try NativeReaderIntentService.commentaryDraftAcknowledgement(result, receipts: [], request: request)
            XCTFail("Unexpected journey plan accepted")
        } catch let error as NativeReaderIntentService.CommentaryDraftFailure {
            XCTAssertFalse(error.errorDescription?.contains("The commentary opened") == true)
            XCTAssertEqual(error.journey, result); XCTAssertTrue(error.receipts.isEmpty)
        }
    }

    private func assertRefused(_ f: CompoundIntentFixture, receipts: [UISceneReceipt],
        file: StaticString = #filePath, line: UInt = #line) throws {
        let journey = try XCTUnwrap(f.journey), request = try XCTUnwrap(f.navigated.last)
        XCTAssertThrowsError(try NativeReaderIntentService.commentaryDraftAcknowledgement(journey, receipts: receipts, request: request),
            file: file, line: line) { error in
                guard let failure = error as? NativeReaderIntentService.CommentaryDraftFailure else {
                    return XCTFail("Typed partial result lost", file: file, line: line)
                }
                XCTAssertEqual(failure.code, "native_effect_uncertain", file: file, line: line)
                XCTAssertEqual(failure.journey, journey, file: file, line: line)
                XCTAssertEqual(failure.receipts, receipts, file: file, line: line)
            }
    }
}

@MainActor private final class CompoundIntentFixture: ActionSynchronousBackendStatePort,
    ActionResolverDataPort, ActionCommentaryDataPort, ActionSearchPort, ActionNavigationAuthority,
    ActionCommentaryUICommandSink, ActionNoteDraftUICommandSink {
    let baseWork = ActionWorkRef(backend: .otzaria, workKey: "book:1")
    let commentary = ActionWorkRef(backend: .otzaria, workKey: "book:2")
    let base = ActionTextRef(backend: .otzaria, workKey: "book:1", position: .legacyLine(12))
    let section = ActionTextRef(backend: .otzaria, workKey: "book:2", position: .legacyLine(20))
    let focus = ActionTextRef(backend: .otzaria, workKey: "book:2", position: .legacyLine(21))
    var resolvedBase: ActionTextRef?
    var current = ActionBackendSnapshot(backend: .otzaria, generation: 7)
    let navigationContext = ActionExecutionContext(subjectID: "fixture-intent-window", origin: .appIntent,
        allowedBackends: [.otzaria], scopes: [.navigation, .discovery], foregroundSceneID: "fixture-scene")
    let metadataContext = ActionExecutionContext(subjectID: "fixture-intent-metadata", origin: .appIntent,
        allowedBackends: [.otzaria], scopes: [.discovery])
    let scene = UIStableID(rawValue: "fixture-scene")!
    let lifetime = UUID()
    var sourceRevision: UInt64 = 1
    var metadata: [ActionRequest] = [], nativeRequests: [ActionRequest] = []
    var navigated: [NativeReaderIntentService.OpenRequest] = []
    var receipts: [UISceneReceipt] = [], nativeReceipts: [UUID: UISceneReceipt] = [:]
    var journey: ActionSemanticJourneyResult?
    var afterMetadata: (@MainActor (ActionRequest) -> Void)?
    var afterNative: (@MainActor (String) -> Void)?
    var removeCommentaryOnSecondMetadata = false, commentaryPresent = true
    var notesAvailable = true, noteVisible = true, savedNote = false
    var preparedReader: ActionReaderDestination?, selected: ActionTextRef?
    var preparedDraft: ActionNoteDraftRequest?, displayedDraft: ActionNoteDraftRequest?
    var readerCalls = 0, noteCalls = 0, headlessSearchCalls = 0

    func identifiers() throws -> (base: String, location: String, commentary: String) {
        (try NativeReaderIntentService.Work(reference: baseWork, title: "Base").id,
         try NativeReaderIntentService.Location(reference: base, title: "Passage").id,
         try NativeReaderIntentService.Work(reference: commentary, title: "Commentary").id)
    }
    func open(proposal: String = "proposal") async throws -> UISceneAcknowledgement {
        let service = try service(), ids = try identifiers()
        return try await service.open(workIdentifier: ids.base, locationIdentifier: ids.location,
            windowIdentifier: "selected-window", newTab: true,
            commentaryWorkIdentifier: ids.commentary, proposedText: proposal)
    }
    func service() throws -> NativeReaderIntentService {
        let core = try makeCore()
        return .init(execute: { [self] request in
            metadata.append(request)
            if removeCommentaryOnSecondMetadata, metadata.count == 2 { commentaryPresent = false }
            let snapshot = current
            let pinned = ActionRequest(requestId: request.requestId, action: request.action, arguments: request.arguments,
                expectedBackend: snapshot.backend, expectedGeneration: snapshot.generation, requestedPresentation: .headless)
            let result = await core.execute(pinned, context: metadataContext)
            afterMetadata?(request)
            return .init(result: result, snapshot: snapshot)
        }, navigate: { [self] request in
            navigated.append(request)
            guard let draft = request.commentaryDraft else { return .queued(handle: "original-navigation-double") }
            let result = await makeJourney(core: core).commentaryThenPrepareDraft(
                baseLocator: request.locator, workRef: draft.workRef, proposedText: draft.proposedText)
            journey = result
            return try NativeReaderIntentService.commentaryDraftAcknowledgement(result, receipts: receipts, request: request)
        })
    }
    func makeCore() throws -> ActionExecutor {
        try .init(state: self, resolver: CatalogActionResolver(data: self, state: self),
            search: self, ui: self, navigationAuthority: self)
    }
    func makeJourney(core: ActionExecutor) -> ActionSemanticJourneys {
        let revision = sourceRevision, snapshot = current
        return .init(core: core, navigationAuthority: { [self] in
            guard sourceRevision == revision, current == snapshot else { throw ActionPortError.staleState }
            return .init(context: navigationContext, snapshot: current)
        }) { [self] request, authority in
            nativeRequests.append(request)
            let result = await core.execute(request, context: authority.context)
            if result.status == .completed, let receipt = nativeReceipts[request.requestId] { receipts.append(receipt) }
            afterNative?(request.action)
            return result
        }
    }
    func snapshot() async throws -> ActionBackendSnapshot { current }
    func currentBackendSnapshot() throws -> ActionBackendSnapshot { current }
    func report(for backend: ActionBackendID) async throws -> ActionBackendReport {
        .init(id: backend, operations: Dictionary(uniqueKeysWithValues: ActionRegistry.implemented.map {
            ($0, .init(registered: true, supported: true, availableNow: true))
        }))
    }
    func assess(action: String, arguments: ActionObject, invocation: ActionPortInvocation) async throws -> ActionCapabilityAssessment {
        .init(registered: true, supported: true, availableNow: true)
    }
    func catalog(for backend: ActionBackendID, invocation: ActionPortInvocation) async throws -> [ActionCatalogEntry] {
        var result = [ActionCatalogEntry(workRef: baseWork, title: "Base", provenance: "explicit-test-catalog")]
        if commentaryPresent { result.append(.init(workRef: commentary, title: "Commentary", kind: .commentary, provenance: "explicit-test-catalog")) }
        return result
    }
    func referenceCandidates(_ query: ActionResolveReferenceQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionTextRef> {
        guard query.workRef == baseWork, query.section == "12" else { return .notFound }
        return .unique(resolvedBase ?? base)
    }
    func validate(_ ref: ActionTextRef, invocation: ActionPortInvocation) async throws -> ActionTextRef {
        guard [resolvedBase ?? base, section, focus].contains(ref) else { throw ActionPortError.notFound }; return ref
    }
    func commentaryLinks(for baseLocator: ActionTextRef, invocation: ActionPortInvocation) async throws -> [ActionCommentaryLink] {
        [.init(baseLocator: base, destination: .init(sectionLocator: section, focusLocator: focus), title: "Commentary")]
    }
    func search(_ query: ActionSearchQuery, invocation: ActionPortInvocation) async throws -> ActionSearchPage {
        headlessSearchCalls += 1; return .init(hits: [], total: 0, precision: .exact)
    }
    func navigationState(sceneID: String) throws -> ActionNavigationState {
        .init(context: navigationContext, sceneID: scene.rawValue, lifetimeID: lifetime, authorityRevision: 1, active: true)
    }
    func prepareCommentaryReader(_ destination: ActionReaderDestination, context: ActionExecutionContext,
        invocation: ActionPortInvocation) async throws { preparedReader = destination }
    func open(_ command: ActionOpenReaderCommand) async throws -> ActionUIAcknowledgement {
        guard preparedReader == command.destination, let grant = command.navigationAuthorization else { throw ActionPortError.invalidResponse }
        try grant.authorizeCommit(invocation: command.invocation, sceneID: command.sceneID, destination: command.destination)
        readerCalls += 1; selected = command.destination.focusLocator
        let coreReceipt = ActionUIReceipt(requestId: command.invocation.requestId, snapshot: command.invocation.snapshot,
            sceneID: command.sceneID, destination: command.destination)
        nativeReceipts[command.invocation.requestId] = receipt(command.invocation, destination: "native.reader",
            presentation: .newTab, content: command.destination, coreReceipt: coreReceipt)
        return .acknowledged(coreReceipt)
    }
    func canPrepareNoteDraft(in sceneID: String) -> Bool { notesAvailable && selected != nil && sceneID == scene.rawValue }
    func prepareNoteDraft(_ draft: ActionNoteDraftRequest, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws {
        guard let selected else { throw ActionPortError.unavailable }
        _ = try ActionNoteDraftSelection.validate(draft, observedLocator: selected,
            sourceText: "before chosen after", originalRange: NSRange(location: 7, length: 6))
        preparedDraft = draft
    }
    func presentNoteDraft(_ command: ActionPrepareNoteDraftCommand) async throws -> ActionNoteDraftAcknowledgement {
        guard preparedDraft == command.draft, let grant = command.navigationAuthorization else { throw ActionPortError.invalidResponse }
        try grant.authorizeCommit(invocation: command.invocation, sceneID: command.sceneID, noteDraft: command.draft)
        noteCalls += 1; displayedDraft = command.draft
        nativeReceipts[command.invocation.requestId] = receipt(command.invocation,
            destination: "native.reader.noteDraft", presentation: .sheet)
        return .acknowledged(.init(requestId: command.invocation.requestId, snapshot: command.invocation.snapshot,
            sceneID: command.sceneID, draft: command.draft, isUnsaved: !savedNote))
    }
    func validateNoteDraftCompletion(_ receipt: ActionNoteDraftReceipt, invocation: ActionPortInvocation) throws {
        guard noteVisible, displayedDraft == receipt.draft else { throw ActionPortError.staleState }
    }
    func receipt(_ invocation: ActionPortInvocation, destination: String, presentation: PresentationSpec.Kind,
        content: ActionReaderDestination? = nil, coreReceipt: ActionUIReceipt? = nil) -> UISceneReceipt {
        let route = RouteSpec(requestId: invocation.requestId, destination: .init(rawValue: destination)!,
            backend: invocation.snapshot.backend, content: content, presentation: .init(kind: presentation),
            state: .init(workspaceID: .init(rawValue: "fixture-workspace"), profileID: .init(rawValue: "fixture-profile")),
            scene: .init(kind: .specific, sceneID: scene), expectedBackendSnapshot: invocation.snapshot)
        return .init(requestId: invocation.requestId, route: route, backendSnapshot: invocation.snapshot,
            sceneID: scene, basedOnSceneRevision: UInt64(readerCalls + noteCalls), appliedSceneRevision: UInt64(readerCalls + noteCalls + 1),
            coreReceipt: coreReceipt)
    }
    func copy(_ original: UISceneReceipt, scene: UIStableID? = nil, snapshot: ActionBackendSnapshot? = nil,
        route: RouteSpec? = nil, applied: UInt64? = nil) -> UISceneReceipt {
        .init(requestId: original.requestId, route: route ?? original.route, backendSnapshot: snapshot ?? original.backendSnapshot,
            sceneID: scene ?? original.sceneID, basedOnSceneRevision: original.basedOnSceneRevision,
            appliedSceneRevision: applied ?? original.appliedSceneRevision, coreReceipt: original.coreReceipt)
    }
}
