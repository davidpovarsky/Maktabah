import Foundation

public struct ActionOfflinePackage: Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let heTitle: String?
    public let parentID: String?
    public let compressedSize: Int64
    public let indexTitles: [String]?
    public let isCompleteLibrary: Bool

    public init(id: String, title: String, heTitle: String?, parentID: String?,
                compressedSize: Int64, indexTitles: [String]?, isCompleteLibrary: Bool) {
        self.id = id
        self.title = title
        self.heTitle = heTitle
        self.parentID = parentID
        self.compressedSize = compressedSize
        self.indexTitles = indexTitles
        self.isCompleteLibrary = isCompleteLibrary
    }
}

public struct ActionOfflinePackageStatus: Codable, Sendable, Equatable {
    public let installedPackageIDs: [String]
    public let installedWorkKeys: [String]?
    public let activeOperationHandle: UUID?

    public init(installedPackageIDs: [String], installedWorkKeys: [String]?, activeOperationHandle: UUID? = nil) {
        self.installedPackageIDs = installedPackageIDs
        self.installedWorkKeys = installedWorkKeys
        self.activeOperationHandle = activeOperationHandle
    }
}

public struct ActionOfflinePackageUpdates: Codable, Sendable, Equatable {
    public let changedWorkCount: Int
    public let affectedPackageIDs: [String]

    public init(changedWorkCount: Int, affectedPackageIDs: [String]) {
        self.changedWorkCount = changedWorkCount
        self.affectedPackageIDs = affectedPackageIDs
    }
}

public protocol ActionOfflinePackageObservationPort: Sendable {
    func offlinePackages(forceRefresh: Bool, invocation: ActionPortInvocation) async throws -> [ActionOfflinePackage]
    func offlinePackageStatus(includeWorks: Bool, invocation: ActionPortInvocation) async throws -> ActionOfflinePackageStatus
    func offlinePackageUpdates(invocation: ActionPortInvocation) async throws -> ActionOfflinePackageUpdates
}

/// The original package owner resolves and cancels one specific task.
public protocol ActionOfflinePackageCancellationPort: Sendable {
    func offlinePackageCancellationAvailable(invocation: ActionPortInvocation) async throws -> Bool
    func cancelOfflinePackage(operationHandle: UUID?, sceneID: String, invocation: ActionPortInvocation,
                              authorization: ActionNavigationPreparation) async throws -> UUID
}
