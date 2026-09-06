import Foundation

enum OtzariaDataComponent: String, Codable, CaseIterable, Sendable {
    case database
    case otzariaSearch
    case zayitSearch
}

struct OtzariaDataProfile: Codable, Equatable, Identifiable, Sendable {
    struct SourceDatabase: Codable, Equatable, Sendable {
        let repository: String
        let releaseTag: String
        let releaseID: Int64
        let assetID: Int64
        let assetName: String
        let sourceAssetBytes: Int64
        let sourceAssetSHA256: String
        let databaseBytes: Int64
        let databaseSHA256: String
    }

    struct SharedLexicalDatabase: Codable, Equatable, Sendable {
        let releaseTag: String
        let bytes: Int64
        let sha256: String
    }

    let profileID: String
    let profileVersion: Int
    let displayName: String
    let releaseBaseURL: URL
    let databaseAssetName: String
    let databaseCompressedBytes: Int64
    let databaseCompressedSHA256: String
    let otzariaManifestAssetName: String
    let zayitManifestAssetName: String
    let sourceDatabase: SourceDatabase
    let sharedLexicalDatabase: SharedLexicalDatabase
    let bookIDs: [Int]
    let goldenQueries: [String]

    var id: String { profileID }
    var databaseDownloadURL: URL { releaseBaseURL.appendingPathComponent(databaseAssetName) }
    var otzariaManifestURL: URL { releaseBaseURL.appendingPathComponent(otzariaManifestAssetName) }
    var zayitManifestURL: URL { releaseBaseURL.appendingPathComponent(zayitManifestAssetName) }

    func validate() throws {
        guard profileID.range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil,
              profileVersion > 0,
              releaseBaseURL.scheme?.lowercased() == "https",
              Set(bookIDs).count == bookIDs.count,
              !bookIDs.isEmpty,
              databaseCompressedBytes > 0,
              sourceDatabase.databaseBytes > 0,
              sourceDatabase.sourceAssetBytes > 0,
              !sharedLexicalDatabase.releaseTag.isEmpty,
              sharedLexicalDatabase.bytes > 0,
              Self.isSHA256(sharedLexicalDatabase.sha256),
              Self.isSHA256(sourceDatabase.sourceAssetSHA256),
              Self.isSHA256(databaseCompressedSHA256),
              Self.isSHA256(sourceDatabase.databaseSHA256) else {
            throw OtzariaDataProfileError.invalidManifest("unsafe or incomplete profile metadata")
        }
        for name in [databaseAssetName, otzariaManifestAssetName, zayitManifestAssetName] {
            guard !name.isEmpty, name == URL(fileURLWithPath: name).lastPathComponent else {
                throw OtzariaDataProfileError.invalidManifest("unsafe asset name")
            }
        }
    }

    private static func isSHA256(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy(\.isHexDigit)
    }
}

enum OtzariaDataProfileError: LocalizedError, Sendable {
    case profileNotFound(String)
    case invalidManifest(String)

    var errorDescription: String? {
        switch self {
        case .profileNotFound(let id):
            return "The Otzaria data profile '\(id)' is not bundled with this build."
        case .invalidManifest(let detail):
            return "The Otzaria data profile is invalid: \(detail)"
        }
    }
}

enum OtzariaDataProfileCompatibility {
    static func matches(
        profileID: String?,
        profileVersion: Int?,
        activeID: String,
        activeVersion: Int
    ) -> Bool {
        (profileID ?? OtzariaDataProfileRegistry.productionID) == activeID
            && (profileVersion ?? 1) == activeVersion
    }

    static func matchesActiveProfile(profileID: String?, profileVersion: Int?) -> Bool {
        let active = OtzariaDataProfileRegistry.activeIdentity
        return matches(
            profileID: profileID,
            profileVersion: profileVersion,
            activeID: active.id,
            activeVersion: active.version
        )
    }
}
