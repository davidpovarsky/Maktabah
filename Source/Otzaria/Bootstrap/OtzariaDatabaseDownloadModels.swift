import Foundation

struct OtzariaStorageCapacityFailure: Equatable, Sendable {
    let requiredBytes: Int64?
    let availableBytes: Int64?

    var missingBytes: Int64? {
        guard let requiredBytes, let availableBytes else { return nil }
        return max(0, requiredBytes - availableBytes)
    }
}

protocol OtzariaStorageCapacityError: Error {
    var storageCapacityFailure: OtzariaStorageCapacityFailure? { get }
}

enum OtzariaStorageErrorNormalizer {
    private static let cocoaErrorDomain = "NSCocoaErrorDomain"
    private static let posixErrorDomain = "NSPOSIXErrorDomain"
    private static let fileWriteOutOfSpaceCode = 640
    private static let noSpaceLeftOnDeviceCode = 28

    static func failure(
        for error: Error,
        fallbackAvailableBytes: Int64? = nil
    ) -> OtzariaStorageCapacityFailure? {
        if let capacityError = error as? OtzariaStorageCapacityError,
           let failure = capacityError.storageCapacityFailure {
            return OtzariaStorageCapacityFailure(
                requiredBytes: failure.requiredBytes,
                availableBytes: failure.availableBytes ?? fallbackAvailableBytes.map { max(0, $0) }
            )
        }

        let nsError = error as NSError
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error,
           let failure = failure(for: underlying, fallbackAvailableBytes: fallbackAvailableBytes) {
            return failure
        }

        let isOutOfSpace =
            (nsError.domain == cocoaErrorDomain && nsError.code == fileWriteOutOfSpaceCode) ||
            (nsError.domain == posixErrorDomain && nsError.code == noSpaceLeftOnDeviceCode)
        guard isOutOfSpace else { return nil }
        return OtzariaStorageCapacityFailure(
            requiredBytes: nil,
            availableBytes: fallbackAvailableBytes.map { max(0, $0) }
        )
    }
}

struct OtzariaLibraryRelease: Codable, Equatable, Sendable {
    static let repository = "Otzaria/SeforimLibrary"
    /// Compatibility name used by older releases and existing test profiles.
    static let databaseAssetName = "seforim.db.zst"

    static func schemaVersion(inAssetName name: String) -> Int? {
        let prefix = "seforim-schema"
        let suffix = ".db.zst"
        guard name.hasPrefix(prefix), name.hasSuffix(suffix) else { return nil }
        let start = name.index(name.startIndex, offsetBy: prefix.count)
        let end = name.index(name.endIndex, offsetBy: -suffix.count)
        guard start < end else { return nil }
        return Int(name[start..<end])
    }

    static func isProductionDatabaseAssetName(_ name: String) -> Bool {
        name == databaseAssetName || schemaVersion(inAssetName: name) != nil
    }

    let id: Int64
    let tag: String
    let asset: Asset
    /// The remote asset remains the actual manifest when the archive is split.
    /// Archive identity and ordered remote parts are represented separately.
    var multipart: Multipart? = nil

    struct Multipart: Codable, Equatable, Sendable {
        let manifest: Asset
        let archiveName: String
        let compressedSize: Int64
        let digest: String
        let parts: [Asset]
    }

    var archiveName: String { multipart?.archiveName ?? asset.name }
    var compressedSize: Int64 { multipart?.compressedSize ?? asset.compressedSize }
    var archiveDigest: String? { multipart?.digest ?? asset.digest }

    /// Recheck persisted plans before using their URLs or counting cached bytes.
    func validatedMultipart() throws -> Multipart? {
        guard let multipart else { return nil }
        guard id > 0, !tag.isEmpty, multipart.manifest == asset,
              Self.isProductionDatabaseAssetName(multipart.archiveName),
              asset.name == multipart.archiveName + ".manifest.json",
              asset.compressedSize > 0, asset.compressedSize <= 1_048_576,
              Self.sha256Value(asset.digest) != nil,
              Self.sha256Value(multipart.digest) != nil,
              multipart.compressedSize > 0,
              !multipart.parts.isEmpty, multipart.parts.count <= 1_000 else {
            throw OtzariaDatabaseBootstrapError.invalidAssetMetadata("invalid multipart archive identity")
        }
        var total: Int64 = 0
        var ids: Set<Int64> = [asset.id]
        for (index, part) in multipart.parts.enumerated() {
            let expectedName = multipart.archiveName + String(format: ".part-%03d", index)
            let sum = total.addingReportingOverflow(part.compressedSize)
            guard part.id > 0, ids.insert(part.id).inserted,
                  part.name == expectedName, part.compressedSize > 0,
                  Self.sha256Value(part.digest) != nil, !sum.overflow,
                  Self.isOfficialAssetURL(part.downloadURL, tag: tag, name: part.name) else {
                throw OtzariaDatabaseBootstrapError.invalidAssetMetadata("invalid ordered multipart asset")
            }
            total = sum.partialValue
        }
        guard asset.id > 0,
              Self.isOfficialAssetURL(asset.downloadURL, tag: tag, name: asset.name),
              total == multipart.compressedSize else {
            throw OtzariaDatabaseBootstrapError.invalidAssetMetadata("multipart size or manifest URL differs")
        }
        return multipart
    }

    static func sha256Value(_ digest: String?) -> String? {
        guard let digest, digest.lowercased().hasPrefix("sha256:") else { return nil }
        let value = String(digest.dropFirst(7)).lowercased()
        guard value.utf8.count == 64,
              value.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else { return nil }
        return value
    }

