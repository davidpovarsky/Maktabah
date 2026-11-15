import Foundation
import OtzariaActionCore
import OtzariaUIRouting

/// Adapter over existing native components. Apply must be synchronous and may
/// apply only the supplied full command. Resolve/content/policy stay in Core.
@MainActor public protocol NativeSceneDriver: AnyObject, Sendable {
    var sceneID: UIStableID { get }
    func validateSurface(_ command: UISceneCommand) throws
    func beginObservation(_ command: UISceneCommand) throws
    func apply(_ command: UISceneCommand) throws
    func waitUntilVisible(_ command: UISceneCommand) async throws -> NativeSurfaceState
    func endObservation(requestID: UUID)
}

/// A bounded native port, not a second semantic executor. Preparation comes
/// exclusively from the one retained Core actor. Native receipts require the
/// actual destination witness and a fresh same-authority scene observation.
@MainActor
public final class NativeSceneNavigationOrchestrator: UISceneNavigationPort {
    private let core: ActionExecutor
    private let backend: any ActionSynchronousBackendStatePort
    private let authority: NativeNavigationAuthority
    private let directory: NativeSceneDirectory
    private let capacity: Int
    private let clock: any ActionClock
    private var drivers: [UIStableID: any NativeSceneDriver] = [:]
    private struct Dispatch {
        let command: UISceneCommand
        let context: ActionExecutionContext
        var dispatched: Bool
        var active: Bool
        let token: UUID
    }
    private var dispatches: [UUID: Dispatch] = [:]

