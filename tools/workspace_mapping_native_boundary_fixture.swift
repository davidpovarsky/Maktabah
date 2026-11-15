import Foundation
import Observation

// Only the Apple native manager/book/view-model shell is doubled. The runner
// inserts the complete exact producer block from the actual downstream adapter.
@MainActor final class BackendCoordinator {
    static let shared = BackendCoordinator()
    var activeBackendID: BackendID = .otzaria
    var generation: UInt64 = 0
    var beforeNextCommit: (() throws -> Void)?
    func commitCheckedAsync(_ backend: BackendID, beforeCommit: () throws -> Void = {}, publish: () -> Void = {}) async throws {
        await Task.yield()
        let hook = beforeNextCommit
        beforeNextCommit = nil
        try hook?()
        try beforeCommit()
        activeBackendID = backend
        publish()
    }
}
enum BackendTransitionError: Error { case transitionSuperseded }
@MainActor final class ChavrusaTextTargetBackendBookResolver {
    static let shared = ChavrusaTextTargetBackendBookResolver()
    func withTargetCatalog<T>(in backend: BackendID, operation: () async throws -> T) async throws -> T {
        await Task.yield()
        return try await operation()
    }
    func resolveBook(id: Int, backendLocator: String?, title: String?, in backend: BackendID) throws -> MappingFixtureBook {
        .init(id, key: backendLocator ?? "fixture", backend: backend)
    }
}
@MainActor final class MappingFixtureBook {
    let id: Int
    var backendLocator: TextLocator?
    init(_ id: Int, key: String, backend: BackendID = .otzaria) {
        self.id = id
        backendLocator = .init(backend: backend, workKey: key, position: .legacyLine(0))
    }
}
@MainActor final class MappingFixtureReader {
    var renderRevision = 0
    var contentText = ""
    var needsScrollRestore = false
    var loadCalls = 0
    func loadBackendContent(_ locator: TextLocator) { loadCalls += 1 }
    func loadInitialContent(initialContentId: Int?) { loadCalls += 1 }
    func loadTOC(book: MappingFixtureBook) { loadCalls += 1 }
}

@MainActor @Observable final class iOSNavigationManager {
    struct ReaderTab: Identifiable, Equatable {
        let id: UUID
        let book: MappingFixtureBook
        var initialContentId: Int?
        var viewModel: MappingFixtureReader
        static func == (lhs: ReaderTab, rhs: ReaderTab) -> Bool { lhs.id == rhs.id }
    }
    @ObservationIgnored let installed: Bool
    var persistCalls = 0
    var openTabs: [ReaderTab] = [] {
        willSet { if installed { StudyWorkspaceNavigationAdapter.nativeMappingTabsWillChange(self, to: newValue) } }
        didSet { if installed { StudyWorkspaceNavigationAdapter.nativeMappingDidChange(self) } }
    }
    var activeTabId: UUID? {
        willSet { if installed { StudyWorkspaceNavigationAdapter.nativeMappingSelectionWillChange(self, to: newValue) } }
        didSet { if installed { StudyWorkspaceNavigationAdapter.nativeMappingDidChange(self) } }
    }
    init(installed: Bool) {
        self.installed = installed
        if installed { StudyWorkspaceNavigationAdapter.nativeMappingOwnerInitialized(self) }
    }
    isolated deinit {
        if installed { StudyWorkspaceNavigationAdapter.nativeMappingOwnerWillDeinitialize(self) }
    }
    func selectTab(id: UUID) { activeTabId = id }
    func closeTab(id: UUID) {
        openTabs.removeAll { $0.id == id }
        if activeTabId == id { activeTabId = openTabs.first?.id }
    }
    func persistCurrentSession(immediate: Bool) { persistCalls += 1 }
}

