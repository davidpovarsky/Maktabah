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
    private var observationRevision: UInt64? = 0

    @discardableResult
    func observe(_ window: UIWindow?, from source: UIView) -> Bool {
        if window == nil {
            guard self.source === source else { return false }
            self.source = nil; self.window = nil
            advanceObservation()
            return true
        }
        guard self.source !== source || self.window !== window else { return false }
        self.source = source; self.window = window
        advanceObservation()
        return true
    }

    private func advanceObservation() {
        guard let revision = observationRevision, revision < .max else {
            observationRevision = nil; return
        }
        observationRevision = revision + 1
    }

    /// Retain identity before foreground/layout awaits. Actual presentation
    /// readiness remains the independent unchanged original predicate below.
    func retainOriginalWindow(in sceneID: UIStableID,
                              isCurrentSource: @escaping @MainActor () -> Bool) throws -> MaktabahNativeWindowObservation {
        guard let originalSource = source, let originalWindow = window,
              let revision = observationRevision,
              originalSource.window === originalWindow,
              originalWindow.windowScene?.session.persistentIdentifier == sceneID.rawValue,
              isCurrentSource(), source === originalSource, window === originalWindow,
              observationRevision == revision else {
            throw UIRouteError(.staleState, "native_original_window_source_unavailable")
        }
        return MaktabahNativeWindowObservation(window: originalWindow) { [weak self, weak originalSource] actual in
            guard let self, let originalSource,
                  self.source === originalSource, self.window === actual,
                  originalSource.window === actual, self.observationRevision == revision,
                  actual.windowScene?.session.persistentIdentifier == sceneID.rawValue,
                  isCurrentSource() else { return false }
            return self.source === originalSource && self.window === actual
                && originalSource.window === actual && self.observationRevision == revision
        }
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

/// The RN sheet may cover the original root, but it never selects a tab, pops a
/// book or dismisses Settings. Retain those ORIGINAL publication histories at
/// +0, separately from the feature's runtime/React/host proof. Values stay in
/// their original owners; equal writes and A→B→A cannot renew this observation.
@MainActor private final class MaktabahNativeSefariaRootSource {
    private let observation: NativeComponentSourceObservation
    private let managerID: ObjectIdentifier
    private let root: MaktabahNativeRootPublicationSource
    private weak var workspacePresentation: MaktabahNativeWorkspacePresentationBinding?
    private let workspaceRevision: UInt64
    private let selectionRevision: UInt64
    private let settingsRevision: UInt64
    private let modeRevision: UInt64
    private let bookRevision: UInt64
    private let tab: iOSTab
    private let mode: AppMode
    private let bookID: ObjectIdentifier?
    private let bookMode: AppMode?

    static func isAvailable(_ bindings: MaktabahNativeSceneBindings,
                            workspace: MaktabahNativeWorkspacePresentationBinding?) -> Bool {
        bindings.rootPublications?.selectionRevision != nil
            && bindings.rootPublications?.settingsRevision != nil
            && bindings.manager.nativeModePresentationRevision != nil
            && bindings.manager.selectedBookPresentationRevision != nil
            && workspace?.originalStateRevision != nil
            && bindings.selectedTab.wrappedValue == bindings.selectedTab.wrappedValue.canonical
            && bindings.manager.currentMode == bindings.selectedTab.wrappedValue.appMode
            && !bindings.showSettings.wrappedValue && bindings.isPresentationReady
    }

    init(bindings: MaktabahNativeSceneBindings,
         workspace: MaktabahNativeWorkspacePresentationBinding,
         readForeignPresentations: @MainActor () -> Void) throws {
        let manager = bindings.manager
        observation = NativeComponentSourceObservation {
            _ = manager.currentMode; _ = manager.selectedBook; _ = manager.selectedBookPresentationMode
            _ = manager.selectedBookForInfo; _ = manager.showingTabsList
            _ = manager.activeReaderViewModel?.isPopoverPresented
            _ = DonationManager.shared.showDonationSheet
            _ = bindings.sidebar?.overview.blocksRouting
            _ = workspace.originalStateRevision
            readForeignPresentations()
        }
        guard Self.isAvailable(bindings, workspace: workspace),
              let root = bindings.rootPublications,
              let selection = root.selectionRevision, let settings = root.settingsRevision,
              let mode = manager.nativeModePresentationRevision,
              let book = manager.selectedBookPresentationRevision,
              let workspaceRevision = workspace.originalStateRevision else {
            throw UIRouteError(.unavailable, "native_sefaria_original_root_unavailable")
        }
        self.root = root; managerID = ObjectIdentifier(manager)
        workspacePresentation = workspace; self.workspaceRevision = workspaceRevision
        selectionRevision = selection; settingsRevision = settings
        modeRevision = mode; bookRevision = book
        tab = bindings.selectedTab.wrappedValue; self.mode = manager.currentMode
        bookID = manager.selectedBook.map(ObjectIdentifier.init)
        bookMode = manager.selectedBookPresentationMode
        try validate(bindings, workspace: workspace)
    }

    func validate(_ bindings: MaktabahNativeSceneBindings,
                  workspace: MaktabahNativeWorkspacePresentationBinding?) throws {
        try observation.validate()
        let manager = bindings.manager
        guard ObjectIdentifier(manager) == managerID, bindings.rootPublications === root,
              let workspace, workspacePresentation === workspace,
              workspace.originalStateRevision == workspaceRevision,
              root.selectionRevision == selectionRevision, root.settingsRevision == settingsRevision,
              manager.nativeModePresentationRevision == modeRevision,
              manager.selectedBookPresentationRevision == bookRevision,
              bindings.selectedTab.wrappedValue == tab, manager.currentMode == mode,
              manager.selectedBook.map(ObjectIdentifier.init) == bookID,
              manager.selectedBookPresentationMode == bookMode,
              !bindings.showSettings.wrappedValue, bindings.isPresentationReady else {
            throw UIRouteError(.staleState, "native_sefaria_original_root_changed")
        }
    }
    func invalidate() { observation.invalidate() }
}

/// One instance per actual UIKit session. The app supplies the SAME directory /
/// S facade used by Core and its current lifetime validator at composition.
/// Native mutations remain behind P's canonical precommit guard.
@MainActor @Observable
final class MaktabahNativeSceneSession: NativeParentSelectionSceneDriver {
    let sceneID: UIStableID
    let presentation: NativePresentationObserver
    private(set) var submissionID: UUID?
    private(set) var mounted = true
    var foreground = false
    private let directory: NativeSceneDirectory
    private var project: @MainActor () throws -> MaktabahNativeSceneProjection
    private let bindings: MaktabahNativeSceneBindings
    let workspaceProjectionSource: MaktabahNativeWorkspaceProjectionSource?
    private(set) var workspacePresentation: MaktabahNativeWorkspacePresentationBinding?
    private(set) var phoneTOCPresentation: MaktabahNativePhoneTOCPresentationBinding?
    private(set) var sefariaSurfaceBinding: MaktabahNativeSefariaSurfaceBinding?
    @ObservationIgnored private var sefariaRootSources: [UUID: MaktabahNativeSefariaRootSource] = [:]
    @ObservationIgnored private var completedSefariaRootSource: MaktabahNativeSefariaRootSource?
    @ObservationIgnored private var retainedSefariaSurface = false
    @ObservationIgnored private var retainedPhoneTOC = false
    @ObservationIgnored private weak var forwardingWorkspaceOwner: MaktabahNativeWorkspaceOwner?
    @ObservationIgnored private var retainedWorkspaceParent: MaktabahNativeWorkspacePresentationBinding.Parent?
    private var lease: NativeSceneDirectory.Lease?
    private var command: UISceneCommand?
    @ObservationIgnored private var lastCompletedSurface: (route: RouteSpec, evidence: NativeSurfaceWitness.Evidence)?
    var readerBinding: MaktabahNativeReaderBinding?
    var searchResultsBinding: MaktabahNativeSearchResultsBinding?
    @ObservationIgnored private var searchContinuationOwner: MaktabahNativeSearchContinuationOwner?
    @ObservationIgnored private var publicSearchContinuationCatalog: MaktabahNativeSearchContinuationCatalog?
    @ObservationIgnored private var readerTabBinding: MaktabahNativeReaderTabBinding?
    @ObservationIgnored private var workspaceSelectionBinding: MaktabahNativeWorkspaceSelectionBinding?
    private(set) var viewerParentHost: MaktabahNativeViewerParentHost?
    @ObservationIgnored private var readerTabParentObservation: NativeOriginalParentObservation?
    @ObservationIgnored private weak var nativeSearchField: UISearchTextField?
    @ObservationIgnored private var retainedSearchField: UISearchTextField?
    private(set) var searchEntryBinding: MaktabahNativeSearchEntryBinding?
    private(set) var historyRecordBinding: MaktabahNativeHistoryRecordBinding?
    @ObservationIgnored private var retainedHistoryRecord = false
    private(set) var savedResultsBinding: MaktabahNativeSavedResultsBinding?
    @ObservationIgnored private var retainedSavedResults = false
    @ObservationIgnored private var searchFieldUpdateScheduled = false
    @ObservationIgnored private var inspectorBinding: MaktabahNativeInspectorBinding?
    @ObservationIgnored private var noteEditorOwner: MaktabahNativeNoteEditorOwner?
    @ObservationIgnored private var noteDraftBinding: MaktabahNativeNoteDraftBinding?
    private var searchFieldRevision: UInt64 = 0
    @ObservationIgnored private weak var windowSource: MaktabahNativeWindowSource?
    @ObservationIgnored private var windowSourceRevision: UInt64? = 0
    @ObservationIgnored private var searchPresentationOwner: UUID?
    @ObservationIgnored private var searchPresentationBlocked: (@MainActor () -> Bool)?
    @ObservationIgnored private var componentOwners: [UIDestinationID: MaktabahNativeComponentOwner] = [:]
    @ObservationIgnored private var retainedComponentOwner: MaktabahNativeComponentOwner?
    @ObservationIgnored private var componentValidation: (@MainActor (UISceneCommand) throws -> (@MainActor () throws -> Void))?
    @ObservationIgnored private var componentUpdateScheduled = false
    private var componentRevision: UInt64 = 0

    func componentOwner(for destination: UIDestinationID) -> MaktabahNativeComponentOwner? { componentOwners[destination] }

    func forwardRouting(to owner: MaktabahNativeWorkspaceOwner) throws {
        guard usesWorkspaceOwner(owner) else { throw UIRouteError(.staleState, "native_workspace_owner_changed") }
        try owner.attachNativeRoutingSession(self)
        forwardingWorkspaceOwner = owner
    }

    /// The original parent source is retained before its component source and
    /// before any public binding/Core await. Read-only discovery does not retain.
    func retainParentSource(destination: UIDestinationID, requestID: UUID) throws {
        if destination == MaktabahNativeSavedResultsBinding.destination {
            guard mounted, let original = savedResultsBinding else {
                throw UIRouteError(.unavailable, "native_saved_results_owner_missing")
            }
            try original.retain(record: nil, requestID: requestID)
            return
        }
        if destination == MaktabahNativeSefariaSurfaceBinding.destination {
            guard mounted, foreground, isPresentationReady(for: destination),
                  sefariaRootSources[requestID] == nil,
                  let original = sefariaSurfaceBinding, let workspacePresentation else {
                throw UIRouteError(.unavailable, "native_sefaria_parent_unavailable")
            }
            let root = try MaktabahNativeSefariaRootSource(bindings: bindings, workspace: workspacePresentation) { [weak self] in
                guard let self else { return }
                _ = mounted; _ = foreground; _ = studyChatPresentationID
                // The original note editor owns SwiftUI State, not Observable
                // fields. Its exact setter invalidates this source synchronously.
            }
            try original.retainSource(requestID: requestID)
            do { try root.validate(bindings, workspace: workspacePresentation) }
            catch { original.releaseSource(requestID: requestID); throw error }
            sefariaRootSources[requestID] = root
            return
        }
        if usesOriginalPhoneTOC(destination) {
            guard mounted, foreground, isPresentationReady(for: destination), let phoneTOCPresentation else {
                throw UIRouteError(.unavailable, "native_phone_toc_parent_unavailable")
            }
            try phoneTOCPresentation.retainSource(requestID: requestID)
            return
        }
        guard let parent = MaktabahNativeWorkspacePresentationBinding.Parent(rawValue: destination.rawValue) else { return }
        guard mounted, foreground, isPresentationReady(for: destination), let workspacePresentation else {
            throw UIRouteError(.unavailable, "native_workspace_parent_unavailable")
        }
        try workspacePresentation.retainSource(parent: parent, requestID: requestID)
    }
    func validateParentSource(destination: UIDestinationID, requestID: UUID) throws {
        if destination == MaktabahNativeSavedResultsBinding.destination {
            guard let original = savedResultsBinding else {
                throw UIRouteError(.staleState, "native_saved_results_owner_detached")
            }
            try original.validateSource(requestID: requestID)
            return
        }
        if destination == MaktabahNativeSefariaSurfaceBinding.destination {
            guard let original = sefariaSurfaceBinding, let root = sefariaRootSources[requestID] else {
                throw UIRouteError(.staleState, "native_sefaria_parent_not_retained")
            }
            try root.validate(bindings, workspace: workspacePresentation)
            try original.validateSource(requestID: requestID)
            guard sefariaRootSources[requestID] === root else {
                throw UIRouteError(.staleState, "native_sefaria_parent_released")
            }
            return
        }
        if usesOriginalPhoneTOC(destination) {
            guard let phoneTOCPresentation else { throw UIRouteError(.staleState, "native_phone_toc_parent_detached") }
            try phoneTOCPresentation.validateSource(requestID: requestID)
            return
        }
        guard let parent = MaktabahNativeWorkspacePresentationBinding.Parent(rawValue: destination.rawValue) else { return }
        guard let workspacePresentation else { throw UIRouteError(.staleState, "native_workspace_parent_detached") }
        try workspacePresentation.validateSource(parent: parent, requestID: requestID)
    }
    func releaseParentSource(destination: UIDestinationID, requestID: UUID) {
        if destination == MaktabahNativeSavedResultsBinding.destination {
            savedResultsBinding?.releaseSource(requestID: requestID)
            return
        }
        if destination == MaktabahNativeSefariaSurfaceBinding.destination {
            if let root = sefariaRootSources.removeValue(forKey: requestID), root !== completedSefariaRootSource {
                root.invalidate()
            }
            sefariaSurfaceBinding?.releaseSource(requestID: requestID)
            return
        }
        if usesOriginalPhoneTOC(destination) {
            phoneTOCPresentation?.releaseSource(requestID: requestID)
            return
        }
        guard MaktabahNativeWorkspacePresentationBinding.Parent(rawValue: destination.rawValue) != nil else { return }
        workspacePresentation?.releaseSource(requestID: requestID)
    }
    func retainComponentSource(destination: UIDestinationID, anchor: UIDestinationID, requestID: UUID) throws -> MaktabahNativeComponentOwner {
        guard let owner = componentOwners[destination] else { throw UIRouteError(.notSupported, "native_component_not_installed") }
        let searchEntry = destination == MaktabahNativeSearchEntryBinding.destination
            && anchor == MaktabahNativeSearchEntryBinding.anchor
        if searchEntry {
            guard let searchEntryBinding, searchEntryBinding.owner === owner else {
                throw UIRouteError(.unavailable, "native_search_entry_source_missing")
            }
            try searchEntryBinding.retainSource(requestID: requestID)
        }
        do { try owner.retainSource(requestID: requestID, anchor: anchor) }
        catch {
            if searchEntry { searchEntryBinding?.releaseSource(requestID: requestID) }
            throw error
        }
        return owner
    }
    func releaseComponentSource(_ owner: MaktabahNativeComponentOwner, requestID: UUID) {
        owner.releaseSource(requestID: requestID)
        if searchEntryBinding?.owner === owner { searchEntryBinding?.releaseSource(requestID: requestID) }
    }
    func validateComponentSource(destination: UIDestinationID, anchor: UIDestinationID, requestID: UUID) throws {
        if destination == NativeSearchFieldVisibility.destination, anchor == NativeSearchFieldVisibility.focus.anchor { return }
        guard let owner = componentOwners[destination] else { throw UIRouteError(.notSupported, "native_component_not_installed") }
        try owner.validateSource(requestID: requestID, anchor: anchor)
    }
    func attachComponentOwner(_ owner: MaktabahNativeComponentOwner) {
        guard componentOwners[owner.destination] == nil else { return }
        componentOwners[owner.destination] = owner
        owner.install(changed: { [weak self, weak owner] in
            guard let self, let owner else { return }
            componentStateDidChange(owner)
        }, invalidated: { [weak self] in self?.presentation.revoke() })
    }
    func detachComponentOwner(_ owner: MaktabahNativeComponentOwner) {
        guard componentOwners[owner.destination] === owner else { return }
        owner.retirePresentation(); componentOwners.removeValue(forKey: owner.destination)
        try? nativeStateChanged()
    }
    func configureComponentValidation(_ validation: @escaping @MainActor (UISceneCommand) throws -> (@MainActor () throws -> Void)) {
        componentValidation = validation
    }
    func componentStateDidChange(_ owner: MaktabahNativeComponentOwner) {
        guard mounted, componentOwners[owner.destination] === owner else { return }
        originalPresentationStateDidChange()
    }
    private func originalPresentationStateDidChange() {
        guard mounted else { return }
        try? nativeStateChanged()
        // UIKit layout may call this while SwiftUI updates. Only the graph
        // notification is deferred; ownership invalidation is synchronous.
        guard !componentUpdateScheduled else { return }
        componentUpdateScheduled = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            componentUpdateScheduled = false; componentRevision &+= 1
        }
    }

    func attachWindowSource(_ source: MaktabahNativeWindowSource) {
        guard mounted else { return }
        if windowSource !== source {
            if let revision = windowSourceRevision, revision < .max { windowSourceRevision = revision + 1 }
            else { windowSourceRevision = nil }
        }
        windowSource = source
    }
    func retainOriginalWindowObservation() throws -> MaktabahNativeWindowObservation {
        guard mounted, let originalSource = windowSource, let revision = windowSourceRevision else {
            throw UIRouteError(.staleState, "native_original_window_source_unavailable")
        }
        return try originalSource.retainOriginalWindow(in: sceneID) { [weak self, weak originalSource] in
            guard let self, let originalSource else { return false }
            return self.mounted && self.windowSource === originalSource && self.windowSourceRevision == revision
        }
    }
    func nativeWindowDidChange(_ source: MaktabahNativeWindowSource) {
        guard mounted, windowSource === source else { return }
        readerTabBinding?.invalidate()
        workspaceSelectionBinding?.invalidate()
        viewerParentHost?.originalWindowSourceDidChange()
        searchContinuationOwner?.retire()
        publicSearchContinuationCatalog?.retire()
        searchEntryBinding?.retire()
        historyRecordBinding?.retire()
        savedResultsBinding?.retire()
        sefariaRootSources.values.forEach { $0.invalidate() }
        completedSefariaRootSource?.invalidate()
        presentation.revoke()
        try? nativeStateChanged()
    }
    func observeSearchPresentation(owner: UUID, isBlocked: @escaping @MainActor () -> Bool) {
        guard mounted else { return }
        if searchPresentationOwner != owner {
            searchContinuationOwner?.retire(); publicSearchContinuationCatalog?.retire()
        }
        searchEntryBinding?.observeOriginalPresentation(owner: owner)
        searchPresentationOwner = owner; searchPresentationBlocked = isBlocked
    }
    func originalSearchPresentationWillChange(owner: UUID) {
        searchEntryBinding?.originalPresentationWillChange(owner: owner)
        if searchPresentationOwner == owner {
            searchContinuationOwner?.retire()
            publicSearchContinuationCatalog?.retire()
            historyRecordBinding?.originalForeignStateWillChange()
        }
    }
    func renderSearchEntryFromOriginalView() {
        guard mounted, foreground else { return }
        searchEntryBinding?.renderOriginalFieldIfReady()
    }
    func removeSearchPresentation(owner: UUID) {
        guard searchPresentationOwner == owner else { return }
        searchContinuationOwner?.retire()
        publicSearchContinuationCatalog?.retire()
        searchEntryBinding?.originalPresentationDidDisappear(owner: owner)
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
        searchEntryBinding?.attachOriginalField(field)
        searchFieldStateDidChange(field)
    }

    func detachSearchField(_ field: UISearchTextField) {
        guard nativeSearchField === field else { return }
        searchEntryBinding?.detachOriginalField(field)
        if retainedSearchField === field { presentation.revoke() }
        nativeSearchField = nil
        // Ownership invalidation is synchronous even if the SwiftUI graph has
        // not rendered yet, including detach/reattach ABA during Core awaits.
        try? nativeStateChanged()
        scheduleSearchFieldObservation()
    }

    func searchFieldStateDidChange(_ field: UISearchTextField) {
        guard nativeSearchField === field else { return }
        searchEntryBinding?.originalFieldStateDidChange(field)
        try? nativeStateChanged()
        scheduleSearchFieldObservation()
    }
    func searchFieldDidLayout(_ field: UISearchTextField) {
        guard nativeSearchField === field else { return }
        searchEntryBinding?.originalFieldDidLayout(field)
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
    private var hasOriginalWorkspacePresentation: Bool {
        guard let workspacePresentation else { return false }
        return MaktabahNativeWorkspacePresentationBinding.Parent.allCases.contains {
            let actual = workspacePresentation.presentationFacets(for: $0)
            return actual.requested || actual.mounted || actual.transitioning
        }
    }
    private var hasOriginalSefariaSurface: Bool {
        guard let actual = sefariaSurfaceBinding?.presentationFacets else { return false }
        return actual.requested || actual.mounted || actual.transitioning
    }
    private var isSefariaOriginalRootReady: Bool {
        mounted && foreground && !bindings.showSettings.wrappedValue && bindings.isPresentationReady
            && !hasOriginalWorkspacePresentation && studyChatPresentationID == nil
            && noteEditorOwner?.current == nil && noteEditorOwner?.presentationActive != true
            && MaktabahNativeSefariaRootSource.isAvailable(bindings, workspace: workspacePresentation)
    }
    var isPresentationReady: Bool {
        readerTabBinding == nil && workspaceSelectionBinding == nil && bindings.isPresentationReady && !hasOriginalWorkspacePresentation && !hasOriginalSefariaSurface
            && savedResultsBinding?.isRequestedOrMounted != true
            && studyChatPresentationID == nil
            && ((noteEditorOwner?.current == nil && noteEditorOwner?.presentationActive != true)
                || (command?.route.route.destination.rawValue == "native.reader.noteDraft" && noteDraftBinding?.isApplied == true))
    }

    private func usesOriginalPhoneTOC(_ destination: UIDestinationID) -> Bool {
        !MaktabahApp.isIpad && destination == MaktabahNativeTOCComponents.destination
    }

    /// Stable original Workspace sheets may navigate their own components.
    /// Every unrelated modal keeps the existing blockers. A transition can be
    /// awaited only by its already-applied command, never by fresh discovery.
    func isPresentationReady(for destination: UIDestinationID) -> Bool {
        if destination == MaktabahNativeSavedResultsBinding.destination {
            guard mounted, foreground, let original = savedResultsBinding, original.isAvailable else { return false }
            if let requestID = submissionID, command?.invocation.requestId == requestID,
               command?.route.route.destination == destination,
               original.isContinuingAppliedRequest(requestID: requestID) { return true }
            if original.isRequestedOrMounted { return original.isStableOriginalPresentation }
            return windowSource?.isPresentationReady(in: sceneID) == true
        }
        guard savedResultsBinding?.isRequestedOrMounted != true else { return false }
        if destination == MaktabahNativeWorkspaceSelectionBinding.destination {
            guard mounted, foreground, isReaderTabSourceReady, let bound = workspaceSelectionBinding,
                  (try? bound.validate()) != nil else { return false }
            if bound.isApplied, submissionID == bound.requestID,
               command?.invocation.requestId == bound.requestID,
               command?.route.route.destination == destination { return true }
            return windowSource?.isPresentationReady(in: sceneID) == true
        }
        guard workspaceSelectionBinding == nil else { return false }
        if destination == MaktabahNativeReaderTabBinding.destination {
            guard mounted, foreground, isReaderTabSourceReady, let bound = readerTabBinding,
                  (try? bound.validate()) != nil else { return false }
            if bound.isApplied, submissionID == bound.requestID,
               command?.invocation.requestId == bound.requestID,
               command?.route.route.destination == destination { return true }
            return windowSource?.isPresentationReady(in: sceneID) == true
        }
        guard readerTabBinding == nil else { return false }
        if destination == MaktabahNativeSefariaSurfaceBinding.destination {
            guard isSefariaOriginalRootReady, let original = sefariaSurfaceBinding,
                  original.isAvailable else { return false }
            let actual = original.presentationFacets
            if let requestID = submissionID, command?.invocation.requestId == requestID,
               command?.route.route.destination == destination,
               original.isContinuingAppliedRequest(requestID: requestID) {
                return true
            }
            if actual.requested || actual.mounted || actual.transitioning {
                return actual.requested && actual.mounted && actual.visible && !actual.transitioning
            }
            // Only a cold request uses the original root window. A stable own
            // sheet supplies its exact host; unrelated modal transitions block.
            return windowSource?.isPresentationReady(in: sceneID) == true
        }
        if usesOriginalPhoneTOC(destination) {
            guard !bindings.showSettings.wrappedValue, isPresentationReady,
                  isRootAvailable(destination), let phoneTOCPresentation else { return false }
            if let requestID = submissionID, command?.invocation.requestId == requestID,
               command?.route.route.destination == destination,
               phoneTOCPresentation.isContinuingOriginalReaderPresentation(requestID: requestID) {
                return true
            }
            // A cold request cannot dismiss or borrow a foreign transition.
            // Only its already committed exact Reader source may await its push.
            return windowSource?.isPresentationReady(in: sceneID) == true
        }
        guard let parent = MaktabahNativeWorkspacePresentationBinding.Parent(rawValue: destination.rawValue) else {
            return isPresentationReady
        }
        guard bindings.isWorkspaceParentPresentationReady, !hasOriginalSefariaSurface, studyChatPresentationID == nil,
              noteEditorOwner?.current == nil, noteEditorOwner?.presentationActive != true,
              let binding = workspacePresentation, binding.isAvailable(parent: parent) else { return false }
        let profiles = binding.presentationFacets(for: .profiles)
        let overview = binding.presentationFacets(for: .overview)
        let continuing: Bool
        if let requestID = submissionID, command?.invocation.requestId == requestID,
           command?.route.route.destination == destination {
            continuing = binding.isContinuingAppliedRequest(parent: parent, requestID: requestID)
        } else {
            continuing = false
        }
        // Before the first canonical apply, the ORIGINAL window must have no
        // unrelated presented controller or unfinished dismissal. A false
        // SwiftUI sheet binding alone does not prove that UIKit has finished.
        // Warm original Workspace sheets instead use their exact host evidence.
        if !profiles.requested && !profiles.mounted && !overview.requested && !overview.mounted
            && !continuing {
            guard windowSource?.isPresentationReady(in: sceneID) == true else { return false }
        }
        if profiles.requested || profiles.mounted {
            guard parent == .profiles,
                  continuing || (profiles.visible && !profiles.transitioning) else { return false }
        }
        if overview.requested || overview.mounted || bindings.manager.showingTabsList
            || bindings.sidebar?.overview.blocksRouting == true {
            guard parent == .overview || (!MaktabahApp.isIpad && parent == .profiles),
                  overview.requested else { return false }
            let coveredByOriginalProfiles = parent == .profiles && profiles.requested
                && profiles.mounted && profiles.visible && !profiles.transitioning
            guard continuing || coveredByOriginalProfiles
                || (overview.mounted && overview.visible && !overview.transitioning) else { return false }
        }
        return true
    }

    private func boundedRenderValidation(for value: UISceneCommand,
                                         owner: MaktabahNativeComponentOwner? = nil,
                                         anchor: UIDestinationID? = nil) throws -> @MainActor () throws -> Void {
        guard let componentValidation else { throw UIRouteError(.unavailable, "native_render_lifetime_missing") }
        let originalLifetime = try componentValidation(value)
        return { [weak self, weak owner] in
            try originalLifetime()
            guard let self, mounted, foreground, isPresentationReady(for: value.route.route.destination) else {
                throw UIRouteError(.staleState, "native_original_presentation_changed")
            }
            try validateParentSource(destination: value.route.route.destination, requestID: value.invocation.requestId)
            if let anchor {
                guard let owner, componentOwners[owner.destination] === owner, owner.isAvailable(anchor) else {
                    throw UIRouteError(.staleState, "native_component_owner_changed")
                }
            }
            let identity = try project().identity(workspacePresentation: workspacePresentation, sefariaSurface: sefariaSurfaceBinding, savedResults: savedResultsBinding)
            guard value.route.route.state.workspaceID == identity.state.workspaceID,
                  value.route.route.state.profileID == identity.state.profileID else {
                throw UIRouteError(.staleState, "native_workspace_changed")
            }
        }
    }

    func attachNoteEditor(id: UUID, reader: ReaderViewModel, annotation: Binding<Annotation?>,
                          presentationID: @escaping @MainActor () -> UUID) {
        if noteEditorOwner?.id == id, noteEditorOwner?.reader === reader { return }
        if noteDraftBinding != nil { presentation.revoke() }
        noteEditorOwner = .init(id: id, reader: reader, annotation: annotation, presentationID: presentationID)
        try? nativeStateChanged()
    }
    func originalNoteEditorStateWillChange(id: UUID, reader: ReaderViewModel) {
        guard mounted, let owner = noteEditorOwner,
              owner.id == id, owner.reader === reader else { return }
        readerTabBinding?.invalidate()
        workspaceSelectionBinding?.invalidate()
        searchContinuationOwner?.retire()
        publicSearchContinuationCatalog?.retire()
        // Observe the original setter BEFORE its SwiftUI State/presentation
        // mutation. This also covers a retained source before beginObservation
        // and completed proof; final-value equality cannot revive either one.
        sefariaRootSources.values.forEach { $0.invalidate() }
        completedSefariaRootSource?.invalidate()
        historyRecordBinding?.originalForeignStateWillChange()
        savedResultsBinding?.retire()
        if retainedSefariaSurface { presentation.revoke() }
    }
    func detachNoteEditor(id: UUID) {
        guard let owner = noteEditorOwner, owner.id == id else { return }
        // Leaving the Reader normally unmounts its idle editor registration.
        // Revoke only a note-owned presentation, not the admitted Search/root
        // transition that caused this original Reader to disappear.
        let hadNotePresentation = noteDraftBinding != nil || owner.current != nil || owner.presentationActive
        noteEditorOwner = nil
        if hadNotePresentation { presentation.revoke() }
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
    #if DEBUG
    /// Passive acceptance observation of the existing exact Reader/editor owner.
    /// Missing ownership is unknown, distinct from an owned dismissed draft.
    struct NoteDraftAcceptanceState {
        let ownerID: UUID
        let draft: Annotation?
        let presentationActive: Bool
    }
    func noteDraftAcceptanceState(reader: ReaderViewModel) -> NoteDraftAcceptanceState? {
        guard mounted, foreground,
              MaktabahNativeInspectorBinding.currentReader(in: bindings.manager) === reader,
              let owner = noteEditorOwner, owner.reader === reader else { return nil }
        return .init(ownerID: owner.id, draft: owner.current,
                     presentationActive: owner.presentationActive)
    }
    #endif

    #if DEBUG
    /// Passive flags for the actual owner/marker seam. Never publishes a
    /// receipt, forces TextKit layout, changes selection, or logs note content.
    func diagnoseNoteDraftSurface(stage: String, reader: ReaderViewModel? = nil, draft: Annotation? = nil) {
        let bound = noteDraftBinding, owner = noteEditorOwner
        var validation = "no_binding"
        if let bound {
            do { try bound.validate(); validation = "valid" }
            catch { validation = (error as? UIRouteError)?.code ?? String(describing: type(of: error)) }
        }
        let projected = (try? project().surface(.noteDraft)) != nil
        let surfaceAvailable = (try? surface(.noteDraft)) != nil
        let destination = UIDestinationID(rawValue: "native.reader.noteDraft")!
        let check = visibilityChecks[destination], evidence = check?()
        let textView = owner?.textView
        let sameOwner = bound.map { owner === $0.owner } ?? false
        let currentMatches = bound.map { owner?.current == $0.draft } ?? false
        let passedReaderMatches = reader.map { owner?.reader === $0 } ?? false
        let passedDraftMatches = draft.map { owner?.current == $0 } ?? false
        let proposalMatches = bound.flatMap { bound in
            textView.map { ($0.text ?? "").utf8.elementsEqual((bound.request.proposedText ?? "").utf8) }
        } ?? false
        let source = bound?.sourceDiagnostic() ?? "no_binding"
        OtzariaFileLogger.shared.log("[NativeNoteDraftDiagnostic] stage=\(stage)"
            + " mounted=\(mounted) foreground=\(foreground) pending=\(submissionID != nil)"
            + " owner=\(owner != nil) binding=\(bound != nil) applied=\(bound?.isApplied == true)"
            + " sameOwner=\(sameOwner) currentDraft=\(currentMatches)"
            + " passedReader=\(passedReaderMatches) passedDraft=\(passedDraftMatches)"
            + " sourceValidation=\(validation) source={\(source)}"
            + " projected=\(projected) surface=\(surfaceAvailable)"
            + " markerRegistered=\(check != nil) markerVisible=\(evidence?.isVisible == true)"
            + " textView=\(textView != nil) textWindow=\(textView?.window != nil)"
            + " textScene=\(textView?.window?.windowScene?.session.persistentIdentifier == sceneID.rawValue)"
            + " proposalMatches=\(proposalMatches)")
    }
    #endif

    // MARK: Existing Reader-tab intent

    private var isReaderTabSourceReady: Bool {
        bindings.isPresentationReady && !bindings.showSettings.wrappedValue
            && !hasOriginalWorkspacePresentation && !hasOriginalSefariaSurface
            && savedResultsBinding?.isRequestedOrMounted != true
            && studyChatPresentationID == nil
            && noteEditorOwner?.current == nil && noteEditorOwner?.presentationActive != true
    }

    func readerTabCatalog(windowTitle: String) throws -> [NativeReaderTabIntentService.Tab] {
        guard mounted, readerTabBinding == nil, workspaceSelectionBinding == nil, isReaderTabSourceReady,
              let source = workspaceProjectionSource else { return [] }
        let originalViewer = bindings.selectedTab.wrappedValue == .viewer && bindings.manager.currentMode == .viewer
        guard originalViewer || viewerParentHost?.isAvailable(bindings: bindings) == true else { return [] }
        return try MaktabahNativeReaderTabBinding.catalog(sceneID: sceneID, manager: bindings.manager,
                                                         source: source, windowTitle: windowTitle)
    }

    func retainReaderTabSelection(_ target: NativeReaderTabIntentService.Tab,
                                  requestID: UUID) throws -> MaktabahNativeReaderTabBinding {
        guard mounted, target.sceneID == sceneID, command == nil,
              readerTabBinding == nil, workspaceSelectionBinding == nil, readerBinding == nil, searchResultsBinding == nil,
              isReaderTabSourceReady, let source = workspaceProjectionSource else {
            throw UIRouteError(.unavailable, "native_reader_tab_scene_busy")
        }
        let bound = try MaktabahNativeReaderTabBinding(requestID: requestID, target: target,
            bindings: bindings, source: source, viewerParentHost: viewerParentHost,
            foreignReady: { [weak self] in self?.isReaderTabSourceReady == true },
            readForeignPresentations: { [weak self] in
                guard let self else { return }
                _ = workspacePresentation?.originalStateRevision
                _ = studyChatPresentationID
                _ = hasOriginalSefariaSurface
            })
        readerTabBinding = bound
        return bound
    }

    func reserveReaderTabSelection(_ bound: MaktabahNativeReaderTabBinding) throws {
        guard readerTabBinding === bound, mounted, foreground, command == nil,
              isReaderTabSourceReady, windowSource?.isPresentationReady(in: sceneID) == true else {
            throw UIRouteError(.unavailable, "native_reader_tab_presentation_unavailable")
        }
        try bound.reserve()
    }

    func releaseReaderTabSelection(_ bound: MaktabahNativeReaderTabBinding) {
        guard readerTabBinding === bound else { return }
        readerTabBinding = nil; readerTabParentObservation = nil
        bound.release()
        originalPresentationStateDidChange()
    }

    func prepareReaderTabRoute(_ bound: MaktabahNativeReaderTabBinding,
                               invocation: ActionPortInvocation, scene: UISceneSnapshot) throws -> RouteSpec {
        guard readerTabBinding === bound, bound.isReserved, !bound.isApplied,
              invocation.requestId == bound.requestID, scene.sceneID == sceneID,
              invocation.snapshot.backend == bound.target.backend else {
            throw UIRouteError(.staleState, "native_reader_tab_request_changed")
        }
        try bound.validate()
        return .init(requestId: invocation.requestId, destination: MaktabahNativeReaderTabBinding.destination,
            backend: invocation.snapshot.backend,
            presentation: .init(kind: .currentTab, tabID: UIStableID(rawValue: bound.target.tabID.uuidString)),
            state: .init(workspaceID: UIStableID(rawValue: bound.target.groupID.uuidString),
                         profileID: UIStableID(rawValue: bound.target.profileID.uuidString)),
            scene: .init(kind: .specific, sceneID: sceneID, expectedRevision: scene.revision),
            expectedBackendSnapshot: invocation.snapshot)
    }

    func validateReaderTabCompletion(_ bound: MaktabahNativeReaderTabBinding,
                                     receipt: UISceneReceipt) throws {
        guard readerTabBinding === bound, bound.isApplied, receipt.requestId == bound.requestID,
              receipt.route.destination == MaktabahNativeReaderTabBinding.destination else {
            throw UIRouteError(.staleState, "native_reader_tab_completed_owner_changed")
        }
        try bound.validate()
        try validateCompletedJourneySurface(receipt)
        guard readerTabBinding === bound else { throw UIRouteError(.staleState, "native_reader_tab_completed_owner_changed") }
        try bound.validate()
    }

    func workspaceSelectionCatalog(windowTitle: String) throws -> [NativeWorkspaceSelectionIntentService.Selection] {
        guard mounted, workspaceSelectionBinding == nil, readerTabBinding == nil, isReaderTabSourceReady,
              bindings.selectedTab.wrappedValue == .viewer, bindings.manager.currentMode == .viewer,
              let source = workspaceProjectionSource else { return [] }
        return try MaktabahNativeWorkspaceSelectionBinding.catalog(sceneID: sceneID, manager: bindings.manager,
                                                                    source: source, windowTitle: windowTitle)
    }

    func retainWorkspaceSelection(_ target: NativeWorkspaceSelectionIntentService.Selection,
                                  requestID: UUID) throws -> MaktabahNativeWorkspaceSelectionBinding {
        guard mounted, target.sceneID == sceneID, command == nil,
              workspaceSelectionBinding == nil, readerTabBinding == nil, readerBinding == nil,
              searchResultsBinding == nil, isReaderTabSourceReady, let source = workspaceProjectionSource else {
            throw UIRouteError(.unavailable, "native_workspace_selection_scene_busy")
        }
        let bound = try MaktabahNativeWorkspaceSelectionBinding(requestID: requestID, target: target,
            bindings: bindings, source: source,
            foreignReady: { [weak self] in self?.isReaderTabSourceReady == true },
            readForeignPresentations: { [weak self] in
                guard let self else { return }
                _ = workspacePresentation?.originalStateRevision
                _ = studyChatPresentationID; _ = hasOriginalSefariaSurface
            })
        workspaceSelectionBinding = bound
        return bound
    }

    func reserveWorkspaceSelection(_ bound: MaktabahNativeWorkspaceSelectionBinding) throws {
        guard workspaceSelectionBinding === bound, mounted, foreground, command == nil,
              isReaderTabSourceReady, windowSource?.isPresentationReady(in: sceneID) == true else {
            throw UIRouteError(.unavailable, "native_workspace_selection_presentation_unavailable")
        }
        try bound.reserve()
    }

    func prepareWorkspaceSelection(_ bound: MaktabahNativeWorkspaceSelectionBinding,
                                   validateLifetime: @escaping @MainActor () throws -> Void) async throws {
        guard workspaceSelectionBinding === bound, command == nil, mounted, foreground else {
            throw UIRouteError(.staleState, "native_workspace_selection_owner_changed")
        }
        try await bound.prepare { [weak self] in
            try validateLifetime()
            guard let self, self.workspaceSelectionBinding === bound, self.command == nil,
                  self.mounted, self.foreground, self.isReaderTabSourceReady else {
                throw UIRouteError(.staleState, "native_workspace_selection_scene_changed")
            }
        }
    }

    func releaseWorkspaceSelection(_ bound: MaktabahNativeWorkspaceSelectionBinding) {
        guard workspaceSelectionBinding === bound else { return }
        workspaceSelectionBinding = nil
        bound.release()
        originalPresentationStateDidChange()
    }

    func prepareWorkspaceSelectionRoute(_ bound: MaktabahNativeWorkspaceSelectionBinding,
                                        invocation: ActionPortInvocation, scene: UISceneSnapshot) throws -> RouteSpec {
        guard workspaceSelectionBinding === bound, bound.isPrepared, !bound.isApplied,
              invocation.requestId == bound.requestID, scene.sceneID == sceneID,
              invocation.snapshot.backend == bound.target.backend else {
            throw UIRouteError(.staleState, "native_workspace_selection_request_changed")
        }
        try bound.validate()
        return .init(requestId: invocation.requestId, destination: MaktabahNativeWorkspaceSelectionBinding.destination,
            backend: invocation.snapshot.backend,
            presentation: .init(kind: .currentTab, tabID: bound.target.activeDocumentID.flatMap { UIStableID(rawValue: $0.uuidString) }),
            state: .init(workspaceID: UIStableID(rawValue: bound.target.groupID.uuidString),
                         profileID: UIStableID(rawValue: bound.target.profileID.uuidString)),
            scene: .init(kind: .specific, sceneID: sceneID, expectedRevision: scene.revision),
            expectedBackendSnapshot: invocation.snapshot)
    }

    func validateWorkspaceSelectionCompletion(_ bound: MaktabahNativeWorkspaceSelectionBinding,
                                              receipt: UISceneReceipt) throws {
        guard workspaceSelectionBinding === bound, bound.isApplied, receipt.requestId == bound.requestID,
              receipt.route.destination == MaktabahNativeWorkspaceSelectionBinding.destination else {
            throw UIRouteError(.staleState, "native_workspace_selection_completed_owner_changed")
        }
        try bound.validate()
        try validateCompletedJourneySurface(receipt)
        guard workspaceSelectionBinding === bound else {
            throw UIRouteError(.staleState, "native_workspace_selection_completed_owner_changed")
        }
        try bound.validate()
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
        #if DEBUG
        if noteDraftBinding === bound { diagnoseNoteDraftSurface(stage: "before-binding-release") }
        #endif
        if noteDraftBinding === bound {
            noteDraftBinding = nil
            visibilityChecks[UIDestinationID(rawValue: "native.reader.noteDraft")!] = nil
        }
        // The original unsaved editor remains under the user's Save/Cancel.
    }
    func prepareNoteDraftRoute(invocation: ActionPortInvocation, scene: UISceneSnapshot) throws -> RouteSpec {
        guard let bound = noteDraftBinding else { throw ActionPortError.unavailable }
        try bound.validate()
        let identity = try project().identity(workspacePresentation: workspacePresentation, sefariaSurface: sefariaSurfaceBinding, savedResults: savedResultsBinding)
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
        bindings.isPresentationReady && !hasOriginalWorkspacePresentation && !hasOriginalSefariaSurface
            && noteEditorOwner?.current == nil && noteEditorOwner?.presentationActive != true
            && (studyChatPresentationID == nil || studyChatPresentationID == id)
    }
    func isRootAvailable(_ destination: UIDestinationID) -> Bool {
        if destination == MaktabahNativeSavedResultsBinding.destination {
            return savedResultsBinding?.isAvailable == true
        }
        if destination == MaktabahNativeSefariaSurfaceBinding.destination {
            return sefariaSurfaceBinding?.isAvailable == true
                && MaktabahNativeSefariaRootSource.isAvailable(bindings, workspace: workspacePresentation)
        }
        if usesOriginalPhoneTOC(destination) {
            return MaktabahNativeRootDestination.library.isAvailable
                && phoneTOCPresentation?.isAvailable() == true
        }
        if let parent = MaktabahNativeWorkspacePresentationBinding.Parent(rawValue: destination.rawValue) {
            return workspacePresentation?.isAvailable(parent: parent) == true
        }
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
        if let workspaceSource, workspaceSource.isAuthoritative {
            viewerParentHost = MaktabahNativeViewerParentHost(sceneID: sceneID, manager: bindings.manager,
                isCurrentSession: { [weak self] in self?.mounted == true && self?.foreground == true },
                captureOriginalWindow: { [weak self] in
                    guard let self else { throw UIRouteError(.staleState, "native_viewer_parent_session_changed") }
                    return try self.retainOriginalWindowObservation()
                }, originalRootIsReady: { [weak self] in
                    guard let self else { return false }
                    return self.isReaderTabSourceReady && self.windowSource?.isPresentationReady(in: self.sceneID) == true
                })
            let searchEntry = MaktabahNativeSearchEntryBinding(sceneID: sceneID, bindings: bindings,
                workspaceSource: workspaceSource,
                commonReady: { [weak self] in
                    guard let self else { return false }
                    return mounted && foreground && isPresentationReady && searchPresentationBlocked?() != true
                }, windowReady: { [weak self] in
                    guard let self else { return false }
                    return windowSource?.isPresentationReady(in: sceneID) == true
                }, parentVisible: { [weak self] in
                    guard let self else { return false }
                    return (try? project().surface(.search)) != nil
                })
            searchEntryBinding = searchEntry
            attachComponentOwner(searchEntry.owner)
            let original = MaktabahNativeWorkspacePresentationBinding(sceneID: sceneID,
                manager: bindings.manager, workspaceSource: workspaceSource, sidebar: bindings.sidebar,
                selectViewer: { bindings.selectOriginalWorkspaceParent() })
            workspacePresentation = original
            original.install(changed: { [weak self, weak original] in
                guard let self, let original, workspacePresentation === original else { return }
                originalPresentationStateDidChange()
            }, invalidated: { [weak self] in self?.presentation.revoke() })
            for owner in MaktabahNativeWorkspaceComponents.makeOwners(binding: original) { attachComponentOwner(owner) }
            let history = MaktabahNativeHistoryRecordBinding(sceneID: sceneID, bindings: bindings,
                workspaceSource: workspaceSource, workspacePresentation: original,
                commonReady: { [weak self] in
                    guard let self else { return false }
                    // Source is retained before system foreground activation.
                    // Foreground and the real window are mandatory at begin.
                    return mounted && isPresentationReady && !bindings.showSettings.wrappedValue
                        && searchPresentationBlocked?() != true
                }, windowReady: { [weak self] in
                    guard let self else { return false }
                    return foreground && windowSource?.isPresentationReady(in: sceneID) == true
                }, readForeignPresentations: { [weak self] in
                    guard let self else { return }
                    _ = mounted; _ = studyChatPresentationID
                    // Original Notes/Search local State invalidates through
                    // their existing exact-owner pre-mutation callbacks.
                })
            historyRecordBinding = history
            history.install(changed: { [weak self, weak history] in
                guard let self, let history, historyRecordBinding === history else { return }
                originalPresentationStateDidChange()
            }, invalidated: { [weak self] in
                guard let self, retainedHistoryRecord else { return }
                presentation.revoke()
            })
            let saved = MaktabahNativeSavedResultsBinding(sceneID: sceneID, bindings: bindings,
                workspaceSource: workspaceSource, workspacePresentation: original,
                commonReady: { [weak self] in
                    guard let self else { return false }
                    // Primitive foreign-presentation checks, deliberately not
                    // recursive isPresentationReady (which blocks this own sheet).
                    return mounted && readerBinding == nil && readerTabBinding == nil
                        && workspaceSelectionBinding == nil && searchResultsBinding == nil
                        && searchContinuationOwner == nil && bindings.isPresentationReady
                        && !bindings.showSettings.wrappedValue && !hasOriginalWorkspacePresentation
                        && !hasOriginalSefariaSurface && studyChatPresentationID == nil
                        && noteEditorOwner?.current == nil && noteEditorOwner?.presentationActive != true
                }, windowReady: { [weak self] in
                    guard let self else { return false }
                    return foreground && windowSource?.isPresentationReady(in: sceneID) == true
                }, retainWindow: { [weak self] in
                    guard let self else { throw UIRouteError(.staleState, "native_saved_results_window_detached") }
                    return try retainOriginalWindowObservation()
                }, readForeignPresentations: { [weak self] in
                    guard let self else { return }
                    _ = mounted; _ = studyChatPresentationID
                    _ = workspacePresentation?.originalStateRevision
                })
            savedResultsBinding = saved
            saved.install(changed: { [weak self, weak saved] in
                guard let self, let saved, savedResultsBinding === saved else { return }
                originalPresentationStateDidChange()
            }, invalidated: { [weak self] in
                guard let self, retainedSavedResults else { return }
                presentation.revoke()
            })
            let sefaria = MaktabahNativeSefariaSurfaceBinding(sceneID: sceneID,
                manager: bindings.manager, workspaceSource: workspaceSource)
            sefariaSurfaceBinding = sefaria
            sefaria.install(changed: { [weak self, weak sefaria] in
                guard let self, let sefaria, sefariaSurfaceBinding === sefaria else { return }
                originalPresentationStateDidChange()
            }, invalidated: { [weak self] in self?.presentation.revoke() })
            if !MaktabahApp.isIpad {
                let phone = MaktabahNativePhoneTOCPresentationBinding(sceneID: sceneID,
                    manager: bindings.manager, workspaceSource: workspaceSource,
                    presentReader: { try bindings.presentOriginalPhoneTOCReader($0) })
                phoneTOCPresentation = phone
                phone.install(changed: { [weak self, weak phone] in
                    guard let self, let phone, phoneTOCPresentation === phone else { return }
                    originalPresentationStateDidChange()
                }, invalidated: { [weak self] in self?.presentation.revoke() })
            }
        }
        attachComponentOwner(MaktabahNativeSettingsComponents.makeOwner())
        attachComponentOwner(MaktabahNativeTOCComponents.makeOwner(manager: bindings.manager,
                                                                  phonePresentation: phoneTOCPresentation))
        attachComponentOwner(MaktabahNativeLibraryComponents.makeOwner(manager: bindings.manager))
    }

    func mount(validateLifetime: @escaping NativeSceneDirectory.ValidateLifetime) throws {
        guard lease == nil, mounted else { throw UIRouteError(.staleState, "scene_session_already_mounted") }
        lease = try directory.mount(sceneID: sceneID, observe: { [weak self] in
            guard let self, mounted else { throw UIRouteError(.unavailable, "scene_missing") }
            let projection = try project()
            var route: RouteSpec?
            var surface: NativeSurfaceState?
            if let command, isPresentationReady(for: command.route.route.destination),
               let evidence = visible[command.route.route.destination], evidence.isVisible,
               let currentEvidence = visibilityChecks[command.route.route.destination]?(), currentEvidence == evidence,
               evidence.sceneID == sceneID, evidence.submissionID == command.invocation.requestId,
               let kind = surfaceKind(command.route.route.destination), let current = try self.surface(kind),
               current == evidence.surface,
               (kind != .reader || projection.hasRenderedReaderEvidence(sceneID: sceneID,
                    includingContainingSection: command.route.route.destination == MaktabahNativeReaderTabBinding.destination)),
               (kind != .noteDraft || (try? noteDraftBinding?.validateVisible()) != nil) {
                surface = current
                route = current.observedRoute(for: command, backend: command.invocation.snapshot)
            }
            return .init(isForeground: foreground, isMounted: mounted, visibleRoute: route, surface: surface,
                         identity: try projection.identity(workspacePresentation: workspacePresentation, sefariaSurface: sefariaSurfaceBinding, savedResults: savedResultsBinding))
        }, validateLifetime: validateLifetime)
    }

    /// Preparation for the observer only; caller must possess the canonical
    /// Core grant before invoking any native binding/model mutation afterwards.
    func beginObservation(_ value: UISceneCommand) throws {
        guard mounted, lease != nil, value.scene.sceneID == sceneID else { throw UIRouteError(.staleState, "scene_lifetime_changed") }
        let field: UISearchTextField?
        if value.route.route.focus != nil, value.route.route.destination == NativeSearchFieldVisibility.destination,
           value.route.route.focus?.anchor != MaktabahNativeSearchEntryBinding.anchor {
            guard value.route.route.focus == NativeSearchFieldVisibility.focus,
                  searchFieldAvailable, let original = nativeSearchField else {
                throw UIRouteError(.unavailable, "native_search_field_not_visible")
            }
            field = original
        } else { field = nil }
        let component: MaktabahNativeComponentOwner?
        let renderValidation: (@MainActor () throws -> Void)?
        if let focus = value.route.route.focus, field == nil {
            guard focus.kind == .component, focus.locator == nil, focus.range == nil,
                  let anchor = focus.anchor, let owner = componentOwners[value.route.route.destination],
                  owner.isAvailable(anchor) else {
                throw UIRouteError(.unavailable, "native_component_unavailable")
            }
            component = owner
            renderValidation = try boundedRenderValidation(for: value, owner: owner, anchor: anchor)
        } else { component = nil; renderValidation = nil }
        let workspaceParent = MaktabahNativeWorkspacePresentationBinding.Parent(rawValue: value.route.route.destination.rawValue)
        let phoneTOC = usesOriginalPhoneTOC(value.route.route.destination)
        let sefaria = value.route.route.destination == MaktabahNativeSefariaSurfaceBinding.destination
        let historyRecord = value.route.route.destination == MaktabahNativeHistoryRecords.destination
            && value.route.route.state.selectedItemID != nil
        let workspaceSelection = value.route.route.destination == MaktabahNativeWorkspaceSelectionBinding.destination
        let savedResults = value.route.route.destination == MaktabahNativeSavedResultsBinding.destination
        let parentValidation: (@MainActor () throws -> Void)?
        if workspaceParent != nil || phoneTOC || sefaria || historyRecord || savedResults {
            parentValidation = try renderValidation ?? boundedRenderValidation(for: value)
        } else { parentValidation = nil }
        let inspector: MaktabahNativeInspectorBinding?
        if value.route.route.destination.rawValue == "native.reader.inspector" {
            guard try publicBindingPresentation().inspectorAvailable else {
                throw UIRouteError(.unavailable, "native_inspector_reader_unavailable")
            }
            inspector = try MaktabahNativeInspectorBinding(manager: bindings.manager)
        } else { inspector = nil }
        try presentation.begin(value)
        do {
            if workspaceSelection {
                guard let bound = workspaceSelectionBinding, bound.requestID == value.invocation.requestId,
                      let componentValidation else {
                    throw UIRouteError(.staleState, "native_workspace_selection_owner_missing")
                }
                let originalLifetime = try componentValidation(value)
                try bound.begin { [weak self, weak bound] in
                    try originalLifetime()
                    guard let self, let bound, self.workspaceSelectionBinding === bound,
                          self.mounted, self.foreground, self.isReaderTabSourceReady else {
                        throw UIRouteError(.staleState, "native_workspace_selection_lifetime_changed")
                    }
                    try bound.validate()
                }
            }
            if value.route.route.destination == MaktabahNativeReaderTabBinding.destination {
                guard let bound = readerTabBinding, bound.requestID == value.invocation.requestId else {
                    throw UIRouteError(.staleState, "native_reader_tab_owner_missing")
                }
                readerTabParentObservation = nil
                try bound.viewerParent?.bind(value)
            }
            if let workspaceParent, let parentValidation, let workspacePresentation {
                try workspacePresentation.begin(parent: workspaceParent, requestID: value.invocation.requestId,
                                                validate: parentValidation)
            }
            if phoneTOC {
                guard let phoneTOCPresentation, let parentValidation else {
                    throw UIRouteError(.unavailable, "native_phone_toc_parent_detached")
                }
                try phoneTOCPresentation.begin(requestID: value.invocation.requestId, validate: parentValidation)
            }
            if sefaria {
                guard let sefariaSurfaceBinding, let parentValidation else {
                    throw UIRouteError(.unavailable, "native_sefaria_parent_detached")
                }
                try sefariaSurfaceBinding.begin(requestID: value.invocation.requestId, validate: parentValidation)
            }
            if savedResults {
                guard let savedResultsBinding, let parentValidation else {
                    throw UIRouteError(.unavailable, "native_saved_results_owner_missing")
                }
                try savedResultsBinding.begin(requestID: value.invocation.requestId, validate: parentValidation)
            }
            if historyRecord {
                guard let historyRecordBinding, let parentValidation else {
                    throw UIRouteError(.unavailable, "native_history_record_owner_missing")
                }
                try historyRecordBinding.begin(requestID: value.invocation.requestId, validate: parentValidation)
            }
            if let component, let anchor = value.route.route.focus?.anchor, let renderValidation {
                if component === searchEntryBinding?.owner {
                    try searchEntryBinding?.begin(requestID: value.invocation.requestId, validate: renderValidation)
                }
                try component.begin(requestID: value.invocation.requestId, anchor: anchor, validate: renderValidation)
            }
        } catch {
            if workspaceSelection { workspaceSelectionBinding?.invalidate() }
            workspacePresentation?.finish(requestID: value.invocation.requestId, completed: false)
            phoneTOCPresentation?.finish(requestID: value.invocation.requestId, completed: false)
            searchEntryBinding?.finish(requestID: value.invocation.requestId, completed: false)
            sefariaSurfaceBinding?.finish(requestID: value.invocation.requestId, completed: false)
            historyRecordBinding?.finish(requestID: value.invocation.requestId, completed: false)
            savedResultsBinding?.finish(requestID: value.invocation.requestId, completed: false)
            presentation.end(requestID: value.invocation.requestId)
            throw error
        }
        retainedWorkspaceParent = workspaceParent
        retainedPhoneTOC = phoneTOC
        retainedSefariaSurface = sefaria
        retainedHistoryRecord = historyRecord
        retainedSavedResults = savedResults
        if !savedResults { savedResultsBinding?.clearCompletedProof() }
        if !historyRecord { historyRecordBinding?.clearCompletedProof() }
        retainedComponentOwner = component
        inspectorBinding = inspector
        retainedSearchField = field
        lastCompletedSurface = nil
        completedSefariaRootSource = nil
        command = value; submissionID = value.invocation.requestId
    }

    func retainReader(_ content: ActionReaderDestination, requestID: UUID,
                      historySource: MaktabahNativeHistoryReaderSource? = nil,
                      revoke: @escaping @MainActor () -> Void) throws -> MaktabahNativeReaderBinding {
        guard readerBinding == nil else { throw UIRouteError(.unavailable, "reader_binding_busy") }
        let identity = try project().identity(workspacePresentation: workspacePresentation, sefariaSurface: sefariaSurfaceBinding, savedResults: savedResultsBinding)
        let workspace = try workspaceProjectionSource?.read()
        if content.presentationMode == .newTab, workspaceProjectionSource?.isAuthoritative != true {
            throw UIRouteError(.unavailable, "new_reader_workspace_unavailable")
        }
        let retained = try MaktabahNativeReaderBinding(manager: bindings.manager,
            currentTabID: identity.activeTabID, workspace: workspace, requestID: requestID, content: content,
            historySource: historySource, revoke: revoke)
        readerBinding = retained
        return retained
    }
    func releaseReader(_ retained: MaktabahNativeReaderBinding) {
        guard readerBinding === retained else { return }
        retained.release(); readerBinding = nil
    }


    /// Retain the selected original window before system foreground activation.
    /// This read-only witness ends at the existing Reader reservation handoff;
    /// the original mapping/Core owners govern all later native awaits.
    func captureHistoryReaderWindow() throws -> @MainActor () throws -> Void {
        let originalWindow = try retainOriginalWindowObservation()
        _ = try originalWindow.validate()
        let manager = bindings.manager
        guard mounted, !bindings.showSettings.wrappedValue, bindings.isPresentationReady,
              let root = bindings.rootPublications,
              let rootRevision = root.selectionRevision, let settingsRevision = root.settingsRevision,
              let modeRevision = manager.nativeModePresentationRevision,
              let bookRevision = manager.selectedBookPresentationRevision,
              let source = workspaceProjectionSource, source.isAuthoritative,
              let workspace = try source.read(), workspace.attached, !workspace.isSwitching,
              let mapping = workspace.mappingOwnershipObservation(),
              mapping.coverage == .liveNativeSetters, mapping.scene == sceneID.rawValue,
              mapping.owner == ObjectIdentifier(manager), mapping.source.event.phase == .available,
              mapping.source.event.epoch == mapping.epoch else {
            throw UIRouteError(.unavailable, "history_reader_window_owner_unavailable")
        }
        let selected = bindings.selectedTab.wrappedValue
        guard selected == selected.canonical, manager.currentMode == selected.appMode else {
            throw UIRouteError(.unavailable, "history_reader_window_not_committed")
        }
        let observation = MaktabahNativeComponentSourceObservation {
            _ = manager.openTabs; _ = manager.activeTabId; _ = manager.selectedBook
            _ = manager.selectedContentId; _ = manager.currentMode
            _ = manager.selectedBookForInfo; _ = manager.showingTabsList; _ = manager.alertMessage
            _ = manager.activeReaderViewModel?.isPopoverPresented
            _ = manager.activeReaderViewModel?.readerInspectorVisible
            _ = DonationManager.shared.showDonationSheet
            _ = workspace.attached; _ = workspace.isSwitching
            _ = workspace.mappingOwnershipSource.event
        }
        let validate: @MainActor () throws -> Void = { [weak self, weak manager, weak workspace] in
            _ = try originalWindow.validate()
            try observation.validate()
            guard let self, let manager, let workspace, self.mounted,
                  self.bindings.manager === manager, self.bindings.rootPublications === root,
                  root.selectionRevision == rootRevision, root.settingsRevision == settingsRevision,
                  self.bindings.selectedTab.wrappedValue == selected,
                  manager.currentMode == selected.appMode,
                  manager.nativeModePresentationRevision == modeRevision,
                  manager.selectedBookPresentationRevision == bookRevision,
                  !self.bindings.showSettings.wrappedValue, self.bindings.isPresentationReady,
                  self.workspaceProjectionSource === source, source.isAuthoritative,
                  let current = try source.read(), current === workspace,
                  workspace.attached, !workspace.isSwitching,
                  let actual = workspace.mappingOwnershipObservation(),
                  actual.coverage == .liveNativeSetters, actual.source === mapping.source,
                  actual.owner == mapping.owner, actual.scene == mapping.scene,
                  actual.epoch == mapping.epoch, actual.projection == mapping.projection,
                  actual.source.event.phase == .available, actual.source.event.epoch == actual.epoch else {
                throw UIRouteError(.staleState, "history_reader_window_owner_changed")
            }
            try observation.validate()
            _ = try originalWindow.validate()
        }
        try validate()
        return validate
    }

    func retainSavedResult(_ record: NativeSavedResultIntentService.Record, requestID: UUID) throws
        -> MaktabahNativeSavedResultsBinding {
        guard mounted, let original = savedResultsBinding else {
            throw UIRouteError(.unavailable, "native_saved_results_owner_missing")
        }
        try original.retain(record: record, requestID: requestID)
        return original
    }
    func prepareSavedResult(invocation: ActionPortInvocation, scene: UISceneSnapshot) throws -> RouteSpec {
        guard mounted, foreground, scene.sceneID == sceneID, let original = savedResultsBinding else {
            throw UIRouteError(.staleState, "native_saved_results_window_changed")
        }
        let selected = try original.selectedItem(requestID: invocation.requestId)
        let identity = try project().identity(workspacePresentation: workspacePresentation, sefariaSurface: sefariaSurfaceBinding, savedResults: savedResultsBinding)
        return RouteSpec(requestId: invocation.requestId, destination: MaktabahNativeSavedResultsBinding.destination,
            backend: invocation.snapshot.backend, presentation: .init(kind: .sheet),
            state: .init(workspaceID: identity.state.workspaceID, profileID: identity.state.profileID, selectedItemID: selected),
            scene: .init(kind: .specific, sceneID: sceneID, expectedRevision: scene.revision),
            expectedBackendSnapshot: invocation.snapshot)
    }
    func validateCompletedSavedResult(_ receipt: UISceneReceipt,
                                     original: MaktabahNativeSavedResultsBinding) throws {
        guard savedResultsBinding === original,
              receipt.route.destination == MaktabahNativeSavedResultsBinding.destination,
              original.hasVisibleSurface(requestID: receipt.requestId),
              original.observedItem(requestID: receipt.requestId) == receipt.route.state.selectedItemID else {
            throw UIRouteError(.staleState, "native_saved_results_completion_changed")
        }
        try original.validateCompletedSurface(requestID: receipt.requestId)
        try validateCompletedJourneySurface(receipt)
        try original.validateSource(requestID: receipt.requestId)
    }

    /// Typed record metadata is converted into private route state only by the
    /// exact scene which retained its actual original publication before await.
    func retainHistoryRecord(_ record: NativeHistoryRecordIntentService.Record, requestID: UUID) throws
        -> MaktabahNativeHistoryRecordBinding {
        guard mounted, let original = historyRecordBinding else {
            throw UIRouteError(.unavailable, "native_history_record_owner_missing")
        }
        try original.retain(record: record, requestID: requestID)
        return original
    }
    func prepareHistoryRecord(invocation: ActionPortInvocation, scene: UISceneSnapshot) throws -> RouteSpec {
        guard mounted, foreground, scene.sceneID == sceneID, let original = historyRecordBinding else {
            throw UIRouteError(.staleState, "native_history_record_window_changed")
        }
        let itemID = try original.selectedItem(requestID: invocation.requestId)
        let identity = try project().identity(workspacePresentation: workspacePresentation, sefariaSurface: sefariaSurfaceBinding, savedResults: savedResultsBinding)
        return RouteSpec(requestId: invocation.requestId, destination: MaktabahNativeHistoryRecords.destination,
            backend: invocation.snapshot.backend,
            state: .init(workspaceID: identity.state.workspaceID, profileID: identity.state.profileID, selectedItemID: itemID),
            scene: .init(kind: .specific, sceneID: sceneID, expectedRevision: scene.revision),
            expectedBackendSnapshot: invocation.snapshot)
    }
    func validateCompletedHistoryRecord(_ receipt: UISceneReceipt,
                                        original: MaktabahNativeHistoryRecordBinding) throws {
        guard historyRecordBinding === original,
              receipt.route.destination == MaktabahNativeHistoryRecords.destination,
              try original.selectedItem(requestID: receipt.requestId) == receipt.route.state.selectedItemID,
              try original.observedItem() == receipt.route.state.selectedItemID else {
            throw UIRouteError(.staleState, "native_history_record_completion_changed")
        }
        try validateCompletedJourneySurface(receipt)
        try original.validateSource(requestID: receipt.requestId)
    }

    func validateSurface(_ command: UISceneCommand) throws {
        guard mounted, foreground else { throw UIRouteError(.requiresForeground, "exact_foreground_scene_required") }
        guard isPresentationReady(for: command.route.route.destination) else {
            throw UIRouteError(.unavailable, "native_presentation_in_progress")
        }
        let route = command.route.route, projection = try project()
        let identity = try projection.identity(workspacePresentation: workspacePresentation, sefariaSurface: sefariaSurfaceBinding, savedResults: savedResultsBinding)
        try validateParentSource(destination: route.destination, requestID: command.invocation.requestId)
        if route.destination == MaktabahNativeWorkspaceSelectionBinding.destination {
            guard command.scene.sceneID == sceneID, route.content == nil, route.focus == nil,
                  let bound = workspaceSelectionBinding, bound.isReserved,
                  bound.requestID == command.invocation.requestId,
                  route.backend == bound.target.backend,
                  route.presentation == .init(kind: .currentTab,
                    tabID: bound.target.activeDocumentID.flatMap { UIStableID(rawValue: $0.uuidString) }),
                  route.state == UIStateSpec(workspaceID: UIStableID(rawValue: bound.target.groupID.uuidString),
                                             profileID: UIStableID(rawValue: bound.target.profileID.uuidString)) else {
                throw UIRouteError(.staleState, "native_workspace_selection_route_changed")
            }
            // This private route's original one-use Store/native reservation
            // validates BOTH sides of its authorized workspace change. Generic
            // roots retain the unchanged-workspace guard below.
            try bound.validate()
            return
        }
        guard command.scene.sceneID == sceneID, route.state.workspaceID == identity.state.workspaceID,
              route.state.profileID == identity.state.profileID else { throw UIRouteError(.staleState, "native_workspace_changed") }
        if route.destination == MaktabahNativeSavedResultsBinding.destination {
            guard route.backend == .otzaria, route.content == nil, route.focus == nil,
                  route.presentation == .init(kind: .sheet), let savedResultsBinding,
                  route.state == UIStateSpec(workspaceID: identity.state.workspaceID,
                      profileID: identity.state.profileID,
                      selectedItemID: try savedResultsBinding.selectedItem(requestID: command.invocation.requestId)) else {
                throw UIRouteError(.staleState, "native_saved_results_route_changed")
            }
            return
        }
        if route.destination == MaktabahNativeHistoryRecords.destination, let itemID = route.state.selectedItemID {
            guard route.content == nil, route.focus == nil, route.presentation.kind == .currentTab,
                  route.presentation.tabID == nil, let historyRecordBinding,
                  route.state == UIStateSpec(workspaceID: identity.state.workspaceID,
                      profileID: identity.state.profileID, selectedItemID: itemID),
                  try historyRecordBinding.selectedItem(requestID: command.invocation.requestId) == itemID else {
                throw UIRouteError(.staleState, "native_history_record_route_changed")
            }
            return
        }
        if route.destination == MaktabahNativeReaderTabBinding.destination {
            guard route.content == nil, route.focus == nil, route.presentation.kind == .currentTab,
                  let bound = readerTabBinding, bound.isReserved,
                  bound.requestID == command.invocation.requestId,
                  route.presentation.tabID?.rawValue == bound.target.tabID.uuidString,
                  route.state == UIStateSpec(workspaceID: UIStableID(rawValue: bound.target.groupID.uuidString),
                                             profileID: UIStableID(rawValue: bound.target.profileID.uuidString)) else {
                throw UIRouteError(.staleState, "native_reader_tab_route_changed")
            }
            try bound.validate()
            return
        }
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
            if route.destination == NativeSearchFieldVisibility.destination,
               focus.anchor != MaktabahNativeSearchEntryBinding.anchor {
                guard focus == NativeSearchFieldVisibility.focus, searchFieldAvailable,
                      retainedSearchField == nil || retainedSearchField === nativeSearchField else {
                    throw UIRouteError(.unavailable, "native_search_field_not_visible")
                }
            } else {
                guard focus.kind == .component, focus.locator == nil, focus.range == nil,
                      let anchor = focus.anchor, let owner = componentOwners[route.destination],
                      owner.presentation == route.presentation.kind, owner.isAvailable(anchor),
                      retainedComponentOwner == nil || retainedComponentOwner === owner else {
                    throw UIRouteError(.unavailable, "native_component_unavailable")
                }
            }
        }
        guard route.content == nil, route.presentation.tabID == nil,
              route.state == UIStateSpec(workspaceID: identity.state.workspaceID, profileID: identity.state.profileID) else {
            throw UIRouteError(.notSupported, "native_surface_variant_not_installed")
        }
        switch route.destination.rawValue {
        case "native.sefariaEmbedded":
            guard route.presentation.kind == .sheet, route.focus == nil,
                  isRootAvailable(route.destination) else {
                throw UIRouteError(.unavailable, "native_sefaria_surface_unavailable")
            }
        case "native.workspace.profiles", "native.workspace.overview":
            guard route.presentation.kind == .sheet, isRootAvailable(route.destination) else {
                throw UIRouteError(.unavailable, "native_workspace_parent_unavailable")
            }
        case "native.settings":
            guard route.presentation.kind == .sheet else { throw UIRouteError(.notSupported, "settings_presentation_not_installed") }
        case "native.library", "native.reader.toc", "native.history", "native.search", "native.annotations":
            guard route.presentation.kind == .currentTab, isRootAvailable(route.destination) else {
                throw UIRouteError(.notSupported, "native_root_presentation_unavailable")
            }
        default: throw UIRouteError(.notSupported, "native_surface_not_installed")
        }
    }

    // Opt-in ONLY for an existing Reader-tab request retained on a foreign
    // original root. The same command/preparation owns both effects; these
    // methods grant nothing and never call an async feature action from render.
    func originalParentSelectionKind(for value: UISceneCommand) throws -> UIOriginalParentSelectionKind? {
        guard value.route.route.destination == MaktabahNativeReaderTabBinding.destination else { return nil }
        guard command == value, let bound = readerTabBinding, bound.requestID == value.invocation.requestId,
              bound.isReserved else { throw UIRouteError(.staleState, "native_reader_tab_owner_missing") }
        try bound.validate()
        guard let parent = bound.viewerParent else { return nil }
        try parent.validates(value)
        return .readerTab
    }
    func applyOriginalParent(_ value: UISceneCommand) throws {
        try validateSurface(value)
        guard command == value, let bound = readerTabBinding, let parent = bound.viewerParent,
              bound.requestID == value.invocation.requestId, !bound.isApplied else {
            throw UIRouteError(.staleState, "native_viewer_parent_owner_changed")
        }
        try bound.validate()
        try parent.applyParent(value)
        guard readerTabBinding === bound, command == value else {
            throw UIRouteError(.staleState, "native_viewer_parent_owner_changed")
        }
        try bound.validate()
        originalPresentationStateDidChange()
    }
    func waitUntilOriginalParentReady(_ value: UISceneCommand) async throws -> NativeOriginalParentObservation {
        guard command == value, let bound = readerTabBinding, let parent = bound.viewerParent,
              bound.requestID == value.invocation.requestId else {
            throw UIRouteError(.staleState, "native_viewer_parent_owner_changed")
        }
        try bound.validate()
        let actual = try await parent.waitUntilReady(value)
        guard readerTabBinding === bound, command == value, bound.viewerParent === parent else {
            throw UIRouteError(.staleState, "native_viewer_parent_owner_changed")
        }
        try bound.validate()
        try parent.validateParent(actual, command: value)
        readerTabParentObservation = actual
        return actual
    }
    func validateOriginalParent(_ actual: NativeOriginalParentObservation, for value: UISceneCommand) throws {
        guard command == value, let bound = readerTabBinding, let parent = bound.viewerParent,
              bound.requestID == value.invocation.requestId,
              readerTabParentObservation == actual else {
            throw UIRouteError(.staleState, "native_viewer_parent_owner_changed")
        }
        try bound.validate()
        try parent.validateParent(actual, command: value)
        guard readerTabBinding === bound, command == value else {
            throw UIRouteError(.staleState, "native_viewer_parent_owner_changed")
        }
    }
    func applyOriginalSelection(_ value: UISceneCommand) throws {
        guard command == value, let bound = readerTabBinding, let parent = bound.viewerParent,
              bound.requestID == value.invocation.requestId, let actual = readerTabParentObservation else {
            throw UIRouteError(.staleState, "native_viewer_parent_owner_changed")
        }
        try validateOriginalParent(actual, for: value)
        try parent.beginSelection(actual, command: value)
        // This is the unchanged canonical Reader-tab apply owner. It calls
        // the original manager.selectTab and its original Store checkpoint.
        try apply(value)
    }

    func apply(_ command: UISceneCommand) throws {
        if command.route.route.destination == MaktabahNativeWorkspaceSelectionBinding.destination {
            try validateSurface(command)
            guard let bound = workspaceSelectionBinding else {
                throw UIRouteError(.unavailable, "native_workspace_selection_owner_missing")
            }
            try bound.apply()
            originalPresentationStateDidChange()
            return
        }
        if command.route.route.destination == MaktabahNativeSavedResultsBinding.destination {
            try validateSurface(command)
            guard retainedSavedResults, let savedResultsBinding else {
                throw UIRouteError(.staleState, "native_saved_results_not_prepared")
            }
            try savedResultsBinding.apply(requestID: command.invocation.requestId)
            return
        }
        if command.route.route.destination == MaktabahNativeHistoryRecords.destination,
           command.route.route.state.selectedItemID != nil {
            try validateSurface(command)
            guard retainedHistoryRecord, let historyRecordBinding else {
                throw UIRouteError(.staleState, "native_history_record_not_prepared")
            }
            try historyRecordBinding.apply(requestID: command.invocation.requestId)
            return
        }
        if command.route.route.destination == MaktabahNativeReaderTabBinding.destination {
            try validateSurface(command)
            guard let bound = readerTabBinding else { throw UIRouteError(.unavailable, "native_reader_tab_owner_missing") }
            try bound.apply()
            originalPresentationStateDidChange()
            return
        }
        if command.route.route.destination == MaktabahNativeSefariaSurfaceBinding.destination {
            try validateSurface(command)
            guard retainedSefariaSurface, let original = sefariaSurfaceBinding else {
                throw UIRouteError(.staleState, "native_sefaria_parent_not_prepared")
            }
            // The sole Core-authorized commit publishes only this original RN
            // sheet. Root selection, Reader, query and Settings stay untouched.
            try original.apply(requestID: command.invocation.requestId)
            return
        }
        if usesOriginalPhoneTOC(command.route.route.destination) {
            try validateSurface(command)
            guard retainedPhoneTOC, let phoneTOCPresentation else {
                throw UIRouteError(.staleState, "native_phone_toc_parent_not_prepared")
            }
            if let owner = retainedComponentOwner { try owner.apply(requestID: command.invocation.requestId) }
            try phoneTOCPresentation.apply(requestID: command.invocation.requestId)
            return
        }
        if let parent = MaktabahNativeWorkspacePresentationBinding.Parent(rawValue: command.route.route.destination.rawValue) {
            try validateSurface(command)
            guard retainedWorkspaceParent == parent, let workspacePresentation else {
                throw UIRouteError(.staleState, "native_workspace_parent_not_prepared")
            }
            if let owner = retainedComponentOwner { try owner.apply(requestID: command.invocation.requestId) }
            // One canonical commit. Only the captured original parent setter
            // runs; any cold host continuation keeps this same source/deadline.
            try workspacePresentation.apply(parent: parent, requestID: command.invocation.requestId)
            return
        }
        if command.route.route.destination.rawValue == "native.reader.noteDraft" {
            try validateSurface(command)
            guard let bound = noteDraftBinding else { throw ActionPortError.unavailable }
            try bound.apply()
            // Observe the actual editor's UITextView. Its binding checks the
            // frontmost sheet, scene, text and TextKit layout on each read.
            observeVisibility(for: command.route.route.destination) { [weak self, weak bound] in
                guard let self, let bound, noteDraftBinding === bound,
                      noteEditorOwner === bound.owner, (try? bound.validateVisible()) != nil,
                      let actual = try? surface(.noteDraft) else { return nil }
                return .init(sceneID: sceneID, surface: actual, isVisible: true,
                             submissionID: command.invocation.requestId)
            }
            #if DEBUG
            diagnoseNoteDraftSurface(stage: "after-apply")
            #endif
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
        if let owner = retainedComponentOwner, command.route.route.focus != nil {
            try validateSurface(command)
            try owner.apply(requestID: command.invocation.requestId)
            if let searchEntryBinding, owner === searchEntryBinding.owner {
                try searchEntryBinding.apply(requestID: command.invocation.requestId)
                searchEntryBinding.renderOriginalFieldIfReady()
                return
            }
            // One guarded, synchronous navigation commit publishes BOTH parent
            // visibility and exact target. The original view renders that state.
            try bindings.apply(command)
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
        if command.route.route.destination == MaktabahNativeSefariaSurfaceBinding.destination {
            guard retainedSefariaSurface, let original = sefariaSurfaceBinding,
                  submissionID == command.invocation.requestId else {
                throw UIRouteError(.staleState, "native_sefaria_wait_not_owned")
            }
            try validateSurface(command)
            // This awaits the original RPC/host children inside the existing
            // orchestrator deadline. No detached task, new grant or new timer
            // extends that admission. Cancellation joins the original child.
            try await original.awaitOriginalSurface(requestID: command.invocation.requestId)
            try Task.checkCancellation()
            try validateSurface(command)
            if let actual = visibilityChecks[command.route.route.destination]?() { observe(actual) }
        }
        #if DEBUG
        if command.route.route.destination.rawValue == "native.reader.noteDraft" {
            diagnoseNoteDraftSurface(stage: "wait-begin")
        }
        #endif
        // A container's deduplicated layout callback can precede final geometry
        // or TextKit paint/scroll restoration. Observe the same live UIKit
        // witness only while its original request is waiting; never echo the route.
        let readerObservation: Task<Void, Never>?
        if retainedComponentOwner != nil || retainedHistoryRecord || retainedSavedResults || ["native.reader", "native.reader.tab", "native.workspace.selection", "native.reader.noteDraft", "native.library", "native.reader.toc", "native.annotations",
                                             "native.workspace.profiles", "native.workspace.overview", "native.sefariaEmbedded"].contains(command.route.route.destination.rawValue) {
            readerObservation = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    guard let self, mounted, submissionID == command.invocation.requestId else { return }
                    if retainedHistoryRecord { historyRecordBinding?.renderOriginalContainer() }
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
            if command.route.route.destination.rawValue == "native.reader.noteDraft" {
                diagnoseNoteDraftSurface(stage: "wait-error")
            }
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
        if kind == .sefariaEmbedded {
            let source = submissionID.flatMap { sefariaRootSources[$0] } ?? completedSefariaRootSource
            guard let source, isSefariaOriginalRootReady else { return nil }
            try source.validate(bindings, workspace: workspacePresentation)
        }
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
        _ = componentRevision
        _ = phoneTOCPresentation?.stateRevision
        _ = sefariaSurfaceBinding?.renderRevision
        let historySource = kind == .history && (retainedHistoryRecord
            || (command == nil && lastCompletedSurface?.route.destination == MaktabahNativeHistoryRecords.destination
                && lastCompletedSurface?.route.state.selectedItemID != nil)) ? historyRecordBinding : nil
        guard let state = try project().surface(kind, workspacePresentation: workspacePresentation,
                                               phoneTOCPresentation: phoneTOCPresentation,
                                               sefariaSurface: sefariaSurfaceBinding,
                                               historyRecord: historySource,
                                               savedResults: savedResultsBinding,
                                               savedResultsRequestID: kind == .savedResults
                                                   ? submissionID ?? lastCompletedSurface?.route.requestId : nil) else { return nil }
        if let bound = workspaceSelectionBinding, kind == bound.observedSurface {
            return try bound.selectionSurface(from: state)
        }
        if kind == .reader, let bound = readerTabBinding {
            return try bound.selectionSurface(from: state)
        }
        if command?.route.route.focus != nil, let owner = retainedComponentOwner, owner.destination == state.destination {
            _ = componentRevision
            return .init(destination: state.destination, presentation: state.presentation,
                         content: state.content, state: state.state, focus: owner.actualFocus(in: sceneID))
        }
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
    /// Recheck the original UIKit surface after the navigation request has been retired.
    func guidePresentationIdentity(for route: RouteSpec) throws -> NativeSceneIdentity? {
        guard mounted, foreground, isPresentationReady(for: route.destination), let kind = surfaceKind(route.destination),
              let evidence = visibilityChecks[route.destination]?(), evidence.isVisible, evidence.sceneID == sceneID,
              let actual = try surface(kind), actual == evidence.surface,
              actual.destination == route.destination, actual.presentation == route.presentation,
              actual.content == route.content, actual.state == route.state else { return nil }
        if kind == .reader {
            guard try project().hasRenderedReaderEvidence(sceneID: sceneID,
                includingContainingSection: route.destination == MaktabahNativeReaderTabBinding.destination
                    || route.destination == MaktabahNativeWorkspaceSelectionBinding.destination) else { return nil }
        }
        if actual.focus != route.focus {
            let searchFocus = route.destination == NativeSearchFieldVisibility.destination
                && route.focus == NativeSearchFieldVisibility.focus
                && nativeSearchField?.isFirstResponder == true && searchFieldAvailable
            let componentFocus = route.focus != nil && componentOwners[route.destination]?.actualFocus(in: sceneID) == route.focus
            guard searchFocus || componentFocus else { return nil }
        }
        return try project().identity(workspacePresentation: workspacePresentation, sefariaSurface: sefariaSurfaceBinding, savedResults: savedResultsBinding)
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
           try project().hasRenderedReaderEvidence(sceneID: sceneID, includingContainingSection: true) { reader = current }
        let inspectorID = UIDestinationID(rawValue: "native.reader.inspector")!
        let inspectorWitnessed: Bool
        if let evidence = visibilityChecks[inspectorID]?(), evidence.isVisible, evidence.sceneID == sceneID,
           let actual = try surface(.inspector), actual == evidence.surface { inspectorWitnessed = true }
        else { inspectorWitnessed = false }
        let inspectorAvailable = MaktabahNativeInspectorBinding.currentReader(in: bindings.manager) != nil
            && (reader != nil || inspectorWitnessed)
        return .init(ready: mounted && foreground && isPresentationReady,
            historyRootAvailable: HistoryViewModel.shared.searchText.isEmpty,
            tableOfContentsAvailable: isRootAvailable(MaktabahNativeTOCComponents.destination), witnessedReader: reader,
            searchFieldAvailable: searchFieldAvailable,
            readyTableOfContents: mounted && foreground && isPresentationReady(for: MaktabahNativeTOCComponents.destination),
            readySefariaSurface: mounted && foreground && isPresentationReady(for: MaktabahNativeSefariaSurfaceBinding.destination),
            readySavedResults: mounted && foreground && isPresentationReady(for: MaktabahNativeSavedResultsBinding.destination),
            readyWorkspaceParents: Set(MaktabahNativeWorkspacePresentationBinding.Parent.allCases
                .filter { mounted && foreground && isPresentationReady(for: $0.destination) }.map(\.destination)),
            availableComponents: Dictionary(uniqueKeysWithValues: componentOwners.map { destination, owner in
                // A pushed Settings child is not the original Form. Do not
                // pretend setting its existing sheet flag can pop that stack.
                let presentable = destination != MaktabahNativeSettingsComponents.destination
                    || !bindings.showSettings.wrappedValue || owner.isMounted
                return (destination, Set(owner.descriptors.filter { presentable && owner.isAvailable($0.anchor) }.map(\.anchor)))
            }), inspectorAvailable: inspectorAvailable,
            witnessedInspectorVisible: inspectorWitnessed ? true : reader?.state.inspectorVisible)
    }
    /// Independent source identity for the explicit current-work consent offer;
    /// this does not relax the native route's surface or visibility receipt.
    func hanlinCurrentWorkReadSource() throws -> MaktabahNativeSceneProjection.HanlinCurrentWorkReadSource? {
        try project().hanlinCurrentWorkReadSource()
    }
    /// A freshness facet from the existing scene projection; no selected text or content grant.
    func hanlinSelectionRange() throws -> UIUTF16Range? { try project().identity(workspacePresentation: workspacePresentation, sefariaSurface: sefariaSurfaceBinding, savedResults: savedResultsBinding).selectedRange }
    func ownsInspectorReader(_ reader: ReaderViewModel) -> Bool {
        MaktabahNativeInspectorBinding.currentReader(in: bindings.manager) === reader
    }
    func observeVisibility(for destination: UIDestinationID, check: @escaping @MainActor () -> NativeSurfaceWitness.Evidence?) {
        visibilityChecks[destination] = check
    }

    /// Retain the exact mounted original Search BEFORE any asynchronous work.
    /// Source metadata never selects a window or submits a new query.
    func retainSearchContinuation(requestID: UUID,
        currentSnapshot: @escaping @MainActor () throws -> ActionBackendSnapshot) throws
        -> MaktabahNativeSearchContinuationOwner {
        try validateSearchPresentation()
        guard mounted, foreground, isPresentationReady, command == nil,
              searchContinuationOwner == nil, searchResultsBinding == nil,
              readerBinding == nil, readerTabBinding == nil, workspaceSelectionBinding == nil,
              let source = workspaceProjectionSource, let originalPresentation = searchPresentationOwner,
              bindings.selectedTab.wrappedValue == .search, bindings.manager.currentMode == .search else {
            throw UIRouteError(.unavailable, "native_search_continuation_scene_busy")
        }
        let window = try retainOriginalWindowObservation()
        let owner = try MaktabahNativeSearchContinuationOwner(requestID: requestID, sceneID: sceneID,
            bindings: bindings, workspaceSource: source, window: window,
            readForeign: { [weak self] in
                guard let self else { return }
                _ = self.mounted; _ = self.foreground; _ = self.studyChatPresentationID
                _ = self.workspacePresentation?.originalStateRevision
                // Notes uses original SwiftUI State, not Observation. Its exact
                // original setter retires this owner synchronously above.
            }, validateScene: { [weak self] in
                guard let self, self.mounted, self.foreground, self.isPresentationReady,
                      self.command == nil, self.searchResultsBinding == nil,
                      self.readerBinding == nil, self.readerTabBinding == nil, self.workspaceSelectionBinding == nil,
                      self.searchPresentationOwner == originalPresentation else {
                    throw UIRouteError(.staleState, "native_search_continuation_scene_changed")
                }
                try self.validateSearchPresentation()
            }, currentSnapshot: currentSnapshot)
        searchContinuationOwner = owner
        return owner
    }

    func validateSearchContinuationOwner(_ owner: MaktabahNativeSearchContinuationOwner) throws {
        guard searchContinuationOwner === owner, owner.sceneID == sceneID else {
            throw UIRouteError(.staleState, "native_search_continuation_scene_owner_replaced")
        }
        try owner.validate()
    }

    func releaseSearchContinuation(_ owner: MaktabahNativeSearchContinuationOwner) {
        guard searchContinuationOwner === owner else { return }
        owner.retire(); searchContinuationOwner = nil
    }

    /// Metadata queries neither select a scene nor prepare Core/source claims.
    /// A background window is eligible only while its SAME original Search
    /// and original attached list/window remain identifiable; execution still
    /// requires the unchanged foreground/geometry owner above.
    func publicSearchContinuationTargets(_ query: NativeSearchContinuationIntentService.Query,
        windowTitle: String, currentSnapshot: @escaping @MainActor () throws -> ActionBackendSnapshot)
        throws -> [NativeSearchContinuationIntentService.Target] {
        guard mounted, command == nil, searchResultsBinding == nil, searchContinuationOwner == nil,
              readerBinding == nil, readerTabBinding == nil, workspaceSelectionBinding == nil,
              isPresentationReady, !bindings.showSettings.wrappedValue,
              searchPresentationOwner != nil, searchPresentationBlocked?() != true,
              bindings.selectedTab.wrappedValue == .search, bindings.manager.currentMode == .search,
              MaktabahApp.isIpad || bindings.manager.selectedBook == nil else { return [] }
        if publicSearchContinuationCatalog == nil {
            publicSearchContinuationCatalog = .init(sceneID: sceneID, capture: { [weak self] in
                guard let self, mounted, let source = workspaceProjectionSource,
                      let originalPresentation = searchPresentationOwner,
                      let workspacePresentation,
                      let originalWorkspaceRevision = workspacePresentation.originalStateRevision else {
                    throw ActionPortError.unavailable
                }
                let window = try retainOriginalWindowObservation()
                return try MaktabahNativeSearchContinuationCatalog.captureOriginal(sceneID: sceneID,
                    readBindings: { [weak self] in
                        guard let self, mounted else { throw ActionPortError.staleState }
                        return bindings
                    }, workspaceSource: source, window: window, windowTitle: windowTitle,
                    readForeign: { [weak self] in
                        guard let self else { return }
                        _ = mounted; _ = studyChatPresentationID
                        _ = self.workspacePresentation?.originalStateRevision
                        // Exact original Search/Notes local-State setters retire
                        // the catalog synchronously. Foreground is not metadata.
                    }, validateScene: { [weak self, weak source, weak workspacePresentation] in
                        guard let self, let source, let workspacePresentation,
                              mounted, isPresentationReady, command == nil,
                              searchResultsBinding == nil, readerBinding == nil,
                              readerTabBinding == nil, workspaceSelectionBinding == nil,
                              workspaceProjectionSource === source,
                              self.workspacePresentation === workspacePresentation,
                              workspacePresentation.originalStateRevision == originalWorkspaceRevision,
                              searchPresentationOwner == originalPresentation,
                              searchPresentationBlocked?() != true,
                              MaktabahApp.isIpad || bindings.manager.selectedBook == nil else {
                            throw ActionPortError.staleState
                        }
                        if let owner = searchContinuationOwner,
                           publicSearchContinuationCatalog?.ownsSelection(requestID: owner.requestID) != true {
                            throw ActionPortError.staleState
                        }
                    }, currentSnapshot: currentSnapshot)
            })
        }
        guard let catalog = publicSearchContinuationCatalog else { throw ActionPortError.unavailable }
        do { return try catalog.targets(query) }
        catch ActionPortError.unavailable { return [] }
        catch ActionPortError.staleState { return [] }
    }

    func retainPublicSearchContinuation(_ request: NativeSearchContinuationIntentService.OpenRequest)
        throws -> MaktabahNativeSearchContinuationCatalog.Selection {
        guard mounted, searchContinuationOwner == nil, command == nil,
              let catalog = publicSearchContinuationCatalog else { throw ActionPortError.staleState }
        return try catalog.retain(request)
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
        let identity = try project().identity(workspacePresentation: workspacePresentation, sefariaSurface: sefariaSurfaceBinding, savedResults: savedResultsBinding)
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
        return names.isEmpty ? window : names + " — " + window
    }

    func prepare(_ route: PublicRouteSpec, invocation: ActionPortInvocation, scene: UISceneSnapshot) throws -> RouteSpec {
        guard route.destination != MaktabahNativeSefariaSurfaceBinding.destination,
              !usesOriginalPhoneTOC(route.destination), isRootAvailable(route.destination),
              route.content == nil, route.presentation == .currentTab else {
            throw UIRouteError(.notSupported, "public_native_variant_not_installed")
        }
        let identity = try project().identity(workspacePresentation: workspacePresentation, sefariaSurface: sefariaSurfaceBinding, savedResults: savedResultsBinding)
        return RouteSpec(requestId: invocation.requestId, destination: route.destination, backend: invocation.snapshot.backend,
            state: .init(workspaceID: identity.state.workspaceID, profileID: identity.state.profileID),
            scene: .init(kind: .specific, sceneID: sceneID, expectedRevision: scene.revision), expectedBackendSnapshot: invocation.snapshot)
    }

    func prepare(destination: UIDestinationID, invocation: ActionPortInvocation, scene: UISceneSnapshot) throws -> RouteSpec {
        guard destination != MaktabahNativeSefariaSurfaceBinding.destination else {
            throw UIRouteError(.unavailable, "native_sefaria_parent_binding_required")
        }
        guard !usesOriginalPhoneTOC(destination) else {
            throw UIRouteError(.unavailable, "native_phone_toc_parent_binding_required")
        }
        guard destination.rawValue == "native.settings"
            || (MaktabahNativeRootDestination(rawValue: destination.rawValue) != nil && isRootAvailable(destination)) else {
            throw UIRouteError(.notSupported, "native_surface_not_installed")
        }
        let identity = try project().identity(workspacePresentation: workspacePresentation, sefariaSurface: sefariaSurfaceBinding, savedResults: savedResultsBinding)
        return RouteSpec(requestId: invocation.requestId, destination: destination, backend: invocation.snapshot.backend,
            presentation: .init(kind: destination.rawValue == "native.settings" ? .sheet : .currentTab),
            state: .init(workspaceID: identity.state.workspaceID, profileID: identity.state.profileID),
            scene: .init(kind: .specific, sceneID: sceneID, expectedRevision: scene.revision), expectedBackendSnapshot: invocation.snapshot)
    }

    func observe(_ evidence: NativeSurfaceWitness.Evidence) {
        guard mounted, evidence.sceneID == sceneID else { return }
        if evidence.isVisible, evidence.surface.destination == MaktabahNativeSavedResultsBinding.destination {
            do {
                guard retainedSavedResults, let original = savedResultsBinding,
                      let requestID = evidence.submissionID, submissionID == requestID,
                      command?.invocation.requestId == requestID else {
                    throw UIRouteError(.staleState, "native_saved_results_report_not_owned")
                }
                try original.withValidatedSurface(requestID: requestID) {
                    guard isPresentationReady(for: evidence.surface.destination),
                          let actual = try surface(.savedResults), actual == evidence.surface else {
                        throw UIRouteError(.staleState, "native_saved_results_report_changed")
                    }
                    recordNativeObservation(evidence)
                }
            } catch {
                if visible.removeValue(forKey: evidence.surface.destination) != nil { try? nativeStateChanged() }
                presentation.revoke()
            }
            return
        }
        if evidence.isVisible, evidence.surface.destination == MaktabahNativeHistoryRecords.destination,
           evidence.surface.state.selectedItemID != nil, let requestID = evidence.submissionID {
            do {
                guard retainedHistoryRecord, let original = historyRecordBinding,
                      submissionID == requestID, command?.invocation.requestId == requestID else {
                    throw UIRouteError(.staleState, "native_history_record_report_not_owned")
                }
                // The actor's exact publication token remains locked across
                // final row/root revalidation and the original native report.
                try original.withValidatedRecord(requestID: requestID) {
                    guard let current = try surface(.history), current == evidence.surface else {
                        throw UIRouteError(.staleState, "native_history_record_report_changed")
                    }
                    recordNativeObservation(evidence)
                }
            } catch {
                if visible.removeValue(forKey: evidence.surface.destination) != nil { try? nativeStateChanged() }
                presentation.revoke()
            }
            return
        }
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
        if evidence.isVisible, evidence.surface.destination == MaktabahNativeWorkspaceSelectionBinding.destination {
            do {
                guard let bound = workspaceSelectionBinding, bound.isApplied,
                      evidence.submissionID == bound.requestID, submissionID == bound.requestID,
                      command?.invocation.requestId == bound.requestID,
                      isPresentationReady(for: evidence.surface.destination),
                      let current = try surface(bound.observedSurface), current == evidence.surface else {
                    throw UIRouteError(.staleState, "native_workspace_selection_report_changed")
                }
                if !bound.isEmpty {
                    guard try project().hasRenderedReaderEvidence(sceneID: sceneID, includingContainingSection: true) else {
                        throw UIRouteError(.staleState, "native_workspace_selection_reader_not_rendered")
                    }
                }
                try bound.validate()
                recordNativeObservation(evidence)
                guard workspaceSelectionBinding === bound else {
                    throw UIRouteError(.staleState, "native_workspace_selection_report_owner_changed")
                }
                try bound.validate()
            } catch {
                if visible.removeValue(forKey: evidence.surface.destination) != nil { try? nativeStateChanged() }
                presentation.revoke()
            }
            return
        }
        if evidence.isVisible, evidence.surface.destination == MaktabahNativeReaderTabBinding.destination {
            do {
                guard let bound = readerTabBinding, bound.isApplied,
                      evidence.submissionID == bound.requestID, submissionID == bound.requestID,
                      command?.invocation.requestId == bound.requestID,
                      isPresentationReady(for: evidence.surface.destination),
                      let current = try surface(.reader), current == evidence.surface,
                      try project().hasRenderedReaderEvidence(sceneID: sceneID, includingContainingSection: true) else {
                    throw UIRouteError(.staleState, "native_reader_tab_report_changed")
                }
                try bound.validate()
                recordNativeObservation(evidence)
                guard readerTabBinding === bound else { throw UIRouteError(.staleState, "native_reader_tab_report_owner_changed") }
                try bound.validate()
            } catch {
                if visible.removeValue(forKey: evidence.surface.destination) != nil { try? nativeStateChanged() }
                presentation.revoke()
            }
            return
        }
        if evidence.isVisible, evidence.surface.destination == MaktabahNativeSefariaSurfaceBinding.destination,
           let requestID = evidence.submissionID {
            do {
                guard let original = sefariaSurfaceBinding, submissionID == requestID,
                      command?.invocation.requestId == requestID else {
                    throw UIRouteError(.staleState, "native_sefaria_report_not_owned")
                }
                try original.withValidatedSurface(requestID: requestID) {
                    try validateParentSource(destination: evidence.surface.destination, requestID: requestID)
                    guard isSefariaOriginalRootReady, let current = try surface(.sefariaEmbedded),
                          current == evidence.surface else {
                        throw UIRouteError(.staleState, "native_sefaria_report_changed")
                    }
                    recordNativeObservation(evidence)
                }
            } catch {
                if visible.removeValue(forKey: evidence.surface.destination) != nil { try? nativeStateChanged() }
                presentation.revoke()
            }
            return
        }
        recordNativeObservation(evidence)
    }

    private func recordNativeObservation(_ evidence: NativeSurfaceWitness.Evidence) {
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
        if let command, let observed = visible[command.route.route.destination],
           observed.isVisible, observed.submissionID == requestID,
           observed.surface.observedRoute(for: command, backend: command.invocation.snapshot) == command.route.route {
            lastCompletedSurface = (command.route.route, observed)
        }
        let completed = lastCompletedSurface?.route.requestId == requestID
        retainedComponentOwner?.finish(requestID: requestID, completed: completed)
        workspacePresentation?.finish(requestID: requestID, completed: completed)
        phoneTOCPresentation?.finish(requestID: requestID, completed: completed)
        searchEntryBinding?.finish(requestID: requestID, completed: completed)
        historyRecordBinding?.finish(requestID: requestID, completed: completed && retainedHistoryRecord)
        savedResultsBinding?.finish(requestID: requestID, completed: completed && retainedSavedResults)
        if retainedSefariaSurface, completed, let root = sefariaRootSources[requestID],
           (try? root.validate(bindings, workspace: workspacePresentation)) != nil {
            completedSefariaRootSource = root
        }
        sefariaSurfaceBinding?.finish(requestID: requestID, completed: completedSefariaRootSource != nil)
        retainedComponentOwner = nil; retainedWorkspaceParent = nil; retainedPhoneTOC = false
        retainedSefariaSurface = false
        retainedHistoryRecord = false
        retainedSavedResults = false
        presentation.end(requestID: requestID); submissionID = nil
        // Keep only the independently observed surface. Clear private request
        // metadata after its owner has validated the complete visible receipt.
        command = nil; retainedSearchField = nil; inspectorBinding = nil
        readerTabParentObservation = nil
    }

    func validateCompletedJourneySurface(_ receipt: UISceneReceipt) throws {
        let projection = try project()
        guard mounted, foreground, isPresentationReady(for: receipt.route.destination), receipt.sceneID == sceneID,
              let completed = lastCompletedSurface, completed.route == receipt.route,
              completed.evidence.submissionID == receipt.requestId,
              let visible = visibilityChecks[receipt.route.destination]?(),
              visible.isVisible, visible.sceneID == sceneID,
              let kind = surfaceKind(receipt.route.destination), let actual = try surface(kind),
              actual == visible.surface, actual == completed.evidence.surface,
              kind != .reader || projection.hasRenderedReaderEvidence(sceneID: sceneID,
                includingContainingSection: receipt.route.destination == MaktabahNativeReaderTabBinding.destination
                    || receipt.route.destination == MaktabahNativeWorkspaceSelectionBinding.destination) else {
            throw ActionPortError.staleState
        }
    }

    func originalSefariaSurfaceAcceptanceEvidence(for receipt: UISceneReceipt) throws -> SefariaEmbeddedSurfaceAcceptanceEvidence {
        guard receipt.route.destination == MaktabahNativeSefariaSurfaceBinding.destination,
              let original = sefariaSurfaceBinding, let source = completedSefariaRootSource else {
            throw UIRouteError(.staleState, "native_sefaria_completed_source_missing")
        }
        try source.validate(bindings, workspace: workspacePresentation)
        try validateCompletedJourneySurface(receipt)
        let evidence = try original.acceptanceEvidence(for: receipt)
        try source.validate(bindings, workspace: workspacePresentation)
        return evidence
    }

    func unmount() {
        guard mounted else { return }
        lastCompletedSurface = nil
        searchContinuationOwner?.retire(); searchContinuationOwner = nil
        publicSearchContinuationCatalog?.unmount(); publicSearchContinuationCatalog = nil
        readerTabBinding?.release(); readerTabBinding = nil; readerTabParentObservation = nil
        viewerParentHost?.unmount(); viewerParentHost = nil
        workspaceSelectionBinding?.release(); workspaceSelectionBinding = nil
        forwardingWorkspaceOwner?.detachNativeRoutingSession(self); forwardingWorkspaceOwner = nil
        workspacePresentation?.retire(); workspacePresentation = nil; retainedWorkspaceParent = nil
        phoneTOCPresentation?.unmount(); phoneTOCPresentation = nil; retainedPhoneTOC = false
        searchEntryBinding?.unmount(); searchEntryBinding = nil
        historyRecordBinding?.unmount(); historyRecordBinding = nil; retainedHistoryRecord = false
        savedResultsBinding?.unmount(); savedResultsBinding = nil; retainedSavedResults = false
        sefariaRootSources.values.forEach { $0.invalidate() }; sefariaRootSources.removeAll()
        completedSefariaRootSource?.invalidate(); completedSefariaRootSource = nil
        sefariaSurfaceBinding?.unmount(); sefariaSurfaceBinding = nil; retainedSefariaSurface = false
        mounted = false; presentation.revoke(); submissionID = nil; command = nil; visible.removeAll(); visibilityChecks.removeAll()
        nativeSearchField = nil; retainedSearchField = nil; inspectorBinding = nil
        for owner in componentOwners.values { owner.retirePresentation() }
        componentOwners.removeAll(); retainedComponentOwner = nil; componentValidation = nil
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
        case "native.reader", "native.reader.tab": .reader
        case "native.workspace.selection": workspaceSelectionBinding?.observedSurface
        case "native.reader.inspector": .inspector
        case "native.reader.noteDraft": .noteDraft
        case "native.history": .history
        case "native.search": .search
        case "native.search.results": .searchResults
        case "native.annotations": .annotations
        case "native.settings": .settings
        case "native.workspace.profiles": .workspaceProfiles
        case "native.workspace.overview": .workspaceOverview
        case "native.sefariaEmbedded": .sefariaEmbedded
        case "native.savedResults": .savedResults
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
