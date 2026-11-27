import Foundation
@MainActor final class MaktabahNativeSceneSession {
    private(set) var mounted = true
    let originalAnnotationPresentationPublication = NativeComponentSourcePublication()
    private var annotationPresentationOwner: UUID?
    private var annotationPresentationBlocked: (@MainActor () -> Bool)?
    private var annotationPresentationPublicationRevision: UInt64? = 0
    private var annotationSelectionBinding: CallbackOwner? = CallbackOwner()
    private var retainedAnnotationSelection = false
    private var searchPresentationOwner: UUID?
    private var searchPresentationBlocked: (@MainActor () -> Bool)?
    // Candidate declaration matches the source; baseline never reads this
    // fixture-only seed slot because its actual caller has no new helper.
    private var searchPresentationPublicationRevision: UInt64? = 0
    private let bindings = Bindings()
    private let sceneID = UIStableID(rawValue: "scene")
    private var workspaceProjectionSource: WorkspaceSource?
    private var windowSource: AnyObject?
    private let originalWindow = OriginalWindow()
    private var onWindowRetain: (() -> Void)?
    private let directory = Directory()
    private var searchContinuationOwner: CallbackOwner? = CallbackOwner()
    private var publicSearchContinuationCatalog: CallbackOwner? = CallbackOwner()
    private var searchEntryBinding: CallbackOwner? = CallbackOwner()
    private var historyRecordBinding: CallbackOwner? = CallbackOwner()
    private var savedResultsBinding: CallbackOwner? = CallbackOwner()
    private var readerTabBinding: CallbackOwner?
    private var readerTabParentObservation: Int?
    private var viewerParentHost: CallbackOwner?
    private var workspaceSelectionBinding: CallbackOwner?
    private var forwardingWorkspaceOwner: CallbackOwner?
    private var workspacePresentation: CallbackOwner?
    private var retainedWorkspaceParent: Int?
    private var phoneTOCPresentation: CallbackOwner?
    private var retainedPhoneTOC = false
    private var retainedHistoryRecord = false
    private var retainedSavedResults = false
    private var sefariaRootSources: [UUID: CallbackOwner] = [:]
    private var completedSefariaRootSource: CallbackOwner?
    private var sefariaSurfaceBinding: CallbackOwner?
    private var retainedSefariaSurface = false
    private var lastCompletedSurface: Int?
    private let presentation = CallbackOwner()
    private var submissionID: Int?; private var command: Int?
    private var visible: [Int] = []; private var visibilityChecks: [Int] = []
    private var nativeSearchField: Int?; private var retainedSearchField: Int?; private var inspectorBinding: Int?
    private var componentOwners: [Int: CallbackOwner] = [:]; private var retainedComponentOwner: Int?
    private var componentValidation: Int?; private var noteEditorOwner: Int?; private var noteDraftBinding: Int?
    private var searchResultsBinding: Int?; private var lease: Int?

    init() { workspaceProjectionSource = WorkspaceSource(bindings.manager) }
    private func retainOriginalWindowObservation() throws -> OriginalWindow { onWindowRetain?(); return originalWindow }
    func fixtureSeedRevision(_ value: UInt64?) { annotationPresentationPublicationRevision = value }
    var fixtureRevision: UInt64? { annotationPresentationPublicationRevision }
    var fixtureOwner: UUID? { annotationPresentationOwner }
    func fixtureOnRetire(_ body: @escaping () -> Void) { annotationSelectionBinding?.onCall = { _ in body() } }
    func fixtureOnEntry(_ body: @escaping (String) -> Void) { annotationSelectionBinding?.onCall = body }
    func fixtureOnFirstUnmount(_ body: @escaping () -> Void) { searchContinuationOwner?.onCall = { _ in body() } }
    func fixtureOnCatalog(_ body: @escaping (String) -> Void) { publicSearchContinuationCatalog?.onCall = body }
    func fixtureOnHistory(_ body: @escaping (String) -> Void) { historyRecordBinding?.onCall = body }
    func fixtureOnWindowRetain(_ body: (() -> Void)?) { onWindowRetain = body }
    func fixtureOnWindowValidate(_ body: (() -> Void)?) { originalWindow.onValidate = body }
    func fixtureOnReadiness(_ body: (() -> Void)?) { bindings.onReady = body }


