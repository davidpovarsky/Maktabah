
import Foundation
import CryptoKit
actor SourceSectionControl {
    let configuration = SefariaNetworkConfiguration.production
    let client: SefariaHTTPClient
    let cache: SefariaDiskCache
    init(client: SefariaHTTPClient, cache: SefariaDiskCache) { self.client = client; self.cache = cache }
    func navigationItems(for work: LibraryWork) async throws -> [LibraryNavigationItem] { throw LibraryBackendError.capabilityUnavailable }
    func rememberSectionReferences(_ dto: SefariaTextsV3DTO) {}
    func section(at locator: TextLocator) async throws -> LibraryTextSection {
        try await section(at: locator, redirectDepth: 0)
    }

    private func section(at locator: TextLocator, redirectDepth: Int) async throws -> LibraryTextSection {
        guard redirectDepth <= 3 else {
            throw LibraryBackendError.invalidResponse("Exceeded maximum redirects for section \(locator)")
        }
        guard locator.backend == .sefaria, case .canonicalRef(let ref) = locator.position else {
            throw LibraryBackendError.invalidLocator
        }
        if LibraryReadingUnitPolicy.isWorkRoot(locator) {
            let work = LibraryWork(locator: locator, title: locator.workKey, heTitle: nil,
                categories: [], description: nil)
            let items = try await navigationItems(for: work)
            return try await section(at: LibraryReadingUnitPolicy.resolve(locator, navigationItems: items), redirectDepth: redirectDepth)
        }
        let cacheName = "section-\(Data(ref.utf8).base64EncodedString().replacingOccurrences(of: "/", with: "_"))"
        if let cached: SefariaTextsV3DTO = await cache.decode(cacheName) {
            rememberSectionReferences(cached)
            if cached.sectionRef != ref {
                return try await section(at: TextLocator(backend: .sefaria, workKey: locator.workKey, position: .canonicalRef(cached.sectionRef)), redirectDepth: redirectDepth + 1)
            }
            return map(cached, origin: .diskCache).asLibrarySection()
        }
        let url = try configuration.apiURL(pathPrefix: "/api/v3/texts/", pathComponent: ref, queryItems: [
            URLQueryItem(name: "version", value: "source"),
            URLQueryItem(name: "version", value: "translation"),
            URLQueryItem(name: "fill_in_missing_segments", value: "1"),
            URLQueryItem(name: "return_format", value: "text_only")
        ])
        let dto = try await client.get(SefariaTextsV3DTO.self, url: url)
        try await cache.encode(dto, as: cacheName)
        rememberSectionReferences(dto)
        if dto.sectionRef != ref {
            return try await section(at: TextLocator(backend: .sefaria, workKey: locator.workKey, position: .canonicalRef(dto.sectionRef)), redirectDepth: redirectDepth + 1)
        }
        return map(dto, origin: .remote).asLibrarySection()
    }

    /// Fetches exactly the selected search edition. Its cache is separate from
    /// the ordinary default source/translation cache and includes the full tuple.
    func section(
        at locator: TextLocator, version: LibraryTextVersionSelection
    ) async throws -> LibraryTextSection {
        try await section(at: locator, version: version, redirectDepth: 0)
    }

    private func section(
        at locator: TextLocator, version: LibraryTextVersionSelection, redirectDepth: Int
    ) async throws -> LibraryTextSection {
        guard redirectDepth <= 3 else {
            throw LibraryBackendError.invalidResponse("Exceeded maximum redirects for selected edition")
        }
        guard locator.backend == .sefaria, case .canonicalRef(let ref) = locator.position,
              !version.title.isEmpty, !version.language.isEmpty else {
            throw LibraryBackendError.invalidLocator
        }
        if LibraryReadingUnitPolicy.isWorkRoot(locator) {
            let work = LibraryWork(locator: locator, title: locator.workKey, heTitle: nil,
                categories: [], description: nil)
            let items = try await navigationItems(for: work)
            return try await section(at: LibraryReadingUnitPolicy.resolve(locator, navigationItems: items),
                version: version, redirectDepth: redirectDepth)
        }
        let cacheName = try SefariaSelectedVersionRequest.cacheName(ref: ref, version: version)
        if let cached: SefariaTextsV3DTO = await cache.decode(cacheName) {
            try SefariaSelectedVersionRequest.validate(cached, locator: locator, version: version)
            rememberSectionReferences(cached)
            if cached.sectionRef != ref {
                return try await section(at: TextLocator(backend: .sefaria, workKey: locator.workKey,
                    position: .canonicalRef(cached.sectionRef)), version: version, redirectDepth: redirectDepth + 1)
            }
            return map(cached, origin: .diskCache).asLibrarySection()
        }
        let versionsURL = try configuration.apiURL(
            pathPrefix: "/api/texts/versions/", pathComponent: locator.workKey)
        let versions = try await client.get([SefariaVersion].self, url: versionsURL)
        let metadata = try SefariaSelectedVersionRequest.metadata(for: version, in: versions)
        let url = try configuration.apiURL(pathPrefix: "/api/v3/texts/", pathComponent: ref,
            queryItems: try SefariaSelectedVersionRequest.queryItems(for: metadata))
        let dto = try await client.get(SefariaTextsV3DTO.self, url: url)
        try Task.checkCancellation()
        // A missing edition can be a successful HTTP response containing a warning.
        // Validate the response before caching or displaying a body under its title.
        try SefariaSelectedVersionRequest.validate(dto, locator: locator, version: version)
        try await cache.encode(dto, as: cacheName)
        rememberSectionReferences(dto)
        if dto.sectionRef != ref {
            return try await section(at: TextLocator(backend: .sefaria, workKey: locator.workKey,
                position: .canonicalRef(dto.sectionRef)), version: version, redirectDepth: redirectDepth + 1)
        }
        return map(dto, origin: .remote).asLibrarySection()
    }

    private func map(_ dto: SefariaTextsV3DTO, origin: LibraryTextSection.Origin) -> SefariaSection {
        SefariaSection(ref: dto.ref, heRef: dto.heRef, sectionRef: dto.sectionRef,
            indexTitle: dto.indexTitle, next: dto.next, prev: dto.prev,
            versions: dto.versions, linksBySegment: [], origin: origin)
    }


    func expandedContext(at locator: TextLocator, selected version: LibraryTextVersionSelection) async throws -> LibraryTextSection {
        try await section(at: locator, version: version)
    }
}
enum SefariaSelectedVersionRequest {
    static func cacheName(ref: String, version: LibraryTextVersionSelection) throws -> String {
        let key = try JSONEncoder().encode([ref, version.title, version.language])
        return "selected-section-" + SHA256.hash(data: key).map { String(format: "%02x", $0) }.joined()
    }

