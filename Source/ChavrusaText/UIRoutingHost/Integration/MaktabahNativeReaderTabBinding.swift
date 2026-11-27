#if os(iOS)
import Foundation
import SwiftUI
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

/// One original live tab, retained before foreground/permission awaits. The
/// original scene/manager/store/readers stay authoritative throughout. This
/// private selection route does not resolve a book or create another Reader.
@MainActor
final class MaktabahNativeReaderTabBinding {
    static let destination = NativeReaderTabIntentService.destination
    let requestID: UUID
    let target: NativeReaderTabIntentService.Tab
    private let bindings: MaktabahNativeSceneBindings
    private let source: MaktabahNativeWorkspaceProjectionSource
    private let workspace: StudyWorkspaceNavigationAdapter
    private let store: StudyWorkspaceStore
    private let originalNative: StudyWorkspaceMappingObservation
    private let originalStored: StudyWorkspaceMappingObservation
    private let tab: iOSNavigationManager.ReaderTab
    private let requestToken: ReaderContentRequestToken
    private let readerDestination: LibraryReaderDestination
    private let root: MaktabahNativeRootPublicationSource
    private let selectionRevision: UInt64
    private let settingsRevision: UInt64
    private let modeRevision: UInt64
    private let bookRevision: UInt64
    private let originalBook: BooksData?
    private let originalBookMode: AppMode?
    private let sourceObservation: MaktabahNativeComponentSourceObservation
    private let foreignReady: @MainActor () -> Bool
    private let changesTab: Bool
    let viewerParent: MaktabahNativeViewerParentContinuation?
    private var reservation: StudyWorkspaceNativeTabSelectionReservation?
    private var valid = true
    private(set) var isApplied = false

    static func catalog(sceneID: UIStableID, manager: iOSNavigationManager,
                        source: MaktabahNativeWorkspaceProjectionSource,
                        windowTitle: String) throws -> [NativeReaderTabIntentService.Tab] {
        guard source.isAuthoritative, let workspace = try source.read(),
              workspace.sceneID == sceneID.rawValue, workspace.attached, !workspace.isSwitching,
              workspace.errorMessage == nil, workspace.store.loadError == nil,
              !BackendCoordinator.shared.isTransitioning,
              let snapshot = workspace.store.snapshot, (try? snapshot.validate()) != nil,
              let selected = snapshot.scenes[sceneID.rawValue],
              let profile = snapshot.profiles.first(where: { $0.id == selected.profileID }),
              let group = snapshot.groups.first(where: { $0.id == selected.groupID && $0.profileID == profile.id }),
              let mapping = workspace.mappingOwnershipObservation(),
              mapping.owner == ObjectIdentifier(manager), mapping.coverage == .liveNativeSetters,
              mapping.projection.profileID == profile.id, mapping.projection.groupID == group.id else {
            throw UIRouteError(.unavailable, "native_reader_tab_source_unavailable")
        }
        let backend = BackendCoordinator.shared.activeBackendID
        guard Set(manager.openTabs.map(\.id)).count == manager.openTabs.count else {
            throw UIRouteError(.unavailable, "native_reader_tab_identity_ambiguous")
        }
        return manager.openTabs.compactMap { tab in
            guard let document = group.tabs.first(where: { $0.id == tab.id }),
                  document.backend == backend, document.session.bookId == tab.book.id,
                  manager.activeTabId != tab.id || MaktabahApp.isIpad
                    || (manager.selectedBook === tab.book && manager.selectedBookPresentationMode == .viewer),
                  let book = tab.book.backendLocator, book.backend == backend,
                  (document.session.backendLocator?.workKey ?? document.session.locator?.workKey) == book.workKey,
                  mapping.projection.targets[tab.id]?.readerOwner == ObjectIdentifier(tab.viewModel),
                  case .loaded = tab.viewModel.state,
                  let destination = tab.viewModel.currentDestination,
                  destination.sectionLocator.backend == backend, destination.sectionLocator.workKey == book.workKey,
                  tab.viewModel.contentLoadCoordinator.currentRequestToken() != nil,
                  !tab.viewModel.contentText.isEmpty else { return nil }
            return .init(sceneID: sceneID, profileID: profile.id, groupID: group.id, tabID: tab.id,
                backend: ActionAppIdentityBridge.actionBackend(backend), title: tab.book.title,
                profileTitle: profile.name, groupTitle: group.name, windowTitle: windowTitle)
        }
    }

