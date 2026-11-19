#if os(iOS)
import Foundation
import Observation
import UIKit
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
    let workspaceProjectionSource: MaktabahNativeWorkspaceProjectionSource?
    private var lease: NativeSceneDirectory.Lease?
    private var command: UISceneCommand?
    var readerBinding: MaktabahNativeReaderBinding?
    @ObservationIgnored private weak var nativeSearchField: UISearchTextField?
    @ObservationIgnored private var retainedSearchField: UISearchTextField?
    @ObservationIgnored private var searchFieldUpdateScheduled = false
    @ObservationIgnored private var inspectorBinding: MaktabahNativeInspectorBinding?
    private var searchFieldRevision: UInt64 = 0

    // This is the original scene-owned UIKit control, installed by its existing
    // representable. No lookup through global windows or runtime class names.
    func attachSearchField(_ field: UISearchTextField) {
        guard nativeSearchField !== field else { return }
        if retainedSearchField != nil { presentation.revoke() }
        nativeSearchField = field
        searchFieldStateDidChange(field)
    }

    func detachSearchField(_ field: UISearchTextField) {
        guard nativeSearchField === field else { return }
        if retainedSearchField === field { presentation.revoke() }
        nativeSearchField = nil
        // Ownership invalidation is synchronous even if the SwiftUI graph has
        // not rendered yet, including detach/reattach ABA during Core awaits.
        try? nativeStateChanged()
        scheduleSearchFieldObservation()
    }

    func searchFieldStateDidChange(_ field: UISearchTextField) {
        guard nativeSearchField === field else { return }
        try? nativeStateChanged()
        scheduleSearchFieldObservation()
    }

    private func scheduleSearchFieldObservation() {
        // UIKit attachment can happen inside updateUIView. Only the graph
        // notification is deferred; the original directory revision has already
        // changed synchronously above. Never defer authority invalidation.
        guard !searchFieldUpdateScheduled else { return }
        searchFieldUpdateScheduled = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            searchFieldUpdateScheduled = false
            searchFieldRevision &+= 1
        }
    }

    private var searchFieldAvailable: Bool {
        guard mounted, foreground, isPresentationReady, let field = nativeSearchField,
              (try? project().surface(.search)) != nil,
              let evidence = visibilityChecks[NativeSearchFieldVisibility.destination]?(),
              evidence.isVisible, evidence.sceneID == sceneID,
              evidence.surface.destination == NativeSearchFieldVisibility.destination else { return false }
        return NativeSearchFieldVisibility.isVisible(field, in: sceneID)
    }
    private var visible: [UIDestinationID: NativeSurfaceWitness.Evidence] = [:]
    @ObservationIgnored private var visibilityChecks: [UIDestinationID: @MainActor () -> NativeSurfaceWitness.Evidence?] = [:]
    private(set) var studyChatPresentationID: UUID?
    var isPresentationReady: Bool { bindings.isPresentationReady && studyChatPresentationID == nil }

    func beginStudyChatPresentation(_ id: UUID) throws {
        guard mounted, foreground, isPresentationReady else {
            throw UIRouteError(.unavailable, "native_presentation_in_progress")
        }
        studyChatPresentationID = id
        do { try nativeStateChanged() }
        catch { studyChatPresentationID = nil; throw error }
        presentation.revoke()
    }
    func finishStudyChatPresentation(_ id: UUID) {
        guard studyChatPresentationID == id else { return }
        studyChatPresentationID = nil
        try? nativeStateChanged()
    }
    /// Only this exact app-owned sheet may use its underlying source identity.
    /// Other native routes stay unavailable until actual onDismiss, including
    /// the period after the SDK lease is revoked but its sheet is still visible.
    func isStudyChatContextReady(allowing id: UUID?) -> Bool {
        bindings.isPresentationReady && (studyChatPresentationID == nil || studyChatPresentationID == id)
    }
    func isRootAvailable(_ destination: UIDestinationID) -> Bool {
        guard let root = MaktabahNativeRootDestination(rawValue: destination.rawValue) else { return false }
        return bindings.isRootAvailable(root)
    }

    init(sceneID: UIStableID, directory: NativeSceneDirectory, bindings: MaktabahNativeSceneBindings,
         workspaceSource: MaktabahNativeWorkspaceProjectionSource? = nil,
         project: @escaping @MainActor () throws -> MaktabahNativeSceneProjection) {
        self.sceneID = sceneID; self.directory = directory; self.project = project
        self.bindings = bindings
        workspaceProjectionSource = workspaceSource
        presentation = NativePresentationObserver(sceneID: sceneID)
    }

    func mount(validateLifetime: @escaping NativeSceneDirectory.ValidateLifetime) throws {
        guard lease == nil, mounted else { throw UIRouteError(.staleState, "scene_session_already_mounted") }
        lease = try directory.mount(sceneID: sceneID, observe: { [weak self] in
            guard let self, mounted else { throw UIRouteError(.unavailable, "scene_missing") }
            let projection = try project()
            var route: RouteSpec?
            var surface: NativeSurfaceState?
            if isPresentationReady, let command, let evidence = visible[command.route.route.destination], evidence.isVisible,
               let currentEvidence = visibilityChecks[command.route.route.destination]?(), currentEvidence == evidence,
               evidence.sceneID == sceneID, evidence.submissionID == command.invocation.requestId,
               let kind = surfaceKind(command.route.route.destination), let current = try self.surface(kind),
               current == evidence.surface,
               kind != .reader || projection.hasRenderedReaderEvidence(sceneID: sceneID) {
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
        let field: UISearchTextField?
        if value.route.route.focus != nil {
            guard value.route.route.destination == NativeSearchFieldVisibility.destination,
                  value.route.route.focus == NativeSearchFieldVisibility.focus,
                  searchFieldAvailable, let original = nativeSearchField else {
                throw UIRouteError(.unavailable, "native_search_field_not_visible")
            }
            field = original
        } else { field = nil }
        let inspector: MaktabahNativeInspectorBinding?
        if value.route.route.destination.rawValue == "native.reader.inspector" {
            guard try publicBindingPresentation().inspectorAvailable else {
                throw UIRouteError(.unavailable, "native_inspector_reader_unavailable")
            }
            inspector = try MaktabahNativeInspectorBinding(manager: bindings.manager)
        } else { inspector = nil }
        try presentation.begin(value)
        inspectorBinding = inspector
        retainedSearchField = field
        command = value; submissionID = value.invocation.requestId
    }

    func retainReader(_ content: ActionReaderDestination, requestID: UUID,
                      revoke: @escaping @MainActor () -> Void) throws -> MaktabahNativeReaderBinding {
        guard readerBinding == nil else { throw UIRouteError(.unavailable, "reader_binding_busy") }
        let identity = try project().identity()
        let workspace = try workspaceProjectionSource?.read()
        if content.presentationMode == .newTab, workspaceProjectionSource?.isAuthoritative != true {
            throw UIRouteError(.unavailable, "new_reader_workspace_unavailable")
        }
        let retained = try MaktabahNativeReaderBinding(manager: bindings.manager,
            currentTabID: identity.activeTabID, workspace: workspace, requestID: requestID, content: content, revoke: revoke)
        readerBinding = retained
        return retained
    }
    func releaseReader(_ retained: MaktabahNativeReaderBinding) {
        guard readerBinding === retained else { return }
        retained.release(); readerBinding = nil
    }

    func validateSurface(_ command: UISceneCommand) throws {
        guard mounted, foreground else { throw UIRouteError(.requiresForeground, "exact_foreground_scene_required") }
        guard isPresentationReady else { throw UIRouteError(.unavailable, "native_presentation_in_progress") }
        let route = command.route.route, projection = try project(), identity = try projection.identity()
        guard command.scene.sceneID == sceneID, route.state.workspaceID == identity.state.workspaceID,
              route.state.profileID == identity.state.profileID else { throw UIRouteError(.staleState, "native_workspace_changed") }
        if route.destination.rawValue == "native.reader.inspector" {
            guard route.content == nil, route.focus == nil, route.presentation.kind == .inspector,
                  route.presentation.tabID == nil,
                  route.state == UIStateSpec(workspaceID: identity.state.workspaceID,
                      profileID: identity.state.profileID, inspectorVisible: true),
                  try publicBindingPresentation().inspectorAvailable else {
                throw UIRouteError(.unavailable, "native_inspector_reader_unavailable")
            }
            try inspectorBinding?.validate()
            return
        }
        if route.destination.rawValue == "native.reader" {
            guard let content = route.content, let readerBinding, readerBinding.accepts(content),
                  route.presentation.kind == (readerBinding.isNewTab ? .newTab : .currentTab),
                  route.presentation.tabID == readerBinding.targetTabID, route.focus == nil,
                  route.state == UIStateSpec(workspaceID: identity.state.workspaceID, profileID: identity.state.profileID,
                                              inspectorVisible: readerBinding.inspectorVisible) else {
                throw UIRouteError(.notSupported, "native_reader_variant_not_installed")
            }
            try readerBinding.validate()
            return
        }
        if let focus = route.focus {
            guard route.destination == NativeSearchFieldVisibility.destination,
                  focus == NativeSearchFieldVisibility.focus, searchFieldAvailable,
                  retainedSearchField == nil || retainedSearchField === nativeSearchField else {
                throw UIRouteError(.unavailable, "native_search_field_not_visible")
            }
        }
        guard route.content == nil, route.presentation.tabID == nil,
              route.state == UIStateSpec(workspaceID: identity.state.workspaceID, profileID: identity.state.profileID) else {
            throw UIRouteError(.notSupported, "native_surface_variant_not_installed")
        }
        switch route.destination.rawValue {
        case "native.settings":
            guard route.presentation.kind == .sheet else { throw UIRouteError(.notSupported, "settings_presentation_not_installed") }
        case "native.library", "native.reader.toc", "native.history", "native.search", "native.annotations":
            guard route.presentation.kind == .currentTab, isRootAvailable(route.destination) else {
                throw UIRouteError(.notSupported, "native_root_presentation_unavailable")
            }
        default: throw UIRouteError(.notSupported, "native_surface_not_installed")
        }
    }

    func apply(_ command: UISceneCommand) throws {
        if command.route.route.destination.rawValue == "native.reader.inspector" {
            try validateSurface(command)
            guard let inspectorBinding else { throw UIRouteError(.unavailable, "native_inspector_owner_missing") }
            try inspectorBinding.apply()
            return
        }
        if command.route.route.focus != nil {
            // Focus only an ALREADY VISIBLE original field. A caller first
            // opens the Search root through this same orchestrator, then
            // requests its component; no deferred mutation borrows a grant.
            try validateSurface(command)
            guard let field = retainedSearchField, nativeSearchField === field,
                  field.isFirstResponder || field.becomeFirstResponder(),
                  nativeSearchField === field, field.isFirstResponder,
                  NativeSearchFieldVisibility.isVisible(field, in: sceneID) else {
                throw UIRouteError(.unavailable, "native_search_focus_not_applied")
            }
            searchFieldStateDidChange(field)
            return
        }
        if command.route.route.destination.rawValue == "native.reader" {
            guard let readerBinding else { throw UIRouteError(.unavailable, "native_reader_owner_missing") }
            try readerBinding.apply { try bindings.apply(command, reservedTab: readerBinding.reservedTab) }
        } else { try bindings.apply(command) }
    }

    func waitUntilVisible(_ command: UISceneCommand) async throws -> NativeSurfaceState {
        // A container's deduplicated layout callback can precede TextKit's
        // paint/scroll restoration. Observe that same live UIKit witness only
        // while this original reader request is waiting; never echo the route.
        let readerObservation: Task<Void, Never>?
        if command.route.route.destination.rawValue == "native.reader" {
            readerObservation = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    guard let self, mounted, submissionID == command.invocation.requestId else { return }
                    if let actual = visibilityChecks[command.route.route.destination]?() { observe(actual) }
                    do { try await Task.sleep(for: .milliseconds(33)) } catch { return }
                }
            }
        } else { readerObservation = nil }
        defer { readerObservation?.cancel() }
        do { return try await presentation.wait(for: command).surface }
        catch {
            #if DEBUG
            OtzariaFileLogger.shared.log("[NativePresentationWait] code=\((error as? UIRouteError)?.code ?? (error is CancellationError ? "cancelled" : "unavailable")) mounted=\(mounted) foreground=\(foreground) ready=\(isPresentationReady)")
            #endif
            throw error
        }
    }

    func nativeStateChanged() throws {
        guard let lease else { return }
        try directory.invalidate(lease)
    }

    func updateProjection(_ project: @escaping @MainActor () throws -> MaktabahNativeSceneProjection) {
        self.project = project
    }
    func surface(_ kind: MaktabahNativeSceneProjection.Surface) throws -> NativeSurfaceState? {
        if kind == .inspector { try inspectorBinding?.validate() }
        guard let state = try project().surface(kind) else { return nil }
        // Root navigation does not request or report keyboard focus. For the
        // registered component, the optional focus facet is projected ONLY
        // from the same retained, visible UIKit field's actual responder state.
        // The incoming anchor is never copied into native evidence.
        guard state.destination == NativeSearchFieldVisibility.destination,
              command?.route.route.focus != nil else { return state }
        _ = searchFieldRevision
        let actual: FocusSpec?
        if let field = retainedSearchField, nativeSearchField === field, field.isFirstResponder,
           NativeSearchFieldVisibility.isVisible(field, in: sceneID) {
            actual = NativeSearchFieldVisibility.focus
        } else { actual = nil }
        return .init(destination: state.destination, presentation: state.presentation,
            content: state.content, state: state.state, focus: actual)
    }
    func usesWorkspaceOwner(_ owner: MaktabahNativeWorkspaceOwner) -> Bool { workspaceProjectionSource?.uses(owner) == true }
    /// Passive independent evidence only. With the reader marker absent this
    /// stays nil even if a reader model contains the requested destination.
    func publicBindingPresentation() throws -> MaktabahNativePublicPresentation {
        let readerID = UIDestinationID(rawValue: "native.reader")!
        var reader: NativeSurfaceState?
        if let evidence = visibilityChecks[readerID]?(), evidence.isVisible, evidence.sceneID == sceneID,
           let current = try project().surface(.reader),
           current == evidence.surface,
           try project().hasRenderedReaderEvidence(sceneID: sceneID) { reader = current }
        let inspectorID = UIDestinationID(rawValue: "native.reader.inspector")!
        let inspectorWitnessed: Bool
        if let evidence = visibilityChecks[inspectorID]?(), evidence.isVisible, evidence.sceneID == sceneID,
           let actual = try surface(.inspector), actual == evidence.surface { inspectorWitnessed = true }
        else { inspectorWitnessed = false }
        let inspectorAvailable = MaktabahNativeInspectorBinding.currentReader(in: bindings.manager) != nil
            && (reader != nil || inspectorWitnessed)
        return .init(ready: mounted && foreground && isPresentationReady,
            historyRootAvailable: HistoryViewModel.shared.searchText.isEmpty,
            tableOfContentsAvailable: bindings.isRootAvailable(.tableOfContents), witnessedReader: reader,
            searchFieldAvailable: searchFieldAvailable, inspectorAvailable: inspectorAvailable)
    }
    /// A freshness facet from the existing scene projection; no selected text or content grant.
    func hanlinSelectionRange() throws -> UIUTF16Range? { try project().identity().selectedRange }
    func ownsInspectorReader(_ reader: ReaderViewModel) -> Bool {
        MaktabahNativeInspectorBinding.currentReader(in: bindings.manager) === reader
    }
    func observeVisibility(for destination: UIDestinationID, check: @escaping @MainActor () -> NativeSurfaceWitness.Evidence?) {
        visibilityChecks[destination] = check
    }
    func windowLabel(number: Int) -> String {
        let projection = try? project()
        let names = [projection?.workspace?.profile?.name, projection?.workspace?.group?.name]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " / ")
        let window = String(localized: "Window \(number)")
        return names.isEmpty ? window : names + " â€” " + window
    }

    func prepare(_ route: PublicRouteSpec, invocation: ActionPortInvocation, scene: UISceneSnapshot) throws -> RouteSpec {
        guard isRootAvailable(route.destination),
              route.content == nil, route.presentation == .currentTab else {
            throw UIRouteError(.notSupported, "public_native_variant_not_installed")
        }
        let identity = try project().identity()
        return RouteSpec(requestId: invocation.requestId, destination: route.destination, backend: invocation.snapshot.backend,
            state: .init(workspaceID: identity.state.workspaceID, profileID: identity.state.profileID),
            scene: .init(kind: .specific, sceneID: sceneID, expectedRevision: scene.revision), expectedBackendSnapshot: invocation.snapshot)
    }

    func prepare(destination: UIDestinationID, invocation: ActionPortInvocation, scene: UISceneSnapshot) throws -> RouteSpec {
        guard destination.rawValue == "native.settings" || isRootAvailable(destination) else { throw UIRouteError(.notSupported, "native_surface_not_installed") }
        let identity = try project().identity()
        return RouteSpec(requestId: invocation.requestId, destination: destination, backend: invocation.snapshot.backend,
            presentation: .init(kind: destination.rawValue == "native.settings" ? .sheet : .currentTab),
            state: .init(workspaceID: identity.state.workspaceID, profileID: identity.state.profileID),
            scene: .init(kind: .specific, sceneID: sceneID, expectedRevision: scene.revision), expectedBackendSnapshot: invocation.snapshot)
    }

    func observe(_ evidence: NativeSurfaceWitness.Evidence) {
        guard mounted, evidence.sceneID == sceneID else { return }
        if evidence.isVisible, evidence.surface.destination.rawValue == "native.reader",
           (try? project().hasRenderedReaderEvidence(sceneID: sceneID)) != true {
            if visible.removeValue(forKey: evidence.surface.destination) != nil { try? nativeStateChanged() }
            return
        }
        #if DEBUG
        if evidence.submissionID != nil {
            let matches = command.map { evidence.surface.observedRoute(for: $0, backend: $0.invocation.snapshot) == $0.route.route } ?? false
            OtzariaFileLogger.shared.log("[NativeSurfaceObservation] destination=\(evidence.surface.destination.rawValue) visible=\(evidence.isVisible) matches=\(matches)")
        }
        #endif
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
        command = nil; retainedSearchField = nil; inspectorBinding = nil
    }

    func unmount() {
        guard mounted else { return }
        mounted = false; presentation.revoke(); submissionID = nil; command = nil; visible.removeAll(); visibilityChecks.removeAll()
        nativeSearchField = nil; retainedSearchField = nil; inspectorBinding = nil
        if let lease { directory.unmount(lease) }
        lease = nil
    }

    private func surfaceKind(_ destination: UIDestinationID) -> MaktabahNativeSceneProjection.Surface? {
        switch destination.rawValue {
        case "native.library": .library
        case "native.reader.toc": .tableOfContents
        case "native.reader": .reader
        case "native.reader.inspector": .inspector
        case "native.history": .history
        case "native.search": .search
        case "native.annotations": .annotations
        case "native.settings": .settings
        default: nil
        }
    }
}

