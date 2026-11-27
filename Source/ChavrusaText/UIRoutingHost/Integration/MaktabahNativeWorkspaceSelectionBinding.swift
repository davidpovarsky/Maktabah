#if os(iOS)
import Foundation
import SwiftUI
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

/// A captured ORIGINAL group stage, not a second workspace or a Boolean
/// adapter around async switching. All async resolution precedes Core; the
/// complete original Store/native terminal runs only in canonical apply.
@MainActor
final class MaktabahNativeWorkspaceSelectionBinding {
    static let destination = NativeWorkspaceSelectionIntentService.destination
    let requestID: UUID
    let target: NativeWorkspaceSelectionIntentService.Selection
    private let bindings: MaktabahNativeSceneBindings
    private let source: MaktabahNativeWorkspaceProjectionSource
    private let workspace: StudyWorkspaceNavigationAdapter
    private let store: StudyWorkspaceStore
    private let originalNative: StudyWorkspaceMappingObservation
    private let originalStored: StudyWorkspaceMappingObservation
    private let prepared: StudyWorkspacePreparedGroupSelection
    private let backendObservation: StudyWorkspaceGroupBackendObservation
    private let root: MaktabahNativeRootPublicationSource
    private let selectionRevision: UInt64
    private let settingsRevision: UInt64
    private let modeRevision: UInt64
    private let bookRevision: UInt64
    private let overviewRevision: UInt64
    private let originalBook: BooksData?
    private let originalBookMode: AppMode?
    private let foreignObservation: NativeComponentSourceObservation
    private let foreignReady: @MainActor () -> Bool
    let viewerParent: MaktabahNativeViewerParentContinuation?
    private var stagedForeignObservation: NativeComponentSourceObservation?
    private var reservation: StudyWorkspaceNativeGroupSelectionReservation?
    private var canonicalLifetime: (@MainActor () throws -> Void)?
    private var valid = true
    private var applying = false
    private(set) var isApplied = false

    static func catalog(sceneID: UIStableID, manager: iOSNavigationManager,
                        source: MaktabahNativeWorkspaceProjectionSource,
                        windowTitle: String) throws -> [NativeWorkspaceSelectionIntentService.Selection] {
        guard source.isAuthoritative, let workspace = try source.read(),
              workspace.sceneID == sceneID.rawValue, workspace.attached, !workspace.isSwitching,
              workspace.errorMessage == nil, workspace.store.loadError == nil,
              !BackendCoordinator.shared.isTransitioning,
              BackendCoordinator.shared.pendingBackendID == nil,
              BackendCoordinator.shared.committedBackendID == BackendCoordinator.shared.activeBackendID,
              let snapshot = workspace.store.snapshot, (try? snapshot.validate()) != nil,
              let selection = snapshot.scenes[sceneID.rawValue],
              let native = workspace.mappingOwnershipObservation(),
              native.owner == ObjectIdentifier(manager), native.coverage == .liveNativeSetters else { return [] }
        var result: [NativeWorkspaceSelectionIntentService.Selection] = []
        func append(_ kind: NativeWorkspaceSelectionIntentService.Kind, profile: StudyProfile, group: StudyTabGroup) {
            guard let stage = try? workspace.captureNativeGroupSelection(profileID: profile.id, groupID: group.id,
                        selectsProfile: kind == .profile, manager: manager),
                  stage.snapshot == snapshot, canStageOriginalDocuments(stage) else { return }
            let selected = stage.documents.first(where: { $0.id == stage.requested }) ?? stage.documents.first
            // Original selectTab is a no-op for the already active tab. Do not
            // advertise that it pushes a hidden compact Reader as a side effect.
            if !MaktabahApp.isIpad, let selected, manager.activeTabId == selected.id {
                guard let tab = manager.openTabs.first(where: { $0.id == selected.id }),
                      manager.selectedBook === tab.book, manager.selectedBookPresentationMode == .viewer else { return }
            }
            result.append(.init(kind: kind, sceneID: sceneID,
                backend: ActionAppIdentityBridge.actionBackend(stage.desiredBackend),
                profileID: profile.id, groupID: group.id, activeDocumentID: selected?.id,
                title: kind == .profile ? profile.name : group.name,
                profileTitle: profile.name, groupTitle: group.name, windowTitle: windowTitle))
        }
        for profile in snapshot.profiles.sorted(by: { $0.order < $1.order }) {
            if let first = workspace.firstGroup(in: profile.id) { append(.profile, profile: profile, group: first) }
            if profile.id == selection.profileID {
                for group in snapshot.groups.filter({ $0.profileID == profile.id }).sorted(by: { $0.order < $1.order }) {
                    append(.group, profile: profile, group: group)
                }
            }
        }
        guard workspace.store.snapshot == snapshot,
              workspace.mappingOwnershipObservation()?.epoch == native.epoch else {
            throw UIRouteError(.staleState, "native_workspace_selection_catalog_changed")
        }
        return result
    }