    init(requestID: UUID, target: NativeReaderTabIntentService.Tab,
         bindings: MaktabahNativeSceneBindings, source: MaktabahNativeWorkspaceProjectionSource,
         viewerParentHost: MaktabahNativeViewerParentHost?,
         foreignReady: @escaping @MainActor () -> Bool,
         readForeignPresentations: @escaping @MainActor () -> Void) throws {
        let manager = bindings.manager
        guard source.isAuthoritative, let workspace = try source.read(),
              let native = workspace.mappingOwnershipObservation(),
              let stored = workspace.store.mappingObservation(scene: target.sceneID.rawValue),
              workspace.sceneID == target.sceneID.rawValue,
              native.owner == ObjectIdentifier(manager), stored.owner == ObjectIdentifier(workspace.store),
              native.projection.profileID == target.profileID, native.projection.groupID == target.groupID,
              native.coverage == .liveNativeSetters, stored.coverage == .workspaceStoreOnly,
              ActionAppIdentityBridge.actionBackend(BackendCoordinator.shared.activeBackendID) == target.backend,
              let root = bindings.rootPublications,
              let selectionRevision = root.selectionRevision, let settingsRevision = root.settingsRevision,
              let modeRevision = manager.nativeModePresentationRevision,
              let bookRevision = manager.selectedBookPresentationRevision,
              let tab = manager.openTabs.first(where: { $0.id == target.tabID }),
              let destination = tab.viewModel.currentDestination,
              let requestToken = tab.viewModel.contentLoadCoordinator.currentRequestToken() else {
            throw UIRouteError(.unavailable, "native_reader_tab_source_unavailable")
        }
        self.requestID = requestID; self.target = target; self.bindings = bindings; self.source = source
        self.workspace = workspace; store = workspace.store; originalNative = native; originalStored = stored
        self.tab = tab; self.requestToken = requestToken; readerDestination = destination
        self.root = root; self.selectionRevision = selectionRevision; self.settingsRevision = settingsRevision
        self.modeRevision = modeRevision; self.bookRevision = bookRevision
        originalBook = manager.selectedBook; originalBookMode = manager.selectedBookPresentationMode
        changesTab = manager.activeTabId != target.tabID
        self.foreignReady = foreignReady
        let retainedParent: MaktabahNativeViewerParentContinuation?
        if bindings.selectedTab.wrappedValue == .viewer, manager.currentMode == .viewer {
            retainedParent = nil
        } else {
            guard let viewerParentHost else {
                throw UIRouteError(.unavailable, "native_viewer_parent_unavailable")
            }
            retainedParent = try viewerParentHost.retain(requestID: requestID, tabID: target.tabID, bindings: bindings)
        }
        viewerParent = retainedParent
        // Native/store mapping events have a separate exact source-owned
        // reservation below. Do not install a mirror epoch or rearm this latch
        // after an owned selection. All other original source changes revoke it.
        let outgoingReader = manager.openTabs.first(where: { $0.id == manager.activeTabId })?.viewModel
        sourceObservation = MaktabahNativeComponentSourceObservation {
            _ = try? source.read()
            _ = workspace.attached; _ = workspace.isSwitching; _ = workspace.errorMessage
            _ = workspace.store.loadError
            _ = root.settingsRevision
            if retainedParent == nil {
                _ = root.selectionRevision
                _ = manager.currentMode; _ = manager.nativeModePresentationRevision
            }
            // The foreign-parent request owns exactly its one original root
            // publication and original onChange mode call. Its source-owned
            // proof replaces ONLY these two unchanged-root observations.

            _ = tab.viewModel.state
            _ = tab.viewModel.currentBook; _ = tab.viewModel.currentDestination
            _ = tab.viewModel.backendSection; _ = tab.viewModel.contentText
            _ = tab.viewModel.contentLoadCoordinator.currentRequestToken()
            _ = manager.selectedBookForInfo; _ = manager.showingTabsList
            _ = outgoingReader?.isPopoverPresented; _ = tab.viewModel.isPopoverPresented
            _ = DonationManager.shared.showDonationSheet; _ = bindings.sidebar?.overview.blocksRouting
            readForeignPresentations()
        }
        do { try validate() } catch { retainedParent?.release(); throw error }
    }

    var isReserved: Bool { reservation != nil }
    func invalidate() { valid = false; viewerParent?.invalidate() }

