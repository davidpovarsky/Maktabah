#if os(iOS)
import Foundation
import Observation
import SwiftUI
import UIKit
import OtzariaUIRouting
import ChavrusaUIRoutingHost

/// One scene-owned adapter for the original, pinned Sefaria ReaderApp surface.
/// It neither replaces a Maktabah Reader nor accepts JS selectors/content actions.
@MainActor @Observable
final class MaktabahNativeSefariaSurfaceBinding: SefariaEmbeddedNativeSurfaceObserver {
    static let destination = UIDestinationID(rawValue: "native.sefariaEmbedded")!
    static func semanticTarget(for destination: UIDestinationID) -> SefariaEmbeddedSemanticTarget? {
        SefariaEmbeddedSemanticTarget.allCases.first { $0.destinationID == destination.rawValue }
    }
    static func accepts(_ destination: UIDestinationID) -> Bool {
        destination == Self.destination || semanticTarget(for: destination) != nil
    }
    struct PresentationFacets {
        let requested: Bool
        let mounted: Bool
        let visible: Bool
        let transitioning: Bool
        let ready: Bool
    }
    let sceneID: UIStableID
    private(set) var presentation: SefariaEmbeddedSurfaceIdentity?
    private(set) var renderRevision: UInt64 = 0
    @ObservationIgnored private let ownerID = UUID()
    @ObservationIgnored private weak var manager: iOSNavigationManager?
    @ObservationIgnored private let workspaceSource: MaktabahNativeWorkspaceProjectionSource
    @ObservationIgnored private var sources: [UUID: SourceEntry] = [:]
    @ObservationIgnored private var pending: Pending?
    @ObservationIgnored private var lease: SefariaEmbeddedSurfaceLease.Lease?
    @ObservationIgnored private weak var host: SefariaEmbeddedNativeSurfaceController?
    @ObservationIgnored private var presentationRevision: UInt64 = 0
    @ObservationIgnored private var presentationCreator: (requestID: UUID, identity: UUID)?
    @ObservationIgnored private var retired = false
    @ObservationIgnored private var readinessRequestID: UUID?
    @ObservationIgnored private var hostWaiter: Waiter?
    @ObservationIgnored private var invalidationWaiter: Waiter?
    @ObservationIgnored private var semanticWaiter: Waiter?
    @ObservationIgnored private var proof: ObservedProof?
    @ObservationIgnored private var completed: Completed?
    @ObservationIgnored private var changed: @MainActor () -> Void = {}
    @ObservationIgnored private var invalidated: @MainActor () -> Void = {}

    @MainActor private final class OriginalSourceProof {
        let runtime: SefariaEmbeddedSurfaceRuntimeToken
        private let observation: MaktabahNativeComponentSourceObservation
        private let source: MaktabahNativeWorkspaceProjectionSource
        private weak var workspace: StudyWorkspaceNavigationAdapter?
        private weak var manager: iOSNavigationManager?
        private let sceneID: String
        private let stored: StudyWorkspaceMappingObservation
        private let native: StudyWorkspaceMappingObservation
        private var valid = true

