import Foundation

struct OtzariaLibraryRelease: Codable, Equatable, Sendable {
    static let repository = "Otzaria/SeforimLibrary"
    static let databaseAssetName = "seforim.db.zst"

    let id: Int64
    let tag: String
    let asset: Asset

    struct Asset: Codable, Equatable, Sendable {
        let id: Int64
        let name: String
        let downloadURL: URL
        let compressedSize: Int64
        let digest: String?
        let updatedAt: Date?
    }

    var downloadIdentity: String {
        [
            Self.repository,
            String(id),
            tag,
            String(asset.id),
            asset.name,
            String(asset.compressedSize),
            asset.digest ?? "",
        ].joined(separator: "|")
    }

    var expectedSHA256: String? {
        guard let digest else { return nil }
        let prefix = "sha256:"
        guard digest.lowercased().hasPrefix(prefix) else { return nil }
        let value = String(digest.dropFirst(prefix.count)).lowercased()
        guard value.count == 64, value.allSatisfy({ $0.isHexDigit }) else { return nil }
        return value
    }

    private var digest: String? { asset.digest }
}

struct OtzariaDownloadResumeMetadata: Codable, Equatable, Sendable {
    let repository: String
    let releaseID: Int64
    let releaseTag: String
    let assetID: Int64
    let assetName: String
    let browserDownloadURL: URL
    let expectedCompressedSize: Int64
    let digest: String?
    var etag: String?
    var lastModified: String?
    var downloadedBytes: Int64
    var updatedAt: Date

    init(release: OtzariaLibraryRelease, downloadedBytes: Int64 = 0) {
        repository = OtzariaLibraryRelease.repository
        releaseID = release.id
        releaseTag = release.tag
        assetID = release.asset.id
        assetName = release.asset.name
        browserDownloadURL = release.asset.downloadURL
        expectedCompressedSize = release.asset.compressedSize
        digest = release.asset.digest
        etag = nil
        lastModified = nil
        self.downloadedBytes = downloadedBytes
        updatedAt = Date()
    }

    func matches(_ release: OtzariaLibraryRelease) -> Bool {
        repository == OtzariaLibraryRelease.repository &&
            releaseID == release.id &&
            releaseTag == release.tag &&
            assetID == release.asset.id &&
            assetName == release.asset.name &&
            browserDownloadURL == release.asset.downloadURL &&
            expectedCompressedSize == release.asset.compressedSize &&
            digest == release.asset.digest
    }

    var resumeValidator: String? {
        if let etag, !etag.isEmpty, !etag.hasPrefix("W/") { return etag }
        if let lastModified, !lastModified.isEmpty { return lastModified }
        return nil
    }
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

    init(release: OtzariaLibraryRelease, databaseFileSize: Int64) {
        repository = OtzariaLibraryRelease.repository
        releaseID = release.id
        releaseTag = release.tag
        assetID = release.asset.id
        assetName = release.asset.name
        compressedSize = release.asset.compressedSize
        digest = release.asset.digest
        installedAt = Date()
        self.databaseFileSize = databaseFileSize
    }
}

struct OtzariaPreparedDatabaseInstallation: Sendable {
    let release: OtzariaLibraryRelease
    let stagingURL: URL
    let databaseFileSize: Int64
    let extractionElapsedSeconds: TimeInterval
    let validationElapsedSeconds: TimeInterval
}

struct OtzariaManagedDatabaseInstallResult: Sendable {
    let release: OtzariaLibraryRelease
    let finalURL: URL
    let resumeFromBytes: Int64
    let downloadedBytes: Int64
    let actualSHA256: String?
    let downloadElapsedSeconds: TimeInterval
    let verificationElapsedSeconds: TimeInterval
    let extractionElapsedSeconds: TimeInterval
    let validationElapsedSeconds: TimeInterval
    let databaseFileSize: Int64
}

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

enum OtzariaDatabaseBootstrapError: LocalizedError, Sendable {
    case releaseLookupFailed(String)
    case databaseAssetMissing
    case invalidAssetMetadata(String)
    case insufficientDiskSpace(required: Int64, available: Int64)
    case downloadHTTPError(Int)
    case invalidResumeResponse(String)
    case downloadSizeMismatch(expected: Int64, actual: Int64)
    case digestMismatch(expected: String, actual: String)
    case zstdInitializationFailed(String)
    case zstdCorruptData(String)
    case extractionWriteFailed(String)
    case sqliteValidationFailed(String)
    case atomicInstallFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .releaseLookupFailed(let message):
            return "Could not connect to the Otzaria library release: \(message)"
        case .databaseAssetMissing:
            return "The latest Otzaria release does not contain seforim.db.zst."
        case .invalidAssetMetadata(let message):
            return "The Otzaria release metadata is invalid: \(message)"
        case .insufficientDiskSpace(let required, let available):
            return "There is not enough free space to install the Otzaria library. " +
                "About \(Self.format(required)) is required; \(Self.format(available)) is available."
        case .downloadHTTPError(let status):
            return "The Otzaria library download failed (HTTP \(status))."
        case .invalidResumeResponse(let message):
            return "The server returned an invalid resume response: \(message)"
        case .downloadSizeMismatch(let expected, let actual):
            return "The downloaded file has the wrong size (expected \(expected), received \(actual) bytes)."
        case .digestMismatch:
            return "The downloaded Otzaria library failed its SHA-256 integrity check. Download it again."
        case .zstdInitializationFailed(let message):
            return "The Otzaria library decompressor could not start: \(message)"
        case .zstdCorruptData(let message):
            return "The downloaded Otzaria archive is corrupt or incomplete: \(message)"
        case .extractionWriteFailed(let message):
            return "The Otzaria library could not be written to storage: \(message)"
        case .sqliteValidationFailed(let message):
            return "The downloaded Otzaria database is invalid: \(message)"
        case .atomicInstallFailed(let message):
            return "The Otzaria library could not be installed safely: \(message)"
        case .cancelled:
            return "The Otzaria library download was cancelled. You can resume it later."
        }
    }

    private static func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
