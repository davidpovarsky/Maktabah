import Foundation

// Explicit portable boundary: UIKit/Expo/Hermes startup is not executed here.
// The entire original RPC bridge remains in use, including its transport,
// generation, cancellation and continuation implementation.
struct SefariaRuntimeManager: Sendable {
    static let shared = SefariaRuntimeManager()
    func ensureReady() async throws {
        guard await SefariaJSRPCBridge.shared.isTransportReady else {
            throw LibraryBackendError.capabilityUnavailable
        }
    }
}

actor MobileFixtureTransport: SefariaJSTransport {
    enum Mode: Sendable {
        case body(String)
        case absent
        case error
        case foreignBackend
        case hold(String)
    }
    private var mode: Mode = .absent
    private var envelopes: [SefariaRPCEnvelope] = []
    private var held: [SefariaRPCEnvelope] = []
    func select(_ mode: Mode) { self.mode = mode; envelopes = []; held = [] }
    func count() -> Int { envelopes.count }
    func methods() -> [String] { envelopes.map(\.method) }
    func titles() -> [String] {
        envelopes.compactMap {
            guard let json = $0.paramsJson,
                  let value = try? JSONDecoder().decode([String: String].self, from: Data(json.utf8)) else { return nil }
            return value["title"]
        }
    }
    func sendToJS(jsonString: String) async throws {
        let request = try JSONDecoder().decode(SefariaRPCEnvelope.self, from: Data(jsonString.utf8))
        envelopes.append(request)
        if case .hold = mode { held.append(request); return }
        await reply(request)
    }
    private func reply(_ request: SefariaRPCEnvelope) async {
        let body: String?
        let status: String
        let error: SefariaRPCError?
        let backend: String
        switch mode {
        case .body(let value), .hold(let value): body = value; status = "success"; error = nil; backend = "sefariaEmbedded"
        case .absent: body = nil; status = "success"; error = nil; backend = "sefariaEmbedded"
        case .error:
            body = nil; status = "error"
            error = .init(code: "ORIGINAL_RPC_FAILURE_CONTROL", message: "Controlled transport error", retryable: true)
            backend = "sefariaEmbedded"
        case .foreignBackend: body = "{}"; status = "success"; error = nil; backend = "sefaria"
        }
        let response = SefariaRPCResponse(requestID: request.requestID, status: status,
            resultJson: body, error: error, sessionGeneration: request.sessionGeneration, backendID: backend)
        let encoded = String(decoding: try! JSONEncoder().encode(response), as: UTF8.self)
        await SefariaJSRPCBridge.shared.handleIncomingResponse(jsonString: encoded)
    }
    func releaseLateResponses() async {
        let pending = held; held = []
        for request in pending { await reply(request) }
    }
}

actor MobileCompletionObservation {
    private var finished = false
    func finish() { finished = true }
    func isFinished() -> Bool { finished }
}
