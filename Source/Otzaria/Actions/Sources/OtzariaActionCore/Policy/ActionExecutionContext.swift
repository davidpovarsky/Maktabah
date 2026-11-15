import Foundation

public enum ActionOrigin: String, Sendable { case inApp, appIntent, deepLink, internalAI, guide, mcp }
public enum ActionScope: String, Hashable, Sendable { case discovery, contentRead, navigation }

/// Trusted adapter-owned data. Intentionally neither Decodable nor Codable.
public struct ActionExecutionContext: Sendable, Equatable {
    public let subjectID: String
    public let correlationID: UUID
    public let origin: ActionOrigin
    public let allowedBackends: Set<ActionBackendID>
    public let contentRights: Set<ActionBackendID>
    public let scopes: Set<ActionScope>
    public let allowedWorkKeys: [ActionBackendID: Set<String>]?
    public let foregroundSceneID: String?
    public let pairedDeviceAvailable: Bool
    public let maxActions: Int
    public let maxResultBytes: Int
    public init(subjectID: String, correlationID: UUID = UUID(), origin: ActionOrigin,
                allowedBackends: Set<ActionBackendID>, contentRights: Set<ActionBackendID> = [], scopes: Set<ActionScope>,
                allowedWorkKeys: [ActionBackendID: Set<String>]? = nil,
                foregroundSceneID: String? = nil, pairedDeviceAvailable: Bool = false, maxActions: Int = 20, maxResultBytes: Int = 65_536) {
        self.subjectID = subjectID; self.correlationID = correlationID; self.origin = origin
        self.allowedBackends = allowedBackends; self.contentRights = contentRights; self.scopes = scopes
        self.allowedWorkKeys = allowedWorkKeys
        self.foregroundSceneID = foregroundSceneID; self.pairedDeviceAvailable = pairedDeviceAvailable
        self.maxActions = maxActions; self.maxResultBytes = maxResultBytes
    }
}
