//
//  SefariaJSRPCBridge.swift
//  Maktabah
//
//  Downstream-owned asynchronous RPC bridge between Swift and Sefaria-Mobile JS runtime.
//  Enforces timeouts, generation guards, error propagation, and event routing.
//

import Foundation

public protocol SefariaJSTransport: Sendable {
    func sendToJS(jsonString: String) async throws
}

public actor SefariaJSRPCBridge {
    public static let shared = SefariaJSRPCBridge()

    private var transport: (any SefariaJSTransport)?
    private var inFlightContinuations: [String: CheckedContinuation<SefariaRPCResponse, any Error>] = [:]
    private var inFlightGenerations: [String: UInt64] = [:]
    private var eventListeners: [String: [(SefariaRPCEvent) -> Void]] = [:]

    private init() {}

    public func setTransport(_ transport: any SefariaJSTransport) {
        self.transport = transport
    }

    /// Dispatches an RPC call to the Sefaria runtime with bounded timeout and generation tracking.
    public func call(
        method: String,
        paramsData: Data? = nil,
        generation: UInt64 = 0,
        timeoutMs: Int = 15000
    ) async throws -> SefariaRPCResponse {
        let requestID = UUID().uuidString
        let envelope = SefariaRPCEnvelope(
            protocolVersion: "1.0",
            requestID: requestID,
            method: method,
            paramsData: paramsData,
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

        return try await withThrowingTaskGroup(of: SefariaRPCResponse.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    Task { [weak self] in
                        guard let self else { return }
                        await self.registerContinuation(continuation, for: requestID, generation: generation)
                        do {
                            try await transport.sendToJS(jsonString: jsonString)
                        } catch {
                            await self.failContinuation(for: requestID, error: error)
                        }
                    }
                }
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeoutMs) * 1_000_000)
                throw SefariaRPCError(
                    code: "TIMEOUT",
                    message: "RPC call to '\(method)' timed out after \(timeoutMs)ms",
                    retryable: true
                )
            }

            let response = try await group.next()!
            group.cancelAll()
            return response
        }
    }

    private func registerContinuation(
        _ continuation: CheckedContinuation<SefariaRPCResponse, any Error>,
        for requestID: String,
        generation: UInt64
    ) {
        inFlightContinuations[requestID] = continuation
        inFlightGenerations[requestID] = generation
    }

    private func failContinuation(for requestID: String, error: any Error) {
        guard let continuation = inFlightContinuations.removeValue(forKey: requestID) else { return }
        inFlightGenerations.removeValue(forKey: requestID)
        continuation.resume(throwing: error)
    }

    /// Handles an incoming RPC response delivered from JavaScript.
    public func handleIncomingResponse(jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let response = try? JSONDecoder().decode(SefariaRPCResponse.self, from: data) else {
            return
        }

        guard let continuation = inFlightContinuations.removeValue(forKey: response.requestID) else {
            return
        }
        inFlightGenerations.removeValue(forKey: response.requestID)

        if response.isSuccess {
            continuation.resume(returning: response)
        } else {
            let error = response.error ?? SefariaRPCError(
                code: "UNKNOWN_JS_ERROR",
                message: "JavaScript execution failed without error details"
            )
            continuation.resume(throwing: error)
        }
    }

    /// Registers a listener for asynchronous Sefaria events (e.g. downloadProgress, catalogChanged).
    public func addEventListener(
        for event: String,
        handler: @escaping @Sendable (SefariaRPCEvent) -> Void
    ) {
        var handlers = eventListeners[event] ?? []
        handlers.append(handler)
        eventListeners[event] = handlers
    }

    /// Handles an incoming asynchronous event delivered from JavaScript.
    public func handleIncomingEvent(jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let event = try? JSONDecoder().decode(SefariaRPCEvent.self, from: data) else {
            return
        }

        if let handlers = eventListeners[event.event] {
            for handler in handlers {
                handler(event)
            }
        }
    }

    /// Cancels all pending in-flight requests, e.g. on backend transition abort.
    public func cancelAllInFlight() {
        let staleError = SefariaRPCError(
            code: "CANCELLED",
            message: "RPC request was cancelled by runtime or session transition.",
            retryable: false
        )
        for (_, continuation) in inFlightContinuations {
            continuation.resume(throwing: staleError)
        }
        inFlightContinuations.removeAll()
        inFlightGenerations.removeAll()
    }
}
