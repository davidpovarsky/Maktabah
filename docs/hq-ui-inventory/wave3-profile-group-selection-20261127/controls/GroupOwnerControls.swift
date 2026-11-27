import Foundation
import Observation

enum ControlFailure: Error { case expected(String) }
@MainActor final class PassiveStoreProbe: StudyWorkspaceSnapshotObserver {
    var will: (() -> Void)?
    var did: (() -> Void)?
    func workspaceSnapshotWillPublish(before: StudyWorkspaceSnapshot?, after: StudyWorkspaceSnapshot) { let hook = will; will = nil; hook?() }
    func workspaceSnapshotDidPublish(_ snapshot: StudyWorkspaceSnapshot) { let hook = did; did = nil; hook?() }
    func workspaceSnapshotOwnerDidRetire() {}
}
final class SnapshotProbe: BackendSnapshotStaging, @unchecked Sendable {
    let original: BackendNavigationAdapter
    var flushHook: (@MainActor () throws -> Void)?
    var events: [String] = []
    init(_ url: URL) { original = .init(storageDirectory: url) }
    @MainActor func withSnapshotRollback(_ operation: () async throws -> Void) async throws {
        events.append("async-begin")
        try await original.withSnapshotRollback(operation)
        events.append("async-end")
    }
    @MainActor func withSynchronousSnapshotRollback(_ operation: () throws -> Void) throws {
        events.append("sync-begin")
        try original.withSynchronousSnapshotRollback(operation)
        events.append("sync-end")
    }
    func flushStagedSnapshots() throws {
        events.append("flush")
        try original.flushStagedSnapshots()
        try MainActor.assumeIsolated { try flushHook?() }
    }
}
@MainActor final class GroupFixture {
    let directory: URL
    let persistence: StudyWorkspacePersistence
    let store: StudyWorkspaceStore
    let manager: iOSNavigationManager
    let workspace: StudyWorkspaceNavigationAdapter
    let p1: UUID
    let p2: UUID
    let g1: UUID
    let g2: UUID
    let g3: UUID
    let oldTabs: [iOSNavigationManager.ReaderTab]
    let targetTabs: [iOSNavigationManager.ReaderTab]
    let targetProfile: UUID
    let scene = "source-control-scene"
    init(empty: Bool = false, warm: Bool = true, profile: Bool = false,
         foreign: Bool = false, qualified: Bool = true, oldCount: Int = 2, sameGroup: Bool = false) throws {
        BackendCoordinator.shared.resetBoundary()
        ChavrusaTextTargetBackendBookResolver.shared.duringCatalog = nil
        ChavrusaTextTargetBackendBookResolver.shared.duringResolve = nil
        p1 = UUID(); p2 = UUID(); g1 = UUID(); g2 = sameGroup ? g1 : UUID(); g3 = UUID()
        targetProfile = profile ? p2 : p1
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("original-group-control-" + UUID().uuidString)
        persistence = .init(url: directory.appendingPathComponent("workspace.json"))
        func tab(_ number: Int, backend: BackendID = .otzaria) -> iOSNavigationManager.ReaderTab {
            let book = BooksData(number, key: "book:\(number)", backend: backend)
            let reader = ReaderViewModel(book: book)
            reader.seedLoaded(.init(backend: backend, workKey: "book:\(number)", position: .legacyLine(523)))
            reader.readerState.scrollPosition = CGPoint(x: 0, y: CGFloat(number))
            return .init(id: UUID(), book: book, initialContentId: 523, viewModel: reader)
        }
        oldTabs = (0..<oldCount).map { tab(100 + $0) }
        targetTabs = sameGroup ? oldTabs : empty ? [] : [tab(201, backend: foreign ? .sefaria : .otzaria), tab(202, backend: foreign ? .sefaria : .otzaria)]
        func document(_ tab: iOSNavigationManager.ReaderTab, qualified: Bool) -> ReaderDocumentTab {
            .init(backend: tab.book.backendLocator!.backend, session: .init(id: tab.id, bookId: tab.book.id,
                bookTitle: tab.book.title, backendLocator: tab.book.backendLocator, contentId: 523,
                locator: qualified ? tab.viewModel.currentLocator : nil,
                scrollPosition: CGPoint(x: 0, y: 73), selectedRange: NSRange(location: 3, length: 2),
                expandedNodeIDs: [8], searchText: "saved original query", searchModeRaw: 0,
                nearDistance: 12, highlightTerms: ["saved"]))
        }
        var snapshot = StudyWorkspaceSnapshot()
        snapshot.profiles = [.init(id: p1, name: "Current", symbol: "person", order: 0),
                             .init(id: p2, name: "Other", symbol: "person", order: 1)]
        snapshot.groups = [.init(id: g1, profileID: p1, name: "Outgoing", order: 0,
                                tabs: oldTabs.map { document($0, qualified: true) }, activeTabID: oldTabs.last?.id)]
        if !sameGroup { snapshot.groups.append(.init(id: g2, profileID: targetProfile, name: "Selected group", order: profile ? 0 : 1,
                                                     tabs: targetTabs.map { document($0, qualified: qualified) }, activeTabID: targetTabs.first?.id)) }
        snapshot.groups.append(.init(id: g3, profileID: p2, name: "Other group", order: profile ? 1 : 0, tabs: [], activeTabID: nil))
        snapshot.scenes[scene] = .init(profileID: p1, groupID: g1)
        snapshot.lastActiveSceneID = scene
        try persistence.save(snapshot)
        store = .init(persistence: persistence, canonicalSessionURL: directory.appendingPathComponent("unused-canonical.json"))
        manager = .init(); manager.openTabs = oldTabs; manager.activeTabId = oldTabs.last?.id
        manager.selectedBook = oldTabs.last?.book
        workspace = .init(sceneID: scene, store: store)
        workspace.fixtureConnect(manager, groupID: g1)
        if warm { workspace.fixtureCache(targetTabs, groupID: g2) }
    }
    isolated deinit { try? FileManager.default.removeItem(at: directory) }
    func reserve(profile: Bool = false) throws -> StudyWorkspaceNativeGroupSelectionReservation {
        try workspace.reserveNativeGroupSelection(requestID: UUID(), profileID: targetProfile,
            groupID: g2, selectsProfile: profile, manager: manager, backendObservation: StudyWorkspaceGroupBackendObservation(),
            prepared: workspace.captureNativeGroupSelection(profileID: targetProfile, groupID: g2, selectsProfile: profile, manager: manager))
    }
    func prepared(profile: Bool = false) async throws -> StudyWorkspaceNativeGroupSelectionReservation {
        let owner = try reserve(profile: profile)
        try await workspace.prepareNativeGroupSelection(owner, validate: {})
        return owner
    }
    func apply(_ owner: StudyWorkspaceNativeGroupSelectionReservation, validate: @MainActor () throws -> Void = {}) throws {
        try workspace.applyNativeGroupSelection(owner, validate: validate)
    }
}