    /// Read-only feasibility from the ORIGINAL saved documents/cache. Actual
    /// catalog resolution still happens once inside the original async stage.
    private static func canStageOriginalDocuments(_ stage: StudyWorkspacePreparedGroupSelection) -> Bool {
        stage.documents.allSatisfy { document in
            let work = document.session.backendLocator?.workKey ?? document.session.locator?.workKey
            guard document.backend == stage.desiredBackend, let work, !work.isEmpty else { return false }
            let existing = (stage.retained + stage.previousTabs).first {
                $0.id == document.id && $0.book.id == document.session.bookId
                    && $0.book.backendLocator?.backend == document.backend && $0.book.backendLocator?.workKey == work
            }
            if let existing, !existing.viewModel.contentText.isEmpty {
                guard case .loaded = existing.viewModel.state,
                      existing.viewModel.currentBook === existing.book,
                      let token = existing.viewModel.contentLoadCoordinator.currentRequestToken(),
                      token.backend == document.backend, token.workKey == work,
                      token.sectionLocator == existing.viewModel.currentDestination?.sectionLocator else { return false }
                return true
            }
            guard let locator = document.session.locator,
                  locator.backend == document.backend, locator.workKey == work else { return false }
            // Cached cold Readers with no extant token have an unknown private
            // generation; newly hydrated original Readers start at generation 1.
            return existing == nil || existing?.viewModel.contentLoadCoordinator.currentRequestToken().map { $0.generation < .max } == true
        }
    }

