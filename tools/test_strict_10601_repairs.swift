import Foundation

private enum Failure: Error { case expected, assertion(String) }

private struct Catalog: LibraryCatalogProviding {
    let backend: BackendID
    let fails: Bool
    func catalog(forceRefresh: Bool) async throws -> [LibraryCatalogNode] {
        if fails { throw Failure.expected }
        let work = LibraryWork(locator: .init(backend: backend, workKey: "Genesis", position: .canonicalRef("Genesis")),
            title: "Genesis", heTitle: "בראשית", categories: [], description: nil)
        return [.init(id: "work", kind: .work, title: work.title, heTitle: work.heTitle, work: work, children: [])]
    }
}

@MainActor private final class Participant: BackendSwitchParticipant {
    var fail = false
    var cancel = false
    var events: [String] = []
    var onPrepare: () throws -> Void = {}
    func prepareTransitionAsync(from: BackendID, to: BackendID, token: UInt64) async throws -> PreparedBackendTransition? {
        events.append("prepare")
        try onPrepare()
        if cancel { withUnsafeCurrentTask { $0?.cancel() } }
        if fail { throw Failure.expected }
        return nil
    }
    func publishTransition(to: BackendID, transition: PreparedBackendTransition?) { events.append("publish") }
    func abortTransition(from: BackendID, to: BackendID, error: Error) { events.append("abort") }
    func completeTransition(to: BackendID) { events.append("complete") }
}

