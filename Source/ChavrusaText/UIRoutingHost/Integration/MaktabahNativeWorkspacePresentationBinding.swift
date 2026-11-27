#if os(iOS)
import Foundation
import Observation
import SwiftUI
import UIKit
import OtzariaUIRouting

/// Adapts the original scene-owned Workspace presentations. It does not own a
/// second profile/group/tab model or manufacture a visible-surface receipt.
@MainActor @Observable
final class MaktabahNativeWorkspacePresentationBinding {
    enum Parent: String, CaseIterable {
        case profiles = "native.workspace.profiles"
        case overview = "native.workspace.overview"
        var destination: UIDestinationID { UIDestinationID(rawValue: rawValue)! }
    }

    enum Host: Hashable { case compactRoot, tabletToolbar, overview, profiles }
    enum OriginalChange: Hashable { case overview, profiles, navigation, draft, layout }

    private enum OwnedChange: Equatable {
        case host(Host, UUID, OriginalChange)
        case sidebar
    }

    struct PresentationFacets {
        let requested: Bool
        let mounted: Bool
        let visible: Bool
        let blockingChild: Bool
        let transitioning: Bool
    }

    struct HostEvidence: Equatable {
        let sceneID: String
        let window: ObjectIdentifier
        let parent: ObjectIdentifier?
        let frame: CGRect
        let appeared: Bool
        let mounted: Bool
        let visible: Bool
        let transitioning: Bool
    }

    let sceneID: UIStableID
    private(set) var renderRevision: UInt64 = 0
    @ObservationIgnored private weak var manager: iOSNavigationManager?
    @ObservationIgnored private weak var sidebar: ReaderSidebarPageCoordinator?
    @ObservationIgnored private let workspaceSource: MaktabahNativeWorkspaceProjectionSource
    @ObservationIgnored private let selectViewer: @MainActor () -> Void
    @ObservationIgnored private var hosts: [Host: OriginalHost] = [:]
    @ObservationIgnored private var sources: [UUID: SourceEntry] = [:]
    @ObservationIgnored private var observedProofs: [WeakProof] = []
    @ObservationIgnored private var pending: Pending?
    @ObservationIgnored private var ownedChange: OwnedChange?
    @ObservationIgnored private var sidebarObservation: UUID?
    @ObservationIgnored private var retired = false
    @ObservationIgnored private var changed: @MainActor () -> Void = {}
    @ObservationIgnored private var invalidated: @MainActor () -> Void = {}

    @MainActor private final class OriginalHost {
        let token: UUID
        let stateOwnerID: UUID
        weak var workspace: StudyWorkspaceNavigationAdapter?
        weak var manager: iOSNavigationManager?
        var profilesPresented: @MainActor () -> Bool
        var presentProfiles: (@MainActor () -> Void)?
        var overviewPresented: @MainActor () -> Bool
        var presentOverview: (@MainActor () -> Void)?
        var blocked: @MainActor () -> Bool
        var evidence: @MainActor () -> HostEvidence?

        init(token: UUID, stateOwnerID: UUID, workspace: StudyWorkspaceNavigationAdapter,
             manager: iOSNavigationManager,
             profilesPresented: @escaping @MainActor () -> Bool,
             presentProfiles: (@MainActor () -> Void)?,
             overviewPresented: @escaping @MainActor () -> Bool,
             presentOverview: (@MainActor () -> Void)?,
             blocked: @escaping @MainActor () -> Bool,
             evidence: @escaping @MainActor () -> HostEvidence?) {
            self.token = token; self.stateOwnerID = stateOwnerID
            self.workspace = workspace; self.manager = manager
            self.profilesPresented = profilesPresented; self.presentProfiles = presentProfiles
            self.overviewPresented = overviewPresented; self.presentOverview = presentOverview
            self.blocked = blocked; self.evidence = evidence
        }
    }

    private final class WeakProof {
        weak var value: OriginalSourceProof?
        init(_ value: OriginalSourceProof) { self.value = value }
    }

    private struct SourceEntry {
        let parent: Parent
        let proof: OriginalSourceProof
        var hosts: [Host: UUID]
        var component: UIDestinationID?
    }

    private struct Pending {
        let requestID: UUID
        let parent: Parent
        let validate: @MainActor () throws -> Void
        var applied = false
        var originalPresentationRequested = false
    }

