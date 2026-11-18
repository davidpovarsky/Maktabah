#if os(iOS)
import AppIntents
import Foundation
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost
import HanlinHostContracts
import HanlinPlatformContracts

/// One process composition using S's real singleton, one Core actor and I's
/// canonical resolver. No facade/cache/parser/permission implementation here.
@MainActor
final class MaktabahNativeRoutingComposition: UIDestinationEligibilityPort, OtzariaHanlinHostAuthority {
    static let futurePublicBindingsEnabled = true
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
        let hanlinSceneID = UUID()
        var hanlin: HanlinRegistration?
    }
    private var scenes: [UIStableID: Registration] = [:]
    private var contexts: [UIStableID: ActionExecutionContext] = [:]
    // Ephemeral association to the actual native registration, not another
    // account, workspace, permission store or scene-selection authority.
    private struct HanlinSourceObservation: Equatable {
        let backend: ActionBackendSnapshot
        let source: ObjectIdentifier
        let epoch: StudyWorkspaceMappingEpoch
        let projection: StudyWorkspaceMappingProjection
        let locale: String
    }
    private struct HanlinRegistration {
        let session: HanlinHostSession
        let binding: OtzariaHanlinBinding
        let observed: HanlinSourceObservation
    }

    private struct MountWaiter {
        let token: UUID
        let continuation: CheckedContinuation<UIStableID, any Error>
    }
    private var mountWaiters: [ObjectIdentifier: MountWaiter] = [:]
    private var intentsInstalled = false

    private final class ReaderInvocation {
        let route: UIValidatedRoute
        let context: ActionExecutionContext
        let sceneID: UIStableID
        var receipt: UISceneReceipt?
        init(route: UIValidatedRoute, context: ActionExecutionContext, sceneID: UIStableID) {
            self.route = route; self.context = context; self.sceneID = sceneID
        }
    }
    private var readerInvocations: [UUID: ReaderInvocation] = [:]

    init(backend: any ActionSynchronousBackendStatePort & ActionResolverDataPort & ActionSearchPort) throws {
        self.backend = backend
        authority = try NativeNavigationAuthority()
        directory = try NativeSceneDirectory(authority: backend)
        let readerSink = MaktabahNativeReaderCommandSink()
        core = try ActionExecutor(state: backend, resolver: CatalogActionResolver(data: backend, state: backend), search: backend,
                                  ui: readerSink, navigationAuthority: authority)
        orchestrator = try NativeSceneNavigationOrchestrator(core: core, backend: backend, authority: authority, directory: directory)
        func id(_ value: String) -> UIDestinationID { UIDestinationID(rawValue: value)! }
        registry = try UIDestinationRegistry(descriptors: [
            .init(id: id("native.library"), title: "Library".localized, implementation: .implemented,
                  supportedBackends: ActionBackendID.allCases, presentations: [.currentTab], requiredCoreActions: [], allowsPublicRoute: true,
                  publicNavigationV2: .init(rules: [.init(presentation: .currentTab)])),
            .init(id: id("native.reader.toc"), title: "Table of Contents".localized, implementation: .implemented,
                  supportedBackends: ActionBackendID.allCases, presentations: [.currentTab], requiredCoreActions: [], allowsPublicRoute: true,
                  publicNavigationV2: .init(rules: [.init(presentation: .currentTab)])),
            .init(id: id("native.history"), title: "History".localized, implementation: .implemented,
                  supportedBackends: ActionBackendID.allCases, presentations: [.currentTab], requiredCoreActions: [], allowsPublicRoute: true,
                  publicNavigationV2: .init(rules: [.init(presentation: .currentTab)])),
            .init(id: id("native.search"), title: "Search".localized, implementation: .implemented,
                  supportedBackends: ActionBackendID.allCases, presentations: [.currentTab], anchors: [id("native.search.query")],
                  requiredCoreActions: [], allowsPublicRoute: true,
                  publicNavigationV2: .init(rules: [.init(presentation: .currentTab, components: [id("native.search.query")])])),
            .init(id: id("native.annotations"), title: "Annotations".localized, implementation: .implemented,
                  supportedBackends: ActionBackendID.allCases, presentations: [.currentTab], requiredCoreActions: [], allowsPublicRoute: true,
                  publicNavigationV2: .init(rules: [.init(presentation: .currentTab)])),
            .init(id: id("native.settings"), title: "Settings".localized, implementation: .implemented,
                  supportedBackends: ActionBackendID.allCases, presentations: [.sheet], requiredCoreActions: [],
                  publicNavigationV2: .init(rules: [.init(presentation: .sheet)])),
            .init(id: id("native.reader"), title: "Reader".localized, implementation: .implemented,
                  supportedBackends: ActionBackendID.allCases, presentations: [.currentTab, .newTab],
                  requiredCoreActions: ["reader.open"], requiresContent: true,
                  publicNavigationV2: .init(rules: [.init(presentation: .currentTab), .init(presentation: .newTab)]))
        ])
        readerSink.deliver = { [weak self] command in
            guard let self else { throw ActionPortError.unavailable }
            return try await receiveReader(command)
        }
    }

    func mount(sceneID: UIStableID, manager: iOSNavigationManager, bindings: MaktabahNativeSceneBindings, foreground: Bool,
               workspaceSource: MaktabahNativeWorkspaceProjectionSource? = nil,
               project: @escaping @MainActor () throws -> MaktabahNativeSceneProjection) throws -> MaktabahNativeSceneSession {
        guard scenes[sceneID] == nil else { throw UIRouteError(.unavailable, "native_scene_already_registered") }
        guard let windowNumber = (1...16).first(where: { number in !scenes.values.contains(where: { $0.windowNumber == number }) }) else {
            throw UIRouteError(.unavailable, "native_scene_admission_rejected")
        }
        let session = MaktabahNativeSceneSession(sceneID: sceneID, directory: directory, bindings: bindings, workspaceSource: workspaceSource, project: project)
        session.foreground = foreground
        let lease = try authority.mount(sceneID: sceneID, foreground: foreground)
        do {
            try session.mount { [weak self, weak session] context in
                guard let self, let session, session.mounted, contexts[sceneID] == context, context.foregroundSceneID == sceneID.rawValue,
                      context.subjectID == "maktabah.scene:" + sceneID.rawValue else { throw UIRouteError(.staleState, "native_scene_context_changed") }
            }
            try orchestrator.register(session)
            scenes[sceneID] = .init(managerID: ObjectIdentifier(manager), session: session, lease: lease, windowNumber: windowNumber)
            #if DEBUG
            OtzariaFileLogger.shared.log("[NativeSceneLifecycle] event=mount pid=\(ProcessInfo.processInfo.processIdentifier) foreground=\(foreground)")
            #endif
            if foreground {
                mountWaiters.removeValue(forKey: ObjectIdentifier(manager))?.continuation.resume(returning: sceneID)
            }
            return session
        } catch { session.unmount(); authority.unmount(lease); throw error }
    }
    func setForeground(_ value: Bool, session: MaktabahNativeSceneSession) throws {
        #if DEBUG
        OtzariaFileLogger.shared.log("[NativeSceneLifecycle] event=foreground pid=\(ProcessInfo.processInfo.processIdentifier) foreground=\(value)")
        #endif
        guard let entry = scenes[session.sceneID], entry.session === session else { throw UIRouteError(.staleState, "scene_lifetime_changed") }
        try authority.setForeground(value, lease: entry.lease); session.foreground = value
        scenes[session.sceneID]?.hanlin = nil
        contexts.removeValue(forKey: session.sceneID)
        try session.nativeStateChanged()
        if !value { session.presentation.revoke() }
        else { mountWaiters.removeValue(forKey: entry.managerID)?.continuation.resume(returning: session.sceneID) }
    }
    func unmount(_ session: MaktabahNativeSceneSession) {
        guard let entry = scenes[session.sceneID], entry.session === session else { return }
        #if DEBUG
        OtzariaFileLogger.shared.log("[NativeSceneLifecycle] event=unmount pid=\(ProcessInfo.processInfo.processIdentifier)")
        #endif
        mountWaiters.removeValue(forKey: entry.managerID)?.continuation.resume(throwing: UIRouteError(.staleState, "scene_lifetime_changed"))
        entry.publicBinding?.cancel()
        orchestrator.unregister(session); session.unmount(); authority.unmount(entry.lease); scenes.removeValue(forKey: session.sceneID)
        contexts.removeValue(forKey: session.sceneID)
    }
    /// Explicit future composition only; no current handler or registry opts in.
    /// The original scene registration/lease/Core/directory remain authoritative.
    @discardableResult
    func configureFuturePublicBinding(session: MaktabahNativeSceneSession, manager: iOSNavigationManager,
                                      workspace: StudyWorkspaceNavigationAdapter,
                                      workspaceOwner: MaktabahNativeWorkspaceOwner? = nil,
                                      enabled: Bool = false) throws -> MaktabahNativePublicBindingAdapter {
        guard enabled else { throw UIRouteError(.notSupported, "future_public_binding_disabled") }
        guard let workspaceOwner, workspaceOwner.current === workspace, session.usesWorkspaceOwner(workspaceOwner) else {
            throw UIRouteError(.unavailable, "authoritative_workspace_owner_not_installed")
        }
        guard let entry = scenes[session.sceneID], entry.session === session,
              entry.managerID == ObjectIdentifier(manager), entry.publicBinding == nil else {
            throw UIRouteError(.staleState, "public_binding_registration_changed")
        }
        let binding = try MaktabahNativePublicBindingAdapter(sceneID: session.sceneID, manager: manager,
            workspace: workspace, workspaceOwner: workspaceOwner, authority: authority, lease: entry.lease, directory: directory, backend: backend,
            presentation: { [weak session] in
                guard let session else { throw ActionPortError.unavailable }
                return try session.publicBindingPresentation()
            }, invalidated: { [weak self, weak session] in
                guard let self, let session, self.scenes[session.sceneID]?.session === session else { return }
                self.contexts.removeValue(forKey: session.sceneID)
                self.scenes[session.sceneID]?.hanlin = nil
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
            scenes[session.sceneID]?.publicBinding = nil
            scenes[session.sceneID]?.hanlin = nil
        } else { try invalidateContext(session) }
    }
    func installPublicBindingIfReady(session: MaktabahNativeSceneSession, manager: iOSNavigationManager,
                                     workspace: StudyWorkspaceNavigationAdapter?, owner: MaktabahNativeWorkspaceOwner?) throws {
        guard Self.futurePublicBindingsEnabled, scenes[session.sceneID]?.publicBinding == nil,
              let workspace, let owner, workspace.mappingOwnershipObservation()?.coverage == .liveNativeSetters else { return }
        _ = try configureFuturePublicBinding(session: session, manager: manager, workspace: workspace,
                                              workspaceOwner: owner, enabled: true)
    }

    func invalidateContext(_ session: MaktabahNativeSceneSession) throws {
        guard let entry = scenes[session.sceneID], entry.session === session else { throw UIRouteError(.staleState, "scene_lifetime_changed") }
        scenes[session.sceneID]?.hanlin = nil
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
    /// A real host entry for the original Hanlin SDK. The app's existing
    /// profile/group and native mapping own this namespace. This checkpoint
    /// exposes metadata and UI-only routes; it grants no content-read scope and
    /// does not publish selected text, run a model or construct a chat/store.
    func makeHanlinHostSession(manager: iOSNavigationManager, conversationID: UUID) throws
        -> (host: OtzariaHanlinHostAdapter, session: HanlinHostSession) {
        try Task.checkCancellation()
        let matches = scenes.filter { $0.value.managerID == ObjectIdentifier(manager) }
        guard matches.count == 1, let (sceneID, entry) = matches.first else { throw HanlinHostError.invalidContext }
        let observed = try hanlinSource(sceneID: sceneID, entry: entry)
        let namespace = try HanlinConversationNamespace(app: "otzaria",
            account: observed.projection.profileID.uuidString,
            workspace: observed.projection.groupID.uuidString, space: observed.backend.backend.rawValue)
        // Native UIKit identifiers remain strings. This UUID belongs only to the
        // SDK association and is discarded with this exact native registration.
        let sdkContext = HanlinHostContext(namespace: namespace, sceneID: entry.hanlinSceneID,
            generation: UUID(), sourceRevision: "backend:" + String(observed.backend.generation)
                + ";rpc:" + (observed.backend.rpcEpoch.map(String.init) ?? "none")
                + ";mapping:" + observed.epoch.sourceID.uuidString + ":" + String(observed.epoch.revision),
            localeIdentifier: observed.locale)
        let binding = OtzariaHanlinBinding(context: sdkContext,
            executionContext: context(sceneID: sceneID, origin: .internalAI, snapshot: observed.backend),
            backend: observed.backend, catalogRevision: .init(observed.backend.generation),
            availableReadActions: ["system.listBackends", "catalog.resolveWork", "catalog.resolveReference"])
        let session = HanlinHostSession(conversationID: conversationID, context: sdkContext)
        // Replay/cancellation admission belongs to this exact SDK session.
        // Reuse the one original Core, not a process-wide transport budget that
        // can exhaust unrelated scenes or later conversations.
        let adapter = try OtzariaHanlinHostAdapter(core: core, authority: self)
        scenes[sceneID]?.hanlin = .init(session: session, binding: binding, observed: observed)
        return (adapter, session)
    }

    private func hanlinSource(sceneID: UIStableID, entry: Registration) throws -> HanlinSourceObservation {
        guard entry.session.mounted, entry.session.foreground,
              entry.session.isPresentationReady, let publicBinding = entry.publicBinding,
              let source = entry.session.workspaceProjectionSource, source.isAuthoritative,
              let workspace = try source.read(), publicBinding.ownsSource(workspace),
              let mapping = workspace.mappingOwnershipObservation(),
              mapping.coverage == .liveNativeSetters, mapping.scene == sceneID.rawValue,
              mapping.owner == entry.managerID, mapping.source.event.phase == .available,
              mapping.source.event.epoch == mapping.epoch else { throw HanlinHostError.staleContext }
        let snapshot = try backend.currentBackendSnapshot()
        guard mapping.projection.targets.values.allSatisfy({
            ActionAppIdentityBridge.actionBackend($0.backend) == snapshot.backend
        }) else { throw HanlinHostError.staleContext }
        return .init(backend: snapshot, source: ObjectIdentifier(mapping.source),
            epoch: mapping.epoch, projection: mapping.projection, locale: Locale.current.identifier)
    }

    private func hanlinRegistration(for context: HanlinHostContext) throws -> (UIStableID, Registration, HanlinRegistration) {
        try Task.checkCancellation()
        let matches = scenes.filter { $0.value.hanlin?.binding.context == context }
        guard matches.count == 1, let (sceneID, entry) = matches.first, let active = entry.hanlin else {
            throw HanlinHostError.staleContext
        }
        do {
            guard try hanlinSource(sceneID: sceneID, entry: entry) == active.observed else {
                throw HanlinHostError.staleContext
            }
        } catch {
            scenes[sceneID]?.hanlin = nil
            throw HanlinHostError.staleContext
        }
        return (sceneID, entry, active)
    }

    func current(for session: HanlinHostSession) async throws -> OtzariaHanlinBinding {
        let (_, _, active) = try hanlinRegistration(for: session.context)
        guard active.session == session else { throw HanlinHostError.staleContext }
        return active.binding
    }

    func current(for context: HanlinHostContext) async throws -> OtzariaHanlinBinding {
        try hanlinRegistration(for: context).2.binding
    }

    func open(_ destination: HanlinHostDestination, binding: OtzariaHanlinBinding) async throws -> HanlinHostNavigationResult {
        let (sceneID, entry, active) = try hanlinRegistration(for: destination.context)
        guard active.binding == binding, destination.blockReference == nil,
              let url = URL(string: destination.objectReference) else { throw HanlinHostError.invalidArguments }
        // Reuse the original public-v2 codec and Registry, never a private route
        // parser or caller-supplied local IDs. Components live in that same URL.
        let intent = try NativePublicNavigationURLV2.decode(url, registry: registry)
        guard intent.content == nil else {
            throw UIRouteError(.notSupported, "hanlin_content_context_transition_not_installed")
        }
        let result = try await open(public: intent, sceneID: sceneID, managerID: entry.managerID,
            expectedSnapshot: binding.backend, origin: .internalAI, until: deadline(), requestID: destination.requestID)
        switch result {
        case .acknowledged(let receipt):
            // The original orchestrator has already checked the complete route,
            // native visible witness and Core final authority. Preserve identity.
            guard receipt.requestId == destination.requestID, receipt.sceneID == sceneID,
                  receipt.backendSnapshot == binding.backend, receipt.route.destination == intent.destination,
                  receipt.route.content == nil else { throw HanlinHostError.resultMismatch }
            return .presented(requestID: destination.requestID, context: destination.context,
                objectReference: destination.objectReference, blockReference: nil)
        case .queued:
            return .queued(requestID: destination.requestID, context: destination.context)
        case .requiresForeground: throw UIRouteError(.requiresForeground, "exact_foreground_scene_required")
        case .requiresBackendSwitch: throw UIRouteError(.requiresBackendSwitch, "backend_selection_required")
        case .notSupported(let failure): throw UIRouteError(.notSupported, failure.code)
        case .unavailable(let failure): throw UIRouteError(.unavailable, failure.code)
        case .staleState(let failure): throw UIRouteError(.staleState, failure.code)
        case .needsDisambiguation: throw UIRouteError(.needsDisambiguation, "native_scene_ambiguous")
        case .requiresConfirmation(let failure): throw UIRouteError(.requiresConfirmation, failure.code)
        case .cancelled: throw HanlinHostError.cancelled
        case .failed(let failure): throw UIRouteError(.failed, failure.code)
        }
    }

    func open(destination: NativeIntentService.Destination) async throws -> UISceneAcknowledgement {
        guard let entry = scenes[destination.sceneID], entry.session.foreground else { return .requiresForeground }
        let snapshot = try backend.currentBackendSnapshot()
        guard snapshot.backend == destination.backend else { return .requiresBackendSwitch(destination.backend) }
        if let component = destination.component {
            // The same live system entity uses the same public binder and
            // original Core fence as a component deep link. No second intent
            // executor, deferred focus or caller-supplied authority is added.
            return try await open(public: .init(destination: destination.destination, backend: destination.backend,
                presentation: .currentTab, component: component), sceneID: destination.sceneID,
                managerID: entry.managerID, expectedSnapshot: snapshot, origin: .appIntent, until: deadline())
        }
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
    /// Public content uses the original current Reader or R's exact new-tab
    /// reservation. Core still authorizes the one native mutation.
    func open(public intent: PublicNavigationSpecV2, manager: iOSNavigationManager,
              origin: ActionOrigin = .deepLink, until end: UInt64) async throws -> UISceneAcknowledgement {
        let sceneID = try await NativeObservationDeadline.run(until: end, clock: SystemActionClock()) { [self] in
            try await waitForMount(managerID: ObjectIdentifier(manager))
        }
        return try await open(public: intent, sceneID: sceneID, managerID: ObjectIdentifier(manager),
                              expectedSnapshot: nil, origin: origin, until: end)
    }
    private func open(public intent: PublicNavigationSpecV2, sceneID: UIStableID, managerID: ObjectIdentifier,
                      expectedSnapshot: ActionBackendSnapshot?, origin: ActionOrigin,
                      until end: UInt64, requestID: UUID = UUID()) async throws -> UISceneAcknowledgement {
        guard let entry = scenes[sceneID], entry.managerID == managerID,
              entry.session.foreground, let binding = entry.publicBinding else { return .requiresForeground }
        let snapshot = try backend.currentBackendSnapshot()
        guard expectedSnapshot == nil || expectedSnapshot == snapshot else {
            throw UIRouteError(.staleState, "intent_source_generation_changed")
        }
        if let requested = intent.backend, requested != snapshot.backend { return .requiresBackendSwitch(requested) }
        guard contexts[sceneID] == nil else { throw UIRouteError(.unavailable, "native_scene_busy") }
        let invocation = ActionPortInvocation(requestId: requestID, snapshot: snapshot, deadlineUptimeNanoseconds: end)
        // Reserve actual native ownership before issuing/admitting authority;
        // R advances its epoch and invalidates any older mapping context.
        let retainedReader = try intent.content.map { content in
            try entry.session.retainReader(content, requestID: invocation.requestId) { [weak self, weak session = entry.session] in
                guard let self, let session else { return }
                try? invalidateContext(session)
            }
        }
        defer { if let retainedReader { entry.session.releaseReader(retainedReader) } }
        let context = context(sceneID: sceneID, origin: origin, snapshot: snapshot)
        try issue(context, sceneID: sceneID)
        defer { finish(context, sceneID: sceneID) }
        let admitted = try authority.admit(context: context, sceneID: sceneID)
        defer { authority.release(admitted) }
        let scene = try await directory.currentScene(sceneID: sceneID, context: context, invocation: invocation)
        let plan = try await registry.bindPublicV2(intent, scene: scene, context: context, invocation: invocation, core: core, host: binding)
        let result: UISceneAcknowledgement
        switch plan {
        case .surface(let prepared):
            result = await orchestrator.commitPrepared(prepared, admitted: admitted)
        case .reader(let route):
            guard retainedReader != nil, readerInvocations.count < 16, readerInvocations[invocation.requestId] == nil else {
                throw UIRouteError(.unavailable, "native_reader_admission_unavailable")
            }
            let pending = ReaderInvocation(route: route, context: context, sceneID: sceneID)
            readerInvocations[invocation.requestId] = pending
            defer { readerInvocations.removeValue(forKey: invocation.requestId) }
            let coreResult = try await orchestrator.executeReaderPlan(route, originalInvocation: invocation, admitted: admitted)
            guard coreResult.status == .completed, let receipt = pending.receipt else {
                throw UIRouteError(.failed, "canonical_reader_not_completed")
            }
            result = .acknowledged(receipt)
        }
        record(result)
        return result
    }

    private func receiveReader(_ reader: ActionOpenReaderCommand) async throws -> ActionUIAcknowledgement {
        guard let pending = readerInvocations[reader.invocation.requestId],
              pending.sceneID.rawValue == reader.sceneID, pending.route.route.content == reader.destination,
              contexts[pending.sceneID] == pending.context else { throw ActionPortError.staleState }
        let scene = try await directory.currentScene(sceneID: pending.sceneID, context: pending.context, invocation: reader.invocation)
        let command = try UISceneCommand(route: pending.route, invocation: reader.invocation, scene: scene)
        let result = await orchestrator.commit(command, readerCommand: reader, context: pending.context)
        guard case .acknowledged(let receipt) = result, let coreReceipt = receipt.coreReceipt else {
            if case .requiresForeground = result { return .requiresForeground }
            throw ActionPortError.unavailable
        }
        pending.receipt = receipt
        return .acknowledged(coreReceipt)
    }

    func open(url: URL, manager: iOSNavigationManager) async throws -> UISceneAcknowledgement? {
        #if DEBUG
        let scheme = "maktabah-debug"
        #else
        let scheme = "maktabah"
        #endif
        if URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath.hasPrefix("/v2/") == true {
            let intent = try NativePublicNavigationURLV2.decode(url, scheme: scheme, registry: registry)
            return try await open(public: intent, manager: manager, until: deadline())
        }
        guard case .route(let route) = try NativeRouteURL.decode(url, scheme: scheme, registry: registry) else { return nil }
        #if DEBUG
        OtzariaFileLogger.shared.log("[NativeSceneLifecycle] event=url pid=\(ProcessInfo.processInfo.processIdentifier)")
        #endif
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
        #if DEBUG
        OtzariaFileLogger.shared.log("[NativeSceneLifecycle] event=await-mount pid=\(ProcessInfo.processInfo.processIdentifier) matches=\(existing.count) foreground=\(existing.first?.session.foreground == true)")
        #endif
        if existing.count == 1, let value = existing.first, value.session.foreground { return value.session.sceneID }
        // A system URL can arrive after mount but before scenePhase becomes
        // active. Await only this manager's activation, within the original
        // URL deadline; never pick a different foreground window or re-admit.
        guard existing.count <= 1, mountWaiters[managerID] == nil, mountWaiters.count < 16 else { throw UIRouteError(.unavailable, "native_mount_admission_rejected") }
        let token = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                if Task.isCancelled { continuation.resume(throwing: CancellationError()) }
                else { mountWaiters[managerID] = .init(token: token, continuation: continuation) }
            }
        } onCancel: { [weak self] in
            Task { @MainActor in
                guard let self, self.mountWaiters[managerID]?.token == token else { return }
                self.mountWaiters.removeValue(forKey: managerID)?.continuation.resume(throwing: CancellationError())
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
            if let binding = entry.publicBinding {
                let variants = try await registry.discoverPublicV2(scene: scene, context: context, invocation: invocation,
                                                                  core: core, host: binding)
                for variant in variants where variant.destination.rawValue == "native.search"
                    && variant.presentation == .currentTab && variant.component?.rawValue == "native.search.query" {
                    values.append(.init(backend: snapshot.backend, destination: variant.destination,
                        title: "Search field".localized + " — " + windowLabel, sceneID: id, component: variant.component))
                }
            }
        }
        return values
    }
    /// System entity metadata executes only the original Core catalog actions.
    /// The observation carries the exact backend/generation/RPC epoch to native
    /// commit; it is not an authority and cannot be used to fabricate a receipt.
    private func readerIntentMetadata(_ request: ActionRequest) async throws -> NativeReaderIntentService.CoreObservation {
        guard ["catalog.resolveWork", "catalog.resolveReference"].contains(request.action) else {
            throw UIRouteError(.notSupported, "intent_metadata_action_not_supported")
        }
        let snapshot = try backend.currentBackendSnapshot()
        if let requested = request.expectedBackend, requested != snapshot.backend {
            throw UIRouteError(.requiresBackendSwitch, "backend_selection_required")
        }
        let request = ActionRequest(requestId: request.requestId, action: request.action, arguments: request.arguments,
            expectedBackend: snapshot.backend, expectedGeneration: snapshot.generation, requestedPresentation: .headless)
        let context = ActionExecutionContext(subjectID: "maktabah.intent.metadata", origin: .appIntent,
            allowedBackends: [snapshot.backend], scopes: [.discovery])
        let result = await core.execute(request, context: context)
        try Task.checkCancellation()
        guard try backend.currentBackendSnapshot() == snapshot else {
            throw UIRouteError(.staleState, "intent_source_generation_changed")
        }
        return .init(result: result, snapshot: snapshot)
    }
    private func openReaderIntent(_ request: NativeReaderIntentService.OpenRequest) async throws -> UISceneAcknowledgement {
        // Re-resolve the explicit user-selected window. Never pick a first scene
        // or open another one when a cached system entity has become stale.
        let windows = try await destinations().filter {
            $0.destination.rawValue == "native.library" && $0.id == request.windowIdentifier
        }
        guard windows.count == 1, let window = windows.first, let entry = scenes[window.sceneID],
              entry.session.foreground, entry.session.mounted else {
            throw UIRouteError(.staleState, "intent_window_no_longer_available")
        }
        guard window.backend == request.locator.backend,
              try backend.currentBackendSnapshot() == request.expectedSnapshot else {
            throw UIRouteError(.staleState, "intent_source_generation_changed")
        }
        // Use R's ORIGINAL bounded-section/focus resolver, then the existing
        // public binder and Core reader.open with the original retained owner.
        let native = try ActionAppIdentityBridge.appLocator(request.locator)
        let resolved = ReaderDestinationResolver.resolve(locator: native)
        let content = ActionReaderDestination(sectionLocator: try ActionAppIdentityBridge.actionRef(resolved.sectionLocator),
            focusLocator: try resolved.focusLocator.map(ActionAppIdentityBridge.actionRef),
            presentationMode: request.newTab ? .newTab : .sameTab)
        let intent = PublicNavigationSpecV2(destination: UIDestinationID(rawValue: "native.reader")!,
            backend: window.backend, content: content, presentation: request.newTab ? .newTab : .currentTab)
        return try await open(public: intent, sceneID: window.sceneID, managerID: entry.managerID,
            expectedSnapshot: request.expectedSnapshot, origin: .appIntent, until: deadline())
    }
    func installIntentDependency() {
        guard !intentsInstalled else { return }
        let service = NativeIntentService(discover: { [self] in try await destinations() }, navigate: { [self] in try await open(destination: $0) })
        AppDependencyManager.shared.add(dependency: service)
        let readerService = NativeReaderIntentService(execute: { [self] in try await readerIntentMetadata($0) },
            navigate: { [self] in try await openReaderIntent($0) })
        AppDependencyManager.shared.add(dependency: readerService)
        intentsInstalled = true
    }
    func currentScene(sceneID: UIStableID, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws -> UISceneSnapshot {
        try await directory.currentScene(sceneID: sceneID, context: context, invocation: invocation)
    }
    func assess(_ descriptor: UIDestinationDescriptor, scene: UISceneSnapshot, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws -> UIRouteEligibility {
        let current = try await directory.currentScene(sceneID: scene.sceneID, context: context, invocation: invocation)
        guard current == scene, let entry = scenes[scene.sceneID] else { throw UIRouteError(.staleState, "scene_or_backend_changed") }
        let supported = descriptor.id.rawValue == "native.settings" || entry.session.isRootAvailable(descriptor.id)
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
        if receipt.route.destination.rawValue == "native.search",
           receipt.route.focus == FocusSpec(kind: .component, anchor: UIDestinationID(rawValue: "native.search.query")!) {
            OtzariaFileLogger.shared.log("[NativeFocusReceipt] request=\(receipt.requestId) scene=\(receipt.sceneID.rawValue) component=native.search.query")
        }
        OtzariaFileLogger.shared.log("[NativeNavigationReceipt] request=\(receipt.requestId) scene=\(receipt.sceneID.rawValue) backend=\(receipt.backendSnapshot.backend.rawValue) generation=\(receipt.backendSnapshot.generation) epoch=\(receipt.backendSnapshot.rpcEpoch.map(String.init) ?? "none") revision=\(receipt.basedOnSceneRevision)->\(receipt.appliedSceneRevision) destination=\(receipt.route.destination.rawValue) presentation=\(receipt.route.presentation.kind.rawValue)")
    }
}

/// Only forwards Core's original, opaque, one-use reader command to its
/// retained native owner. It cannot create grants, resolve or mint receipts.
@MainActor private final class MaktabahNativeReaderCommandSink: ActionUICommandSink {
    var deliver: (@MainActor @Sendable (ActionOpenReaderCommand) async throws -> ActionUIAcknowledgement)?
    func open(_ command: ActionOpenReaderCommand) async throws -> ActionUIAcknowledgement {
        guard let deliver else { throw ActionPortError.unavailable }
        return try await deliver(command)
    }
}
#endif
