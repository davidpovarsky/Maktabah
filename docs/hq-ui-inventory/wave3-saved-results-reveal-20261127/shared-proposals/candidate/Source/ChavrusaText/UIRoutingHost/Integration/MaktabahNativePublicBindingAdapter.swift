import Foundation
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

/// Independently read presentation fields, separate from R's ownership epoch.
/// A missing current-reader witness is unavailable, not inspector=false.
struct MaktabahNativePublicPresentation {
    let ready: Bool
    let historyRootAvailable: Bool
    let tableOfContentsAvailable: Bool
    let witnessedReader: NativeSurfaceState?
    var searchFieldAvailable: Bool = false
    var readyTableOfContents: Bool = false
    var readySefariaSurface: Bool = false
    var readySavedResults: Bool = false
    var readyWorkspaceParents: Set<UIDestinationID> = []
    var availableComponents: [UIDestinationID: Set<UIDestinationID>] = [:]
    var inspectorAvailable: Bool = false
    /// From the independently witnessed original Reader or Inspector; nil is unknown.
    var witnessedInspectorVisible: Bool? = nil

    func ready(for destination: UIDestinationID) -> Bool {
        switch destination.rawValue {
        case "native.reader.toc": return readyTableOfContents
        case "native.sefariaEmbedded": return readySefariaSurface
        case "native.savedResults": return readySavedResults
        case "native.workspace.profiles", "native.workspace.overview":
            return readyWorkspaceParents.contains(destination)
        default: return ready
        }
    }

    func componentAvailable(_ anchor: UIDestinationID, in destination: UIDestinationID) -> Bool {
        if destination.rawValue == "native.search", anchor.rawValue == "native.search.query" { return searchFieldAvailable }
        return availableComponents[destination]?.contains(anchor) == true
    }
}

/// App-target adapter over immutable R44 producer APIs. Not an executor, cache,
/// permission authority or public registration. Composition opts in separately.
@MainActor final class MaktabahNativePublicBindingAdapter: UIPublicNavigationBindingPort, MaktabahNativeWorkspaceOwnerObserver {
    let sceneID: UIStableID
    private weak var manager: iOSNavigationManager?
    private weak var workspace: StudyWorkspaceNavigationAdapter?
    private weak var workspaceOwner: MaktabahNativeWorkspaceOwner?
    private var ownerObservation: UUID?
    private let owner: ObjectIdentifier
    private let source: StudyWorkspaceMappingSource
    private let sourceID: UUID?
    private let authority: NativeNavigationAuthority
    private let lease: NativeNavigationAuthority.Lease
    private let directory: NativeSceneDirectory
    private let backend: any ActionSynchronousBackendStatePort
    private let presentation: @MainActor () throws -> MaktabahNativePublicPresentation
    private let validateParentSource: @MainActor (UIDestinationID, UUID) throws -> Void
    private let validateComponentSource: @MainActor (UIDestinationID, UIDestinationID, UUID) throws -> Void
    private let invalidated: @MainActor () -> Void
    private var subscription: StudyWorkspaceMappingSubscription?
    private var retired = false