    init(requestID: UUID, target: NativeWorkspaceSelectionIntentService.Selection,
         bindings: MaktabahNativeSceneBindings, source: MaktabahNativeWorkspaceProjectionSource,
         viewerParentHost: MaktabahNativeViewerParentHost? = nil,
         foreignReady: @escaping @MainActor () -> Bool,
         readForeignPresentations: @escaping @MainActor () -> Void) throws {
        let manager = bindings.manager
        let backendObservation = StudyWorkspaceGroupBackendObservation()
        guard source.isAuthoritative, let workspace = try source.read(), workspace.sceneID == target.sceneID.rawValue,
              let native = workspace.mappingOwnershipObservation(),
              let stored = workspace.store.mappingObservation(scene: target.sceneID.rawValue),
              native.owner == ObjectIdentifier(manager), stored.owner == ObjectIdentifier(workspace.store),
              native.coverage == .liveNativeSetters, stored.coverage == .workspaceStoreOnly,
              let root = bindings.rootPublications,
              let selectionRevision = root.selectionRevision, let settingsRevision = root.settingsRevision,
              let modeRevision = manager.nativeModePresentationRevision,
              let bookRevision = manager.selectedBookPresentationRevision,
              let overviewRevision = workspace.nativeOverviewPublicationRevision else {
            backendObservation.retire()
            throw UIRouteError(.unavailable, "native_workspace_selection_source_unavailable")
        }
        let stage = try workspace.captureNativeGroupSelection(profileID: target.profileID, groupID: target.groupID,
            selectsProfile: target.kind == .profile, manager: manager)
        guard Self.canStageOriginalDocuments(stage), target.backend == ActionAppIdentityBridge.actionBackend(stage.desiredBackend),
              target.activeDocumentID == (stage.documents.first(where: { $0.id == stage.requested }) ?? stage.documents.first)?.id else {
            backendObservation.retire()
            throw UIRouteError(.staleState, "native_workspace_selection_target_changed")
        }
        self.requestID = requestID; self.target = target; self.bindings = bindings; self.source = source
        self.workspace = workspace; store = workspace.store; originalNative = native; originalStored = stored
        prepared = stage; self.backendObservation = backendObservation; self.root = root
        self.selectionRevision = selectionRevision; self.settingsRevision = settingsRevision; self.modeRevision = modeRevision
        self.bookRevision = bookRevision; self.overviewRevision = overviewRevision
        originalBook = manager.selectedBook; originalBookMode = manager.selectedBookPresentationMode
        self.foreignReady = foreignReady
        let retainedParent: MaktabahNativeViewerParentContinuation?
        if bindings.selectedTab.wrappedValue == .viewer, manager.currentMode == .viewer {
            retainedParent = nil
        } else {
            guard let viewerParentHost else {
                backendObservation.retire()
                throw UIRouteError(.unavailable, "native_viewer_parent_unavailable")
            }
            do {
                retainedParent = try viewerParentHost.retainWorkspaceSelection(requestID: requestID,
                    profileID: target.profileID, groupID: target.groupID,
                    activeDocumentID: target.activeDocumentID, bindings: bindings)
            } catch { backendObservation.retire(); throw error }
        }
        viewerParent = retainedParent
        // Do not observe owned Store/native/isSwitching mutations through a
        // generic latch. Their original setters have exact one-use permissions.
        // Warm original Reader source fields and all unrelated UI remain one-shot.
        let originalReaders = (stage.retained + stage.previousTabs).map(\.viewModel)
        let warmReaders = originalReaders.filter { !$0.contentText.isEmpty }
        foreignObservation = NativeComponentSourceObservation {
            _ = try? source.read()
            _ = workspace.attached; _ = workspace.errorMessage; _ = workspace.store.loadError
            _ = root.settingsRevision
            if retainedParent == nil {
                _ = root.selectionRevision
                _ = manager.currentMode; _ = manager.nativeModePresentationRevision
            }
            // The exact original parent owns only its one root publication
            // and original onChange mode call. Its source proof replaces
            // these two observations, without rearming any other observer.
            _ = manager.selectedBookForInfo; _ = DonationManager.shared.showDonationSheet
            _ = bindings.sidebar?.overview.blocksRouting
            for reader in originalReaders { _ = reader.isPopoverPresented }
            for reader in warmReaders {
                _ = reader.state; _ = reader.currentBook; _ = reader.currentDestination
                _ = reader.backendSection; _ = reader.contentText
                _ = reader.contentLoadCoordinator.currentRequestToken()
            }
            readForeignPresentations()
        }
        do { try validate() }
        catch { retainedParent?.release(); backendObservation.retire(); throw error }
    }

    var isReserved: Bool { reservation != nil }
    var isPrepared: Bool { reservation?.policy.phase == .prepared }
    var isEmpty: Bool { target.activeDocumentID == nil }
    var observedSurface: MaktabahNativeSceneProjection.Surface {
        isEmpty ? (MaktabahApp.isIpad ? .emptyReader : .library) : .reader
    }
    func invalidate() { valid = false; viewerParent?.invalidate() }

