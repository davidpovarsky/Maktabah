import Foundation

actor SefariaRemoteStore: LibraryCatalogProviding, LibraryTextProviding,
    LibraryNavigationProviding, LibrarySearchProviding, LibraryMetadataProviding {
    private let configuration: SefariaNetworkConfiguration
    private let client: SefariaHTTPClient
    private let cache: SefariaDiskCache
    private var knownTitles: Set<String> = []

    init(
        configuration: SefariaNetworkConfiguration = .production,
        client: SefariaHTTPClient = SefariaHTTPClient(),
        cache: SefariaDiskCache = SefariaDiskCache()
    ) {
        self.configuration = configuration
        self.client = client
        self.cache = cache
    }

    func catalog(forceRefresh: Bool) async throws -> [LibraryCatalogNode] {
        if !forceRefresh, let cached: [SefariaTOCEntryDTO] = await cache.decode("catalog.json") {
            rememberTitles(cached)
            return cached.map(Self.mapCatalog)
        }
        let url = try configuration.apiURL(path: "/api/index")
        let dto = try await client.get([SefariaTOCEntryDTO].self, url: url)
        try await cache.encode(dto, as: "catalog.json")
        rememberTitles(dto)
        return dto.map(Self.mapCatalog)
    }

    func section(at locator: TextLocator) async throws -> LibraryTextSection {
        guard locator.backend == .sefaria, case .canonicalRef(let ref) = locator.position else {
            throw LibraryBackendError.invalidLocator
        }
        let cacheName = "section-\(Data(ref.utf8).base64EncodedString().replacingOccurrences(of: "/", with: "_"))"
        if let cached: SefariaTextsV3DTO = await cache.decode(cacheName) {
            return map(cached, origin: .diskCache).asLibrarySection()
        }
        let url = try configuration.apiURL(pathPrefix: "/api/v3/texts/", pathComponent: ref, queryItems: [
            URLQueryItem(name: "version", value: "primary"),
            URLQueryItem(name: "version", value: "translation"),
            URLQueryItem(name: "return_format", value: "strip_only_footnotes")
        ])
        let dto = try await client.get(SefariaTextsV3DTO.self, url: url)
        try await cache.encode(dto, as: cacheName)
        return map(dto, origin: .remote).asLibrarySection()
    }

    func normalizedLocator(for input: String) async throws -> TextLocator {
        let normalized = SefariaRef.canonicalInput(input)
        let url = try configuration.apiURL(pathPrefix: "/api/name/", pathComponent: normalized)
        let response = try await client.get(SefariaNameDTO.self, url: url)
        guard response.isRef == true, let ref = response.ref else { throw LibraryBackendError.invalidLocator }
        if knownTitles.isEmpty { _ = try? await catalog(forceRefresh: false) }
        guard let work = SefariaRef.workKey(from: ref, knownTitles: Array(knownTitles)) else {
            throw LibraryBackendError.invalidLocator
        }
        return TextLocator(backend: .sefaria, workKey: work, position: .canonicalRef(ref))
    }

    func tableOfContents(for work: LibraryWork) async throws -> [LibraryTOCNode] {
        let url = try configuration.apiURL(pathPrefix: "/api/v2/raw/index/", pathComponent: work.locator.workKey)
        let index = try await client.get(SefariaIndexDTO.self, url: url)
        return SefariaNavigationParser.nodes(schema: index.schema, indexTitle: index.title, baseRef: index.title)
    }

    func search(_ request: LibrarySearchRequest) async throws -> LibrarySearchPage {
        let url = try configuration.apiURL(path: "/api/search-wrapper")
        let response = try await client.post(SefariaSearchResponseDTO.self, url: url, body: SefariaSearchBody(
            query: request.query, start: request.offset, size: request.limit
        ))
        if knownTitles.isEmpty { _ = try? await catalog(forceRefresh: false) }
        let hits = response.hits.hits.compactMap { hit -> LibrarySearchHit? in
            guard let work = SefariaRef.workKey(from: hit.source.ref, knownTitles: Array(knownTitles))
                ?? hit.source.title else { return nil }
            let snippet = hit.highlight?.values.first?.first ?? hit.source.content ?? ""
            return LibrarySearchHit(
                locator: TextLocator(backend: .sefaria, workKey: work, position: .canonicalRef(hit.source.ref)),
                displayRef: hit.source.ref,
                heRef: hit.source.heRef,
                snippet: snippet,
                score: hit.score
            )
        }
        let next = request.offset + hits.count < response.hits.total.value ? request.offset + hits.count : nil
        return LibrarySearchPage(hits: hits, total: response.hits.total.value, nextOffset: next)
    }

    func versions(for workKey: String) async throws -> [TextVersionMetadata] {
        let url = try configuration.apiURL(pathPrefix: "/api/texts/versions/", pathComponent: workKey)
        return try await client.get([SefariaVersion].self, url: url).map(\.metadata)
    }

    func related(to locator: TextLocator) async throws -> [TextLocator] {
        guard case .canonicalRef(let ref) = locator.position else { throw LibraryBackendError.invalidLocator }
        let url = try configuration.apiURL(pathPrefix: "/api/related/", pathComponent: ref)
        let response = try await client.get(SefariaRelatedDTO.self, url: url)
        return response.links.compactMap { link in
            guard let ref = link.ref ?? link.sourceRef,
                  let work = SefariaRef.workKey(from: ref, knownTitles: Array(knownTitles)) else { return nil }
            return TextLocator(backend: .sefaria, workKey: work, position: .canonicalRef(ref))
        }
    }

    func clearTransientState() { knownTitles.removeAll() }

    private func map(_ dto: SefariaTextsV3DTO, origin: LibraryTextSection.Origin) -> SefariaSection {
        SefariaSection(ref: dto.ref, heRef: dto.heRef, sectionRef: dto.sectionRef,
            indexTitle: dto.indexTitle, next: dto.next, prev: dto.prev,
            versions: dto.versions, linksBySegment: [], origin: origin)
    }

    private func rememberTitles(_ entries: [SefariaTOCEntryDTO]) {
        for entry in entries {
            if let title = entry.title { knownTitles.insert(title) }
            rememberTitles(entry.contents)
        }
    }

    private static func mapCatalog(_ entry: SefariaTOCEntryDTO) -> LibraryCatalogNode {
        if let title = entry.title {
            let locator = TextLocator(backend: .sefaria, workKey: title, position: .canonicalRef(title))
            let work = LibraryWork(locator: locator, title: title, heTitle: entry.heTitle,
                categories: [], description: nil)
            return LibraryCatalogNode(id: locator.persistenceKey, kind: .work, title: title,
                heTitle: entry.heTitle, work: work, children: [])
        }
        let title = entry.category ?? ""
        return LibraryCatalogNode(id: "sefaria-category|\(title)", kind: .category, title: title,
            heTitle: entry.heCategory, work: nil, children: entry.contents.map(mapCatalog))
    }

}
