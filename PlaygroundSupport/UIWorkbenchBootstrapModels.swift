import Foundation

enum OtzariaDatabaseBootstrapStage: Equatable, Sendable {
    case connecting
    case downloading(resumedFrom: Int64)
    case verifyingDownload
    case extracting
    case validatingDatabase
    case installing
    case ready
}

struct OtzariaDatabaseBootstrapProgress: Equatable, Sendable {
    let stage: OtzariaDatabaseBootstrapStage
    let fraction: Double
    let detail: String
}

struct OtzariaDatabaseInstallationManifest: Codable, Equatable, Sendable {
    let repository: String
    let releaseID: Int64
    let releaseTag: String
    let assetID: Int64
    let assetName: String
    let compressedSize: Int64
    let digest: String?
    let installedAt: Date
    let databaseFileSize: Int64
}