    static func metadata(
        for selection: LibraryTextVersionSelection, in versions: [SefariaVersion]
    ) throws -> SefariaVersion {
        let matches = versions.filter {
            $0.versionTitle == selection.title && $0.language == selection.language
        }
        guard matches.count == 1, let selected = matches.first else {
            throw LibraryBackendError.invalidResponse("The selected text edition is unavailable or ambiguous.")
        }
        return selected
    }

    static func queryItems(for version: SefariaVersion) throws -> [URLQueryItem] {
        guard let family = version.languageFamilyName, !family.isEmpty else {
            throw LibraryBackendError.invalidResponse("The selected text edition has no language family.")
        }
        return [
            URLQueryItem(name: "version", value: "\(family)|\(version.versionTitle)"),
            URLQueryItem(name: "version", value: version.isSource == true ? "translation" : "source"),
            URLQueryItem(name: "fill_in_missing_segments", value: "0"),
            URLQueryItem(name: "return_format", value: "text_only")
        ]
    }

    static func validate(
        _ dto: SefariaTextsV3DTO, locator: TextLocator, version: LibraryTextVersionSelection
    ) throws {
        guard case .canonicalRef(let ref) = locator.position,
              dto.indexTitle == locator.workKey,
              SefariaRef.canonicalInput(dto.ref) == SefariaRef.canonicalInput(ref),
              !dto.sectionRef.isEmpty else {
            throw LibraryBackendError.invalidResponse("The selected edition returned a different source.")
        }
        _ = try metadata(for: version, in: dto.versions)
    }
}

func previewVisibility(mode: LibraryReaderTextMode, language: String?, primary: String, translation: String?) -> (Bool, Bool) {
    let readerMode = mode
    let item = (resultLanguage: language, unused: false)
    let segment = (primary: primary, translation: translation)
                            let hasTranslation = segment.translation?.isEmpty == false
                            let showPrimary = readerMode == .source || readerMode == .both
                                || (readerMode == .translation && !hasTranslation)
                            let showTranslation = hasTranslation
                                && (readerMode == .translation || readerMode == .both
                                    || (readerMode == .source && segment.primary.isEmpty))

    return (showPrimary, showTranslation)
}