    func observeSearchPresentation(owner: UUID, isBlocked: @escaping @MainActor () -> Bool) {
        guard mounted else { return }
        if searchPresentationOwner != owner {
            advanceOriginalSearchPresentationPublication()
            searchContinuationOwner?.retire(); publicSearchContinuationCatalog?.retire()
        }
        searchEntryBinding?.observeOriginalPresentation(owner: owner)
        searchPresentationOwner = owner; searchPresentationBlocked = isBlocked
    }

    func originalSearchPresentationWillChange(owner: UUID) {
        if searchPresentationOwner == owner { advanceOriginalSearchPresentationPublication() }
        searchEntryBinding?.originalPresentationWillChange(owner: owner)
        if searchPresentationOwner == owner {
            searchContinuationOwner?.retire()
            publicSearchContinuationCatalog?.retire()
            historyRecordBinding?.originalForeignStateWillChange()
        }
    }

    func removeSearchPresentation(owner: UUID) {
        guard searchPresentationOwner == owner else { return }
        advanceOriginalSearchPresentationPublication()
        searchContinuationOwner?.retire()
        publicSearchContinuationCatalog?.retire()
        searchEntryBinding?.originalPresentationDidDisappear(owner: owner)
        // A hidden Search tab can retain its opaque FTS overlay state. Keep
        // that original blocker until the actual owner clears/replaces it;
        // reopening Search semantically must not submit behind a restored mask.
        guard searchPresentationBlocked?() != true else { return }
        searchPresentationOwner = nil; searchPresentationBlocked = nil
    }