        static func inspect(sceneID: String, manager: iOSNavigationManager,
                            source: MaktabahNativeWorkspaceProjectionSource) throws
            -> (StudyWorkspaceNavigationAdapter, StudyWorkspaceMappingObservation, StudyWorkspaceMappingObservation) {
            guard source.isAuthoritative, let workspace = try source.read(),
                  workspace.sceneID == sceneID, workspace.attached, !workspace.isSwitching,
                  workspace.errorMessage == nil, workspace.store.loadError == nil,
                  !BackendCoordinator.shared.isTransitioning,
                  BackendCoordinator.shared.activeBackendID == .sefariaEmbedded,
                  BackendCoordinator.shared.activeCapabilities.contains(.catalog),
                  BackendCoordinator.shared.activeCapabilities.contains(.reading),
                  let stored = workspace.store.mappingObservation(scene: sceneID),
                  let native = workspace.mappingOwnershipObservation(),
                  stored.owner == ObjectIdentifier(workspace.store), stored.scene == sceneID,
                  native.owner == ObjectIdentifier(manager), native.scene == sceneID,
                  case .workspaceStoreOnly = stored.coverage,
                  case .liveNativeSetters = native.coverage else {
                throw UIRouteError(.unavailable, "native_sefaria_original_source_unavailable")
            }
            return (workspace, stored, native)
        }
        init(sceneID: String, manager: iOSNavigationManager,
             source: MaktabahNativeWorkspaceProjectionSource) throws {
            let publication = try source.originalPublication()
            var inspected: (StudyWorkspaceNavigationAdapter, StudyWorkspaceMappingObservation, StudyWorkspaceMappingObservation)?
            var inspectionError: (any Error)?
            // Register with the ORIGINAL owner before the first source getter.
            // The latch also precedes its prepublication/deinit callbacks.
            let captured = MaktabahNativeComponentSourceObservation(publications: [publication]) {
                do {
                    let current = try Self.inspect(sceneID: sceneID, manager: manager, source: source)
                    inspected = current
                    _ = current.0.attached; _ = current.0.isSwitching
                    _ = current.0.errorMessage; _ = current.0.store.loadError
                    _ = current.1.source.event; _ = current.2.source.event
                } catch { inspectionError = error }
            }
            if let inspectionError { throw inspectionError }
            guard let (workspace, stored, native) = inspected else {
                throw UIRouteError(.unavailable, "native_sefaria_original_source_unavailable")
            }
            try captured.validate()
            runtime = try SefariaJSRPCBridge.shared.retainSurfaceRuntime()
            self.workspace = workspace; self.manager = manager; self.source = source
            self.sceneID = sceneID; self.stored = stored; self.native = native
            observation = captured
        }
        var claimObservation: NativeComponentSourceObservation { observation.retainedClaimObservation }
        func invalidate() { valid = false; observation.invalidate() }
        func validate() throws {
            try runtime.validate(); try observation.validate()
            guard valid, let workspace, let manager, try source.read() === workspace else {
                throw UIRouteError(.staleState, "native_sefaria_original_source_changed")
            }
            let (actual, storedNow, nativeNow) = try Self.inspect(sceneID: sceneID, manager: manager, source: source)
            guard actual === workspace, storedNow.source === stored.source, storedNow.epoch == stored.epoch,
                  storedNow.owner == stored.owner, nativeNow.source === native.source,
                  nativeNow.epoch == native.epoch, nativeNow.owner == native.owner else {
                throw UIRouteError(.staleState, "native_sefaria_original_mapping_changed")
            }
        }
    }
    @MainActor private final class SourceEntry {
        let original: OriginalSourceProof
        let target: SefariaEmbeddedSemanticTarget?
        let parentClaimObservation: NativeComponentSourceObservation?
        let capturedLease: SefariaEmbeddedSurfaceLease.Snapshot
        var expectedRevision: UInt64
        var expectedPresentation: SefariaEmbeddedSurfaceIdentity?
        var expectedHost: UUID?
        var authorizedLease: SefariaEmbeddedSurfaceLease.Lease?
        init(original: OriginalSourceProof, capturedLease: SefariaEmbeddedSurfaceLease.Snapshot,
             revision: UInt64, presentation: SefariaEmbeddedSurfaceIdentity?, host: UUID?,
             lease: SefariaEmbeddedSurfaceLease.Lease?, target: SefariaEmbeddedSemanticTarget? = nil,
             parentClaimObservation: NativeComponentSourceObservation? = nil) {
            self.original = original; self.capturedLease = capturedLease; expectedRevision = revision
            self.target = target; self.parentClaimObservation = parentClaimObservation
            expectedPresentation = presentation; expectedHost = host; authorizedLease = lease
        }
    }
    private struct Pending {
        let token = UUID()
        let requestID: UUID
        let validate: @MainActor () throws -> Void
        var applied = false
        var openedNewSurface = false
        var deadlineUptimeNanoseconds: UInt64 = 0
        var semanticTicket: SefariaEmbeddedSemanticTicket? = nil
    }
    private struct RetainedRequest: Sendable {
        let requestID: UUID
        let pendingToken: UUID
        let source: SourceEntry
    }
    private struct ObservedProof {
        let requestID: UUID
        let nonce: UUID
        let value: SefariaEmbeddedSurfaceProof
        let hostToken: UUID
        let source: SourceEntry
        var semantic: SefariaEmbeddedSemanticProof? = nil
        var semanticTicket: SefariaEmbeddedSemanticTicket? = nil
    }
    private struct Completed {
        let observed: ObservedProof
        let identity: SefariaEmbeddedSurfaceIdentity
    }
    private struct Waiter {
        let request: RetainedRequest
        let token: UUID
        let continuation: CheckedContinuation<Void, any Error>
    }

