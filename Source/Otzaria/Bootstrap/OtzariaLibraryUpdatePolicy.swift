import Foundation

/// Full snapshots use the original managed installer. The upstream Dart delta
/// patch format is deliberately not interpreted by the legacy Maktabah updater.
enum OtzariaLibraryUpdatePolicy {
    enum UpdateError: LocalizedError {
        case unverifiedInstallation
        case changedRelease
        case changedSelection
        case unmanagedLibrary
        case alreadyRunning

        var errorDescription: String? {
            switch self {
            case .unverifiedInstallation:
                return String(localized: "otzaria.update.error.unverified")
            case .changedRelease:
                return String(localized: "otzaria.update.error.releaseChanged")
            case .changedSelection:
                return String(localized: "otzaria.update.error.selectionChanged")
            case .unmanagedLibrary:
                return String(localized: "otzaria.update.error.unmanaged")
            case .alreadyRunning:
                return String(localized: "otzaria.update.error.running")
            }
        }
    }

    static func validateInstalled(_ installed: OtzariaDatabaseInstallationManifest) throws {
        guard installed.repository == OtzariaLibraryRelease.repository,
              installed.effectiveProfileID == OtzariaDataProfileRegistry.productionID,
              installed.effectiveProfileVersion == 1,
              installed.releaseID > 0, installed.assetID > 0,
              installed.compressedSize > 0, installed.databaseFileSize > 0,
              installed.hasValidProductionArchiveIdentity,
              OtzariaLibraryRelease.sha256Value(installed.archiveDigest) != nil,
              version(in: installed.releaseTag) != nil else {
            throw UpdateError.unverifiedInstallation
        }
    }

    static func validateRelease(_ release: OtzariaLibraryRelease) throws {
        guard release.id > 0, release.asset.id > 0,
              release.compressedSize > 0,
              OtzariaLibraryRelease.isProductionDatabaseAssetName(release.archiveName),
              OtzariaLibraryRelease.sha256Value(release.archiveDigest) != nil,
              OtzariaLibraryRelease.isOfficialAssetURL(
                release.asset.downloadURL, tag: release.tag, name: release.asset.name),
              version(in: release.tag) != nil else {
            throw UpdateError.changedRelease
        }
        _ = try release.validatedMultipart()
    }

    /// Equality binds the whole asset plan, including every multipart digest.
    /// A republished release cannot silently replace an already installed ID.
    static func isNewer(
        _ release: OtzariaLibraryRelease,
        than installed: OtzariaDatabaseInstallationManifest
    ) throws -> Bool {
        try validateInstalled(installed)
        try validateRelease(release)
        if installed.releaseID == release.id {
            guard installed.releaseTag == release.tag,
                  installed.assetID == release.asset.id,
                  installed.assetName == release.asset.name,
                  installed.compressedSize == release.asset.compressedSize,
                  installed.digest == release.asset.digest,
                  installed.multipart == release.multipart else {
                throw UpdateError.changedRelease
            }
            return false
        }
        guard let current = version(in: installed.releaseTag),
              let latest = version(in: release.tag) else {
            throw UpdateError.changedRelease
        }
        return latest > current
    }

    static func version(in tag: String) -> Int? {
        let components = tag.split(separator: "-", omittingEmptySubsequences: false)
        guard components.count == 2, components[0].first == "v",
              components[1].count == 14, components[1].allSatisfy({ $0.isASCII && $0.isNumber }) else {
            return nil
        }
        let digits = components[0].dropFirst()
        guard !digits.isEmpty, digits.allSatisfy({ $0.isASCII && $0.isNumber }),
              let value = Int(digits), value > 0, String(value) == digits else { return nil }
        return value
    }
}
