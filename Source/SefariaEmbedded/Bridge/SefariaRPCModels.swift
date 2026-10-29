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

public struct SefariaRPCEnvelope: Codable, Sendable, Equatable {
    public let protocolVersion: String
    public let requestID: String
    public let method: String
    public let paramsJson: String?
    public let backendID: String
    public let sessionGeneration: UInt64
    public let timeoutMs: Int

    public init(
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

    public init<T: Encodable>(
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

public struct SefariaRPCResponse: Codable, Sendable, Equatable {
    public let protocolVersion: String
    public let requestID: String
    public let status: String // "success" or "error"
    public let resultJson: String?
    public let error: SefariaRPCError?
    public let sessionGeneration: UInt64

    public var isSuccess: Bool {
        status == "success"
    }

    public init(
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

    public func decodeResult<T: Decodable>(_ type: T.Type) throws -> T {
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

public struct SefariaRPCError: Codable, Sendable, Equatable, LocalizedError {
    public let code: String
    public let message: String
    public let retryable: Bool
    public let details: String?

    public var errorDescription: String? {
        "[\(code)] \(message)"
    }

    public init(
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

public struct SefariaRPCEvent: Codable, Sendable, Equatable {
    public let event: String
    public let sequence: UInt64
    public let backendID: String
    public let payloadJson: String?

    public init(
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

    public func decodePayload<T: Decodable>(_ type: T.Type) throws -> T {
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