    init(sceneID: UIStableID, manager: iOSNavigationManager,
         workspaceSource: MaktabahNativeWorkspaceProjectionSource) {
        self.sceneID = sceneID; self.manager = manager; self.workspaceSource = workspaceSource
    }
    func install(changed: @escaping @MainActor () -> Void, invalidated: @escaping @MainActor () -> Void) {
        self.changed = changed; self.invalidated = invalidated
    }
    func owns(_ workspace: StudyWorkspaceNavigationAdapter, manager: iOSNavigationManager) -> Bool {
        !retired && self.manager === manager && workspace.sceneID == sceneID.rawValue
            && (try? workspaceSource.read()) === workspace
    }
    var isAvailable: Bool {
        guard !retired, let manager, SefariaExpoLifecycleAdapter.shared.canCreateVisibleSurface,
              SefariaJSRPCBridge.shared.currentSurfaceRuntimeObservation.canPresent,
              (try? OriginalSourceProof.inspect(sceneID: sceneID.rawValue, manager: manager,
                                                source: workspaceSource)) != nil else { return false }
        let global = SefariaEmbeddedSurfaceLease.shared.snapshot
        guard !global.exhausted else { return false }
        if let identity = presentation {
            guard identity.epoch == SefariaJSRPCBridge.shared.currentSessionEpoch,
                  let lease, global.lease == lease, lease.identity == identity else { return false }
            if let pending, isContinuingAppliedRequest(requestID: pending.requestID) { return true }
            return host?.evidence()?.visible == true
        }
        return host == nil && lease == nil && global.lease == nil
    }
    var presentationFacets: PresentationFacets {
        let actual = host?.evidence()
        let ready = hasCurrentVisibleProof()
        return .init(requested: presentation != nil, mounted: actual?.mounted == true,
                     visible: actual?.visible == true, transitioning: actual?.transitioning == true,
                     ready: ready)
    }
    func retainSource(requestID: UUID, target: SefariaEmbeddedSemanticTarget? = nil,
                      parentClaimObservation: NativeComponentSourceObservation? = nil) throws {
        guard sources[requestID] == nil, pending == nil, isAvailable, let manager else {
            throw UIRouteError(.unavailable, "native_sefaria_surface_unavailable")
        }
        guard (target == nil) == (parentClaimObservation == nil) else {
            throw UIRouteError(.staleState, "native_sefaria_semantic_parent_missing")
        }
        let original = try OriginalSourceProof(sceneID: sceneID.rawValue, manager: manager, source: workspaceSource)
        let entry = SourceEntry(original: original, capturedLease: SefariaEmbeddedSurfaceLease.shared.snapshot,
            revision: presentationRevision, presentation: presentation, host: host?.token, lease: lease,
            target: target, parentClaimObservation: parentClaimObservation)
        try validate(entry)
        sources[requestID] = entry
    }
    func validateSource(requestID: UUID, target: SefariaEmbeddedSemanticTarget? = nil) throws {
        guard let entry = sources[requestID], entry.target == target else { throw UIRouteError(.staleState, "native_sefaria_source_not_retained") }
        try validate(entry)
    }
    private func validate(_ entry: SourceEntry) throws {
        try entry.original.validate()
        guard !retired, presentationRevision == entry.expectedRevision,
              presentation == entry.expectedPresentation, host?.token == entry.expectedHost else {
            throw UIRouteError(.staleState, "native_sefaria_surface_owner_changed")
        }
        if let authorized = entry.authorizedLease {
            guard lease == authorized, SefariaEmbeddedSurfaceLease.shared.owns(authorized) else {
                throw UIRouteError(.staleState, "native_sefaria_surface_lease_changed")
            }
        } else {
            guard lease == nil, SefariaEmbeddedSurfaceLease.shared.snapshot == entry.capturedLease else {
                throw UIRouteError(.staleState, "native_sefaria_surface_lease_changed")
            }
        }
    }
    func releaseSource(requestID: UUID) {
        guard let entry = sources.removeValue(forKey: requestID) else { return }
        // Only the exact completed receipt may retain its proof after the outer
        // public operation releases its map membership. An early/reentrant
        // release revokes the active operation and joins its normal cleanup.
        let retainsCompleted = pending == nil && completed?.observed.source === entry
        if !retainsCompleted { entry.original.invalidate() }
        if pending?.requestID == requestID { finish(requestID: requestID, completed: false) }
    }
    func begin(requestID: UUID, target: SefariaEmbeddedSemanticTarget? = nil,
               deadlineUptimeNanoseconds: UInt64 = 0,
               validate: @escaping @MainActor () throws -> Void) throws {
        guard pending == nil, let entry = sources[requestID] else {
            throw UIRouteError(.unavailable, "native_sefaria_surface_busy")
        }
        guard entry.target == target,
              target == nil || deadlineUptimeNanoseconds > DispatchTime.now().uptimeNanoseconds else {
            throw UIRouteError(.staleState, "native_sefaria_semantic_admission_changed")
        }
        try self.validate(entry); try validate()
        guard pending == nil, sources[requestID] === entry else {
            throw UIRouteError(.staleState, "native_sefaria_observation_changed")
        }
        try self.validate(entry)
        completed = nil
        pending = .init(requestID: requestID, validate: validate,
                        deadlineUptimeNanoseconds: deadlineUptimeNanoseconds)
    }
    /// Read-only: it never invokes the Session validator and cannot recursively
    /// make an unrelated transition look like this command's authorized mount.
    func isContinuingAppliedRequest(requestID: UUID) -> Bool {
        guard let pending, pending.requestID == requestID, pending.applied,
              let entry = sources[requestID], presentation != nil,
              entry.expectedPresentation == presentation else { return false }
        return (try? validate(entry)) != nil
    }
    private func withSource<T>(requestID: UUID, operation: @MainActor (SourceEntry) throws -> T) throws -> T {
        try withSource(request: retainedRequest(requestID), operation: operation)
    }
    private func retainedRequest(_ requestID: UUID) throws -> RetainedRequest {
        guard let entry = sources[requestID], let pending, pending.requestID == requestID else {
            throw UIRouteError(.staleState, "native_sefaria_observation_changed")
        }
        return .init(requestID: requestID, pendingToken: pending.token, source: entry)
    }
    private func validateMembership(_ request: RetainedRequest) throws {
        guard sources[request.requestID] === request.source,
              pending?.requestID == request.requestID, pending?.token == request.pendingToken else {
            throw UIRouteError(.staleState, "native_sefaria_observation_changed")
        }
    }
    private func withSource<T>(request: RetainedRequest, operation: @MainActor (SourceEntry) throws -> T) throws -> T {
        try validateMembership(request)
        let entry = request.source
        return try entry.original.runtime.withValidRuntime {
            try validateMembership(request); try validate(entry)
            guard let validateAdmission = pending?.validate else {
                throw UIRouteError(.staleState, "native_sefaria_observation_changed")
            }
            try validateAdmission()
            try validateMembership(request); try validate(entry)
            let value = try operation(entry)
            try validateMembership(request); try validate(entry)
            try validateAdmission()
            try validateMembership(request); try validate(entry)
            return value
        }
    }
    func apply(requestID: UUID) throws {
        try withSource(requestID: requestID) { entry in
            guard pending?.applied == false else { throw UIRouteError(.staleState, "native_sefaria_already_applied") }
            if presentation == nil {
                guard presentationRevision < .max else { throw UIRouteError(.unavailable, "native_sefaria_lifetime_exhausted") }
                let identity = SefariaEmbeddedSurfaceIdentity(id: UUID(), mountID: UUID(), sceneID: sceneID.rawValue,
                                                              epoch: entry.original.runtime.observation.epoch)
                let acquired = try SefariaEmbeddedSurfaceLease.shared.acquire(ownerID: ownerID, identity: identity,
                                                                             expected: entry.capturedLease)
                lease = acquired; entry.authorizedLease = acquired
                // Declare this one publication before SwiftUI observes it. No
                // source latch, backend epoch or original mapping is rearmed.
                presentationRevision += 1; entry.expectedRevision = presentationRevision
                entry.expectedPresentation = identity
                pending?.applied = true; pending?.openedNewSurface = true
                presentationCreator = (requestID, identity.id)
                presentation = identity
            } else { pending?.applied = true }
            if let target = entry.target {
                guard let identity = presentation, let parent = entry.parentClaimObservation,
                      let deadline = pending?.deadlineUptimeNanoseconds else {
                    throw UIRouteError(.staleState, "native_sefaria_semantic_admission_changed")
                }
                let ticket = try SefariaEmbeddedSemanticTicket(requestID: requestID, identity: identity,
                    target: target, deadlineUptimeNanoseconds: deadline, runtime: entry.original.runtime,
                    rootSource: parent, originalSource: entry.original.claimObservation)
                try SefariaEmbeddedSemanticHandoffs.shared.register(ticket)
                pending?.semanticTicket = ticket
            }
            proof = nil
        }
        signalChange(); resumeHostWaiterIfVisible()
    }
    /// Shared Session uses this only for the actual synchronous native report.
    /// The source lock stays held through that callback; no await is accepted.
    func withValidatedSurface<T>(requestID: UUID, _ operation: @MainActor () throws -> T) throws -> T {
        try withSource(requestID: requestID) { _ in
            guard pending?.applied == true, let proof, proof.requestID == requestID,
                  hasCurrentVisibleProof() else { throw UIRouteError(.unavailable, "native_sefaria_original_surface_not_visible") }
            return try operation()
        }
    }
    func finish(requestID: UUID, completed didComplete: Bool) {
        guard let pending, pending.requestID == requestID else { return }
        cancelWaiters(requestID: requestID)
        if didComplete, let proof, sources[requestID] === proof.source,
           proof.requestID == requestID, let presentation,
           hasCurrentVisibleProof(), (try? validate(proof.source)) != nil {
            completed = .init(observed: proof, identity: presentation)
        } else { completed = nil }
        if let ticket = pending.semanticTicket {
            SefariaEmbeddedSemanticHandoffs.shared.remove(ticket, revoke: completed == nil)
        }
        host?.stopSemanticObservation()
        self.pending = nil
        if completed == nil && pending.openedNewSurface, let identity = presentation { dismiss(identity: identity.id) }
    }
    func dismiss(identity: UUID) {
        guard presentation?.id == identity else { return }
        invalidateSources(); advancePresentationRevision(); presentationCreator = nil; presentation = nil
        if host == nil { releaseLease() }
        signalChange()
    }
    /// Diagnostic cleanup may run after cancellation or failed fresh evidence.
    /// Only the exact cold creator can dismiss its own still-current identity;
    /// warm/pre-apply/foreign requests never acquire this cleanup ownership.
    func dismissNewSurface(requestID: UUID) {
        guard let creator = presentationCreator, creator.requestID == requestID,
              presentation?.id == creator.identity else { return }
        dismiss(identity: creator.identity)
    }
    func retire() {
        guard !retired else { return }
        retired = true; invalidateSources(); presentationCreator = nil; presentation = nil
        if host == nil { releaseLease() }
        signalChange()
    }
    func unmount() {
        retire(); host?.detach(); host = nil; releaseLease()
        sources.removeAll(); pending = nil; completed = nil; proof = nil
        changed = {}; invalidated = {}
    }

