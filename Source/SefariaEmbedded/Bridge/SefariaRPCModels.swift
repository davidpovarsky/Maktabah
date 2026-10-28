//
//  SefariaRPCModels.swift
//  Maktabah
//
//  Downstream-owned strongly typed RPC models for native <-> JS communication
//  with the embedded Sefaria-Mobile runtime.
//

import Foundation

public struct SefariaRPCEnvelope: Codable, Sendable, Equatable {
    public let protocolVersion: String
    public let requestID: String
    public let method: String
    public let paramsData: Data?
    public let backendID: String
    public let sessionGeneration: UInt64
    public let timeoutMs: Int

    public init(
        protocolVersion: String = "1.0",
        requestID: String = UUID().uuidString,
        method: String,
        paramsData: Data? = nil,
        backendID: String = BackendID.sefariaEmbedded.rawValue,
        sessionGeneration: UInt64 = 0,
        timeoutMs: Int = 15000
    ) {
        self.protocolVersion = protocolVersion
        self.requestID = requestID
        self.method = method
        self.paramsData = paramsData
        self.backendID = backendID
        self.sessionGeneration = sessionGeneration
        self.timeoutMs = timeoutMs
    }
}

public struct SefariaRPCResponse: Codable, Sendable, Equatable {
    public let protocolVersion: String
    public let requestID: String
    public let status: String // "success" or "error"
    public let resultData: Data?
    public let error: SefariaRPCError?
    public let sessionGeneration: UInt64

    public var isSuccess: Bool {
        status == "success"
    }

    public init(
        protocolVersion: String = "1.0",
        requestID: String,
        status: String,
        resultData: Data? = nil,
        error: SefariaRPCError? = nil,
        sessionGeneration: UInt64 = 0
    ) {
        self.protocolVersion = protocolVersion
        self.requestID = requestID
        self.status = status
        self.resultData = resultData
        self.error = error
        self.sessionGeneration = sessionGeneration
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
    public let payloadData: Data?

    public init(
        event: String,
        sequence: UInt64,
        backendID: String = BackendID.sefariaEmbedded.rawValue,
        payloadData: Data? = nil
    ) {
        self.event = event
        self.sequence = sequence
        self.backendID = backendID
        self.payloadData = payloadData
    }
}