@MainActor @Observable final class StudyWorkspaceNavigationAdapter {
    let sceneID: String
    let store: StudyWorkspaceStore
    private(set) var attached = false
    private var liveGroupID: UUID?
    private var liveBackend: BackendID?
    private(set) var isSwitching = false
    var errorMessage: String?
    private var cache: [UUID: [BackendID: [iOSNavigationManager.ReaderTab]]] = [:]
    var selection: StudySceneSelection? { store.snapshot?.scenes[sceneID] }
    var group: StudyTabGroup? { store.selectedGroup(scene: sceneID) }
    init(sceneID: String, store: StudyWorkspaceStore) { self.sceneID = sceneID; self.store = store }
    func fixtureConnect(_ manager: iOSNavigationManager, groupID: UUID, backend: BackendID = .otzaria) {
        bindMappingOwner(manager)
        attached = true
        setMappingLiveContext(groupID: groupID, backend: backend, manager: manager)
    }
    // ACTUAL_PRODUCER_BLOCK
    // ACTUAL_STARTUP_METHODS
    private func capture(_ tabs: [iOSNavigationManager.ReaderTab], backend: BackendID) -> [ReaderDocumentTab] {
        tabs.map { .init(backend: backend, session: .init(id: $0.id, bookId: $0.book.id,
            backendLocator: $0.book.backendLocator, contentId: $0.initialContentId, locator: $0.book.backendLocator)) }
    }
    private func matches(_ tab: iOSNavigationManager.ReaderTab, _ document: ReaderDocumentTab) -> Bool {
        tab.id == document.id && tab.book.id == document.session.bookId && tab.book.backendLocator?.workKey == document.session.backendLocator?.workKey
    }
    private func hydrate(_ document: ReaderDocumentTab) throws -> iOSNavigationManager.ReaderTab {
        .init(id: document.id, book: .init(document.session.bookId, key: document.session.backendLocator?.workKey ?? "fixture", backend: document.backend),
            initialContentId: document.session.contentId, viewModel: .init())
    }
}

