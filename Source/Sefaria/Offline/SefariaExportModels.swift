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
        var excludedTitles: Set<String>? = nil
    }
    struct StandaloneWorkState: Codable, Sendable {
        let title: String
        let installedAt: Date
        let lastUpdated: String?
        let archiveFilename: String
    }

    var schemaVersion = 2
    var packages: [String: PackageState] = [:]
    var standaloneWorks: [String: StandaloneWorkState] = [:]

    private enum CodingKeys: String, CodingKey { case schemaVersion, packages, standaloneWorks }

    init(
        schemaVersion: Int = 2,
        packages: [String: PackageState] = [:],
        standaloneWorks: [String: StandaloneWorkState] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.packages = packages
        self.standaloneWorks = standaloneWorks
    }

    func installedWorkKeys(
        validStandaloneWorkKeys: Set<String>? = nil,
        validPackageWorkKeys: [String: Set<String>]? = nil
    ) -> Set<String> {
        let standalone = validStandaloneWorkKeys.map { Set(standaloneWorks.keys).intersection($0) }
            ?? Set(standaloneWorks.keys)
        return packages.reduce(into: standalone) { result, entry in
            let (id, package) = entry
            let declared = package.titleUpdates.map { Set($0.keys) } ?? []
            let valid = validPackageWorkKeys?[id]
            let available = valid.map { declared.isEmpty ? $0 : declared.intersection($0) } ?? declared
            result.formUnion(available.subtracting(package.excludedTitles ?? []))
        }
    }

    func desiredWorkKeys(
        forPackageID id: String,
        packageIndexTitles: [String]?,
        manifestWorkKeys: Set<String>
    ) -> Set<String> {
        let desired = packageIndexTitles.map(Set.init) ?? manifestWorkKeys
        return desired.subtracting(packages[id]?.excludedTitles ?? [])
    }

    mutating func recordStandaloneInstall(
        workKeys: Set<String>,
        committedArchiveFilenames: [String: String],
        timestamps: [String: String],
        installedAt: Date = Date()
    ) throws {
        guard workKeys.isSubset(of: committedArchiveFilenames.keys) else {
            throw LibraryBackendError.corruptData("standalone install files were not committed")
        }
        var next = standaloneWorks
        for title in workKeys {
            guard let filename = committedArchiveFilenames[title] else { continue }
            next[title] = .init(title: title, installedAt: installedAt,
                lastUpdated: timestamps[title], archiveFilename: filename)
        }
        standaloneWorks = next
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        packages = try values.decodeIfPresent([String: PackageState].self, forKey: .packages) ?? [:]
        standaloneWorks = try values.decodeIfPresent([String: StandaloneWorkState].self, forKey: .standaloneWorks) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(2, forKey: .schemaVersion)
        try values.encode(packages, forKey: .packages)
        try values.encode(standaloneWorks, forKey: .standaloneWorks)
    }
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
    let heTitle: String?
    let categories: [String]?
    let heCategories: [String]?
    let enDesc: String?
    let heDesc: String?
    let schema: SefariaJSONValue
    let versions: [SefariaVersion]
}

enum SefariaOfflineNavigationBuilder {
    static func nodes(
        metadata: [SefariaOfflineMetadataDTO],
        workKey: String,
        localeIdentifier: String? = Locale.preferredLanguages.first
    ) -> [LibraryTOCNode] {
        var seen = Set<String>()
        return ordered(metadata).compactMap { entry in
            let ref = entry.sectionRef.isEmpty ? entry.ref : entry.sectionRef
            guard ref != workKey else { return nil }
            let locator = TextLocator(backend: .sefaria, workKey: workKey, position: .canonicalRef(ref))
            guard seen.insert(locator.persistenceKey).inserted else { return nil }
            return LibraryTOCNode(
                locator: locator,
                title: LibraryPresentationPolicy.reference(
                    displayRef: ref,
                    heRef: entry.heRef,
                    localeIdentifier: localeIdentifier
                ),
                children: []
            )
        }
    }

    private static func ordered(_ metadata: [SefariaOfflineMetadataDTO]) -> [SefariaOfflineMetadataDTO] {
        var byRef: [String: SefariaOfflineMetadataDTO] = [:]
        for entry in metadata { byRef[entry.sectionRef] = entry }
        var remaining = Set(byRef.keys)
        var result: [SefariaOfflineMetadataDTO] = []

        while !remaining.isEmpty {
            let start = remaining.compactMap { byRef[$0] }.filter {
                guard let previous = $0.prev else { return true }
                return !remaining.contains(previous)
            }.min { $0.sectionRef.localizedStandardCompare($1.sectionRef) == .orderedAscending }
                ?? remaining.compactMap { byRef[$0] }.min {
                    $0.sectionRef.localizedStandardCompare($1.sectionRef) == .orderedAscending
                }
            guard var current = start else { break }
            while remaining.remove(current.sectionRef) != nil {
                result.append(current)
                guard let next = current.next, let following = byRef[next], remaining.contains(next) else { break }
                current = following
            }
        }
        return result
    }
}