    func surfaceWillAttach(_ controller: SefariaEmbeddedNativeSurfaceController) throws {
        guard let pending, pending.applied, pending.openedNewSurface, host == nil,
              presentation == controller.identity, let entry = sources[pending.requestID], entry.expectedHost == nil else {
            throw UIRouteError(.staleState, "native_sefaria_first_mount_not_owned")
        }
        try withSource(requestID: pending.requestID) { entry in
            entry.expectedHost = controller.token; host = controller
        }
    }
    func surfaceDidChange(_ controller: SefariaEmbeddedNativeSurfaceController) {
        guard host === controller, presentation == controller.identity else { return }
        if let ticket = pending?.semanticTicket, ticket.isArmed, controller.evidence()?.visible != true {
            ticket.revoke()
        }
        signalChange(); resumeHostWaiterIfVisible(); resumeSemanticWaiterIfVisible()
    }
    func surfaceWillDisappear(_ controller: SefariaEmbeddedNativeSurfaceController) {
        guard host === controller else { return }
        invalidateSources(); signalChange()
    }
    func surfaceDidDetach(_ controller: SefariaEmbeddedNativeSurfaceController) {
        guard host === controller else { return }
        invalidateSources(); host = nil; releaseLease(); advancePresentationRevision()
        if presentation == controller.identity { presentationCreator = nil; presentation = nil }
        signalChange()
    }
    func surfaceDidFail(_ controller: SefariaEmbeddedNativeSurfaceController, error: any Error) {
        guard host === controller || presentation == controller.identity else { return }
        OtzariaFileLogger.shared.log("[SefariaVisibleSurface] failed=\((error as? SefariaRPCError)?.code ?? (error as? UIRouteError)?.code ?? "native_surface_failed")")
        invalidateSources(); signalChange()
    }
    /// Await inside the Session's EXISTING structured observation/deadline task.
    /// No detached probe can outlive admission or publish after cancellation.
    func awaitOriginalSurface(requestID: UUID) async throws {
        guard readinessRequestID == nil, pending?.requestID == requestID, pending?.applied == true else {
            throw UIRouteError(.unavailable, "native_sefaria_readiness_busy")
        }
        let request = try retainedRequest(requestID)
        readinessRequestID = requestID
        defer {
            if readinessRequestID == requestID { readinessRequestID = nil }
            withExtendedLifetime(request.source) {}
        }
        try await waitForVisibleHost(request: request)
        try Task.checkCancellation()
        guard let identity = presentation, let controller = host, controller.identity == identity else {
            throw UIRouteError(.staleState, "native_sefaria_host_changed")
        }
        let nonce = UUID(), token = controller.token
        try withSource(request: request) { _ in }
        // Encoding and the actor RPC are outside the synchronous source lock.
        let params: [String: String] = ["surfaceID": identity.id.uuidString, "mountID": identity.mountID.uuidString,
            "sceneID": identity.sceneID, "nonce": nonce.uuidString]
        let json = String(decoding: try JSONEncoder().encode(params), as: UTF8.self)
        let response = try await withThrowingTaskGroup(of: SefariaRPCResponse.self) { group in
            group.addTask {
                try await SefariaJSRPCBridge.shared.call(method: "surface.awaitVisible", paramsJson: json,
                    generation: identity.epoch, timeoutMs: 5000)
            }
            group.addTask { [weak self] in
                guard let self else { throw CancellationError() }
                try await self.waitForInvalidation(request: request)
                throw CancellationError()
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else { throw CancellationError() }
            return result
        }
        try Task.checkCancellation()
        guard response.isSuccess else {
            throw response.error ?? SefariaRPCError(code: "SURFACE_PROOF_FAILED", message: "The original surface did not become ready.")
        }
        let observed = try response.decodeResult(SefariaEmbeddedSurfaceProof.self)
        try withSource(request: request) { entry in
            guard host === controller, controller.token == token, controller.identity == identity,
                  presentation == identity, observed.matches(identity, nonce: nonce),
                  proofFitsOriginalView(observed, controller: controller) else {
                throw UIRouteError(.staleState, "native_sefaria_visible_proof_changed")
            }
            proof = .init(requestID: requestID, nonce: nonce, value: observed, hostToken: token, source: entry)
        }
        if request.source.target != nil {
            try await awaitOriginalSemanticTarget(request: request, identity: identity, controller: controller)
        }
        signalChange()
    }

    private func awaitOriginalSemanticTarget(request: RetainedRequest, identity: SefariaEmbeddedSurfaceIdentity,
                                             controller: SefariaEmbeddedNativeSurfaceController) async throws {
        guard let ticket = pending?.semanticTicket, ticket.claim.requestID == request.requestID,
              request.source.target == ticket.claim.target else {
            throw UIRouteError(.staleState, "native_sefaria_semantic_ticket_missing")
        }
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try withSource(request: request) { _ in
                guard host === controller, controller.evidence()?.visible == true,
                      ticket.arm(originalHostToken: controller.token) else {
                    throw UIRouteError(.staleState, "native_sefaria_semantic_ticket_not_owned")
                }
            }
            let json = String(decoding: try JSONEncoder().encode(ticket.claim), as: UTF8.self)
            let response = try await withThrowingTaskGroup(of: SefariaRPCResponse.self) { group in
                group.addTask {
                    try await SefariaJSRPCBridge.shared.call(method: "surface.navigateOriginal", paramsJson: json,
                        generation: identity.epoch, timeoutMs: 5000)
                }
                group.addTask { [weak self] in
                    guard let self else { throw CancellationError() }
                    try await self.waitForInvalidation(request: request)
                    throw CancellationError()
                }
                defer { group.cancelAll() }
                guard let result = try await group.next() else { throw CancellationError() }
                return result
            }
            try Task.checkCancellation()
            guard response.isSuccess else {
                throw response.error ?? SefariaRPCError(code: "SEMANTIC_PROOF_FAILED", message: "The original destination was not revealed.")
            }
            let observed = try response.decodeResult(SefariaEmbeddedSemanticProof.self)
            try withSource(request: request) { entry in
                guard host === controller, presentation == identity,
                      ticket.matchesOriginalHost(controller.token), observed.matches(ticket, identity: identity),
                      proofFitsOriginalView(observed.originalSurface, controller: controller) else {
                    throw UIRouteError(.staleState, "native_sefaria_semantic_proof_changed")
                }
                proof = .init(requestID: request.requestID, nonce: ticket.claim.nonce,
                    value: observed.originalSurface, hostToken: controller.token, source: entry,
                    semantic: observed, semanticTicket: ticket)
            }
            // The JS selected state is not a UIKit acknowledgement. Observe the
            // actual original views until they really appear, under this same
            // command/deadline; source/cancellation still revokes the ticket.
            controller.observeSemanticTarget(ticket.claim.target, language: observed.interfaceLanguage)
            defer { controller.stopSemanticObservation() }
            try await waitForVisibleSemanticTarget(request: request)
            try Task.checkCancellation()
            try withSource(request: request) { _ in
                guard hasCurrentVisibleProof() else {
                    throw UIRouteError(.unavailable, "native_sefaria_original_target_not_visible")
                }
            }
        } onCancel: {
            // This cannot wait for the MainActor. A queued JS call has to see
            // revocation before it can consume its one original method ticket.
            ticket.revoke()
        }
    }