@main struct Strict10601Tests {
    @MainActor static func main() async throws {
        var count = 0
        func expect(_ value: Bool, _ message: String) throws {
            guard value else { throw Failure.assertion(message) }
            count += 1
        }
        for backend in [BackendID.otzaria, .sefaria, .sefariaEmbedded] {
            try expect(TargetBackendBookIdentity.matches(id: 7, backend: backend, workKey: "A",
                candidateID: 7, candidateBackend: backend, candidateWorkKey: "A"), "exact identity")
            try expect(!TargetBackendBookIdentity.matches(id: 7, backend: backend, workKey: "A",
                candidateID: 7, candidateBackend: backend, candidateWorkKey: "B"), "same ID wrong work")
            try expect(!TargetBackendBookIdentity.matches(id: 7, backend: backend, workKey: "A",
                candidateID: 8, candidateBackend: backend, candidateWorkKey: "A"), "wrong local ID")
            for other in [BackendID.otzaria, .sefaria, .sefariaEmbedded] where other != backend {
                try expect(!TargetBackendBookIdentity.matches(id: 7, backend: backend, workKey: "A",
                    candidateID: 7, candidateBackend: other, candidateWorkKey: "A"), "same ID cross-source collision")
            }
        }
        try expect(!TargetBackendBookIdentity.matches(id: 7, backend: .sefaria, workKey: "A",
            candidateID: 7, candidateBackend: nil, candidateWorkKey: nil), "nil is never Otzaria/Sefaria evidence")
        try expect(!TargetBackendBookIdentity.matches(id: 7, backend: .sefaria, workKey: nil,
            candidateID: 7, candidateBackend: .sefaria, candidateWorkKey: "A"), "numeric ID alone cannot establish work identity")

        for readerWidth in [CGFloat(430), 645, 860] {
            let threshold = readerWidth + 318
            try expect(!ChavrusaReaderWorkspaceWidthPolicy.canDock(detailWidth: threshold - 1, minimumReaderWidth: readerWidth), "below threshold floats")
            try expect(ChavrusaReaderWorkspaceWidthPolicy.canDock(detailWidth: threshold, minimumReaderWidth: readerWidth), "threshold docks")
            try expect(ChavrusaReaderWorkspaceWidthPolicy.canDock(detailWidth: threshold + 300, minimumReaderWidth: readerWidth), "wide docks")
        }
        try expect(!ChavrusaReaderWorkspaceWidthPolicy.canDock(detailWidth: .nan, minimumReaderWidth: 430), "invalid measurement floats")

        for tabsCount in [0, 1, 3, 10] {
            for width in [CGFloat(340), 900] {
                let layout = TabsBarLayout(stripWidth: width, tabsCount: tabsCount, minItemWidth: 100,
                    maxItemWidth: 240, buttonWidth: 0, buttonGap: 0)
                try expect(layout.itemWidth.isFinite && layout.addTabButtonContentInsetRight == 0,
                    "0/1/3/10 tabs reserve no hidden toolbar-button width")
                try expect(tabsCount == 0 ? layout.itemWidth == 0 : (100...240).contains(layout.itemWidth),
                    "original source tab width bounds at compact/wide sizes")
            }
        }
        let firstID = UUID(), secondID = UUID(), groupID = UUID(), profileID = UUID()
        func document(_ id: UUID) -> ReaderDocumentTab {
            .init(backend: .otzaria, session: .init(id: id, bookId: 7, backendLocator: nil))
        }
        let group = StudyTabGroup(id: groupID, profileID: profileID, name: "test", order: 0,
            tabs: [document(firstID), document(secondID)], activeTabID: firstID)
        let scene = StudySceneSelection(profileID: profileID, groupID: groupID, activeTabIDsByGroup: [groupID: secondID])
        try expect(StudyWorkspaceProjectionPolicy.activeDocumentID(in: group, selection: scene) == secondID,
            "scene selected UUID overrides another window's group active card")
        try expect(StudyWorkspaceProjectionPolicy.activeDocumentID(in: group, selection: nil) == firstID,
            "legacy group fallback preserved")

        let suite = "strict-10601-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("otzaria", forKey: BackendCoordinator.selectionDefaultsKey)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("strict-snapshots-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let snapshots = BackendNavigationAdapter(storageDirectory: directory)
        let snapshotURL = directory.appendingPathComponent("otzaria.session.json")
        let originalBytes = Data("old snapshot bytes".utf8)
        try snapshots.saveBackendSessionSnapshot(backend: .otzaria, sessionData: originalBytes)
        let coordinator = BackendCoordinator(defaults: defaults, sessionSnapshots: snapshots)
        for backend in [BackendID.otzaria, .sefaria, .sefariaEmbedded] {
            coordinator.register(.init(id: backend, sourceDescription: backend.rawValue, capabilities: [],
                catalog: Catalog(backend: backend, fails: backend == .sefariaEmbedded),
                usesNativeMaktabahDataPath: backend == .otzaria, invalidateTransientState: {}))
        }
        let target = try await coordinator.catalog(for: .sefaria)
        try expect(target.first?.work?.locator.backend == .sefaria && coordinator.activeBackendID == .otzaria,
            "cold target catalog does not commit active library")
        do { _ = try await coordinator.catalog(for: .sefariaEmbedded); throw Failure.assertion("network failure swallowed") }
        catch Failure.expected {}
        try expect(coordinator.activeBackendID == .otzaria && coordinator.generation == 0, "network failure leaves active state intact")

        let first = Participant(), second = Participant()
        coordinator.addSwitchParticipant(first)
        coordinator.addSwitchParticipant(second)
        first.onPrepare = {
            try snapshots.saveBackendSessionSnapshot(backend: .otzaria, sessionData: Data("prepared outgoing snapshot".utf8))
            try expect(try Data(contentsOf: snapshotURL) == originalBytes, "participant snapshot writes stay staged during prepare")
        }
        second.fail = true
        var persisted = Data("original persistent bytes".utf8)
        let original = persisted
        do {
            try await coordinator.commitCheckedAsync(.sefaria, beforeCommit: { persisted = Data("new".utf8) })
            throw Failure.assertion("partial prepare failure swallowed")
        } catch Failure.expected {}
        try expect(first.events == ["prepare", "abort"] && second.events == ["prepare", "abort"], "all participants abort partial preparation")
        try expect(persisted == original && coordinator.activeBackendID == .otzaria && coordinator.generation == 0,
            "partial preparation cannot reach persistence or backend commit")
        try expect(try Data(contentsOf: snapshotURL) == originalBytes && snapshots.retrieveBackendSessionSnapshot(backend: .otzaria) == originalBytes,
            "partial failure retains actual disk bytes and cache")
        second.fail = false
        first.events = []; second.events = []
        do {
            try await coordinator.commitCheckedAsync(.sefaria, beforeCommit: { throw Failure.expected }, publish: { persisted = Data("bad".utf8) })
            throw Failure.assertion("I/O failure swallowed")
        } catch Failure.expected {}
        try expect(first.events == ["prepare", "abort"] && persisted == original, "failed persistence cannot publish")
        try expect(defaults.string(forKey: BackendCoordinator.selectionDefaultsKey) == "otzaria", "failed persistence retains committed selection")
        try expect(try Data(contentsOf: snapshotURL) == originalBytes && snapshots.retrieveBackendSessionSnapshot(backend: .otzaria) == originalBytes,
            "workspace persistence failure rolls back flushed session bytes and cache")

        first.events = []; second.events = []
        try await coordinator.commitCheckedAsync(.sefaria, beforeCommit: {
            try expect(coordinator.activeBackendID == .otzaria, "prepare precedes commit")
            persisted = Data("new".utf8)
        }, publish: {
            precondition(coordinator.activeBackendID == .sefaria)
            first.events.append("group-publish")
        })
        try expect(first.events == ["prepare", "publish", "group-publish", "complete"], "group publishes before completion")
        try expect(coordinator.activeBackendID == .sefaria && coordinator.generation == 1, "recovery commits exactly once")
        var sameBackend = false
        try await coordinator.commitCheckedAsync(.sefaria, publish: { sameBackend = true })
        try expect(sameBackend && coordinator.generation == 1, "same-source group publication does not switch backend")

        first.cancel = true
        first.onPrepare = {}
        let cancelled = Task { @MainActor in
            try await coordinator.commitCheckedAsync(.sefariaEmbedded, publish: { preconditionFailure("cancelled publication") })
        }
        do { try await cancelled.value; throw Failure.assertion("cancelled participant committed") }
        catch is CancellationError {}
        try expect(coordinator.activeBackendID == .sefaria && coordinator.generation == 1,
            "participant ignoring cancellation still cannot commit")
        print("PASS: \(count) strict identity/docking/target-provider/atomic-publication/failure/cancellation checks")
    }
}