    /// The original store and native setter epochs are monotonic. They retain
    /// source identity through ABA changes without copying persisted feature data.
    @MainActor private final class OriginalSourceProof {
        private weak var workspace: StudyWorkspaceNavigationAdapter?
        private weak var manager: iOSNavigationManager?
        private let source: MaktabahNativeWorkspaceProjectionSource
        private let sceneID: String
        private let storeObservation: StudyWorkspaceMappingObservation
        private let nativeObservation: StudyWorkspaceMappingObservation
        private let backend: BackendID
        private let generation: UInt64
        private let observation: MaktabahNativeComponentSourceObservation
        private var valid = true

        init(sceneID: String, manager: iOSNavigationManager,
             source: MaktabahNativeWorkspaceProjectionSource) throws {
            guard source.isAuthoritative, let workspace = try source.read(),
                  workspace.sceneID == sceneID, workspace.attached, !workspace.isSwitching,
                  workspace.errorMessage == nil, workspace.store.loadError == nil,
                  !BackendCoordinator.shared.isTransitioning,
                  let stored = workspace.store.mappingObservation(scene: sceneID),
                  let native = workspace.mappingOwnershipObservation(),
                  stored.owner == ObjectIdentifier(workspace.store),
                  native.owner == ObjectIdentifier(manager), native.scene == sceneID,
                  case .workspaceStoreOnly = stored.coverage,
                  case .liveNativeSetters = native.coverage else {
                throw UIRouteError(.unavailable, "native_workspace_source_unavailable")
            }
            self.workspace = workspace; self.manager = manager; self.source = source
            self.sceneID = sceneID; storeObservation = stored; nativeObservation = native
            backend = BackendCoordinator.shared.activeBackendID
            generation = BackendCoordinator.shared.generation
            observation = MaktabahNativeComponentSourceObservation {
                _ = try? source.read()
                _ = workspace.attached
                _ = workspace.isSwitching
                _ = workspace.errorMessage
                _ = workspace.store.loadError
                _ = stored.source.event
                _ = native.source.event
            }
        }

        func owns(_ workspace: StudyWorkspaceNavigationAdapter, manager: iOSNavigationManager) -> Bool {
            self.workspace === workspace && self.manager === manager
        }

        func invalidate() { valid = false }

        func validate() throws {
            try observation.validate()
            guard valid, let workspace, let manager, try source.read() === workspace,
                  workspace.sceneID == sceneID, workspace.attached, !workspace.isSwitching,
                  workspace.errorMessage == nil, workspace.store.loadError == nil,
                  !BackendCoordinator.shared.isTransitioning,
                  BackendCoordinator.shared.activeBackendID == backend,
                  BackendCoordinator.shared.generation == generation,
                  let stored = workspace.store.mappingObservation(scene: sceneID),
                  let native = workspace.mappingOwnershipObservation(),
                  stored.source === storeObservation.source, stored.epoch == storeObservation.epoch,
                  stored.owner == storeObservation.owner, stored.scene == sceneID,
                  native.source === nativeObservation.source, native.epoch == nativeObservation.epoch,
                  native.owner == ObjectIdentifier(manager), native.scene == sceneID,
                  case .workspaceStoreOnly = stored.coverage,
                  case .liveNativeSetters = native.coverage else {
                throw UIRouteError(.staleState, "native_workspace_source_changed")
            }
        }
    }

    init(sceneID: UIStableID, manager: iOSNavigationManager,
         workspaceSource: MaktabahNativeWorkspaceProjectionSource,
         sidebar: ReaderSidebarPageCoordinator?, selectViewer: @escaping @MainActor () -> Void) {
        self.sceneID = sceneID; self.manager = manager; self.workspaceSource = workspaceSource
        self.sidebar = sidebar; self.selectViewer = selectViewer
        sidebarObservation = sidebar?.observeOverviewRequestChanges { [weak self] in
            guard let self else { return }
            // Only the exact synchronous original request setter is exempt.
            // The one-shot source proof is never reset after a user state change.
            if ownedChange != .sidebar { invalidateRetainedSources() }
        }
    }