    private func waitForVisibleSemanticTarget(request: RetainedRequest) async throws {
        try withSource(request: request) { _ in }
        if hasCurrentVisibleProof() { return }
        let token = UUID(), requestID = request.requestID
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                guard semanticWaiter == nil else { continuation.resume(throwing: UIRouteError(.unavailable, "native_sefaria_semantic_wait_busy")); return }
                semanticWaiter = .init(request: request, token: token, continuation: continuation)
                if Task.isCancelled { cancelSemanticWaiter(requestID: requestID, token: token) }
                else { resumeSemanticWaiterIfVisible() }
            }
        } onCancel: { [weak self] in
            Task { @MainActor in self?.cancelSemanticWaiter(requestID: requestID, token: token) }
        }
    }
    private func resumeSemanticWaiterIfVisible() {
        guard let waiter = semanticWaiter else { return }
        do {
            try withSource(request: waiter.request) { _ in }
            guard pending?.semanticTicket?.canSupportEvidence == true else { throw CancellationError() }
            guard hasCurrentVisibleProof() else { return }
            semanticWaiter = nil; waiter.continuation.resume()
        } catch { semanticWaiter = nil; waiter.continuation.resume(throwing: error) }
    }
    private func cancelSemanticWaiter(requestID: UUID, token: UUID) {
        guard let waiter = semanticWaiter, waiter.request.requestID == requestID, waiter.token == token else { return }
        semanticWaiter = nil; waiter.continuation.resume(throwing: CancellationError())
    }
    private func waitForVisibleHost(request: RetainedRequest) async throws {
        let requestID = request.requestID
        try withSource(request: request) { _ in }
        if host?.evidence()?.visible == true { return }
        let token = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                guard hostWaiter == nil else { continuation.resume(throwing: UIRouteError(.unavailable, "native_sefaria_mount_busy")); return }
                hostWaiter = .init(request: request, token: token, continuation: continuation)
                if Task.isCancelled { cancelHostWaiter(requestID: requestID, token: token) }
                else { resumeHostWaiterIfVisible() }
            }
        } onCancel: { [weak self] in
            Task { @MainActor in self?.cancelHostWaiter(requestID: requestID, token: token) }
        }
    }
    private func waitForInvalidation(request: RetainedRequest) async throws {
        let requestID = request.requestID
        try withSource(request: request) { _ in }
        let token = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                guard invalidationWaiter == nil else { continuation.resume(throwing: UIRouteError(.unavailable, "native_sefaria_invalidation_busy")); return }
                invalidationWaiter = .init(request: request, token: token, continuation: continuation)
                if Task.isCancelled { cancelInvalidationWaiter(requestID: requestID, token: token) }
            }
        } onCancel: { [weak self] in
            Task { @MainActor in self?.cancelInvalidationWaiter(requestID: requestID, token: token) }
        }
    }
    private func resumeHostWaiterIfVisible() {
        guard let waiter = hostWaiter else { return }
        do {
            try withSource(request: waiter.request) { _ in }
            guard host?.evidence()?.visible == true else { return }
            hostWaiter = nil; waiter.continuation.resume()
        } catch { hostWaiter = nil; waiter.continuation.resume(throwing: error) }
    }
    private func cancelHostWaiter(requestID: UUID, token: UUID) {
        guard let waiter = hostWaiter, waiter.request.requestID == requestID, waiter.token == token else { return }
        hostWaiter = nil; waiter.continuation.resume(throwing: CancellationError())
    }
    private func cancelInvalidationWaiter(requestID: UUID, token: UUID) {
        guard let waiter = invalidationWaiter, waiter.request.requestID == requestID, waiter.token == token else { return }
        invalidationWaiter = nil; waiter.continuation.resume(throwing: CancellationError())
    }
    private func cancelWaiters(requestID: UUID) {
        if let waiter = hostWaiter { cancelHostWaiter(requestID: requestID, token: waiter.token) }
        if let waiter = invalidationWaiter { cancelInvalidationWaiter(requestID: requestID, token: waiter.token) }
        if let waiter = semanticWaiter { cancelSemanticWaiter(requestID: requestID, token: waiter.token) }
    }

    func acceptanceEvidence(for receipt: UISceneReceipt) throws -> SefariaEmbeddedSurfaceAcceptanceEvidence {
        guard pending == nil, let completed, receipt.requestId == completed.observed.requestID,
              completed.observed.source.target == nil,
              receipt.route.requestId == receipt.requestId, receipt.sceneID == sceneID,
              receipt.route.destination == Self.destination, receipt.route.presentation.kind == .sheet,
              receipt.route.content == nil, receipt.route.focus == nil,
              presentation == completed.identity else {
            throw UIRouteError(.staleState, "native_sefaria_receipt_not_owned")
        }
        return try completed.observed.source.original.runtime.withValidRuntime {
            try validate(completed.observed.source)
            guard hasCurrentVisibleProof(), host?.token == completed.observed.hostToken else {
                throw UIRouteError(.unavailable, "native_sefaria_receipt_no_longer_visible")
            }
            return .init(nativeReceiptID: receipt.requestId, nativeSceneID: sceneID.rawValue,
                nativeHostToken: completed.observed.hostToken,
                runtimeRevision: completed.observed.source.original.runtime.observation.revision,
                originalSurface: completed.observed.value)
        }
    }
    private func proofFitsOriginalView(_ value: SefariaEmbeddedSurfaceProof,
                                      controller: SefariaEmbeddedNativeSurfaceController) -> Bool {
        guard controller.evidence()?.visible == true, let original = controller.reactView else { return false }
        return abs(value.layout.width - Double(original.bounds.width)) <= 1
            && abs(value.layout.height - Double(original.bounds.height)) <= 1
    }
    private func hasCurrentVisibleProof() -> Bool {
        guard !retired, let proof, let identity = presentation, let controller = host,
              controller.token == proof.hostToken, controller.identity == identity,
              proof.value.matches(identity, nonce: proof.nonce),
              (try? validate(proof.source)) != nil else { return false }
        if let pending, !pending.applied || proof.requestID != pending.requestID { return false }
        guard proofFitsOriginalView(proof.value, controller: controller) else { return false }
        if let target = proof.source.target {
            guard let semantic = proof.semantic, let ticket = proof.semanticTicket,
                  semantic.claim.target == target, semantic.matches(ticket, identity: identity),
                  ticket.matchesOriginalHost(controller.token),
                  controller.semanticEvidence(target: target, language: semantic.interfaceLanguage) != nil else { return false }
        } else if proof.semantic != nil || proof.semanticTicket != nil { return false }
        return true
    }
    var observedDestination: UIDestinationID? {
        guard hasCurrentVisibleProof(), let proof else { return nil }
        return proof.source.target.flatMap { UIDestinationID(rawValue: $0.destinationID) } ?? Self.destination
    }
    func semanticAcceptanceEvidence(for receipt: UISceneReceipt) throws -> SefariaEmbeddedSemanticAcceptanceEvidence {
        guard pending == nil, let completed, let target = completed.observed.source.target,
              let semantic = completed.observed.semantic,
              receipt.requestId == completed.observed.requestID, receipt.route.requestId == receipt.requestId,
              receipt.sceneID == sceneID, receipt.route.destination.rawValue == target.destinationID,
              receipt.route.presentation.kind == .sheet, receipt.route.content == nil, receipt.route.focus == nil,
              presentation == completed.identity else {
            throw UIRouteError(.staleState, "native_sefaria_semantic_receipt_not_owned")
        }
        return try completed.observed.source.original.runtime.withValidRuntime {
            try validate(completed.observed.source)
            guard hasCurrentVisibleProof(), let controller = host,
                  controller.token == completed.observed.hostToken,
                  let actual = controller.semanticEvidence(target: target, language: semantic.interfaceLanguage) else {
                throw UIRouteError(.unavailable, "native_sefaria_semantic_receipt_no_longer_visible")
            }
            return .init(nativeReceiptID: receipt.requestId, nativeSceneID: sceneID.rawValue,
                nativeHostToken: controller.token,
                runtimeRevision: completed.observed.source.original.runtime.observation.revision,
                actualOriginalViewCount: actual.originalViews.count, originalTarget: semantic)
        }
    }
    private func invalidateSources() {
        if let ticket = pending?.semanticTicket { SefariaEmbeddedSemanticHandoffs.shared.remove(ticket, revoke: true) }
        host?.stopSemanticObservation()
        if let waiter = hostWaiter { hostWaiter = nil; waiter.continuation.resume(throwing: CancellationError()) }
        if let waiter = invalidationWaiter { invalidationWaiter = nil; waiter.continuation.resume(throwing: CancellationError()) }
        if let waiter = semanticWaiter { semanticWaiter = nil; waiter.continuation.resume(throwing: CancellationError()) }
        for source in sources.values { source.original.invalidate() }
        proof?.source.original.invalidate(); completed?.observed.source.original.invalidate()
        proof = nil; completed = nil; invalidated()
    }
    private func advancePresentationRevision() {
        if presentationRevision == .max { retired = true } else { presentationRevision += 1 }
    }
    private func releaseLease() {
        if let lease { SefariaEmbeddedSurfaceLease.shared.release(lease) }
        lease = nil
    }
    private func signalChange() {
        if renderRevision < .max { renderRevision += 1 } else { retired = true }
        changed()
    }
}
#endif
