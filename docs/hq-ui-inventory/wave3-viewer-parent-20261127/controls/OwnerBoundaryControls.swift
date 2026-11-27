import Foundation
import Observation
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

// Explicit Apple/app-domain boundaries. The compiled owner, window-source,
// root setter, mode setter and Session attachment methods are extracted byte-
// exactly from the pinned production/candidate sources by the input manifest.
// UIKit appearance/geometry itself is NOT exercised by these controls.
enum AppMode { case viewer, history, search }
enum iOSTab: Equatable {
    case viewer, history, search
    var canonical: iOSTab { self }
    var appMode: AppMode { switch self { case .viewer: .viewer; case .history: .history; case .search: .search } }
}
final class BooksData {}
@MainActor struct Binding<T> {
    let get: () -> T
    let set: (T, Int) -> Void
    init(get: @escaping () -> T, set: @escaping (T, Int) -> Void) { self.get = get; self.set = set }
    var wrappedValue: T { get { get() } nonmutating set { set(newValue, 0) } }
    func transaction(_ value: Int) -> Binding<T> { self }
}
@MainActor final class WindowSession { let persistentIdentifier = "scene.A" }
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
@MainActor final class MaktabahNativeSceneBindings {
    let manager: iOSNavigationManager
    let rootPublications: MaktabahNativeRootPublicationSource?
    let selectedTab: Binding<iOSTab>
    let showSettings: Binding<Bool>
    init(manager: iOSNavigationManager, root: MaktabahNativeRootPublicationSource,
         selectedTab: Binding<iOSTab>, showSettings: Binding<Bool>) {
        self.manager = manager; rootPublications = root
        self.selectedTab = root.selectionBinding(selectedTab); self.showSettings = root.settingsBinding(showSettings)
    }
}
@MainActor enum MaktabahNativeViewerParentWitness {
    final class Controller {
        let identity = UUID()
        var window: UIWindow?
        var visible = true
        func currentOriginalWindow(in sceneID: UIStableID) -> UIWindow? { visible ? window : nil }
    }
}

// INSERT_ACTUAL_OWNER_SOURCES

@MainActor final class Fixture {
    let manager = iOSNavigationManager()
    let root = MaktabahNativeRootPublicationSource()
    var tab = iOSTab.history, settings = false
    let window = UIWindow(), view = UIView(), nativeRoot = UIViewController()
    let source = MaktabahNativeWindowSource(), session = WindowSessionOwner()
    let controller = MaktabahNativeViewerParentWitness.Controller()
    var bindings: MaktabahNativeSceneBindings!
    var host: MaktabahNativeViewerParentHost!
    var parent: MaktabahNativeViewerParentContinuation!
    var command: UISceneCommand!
    init() throws {
        manager.currentMode = .history
        view.window = window; nativeRoot.viewIfLoaded = view; window.rootViewController = nativeRoot
        source.observe(window, from: view); session.attachWindowSource(source)
        bindings = .init(manager: manager, root: root,
            selectedTab: .init(get: { [unowned self] in tab }, set: { [unowned self] value, _ in tab = value }),
            showSettings: .init(get: { [unowned self] in settings }, set: { [unowned self] value, _ in settings = value }))
        host = .init(sceneID: .init(rawValue: "scene.A")!, manager: manager,
            isCurrentSession: { true }, captureOriginalWindow: { [unowned self] in try session.retainOriginalWindowObservation() },
            originalRootIsReady: { [unowned self] in source.isPresentationReady(in: .init(rawValue: "scene.A")!) })
        let tabID = UUID(), request = UUID(), snapshot = ActionBackendSnapshot(backend: .otzaria, generation: 1)
        let descriptor = UIDestinationDescriptor(id: NativeReaderTabIntentService.destination, title: "BOUNDARY ONLY",
            implementation: .implemented, supportedBackends: [.otzaria], presentations: [.currentTab], requiredCoreActions: [])
        let registry = try UIDestinationRegistry(descriptors: [descriptor])
        let route = RouteSpec(requestId: request, destination: descriptor.id, backend: .otzaria,
            presentation: .init(kind: .currentTab, tabID: .init(rawValue: tabID.uuidString)),
            state: .init(workspaceID: .init(rawValue: "group.A"), profileID: .init(rawValue: "profile.A")),
            scene: .init(kind: .specific, sceneID: .init(rawValue: "scene.A")))
        command = try .init(route: registry.validate(route), invocation: .init(requestId: request, snapshot: snapshot, deadlineUptimeNanoseconds: UInt64.max),
                            scene: .init(sceneID: .init(rawValue: "scene.A")!, revision: 1, backendSnapshot: snapshot))
        parent = try host.retain(requestID: request, tabID: tabID, bindings: bindings)
        try parent.bind(command)
    }
    func originalMode(_ mode: AppMode = .viewer) {
        MaktabahNativeViewerModePublication.perform(host: host, manager: manager, mode: mode) { manager.switchToMode(mode) }
    }
    func actualParent() async throws -> NativeOriginalParentObservation {
        try parent.applyParent(command)
        originalMode()
        controller.window = window
        host.attach(controller, manager: manager)
        host.originalPresentationDidChange(controller)
        return try await parent.waitUntilReady(command)
    }
}

