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
        var acknowledged: Bool
        let token: UUID
    }
    private var dispatches: [UUID: Dispatch] = [:]
    private var readerExecutions: [UIStableID: UUID] = [:]

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
        readerExecutions.removeValue(forKey: driver.sceneID)
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
    /// Future public-v2 consumer: retain the ORIGINAL binder-issued wrapper and
    /// the caller's original admission. Never re-prepare or re-admit here. The
    /// caller owns release after this full completion check (or full Core result
    /// for content, which still enters through the actual reader sink above).
    public func commitPrepared(_ prepared: UIAuthorizedSceneCommand,
                               admitted: ActionNavigationState) async -> UISceneAcknowledgement {
        guard prepared.command.route.route.content == nil else {
            return .notSupported(.init(code: "core_reader_command_required", message: "Use canonical reader.open."))
        }
        return await commitCurrent(prepared.command, context: admitted.context, reader: nil,
                                   originalPreparation: prepared, borrowedAdmission: admitted)
    }

    /// Inactive future consumer entry. The already configured canonical sink
    /// must retain this EXACT validated route and use Core's actual issued
    /// invocation/grant; this method installs no sink/route/renderer. The caller
    /// retains admission and producer subscription through the whole result.
    public func executeReaderPlan(_ retained: UIValidatedRoute, originalInvocation: ActionPortInvocation,
                                  admitted: ActionNavigationState) async throws -> ActionResult {
        guard let sceneID = retained.route.scene.sceneID, sceneID.rawValue == admitted.sceneID else { throw UIRouteError(.staleState, "native_context_changed") }
        guard drivers[sceneID] != nil else { throw UIRouteError(.unavailable, "scene_driver_missing") }
        if let old = dispatches[originalInvocation.requestId] {
            guard old.command.route == retained, old.context == admitted.context else { throw UIRouteError(.failed, "native_request_replay_conflict") }
            throw UIRouteError(old.active ? .unavailable : .staleState, old.active ? "native_request_in_progress" : "native_request_already_finished")
        }
        guard readerExecutions[sceneID] == nil, readerExecutions.count < 16 else { throw UIRouteError(.unavailable, "native_reader_execution_in_progress") }
        guard dispatches.count < capacity else { throw UIRouteError(.unavailable, "native_dispatch_ledger_full") }
        let executionToken = UUID()
        readerExecutions[sceneID] = executionToken
        defer { if readerExecutions[sceneID] == executionToken { readerExecutions.removeValue(forKey: sceneID) } }
        let phase = ReaderExecutionPhase()
        do {
            try validateReaderOwner(admitted, invocation: originalInvocation)
            let result = try await NativeObservationDeadline.run(until: originalInvocation.deadlineUptimeNanoseconds, clock: clock) { @MainActor [self] in
                try validateReaderOwner(admitted, invocation: originalInvocation)
                let request = try NativeReaderPlanBudget.request(for: retained, original: originalInvocation, now: clock.now())
                phase.coreStarted = true
                let result = await core.execute(request, context: admitted.context)
                if result.status == .completed {
                    try validateReaderOwner(admitted, invocation: originalInvocation)
                    try validateReaderReceipt(retained, admitted: admitted)
                }
                return result
            }
            // Leaving the structured scope is another await/cleanup boundary.
            if result.status == .completed {
                try validateReaderOwner(admitted, invocation: originalInvocation)
                try validateReaderReceipt(retained, admitted: admitted)
            }
            return result
        } catch {
            // Once Core starts, an outer deadline/cancellation/freshness failure
            // cannot assert that no native effect happened. No retry/rollback.
            if phase.coreStarted { throw UIRouteError(.failed, "native_effect_uncertain") }
            throw error
        }
    }

    private func validateReaderOwner(_ original: ActionNavigationState, invocation: ActionPortInvocation) throws {
        try Task.checkCancellation()
        guard clock.now() < invocation.deadlineUptimeNanoseconds else { throw UIRouteError(.cancelled, "deadline_exceeded") }
        let current = try authority.navigationState(sceneID: original.sceneID)
        guard Self.sameAdmission(original, current) else { throw UIRouteError(.staleState, "native_context_changed") }
        guard try backend.currentBackendSnapshot() == invocation.snapshot else { throw UIRouteError(.staleState, "backend_generation_changed") }
    }

    private static func sameAdmission(_ original: ActionNavigationState, _ current: ActionNavigationState) -> Bool {
        original.active && current.active && original.sceneID == current.sceneID && original.context == current.context
            && original.lifetimeID == current.lifetimeID && original.authorityRevision == current.authorityRevision
    }

    private func validateReaderReceipt(_ retained: UIValidatedRoute, admitted: ActionNavigationState) throws {
        guard let actual = dispatches[retained.route.requestId], actual.acknowledged, !actual.active,
              actual.command.route == retained, actual.context == admitted.context else {
            throw UIRouteError(.failed, "native_reader_receipt_missing")
        }
    }

    @MainActor private final class ReaderExecutionPhase { var coreStarted = false }
    private func commitCurrent(_ command: UISceneCommand, context: ActionExecutionContext,
                               reader: ActionOpenReaderCommand?, originalPreparation: UIAuthorizedSceneCommand? = nil,
                               borrowedAdmission: ActionNavigationState? = nil) async -> UISceneAcknowledgement {
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
            let ownsAdmission = reader == nil && originalPreparation == nil
            if ownsAdmission { admitted = try authority.admit(context: context, sceneID: sceneID) }
            else {
                let live = try authority.navigationState(sceneID: sceneID.rawValue)
                guard live.active, live.context == context else { throw UIRouteError(.staleState, "native_context_changed") }
                if let borrowedAdmission {
                    guard borrowedAdmission.sceneID == sceneID.rawValue, Self.sameAdmission(borrowedAdmission, live) else {
                        throw UIRouteError(.staleState, "native_context_changed")
                    }
                    admitted = borrowedAdmission
                } else { admitted = live }
            }
            // Content is admitted by the outer Core invocation owner. Its
            // retained grant must remain live through Core's own post-sink
            // completion check; only that outer owner releases it afterwards.
            defer { if ownsAdmission { authority.release(admitted) } }
            try driver.validateSurface(command)
            let token = UUID()
            dispatches[requestID] = Dispatch(command: command, context: context, dispatched: false, active: true, acknowledged: false, token: token)
            defer { if dispatches[requestID]?.token == token { dispatches[requestID]?.active = false } }
            let prepared: UIAuthorizedSceneCommand
            if let originalPreparation { prepared = originalPreparation }
            else if let reader { prepared = try command.prepareNavigation(readerCommand: reader) }
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
            guard let currentDriver = drivers[sceneID], currentDriver === driver,
                  dispatches[requestID]?.token == token else { throw UIRouteError(.staleState, "scene_lifetime_changed") }
            dispatches[requestID]?.acknowledged = true
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
