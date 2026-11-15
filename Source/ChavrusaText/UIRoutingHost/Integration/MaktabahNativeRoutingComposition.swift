#if os(iOS)
import AppIntents
import Foundation
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

/// One process composition using S's real singleton, one Core actor and I's
/// canonical resolver. No facade/cache/parser/permission implementation here.
@MainActor
final class MaktabahNativeRoutingComposition: UIDestinationEligibilityPort {
    static let futurePublicBindingsEnabled = false
    static let shared: MaktabahNativeRoutingComposition = {
        // Only programmer-defined finite capacities/validated static metadata
        // can fail construction. Runtime readiness is queried at invocation.
        do { return try MaktabahNativeRoutingComposition(backend: ActionLiveBackendBridge.shared) }
        catch { preconditionFailure("Invalid native routing composition: \(error)") }
    }()
    let registry: UIDestinationRegistry
    let directory: NativeSceneDirectory
    let authority: NativeNavigationAuthority
    let orchestrator: NativeSceneNavigationOrchestrator
    let core: ActionExecutor
    private let backend: any ActionSynchronousBackendStatePort & ActionResolverDataPort & ActionSearchPort
    private struct Registration {
        let managerID: ObjectIdentifier
        let session: MaktabahNativeSceneSession
        let lease: NativeNavigationAuthority.Lease
        let windowNumber: Int
        var publicBinding: MaktabahNativePublicBindingAdapter? = nil
    }
    private var scenes: [UIStableID: Registration] = [:]
    private var contexts: [UIStableID: ActionExecutionContext] = [:]
    private struct MountWaiter {
        let token: UUID
        let continuation: CheckedContinuation<UIStableID, any Error>
    }
    private var mountWaiters: [ObjectIdentifier: MountWaiter] = [:]
    private var intentsInstalled = false

    init(backend: any ActionSynchronousBackendStatePort & ActionResolverDataPort & ActionSearchPort) throws {
        self.backend = backend
        authority = try NativeNavigationAuthority()
        directory = try NativeSceneDirectory(authority: backend)
        core = try ActionExecutor(state: backend, resolver: CatalogActionResolver(data: backend, state: backend), search: backend,
                                  navigationAuthority: authority)
        orchestrator = try NativeSceneNavigationOrchestrator(core: core, backend: backend, authority: authority, directory: directory)
        func id(_ value: String) -> UIDestinationID { UIDestinationID(rawValue: value)! }
        registry = try UIDestinationRegistry(descriptors: [
            .init(id: id("native.history"), title: "History".localized, implementation: .implemented,
                  supportedBackends: ActionBackendID.allCases, presentations: [.currentTab], requiredCoreActions: [], allowsPublicRoute: true),
            .init(id: id("native.settings"), title: "Settings".localized, implementation: .implemented,
                  supportedBackends: ActionBackendID.allCases, presentations: [.sheet], requiredCoreActions: [])
        ])
    }