    func install(changed: @escaping @MainActor () -> Void,
                 invalidated: @escaping @MainActor () -> Void) {
        self.changed = changed; self.invalidated = invalidated
    }

    func owns(_ workspace: StudyWorkspaceNavigationAdapter, manager: iOSNavigationManager) -> Bool {
        !retired && self.manager === manager && workspace.sceneID == sceneID.rawValue
            && (try? workspaceSource.read()) === workspace
    }

    var hasOriginalTabs: Bool {
        guard let workspace = try? workspaceSource.read() else { return false }
        return workspace.group?.tabs.isEmpty == false
    }

    /// Same original @AppStorage key and default as StudyGroupsOverview. This
    /// is a read-only availability facet, never another layout preference/setter.
    var originalOverviewLayout: ReaderTabSwitcherLayout {
        ReaderTabSwitcherLayout(rawValue: UserDefaults.standard.string(forKey: "chavrusa.study-tabs.layout")
                                ?? ReaderTabSwitcherLayout.grid.rawValue) ?? .grid
    }

    func isAvailable(parent: Parent) -> Bool {
        guard !retired, ChavrusaTextReaderUI.isEnabled, let manager,
              !MaktabahApp.isIpad || sidebar != nil,
              (try? OriginalSourceProof(sceneID: sceneID.rawValue, manager: manager,
                                        source: workspaceSource)) != nil,
              hosts[.profiles]?.blocked() != true,
              hosts[.overview]?.blocked() != true else { return false }
        let profiles = presentationFacets(for: .profiles)
        let overview = presentationFacets(for: .overview)
        let continuesOwnRequest = pending?.applied == true && pending?.parent == parent
        switch parent {
        case .profiles:
            if MaktabahApp.isIpad && sidebar?.overview.blocksRouting == true { return false }
            if profiles.transitioning && !continuesOwnRequest { return false }
            // On the phone, a stable original profile sheet covers its original
            // overview. That coverage is not an unrelated transition.
            if !MaktabahApp.isIpad && overview.transitioning && !profiles.visible
                && !continuesOwnRequest { return false }
            return true
        case .overview:
            return !profiles.requested && !profiles.mounted
                && (!overview.transitioning || continuesOwnRequest)
        }
    }

    /// These facets are read from original presentation bindings and real UIKit
    /// hosts. They do not infer successful presentation from a submitted request.
    func presentationFacets(for parent: Parent) -> PresentationFacets {
        let host = hosts[parent == .profiles ? .profiles : .overview]
        let actual = host?.evidence()
        let mounted = actual?.sceneID == sceneID.rawValue && actual?.mounted == true
        let visible = actual?.sceneID == sceneID.rawValue && actual?.visible == true
        let requested: Bool
        switch parent {
        case .profiles:
            requested = hosts[MaktabahApp.isIpad ? .tabletToolbar : .overview]?.profilesPresented() == true
        case .overview:
            requested = MaktabahApp.isIpad
                ? sidebar?.overview.isRequested == true : hosts[.compactRoot]?.overviewPresented() == true
        }
        let retainedDismissal = parent == .overview && MaktabahApp.isIpad
            && sidebar?.overview.blocksRouting == true && !requested
        return .init(requested: requested, mounted: mounted, visible: visible,
                     blockingChild: host?.blocked() == true,
                     transitioning: actual?.transitioning == true || retainedDismissal
                        || (requested && !visible) || (!requested && mounted))
    }

    func retainSource(parent: Parent, requestID: UUID) throws {
        guard sources.isEmpty, pending == nil, isAvailable(parent: parent), let manager else {
            throw UIRouteError(.unavailable, "native_workspace_presentation_busy")
        }
        let proof = try OriginalSourceProof(sceneID: sceneID.rawValue, manager: manager,
                                            source: workspaceSource)
        try proof.validate()
        sources[requestID] = .init(parent: parent, proof: proof,
                                   hosts: hosts.mapValues(\.token), component: nil)
        // The component owner can retain this proof for post-completion guide
        // validation. Keep only weak invalidation observers after public release.
        observedProofs.removeAll { $0.value == nil }
        observedProofs.append(WeakProof(proof))
    }

