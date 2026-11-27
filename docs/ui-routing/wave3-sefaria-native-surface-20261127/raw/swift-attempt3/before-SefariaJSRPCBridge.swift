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

/// The RPC actor is the only writer. The same recursive lock covers a native
/// synchronous commit/report and the actor's lifecycle publications. No actor
/// call, suspension or asynchronous work is permitted in that native section.
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
            return
        }
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
        for (_, req) in inFlightRequests {
            req.timeoutTask.cancel()
            req.continuation.resume(throwing: SefariaRPCError(code: "CANCELLED", message: reason, retryable: false))
        }
        inFlightRequests.removeAll()
    }

    func cancelAllInFlight() {
        cancelAll(reason: "Backend invalidated")
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
