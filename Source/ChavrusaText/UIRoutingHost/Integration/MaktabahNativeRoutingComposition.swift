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
final class MaktabahNativeRoutingComposition: UIDestinationEligibilityPort, OtzariaHanlinNavigationAuthority {
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
        weak var manager: iOSNavigationManager?
        let session: MaktabahNativeSceneSession
        let lease: NativeNavigationAuthority.Lease
        let windowNumber: Int
        var publicBinding: MaktabahNativePublicBindingAdapter? = nil
        let hanlinSceneID = UUID()
        var hanlin: HanlinRegistration?
        // Remains source-owned while the old chat is dismissed but its one-use
        // read consent has not yet been consumed. Foreground/source transitions
        // must revoke it even when the live SDK registration is already gone.
        var pendingHanlinReadConsent: HanlinReadConsent?
    }
    private var scenes: [UIStableID: Registration] = [:]
    private var contexts: [UIStableID: ActionExecutionContext] = [:]
    // Ephemeral association to the actual native registration, not another
    // account, workspace, permission store or scene-selection authority.
    fileprivate struct HanlinSourceObservation: Equatable {
        let backend: ActionBackendSnapshot
        let source: ObjectIdentifier
        let epoch: StudyWorkspaceMappingEpoch
        let projection: StudyWorkspaceMappingProjection
        let readerContent: ActionReaderDestination?
        let currentWorkReadSource: MaktabahNativeSceneProjection.HanlinCurrentWorkReadSource?
        let selectedRange: UIUTF16Range?
        let locale: String
    }
    private struct HanlinRegistration {
        let session: HanlinHostSession
        let binding: OtzariaHanlinBinding
        let observed: HanlinSourceObservation
        let invalidated: @MainActor () -> Void
        let readScope: OtzariaHanlinCurrentWorkReadScope?
        let requiredConfigurationID: UUID?
        var configuredConnectionID: UUID?
        var navigation: HanlinNavigationRequest?
    }
    /// Only the real native Connect action constructs this transient witness.
    /// It has no Codable/store path and cannot be supplied by the SDK/model.
    @MainActor final class HanlinReadConsent {
        fileprivate let witness: OtzariaHanlinCurrentWorkReadConsent<HanlinSourceObservation>
        private let invalidated: @MainActor () -> Void
        private var notified = false
        var originalSession: HanlinHostSession { witness.session }
        var scope: OtzariaHanlinCurrentWorkReadScope { witness.scope }
        var configurationID: UUID { witness.configurationID }
        fileprivate init(session: HanlinHostSession, scope: OtzariaHanlinCurrentWorkReadScope,
                         configurationID: UUID, observed: HanlinSourceObservation,
                         invalidated: @escaping @MainActor () -> Void) {
            witness = .init(session: session, scope: scope, configurationID: configurationID, source: observed)
            self.invalidated = invalidated
        }
        func revoke() { witness.revoke() }
        fileprivate func invalidate() {
            witness.revoke()
            guard !notified else { return }
            notified = true
            invalidated()
        }
    }
    private struct HanlinNavigationRequest {
        let destination: HanlinHostDestination
        let intent: PublicNavigationSpecV2
        let deadline: UInt64
    }

    private struct MountWaiter {
        let token: UUID
        let continuation: CheckedContinuation<UIStableID, any Error>
    }
    private var mountWaiters: [ObjectIdentifier: MountWaiter] = [:]
    private var intentsInstalled = false
    #if DEBUG
    private var acceptanceReaderIntentService: NativeReaderIntentService?
    private var semanticIntentAcceptanceObserver: (@MainActor (NativeReaderIntentService.OpenRequest, ActionSemanticJourneyResult, [UISceneReceipt]) -> Void)?
    #endif

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
    private final class CommentaryInvocation {
        let sceneID: UIStableID
        let context: ActionExecutionContext
        let observation: HanlinSourceObservation
        var cleanup: (@MainActor () -> Void)?
        init(sceneID: UIStableID, context: ActionExecutionContext, observation: HanlinSourceObservation) {
            self.sceneID = sceneID; self.context = context; self.observation = observation
        }
    }
    private var commentaryInvocations: [UUID: CommentaryInvocation] = [:]

    private final class NoteDraftInvocation {
        let sceneID: UIStableID
        let context: ActionExecutionContext
        let observation: HanlinSourceObservation
        let request: ActionNoteDraftRequest
        var binding: MaktabahNativeNoteDraftBinding?
        var command: UISceneCommand?
        var admitted: ActionNavigationState?
        var receipt: UISceneReceipt?
        var cleanup: (@MainActor () -> Void)?
        init(sceneID: UIStableID, context: ActionExecutionContext, observation: HanlinSourceObservation,
             request: ActionNoteDraftRequest) {
            self.sceneID = sceneID; self.context = context; self.observation = observation; self.request = request
        }
    }
    private var noteDraftInvocations: [UUID: NoteDraftInvocation] = [:]
    private final class SearchResultsInvocation {
        let sceneID: UIStableID
        let context: ActionExecutionContext
        let observation: HanlinSourceObservation
        let query: ActionSearchResultsQuery
        var command: UISceneCommand?
        var admission: ActionNavigationState?
        var binding: MaktabahNativeSearchResultsBinding?
        var receipt: UISceneReceipt?
        var cleanup: (@MainActor () -> Void)?
        init(sceneID: UIStableID, context: ActionExecutionContext, observation: HanlinSourceObservation,
             query: ActionSearchResultsQuery) {
            self.sceneID = sceneID; self.context = context; self.observation = observation; self.query = query
        }
    }
    private var searchResultsInvocations: [UUID: SearchResultsInvocation] = [:]

    /// One bounded compound call retains the original source observation. Only
    /// an acknowledged commentary reader may advance it to the new tab.
    private final class SemanticJourneyOwner {
        let sceneID: UIStableID
        let managerID: ObjectIdentifier
        let context: ActionExecutionContext
        var observation: HanlinSourceObservation
        let didAcknowledge: (@MainActor (UISceneReceipt) -> Void)?
        init(sceneID: UIStableID, managerID: ObjectIdentifier, context: ActionExecutionContext,
             observation: HanlinSourceObservation, didAcknowledge: (@MainActor (UISceneReceipt) -> Void)? = nil) {
            self.sceneID = sceneID; self.managerID = managerID
            self.context = context; self.observation = observation
            self.didAcknowledge = didAcknowledge
        }
    }
    private struct SemanticJourneyInvocation {
        let owner: SemanticJourneyOwner
        let request: ActionRequest
    }


    init(backend: any ActionSynchronousBackendStatePort & ActionResolverDataPort & ActionSearchPort) throws {
        self.backend = backend
        authority = try NativeNavigationAuthority()
        directory = try NativeSceneDirectory(authority: backend)
        let readerSink = MaktabahNativeReaderCommandSink()
        core = try ActionExecutor(state: backend, resolver: CatalogActionResolver(data: backend, state: backend), search: backend,
                                  ui: readerSink, navigationAuthority: authority)
        orchestrator = try NativeSceneNavigationOrchestrator(core: core, backend: backend, authority: authority, directory: directory)
        func id(_ value: String) -> UIDestinationID { UIDestinationID(rawValue: value)! }
        let workspaceText = StudyWorkspaceText(locale: .current)
        registry = try UIDestinationRegistry(descriptors: [
            .init(id: id("native.library"), title: "Library".localized, implementation: .implemented,
                  supportedBackends: ActionBackendID.allCases, presentations: [.currentTab],
                  anchors: MaktabahNativeLibraryComponents.descriptors.map(\.anchor), requiredCoreActions: [], allowsPublicRoute: true,
                  publicNavigationV2: .init(rules: [.init(presentation: .currentTab,
                      components: MaktabahNativeLibraryComponents.descriptors.map(\.anchor))])),
            .init(id: id("native.reader.toc"), title: "Table of Contents".localized, implementation: .implemented,
                  supportedBackends: ActionBackendID.allCases, presentations: [.currentTab],
                  anchors: MaktabahNativeTOCComponents.descriptors.map(\.anchor), requiredCoreActions: [], allowsPublicRoute: true,
                  publicNavigationV2: .init(rules: [.init(presentation: .currentTab,
                      components: MaktabahNativeTOCComponents.descriptors.map(\.anchor))])),
            .init(id: id("native.history"), title: "History".localized, implementation: .implemented,
                  supportedBackends: ActionBackendID.allCases, presentations: [.currentTab], requiredCoreActions: [], allowsPublicRoute: true,
                  publicNavigationV2: .init(rules: [.init(presentation: .currentTab)])),
            .init(id: id("native.search"), title: "Search".localized, implementation: .implemented,
                  supportedBackends: ActionBackendID.allCases, presentations: [.currentTab], anchors: [id("native.search.query")],
                  requiredCoreActions: [], allowsPublicRoute: true,
                  publicNavigationV2: .init(rules: [.init(presentation: .currentTab, components: [id("native.search.query")])])),
            .init(id: id("native.search.results"), title: "Search results".localized, implementation: .implemented,
                  supportedBackends: ActionBackendID.allCases, presentations: [.currentTab],
                  requiredCoreActions: ["search.openResults"]),
            .init(id: id("native.annotations"), title: "Annotations".localized, implementation: .implemented,
                  supportedBackends: ActionBackendID.allCases, presentations: [.currentTab], requiredCoreActions: [], allowsPublicRoute: true,
                  publicNavigationV2: .init(rules: [.init(presentation: .currentTab)])),
            .init(id: id("native.settings"), title: "Settings".localized, implementation: .implemented,
                  supportedBackends: ActionBackendID.allCases, presentations: [.sheet],
                  anchors: MaktabahNativeSettingsComponents.descriptors.map(\.anchor), requiredCoreActions: [],
                  publicNavigationV2: .init(rules: [.init(presentation: .sheet,
                      components: MaktabahNativeSettingsComponents.descriptors.map(\.anchor))])),
            .init(id: MaktabahNativeWorkspacePresentationBinding.Parent.profiles.destination,
                  title: workspaceText("Study profile management", "ניהול פרופילי לימוד"), implementation: .implemented,
                  supportedBackends: ActionBackendID.allCases, presentations: [.sheet],
                  anchors: MaktabahNativeWorkspaceComponents.Profiles.allCases.map(\.id), requiredCoreActions: [],
                  publicNavigationV2: .init(rules: [.init(presentation: .sheet,
                      components: MaktabahNativeWorkspaceComponents.Profiles.allCases.map(\.id))])),
            .init(id: MaktabahNativeWorkspacePresentationBinding.Parent.overview.destination,
                  title: workspaceText("Study workspace overview", "סקירת סביבת הלימוד"), implementation: .implemented,
                  supportedBackends: ActionBackendID.allCases, presentations: [.sheet],
                  anchors: MaktabahNativeWorkspaceComponents.Overview.allCases.map(\.id), requiredCoreActions: [],
                  publicNavigationV2: .init(rules: [.init(presentation: .sheet,
                      components: MaktabahNativeWorkspaceComponents.Overview.allCases.map(\.id))])),
            .init(id: id("native.reader.inspector"), title: "Study Tools".localized, implementation: .implemented,
                  supportedBackends: ActionBackendID.allCases, presentations: [.inspector], requiredCoreActions: [],
                  publicNavigationV2: .init(rules: [.init(presentation: .inspector)])),
            .init(id: id("native.reader.noteDraft"), title: "Note Draft".localized, implementation: .implemented,
                  supportedBackends: ActionBackendID.allCases, presentations: [.sheet],
                  requiredCoreActions: ["notes.prepareDraft"]),
            .init(id: id("native.reader"), title: "Reader".localized, implementation: .implemented,
                  supportedBackends: ActionBackendID.allCases, presentations: [.currentTab, .newTab],
                  requiredCoreActions: ["reader.open"], requiresContent: true,
                  publicNavigationV2: .init(rules: [.init(presentation: .currentTab), .init(presentation: .newTab)]))
        ])
        #if DEBUG
        let diagnosticArguments = ProcessInfo.processInfo.arguments
        func diagnosticValue(_ flag: String) -> String? {
            guard let index = diagnosticArguments.firstIndex(of: flag),
                  diagnosticArguments.indices.contains(index + 1) else { return nil }
            return diagnosticArguments[index + 1]
        }
        if OtzariaDataProfileRegistry.activeProfileID == "miniTest10",
           diagnosticValue("-nativeActionAcceptanceKind") == "commentary",
           let rawToken = diagnosticValue("-nativeActionAcceptanceToken"), UUID(uuidString: rawToken) != nil {
            orchestrator.debugFailureObserver = { observation in
                let dispatched = observation.didDispatch.map { $0 ? "true" : "false" } ?? "unobserved"
                let coreStarted = observation.coreStarted.map { $0 ? "true" : "false" } ?? "unobserved"
                // Capture monotonic values in the original catch, before the
                // existing serial file logger asynchronously writes its Date.
                OtzariaFileLogger.shared.log("[NativeReaderFailureObservation] boundary=\(observation.boundary.rawValue) status=\(observation.status.rawValue) code=\(observation.code) didDispatch=\(dispatched) coreStarted=\(coreStarted) taskCancelled=\(observation.taskCancelled) deadlineExpired=\(observation.deadlineExpired) uptimeNanoseconds=\(observation.uptimeNanoseconds)")
            }
        }
        #endif
        readerSink.deliver = { [weak self] command in
            guard let self else { throw ActionPortError.unavailable }
            return try await receiveReader(command)
        }
        readerSink.searchResultsAvailable = { [weak self] sceneID in
            guard let self, let id = UIStableID(rawValue: sceneID), let entry = scenes[id] else { return false }
            return entry.session.canPrepareSearchResults()
        }
        readerSink.prepareSearch = { [weak self] query, context, invocation in
            guard let self else { throw ActionPortError.unavailable }
            try await prepareSearchResults(query, context: context, invocation: invocation)
        }
        readerSink.deliverSearch = { [weak self] command in
            guard let self else { throw ActionPortError.unavailable }
            return try await receiveSearchResults(command)
        }
        readerSink.completeSearch = { [weak self] command, receipt in
            guard let self else { throw ActionPortError.unavailable }
            try validateSearchResultsCompletion(command, receipt: receipt)
        }
        readerSink.prepareCommentary = { [weak self] destination, context, invocation in
            guard let self else { throw ActionPortError.unavailable }
            try await prepareCommentaryReader(destination, context: context, invocation: invocation)
        }
        readerSink.noteDraftAvailable = { [weak self] sceneID in
            guard let self, let id = UIStableID(rawValue: sceneID), let entry = scenes[id] else { return false }
            return entry.session.canPrepareNoteDraft()
        }
        readerSink.prepareNote = { [weak self] draft, context, invocation in
            guard let self else { throw ActionPortError.unavailable }
            try await prepareNoteDraft(draft, context: context, invocation: invocation)
        }
        readerSink.presentNote = { [weak self] command in
            guard let self else { throw ActionPortError.unavailable }
            return try await receiveNoteDraft(command)
        }
        readerSink.validateNote = { [weak self] receipt, invocation in
            guard let self else { throw ActionPortError.unavailable }
            try validateNoteDraftCompletion(receipt, invocation: invocation)
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
        session.configureComponentValidation { [weak self, weak session] command in
            guard let self, let session, command.scene.sceneID == sceneID else {
                throw UIRouteError(.staleState, "scene_lifetime_changed")
            }
            let original = try authority.navigationState(sceneID: sceneID.rawValue)
            guard original.active, original.lifetimeID == lease.lifetimeID,
                  contexts[sceneID] == original.context else {
                throw UIRouteError(.staleState, "native_context_changed")
            }
            // This is read-only liveness of an ALREADY COMMITTED UI projection,
            // not another authorization, preparation, admission or native receipt.
            return { [weak self, weak session] in
                try Task.checkCancellation()
                guard let self, let session,
                      SystemActionClock().now() < command.invocation.deadlineUptimeNanoseconds,
                      let entry = scenes[sceneID], entry.session === session, entry.lease == lease,
                      session.mounted, session.foreground else {
                    throw UIRouteError(.staleState, "scene_lifetime_changed")
                }
                let snapshot = try backend.currentBackendSnapshot()
                let current = try authority.navigationState(sceneID: sceneID.rawValue)
                guard snapshot == command.invocation.snapshot, current.active,
                      current.context == original.context, contexts[sceneID] == original.context,
                      current.lifetimeID == original.lifetimeID,
                      current.authorityRevision == original.authorityRevision else {
                    throw UIRouteError(.staleState, "native_component_source_changed")
                }
            }
        }
        do {
            try session.mount { [weak self, weak session] context in
                guard let self, let session, session.mounted, contexts[sceneID] == context, context.foregroundSceneID == sceneID.rawValue,
                      context.subjectID == "maktabah.scene:" + sceneID.rawValue else { throw UIRouteError(.staleState, "native_scene_context_changed") }
            }
            try orchestrator.register(session)
            scenes[sceneID] = .init(managerID: ObjectIdentifier(manager), manager: manager, session: session, lease: lease, windowNumber: windowNumber)
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
        invalidateHanlin(sceneID: session.sceneID)
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
        invalidateHanlin(sceneID: session.sceneID)
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
            }, validateParentSource: { [weak session] destination, requestID in
                guard let session else { throw ActionPortError.unavailable }
                try session.validateParentSource(destination: destination, requestID: requestID)
            }, validateComponentSource: { [weak session] destination, anchor, requestID in
                guard let session else { throw ActionPortError.unavailable }
                try session.validateComponentSource(destination: destination, anchor: anchor, requestID: requestID)
            }, invalidated: { [weak self, weak session] in
                guard let self, let session, self.scenes[session.sceneID]?.session === session else { return }
                self.contexts.removeValue(forKey: session.sceneID)
                self.invalidateHanlin(sceneID: session.sceneID)
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
            invalidateHanlin(sceneID: session.sceneID)
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
        invalidateHanlin(sceneID: session.sceneID)
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
    /// The existing profile/group and native mapping own the SDK namespace.
    /// The scene-owned chat composes the original SDK; this authority exposes
    /// metadata/navigation by default. Only the explicit current-work connection
    /// consent below can issue a separate bounded search context.
    func makeHanlinHostSession(manager: iOSNavigationManager, conversationID: UUID,
        readConnection: (consent: HanlinReadConsent, dismissedSessionID: UUID, configurationID: UUID)? = nil,
        invalidated: @escaping @MainActor () -> Void = {}) throws
        -> (host: OtzariaHanlinHostAdapter, session: HanlinHostSession) {
        try Task.checkCancellation()
        let matches = scenes.filter { $0.value.managerID == ObjectIdentifier(manager) }
        guard matches.count == 1, let (sceneID, entry) = matches.first else { throw HanlinHostError.invalidContext }
        return try issueHanlinHostSession(sceneID: sceneID, entry: entry,
            conversationID: conversationID, readConnection: readConnection, invalidated: invalidated)
    }

    private func issueHanlinHostSession(sceneID: UIStableID, entry: Registration,
        conversationID: UUID,
        readConnection: (consent: HanlinReadConsent, dismissedSessionID: UUID, configurationID: UUID)? = nil,
        invalidated: @escaping @MainActor () -> Void)
        throws -> (host: OtzariaHanlinHostAdapter, session: HanlinHostSession) {
        let observed = try hanlinSource(sceneID: sceneID, entry: entry)
        let namespace = try HanlinConversationNamespace(app: "otzaria",
            account: observed.projection.profileID.uuidString,
            workspace: observed.projection.groupID.uuidString, space: observed.backend.backend.rawValue)
        let readScope: OtzariaHanlinCurrentWorkReadScope?
        if let readConnection {
            OtzariaHanlinConnectionDiagnostic.record(.consentConsumeEntered)
            guard entry.pendingHanlinReadConsent === readConnection.consent,
                  readConnection.consent.originalSession.conversationID == conversationID,
                  readConnection.consent.originalSession.context.sceneID == entry.hanlinSceneID else {
                readConnection.consent.revoke()
                throw HanlinHostError.staleContext
            }
            readScope = try readConnection.consent.witness.consume(
                dismissedSessionID: readConnection.dismissedSessionID, currentSource: observed,
                namespace: namespace, configurationID: readConnection.configurationID)
            OtzariaHanlinConnectionDiagnostic.record(.consentConsumed)
            scenes[sceneID]?.pendingHanlinReadConsent = nil
        } else { readScope = nil }
        // Native UIKit identifiers remain strings. This UUID belongs only to the
        // SDK association and is discarded with this exact native registration.
        let objectReference = try observed.readerContent.map { content in
            let current = ActionReaderDestination(sectionLocator: content.sectionLocator,
                focusLocator: content.focusLocator, presentationMode: .sameTab)
            return try NativePublicNavigationURLV2.encode(.init(
                destination: UIDestinationID(rawValue: "native.reader")!, backend: observed.backend.backend,
                content: current, presentation: .currentTab), registry: registry).absoluteString
        }
        let sdkContext = HanlinHostContext(namespace: namespace, sceneID: entry.hanlinSceneID,
            generation: UUID(), objectReference: objectReference, sourceRevision: "backend:" + String(observed.backend.generation)
                + ";rpc:" + (observed.backend.rpcEpoch.map(String.init) ?? "none")
                + ";mapping:" + observed.epoch.sourceID.uuidString + ":" + String(observed.epoch.revision)
                + ";tab:" + (observed.projection.activeTabID?.uuidString ?? "none")
                + (readConnection.map { ";read-configuration:" + $0.configurationID.uuidString } ?? ""),
            localeIdentifier: observed.locale)
        let metadataContext = context(sceneID: sceneID, origin: .internalAI, snapshot: observed.backend)
        let binding = OtzariaHanlinBinding(context: sdkContext, executionContext: metadataContext,
            backend: observed.backend, catalogRevision: .init(observed.backend.generation),
            availableReadActions: OtzariaHanlinHostAdapter.metadataReadActions
                .union(readScope == nil ? [] : ["search.query"]),
            searchExecutionContext: try readScope?.searchContext(from: metadataContext))
        let session = HanlinHostSession(conversationID: conversationID, context: sdkContext)
        // Replay/cancellation admission belongs to this exact SDK session.
        // Reuse the one original Core, not a process-wide transport budget that
        // can exhaust unrelated scenes or later conversations.
        let adapter = try OtzariaHanlinHostAdapter(core: core, authority: self)
        invalidateHanlin(sceneID: sceneID)
        scenes[sceneID]?.hanlin = .init(session: session, binding: binding, observed: observed,
            invalidated: invalidated, readScope: readScope,
            requiredConfigurationID: readConnection?.configurationID, configuredConnectionID: nil, navigation: nil)
        return (adapter, session)
    }

    /// Source metadata labels a bounded offer; it does not itself grant reading.
    /// Embedded search cannot scope by work; other backends are not enabled here.
    func hanlinCurrentWorkReadOffer(manager: iOSNavigationManager, session: HanlinHostSession)
        throws -> OtzariaHanlinCurrentWorkReadScope? {
        let (_, entry, active) = try hanlinRegistration(for: session.context)
        guard active.session == session, entry.managerID == ObjectIdentifier(manager) else { throw HanlinHostError.staleContext }
        guard active.observed.backend.backend == .otzaria,
              let source = active.observed.currentWorkReadSource,
              let tabID = active.observed.projection.activeTabID, manager.activeTabId == tabID,
              let mapped = active.observed.projection.targets[tabID],
              mapped.backend == .otzaria, mapped.readerOwner == source.readerOwner else { return nil }
        let tabs = manager.openTabs.filter { $0.id == tabID }
        guard tabs.count == 1, let tab = tabs.first, ObjectIdentifier(tab.viewModel) == source.readerOwner,
              let locator = tab.book.backendLocator, locator.backend == .otzaria,
              mapped.bookID == tab.book.id, mapped.workKey == locator.workKey,
              locator.workKey == source.loaded.sectionLocator.workKey else { return nil }
        return try .init(workRef: .init(backend: .otzaria, workKey: locator.workKey), title: tab.book.title)
    }

    func makeHanlinCurrentWorkReadConsent(manager: iOSNavigationManager, session: HanlinHostSession,
        displayedScope: OtzariaHanlinCurrentWorkReadScope, configurationID: UUID,
        invalidated: @escaping @MainActor () -> Void) throws -> HanlinReadConsent {
        let (sceneID, entry, active) = try hanlinRegistration(for: session.context)
        guard active.session == session, active.readScope == nil, active.configuredConnectionID == nil,
              entry.pendingHanlinReadConsent == nil,
              try hanlinCurrentWorkReadOffer(manager: manager, session: session) == displayedScope else {
            throw HanlinHostError.staleContext
        }
        let consent = HanlinReadConsent(session: session, scope: displayedScope,
            configurationID: configurationID, observed: active.observed, invalidated: invalidated)
        scenes[sceneID]?.pendingHanlinReadConsent = consent
        return consent
    }

    func hanlinCurrentWorkReadScope(for session: HanlinHostSession) throws -> OtzariaHanlinCurrentWorkReadScope? {
        let (_, _, active) = try hanlinRegistration(for: session.context)
        guard active.session == session else { throw HanlinHostError.staleContext }
        return active.readScope
    }

    /// The exact immutable native connection request owns this nonce. It is
    /// activated only after local original-engine construction and before the
    /// original SDK session exists. No provider request is made by this method.
    func hanlinConnectionConfigured(_ configurationID: UUID, session: HanlinHostSession) throws {
        let (sceneID, _, active) = try hanlinRegistration(for: session.context)
        guard active.session == session,
              active.configuredConnectionID == nil || active.configuredConnectionID == configurationID,
              active.requiredConfigurationID == nil || active.requiredConfigurationID == configurationID else {
            invalidateHanlin(sceneID: sceneID)
            throw HanlinHostError.staleContext
        }
        scenes[sceneID]?.hanlin?.configuredConnectionID = configurationID
    }

    private func requireHanlinReadConnection(_ active: HanlinRegistration) throws {
        if let required = active.requiredConfigurationID,
           active.configuredConnectionID != required { throw HanlinHostError.denied }
    }

    private func hanlinSource(sceneID: UIStableID, entry: Registration, allowingHanlinSession: UUID? = nil) throws -> HanlinSourceObservation {
        guard entry.session.mounted, entry.session.foreground,
              entry.session.isStudyChatContextReady(allowing: allowingHanlinSession), let publicBinding = entry.publicBinding,
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
        let content = try entry.session.surface(.reader)?.content.map {
            ActionReaderDestination(sectionLocator: $0.sectionLocator, focusLocator: $0.focusLocator,
                presentationMode: .sameTab)
        }
        return .init(backend: snapshot, source: ObjectIdentifier(mapping.source),
            epoch: mapping.epoch, projection: mapping.projection, readerContent: content,
            currentWorkReadSource: try entry.session.hanlinCurrentWorkReadSource(),
            selectedRange: try entry.session.hanlinSelectionRange(), locale: Locale.current.identifier)
    }

    private func hanlinRegistration(for context: HanlinHostContext) throws -> (UIStableID, Registration, HanlinRegistration) {
        try Task.checkCancellation()
        let matches = scenes.filter { $0.value.hanlin?.binding.context == context }
        guard matches.count == 1, let (sceneID, entry) = matches.first, let active = entry.hanlin else {
            throw HanlinHostError.staleContext
        }
        do {
            let observed = try hanlinSource(sceneID: sceneID, entry: entry, allowingHanlinSession: active.session.id)
            guard observed == active.observed else {
                OtzariaHanlinConnectionDiagnostic.record(.sourceComparisonRejected, flags: [
                    .sameBackend: observed.backend == active.observed.backend,
                    .sameMappingSource: observed.source == active.observed.source,
                    .sameMappingEpoch: observed.epoch == active.observed.epoch,
                    .sameWorkspaceProjection: observed.projection == active.observed.projection,
                    .sameReaderContent: observed.readerContent == active.observed.readerContent,
                    .sameReadSource: observed.currentWorkReadSource == active.observed.currentWorkReadSource,
                    .sameSelection: observed.selectedRange == active.observed.selectedRange,
                    .sameLocale: observed.locale == active.observed.locale,
                ])
                throw HanlinHostError.staleContext
            }
        } catch {
            OtzariaHanlinConnectionDiagnostic.record(.sourceValidationFailed,
                reason: OtzariaHanlinConnectionDiagnostic.reason(for: error))
            invalidateHanlin(sceneID: sceneID)
            throw HanlinHostError.staleContext
        }
        return (sceneID, entry, active)
    }

    func current(for session: HanlinHostSession) async throws -> OtzariaHanlinBinding {
        let (_, _, active) = try hanlinRegistration(for: session.context)
        guard active.session == session else { throw HanlinHostError.staleContext }
        try requireHanlinReadConnection(active)
        return active.binding
    }

    func current(for context: HanlinHostContext) async throws -> OtzariaHanlinBinding {
        let active = try hanlinRegistration(for: context).2
        try requireHanlinReadConnection(active)
        return active.binding
    }

    private func invalidateHanlin(sceneID: UIStableID) {
        let prior = scenes[sceneID]?.hanlin
        let pending = scenes[sceneID]?.pendingHanlinReadConsent
        scenes[sceneID]?.hanlin = nil
        scenes[sceneID]?.pendingHanlinReadConsent = nil
        pending?.invalidate()
        prior?.invalidated()
    }

    func validateHanlinHostSession(_ session: HanlinHostSession) throws {
        guard try hanlinRegistration(for: session.context).2.session == session else {
            throw HanlinHostError.staleContext
        }
    }

    /// The presentation has already revoked itself synchronously. Retiring its
    /// exact registration must not notify it as a separate foreign invalidation.
    func closeHanlinHostSession(_ session: HanlinHostSession) {
        guard let (sceneID, _) = scenes.first(where: { $0.value.hanlin?.session == session }) else { return }
        scenes[sceneID]?.hanlin = nil
    }

    func open(_ destination: HanlinHostDestination, binding: OtzariaHanlinBinding) async throws -> HanlinHostNavigationResult {
        let (sceneID, _, active) = try hanlinRegistration(for: destination.context)
        guard active.binding == binding, destination.blockReference == nil,
              let url = URL(string: destination.objectReference) else { throw HanlinHostError.invalidArguments }
        let intent = try NativePublicNavigationURLV2.decode(url, registry: registry)
        guard active.navigation == nil else { throw HanlinHostError.duplicateInvocation }
        // The actual chat sheet currently covers the native destination. Queue
        // this exact route without a UI effect; the app must revoke/dismiss the
        // SDK owner before consuming its original native handoff.
        scenes[sceneID]?.hanlin?.navigation = .init(destination: destination, intent: intent, deadline: deadline())
        return .queued(requestID: destination.requestID, context: destination.context)
    }

    /// Derive a source button only from the original SDK's correlated Core
    /// receipt. Use R's existing section/focus resolver and the public codec;
    /// model prose never manufactures a trusted locator or private route.
    func hanlinSourceDestination(_ event: HanlinHostResultEvent, session: HanlinHostSession) throws -> URL? {
        let (_, _, active) = try hanlinRegistration(for: session.context)
        guard active.session == session, event.call.session == session, event.result.context == session.context else {
            throw HanlinHostError.staleContext
        }
        guard event.call.logicalToolID.localToolID.rawValue == "catalog.resolve-reference",
              event.result.effectState == .confirmedNoEffect,
              case .completed(let contents) = event.result.result.outcome else { return nil }
        guard contents.count == 1, case .text(let text) = contents[0] else { throw HanlinHostError.resultMismatch }
        let result = try JSONDecoder().decode(ActionResult.self, from: Data(text.utf8))
        guard result.requestId == event.resultID, result.action == "catalog.resolveReference",
              result.status == .completed, result.backend == active.binding.backend.backend,
              result.backendGeneration == active.binding.backend.generation,
              let locator = try result.data?["locator"]?.decoded(as: ActionTextRef.self),
              locator.backend == active.binding.backend.backend else { throw HanlinHostError.resultMismatch }
        let native = try ActionAppIdentityBridge.appLocator(locator)
        let resolved = ReaderDestinationResolver.resolve(locator: native)
        let content = ActionReaderDestination(sectionLocator: try ActionAppIdentityBridge.actionRef(resolved.sectionLocator),
            focusLocator: try resolved.focusLocator.map(ActionAppIdentityBridge.actionRef), presentationMode: .sameTab)
        let intent = PublicNavigationSpecV2(destination: UIDestinationID(rawValue: "native.reader")!,
            backend: active.binding.backend.backend, content: content, presentation: .currentTab)
        return try NativePublicNavigationURLV2.encode(intent, registry: registry)
    }

    /// Called only after the original chat sheet has actually dismissed. The
    /// original Core and scene orchestrator still own the one native mutation.
    func openWithContextTransition(_ destination: HanlinHostDestination,
        session: HanlinHostSession, binding: OtzariaHanlinBinding) async throws -> HanlinHostNavigationReceipt {
        let (sceneID, entry, active) = try hanlinRegistration(for: destination.context)
        guard active.session == session, active.binding == binding,
              let pending = active.navigation, pending.destination == destination,
              entry.session.studyChatPresentationID == nil, entry.session.isPresentationReady else {
            throw HanlinHostError.staleContext
        }
        scenes[sceneID]?.hanlin?.navigation = nil
        let observed = active.observed
        try Task.checkCancellation()
        // `open(public:)` retains the original mapping owner and revalidates it
        // at the actual Core/native commit boundary; no alternate UI path exists.
        let result = try await open(public: pending.intent, sceneID: sceneID, managerID: entry.managerID,
            expectedSnapshot: observed.backend, origin: .internalAI, until: pending.deadline,
            requestID: destination.requestID)
        guard case .acknowledged(let receipt) = result,
              receipt.requestId == destination.requestID, receipt.sceneID == sceneID,
              receipt.backendSnapshot == observed.backend,
              receipt.route.destination == pending.intent.destination,
              receipt.route.content == pending.intent.content else {
            throw HanlinHostError.resultMismatch
        }
        guard let current = scenes[sceneID], current.session === entry.session,
              current.managerID == entry.managerID, current.hanlinSceneID == entry.hanlinSceneID else {
            throw HanlinHostError.staleContext
        }
        let after = try hanlinSource(sceneID: sceneID, entry: current)
        guard after.backend == observed.backend, after.source == observed.source,
              after.epoch.sourceID == observed.epoch.sourceID,
              after.projection.profileID == observed.projection.profileID,
              after.projection.groupID == observed.projection.groupID else {
            throw HanlinHostError.staleContext
        }
        // Only the observed same-scene result can create this fresh generation.
        // This is metadata/navigation authority, never permission to read text.
        let successor = try issueHanlinHostSession(sceneID: sceneID, entry: current,
            conversationID: session.conversationID, invalidated: active.invalidated).session
        let acknowledgement = HanlinHostNavigationReceipt(originalSession: session,
            result: .presented(requestID: destination.requestID, context: destination.context,
                objectReference: destination.objectReference, blockReference: destination.blockReference),
            successorSession: successor)
        try acknowledgement.validate(for: destination, session: session)
        return acknowledgement
    }

    func open(destination: NativeIntentService.Destination) async throws -> UISceneAcknowledgement {
        guard let entry = scenes[destination.sceneID], entry.session.foreground else { return .requiresForeground }
        let snapshot = try backend.currentBackendSnapshot()
        guard snapshot.backend == destination.backend else { return .requiresBackendSwitch(destination.backend) }
        if destination.component != nil || destination.destination.rawValue == "native.reader.inspector"
            || MaktabahNativeWorkspacePresentationBinding.Parent(rawValue: destination.destination.rawValue) != nil {
            // The same live system entity uses the same public binder and
            // original Core fence as a component deep link. No second intent
            // executor or caller-supplied authority is added.
            return try await open(public: .init(destination: destination.destination, backend: destination.backend,
                presentation: destination.destination.rawValue == "native.reader.inspector" ? .inspector
                    : (destination.destination.rawValue == "native.settings"
                    || MaktabahNativeWorkspacePresentationBinding.Parent(rawValue: destination.destination.rawValue) != nil) ? .sheet : .currentTab,
                component: destination.component), sceneID: destination.sceneID,
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
    func makeGuide(_ definition: UIGuideDefinition, session: MaktabahNativeSceneSession,
                   manager: iOSNavigationManager) -> UIGuideRun {
        let sceneID = session.sceneID, managerID = ObjectIdentifier(manager)
        var verifiedPresentation: (request: UUID, activeTab: UIStableID?)?
        return .init(definition: definition, sceneID: sceneID, observe: { [weak self, weak session] in
            guard let self, let session, let entry = scenes[sceneID], entry.session === session,
                  entry.managerID == managerID, session.foreground,
                  let snapshot = try? backend.currentBackendSnapshot() else { return nil }
            let readContext = context(sceneID: sceneID, origin: .guide, snapshot: snapshot)
            do {
                try issue(readContext, sceneID: sceneID)
                defer { finish(readContext, sceneID: sceneID) }
                return try directory.synchronousScene(sceneID: sceneID, context: readContext, backend: snapshot)
            } catch { return nil }
        }, verifyVisible: { [weak self, weak session] receipt in
            guard let self, let session, scenes[sceneID]?.session === session,
                  let identity = try? session.guidePresentationIdentity(for: receipt.route) else { return false }
            if let prior = verifiedPresentation, prior.request == receipt.requestId {
                return prior.activeTab == identity.activeTabID
            }
            verifiedPresentation = (receipt.requestId, identity.activeTabID)
            return true
        }) { [weak self, weak session] intent, before, deadline in
            guard let self, let session, scenes[sceneID]?.session === session, before.sceneID == sceneID else {
                throw UIRouteError(.staleState, "guide_scene_lifetime_changed")
            }
            return try await open(public: intent, sceneID: sceneID, managerID: managerID,
                                  expectedSnapshot: before.backendSnapshot, origin: .guide, until: deadline)
        }
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
        // Retain the exact ORIGINAL parent first; a component must inherit
        // that same proof. Neither operation grants authority or changes UI.
        try entry.session.retainParentSource(destination: intent.destination, requestID: requestID)
        defer { entry.session.releaseParentSource(destination: intent.destination, requestID: requestID) }
        // Retain exact original component source BEFORE the first await. This
        // reads identity only; canonical Core still authorizes all navigation.
        let retainedComponent: MaktabahNativeComponentOwner?
        if let anchor = intent.component, intent.destination.rawValue != "native.search" {
            retainedComponent = try entry.session.retainComponentSource(destination: intent.destination,
                anchor: anchor, requestID: requestID)
        } else { retainedComponent = nil }
        defer { retainedComponent?.releaseSource(requestID: requestID) }
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


    /// An explicit trusted caller must supply its live read authority. This API
    /// does not grant corpus access, expose a Hanlin tool, or send a message.
    func countThenOpenSearchResults(query: ActionOccurrenceQuery, manager: iOSNavigationManager,
                                    readAuthority: @escaping @MainActor () throws -> ActionExecutionContext) async throws -> ActionSemanticJourneyResult {
        let journey = try await semanticJourneys(manager: manager, readAuthority: readAuthority)
        return await journey.countThenOpenResults(query)
    }

    func openCommentaryThenPrepareDraft(baseLocator: ActionTextRef, workRef: ActionWorkRef? = nil,
                                        commentaryQuery: String? = nil, proposedText: String? = nil,
                                        manager: iOSNavigationManager) async throws -> ActionSemanticJourneyResult {
        let journey = try await semanticJourneys(manager: manager)
        return await journey.commentaryThenPrepareDraft(baseLocator: baseLocator, workRef: workRef,
            commentaryQuery: commentaryQuery, proposedText: proposedText)
    }

    func resolveCommentaryThenPrepareDraft(backend: ActionBackendID, baseWorkQuery: String, section: String,
                                           commentaryQuery: String, proposedText: String? = nil,
                                           manager: iOSNavigationManager) async throws -> ActionSemanticJourneyResult {
        let journey = try await semanticJourneys(manager: manager)
        return await journey.resolveCommentaryThenPrepareDraft(backend: backend, baseWorkQuery: baseWorkQuery,
            section: section, commentaryQuery: commentaryQuery, proposedText: proposedText)
    }

    private func semanticJourneys(manager: iOSNavigationManager,
                                  readAuthority: (@MainActor () throws -> ActionExecutionContext)? = nil) async throws -> ActionSemanticJourneys {
        let end = deadline(), managerID = ObjectIdentifier(manager)
        let sceneID = try await NativeObservationDeadline.run(until: end, clock: SystemActionClock()) { [self] in
            try await waitForMount(managerID: managerID)
        }
        guard let entry = scenes[sceneID], entry.managerID == managerID, contexts[sceneID] == nil else {
            throw UIRouteError(.unavailable, "native_scene_busy")
        }
        let observed = try hanlinSource(sceneID: sceneID, entry: entry)
        let owner = SemanticJourneyOwner(sceneID: sceneID, managerID: managerID,
            context: context(sceneID: sceneID, origin: .inApp, snapshot: observed.backend), observation: observed)
        return semanticJourneys(owner: owner, manager: manager, readAuthority: readAuthority)
    }

    private func semanticJourneys(owner: SemanticJourneyOwner, manager: iOSNavigationManager,
                                  readAuthority: (@MainActor () throws -> ActionExecutionContext)? = nil) -> ActionSemanticJourneys {
        let navigation: ActionSemanticJourneys.Authority = { [self] in
            try validateSemanticJourney(owner)
            return .init(context: owner.context, snapshot: owner.observation.backend)
        }
        let read: ActionSemanticJourneys.Authority?
        if let readAuthority {
            read = { [self] in
                try validateSemanticJourney(owner)
                let context = try readAuthority()
                guard context.foregroundSceneID == owner.sceneID.rawValue else { throw ActionPortError.staleState }
                return .init(context: context, snapshot: owner.observation.backend)
            }
        } else { read = nil }
        return .init(core: core, navigationAuthority: navigation, readAuthority: read) { [self, manager] request, authority in
            try validateSemanticJourney(owner)
            guard authority.context == owner.context, authority.snapshot == owner.observation.backend else {
                throw ActionPortError.staleState
            }
            let continuing = SemanticJourneyInvocation(owner: owner, request: request)
            do {
                switch request.action {
                case "search.openResults":
                    let query = try ActionSearchResultsQuery.arguments(request.arguments, backend: authority.snapshot.backend)
                    return try await openSearchResults(query: query, manager: manager, continuing: continuing)
                case "reader.openCommentary":
                    guard let base = try request.arguments["baseLocator"]?.decoded(as: ActionTextRef.self) else { throw ActionPortError.invalidResponse }
                    return try await openCommentary(baseLocator: base,
                        workRef: request.arguments["workRef"]?.decoded(as: ActionWorkRef.self),
                        commentaryQuery: request.arguments["commentaryQuery"]?.string,
                        manager: manager, continuing: continuing)
                case "notes.prepareDraft":
                    guard let locator = try request.arguments["locator"]?.decoded(as: ActionTextRef.self) else { throw ActionPortError.invalidResponse }
                    return try await prepareNoteDraft(locator: locator, selectedText: nil,
                        proposedText: request.arguments["proposedText"]?.string,
                        manager: manager, continuing: continuing)
                default: throw ActionPortError.notSupported
                }
            } catch let error as UIRouteError {
                throw ActionNativeUIFailure(status: error.status,
                    failure: .init(code: error.code, message: ""))
            }
        }
    }

    private func validateSemanticJourney(_ owner: SemanticJourneyOwner) throws {
        try Task.checkCancellation()
        guard let entry = scenes[owner.sceneID], entry.managerID == owner.managerID,
              contexts[owner.sceneID] == nil else { throw ActionPortError.staleState }
        let current: HanlinSourceObservation
        do { current = try hanlinSource(sceneID: owner.sceneID, entry: entry) }
        catch {
            #if DEBUG
            OtzariaFileLogger.shared.log("[SemanticJourneyWitness] stage=live-authority sourceAvailable=false")
            #endif
            throw ActionPortError.staleState
        }
        let expected = owner.observation
        guard current == expected else {
            #if DEBUG
            OtzariaFileLogger.shared.log("[SemanticJourneyWitness] stage=live-authority"
                + " sameBackend=\(current.backend == expected.backend)"
                + " sameMappingSource=\(current.source == expected.source)"
                + " sameEpoch=\(current.epoch == expected.epoch)"
                + " sameProjection=\(current.projection == expected.projection)"
                + " sameReaderContent=\(current.readerContent == expected.readerContent)"
                + " sameReadSource=\(current.currentWorkReadSource == expected.currentWorkReadSource)"
                + " sameRange=\(current.selectedRange == expected.selectedRange)"
                + " sameLocale=\(current.locale == expected.locale)")
            #endif
            throw ActionPortError.staleState
        }
    }

    private func semanticJourneyInvocation(_ continuing: SemanticJourneyInvocation?, fallback: ActionRequest,
                                           context: ActionExecutionContext, sceneID: UIStableID,
                                           observed: HanlinSourceObservation) throws -> (ActionRequest, ActionExecutionContext) {
        guard let continuing else { return (fallback, context) }
        try validateSemanticJourney(continuing.owner)
        let request = continuing.request, encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let sameArguments = try encoder.encode(request.arguments) == encoder.encode(fallback.arguments)
        guard continuing.owner.sceneID == sceneID, continuing.owner.observation == observed,
              request.action == fallback.action, request.expectedBackend == fallback.expectedBackend,
              request.expectedGeneration == fallback.expectedGeneration,
              request.requestedPresentation == fallback.requestedPresentation, sameArguments else {
            #if DEBUG
            OtzariaFileLogger.shared.log("[SemanticJourneyWitness] stage=continued-request"
                + " sameScene=\(continuing.owner.sceneID == sceneID)"
                + " sameObservation=\(continuing.owner.observation == observed)"
                + " sameAction=\(request.action == fallback.action)"
                + " sameBackend=\(request.expectedBackend == fallback.expectedBackend)"
                + " sameGeneration=\(request.expectedGeneration == fallback.expectedGeneration)"
                + " samePresentation=\(request.requestedPresentation == fallback.requestedPresentation)"
                + " sameArguments=\(sameArguments)")
            #endif
            throw ActionPortError.staleState
        }
        return (request, continuing.owner.context)
    }

    private func advanceSemanticJourney(_ owner: SemanticJourneyOwner, receipt: UISceneReceipt,
                                        finishing pending: CommentaryInvocation) throws {
        guard let entry = scenes[owner.sceneID], entry.managerID == owner.managerID,
              contexts[owner.sceneID] == owner.context, pending.sceneID == owner.sceneID,
              pending.context == owner.context, let release = pending.cleanup,
              receipt.sceneID == owner.sceneID, receipt.backendSnapshot == owner.observation.backend,
              let reader = receipt.coreReceipt, reader.destination.presentationMode == .newTab else {
            throw ActionPortError.staleState
        }
        let current = try directory.synchronousScene(sceneID: owner.sceneID, context: owner.context,
            backend: backend.currentBackendSnapshot())
        guard current.revision >= receipt.appliedSceneRevision,
              current.backendSnapshot == receipt.backendSnapshot else {
            throw ActionPortError.staleState
        }
        // The native observer retires the request-specific route after commit.
        // Verify the correlated receipt against the destination's live UIKit surface.
        do { try entry.session.validateCompletedJourneySurface(receipt) }
        catch {
            #if DEBUG
            OtzariaFileLogger.shared.log("[SemanticJourneyWitness] stage=reader-receipt liveCompletedSurface=false")
            #endif
            throw error
        }
        let observed = try hanlinSource(sceneID: owner.sceneID, entry: entry)
        guard observed.backend == owner.observation.backend,
              observed.readerContent?.sectionLocator == reader.destination.sectionLocator,
              observed.readerContent?.focusLocator == reader.destination.focusLocator else {
            #if DEBUG
            OtzariaFileLogger.shared.log("[SemanticJourneyWitness] stage=reader-source"
                + " sameBackend=\(observed.backend == owner.observation.backend)"
                + " sameSection=\(observed.readerContent?.sectionLocator == reader.destination.sectionLocator)"
                + " sameFocus=\(observed.readerContent?.focusLocator == reader.destination.focusLocator)")
            #endif
            throw ActionPortError.staleState
        }
        // The source owner publishes release synchronously, while the request
        // tears down its binding. Keep the exact source alive across that
        // boundary. The next admission observes the fresh scene again.
        guard let workspaceSource = entry.session.workspaceProjectionSource,
              let mapping = try workspaceSource.read()?.mappingOwnershipObservation(),
              ObjectIdentifier(mapping.source) == observed.source, mapping.epoch == observed.epoch else {
            throw ActionPortError.staleState
        }
        let (revision, overflow) = observed.epoch.revision.addingReportingOverflow(1)
        guard !overflow else { throw ActionPortError.staleState }
        let expectedEpoch = StudyWorkspaceMappingEpoch(sourceID: observed.epoch.sourceID, revision: revision)
        pending.cleanup = nil
        release()
        let publication = mapping.source.event
        guard publication.phase == .available, publication.epoch == expectedEpoch,
              publication.reasons == [.readerReservation] else {
            #if DEBUG
            OtzariaFileLogger.shared.log("[SemanticJourneyWitness] stage=owned-reader-release"
                + " available=\(publication.phase == .available)"
                + " expectedEpoch=\(publication.epoch == expectedEpoch)"
                + " ownRelease=\(publication.reasons == [.readerReservation])")
            #endif
            throw ActionPortError.staleState
        }
        owner.observation = .init(backend: observed.backend, source: observed.source, epoch: expectedEpoch,
            projection: observed.projection, readerContent: observed.readerContent,
            currentWorkReadSource: observed.currentWorkReadSource, selectedRange: observed.selectedRange,
            locale: observed.locale)
    }

    /// A count remains withheld until its read authority is checked again after
    /// the results UI await. Only our exact observed search transition may move
    /// the scene witness; this never renews the caller's separate read grant.
    private func advanceSemanticSearchJourney(_ owner: SemanticJourneyOwner, receipt: UISceneReceipt) throws {
        guard let entry = scenes[owner.sceneID], entry.managerID == owner.managerID,
              contexts[owner.sceneID] == owner.context,
              receipt.sceneID == owner.sceneID, receipt.backendSnapshot == owner.observation.backend,
              receipt.coreReceipt == nil, receipt.route.destination.rawValue == "native.search.results" else {
            throw ActionPortError.staleState
        }
        let current = try directory.synchronousScene(sceneID: owner.sceneID, context: owner.context,
            backend: backend.currentBackendSnapshot())
        guard current.revision >= receipt.appliedSceneRevision,
              current.backendSnapshot == receipt.backendSnapshot else {
            throw ActionPortError.staleState
        }
        // The native observer retires the request-specific route after commit.
        // Verify the correlated receipt against the destination's live UIKit surface.
        do { try entry.session.validateCompletedJourneySurface(receipt) }
        catch {
            #if DEBUG
            OtzariaFileLogger.shared.log("[SemanticJourneyWitness] stage=search-receipt liveCompletedSurface=false")
            #endif
            throw error
        }
        let observed = try hanlinSource(sceneID: owner.sceneID, entry: entry)
        let prior = owner.observation
        // The original Viewer -> Search mode switch does not change the mapping
        // projection or its epoch. Never adopt another profile/group/tab/reader
        // merely because the mapping-source object survived the UI await.
        // Off Viewer, its visible reader metadata can become unobservable (nil);
        // any metadata still observed must retain the original value. The
        // caller's separate live read authority is checked again before publish.
        guard observed.backend == prior.backend, observed.source == prior.source,
              observed.epoch == prior.epoch, observed.projection == prior.projection,
              observed.locale == prior.locale,
              observed.readerContent == nil || observed.readerContent == prior.readerContent,
              observed.currentWorkReadSource == nil || observed.currentWorkReadSource == prior.currentWorkReadSource,
              observed.selectedRange == nil || observed.selectedRange == prior.selectedRange else {
            #if DEBUG
            OtzariaFileLogger.shared.log("[SemanticJourneyWitness] stage=search-source"
                + " sameBackend=\(observed.backend == prior.backend)"
                + " sameMappingSource=\(observed.source == prior.source)"
                + " sameEpoch=\(observed.epoch == prior.epoch)"
                + " sameProjection=\(observed.projection == prior.projection)"
                + " sameLocale=\(observed.locale == prior.locale)"
                + " compatibleReader=\(observed.readerContent == nil || observed.readerContent == prior.readerContent)"
                + " compatibleReadSource=\(observed.currentWorkReadSource == nil || observed.currentWorkReadSource == prior.currentWorkReadSource)"
                + " compatibleRange=\(observed.selectedRange == nil || observed.selectedRange == prior.selectedRange)")
            #endif
            throw ActionPortError.staleState
        }
        owner.observation = observed
    }

    /// Explicit local submission into the original global results UI. Paging
    /// and result ownership remain with that existing session and its engines.
    func openSearchResults(query: ActionSearchResultsQuery, manager: iOSNavigationManager) async throws -> ActionResult {
        try await openSearchResults(query: query, manager: manager, continuing: nil)
    }

    private func openSearchResults(query: ActionSearchResultsQuery, manager: iOSNavigationManager,
                                   continuing: SemanticJourneyInvocation?) async throws -> ActionResult {
        let end = deadline(), managerID = ObjectIdentifier(manager)
        let sceneID = try await NativeObservationDeadline.run(until: end, clock: SystemActionClock()) { [self] in
            try await waitForMount(managerID: managerID)
        }
        guard let entry = scenes[sceneID], entry.managerID == managerID, contexts[sceneID] == nil,
              searchResultsInvocations.count < 16,
              !searchResultsInvocations.values.contains(where: { $0.sceneID == sceneID }) else {
            throw UIRouteError(.unavailable, "native_scene_busy")
        }
        let observed = try hanlinSource(sceneID: sceneID, entry: entry)
        let localContext = context(sceneID: sceneID, origin: .inApp, snapshot: observed.backend)
        let localRequest = ActionRequest(action: "search.openResults", arguments: try query.actionArguments(),
            expectedBackend: query.search.backend, expectedGeneration: observed.backend.generation,
            requestedPresentation: .foreground)
        let (request, context) = try semanticJourneyInvocation(continuing, fallback: localRequest,
            context: localContext, sceneID: sceneID, observed: observed)
        let pending = SearchResultsInvocation(sceneID: sceneID, context: context, observation: observed, query: query)
        searchResultsInvocations[request.requestId] = pending
        defer {
            let cleanup = pending.cleanup; pending.cleanup = nil; cleanup?()
            searchResultsInvocations.removeValue(forKey: request.requestId)
        }
        let result = await core.execute(request, context: context)
        if result.status == .completed {
            guard let receipt = pending.receipt else { throw ActionPortError.invalidResponse }
            record(.acknowledged(receipt))
            if let continuing {
                do { try advanceSemanticSearchJourney(continuing.owner, receipt: receipt) }
                catch { throw Self.uncertainNativeEffect(error) }
            }
        }
        return result
    }

    private func prepareSearchResults(_ query: ActionSearchResultsQuery, context: ActionExecutionContext,
                                      invocation: ActionPortInvocation) async throws {
        guard let pending = searchResultsInvocations[invocation.requestId], pending.query == query,
              pending.context == context, pending.cleanup == nil, pending.sceneID.rawValue == context.foregroundSceneID,
              let entry = scenes[pending.sceneID], contexts[pending.sceneID] == nil,
              pending.observation.backend == invocation.snapshot,
              try hanlinSource(sceneID: pending.sceneID, entry: entry) == pending.observation else {
            throw ActionPortError.staleState
        }
        let retained = try entry.session.retainSearchResults(query, requestID: invocation.requestId)
        do {
            try issue(context, sceneID: pending.sceneID)
            let admitted = try authority.admit(context: context, sceneID: pending.sceneID)
            pending.admission = admitted; pending.binding = retained
            pending.cleanup = { [self, session = entry.session] in
                authority.release(admitted)
                finish(context, sceneID: pending.sceneID)
                session.releaseSearchResults(retained)
            }
            let scene = try await directory.currentScene(sceneID: pending.sceneID, context: context, invocation: invocation)
            let route = try entry.session.prepareSearchResults(invocation: invocation, scene: scene)
            pending.command = try UISceneCommand(route: registry.validate(route), invocation: invocation, scene: scene)
            guard searchResultsInvocations[invocation.requestId] === pending, contexts[pending.sceneID] == context else {
                throw ActionPortError.staleState
            }
        } catch {
            if let cleanup = pending.cleanup { cleanup(); pending.cleanup = nil }
            else { finish(context, sceneID: pending.sceneID); entry.session.releaseSearchResults(retained) }
            throw error
        }
    }

    private func receiveSearchResults(_ search: ActionOpenSearchResultsCommand) async throws -> ActionSearchResultsAcknowledgement {
        guard let pending = searchResultsInvocations[search.invocation.requestId],
              pending.sceneID.rawValue == search.sceneID, pending.query == search.query,
              contexts[pending.sceneID] == pending.context,
              let command = pending.command, let admitted = pending.admission,
              let binding = pending.binding, binding.accepts(search.query, requestID: search.invocation.requestId) else {
            throw ActionPortError.staleState
        }
        let prepared = try command.prepareNavigation(searchResultsCommand: search)
        let result = await orchestrator.commitPrepared(prepared, admitted: admitted)
        guard case .acknowledged(let receipt) = result else {
            if case .requiresForeground = result { return .requiresForeground }
            throw Self.nativeUIFailure(result)
        }
        do {
            guard searchResultsInvocations[search.invocation.requestId] === pending, pending.cleanup != nil,
                  receipt.requestId == search.invocation.requestId, receipt.backendSnapshot == search.invocation.snapshot,
                  receipt.sceneID == pending.sceneID, receipt.route == command.route.route,
                  receipt.coreReceipt == nil else { throw ActionPortError.invalidResponse }
            try binding.validateCompleted()
            guard let revision = binding.submissionRevision else { throw ActionPortError.invalidResponse }
            pending.receipt = receipt
            return .acknowledged(.init(requestId: search.invocation.requestId, snapshot: search.invocation.snapshot,
                sceneID: search.sceneID, query: search.query, submissionRevision: revision))
        } catch { throw Self.uncertainNativeEffect(error) }
    }

    private func validateSearchResultsCompletion(_ search: ActionOpenSearchResultsCommand,
                                                  receipt: ActionSearchResultsReceipt) throws {
        guard let pending = searchResultsInvocations[search.invocation.requestId],
              pending.query == search.query, pending.sceneID.rawValue == search.sceneID,
              contexts[pending.sceneID] == pending.context, pending.receipt != nil,
              let binding = pending.binding, binding.submissionRevision == receipt.submissionRevision,
              let entry = scenes[pending.sceneID], entry.session.searchResultsBinding === binding else {
            throw ActionPortError.staleState
        }
        try entry.session.validateSearchResultsCompletion(requestID: search.invocation.requestId)
    }

    /// Local, explicit commentary navigation. Resolution runs in the same Core;
    /// only the original scene owner may retain the resolved target. No Hanlin
    /// content scope, note write or new agent tool is granted by this entry.
    func openCommentary(baseLocator: ActionTextRef, workRef: ActionWorkRef? = nil,
                        commentaryQuery: String? = nil, manager: iOSNavigationManager) async throws -> ActionResult {
        try await openCommentary(baseLocator: baseLocator, workRef: workRef, commentaryQuery: commentaryQuery,
            manager: manager, continuing: nil)
    }

    private func openCommentary(baseLocator: ActionTextRef, workRef: ActionWorkRef?, commentaryQuery: String?,
                                manager: iOSNavigationManager, continuing: SemanticJourneyInvocation?) async throws -> ActionResult {
        let end = deadline(), managerID = ObjectIdentifier(manager)
        let sceneID = try await NativeObservationDeadline.run(until: end, clock: SystemActionClock()) { [self] in
            try await waitForMount(managerID: managerID)
        }
        guard let entry = scenes[sceneID], entry.managerID == managerID, contexts[sceneID] == nil,
              commentaryInvocations.count < 16,
              !commentaryInvocations.values.contains(where: { $0.sceneID == sceneID }) else { throw UIRouteError(.unavailable, "native_scene_busy") }
        let observed = try hanlinSource(sceneID: sceneID, entry: entry)
        let localContext = context(sceneID: sceneID, origin: .inApp, snapshot: observed.backend)
        var arguments: ActionObject = ["baseLocator": try .encoded(baseLocator)]
        if let workRef { arguments["workRef"] = try .encoded(workRef) }
        if let commentaryQuery { arguments["commentaryQuery"] = .string(commentaryQuery) }
        let localRequest = ActionRequest(action: "reader.openCommentary", arguments: arguments,
            expectedBackend: baseLocator.backend, expectedGeneration: observed.backend.generation,
            requestedPresentation: .foreground)
        let (request, context) = try semanticJourneyInvocation(continuing, fallback: localRequest,
            context: localContext, sceneID: sceneID, observed: observed)
        let pending = CommentaryInvocation(sceneID: sceneID, context: context, observation: observed)
        commentaryInvocations[request.requestId] = pending
        defer {
            let cleanup = pending.cleanup; pending.cleanup = nil
            cleanup?()
            commentaryInvocations.removeValue(forKey: request.requestId)
        }
        let result = await core.execute(request, context: context)
        if result.status == .completed {
            guard let receipt = readerInvocations[request.requestId]?.receipt else { throw ActionPortError.invalidResponse }
            record(.acknowledged(receipt))
            if let continuing {
                do { try advanceSemanticJourney(continuing.owner, receipt: receipt, finishing: pending) }
                catch { throw Self.uncertainNativeEffect(error) }
                continuing.owner.didAcknowledge?(receipt)
            }
        }
        return result
    }

    private func prepareCommentaryReader(_ destination: ActionReaderDestination, context: ActionExecutionContext,
                                         invocation: ActionPortInvocation) async throws {
        guard let pending = commentaryInvocations[invocation.requestId], pending.context == context,
              pending.cleanup == nil, pending.sceneID.rawValue == context.foregroundSceneID,
              let entry = scenes[pending.sceneID], contexts[pending.sceneID] == nil,
              let binding = entry.publicBinding, readerInvocations[invocation.requestId] == nil,
              readerInvocations.count < 16, destination.presentationMode == .newTab,
              pending.observation.backend == invocation.snapshot,
              try hanlinSource(sceneID: pending.sceneID, entry: entry) == pending.observation else {
            throw ActionPortError.staleState
        }
        // As in open(public:), reservation advances the original workspace
        // epoch BEFORE issuing/admitting the context used by the Core grant.
        let retained = try entry.session.retainReader(destination, requestID: invocation.requestId) { [weak self, weak session = entry.session] in
            guard let self, let session else { return }
            try? invalidateContext(session)
        }
        do {
            try issue(context, sceneID: pending.sceneID)
            let admitted = try authority.admit(context: context, sceneID: pending.sceneID)
            pending.cleanup = { [self, session = entry.session] in
                readerInvocations.removeValue(forKey: invocation.requestId)
                authority.release(admitted)
                finish(context, sceneID: pending.sceneID)
                session.releaseReader(retained)
            }
            let scene = try await directory.currentScene(sceneID: pending.sceneID, context: context, invocation: invocation)
            let intent = PublicNavigationSpecV2(destination: UIDestinationID(rawValue: "native.reader")!,
                backend: invocation.snapshot.backend, content: destination, presentation: .newTab)
            let plan = try await registry.bindPublicV2(intent, scene: scene, context: context, invocation: invocation, core: core, host: binding)
            guard case .reader(let route) = plan else { throw ActionPortError.invalidResponse }
            guard commentaryInvocations[invocation.requestId] === pending, pending.cleanup != nil,
                  contexts[pending.sceneID] == context else { throw ActionPortError.staleState }
            try Task.checkCancellation()
            readerInvocations[invocation.requestId] = ReaderInvocation(route: route, context: context, sceneID: pending.sceneID)
        } catch {
            if let cleanup = pending.cleanup { cleanup(); pending.cleanup = nil }
            else { finish(context, sceneID: pending.sceneID); entry.session.releaseReader(retained) }
            throw error
        }
    }

    /// Local editable proposal in the ORIGINAL note editor. It neither saves
    /// the Annotation nor exports selected text through a new agent tool.
    func prepareNoteDraft(locator: ActionTextRef, selectedText: String? = nil,
                          proposedText: String? = nil, manager: iOSNavigationManager) async throws -> ActionResult {
        try await prepareNoteDraft(locator: locator, selectedText: selectedText, proposedText: proposedText,
            manager: manager, continuing: nil)
    }

    private func prepareNoteDraft(locator: ActionTextRef, selectedText: String?, proposedText: String?,
                                  manager: iOSNavigationManager, continuing: SemanticJourneyInvocation?) async throws -> ActionResult {
        let end = deadline(), managerID = ObjectIdentifier(manager)
        let sceneID = try await NativeObservationDeadline.run(until: end, clock: SystemActionClock()) { [self] in
            try await waitForMount(managerID: managerID)
        }
        guard let entry = scenes[sceneID], entry.managerID == managerID, contexts[sceneID] == nil,
              noteDraftInvocations.count < 16,
              !noteDraftInvocations.values.contains(where: { $0.sceneID == sceneID }),
              entry.session.canPrepareNoteDraft() else { throw UIRouteError(.unavailable, "exact_note_selection_unavailable") }
        let observed = try hanlinSource(sceneID: sceneID, entry: entry)
        let localContext = context(sceneID: sceneID, origin: .inApp, snapshot: observed.backend)
        let draft = ActionNoteDraftRequest(locator: locator, selectedText: selectedText, proposedText: proposedText)
        var arguments: ActionObject = ["locator": try .encoded(locator)]
        if let selectedText { arguments["selectedText"] = .string(selectedText) }
        if let proposedText { arguments["proposedText"] = .string(proposedText) }
        let localRequest = ActionRequest(action: "notes.prepareDraft", arguments: arguments,
            expectedBackend: locator.backend, expectedGeneration: observed.backend.generation,
            requestedPresentation: .foreground)
        let (request, context) = try semanticJourneyInvocation(continuing, fallback: localRequest,
            context: localContext, sceneID: sceneID, observed: observed)
        let pending = NoteDraftInvocation(sceneID: sceneID, context: context, observation: observed, request: draft)
        noteDraftInvocations[request.requestId] = pending
        defer {
            let cleanup = pending.cleanup; pending.cleanup = nil
            cleanup?()
            noteDraftInvocations.removeValue(forKey: request.requestId)
        }
        let result = await core.execute(request, context: context)
        if result.status == .completed {
            guard let receipt = pending.receipt else { throw ActionPortError.invalidResponse }
            record(.acknowledged(receipt))
            continuing?.owner.didAcknowledge?(receipt)
        }
        return result
    }

    private func prepareNoteDraft(_ draft: ActionNoteDraftRequest, context: ActionExecutionContext,
                                  invocation: ActionPortInvocation) async throws {
        guard let pending = noteDraftInvocations[invocation.requestId], pending.context == context,
              pending.request == draft, pending.cleanup == nil, pending.sceneID.rawValue == context.foregroundSceneID,
              let entry = scenes[pending.sceneID], contexts[pending.sceneID] == nil,
              pending.observation.backend == invocation.snapshot,
              try hanlinSource(sceneID: pending.sceneID, entry: entry) == pending.observation else {
            throw ActionPortError.staleState
        }
        let retained = try entry.session.retainNoteDraft(draft)
        do {
            try issue(context, sceneID: pending.sceneID)
            let admitted = try authority.admit(context: context, sceneID: pending.sceneID)
            pending.binding = retained; pending.admitted = admitted
            pending.cleanup = { [self, session = entry.session] in
                authority.release(admitted)
                finish(context, sceneID: pending.sceneID)
                session.releaseNoteDraft(retained)
            }
            let scene = try await directory.currentScene(sceneID: pending.sceneID, context: context, invocation: invocation)
            let route = try entry.session.prepareNoteDraftRoute(invocation: invocation, scene: scene)
            let command = try UISceneCommand(route: registry.validate(route), invocation: invocation, scene: scene)
            guard noteDraftInvocations[invocation.requestId] === pending, pending.cleanup != nil,
                  contexts[pending.sceneID] == context else { throw ActionPortError.staleState }
            try Task.checkCancellation()
            pending.command = command
        } catch {
            if let cleanup = pending.cleanup { cleanup(); pending.cleanup = nil }
            else { finish(context, sceneID: pending.sceneID); entry.session.releaseNoteDraft(retained) }
            throw error
        }
    }

    private func receiveNoteDraft(_ note: ActionPrepareNoteDraftCommand) async throws -> ActionNoteDraftAcknowledgement {
        guard let pending = noteDraftInvocations[note.invocation.requestId], pending.request == note.draft,
              pending.sceneID.rawValue == note.sceneID, pending.observation.backend == note.invocation.snapshot,
              contexts[pending.sceneID] == pending.context, let command = pending.command,
              command.invocation == note.invocation, let admitted = pending.admitted,
              let bound = pending.binding, let entry = scenes[pending.sceneID] else { throw ActionPortError.staleState }
        let prepared = try command.prepareNavigation(noteDraftCommand: note)
        let result = await orchestrator.commitPrepared(prepared, admitted: admitted)
        guard case .acknowledged(let receipt) = result else {
            if case .requiresForeground = result { return .requiresForeground }
            throw Self.nativeUIFailure(result)
        }
        do {
            guard noteDraftInvocations[note.invocation.requestId] === pending, pending.cleanup != nil,
                  receipt.requestId == note.invocation.requestId, receipt.backendSnapshot == note.invocation.snapshot,
                  receipt.sceneID == pending.sceneID, receipt.route == command.route.route,
                  receipt.coreReceipt == nil else { throw ActionPortError.invalidResponse }
            try entry.session.validateNoteDraftCompletion(bound, route: receipt.route)
            pending.receipt = receipt
            guard let actual = bound.owner.current else { throw ActionPortError.staleState }
            return .acknowledged(.init(requestId: receipt.requestId, snapshot: receipt.backendSnapshot,
                sceneID: receipt.sceneID.rawValue, draft: bound.request, isUnsaved: actual.id == nil))
        } catch { throw Self.uncertainNativeEffect(error) }
    }

    private func validateNoteDraftCompletion(_ receipt: ActionNoteDraftReceipt, invocation: ActionPortInvocation) throws {
        guard let pending = noteDraftInvocations[invocation.requestId], pending.cleanup != nil,
              let native = pending.receipt, let bound = pending.binding,
              pending.request == receipt.draft, receipt.isUnsaved,
              receipt.requestId == invocation.requestId, receipt.snapshot == invocation.snapshot,
              native.requestId == invocation.requestId, native.backendSnapshot == invocation.snapshot,
              receipt.sceneID == pending.sceneID.rawValue, native.sceneID == pending.sceneID,
              contexts[pending.sceneID] == pending.context, let entry = scenes[pending.sceneID] else {
            throw ActionPortError.staleState
        }
        // Called synchronously on MainActor immediately AFTER Core's final
        // backend/authority read. Re-read original source/editor/UIKit here;
        // do not introduce another callback/await or invent a scene snapshot.
        try entry.session.validateNoteDraftCompletion(bound, route: native.route)
    }

    private static func uncertainNativeEffect(_ error: any Error) -> ActionNativeUIFailure {
        let status = (error as? UIRouteError)?.status ?? (error as? ActionNavigationError)?.status
            ?? (error as? ActionNativeUIFailure)?.status
            ?? ((error as? ActionPortError) == .staleState ? .staleState : (error is CancellationError ? .cancelled : .failed))
        return .init(status: status, failure: .init(code: "native_effect_uncertain", message: "", retryable: false))
    }

    private static func nativeUIFailure(_ result: UISceneAcknowledgement) -> ActionNativeUIFailure {
        let status: ActionStatus, failure: ActionFailure
        switch result {
        case .notSupported(let value): status = .notSupported; failure = value
        case .unavailable(let value): status = .unavailable; failure = value
        case .staleState(let value): status = .staleState; failure = value
        case .failed(let value): status = .failed; failure = value
        case .requiresConfirmation(let value): status = .requiresConfirmation; failure = value
        case .cancelled: status = .cancelled; failure = .init(code: "cancelled", message: "")
        default: status = .failed; failure = .init(code: "native_ui_failed", message: "")
        }
        return .init(status: status, failure: failure)
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
                for variant in variants {
                    if variant.destination.rawValue == "native.search", variant.presentation == .currentTab,
                       variant.component?.rawValue == "native.search.query" {
                        values.append(.init(backend: snapshot.backend, destination: variant.destination,
                            title: "Search field".localized + " — " + windowLabel, sceneID: id, component: variant.component))
                    } else if let anchor = variant.component,
                              let owner = entry.session.componentOwner(for: variant.destination),
                              let descriptor = owner.descriptors.first(where: { $0.anchor == anchor }) {
                        values.append(.init(backend: snapshot.backend, destination: variant.destination,
                            title: descriptor.title + " — " + windowLabel, sceneID: id, component: anchor))
                    }
                }
            }
        }
        return values
    }
    /// Resolve the identity of an existing mounted window before the system
    /// brings it to the foreground. Use original Registry metadata and actual
    /// capability/state checks; do not issue a context, grant or native receipt.
    private func intentRootEntities() throws -> [NativeIntentService.Destination] {
        try Task.checkCancellation()
        let snapshot = try backend.currentBackendSnapshot()
        var values: [NativeIntentService.Destination] = []
        for (id, entry) in scenes.sorted(by: { $0.key.rawValue < $1.key.rawValue }) where entry.session.mounted {
            let windowLabel = entry.session.windowLabel(number: entry.windowNumber)
            for descriptor in registry.descriptors where descriptor.implementation == .implemented
                && descriptor.supportedBackends.contains(snapshot.backend)
                && descriptor.requiredCoreActions.isEmpty && !descriptor.requiresContent
                && !descriptor.mutatesUserData && !descriptor.allowsPrivateState {
                guard descriptor.id.rawValue == "native.settings" || entry.session.isRootAvailable(descriptor.id) else { continue }
                values.append(.init(backend: snapshot.backend, destination: descriptor.id,
                    title: descriptor.title + " — " + windowLabel, sceneID: id))
                if !entry.session.foreground, let owner = entry.session.componentOwner(for: descriptor.id) {
                    // Existing scene/source identity may resolve before the
                    // system foregrounds it. Execution still discovers afresh.
                    values += owner.descriptors.filter { owner.isAvailable($0.anchor) }.map {
                        .init(backend: snapshot.backend, destination: descriptor.id,
                              title: $0.title + " — " + windowLabel, sceneID: id, component: $0.anchor)
                    }
                }
            }
        }
        try Task.checkCancellation()
        guard try backend.currentBackendSnapshot() == snapshot else {
            throw UIRouteError(.staleState, "intent_source_generation_changed")
        }
        return values
    }

    private func intentEntities() async throws -> [NativeIntentService.Destination] {
        let snapshot = try backend.currentBackendSnapshot()
        var values = try intentRootEntities()
        // General system entities still require live discovery for controls and
        // the Inspector. Reader-window identity resolution does not use this path.
        values += try await destinations().filter { $0.component != nil || $0.destination.rawValue == "native.reader.inspector" }
        guard try backend.currentBackendSnapshot() == snapshot else {
            throw UIRouteError(.staleState, "intent_source_generation_changed")
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
    private func awaitIntentForeground(_ destination: NativeIntentService.Destination) async throws {
        guard let original = scenes[destination.sceneID], original.session.mounted,
              try backend.currentBackendSnapshot().backend == destination.backend else {
            throw UIRouteError(.staleState, "intent_window_no_longer_available")
        }
        let snapshot = try backend.currentBackendSnapshot(), end = deadline()
        let activated = try await NativeObservationDeadline.run(until: end, clock: SystemActionClock()) { [self] in
            try await waitForMount(managerID: original.managerID)
        }
        guard activated == destination.sceneID, let current = scenes[destination.sceneID],
              current.session === original.session, current.managerID == original.managerID,
              current.session.mounted, current.session.foreground,
              try backend.currentBackendSnapshot() == snapshot else {
            throw UIRouteError(.staleState, "intent_window_changed_during_activation")
        }
        // No context, grant, mutation or receipt exists before this boundary.
        // The caller must still discover and authorize the current destination.
    }

    private func openReaderIntent(_ request: NativeReaderIntentService.OpenRequest) async throws -> UISceneAcknowledgement {
        let identities = try intentRootEntities().filter {
            $0.destination.rawValue == "native.library" && $0.id == request.windowIdentifier
        }
        guard identities.count == 1, let selected = identities.first else {
            throw UIRouteError(.staleState, "intent_window_no_longer_available")
        }
        let selectedEntry = scenes[selected.sceneID]
        do { try await awaitIntentForeground(selected) }
        catch {
            logIntentFailure(error, stage: "reader_foreground")
            throw error
        }
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
        if request.commentaryDraft != nil {
            guard let selectedEntry, selectedEntry.session === entry.session,
                  selectedEntry.managerID == entry.managerID else {
                throw UIRouteError(.staleState, "intent_window_changed_during_activation")
            }
            return try await openReaderCommentaryDraftIntent(request, sceneID: window.sceneID, entry: entry)
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
    private func openReaderCommentaryDraftIntent(_ request: NativeReaderIntentService.OpenRequest,
        sceneID: UIStableID, entry: Registration) async throws -> UISceneAcknowledgement {
        guard let draft = request.commentaryDraft, request.newTab,
              let manager = entry.manager, ObjectIdentifier(manager) == entry.managerID,
              contexts[sceneID] == nil else {
            throw UIRouteError(.unavailable, "native_scene_busy")
        }
        let observed = try hanlinSource(sceneID: sceneID, entry: entry)
        guard observed.backend == request.expectedSnapshot else {
            throw UIRouteError(.staleState, "intent_source_generation_changed")
        }
        var receipts: [UISceneReceipt] = []
        let owner = SemanticJourneyOwner(sceneID: sceneID, managerID: entry.managerID,
            context: context(sceneID: sceneID, origin: .appIntent, snapshot: observed.backend),
            observation: observed, didAcknowledge: { receipt in
                // Keep one excess item so a duplicate fails the exact-two guard.
                if receipts.count < 3 { receipts.append(receipt) }
            })
        let journey = await semanticJourneys(owner: owner, manager: manager).commentaryThenPrepareDraft(
            baseLocator: request.locator, workRef: draft.workRef, proposedText: draft.proposedText)
        let acknowledgement = try NativeReaderIntentService.commentaryDraftAcknowledgement(
            journey, receipts: receipts, request: request)
        do {
            try validateReaderIntentJourneyOwner(owner, initial: observed, entry: entry, manager: manager)
        } catch {
            let status: ActionStatus = error is CancellationError ? .cancelled : .staleState
            throw NativeReaderIntentService.CommentaryDraftFailure(journey: journey, receipts: receipts,
                status: status, code: "native_effect_uncertain")
        }
        #if DEBUG
        semanticIntentAcceptanceObserver?(request, journey, receipts)
        #endif
        return acknowledgement
    }

    /// The original Core owns each final visible acknowledgement. After the
    /// aggregate await, independently retain the exact source/window owner while
    /// the note sheet legitimately makes generic chat readiness false.
    private func validateReaderIntentJourneyOwner(_ owner: SemanticJourneyOwner,
        initial: HanlinSourceObservation, entry: Registration, manager: iOSNavigationManager) throws {
        try Task.checkCancellation()
        guard let current = scenes[owner.sceneID], current.session === entry.session,
              current.managerID == owner.managerID, current.manager === manager,
              current.session.mounted, current.session.foreground, contexts[owner.sceneID] == nil,
              try backend.currentBackendSnapshot() == owner.observation.backend,
              let source = current.session.workspaceProjectionSource, source.isAuthoritative,
              let workspace = try source.read(), let binding = current.publicBinding,
              let originalBinding = entry.publicBinding, binding === originalBinding,
              binding.ownsSource(workspace), let mapping = workspace.mappingOwnershipObservation(),
              mapping.coverage == .liveNativeSetters, mapping.scene == owner.sceneID.rawValue,
              mapping.owner == owner.managerID, mapping.source.event.phase == .available,
              mapping.source.event.epoch == mapping.epoch,
              ObjectIdentifier(mapping.source) == owner.observation.source,
              mapping.epoch == owner.observation.epoch, mapping.projection == owner.observation.projection,
              owner.observation.source == initial.source,
              owner.observation.epoch.sourceID == initial.epoch.sourceID,
              owner.observation.locale == initial.locale, Locale.current.identifier == initial.locale,
              mapping.projection.profileID == initial.projection.profileID,
              mapping.projection.groupID == initial.projection.groupID,
              mapping.projection.profileIDs == initial.projection.profileIDs,
              mapping.projection.groupIDs == initial.projection.groupIDs,
              initial.projection.targets.allSatisfy({ mapping.projection.targets[$0.key] == $0.value }) else {
            throw ActionPortError.staleState
        }
    }

    func installIntentDependency() {
        guard !intentsInstalled else { return }
        let service = NativeIntentService(discover: { [self] in
            do { return try await destinations() }
            catch { logIntentFailure(error, stage: "discovery"); throw error }
        }, resolveEntities: { [self] in
            do { return try await intentEntities() }
            catch { logIntentFailure(error, stage: "entities"); throw error }
        }, resolveReaderWindows: { [self] in
            do { return try intentRootEntities() }
            catch { logIntentFailure(error, stage: "reader_windows"); throw error }
        }, awaitForeground: { [self] in
            do { try await awaitIntentForeground($0) }
            catch { logIntentFailure(error, stage: "foreground"); throw error }
        }, navigate: { [self] in
            do { return try await open(destination: $0) }
            catch { logIntentFailure(error, stage: "navigation"); throw error }
        })
        AppDependencyManager.shared.add(dependency: service)
        let readerService = NativeReaderIntentService(execute: { [self] in
            do { return try await readerIntentMetadata($0) }
            catch { logIntentFailure(error, stage: "reader_metadata"); throw error }
        }, navigate: { [self] in
            do { return try await openReaderIntent($0) }
            catch { logIntentFailure(error, stage: "reader_navigation"); throw error }
        })
        AppDependencyManager.shared.add(dependency: readerService)
        #if DEBUG
        acceptanceReaderIntentService = readerService
        #endif
        intentsInstalled = true
    }

    private func logIntentFailure(_ error: any Error, stage: StaticString) {
        #if DEBUG
        // Only fixed internal codes cross this diagnostic boundary. Never log
        // the request, source, scene identity, token, query or error description.
        let route = error as? UIRouteError
        let journey = error as? NativeReaderIntentService.CommentaryDraftFailure
        let knownCodes: Set<String> = [
            "native_scene_busy", "native_scene_context_changed", "scene_changed_during_observation",
            "scene_lifetime_changed", "scene_not_foreground", "scene_not_mounted",
            "backend_generation_changed", "intent_source_generation_changed",
            "intent_window_no_longer_available", "intent_window_changed_during_activation",
            "intent_entity_no_longer_available", "deadline_exceeded", "native_effect_uncertain",
            "exact_note_selection_unavailable", "semantic_journey_not_completed",
            "backend_unavailable", "capability_unavailable", "invalid_backend_response",
            "note_draft_editor_unavailable", "scene_or_backend_changed"
        ]
        let rawCode = route?.code ?? journey?.code
        let code = rawCode.flatMap { knownCodes.contains($0) ? $0 : nil }
            ?? (error is CancellationError ? "cancelled" : "unclassified")
        let status = (route?.status ?? journey?.status)?.rawValue
            ?? (error is CancellationError ? "cancelled" : "unclassified")
        OtzariaFileLogger.shared.log("[NativeIntentFailure] stage=\(stage) status=\(status) code=\(code)")
        if let journey {
            let stepStatuses = journey.journey.steps.map { $0.status.rawValue }.joined(separator: ",")
            OtzariaFileLogger.shared.log(
                "[NativeIntentJourneyFailure] receipts=\(journey.receipts.count) stepStatuses=\(stepStatuses)")
        }
        #endif
    }
    func currentScene(sceneID: UIStableID, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws -> UISceneSnapshot {
        try await directory.currentScene(sceneID: sceneID, context: context, invocation: invocation)
    }
    func assess(_ descriptor: UIDestinationDescriptor, scene: UISceneSnapshot, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws -> UIRouteEligibility {
        let current = try await directory.currentScene(sceneID: scene.sceneID, context: context, invocation: invocation)
        guard current == scene, let entry = scenes[scene.sceneID] else { throw UIRouteError(.staleState, "scene_or_backend_changed") }
        let supported = descriptor.id.rawValue == "native.reader.inspector"
            ? try entry.session.publicBindingPresentation().inspectorAvailable
            : descriptor.id.rawValue == "native.settings" || entry.session.isRootAvailable(descriptor.id)
        return .init(sceneID: scene.sceneID, sceneRevision: current.revision, backendSnapshot: current.backendSnapshot,
                     supported: supported,
                     ready: entry.session.foreground && entry.session.mounted
                        && entry.session.isPresentationReady(for: descriptor.id), allowed: true)
    }
    private func deadline() -> UInt64 {
        let (value, overflow) = SystemActionClock().now().addingReportingOverflow(5_000_000_000)
        return overflow ? UInt64.max : value
    }
    private func record(_ result: UISceneAcknowledgement) {
        guard case .acknowledged(let receipt) = result else { return }
        // Only validated native acknowledgement reaches here. No private query,
        // note text, selected text or model arguments enter diagnostic logs.
        if let focus = receipt.route.focus, focus.kind == .component,
           focus.locator == nil, focus.range == nil, let anchor = focus.anchor,
           registry.descriptor(for: receipt.route.destination)?.anchors.contains(anchor) == true {
            OtzariaFileLogger.shared.log("[NativeFocusReceipt] request=\(receipt.requestId) scene=\(receipt.sceneID.rawValue) component=\(anchor.rawValue)")
        }
        OtzariaFileLogger.shared.log("[NativeNavigationReceipt] request=\(receipt.requestId) scene=\(receipt.sceneID.rawValue) backend=\(receipt.backendSnapshot.backend.rawValue) generation=\(receipt.backendSnapshot.generation) epoch=\(receipt.backendSnapshot.rpcEpoch.map(String.init) ?? "none") revision=\(receipt.basedOnSceneRevision)->\(receipt.appliedSceneRevision) destination=\(receipt.route.destination.rawValue) presentation=\(receipt.route.presentation.kind.rawValue)")
    }
}

/// Only forwards Core's original, opaque, one-use reader command to its
/// retained native owner. It cannot create grants, resolve or mint receipts.
@MainActor private final class MaktabahNativeReaderCommandSink: ActionCommentaryUICommandSink, ActionNoteDraftUICommandSink, ActionSearchResultsUICommandSink {

    var searchResultsAvailable: (@MainActor @Sendable (String) -> Bool)?
    func canOpenSearchResults(in sceneID: String) -> Bool { searchResultsAvailable?(sceneID) == true }
    var prepareSearch: (@MainActor (ActionSearchResultsQuery, ActionExecutionContext, ActionPortInvocation) async throws -> Void)?
    var deliverSearch: (@MainActor (ActionOpenSearchResultsCommand) async throws -> ActionSearchResultsAcknowledgement)?
    var completeSearch: (@MainActor (ActionOpenSearchResultsCommand, ActionSearchResultsReceipt) throws -> Void)?
    func prepareSearchResults(_ query: ActionSearchResultsQuery, context: ActionExecutionContext,
                              invocation: ActionPortInvocation) async throws {
        guard let prepareSearch else { throw ActionPortError.unavailable }
        try await prepareSearch(query, context, invocation)
    }
    func openSearchResults(_ command: ActionOpenSearchResultsCommand) async throws -> ActionSearchResultsAcknowledgement {
        guard let deliverSearch else { throw ActionPortError.unavailable }
        return try await deliverSearch(command)
    }
    func validateSearchResultsCompletion(_ command: ActionOpenSearchResultsCommand, receipt: ActionSearchResultsReceipt) throws {
        guard let completeSearch else { throw ActionPortError.unavailable }
        try completeSearch(command, receipt)
    }

    var deliver: (@MainActor @Sendable (ActionOpenReaderCommand) async throws -> ActionUIAcknowledgement)?
    var prepareCommentary: (@MainActor @Sendable (ActionReaderDestination, ActionExecutionContext, ActionPortInvocation) async throws -> Void)?
    var noteDraftAvailable: (@MainActor @Sendable (String) -> Bool)?
    var prepareNote: (@MainActor @Sendable (ActionNoteDraftRequest, ActionExecutionContext, ActionPortInvocation) async throws -> Void)?
    var presentNote: (@MainActor @Sendable (ActionPrepareNoteDraftCommand) async throws -> ActionNoteDraftAcknowledgement)?
    var validateNote: (@MainActor @Sendable (ActionNoteDraftReceipt, ActionPortInvocation) throws -> Void)?
    func canPrepareNoteDraft(in sceneID: String) -> Bool { noteDraftAvailable?(sceneID) == true }
    func prepareNoteDraft(_ draft: ActionNoteDraftRequest, context: ActionExecutionContext,
                          invocation: ActionPortInvocation) async throws {
        guard let prepareNote else { throw ActionPortError.unavailable }
        try await prepareNote(draft, context, invocation)
    }
    func presentNoteDraft(_ command: ActionPrepareNoteDraftCommand) async throws -> ActionNoteDraftAcknowledgement {
        guard let presentNote else { throw ActionPortError.unavailable }
        return try await presentNote(command)
    }
    func validateNoteDraftCompletion(_ receipt: ActionNoteDraftReceipt, invocation: ActionPortInvocation) throws {
        guard let validateNote else { throw ActionPortError.unavailable }
        try validateNote(receipt, invocation)
    }
    func prepareCommentaryReader(_ destination: ActionReaderDestination, context: ActionExecutionContext,
                                 invocation: ActionPortInvocation) async throws {
        guard let prepareCommentary else { throw ActionPortError.unavailable }
        try await prepareCommentary(destination, context, invocation)
    }
    func open(_ command: ActionOpenReaderCommand) async throws -> ActionUIAcknowledgement {
        guard let deliver else { throw ActionPortError.unavailable }
        return try await deliver(command)
    }
}

#if DEBUG
/// Explicit local acceptance trigger only. Production actions still run through
/// the original Composition -> Core -> Registry -> native owner and witnesses.
/// Each test provides a unique UUID and its own file in this app's Documents.
@MainActor struct MaktabahNativeActionAcceptanceProbe {
    let kind: String
    let token: UUID
    private let documents: URL

    init?(kind: String) {
        guard ["notes", "search", "commentary", "count", "journey-count-results",
               "journey-commentary-draft", "journey-catalog-stop"].contains(kind) else { return nil }
        let args = ProcessInfo.processInfo.arguments
        func value(_ key: String) -> String? {
            guard let i = args.firstIndex(of: key), args.indices.contains(i + 1) else { return nil }
            return args[i + 1]
        }
        guard OtzariaDataProfileRegistry.activeProfileID == "miniTest10",
              UUID(uuidString: UserDefaults.standard.string(forKey: "studyWorkspaceTestingNamespace") ?? "") != nil,
              value("-nativeActionAcceptanceKind") == kind,
              let raw = value("-nativeActionAcceptanceToken"), let token = UUID(uuidString: raw),
              let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        self.kind = kind; self.token = token; self.documents = documents
    }
    func argument(_ key: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: key), args.indices.contains(i + 1) else { return nil }
        return args[i + 1]
    }
    func json<T: Encodable>(_ value: T) throws -> Any {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
    }
    private var stem: String { "native-action-\(kind)-\(token.uuidString)" }
    private var trigger: URL { documents.appendingPathComponent(stem + "-trigger.txt") }
    private var result: URL { documents.appendingPathComponent(stem + "-result.json") }
    var hasResult: Bool { FileManager.default.fileExists(atPath: result.path) }

    func consumeTrigger() throws -> Bool {
        guard !FileManager.default.fileExists(atPath: result.path),
              FileManager.default.fileExists(atPath: trigger.path) else { return false }
        let attributes = try FileManager.default.attributesOfItem(atPath: trigger.path)
        guard (attributes[.size] as? NSNumber)?.intValue == token.uuidString.utf8.count,
              try String(contentsOf: trigger, encoding: .utf8) == token.uuidString else { return false }
        try FileManager.default.removeItem(at: trigger)
        return true
    }
    func write(phase: String = "result", payload: [String: Any]) throws {
        guard phase == "result" || phase == "closed" else { throw ProbeError.invalidPhase }
        let destination = documents.appendingPathComponent(stem + "-" + phase + ".json")
        guard !FileManager.default.fileExists(atPath: destination.path) else { return }
        let bytes = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        try bytes.write(to: destination, options: .atomic)
    }
    private enum ProbeError: Error { case invalidPhase }
}

// These DEBUG calls are opt-in for the exact disposable miniTest10 fixture.
// They invoke production entry points and observe original owners; they cannot
// supply a resolver answer, render text, mutate a receipt or save an Annotation.
extension MaktabahNativeRoutingComposition {
    private func actionAcceptanceSession(manager: iOSNavigationManager) -> MaktabahNativeSceneSession? {
        let matches = scenes.values.filter { $0.managerID == ObjectIdentifier(manager) }
        guard matches.count == 1, let session = matches.first?.session,
              session.mounted, session.foreground else { return nil }
        return session
    }

    func runNoteDraftAcceptanceProbe(manager: iOSNavigationManager, reader: ReaderViewModel,
                                    currentDraft: @escaping @MainActor () -> Annotation?) async {
        guard let probe = MaktabahNativeActionAcceptanceProbe(kind: "notes") else { return }
        do {
            for _ in 0..<900 {
                try Task.checkCancellation()
                if probe.hasResult { return }
                if MaktabahNativeInspectorBinding.currentReader(in: manager) === reader,
                   let session = actionAcceptanceSession(manager: manager), session.canPrepareNoteDraft(),
                   AnnotationRepository.shared.db != nil, let locator = reader.selectedSegmentLocator,
                   try probe.consumeTrigger() {
                    let ref = try ActionAppIdentityBridge.actionRef(locator)
                    let original = try AnnotationRepository.shared.loadAllAnnotations()
                    let proposal = "טיוטה ללא שמירה \(probe.token.uuidString)"
                    let result = try await prepareNoteDraft(locator: ref, proposedText: proposal, manager: manager)
                    let draft = currentDraft()
                    var payload: [String: Any] = [
                        "coreResult": try probe.json(result),
                        "originalStoreUnchanged": try AnnotationRepository.shared.loadAllAnnotations() == original,
                        "originalUnsavedEditor": draft != nil && draft?.id == nil,
                        "originalEditorOwnsProposal": draft?.note == proposal,
                        "processID": ProcessInfo.processInfo.processIdentifier,
                    ]
                    if let actual = draft?.backendLocator {
                        payload["originalDraftLocator"] = try probe.json(ActionAppIdentityBridge.actionRef(actual))
                    }
                    try probe.write(payload: payload)
                    // Only UITest's actual Cancel button dismisses the editor.
                    // Binding=nil alone is insufficient; await original onDismiss.
                    for _ in 0..<300 {
                        try Task.checkCancellation()
                        if currentDraft() == nil, session.isPresentationReady {
                            try probe.write(phase: "closed", payload: [
                                "originalStoreUnchanged": try AnnotationRepository.shared.loadAllAnnotations() == original,
                                "originalEditorDismissed": true,
                                "originalSceneReady": session.mounted && session.foreground && session.isPresentationReady,
                            ])
                            return
                        }
                        try await Task.sleep(for: .milliseconds(100))
                    }
                    try probe.write(phase: "closed", payload: ["probeError": "original_editor_dismissal_not_observed"])
                    return
                }
                try await Task.sleep(for: .milliseconds(100))
            }
            try probe.write(payload: ["probeError": "original_note_source_or_trigger_not_ready"])
        } catch is CancellationError {
            // An unmounted inactive reader must not overwrite the active owner's proof.
        } catch {
            try? probe.write(payload: ["probeError": "note_action_failed", "errorType": String(describing: type(of: error))])
        }
    }

    func runSearchResultsAcceptanceProbe(manager: iOSNavigationManager) async {
        guard let probe = MaktabahNativeActionAcceptanceProbe(kind: "search") else { return }
        do {
            guard let text = probe.argument("-nativeActionAcceptanceQuery"), !text.isEmpty else {
                try probe.write(payload: ["probeError": "missing_independent_query"]); return
            }
            let query = try ActionSearchResultsQuery(.init(backend: .otzaria, text: text))
            for _ in 0..<900 {
                try Task.checkCancellation()
                if probe.hasResult { return }
                if manager.currentMode == .search,
                   let scene = actionAcceptanceSession(manager: manager), scene.isPresentationReady,
                   try probe.consumeTrigger() {
                    let session = manager.unifiedSearchSession
                    let before = session.submissionRevision
                    let result = try await openSearchResults(query: query, manager: manager)
                    let rows: [[String: Any]] = try session.results.prefix(20).map { item in
                        var row: [String: Any] = ["stableID": item.stableID]
                        if let locator = item.backendLocator {
                            row["locator"] = try probe.json(ActionAppIdentityBridge.actionRef(locator))
                        }
                        return row
                    }
                    var payload: [String: Any] = [
                        "coreResult": try probe.json(result),
                        "originalQuery": session.query,
                        "originalSubmissionBefore": before,
                        "originalSubmissionAfter": session.submissionRevision,
                        "originalHasSubmitted": session.hasSubmitted,
                        "originalIsSearching": session.isSearching,
                        "originalResultsAreDirty": session.resultsAreDirty,
                        "originalBookIDs": session.selectedBookIds.sorted(),
                        "originalRows": rows,
                        "processID": ProcessInfo.processInfo.processIdentifier,
                    ]
                    if let error = session.errorMessage { payload["originalError"] = error }
                    try probe.write(payload: payload)
                    return
                }
                try await Task.sleep(for: .milliseconds(100))
            }
            try probe.write(payload: ["probeError": "original_search_scene_or_trigger_not_ready"])
        } catch is CancellationError {
        } catch {
            try? probe.write(payload: ["probeError": "search_action_failed", "errorType": String(describing: type(of: error))])
        }
    }


    /// Disposable miniTest10 acceptance caller only. It grants read access to
    /// the actual current Reader work, then uses the public Core contract.
    /// The registry, managed coverage policy, cached-engine lease and original
    /// Rust analyzer remain production code; this probe cannot open an index.
    private func runOccurrenceCountAcceptanceProbe(_ probe: MaktabahNativeActionAcceptanceProbe,
                                                    manager: iOSNavigationManager,
                                                    reader: ReaderViewModel) async {
        do {
            for _ in 0..<900 {
                try Task.checkCancellation()
                if probe.hasResult { return }
                let search = manager.unifiedSearchSession
                if manager.currentMode == .viewer,
                   MaktabahNativeInspectorBinding.currentReader(in: manager) === reader,
                   let scene = actionAcceptanceSession(manager: manager), scene.isPresentationReady,
                   search.hasSubmitted, !search.isSearching, !search.resultsAreDirty,
                   search.errorMessage == nil, search.query == "אברהם",
                   search.selectedBookIds.isEmpty, !search.results.isEmpty,
                   let locator = reader.selectedSegmentLocator, try probe.consumeTrigger() {
                    guard let entry = scenes[scene.sceneID], entry.session === scene else {
                        throw UIRouteError(.staleState, "count_acceptance_scene_changed")
                    }
                    let ref = try ActionAppIdentityBridge.actionRef(locator)
                    let source = try hanlinSource(sceneID: scene.sceneID, entry: entry)
                    guard ref.backend == .otzaria, ref.workKey == "book:1", source.backend.backend == .otzaria else {
                        throw UIRouteError(.unavailable, "count_acceptance_original_work_required")
                    }
                    let context = ActionExecutionContext(
                        subjectID: "maktabah.acceptance.count:" + probe.token.uuidString,
                        correlationID: probe.token, origin: .inApp,
                        allowedBackends: [.otzaria], contentRights: [.otzaria],
                        scopes: [.discovery, .contentRead],
                        allowedWorkKeys: [.otzaria: [ref.workKey]],
                        foregroundSceneID: scene.sceneID.rawValue, maxActions: 3)
                    try issue(context, sceneID: scene.sceneID)
                    defer { finish(context, sceneID: scene.sceneID) }
                    let submission = search.submissionRevision
                    let originalRows = search.results.map(\.stableID)
                    func requireSameOriginalSource() throws {
                        try Task.checkCancellation()
                        guard contexts[scene.sceneID] == context,
                              let live = scenes[scene.sceneID], live.session === scene,
                              manager.currentMode == .viewer,
                              MaktabahNativeInspectorBinding.currentReader(in: manager) === reader,
                              try hanlinSource(sceneID: scene.sceneID, entry: live) == source,
                              let current = reader.selectedSegmentLocator,
                              try ActionAppIdentityBridge.actionRef(current) == ref,
                              search.query == "אברהם", search.submissionRevision == submission,
                              search.hasSubmitted, !search.isSearching, !search.resultsAreDirty,
                              search.errorMessage == nil, search.selectedBookIds.isEmpty,
                              search.results.map(\.stableID) == originalRows else {
                            throw UIRouteError(.staleState, "count_acceptance_original_source_changed")
                        }
                    }
                    let work = ActionWorkRef(backend: ref.backend, workKey: ref.workKey)
                    func request(text: String, id: UUID = UUID()) throws -> ActionRequest {
                        .init(requestId: id, action: "search.countOccurrences", arguments: [
                            "text": .string(text), "scopeWorkRefs": try .encoded([work]),
                            "matchMode": .string("exact"), "countUnit": .string("matching_occurrences"),
                        ], expectedBackend: source.backend.backend, expectedGeneration: source.backend.generation,
                           requestedPresentation: .headless, deadlineMs: 10_000)
                    }
                    let countRequest = try request(text: "אברהם", id: probe.token)
                    let result = await core.execute(countRequest, context: context)
                    try requireSameOriginalSource()
                    // The original analyzer, not a whitespace check in this
                    // caller, must refuse two analyzed tokens without a scalar.
                    let unsupportedRequest = try request(text: "אברהם שלום")
                    let unsupported = await core.execute(unsupportedRequest, context: context)
                    try requireSameOriginalSource()
                    let cancelledRequest = try request(text: "אברהם")
                    // Both statements run on MainActor before the child can
                    // enter Core. This proves pre-cancelled admission only;
                    // it is not an in-flight engine cancellation assertion.
                    let cancelledTask = Task { @MainActor in
                        await self.core.execute(cancelledRequest, context: context)
                    }
                    cancelledTask.cancel()
                    let cancelled = await cancelledTask.value
                    try requireSameOriginalSource()
                    try probe.write(payload: [
                        "coreRequest": try probe.json(countRequest), "coreResult": try probe.json(result),
                        "unsupportedRequest": try probe.json(unsupportedRequest),
                        "unsupportedResult": try probe.json(unsupported),
                        "preCancelledRequest": try probe.json(cancelledRequest),
                        "preCancelledResult": try probe.json(cancelled),
                        "originalReaderLocator": try probe.json(ref),
                        "originalSourceUnchanged": true,
                        "originalBackendGeneration": source.backend.generation,
                        "originalSearchQuery": search.query,
                        "originalSearchSubmission": submission,
                        "originalSearchHasSubmitted": search.hasSubmitted,
                        "originalSearchIsSearching": search.isSearching,
                        "originalSearchResultsAreDirty": search.resultsAreDirty,
                        "originalSearchBookIDs": search.selectedBookIds.sorted(),
                        "originalSearchRowIDs": originalRows,
                        "originalSearchUnchanged": true,
                        "processID": ProcessInfo.processInfo.processIdentifier,
                    ])
                    return
                }
                try await Task.sleep(for: .milliseconds(100))
            }
            try probe.write(payload: ["probeError": "original_count_source_or_search_or_trigger_not_ready"])
        } catch is CancellationError {
            // An inactive Reader cannot publish another owner's result.
        } catch {
            try? probe.write(payload: ["probeError": "count_action_failed",
                                      "errorType": String(describing: type(of: error))])
        }
    }

    /// Only the explicitly launched disposable fixture can invoke this caller.
    /// The live one-work read authority is local to this invocation; it neither
    /// alters production discovery nor issues a Hanlin/model content grant.
    private func runSemanticCountResultsAcceptanceProbe(_ probe: MaktabahNativeActionAcceptanceProbe,
                                                        manager: iOSNavigationManager,
                                                        reader: ReaderViewModel) async {
        do {
            for _ in 0..<900 {
                try Task.checkCancellation()
                if probe.hasResult { return }
                let search = manager.unifiedSearchSession
                if manager.currentMode == .viewer,
                   MaktabahNativeInspectorBinding.currentReader(in: manager) === reader,
                   let scene = actionAcceptanceSession(manager: manager), scene.isPresentationReady,
                   search.hasSubmitted, !search.isSearching, !search.resultsAreDirty,
                   search.errorMessage == nil, search.query == "אברהם",
                   search.selectedBookIds.isEmpty, !search.results.isEmpty,
                   let locator = reader.selectedSegmentLocator,
                   let tabID = manager.activeTabId, try probe.consumeTrigger() {
                    // As in the original commentary probe, this explicit request
                    // belongs to Composition when its source View disappears.
                    await Task { @MainActor in
                        do {
                            guard let entry = self.scenes[scene.sceneID], entry.session === scene else {
                                throw ActionPortError.staleState
                            }
                            let ref = try ActionAppIdentityBridge.actionRef(locator)
                            let source = try self.hanlinSource(sceneID: scene.sceneID, entry: entry)
                            guard ref.backend == .otzaria, ref.workKey == "book:1",
                                  source.backend.backend == .otzaria,
                                  let loaded = source.currentWorkReadSource,
                                  loaded.readerOwner == ObjectIdentifier(reader) else {
                                throw ActionPortError.unavailable
                            }
                            let read = ActionExecutionContext(
                                subjectID: "maktabah.acceptance.journey:" + probe.token.uuidString,
                                correlationID: probe.token, origin: .inApp,
                                allowedBackends: [.otzaria], contentRights: [.otzaria],
                                scopes: [.discovery, .contentRead],
                                allowedWorkKeys: [.otzaria: [ref.workKey]],
                                foregroundSceneID: scene.sceneID.rawValue, maxActions: 1)
                            let query = ActionOccurrenceQuery(backend: ref.backend, text: "אברהם",
                                scopeWorkRefs: [.init(backend: ref.backend, workKey: ref.workKey)])
                            let submission = search.submissionRevision
                            var authorityObservations = 0
                            var authorityAfterSearch = 0
                            let observeRead: @MainActor () throws -> ActionExecutionContext = { [self] in
                                try Task.checkCancellation()
                                guard let live = scenes[scene.sceneID], live.session === scene,
                                      scene.mounted, scene.foreground,
                                      manager.activeTabId == tabID else { throw ActionPortError.staleState }
                                let tabs = manager.openTabs.filter { $0.id == tabID }
                                guard tabs.count == 1, tabs[0].viewModel === reader,
                                      reader.contentLoadCoordinator.currentRequestToken() == loaded.requestToken,
                                      reader.currentDestination == loaded.requested,
                                      reader.backendSection?.locator == loaded.loaded.sectionLocator,
                                      reader.selectedSegmentLocator == locator,
                                      case .loaded = reader.state else { throw ActionPortError.staleState }
                                let observed = try hanlinSource(sceneID: scene.sceneID, entry: live)
                                guard observed.backend == source.backend, observed.source == source.source,
                                      observed.epoch == source.epoch, observed.projection == source.projection,
                                      observed.locale == source.locale else { throw ActionPortError.staleState }
                                authorityObservations += 1
                                if manager.currentMode == .search { authorityAfterSearch += 1 }
                                return read
                            }
                            let journey = try await self.countThenOpenSearchResults(
                                query: query, manager: manager, readAuthority: observeRead)
                            let rows: [[String: Any]] = try search.results.prefix(20).map { item in
                                var row: [String: Any] = ["stableID": item.stableID]
                                if let actual = item.backendLocator {
                                    row["locator"] = try probe.json(ActionAppIdentityBridge.actionRef(actual))
                                }
                                return row
                            }
                            var payload: [String: Any] = [
                                "plannedActions": journey.plannedActions,
                                "steps": try probe.json(journey.steps),
                                "journeyComplete": journey.isComplete,
                                "originalReaderLocator": try probe.json(ref),
                                "originalBackendGeneration": source.backend.generation,
                                "readAuthorityObservations": authorityObservations,
                                "readAuthorityAfterSearch": authorityAfterSearch,
                                "originalQuery": search.query,
                                "originalExactScope": search.scope == .exact,
                                "originalSort": search.otzariaOrder.rawValue,
                                "originalSubmissionBefore": submission,
                                "originalSubmissionAfter": search.submissionRevision,
                                "originalHasSubmitted": search.hasSubmitted,
                                "originalIsSearching": search.isSearching,
                                "originalResultsAreDirty": search.resultsAreDirty,
                                "originalBookIDs": search.selectedBookIds.sorted(),
                                "originalModelBookIDs": manager.searchViewModel.selectedBookIds.sorted(),
                                "originalRows": rows,
                                "processID": ProcessInfo.processInfo.processIdentifier,
                            ]
                            if let error = search.errorMessage { payload["originalError"] = error }
                            try probe.write(payload: payload)
                        } catch {
                            try? probe.write(payload: ["probeError": "semantic_count_results_failed",
                                "errorType": String(describing: type(of: error))])
                        }
                    }.value
                    return
                }
                try await Task.sleep(for: .milliseconds(100))
            }
            try probe.write(payload: ["probeError": "semantic_count_source_or_trigger_not_ready"])
        } catch is CancellationError {
        } catch {
            try? probe.write(payload: ["probeError": "semantic_count_probe_failed"])
        }
    }

    private func runSemanticCommentaryDraftAcceptanceProbe(_ probe: MaktabahNativeActionAcceptanceProbe,
                                                           manager: iOSNavigationManager,
                                                           reader: ReaderViewModel) async {
        do {
            for _ in 0..<900 {
                try Task.checkCancellation()
                if probe.hasResult { return }
                if MaktabahNativeInspectorBinding.currentReader(in: manager) === reader,
                   let scene = actionAcceptanceSession(manager: manager), scene.isPresentationReady,
                   AnnotationRepository.shared.db != nil,
                   let base = reader.selectedSegmentLocator, try probe.consumeTrigger() {
                    await Task { @MainActor in
                        do {
                            let ref = try ActionAppIdentityBridge.actionRef(base)
                            let original = try AnnotationRepository.shared.loadAllAnnotations()
                            let proposal = "טיוטת מסע \(probe.token.uuidString)"
                            let journey: ActionSemanticJourneyResult
                            var intentReceipts: [UISceneReceipt] = []
                            if probe.kind == "journey-catalog-stop" {
                                guard let work = probe.argument("-nativeActionAcceptanceBaseWorkQuery"),
                                      let section = probe.argument("-nativeActionAcceptanceSection"),
                                      let commentary = probe.argument("-nativeActionAcceptanceCommentaryQuery") else {
                                    throw ActionPortError.invalidResponse
                                }
                                journey = try await self.resolveCommentaryThenPrepareDraft(
                                    backend: ref.backend, baseWorkQuery: work, section: section,
                                    commentaryQuery: commentary, proposedText: proposal, manager: manager)
                            } else {
                                guard let target = probe.argument("-nativeActionAcceptanceTargetWorkKey"),
                                      let service = self.acceptanceReaderIntentService,
                                      self.semanticIntentAcceptanceObserver == nil else {
                                    throw ActionPortError.invalidResponse
                                }
                                let windows = try self.intentRootEntities().filter {
                                    $0.destination.rawValue == "native.library" && $0.sceneID == scene.sceneID
                                        && $0.backend == ref.backend
                                }
                                guard windows.count == 1, let window = windows.first else { throw ActionPortError.staleState }
                                let baseWork = try NativeReaderIntentService.Work(reference:
                                    .init(backend: ref.backend, workKey: ref.workKey, catalogRevision: ref.catalogRevision), title: "")
                                let location = try NativeReaderIntentService.Location(reference: ref, title: "")
                                let targetWork = ActionWorkRef(backend: ref.backend, workKey: target)
                                let commentary = try NativeReaderIntentService.Work(reference: targetWork, title: "")
                                var observed: ActionSemanticJourneyResult?
                                var duplicateObservation = false
                                self.semanticIntentAcceptanceObserver = { request, result, receipts in
                                    guard request.locator == ref, request.windowIdentifier == window.id,
                                          let draft = request.commentaryDraft, draft.workRef == targetWork,
                                          draft.proposedText.utf8.elementsEqual(proposal.utf8) else { return }
                                    if observed != nil { duplicateObservation = true; return }
                                    observed = result; intentReceipts = receipts
                                }
                                defer { self.semanticIntentAcceptanceObserver = nil }
                                // This is the exact instance registered with AppDependencyManager.
                                // It re-resolves both entities and uses the production intent host.
                                let acknowledgement = try await service.open(workIdentifier: baseWork.id,
                                    locationIdentifier: location.id, windowIdentifier: window.id, newTab: true,
                                    commentaryWorkIdentifier: commentary.id, proposedText: proposal)
                                try NativeIntentOutcome.requireVisibleAcknowledgement(acknowledgement)
                                guard !duplicateObservation, let observed, intentReceipts.count == 2,
                                      case .acknowledged(let final) = acknowledgement,
                                      intentReceipts.last == final else { throw ActionPortError.invalidResponse }
                                journey = observed
                            }
                            let currentReader = MaktabahNativeInspectorBinding.currentReader(in: manager)
                            let editor = currentReader.flatMap { scene.noteDraftAcceptanceState(reader: $0) }
                            let draft = editor?.draft
                            var payload: [String: Any] = [
                                "plannedActions": journey.plannedActions,
                                "steps": try probe.json(journey.steps),
                                "journeyComplete": journey.isComplete,
                                "originalBaseLocator": try probe.json(ref),
                                "originalStoreUnchanged": try AnnotationRepository.shared.loadAllAnnotations() == original,
                                "originalEditorOwnerObserved": editor != nil,
                                "originalUnsavedEditor": draft != nil && draft?.id == nil,
                                "originalEditorOwnsProposal": draft?.note == proposal,
                                "originalEditorPresentationActive": editor?.presentationActive == true,
                                "processID": ProcessInfo.processInfo.processIdentifier,
                            ]
                            if probe.kind == "journey-commentary-draft" {
                                payload["productionConsumer"] = "NativeReaderIntentService.open"
                                payload["appIntentsSystemExecution"] = "NOT_RUN"
                                payload["nativeReceiptRequestIDs"] = intentReceipts.map { $0.requestId.uuidString }
                                payload["nativeReceiptSceneIDs"] = intentReceipts.map { $0.sceneID.rawValue }
                            }
                            if let actual = draft?.backendLocator {
                                payload["originalDraftLocator"] = try probe.json(ActionAppIdentityBridge.actionRef(actual))
                            }
                            try probe.write(payload: payload)
                            guard journey.isComplete, let currentReader, let editor, draft != nil else { return }
                            // Only the real UITest Cancel button closes the original
                            // editor. Unknown/replaced ownership can never certify nil.
                            for _ in 0..<300 {
                                try Task.checkCancellation()
                                if let observed = scene.noteDraftAcceptanceState(reader: currentReader),
                                   observed.ownerID == editor.ownerID, observed.draft == nil,
                                   !observed.presentationActive, scene.isPresentationReady {
                                    try probe.write(phase: "closed", payload: [
                                        "originalStoreUnchanged": try AnnotationRepository.shared.loadAllAnnotations() == original,
                                        "originalEditorDismissed": true,
                                        "originalSceneReady": scene.mounted && scene.foreground && scene.isPresentationReady,
                                        "originalEditorOwnerUnchanged": true,
                                    ])
                                    return
                                }
                                try await Task.sleep(for: .milliseconds(100))
                            }
                            try probe.write(phase: "closed", payload: ["probeError": "semantic_original_editor_dismissal_not_observed"])
                        } catch {
                            try? probe.write(payload: ["probeError": "semantic_commentary_draft_failed",
                                "errorType": String(describing: type(of: error))])
                        }
                    }.value
                    return
                }
                try await Task.sleep(for: .milliseconds(100))
            }
            try probe.write(payload: ["probeError": "semantic_commentary_source_or_trigger_not_ready"])
        } catch is CancellationError {
        } catch {
            try? probe.write(payload: ["probeError": "semantic_commentary_probe_failed"])
        }
    }

    func runCommentaryAcceptanceProbe(manager: iOSNavigationManager, reader: ReaderViewModel) async {
        if let probe = MaktabahNativeActionAcceptanceProbe(kind: "journey-count-results") {
            await runSemanticCountResultsAcceptanceProbe(probe, manager: manager, reader: reader)
            return
        }
        for kind in ["journey-commentary-draft", "journey-catalog-stop"] {
            if let probe = MaktabahNativeActionAcceptanceProbe(kind: kind) {
                await runSemanticCommentaryDraftAcceptanceProbe(probe, manager: manager, reader: reader)
                return
            }
        }
        if let probe = MaktabahNativeActionAcceptanceProbe(kind: "count") {
            await runOccurrenceCountAcceptanceProbe(probe, manager: manager, reader: reader)
            return
        }
        guard let probe = MaktabahNativeActionAcceptanceProbe(kind: "commentary") else { return }
        do {
            guard let workKey = probe.argument("-nativeActionAcceptanceTargetWorkKey") else {
                try probe.write(payload: ["probeError": "missing_source_commentary_work"]); return
            }
            for _ in 0..<900 {
                try Task.checkCancellation()
                if probe.hasResult { return }
                if MaktabahNativeInspectorBinding.currentReader(in: manager) === reader,
                   let scene = actionAcceptanceSession(manager: manager), scene.isPresentationReady,
                   let base = reader.selectedSegmentLocator, try probe.consumeTrigger() {
                    let ref = try ActionAppIdentityBridge.actionRef(base)
                    // The action changes the active tab. This explicit local
                    // request belongs to the composition, not the disappearing
                    // source View's task. Core owns its normal bounded lifetime.
                    await Task { @MainActor in
                        do {
                            let result = try await self.openCommentary(baseLocator: ref,
                                workRef: .init(backend: ref.backend, workKey: workKey), manager: manager)
                            try probe.write(payload: [
                                "coreResult": try probe.json(result),
                                "originalBaseLocator": try probe.json(ref),
                                "processID": ProcessInfo.processInfo.processIdentifier,
                            ])
                        } catch {
                            try? probe.write(payload: ["probeError": "commentary_action_failed",
                                "errorType": String(describing: type(of: error))])
                        }
                    }.value
                    return
                }
                try await Task.sleep(for: .milliseconds(100))
            }
            try probe.write(payload: ["probeError": "original_commentary_source_or_trigger_not_ready"])
        } catch is CancellationError {
        } catch {
            try? probe.write(payload: ["probeError": "commentary_probe_failed"])
        }
    }
}
#endif

#endif