    func validateSource(parent: Parent, requestID: UUID) throws {
        guard !retired, let source = sources[requestID], source.parent == parent,
              isAvailable(parent: parent),
              source.hosts.allSatisfy({ hosts[$0.key]?.token == $0.value }) else {
            throw UIRouteError(.staleState, "native_workspace_presentation_owner_changed")
        }
        try source.proof.validate()
    }

    /// Session retains the parent FIRST. Component binding receives that same
    /// proof; it must never capture another workspace after a Core await.
    func captureComponentSource(parent: Parent, anchor: UIDestinationID) throws -> @MainActor () throws -> Void {
        guard let entry = sources.first, sources.count == 1, entry.value.parent == parent else {
            throw UIRouteError(.staleState, "native_workspace_parent_source_not_retained")
        }
        try validateSource(parent: parent, requestID: entry.key)
        guard entry.value.component == nil else {
            throw UIRouteError(.staleState, "native_workspace_component_already_retained")
        }
        sources[entry.key]?.component = anchor
        let proof = entry.value.proof
        return { [weak self] in
            guard let self, !retired else {
                throw UIRouteError(.staleState, "native_workspace_presentation_retired")
            }
            try proof.validate()
        }
    }

    func releaseSource(requestID: UUID) { sources.removeValue(forKey: requestID) }

    func begin(parent: Parent, requestID: UUID,
               validate: @escaping @MainActor () throws -> Void) throws {
        guard pending == nil else { throw UIRouteError(.unavailable, "native_workspace_presentation_busy") }
        try validateSource(parent: parent, requestID: requestID)
        try validate()
        pending = .init(requestID: requestID, parent: parent, validate: validate)
    }

    /// Only the canonical original driver calls apply. Later cold host rendering
    /// remains bounded by this same source proof, admission and deadline.
    func apply(parent: Parent, requestID: UUID) throws {
        guard var value = pending, value.requestID == requestID, value.parent == parent,
              !value.applied, manager != nil else {
            throw UIRouteError(.staleState, "native_workspace_presentation_not_prepared")
        }
        try validateSource(parent: parent, requestID: requestID); try value.validate()
        value.applied = true; pending = value
        selectViewer()
        if parent == .overview && MaktabahApp.isIpad {
            guard let sidebar else { throw UIRouteError(.staleState, "native_workspace_sidebar_detached") }
            sidebar.dismissLibrarySearch(); sidebar.navigationChrome.reveal()
            try withOwnedChange(.sidebar, requestID: requestID) { sidebar.overview.request() }
            pending?.originalPresentationRequested = true
        }
        renderOriginalPresentationsIfReady()
        renderRevision &+= 1
        changed()
    }

    /// Every original @State setter reports before it mutates. A user change
    /// consumes all retained proofs synchronously, including an A→B→A cycle.
    func originalStateWillChange(host kind: Host, stateOwnerID: UUID, change: OriginalChange) {
        guard let host = hosts[kind], host.stateOwnerID == stateOwnerID else {
            invalidateRetainedSources(); return
        }
        if ownedChange != .host(kind, host.token, change) { invalidateRetainedSources() }
    }

    /// Called only by the original profile NavigationStack's finite reveal
    /// callback, under the generic component owner's retained render admission.
    func revealProfileNavigation(anchor: UIDestinationID, stateOwnerID: UUID,
                                 perform: @MainActor () -> Void) throws {
        guard let value = pending, value.applied, value.parent == .profiles,
              sources[value.requestID]?.component == anchor,
              MaktabahNativeWorkspaceComponents.Profiles(rawValue: anchor.rawValue) != nil,
              let host = hosts[.profiles], host.stateOwnerID == stateOwnerID,
              host.evidence()?.visible == true, !host.blocked() else {
            throw UIRouteError(.staleState, "native_workspace_profile_navigation_not_owned")
        }
        try withOwnedChange(.host(.profiles, host.token, .navigation),
                            requestID: value.requestID, perform: perform)
    }

    private func withOwnedChange(_ change: OwnedChange, requestID: UUID,
                                 perform: @MainActor () -> Void) throws {
        guard let value = pending, value.applied, value.requestID == requestID,
              ownedChange == nil else {
            throw UIRouteError(.staleState, "native_workspace_original_setter_not_owned")
        }
        try validateSource(parent: value.parent, requestID: requestID)
        try value.validate()
        ownedChange = change
        defer { ownedChange = nil }
        perform()
    }

