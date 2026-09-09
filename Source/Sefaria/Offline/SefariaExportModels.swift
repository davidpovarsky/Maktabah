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
    let sections: [String: SefariaOfflineMetadataDTO]?
    let containerRef: String?

    private enum CodingKeys: String, CodingKey {
        case ref, heRef, indexTitle, sectionRef, next, prev, versions, links, sections
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        ref = try values.decode(String.self, forKey: .ref)
        heRef = try values.decodeIfPresent(String.self, forKey: .heRef)
        indexTitle = try values.decodeIfPresent(String.self, forKey: .indexTitle) ?? ""
        sectionRef = try values.decodeIfPresent(String.self, forKey: .sectionRef) ?? ref
        next = try values.decodeIfPresent(String.self, forKey: .next)
        prev = try values.decodeIfPresent(String.self, forKey: .prev)
        versions = try values.decodeIfPresent([VersionPointer].self, forKey: .versions) ?? []
        links = try values.decodeIfPresent([[SefariaLink]].self, forKey: .links)
        sections = try values.decodeIfPresent([String: Self].self, forKey: .sections)
        containerRef = nil
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(ref, forKey: .ref)
        try values.encodeIfPresent(heRef, forKey: .heRef)
        if !indexTitle.isEmpty { try values.encode(indexTitle, forKey: .indexTitle) }
        if sectionRef != ref { try values.encode(sectionRef, forKey: .sectionRef) }
        try values.encodeIfPresent(next, forKey: .next)
        try values.encodeIfPresent(prev, forKey: .prev)
        if !versions.isEmpty { try values.encode(versions, forKey: .versions) }
        try values.encodeIfPresent(links, forKey: .links)
        try values.encodeIfPresent(sections, forKey: .sections)
    }

    var flattenedSections: [SefariaOfflineMetadataDTO] {
        guard let sections, !sections.isEmpty else { return [self] }
        return sections.keys.sorted().flatMap { key -> [Self] in
            guard let child = sections[key] else { return [] }
            return child.withContainerRef(containerRef ?? ref).flattenedSections
        }
    }

    private func withContainerRef(_ value: String) -> Self {
        Self(
            ref: ref,
            heRef: heRef,
            indexTitle: indexTitle,
            sectionRef: sectionRef,
            next: next,
            prev: prev,
            versions: versions,
            links: links,
            sections: sections,
            containerRef: value
        )
    }

    private init(
        ref: String,
        heRef: String?,
        indexTitle: String,
        sectionRef: String,
        next: String?,
        prev: String?,
        versions: [VersionPointer],
        links: [[SefariaLink]]?,
        sections: [String: Self]?,
        containerRef: String?
    ) {
        self.ref = ref
        self.heRef = heRef
        self.indexTitle = indexTitle
        self.sectionRef = sectionRef
        self.next = next
        self.prev = prev
        self.versions = versions
        self.links = links
        self.sections = sections
        self.containerRef = containerRef
    }
}

struct SefariaOfflineIndexDTO: Codable, Sendable {
    let title: String
    let schema: SefariaJSONValue
    let versions: [SefariaVersion]
}