    init(sceneID: UIStableID, manager: iOSNavigationManager, workspace: StudyWorkspaceNavigationAdapter,
         workspaceOwner: MaktabahNativeWorkspaceOwner,
         authority: NativeNavigationAuthority, lease: NativeNavigationAuthority.Lease,
         directory: NativeSceneDirectory, backend: any ActionSynchronousBackendStatePort,
         presentation: @escaping @MainActor () throws -> MaktabahNativePublicPresentation,
         validateParentSource: @escaping @MainActor (UIDestinationID, UUID) throws -> Void = { destination, _ in
             guard MaktabahNativeWorkspacePresentationBinding.Parent(rawValue: destination.rawValue) == nil,
                   destination != MaktabahNativeSefariaSurfaceBinding.destination,
                   destination != MaktabahNativeSavedResultsBinding.destination,
                   MaktabahApp.isIpad || destination != MaktabahNativeTOCComponents.destination else {
                 throw UIRouteError(.unavailable, "native_parent_source_missing")
             }
         },
         validateComponentSource: @escaping @MainActor (UIDestinationID, UIDestinationID, UUID) throws -> Void = { destination, anchor, _ in
             guard destination.rawValue == "native.search", anchor.rawValue == "native.search.query" else {
                 throw UIRouteError(.unavailable, "native_component_source_missing")
             }
         },
         invalidated: @escaping @MainActor () -> Void) throws {
        guard lease.sceneID == sceneID, workspaceOwner.current === workspace else { throw UIRouteError(.staleState, "public_binding_wrong_lease_or_owner") }
        self.sceneID = sceneID; self.manager = manager; self.workspace = workspace
        self.workspaceOwner = workspaceOwner
        owner = ObjectIdentifier(manager); source = workspace.mappingOwnershipSource
        sourceID = workspace.mappingOwnershipObservation()?.epoch.sourceID
        self.authority = authority; self.lease = lease; self.directory = directory; self.backend = backend
        self.presentation = presentation; self.validateParentSource = validateParentSource
        self.validateComponentSource = validateComponentSource
        self.invalidated = invalidated
        ownerObservation = try workspaceOwner.observe(self)
        subscription = source.subscribeInvalidation(owner: self) { adapter, _ in adapter.revokeOriginalLease() }
    }

    /// Only this fixed authority lease is revoked. No remount/re-admit/retry.
    private func revokeOriginalLease() {
        do { try authority.invalidate(lease) }
        catch { authority.unmount(lease) }
        invalidated()
    }
    func cancel() {
        guard !retired else { return }
        retired = true; subscription?.cancel(); subscription = nil
        if let ownerObservation { workspaceOwner?.cancelObservation(ownerObservation) }
        ownerObservation = nil
        revokeOriginalLease()
    }
    func ownsSource(_ workspace: StudyWorkspaceNavigationAdapter) -> Bool { !retired && self.workspace === workspace }
    func workspaceOwnerWillChange() { cancel() }
    isolated deinit {
        subscription?.cancel()
        if let ownerObservation { workspaceOwner?.cancelObservation(ownerObservation) }
    }

    private func mapping() throws -> StudyWorkspaceMappingObservation {
        guard !retired, let manager, let workspace, workspaceOwner?.current === workspace, ObjectIdentifier(manager) == owner,
              let actual = workspace.mappingOwnershipObservation(), actual.source === source,
              actual.owner == owner, actual.scene == sceneID.rawValue, actual.coverage == .liveNativeSetters,
              let sourceID, actual.epoch.sourceID == sourceID else {
            throw UIRouteError(.unavailable, "public_native_mapping_unavailable")
        }
        return actual
    }
    private func liveAuthority() throws -> ActionNavigationState {
        let live = try authority.navigationState(sceneID: sceneID.rawValue)
        guard live.active, live.lifetimeID == lease.lifetimeID else { throw UIRouteError(.staleState, "public_binding_lifetime_changed") }
        return live
    }
    private enum Shape { case library, tableOfContents, history, search, annotations, settings, reader, inspector, workspaceProfiles, workspaceOverview, sefariaEmbedded, savedResults }
    private func shape(destination: UIDestinationID, presentation: PublicNavigationSpecV2.Presentation,
                       component: UIDestinationID?, hasContent: Bool) throws -> Shape {
        if let component {
            let search = destination.rawValue == "native.search" && presentation == .currentTab
                && (component.rawValue == "native.search.query" || component == MaktabahNativeSearchEntryBinding.anchor)
            let settings = destination == MaktabahNativeSettingsComponents.destination && presentation == .sheet
                && MaktabahNativeSettingsComponents.descriptors.contains { $0.anchor == component }
            let library = destination == MaktabahNativeLibraryComponents.destination && presentation == .currentTab
                && MaktabahNativeLibraryComponents.descriptors.contains { $0.anchor == component }
            let tableOfContents = destination == MaktabahNativeTOCComponents.destination && presentation == .currentTab
                && MaktabahNativeTOCComponents.descriptors.contains { $0.anchor == component }
            let profiles = destination == MaktabahNativeWorkspacePresentationBinding.Parent.profiles.destination
                && presentation == .sheet && MaktabahNativeWorkspaceComponents.Profiles.allCases.contains { $0.id == component }
            let overview = destination == MaktabahNativeWorkspacePresentationBinding.Parent.overview.destination
                && presentation == .sheet && MaktabahNativeWorkspaceComponents.Overview.allCases.contains { $0.id == component }
            guard !hasContent, search || settings || library || tableOfContents || profiles || overview else {
                throw UIRouteError(.notSupported, "public_component_not_installed")
            }
        }
        switch (destination.rawValue, presentation, hasContent) {
        case ("native.library", .currentTab, false): return .library
        case ("native.reader.toc", .currentTab, false): return .tableOfContents
        case ("native.history", .currentTab, false): return .history
        case ("native.search", .currentTab, false):
            guard MaktabahNativeRootDestination.search.isAvailable else { throw UIRouteError(.notSupported, "native_search_unavailable") }
            return .search
        case ("native.annotations", .currentTab, false): return .annotations
        case ("native.settings", .sheet, false): return .settings
        case ("native.workspace.profiles", .sheet, false): return .workspaceProfiles
        case ("native.workspace.overview", .sheet, false): return .workspaceOverview
        case ("native.sefariaEmbedded", .sheet, false): return .sefariaEmbedded
        case ("native.savedResults", .sheet, false): return .savedResults
        case ("native.reader.inspector", .inspector, false): return .inspector
        case ("native.reader", .currentTab, true), ("native.reader", .newTab, true): return .reader
        default: throw UIRouteError(.notSupported, "public_binding_variant_not_installed")
        }
    }