    func finish(requestID: UUID, completed: Bool) {
        guard pending?.requestID == requestID else { return }
        pending = nil
        if !completed { sources[requestID]?.proof.invalidate() }
    }

    func retire() {
        guard !retired else { return }
        retired = true; invalidateRetainedSources(); hosts.removeAll()
        if let sidebarObservation { sidebar?.removeOverviewRequestObserver(sidebarObservation) }
        sidebarObservation = nil
    }

    func attachHost(_ kind: Host, token: UUID, stateOwnerID: UUID,
                    workspace: StudyWorkspaceNavigationAdapter, manager: iOSNavigationManager,
                    profilesPresented: @escaping @MainActor () -> Bool,
                    presentProfiles: (@MainActor () -> Void)?,
                    overviewPresented: @escaping @MainActor () -> Bool,
                    presentOverview: (@MainActor () -> Void)?,
                    blocked: @escaping @MainActor () -> Bool,
                    evidence: @escaping @MainActor () -> HostEvidence?) {
        guard !retired, self.manager === manager, workspace.sceneID == sceneID.rawValue,
              (try? workspaceSource.read()) === workspace else { return }
        if let existing = hosts[kind], existing.token != token {
            invalidateRetainedSources()
        }
        if let entry = sources.first, entry.value.hosts[kind] == nil {
            // Only the first actual original host mounted BY this committed
            // request may join. Independent mounting during awaits invalidates it.
            if let value = pending, value.applied, value.requestID == entry.key,
               entry.value.proof.owns(workspace, manager: manager),
               kind != .profiles || value.parent == .profiles {
                sources[entry.key]?.hosts[kind] = token
            } else {
                invalidateRetainedSources()
            }
        }
        if let existing = hosts[kind], existing.token == token {
            guard existing.workspace === workspace, existing.manager === manager,
                  existing.stateOwnerID == stateOwnerID else {
                invalidateRetainedSources(); return
            }
            existing.profilesPresented = profilesPresented; existing.presentProfiles = presentProfiles
            existing.overviewPresented = overviewPresented; existing.presentOverview = presentOverview
            existing.blocked = blocked; existing.evidence = evidence
        } else {
            hosts[kind] = .init(token: token, stateOwnerID: stateOwnerID,
                workspace: workspace, manager: manager,
                profilesPresented: profilesPresented, presentProfiles: presentProfiles,
                overviewPresented: overviewPresented, presentOverview: presentOverview,
                blocked: blocked, evidence: evidence)
        }
    }

    func detachHost(_ kind: Host, token: UUID) {
        guard hosts[kind]?.token == token else { return }
        invalidateRetainedSources()
        hosts.removeValue(forKey: kind)
        changed()
    }

    func hostWillDisappear(_ kind: Host, token: UUID) {
        guard hosts[kind]?.token == token,
              observedProofs.contains(where: { $0.value != nil }) else { return }
        let expectedCoverage: Bool
        if let value = pending, value.applied {
            switch kind {
            case .compactRoot:
                expectedCoverage = presentationFacets(for: .overview).requested
            case .tabletToolbar:
                expectedCoverage = value.parent == .profiles && presentationFacets(for: .profiles).requested
                    || value.parent == .overview && presentationFacets(for: .overview).requested
            case .overview:
                expectedCoverage = value.parent == .profiles && presentationFacets(for: .profiles).requested
            case .profiles:
                expectedCoverage = false
            }
        } else { expectedCoverage = false }
        // Interactive dismissal followed by cancellation must not resurrect a
        // retained admission just because the original State value stayed true.
        if !expectedCoverage { invalidateRetainedSources() }
    }

    func hostDidLayout(_ kind: Host, token: UUID) {
        guard hosts[kind]?.token == token else { return }
        renderOriginalPresentationsIfReady()
        changed()
    }

