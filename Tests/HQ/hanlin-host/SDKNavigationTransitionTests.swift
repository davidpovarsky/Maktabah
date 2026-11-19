import Foundation
import XCTest
import HanlinAgentCore
import HanlinHostContracts
import HanlinPlatformContracts

/// Explicit navigation authority double. No application/UI/model provider runs here.
private actor NavigationTransitionHost: HanlinHostIntegration {
    nonisolated let apiVersion = HanlinAPIVersion(major: 1, minor: 0)
    enum Mode: Sendable { case stable, queued, generation, object, namespace, replyNewContext }
    private var current: HanlinHostContext
    private let mode: Mode
    private(set) var openCount = 0
    init(context: HanlinHostContext, mode: Mode) { current = context; self.mode = mode }
    func context(for session: HanlinHostSession) -> HanlinHostContext { current }
    func replaceContext(_ context: HanlinHostContext) { current = context }
    func catalog(for context: HanlinHostContext) throws -> HanlinHostCatalog {
        guard current == context else { throw HanlinHostError.staleContext }
        return .init(revision: .init(1), context: context, tools: [])
    }
    func execute(_ invocation: HanlinHostInvocation,
                 progress: @escaping HanlinHostProgressHandler) throws -> HanlinHostExecutionResult {
        throw HanlinHostError.unknownTool
    }
    func cancel(_ invocation: HanlinToolInvocationID) {}
    func open(_ destination: HanlinHostDestination) throws -> HanlinHostNavigationResult {
        guard current == destination.context else { throw HanlinHostError.staleContext }
        openCount += 1
        if mode == .queued { return .queued(requestID: destination.requestID, context: current) }
        if mode != .stable {
            let namespace = mode == .namespace
                ? try HanlinConversationNamespace(app: current.namespace.app, account: "changed-account",
                    workspace: current.namespace.workspace, space: current.namespace.space)
                : current.namespace
            current = .init(namespace: namespace, sceneID: current.sceneID,
                generation: mode == .object || mode == .namespace ? current.generation : UUID(),
                objectReference: mode == .object ? "new-original-reader" : current.objectReference,
                selectionReferences: current.selectionReferences, sourceRevision: current.sourceRevision,
                localeIdentifier: current.localeIdentifier)
        }
        return .presented(requestID: destination.requestID,
            context: mode == .replyNewContext ? current : destination.context,
            objectReference: destination.objectReference, blockReference: destination.blockReference)
    }
}

@MainActor
final class SDKNavigationTransitionTests: XCTestCase {
    private func fixture(_ mode: NavigationTransitionHost.Mode = .stable) throws
        -> (NavigationTransitionHost, HanlinHostDispatcher, HanlinHostSession, HanlinHostDestination) {
        let namespace = try HanlinConversationNamespace(app: "otzaria-fixture", account: "local-fixture",
            workspace: "original-workspace", space: "original-profile")
        let context = HanlinHostContext(namespace: namespace, sceneID: UUID(), generation: UUID(),
            objectReference: "original-reader", sourceRevision: "original-workspace-epoch")
        let session = HanlinHostSession(conversationID: UUID(), context: context)
        let host = NavigationTransitionHost(context: context, mode: mode)
        return (host, HanlinHostDispatcher(host: host), session,
            HanlinHostDestination(context: context, objectReference: "requested-reader", blockReference: "requested-segment"))
    }
    private func rejects(_ expected: HanlinHostError, _ body: @MainActor () async throws -> Void,
                         file: StaticString = #filePath, line: UInt = #line) async {
        do { try await body(); XCTFail("Expected \(expected)", file: file, line: line) }
        catch { XCTAssertEqual(error as? HanlinHostError, expected, file: file, line: line) }
    }
    func testStableContextPreservesExactPresentedAcknowledgement() async throws {
        let (host, dispatcher, session, target) = try fixture()
        let result = try await dispatcher.open(target, session: session)
        XCTAssertTrue(result.presentationAcknowledged)
        XCTAssertNoThrow(try result.validate(for: target))
        let effects = await host.openCount
        XCTAssertEqual(effects, 1)
    }
    func testQueuedIsNotPresentationAcknowledgement() async throws {
        let (host, dispatcher, session, target) = try fixture(.queued)
        let result = try await dispatcher.open(target, session: session)
        XCTAssertFalse(result.presentationAcknowledged)
        let effects = await host.openCount
        XCTAssertEqual(effects, 1)
    }
    func testGenerationTransitionDropsAcknowledgementAfterNavigationEffect() async throws {
        let (host, dispatcher, session, target) = try fixture(.generation)
        await rejects(.staleContext) { _ = try await dispatcher.open(target, session: session) }
        let effects = await host.openCount
        XCTAssertEqual(effects, 1, "The original dispatcher rejects only after the host's navigation effect")
        let current = await host.context(for: session)
        XCTAssertNotEqual(current.generation, session.context.generation)
    }
    func testObjectTransitionDropsAcknowledgementAfterNavigationEffect() async throws {
        let (host, dispatcher, session, target) = try fixture(.object)
        await rejects(.staleContext) { _ = try await dispatcher.open(target, session: session) }
        let effects = await host.openCount
        XCTAssertEqual(effects, 1)
    }
    func testAccountTransitionMustRemainRejected() async throws {
        let (host, dispatcher, session, target) = try fixture(.namespace)
        await rejects(.staleContext) { _ = try await dispatcher.open(target, session: session) }
        let effects = await host.openCount
        XCTAssertEqual(effects, 1)
    }
    func testReplyCannotSubstituteNewContextToBypassGuard() async throws {
        let (host, dispatcher, session, target) = try fixture(.replyNewContext)
        await rejects(.resultMismatch) { _ = try await dispatcher.open(target, session: session) }
        let effects = await host.openCount
        XCTAssertEqual(effects, 1)
    }
    func testAlreadyStaleContextNeverNavigates() async throws {
        let (host, dispatcher, session, target) = try fixture()
        await host.replaceContext(.init(namespace: session.context.namespace,
            sceneID: session.context.sceneID, generation: UUID()))
        await rejects(.staleContext) { _ = try await dispatcher.open(target, session: session) }
        let effects = await host.openCount
        XCTAssertEqual(effects, 0)
    }
    func testRevokedSessionNeverNavigates() async throws {
        let (host, dispatcher, session, target) = try fixture()
        await dispatcher.invalidate(session)
        await rejects(.staleContext) { _ = try await dispatcher.open(target, session: session) }
        let effects = await host.openCount
        XCTAssertEqual(effects, 0)
    }
}
