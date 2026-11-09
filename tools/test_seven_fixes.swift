import Foundation

private enum FixtureError: Error { case offline, prepare, assertion(String) }
private actor CleanupProbe {
    var calls: [BackendID: Int] = [:]
    func invalidate(_ backend: BackendID) { calls[backend, default: 0] += 1 }
    func count(_ backend: BackendID) -> Int { calls[backend, default: 0] }
}
private struct CatalogFixture: LibraryCatalogProviding {
    var nodes: [LibraryCatalogNode]
    var fails = false
    func catalog(forceRefresh: Bool) async throws -> [LibraryCatalogNode] {
        if fails { throw FixtureError.offline }
        return nodes
    }
}

@MainActor
private final class ParticipantFixture: BackendSwitchParticipant {
    let coordinator: BackendCoordinator
    var fails = false
    var prepared = 0
    var published = 0
    var aborted = 0
    var expectedOutgoing: BackendID = .otzaria
    var expectedTarget: BackendID = .sefaria
    var visibleTabs = ["outgoing@scroll812:selected9,4"]
    init(_ coordinator: BackendCoordinator) { self.coordinator = coordinator }
    func prepareTransition(from currentBackend: BackendID, to targetBackend: BackendID, token: UInt64) throws -> PreparedBackendTransition? {
        prepared += 1
        guard coordinator.activeBackendID == expectedOutgoing, currentBackend == expectedOutgoing,
              targetBackend == expectedTarget,
              coordinator.stagedCatalogs[targetBackend]?["Genesis"]?.locator.backend == targetBackend else {
            throw FixtureError.assertion("Target metadata must be staged before preparation while outgoing is still active")
        }
        if fails { throw FixtureError.prepare }
        return nil
    }
    func publishTransition(to targetBackend: BackendID, transition: PreparedBackendTransition?) {
        published += 1
        visibleTabs = [targetBackend.rawValue + ":Genesis"]
    }
    func abortTransition(from currentBackend: BackendID, to targetBackend: BackendID, error: Error) { aborted += 1 }
}

