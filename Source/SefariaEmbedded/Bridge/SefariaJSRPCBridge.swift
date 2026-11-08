//
//  SefariaJSRPCBridge.swift
//  Maktabah
//
//  Downstream-owned asynchronous RPC bridge between Swift and Sefaria-Mobile JS runtime.
//  Enforces single-resume continuations, actor-owned timeout handling, zero leaks,
//  generation guards, and event listener dispatching.
//

import Foundation

protocol SefariaJSTransport: Sendable {
    func sendToJS(jsonString: String) async throws
}

actor SefariaJSRPCBridge {
    static let shared = SefariaJSRPCBridge()

    private struct InFlightRequest {
        let method: String
        let continuation: CheckedContinuation<SefariaRPCResponse, any Error>
        let generation: UInt64
        let timeoutTask: Task<Void, Never>
    }

    private var transport: (any SefariaJSTransport)?
    private var inFlightRequests: [String: InFlightRequest] = [:]
    func hasPendingRequest(method: String) -> Bool { inFlightRequests.values.contains { $0.method == method } }
    private var eventListeners: [String: [@Sendable (SefariaRPCEvent) -> Void]] = [:]

    private(set) var isReady: Bool = false
    private(set) var hasActiveListeners: Bool = false
    private(set) var sessionEpoch: UInt64 = 1

    var hasTransport: Bool {
        return transport != nil
    }

    var isTransportReady: Bool {
        return isReady && transport != nil && hasActiveListeners
    }

    private init() {}

    func setSessionEpoch(_ epoch: UInt64) {
        self.sessionEpoch = epoch
    }

    func bumpSessionEpoch() -> UInt64 {
        sessionEpoch &+= 1
        return sessionEpoch
    }

    func setTransport(_ transport: (any SefariaJSTransport)?) {
        NSLog("[SefariaJSRPCBridge] setTransport called (transport: %@)", String(describing: transport))
        self.transport = transport
        if transport == nil {
            self.isReady = false
            self.hasActiveListeners = false
            cancelAll(reason: "Transport detached")
        }
    }

    func clearTransportIfMatches(_ transport: any SefariaJSTransport) {
        if let current = self.transport, (current as AnyObject) === (transport as AnyObject) {
            NSLog("[SefariaJSRPCBridge] clearTransportIfMatches: clearing transport")
            self.transport = nil
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
        let requestID = UUID().uuidString
        let effectiveGeneration = generation ?? sessionEpoch
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
            method: method,
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
        if response.sessionGeneration != req.generation {
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
