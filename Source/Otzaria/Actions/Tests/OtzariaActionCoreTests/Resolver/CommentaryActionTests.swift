import Foundation
import XCTest
@testable import OtzariaActionCore

// Portable contract fixtures only. They are not production DB/RPC or Native evidence.
private struct CommentaryFixture: Sendable {
    let backend: ActionBackendID
    let base: ActionTextRef
    let work: ActionWorkRef
    let destination: ActionReaderDestination
    let entries: [ActionCatalogEntry]
    init(_ backend: ActionBackendID = .otzaria) {
        self.backend = backend
        let baseKey = backend == .otzaria ? "book:1" : "Deuteronomy"
        let linkedKey = backend == .otzaria ? "book:2" : "Kli Yakar on Deuteronomy"
        base = .init(backend: backend, workKey: baseKey,
            position: backend == .otzaria ? .legacyLine(12) : .canonicalRef(baseKey + " 1:1"))
        work = .init(backend: backend, workKey: linkedKey)
        let section = ActionTextRef(backend: backend, workKey: linkedKey,
            position: backend == .otzaria ? .legacyLine(20) : .canonicalRef(linkedKey + " 1"))
        let focus = ActionTextRef(backend: backend, workKey: linkedKey,
            position: backend == .otzaria ? .legacyLine(21) : .canonicalRef(linkedKey + " 1:1"))
        destination = .init(sectionLocator: section, focusLocator: focus)
        entries = [
            .init(workRef: .init(backend: backend, workKey: baseKey), title: "דברים", provenance: "fixture:catalog"),
            .init(workRef: work, title: "כלי יקר על דברים", aliases: ["Kli Yakar on Deuteronomy"], kind: .commentary, provenance: "fixture:catalog")
        ]
    }
    var link: ActionCommentaryLink {
        .init(baseLocator: base, destination: destination, title: "כלי יקר", aliases: ["Kli Yakar"])
    }
    var opened: ActionReaderDestination {
        .init(sectionLocator: destination.sectionLocator, focusLocator: destination.focusLocator, presentationMode: .newTab)
    }
}