extension MaktabahNativeWindowSource {
    // Test-only initial metadata boundary, never present in the app source.
    func exhaustRevisionForControl() { observationRevision = .max }
}
@main struct OwnerControls {
    @MainActor static var rows: [[String: Any]] = []
    @MainActor static func record(_ name: String, _ pass: Bool) { rows.append(["name": name, "pass": pass]) }
    @MainActor static func refuses(_ operation: () throws -> Void) -> Bool { do { try operation(); return false } catch { return true } }
    @MainActor static func main() async {
        do {
            do {
                let f = try Fixture(), proof = try f.session.retainOriginalWindowObservation()
                record("same_original_window_valid", try proof.validate() === f.window)
                let unchanged = !f.source.observe(f.window, from: f.view)
                let sameWindow = try proof.validate() === f.window
                record("equal_source_observation_is_not_identity_change", unchanged && sameWindow)
                f.session.attachWindowSource(f.source)
                record("equal_source_attachment_preserves_proof", try proof.validate() === f.window)
            }
            for change in ["window_ABA", "view_ABA", "nil_return", "source_attachment_ABA", "source_exhaustion"] {
                let f = try Fixture(), proof = try f.session.retainOriginalWindowObservation()
                switch change {
                case "window_ABA":
                    let next = UIWindow(); f.view.window = next; f.source.observe(next, from: f.view)
                    f.view.window = f.window; f.source.observe(f.window, from: f.view)
                case "view_ABA":
                    let next = UIView(); next.window = f.window; f.source.observe(f.window, from: next); f.source.observe(f.window, from: f.view)
                case "nil_return":
                    f.view.window = nil; f.source.observe(nil, from: f.view)
                    f.view.window = f.window; f.source.observe(f.window, from: f.view)
                case "source_attachment_ABA":
                    let next = MaktabahNativeWindowSource(); f.session.attachWindowSource(next); f.session.attachWindowSource(f.source)
                default:
                    f.source.exhaustRevisionForControl(); f.source.observe(nil, from: f.view); f.source.observe(f.window, from: f.view)
                }
                record(change + "_cannot_revive_proof", refuses { _ = try proof.validate() })
            }
            do {
                let f = try Fixture(), proof = try f.session.retainOriginalWindowObservation()
                f.nativeRoot.transitionCoordinator = UUID()
                record("source_identity_does_not_relax_presentation_guard", (try proof.validate()) === f.window && !f.source.isPresentationReady(in: .init(rawValue: "scene.A")!))
            }
            do {
                let f = try Fixture(), actual = try await f.actualParent()
                try f.parent.validateParent(actual, command: f.command)
                try f.parent.beginSelection(actual, command: f.command)
                try f.parent.validateOriginalSelectionEntry(); try f.parent.selectionDidApply()
                record("actual_parent_then_same_owned_selection_phase", f.tab == .viewer && f.manager.currentMode == .viewer && f.root.selectionRevision == 1 && f.manager.nativeModePresentationRevision == 2)
                record("parent_cannot_reselect_root", refuses { try f.parent.applyParent(f.command) })
            }
            do {
                let f = try Fixture(); try f.parent.applyParent(f.command)
                f.manager.switchToMode(.viewer)
                record("unowned_equal_mode_cannot_impersonate_original_publisher", refuses { try f.parent.validateRoot() })
            }
            do {
                let f = try Fixture(); try f.parent.applyParent(f.command); f.originalMode(); f.originalMode()
                record("second_mode_publication_revokes_but_preserves_UI_calls", f.manager.nativeModePresentationRevision == 3 && refuses { try f.parent.validateRoot() })
            }
            do {
                let f = try Fixture(); try f.parent.applyParent(f.command)
                var calls = 0
                MaktabahNativeViewerModePublication.perform(host: f.host, manager: f.manager, mode: .viewer) {
                    f.originalMode(); calls += 1; f.manager.switchToMode(.viewer)
                }
                record("nested_mode_publication_revokes_without_vetoing_UI", calls == 1 && f.manager.nativeModePresentationRevision == 3 && refuses { try f.parent.validateRoot() })
            }
            do {
                let f = try Fixture(); try f.parent.applyParent(f.command); f.originalMode(.search)
                record("wrong_original_mode_call_is_preserved_and_refused", f.manager.currentMode == .search && refuses { try f.parent.validateRoot() })
            }
            do {
                let f = try Fixture(), actual = try await f.actualParent()
                f.host.detach(f.controller); f.host.attach(f.controller, manager: f.manager)
                record("host_detach_return_cannot_revive_parent", refuses { try f.parent.validateParent(actual, command: f.command) })
            }
            do {
                let f = try Fixture(), actual = try await f.actualParent()
                let next = MaktabahNativeViewerParentWitness.Controller(); next.window = f.window
                f.host.attach(next, manager: f.manager)
                record("first_host_permission_cannot_transfer_to_replacement", refuses { try f.parent.validateParent(actual, command: f.command) })
            }
            do {
                let f = try Fixture(); f.controller.window = f.window; f.host.attach(f.controller, manager: f.manager)
                record("cold_host_cannot_join_before_canonical_parent_apply", refuses { try f.parent.validateRoot() })
            }
            do {
                let f = try Fixture(), actual = try await f.actualParent()
                f.bindings.selectedTab.wrappedValue = .history; f.bindings.selectedTab.wrappedValue = .viewer
                record("root_ABA_revokes_exact_parent", refuses { try f.parent.validateParent(actual, command: f.command) })
            }
            do {
                let f = try Fixture(), actual = try await f.actualParent()
                f.bindings.showSettings.wrappedValue = true; f.bindings.showSettings.wrappedValue = false
                record("settings_ABA_revokes_exact_parent", refuses { try f.parent.validateParent(actual, command: f.command) })
            }
            do {
                let f = try Fixture(), actual = try await f.actualParent()
                f.parent.release()
                record("released_source_never_authorizes_selection", refuses { try f.parent.beginSelection(actual, command: f.command) })
            }
        } catch { rows.append(["name": "unexpected_error", "pass": false, "error": String(describing: error)]) }
        let failures = rows.filter { !($0["pass"] as! Bool) }
        print(String(data: try! JSONSerialization.data(withJSONObject: ["rows": rows, "pass_count": rows.count-failures.count, "fail_count": failures.count,
            "boundary": "Actual owner/source/setter bodies; explicit UIKit/app-domain substitutes; no Core grant or native UI acceptance"], options: [.sortedKeys]), encoding: .utf8)!)
        if !failures.isEmpty { exit(1) }
    }
}
