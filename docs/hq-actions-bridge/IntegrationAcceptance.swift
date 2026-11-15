import Foundation
import OtzariaActionCore

// Real app BackendCoordinator/Models/Protocols + real new facade/mapper compile
// in this harness. Providers/observations are explicit doubles, not a replacement
// coordinator or evidence of installed SQLite/network/Hermes/Apple UI behavior.
actor BridgeFixtureProvider: LibraryCatalogProviding, LibraryTextProviding, LibraryNavigationProviding, LibrarySearchProviding {
    let backend: BackendID
    var lastRequest: LibrarySearchRequest?
    var badScope = false
    var hold = false
    var started = false
    var startWaiter: CheckedContinuation<Void, Never>?
    var continuation: CheckedContinuation<Void, Never>?
    init(_ backend: BackendID) { self.backend = backend }
    func workKey() -> String { backend == .otzaria ? "book:7" : "Genesis" }
    func locator(_ line: Int = 42) -> TextLocator {
        .init(backend: backend, workKey: workKey(), position: backend == .otzaria ? .legacyLine(line) : .canonicalRef("Genesis 1:1"))
    }
    func catalog(forceRefresh: Bool) -> [LibraryCatalogNode] {
        let work = LibraryWork(locator: locator(), title: "Fixture source", heTitle: "מקור בדיקה", categories: [], description: nil,
                               searchPath: backend == .sefaria ? "Tanakh/Torah/Genesis" : nil)
        return [.init(id: "fixture", kind: .work, title: work.title, heTitle: work.heTitle, work: work, children: [])]
    }
    func section(at input: TextLocator) -> LibraryTextSection {
        let exact = locator()
        return .init(locator: exact, displayRef: "fixture", heRef: nil,
            segments: [.init(locator: exact, heRef: nil, primaryText: "fixture", translation: nil)],
            previous: nil, next: nil, versions: [], links: [], origin: .offline)
    }
    func normalizedLocator(for input: String) throws -> TextLocator {
        guard input != "missing" else { throw LibraryBackendError.invalidLocator }
        return locator()
    }
    func tableOfContents(for work: LibraryWork) -> [LibraryTOCNode] { [] }
    func search(_ request: LibrarySearchRequest) async -> LibrarySearchPage {
        lastRequest = request
        if hold {
            started = true; startWaiter?.resume(); startWaiter = nil
            await withCheckedContinuation { continuation = $0 }
        }
        let result = badScope ? TextLocator(backend: backend, workKey: "book:8", position: .legacyLine(1)) : locator()
        return .init(hits: [.init(locator: result, displayRef: "fixture", heRef: nil, snippet: "fixture", score: nil)], total: 42, nextOffset: 17)
    }
    func setBadScope(_ value: Bool) { badScope = value }
    func beginHold() { hold = true; started = false }
    func waitForStart() async {
        if started { return }
        await withCheckedContinuation { startWaiter = $0 }
    }
    func release() { hold = false; continuation?.resume(); continuation = nil }
}
actor BridgeFixtureEpoch {
    var epoch: UInt64 = 7
    func value() -> UInt64? { epoch }
    func bump() { epoch += 1 }
}
actor BridgeFixtureProofGate {
    private var started = false
    private var listener: CheckedContinuation<Void, Never>?
    private var pending: CheckedContinuation<Void, Never>?
    func proof() async {
        started = true; listener?.resume(); listener = nil
        await withCheckedContinuation { pending = $0 }
    }
    func waitForStart() async {
        if started { return }
        await withCheckedContinuation { listener = $0 }
    }
    func release() { pending?.resume(); pending = nil }
}

