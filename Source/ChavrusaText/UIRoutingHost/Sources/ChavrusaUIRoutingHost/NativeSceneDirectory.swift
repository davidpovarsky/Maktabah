import Foundation
import OtzariaActionCore
import OtzariaUIRouting

/// Scene-owned observations. The closure reads native state, never a submitted
/// route payload. Lifetime checking is an application identity/revocation check;
/// it does not replace Core authorization.
@MainActor
public final class NativeSceneDirectory: UIDestinationEligibilityPort {
    public struct Observation: Sendable, Equatable {
        public let isForeground: Bool
        public let isMounted: Bool
        public let visibleRoute: RouteSpec?
        public let surface: NativeSurfaceState?
        public let identity: NativeSceneIdentity?
        public init(isForeground: Bool, isMounted: Bool, visibleRoute: RouteSpec?, surface: NativeSurfaceState? = nil, identity: NativeSceneIdentity? = nil) {
            self.isForeground = isForeground; self.isMounted = isMounted; self.visibleRoute = visibleRoute
            self.surface = surface
            self.identity = identity
        }
    }
    public struct Lease: Sendable, Equatable {
        public let sceneID: UIStableID
        public let lifetime: UUID
    }
    public typealias Observe = @MainActor @Sendable () throws -> Observation
    public typealias ValidateLifetime = @MainActor @Sendable (ActionExecutionContext) throws -> Void

    private struct Entry {
        let lease: Lease
        let observe: Observe
        let validate: ValidateLifetime
        var observation: Observation?
        var backend: ActionBackendSnapshot?
        var revision: UInt64
    }
    /// The application must inject the identical state object used by Core.
    private let authority: any ActionBackendStatePort
    private let clock: any ActionClock
    private let capacity: Int
    private var entries: [UIStableID: Entry] = [:]
    private var nextRevision: UInt64 = 0
    private var activeObservations = 0
    private let observationCapacity: Int

    public init(authority: any ActionBackendStatePort, clock: any ActionClock = SystemActionClock(),
                sceneCapacity: Int = 16, observationCapacity: Int = 32) throws {
        guard (1...64).contains(sceneCapacity), (1...128).contains(observationCapacity) else { throw UIRouteError(.failed, "invalid_host_capacity") }
        self.authority = authority; self.clock = clock; capacity = sceneCapacity; self.observationCapacity = observationCapacity
    }

    /// Duplicate IDs are rejected; mounting a second window cannot replace one.
    public func mount(sceneID: UIStableID, observe: @escaping Observe, validateLifetime: @escaping ValidateLifetime) throws -> Lease {
        guard entries[sceneID] == nil, entries.count < capacity else { throw UIRouteError(.unavailable, "scene_admission_rejected") }
        let lease = Lease(sceneID: sceneID, lifetime: UUID())
        entries[sceneID] = Entry(lease: lease, observe: observe, validate: validateLifetime, revision: try advance())
        return lease
    }

    public func unmount(_ lease: Lease) {
        guard entries[lease.sceneID]?.lease == lease else { return }
        entries.removeValue(forKey: lease.sceneID)
    }

    /// Call synchronously on native document/tab/selection/permission/workspace
    /// changes, even if the UI later returns to the same values (ABA).
    public func invalidate(_ lease: Lease) throws {
        guard var entry = entries[lease.sceneID], entry.lease == lease else { throw UIRouteError(.staleState, "scene_lifetime_changed") }
        entry.revision = try advance(); entry.observation = nil
        entries[lease.sceneID] = entry
    }

    public func snapshot(target: SceneTarget, context: ActionExecutionContext) async throws -> UISceneSnapshot {
        let sceneID: UIStableID
        switch target.kind {
        case .current:
            guard target.sceneID == nil, let trusted = context.foregroundSceneID.flatMap(UIStableID.init(rawValue:)) else {
                throw UIRouteError(.requiresForeground, "exact_foreground_scene_required")
            }
            sceneID = trusted
        case .specific:
            guard let specific = target.sceneID else { throw UIRouteError(.failed, "missing_scene_id") }
            sceneID = specific
        case .newWindow: throw UIRouteError(.notSupported, "new_window_not_registered")
        }
        try Task.checkCancellation()
        guard activeObservations < observationCapacity else { throw UIRouteError(.unavailable, "scene_observer_busy") }
        guard let entry = entries[sceneID] else { throw UIRouteError(.unavailable, "scene_missing") }
        try entry.validate(context)
        activeObservations += 1
        defer { activeObservations -= 1 }
        let (end, overflow) = clock.now().addingReportingOverflow(5_000_000_000)
        let deadline = overflow ? UInt64.max : end
        return try await NativeObservationDeadline.run(until: deadline, clock: clock) { [self] in
            let backend = try await authority.snapshot()
            let result = try await observeCurrent(sceneID: sceneID, context: context,
                invocation: .init(requestId: context.correlationID, snapshot: backend, deadlineUptimeNanoseconds: deadline))
            if let expected = target.expectedRevision, result.revision != expected { throw UIRouteError(.staleState, "scene_revision_changed") }
            return result
        }
    }

