#if os(iOS)
import Foundation
import Observation
import SwiftUI
import UIKit
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

/// The original root identity view owns this observation. Both UIKit references
/// are weak, and a detached older view cannot erase a newer registration.
@MainActor final class MaktabahNativeWindowSource {
    private weak var source: UIView?
    private weak var window: UIWindow?

    @discardableResult
    func observe(_ window: UIWindow?, from source: UIView) -> Bool {
        if window == nil {
            guard self.source === source else { return false }
            self.source = nil; self.window = nil
            return true
        }
        guard self.source !== source || self.window !== window else { return false }
        self.source = source; self.window = window
        return true
    }

    func isPresentationReady(in sceneID: UIStableID) -> Bool {
        guard let source, let window, source.window === window,
              window.isKeyWindow, !window.isHidden, window.alpha >= 0.95,
              let scene = window.windowScene, scene.activationState == .foregroundActive,
              scene.session.persistentIdentifier == sceneID.rawValue,
              let root = window.rootViewController, root.viewIfLoaded?.window === window else { return false }
        // Read the original controller tree now, including the dismissal
        // interval after a SwiftUI sheet binding has already become false.
        var controllers = [root]
        while let controller = controllers.popLast() {
            guard controller.presentedViewController == nil,
                  !controller.isBeingPresented, !controller.isBeingDismissed,
                  controller.transitionCoordinator == nil else { return false }
            controllers.append(contentsOf: controller.children)
        }
        return true
    }
}

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
    var searchResultsBinding: MaktabahNativeSearchResultsBinding?
    @ObservationIgnored private weak var nativeSearchField: UISearchTextField?
    @ObservationIgnored private var retainedSearchField: UISearchTextField?
    @ObservationIgnored private var searchFieldUpdateScheduled = false
    @ObservationIgnored private var inspectorBinding: MaktabahNativeInspectorBinding?
    @ObservationIgnored private var noteEditorOwner: MaktabahNativeNoteEditorOwner?
    @ObservationIgnored private var noteDraftBinding: MaktabahNativeNoteDraftBinding?
    private var searchFieldRevision: UInt64 = 0
    @ObservationIgnored private weak var windowSource: MaktabahNativeWindowSource?
    @ObservationIgnored private var searchPresentationOwner: UUID?
    @ObservationIgnored private var searchPresentationBlocked: (@MainActor () -> Bool)?

    func attachWindowSource(_ source: MaktabahNativeWindowSource) {
        guard mounted else { return }
        windowSource = source
    }
    func nativeWindowDidChange(_ source: MaktabahNativeWindowSource) {
        guard mounted, windowSource === source else { return }
        presentation.revoke()
        try? nativeStateChanged()
    }
    func observeSearchPresentation(owner: UUID, isBlocked: @escaping @MainActor () -> Bool) {
        guard mounted else { return }
        searchPresentationOwner = owner; searchPresentationBlocked = isBlocked
    }
    func removeSearchPresentation(owner: UUID) {
        guard searchPresentationOwner == owner else { return }
        // A hidden Search tab can retain its opaque FTS overlay state. Keep
        // that original blocker until the actual owner clears/replaces it;
        // reopening Search semantically must not submit behind a restored mask.
        guard searchPresentationBlocked?() != true else { return }
        searchPresentationOwner = nil; searchPresentationBlocked = nil
    }
    private func validateSearchPresentation() throws {
        guard windowSource?.isPresentationReady(in: sceneID) == true,
              searchPresentationBlocked?() != true else {
            throw UIRouteError(.unavailable, "native_search_presentation_in_progress")
        }
    }

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
    var isPresentationReady: Bool {
        bindings.isPresentationReady && studyChatPresentationID == nil
            && ((noteEditorOwner?.current == nil && noteEditorOwner?.presentationActive != true)
                || (command?.route.route.destination.rawValue == "native.reader.noteDraft" && noteDraftBinding?.isApplied == true))
    }

    func attachNoteEditor(id: UUID, reader: ReaderViewModel, annotation: Binding<Annotation?>,
                          presentationID: @escaping @MainActor () -> UUID) {
        if noteEditorOwner?.id == id, noteEditorOwner?.reader === reader { return }
        if noteDraftBinding != nil { presentation.revoke() }
        noteEditorOwner = .init(id: id, reader: reader, annotation: annotation, presentationID: presentationID)
        try? nativeStateChanged()
    }
    func detachNoteEditor(id: UUID) {
        guard noteEditorOwner?.id == id else { return }
        noteEditorOwner = nil
        presentation.revoke()
        try? nativeStateChanged()
    }
    func noteEditorTextViewChanged(id: UUID, reader: ReaderViewModel, presentationID: UUID, textView: UITextView?) {
        guard let owner = noteEditorOwner, owner.id == id, owner.reader === reader else { return }
        guard owner.observeTextView(textView, presentationID: presentationID) else { return }
        try? nativeStateChanged()
    }
    func noteEditorDidDismiss(id: UUID, presentationID: UUID) {
        guard let owner = noteEditorOwner, owner.id == id else { return }
        guard owner.didDismiss(presentationID: presentationID) else { return }
        try? nativeStateChanged()
    }
    func ownsNoteEditor(_ reader: ReaderViewModel, draft: Annotation) -> Bool {
        guard let owner = noteEditorOwner, owner.reader === reader, owner.current == draft,
              let bound = noteDraftBinding, bound.owner === owner, bound.draft == draft else { return false }
        return true
    }
    func canPrepareNoteDraft() -> Bool {
        guard mounted, foreground, isPresentationReady, noteDraftBinding == nil,
              let owner = noteEditorOwner, owner.current == nil,
              (try? publicBindingPresentation().witnessedReader) != nil else { return false }
        return (try? MaktabahNativeNoteDraftBinding.selection(manager: bindings.manager, owner: owner, sceneID: sceneID)) != nil
    }
    func retainNoteDraft(_ request: ActionNoteDraftRequest) throws -> MaktabahNativeNoteDraftBinding {
        guard canPrepareNoteDraft(), let owner = noteEditorOwner else { throw ActionPortError.unavailable }
        let bound = try MaktabahNativeNoteDraftBinding(manager: bindings.manager, owner: owner, request: request, sceneID: sceneID)
        noteDraftBinding = bound
        return bound
    }
    func releaseNoteDraft(_ bound: MaktabahNativeNoteDraftBinding) {
        if noteDraftBinding === bound { noteDraftBinding = nil }
        // The original unsaved editor remains under the user's Save/Cancel.
    }
    func prepareNoteDraftRoute(invocation: ActionPortInvocation, scene: UISceneSnapshot) throws -> RouteSpec {
        guard let bound = noteDraftBinding else { throw ActionPortError.unavailable }
        try bound.validate()
        let identity = try project().identity()
        return RouteSpec(requestId: invocation.requestId, destination: UIDestinationID(rawValue: "native.reader.noteDraft")!,
            backend: invocation.snapshot.backend, presentation: .init(kind: .sheet),
            state: .init(workspaceID: identity.state.workspaceID, profileID: identity.state.profileID),
            scene: .init(kind: .specific, sceneID: sceneID, expectedRevision: scene.revision),
            expectedBackendSnapshot: invocation.snapshot)
    }
    func validateNoteDraftCompletion(_ bound: MaktabahNativeNoteDraftBinding, route: RouteSpec) throws {
        guard mounted, foreground, noteDraftBinding === bound, noteEditorOwner === bound.owner else { throw ActionPortError.staleState }
        try bound.validateVisible()
        let id = UIDestinationID(rawValue: "native.reader.noteDraft")!
        guard let actual = visibilityChecks[id]?(), actual.isVisible, actual.sceneID == sceneID,
              actual.surface == (try surface(.noteDraft)),
              actual.surface.destination == route.destination, actual.surface.presentation == route.presentation,
              actual.surface.state == route.state, actual.surface.content == nil, actual.surface.focus == nil else {
            throw ActionPortError.staleState
        }
    }

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
        bindings.isPresentationReady && noteEditorOwner?.current == nil && noteEditorOwner?.presentationActive != true
            && (studyChatPresentationID == nil || studyChatPresentationID == id)
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
               (kind != .reader || projection.hasRenderedReaderEvidence(sceneID: sceneID)),
               (kind != .noteDraft || (try? noteDraftBinding?.validateVisible()) != nil) {
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
        if route.destination.rawValue == "native.reader.noteDraft" {
            guard route.content == nil, route.focus == nil, route.presentation.kind == .sheet,
                  route.presentation.tabID == nil,
                  route.state == UIStateSpec(workspaceID: identity.state.workspaceID, profileID: identity.state.profileID),
                  let bound = noteDraftBinding, noteEditorOwner === bound.owner else {
                throw UIRouteError(.unavailable, "original_note_editor_unavailable")
            }
            try bound.validate()
            return
        }
        if route.destination.rawValue == "native.search.results" {
            try validateSearchPresentation()
            guard route.content == nil, route.focus == nil, route.presentation.kind == .currentTab,
                  route.presentation.tabID == nil, let searchResultsBinding,
                  searchResultsBinding.requestID == command.invocation.requestId,
                  route.state == UIStateSpec(workspaceID: identity.state.workspaceID, profileID: identity.state.profileID) else {
                throw UIRouteError(.notSupported, "native_search_results_variant_not_installed")
            }
            try searchResultsBinding.validate()
            return
        }
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
        if command.route.route.destination.rawValue == "native.reader.noteDraft" {
            try validateSurface(command)
            guard let bound = noteDraftBinding else { throw ActionPortError.unavailable }
            try bound.apply()
            return
        }
        if command.route.route.destination.rawValue == "native.search.results" {
            try validateSurface(command)
            guard let searchResultsBinding else { throw UIRouteError(.unavailable, "native_search_owner_missing") }
            try searchResultsBinding.apply {
                bindings.showSettings.wrappedValue = false
                if !MaktabahApp.isIpad { bindings.manager.selectedBook = nil }
                bindings.selectedTab.wrappedValue = .search
                bindings.manager.switchToMode(.search)
            }
            return
        }
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
        if ["native.reader", "native.reader.noteDraft"].contains(command.route.route.destination.rawValue) {
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
        if kind == .noteDraft {
            guard let bound = noteDraftBinding, bound.isApplied, noteEditorOwner === bound.owner else { return nil }
            try bound.validate()
        }
        if kind == .searchResults {
            // Allow the native witness to mount during this route's own
            // transition so UIKit can report viewDidAppear. The exact window
            // is rechecked at completion; local overlays must hide the witness.
            guard searchPresentationBlocked?() != true else { return nil }
            guard let searchResultsBinding else { return nil }
            try searchResultsBinding.validateCompleted()
        }
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

    /// Synchronous readiness for Core capability/availability checks. This
    /// observes only the original scene, presentation and search model; it
    /// neither submits a query nor acquires a request-specific binding.
    func canPrepareSearchResults() -> Bool {
        let manager = bindings.manager, session = bindings.manager.unifiedSearchSession
        guard mounted, foreground, isPresentationReady, searchResultsBinding == nil,
              (try? validateSearchPresentation()) != nil,
              session.searchViewModel === manager.searchViewModel,
              session.selectedBookIds == manager.searchViewModel.selectedBookIds,
              session.availableScopes.contains(.exact),
              !session.showsBookFilterSheet, !session.showsSearchDataSheet,
              !session.showsAdvancedOptions else { return false }
        return true
    }

    func retainSearchResults(_ query: ActionSearchResultsQuery, requestID: UUID) throws -> MaktabahNativeSearchResultsBinding {
        try validateSearchPresentation()
        guard canPrepareSearchResults() else {
            throw UIRouteError(.unavailable, "native_search_owner_unavailable")
        }
        let retained = try MaktabahNativeSearchResultsBinding(manager: bindings.manager, query: query, requestID: requestID)
        searchResultsBinding = retained
        return retained
    }
    func releaseSearchResults(_ binding: MaktabahNativeSearchResultsBinding) {
        if searchResultsBinding === binding { searchResultsBinding = nil }
    }
    func prepareSearchResults(invocation: ActionPortInvocation, scene: UISceneSnapshot) throws -> RouteSpec {
        try validateSearchPresentation()
        guard let searchResultsBinding, searchResultsBinding.requestID == invocation.requestId else {
            throw UIRouteError(.unavailable, "native_search_owner_missing")
        }
        try searchResultsBinding.validate()
        let identity = try project().identity()
        return RouteSpec(requestId: invocation.requestId, destination: UIDestinationID(rawValue: "native.search.results")!,
            backend: invocation.snapshot.backend, presentation: .init(kind: .currentTab),
            state: .init(workspaceID: identity.state.workspaceID, profileID: identity.state.profileID),
            scene: .init(kind: .specific, sceneID: sceneID, expectedRevision: scene.revision),
            expectedBackendSnapshot: invocation.snapshot)
    }
    func validateSearchResultsCompletion(requestID: UUID) throws {
        try validateSearchPresentation()
        guard let searchResultsBinding, searchResultsBinding.requestID == requestID,
              mounted, foreground, isPresentationReady,
              let surface = try surface(.searchResults),
              let evidence = visibilityChecks[surface.destination]?(),
              evidence.isVisible, evidence.sceneID == sceneID, evidence.surface == surface else {
            throw UIRouteError(.staleState, "native_search_results_no_longer_visible")
        }
        try searchResultsBinding.validateCompleted()
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
        if evidence.isVisible, evidence.surface.destination.rawValue == "native.reader.noteDraft",
           (try? noteDraftBinding?.validateVisible()) == nil {
            if visible.removeValue(forKey: evidence.surface.destination) != nil { try? nativeStateChanged() }
            return
        }
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
        noteEditorOwner = nil; noteDraftBinding = nil
        windowSource = nil; searchPresentationOwner = nil; searchPresentationBlocked = nil
        searchResultsBinding = nil
        if let lease { directory.unmount(lease) }
        lease = nil
    }

    private func surfaceKind(_ destination: UIDestinationID) -> MaktabahNativeSceneProjection.Surface? {
        switch destination.rawValue {
        case "native.library": .library
        case "native.reader.toc": .tableOfContents
        case "native.reader": .reader
        case "native.reader.inspector": .inspector
        case "native.reader.noteDraft": .noteDraft
        case "native.history": .history
        case "native.search": .search
        case "native.search.results": .searchResults
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
