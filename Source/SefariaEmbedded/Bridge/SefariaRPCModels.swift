//
//  SefariaRPCModels.swift
//  Maktabah
//
//  Downstream-owned strongly typed RPC models for native <-> JS communication
//  with the embedded Sefaria-Mobile runtime.
//  Uses explicit JSON strings (paramsJson, resultJson, payloadJson) at the boundary
//  to guarantee zero Base64 / binary encoding ambiguity across Swift and JavaScript.
//

import Foundation

struct SefariaRPCEnvelope: Codable, Sendable, Equatable {
    let protocolVersion: String
    let requestID: String
    let method: String
    let paramsJson: String?
    let backendID: String
    let sessionGeneration: UInt64
    let timeoutMs: Int

    init(
        protocolVersion: String = "1.0",
        requestID: String = UUID().uuidString,
        method: String,
        paramsJson: String? = nil,
        backendID: String = "sefariaEmbedded",
        sessionGeneration: UInt64 = 0,
        timeoutMs: Int = 15000
    ) {
        self.protocolVersion = protocolVersion
        self.requestID = requestID
        self.method = method
        self.paramsJson = paramsJson
        self.backendID = backendID
        self.sessionGeneration = sessionGeneration
        self.timeoutMs = timeoutMs
    }

    init<T: Encodable>(
        protocolVersion: String = "1.0",
        requestID: String = UUID().uuidString,
        method: String,
        params: T,
        backendID: String = "sefariaEmbedded",
        sessionGeneration: UInt64 = 0,
        timeoutMs: Int = 15000
    ) throws {
        let data = try JSONEncoder().encode(params)
        let jsonStr = String(data: data, encoding: .utf8)
        self.init(
            protocolVersion: protocolVersion,
            requestID: requestID,
            method: method,
            paramsJson: jsonStr,
            backendID: backendID,
            sessionGeneration: sessionGeneration,
            timeoutMs: timeoutMs
        )
    }
}

struct SefariaRPCResponse: Codable, Sendable, Equatable {
    let protocolVersion: String
    let requestID: String
    let status: String // "success" or "error"
    let resultJson: String?
    let error: SefariaRPCError?
    let sessionGeneration: UInt64

    var isSuccess: Bool {
        status == "success"
    }

    init(
        protocolVersion: String = "1.0",
        requestID: String,
        status: String,
        resultJson: String? = nil,
        error: SefariaRPCError? = nil,
        sessionGeneration: UInt64 = 0
    ) {
        self.protocolVersion = protocolVersion
        self.requestID = requestID
        self.status = status
        self.resultJson = resultJson
        self.error = error
        self.sessionGeneration = sessionGeneration
    }

    func decodeResult<T: Decodable>(_ type: T.Type) throws -> T {
        guard let resultJson = resultJson,
              let data = resultJson.data(using: .utf8) else {
            throw SefariaRPCError(
                code: "EMPTY_RESULT",
                message: "RPC response contained no result JSON payload for decoding \(T.self)"
            )
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

struct SefariaRPCError: Codable, Sendable, Equatable, LocalizedError {
    let code: String
    let message: String
    let retryable: Bool
    let details: String?

    var errorDescription: String? {
        "[\(code)] \(message)"
    }

    init(
        code: String,
        message: String,
        retryable: Bool = false,
        details: String? = nil
    ) {
        self.code = code
        self.message = message
        self.retryable = retryable
        self.details = details
    }
}

struct SefariaRPCEvent: Codable, Sendable, Equatable {
    let event: String
    let sequence: UInt64
    let backendID: String
    let payloadJson: String?

    init(
        event: String,
        sequence: UInt64,
        backendID: String = "sefariaEmbedded",
        payloadJson: String? = nil
    ) {
        self.event = event
        self.sequence = sequence
        self.backendID = backendID
        self.payloadJson = payloadJson
    }

    func decodePayload<T: Decodable>(_ type: T.Type) throws -> T {
        guard let payloadJson = payloadJson,
              let data = payloadJson.data(using: .utf8) else {
            throw SefariaRPCError(
                code: "EMPTY_PAYLOAD",
                message: "Event '\(event)' contained no payload JSON for decoding \(T.self)"
            )
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
