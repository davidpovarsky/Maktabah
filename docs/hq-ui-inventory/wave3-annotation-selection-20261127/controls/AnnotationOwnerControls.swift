import Foundation
import OtzariaUIRouting
import ChavrusaUIRoutingHost

struct OwnerFailure: Error { let message: String }
@MainActor func check(_ value: @autoclosure () throws -> Bool, _ message: String) throws {
    if try !value() { throw OwnerFailure(message: message) }
}
@MainActor func refusal(_ body: () throws -> Void) throws {
    do { try body(); throw OwnerFailure(message: "unexpected acceptance") }
    catch is OwnerFailure { throw OwnerFailure(message: "unexpected acceptance") }
    catch {}
}
@MainActor final class Fixture {
    let manager = iOSNavigationManager()
    let window = UIWindow()
    let root = MaktabahNativeRootPublicationSource()
    let tab = Cell(iOSTab.annotations), settings = Cell(false)
    let presentation = MaktabahNativeWorkspacePresentationBinding()
    let scene = UIStableID(rawValue: "original-scene")!
    let owner = UUID()
    var originalWindow = true, blocked = false, common = true, foreground = true
    var validation: (() throws -> Void)?
    var callback: (() -> Void)?
    var workspace: Workspace!
    var projection: MaktabahNativeWorkspaceProjectionSource!
    var binding: MaktabahNativeAnnotationSelectionBinding!
    var controller: iOSAnnotationViewController!
    let request = UUID()
    var originalRecord: NativeAnnotationSelectionIntentService.Record!
    init(groups: [(String,Annotation)] = [("one",Annotation(id: 7))]) {
        BackendCoordinator.shared.activeBackendID = .otzaria
        BackendCoordinator.shared.isTransitioning = false
        BackendCoordinator.shared.activeCapabilities = true
        workspace = Workspace(manager); projection = .init(workspace)
        let bindings = MaktabahNativeSceneBindings(manager: manager,
            selectedTab: root.selectionBinding(tab.binding), showSettings: root.settingsBinding(settings.binding), rootPublications: root)
        binding = .init(sceneID: scene, bindings: bindings, workspaceSource: projection,
            workspacePresentation: presentation, commonReady: { [weak self] in self?.common == true },
            windowReady: { [weak self] in self?.foreground == true && self?.originalWindow == true },
            retainWindow: { [weak self] in
                guard let self else { throw OwnerFailure(message: "fixture removed") }
                return MaktabahNativeWindowObservation(window: self.window) { [weak self] actual in
                    self?.originalWindow == true && actual === self?.window
                }
            }, readForeignPresentations: {})
        binding.install(changed: { [weak self] in self?.callback?() }, invalidated: {})
        controller = .init(window: window, model: manager.annotationViewModel)
        controller.controlSeed(groups)
        controller.nativeRoutingAttach(binding: binding, owner: owner, blocked: { [weak self] in self?.blocked != false })
    }
    func retain(index: Int = 0) throws {
        originalRecord = try binding.catalog()[index]
        try binding.retain(record: originalRecord, requestID: request)
    }
    func begin() throws { try binding.begin(requestID: request) { [weak self] in try self?.validation?() } }
    func apply() throws { try binding.apply(requestID: request) }
    func complete() throws {
        _ = try binding.withValidatedSurface(requestID: request) { true }
        binding.finish(requestID: request, completed: true)
        binding.releaseSource(requestID: request)
        try binding.validateCompletedSurface(requestID: request)
    }
}

