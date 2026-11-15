import Foundation
import OtzariaActionCore
import OtzariaUIRouting

/// One scene-owned observer, one outstanding presentation. Views report actual
/// native visibility and typed state following layout. No timer/AX-only success.
@MainActor
public final class NativePresentationObserver {
    public struct Visible: Sendable, Equatable {
        public let sceneID: UIStableID
        public let submissionID: UUID
        public let surface: NativeSurfaceState
        public init(sceneID: UIStableID, submissionID: UUID, surface: NativeSurfaceState) {
            self.sceneID = sceneID; self.submissionID = submissionID; self.surface = surface
        }
    }
    private let sceneID: UIStableID
    private let clock: any ActionClock
    private var pending: UISceneCommand?
    private var visible: Visible?
    private var continuation: CheckedContinuation<Visible, any Error>?
    public init(sceneID: UIStableID, clock: any ActionClock = SystemActionClock()) { self.sceneID = sceneID; self.clock = clock }
    public var submissionID: UUID? { pending?.invocation.requestId }
    public var pendingWaiterCount: Int { continuation == nil ? 0 : 1 }

    /// Reserve before the native synchronous mutation, so immediate native
    /// layout cannot be lost. Reservation itself authorizes no UI effects.
    public func begin(_ command: UISceneCommand) throws {
        try Task.checkCancellation()
        guard clock.now() < command.invocation.deadlineUptimeNanoseconds else { throw UIRouteError(.cancelled, "deadline_exceeded") }
        guard command.scene.sceneID == sceneID else { throw UIRouteError(.staleState, "scene_target_changed") }
        guard pending == nil else { throw UIRouteError(.unavailable, "scene_presentation_busy") }
        pending = command; visible = nil
    }

    public func report(_ value: Visible) {
        guard let pending, value.sceneID == sceneID, value.submissionID == pending.invocation.requestId,
              value.surface.observedRoute(for: pending, backend: pending.invocation.snapshot) == pending.route.route else { return }
        visible = value
        let waiter = continuation; continuation = nil
        waiter?.resume(returning: value)
    }

    public func wait(for command: UISceneCommand) async throws -> Visible {
        guard pending == command else { throw UIRouteError(.staleState, "presentation_binding_changed") }
        do {
            return try await NativeObservationDeadline.run(until: command.invocation.deadlineUptimeNanoseconds, clock: clock) { [self] in
                try await waitCurrent(command)
            }
        } catch {
            end(requestID: command.invocation.requestId, error: error)
            throw error
        }
    }
    private func waitCurrent(_ command: UISceneCommand) async throws -> Visible {
        try Task.checkCancellation()
        guard pending == command else { throw UIRouteError(.staleState, "presentation_binding_changed") }
        if let visible { return visible }
        guard continuation == nil else { throw UIRouteError(.unavailable, "scene_observer_busy") }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { waiter in
                if Task.isCancelled { waiter.resume(throwing: CancellationError()) }
                else { continuation = waiter }
            }
        } onCancel: { [weak self] in
            Task { @MainActor in self?.end(requestID: command.invocation.requestId, error: CancellationError()) }
        }
    }
    public func end(requestID: UUID, error: any Error = CancellationError()) {
        guard pending?.invocation.requestId == requestID else { return }
        pending = nil; visible = nil
        let waiter = continuation; continuation = nil
        waiter?.resume(throwing: error)
    }
    public func revoke() {
        if let id = submissionID { end(requestID: id, error: UIRouteError(.staleState, "scene_lifetime_changed")) }
    }
}