@main struct GroupOwnerControls {
    @MainActor static func main() async {
        var passed = 0, failed = 0
        func require(_ value: Bool, _ reason: String) throws { if !value { throw ControlFailure.expected(reason) } }
        func refuses(_ run: () throws -> Void) -> Bool { do { try run(); return false } catch { return true } }
        func test(_ name: String, _ body: @MainActor () async throws -> Void) async {
            do { try await body(); passed += 1; print("PASS " + name) }
            catch { failed += 1; print("FAIL \(name): \(error)") }
        }
        await test("warm group retains actual original Readers and only selects saved active tab") {
            let f = try GroupFixture(); let before = f.workspace.mappingOwnershipObservation()!
            let r = try await f.prepared(); try f.apply(r)
            try require(r.policy.phase == .committed && f.workspace.group?.id == f.g2, "actual selected group")
            try require(f.manager.openTabs.map(\.id) == f.targetTabs.map(\.id), "exact target order")
            try require(f.manager.openTabs[0].viewModel === f.targetTabs[0].viewModel, "reuse original Reader")
            try require(f.manager.selectedBook === f.targetTabs[0].book && f.manager.selectedBookPresentationMode == .viewer, "original selectTab")
            try require(f.manager.persistCalls == [false, true], "original session calls")
            try require(BackendCoordinator.shared.activeBackendID == .otzaria && BackendCoordinator.shared.generation == 0, "no backend switch")
            try require(r.policy.epoch.sourceID == before.epoch.sourceID && r.policy.epoch.revision == before.epoch.revision + 1, "one preadmission reservation")
            try require(f.store.snapshot?.groups.first(where: {$0.id == f.g1})?.tabs[0].session.scrollPosition?.y == 100, "original outgoing capture")
        }
        await test("profile uses actual first ordered group and changes Store profile together") {
            let f = try GroupFixture(profile: true); let r = try await f.prepared(profile: true); try f.apply(r)
            try require(f.workspace.profile?.id == f.p2 && f.workspace.group?.id == f.g2, "actual original first group")
            try require(f.store.snapshot?.groups.first(where: {$0.id == f.g3})?.tabs.isEmpty == true, "other group untouched")
        }
        await test("same group invokes original no-op selectTab without selectedBook write") {
            let f = try GroupFixture(sameGroup: true); let revision = f.manager.selectedBookPresentationRevision
            let r = try await f.prepared(); try f.apply(r)
            try require(f.manager.selectedBookPresentationRevision == revision, "zero declared book publications")
            try require(f.manager.persistCalls == [true], "no-op original selection")
        }
        await test("empty group runs original close loop and exact final overview false") {
            let f = try GroupFixture(empty: true); let revision = f.manager.selectedBookPresentationRevision!
            let r = try await f.prepared(); try f.apply(r)
            try require(f.manager.openTabs.isEmpty && f.manager.activeTabId == nil && f.manager.selectedBook == nil, "original empty state")
            try require(f.manager.selectedBookPresentationRevision == revision + 1 && !f.manager.showingTabsList, "original final close bookkeeping")
            try require(f.manager.persistCalls == [true, true, true], "both original closes and final checkpoint")
        }
        await test("already empty original group remains original empty without invented selection") {
            let f = try GroupFixture(empty: true, oldCount: 0); let revision = f.manager.selectedBookPresentationRevision
            let r = try await f.prepared(); try f.apply(r)
            try require(f.manager.selectedBookPresentationRevision == revision && f.manager.openTabs.isEmpty, "no synthetic setter")
        }
        await test("qualified cold group uses actual hydrate state and one original issued content token") {
            let f = try GroupFixture(warm: false); let r = try await f.prepared(); try f.apply(r)
            let tab = f.manager.openTabs[0]
            try require(tab.viewModel !== f.targetTabs[0].viewModel, "actual new cold Reader")
            try require(tab.viewModel.searchText == "saved original query" && tab.viewModel.readerState.selectedRange == NSRange(location: 3, length: 2), "original hydrate state")
            try require(tab.viewModel.contentLoadCoordinator.currentRequestToken()?.generation == 1 && tab.viewModel.loadCalls == 1, "one original request")
        }
        await test("legacy unqualified cold route refuses before Store or native publication") {
            let f = try GroupFixture(warm: false, qualified: false); let before = f.store.snapshot; let tabs = f.manager.openTabs.map(\.id)
            let r = try f.reserve(); var rejected = false
            do { try await f.workspace.prepareNativeGroupSelection(r, validate: {}) } catch { rejected = true }
            try require(rejected && f.store.snapshot == before && f.manager.openTabs.map(\.id) == tabs, "truthful unavailable")
        }
        await test("original UI foreign group refuses without silent backend or document change") {
            let f = try GroupFixture(foreign: true); let before = f.store.snapshot; let tabs = f.manager.openTabs.map(\.id)
            var rejected = false
            do { try await f.workspace.switchGroup(to: f.g2, manager: f.manager) } catch { rejected = true }
            try require(rejected && f.store.snapshot == before && f.manager.openTabs.map(\.id) == tabs && BackendCoordinator.shared.activeBackendID == .otzaria, "foreign source unchanged")
        }
        await test("typed foreign group refuses before resolver preparation") {
            let f = try GroupFixture(foreign: true)
            try require(refuses { _ = try f.reserve() }, "foreign unavailable")
        }
        await test("profile first-group reorder during catalog await revokes retained source") {
            let f = try GroupFixture(profile: true); let r = try f.reserve(profile: true)
            ChavrusaTextTargetBackendBookResolver.shared.duringCatalog = {
                try f.store.transaction { value in
                    value.groups[value.groups.firstIndex(where: {$0.id == f.g3})!].order = -1
                }
            }
            var rejected = false; do { try await f.workspace.prepareNativeGroupSelection(r, validate: {}) } catch { rejected = true }
            try require(rejected && f.workspace.group?.id == f.g1 && f.manager.openTabs.map(\.id) == f.oldTabs.map(\.id), "original current untouched")
        }
        await test("inactive saved group A-B-A remains revoked") {
            let f = try GroupFixture(); let r = try await f.prepared()
            let index = f.store.snapshot!.groups.firstIndex(where: {$0.id == f.g2})!
            let name = f.store.snapshot!.groups[index].name
            try f.store.transaction { $0.groups[index].name = "changed" }
            try f.store.transaction { $0.groups[index].name = name }
            try require(refuses { try f.apply(r) } && f.manager.openTabs.map(\.id) == f.oldTabs.map(\.id), "Store publication ABA refused")
        }
        await test("backend A-B-A even with unchanged generation revokes during prepare") {
            let f = try GroupFixture(); let r = try f.reserve()
            ChavrusaTextTargetBackendBookResolver.shared.duringCatalog = {
                BackendCoordinator.shared.activeBackendID = .sefaria
                BackendCoordinator.shared.activeBackendID = .otzaria
            }
            var rejected = false; do { try await f.workspace.prepareNativeGroupSelection(r, validate: {}) } catch { rejected = true }
            try require(rejected && f.workspace.group?.id == f.g1, "backend ABA refused")
        }
        await test("equal foreign backend publication is not original terminal clear") {
            let f = try GroupFixture(); let r = try await f.prepared()
            BackendCoordinator.shared.pendingBackendID = nil
            try require(refuses { try f.apply(r) }, "equal event refused")
        }
        await test("foreign selectedBook equal publication revokes before apply") {
            let f = try GroupFixture(); let r = try await f.prepared()
            f.manager.selectedBook = f.manager.selectedBook
            try require(refuses { try f.apply(r) } && f.workspace.group?.id == f.g1, "same pointer setter refused")
        }
        await test("foreign overview A-B-A publication revokes before apply") {
            let f = try GroupFixture(); let r = try await f.prepared()
            f.manager.showingTabsList = true; f.manager.showingTabsList = false
            try require(refuses { try f.apply(r) }, "real overview source ABA refused")
        }
        await test("equal foreign native tabs publication revokes") {
            let f = try GroupFixture(); let r = try await f.prepared()
            f.manager.openTabs = f.manager.openTabs
            try require(refuses { try f.apply(r) }, "array setter refused")
        }
        await test("book publication overflow refuses before any Store write") {
            let f = try GroupFixture(); f.manager.fixtureBookRevision(.max)
            let before = f.store.snapshot; let r = try f.reserve(); var rejected = false
            do { try await f.workspace.prepareNativeGroupSelection(r, validate: {}) } catch { rejected = true }
            try require(rejected && f.store.snapshot == before, "overflow not recycled")
        }
        await test("Store revision overflow refuses native preparation") {
            let f = try GroupFixture(); var snapshot = f.store.snapshot!; snapshot.revision = .max
            try f.persistence.save(snapshot)
            let store = StudyWorkspaceStore(persistence: f.persistence)
            let adapter = StudyWorkspaceNavigationAdapter(sceneID: f.scene, store: store)
            adapter.fixtureConnect(f.manager, groupID: f.g1)
            try require(refuses { _ = try adapter.reserveNativeGroupSelection(requestID: UUID(), profileID: f.p1, groupID: f.g2, selectsProfile: false, manager: f.manager, backendObservation: StudyWorkspaceGroupBackendObservation(), prepared: adapter.captureNativeGroupSelection(profileID: f.p1, groupID: f.g2, selectsProfile: false, manager: f.manager)) }, "Store overflow refused")
        }
        await test("original flush callback revalidation precedes first persistent group write") {
            let f = try GroupFixture(); let r = try await f.prepared(); let before = f.store.snapshot
            let snapshots = SnapshotProbe(f.directory.appendingPathComponent("backend"))
            snapshots.flushHook = { f.manager.selectedBook = f.manager.selectedBook }
            BackendCoordinator.shared.activeSessionSnapshots = snapshots
            try require(refuses { try f.apply(r) } && f.store.snapshot == before && f.manager.openTabs.map(\.id) == f.oldTabs.map(\.id), "postflush source checked")
            try require(snapshots.events == ["sync-begin", "flush"], "snapshot rollback scope ended on error")
        }
        await test("post-Store observer change prevents first native tab installation") {
            let f = try GroupFixture(); let r = try await f.prepared()
            let probe = PassiveStoreProbe(); probe.did = { f.manager.selectedBook = f.manager.selectedBook }
            let token = f.store.observeSnapshotPublication(probe); defer { f.store.removeSnapshotPublicationObserver(token) }
            try require(refuses { try f.apply(r) } && f.manager.openTabs.map(\.id) == f.oldTabs.map(\.id), "no native effect after observer change")
            try require(f.workspace.group?.id == f.g2, "actual durable Store effect remains visible, never fake rollback")
        }
        await test("release during original outgoing-state capture prevents Store write") {
            let f = try GroupFixture(); let r = try await f.prepared(); let before = f.store.snapshot
            f.oldTabs[0].viewModel.fetchScrollPosition = { f.workspace.releaseNativeGroupSelection(r); return .zero }
            try require(refuses { try f.apply(r) } && f.store.snapshot == before && f.manager.openTabs.map(\.id) == f.oldTabs.map(\.id), "retired owned call cannot become ordinary UI call")
        }
        await test("release during original load prevents later original selectTab") {
            let f = try GroupFixture(warm: false); let r = try await f.prepared()
            let beforeActive = f.manager.activeTabId; let beforeBook = f.manager.selectedBook
            r.prepared.staged[0].viewModel.duringLoad = { f.workspace.releaseNativeGroupSelection(r) }
            try require(refuses { try f.apply(r) }, "retired source refused")
            try require(f.manager.activeTabId == beforeActive && f.manager.selectedBook === beforeBook, "no later selection effect")
        }
        await test("foreign token reentry during original load prevents later selection") {
            let f = try GroupFixture(warm: false); let r = try await f.prepared(); let beforeActive = f.manager.activeTabId
            let tab = r.prepared.staged[0]
            tab.viewModel.duringLoad = { tab.viewModel.loadBackendContent(tab.book.backendLocator!) }
            try require(refuses { try f.apply(r) } && f.manager.activeTabId == beforeActive, "two original tokens cannot consume one load")
        }
        await test("original session callback release remains uncertain after native effect") {
            let f = try GroupFixture(); let r = try await f.prepared()
            f.manager.afterPersist = { f.workspace.releaseNativeGroupSelection(r) }
            try require(refuses { try f.apply(r) }, "release cannot be acknowledged")
            try require(f.manager.activeTabId == f.targetTabs[0].id, "real partial selection not hidden")
        }
        await test("owned terminal clear rejects nested foreign publication") {
            let f = try GroupFixture(); let r = try await f.prepared()
            BackendCoordinator.shared.objectWillChange.beforeSend = { BackendCoordinator.shared.pendingBackendID = nil }
            try require(refuses { try f.apply(r) }, "no callback-wide backend permit")
        }
        await test("exact ordinary postcommit checkpoint preserves one retained source") {
            let f = try GroupFixture(); let r = try await f.prepared(); try f.apply(r)
            let epoch = r.policy.epoch; let beforeRevision = f.store.snapshot!.revision
            f.manager.openTabs[0].viewModel.readerState.scrollPosition = CGPoint(x: 0, y: 991)
            f.workspace.synchronize(f.manager)
            try f.workspace.validateNativeGroupSelection(r)
            try require(r.policy.epoch == epoch && f.store.snapshot!.revision == beforeRevision + 1, "same source and real saved revision")
            try require(f.workspace.group!.tabs[0].session.scrollPosition?.y == 991, "actual saved viewport")
        }
        await test("foreign postcommit no-op Store transaction still revokes") {
            let f = try GroupFixture(); let r = try await f.prepared(); try f.apply(r)
            try f.store.transaction { _ in }
            try require(refuses { try f.workspace.validateNativeGroupSelection(r) }, "unowned same-value Store publication")
        }
        await test("postcommit real content-token replacement revokes") {
            let f = try GroupFixture(); let r = try await f.prepared(); try f.apply(r)
            let tab = f.manager.openTabs[0]; tab.viewModel.loadBackendContent(tab.book.backendLocator!)
            try require(refuses { try f.workspace.validateNativeGroupSelection(r) }, "original request identity retained")
        }
        await test("normal original UI selection stays executable after native owner release") {
            let f = try GroupFixture(); let r = try await f.prepared(); f.workspace.releaseNativeGroupSelection(r)
            try await f.workspace.switchGroup(to: f.g2, manager: f.manager)
            try require(f.workspace.group?.id == f.g2 && f.manager.openTabs.map(\.id) == f.targetTabs.map(\.id), "original UI preserved")
        }
        await test("synchronous original snapshot rollback restores exact existing bytes") {
            let f = try GroupFixture(); let adapter = BackendNavigationAdapter(storageDirectory: f.directory.appendingPathComponent("snapshot"))
            let original = Data("existing exact bytes".utf8), next = Data("new exact bytes".utf8)
            try adapter.saveBackendSessionSnapshot(backend: .otzaria, sessionData: original)
            do {
                try adapter.withSynchronousSnapshotRollback {
                    try adapter.saveBackendSessionSnapshot(backend: .otzaria, sessionData: next)
                    try adapter.flushStagedSnapshots()
                    throw ControlFailure.expected("original beforeCommit failure")
                }
            } catch {}
            try require(adapter.retrieveBackendSessionSnapshot(backend: .otzaria) == original, "exact previous bytes restored")
        }
        await test("synchronous original snapshot rollback restores original missing file") {
            let f = try GroupFixture(); let adapter = BackendNavigationAdapter(storageDirectory: f.directory.appendingPathComponent("snapshot"))
            do {
                try adapter.withSynchronousSnapshotRollback {
                    try adapter.saveBackendSessionSnapshot(backend: .otzaria, sessionData: Data("staged".utf8))
                    try adapter.flushStagedSnapshots()
                    throw ControlFailure.expected("failed")
                }
            } catch {}
            try require(adapter.retrieveBackendSessionSnapshot(backend: .otzaria) == nil, "original absence restored")
        }
        await test("sync rollback refuses nesting with original async rollback owner") {
            let f = try GroupFixture(); let adapter = BackendNavigationAdapter(storageDirectory: f.directory.appendingPathComponent("snapshot"))
            var rejected = false
            try await adapter.withSnapshotRollback {
                rejected = refuses { try adapter.withSynchronousSnapshotRollback {} }
            }
            try require(rejected, "same original staging owner")
            try adapter.withSynchronousSnapshotRollback {}
        }
        print("RESULT " + String(data: try! JSONSerialization.data(withJSONObject: ["passed": passed, "failed": failed, "scope": "actual source + explicit domain/Apple boundary controls", "native": "NOT_RUN"], options: [.sortedKeys]), encoding: .utf8)!)
        if failed > 0 { exit(1) }
    }
}
