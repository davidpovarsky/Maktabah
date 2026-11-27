import Foundation
import Observation
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

struct TestFailure: Error { let message: String }
@MainActor func check(_ value: @autoclosure () -> Bool, _ message: String) throws {
    if !value() { throw TestFailure(message: message) }
}
@MainActor func rejects(_ call: () throws -> Void) throws {
    do { try call() } catch is TestFailure { throw TestFailure(message: "test failed inside rejection") }
    catch { return }
    throw TestFailure(message: "expected refusal")
}
@MainActor final class OwnerFixture {
    let scene = UIStableID(rawValue: "original-scene")!
    let model = ResultsViewModel.shared
    let manager = iOSNavigationManager()
    let root = RootPublications()
    let selected = Cell(iOSTab.search), settings = Cell(false)
    let workspacePresentation = MaktabahNativeWorkspacePresentationBinding()
    let window = UIWindow()
    var windowRevision = 0
    var windowValid = true, commonReady = true
    let requested = Cell(false), path = Cell<[FolderNode]>([]), filter = Cell("")
    let loading = Cell(false), blocked = Cell(false)
    let searchID = UUID(), sheetID = UUID(), pageID = UUID(), rowID = UUID()
    let testSession = TestSession()
    var binding: MaktabahNativeSavedResultsBinding!
    var hooks: OriginalStateHookFixture!
    var sheetView: UIView!, pageView: UIView!, rowView: UIView!
    var scrolls = 0, writes = 0
    var ready: Workspace!
    var a: FolderNode!, b: FolderNode!, result: ResultNode!
    init(warm: Bool = true, atFolder: Bool = false) {
        BackendCoordinator.shared.activeBackendID = .otzaria
        BackendCoordinator.shared.usesNativeMaktabahDataPath = true
        BackendCoordinator.shared.isTransitioning = false
        DonationManager.shared.showDonationSheet = false
        a = FolderNode(id: 10, name: "Folder A"); b = FolderNode(id: 11, name: "Folder B")
        result = ResultNode(id: 20, parentId: 10, name: "Saved row", items: [
            .init(archive: "actual-fixture", tableName: "fixture", query: "private needle", bookId: 42, bookTitle: "Book")])
        model.folderRoots = [a, b]; model.folderById = [10: a, 11: b]
        model.parentById = [:]; model.folderResults = [10: [result]]; model.resultById = [20: result]
        ready = Workspace(manager)
        let source = MaktabahNativeWorkspaceProjectionSource(ready)
        let bindings = MaktabahNativeSceneBindings(manager: manager, selectedTab: selected.binding,
            showSettings: settings.binding, rootPublications: root)
        binding = MaktabahNativeSavedResultsBinding(sceneID: scene, bindings: bindings,
            workspaceSource: source, workspacePresentation: workspacePresentation,
            commonReady: { [weak self] in self?.commonReady == true }, windowReady: { true },
            retainWindow: { [weak self] in
                guard let self else { throw TestFailure(message: "fixture retired") }
                let revision = self.windowRevision
                return MaktabahNativeWindowObservation(window: self.window) { [weak self] actual in
                    self?.window === actual && self?.windowValid == true && self?.windowRevision == revision
                }
            }, readForeignPresentations: {})
        testSession.savedResultsBinding = binding
        hooks = OriginalStateHookFixture(session: testSession, search: searchID, sheet: sheetID)
        binding.attachSearch(owner: searchID, manager: manager, requested: { [self] in requested.value },
            setRequested: { [self] value in writes += 1; hooks.setSearch(requested, value) }, otherBlocked: { false })
        sheetView = UIView(window); pageView = UIView(window); rowView = UIView(window)
        if warm {
            hooks.setSearch(requested, true)
            if atFolder { path.value = [a] }
            attachSheet()
            attachPage(atFolder ? a : nil)
        }
    }
    func attachSheet() {
        binding.attachSheet(access: .init(token: sheetID, model: model,
            path: { [self] in path.value }, setPath: { [self] in hooks.set(path, field: .path, value: $0) },
            filter: { [self] in filter.value }, loading: { [self] in loading.value }, blocked: { [self] in blocked.value }), view: sheetView)
    }
    func attachPage(_ folder: FolderNode?) {
        binding.attachPage(token: pageID, sheet: sheetID, folder: folder, view: pageView,
            reveal: { [self] _ in scrolls += 1 })
    }
    func attachRow() { binding.attachRow(token: rowID, sheet: sheetID, page: path.value.last,
        node: .result(result), view: rowView) }
    func record(_ kind: NativeSavedResultIntentService.Kind) throws -> NativeSavedResultIntentService.Record {
        let values = try binding.catalog().filter { $0.reference.kind == kind }
        guard let value = values.first else { throw TestFailure(message: "missing original metadata") }; return value
    }
    func begin(_ record: NativeSavedResultIntentService.Record? = nil,
               validator: @escaping @MainActor () throws -> Void = {}) throws -> UUID {
        let id = UUID(); try binding.retain(record: record, requestID: id)
        try binding.begin(requestID: id, validate: validator); return id
    }
}

