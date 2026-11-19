import Foundation
import XCTest
import OtzariaActionCore
@testable import OtzariaUIRouting

// Contract fixtures, not an app engine, native UI or production-corpus result.
@MainActor private final class SearchSceneSource: ActionSynchronousBackendStatePort, ActionResolverPort, ActionSearchPort, ActionNavigationAuthority {
    var current = ActionBackendSnapshot(backend: .otzaria, generation: 3)
    var context = ActionExecutionContext(subjectID: "search-results-fixture", origin: .inApp,
        allowedBackends: [.otzaria], scopes: [.discovery, .navigation], foregroundSceneID: "scene")
    let lifetime = UUID()
    var revision: UInt64 = 1
    var active = true
    var afterSnapshot: (@MainActor () -> Void)?
    var resolvedWorks: Set<String> = ["book:1"]
    var searchCalls = 0
    func snapshot() async throws -> ActionBackendSnapshot {
        let operation = afterSnapshot; afterSnapshot = nil; operation?()
        return current
    }
    func currentBackendSnapshot() throws -> ActionBackendSnapshot { current }
    func navigationState(sceneID: String) throws -> ActionNavigationState {
        .init(context: context, sceneID: "scene", lifetimeID: lifetime, authorityRevision: revision, active: active)
    }
    func report(for backend: ActionBackendID) async throws -> ActionBackendReport {
        .init(id: backend, operations: ["search.openResults": .init(registered: true, supported: true, availableNow: true)])
    }
    func assess(action: String, arguments: ActionObject, invocation: ActionPortInvocation) async throws -> ActionCapabilityAssessment {
        .init(registered: true, supported: true, availableNow: true)
    }
    func resolveWork(_ query: ActionResolveWorkQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionWorkRef> {
        guard let ref = query.workRef, resolvedWorks.contains(ref.workKey) else { return .notFound }
        return .unique(ref)
    }
    func resolveReference(_ query: ActionResolveReferenceQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionTextRef> { .notFound }
    func validateDestination(_ destination: ActionReaderDestination, invocation: ActionPortInvocation) async throws -> ActionReaderDestination { destination }
    func search(_ query: ActionSearchQuery, invocation: ActionPortInvocation) async throws -> ActionSearchPage {
        searchCalls += 1; throw ActionPortError.notSupported
    }
}
@MainActor private final class SearchSceneUI: ActionSearchResultsUICommandSink {
    enum Mutation { case none, substituteQuery, wrongDestination, wrongScene }
    let source: SearchSceneSource
    let mutation: Mutation
    var effects = 0
    var prepared: ActionSearchResultsQuery?
    var wrapper: UIAuthorizedSceneCommand?
    init(_ source: SearchSceneSource, mutation: Mutation = .none) { self.source = source; self.mutation = mutation }
    func open(_ command: ActionOpenReaderCommand) async throws -> ActionUIAcknowledgement { throw ActionPortError.notSupported }
    func prepareSearchResults(_ query: ActionSearchResultsQuery, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws { prepared = query }
    func openSearchResults(_ search: ActionOpenSearchResultsCommand) async throws -> ActionSearchResultsAcknowledgement {
        let identifier = UIDestinationID(rawValue: mutation == .wrongDestination ? "native.history" : "native.search.results")!
        let descriptor = UIDestinationDescriptor(id: identifier, title: "Synthetic results", implementation: .implemented,
            supportedBackends: [.otzaria], presentations: [.currentTab],
            requiredCoreActions: mutation == .wrongDestination ? [] : ["search.openResults"])
        let registry = try UIDestinationRegistry(descriptors: [descriptor])
        let scene = UISceneSnapshot(sceneID: .init(rawValue: "scene")!, revision: 5, backendSnapshot: source.current)
        let route = RouteSpec(requestId: search.invocation.requestId, destination: identifier, backend: .otzaria,
            scene: .init(kind: .specific, sceneID: scene.sceneID, expectedRevision: 5), expectedBackendSnapshot: source.current)
        let command = try UISceneCommand(route: registry.validate(route), invocation: search.invocation, scene: scene)
        let delivered: ActionOpenSearchResultsCommand
        if mutation == .substituteQuery {
            delivered = .init(query: try .init(.init(backend: .otzaria, text: "different")), sceneID: search.sceneID,
                invocation: search.invocation, navigationAuthorization: search.navigationAuthorization)
        } else { delivered = search }
        let wrapper = try command.prepareNavigation(searchResultsCommand: delivered)
        let current = mutation == .wrongScene
            ? UISceneSnapshot(sceneID: .init(rawValue: "other-scene")!, revision: 5, backendSnapshot: source.current)
            : scene
        try wrapper.authorizeCommit(current: current)
        effects += 1; self.wrapper = wrapper
        // Synthetic observed scene only; no UIKit result is claimed.
        let receipt = UISceneReceipt(requestId: search.invocation.requestId, route: route, backendSnapshot: source.current,
            sceneID: scene.sceneID, basedOnSceneRevision: 5, appliedSceneRevision: 6)
        let observed = UISceneSnapshot(sceneID: scene.sceneID, revision: 6, backendSnapshot: source.current, visibleRoute: route)
        try wrapper.validateCompletion(receipt: receipt, observed: observed)
        return .acknowledged(.init(requestId: search.invocation.requestId, snapshot: source.current,
            sceneID: search.sceneID, query: search.query, submissionRevision: effects))
    }
    func validateSearchResultsCompletion(_ command: ActionOpenSearchResultsCommand, receipt: ActionSearchResultsReceipt) throws {
        guard effects == 1, wrapper != nil, prepared == command.query else { throw ActionPortError.invalidResponse }
    }
}
final class SearchResultsNavigationTests: XCTestCase, @unchecked Sendable {
    @MainActor private func execute(_ mutation: SearchSceneUI.Mutation) async throws -> (ActionResult, Int) {
        let source = SearchSceneSource(), ui = SearchSceneUI(source, mutation: mutation)
        let core = try ActionExecutor(state: source, resolver: source, search: source, ui: ui, navigationAuthority: source)
        let result = await core.execute(.init(action: "search.openResults",
            arguments: ["searchQuery": .object(["text": .string("בראשית")])], expectedBackend: .otzaria,
            requestedPresentation: .foreground), context: source.context)
        return (result, ui.effects)
    }
    @MainActor func testRealCoreSearchPreparationAuthorizesOnlyOriginalSceneCommand() async throws {
        let result = try await execute(.none)
        XCTAssertEqual(result.0.status, .completed); XCTAssertEqual(result.1, 1)
    }
    @MainActor func testSubstitutedQueryCannotBorrowOriginalCoreGrant() async throws {
        let result = try await execute(.substituteQuery)
        XCTAssertNotEqual(result.0.status, .completed); XCTAssertEqual(result.1, 0)
    }
    @MainActor func testDifferentDestinationCannotBorrowSearchGrant() async throws {
        let result = try await execute(.wrongDestination)
        XCTAssertNotEqual(result.0.status, .completed); XCTAssertEqual(result.1, 0)
    }
    @MainActor func testDifferentNativeSceneCannotCommitSearch() async throws {
        let result = try await execute(.wrongScene)
        XCTAssertNotEqual(result.0.status, .completed); XCTAssertEqual(result.1, 0)
    }
    @MainActor func testGenericNavigationCannotExecuteResultsSemanticDestination() async throws {
        let source = SearchSceneSource()
        let core = try ActionExecutor(state: source, resolver: source, search: source, navigationAuthority: source)
        let descriptor = UIDestinationDescriptor(id: .init(rawValue: "native.search.results")!, title: "Synthetic",
            implementation: .implemented, supportedBackends: [.otzaria], presentations: [.currentTab],
            requiredCoreActions: ["search.openResults"])
        let registry = try UIDestinationRegistry(descriptors: [descriptor])
        let scene = UISceneSnapshot(sceneID: .init(rawValue: "scene")!, revision: 1, backendSnapshot: source.current)
        let route = RouteSpec(destination: descriptor.id, backend: .otzaria,
            scene: .init(kind: .specific, sceneID: scene.sceneID, expectedRevision: 1), expectedBackendSnapshot: source.current)
        let command = try UISceneCommand(route: registry.validate(route), invocation: .init(requestId: route.requestId,
            snapshot: source.current, deadlineUptimeNanoseconds: UInt64.max), scene: scene)
        do { _ = try await command.prepareNavigation(using: core, context: source.context); XCTFail("Semantic action borrowed generic grant") }
        catch { XCTAssertEqual((error as? UIRouteError)?.code, "semantic_execution_required") }
    }
}