private actor CommentarySource: ActionBackendStatePort, ActionResolverDataPort, ActionCommentaryDataPort, ActionSearchPort {
    let fixture: CommentaryFixture
    var current: ActionBackendSnapshot
    var links: [ActionCommentaryLink]
    var entries: [ActionCatalogEntry]
    var verified: Set<ActionTextRef>
    var substitute: ActionTextRef?
    var changeOnLinks = false
    var linksFailure: ActionPortError?
    var linkCalls = 0
    init(_ fixture: CommentaryFixture) {
        self.fixture = fixture
        current = .init(backend: fixture.backend, generation: 3, rpcEpoch: fixture.backend == .sefariaEmbedded ? 8 : nil)
        links = [fixture.link]; entries = fixture.entries
        verified = [fixture.base, fixture.destination.sectionLocator, fixture.destination.focusLocator!]
    }
    func setup(links: [ActionCommentaryLink]? = nil, verified: Set<ActionTextRef>? = nil,
               substitute: ActionTextRef? = nil, changeOnLinks: Bool = false, failure: ActionPortError? = nil) {
        if let links { self.links = links }; if let verified { self.verified = verified }
        self.substitute = substitute; self.changeOnLinks = changeOnLinks; linksFailure = failure
    }
    func bump() {
        current = .init(backend: current.backend,
            generation: current.backend == .sefariaEmbedded ? current.generation : current.generation + 1,
            rpcEpoch: current.rpcEpoch.map { $0 + 1 })
    }
    func invocation() -> ActionPortInvocation {
        .init(requestId: UUID(), snapshot: current, deadlineUptimeNanoseconds: UInt64.max)
    }
    func snapshot() async throws -> ActionBackendSnapshot { current }
    func report(for backend: ActionBackendID) async throws -> ActionBackendReport {
        .init(id: backend, operations: Dictionary(uniqueKeysWithValues: ActionRegistry.implemented.map {
            ($0, ActionCapabilityAssessment(registered: true, supported: true, availableNow: true))
        }))
    }
    func assess(action: String, arguments: ActionObject, invocation: ActionPortInvocation) async throws -> ActionCapabilityAssessment {
        .init(registered: true, supported: true, availableNow: true)
    }
    func catalog(for backend: ActionBackendID, invocation: ActionPortInvocation) async throws -> [ActionCatalogEntry] { entries }
    func referenceCandidates(_ query: ActionResolveReferenceQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionTextRef> { .notFound }
    func validate(_ ref: ActionTextRef, invocation: ActionPortInvocation) async throws -> ActionTextRef {
        if let substitute { return substitute }
        guard verified.contains(ref) else { throw ActionPortError.notFound }
        return ref
    }
    func commentaryLinks(for baseLocator: ActionTextRef, invocation: ActionPortInvocation) async throws -> [ActionCommentaryLink] {
        linkCalls += 1
        if changeOnLinks { bump() }
        if let linksFailure { throw linksFailure }
        return links
    }
    func search(_ query: ActionSearchQuery, invocation: ActionPortInvocation) async throws -> ActionSearchPage { throw ActionPortError.notSupported }
}

@MainActor private final class CommentaryUI: ActionCommentaryUICommandSink {
    let source: CommentarySource
    var prepared: ActionReaderDestination?
    var commands: [ActionOpenReaderCommand] = []
    var changeOnPrepare = false
    var wrongReceipt = false
    init(_ source: CommentarySource) { self.source = source }
    func prepareCommentaryReader(_ destination: ActionReaderDestination, context: ActionExecutionContext,
                                 invocation: ActionPortInvocation) async throws {
        prepared = destination
        if changeOnPrepare { await source.bump() }
    }
    func open(_ command: ActionOpenReaderCommand) async throws -> ActionUIAcknowledgement {
        guard prepared == command.destination else { throw ActionPortError.invalidResponse }
        commands.append(command)
        let target = wrongReceipt
            ? ActionReaderDestination(sectionLocator: command.destination.sectionLocator, presentationMode: .newTab)
            : command.destination
        return .acknowledged(.init(requestId: command.invocation.requestId, snapshot: command.invocation.snapshot,
            sceneID: command.sceneID, destination: target))
    }
}

final class CommentaryActionTests: XCTestCase, @unchecked Sendable {
    private func resolver(_ source: CommentarySource) -> CatalogActionResolver { .init(data: source, state: source) }
    private func query(_ f: CommentaryFixture, name: String? = "כלי יקר", selected: Bool = false) -> ActionResolveCommentaryQuery {
        .init(baseLocator: f.base, workRef: selected ? f.work : nil, commentaryQuery: name)
    }
    private func context(_ f: CommentaryFixture, works: Set<String>? = nil) -> ActionExecutionContext {
        .init(subjectID: "fixture-commentary", origin: .inApp, allowedBackends: [f.backend],
            scopes: [.discovery, .navigation], allowedWorkKeys: works.map { [f.backend: $0] }, foregroundSceneID: "fixture-scene")
    }
    private func request(_ f: CommentaryFixture, headless: Bool = false) throws -> ActionRequest {
        .init(action: "reader.openCommentary",
            arguments: ["baseLocator": try .encoded(f.base), "commentaryQuery": .string("כלי יקר")],
            expectedBackend: f.backend, requestedPresentation: headless ? .headless : .foreground)
    }
    private func expect(_ error: ActionPortError, _ operation: () async throws -> Void,
                        file: StaticString = #filePath, line: UInt = #line) async {
        do { try await operation(); XCTFail("Expected \(error)", file: file, line: line) }
        catch let actual { XCTAssertEqual(actual as? ActionPortError, error, file: file, line: line) }
    }

    func testExactLinkedSectionAndFocusAcrossAllSources() async throws {
        for backend in ActionBackendID.allCases {
            let f = CommentaryFixture(backend), source = CommentarySource(f)
            let r = try await resolver(source).resolveCommentary(query(f), invocation: source.invocation())
            XCTAssertEqual(r, .unique(f.destination))
        }
    }
    func testCatalogTitleCannotCreateMissingRelationship() async throws {
        let f = CommentaryFixture(), source = CommentarySource(f)
        await source.setup(links: [])
        let r = try await resolver(source).resolveCommentary(query(f, name: "כלי יקר על דברים"), invocation: source.invocation())
        XCTAssertEqual(r, .notFound)
    }
    func testExplicitWorkStillRequiresSourceLinkAndExactQuery() async throws {
        let f = CommentaryFixture(), source = CommentarySource(f)
        let r = try await resolver(source).resolveCommentary(query(f, name: "unknown", selected: true), invocation: source.invocation())
        XCTAssertEqual(r, .notFound)
        let selected = try await resolver(source).resolveCommentary(query(f, name: nil, selected: true), invocation: source.invocation())
        XCTAssertEqual(selected, .unique(f.destination))
    }
    func testNFCWhitespaceAndSourceAliasesAreConservative() async throws {
        let f = CommentaryFixture(), source = CommentarySource(f)
        let r = try await resolver(source).resolveCommentary(query(f, name: "  Kli   Yakar  "), invocation: source.invocation())
        XCTAssertEqual(r, .unique(f.destination))
        let fuzzy = try await resolver(source).resolveCommentary(query(f, name: "Kli Ykr"), invocation: source.invocation())
        XCTAssertEqual(fuzzy, .notFound)
    }
    func testDuplicateLinkIsDeduplicatedWithoutDroppingFocus() async throws {
        let f = CommentaryFixture(), source = CommentarySource(f)
        await source.setup(links: [f.link, f.link])
        let r = try await resolver(source).resolveCommentary(query(f), invocation: source.invocation())
        XCTAssertEqual(r, .unique(f.destination))
    }
    func testAmbiguousLinkedPassagesStayAmbiguousAndBounded() async throws {
        let f = CommentaryFixture(), source = CommentarySource(f)
        let refs = (0..<26).map { ActionTextRef(backend: f.backend, workKey: f.work.workKey, position: .legacyLine(Int64(100 + $0))) }
        let links = refs.map { ActionCommentaryLink(baseLocator: f.base,
            destination: .init(sectionLocator: f.destination.sectionLocator, focusLocator: $0), title: "כלי יקר") }
        await source.setup(links: links, verified: Set(refs + [f.base, f.destination.sectionLocator]))
        let r = try await resolver(source).resolveCommentary(query(f), invocation: source.invocation())
        guard case .ambiguous(let candidates) = r else { return XCTFail("Must not choose one linked passage") }
        XCTAssertEqual(candidates.count, 25)
        XCTAssertTrue(candidates.allSatisfy { $0.kind == .segment && $0.ref["workKey"] == .string(f.work.workKey) })
    }
    func testWrongBaseLinkIsInvalid() async throws {
        let f = CommentaryFixture(), source = CommentarySource(f)
        await source.setup(links: [.init(baseLocator: f.destination.sectionLocator, destination: f.destination, title: "כלי יקר")])
        await expect(.invalidResponse) { _ = try await self.resolver(source).resolveCommentary(self.query(f), invocation: source.invocation()) }
    }
    func testForeignAndUnknownCatalogTargetsAreInvalid() async throws {
        for foreign in [false, true] {
            let f = CommentaryFixture(), source = CommentarySource(f)
            let target = ActionTextRef(backend: foreign ? .sefaria : .otzaria, workKey: foreign ? "Foreign" : "book:999",
                position: foreign ? .canonicalRef("Foreign 1") : .legacyLine(20))
            await source.setup(links: [.init(baseLocator: f.base, destination: .init(sectionLocator: target), title: "כלי יקר")])
            await expect(.invalidResponse) { _ = try await self.resolver(source).resolveCommentary(self.query(f), invocation: source.invocation()) }
        }
    }
    func testFocusFromAnotherWorkIsInvalid() async throws {
        let f = CommentaryFixture(), source = CommentarySource(f)
        await source.setup(links: [.init(baseLocator: f.base,
            destination: .init(sectionLocator: f.destination.sectionLocator, focusLocator: f.base), title: "כלי יקר")])
        await expect(.invalidResponse) { _ = try await self.resolver(source).resolveCommentary(self.query(f), invocation: source.invocation()) }
    }
    func testUnprovenFocusCannotOpenSectionInstead() async throws {
        let f = CommentaryFixture(), source = CommentarySource(f)
        await source.setup(verified: [f.base, f.destination.sectionLocator])
        await expect(.invalidResponse) { _ = try await self.resolver(source).resolveCommentary(self.query(f), invocation: source.invocation()) }
    }
    func testOversizedRelationshipPayloadFailsWithoutPrefixUniqueness() async throws {
        let f = CommentaryFixture(), source = CommentarySource(f)
        await source.setup(links: Array(repeating: f.link, count: 10_001))
        await expect(.invalidResponse) { _ = try await self.resolver(source).resolveCommentary(self.query(f), invocation: source.invocation()) }
    }
    func testSourceGenerationAndEmbeddedEpochChangesDiscardLinks() async throws {
        for backend in [ActionBackendID.otzaria, .sefariaEmbedded] {
            let f = CommentaryFixture(backend), source = CommentarySource(f)
            await source.setup(changeOnLinks: true)
            await expect(.staleState) { _ = try await self.resolver(source).resolveCommentary(self.query(f), invocation: source.invocation()) }
        }
    }
    func testSourceCannotSubstituteProofForBase() async throws {
        let f = CommentaryFixture(), source = CommentarySource(f)
        await source.setup(substitute: f.destination.sectionLocator)
        await expect(.invalidResponse) { _ = try await self.resolver(source).resolveCommentary(self.query(f), invocation: source.invocation()) }
        let calls = await source.linkCalls
        XCTAssertEqual(calls, 0)
    }
    func testEngineUsesOriginalReaderReceiptAndIdempotentRequest() async throws {
        let f = CommentaryFixture(), source = CommentarySource(f), ui = await CommentaryUI(source)
        let core = try ActionExecutor(state: source, resolver: resolver(source), search: source, ui: ui)
        let req = try request(f), ctx = context(f)
        let first = await core.execute(req, context: ctx), retry = await core.execute(req, context: ctx)
        XCTAssertEqual(first.status, .completed); XCTAssertEqual(first.effects, ["reader_opened"]); XCTAssertEqual(retry, first)
        let commands = await ui.commands
        XCTAssertEqual(commands.count, 1); XCTAssertEqual(commands.first?.destination, f.opened)
        XCTAssertEqual(commands.first?.invocation.requestId, req.requestId)
    }
    func testWrongNativeReceiptCannotComplete() async throws {
        let f = CommentaryFixture(), source = CommentarySource(f), ui = await CommentaryUI(source)
        await MainActor.run { ui.wrongReceipt = true }
        let core = try ActionExecutor(state: source, resolver: resolver(source), search: source, ui: ui)
        let result = await core.execute(try request(f), context: context(f))
        XCTAssertEqual(result.error?.code, "invalid_backend_response")
    }
    func testBackendChangeDuringNativePreparationNeverOpens() async throws {
        let f = CommentaryFixture(), source = CommentarySource(f), ui = await CommentaryUI(source)
        await MainActor.run { ui.changeOnPrepare = true }
        let core = try ActionExecutor(state: source, resolver: resolver(source), search: source, ui: ui)
        let result = await core.execute(try request(f), context: context(f))
        XCTAssertEqual(result.status, .staleState)
        let commands = await ui.commands; XCTAssertTrue(commands.isEmpty)
    }
    func testHeadlessAndRestrictedWorkCannotOpen() async throws {
        let f = CommentaryFixture(), source = CommentarySource(f), ui = await CommentaryUI(source)
        let core = try ActionExecutor(state: source, resolver: resolver(source), search: source, ui: ui)
        let headless = await core.execute(try request(f, headless: true), context: context(f))
        XCTAssertEqual(headless.status, .requiresForeground)
        let denied = await core.execute(try request(f), context: context(f, works: [f.base.workKey]))
        XCTAssertNotEqual(denied.status, .completed)
        let commands = await ui.commands; XCTAssertTrue(commands.isEmpty)
    }
    func testUnsupportedSourceOrSinkDoesNotAdvertiseOrExecute() async throws {
        let f = CommentaryFixture(), source = CommentarySource(f)
        let core = try ActionExecutor(state: source, resolver: resolver(source), search: source)
        let actions = await core.advertisedActions(for: f.backend, context: context(f))
        XCTAssertFalse(actions.contains { $0.id == "reader.openCommentary" })
        let result = await core.execute(try request(f), context: context(f))
        XCTAssertEqual(result.error?.code, "commentary_navigation_unavailable")
        let calls = await source.linkCalls; XCTAssertEqual(calls, 0)
        let ports = MockPorts(), ui = await CommentaryUI(source)
        let oldResolver = try ActionExecutor(state: ports, resolver: ports, search: ports, ui: ui)
        let oldResult = await oldResolver.execute(try request(f), context: context(f))
        XCTAssertEqual(oldResult.error?.code, "commentary_navigation_unavailable")
    }
    func testSemanticCapabilityRequiresBothNavigationAndOriginalLinks() throws {
        let f = CommentaryFixture()
        var evidence = ActionBackendRuntimeEvidence(snapshot: .init(backend: f.backend, generation: 3),
            registeredCapabilities: ["navigation"], references: .ready)
        let profile = ActionBackendSemanticProfile(backend: f.backend)
        let absent = try profile.assess(action: "reader.openCommentary", evidence: evidence)
        XCTAssertFalse(absent.registered); XCTAssertFalse(absent.availableNow)
        evidence.registeredCapabilities.insert("links")
        let ready = try profile.assess(action: "reader.openCommentary", evidence: evidence)
        XCTAssertTrue(ready.registered); XCTAssertTrue(ready.supported); XCTAssertTrue(ready.availableNow)
        let count = try profile.assess(action: "search.countOccurrences", evidence: evidence)
        XCTAssertFalse(count.supported); XCTAssertEqual(count.reasonCode, "exact_count_unavailable")
    }
}
