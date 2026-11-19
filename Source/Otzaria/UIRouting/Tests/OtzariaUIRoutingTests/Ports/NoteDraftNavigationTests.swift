import Foundation
import XCTest
import OtzariaActionCore
@testable import OtzariaUIRouting

// Exercises actual Core-issued purposes and Registry wrappers. Host/UI state is
// deliberately synthetic; these tests do not establish Native editor visibility.
@MainActor private final class NotePurposeSink: ActionNoteDraftUICommandSink {
    let host: NavigationAuthorityFixture
    var prepared: ActionNoteDraftRequest?
    var lastCommand: ActionPrepareNoteDraftCommand?
    var onPresent: (@MainActor (ActionPrepareNoteDraftCommand) throws -> Void)?
    var sourceVisible = true
    var finalObservations = 0
    init(_ host: NavigationAuthorityFixture) { self.host = host }
    func canPrepareNoteDraft(in sceneID: String) -> Bool { sourceVisible && sceneID == host.sceneID }
    func prepareNoteDraft(_ draft: ActionNoteDraftRequest, context: ActionExecutionContext,
                          invocation: ActionPortInvocation) async throws { prepared = draft }
    func presentNoteDraft(_ command: ActionPrepareNoteDraftCommand) async throws -> ActionNoteDraftAcknowledgement {
        guard command.draft == prepared else { throw ActionPortError.invalidResponse }
        lastCommand = command
        if let onPresent { try onPresent(command) }
        else {
            try command.navigationAuthorization!.authorizeCommit(invocation: command.invocation, sceneID: command.sceneID, noteDraft: command.draft)
            host.effects += 1
        }
        return .acknowledged(.init(requestId: command.invocation.requestId, snapshot: command.invocation.snapshot,
            sceneID: command.sceneID, draft: command.draft, isUnsaved: true))
    }
    func validateNoteDraftCompletion(_ receipt: ActionNoteDraftReceipt, invocation: ActionPortInvocation) throws {
        finalObservations += 1
        guard sourceVisible, receipt.draft == prepared else { throw ActionPortError.staleState }
    }
    func open(_ command: ActionOpenReaderCommand) async throws -> ActionUIAcknowledgement { throw ActionPortError.notSupported }
}