    public var mountedSceneCount: Int { entries.count }
    public var pendingObservationCount: Int { activeObservations }

    /// Immediately before Core's synchronous guard. The caller supplies the
    /// current snapshot read from the same retained synchronous S authority.
    public func synchronousScene(sceneID: UIStableID, context: ActionExecutionContext, backend: ActionBackendSnapshot) throws -> UISceneSnapshot {
        try Task.checkCancellation()
        guard var entry = entries[sceneID] else { throw UIRouteError(.unavailable, "scene_missing") }
        try entry.validate(context)
        let observation = try entry.observe()
        guard observation.isForeground else { throw UIRouteError(.requiresForeground, "exact_foreground_scene_required") }
        guard observation.isMounted else { throw UIRouteError(.uiQueued, "scene_not_mounted") }
        if backend.backend == .sefariaEmbedded, backend.rpcEpoch == nil { throw UIRouteError(.unavailable, "rpc_epoch_unavailable") }
        if entry.observation != observation || entry.backend != backend {
            entry.revision = try advance(); entry.observation = observation; entry.backend = backend
            entries[sceneID] = entry
        }
        return .init(sceneID: sceneID, revision: entry.revision, backendSnapshot: backend, visibleRoute: observation.visibleRoute)
    }

    private func advance() throws -> UInt64 {
        guard nextRevision < UInt64.max else { throw UIRouteError(.unavailable, "scene_revision_exhausted") }
        nextRevision += 1; return nextRevision
    }

    private func check(_ invocation: ActionPortInvocation) throws {
        try Task.checkCancellation()
        guard clock.now() < invocation.deadlineUptimeNanoseconds else { throw UIRouteError(.cancelled, "deadline_exceeded") }
    }

    public func currentScene(sceneID: UIStableID, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws -> UISceneSnapshot {
        try check(invocation)
        guard activeObservations < observationCapacity else { throw UIRouteError(.unavailable, "scene_observer_busy") }
        activeObservations += 1
        defer { activeObservations -= 1 }
        return try await NativeObservationDeadline.run(until: invocation.deadlineUptimeNanoseconds, clock: clock) { [self] in
            try await observeCurrent(sceneID: sceneID, context: context, invocation: invocation)
        }
    }

    private func observeCurrent(sceneID: UIStableID, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws -> UISceneSnapshot {
        guard let before = entries[sceneID] else { throw UIRouteError(.unavailable, "scene_missing") }
        try before.validate(context)
        let initial = try before.observe()
        // This await uses Core's authority, not a generation/epoch supplied in
        // route JSON. Recheck the exact scene lifetime and native state after it.
        let backend = try await authority.snapshot()
        try check(invocation)
        guard var current = entries[sceneID], current.lease == before.lease else { throw UIRouteError(.staleState, "scene_lifetime_changed") }
        guard current.revision == before.revision else { throw UIRouteError(.staleState, "scene_changed_during_observation") }
        try current.validate(context)
        let observed = try current.observe()
        guard observed == initial else { throw UIRouteError(.staleState, "scene_changed_during_observation") }
        guard backend == invocation.snapshot else { throw UIRouteError(.staleState, "backend_generation_changed") }
        if backend.backend == .sefariaEmbedded, backend.rpcEpoch == nil { throw UIRouteError(.unavailable, "rpc_epoch_unavailable") }
        if current.observation != observed || current.backend != backend {
            current.revision = try advance(); current.observation = observed; current.backend = backend
            entries[sceneID] = current
        }
        guard observed.isMounted else { throw UIRouteError(.uiQueued, "scene_not_mounted") }
        return UISceneSnapshot(sceneID: sceneID, revision: current.revision, backendSnapshot: backend, visibleRoute: observed.visibleRoute)
    }

    /// No native destination has been installed by the directory itself.
    /// Concrete scene drivers later supply support; inventory cannot grant it.
    public func assess(_ descriptor: UIDestinationDescriptor, scene: UISceneSnapshot, context: ActionExecutionContext,
                       invocation: ActionPortInvocation) async throws -> UIRouteEligibility {
        let current = try await currentScene(sceneID: scene.sceneID, context: context, invocation: invocation)
        guard current == scene else { throw UIRouteError(.staleState, "scene_or_backend_changed") }
        return UIRouteEligibility(sceneID: current.sceneID, sceneRevision: current.revision, backendSnapshot: current.backendSnapshot,
                                  supported: false, ready: false, allowed: false)
    }
}
