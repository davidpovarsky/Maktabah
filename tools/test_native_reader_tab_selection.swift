import Foundation
import Observation

/// Actual Store/persistence/mapping and adapter setter/checkpoint bodies;
/// only the Apple Book/Reader/manager shell and UI visibility are boundaries.
@main struct NativeReaderTabOwnerControls {
    @MainActor final class Recorder {
        var passed = 0; var failed = 0
        func check(_ value: Bool, _ name: String) {
            if value { passed += 1; print("PASS \(name)") }
            else { failed += 1; print("FAIL \(name)") }
        }
        func rejects(_ name: String, _ operation: () throws -> Void) {
            do { try operation(); check(false, name) } catch { check(true, name) }
        }
        func run(_ name: String, _ operation: () throws -> Void) {
            do { try operation() } catch { check(false, "\(name): unexpected \(type(of: error))") }
        }
    }
    @MainActor final class Fixture {
        let root: URL
        let store: StudyWorkspaceStore
        let manager: iOSNavigationManager
        let adapter: StudyWorkspaceNavigationAdapter
        let a: iOSNavigationManager.ReaderTab
        let b: iOSNavigationManager.ReaderTab
        let group: StudyTabGroup
        init(root: URL, extraBackend: Bool = false) throws {
            self.root = root
            BackendCoordinator.shared.activeBackendID = .otzaria
            store = StudyWorkspaceStore(persistence: .init(url: root.appendingPathComponent("workspace.json")),
                                        canonicalSessionURL: root.appendingPathComponent("none.json"))
            a = .init(id: UUID(), book: .init(103, key: "book:103"), viewModel: .init())
            b = .init(id: UUID(), book: .init(103, key: "book:103"), viewModel: .init())
            func document(_ tab: iOSNavigationManager.ReaderTab, backend: BackendID = .otzaria) -> ReaderDocumentTab {
                .init(backend: backend, session: .init(id: tab.id, bookId: tab.book.id,
                    bookTitle: "Fixture", backendLocator: tab.book.backendLocator, locator: tab.book.backendLocator))
            }
            var saved = [document(a), document(b)]
            if extraBackend {
                saved.append(.init(backend: .sefaria, session: .init(id: UUID(), bookId: -103,
                    bookTitle: "Foreign", backendLocator: .init(backend: .sefaria, workKey: "Genesis",
                                                              position: .canonicalRef("Genesis")))))
            }
            try store.attach(scene: "window-a", legacyTabs: saved, activeID: a.id)
            group = store.selectedGroup(scene: "window-a")!
            manager = .init(installed: true)
            manager.openTabs = [a, b]; manager.activeTabId = a.id; manager.selectedBook = a.book
            adapter = .init(sceneID: "window-a", store: store)
            adapter.fixtureConnect(manager, groupID: group.id)
        }
        func reserve(_ target: UUID? = nil) throws -> StudyWorkspaceNativeTabSelectionReservation {
            try adapter.reserveNativeTabSelection(requestID: UUID(), tabID: target ?? b.id, manager: manager)
        }
        func apply(_ value: StudyWorkspaceNativeTabSelectionReservation) throws {
            try adapter.applyNativeTabSelection(value) { manager.selectTab(id: value.tab.id) }
        }
    }
    @MainActor final class Listener { var calls = 0; var sawUnavailable = false }
    @MainActor static func main() throws {
        let r = Recorder()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("reader-tab-controls-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        var number = 0
        func fixture(_ extraBackend: Bool = false) throws -> Fixture {
            number += 1
            return try Fixture(root: root.appendingPathComponent("case-\(number)"), extraBackend: extraBackend)
        }
        r.run("exact original selection") {
            let f = try fixture(), prior = f.adapter.mappingOwnershipObservation()!
            let v = try f.reserve()
            r.check(v.tab.book === f.b.book && v.tab.viewModel === f.b.viewModel, "reservation retains original duplicate-book tab objects")
            r.check(v.policy.epoch.revision == prior.epoch.revision + 1, "reservation retires previous native contract before admission")
            let nativeListener = Listener(), storedListener = Listener()
            let nativeSubscription = v.policy.source.subscribeInvalidation(owner: nativeListener) { owner, _ in owner.calls += 1 }
            let storedSubscription = v.policy.workspaceSource.subscribe(owner: storedListener) { owner, event in
                if event.phase == .changing {
                    owner.calls += 1
                    owner.sawUnavailable = f.adapter.mappingOwnershipObservation() == nil
                }
            }
            let storedEpoch = v.policy.workspaceEpoch
            try f.apply(v)
            r.check(v.policy.phase == .committed && f.manager.activeTabId == f.b.id, "original selectTab commits the exact tab")
            r.check(f.manager.openTabs.count == 2 && f.manager.openTabs[0].viewModel === f.a.viewModel
                    && f.manager.openTabs[1].viewModel === f.b.viewModel, "selection creates no Reader or tab and preserves duplicate book identities")
            r.check(f.a.viewModel.saveCalls == 1 && f.a.viewModel.closeCalls == 1
                    && f.b.viewModel.needsScrollRestore && f.manager.selectedBook === f.b.book,
                    "actual original selectTab body preserves outgoing save and incoming restore effects")
            r.check(nativeListener.calls == 0 && storedListener.calls == 1 && storedListener.sawUnavailable,
                    "owned store checkpoint cannot expose a partial mapping or revoke its own original native contract")
            r.check(v.policy.workspaceEpoch.sourceID == storedEpoch.sourceID
                    && v.policy.workspaceEpoch.revision == storedEpoch.revision + 1,
                    "actual original store advances exactly one retained scene epoch")
            let selected = f.store.snapshot!.scenes["window-a"]!
            r.check(selected.groupID == f.group.id && selected.profileID == f.group.profileID
                    && selected.activeTabIDsByGroup?[f.group.id] == f.b.id,
                    "real original per-scene profile group and tab persisted")
            let loaded = try StudyWorkspacePersistence(url: f.root.appendingPathComponent("workspace.json")).load()!
            r.check(loaded.scenes["window-a"] == selected, "real isolated persistence reload matches exact selected tab")
            try f.adapter.validateNativeTabSelection(v)
            r.check(true, "source-bound ownership remains valid through completion")
            nativeSubscription.cancel(); storedSubscription.cancel()
            f.adapter.releaseNativeTabSelection(v)
            r.rejects("released request cannot apply or validate again") { try f.adapter.validateNativeTabSelection(v) }
        }
        r.run("current tab no-op actual") {
            let f = try fixture(), v = try f.reserve(f.a.id)
            let old = v.policy.workspaceEpoch
            try f.apply(v)
            r.check(v.policy.phase == .committed && f.manager.activeTabId == f.a.id && f.a.viewModel.saveCalls == 0,
                    "already selected original tab remains an exact no-op action")
            r.check(v.policy.workspaceEpoch == old, "unchanged original store mapping is not given a manufactured new epoch")
        }
        r.run("foreign backend preservation") {
            let f = try fixture(true), foreign = f.store.selectedGroup(scene: "window-a")!.tabs.last!
            let v = try f.reserve(); try f.apply(v)
            r.check(f.store.selectedGroup(scene: "window-a")!.tabs.contains(foreign),
                    "original checkpoint preserves inactive foreign-backend document unchanged")
            r.check(BackendCoordinator.shared.activeBackendID == .otzaria, "selection never switches backend")
        }
        r.run("single consumption") {
            let f = try fixture(), v = try f.reserve()
            try f.apply(v)
            r.rejects("completed request cannot replay original selectTab") { try f.apply(v) }
            r.check(f.a.viewModel.saveCalls == 1, "rejected replay has no second original selection side effect")
        }
        r.run("live selection ABA") {
            let f = try fixture(), v = try f.reserve()
            f.manager.activeTabId = f.b.id; f.manager.activeTabId = f.a.id
            r.rejects("foreign A to B to A cannot revive original reservation") { try f.apply(v) }
        }
        r.run("equal original setter") {
            let f = try fixture(), v = try f.reserve()
            f.manager.activeTabId = f.a.id
            r.rejects("equal foreign setter cannot borrow owned publication allowance") { try f.apply(v) }
        }
        r.run("array publication") {
            let f = try fixture(), v = try f.reserve()
            f.manager.openTabs = [f.a, f.b]
            r.rejects("equal tab-array publication invalidates pending selection") { try f.apply(v) }
        }
        r.run("replacement original reader") {
            let f = try fixture(), v = try f.reserve()
            f.manager.openTabs[1].viewModel = .init()
            r.rejects("same tab ID with replacement Reader owner is stale") { try f.apply(v) }
        }
        r.run("replacement original book") {
            let f = try fixture(), v = try f.reserve()
            f.manager.openTabs[1] = .init(id: f.b.id, book: .init(104, key: "book:104"), viewModel: f.b.viewModel)
            r.rejects("same tab ID with changed book/work is stale") { try f.apply(v) }
        }
        r.run("reentrant setter") {
            let f = try fixture(), v = try f.reserve()
            f.manager.beforeSelectionPublication = { f.manager.activeTabId = f.b.id }
            r.rejects("second matching willSet inside owned original setter is rejected") { try f.apply(v) }
            r.check(v.policy.phase == .invalid, "reentrant publication cannot complete source proof")
        }
        r.run("outgoing save reentrancy") {
            let f = try fixture(), v = try f.reserve()
            f.a.viewModel.beforeSave = { f.manager.activeTabId = f.b.id; f.manager.activeTabId = f.a.id }
            r.rejects("outgoing original save callback cannot hide an ABA before canonical tab setter") { try f.apply(v) }
        }
        r.run("store selection ABA") {
            let f = try fixture(), v = try f.reserve()
            let other = try f.store.addGroup(profileID: f.group.profileID, name: "Other")
            try f.store.transaction { $0.scenes["window-a"]?.groupID = other }
            try f.store.transaction { $0.scenes["window-a"]?.groupID = f.group.id }
            r.rejects("original store group ABA invalidates pending source") { try f.apply(v) }
        }
        r.run("target removed") {
            let f = try fixture(), v = try f.reserve()
            f.manager.openTabs = [f.a]
            r.rejects("removed target cannot fall back to first tab") { try f.apply(v) }
        }
        r.run("target backend changed") {
            let f = try fixture(), v = try f.reserve()
            BackendCoordinator.shared.activeBackendID = .sefaria
            r.rejects("foreign backend cannot be selected under retained native mapping") { try f.apply(v) }
            BackendCoordinator.shared.activeBackendID = .otzaria
        }
        r.run("store failure after actual selection") {
            let f = try fixture(), v = try f.reserve()
            let blocked = f.root.appendingPathComponent("workspace.json.bak")
            try FileManager.default.createDirectory(at: blocked, withIntermediateDirectories: false)
            r.rejects("real original checkpoint failure cannot become completed") { try f.apply(v) }
            r.check(v.policy.phase == .invalid && f.manager.activeTabId == f.b.id,
                    "uncertain original effect is retained without fabricated rollback or receipt")
        }
        r.run("scope and admission") {
            let f = try fixture()
            r.rejects("unowned unknown tab ID is rejected before original action") { _ = try f.reserve(UUID()) }
            let v = try f.reserve()
            r.rejects("second selection reservation cannot replace original pending owner") { _ = try f.reserve(f.a.id) }
            let actual = f.adapter.mappingOwnershipObservation()!, stored = f.store.mappingObservation(scene: "window-a")!
            let otherOwner = Listener()
            let wrong = StudyWorkspaceMappingObservation(source: actual.source, owner: ObjectIdentifier(otherOwner),
                scene: actual.scene, epoch: actual.epoch, coverage: actual.coverage, projection: actual.projection)
            r.check(!v.policy.matches(wrong, workspace: stored), "same values with foreign native manager owner rejected")
            let wrongScene = StudyWorkspaceMappingObservation(source: actual.source, owner: actual.owner,
                scene: "window-b", epoch: actual.epoch, coverage: actual.coverage, projection: actual.projection)
            r.check(!v.policy.matches(wrongScene, workspace: stored), "same tab IDs in another scene cannot borrow ownership")
            let wrongStore = StudyWorkspaceMappingObservation(source: stored.source, owner: ObjectIdentifier(otherOwner),
                scene: stored.scene, epoch: stored.epoch, coverage: stored.coverage, projection: stored.projection)
            r.check(!v.policy.matches(actual, workspace: wrongStore), "same persisted values with foreign original store owner rejected")
            f.adapter.releaseNativeTabSelection(v)
            r.rejects("release before apply prevents original action") { try f.apply(v) }
        }
        r.run("missing saved target") {
            let f = try fixture()
            try f.store.saveTabs([f.store.selectedGroup(scene: "window-a")!.tabs[0]], activeID: f.a.id, groupID: f.group.id)
            r.rejects("live tab absent from original group cannot be admitted") { _ = try f.reserve() }
        }
        r.run("wrong field through source policy") {
            let f = try fixture(), v = try f.reserve()
            let native = f.adapter.mappingOwnershipObservation()!, stored = f.store.mappingObservation(scene: "window-a")!
            try v.policy.beginApply(native, workspace: stored)
            let wrong = StudyWorkspaceMappingProjection(profileID: UUID(), groupID: native.projection.groupID,
                profileIDs: native.projection.profileIDs, groupIDs: native.projection.groupIDs,
                activeTabID: f.b.id, targets: native.projection.targets)
            r.check(!v.policy.permitsSelectionPublication(from: native.projection, to: wrong),
                    "owned setter cannot transfer the retained profile")
        }
        r.run("one owned willSet allowance") {
            let f = try fixture(), v = try f.reserve()
            let native = f.adapter.mappingOwnershipObservation()!, stored = f.store.mappingObservation(scene: "window-a")!
            try v.policy.beginApply(native, workspace: stored)
            let first = v.policy.permitsSelectionPublication(from: native.projection, to: v.policy.selected)
            let second = v.policy.permitsSelectionPublication(from: native.projection, to: v.policy.selected)
            r.check(first && !second, "same original setter permit cannot be consumed twice before didSet")
        }
        r.run("source exhaustion") {
            let f = try fixture(), native = f.adapter.mappingOwnershipObservation()!, stored = f.store.mappingObservation(scene: "window-a")!
            let source = StudyWorkspaceMappingSource(available: true, maximumRevision: 0)
            let fresh = StudyWorkspaceMappingObservation(source: source, owner: native.owner, scene: native.scene,
                epoch: source.event.epoch!, coverage: native.coverage, projection: native.projection)
            let v = try StudyWorkspaceTabSelectionReservation(requestID: UUID(), observation: fresh, workspace: stored, targetID: f.b.id)
            source.beginChange([.selection])
            r.check(source.event.epoch == nil && !v.matches(fresh, workspace: stored),
                    "source epoch exhaustion fails closed without recycling identity")
        }
        let result: [String: Any] = ["scope": "actual original mapping/store/persistence and extracted original selection/setter/checkpoint bodies; Apple shell boundaries",
            "passed": r.passed, "failed": r.failed, "native": "NOT_RUN"]
        print(String(data: try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), encoding: .utf8)!)
        if r.failed != 0 { throw NSError(domain: "NativeReaderTabOwnerControls", code: r.failed) }
    }
}