@MainActor final class NoteDraftNavigationTests: XCTestCase, @unchecked Sendable {
    private func fixture(_ backend: ActionBackendID = .otzaria) throws -> (NavigationAuthorityFixture, NotePurposeSink, ActionExecutor) {
        let ctx = ActionExecutionContext(subjectID: "notes-native-fixture", origin: .inApp, allowedBackends: [backend],
            contentRights: [], scopes: [.discovery, .navigation], allowedWorkKeys: [backend: ["fixture:work"]], foregroundSceneID: "native-scene")
        let host = NavigationAuthorityFixture(context: ctx, backend: backend), sink = NotePurposeSink(host)
        return (host, sink, try ActionExecutor(state: host, resolver: host, search: host, ui: sink, navigationAuthority: host))
    }
    private func draft(_ backend: ActionBackendID) -> ActionNoteDraftRequest {
        .init(locator: .init(backend: backend, workKey: "fixture:work",
            position: backend == .otzaria ? .legacyLine(42) : .canonicalRef("Fixture 1:1")),
            selectedText: "exact selection", proposedText: "e\u{301}")
    }
    private func request(_ backend: ActionBackendID) throws -> ActionRequest {
        let value = draft(backend)
        return .init(action: "notes.prepareDraft", arguments: ["locator": try .encoded(value.locator),
            "selectedText": .string(value.selectedText!), "proposedText": .string(value.proposedText!)],
            expectedBackend: backend, requestedPresentation: .foreground)
    }
    private func command(_ host: NavigationAuthorityFixture, invocation: ActionPortInvocation,
                         actions: [String] = ["notes.prepareDraft"], presentation: PresentationSpec.Kind = .sheet) throws -> UISceneCommand {
        let descriptor = UIDestinationDescriptor(id: .init(rawValue: "native.reader.noteDraft")!, title: "Original note",
            implementation: .implemented, supportedBackends: [host.backend.backend], presentations: [.sheet, .currentTab],
            requiredCoreActions: actions)
        let registry = try UIDestinationRegistry(descriptors: [descriptor])
        let route = RouteSpec(requestId: invocation.requestId, destination: descriptor.id, backend: host.backend.backend,
            presentation: .init(kind: presentation),
            scene: .init(kind: .specific, sceneID: host.scene.sceneID, expectedRevision: host.sceneRevision),
            expectedBackendSnapshot: host.backend)
        return try .init(route: registry.validate(route), invocation: invocation, scene: host.scene)
    }
    func testExactCoreNoteGrantUsesCanonicalSceneWrapperAndCannotRepeat() async throws {
        for backend in ActionBackendID.allCases {
            let (host, sink, core) = try fixture(backend)
            sink.onPresent = { note in
                let scene = try self.command(host, invocation: note.invocation)
                let prepared = try scene.prepareNavigation(noteDraftCommand: note)
                try prepared.authorizeCommit(current: host.scene)
                host.effects += 1
                let receipt = UISceneReceipt(requestId: note.invocation.requestId, route: scene.route.route,
                    backendSnapshot: host.backend, sceneID: host.scene.sceneID, basedOnSceneRevision: host.sceneRevision,
                    appliedSceneRevision: host.sceneRevision + 1)
                let observed = UISceneSnapshot(sceneID: host.scene.sceneID, revision: host.sceneRevision + 1,
                    backendSnapshot: host.backend, visibleRoute: scene.route.route)
                try prepared.validateCompletion(receipt: receipt, observed: observed)
                XCTAssertThrowsError(try prepared.authorizeCommit(current: host.scene))
            }
            let result = await core.execute(try request(backend), context: host.context)
            XCTAssertEqual(result.status, .completed, String(describing: result.error))
            XCTAssertEqual(host.effects, 1); XCTAssertEqual(sink.finalObservations, 1)
        }
    }
    func testGenericSurfaceGrantCannotBeBorrowedForNoteEffect() async throws {
        let (host, _, core) = try fixture()
        let invocation = ActionPortInvocation(requestId: UUID(), snapshot: host.backend, deadlineUptimeNanoseconds: UInt64.max)
        let generic = try await core.prepareNavigation(sceneID: host.sceneID, invocation: invocation, context: host.context)
        let forged = ActionPrepareNoteDraftCommand(draft: draft(.otzaria), sceneID: host.sceneID,
            invocation: invocation, navigationAuthorization: generic)
        let scene = try command(host, invocation: invocation)
        let prepared = try scene.prepareNavigation(noteDraftCommand: forged)
        XCTAssertThrowsError(try prepared.authorizeCommit(current: host.scene)) {
            XCTAssertEqual(($0 as? ActionNavigationError)?.code, "navigation_command_mismatch")
        }
        XCTAssertEqual(host.effects, 0)
        // The mismatch was not a commit; the original surface purpose remains usable.
        try generic.authorizeCommit(invocation: invocation, sceneID: host.sceneID)
    }
    func testNoteGrantCannotBeUsedForGenericSurfaceOrReader() async throws {
        let (host, sink, core) = try fixture()
        sink.onPresent = { note in
            let grant = try XCTUnwrap(note.navigationAuthorization)
            XCTAssertThrowsError(try grant.authorizeCommit(invocation: note.invocation, sceneID: note.sceneID))
            XCTAssertThrowsError(try grant.authorizeCommit(invocation: note.invocation, sceneID: note.sceneID,
                destination: .init(sectionLocator: note.draft.locator)))
            try grant.authorizeCommit(invocation: note.invocation, sceneID: note.sceneID, noteDraft: note.draft)
            host.effects += 1
        }
        let result = await core.execute(try request(.otzaria), context: host.context)
        XCTAssertEqual(result.status, .completed); XCTAssertEqual(host.effects, 1)
    }
    func testProposalSelectionLocatorAndInvocationAreBoundToOneUseGrant() async throws {
        let (host, sink, core) = try fixture()
        sink.onPresent = { note in
            let grant = try XCTUnwrap(note.navigationAuthorization)
            let alternatives = [
                ActionNoteDraftRequest(locator: note.draft.locator, selectedText: note.draft.selectedText, proposedText: "é"),
                .init(locator: note.draft.locator, selectedText: "other", proposedText: note.draft.proposedText),
                .init(locator: .init(backend: .otzaria, workKey: "fixture:work", position: .legacyLine(43)),
                    selectedText: note.draft.selectedText, proposedText: note.draft.proposedText)
            ]
            for changed in alternatives {
                XCTAssertThrowsError(try grant.authorizeCommit(invocation: note.invocation, sceneID: note.sceneID, noteDraft: changed))
            }
            let foreign = ActionPortInvocation(requestId: UUID(), snapshot: note.invocation.snapshot,
                deadlineUptimeNanoseconds: note.invocation.deadlineUptimeNanoseconds)
            XCTAssertThrowsError(try grant.authorizeCommit(invocation: foreign, sceneID: note.sceneID, noteDraft: note.draft))
            XCTAssertThrowsError(try grant.authorizeCommit(invocation: note.invocation, sceneID: "other-scene", noteDraft: note.draft))
            try grant.authorizeCommit(invocation: note.invocation, sceneID: note.sceneID, noteDraft: note.draft)
            host.effects += 1
        }
        let result = await core.execute(try request(.otzaria), context: host.context)
        XCTAssertEqual(result.status, .completed); XCTAssertEqual(host.effects, 1)
    }
    func testSemanticDescriptorCannotUseGenericPreparation() async throws {
        let (host, _, core) = try fixture()
        let invocation = ActionPortInvocation(requestId: UUID(), snapshot: host.backend, deadlineUptimeNanoseconds: UInt64.max)
        do {
            _ = try await command(host, invocation: invocation).prepareNavigation(using: core, context: host.context)
            XCTFail("Semantic action obtained generic surface grant")
        } catch { XCTAssertEqual((error as? UIRouteError)?.code, "semantic_execution_required") }
    }
    func testTypedWrapperRejectsWrongDescriptorPresentationSceneOrInvocation() async throws {
        let (host, sink, core) = try fixture()
        sink.onPresent = { note in
            XCTAssertThrowsError(try self.command(host, invocation: note.invocation, actions: []).prepareNavigation(noteDraftCommand: note))
            XCTAssertThrowsError(try self.command(host, invocation: note.invocation, presentation: .currentTab).prepareNavigation(noteDraftCommand: note))
            let other = ActionPrepareNoteDraftCommand(draft: note.draft, sceneID: "other-scene",
                invocation: note.invocation, navigationAuthorization: note.navigationAuthorization)
            XCTAssertThrowsError(try self.command(host, invocation: note.invocation).prepareNavigation(noteDraftCommand: other))
            let noGrant = ActionPrepareNoteDraftCommand(draft: note.draft, sceneID: note.sceneID, invocation: note.invocation)
            XCTAssertThrowsError(try self.command(host, invocation: note.invocation).prepareNavigation(noteDraftCommand: noGrant))
            try note.navigationAuthorization!.authorizeCommit(invocation: note.invocation, sceneID: note.sceneID, noteDraft: note.draft)
            host.effects += 1
        }
        let result = await core.execute(try request(.otzaria), context: host.context)
        XCTAssertEqual(result.status, .completed); XCTAssertEqual(host.effects, 1)
    }
    func testUnconsumedNoteGrantCannotClaimCompletedEditor() async throws {
        let (host, sink, core) = try fixture()
        sink.onPresent = { _ in }
        let result = await core.execute(try request(.otzaria), context: host.context)
        XCTAssertEqual(result.status, .failed); XCTAssertEqual(result.error?.code, "native_effect_uncertain")
        XCTAssertEqual(host.effects, 0); XCTAssertEqual(sink.finalObservations, 0)
    }
    func testFinalBackendOrAuthorityCallbackCanRevokeOriginalEditorBeforeSuccess() async throws {
        for point in 0..<2 {
            let (host, sink, core) = try fixture()
            sink.onPresent = { note in
                try note.navigationAuthorization!.authorizeCommit(invocation: note.invocation, sceneID: note.sceneID, noteDraft: note.draft)
                host.effects += 1
                if point == 0 { host.onSynchronousBackendRead = { sink.sourceVisible = false } }
                else { host.onNavigationStateRead = { sink.sourceVisible = false } }
            }
            let result = await core.execute(try request(.otzaria), context: host.context)
            XCTAssertEqual(result.status, .staleState, "Final native/source observation must follow all authority callbacks")
            XCTAssertEqual(host.effects, 1); XCTAssertEqual(sink.finalObservations, 1)
            XCTAssertEqual(result.error?.code, "native_effect_uncertain"); XCTAssertEqual(result.error?.retryable, false)
        }
    }
    func testRevocationAfterPresentationCannotClaimSuccessOrRepeatEffect() async throws {
        for mode in 0..<3 {
            let (host, sink, core) = try fixture(.sefariaEmbedded)
            sink.onPresent = { note in
                try note.navigationAuthorization!.authorizeCommit(invocation: note.invocation, sceneID: note.sceneID, noteDraft: note.draft)
                host.effects += 1
                switch mode {
                case 0: host.active = false
                case 1: host.authorityRevision += 2
                default: host.backend = .init(backend: .sefariaEmbedded, generation: 1, rpcEpoch: 8)
                }
            }
            let result = await core.execute(try request(.sefariaEmbedded), context: host.context)
            XCTAssertNotEqual(result.status, .completed); XCTAssertEqual(host.effects, 1)
        }
    }
}