    public init(core: ActionExecutor, backend: any ActionSynchronousBackendStatePort, authority: NativeNavigationAuthority,
                directory: NativeSceneDirectory, dispatchCapacity: Int = 256, clock: any ActionClock = SystemActionClock()) throws {
        guard (1...512).contains(dispatchCapacity) else { throw UIRouteError(.failed, "invalid_dispatch_capacity") }
        self.core = core; self.backend = backend; self.authority = authority; self.directory = directory; capacity = dispatchCapacity
        self.clock = clock
    }
    public func register(_ driver: any NativeSceneDriver) throws {
        guard drivers[driver.sceneID] == nil, drivers.count < 16 else { throw UIRouteError(.unavailable, "scene_driver_admission_rejected") }
        drivers[driver.sceneID] = driver
    }
    public func unregister(_ driver: any NativeSceneDriver) {
        guard let current = drivers[driver.sceneID], current === driver else { return }
        drivers.removeValue(forKey: driver.sceneID)
        dispatches = dispatches.filter { $0.value.command.scene.sceneID != driver.sceneID }
    }
    public func snapshot(target: SceneTarget, context: ActionExecutionContext) async throws -> UISceneSnapshot {
        try await directory.snapshot(target: target, context: context)
    }
    public func commit(_ command: UISceneCommand, context: ActionExecutionContext) async throws -> UISceneAcknowledgement {
        guard command.route.route.content == nil else { return .notSupported(.init(code: "core_reader_command_required", message: "Use canonical reader.open.")) }
        return await commitCurrent(command, context: context, reader: nil)
    }
    /// Only the real Core sink may call this with its exact delivered command.
    public func commit(_ command: UISceneCommand, readerCommand: ActionOpenReaderCommand,
                       context: ActionExecutionContext) async -> UISceneAcknowledgement {
        await commitCurrent(command, context: context, reader: readerCommand)
    }
    private func commitCurrent(_ command: UISceneCommand, context: ActionExecutionContext,
                               reader: ActionOpenReaderCommand?) async -> UISceneAcknowledgement {
        let requestID = command.invocation.requestId, sceneID = command.scene.sceneID
        var didDispatch = false
        do {
            try Task.checkCancellation()
            if let old = dispatches[requestID] {
                guard old.command == command, old.context == context else { throw UIRouteError(.failed, "native_request_replay_conflict") }
                throw UIRouteError(old.active ? .unavailable : .staleState,
                    old.active ? "native_request_in_progress" : old.dispatched ? "native_effect_requires_reconciliation" : "native_request_already_finished")
            }
            guard dispatches.count < capacity else { throw UIRouteError(.unavailable, "native_dispatch_ledger_full") }
            guard let driver = drivers[sceneID] else { throw UIRouteError(.unavailable, "scene_driver_missing") }
            let admitted: ActionNavigationState
            if reader == nil { admitted = try authority.admit(context: context, sceneID: sceneID) }
            else {
                admitted = try authority.navigationState(sceneID: sceneID.rawValue)
                guard admitted.active, admitted.context == context else { throw UIRouteError(.staleState, "native_context_changed") }
            }
            // Content is admitted by the outer Core invocation owner. Its
            // retained grant must remain live through Core's own post-sink
            // completion check; only that outer owner releases it afterwards.
            defer { if reader == nil { authority.release(admitted) } }
            try driver.validateSurface(command)
            let token = UUID()
            dispatches[requestID] = Dispatch(command: command, context: context, dispatched: false, active: true, token: token)
            defer { if dispatches[requestID]?.token == token { dispatches[requestID]?.active = false } }
            let prepared: UIAuthorizedSceneCommand
            if let reader { prepared = try command.prepareNavigation(readerCommand: reader) }
            else { prepared = try await command.prepareNavigation(using: core, context: context) }
            // Recheck the actual driver identity after Core preparation awaits.
            guard let currentDriver = drivers[sceneID], currentDriver === driver else { throw UIRouteError(.staleState, "scene_lifetime_changed") }
            try driver.validateSurface(command)
            try driver.beginObservation(command)
            defer { driver.endObservation(requestID: requestID) }
            let current = try directory.synchronousScene(sceneID: sceneID, context: context, backend: backend.currentBackendSnapshot())
            try prepared.authorizeCommit(current: current)
            // No await between the ONE Core guard and actual native mutation.
            // Mark uncertainty before apply: a throwing driver may have effects.
            didDispatch = true; dispatches[requestID]?.dispatched = true
            try driver.apply(prepared.command)
            let visible = try await NativeObservationDeadline.run(until: command.invocation.deadlineUptimeNanoseconds, clock: clock) {
                try await driver.waitUntilVisible(command)
            }
            let observed = try await directory.currentScene(sceneID: sceneID, context: context, invocation: command.invocation)
            let observedRoute = visible.observedRoute(for: command, backend: observed.backendSnapshot)
            let coreReceipt = observedRoute.content.map {
                ActionUIReceipt(requestId: requestID, snapshot: observed.backendSnapshot, sceneID: observed.sceneID.rawValue, destination: $0)
            }
            let receipt = UISceneReceipt(requestId: requestID, route: observedRoute, backendSnapshot: observed.backendSnapshot,
                sceneID: observed.sceneID, basedOnSceneRevision: command.scene.revision, appliedSceneRevision: observed.revision, coreReceipt: coreReceipt)
            // The authority/context may have been revoked during layout waits.
            guard let live = try? authority.navigationState(sceneID: sceneID.rawValue), live.active, live.context == context, live.lifetimeID == admitted.lifetimeID,
                  live.authorityRevision == admitted.authorityRevision else { throw UIRouteError(.staleState, "native_context_changed") }
            // Retain and revalidate the ORIGINAL Core preparation after the
            // final native/directory awaits. N's context check alone cannot
            // certify current S generation/epoch/readiness/deadline authority.
            try prepared.validateCompletion(receipt: receipt, observed: observed)
            return .acknowledged(receipt)
        } catch {
            // Preserve failed pre-dispatch identity too: never auto-retry the
            // same request with a different route/context after a partial await.
            return acknowledgement(error, didDispatch: didDispatch)
        }
    }
    private func acknowledgement(_ error: any Error, didDispatch: Bool) -> UISceneAcknowledgement {
        let portStatus: ActionStatus?
        switch error as? ActionPortError {
        case .unavailable, .notFound: portStatus = .unavailable
        case .staleState: portStatus = .staleState
        case .notSupported: portStatus = .notSupported
        default: portStatus = nil
        }
        let status = (error as? UIRouteError)?.status ?? (error as? ActionNavigationError)?.status ?? portStatus ?? (error is CancellationError ? .cancelled : .failed)
        let code = didDispatch ? "native_effect_uncertain" : ((error as? UIRouteError)?.code ?? (error as? ActionNavigationError)?.code ?? "native_navigation_failed")
        let failure = ActionFailure(code: code, message: didDispatch ? "Native UI may have changed; completion was not verified." : "Native navigation was not completed.")
        switch status {
        case .requiresForeground: return .requiresForeground
        case .notSupported: return .notSupported(failure)
        case .unavailable: return .unavailable(failure)
        case .staleState: return .staleState(failure)
        case .requiresConfirmation: return .requiresConfirmation(failure)
        case .cancelled where !didDispatch: return .cancelled
        default: return .failed(failure)
        }
    }
}
