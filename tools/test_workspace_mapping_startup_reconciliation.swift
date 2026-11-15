import Foundation

/// Exercises the ACTUAL approved/reconciled attach and switchGroup method bodies.
/// The native manager/backend/catalog/hydration shell remains an explicit double.
@MainActor enum WorkspaceStartupReconciliationChecks {
    private struct Failure: Error { let name: String }
    static func run(root: URL) async throws {
        var checks = 0
        func expect(_ value: Bool, _ name: String) throws {
            guard value else { throw Failure(name: name) }
            checks += 1
            print("PASS STARTUP[\(checks)] \(name)")
        }
        let coordinator = BackendCoordinator.shared
        for backend in BackendID.allCases {
            coordinator.activeBackendID = backend
            coordinator.generation = 0
            let store = StudyWorkspaceStore(persistence: .init(url: root.appendingPathComponent("startup-\(backend.rawValue)/workspace.json")), canonicalSessionURL: root.appendingPathComponent("absent.json"))
            let manager = iOSNavigationManager(installed: true)
            let adapter = StudyWorkspaceNavigationAdapter(sceneID: "startup", store: store)
            let first = iOSNavigationManager.ReaderTab(id: UUID(), book: .init(17, key: "first", backend: backend), viewModel: .init())
            let selected = iOSNavigationManager.ReaderTab(id: UUID(), book: .init(-18, key: "selected", backend: backend), viewModel: .init())
            var sourceStayedUnavailable = false
            coordinator.beforeNextCommit = {
                manager.openTabs = [first, selected]
                manager.activeTabId = selected.id
                sourceStayedUnavailable = adapter.mappingOwnershipObservation() == nil && adapter.mappingOwnershipSource.mappingRevision == nil
            }
            await adapter.attach(manager)
            let group = store.selectedGroup(scene: "startup")!
            let observation = adapter.mappingOwnershipObservation()
            try expect(sourceStayedUnavailable, "\(backend.rawValue): late native open cannot expose ownership before live context publication")
            try expect(adapter.errorMessage == nil && adapter.attached && !adapter.isSwitching, "\(backend.rawValue): actual startup method completes")
            try expect(manager.openTabs.map(\.id) == [first.id, selected.id] && manager.activeTabId == selected.id,
                "\(backend.rawValue): approved startup adoption retains late tabs and requested selection")
            try expect(manager.openTabs[1].viewModel === selected.viewModel && selected.viewModel.loadCalls == 0,
                "\(backend.rawValue): adoption preserves actual late reader instance without hydration/reload")
            try expect(group.tabs.map(\.id) == [first.id, selected.id] && group.activeTabID == selected.id
                && group.tabs.allSatisfy { $0.backend == backend }, "\(backend.rawValue): actual Store transaction adopts correct group/backend/tab identity")
            try expect(observation?.projection.groupID == group.id && observation?.projection.activeTabID == selected.id
                && observation?.projection.targets[selected.id]?.bookID == -18, "\(backend.rawValue): producer becomes qualified only after coherent adoption")
        }

        coordinator.activeBackendID = .otzaria; coordinator.generation = 0
        let unhookedStore = StudyWorkspaceStore(persistence: .init(url: root.appendingPathComponent("startup-unhooked/workspace.json")), canonicalSessionURL: root.appendingPathComponent("absent.json"))
        let unhookedManager = iOSNavigationManager(installed: false)
        let unhookedAdapter = StudyWorkspaceNavigationAdapter(sceneID: "unhooked", store: unhookedStore)
        coordinator.beforeNextCommit = {
            let tab = iOSNavigationManager.ReaderTab(id: UUID(), book: .init(29, key: "unhooked"), viewModel: .init())
            unhookedManager.openTabs = [tab]; unhookedManager.activeTabId = tab.id
        }
        await unhookedAdapter.attach(unhookedManager)
        try expect(unhookedManager.openTabs.count == 1 && unhookedStore.selectedGroup(scene: "unhooked")?.tabs.count == 1,
            "unhooked native startup adoption remains functional")
        try expect(unhookedAdapter.mappingOwnershipObservation() == nil && unhookedAdapter.mappingOwnershipSource.mappingRevision == nil,
            "successful startup/Store adoption never fabricates missing native hook coverage")

        for drift in ["generation", "selection", "disk"] {
            coordinator.activeBackendID = .otzaria; coordinator.generation = 0
            let persistence = StudyWorkspacePersistence(url: root.appendingPathComponent("startup-drift-\(drift)/workspace.json"))
            let store = StudyWorkspaceStore(persistence: persistence, canonicalSessionURL: root.appendingPathComponent("absent.json"))
            let manager = iOSNavigationManager(installed: true)
            let adapter = StudyWorkspaceNavigationAdapter(sceneID: "drift", store: store)
            var intendedGroup: UUID?
            var snapshotBefore: StudyWorkspaceSnapshot?
            var bytesBefore: Data?
            let late = iOSNavigationManager.ReaderTab(id: UUID(), book: .init(88, key: "late"), viewModel: .init())
            coordinator.beforeNextCommit = {
                snapshotBefore = store.snapshot
                bytesBefore = try Data(contentsOf: persistence.url)
                if drift == "generation" { coordinator.generation += 1 }
                else if drift == "selection" {
                    let profile = store.snapshot!.scenes["drift"]!.profileID
                    let other = try store.addGroup(profileID: profile, name: "changed while awaiting")
                    intendedGroup = other
                    try store.transaction { $0.scenes["drift"]?.groupID = other }
                } else {
                    manager.openTabs = [late]; manager.activeTabId = late.id
                    try FileManager.default.createDirectory(at: persistence.backupURL, withIntermediateDirectories: false)
                }
            }
            await adapter.attach(manager)
            try expect(adapter.errorMessage != nil && !adapter.isSwitching && manager.persistCalls == 0,
                "\(drift): last throwing startup boundary rejects stale/failed publication")
            try expect(adapter.mappingOwnershipObservation() == nil && adapter.mappingOwnershipSource.mappingRevision == nil,
                "\(drift): failed startup never exposes coherent native mapping")
            if drift == "selection" {
                try expect(store.snapshot?.scenes["drift"]?.groupID == intendedGroup,
                    "selection: approved previousSelection guard preserves newer actual selection")
            } else {
                try expect(store.snapshot == snapshotBefore && (try? Data(contentsOf: persistence.url)) == bytesBefore,
                    "\(drift): actual failed transaction preserves original snapshot and disk bytes")
            }
            if drift == "disk" {
                try expect(manager.openTabs.first?.id == late.id && manager.openTabs.first?.viewModel === late.viewModel,
                    "disk: failed adoption cannot overwrite the live native open")
            }
        }
        coordinator.beforeNextCommit = nil
        print("PASS: \(checks) actual attach/switchGroup startup-producer interaction assertions; native/backend/catalog/hydration boundary doubles, no Apple/native acceptance")
    }
}