@main
struct SevenFixTests {
    @MainActor
    static func main() async throws {
        var checks = 0
        func expect(_ value: Bool, _ message: String) throws {
            guard value else { throw FixtureError.assertion(message) }
            checks += 1
        }
        for requested in BackendID.allCases {
            let key = requested == .otzaria ? "book:42" : "Genesis"
            for candidate in BackendID.allCases {
                let locator = TextLocator(backend: candidate, workKey: key, position: .legacyLine(0))
                try expect(TargetBackendBookIdentity.matches(id: 42, locator: locator, requestedID: 42,
                    workKey: key, backend: requested) == (candidate == requested),
                    "Same numeric ID cannot cross backend \(candidate) -> \(requested)")
            }
            try expect(!TargetBackendBookIdentity.matches(id: 42, locator: nil, requestedID: 42,
                workKey: nil, backend: requested), "Missing locator is not proof of \(requested)")
            let authentic = TextLocator(backend: requested, workKey: key, position: .legacyLine(0))
            try expect(!TargetBackendBookIdentity.matches(id: 43, locator: authentic, requestedID: 42,
                workKey: key, backend: requested), "Backend-local ID still matters")
            try expect(!TargetBackendBookIdentity.matches(id: 42, locator: authentic, requestedID: 42,
                workKey: "Different", backend: requested), "Different work cannot match by number")
            try expect(try TargetBackendBookIdentity.workKey(requested.rawValue + ":" + key, in: requested) == key,
                       "Qualified prefix normalization preserves work identity")
            for foreign in BackendID.allCases where foreign != requested {
                do {
                    _ = try TargetBackendBookIdentity.workKey(foreign.rawValue + ":Genesis", in: requested)
                    throw FixtureError.assertion("Foreign qualified prefix accepted")
                } catch BackendTransitionError.foreignBackendLocator { checks += 1 }
            }
        }
        let alias = TextLocator(backend: .otzaria, workKey: "/real/path/Shabbat.txt", position: .legacyLine(812))
        try expect(TargetBackendBookIdentity.matches(id: 42, locator: alias, requestedID: 42,
            workKey: "book:42", backend: .otzaria), "Original numeric alias resolves to authentic Otzaria file key")

        func node(_ backend: BackendID) -> LibraryCatalogNode {
            let work = LibraryWork(locator: .init(backend: backend, workKey: "Genesis", position: .canonicalRef("Genesis")),
                title: "Genesis", heTitle: "בראשית", categories: [], description: nil)
            return .init(id: work.id, kind: .work, title: work.title, heTitle: work.heTitle, work: work, children: [])
        }
        let retainedLocator = TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 1"))
        try expect(!TargetBackendBookIdentity.matches(id: 42, locator: retainedLocator, requestedID: 42,
            workKey: nil, backend: .sefaria, stagedCatalog: [:]),
            "A retained authentic book without a saved key cannot bypass a successfully refreshed empty catalog")
        try expect(TargetBackendBookIdentity.matches(id: 42, locator: retainedLocator, requestedID: 42,
            workKey: "Genesis", backend: .sefaria, stagedCatalog: ["Genesis": node(.sefaria).work!]),
            "A retained authentic book still resolves from the complete target catalog")
        let domain = "seven-fixes-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let coordinator = BackendCoordinator(defaults: defaults)
        let cleanup = CleanupProbe()
        func register(_ backend: BackendID, nodes: [LibraryCatalogNode], fails: Bool = false) {
            coordinator.register(.init(id: backend, sourceDescription: backend.rawValue, capabilities: [.catalog],
                catalog: CatalogFixture(nodes: nodes, fails: fails), usesNativeMaktabahDataPath: backend == .otzaria,
                invalidateTransientState: { await cleanup.invalidate(backend) }))
        }
        register(.otzaria, nodes: [])
        register(.sefaria, nodes: [node(.sefaria)])
        register(.sefariaEmbedded, nodes: [node(.sefariaEmbedded)])
        let participant = ParticipantFixture(coordinator)
        coordinator.addSwitchParticipant(participant)
        let startGeneration = coordinator.generation
        try await coordinator.stageCatalog(for: .sefaria)
        try expect(coordinator.activeBackendID == .otzaria && coordinator.generation == startGeneration,
                   "Cold target preflight changes no active backend/generation")
        try expect(defaults.string(forKey: BackendCoordinator.selectionDefaultsKey) == nil,
                   "Preflight never commits preferences")
        try expect(participant.visibleTabs == ["outgoing@scroll812:selected9,4"] && participant.prepared == 0,
                   "Preflight never clears or republishes outgoing tabs")
        register(.sefaria, nodes: [], fails: true)
        do { try await coordinator.commitCheckedAsync(.sefaria); throw FixtureError.assertion("Network failure accepted") }
        catch FixtureError.offline { checks += 1 }
        try expect(coordinator.activeBackendID == .otzaria && coordinator.generation == startGeneration,
                   "Network failure preserves canonical state")
        try expect(participant.published == 0 && participant.visibleTabs == ["outgoing@scroll812:selected9,4"],
                   "Network failure preserves complete visible projection")
        try expect(coordinator.stagedCatalogs[.sefaria]?["Genesis"] != nil,
                   "Failed refresh does not poison previously complete target cache")
        register(.sefaria, nodes: [node(.sefariaEmbedded)])
        do { try await coordinator.commitCheckedAsync(.sefaria); throw FixtureError.assertion("Foreign target catalog accepted") }
        catch BackendTransitionError.foreignBackendLocator { checks += 1 }
        try expect(coordinator.activeBackendID == .otzaria && participant.published == 0,
                   "Mislabeled provider fails before publication")
        register(.sefaria, nodes: [node(.sefaria)])
        participant.fails = true
        do { try await coordinator.commitCheckedAsync(.sefaria); throw FixtureError.assertion("Participant failure accepted") }
        catch FixtureError.prepare { checks += 1 }
        try expect(coordinator.activeBackendID == .otzaria && coordinator.generation == startGeneration,
                   "Participant prepare failure preserves backend/generation")
        try expect(defaults.string(forKey: BackendCoordinator.selectionDefaultsKey) == nil && participant.published == 0,
                   "Prepare failure leaves preferences and live tabs intact")
        participant.fails = false
        try await coordinator.commitCheckedAsync(.sefaria)
        try expect(coordinator.activeBackendID == .sefaria && coordinator.generation == startGeneration + 1,
                   "Successful two-phase commit publishes exactly one generation")
        try expect(participant.published == 1 && participant.visibleTabs == ["sefaria:Genesis"],
                   "Publication follows target staging and preparation")
        for _ in 0..<100 where await cleanup.count(.otzaria) == 0 { await Task.yield() }
        let firstCleanup = await cleanup.count(.otzaria)
        let firstTargetCleanup = await cleanup.count(.sefaria)
        try expect(firstCleanup == 1 && firstTargetCleanup == 0,
                   "Only outgoing cleanup runs; new Sefaria reader requests cannot be invalidated")
        participant.expectedOutgoing = .sefaria
        participant.expectedTarget = .sefariaEmbedded
        try await coordinator.commitCheckedAsync(.sefariaEmbedded)
        try expect(coordinator.stagedCatalogs[.sefaria]?["Genesis"]?.locator.backend == .sefaria &&
                   coordinator.stagedCatalogs[.sefariaEmbedded]?["Genesis"]?.locator.backend == .sefariaEmbedded,
                   "Sefaria and Embedded catalogs remain isolated for the same work")
        try expect(participant.published == 2 && coordinator.generation == startGeneration + 2,
                   "Switching between Sefaria providers follows the same atomic protocol")
        for _ in 0..<100 where await cleanup.count(.sefaria) == 0 { await Task.yield() }
        let secondCleanup = await cleanup.count(.sefaria)
        let secondTargetCleanup = await cleanup.count(.sefariaEmbedded)
        try expect(secondCleanup == 1 && secondTargetCleanup == 0,
                   "Target Embedded RPC cleanup cannot cancel newly published content")
        register(.sefaria, nodes: [])
        try await coordinator.stageCatalog(for: .sefaria)
        try expect(coordinator.stagedCatalogs[.sefaria]?.isEmpty == true,
                   "Deleted works are removed by a complete target refresh")
        try expect(coordinator.activeBackendID == .sefariaEmbedded && participant.published == 2,
                   "Empty target catalog preflight never publishes or clears the active group")

        // Exercise real sidecar validation/persistence: a failing scene selection
        // never publishes the candidate or changes its existing persisted bytes.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(domain)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("workspace.json")
        let store = StudyWorkspaceStore(persistence: .init(url: url), canonicalSessionURL: directory.appendingPathComponent("canonical.json"))
        let saved = ReaderDocumentTab(backend: .otzaria, session: .init(id: UUID(), bookId: 42,
            bookTitle: "שבת", backendLocator: alias, locator: alias,
            scrollPosition: CGPoint(x: 0, y: 812), selectedRange: NSRange(location: 9, length: 4)))
        try store.attach(scene: "window", legacyTabs: [saved], activeID: saved.id)
        let before = store.snapshot
        let bytes = try Data(contentsOf: url)
        do {
            try store.transaction { value in value.scenes["window"]?.groupID = UUID() }
            throw FixtureError.assertion("Invalid scene transaction accepted")
        } catch StudyWorkspaceError.invalidMembership { checks += 1 }
        try expect(store.snapshot == before && (try Data(contentsOf: url)) == bytes,
                   "Invalid group transition preserves full snapshot and disk bytes")
        let parent = directory.appendingPathComponent("blocked")
        let blockedURL = parent.appendingPathComponent("workspace.json")
        let blockedStore = StudyWorkspaceStore(persistence: .init(url: blockedURL), canonicalSessionURL: directory.appendingPathComponent("canonical.json"))
        try blockedStore.attach(scene: "window", legacyTabs: [saved], activeID: saved.id)
        let blockedSnapshot = blockedStore.snapshot
        try FileManager.default.removeItem(at: blockedURL)
        try FileManager.default.removeItem(at: parent)
        try Data("block directory creation".utf8).write(to: parent)
        do {
            try blockedStore.transaction { value in value.groups[0].name = "Must not publish" }
            throw FixtureError.assertion("Disk failure accepted")
        } catch is CocoaError { checks += 1 }
        try expect(blockedStore.snapshot == blockedSnapshot, "Persistence failure preserves outgoing group, UUIDs, positions and selection")
        try expect(StudyWorkspaceProjectionPolicy.backend(restoring: nil, requestedID: saved.id,
            documents: [saved], fallback: .sefariaEmbedded) == .otzaria, "Explicit selection overrides previously active source")
        try expect(StudyWorkspaceProjectionPolicy.backend(restoring: .sefariaEmbedded, requestedID: saved.id,
            documents: [saved], fallback: .otzaria) == .sefariaEmbedded, "Cold startup keeps canonical committed source")
        try expect(StudyWorkspaceProjectionPolicy.backend(restoring: nil, requestedID: nil,
            documents: [], fallback: .sefariaEmbedded) == .sefariaEmbedded, "Empty group keeps active backend")
        print("EXECUTED_PASS: \(checks) seven-fix portable identity/catalog/transition/persistence assertions")
        print("NOT_RUN: SwiftUI/UIKit runtime, Simulator, physical iPad visual acceptance")
    }
}