    func observePublicNavigationBinding(_ intent: PublicNavigationSpecV2, requestId: UUID,
                                       sceneID: UIStableID) throws -> UIPublicNavigationLocalBinding {
        guard sceneID == self.sceneID else { throw UIRouteError(.staleState, "public_binding_wrong_scene") }
        let shape = try shape(destination: intent.destination, presentation: intent.presentation,
                              component: intent.component, hasContent: intent.content != nil)
        let initial = try mapping(), snapshot = try backend.currentBackendSnapshot(), admitted = try liveAuthority()
        guard BackendCoordinator.shared.activeBackendID.rawValue == snapshot.backend.rawValue else { throw ActionPortError.staleState }
        guard intent.backend.map({ $0 == snapshot.backend }) ?? true else { throw ActionPortError.staleState }
        let visible = try presentation()
        guard visible.ready(for: intent.destination) else { throw UIRouteError(.unavailable, "native_presentation_in_progress") }
        try validateParentSource(intent.destination, requestId)
        if let component = intent.component {
            guard visible.componentAvailable(component, in: intent.destination) else {
                throw UIRouteError(.unavailable, intent.destination.rawValue == "native.search"
                    ? "native_search_field_not_visible" : "native_component_unavailable")
            }
            try validateComponentSource(intent.destination, component, requestId)
        }
        let tab: UIPublicNavigationObservedID
        let inspector: Bool?
        switch shape {
        case .history:
            guard visible.historyRootAvailable else { throw UIRouteError(.unavailable, "history_root_unavailable") }
            tab = .absent; inspector = nil
        case .tableOfContents:
            guard visible.tableOfContentsAvailable else { throw UIRouteError(.unavailable, "native_toc_unavailable") }
            tab = .absent; inspector = nil
        case .library, .settings, .search, .annotations, .workspaceProfiles, .workspaceOverview, .sefariaEmbedded, .savedResults:
            tab = .absent; inspector = nil
        case .inspector:
            guard visible.inspectorAvailable, let actualInspectorVisible = visible.witnessedInspectorVisible,
                  let selected = initial.projection.activeTabID, let target = initial.projection.targets[selected],
                  target.readerOwner != nil, target.backend.rawValue == snapshot.backend.rawValue else {
                throw UIRouteError(.unavailable, "native_inspector_reader_unavailable")
            }
            // The URL requests visibility, while this field observes the original
            // native surface. Completion must see true through the same witness;
            // a constant nil would reject every successfully presented Inspector.
            // Its Reader remains privately bound by the original mapping epoch.
            tab = .absent; inspector = actualInspectorVisible
        case .reader:
            guard let wanted = intent.content else { throw ActionPortError.notSupported }
            _ = try MaktabahNativeReaderBinding.appDestination(wanted)
            if intent.presentation == .newTab {
                guard wanted.presentationMode == .newTab, let workspace,
                      let reservation = try? workspace.reservedNativeReader(requestID: requestId),
                      reservation.policy.source === source, reservation.policy.owner == owner,
                      reservation.policy.scene == sceneID.rawValue,
                      reservation.policy.epoch == initial.epoch,
                      reservation.policy.target.target.backend.rawValue == snapshot.backend.rawValue,
                      reservation.policy.target.target.backend.rawValue == wanted.sectionLocator.backend.rawValue,
                      reservation.policy.target.target.workKey == wanted.sectionLocator.workKey,
                      let stable = UIStableID(rawValue: reservation.tab.id.uuidString) else {
                    throw UIRouteError(.unavailable, "new_reader_binding_unavailable")
                }
                let actualInspector = reservation.tab.viewModel.readerInspectorVisible
                if reservation.policy.phase == .committed {
                    guard let witnessed = visible.witnessedReader, witnessed.destination == intent.destination,
                          witnessed.presentation.kind == .newTab, witnessed.presentation.tabID == stable,
                          witnessed.content == wanted, witnessed.focus == nil,
                          witnessed.state.inspectorVisible == actualInspector,
                          witnessed.state.workspaceID?.rawValue == initial.projection.groupID.uuidString,
                          witnessed.state.profileID?.rawValue == initial.projection.profileID.uuidString else {
                        throw UIRouteError(.unavailable, "new_reader_not_rendered")
                    }
                } else if reservation.policy.phase != .reserved {
                    throw UIRouteError(.unavailable, "new_reader_publication_in_progress")
                }
                tab = .present(stable); inspector = actualInspector
            } else {
                guard wanted.presentationMode == .sameTab,
                      let witnessed = visible.witnessedReader, witnessed.destination == intent.destination,
                      witnessed.presentation.kind == .currentTab, let currentContent = witnessed.content,
                      currentContent.sectionLocator.backend == wanted.sectionLocator.backend,
                      currentContent.sectionLocator.workKey == wanted.sectionLocator.workKey, witnessed.focus == nil,
                      let actualInspector = witnessed.state.inspectorVisible,
                      witnessed.state.workspaceID?.rawValue == initial.projection.groupID.uuidString,
                      witnessed.state.profileID?.rawValue == initial.projection.profileID.uuidString,
                      let selected = initial.projection.activeTabID, let target = initial.projection.targets[selected],
                      let stable = UIStableID(rawValue: selected.uuidString), witnessed.presentation.tabID == stable,
                      target.readerOwner != nil, target.backend.rawValue == snapshot.backend.rawValue,
                      target.backend.rawValue == wanted.sectionLocator.backend.rawValue,
                      target.workKey == wanted.sectionLocator.workKey else {
                    throw UIRouteError(.unavailable, "current_reader_binding_unavailable")
                }
                _ = try MaktabahNativeReaderBinding.appDestination(wanted)
                tab = .present(stable); inspector = actualInspector
            }
        }
        let current = try directory.synchronousScene(sceneID: sceneID, context: admitted.context, backend: snapshot)
        let final = try mapping(), finalBackend = try backend.currentBackendSnapshot(), finalAuthority = try liveAuthority()
        guard final.epoch == initial.epoch, final.projection == initial.projection, finalBackend == snapshot,
              BackendCoordinator.shared.activeBackendID.rawValue == snapshot.backend.rawValue,
              finalAuthority.authorityRevision == admitted.authorityRevision,
              finalAuthority.context == admitted.context else { throw UIRouteError(.staleState, "public_binding_changed_during_observation") }
        guard let group = UIStableID(rawValue: initial.projection.groupID.uuidString),
              let profile = UIStableID(rawValue: initial.projection.profileID.uuidString) else {
            throw UIRouteError(.unavailable, "public_workspace_identity_unavailable")
        }
        return .init(sceneID: sceneID, sceneRevision: current.revision, backendSnapshot: snapshot,
            mappingRevision: initial.epoch.revision, workspace: .present(group), profile: .present(profile),
            tab: tab, sidebarVisible: nil, inspectorVisible: inspector)
    }