@main struct IntegrationAcceptance {
    @MainActor static var assertions = 0
    @MainActor static func check(_ value: Bool, _ description: String) {
        assertions += 1
        if !value { fatalError("FAIL: " + description) }
    }
    @MainActor static func invocation(_ bridge: ActionBackendCoordinatorFacade) async throws -> ActionPortInvocation {
        .init(requestId: UUID(), snapshot: try await bridge.snapshot(),
              deadlineUptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + 10_000_000_000)
    }
    @MainActor static func main() async throws {
        let position = ActionTextPosition.legacyLine(Int64.max)
        check(try ActionAppIdentityBridge.actionPosition(ActionAppIdentityBridge.appPosition(position)) == position,
              "Int64 range maps losslessly on actual 64-bit app Int")
        let unicode = ActionTextPosition.canonicalRef(" בראשית א:א ")
        check(try ActionAppIdentityBridge.actionPosition(ActionAppIdentityBridge.appPosition(unicode)) == unicode,
              "canonical ref is not silently trimmed/reencoded")
        do { _ = try ActionAppIdentityBridge.appPosition(.legacyLine(-1)); fatalError("negative line accepted") }
        catch { check(true, "negative line refused") }
        let nativePosition = try ActionAppIdentityBridge.appPosition(.legacyLine(42))
        let nativeJSON = String(decoding: try JSONEncoder().encode(nativePosition), as: UTF8.self)
        let wireJSON = String(decoding: try JSONEncoder().encode(ActionTextPosition.legacyLine(42)), as: UTF8.self)
        check(nativeJSON.contains("integer") && !nativeJSON.contains("value"), "existing app persistence integer shape retained")
        check(wireJSON.contains("value") && !wireJSON.contains("integer"), "wire kind/value stays separate")
        do {
            _ = try ActionAppIdentityBridge.appLocator(.init(backend: .otzaria, workKey: "book:7", position: .legacyLine(42), dataRevision: "unrepresentable"))
            fatalError("revision silently dropped")
        } catch { check(true, "unsupported revision refused instead of loss") }

        let suite = "hq-actions-bridge-fixture-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let coordinator = BackendCoordinator(defaults: defaults)
        var providers: [BackendID: BridgeFixtureProvider] = [:]
        for backend in BackendID.allCases {
            let provider = BridgeFixtureProvider(backend)
            providers[backend] = provider
            coordinator.register(.init(id: backend, sourceDescription: "explicit fixture",
                capabilities: [.catalog, .reading, .navigation, .search], catalog: provider, text: provider,
                navigation: provider, search: provider, usesNativeMaktabahDataPath: false, invalidateTransientState: {}))
        }
        let epoch = BridgeFixtureEpoch()
        let bridge = ActionBackendCoordinatorFacade(coordinator: coordinator, epoch: { await epoch.value() }, readiness: { snapshot in
            .init(snapshot: snapshot, catalog: .ready, references: .ready, search: .ready, network: .ready,
                host: .ready, embeddedCatalog: .ready, embeddedSearch: .ready, embeddedResponseFidelity: .ready)
        })
        let first = try await invocation(bridge)
        let mismatch = try await bridge.assess(action: "search.query", arguments: ["text": .string("fixture"), "backend": .string("sefaria")], invocation: first)
        check(!mismatch.availableNow && mismatch.reasonCode == "backend_selection_required", "inactive backend assessment fails before provider")
        let query = ActionSearchQuery(backend: .otzaria, text: "fixture", scopeWorkRefs: [.init(backend: .otzaria, workKey: "book:7")])
        let page = try await bridge.search(query, invocation: first)
        check(page.nextOffset == 17 && page.precision == .unknown, "actual provider cursor retained with conservative total")
        let sent = await providers[.otzaria]!.lastRequest
        check(sent?.filters == ["book:7"] && sent?.scopeWorkKeys == [], "actual app request uses proven filters not ignored scope")
        check(sent?.options.matchMode == .exact && sent?.options.wordDistance == 0, "actual app options map exactly")
        let ref = ActionTextRef(backend: .otzaria, workKey: "book:7", position: .legacyLine(42))
        check(try await bridge.validate(ref, invocation: first) == ref, "exact catalog and returned section validate supplied identity")
        do {
            _ = try await bridge.validate(.init(backend: .otzaria, workKey: "book:7", position: .legacyLine(99)), invocation: first)
            fatalError("nonexistent ref accepted")
        } catch { check(true, "known work alone cannot prove nonexistent section") }
        await providers[.otzaria]!.setBadScope(true)
        do { _ = try await bridge.search(query, invocation: first); fatalError("wrong scope accepted") }
        catch { check(true, "out-of-scope provider hit rejected") }
        await providers[.otzaria]!.setBadScope(false)

        let unknown = ActionBackendCoordinatorFacade(coordinator: coordinator)
        do { _ = try await unknown.search(query, invocation: invocation(unknown)); fatalError("coarse flags treated ready") }
        catch { check(true, "real registered capabilities do not make unknown runtime available") }

        let provider = providers[.otzaria]!
        await provider.beginHold()
        let pending = Task { try await bridge.search(query, invocation: first) }
        await provider.waitForStart()
        coordinator.select(.sefaria)
        await provider.release()
        do { _ = try await pending.value; fatalError("stale search committed") }
        catch { check(true, "real coordinator switch invalidates in-flight action") }
        let legacy = try await invocation(bridge)
        let legacyPage = try await bridge.search(.init(backend: .sefaria, text: "fixture",
            scopeWorkRefs: [.init(backend: .sefaria, workKey: "Genesis")]), invocation: legacy)
        check(legacyPage.nextOffset == 17, "Legacy provider continuation retained")
        let legacyRequest = await providers[.sefaria]!.lastRequest
        check(legacyRequest?.filters == ["Tanakh/Torah/Genesis"] && legacyRequest?.scopeWorkKeys == [],
              "Legacy bounded source filter prevents remote postfilter loop")
        coordinator.select(.sefariaEmbedded)
        let embeddedProvider = providers[.sefariaEmbedded]!
        let textProof: ActionJSON = .object(["textContent": .object([
            "sectionRef": .string("Genesis 1"), "content": .array([
                .object(["ref": .string("Genesis 1:1"), "he": .string("fixture")])])])])
        let embedded = ActionBackendCoordinatorFacade(coordinator: coordinator, epoch: { await epoch.value() }, readiness: { snapshot in
            .init(snapshot: snapshot, catalog: .ready, references: .ready, host: .ready, embeddedCatalog: .ready)
        }, embeddedReferenceProof: { ref, _ in try EmbeddedActionResponseProof.validateText(textProof, ref: ref) },
           embeddedCatalog: { _ in await embeddedProvider.catalog(forceRefresh: false) })
        let embeddedInvocation = try await invocation(embedded)
        let embeddedRef = ActionTextRef(backend: .sefariaEmbedded, workKey: "Genesis", position: .canonicalRef("Genesis 1:1"))
        check(try await embedded.validate(embeddedRef, invocation: embeddedInvocation) == embeddedRef,
              "Embedded exact reference requires catalog and strict observed section proof")
        do {
            _ = try await embedded.referenceCandidates(.init(backend: .sefariaEmbedded, text: "unknown phrase"), invocation: embeddedInvocation)
            fatalError("trim-only ref accepted")
        } catch { check(true, "Embedded trim-only normalizer is not identity proof") }
        let gate = BridgeFixtureProofGate()
        let guarded = ActionBackendCoordinatorFacade(coordinator: coordinator, epoch: { await epoch.value() }, readiness: { snapshot in
            .init(snapshot: snapshot, catalog: .ready, references: .ready, host: .ready, embeddedCatalog: .ready)
        }, embeddedReferenceProof: { ref, _ in
            await gate.proof()
            try EmbeddedActionResponseProof.validateText(textProof, ref: ref)
        }, embeddedCatalog: { _ in await embeddedProvider.catalog(forceRefresh: false) })
        let guardedInvocation = try await invocation(guarded)
        let waiting = Task { try await guarded.validate(embeddedRef, invocation: guardedInvocation) }
        await gate.waitForStart(); await epoch.bump(); await gate.release()
        do { _ = try await waiting.value; fatalError("stale RPC epoch accepted") }
        catch { check(true, "Embedded RPC epoch change invalidates actual facade completion") }
        try await runtimeChecks()
        try await relationshipsChecks()
        print("PASS: \(assertions) Integration assertions using real app coordinator/models/protocols, facade, RPC bridge and runtime manager; providers/transport are doubles, no Hermes or Apple UI")
    }
}
