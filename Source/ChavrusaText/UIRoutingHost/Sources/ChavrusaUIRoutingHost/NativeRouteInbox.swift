import Foundation
import OtzariaActionCore
import OtzariaUIRouting

/// Bounded, process-local cold/warm handoff. A queue handle is never a receipt
/// or authority. Scene selection must already be exact and trusted by the host.
/// Nothing persists private route state or silently targets a different window.
@MainActor
public final class NativeRouteInbox {
    public struct Pending: Sendable, Equatable {
        public let handle: String
        public let route: RouteSpec
        public let sceneID: UIStableID
        public let sceneLifetime: UUID
        public let subjectID: String
        public let correlationID: UUID
        public let origin: ActionOrigin
        public let deadline: UInt64
    }
    private let capacity: Int
    private let clock: any ActionClock
    private var entries: [UUID: Pending] = [:]
    public init(capacity: Int = 16, clock: any ActionClock = SystemActionClock()) throws {
        guard (1...64).contains(capacity) else { throw UIRouteError(.failed, "invalid_inbox_capacity") }
        self.capacity = capacity; self.clock = clock
    }
    public var count: Int { entries.count }

    public func enqueue(_ route: RouteSpec, sceneID: UIStableID, sceneLifetime: UUID,
                        context: ActionExecutionContext, deadline: UInt64) throws -> Pending {
        try Task.checkCancellation()
        guard clock.now() < deadline else { throw UIRouteError(.cancelled, "deadline_exceeded") }
        expire()
        if let old = entries[route.requestId] {
            guard old.route == route, old.sceneID == sceneID, old.sceneLifetime == sceneLifetime,
                  old.subjectID == context.subjectID, old.correlationID == context.correlationID,
                  old.origin == context.origin, old.deadline == deadline else { throw UIRouteError(.failed, "route_replay_conflict") }
            return old
        }
        guard entries.count < capacity else { throw UIRouteError(.unavailable, "route_inbox_full") }
        let value = Pending(handle: UUID().uuidString.replacingOccurrences(of: "-", with: ""), route: route,
                            sceneID: sceneID, sceneLifetime: sceneLifetime, subjectID: context.subjectID,
                            correlationID: context.correlationID, origin: context.origin, deadline: deadline)
        entries[route.requestId] = value
        return value
    }

    /// Removal is terminal: the caller reauthorizes with current Core context;
    /// queued context/handles never become restored permission grants.
    public func take(requestID: UUID, sceneID: UIStableID, sceneLifetime: UUID,
                     context: ActionExecutionContext) throws -> Pending? {
        try Task.checkCancellation()
        expire()
        guard let value = entries[requestID] else { return nil }
        guard value.sceneID == sceneID, value.sceneLifetime == sceneLifetime,
              value.subjectID == context.subjectID, value.correlationID == context.correlationID,
              value.origin == context.origin else { throw UIRouteError(.staleState, "queued_route_lifetime_changed") }
        entries.removeValue(forKey: requestID)
        return value
    }
    public func cancel(requestID: UUID, subjectID: String) {
        guard entries[requestID]?.subjectID == subjectID else { return }
        entries.removeValue(forKey: requestID)
    }
    public func revoke(sceneID: UIStableID, sceneLifetime: UUID) {
        entries = entries.filter { $0.value.sceneID != sceneID || $0.value.sceneLifetime != sceneLifetime }
    }
    public func expire() { entries = entries.filter { clock.now() < $0.value.deadline } }
}
