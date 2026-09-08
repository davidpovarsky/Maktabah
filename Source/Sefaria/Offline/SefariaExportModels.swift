import Foundation

enum SefariaExportContract {
    static let supportedSchemas: Set<String> = ["7"]
    static let currentSchema = "7"
    static func rootPath(schema: String) -> String { "/static/ios-export/\(schema)" }
    static func validate(schema: String) throws {
        guard supportedSchemas.contains(schema) else {
            throw LibraryBackendError.unsupportedSchema(found: schema, supported: supportedSchemas.sorted())
        }
    }
}

struct SefariaPackageManifestEntry: Codable, Hashable, Sendable {
    let en: String
    let he: String?
    let parent: String?
    let size: Int64
    let indexes: [String]?
    let color: String?

    var package: OfflinePackage {
        OfflinePackage(
            id: en,
            title: en,
            heTitle: he,
            parentID: parent,
            compressedSize: size,
            indexTitles: indexes,
            isCompleteLibrary: en.localizedCaseInsensitiveContains("complete library")
        )
    }
}

struct SefariaLastUpdatedManifest: Codable, Sendable {
    let schemaVersion: String
    let titles: [String: String]
    enum CodingKeys: String, CodingKey { case schemaVersion = "schema_version", titles }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        if let string = try? values.decode(String.self, forKey: .schemaVersion) {
            schemaVersion = string
        } else {
            schemaVersion = String(try values.decode(Int.self, forKey: .schemaVersion))
        }
        titles = try values.decode([String: String].self, forKey: .titles)
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(schemaVersion, forKey: .schemaVersion)
        try values.encode(titles, forKey: .titles)
    }
}

struct SefariaInstalledState: Codable, Sendable {
    struct PackageState: Codable, Sendable {
        let id: String
        let installedAt: Date
        let schemaVersion: String
        let bundlePaths: [String]
        var titleUpdates: [String: String]? = nil
    }
    var schemaVersion = 1
    var packages: [String: PackageState] = [:]
}

struct SefariaOfflineMetadataDTO: Codable, Sendable {
    struct VersionPointer: Codable, Sendable { let versionTitle: String; let language: String }
    let ref: String
    let heRef: String?
    let indexTitle: String
    let sectionRef: String
    let next: String?
    let prev: String?
    let versions: [VersionPointer]
    let links: [[SefariaLink]]?
}

struct SefariaOfflineIndexDTO: Codable, Sendable {
    let title: String
    let schema: SefariaJSONValue
    let versions: [SefariaVersion]
}