    func currentScene(sceneID: UIStableID, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws -> UISceneSnapshot {
        let original = try liveAuthority()
        guard sceneID == self.sceneID, original.context == context else { throw ActionPortError.staleState }
        let scene = try await directory.currentScene(sceneID: sceneID, context: context, invocation: invocation)
        _ = try mapping()
        let final = try liveAuthority()
        guard final.context == context, final.authorityRevision == original.authorityRevision else { throw ActionPortError.staleState }
        return scene
    }
    func assess(_ descriptor: UIDestinationDescriptor, scene: UISceneSnapshot, context: ActionExecutionContext,
                invocation: ActionPortInvocation) async throws -> UIRouteEligibility {
        // Generic discovery can also encounter Core-only destinations. They have
        // no public variant to assess and must not abort discovery of other routes.
        guard descriptor.publicNavigationV2 != nil else {
            let current = try await currentScene(sceneID: scene.sceneID, context: context, invocation: invocation)
            guard current == scene else { throw ActionPortError.staleState }
            return .init(sceneID: current.sceneID, sceneRevision: current.revision, backendSnapshot: current.backendSnapshot,
                         supported: false, ready: false, allowed: false)
        }
        let root: PublicNavigationSpecV2.Presentation = descriptor.id.rawValue == "native.settings"
            || MaktabahNativeWorkspacePresentationBinding.Parent(rawValue: descriptor.id.rawValue) != nil
            || descriptor.id == MaktabahNativeSefariaSurfaceBinding.destination
            || descriptor.id == MaktabahNativeSavedResultsBinding.destination ? .sheet
            : descriptor.id.rawValue == "native.reader.inspector" ? .inspector : .currentTab
        return try await assessPublicVariant(.init(destination: descriptor.id, presentation: root, component: nil,
            requiresContent: descriptor.requiresContent), scene: scene, context: context, invocation: invocation)
    }
    func assessPublicVariant(_ variant: UIPublicNavigationVariantV2, scene: UISceneSnapshot,
                             context: ActionExecutionContext, invocation: ActionPortInvocation) async throws -> UIRouteEligibility {
        _ = try shape(destination: variant.destination, presentation: variant.presentation,
                      component: variant.component, hasContent: variant.requiresContent)
        let current = try await currentScene(sceneID: scene.sceneID, context: context, invocation: invocation)
        guard current == scene else { throw ActionPortError.staleState }
        let visible = try presentation()
        let ready = visible.ready(for: variant.destination)
            && (variant.component.map { visible.componentAvailable($0, in: variant.destination) } ?? true)
            && (variant.destination.rawValue != "native.reader" || variant.presentation == .newTab || visible.witnessedReader != nil)
            && (variant.destination.rawValue != "native.history" || visible.historyRootAvailable)
            && (variant.destination.rawValue != "native.reader.toc" || visible.tableOfContentsAvailable)
            && (variant.destination.rawValue != "native.reader.inspector" || visible.inspectorAvailable)
        return .init(sceneID: current.sceneID, sceneRevision: current.revision, backendSnapshot: current.backendSnapshot,
            supported: true, ready: ready, allowed: true)
    }
    func assessPublicNavigation(_ intent: PublicNavigationSpecV2, scene: UISceneSnapshot,
                                context: ActionExecutionContext, invocation: ActionPortInvocation) async throws -> UIRouteEligibility {
        _ = try observePublicNavigationBinding(intent, requestId: invocation.requestId, sceneID: scene.sceneID)
        return try await assessPublicVariant(.init(destination: intent.destination, presentation: intent.presentation,
            component: intent.component, requiresContent: intent.content != nil), scene: scene, context: context, invocation: invocation)
    }
}
