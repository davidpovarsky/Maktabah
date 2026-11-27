//
//  SefariaJSRPCBridge.swift
//  Maktabah
//
//  Downstream-owned asynchronous RPC bridge between Swift and Sefaria-Mobile JS runtime.
//  Enforces single-resume continuations, actor-owned timeout handling, zero leaks,
//  generation guards, and event listener dispatching.
//

import Foundation

protocol SefariaJSTransport: AnyObject, Sendable {
    func sendToJS(jsonString: String) async throws
}

/// A synchronous, source-owned observation of the same RPC lifecycle fields.
/// The revision also changes for repeated listener/ready lifecycle publications.
struct SefariaEmbeddedSurfaceRuntimeObservation: Sendable, Equatable {
    fileprivate(set) var epoch: UInt64 = 1
    fileprivate(set) var revision: UInt64 = 0
    fileprivate(set) var ready = false
    fileprivate(set) var listeners = false
    fileprivate(set) var transport = false
    fileprivate(set) var resourceMutation = false
    fileprivate(set) var transitioning = false
    fileprivate(set) var exhausted = false
    var canPresent: Bool { ready && listeners && transport && !resourceMutation && !transitioning && !exhausted }
}

/// The RPC actor owns its readiness fields. The original native module also
/// begins invalidation boundaries synchronously, BEFORE queueing actor updates.
/// The same recursive lock covers native commit/report and these publications.
/// No actor call or suspension is permitted in that native critical section.
fileprivate final class SefariaRPCSessionEpoch: @unchecked Sendable {
    private let lock = NSRecursiveLock()
    private var state = SefariaEmbeddedSurfaceRuntimeObservation()
    private var transitionDepth: UInt64 = 0
    func read() -> UInt64 { surface().epoch }
    func surface() -> SefariaEmbeddedSurfaceRuntimeObservation {
        lock.lock(); defer { lock.unlock() }; return state
    }
    func update(_ change: (inout SefariaEmbeddedSurfaceRuntimeObservation) -> Void) {
        lock.lock(); defer { lock.unlock() }
        change(&state)
        if state.revision == .max { state.exhausted = true } else { state.revision += 1 }
    }
    func write(_ value: UInt64) { update { $0.epoch = value } }
    // The public bump operation is also called directly by RuntimeManager.reset.
    // Nested callers keep the OUTERMOST lifecycle boundary closed. No callback
    // or continuation is invoked while this short state-publication lock is held.
    func beginTransition() {
        lock.lock(); defer { lock.unlock() }
        if transitionDepth == .max { state.exhausted = true }
        else { transitionDepth += 1 }
        update { $0.transitioning = true }
    }
    func endTransition() {
        lock.lock(); defer { lock.unlock() }
        guard transitionDepth > 0 else {
            update { $0.exhausted = true }; return
        }
        transitionDepth -= 1
        update { $0.transitioning = transitionDepth > 0 }
    }
    func retainSurface() throws -> SefariaEmbeddedSurfaceRuntimeToken {
        lock.lock(); defer { lock.unlock() }
        guard state.canPresent else { throw unavailable() }
        return .init(authority: self, observation: state)
    }
    func validate(_ expected: SefariaEmbeddedSurfaceRuntimeObservation) throws {
        lock.lock(); defer { lock.unlock() }
        guard state == expected, state.canPresent else { throw unavailable() }
    }
    @MainActor func withSurface<T>(_ expected: SefariaEmbeddedSurfaceRuntimeObservation,
                                  operation: @MainActor () throws -> T) throws -> T {
        lock.lock(); defer { lock.unlock() }
        guard state == expected, state.canPresent else { throw unavailable() }
        let value = try operation()
        guard state == expected, state.canPresent else { throw unavailable() }
        return value
    }
    private func unavailable() -> SefariaRPCError {
        .init(code: "SURFACE_RUNTIME_CHANGED", message: "The original Sefaria runtime is not available for this retained surface.")
    }
}

