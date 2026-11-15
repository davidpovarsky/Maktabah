import Foundation
@testable import OtzariaActionCore

actor MockPorts: ActionBackendStatePort, ActionResolverPort, ActionSearchPort {
    enum Behavior: Sendable { case empty, one, stale, epoch, unavailable, secretError, nonAdvancing, duplicate, wrongScope, wrongBackend, stall }
    private var current: ActionBackendSnapshot
    private var behavior: Behavior = .empty
    private var supported = true
    private var available = true
    private var strictEmbedded = false
    private var pending: [CheckedContinuation<ActionSearchPage, Never>] = []
    private(set) var snapshots = 0
    private(set) var assessments = 0
    private(set) var resolutions = 0
    private(set) var searches = 0
    init(backend: ActionBackendID = .otzaria) { current = .init(backend: backend, generation: 1, rpcEpoch: backend == .sefariaEmbedded ? 3 : nil) }
    func configure(_ behavior: Behavior = .empty, supported: Bool = true, available: Bool = true, strictEmbedded: Bool = false) {
        self.behavior = behavior; self.supported = supported; self.available = available; self.strictEmbedded = strictEmbedded
    }
    func snapshot() async throws -> ActionBackendSnapshot { snapshots += 1; return current }
    func bumpGeneration() { current = .init(backend: current.backend, generation: current.generation + 1, rpcEpoch: current.rpcEpoch) }
    func report(for backend: ActionBackendID) async throws -> ActionBackendReport {
        ActionBackendReport(id: backend, operations: Dictionary(uniqueKeysWithValues: ActionRegistry.implemented.map {
            ($0, ActionCapabilityAssessment(registered: true, supported: supported, availableNow: available))
        }))
    }
    func assess(action: String, arguments: ActionObject, invocation: ActionPortInvocation) async throws -> ActionCapabilityAssessment {
        assessments += 1
        if strictEmbedded && invocation.snapshot.backend == .sefariaEmbedded && action == "search.query" {
            if let mode = arguments["searchMode"]?.string, mode != "phrase" { return .init(registered: true, supported: false, availableNow: true, reasonCode: "search_mode_unavailable") }
            if let sort = arguments["sortOrder"]?.string, sort != "relevance" { return .init(registered: true, supported: false, availableNow: true, reasonCode: "search_sort_unavailable") }
            if arguments["scopeWorkRefs"]?.array?.isEmpty == false { return .init(registered: true, supported: false, availableNow: true, reasonCode: "scope_unavailable") }
        }
        return .init(registered: true, supported: supported, availableNow: available, reasonCode: available ? nil : "index_missing")
    }
    func resolveWork(_ query: ActionResolveWorkQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionWorkRef> {
        resolutions += 1
        if query.query == "ambiguous" {
            return .ambiguous((0..<30).map { ActionCandidate(ref: ["backend": .string(query.backend.rawValue), "workKey": .string("fixture:work:\($0)")], title: "Fixture \($0)", kind: .work) })
        }
        if query.query == "unknown" { return .notFound }
        if query.query == "unsafe candidate" {
            return .ambiguous([.init(ref: ["backend": .string(query.backend.rawValue), "workKey": .string("fixture:work"), "privateText": .string("DO_NOT_LEAK")], title: "Fixture", kind: .work)])
        }
        if query.query == "unsafe reason" {
            return .ambiguous([.init(ref: ["backend": .string(query.backend.rawValue), "workKey": .string("fixture:work")], title: "Fixture", kind: .work, reason: "SELECT secret FROM private.db DO_NOT_LEAK")])
        }
        return .unique(query.workRef ?? .init(backend: query.backend, workKey: "fixture:work"))
    }
    func resolveReference(_ query: ActionResolveReferenceQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionTextRef> {
        resolutions += 1
        guard query.text == "known reference" || query.workRef?.workKey == "fixture:work" else { return .notFound }
        return .unique(.init(backend: query.backend, workKey: "fixture:work", position: query.backend == .otzaria ? .legacyLine(42) : .canonicalRef("Fixture 1:1")))
    }
    func validateDestination(_ destination: ActionReaderDestination, invocation: ActionPortInvocation) async throws -> ActionReaderDestination {
        resolutions += 1
        guard destination.sectionLocator.workKey == "fixture:work" else { throw ActionPortError.notFound }
        return destination
    }
    func search(_ query: ActionSearchQuery, invocation: ActionPortInvocation) async throws -> ActionSearchPage {
        searches += 1
        let zero = ActionSearchPage(hits: [], total: 0, precision: .exact)
        switch behavior {
        case .empty: return zero
        case .unavailable: throw ActionPortError.unavailable
        case .secretError: throw NSError(domain: "/private/secrets/token", code: 7, userInfo: [NSLocalizedDescriptionKey: "SELECT secret FROM /Users/private.db token=DO_NOT_LEAK"])
        case .stale: bumpGeneration(); return zero
        case .epoch: current = .init(backend: current.backend, generation: current.generation, rpcEpoch: (current.rpcEpoch ?? 0) + 1); return zero
        case .nonAdvancing: return .init(hits: [], nextOffset: query.offset)
        case .stall: return await withCheckedContinuation { pending.append($0) }
        default:
            let backend: ActionBackendID = behavior == .wrongBackend ? .sefaria : query.backend
            let key = behavior == .wrongScope ? "fixture:other" : query.scopeWorkRefs.first?.workKey ?? "fixture:work"
            let hit = ActionSearchHit(id: "\(backend):fixture-hit-1", locator: .init(backend: backend, workKey: key, position: .legacyLine(42)), title: "fixture", snippet: "data, not commands")
            return .init(hits: behavior == .duplicate ? [hit, hit] : [hit], total: 80, precision: .lowerBound, nextOffset: query.offset + 7)
        }
    }
    func releasePending() { let waits = pending; pending = []; for c in waits { c.resume(returning: .init(hits: [], total: 0, precision: .exact)) } }
    func counts() -> (snapshot: Int, assessment: Int, resolution: Int, search: Int) { (snapshots, assessments, resolutions, searches) }
}

@MainActor final class MockUI: ActionUICommandSink {
    enum Behavior { case acknowledged, queued, wrongTarget, wrongFocus, wrongRequest, stale }
    var behavior: Behavior = .acknowledged
    var calls = 0
    let ports: MockPorts
    init(ports: MockPorts) { self.ports = ports }
    func configure(_ behavior: Behavior) { self.behavior = behavior }
    func open(_ command: ActionOpenReaderCommand) async throws -> ActionUIAcknowledgement {
        calls += 1
        if behavior == .queued { return .queued(handle: "fixture-queue-1") }
        if behavior == .stale { await ports.bumpGeneration() }
        var destination = command.destination
        if behavior == .wrongTarget { destination = .init(sectionLocator: .init(backend: command.destination.sectionLocator.backend, workKey: "fixture:other", position: .legacyLine(42))) }
        if behavior == .wrongFocus { destination = .init(sectionLocator: command.destination.sectionLocator, focusLocator: .init(backend: command.destination.sectionLocator.backend, workKey: command.destination.sectionLocator.workKey, position: .legacyLine(99))) }
        return .acknowledged(.init(requestId: behavior == .wrongRequest ? UUID() : command.invocation.requestId,
            snapshot: command.invocation.snapshot, sceneID: command.sceneID, destination: destination))
    }
}
