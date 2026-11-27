import Foundation
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

// Explicit Apple-native boundary only. The actual window-source and Viewer
// owner bodies consume these objects. No frame/appearance value here is
// evidence of a running UIWindow, app, native receipt or TextKit rendering.
@MainActor final class WindowSession { let persistentIdentifier = "source-control-scene" }
@MainActor final class WindowScene {
    enum State { case foregroundActive, background }
    let session = WindowSession()
    var activationState = State.foregroundActive
}
@MainActor class UIView { weak var window: UIWindow? }
@MainActor class UIViewController {
    var viewIfLoaded: UIView?
    var presentedViewController: UIViewController?
    var isBeingPresented = false, isBeingDismissed = false
    var transitionCoordinator: UUID?
    var children: [UIViewController] = []
}
@MainActor final class UIWindow {
    var windowScene: WindowScene? = WindowScene()
    var isKeyWindow = true, isHidden = false, alpha = 1.0
    var rootViewController: UIViewController?
}
@MainActor enum MaktabahNativeViewerParentWitness {
    @MainActor final class Controller {
        let identity = UUID()
        var window: UIWindow?
        var visible = true
        var onRead: (() -> Void)?
        func currentOriginalWindow(in sceneID: UIStableID) -> UIWindow? {
            let action = onRead; onRead = nil; action?()
            guard visible, let window, window.windowScene?.session.persistentIdentifier == sceneID.rawValue else { return nil }
            return window
        }
    }
}

@MainActor final class ParentFixture {
    let base: GroupBindingFixture
    let window = UIWindow()
    let view = UIView()
    let nativeRoot = UIViewController()
    let windowSource = MaktabahNativeWindowSource()
    let controller = MaktabahNativeViewerParentWitness.Controller()
    var mounted = true
    let isProfile: Bool
    lazy var host = MaktabahNativeViewerParentHost(sceneID: UIStableID(rawValue: base.fixture.scene)!,
        manager: base.fixture.manager,
        isCurrentSession: { [weak self] in self?.mounted == true },
        captureOriginalWindow: { [unowned self] in
            try windowSource.retainOriginalWindow(in: UIStableID(rawValue: base.fixture.scene)!) { [weak self] in self?.mounted == true }
        }, originalRootIsReady: { [unowned self] in
            windowSource.isPresentationReady(in: UIStableID(rawValue: base.fixture.scene)!)
        })
    init(empty: Bool = false, profile: Bool = false, phone: Bool = false, from: iOSTab = .history) throws {
        base = try GroupBindingFixture(empty: empty, profile: profile, phone: phone)
        isProfile = profile
        base.tab = from
        base.fixture.manager.switchToMode(from.appMode)
        view.window = window; nativeRoot.viewIfLoaded = view; window.rootViewController = nativeRoot
        windowSource.observe(window, from: view)
        controller.window = window
    }
    func target() throws -> NativeWorkspaceSelectionIntentService.Selection {
        let kind = isProfile ? NativeWorkspaceSelectionIntentService.Kind.profile : .group
        let all = try base.catalog().filter { $0.kind == kind && $0.groupID == base.fixture.g2 }
        guard all.count == 1, let target = all.first else { throw ControlFailure.expected("original target unavailable") }
        return target
    }
    func retain() throws -> MaktabahNativeWorkspaceSelectionBinding {
        try .init(requestID: UUID(), target: target(), bindings: base.bindings, source: base.source,
            viewerParentHost: host, foreignReady: { [weak self] in
                guard let self else { return false }
                return mounted && base.externallyReady && !base.settings && !base.fixture.manager.showingTabsList
                    && base.fixture.manager.selectedBookForInfo == nil && !DonationManager.shared.showDonationSheet
                    && !base.sidebar.overview.blocksRouting
            }, readForeignPresentations: {})
    }
    func retainBeforeFeature() throws -> OriginalBeforeFeatureBinding {
        try .init(requestID: UUID(), target: target(), bindings: base.bindings, source: base.source,
            foreignReady: { true }, readForeignPresentations: {})
    }
    func prepare(_ bound: MaktabahNativeWorkspaceSelectionBinding) async throws -> UISceneCommand {
        try await base.prepare(bound)
        let descriptor = UIDestinationDescriptor(id: MaktabahNativeWorkspaceSelectionBinding.destination,
            title: "EXPLICIT SOURCE CONTROL", implementation: .implemented, supportedBackends: [.otzaria],
            presentations: [.currentTab], requiredCoreActions: [])
        let registry = try UIDestinationRegistry(descriptors: [descriptor])
        let snapshot = ActionBackendSnapshot(backend: .otzaria, generation: BackendCoordinator.shared.generation)
        let scene = UIStableID(rawValue: base.fixture.scene)!
        let route = RouteSpec(requestId: bound.requestID, destination: descriptor.id, backend: .otzaria,
            presentation: .init(kind: .currentTab, tabID: bound.target.activeDocumentID.flatMap { UIStableID(rawValue: $0.uuidString) }),
            state: .init(workspaceID: UIStableID(rawValue: bound.target.groupID.uuidString), profileID: UIStableID(rawValue: bound.target.profileID.uuidString)),
            scene: .init(kind: .specific, sceneID: scene))
        let command = try UISceneCommand(route: registry.validate(route),
            invocation: .init(requestId: bound.requestID, snapshot: snapshot, deadlineUptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + 5_000_000_000),
            scene: .init(sceneID: scene, revision: 1, backendSnapshot: snapshot))
        try bound.viewerParent?.bind(command)
        try bound.begin { [unowned self] in guard base.leaseValid else { throw ControlFailure.expected("original deadline revoked") } }
        return command
    }
    func mode(_ value: AppMode = .viewer) {
        MaktabahNativeViewerModePublication.perform(host: host, manager: base.fixture.manager, mode: value) {
            base.fixture.manager.switchToMode(value)
        }
    }
    func present(_ bound: MaktabahNativeWorkspaceSelectionBinding, command: UISceneCommand) async throws -> NativeOriginalParentObservation {
        guard let parent = bound.viewerParent else { throw ControlFailure.expected("missing retained parent") }
        try parent.applyParent(command)
        mode()
        host.attach(controller, manager: base.fixture.manager)
        host.originalPresentationDidChange(controller)
        return try await parent.waitUntilReady(command)
    }
    func ready(_ bound: MaktabahNativeWorkspaceSelectionBinding) async throws -> UISceneCommand {
        let command = try await prepare(bound)
        let observation = try await present(bound, command: command)
        try bound.viewerParent!.beginSelection(observation, command: command)
        return command
    }
}
