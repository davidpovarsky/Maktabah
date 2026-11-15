#if os(iOS)
import Foundation
import Observation
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

/// One instance per actual UIKit session. The app supplies the SAME directory /
/// S facade used by Core and its current lifetime validator at composition.
/// Native mutations remain behind P's canonical precommit guard.
@MainActor @Observable
final class MaktabahNativeSceneSession: NativeSceneDriver {
    let sceneID: UIStableID
    let presentation: NativePresentationObserver
    private(set) var submissionID: UUID?
    private(set) var mounted = true
    var foreground = false
    private let directory: NativeSceneDirectory
    private var project: @MainActor () throws -> MaktabahNativeSceneProjection
    private let bindings: MaktabahNativeSceneBindings
    private var lease: NativeSceneDirectory.Lease?
    private var command: UISceneCommand?
    private var visible: [UIDestinationID: NativeSurfaceWitness.Evidence] = [:]

    init(sceneID: UIStableID, directory: NativeSceneDirectory, bindings: MaktabahNativeSceneBindings,
         project: @escaping @MainActor () throws -> MaktabahNativeSceneProjection) {
        self.sceneID = sceneID; self.directory = directory; self.project = project
        self.bindings = bindings
        presentation = NativePresentationObserver(sceneID: sceneID)
    }

    func mount(validateLifetime: @escaping NativeSceneDirectory.ValidateLifetime) throws {
        guard lease == nil, mounted else { throw UIRouteError(.staleState, "scene_session_already_mounted") }
        lease = try directory.mount(sceneID: sceneID, observe: { [weak self] in
            guard let self, mounted else { throw UIRouteError(.unavailable, "scene_missing") }
            let projection = try project()
            var route: RouteSpec?
            var surface: NativeSurfaceState?
            if let command, let evidence = visible[command.route.route.destination], evidence.isVisible,
               evidence.sceneID == sceneID, evidence.submissionID == command.invocation.requestId,
               let kind = surfaceKind(command.route.route.destination), let current = try projection.surface(kind),
               current == evidence.surface {
                surface = current
                route = current.observedRoute(for: command, backend: command.invocation.snapshot)
            }
            return .init(isForeground: foreground, isMounted: mounted, visibleRoute: route, surface: surface, identity: try projection.identity())
        }, validateLifetime: validateLifetime)
    }

    /// Preparation for the observer only; caller must possess the canonical
    /// Core grant before invoking any native binding/model mutation afterwards.
    func beginObservation(_ value: UISceneCommand) throws {
        guard mounted, lease != nil, value.scene.sceneID == sceneID else { throw UIRouteError(.staleState, "scene_lifetime_changed") }
        try presentation.begin(value)
        command = value; submissionID = value.invocation.requestId
    }

    func validateSurface(_ command: UISceneCommand) throws {
        guard mounted, foreground else { throw UIRouteError(.requiresForeground, "exact_foreground_scene_required") }
        let route = command.route.route, projection = try project(), identity = try projection.identity()
        guard command.scene.sceneID == sceneID, route.state.workspaceID == identity.state.workspaceID,
              route.state.profileID == identity.state.profileID else { throw UIRouteError(.staleState, "native_workspace_changed") }
        guard route.content == nil, route.focus == nil, route.presentation.tabID == nil,
              route.state == UIStateSpec(workspaceID: identity.state.workspaceID, profileID: identity.state.profileID) else {
            throw UIRouteError(.notSupported, "native_surface_variant_not_installed")
        }
        switch route.destination.rawValue {
        case "native.settings":
            guard route.presentation.kind == .sheet else { throw UIRouteError(.notSupported, "settings_presentation_not_installed") }
        case "native.history":
            guard route.presentation.kind == .currentTab, HistoryViewModel.shared.searchText.isEmpty else { throw UIRouteError(.notSupported, "history_presentation_not_installed") }
        default: throw UIRouteError(.notSupported, "native_surface_not_installed")
        }
    }

