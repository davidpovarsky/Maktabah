import Foundation
public enum ActionStatus: String, Sendable, Codable {
    case completed, uiQueued = "ui_queued", requiresBackendSwitch = "requires_backend_switch"
    case requiresForeground = "requires_foreground", requiresConfirmation = "requires_confirmation"
    case needsDisambiguation = "needs_disambiguation", notSupported = "not_supported"
    case unavailable, staleState = "stale_state", cancelled, failed
}
public struct UIStableID: RawRepresentable, Codable, Sendable, Hashable {
    public let rawValue: String
    public init?(rawValue: String) {
        guard rawValue.utf8.count <= 128, rawValue.range(of: "^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$", options: .regularExpression) == rawValue.startIndex..<rawValue.endIndex else { return nil }
        self.rawValue = rawValue
    }
    public init(from decoder: any Decoder) throws {
        guard let id = Self(rawValue: try decoder.singleValueContainer().decode(String.self)) else { throw UIRouteError(.failed, "invalid_stable_id") }
        self = id
    }
    public func encode(to encoder: any Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public struct UIRouteError: Error, Sendable, Equatable {
    public let status: ActionStatus
    public let code: String
    public init(_ status: ActionStatus, _ code: String) { self.status = status; self.code = code }
}