    static func isOfficialAssetURL(_ url: URL, tag: String, name: String) -> Bool {
        url.scheme?.lowercased() == "https" && url.host?.lowercased() == "github.com"
            && url.user == nil && url.password == nil && url.port == nil
            && url.query == nil && url.fragment == nil
            && url.path == "/Otzaria/SeforimLibrary/releases/download/" + tag + "/" + name
    }

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
        ].joined(separator: "|") + (multipart.map { plan in
            "|" + [plan.archiveName, String(plan.compressedSize), plan.digest,
                   plan.parts.map { part in
                       [String(part.id), part.name, part.downloadURL.absoluteString,
                        String(part.compressedSize), part.digest ?? ""].joined(separator: "|")
                   }.joined(separator: "|")].joined(separator: "|")
        } ?? "")
    }

    var expectedSHA256: String? {
        guard let digest else { return nil }
        let prefix = "sha256:"
        guard digest.lowercased().hasPrefix(prefix) else { return nil }
        let value = String(digest.dropFirst(prefix.count)).lowercased()
        guard value.count == 64, value.allSatisfy({ $0.isHexDigit }) else { return nil }
        return value
    }

    private var digest: String? { archiveDigest }
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
    let multipart: OtzariaLibraryRelease.Multipart?
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
        multipart = release.multipart
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
            digest == release.asset.digest &&
            multipart == release.multipart
    }

    var archiveName: String { multipart?.archiveName ?? assetName }
    var archiveCompressedSize: Int64 { multipart?.compressedSize ?? expectedCompressedSize }
    var archiveDigest: String? { multipart?.digest ?? digest }

    var resumeValidator: String? {
        if let etag, !etag.isEmpty, !etag.hasPrefix("W/") { return etag }
        if let lastModified, !lastModified.isEmpty { return lastModified }
        return nil
    }

    func resumableProductionRelease(localSize: Int64) -> OtzariaLibraryRelease? {
        if let multipart {
            let release = OtzariaLibraryRelease(
                id: releaseID, tag: releaseTag, asset: multipart.manifest, multipart: multipart
            )
            guard repository == OtzariaLibraryRelease.repository,
                  matches(release), localSize > 0, localSize <= release.compressedSize,
                  (try? release.validatedMultipart()) != nil else { return nil }
            return release
        }
        let expectedPathPrefix = "/Otzaria/SeforimLibrary/releases/download/"
        guard repository == OtzariaLibraryRelease.repository,
              releaseID > 0,
              !releaseTag.isEmpty,
              assetID > 0,
              OtzariaLibraryRelease.isProductionDatabaseAssetName(assetName),
              browserDownloadURL.scheme?.lowercased() == "https",
              browserDownloadURL.host?.lowercased() == "github.com",
              browserDownloadURL.path.hasPrefix(expectedPathPrefix),
              expectedCompressedSize > 0,
              localSize > 0,
              localSize < expectedCompressedSize,
              resumeValidator != nil else { return nil }

        let release = OtzariaLibraryRelease(
            id: releaseID,
            tag: releaseTag,
            asset: .init(
                id: assetID,
                name: assetName,
                downloadURL: browserDownloadURL,
                compressedSize: expectedCompressedSize,
                digest: digest,
                updatedAt: nil
            )
        )
        guard release.expectedSHA256 != nil else { return nil }
        return release
    }
}

struct OtzariaDatabaseInstallationManifest: Codable, Equatable, Sendable {
    var profileID: String? = nil
    var profileVersion: Int? = nil
    let repository: String
    let releaseID: Int64
    let releaseTag: String
    let assetID: Int64
    let assetName: String
    let compressedSize: Int64
    let digest: String?
    let installedAt: Date
    let databaseFileSize: Int64
    let multipart: OtzariaLibraryRelease.Multipart?

    init(release: OtzariaLibraryRelease, databaseFileSize: Int64) {
        let identity = OtzariaDataProfileRegistry.activeIdentity
        if identity.id != OtzariaDataProfileRegistry.productionID {
            profileID = identity.id
            profileVersion = identity.version
        }
        repository = OtzariaLibraryRelease.repository
        releaseID = release.id
        releaseTag = release.tag
        assetID = release.asset.id
        assetName = release.asset.name
        compressedSize = release.asset.compressedSize
        digest = release.asset.digest
        installedAt = Date()
        self.databaseFileSize = databaseFileSize
        multipart = release.multipart
    }

    var archiveName: String { multipart?.archiveName ?? assetName }
    var archiveCompressedSize: Int64 { multipart?.compressedSize ?? compressedSize }
    var archiveDigest: String? { multipart?.digest ?? digest }

    var hasValidProductionArchiveIdentity: Bool {
        guard let multipart else {
            return OtzariaLibraryRelease.isProductionDatabaseAssetName(assetName)
        }
        let release = OtzariaLibraryRelease(
            id: releaseID, tag: releaseTag, asset: multipart.manifest, multipart: multipart
        )
        return assetID == release.asset.id && assetName == release.asset.name
            && compressedSize == release.asset.compressedSize && digest == release.asset.digest
            && (try? release.validatedMultipart()) != nil
    }

    var effectiveProfileID: String { profileID ?? OtzariaDataProfileRegistry.productionID }
    var effectiveProfileVersion: Int { profileVersion ?? 1 }
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
            return "The latest Otzaria release does not contain a supported seforim database asset."
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

extension OtzariaDatabaseBootstrapError: OtzariaStorageCapacityError {
    var storageCapacityFailure: OtzariaStorageCapacityFailure? {
        guard case let .insufficientDiskSpace(required, available) = self else { return nil }
        return OtzariaStorageCapacityFailure(
            requiredBytes: max(0, required),
            availableBytes: max(0, available)
        )
    }
}