    func captureHistoryReaderWindow() throws -> @MainActor () throws -> Void {
        let searchPresentation = try retainHistorySearchPresentationObservation()
        let annotationPresentation = try retainOriginalAnnotationPresentationObservation()
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
            try searchPresentation()
            try annotationPresentation()
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
            try searchPresentation()
            try annotationPresentation()
        }
        try validate()
        return validate
    }

    func unmount() {
        guard mounted else { return }
        advanceOriginalAnnotationPresentationPublication()
        advanceOriginalSearchPresentationPublication()
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
        annotationSelectionBinding?.unmount(); annotationSelectionBinding = nil; retainedAnnotationSelection = false
        sefariaRootSources.values.forEach { $0.invalidate() }; sefariaRootSources.removeAll()
        completedSefariaRootSource?.invalidate(); completedSefariaRootSource = nil
        sefariaSurfaceBinding?.unmount(); sefariaSurfaceBinding = nil; retainedSefariaSurface = false
        mounted = false; presentation.revoke(); submissionID = nil; command = nil; visible.removeAll(); visibilityChecks.removeAll()
        nativeSearchField = nil; retainedSearchField = nil; inspectorBinding = nil
        for owner in componentOwners.values { owner.retirePresentation() }
        componentOwners.removeAll(); retainedComponentOwner = nil; componentValidation = nil
        noteEditorOwner = nil; noteDraftBinding = nil
        windowSource = nil; searchPresentationOwner = nil; searchPresentationBlocked = nil
        annotationPresentationOwner = nil; annotationPresentationBlocked = nil
        searchResultsBinding = nil
        if let lease { directory.unmount(lease) }
        lease = nil
    }

    private func advanceOriginalSearchPresentationPublication() {
        // This original foreign State publication cannot rearm an annotation source.
        defer { annotationSelectionBinding?.retire() }
        guard let revision = searchPresentationPublicationRevision, revision < .max else {
            searchPresentationPublicationRevision = nil
            return
        }
        searchPresentationPublicationRevision = revision + 1
    }

    private func retainHistorySearchPresentationObservation() throws -> @MainActor () throws -> Void {
        guard mounted, let revision = searchPresentationPublicationRevision else {
            throw UIRouteError(.unavailable, "history_reader_search_presentation_unavailable")
        }
        let owner = searchPresentationOwner
        let validate: @MainActor () throws -> Void = { [weak self] in
            guard let self, self.mounted,
                  self.searchPresentationPublicationRevision == revision,
                  self.searchPresentationOwner == owner,
                  self.searchPresentationBlocked?() != true else {
                throw UIRouteError(.staleState, "history_reader_search_presentation_changed")
            }
            // The original blocker is a callback. It cannot publish a new
            // owner/state and then return a value that rearms this observation.
            guard self.searchPresentationPublicationRevision == revision,
                  self.searchPresentationOwner == owner else {
                throw UIRouteError(.staleState, "history_reader_search_presentation_changed")
            }
        }
        try validate()
        return validate
    }
    /// The original list's existing modal State owner, not a second UI model.
    /// Equal modal writes and owner A-B-A all invalidate retained sources.
    func observeAnnotationPresentation(owner: UUID, isBlocked: @escaping @MainActor () -> Bool) {
        guard mounted else { return }
        if annotationPresentationOwner != owner {
            advanceOriginalAnnotationPresentationPublication()
            annotationPresentationOwner = owner; annotationPresentationBlocked = isBlocked
            annotationSelectionBinding?.retire()
        } else { annotationPresentationBlocked = isBlocked }
    }
    func originalAnnotationPresentationWillChange(owner: UUID) {
        guard mounted, annotationPresentationOwner == owner else { return }
        advanceOriginalAnnotationPresentationPublication()
        annotationSelectionBinding?.originalModalWillChange(owner: owner)
    }
    func removeAnnotationPresentation(owner: UUID) {
        guard annotationPresentationOwner == owner else { return }
        advanceOriginalAnnotationPresentationPublication()
        let revision = annotationPresentationPublicationRevision
        annotationSelectionBinding?.retire()
        // The original list can be covered by its own editor/import/export
        // presentation. Preserve its blocker until that actual owner clears it.
        guard annotationPresentationBlocked?() != true,
              annotationPresentationOwner == owner,
              annotationPresentationPublicationRevision == revision else { return }
        annotationPresentationOwner = nil; annotationPresentationBlocked = nil
    }
    private func advanceOriginalAnnotationPresentationPublication() {
        // Fixed weak one-way latches only. No user/State callback runs under a
        // source lock; RN claims can be refused before the original setter.
        originalAnnotationPresentationPublication.invalidateRetainedSources()
        guard let revision = annotationPresentationPublicationRevision, revision < .max else {
            annotationPresentationPublicationRevision = nil
            return
        }
        annotationPresentationPublicationRevision = revision + 1
    }
    private var hasOriginalAnnotationPresentation: Bool {
        guard let revision = annotationPresentationPublicationRevision else { return true }
        let owner = annotationPresentationOwner
        let blocked = annotationPresentationBlocked?() == true
        return blocked || annotationPresentationPublicationRevision != revision || annotationPresentationOwner != owner
    }
    /// Retain before foreground activation. The caller must register the fixed
    /// originalAnnotationPresentationPublication BEFORE this first getter if it
    /// needs a synchronous off-MainActor claim (RN); this closure is no grant.
    func retainOriginalAnnotationPresentationObservation() throws -> @MainActor () throws -> Void {
        guard mounted, let revision = annotationPresentationPublicationRevision else {
            throw UIRouteError(.unavailable, "original_annotation_presentation_unavailable")
        }
        let owner = annotationPresentationOwner
        let validate: @MainActor () throws -> Void = { [weak self] in
            guard let self, self.mounted,
                  self.annotationPresentationPublicationRevision == revision,
                  self.annotationPresentationOwner == owner,
                  self.annotationPresentationBlocked?() != true else {
                throw UIRouteError(.staleState, "original_annotation_presentation_changed")
            }
            // The original blocker is a getter callback. It may publish a new
            // owner/state; final equality alone cannot restore that source.
            guard self.annotationPresentationPublicationRevision == revision,
                  self.annotationPresentationOwner == owner else {
                throw UIRouteError(.staleState, "original_annotation_presentation_changed")
            }
        }
        try validate()
        return validate
    }

}
