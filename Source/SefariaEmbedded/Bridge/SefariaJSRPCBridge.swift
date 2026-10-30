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
        let continuation: CheckedContinuation<SefariaRPCResponse, any Error>
        let generation: UInt64
        let timeoutTask: Task<Void, Never>
    }

    private var transport: (any SefariaJSTransport)?
    private var inFlightRequests: [String: InFlightRequest] = [:]
    private var eventListeners: [String: [@Sendable (SefariaRPCEvent) -> Void]] = [:]

    private init() {}

    func setTransport(_ transport: (any SefariaJSTransport)?) {
        self.transport = transport
        if transport == nil {
            cancelAll(reason: "Transport detached")
        }
    }

    /// Dispatches an RPC call to the Sefaria runtime with bounded timeout, generation tracking,
    /// and cancellation-safe continuation management.
    func call(
        method: String,
        paramsJson: String? = nil,
        generation: UInt64 = 0,
        timeoutMs: Int = 15000
    ) async throws -> SefariaRPCResponse {
        let requestID = UUID().uuidString
        let envelope = SefariaRPCEnvelope(
            protocolVersion: "1.0",
            requestID: requestID,
            method: method,
            paramsJson: paramsJson,
            backendID: BackendID.sefariaEmbedded.rawValue,
            sessionGeneration: generation,
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
                    generation: generation,
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

        // Verify generation if both caller and response specify it
        if req.generation > 0 && response.sessionGeneration > 0 && req.generation != response.sessionGeneration {
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
        guard let data = jsonString.data(using: .utf8),
              let event = try? JSONDecoder().decode(SefariaRPCEvent.self, from: data) else {
            return
        }

        if let listeners = eventListeners[event.event] {
            for listener in listeners {
                listener(event)
            }
        }
    }
}