/// Geometry and responder ownership belong to UIKit, independently of route
/// metadata. Only the control explicitly supplied by its own representable is
/// inspected; walking its actual ancestors does not discover arbitrary views.
@MainActor private enum NativeSearchFieldVisibility {
    static let destination = UIDestinationID(rawValue: "native.search")!
    static let focus = FocusSpec(kind: .component, anchor: UIDestinationID(rawValue: "native.search.query")!)

    static func isVisible(_ field: UISearchTextField, in expectedScene: UIStableID) -> Bool {
        guard field.isEnabled, field.canBecomeFirstResponder,
              let window = field.window, window.isKeyWindow, !window.isHidden,
              let scene = window.windowScene, scene.activationState == .foregroundActive,
              scene.session.persistentIdentifier == expectedScene.rawValue else { return false }
        let target = field.convert(field.bounds, to: window)
        let intersection = target.intersection(window.bounds), area = target.width * target.height
        guard !target.isEmpty, area.isFinite, area > 0, !intersection.isNull,
              intersection.width * intersection.height >= area * 0.98 else { return false }
        var current: UIView? = field
        var alpha: CGFloat = 1
        while let view = current {
            guard !view.isHidden else { return false }
            alpha *= view.alpha; current = view.superview
        }
        guard alpha >= 0.95 else { return false }
        var top = window.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        if let top, top !== window.rootViewController, !field.isDescendant(of: top.view) { return false }
        return true
    }
}
#endif