    func mount(sceneID: UIStableID, manager: iOSNavigationManager, bindings: MaktabahNativeSceneBindings, foreground: Bool,
               project: @escaping @MainActor () throws -> MaktabahNativeSceneProjection) throws -> MaktabahNativeSceneSession {
        guard scenes[sceneID] == nil else { throw UIRouteError(.unavailable, "native_scene_already_registered") }
        guard let windowNumber = (1...16).first(where: { number in !scenes.values.contains(where: { $0.windowNumber == number }) }) else {
            throw UIRouteError(.unavailable, "native_scene_admission_rejected")
        }
        let session = MaktabahNativeSceneSession(sceneID: sceneID, directory: directory, bindings: bindings, project: project)
        session.foreground = foreground
        let lease = try authority.mount(sceneID: sceneID, foreground: foreground)
        do {
            try session.mount { [weak self, weak session] context in
                guard let self, let session, session.mounted, contexts[sceneID] == context, context.foregroundSceneID == sceneID.rawValue,
                      context.subjectID == "maktabah.scene:" + sceneID.rawValue else { throw UIRouteError(.staleState, "native_scene_context_changed") }
            }
            try orchestrator.register(session)
            scenes[sceneID] = .init(managerID: ObjectIdentifier(manager), session: session, lease: lease, windowNumber: windowNumber)
            mountWaiters.removeValue(forKey: ObjectIdentifier(manager))?.continuation.resume(returning: sceneID)
            return session
        } catch { session.unmount(); authority.unmount(lease); throw error }
    }
    func setForeground(_ value: Bool, session: MaktabahNativeSceneSession) throws {
        guard let entry = scenes[session.sceneID], entry.session === session else { throw UIRouteError(.staleState, "scene_lifetime_changed") }
        try authority.setForeground(value, lease: entry.lease); session.foreground = value
        contexts.removeValue(forKey: session.sceneID)
        try session.nativeStateChanged()
        if !value { session.presentation.revoke() }
    }
    func unmount(_ session: MaktabahNativeSceneSession) {
        guard let entry = scenes[session.sceneID], entry.session === session else { return }
        entry.publicBinding?.cancel()
        orchestrator.unregister(session); session.unmount(); authority.unmount(entry.lease); scenes.removeValue(forKey: session.sceneID)
        contexts.removeValue(forKey: session.sceneID)
    }
    /// Explicit future composition only; no current handler or registry opts in.
    /// The original scene registration/lease/Core/directory remain authoritative.
    @discardableResult
    func configureFuturePublicBinding(session: MaktabahNativeSceneSession, manager: iOSNavigationManager,
                                      workspace: StudyWorkspaceNavigationAdapter,
                                      enabled: Bool = false) throws -> MaktabahNativePublicBindingAdapter {
        guard enabled else { throw UIRouteError(.notSupported, "future_public_binding_disabled") }
        guard let entry = scenes[session.sceneID], entry.session === session,
              entry.managerID == ObjectIdentifier(manager), entry.publicBinding == nil else {
            throw UIRouteError(.staleState, "public_binding_registration_changed")
        }
        let binding = try MaktabahNativePublicBindingAdapter(sceneID: session.sceneID, manager: manager,
            workspace: workspace, authority: authority, lease: entry.lease, directory: directory, backend: backend,
            presentation: { [weak session, weak workspace] in
                guard let session, let workspace, session.ownsWorkspace(workspace) else { throw ActionPortError.unavailable }
                return try session.publicBindingPresentation()
            }, invalidated: { [weak self, weak session] in
                guard let self, let session, self.scenes[session.sceneID]?.session === session else { return }
                self.contexts.removeValue(forKey: session.sceneID)
                do { try session.nativeStateChanged() } catch { session.unmount() }
                session.presentation.revoke()
            })
        scenes[session.sceneID]?.publicBinding = binding
        return binding
    }
    /// With a fixed producer installed, its typed synchronous fence owns
    /// invalidation. A coalesced SwiftUI notification must not revoke a new
    /// post-publication admission. Replacement owners retire the old binding.
    func workspaceProjectionDidUpdate(_ session: MaktabahNativeSceneSession, workspace: StudyWorkspaceNavigationAdapter?) throws {
        guard let entry = scenes[session.sceneID], entry.session === session else { throw ActionPortError.staleState }
        if let binding = entry.publicBinding {
            if let workspace, binding.ownsSource(workspace) { return }
            binding.cancel()
        } else { try invalidateContext(session) }
    }
    func invalidateContext(_ session: MaktabahNativeSceneSession) throws {
        guard let entry = scenes[session.sceneID], entry.session === session else { throw UIRouteError(.staleState, "scene_lifetime_changed") }
        contexts.removeValue(forKey: session.sceneID); try authority.invalidate(entry.lease)
        try session.nativeStateChanged(); session.presentation.revoke()
    }
    private func issue(_ context: ActionExecutionContext, sceneID: UIStableID) throws {
        guard contexts[sceneID] == nil else { throw UIRouteError(.unavailable, "native_scene_busy") }
        contexts[sceneID] = context
    }
    private func finish(_ context: ActionExecutionContext, sceneID: UIStableID) {
        if contexts[sceneID] == context { contexts.removeValue(forKey: sceneID) }
    }
    private func context(sceneID: UIStableID, origin: ActionOrigin, snapshot: ActionBackendSnapshot) -> ActionExecutionContext {
        // A local system/user navigation entry grants no content read or data
        // mutation. Scope enforcement remains in Core's canonical policy.
        .init(subjectID: "maktabah.scene:" + sceneID.rawValue, origin: origin,
              allowedBackends: [snapshot.backend], scopes: [.navigation, .discovery], foregroundSceneID: sceneID.rawValue)
    }
    func open(destination: NativeIntentService.Destination) async throws -> UISceneAcknowledgement {
        guard let entry = scenes[destination.sceneID], entry.session.foreground else { return .requiresForeground }
        let snapshot = try backend.currentBackendSnapshot()
        guard snapshot.backend == destination.backend else { return .requiresBackendSwitch(destination.backend) }
        let context = context(sceneID: destination.sceneID, origin: .appIntent, snapshot: snapshot)
        try issue(context, sceneID: destination.sceneID)
        defer { finish(context, sceneID: destination.sceneID) }
        let invocation = ActionPortInvocation(requestId: UUID(), snapshot: snapshot, deadlineUptimeNanoseconds: deadline())
        let scene = try await directory.currentScene(sceneID: destination.sceneID, context: context, invocation: invocation)
        let route = try entry.session.prepare(destination: destination.destination, invocation: invocation, scene: scene)
        let command = try UISceneCommand(route: registry.validate(route), invocation: invocation, scene: scene)
        let result = try await orchestrator.commit(command, context: context)
        record(result)
        return result
    }
    func open(url: URL, manager: iOSNavigationManager) async throws -> UISceneAcknowledgement? {
        #if DEBUG
        let scheme = "maktabah-debug"
        #else
        let scheme = "maktabah"
        #endif
        guard case .route(let route) = try NativeRouteURL.decode(url, scheme: scheme, registry: registry) else { return nil }
        let end = deadline(), managerID = ObjectIdentifier(manager)
        let exactSceneID = try await NativeObservationDeadline.run(until: end, clock: SystemActionClock()) { [self] in
            try await waitForMount(managerID: managerID)
        }
        let matches = scenes.values.filter { $0.managerID == ObjectIdentifier(manager) }
        guard matches.count == 1, let entry = matches.first, entry.session.sceneID == exactSceneID,
              entry.session.foreground else { return .requiresForeground }
        let snapshot = try backend.currentBackendSnapshot()
        if let requested = route.backend, requested != snapshot.backend { return .requiresBackendSwitch(requested) }
        let context = context(sceneID: entry.session.sceneID, origin: .deepLink, snapshot: snapshot)
        try issue(context, sceneID: entry.session.sceneID)
        defer { finish(context, sceneID: entry.session.sceneID) }
        let invocation = ActionPortInvocation(requestId: route.requestId, snapshot: snapshot, deadlineUptimeNanoseconds: end)
        let scene = try await directory.currentScene(sceneID: entry.session.sceneID, context: context, invocation: invocation)
        let prepared = try entry.session.prepare(route, invocation: invocation, scene: scene)
        let result = try await orchestrator.commit(.init(route: registry.validate(prepared), invocation: invocation, scene: scene), context: context)
        record(result)
        return result
    }
    private func waitForMount(managerID: ObjectIdentifier) async throws -> UIStableID {
        try Task.checkCancellation()
        let existing = scenes.values.filter { $0.managerID == managerID }
        if existing.count == 1, let value = existing.first { return value.session.sceneID }
        guard existing.isEmpty, mountWaiters[managerID] == nil, mountWaiters.count < 16 else { throw UIRouteError(.unavailable, "native_mount_admission_rejected") }
        let token = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                if Task.isCancelled { continuation.resume(throwing: CancellationError()) }
                else { mountWaiters[managerID] = .init(token: token, continuation: continuation) }
            }
        } onCancel: { [weak self] in
            Task { @MainActor in
                guard let self, mountWaiters[managerID]?.token == token else { return }
                mountWaiters.removeValue(forKey: managerID)?.continuation.resume(throwing: CancellationError())
            }
        }
    }
    func destinations() async throws -> [NativeIntentService.Destination] {
        var values: [NativeIntentService.Destination] = []
        for (id, entry) in scenes.sorted(by: { $0.key.rawValue < $1.key.rawValue }) where entry.session.foreground {
            let snapshot = try backend.currentBackendSnapshot(), context = context(sceneID: id, origin: .appIntent, snapshot: snapshot)
            try issue(context, sceneID: id)
            defer { finish(context, sceneID: id) }
            let admitted = try authority.admit(context: context, sceneID: id)
            defer { authority.release(admitted) }
            let invocation = ActionPortInvocation(requestId: UUID(), snapshot: snapshot, deadlineUptimeNanoseconds: deadline())
            let scene = try await directory.currentScene(sceneID: id, context: context, invocation: invocation)
            let descriptors = try await registry.discover(scene: scene, context: context, invocation: invocation, core: core, host: self)
            let windowLabel = entry.session.windowLabel(number: entry.windowNumber)
            values += descriptors.map { .init(backend: snapshot.backend, destination: $0.id, title: $0.title + " — " + windowLabel, sceneID: id) }
        }
        return values
    }
    func installIntentDependency() {
        guard !intentsInstalled else { return }
        let service = NativeIntentService(discover: { [self] in try await destinations() }, navigate: { [self] in try await open(destination: $0) })
        AppDependencyManager.shared.add(dependency: service)
        intentsInstalled = true
    }
    func currentScene(sceneID: UIStableID, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws -> UISceneSnapshot {
        try await directory.currentScene(sceneID: sceneID, context: context, invocation: invocation)
    }
    func assess(_ descriptor: UIDestinationDescriptor, scene: UISceneSnapshot, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws -> UIRouteEligibility {
        let current = try await directory.currentScene(sceneID: scene.sceneID, context: context, invocation: invocation)
        guard current == scene, let entry = scenes[scene.sceneID] else { throw UIRouteError(.staleState, "scene_or_backend_changed") }
        let supported = descriptor.id.rawValue == "native.settings" || (descriptor.id.rawValue == "native.history" && HistoryViewModel.shared.searchText.isEmpty)
        return .init(sceneID: scene.sceneID, sceneRevision: current.revision, backendSnapshot: current.backendSnapshot,
                     supported: supported, ready: entry.session.foreground && entry.session.mounted && entry.session.isPresentationReady, allowed: true)
    }
    private func deadline() -> UInt64 {
        let (value, overflow) = SystemActionClock().now().addingReportingOverflow(5_000_000_000)
        return overflow ? UInt64.max : value
    }
    private func record(_ result: UISceneAcknowledgement) {
        guard case .acknowledged(let receipt) = result else { return }
        // Only validated native acknowledgement reaches here. No private query,
        // note text, selected text or model arguments enter diagnostic logs.
        OtzariaFileLogger.shared.log("[NativeNavigationReceipt] request=\(receipt.requestId) scene=\(receipt.sceneID.rawValue) backend=\(receipt.backendSnapshot.backend.rawValue) generation=\(receipt.backendSnapshot.generation) epoch=\(receipt.backendSnapshot.rpcEpoch.map(String.init) ?? "none") revision=\(receipt.basedOnSceneRevision)->\(receipt.appliedSceneRevision) destination=\(receipt.route.destination.rawValue) presentation=\(receipt.route.presentation.kind.rawValue)")
    }
}
#endif