    func validate() throws {
        try sourceObservation.validate()
        let manager = bindings.manager
        if let viewerParent { try viewerParent.validateRoot() }
        else {
            guard root.selectionRevision == selectionRevision,
                  manager.nativeModePresentationRevision == modeRevision,
                  bindings.selectedTab.wrappedValue == .viewer, manager.currentMode == .viewer else {
                throw UIRouteError(.staleState, "native_reader_tab_source_changed")
            }
        }
        guard valid, try source.read() === workspace, workspace.store === store,
              workspace.sceneID == target.sceneID.rawValue, workspace.attached, !workspace.isSwitching,
              workspace.errorMessage == nil, store.loadError == nil, foreignReady(),
              bindings.rootPublications === root,
              root.settingsRevision == settingsRevision,
              !bindings.showSettings.wrappedValue,
              changesTab || MaktabahApp.isIpad
                || (manager.selectedBook === tab.book && manager.selectedBookPresentationMode == .viewer),
              ActionAppIdentityBridge.actionBackend(BackendCoordinator.shared.activeBackendID) == target.backend,
              tab.book.backendLocator?.backend.rawValue == target.backend.rawValue,
              tab.book.backendLocator?.workKey == readerDestination.sectionLocator.workKey,
              tab.viewModel.currentDestination == readerDestination,
              tab.viewModel.contentLoadCoordinator.currentRequestToken() == requestToken,
              !tab.viewModel.contentText.isEmpty else {
            throw UIRouteError(.staleState, "native_reader_tab_source_changed")
        }
        guard case .loaded = tab.viewModel.state else {
            throw UIRouteError(.unavailable, "native_reader_tab_not_loaded")
        }
        let matches = manager.openTabs.filter { $0.id == target.tabID }
        guard matches.count == 1, let actual = matches.first,
              actual.book === tab.book, actual.viewModel === tab.viewModel else {
            throw UIRouteError(.staleState, "native_reader_tab_owner_changed")
        }
        let expectedBookRevision: UInt64
        if isApplied && changesTab {
            guard bookRevision < .max else { throw UIRouteError(.staleState, "native_reader_tab_revision_exhausted") }
            expectedBookRevision = bookRevision + 1
        } else { expectedBookRevision = bookRevision }
        let expectedBook = isApplied && changesTab ? tab.book : originalBook
        let expectedBookMode = isApplied && changesTab ? AppMode.viewer : originalBookMode
        guard manager.selectedBookPresentationRevision == expectedBookRevision,
              manager.selectedBook === expectedBook, manager.selectedBookPresentationMode == expectedBookMode else {
            throw UIRouteError(.staleState, "native_reader_tab_presentation_changed")
        }
        if let reservation {
            try workspace.validateNativeTabSelection(reservation)
            guard reservation.tab.book === tab.book, reservation.tab.viewModel === tab.viewModel,
                  reservation.policy.requestID == requestID,
                  isApplied == (reservation.policy.phase == .committed) else {
                throw UIRouteError(.staleState, "native_reader_tab_reservation_changed")
            }
        } else {
            guard !isApplied, let native = workspace.mappingOwnershipObservation(),
                  let stored = store.mappingObservation(scene: target.sceneID.rawValue),
                  native.source === originalNative.source, native.epoch == originalNative.epoch,
                  native.owner == originalNative.owner, native.projection == originalNative.projection,
                  stored.source === originalStored.source, stored.epoch == originalStored.epoch,
                  stored.owner == originalStored.owner, stored.projection == originalStored.projection else {
                throw UIRouteError(.staleState, "native_reader_tab_mapping_changed")
            }
        }
    }

    /// No grant exists yet. The original producer retires prior contracts,
    /// retaining these SAME objects under exactly the next owner epoch.
    func reserve() throws {
        try validate()
        guard reservation == nil, !isApplied, originalNative.epoch.revision < .max,
              !changesTab || bookRevision < .max else {
            throw UIRouteError(.staleState, "native_reader_tab_reservation_changed")
        }
        let value = try workspace.reserveNativeTabSelection(requestID: requestID, tabID: target.tabID,
                                                          manager: bindings.manager)
        reservation = value
        guard value.tab.book === tab.book, value.tab.viewModel === tab.viewModel,
              value.policy.original == originalNative.projection,
              value.policy.source === originalNative.source,
              value.policy.epoch.sourceID == originalNative.epoch.sourceID,
              value.policy.epoch.revision == originalNative.epoch.revision + 1,
              value.policy.workspaceSource === originalStored.source,
              value.policy.workspaceEpoch == originalStored.epoch else {
            invalidate(); throw UIRouteError(.staleState, "native_reader_tab_reservation_changed")
        }
        try validate()
    }

    func apply() throws {
        try validate()
        guard let reservation, !isApplied else {
            throw UIRouteError(.staleState, "native_reader_tab_already_applied")
        }
        try viewerParent?.validateOriginalSelectionEntry()
        // The canonical orchestrator has just consumed Core's one preparation.
        // This invokes the ORIGINAL action and its actual source-owned setters.
        try workspace.applyNativeTabSelection(reservation) { bindings.manager.selectTab(id: tab.id) }
        isApplied = true
        try viewerParent?.selectionDidApply()
        try validate()
    }

    func selectionSurface(from original: NativeSurfaceState) throws -> NativeSurfaceState? {
        try validate()
        guard isApplied, original.destination.rawValue == "native.reader",
              original.presentation.kind == .currentTab,
              original.presentation.tabID?.rawValue == target.tabID.uuidString,
              original.state.workspaceID?.rawValue == target.groupID.uuidString,
              original.state.profileID?.rawValue == target.profileID.uuidString,
              original.content?.sectionLocator.backend == target.backend,
              original.content?.sectionLocator.workKey == readerDestination.sectionLocator.workKey,
              original.focus == nil else { return nil }
        // A projection of the ACTUAL original Reader, not an acknowledgement.
        // The existing independent native marker and TextKit viewport remain
        // mandatory in Session and after the canonical receipt returns.
        return .init(destination: Self.destination, presentation: original.presentation, content: nil,
            state: .init(workspaceID: original.state.workspaceID, profileID: original.state.profileID), focus: nil)
    }

    func release() {
        viewerParent?.release()
        guard valid || reservation != nil else { return }
        valid = false
        if let reservation { workspace.releaseNativeTabSelection(reservation) }
        reservation = nil
    }
}
#endif
