
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

    private func map(_ dto: SefariaTextsV3DTO, origin: LibraryTextSection.Origin) -> SefariaSection {
        SefariaSection(ref: dto.ref, heRef: dto.heRef, sectionRef: dto.sectionRef,
            indexTitle: dto.indexTitle, next: dto.next, prev: dto.prev,
            versions: dto.versions, linksBySegment: [], origin: origin)
    }


    func expandedContext(at locator: TextLocator, selected version: LibraryTextVersionSelection) async throws -> LibraryTextSection {
        try await section(at: locator)
    }
}

func previewVisibility(mode: LibraryReaderTextMode, language: String?, primary: String, translation: String?) -> (Bool, Bool) {
    let readerMode = mode
    let item = (resultLanguage: language, unused: false)
    let segment = (primary: primary, translation: translation)
let isTranslationVersion = (item.resultLanguage != nil && item.resultLanguage != "he")
                            let showPrimary = isTranslationVersion
                                ? (segment.translation == nil || segment.translation!.isEmpty)
                                : (readerMode == .source || readerMode == .both || (readerMode == .translation && (segment.translation == nil || segment.translation!.isEmpty)))
                            let showTranslation = isTranslationVersion
                                ? (segment.translation != nil && !segment.translation!.isEmpty)
                                : ((readerMode == .translation || readerMode == .both || (readerMode == .source && segment.primary.isEmpty)) && segment.translation != nil && !segment.translation!.isEmpty)

    return (showPrimary, showTranslation)
}
