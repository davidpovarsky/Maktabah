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