    func validate() throws {
        try Task.checkCancellation()
        try foreignObservation.validate()
        try stagedForeignObservation?.validate()
        try backendObservation.validate()
        let manager = bindings.manager
        if let viewerParent {
            try viewerParent.validateRoot()
            if applying || isApplied { try viewerParent.validateWorkspaceSelectionSource() }
        } else {
            guard root.selectionRevision == selectionRevision,
                  manager.nativeModePresentationRevision == modeRevision,
                  bindings.selectedTab.wrappedValue == .viewer, manager.currentMode == .viewer else {
                throw UIRouteError(.staleState, "native_workspace_selection_source_changed")
            }
        }
        guard valid, source.isAuthoritative, try source.read() === workspace, workspace.store === store,
              workspace.sceneID == target.sceneID.rawValue, workspace.attached,
              workspace.errorMessage == nil, store.loadError == nil, foreignReady(),
              bindings.rootPublications === root,
              root.settingsRevision == settingsRevision,
              !bindings.showSettings.wrappedValue,
              ActionAppIdentityBridge.actionBackend(BackendCoordinator.shared.activeBackendID) == target.backend else {
            throw UIRouteError(.staleState, "native_workspace_selection_source_changed")
        }
        if let reservation {
            guard reservation.prepared === prepared, reservation.backendObservation === backendObservation,
                  reservation.policy.requestID == requestID,
                  reservation.policy.groupID == target.groupID, reservation.policy.profileID == target.profileID,
                  !isApplied || reservation.policy.phase == .committed else {
                throw UIRouteError(.staleState, "native_workspace_selection_reservation_changed")
            }
            try workspace.validateNativeGroupSelection(reservation)
        } else {
            guard !isApplied, !workspace.isSwitching, store.snapshot == prepared.snapshot,
                  manager.selectedBookPresentationRevision == bookRevision,
                  workspace.nativeOverviewPublicationRevision == overviewRevision,
                  manager.selectedBook === originalBook, manager.selectedBookPresentationMode == originalBookMode,
                  let native = workspace.mappingOwnershipObservation(), let stored = store.mappingObservation(scene: target.sceneID.rawValue),
                  native.source === originalNative.source, native.epoch == originalNative.epoch,
                  native.owner == originalNative.owner, native.projection == originalNative.projection,
                  stored.source === originalStored.source, stored.epoch == originalStored.epoch,
                  stored.owner == originalStored.owner, stored.projection == originalStored.projection else {
                throw UIRouteError(.staleState, "native_workspace_selection_mapping_changed")
            }
        }
    }

    func reserve() throws {
        try validate()
        guard reservation == nil, originalNative.epoch.revision < .max else {
            throw UIRouteError(.staleState, "native_workspace_selection_already_reserved")
        }
        let retained = try workspace.reserveNativeGroupSelection(requestID: requestID,
            profileID: target.profileID, groupID: target.groupID, selectsProfile: target.kind == .profile,
            manager: bindings.manager, backendObservation: backendObservation, prepared: prepared)
        reservation = retained
        guard retained.policy.source === originalNative.source,
              retained.policy.epoch.sourceID == originalNative.epoch.sourceID,
              retained.policy.epoch.revision == originalNative.epoch.revision + 1,
              retained.policy.workspaceSource === originalStored.source,
              retained.policy.workspaceEpoch == originalStored.epoch else {
            invalidate(); throw UIRouteError(.staleState, "native_workspace_selection_reservation_changed")
        }
        try validate()
    }

    /// Caller supplies the same original request's bounded pre-admission
    /// lifetime. This stages only original Readers, and performs no UI effect.
    func prepare(validateLifetime: @escaping @MainActor () throws -> Void) async throws {
        try validateLifetime(); try validate()
        guard let reservation, stagedForeignObservation == nil, !isApplied, !applying else {
            throw UIRouteError(.staleState, "native_workspace_selection_not_reserved")
        }
        try await workspace.prepareNativeGroupSelection(reservation) { [weak self] in
            try validateLifetime()
            guard let self, self.reservation === reservation else {
                throw UIRouteError(.staleState, "native_workspace_selection_owner_changed")
            }
            try self.validate()
        }
        try validateLifetime(); try validate()
        guard isPrepared, reservation.selectedTab?.id == target.activeDocumentID else {
            throw UIRouteError(.staleState, "native_workspace_selection_prepared_target_changed")
        }
        // Newly hydrated ORIGINAL Readers did not exist before preparation.
        // Add one immutable observation of their foreign modal/book owner;
        // never replace or rearm either earlier source observation.
        let stagedReaders = prepared.staged.map(\.viewModel)
        stagedForeignObservation = NativeComponentSourceObservation {
            for reader in stagedReaders { _ = reader.isPopoverPresented; _ = reader.currentBook }
        }
        try validate()
    }

    func begin(validateLifetime: @escaping @MainActor () throws -> Void) throws {
        try validate()
        guard isPrepared, canonicalLifetime == nil, !isApplied else {
            throw UIRouteError(.staleState, "native_workspace_selection_already_begun")
        }
        try validateLifetime()
        try validate()
        canonicalLifetime = validateLifetime
    }