    func apply(_ command: UISceneCommand) throws { try bindings.apply(command) }

    func waitUntilVisible(_ command: UISceneCommand) async throws -> NativeSurfaceState {
        try await presentation.wait(for: command).surface
    }

    func nativeStateChanged() throws {
        guard let lease else { return }
        try directory.invalidate(lease)
    }

    func updateProjection(_ project: @escaping @MainActor () throws -> MaktabahNativeSceneProjection) {
        self.project = project
    }
    func surface(_ kind: MaktabahNativeSceneProjection.Surface) throws -> NativeSurfaceState? { try project().surface(kind) }
    func windowLabel(number: Int) -> String {
        let projection = try? project()
        let names = [projection?.workspace?.profile?.name, projection?.workspace?.group?.name]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " / ")
        let window = String(localized: "Window \(number)")
        return names.isEmpty ? window : names + " — " + window
    }

    func prepare(_ route: PublicRouteSpec, invocation: ActionPortInvocation, scene: UISceneSnapshot) throws -> RouteSpec {
        guard route.destination.rawValue == "native.history", route.content == nil, route.presentation == .currentTab else {
            throw UIRouteError(.notSupported, "public_native_variant_not_installed")
        }
        let identity = try project().identity()
        return RouteSpec(requestId: invocation.requestId, destination: route.destination, backend: invocation.snapshot.backend,
            state: .init(workspaceID: identity.state.workspaceID, profileID: identity.state.profileID),
            scene: .init(kind: .specific, sceneID: sceneID, expectedRevision: scene.revision), expectedBackendSnapshot: invocation.snapshot)
    }

    func prepare(destination: UIDestinationID, invocation: ActionPortInvocation, scene: UISceneSnapshot) throws -> RouteSpec {
        guard destination.rawValue == "native.settings" || destination.rawValue == "native.history" else { throw UIRouteError(.notSupported, "native_surface_not_installed") }
        let identity = try project().identity()
        return RouteSpec(requestId: invocation.requestId, destination: destination, backend: invocation.snapshot.backend,
            presentation: .init(kind: destination.rawValue == "native.settings" ? .sheet : .currentTab),
            state: .init(workspaceID: identity.state.workspaceID, profileID: identity.state.profileID),
            scene: .init(kind: .specific, sceneID: sceneID, expectedRevision: scene.revision), expectedBackendSnapshot: invocation.snapshot)
    }

    func observe(_ evidence: NativeSurfaceWitness.Evidence) {
        guard mounted, evidence.sceneID == sceneID else { return }
        let prior = visible[evidence.surface.destination]
        if evidence.isVisible { visible[evidence.surface.destination] = evidence }
        else { visible.removeValue(forKey: evidence.surface.destination) }
        if prior != visible[evidence.surface.destination] { try? nativeStateChanged() }
        guard evidence.isVisible, let requestID = evidence.submissionID else { return }
        presentation.report(.init(sceneID: evidence.sceneID, submissionID: requestID, surface: evidence.surface))
    }

    func endObservation(requestID: UUID) {
        guard submissionID == requestID else { return }
        presentation.end(requestID: requestID); submissionID = nil
        // Keep only the independently observed surface. Clear private request
        // metadata after its owner has validated the complete visible receipt.
        command = nil
    }

    func unmount() {
        guard mounted else { return }
        mounted = false; presentation.revoke(); submissionID = nil; command = nil; visible.removeAll()
        if let lease { directory.unmount(lease) }
        lease = nil
    }

    private func surfaceKind(_ destination: UIDestinationID) -> MaktabahNativeSceneProjection.Surface? {
        switch destination.rawValue {
        case "native.library": .library
        case "native.reader.toc": .tableOfContents
        case "native.reader": .reader
        case "native.history": .history
        case "native.settings": .settings
        default: nil
        }
    }
}
#endif