    private func renderOriginalPresentationsIfReady() {
        guard let value = pending, value.applied else { return }
        if !MaktabahApp.isIpad && !presentationFacets(for: .overview).requested {
            guard let host = hosts[.compactRoot], !host.blocked(),
                  let evidence = host.evidence(), evidence.sceneID == sceneID.rawValue,
                  evidence.visible, let present = host.presentOverview else { return }
            do {
                try withOwnedChange(.host(.compactRoot, host.token, .overview),
                                    requestID: value.requestID, perform: present)
            } catch { invalidateRetainedSources(); return }
        }
        guard let current = pending, current.requestID == value.requestID else { return }
        if current.parent == .overview {
            pending?.originalPresentationRequested = true
            return
        }
        guard !current.originalPresentationRequested else { return }
        if presentationFacets(for: .profiles).requested {
            pending?.originalPresentationRequested = true
            return
        }
        let kind: Host = MaktabahApp.isIpad ? .tabletToolbar : .overview
        guard let host = hosts[kind], !host.blocked(), let evidence = host.evidence(),
              evidence.sceneID == sceneID.rawValue, evidence.visible,
              let present = host.presentProfiles else { return }
        do {
            try withOwnedChange(.host(kind, host.token, .profiles),
                                requestID: current.requestID, perform: present)
            pending?.originalPresentationRequested = true
        } catch { invalidateRetainedSources() }
    }

    private func invalidateRetainedSources() {
        let wasPending = pending != nil || !sources.isEmpty
        observedProofs.forEach { $0.value?.invalidate() }
        observedProofs.removeAll(); sources.removeAll(); pending = nil
        if wasPending { invalidated() }
    }
}

/// Attached inside the original view, with its original State bindings. UIKit
/// appearance/layout, not SwiftUI onAppear or a requested route, permits a cold
/// parent continuation. Dismantling the actual controller retires its lifetime.
struct MaktabahNativeWorkspaceOriginalHost: ViewModifier {
    let binding: MaktabahNativeWorkspacePresentationBinding?
    let kind: MaktabahNativeWorkspacePresentationBinding.Host
    let stateOwnerID: UUID
    let workspace: StudyWorkspaceNavigationAdapter
    let manager: iOSNavigationManager
    var profilesPresented: @MainActor () -> Bool = { false }
    var presentProfiles: (@MainActor () -> Void)? = nil
    var overviewPresented: @MainActor () -> Bool = { false }
    var presentOverview: (@MainActor () -> Void)? = nil
    var blocked: @MainActor () -> Bool = { false }

