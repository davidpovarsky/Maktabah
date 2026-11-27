import Foundation
import OtzariaUIRouting
import ChavrusaUIRoutingHost
@MainActor final class MaktabahNativeSceneSession {
    var mounted = true
    var annotationEditorControls: MaktabahNativeAnnotationEditorControls?
    let originalAnnotationPresentationPublication = NativeComponentSourcePublication()
    private var annotationPresentationOwner: UUID?
    private var annotationPresentationBlocked: (@MainActor () -> Bool)?
    private var annotationPresentationPublicationRevision: UInt64? = 0
    private var annotationSelectionBinding: EditorSceneCallback? = .init()
    private var searchPresentationOwner: UUID?
    private var searchPresentationPublicationRevision: UInt64? = 0
    private var searchPresentationBlocked: (@MainActor () -> Bool)?
    private var searchEntryBinding: EditorSceneCallback? = .init()
    private var publicSearchContinuationCatalog: EditorSceneCallback? = .init()
    private var historyRecordBinding: EditorSceneCallback? = .init()
    private var searchContinuationOwner: EditorSceneCallback?
    private var readerBinding: Int?; private var readerTabBinding: Int?
    private var workspaceSelectionBinding: Int?; private var searchResultsBinding: Int?
    private var workspacePresentation: EditorForeignPresentation? = .init()
    private var sefariaSurfaceBinding: EditorForeignPresentation? = .init()
    private var savedResultsBinding: EditorForeignPresentation? = .init()
    private var hasOriginalWorkspacePresentation = false
    private var hasOriginalSefariaSurface = false
    private var studyChatPresentationID: UUID?
    private var noteEditorOwner: EditorSceneNote?
    let bindings = EditorSceneBindings()
    private let sceneID = UIStableID(rawValue: "editor-scene")!
    private var workspaceProjectionSource: EditorSceneWorkspaceSource?
    let originalWindow = EditorSceneWindow()
    var onWindowRetain: (() -> Void)?
    init() { workspaceProjectionSource = EditorSceneWorkspaceSource(bindings.manager) }
    private func retainOriginalWindowObservation() throws -> EditorSceneWindow { onWindowRetain?(); return originalWindow }
    func fixtureCaptureEditor(_ owner: UUID) throws -> @MainActor () throws -> Void { try captureAnnotationEditorWindow(owner: owner) }
    func fixtureRevision(_ revision: UInt64?) { annotationPresentationPublicationRevision=revision }
    var fixtureCurrentRevision: UInt64? { annotationPresentationPublicationRevision }
    func fixtureEntryCallback(_ body: @escaping () -> Void) { annotationSelectionBinding?.onCall=body }
    func fixtureWorkspaceABA() { workspacePresentation?.originalStateRevision = 1; workspacePresentation?.originalStateRevision = 2 }


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
        defer { annotationEditorControls?.retire() }
        guard let revision = annotationPresentationPublicationRevision, revision < .max else {
            annotationPresentationPublicationRevision = nil
            return
        }
        annotationPresentationPublicationRevision = revision + 1
    }

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

    private func retainOriginalAnnotationEditorPresentationObservation(owner: UUID) throws
        -> @MainActor () throws -> Void {
        guard mounted, let revision = annotationPresentationPublicationRevision,
              annotationPresentationOwner == owner, let original = annotationEditorControls,
              original.originalListOwner == owner else {
            throw UIRouteError(.unavailable, "original_annotation_editor_parent_unavailable")
        }
        let validate: @MainActor () throws -> Void = { [weak self, weak original] in
            guard let self, let original, self.mounted,
                  self.annotationEditorControls === original,
                  self.annotationPresentationPublicationRevision == revision,
                  self.annotationPresentationOwner == owner,
                  original.originalListOwner == owner,
                  self.annotationPresentationBlocked?() == true,
                  original.isAvailable() else {
                throw UIRouteError(.staleState, "original_annotation_editor_parent_changed")
            }
            // Both getters above may synchronously publish/detach an owner.
            guard self.mounted, self.annotationEditorControls === original,
                  self.annotationPresentationPublicationRevision == revision,
                  self.annotationPresentationOwner == owner,
                  original.originalListOwner == owner else {
                throw UIRouteError(.staleState, "original_annotation_editor_parent_changed")
            }
        }
        try validate()
        return validate
    }

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

    private func advanceOriginalSearchPresentationPublication() {
        // This original foreign State publication cannot rearm an annotation source.
        defer { annotationSelectionBinding?.retire(); annotationEditorControls?.retire() }
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

    private var isOriginalAnnotationEditorRootReady: Bool {
        mounted && readerBinding == nil && readerTabBinding == nil && workspaceSelectionBinding == nil
            && searchResultsBinding == nil && searchContinuationOwner == nil
            && bindings.selectedTab.wrappedValue.canonical == .annotations
            && bindings.manager.currentMode == .annotations
            && bindings.isPresentationReady && !bindings.showSettings.wrappedValue
            && !hasOriginalWorkspacePresentation && !hasOriginalSefariaSurface
            && savedResultsBinding?.isRequestedOrMounted != true
            && studyChatPresentationID == nil && searchPresentationBlocked?() != true
            && noteEditorOwner?.current == nil && noteEditorOwner?.presentationActive != true
    }

    func captureHistoryReaderWindow() throws -> @MainActor () throws -> Void {
        try captureHistoryReaderWindow(annotationEditorOwner: nil)
    }

    private func captureHistoryReaderWindow(annotationEditorOwner: UUID?) throws -> @MainActor () throws -> Void {
        let searchPresentation = try retainHistorySearchPresentationObservation()
        let annotationPresentation: @MainActor () throws -> Void
        if let annotationEditorOwner {
            annotationPresentation = try retainOriginalAnnotationEditorPresentationObservation(owner: annotationEditorOwner)
        } else { annotationPresentation = try retainOriginalAnnotationPresentationObservation() }
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

    private func captureAnnotationEditorWindow(owner: UUID) throws -> @MainActor () throws -> Void {
        guard isOriginalAnnotationEditorRootReady, let original = annotationEditorControls,
              original.originalListOwner == owner else {
            throw UIRouteError(.unavailable, "original_annotation_editor_root_unavailable")
        }
        let observation = MaktabahNativeComponentSourceObservation {
            _ = mounted; _ = studyChatPresentationID
            _ = workspacePresentation?.originalStateRevision
            _ = sefariaSurfaceBinding?.presentationFacets
            _ = savedResultsBinding?.isRequestedOrMounted
        }
        let originalRoot = try captureHistoryReaderWindow(annotationEditorOwner: owner)
        let validate: @MainActor () throws -> Void = { [weak self, weak original] in
            try observation.validate(); try originalRoot()
            guard let self, let original, self.annotationEditorControls === original,
                  original.originalListOwner == owner, self.isOriginalAnnotationEditorRootReady else {
                throw UIRouteError(.staleState, "original_annotation_editor_root_changed")
            }
            try originalRoot(); try observation.validate()
        }
        try validate()
        return validate
    }
}