@main struct AnnotationOwnerControls {
    @MainActor static func main() {
        var cases: [[String: Any]] = []
        func run(_ name: String, _ body: () throws -> Void) {
            do { try body(); cases.append(["name": name, "pass": true]) }
            catch { cases.append(["name": name, "pass": false, "error": String(describing: error)]) }
        }
        run("exact collapsed original group expands scrolls selects and retains completed identity") {
            let f = Fixture(); try f.retain(); try f.begin(); try f.apply()
            try check(f.controller.controlExpansionCount == 1 && f.controller.collectionView.scrolls == 1 && f.controller.collectionView.selections == 1, "one original operation each")
            try check(f.binding.observedItem(requestID: f.request) == f.originalRecord.itemID, "actual selected item")
            try f.complete()
            try check(try f.binding.catalog().contains(f.originalRecord), "same source entity after release")
        }
        run("same SQL ID in two real tag sections remains two distinct rows") {
            let f = Fixture(groups: [("one",Annotation(id: 7)),("two",Annotation(id: 7))])
            let records = try f.binding.catalog()
            try check(records.count == 2 && records[0].id != records[1].id, "section scoped identities")
            try f.retain(index: 1); try f.begin(); try f.apply()
            try check(f.controller.collectionView.indexPathsForSelectedItems == [IndexPath(indexes:[1,1])], "same actual second section")
        }
        run("foreign backend row is not advertised") {
            let foreign = Annotation(id: 9, bkId: -9, backendLocator: .init(backend: .sefaria, identity: "other"))
            let f = Fixture(groups:[("one",foreign)])
            try check(try f.binding.catalog().isEmpty, "no backend switch or foreign record")
        }
        run("duplicate original item identity refuses discovery") {
            let f = Fixture(); f.controller.controlDuplicateRow()
            try refusal { _ = try f.binding.catalog() }
        }
        run("parent alone cannot acknowledge an unselected row") {
            let f = Fixture(); try f.retain(); try f.begin()
            try check(!f.binding.hasVisibleSurface(requestID:f.request), "no parent-only completion")
        }
        run("equal original filter publication retires the old reference") {
            let f = Fixture(); try f.retain(); f.manager.annotationViewModel.searchScope = 0
            try refusal { try f.begin() }
            try check(f.controller.collectionView.scrolls == 0, "no effect")
        }
        run("original filter ABA cannot rearm a reference") {
            let f = Fixture(); try f.retain()
            f.manager.annotationViewModel.searchText = "other"; f.manager.annotationViewModel.searchText = ""
            try refusal { try f.begin() }
        }
        run("original ordinary group toggle retires a pending source") {
            let f = Fixture(); try f.retain(); try f.begin(); f.controller.controlOriginalToggle()
            try refusal { try f.apply() }
            try check(f.controller.collectionView.selections == 0 && f.controller.controlExpansionCount == 1, "ordinary toggle preserved only")
        }
        run("original Store event retires published source before later UI reload") {
            let f = Fixture(); try f.retain(); AnnotationStore.shared.events.send()
            try refusal { try f.begin() }
        }
        run("backend ABA through the actual observation boundary refuses") {
            let f = Fixture(); try f.retain()
            BackendCoordinator.shared.activeBackendID = .sefaria; BackendCoordinator.shared.activeBackendID = .otzaria
            try refusal { try f.begin() }
        }
        run("actual original root selection binding ABA refuses") {
            let f = Fixture(); try f.retain()
            let original = f.root.selectionBinding(f.tab.binding)
            original.wrappedValue = .viewer; original.wrappedValue = .annotations
            try refusal { try f.begin() }
        }
        run("wrong old controller detach leaves the current original source intact") {
            let f = Fixture(); try f.retain(); try f.begin()
            let other = iOSAnnotationViewController(window: f.window, model: f.manager.annotationViewModel)
            f.binding.detach(controller: other, owner: f.owner); try f.apply()
        }
        run("actual controller detach and return cannot renew cached entity") {
            let f = Fixture(); try f.retain(); f.controller.nativeRoutingDetach()
            f.controller.nativeRoutingAttach(binding:f.binding, owner:f.owner, blocked:{ false })
            try refusal { try f.begin() }
            try check(try !f.binding.catalog().contains(f.originalRecord), "fresh metadata cannot reuse old identity")
        }
        run("modal equal original publication retires source even before flag changes") {
            let f = Fixture(); try f.retain(); f.binding.originalModalWillChange(owner:f.owner)
            try refusal { try f.begin() }
        }
        run("wrong modal owner cannot retire current list") {
            let f = Fixture(); try f.retain(); try f.begin()
            f.binding.originalModalWillChange(owner:UUID()); try f.apply()
        }
        run("source release inside admission callback prevents every selection effect") {
            let f = Fixture(); try f.retain()
            f.validation = { f.binding.releaseSource(requestID:f.request) }
            try refusal { try f.begin() }
            try check(f.controller.collectionView.selections == 0, "no effect after release")
        }
        run("source release during actual expansion stops later scroll and select") {
            let f = Fixture(); try f.retain(); try f.begin()
            f.controller.controlOnExpansion { f.binding.releaseSource(requestID:f.request) }
            try refusal { try f.apply() }
            try check(f.controller.controlExpansionCount == 1 && f.controller.collectionView.scrolls == 0 && f.controller.collectionView.selections == 0, "partial effect observed, no continuation")
        }
        run("same request apply reentry before live validation is consumed") {
            let f = Fixture(); try f.retain(); try f.begin()
            var nestedRefused = false
            f.validation = { do { try f.apply() } catch { nestedRefused = true } }
            try f.apply()
            try check(nestedRefused && f.controller.collectionView.selections == 1, "one selection")
            try refusal { try f.apply() }
        }
        run("source release during final report rejects the copied pending proof") {
            let f = Fixture(); try f.retain(); try f.begin(); try f.apply()
            var reports = 0
            try refusal { _ = try f.binding.withValidatedSurface(requestID:f.request) { reports += 1; f.binding.releaseSource(requestID:f.request); return true } }
            try check(reports == 1 && !f.binding.hasVisibleSurface(requestID:f.request), "actual reporting callback happened but no surviving ACK")
        }
        run("wrong full configured annotation rejects completion despite identical numeric ID") {
            let f = Fixture(); try f.retain(); try f.begin(); try f.apply()
            var other = Annotation(id:7); other.range = NSRange(location:9,length:1); other.lastModified += 1
            f.controller.collectionView.cells[IndexPath(indexes:[0,1])]!.contentConfiguration = AnnotationContentConfiguration(annotation:other)
            try check(!f.binding.hasVisibleSurface(requestID:f.request), "full original record equality required")
        }
        run("occluded original cell cannot acknowledge") {
            let f = Fixture(); try f.retain(); try f.begin(); try f.apply()
            f.controller.collectionView.cells[IndexPath(indexes:[0,1])]!.visible = false
            try check(!f.binding.hasVisibleSurface(requestID:f.request), "no geometry bypass")
        }
        run("original window source removal refuses before effect") {
            let f = Fixture(); try f.retain(); try f.begin(); f.originalWindow = false
            try refusal { try f.apply() }
            try check(f.controller.collectionView.selections == 0, "no wrong window effect")
        }
        run("cancelled original admission refuses before effect") {
            let f = Fixture(); try f.retain(); try f.begin(); f.validation = { throw CancellationError() }
            try refusal { try f.apply() }
            try check(f.controller.collectionView.selections == 0, "no cancellation bypass")
        }
        run("post-selection cancellation does not relabel partial effects as completion") {
            let f = Fixture(); try f.retain(); try f.begin()
            f.controller.collectionView.onSelect = { f.validation = { throw CancellationError() } }
            try refusal { try f.apply() }
            try check(f.controller.collectionView.selections == 1 && !f.binding.hasVisibleSurface(requestID:f.request), "effect occurred, completion refused")
        }
        let report: [String: Any] = ["boundary":"Actual binding/publication and finite original collection methods; explicit UIKit/Combine/Store/backend/workspace fixtures and original Core/UI value types. No app/native/Core execution or actual geometry evidence.","passed":cases.filter{$0["pass"] as? Bool == true}.count,"failed":cases.filter{$0["pass"] as? Bool == false}.count,"cases":cases]
        print(String(decoding:try! JSONSerialization.data(withJSONObject:report,options:[.sortedKeys,.prettyPrinted]),as:UTF8.self))
        if report["failed"] as? Int != 0 { exit(1) }
    }
}