@MainActor enum MappingNativeBoundaryChecks {
    private struct Failure: Error { let name: String }
    private final class Subscriber { var calls = 0 }
    private final class Admission { var valid = true; var revocations = 0 }
    private final class ReadyReader {
        weak var adapter: StudyWorkspaceNavigationAdapter?
        weak var admission: Admission?
    }
    static func run(root: URL) throws -> Int {
        var count = 0
        func expect(_ value: Bool, _ name: String) throws {
            guard value else { throw Failure(name: name) }
            count += 1
            print("PASS NATIVE_BOUNDARY[\(count)] \(name)")
        }
        let store = StudyWorkspaceStore(persistence: .init(url: root.appendingPathComponent("native/workspace.json")),
            canonicalSessionURL: root.appendingPathComponent("no-session.json"))
        let idA = UUID(), idB = UUID()
        func saved(_ id: UUID, _ book: Int) -> ReaderDocumentTab {
            .init(backend: .otzaria, session: .init(id: id, bookId: book,
                backendLocator: .init(backend: .otzaria, workKey: "book:\(book)", position: .legacyLine(0))))
        }
        try store.attach(scene: "native", legacyTabs: [saved(idA, 17), saved(idB, 18)], activeID: idA)
        let group = store.selectedGroup(scene: "native")!
        let a = iOSNavigationManager.ReaderTab(id: idA, book: .init(17, key: "book:17"), viewModel: .init())
        let b = iOSNavigationManager.ReaderTab(id: idB, book: .init(18, key: "book:18"), viewModel: .init())
        let unhooked = iOSNavigationManager(installed: false)
        unhooked.openTabs = [a, b]; unhooked.activeTabId = idA
        let unavailableAdapter = StudyWorkspaceNavigationAdapter(sceneID: "native", store: store)
        unavailableAdapter.fixtureConnect(unhooked, groupID: group.id)
        try expect(unavailableAdapter.mappingOwnershipObservation() == nil
            && unavailableAdapter.mappingOwnershipSource.mappingRevision == nil, "Store-only success cannot imply installed live-native coverage")

        var manager: iOSNavigationManager? = .init(installed: true)
        manager!.openTabs = [a, b]; manager!.activeTabId = idA
        var adapter: StudyWorkspaceNavigationAdapter? = .init(sceneID: "native", store: store)
        adapter!.fixtureConnect(manager!, groupID: group.id)
        let source = adapter!.mappingOwnershipSource
        let initial = adapter!.mappingOwnershipObservation()!
        try expect(initial.projection.activeTabID == idA && initial.projection.targets[idA]?.bookID == 17, "actual live qualified target projection")
        var admitted = true
        var callbacks = 0
        let observer = NativeBindingSourceObservation(readRevision: { source.mappingRevision }, onInvalidation: {
            admitted = false; callbacks += 1
        })
        var callbackReadmittedOldMapping = false
        withObservationTracking { _ = manager!.activeTabId } onChange: {
            MainActor.assumeIsolated {
                callbackReadmittedOldMapping = true
                admitted = true // Raw Observation is willSet; the old value is still visible.
            }
        }
        manager!.activeTabId = idB
        try expect(callbackReadmittedOldMapping && !admitted && adapter!.mappingOwnershipObservation()?.projection.activeTabID == idB,
            "live selection setter invalidates without delayed Store checkpoint")
        try expect(store.selectedGroup(scene: "native")?.activeTabID == idA, "test actually spans live-to-Store checkpoint gap")
        for _ in 0..<20 {
            admitted = true
            manager!.activeTabId = idA
            try expect(!admitted, "native ABA A invalidates before setter returns")
            admitted = true
            manager!.activeTabId = idB
            try expect(!admitted, "native ABA B invalidates intervening readmission")
        }
        let steady = source.event.epoch
        let calls = callbacks
        admitted = true
        manager!.activeTabId = idB
        manager!.openTabs.swapAt(0, 1)
        manager!.openTabs[0].initialContentId = 40
        b.viewModel.renderRevision += 1
        try store.saveTabs([saved(idA, 17), saved(idB, 18)], activeID: idA, groupID: group.id)
        try store.renameGroup(group.id, name: "presentation only")
        try expect(admitted && callbacks == calls && source.event.epoch == steady,
            "native no-op/order/render and identical Store checkpoint preserve binding")
        let otherGroup = try store.addGroup(profileID: group.profileID, name: "other group")
        var snapshotFenced = false
        withObservationTracking { _ = store.snapshot } onChange: {
            MainActor.assumeIsolated { snapshotFenced = adapter!.mappingOwnershipObservation() == nil }
        }
        try store.transaction { $0.scenes["native"]?.groupID = otherGroup }
        try expect(snapshotFenced && source.mappingRevision == nil,
            "changed Store selection cannot expose old live native mapping under a ready combined epoch")
        manager!.openTabs = []; manager!.activeTabId = nil
        adapter!.fixtureConnect(manager!, groupID: otherGroup)
        try expect(adapter!.mappingOwnershipObservation()?.projection.targets.isEmpty == true,
            "context becomes available only after actual native projection catches up")
        try store.transaction { $0.scenes["native"]?.groupID = group.id }
        manager!.openTabs = [a, b]; manager!.activeTabId = idB
        adapter!.fixtureConnect(manager!, groupID: group.id)
        manager!.activeTabId = nil
        let noActive = adapter!.mappingOwnershipObservation()!
        try expect(noActive.projection.activeTabID == nil && noActive.projection.targets.count == 2,
            "absent active target is not absence of background tabs; no first-tab fallback")
        manager!.activeTabId = UUID()
        try expect(adapter!.mappingOwnershipObservation() == nil && source.mappingRevision == nil,
            "stale active target fails closed instead of selecting first tab")
        manager!.activeTabId = idA
        let replaced = iOSNavigationManager.ReaderTab(id: idA, book: .init(99, key: "book:99"), viewModel: a.viewModel)
        manager!.openTabs = [replaced, b]
        try expect(source.event.reasons.contains(.targetIdentity), "same UUID book replacement classified")
        let newReader = iOSNavigationManager.ReaderTab(id: idA, book: replaced.book, viewModel: .init())
        manager!.openTabs = [newReader, b]
        try expect(source.event.reasons.contains(.ownerLifetime), "same target new reader lifetime classified")
        let beforeSlotMutation = source.event.epoch
        manager!.openTabs[0].viewModel = .init()
        try expect(source.event.epoch != beforeSlotMutation && source.event.reasons.contains(.ownerLifetime), "in-place view-model slot mutation is fenced despite native ID-only Equatable")
        let foreign = iOSNavigationManager.ReaderTab(id: idA, book: .init(99, key: "foreign", backend: .sefaria), viewModel: newReader.viewModel)
        manager!.openTabs = [foreign, b]
        try expect(source.event.reasons.contains(.backend) && adapter!.mappingOwnershipObservation() == nil,
            "incompatible backend replacement classified and unavailable")
        manager!.openTabs = [newReader, b]

        let stableBeforeFailure = source.event.epoch
        let callbacksBeforeFailure = callbacks
        let backup = root.appendingPathComponent("native/workspace.json.bak")
        if FileManager.default.fileExists(atPath: backup.path) { try FileManager.default.removeItem(at: backup) }
        try FileManager.default.createDirectory(at: backup, withIntermediateDirectories: false)
        var saveFailed = false
        do { try store.renameGroup(group.id, name: "must fail before invalidation") }
        catch { saveFailed = true }
        try expect(saveFailed && source.event.epoch == stableBeforeFailure && callbacks == callbacksBeforeFailure,
            "actual failed Store save preserves combined native producer and its admission")
        try FileManager.default.removeItem(at: backup)

        var subscriber: Subscriber? = Subscriber()
        var subscription: StudyWorkspaceMappingSubscription? = source.subscribe(owner: subscriber!) { owner, _ in owner.calls += 1 }
        manager!.activeTabId = idB
        try expect(subscriber!.calls > 0, "typed callback synchronous")
        subscription!.cancel()
        let cancelledCalls = subscriber!.calls
        manager!.activeTabId = idA
        try expect(subscriber!.calls == cancelledCalls, "deterministic typed subscription cancellation")
        subscription = source.subscribe(owner: subscriber!) { owner, _ in owner.calls += 1 }
        let oldSubscription = subscription
        subscription = source.subscribe(owner: subscriber!) { owner, _ in owner.calls += 1 }
        oldSubscription?.cancel()
        let beforeReplacement = subscriber!.calls
        manager!.activeTabId = idB
        try expect(subscriber!.calls == beforeReplacement + 2, "old subscription cleanup cannot cancel replacement; one bounded listener per owner")
        weak var weakSubscriber = subscriber
        subscriber = nil
        try expect(weakSubscriber == nil, "producer callback does not retain consumer")
        manager!.activeTabId = idB
        subscription = nil
        weakSubscriber = nil

        let admission = Admission()
        let readyReader = ReadyReader()
        readyReader.adapter = adapter
        readyReader.admission = admission
        let invalidationOnly = source.subscribeInvalidation(owner: admission) { owner, _ in
            owner.valid = false; owner.revocations += 1
        }
        let readyNotification = source.subscribe(owner: readyReader) { owner, event in
            if event.phase == .available, owner.adapter?.mappingOwnershipObservation() != nil {
                owner.admission?.valid = true
            }
        }
        manager!.activeTabId = idA
        try expect(admission.revocations == 1 && admission.valid,
            "post-publication readmission is not revoked by ready notifications or listener order")
        invalidationOnly.cancel(); readyNotification.cancel()

        admitted = true
        let beforeLifetimeEnd = callbacks
        manager = nil
        try expect(!admitted && callbacks > beforeLifetimeEnd && source.mappingRevision == nil && source.event.reasons == [.ownerLifetime],
            "native owner teardown invalidates a retained adapter source")
        observer.cancel()
        weak var weakAdapter = adapter
        adapter = nil
        try expect(weakAdapter == nil, "registry and Store listener do not retain adapter")
        weakAdapter = nil
        for backend in [BackendID.sefaria, .sefariaEmbedded] {
            BackendCoordinator.shared.activeBackendID = backend
            let signedID = UUID()
            let signedStore = StudyWorkspaceStore(persistence: .init(url: root.appendingPathComponent("native-signed-\(backend.rawValue)/workspace.json")), canonicalSessionURL: root.appendingPathComponent("none.json"))
            try signedStore.attach(scene: "signed", legacyTabs: [.init(backend: backend, session: .init(id: signedID, bookId: -17, backendLocator: .init(backend: backend, workKey: "Genesis", position: .canonicalRef("Genesis"))))], activeID: signedID)
            let signedManager = iOSNavigationManager(installed: true)
            signedManager.openTabs = [.init(id: signedID, book: .init(-17, key: "Genesis", backend: backend), viewModel: .init())]
            signedManager.activeTabId = signedID
            let signedAdapter = StudyWorkspaceNavigationAdapter(sceneID: "signed", store: signedStore)
            signedAdapter.fixtureConnect(signedManager, groupID: signedStore.selectedGroup(scene: "signed")!.id, backend: backend)
            try expect(signedAdapter.mappingOwnershipObservation()?.projection.targets[signedID]?.bookID == -17,
                "live \(backend.rawValue) signed legacy identity is observed without a second numeric permission policy")
        }
        print("PASS: \(count) exact adapter producer-body assertions against proposed-hook native boundary double; actual Apple/native setter installation remains NOT_RUN")
        return count
    }
}
