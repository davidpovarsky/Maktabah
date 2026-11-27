import Foundation
import XCTest
@testable import OtzariaActionCore

// Contract fixtures, not an app engine, native UI or production-corpus result.
@MainActor private final class SearchResultsSource: ActionSynchronousBackendStatePort, ActionResolverPort, ActionSearchPort, ActionNavigationAuthority {
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
@MainActor private final class SearchResultsUI: ActionSearchResultsUICommandSink {
    let source: SearchResultsSource
    var prepared: ActionSearchResultsQuery?
    var displayed: ActionSearchResultsQuery?
    var commands = 0
    var wrongReceipt = false
    var changeAfterEffect = false
    var revokeBeforeCommit = false
    var available = true
    var nativeFailure: ActionNativeUIFailure?
    func canOpenSearchResults(in sceneID: String) -> Bool { available && sceneID == "scene" }
    init(_ source: SearchResultsSource) { self.source = source }
    func open(_ command: ActionOpenReaderCommand) async throws -> ActionUIAcknowledgement { throw ActionPortError.notSupported }
    func prepareSearchResults(_ query: ActionSearchResultsQuery, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws {
        prepared = query
    }
    func openSearchResults(_ command: ActionOpenSearchResultsCommand) async throws -> ActionSearchResultsAcknowledgement {
        if let nativeFailure { throw nativeFailure }
        guard prepared == command.query, let authorization = command.navigationAuthorization else { throw ActionPortError.invalidResponse }
        if revokeBeforeCommit { source.revision += 1 }
        try authorization.authorizeCommit(invocation: command.invocation, sceneID: command.sceneID, searchQuery: command.query)
        commands += 1; displayed = command.query
        if changeAfterEffect { source.afterSnapshot = { [weak self] in self?.displayed = nil } }
        return .acknowledged(.init(requestId: command.invocation.requestId, snapshot: command.invocation.snapshot,
            sceneID: command.sceneID, query: command.query, submissionRevision: wrongReceipt ? 0 : commands))
    }
    func validateSearchResultsCompletion(_ command: ActionOpenSearchResultsCommand, receipt: ActionSearchResultsReceipt) throws {
        guard displayed == command.query, receipt.submissionRevision == commands else { throw ActionPortError.staleState }
    }
}

final class SearchResultsActionTests: XCTestCase, @unchecked Sendable {
    private func arguments(_ fields: ActionObject = [:]) -> ActionObject {
        var query: ActionObject = ["text": .string("בראשית")]
        for (key, value) in fields { query[key] = value }
        return ["searchQuery": .object(query)]
    }
    @MainActor private func execute(_ fields: ActionObject = [:], source: SearchResultsSource, ui: SearchResultsUI?,
                                   headless: Bool = false) async throws -> ActionResult {
        let core = try ActionExecutor(state: source, resolver: source, search: source, ui: ui, navigationAuthority: source)
        return await core.execute(.init(action: "search.openResults", arguments: fields.isEmpty ? arguments() : fields,
            expectedBackend: .otzaria, requestedPresentation: headless ? .headless : .foreground), context: source.context)
    }
    func testStrictNestedArgumentsRejectIgnoredFieldsHandlesAndPaging() throws {
        for key in ["offset", "limit", "reverseSort", "unknown"] {
            XCTAssertThrowsError(try ActionSearchResultsQuery.arguments(arguments([key: .integer(0)]), backend: .otzaria))
        }
        XCTAssertThrowsError(try ActionSearchResultsQuery.arguments(["searchHandle": .string("unowned-handle")], backend: .otzaria))
        XCTAssertThrowsError(try ActionSearchResultsQuery.arguments(arguments(["searchMode": .string("invented")]), backend: .otzaria))
        XCTAssertThrowsError(try ActionSearchResultsQuery.arguments(arguments(["backend": .string("sefaria")]), backend: .otzaria))
    }
    func testByteExactQueryPurposeDoesNotNormalizeUnicode() throws {
        let a = try ActionSearchResultsQuery(.init(backend: .otzaria, text: "\u{00E9}"))
        let b = try ActionSearchResultsQuery(.init(backend: .otzaria, text: "e\u{0301}"))
        XCTAssertNotEqual(a, b)
    }
    func testOnlyRepresentableNativeModesAndScopeAreReported() throws {
        XCTAssertNil(ActionSearchResultsQuery.unsupportedReason(.init(backend: .otzaria, text: "אב", sortOrder: .canonical)))
        XCTAssertNotNil(ActionSearchResultsQuery.unsupportedReason(.init(backend: .sefaria, text: "אב", searchMode: .or)))
        XCTAssertNotNil(ActionSearchResultsQuery.unsupportedReason(.init(backend: .sefaria, text: "אב",
            scopeWorkRefs: [.init(backend: .sefaria, workKey: "Genesis")])))
        XCTAssertNotNil(ActionSearchResultsQuery.unsupportedReason(.init(backend: .sefariaEmbedded, text: "אב", sortOrder: .canonical)))
    }
    @MainActor func testCompleteUsesOriginalUISinkAndNeverSubstitutesHeadlessSearch() async throws {
        let source = SearchResultsSource(), ui = SearchResultsUI(SearchResultsSource())
        let actual = SearchResultsUI(source)
        let result = try await execute(source: source, ui: actual)
        XCTAssertEqual(result.status, .completed); XCTAssertEqual(result.effects, ["search_results_opened"])
        XCTAssertEqual(actual.commands, 1); XCTAssertEqual(source.searchCalls, 0); XCTAssertEqual(ui.commands, 0)
    }
    @MainActor func testUnknownScopeNeverReachesUI() async throws {
        let source = SearchResultsSource(), ui = SearchResultsUI(SearchResultsSource())
        let result = try await execute(arguments(["scopeWorkRefs": try .encoded([ActionWorkRef(backend: .otzaria, workKey: "book:404")])]), source: source, ui: ui)
        XCTAssertEqual(result.status, .failed); XCTAssertEqual(result.error?.code, "not_found"); XCTAssertEqual(ui.commands, 0)
    }
    @MainActor func testHeadlessCannotCommit() async throws {
        let source = SearchResultsSource(), ui = SearchResultsUI(source)
        let result = try await execute(source: source, ui: ui, headless: true)
        XCTAssertEqual(result.status, .requiresForeground); XCTAssertEqual(ui.commands, 0)
    }
    @MainActor func testRevokedPurposeNeverMutatesAndWrongReceiptNeverCompletes() async throws {
        let source = SearchResultsSource(), ui = SearchResultsUI(source)
        ui.revokeBeforeCommit = true
        let first = try await execute(source: source, ui: ui)
        XCTAssertNotEqual(first.status, .completed); XCTAssertEqual(ui.commands, 0)
        ui.revokeBeforeCommit = false; ui.wrongReceipt = true
        let second = try await execute(source: source, ui: ui)
        XCTAssertNotEqual(second.status, .completed); XCTAssertEqual(ui.commands, 1)
        XCTAssertEqual(second.error?.code, "native_effect_uncertain"); XCTAssertEqual(second.error?.retryable, false)
    }
    @MainActor func testActualResultsChangeAfterLastBackendAwaitRejectsSuccess() async throws {
        let source = SearchResultsSource(), ui = SearchResultsUI(source)
        ui.changeAfterEffect = true
        let result = try await execute(source: source, ui: ui)
        XCTAssertEqual(result.status, .staleState); XCTAssertEqual(ui.commands, 1)
        XCTAssertEqual(result.error?.code, "native_effect_uncertain"); XCTAssertEqual(result.error?.retryable, false)
    }
    @MainActor func testGenericAndDifferentQueryCannotBorrowSearchPreparation() throws {
        let source = SearchResultsSource()
        let query = try ActionSearchResultsQuery(.init(backend: .otzaria, text: "אב"))
        let invocation = ActionPortInvocation(requestId: UUID(), snapshot: source.current, deadlineUptimeNanoseconds: UInt64.max)
        let grant = try ActionNavigationPreparation(authority: source, backendAuthority: source, invocation: invocation,
            sceneID: "scene", context: source.context, destination: nil, clock: SystemActionClock(), searchQuery: query)
        XCTAssertThrowsError(try grant.authorizeCommit(invocation: invocation, sceneID: "scene"))
        XCTAssertThrowsError(try grant.authorizeCommit(invocation: invocation, sceneID: "scene",
            searchQuery: ActionSearchResultsQuery(.init(backend: .otzaria, text: "אחר"))))
        try grant.authorizeCommit(invocation: invocation, sceneID: "scene", searchQuery: query)
        XCTAssertThrowsError(try grant.authorizeCommit(invocation: invocation, sceneID: "scene", searchQuery: query))
    }
    @MainActor func testBlockedNativeSceneIsNotAdvertisedOrExecuted() async throws {
        let source = SearchResultsSource(), ui = SearchResultsUI(source)
        ui.available = false
        let core = try ActionExecutor(state: source, resolver: source, search: source, ui: ui, navigationAuthority: source)
        let blocked = await core.advertisedActions(for: .otzaria, context: source.context)
        XCTAssertFalse(blocked.contains { $0.id == "search.openResults" })
        let result = try await execute(source: source, ui: ui)
        XCTAssertEqual(result.status, .unavailable); XCTAssertEqual(result.error?.code, "native_search_results_unavailable")
        XCTAssertEqual(ui.commands, 0); XCTAssertNil(ui.prepared)
        ui.available = true
        let ready = await core.advertisedActions(for: .otzaria, context: source.context)
        XCTAssertTrue(ready.contains { $0.id == "search.openResults" })
    }
    @MainActor func testAbsentOptionalSearchPortIsUnsupported() async throws {
        let source = SearchResultsSource()
        let result = try await execute(source: source, ui: nil)
        XCTAssertEqual(result.status, .notSupported); XCTAssertEqual(result.error?.code, "native_search_results_unavailable")
        XCTAssertEqual(source.searchCalls, 0)
    }
    @MainActor func testNativeFailureSurvivesWithoutBecomingRetryableBackendFailure() async throws {
        let source = SearchResultsSource(), ui = SearchResultsUI(source)
        ui.nativeFailure = .init(status: .staleState,
            failure: .init(code: "native_effect_uncertain", message: "private provider text", retryable: true))
        let result = try await execute(source: source, ui: ui)
        XCTAssertEqual(result.status, .staleState); XCTAssertEqual(result.error?.code, "native_effect_uncertain")
        XCTAssertEqual(result.error?.retryable, false); XCTAssertFalse(result.error?.message.contains("private provider text") == true)
        XCTAssertEqual(ui.commands, 0)
    }
    @MainActor func testNoteAndSearchPurposesCannotBeCombinedOrSubstituted() throws {
        let source = SearchResultsSource()
        let query = try ActionSearchResultsQuery(.init(backend: .otzaria, text: "אב"))
        let note = ActionNoteDraftRequest(locator: .init(backend: .otzaria, workKey: "book:1", position: .legacyLine(1)))
        let invocation = ActionPortInvocation(requestId: UUID(), snapshot: source.current, deadlineUptimeNanoseconds: UInt64.max)
        XCTAssertThrowsError(try ActionNavigationPreparation(authority: source, backendAuthority: source, invocation: invocation,
            sceneID: "scene", context: source.context, destination: nil, clock: SystemActionClock(), noteDraft: note, searchQuery: query))
        let searchGrant = try ActionNavigationPreparation(authority: source, backendAuthority: source, invocation: invocation,
            sceneID: "scene", context: source.context, destination: nil, clock: SystemActionClock(), searchQuery: query)
        XCTAssertThrowsError(try searchGrant.authorizeCommit(invocation: invocation, sceneID: "scene", noteDraft: note))
        let noteGrant = try ActionNavigationPreparation(authority: source, backendAuthority: source, invocation: invocation,
            sceneID: "scene", context: source.context, destination: nil, clock: SystemActionClock(), noteDraft: note)
        XCTAssertThrowsError(try noteGrant.authorizeCommit(invocation: invocation, sceneID: "scene", searchQuery: query))
        try searchGrant.authorizeCommit(invocation: invocation, sceneID: "scene", searchQuery: query)
        try noteGrant.authorizeCommit(invocation: invocation, sceneID: "scene", noteDraft: note)
    }
    @MainActor func testAbsentUIIsNotAdvertised() async throws {
        let source = SearchResultsSource()
        let core = try ActionExecutor(state: source, resolver: source, search: source, navigationAuthority: source)
        let actions = await core.advertisedActions(for: .otzaria, context: source.context)
        XCTAssertFalse(actions.contains { $0.id == "search.openResults" })
    }
}