    func body(content: Content) -> some View {
        content.background {
            if let binding {
                OriginalHostWitness(binding: binding, kind: kind, stateOwnerID: stateOwnerID,
                    workspace: workspace, manager: manager, profilesPresented: profilesPresented,
                    presentProfiles: presentProfiles, overviewPresented: overviewPresented,
                    presentOverview: presentOverview, blocked: blocked)
                    .id(HostIdentity(binding: ObjectIdentifier(binding), kind: kind,
                        stateOwnerID: stateOwnerID, workspace: ObjectIdentifier(workspace),
                        manager: ObjectIdentifier(manager)))
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
        }
    }

    private struct HostIdentity: Hashable {
        let binding: ObjectIdentifier
        let kind: MaktabahNativeWorkspacePresentationBinding.Host
        let stateOwnerID: UUID
        let workspace: ObjectIdentifier
        let manager: ObjectIdentifier
    }

    private struct OriginalHostWitness: UIViewControllerRepresentable {
        let binding: MaktabahNativeWorkspacePresentationBinding
        let kind: MaktabahNativeWorkspacePresentationBinding.Host
        let stateOwnerID: UUID
        let workspace: StudyWorkspaceNavigationAdapter
        let manager: iOSNavigationManager
        let profilesPresented: @MainActor () -> Bool
        let presentProfiles: (@MainActor () -> Void)?
        let overviewPresented: @MainActor () -> Bool
        let presentOverview: (@MainActor () -> Void)?
        let blocked: @MainActor () -> Bool

        func makeUIViewController(context: Context) -> Controller { Controller() }
        func updateUIViewController(_ controller: Controller, context: Context) {
            let identity = HostIdentity(binding: ObjectIdentifier(binding), kind: kind,
                stateOwnerID: stateOwnerID, workspace: ObjectIdentifier(workspace),
                manager: ObjectIdentifier(manager))
            guard controller.identity == nil || controller.identity == identity else {
                controller.detach()
                return
            }
            controller.identity = identity
            controller.binding = binding; controller.kind = kind
            binding.attachHost(kind, token: controller.token, stateOwnerID: stateOwnerID,
                workspace: workspace, manager: manager,
                profilesPresented: profilesPresented, presentProfiles: presentProfiles,
                overviewPresented: overviewPresented, presentOverview: presentOverview, blocked: blocked,
                evidence: { [weak controller] in controller?.evidence() })
        }
        static func dismantleUIViewController(_ controller: Controller, coordinator: ()) { controller.detach() }

        final class Controller: UIViewController {
            let token = UUID()
            weak var binding: MaktabahNativeWorkspacePresentationBinding?
            var kind: MaktabahNativeWorkspacePresentationBinding.Host?
            var identity: HostIdentity?
            private var previous: MaktabahNativeWorkspacePresentationBinding.HostEvidence?
            private var appeared = false
            func detach() {
                if let kind { binding?.detachHost(kind, token: token) }
                binding = nil
            }
            override func loadView() {
                view = UIView(); view.backgroundColor = .clear
                view.isUserInteractionEnabled = false; view.isAccessibilityElement = false
            }
            override func viewDidAppear(_ animated: Bool) {
                super.viewDidAppear(animated); appeared = true; publishLayout()
            }
            override func viewWillDisappear(_ animated: Bool) {
                if let kind { binding?.hostWillDisappear(kind, token: token) }
                appeared = false; publishLayout(); super.viewWillDisappear(animated)
            }
            override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); publishLayout() }
            private func publishLayout() {
                let actual = evidence()
                guard actual != previous else { return }
                previous = actual
                if let kind { binding?.hostDidLayout(kind, token: token) }
            }
            func evidence() -> MaktabahNativeWorkspacePresentationBinding.HostEvidence? {
                guard let view = viewIfLoaded, let window = view.window,
                      let scene = window.windowScene else { return nil }
                let rect = view.convert(view.bounds, to: window)
                let area = rect.width * rect.height
                var clipped = rect.intersection(window.bounds)
                var alpha: CGFloat = 1
                var visible = appeared && window.isKeyWindow && !window.isHidden
                    && scene.activationState == .foregroundActive && area.isFinite && area > 0
                var ancestor: UIView? = view
                while let current = ancestor {
                    visible = visible && !current.isHidden; alpha *= current.alpha
                    if current.clipsToBounds {
                        clipped = clipped.intersection(current.convert(current.bounds, to: window))
                    }
                    ancestor = current.superview
                }
                visible = visible && alpha >= 0.95 && !clipped.isNull
                    && clipped.width * clipped.height >= area * 0.98
                var top = window.rootViewController
                while let presented = top?.presentedViewController { top = presented }
                if let top, top !== window.rootViewController, !view.isDescendant(of: top.view) { visible = false }
                var transitioning = false
                var controller: UIViewController? = self
                while let current = controller {
                    if current.isBeingPresented || current.isBeingDismissed || current.transitionCoordinator != nil {
                        visible = false; transitioning = true
                    }
                    controller = current.parent
                }
                if let top, top.isBeingPresented || top.isBeingDismissed || top.transitionCoordinator != nil {
                    visible = false; transitioning = true
                }
                return .init(sceneID: scene.session.persistentIdentifier,
                    window: ObjectIdentifier(window), parent: parent.map(ObjectIdentifier.init),
                    frame: rect, appeared: appeared, mounted: !view.bounds.isEmpty,
                    visible: visible, transitioning: transitioning)
            }
        }
    }
}
/// Wraps an existing State Binding; values remain owned by the original view.
/// Equal writes are no-ops so UIKit's normal presentation reconciliation cannot
/// consume a route that has already invoked that exact original setter.
@MainActor func maktabahWorkspaceOriginalBinding<Value: Equatable>(
    _ original: Binding<Value>, binding: MaktabahNativeWorkspacePresentationBinding?,
    host: MaktabahNativeWorkspacePresentationBinding.Host, stateOwnerID: UUID,
    change: MaktabahNativeWorkspacePresentationBinding.OriginalChange
) -> Binding<Value> {
    Binding(get: { original.wrappedValue }, set: { value in
        guard value != original.wrappedValue else { return }
        binding?.originalStateWillChange(host: host, stateOwnerID: stateOwnerID, change: change)
        original.wrappedValue = value
    })
}
#endif
