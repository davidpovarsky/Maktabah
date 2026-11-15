import Foundation

public enum ActionBackendID: String, Codable, CaseIterable, Sendable { case otzaria, sefaria, sefariaEmbedded }
public enum ActionPresentation: String, Codable, Sendable { case headless, foreground }

public struct ActionRequest: Sendable, Equatable, Codable {
    public let apiVersion: Int
    public let requestId: UUID
    public let action: String
    public let arguments: ActionObject
    public let expectedBackend: ActionBackendID?
    public let expectedGeneration: UInt64?
    public let idempotencyKey: String?
    public let requestedPresentation: ActionPresentation?
    public let deadlineMs: Int?
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case apiVersion, requestId, action, arguments, expectedBackend, expectedGeneration, idempotencyKey, requestedPresentation, deadlineMs
    }
    private struct AnyKey: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }
    public init(from decoder: any Decoder) throws {
        let keys = try decoder.container(keyedBy: AnyKey.self)
        guard Set(keys.allKeys.map { Array($0.stringValue.utf8) }).isSubset(of: Set(CodingKeys.allCases.map { Array($0.rawValue.utf8) })) else {
            throw ActionContractError.invalid("$")
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(apiVersion: try c.decode(Int.self, forKey: .apiVersion), requestId: try c.decode(UUID.self, forKey: .requestId),
            action: try c.decode(String.self, forKey: .action), arguments: try c.decode(ActionObject.self, forKey: .arguments),
            expectedBackend: try c.decodeIfPresent(ActionBackendID.self, forKey: .expectedBackend),
            expectedGeneration: try c.decodeIfPresent(UInt64.self, forKey: .expectedGeneration),
            idempotencyKey: try c.decodeIfPresent(String.self, forKey: .idempotencyKey),
            requestedPresentation: try c.decodeIfPresent(ActionPresentation.self, forKey: .requestedPresentation),
            deadlineMs: try c.decodeIfPresent(Int.self, forKey: .deadlineMs))
    }

    public init(apiVersion: Int = 1, requestId: UUID = UUID(), action: String, arguments: ActionObject = [:],
                expectedBackend: ActionBackendID? = nil, expectedGeneration: UInt64? = nil,
                idempotencyKey: String? = nil, requestedPresentation: ActionPresentation? = nil, deadlineMs: Int? = nil) {
        self.apiVersion = apiVersion; self.requestId = requestId; self.action = action; self.arguments = arguments
        self.expectedBackend = expectedBackend; self.expectedGeneration = expectedGeneration
        self.idempotencyKey = idempotencyKey; self.requestedPresentation = requestedPresentation; self.deadlineMs = deadlineMs
    }
}

public enum ActionStatus: String, Sendable, Codable {
    case completed, uiQueued = "ui_queued", requiresBackendSwitch = "requires_backend_switch"
    case requiresForeground = "requires_foreground", requiresConfirmation = "requires_confirmation"
    case needsDisambiguation = "needs_disambiguation", notSupported = "not_supported"
    case unavailable, staleState = "stale_state", cancelled, failed
}

public struct ActionFailure: Sendable, Equatable, Codable {
    public let code: String
    public let message: String
    public let retryable: Bool
    public let field: String?
    public let retryAfterMs: Int?
    public init(code: String, message: String, retryable: Bool = false, field: String? = nil, retryAfterMs: Int? = nil) {
        self.code = code; self.message = message; self.retryable = retryable; self.field = field; self.retryAfterMs = retryAfterMs
    }
}

public struct ActionCandidate: Sendable, Equatable, Codable {
    public enum Kind: String, Sendable, Codable { case work, commentary, section, segment }
    public enum Confidence: String, Sendable, Codable { case exact, alias, fuzzy }
    public let ref: ActionObject
    public let title: String
    public let kind: Kind
    public let confidenceBand: Confidence?
    public let reason: String?
    public init(ref: ActionObject, title: String, kind: Kind, confidenceBand: Confidence? = nil, reason: String? = nil) {
        self.ref = ref; self.title = title; self.kind = kind; self.confidenceBand = confidenceBand; self.reason = reason
    }
}

public struct ActionResult: Sendable, Equatable, Codable {
    public let apiVersion: Int
    public let requestId: UUID
    public let action: String
    public let status: ActionStatus
    public let data: ActionObject?
    public let error: ActionFailure?
    public let candidates: [ActionCandidate]?
    public let backend: ActionBackendID?
    public let backendGeneration: UInt64?
    public let effects: [String]?
    public let next: ActionContinuation?
    public let completedAt: String?
    public init(request: ActionRequest, status: ActionStatus, data: ActionObject? = nil, error: ActionFailure? = nil,
                candidates: [ActionCandidate]? = nil, backend: ActionBackendID? = nil, backendGeneration: UInt64? = nil, effects: [String]? = nil,
                next: ActionContinuation? = nil, completedAt: String? = nil) {
        apiVersion = 1; requestId = request.requestId; action = request.action; self.status = status; self.data = data
        self.error = error; self.candidates = candidates; self.backend = backend; self.backendGeneration = backendGeneration; self.effects = effects
        self.next = next; self.completedAt = completedAt
    }
}

public struct ActionContinuation: Sendable, Equatable, Codable {
    public let cursor: String?
    public let expiresAt: String?
    public let isStable: Bool?
    public init(cursor: String? = nil, expiresAt: String? = nil, isStable: Bool? = nil) {
        self.cursor = cursor; self.expiresAt = expiresAt; self.isStable = isStable
    }
}
