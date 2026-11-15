import Foundation
#if os(Windows)
import ucrt
#elseif canImport(Darwin)
import Darwin
#else
import Glibc
#endif

@main struct WorkspaceStartupRaceRegression {
    @MainActor static func main() async throws {
        var failures: [String] = []
        var checks = 0
        func check(_ result: Bool, _ name: String) {
            checks += 1
            if !result { failures.append(name); print("FAIL: \(name)") }
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("r27-workspace-race-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        func make(_ backend: BackendID, _ label: String) -> (StudyWorkspaceStore, StudyWorkspaceNavigationAdapter, iOSNavigationManager) {
            BackendCoordinator.shared.activeBackendID = backend
            BackendCoordinator.shared.generation = 0
            BackendCoordinator.shared.commitGate = nil
            ChavrusaTextTargetBackendBookResolver.shared.catalogGate = nil
            let dir = root.appendingPathComponent(backend.rawValue + "-" + label)
            let store = StudyWorkspaceStore(persistence: .init(url: dir.appendingPathComponent("workspace.json")),
                                            canonicalSessionURL: dir.appendingPathComponent("absent-canonical.json"))
            return (store, StudyWorkspaceNavigationAdapter(sceneID: "fixture-scene", store: store), iOSNavigationManager())
        }
        func tab(_ backend: BackendID) -> iOSNavigationManager.ReaderTab {
            let book = BooksData(id: 1, title: "Genesis", backendLocator: .init(backend: backend, workKey: "Genesis"))
            return .init(id: UUID(), book: book, viewModel: ReaderViewModel(book: book))
        }
        func document(_ tab: iOSNavigationManager.ReaderTab, _ backend: BackendID) -> ReaderDocumentTab {
            .init(backend: backend, session: .init(id: tab.id, bookId: tab.book.id,
                                                 bookTitle: tab.book.title, backendLocator: tab.book.backendLocator))
        }
        func disk(_ backend: BackendID, _ label: String) throws -> StudyWorkspaceSnapshot? {
            try StudyWorkspacePersistence(url: root.appendingPathComponent(backend.rawValue + "-" + label)
                .appendingPathComponent("workspace.json")).load()
        }

        for backend in BackendID.allCases {
            // Positive control: canonical tabs already exist at attach entry.
            do {
                let (store, adapter, manager) = make(backend, "existing")
                let original = tab(backend)
                manager.publishOpen(original)
                await adapter.attach(manager)
                check(manager.openTabs.map(\.id) == [original.id], "\(backend) existing tab preserved")
                check(manager.openTabs.first?.viewModel === original.viewModel, "\(backend) existing VM identity preserved")
                check(store.selectedGroup(scene: "fixture-scene")?.tabs.map(\.id) == [original.id], "\(backend) existing sidecar retained")
            }
            // Positive control: a deliberately saved empty group must still
            // suppress a stale canonical session without any concurrent open.
            do {
                let (store, adapter, manager) = make(backend, "intentional-empty")
                try store.attach(scene: "fixture-scene", legacyTabs: [], activeID: nil)
                let stale = tab(backend)
                manager.publishOpen(stale)
                await adapter.attach(manager)
                check(manager.openTabs.isEmpty, "\(backend) intentional empty group remains empty")
                check(store.selectedGroup(scene: "fixture-scene")?.tabs.isEmpty == true, "\(backend) empty group not imported twice")
            }
            // Force a real MainActor suspension at each asynchronous boundary.
            // No DEBUG/smoke flag, UI hierarchy, window precondition or renderer.
            for phase in ["catalog", "before-commit"] {
                let (store, adapter, manager) = make(backend, phase)
                let gate = SuspensionGate()
                if phase == "catalog" { ChavrusaTextTargetBackendBookResolver.shared.catalogGate = gate }
                else { BackendCoordinator.shared.commitGate = gate }
                let restore = Task { await adapter.attach(manager) }
                await gate.waitUntilSuspended()
                let first = tab(backend)
                let opened = tab(backend)
                opened.viewModel.nearDistance = 23
                opened.viewModel.currentLocator = opened.book.backendLocator
                manager.publishOpen(first)
                manager.publishOpen(opened) // Models an actual native open-tab publication.
                gate.release()
                await restore.value
                check(manager.openTabs.map(\.id) == [first.id, opened.id], "\(backend) \(phase) concurrent tabs/order not overwritten")
                check(manager.openTabs.last?.viewModel === opened.viewModel && manager.openTabs.first?.viewModel === first.viewModel,
                      "\(backend) \(phase) VMs not recreated")
                check(manager.activeTabId == opened.id && manager.openTabs.contains(where: { $0.id == opened.id }), "\(backend) \(phase) active ID remains valid")
                check(store.selectedGroup(scene: "fixture-scene")?.tabs.map(\.id) == [first.id, opened.id], "\(backend) \(phase) concurrent tabs checkpointed")
                check(adapter.errorMessage == nil, "\(backend) \(phase) startup reconciled without false error")
                let saved = try disk(backend, phase)
                let savedGroup = saved?.groups.first
                let sceneActiveID = savedGroup.flatMap { saved?.scenes["fixture-scene"]?.activeTabIDsByGroup?[$0.id] }
                check(savedGroup?.tabs.map(\.id) == [first.id, opened.id] && savedGroup?.activeTabID == opened.id &&
                      sceneActiveID == opened.id,
                      "\(backend) \(phase) real JSON reload preserves tabs and active UUID")
                check(savedGroup?.tabs.last?.session.nearDistance == 23 && savedGroup?.tabs.last?.session.locator == opened.book.backendLocator,
                      "\(backend) \(phase) real JSON reload preserves reader state")
                adapter.synchronize(manager)
                check(store.selectedGroup(scene: "fixture-scene")?.tabs.map(\.id) == [first.id, opened.id],
                      "\(backend) \(phase) adopted group supports subsequent checkpoint")
            }
            for phase in ["catalog", "before-commit"] {
                for change in ["generation", "backend", "scene", "target", "cancel", "foreign-live"] {
                    let label = phase + "-" + change
                    let (store, adapter, manager) = make(backend, label)
                    let gate = SuspensionGate()
                    if phase == "catalog" { ChavrusaTextTargetBackendBookResolver.shared.catalogGate = gate }
                    else { BackendCoordinator.shared.commitGate = gate }
                    let restore = Task { await adapter.attach(manager) }
                    await gate.waitUntilSuspended()
                    let otherBackend = BackendID.allCases.first { $0 != backend }!
                    let opened = tab(change == "foreign-live" ? otherBackend : backend)
                    manager.publishOpen(opened)
                    switch change {
                    case "generation": BackendCoordinator.shared.generation += 1
                    case "backend": BackendCoordinator.shared.activeBackendID = otherBackend
                    case "scene":
                        let profileID = store.snapshot!.profiles[0].id
                        let newGroup = try store.addGroup(profileID: profileID, name: "New intent")
                        try store.transaction { $0.scenes["fixture-scene"]?.groupID = newGroup }
                    case "target":
                        try store.saveTabs([document(tab(backend), backend)], activeID: nil, groupID: adapter.group!.id)
                    case "cancel": restore.cancel()
                    default: break
                    }
                    let before = store.snapshot
                    gate.release()
                    await restore.value
                    let reloaded = try disk(backend, label)
                    check(manager.openTabs.map(\.id) == [opened.id] && manager.openTabs.first?.viewModel === opened.viewModel,
                          "\(backend) \(label) rejected restore preserves real live tab/VM")
                    check(manager.activeTabId == opened.id && manager.persisted == 0 && manager.closed.isEmpty,
                          "\(backend) \(label) no stale native publication")
                    check(store.snapshot == before && reloaded == before,
                          "\(backend) \(label) sidecar unchanged in memory and on disk")
                    check(adapter.errorMessage != nil && !adapter.isSwitching,
                          "\(backend) \(label) rejects stale/cancelled authority")
                }
                // A nonempty saved group remains authoritative at startup.
                do {
                    let label = phase + "-saved-nonempty"
                    let (store, adapter, manager) = make(backend, label)
                    let saved = tab(backend)
                    try store.attach(scene: "fixture-scene", legacyTabs: [document(saved, backend)], activeID: saved.id)
                    let gate = SuspensionGate()
                    if phase == "catalog" { ChavrusaTextTargetBackendBookResolver.shared.catalogGate = gate }
                    else { BackendCoordinator.shared.commitGate = gate }
                    let restore = Task { await adapter.attach(manager) }
                    await gate.waitUntilSuspended()
                    manager.publishOpen(tab(backend))
                    gate.release()
                    await restore.value
                    check(manager.openTabs.map(\.id) == [saved.id] && manager.activeTabId == saved.id,
                          "\(backend) \(phase) nonempty saved projection restored")
                    check(store.selectedGroup(scene: "fixture-scene")?.tabs.map(\.id) == [saved.id] && adapter.errorMessage == nil,
                          "\(backend) \(phase) saved group not replaced by live startup tabs")
                }
            }
            // Explicit empty-group selection after attach must not use startup adoption.
            do {
                let (store, adapter, manager) = make(backend, "explicit-empty")
                await adapter.attach(manager)
                let id = try store.addGroup(profileID: store.snapshot!.profiles[0].id, name: "Explicit empty")
                let gate = SuspensionGate()
                BackendCoordinator.shared.commitGate = gate
                let transition = Task { try await adapter.switchGroup(to: id, manager: manager) }
                await gate.waitUntilSuspended()
                manager.publishOpen(tab(backend))
                gate.release()
                try await transition.value
                check(manager.openTabs.isEmpty && adapter.group?.id == id && adapter.group?.tabs.isEmpty == true,
                      "\(backend) explicit empty selection never adopts startup projection")
            }
        }
        let summary = "\(checks - failures.count)/\(checks) deterministic adapter/store assertions; native UI tests 0"
        print(failures.isEmpty ? "PASS: " + summary : "FAIL: " + summary)
        if !failures.isEmpty { exit(1) }
    }
    enum RegressionFailure: Error { case failed(Int) }
}
