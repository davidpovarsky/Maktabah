#if os(iOS)
import Foundation
import SwiftUI
import UIKit
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

/// Retains only the ORIGINAL scene, parent, window, workspace and search owner.
/// This metadata object grants no operation and owns no query or result array.
/// Core and the original source token must both authorize the actual binding.
@MainActor
final class MaktabahNativeSearchContinuationOwner {
    typealias Check = @MainActor () throws -> Void
    let requestID: UUID
    let sceneID: UIStableID
    let binding: MaktabahNativeSearchContinuationBinding
    private let validateOriginal: Check
    private var valid = true

    init(requestID: UUID, sceneID: UIStableID, bindings: MaktabahNativeSceneBindings,
         workspaceSource: MaktabahNativeWorkspaceProjectionSource,
         window: MaktabahNativeWindowObservation,
         readForeign: @MainActor () -> Void,
         validateScene: @escaping Check,
         currentSnapshot: @escaping @MainActor () throws -> ActionBackendSnapshot) throws {
        let manager = bindings.manager
        let session = manager.unifiedSearchSession
        let model = manager.searchViewModel
        let parent = try MaktabahNativeSearchEntryParentTransition(bindings: bindings)
        guard parent.tab == .search, parent.mode == .search,
              workspaceSource.isAuthoritative, let workspace = try workspaceSource.read(),
              workspace.attached, !workspace.isSwitching, workspace.sceneID == sceneID.rawValue,
              let mapping = workspace.mappingOwnershipObservation(),
              mapping.owner == ObjectIdentifier(manager), mapping.scene == sceneID.rawValue,
              mapping.coverage == .liveNativeSetters,
              mapping.source.event.phase == .available, mapping.source.event.epoch == mapping.epoch,
              session.searchViewModel === model, bindings.isPresentationReady,
              !bindings.showSettings.wrappedValue else {
            throw UIRouteError(.unavailable, "native_search_continuation_owner_unavailable")
        }
        _ = try window.validate()
        try validateScene()
        let reader = manager.activeTabId.flatMap { id in manager.openTabs.first { $0.id == id }?.viewModel }
        let foreign = MaktabahNativeComponentSourceObservation {
            _ = try? workspaceSource.read(); _ = workspace.attached; _ = workspace.isSwitching
            _ = workspace.mappingOwnershipSource.event
            _ = manager.openTabs; _ = manager.activeTabId; _ = manager.selectedContentId
            _ = manager.unifiedSearchSession; _ = manager.searchViewModel
            _ = manager.currentMode; _ = manager.selectedBook; _ = manager.selectedBookPresentationMode
            _ = manager.selectedBookForInfo; _ = manager.showingTabsList; _ = manager.alertMessage
            _ = DonationManager.shared.showDonationSheet
            _ = reader?.currentBook; _ = reader?.currentDestination; _ = reader?.currentContentId
            _ = reader?.isPopoverPresented; _ = reader?.readerInspectorVisible
            // Owned paging/result publication stays with the original model.
            // The original binding separately observes every query input.
            readForeign()
        }
        self.requestID = requestID; self.sceneID = sceneID
        binding = MaktabahNativeSearchContinuationBinding(sceneID: sceneID.rawValue, session: session,
            currentSnapshot: currentSnapshot, originalWindow: { try window.validate() })
        validateOriginal = { [weak manager, weak session, weak model, weak workspace] in
            try foreign.validate(); _ = try window.validate(); try validateScene()
            guard let manager, let session, let model, let workspace,
                  workspaceSource.isAuthoritative, try workspaceSource.read() === workspace,
                  workspace.attached, !workspace.isSwitching, workspace.sceneID == sceneID.rawValue,
                  let live = workspace.mappingOwnershipObservation(),
                  live.source === mapping.source, live.owner == mapping.owner, live.scene == mapping.scene,
                  live.epoch == mapping.epoch, live.projection == mapping.projection,
                  live.coverage == .liveNativeSetters,
                  live.source.event.phase == .available, live.source.event.epoch == live.epoch,
                  bindings.manager === manager, manager.unifiedSearchSession === session,
                  manager.searchViewModel === model, session.searchViewModel === model,
                  bindings.selectedTab.wrappedValue == .search, manager.currentMode == .search,
                  !bindings.showSettings.wrappedValue, bindings.isPresentationReady else {
                throw UIRouteError(.staleState, "native_search_continuation_owner_changed")
            }
            try parent.validateBefore(bindings)
            try foreign.validate(); _ = try window.validate()
        }
        try validate()
    }

    func validate() throws {
        guard valid else { throw UIRouteError(.staleState, "native_search_continuation_owner_retired") }
        try validateOriginal()
        guard valid else { throw UIRouteError(.staleState, "native_search_continuation_owner_retired") }
    }

    func retire() {
        valid = false
        // Retire this binding's private metadata, never a replacement query or
        // another source owner's token. Its in-flight operation keeps its own
        // actual effects and exact-attempt cleanup through the original defer.
        binding.retire()
    }
}
#endif