/// This token cannot be decoded from public navigation input or rearmed after a
/// lifecycle change. It retains the bridge's authority, not a MainActor cache.
final class SefariaEmbeddedSurfaceRuntimeToken: @unchecked Sendable {
    fileprivate let authority: SefariaRPCSessionEpoch
    let observation: SefariaEmbeddedSurfaceRuntimeObservation
    fileprivate init(authority: SefariaRPCSessionEpoch, observation: SefariaEmbeddedSurfaceRuntimeObservation) {
        self.authority = authority; self.observation = observation
    }
    func validate() throws { try authority.validate(observation) }
    @MainActor func withValidRuntime<T>(_ operation: @MainActor () throws -> T) throws -> T {
        try authority.withSurface(observation, operation: operation)
    }
}

/// One exact source-owned native lifecycle boundary. Queueing an actor update
/// never leaves a window in which its already-started native mutation can borrow
/// an earlier ready state. Nested/out-of-order boundaries stay closed until all
/// finish. Dropping an unfinished lease does NOT manufacture completion.
final class SefariaEmbeddedSurfaceRuntimeTransition: @unchecked Sendable {
    private let authority: SefariaRPCSessionEpoch
    private let completionLock = NSLock()
    private var finished = false
    fileprivate init(authority: SefariaRPCSessionEpoch) {
        self.authority = authority
        authority.beginTransition()
    }
    func finish() {
        completionLock.lock()
        guard !finished else { completionLock.unlock(); return }
        finished = true
        completionLock.unlock()
        authority.endTransition()
    }
}

/// Exact metadata for the original diagnostic RPC only. These values neither
/// authorize navigation nor alter normal RPC cancellation or response handling.
struct SefariaLateReplyDiagnosticToken: Sendable, Equatable {
    fileprivate let id: UUID
    let nonce: String
    let originalEpoch: UInt64
    let delayMs: Int
    let timeoutMs: Int
}

struct SefariaLateReplyDiagnosticEvidence: Codable, Sendable, Equatable {
    let requestID: String
    let nonce: String
    let originalEpoch: UInt64
    let currentEpoch: UInt64
    let jsReceived: Bool
    let originalCancellation: Bool
    let disposition: String
}