@main struct OwnerControls {
    @MainActor static func main() {
        var results: [[String: Any]] = []
        func run(_ name: String, _ body: @MainActor () throws -> Void) {
            do { try body(); results.append(["name": name, "pass": true]) }
            catch { results.append(["name": name, "pass": false, "error": String(describing: error)]) }
        }
        run("actual tree records retain original objects without load") {
            let f = OwnerFixture(); let source = try MaktabahNativeSavedResultsSource(model: f.model, sceneID: f.scene)
            try check(source.entries.count == 3 && f.model.nativeLoadLifetime.settledRevision != nil, "actual published tree")
            try source.validate()
        }
        run("same SQL ID replacement is a different original node") {
            let f = OwnerFixture(); let source = try MaktabahNativeSavedResultsSource(model: f.model, sceneID: f.scene)
            f.model.folderById[10] = FolderNode(id: 10, name: f.a.name)
            try rejects { try source.validate() }
        }
        run("real node Observation refuses name ABA") {
            let f = OwnerFixture(); let source = try MaktabahNativeSavedResultsSource(model: f.model, sceneID: f.scene)
            let name = f.result.name; f.result.name = "changed"; f.result.name = name
            try rejects { try source.validate() }
        }
        run("equal collection publication cannot rearm captured source") {
            let f = OwnerFixture(); let source = try MaktabahNativeSavedResultsSource(model: f.model, sceneID: f.scene)
            let values = f.model.folderRoots; f.model.folderRoots = values
            try rejects { try source.validate() }
        }
        run("original reload start and completion retire previous tree") {
            let f = OwnerFixture(); let source = try MaktabahNativeSavedResultsSource(model: f.model, sceneID: f.scene)
            let load = f.model.nativeLoadLifetime.beginOriginalLoad()
            try rejects { try source.validate() }
            f.model.nativeLoadLifetime.endOriginalLoad(load, cancelled: false)
            try rejects { try source.validate() }
        }
        run("duplicate SQL/object tree refuses rather than guessing") {
            let f = OwnerFixture(); f.model.folderRoots = [f.a, f.a]
            try rejects { _ = try MaktabahNativeSavedResultsSource(model: f.model, sceneID: f.scene) }
        }
        run("actual parent map mismatch refuses") {
            let f = OwnerFixture(); f.model.parentById[10] = 11
            try rejects { _ = try MaktabahNativeSavedResultsSource(model: f.model, sceneID: f.scene) }
        }
        run("current cold root uses one actual original setter and waits for original load") {
            let f = OwnerFixture(warm: false), query = "unchanged query"
            let id = try f.begin(); try f.binding.apply(requestID: id)
            try check(f.requested.value && f.writes == 1 && !f.binding.hasVisibleSurface(requestID: id), "one original apply")
            f.loading.value = true; f.attachSheet(); f.attachPage(nil)
            try check(!f.binding.hasVisibleSurface(requestID: id), "loading is not a receipt")
            let load = f.model.nativeLoadLifetime.beginOriginalLoad(); f.model.nativeLoadLifetime.endOriginalLoad(load, cancelled: false)
            f.hooks.set(f.loading, field: .loading, value: false)
            try check(f.binding.hasVisibleSurface(requestID: id) && f.manager.unifiedSearchSession.query == query, "actual root only")
        }
        run("warm folder uses original path and actual folder page") {
            let f = OwnerFixture(), id = try f.begin(f.record(.folder))
            try f.binding.apply(requestID: id)
            try check(f.path.value.count == 1 && f.path.value[0] === f.a && !f.binding.hasVisibleSurface(requestID: id), "exact original path")
            f.attachPage(f.a)
            try check(f.binding.hasVisibleSurface(requestID: id) && f.scrolls == 0, "folder page instead of a result action")
        }
        run("cold apply retains its own bounded presentation phase before original callbacks") {
            let f = OwnerFixture(warm: false), id = UUID()
            try f.binding.retain(record: nil, requestID: id)
            try f.binding.begin(requestID: id) {
                // The real Session must reject a foreign requested sheet but
                // permit only this already-applied command's own transition.
                if f.requested.value && !f.binding.isContinuingAppliedRequest(requestID: id) {
                    throw UIRouteError(.unavailable, "original_sheet_transition")
                }
            }
            try f.binding.apply(requestID: id)
            try check(f.writes == 1 && f.requested.value, "same request original setter")
            try check(!f.binding.hasVisibleSurface(requestID: id), "effect phase alone is not a receipt")
            f.attachSheet(); f.attachPage(nil)
            try check(f.binding.hasVisibleSurface(requestID: id), "later actual parent layout")
        }
        run("warm result requires actual row after original List scroll") {
            let f = OwnerFixture(atFolder: true), id = try f.begin(f.record(.result))
            try f.binding.apply(requestID: id)
            try check(f.scrolls == 1 && !f.binding.hasVisibleSurface(requestID: id), "page alone is insufficient")
            f.rowView.visible = false; f.attachRow()
            try check(!f.binding.hasVisibleSurface(requestID: id), "offscreen row refuses")
            f.rowView.visible = true; f.binding.originalLayoutDidChange()
            try check(f.binding.hasVisibleSurface(requestID: id) && f.scrolls == 1, "one actual scroll plus row evidence")
        }
        run("private filter remains unchanged through result reveal") {
            let f = OwnerFixture(atFolder: true); f.hooks.set(f.filter, field: .filter, value: "needle")
            let id = try f.begin(f.record(.result)); try f.binding.apply(requestID: id)
            try check(f.path.value.isEmpty && f.filter.value == "needle", "original filtered root retained")
            f.attachPage(nil); f.attachRow()
            try check(f.binding.hasVisibleSurface(requestID: id), "actual filtered row")
        }
        run("nonmatching private filter hides metadata without changing query") {
            let f = OwnerFixture(); f.hooks.set(f.filter, field: .filter, value: "not in original row")
            let values = try f.binding.catalog(); try check(values.isEmpty, "no replacement record")
            try check(f.filter.value == "not in original row", "private filter unchanged")
        }
        run("cold cached node cannot be rebound after sheet dismissal") {
            let f = OwnerFixture(), old = try f.record(.result)
            f.binding.detachSheet(owner: f.sheetID, view: f.sheetView); f.hooks.setSearch(f.requested, false)
            try rejects { try f.binding.retain(record: old, requestID: UUID()) }
            try check(!f.requested.value, "no cold node fallback")
        }
        run("equal path callback after retain invalidates the source") {
            let f = OwnerFixture(atFolder: true), id = try f.begin(f.record(.result))
            f.hooks.set(f.path, field: .path, value: f.path.value)
            try rejects { try f.binding.apply(requestID: id) }
        }
        run("same request cannot apply original selection twice") {
            let f = OwnerFixture(warm: false), id = try f.begin()
            try f.binding.apply(requestID: id); try rejects { try f.binding.apply(requestID: id) }
            try check(f.writes == 1, "effect is one use")
        }
        run("nested original Search setter cannot borrow the first permit") {
            let f = OwnerFixture(warm: false), id = try f.begin()
            var nested = false
            f.testSession.onSearchWrite = { if !nested { nested = true; f.hooks.setSearch(f.requested, true) } }
            try rejects { try f.binding.apply(requestID: id) }
            try check(f.requested.value && !f.binding.hasVisibleSurface(requestID: id), "ordinary effects preserved but never ACK")
        }
        run("release in original Search callback cannot resurrect pending source") {
            let f = OwnerFixture(warm: false), id = try f.begin()
            f.testSession.onSearchWrite = { f.binding.releaseSource(requestID: id) }
            try rejects { try f.binding.apply(requestID: id) }
            try check(!f.binding.hasVisibleSurface(requestID: id), "released source has no receipt")
        }
        run("reentrant path callback consumes only the intended publication") {
            let f = OwnerFixture(); let id = try f.begin(f.record(.folder)); var nested = false
            f.binding.install(changed: {
                if !nested { nested = true; f.hooks.set(f.path, field: .path, value: f.path.value) }
            }, invalidated: {})
            try rejects { try f.binding.apply(requestID: id) }
            try check(!f.binding.hasVisibleSurface(requestID: id), "second publication revokes")
        }
        run("original window replacement ABA refuses before effect") {
            let f = OwnerFixture(warm: false), id = try f.begin()
            f.windowRevision += 2
            try rejects { try f.binding.apply(requestID: id) }
            try check(f.writes == 0, "same actual window requires same owner epoch")
        }
        run("workspace mapping publication ABA refuses") {
            let f = OwnerFixture(warm: false), id = try f.begin()
            f.ready.source.event = .init(epoch: 1); f.ready.source.event = .init(epoch: 0)
            try rejects { try f.binding.apply(requestID: id) }
        }
        run("foreign root equal publication refuses") {
            let f = OwnerFixture(warm: false), id = try f.begin()
            let before = f.root.selectionRevision; f.root.selectionRevision = before
            try rejects { try f.binding.apply(requestID: id) }
        }
        run("backend abort publication refuses through explicit publisher boundary") {
            let f = OwnerFixture(warm: false), id = try f.begin()
            BackendCoordinator.shared.isTransitioning = true; BackendCoordinator.shared.isTransitioning = false
            try rejects { try f.binding.apply(requestID: id) }
        }
        run("replacement original sheet host cannot adopt pending warm record") {
            let f = OwnerFixture(atFolder: true), id = try f.begin(f.record(.result))
            f.sheetView = UIView(f.window); f.attachSheet()
            try rejects { try f.binding.apply(requestID: id) }
        }
        run("target row detach and return retires the exact source") {
            let f = OwnerFixture(atFolder: true); f.attachRow()
            let id = try f.begin(f.record(.result)); try f.binding.apply(requestID: id)
            try check(f.binding.hasVisibleSurface(requestID: id), "initial actual row")
            f.binding.detachRow(token: f.rowID, node: .result(f.result), view: f.rowView); f.attachRow()
            try check(!f.binding.hasVisibleSurface(requestID: id), "no row ABA")
        }
        run("unrelated lazy row detach does not retire selected original row") {
            let f = OwnerFixture(atFolder: true); f.attachRow()
            let other = ResultNode(id: 55, parentId: 10, name: "unrelated", items: [])
            let otherView = UIView(f.window), token = UUID()
            f.binding.attachRow(token: token, sheet: f.sheetID, page: f.a, node: .result(other), view: otherView)
            let id = try f.begin(f.record(.result)); try f.binding.apply(requestID: id)
            f.binding.detachRow(token: token, node: .result(other), view: otherView)
            try check(f.binding.hasVisibleSurface(requestID: id), "unrelated virtualization is not target replacement")
        }
        run("report callback release cannot return an accepted surface") {
            let f = OwnerFixture(atFolder: true); f.attachRow()
            let id = try f.begin(f.record(.result)); try f.binding.apply(requestID: id)
            try rejects { _ = try f.binding.withValidatedSurface(requestID: id) { f.binding.releaseSource(requestID: id); return "actual callback" } }
        }
        run("completed receipt source remains exact until a later original edit") {
            let f = OwnerFixture(atFolder: true); f.attachRow()
            let id = try f.begin(f.record(.result)); try f.binding.apply(requestID: id)
            f.binding.finish(requestID: id, completed: true); f.binding.releaseSource(requestID: id)
            try f.binding.validateCompletedSurface(requestID: id)
            f.hooks.set(f.filter, field: .filter, value: "new private filter")
            try rejects { try f.binding.validateCompletedSurface(requestID: id) }
        }
        let report: [String: Any] = ["boundary": "actual owner/tree/load/original setter methods; actual Core/UIRouting value contracts; explicit UIKit/workspace/DB/backend publisher fixtures; no Core execution/native acceptance", "passed": results.filter { $0["pass"] as? Bool == true }.count, "failed": results.filter { $0["pass"] as? Bool == false }.count, "cases": results]
        print(String(decoding: try! JSONSerialization.data(withJSONObject: report, options: [.sortedKeys, .prettyPrinted]), as: UTF8.self))
        if report["failed"] as? Int != 0 { exit(1) }
    }
}