    /// The driver can offer the staged path only for THIS actual original
    /// preparation. In particular a nil wire tab is not an empty-group proof.
    func originalParentSelectionKind() throws -> UIOriginalParentSelectionKind? {
        try validate()
        guard viewerParent != nil else { return nil }
        guard isPrepared, !isApplied, let reservation,
              reservation.prepared === prepared,
              reservation.selectedTab?.id == target.activeDocumentID,
              let profileID = UIStableID(rawValue: target.profileID.uuidString),
              let groupID = UIStableID(rawValue: target.groupID.uuidString) else {
            throw UIRouteError(.staleState, "native_workspace_selection_prepared_target_changed")
        }
        if target.activeDocumentID == nil {
            guard prepared.staged.isEmpty, prepared.documents.isEmpty, reservation.selectedTab == nil else {
                throw UIRouteError(.staleState, "native_workspace_selection_empty_target_changed")
            }
        } else {
            guard !prepared.staged.isEmpty, !prepared.documents.isEmpty else {
                throw UIRouteError(.staleState, "native_workspace_selection_prepared_target_changed")
            }
        }
        return .workspaceSelection(profileID: profileID, workspaceID: groupID,
            activeTabID: target.activeDocumentID.flatMap { UIStableID(rawValue: $0.uuidString) })
    }

    func apply() throws {
        try validate()
        guard let reservation, let canonicalLifetime, isPrepared, !isApplied, !applying else {
            throw UIRouteError(.staleState, "native_workspace_selection_not_prepared")
        }
        try viewerParent?.validateOriginalSelectionEntry()
        try viewerParent?.validateWorkspaceSelectionSource()
        try canonicalLifetime()
        applying = true
        defer { applying = false }
        // Only the orchestrator's synchronous, already-authorized apply enters
        // here. The validator below grants nothing and cannot invoke this again.
        try workspace.applyNativeGroupSelection(reservation) { [weak self] in
            try canonicalLifetime()
            guard let self, self.applying, self.reservation === reservation else {
                throw UIRouteError(.staleState, "native_workspace_selection_owner_changed")
            }
            try self.validate()
        }
        isApplied = true
        try viewerParent?.selectionDidApply()
        try canonicalLifetime(); try validate()
    }

    func selectionSurface(from original: NativeSurfaceState) throws -> NativeSurfaceState? {
        try validate()
        guard isApplied, let reservation,
              original.presentation.kind == .currentTab,
              original.state.workspaceID?.rawValue == target.groupID.uuidString,
              original.state.profileID?.rawValue == target.profileID.uuidString, original.focus == nil else { return nil }
        if let selected = reservation.selectedTab {
            guard original.destination.rawValue == "native.reader",
                  original.presentation.tabID?.rawValue == selected.id.uuidString,
                  selected.id == target.activeDocumentID,
                  original.content?.sectionLocator.backend == target.backend,
                  original.content?.sectionLocator.workKey == selected.book.backendLocator?.workKey,
                  case .loaded = selected.viewModel.state, !selected.viewModel.contentText.isEmpty else { return nil }
        } else {
            guard isEmpty, original.destination.rawValue == (MaktabahApp.isIpad ? "native.reader.empty" : "native.library"),
                  original.presentation.tabID == nil, original.content == nil,
                  bindings.manager.openTabs.isEmpty, bindings.manager.activeTabId == nil,
                  bindings.manager.selectedBook == nil else { return nil }
        }
        // This projects observed ORIGINAL UI only. The independent actual
        // marker and TextKit (nonempty target) remain required by Session.
        return .init(destination: Self.destination,
            presentation: .init(kind: .currentTab, tabID: target.activeDocumentID.flatMap { UIStableID(rawValue: $0.uuidString) }),
            content: nil,
            state: .init(workspaceID: original.state.workspaceID, profileID: original.state.profileID), focus: nil)
    }

    func release() {
        valid = false; canonicalLifetime = nil
        viewerParent?.release()
        if let reservation { workspace.releaseNativeGroupSelection(reservation) }
        else { backendObservation.retire() }
        reservation = nil
    }
}
#endif