actor SefariaJSRPCBridge {
    static let shared = SefariaJSRPCBridge()

    private struct InFlightRequest {
        let continuation: CheckedContinuation<SefariaRPCResponse, any Error>
        let generation: UInt64
        let timeoutTask: Task<Void, Never>
    }

    private var transport: (any SefariaJSTransport)? {
        didSet { epochAuthority.update { $0.transport = transport != nil } }
    }
    private var inFlightRequests: [String: InFlightRequest] = [:]
    private var eventListeners: [String: [@Sendable (SefariaRPCEvent) -> Void]] = [:]

    private(set) var isReady: Bool {
        get { epochAuthority.surface().ready }
        set { epochAuthority.update { $0.ready = newValue } }
    }
    private(set) var hasActiveListeners: Bool {
        get { epochAuthority.surface().listeners }
        set { epochAuthority.update { $0.listeners = newValue } }
    }
    private nonisolated let epochAuthority = SefariaRPCSessionEpoch()
    private(set) var sessionEpoch: UInt64 {
        get { epochAuthority.read() }
        set { epochAuthority.write(newValue) }
    }
    nonisolated var currentSessionEpoch: UInt64 { epochAuthority.read() }
    private var resourceMutationInProgress: Bool {
        get { epochAuthority.surface().resourceMutation }
        set { epochAuthority.update { $0.resourceMutation = newValue } }
    }
    nonisolated var currentSurfaceRuntimeObservation: SefariaEmbeddedSurfaceRuntimeObservation {
        epochAuthority.surface()
    }
    nonisolated func retainSurfaceRuntime() throws -> SefariaEmbeddedSurfaceRuntimeToken {
        try epochAuthority.retainSurface()
    }
    nonisolated func beginSurfaceLifecycleTransition() -> SefariaEmbeddedSurfaceRuntimeTransition {
        .init(authority: epochAuthority)
    }

    var resourcesAreStable: Bool { !resourceMutationInProgress }

    var hasTransport: Bool {
        return transport != nil
    }

    var isTransportReady: Bool {
        return isReady && transport != nil && hasActiveListeners
    }

    private init() {}

    func setSessionEpoch(_ epoch: UInt64) {
        guard epoch != sessionEpoch else { return }
        epochAuthority.beginTransition()
        defer { epochAuthority.endTransition() }
        cancelAll(reason: "Session epoch changed")
        isReady = false
        self.sessionEpoch = epoch
    }

    func bumpSessionEpoch() -> UInt64 {
        epochAuthority.beginTransition()
        defer { epochAuthority.endTransition() }
        cancelAll(reason: "Session epoch changed")
        sessionEpoch &+= 1
        return sessionEpoch
    }

    func setTransport(_ transport: (any SefariaJSTransport)?) {
        if let current = self.transport, let transport, current === transport { return }
        epochAuthority.beginTransition()
        defer { epochAuthority.endTransition() }
        // A replacement host must repeat its handshake. Old requests and
        // readiness cannot be carried across two Hermes instances.
        _ = bumpSessionEpoch()
        isReady = false
        hasActiveListeners = false
        self.transport = transport
        if transport == nil {
            self.isReady = false
            self.hasActiveListeners = false
            cancelAll(reason: "Transport detached")
        }
    }

    func clearTransportIfMatches(_ transport: any SefariaJSTransport) {
        if let current = self.transport, (current as AnyObject) === (transport as AnyObject) {
            epochAuthority.beginTransition()
            defer { epochAuthority.endTransition() }
            NSLog("[SefariaJSRPCBridge] clearTransportIfMatches: clearing transport")
            self.transport = nil
            _ = bumpSessionEpoch()
            self.isReady = false
            self.hasActiveListeners = false
            cancelAll(reason: "Transport invalidated")
        }
    }

    func notifyListenersActive(_ active: Bool) {
        NSLog("[SefariaJSRPCBridge] notifyListenersActive: %d", active)
        self.hasActiveListeners = active
    }

    /// Awaits validated readiness from the Sefaria Hermes runtime with generation and listener checks.
    func waitForReady(timeoutSeconds: Double = 30.0, expectedGeneration: UInt64? = nil) async throws {
        if isTransportReady {
            if let expected = expectedGeneration, sessionEpoch != expected {
                // Not matching expected generation, continue waiting below
            } else {
                NSLog("[SefariaJSRPCBridge] waitForReady: already ready with active transport and listeners")
                return
            }
        }

        NSLog("[SefariaJSRPCBridge] waitForReady: awaiting ready event (timeout: %.1fs)...", timeoutSeconds)
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if isReady && transport != nil && hasActiveListeners {
                if let expected = expectedGeneration, sessionEpoch != expected {
                    // Waiting for matching epoch
                } else {
                    NSLog("[SefariaJSRPCBridge] waitForReady: successfully became ready!")
                    return
                }
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        if isReady && transport != nil && hasActiveListeners {
            if let expected = expectedGeneration, sessionEpoch != expected {
                // Mismatch
            } else {
                return
            }
        }

        let state = "isReady=\(isReady), transport=\(transport != nil), hasListeners=\(hasActiveListeners), sessionEpoch=\(sessionEpoch)"
        NSLog("[SefariaJSRPCBridge] waitForReady FAILED: %@", state)
        throw SefariaRPCError(
            code: "READY_TIMEOUT",
            message: "Timed out waiting for Sefaria JS runtime 'ready' event after \(timeoutSeconds)s (\(state))",
            retryable: true
        )
    }

    private func notifyReady() {
        NSLog("[SefariaJSRPCBridge] notifyReady: Hermes runtime ready event received!")
        isReady = true
    }

    /// Dispatches an RPC call to the Sefaria runtime with bounded timeout, generation tracking,
    /// and cancellation-safe continuation management.
    func call(
        method: String,
        paramsJson: String? = nil,
        generation: UInt64? = nil,
        timeoutMs: Int = 15000
    ) async throws -> SefariaRPCResponse {
        try Task.checkCancellation()
        // Invalidate read snapshots at both boundaries of a resource mutation.
        // Read-only action discovery never initiates one of these operations.
        let mutatesResources = ["downloads.install", "downloads.remove", "updates.download"].contains(method)
        if mutatesResources {
            guard !resourceMutationInProgress else {
                throw SefariaRPCError(code: "RESOURCE_BUSY", message: "Another resource operation is active", retryable: true)
            }
            if let generation, generation != sessionEpoch {
                throw SefariaRPCError(code: "STALE_GENERATION", message: "RPC session changed", retryable: true)
            }
            epochAuthority.beginTransition()
            _ = bumpSessionEpoch()
            resourceMutationInProgress = true
            epochAuthority.endTransition()
        }
        defer {
            if mutatesResources {
                epochAuthority.beginTransition()
                resourceMutationInProgress = false
                _ = bumpSessionEpoch()
                epochAuthority.endTransition()
            }
        }
        let requestID = UUID().uuidString
        let effectiveGeneration = mutatesResources ? sessionEpoch : generation ?? sessionEpoch
        guard effectiveGeneration == sessionEpoch else {
            throw SefariaRPCError(code: "STALE_GENERATION", message: "RPC session changed", retryable: true)
        }
        guard timeoutMs > 0, timeoutMs <= 600_000 else {
            throw SefariaRPCError(code: "INVALID_TIMEOUT", message: "RPC timeout is outside supported bounds")
        }
        let envelope = SefariaRPCEnvelope(
            protocolVersion: "1.0",
            requestID: requestID,
            method: method,
            paramsJson: paramsJson,
            backendID: BackendID.sefariaEmbedded.rawValue,
            sessionGeneration: effectiveGeneration,
            timeoutMs: timeoutMs
        )

        guard let transport = self.transport else {
            throw SefariaRPCError(
                code: "TRANSPORT_UNAVAILABLE",
                message: "React Native transport bridge is not initialized or ready.",
                retryable: true
            )
        }

        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(envelope),
              let jsonString = String(data: data, encoding: .utf8) else {
            throw SefariaRPCError(
                code: "ENVELOPE_ENCODING_FAILED",
                message: "Failed to encode RPC envelope for method '\(method)'"
            )
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.registerInFlight(
                    requestID: requestID,
                    continuation: continuation,
                    generation: effectiveGeneration,
                    timeoutMs: timeoutMs,
                    method: method
                )
                self.observeLateReplyDispatch(envelope)
                Task {
                    do {
                        guard self.inFlightRequests[requestID] != nil,
                              self.sessionEpoch == effectiveGeneration else { return }
                        try await transport.sendToJS(jsonString: jsonString)
                    } catch {
                        self.failInFlight(requestID: requestID, error: error)
                    }
                }
            }
        } onCancel: {
            Task {
                await self.cancelInFlight(requestID: requestID)
            }
        }
    }

    private func registerInFlight(
        requestID: String,
        continuation: CheckedContinuation<SefariaRPCResponse, any Error>,
        generation: UInt64,
        timeoutMs: Int,
        method: String
    ) {
        let timeoutTask = Task { [weak self, requestID, method, timeoutMs] in
            try? await Task.sleep(nanoseconds: UInt64(timeoutMs) * 1_000_000)
            await self?.handleTimeout(requestID: requestID, method: method, timeoutMs: timeoutMs)
        }
        inFlightRequests[requestID] = InFlightRequest(
            continuation: continuation,
            generation: generation,
            timeoutTask: timeoutTask
        )
    }

    private func handleTimeout(requestID: String, method: String, timeoutMs: Int) {
        guard let req = inFlightRequests.removeValue(forKey: requestID) else { return }
        req.continuation.resume(throwing: SefariaRPCError(
            code: "TIMEOUT",
            message: "RPC call to '\(method)' timed out after \(timeoutMs)ms",
            retryable: true
        ))
    }

    func handleIncomingResponse(jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let response = try? JSONDecoder().decode(SefariaRPCResponse.self, from: data) else {
            return
        }

        guard let req = inFlightRequests.removeValue(forKey: response.requestID) else {
            // Late response after timeout or stale request - safely ignored
            observeLateReplyResponse(response, wasInFlight: false)
            return
        }
        observeLateReplyResponse(response, wasInFlight: true)
        req.timeoutTask.cancel()

        // Validate protocol version
        if response.protocolVersion != "1.0" {
            req.continuation.resume(throwing: SefariaRPCError(
                code: "PROTOCOL_VERSION_MISMATCH",
                message: "Response protocol version '\(response.protocolVersion)' is incompatible with expected '1.0'",
                retryable: false
            ))
            return
        }

        // Validate backend ID if specified in response
        if let backendID = response.backendID, !backendID.isEmpty, backendID != BackendID.sefariaEmbedded.rawValue {
            req.continuation.resume(throwing: SefariaRPCError(
                code: "BACKEND_MISMATCH",
                message: "Response backend '\(backendID)' does not match expected '\(BackendID.sefariaEmbedded.rawValue)'",
                retryable: false
            ))
            return
        }

        // Strict generation validation: response must match in-flight generation (no zero-bypass)
        if response.sessionGeneration != req.generation || req.generation != sessionEpoch {
            req.continuation.resume(throwing: SefariaRPCError(
                code: "STALE_GENERATION",
                message: "Response generation \(response.sessionGeneration) does not match in-flight generation \(req.generation)",
                retryable: false
            ))
            return
        }

        req.continuation.resume(returning: response)
    }

    private func failInFlight(requestID: String, error: any Error) {
        guard let req = inFlightRequests.removeValue(forKey: requestID) else { return }
        req.timeoutTask.cancel()
        req.continuation.resume(throwing: error)
    }

    private func cancelInFlight(requestID: String) {
        guard let req = inFlightRequests.removeValue(forKey: requestID) else { return }
        req.timeoutTask.cancel()
        req.continuation.resume(throwing: CancellationError())
    }

    /// Cancels all pending in-flight requests (e.g. during a backend switch or runtime reset).
    func cancelAll(reason: String = "Session invalidated") {
        for (requestID, req) in inFlightRequests {
            observeLateReplyCancellation(requestID: requestID, generation: req.generation, reason: reason)
            req.timeoutTask.cancel()
            req.continuation.resume(throwing: SefariaRPCError(code: "CANCELLED", message: reason, retryable: false))
        }
        inFlightRequests.removeAll()
    }

    func cancelAllInFlight() {
        cancelAll(reason: "Backend invalidated")
    }

    // MARK: - Bounded real-transport diagnostic observation

    private struct LateReplyWireProof: Decodable {
        let contract: String
        let requestID: String
        let nonce: String
        let sessionGeneration: UInt64
        let delayMs: Int
    }
    private struct LateReplyParameters: Decodable {
        struct Options: Decodable {
            let contract: String
            let nonce: String
            let delayMs: Int
        }
        let lateReplyDiagnostic: Options
    }
    private struct LateReplyResult: Decodable {
        let lateReplyDiagnostic: LateReplyWireProof
    }
    private final class LateReplyObservation {
        let token: SefariaLateReplyDiagnosticToken
        let transport: any SefariaJSTransport
        let deadline: ContinuousClock.Instant
        var requestID: String?
        var jsReceived = false
        var originalCancellation = false
        var discarded: SefariaLateReplyDiagnosticEvidence?
        var failure: SefariaRPCError?
        init(token: SefariaLateReplyDiagnosticToken, transport: any SefariaJSTransport) {
            self.token = token
            self.transport = transport
            self.deadline = ContinuousClock.now.advanced(by: .milliseconds(token.timeoutMs))
        }
    }
    private var lateReplyObservation: LateReplyObservation?

    func beginLateReplyDiagnostic(nonce: UUID, delayMs: Int, timeoutMs: Int) throws -> SefariaLateReplyDiagnosticToken {
        guard lateReplyObservation == nil, isTransportReady, resourcesAreStable,
              let transport, sessionEpoch > 0, sessionEpoch < 9_007_199_254_740_991,
              (1...3_000).contains(delayMs), timeoutMs > delayMs, timeoutMs <= 10_000 else {
            throw lateReplyFailure("DIAGNOSTIC_UNAVAILABLE")
        }
        let token = SefariaLateReplyDiagnosticToken(id: UUID(), nonce: nonce.uuidString,
            originalEpoch: sessionEpoch, delayMs: delayMs, timeoutMs: timeoutMs)
        lateReplyObservation = LateReplyObservation(token: token, transport: transport)
        return token
    }

    func endLateReplyDiagnostic(_ token: SefariaLateReplyDiagnosticToken) {
        guard lateReplyObservation?.token == token else { return }
        lateReplyObservation = nil
    }

    func waitForLateReplyJSReceipt(_ token: SefariaLateReplyDiagnosticToken) async throws {
        while true {
            try Task.checkCancellation()
            let observation = try lateReplyState(token)
            if observation.jsReceived { return }
            // This only waits for an actual JS event recorded by the original
            // actor; elapsed time is never a received/discarded acknowledgement.
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    func validateLateReplyBeforeReset(_ token: SefariaLateReplyDiagnosticToken) throws {
        let observation = try lateReplyState(token)
        guard sessionEpoch == token.originalEpoch, observation.jsReceived,
              !observation.originalCancellation, observation.discarded == nil,
              let requestID = observation.requestID,
              inFlightRequests[requestID]?.generation == token.originalEpoch else {
            throw lateReplyFailure("DIAGNOSTIC_NOT_IN_FLIGHT")
        }
    }

    func validateLateReplyAfterReset(_ token: SefariaLateReplyDiagnosticToken) throws {
        let observation = try lateReplyState(token)
        guard sessionEpoch == token.originalEpoch + 1, observation.jsReceived,
              observation.originalCancellation, let requestID = observation.requestID,
              inFlightRequests[requestID] == nil else {
            throw lateReplyFailure("DIAGNOSTIC_RESET_NOT_OBSERVED")
        }
    }

    func waitForDiscardedLateReply(_ token: SefariaLateReplyDiagnosticToken) async throws -> SefariaLateReplyDiagnosticEvidence {
        while true {
            try Task.checkCancellation()
            try validateLateReplyAfterReset(token)
            if let evidence = try lateReplyState(token).discarded { return evidence }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    func validateLateReplyCompletion(_ token: SefariaLateReplyDiagnosticToken,
                                     evidence: SefariaLateReplyDiagnosticEvidence) throws {
        try validateLateReplyAfterReset(token)
        guard try lateReplyState(token).discarded == evidence else {
            throw lateReplyFailure("DIAGNOSTIC_RECEIPT_CHANGED")
        }
    }

    private func lateReplyState(_ token: SefariaLateReplyDiagnosticToken) throws -> LateReplyObservation {
        guard let observation = lateReplyObservation, observation.token == token else {
            throw lateReplyFailure("DIAGNOSTIC_RETIRED")
        }
        if let failure = observation.failure { throw failure }
        guard ContinuousClock.now < observation.deadline else {
            throw lateReplyFailure("DIAGNOSTIC_DEADLINE_EXCEEDED")
        }
        guard let transport, transport === observation.transport, isTransportReady,
              resourcesAreStable else {
            throw lateReplyFailure("DIAGNOSTIC_TRANSPORT_CHANGED")
        }
        return observation
    }

    private func lateReplyFailure(_ code: String) -> SefariaRPCError {
        .init(code: code, message: "The original delayed RPC proof is incomplete or changed.")
    }

    private func failLateReply(_ observation: LateReplyObservation, _ code: String) {
        // A diagnostic observation never cancels/resumes or admits an RPC.
        if observation.failure == nil { observation.failure = lateReplyFailure(code) }
    }

    private func observeLateReplyDispatch(_ envelope: SefariaRPCEnvelope) {
        guard envelope.method == "diagnostic.echo", let observation = lateReplyObservation,
              let params = envelope.paramsJson?.data(using: .utf8),
              let options = try? JSONDecoder().decode(LateReplyParameters.self, from: params).lateReplyDiagnostic else { return }
        guard observation.requestID == nil, options.contract == "chavrusa.diagnostic.late-reply.v1",
              options.nonce == observation.token.nonce, options.delayMs == observation.token.delayMs,
              envelope.sessionGeneration == observation.token.originalEpoch,
              envelope.timeoutMs == observation.token.timeoutMs,
              (try? lateReplyState(observation.token)) != nil else {
            failLateReply(observation, "DIAGNOSTIC_DISPATCH_MISMATCH"); return
        }
        observation.requestID = envelope.requestID
    }

    private func observeLateReplyStarted(_ event: SefariaRPCEvent) {
        guard event.event == "diagnostic.echo.started", let observation = lateReplyObservation else { return }
        guard event.backendID == BackendID.sefariaEmbedded.rawValue,
              let json = event.payloadJson, json.utf8.count <= 1_024,
              let proof = try? JSONDecoder().decode(LateReplyWireProof.self, from: Data(json.utf8)),
              proof.contract == "chavrusa.diagnostic.late-reply.v1",
              proof.requestID == observation.requestID, proof.nonce == observation.token.nonce,
              proof.sessionGeneration == observation.token.originalEpoch,
              proof.delayMs == observation.token.delayMs, !observation.jsReceived,
              !observation.originalCancellation, sessionEpoch == observation.token.originalEpoch,
              inFlightRequests[proof.requestID]?.generation == observation.token.originalEpoch,
              (try? lateReplyState(observation.token)) != nil else {
            failLateReply(observation, "DIAGNOSTIC_JS_RECEIPT_MISMATCH"); return
        }
        observation.jsReceived = true
    }

    private func observeLateReplyCancellation(requestID: String, generation: UInt64, reason: String) {
        guard let observation = lateReplyObservation, observation.requestID == requestID else { return }
        guard observation.jsReceived, !observation.originalCancellation, observation.discarded == nil,
              reason == "Session epoch changed", generation == observation.token.originalEpoch,
              sessionEpoch == observation.token.originalEpoch else {
            failLateReply(observation, "DIAGNOSTIC_CANCELLATION_MISMATCH"); return
        }
        observation.originalCancellation = true
    }

    private func observeLateReplyResponse(_ response: SefariaRPCResponse, wasInFlight: Bool) {
        guard let observation = lateReplyObservation, response.requestID == observation.requestID else { return }
        guard !wasInFlight, observation.jsReceived, observation.originalCancellation,
              observation.discarded == nil, response.protocolVersion == "1.0",
              response.backendID == BackendID.sefariaEmbedded.rawValue, response.isSuccess, response.error == nil,
              response.sessionGeneration == observation.token.originalEpoch,
              sessionEpoch == observation.token.originalEpoch + 1,
              let json = response.resultJson, json.utf8.count <= 2_048,
              let proof = try? JSONDecoder().decode(LateReplyResult.self, from: Data(json.utf8)).lateReplyDiagnostic,
              proof.contract == "chavrusa.diagnostic.late-reply.v1",
              proof.requestID == response.requestID, proof.nonce == observation.token.nonce,
              proof.sessionGeneration == response.sessionGeneration, proof.delayMs == observation.token.delayMs,
              (try? lateReplyState(observation.token)) != nil else {
            failLateReply(observation, "DIAGNOSTIC_LATE_DISPOSITION_MISMATCH"); return
        }
        observation.discarded = .init(requestID: response.requestID, nonce: observation.token.nonce,
            originalEpoch: response.sessionGeneration, currentEpoch: sessionEpoch,
            jsReceived: true, originalCancellation: true, disposition: "discarded_no_in_flight_request")
    }

    // MARK: - Event Subscriptions

    func addEventListener(for eventName: String, listener: @escaping @Sendable (SefariaRPCEvent) -> Void) {
        var listeners = eventListeners[eventName] ?? []
        listeners.append(listener)
        eventListeners[eventName] = listeners
    }

    func handleIncomingEvent(jsonString: String) {
        NSLog("[SefariaJSRPCBridge] handleIncomingEvent: %@", jsonString)
        guard let data = jsonString.data(using: .utf8),
              let event = try? JSONDecoder().decode(SefariaRPCEvent.self, from: data) else {
            return
        }

        observeLateReplyStarted(event)
        if event.event == "ready" {
            notifyReady()
        } else if event.event == "bootstrapError" {
            NSLog("[SefariaJSRPCBridge] bootstrapError received: %@", event.payloadJson ?? "")
            isReady = false
        }

        if let listeners = eventListeners[event.event] {
            for listener in listeners {
                listener(event)
            }
        }
    }
}
