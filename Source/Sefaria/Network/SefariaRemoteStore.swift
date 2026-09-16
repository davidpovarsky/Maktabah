import Foundation

actor SefariaRemoteStore: LibraryCatalogProviding, LibraryTextProviding,
    LibraryNavigationProviding, LibrarySearchProviding, LibraryMetadataProviding,
    LibraryRelationshipsProviding {
    private let configuration: SefariaNetworkConfiguration
    private let client: SefariaHTTPClient
    private let cache: SefariaDiskCache
    private var knownTitles: Set<String> = []
    private var activeSession: BooleanSearchSession?
    private var activeSessionKey: BooleanSearchSessionKey?

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
            return cached.map { Self.mapCatalog($0, parentPath: []) }
        }
        let url = try configuration.apiURL(path: "/api/index")
        let dto = try await client.get([SefariaTOCEntryDTO].self, url: url)
        try await cache.encode(dto, as: "catalog.json")
        rememberTitles(dto)
        return dto.map { Self.mapCatalog($0, parentPath: []) }
    }

    func section(at locator: TextLocator) async throws -> LibraryTextSection {
        guard locator.backend == .sefaria, case .canonicalRef(let ref) = locator.position else {
            throw LibraryBackendError.invalidLocator
        }
        let cacheName = "section-\(Data(ref.utf8).base64EncodedString().replacingOccurrences(of: "/", with: "_"))"
        if let cached: SefariaTextsV3DTO = await cache.decode(cacheName) {
            if cached.sectionRef != ref {
                return try await section(at: TextLocator(backend: .sefaria, workKey: locator.workKey, position: .canonicalRef(cached.sectionRef)))
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
        if dto.sectionRef != ref {
            return try await section(at: TextLocator(backend: .sefaria, workKey: locator.workKey, position: .canonicalRef(dto.sectionRef)))
        }
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
        let indexURL = try configuration.apiURL(
            pathPrefix: "/api/v2/raw/index/",
            pathComponent: work.locator.workKey
        )
        let shapeURL = try configuration.apiURL(
            pathPrefix: "/api/shape/",
            pathComponent: work.locator.workKey
        )
        async let indexRequest = client.get(SefariaIndexDTO.self, url: indexURL)
        async let shapeRequest = client.get([SefariaShapeDTO].self, url: shapeURL)
        let index = try await indexRequest
        let shapes = try? await shapeRequest
        if let shapes, !shapes.isEmpty {
            return SefariaNavigationParser.nodes(
                shapes: shapes,
                schema: index.schema,
                alternateStructures: index.alternateStructures,
                indexTitle: index.title
            )
        }
        return SefariaNavigationParser.nodes(
            schema: index.schema,
            alternateStructures: index.alternateStructures,
            indexTitle: index.title,
            baseRef: index.title
        )
    }

    func navigationItems(for work: LibraryWork) async throws -> [LibraryNavigationItem] {
        let toc = try await tableOfContents(for: work)
        var items: [LibraryNavigationItem] = []
        func collectLeaves(_ nodes: [LibraryTOCNode]) {
            for node in nodes {
                if node.children.isEmpty {
                    items.append(LibraryNavigationItem(
                        locator: node.locator,
                        title: node.title,
                        index: items.count
                    ))
                } else {
                    collectLeaves(node.children)
                }
            }
        }
        collectLeaves(toc)
        return items
    }
    func search(_ request: LibrarySearchRequest) async throws -> LibrarySearchPage {
        let terms = Self.extractSearchTerms(from: request.query)
        if request.options.searchMode == .or && terms.count > 1 {
            return try await searchOr(terms: terms, request: request)
        }
        if request.options.searchMode == .contains && terms.count > 1 {
            return try await searchContains(terms: terms, request: request)
        }

        invalidateSearchSession()

        let url = try configuration.apiURL(path: "/api/search-wrapper")
        let response = try await client.post(SefariaSearchResponseDTO.self, url: url, body: SefariaSearchBody(
            query: request.query,
            start: request.offset,
            size: request.limit,
            filters: request.filters,
            options: request.options
        ))
        if knownTitles.isEmpty { _ = try? await catalog(forceRefresh: false) }
        let hits = mapSearchHits(response.hits.hits)
        let receivedCount = response.hits.hits.count
        let next = receivedCount > 0 && request.offset + receivedCount < response.hits.total.value
            ? request.offset + receivedCount
            : nil
        return LibrarySearchPage(hits: hits, total: response.hits.total.value, nextOffset: next)
    }

    nonisolated static func extractSearchTerms(from query: String) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // Protect internal quotes between letters (Hebrew gershayim abbreviations like רש"י)
        let protected = trimmed.replacingOccurrences(
            of: #"(\S)"(\S)"#,
            with: "$1\u{05F4}$2",
            options: .regularExpression
        )

        var terms: [String] = []
        var inQuotes = false
        var current = ""

        for char in protected {
            if char == "\"" {
                if inQuotes {
                    let term = current.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !term.isEmpty {
                        terms.append(term)
                    }
                    current = ""
                    inQuotes = false
                } else {
                    let term = current.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !term.isEmpty {
                        terms.append(contentsOf: term.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
                    }
                    current = ""
                    inQuotes = true
                }
            } else {
                current.append(char)
            }
        }
        let remainder = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !remainder.isEmpty {
            if inQuotes {
                terms.append(remainder)
            } else {
                terms.append(contentsOf: remainder.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
            }
        }
        return terms
    }

    private struct BooleanSearchSessionKey: Equatable {
        let query: String
        let searchMode: LibrarySearchMode
        let matchMode: LibrarySearchMatchMode
        let filters: [String]
        let sortOrder: LibrarySearchSortOrder
        let reverseSort: Bool

        init(request: LibrarySearchRequest) {
            self.query = request.query
            self.searchMode = request.options.searchMode
            self.matchMode = request.options.matchMode
            self.filters = request.filters
            self.sortOrder = request.options.sortOrder
            self.reverseSort = request.options.reverseSort
        }
    }

    private final class TermStreamState {
        let term: String
        var nextRemoteStart: Int = 0
        var total: Int = 0
        var hasMoreRemote: Bool = true
        var hitsByLocator: [String: LibrarySearchHit] = [:]
        var orderedLocators: [String] = []

        init(term: String) {
            self.term = term
        }
    }

    private final class BooleanSearchSession {
        let key: BooleanSearchSessionKey
        let streams: [TermStreamState]
        var uniqueHitsMap: [String: LibrarySearchHit] = [:]

        init(key: BooleanSearchSessionKey, terms: [String]) {
            self.key = key
            self.streams = terms.map { TermStreamState(term: $0) }
        }
    }

    private func searchOr(terms: [String], request: LibrarySearchRequest) async throws -> LibrarySearchPage {
        if knownTitles.isEmpty { _ = try? await catalog(forceRefresh: false) }
        try Task.checkCancellation()

        let key = BooleanSearchSessionKey(request: request)
        let session: BooleanSearchSession
        if let existing = activeSession, activeSessionKey == key {
            session = existing
        } else {
            session = BooleanSearchSession(key: key, terms: terms)
            activeSession = session
            activeSessionKey = key
        }

        let targetCount = request.offset + request.limit
        let batchSize = max(request.limit, 25)
        let maxBatchesPerCall = 15

        typealias BatchResult = (termIndex: Int, rawHits: [SefariaSearchResponseDTO.Hit], total: Int)
        var iterations = 0

        while session.streams.contains(where: { $0.hasMoreRemote }) {
            try Task.checkCancellation()
            let activeIndices = session.streams.indices.filter { session.streams[$0].hasMoreRemote }
            guard !activeIndices.isEmpty else { break }

            iterations += 1

            let batchResults = try await withThrowingTaskGroup(of: BatchResult.self) { group in
                for idx in activeIndices {
                    let term = session.streams[idx].term
                    let start = session.streams[idx].nextRemoteStart
                    let filters = request.filters
                    var termOptions = request.options
                    termOptions.searchMode = .phrase
                    termOptions.wordDistance = 0
                    let apiURL = try self.configuration.apiURL(path: "/api/search-wrapper")

                    group.addTask {
                        let response = try await self.client.post(
                            SefariaSearchResponseDTO.self,
                            url: apiURL,
                            body: SefariaSearchBody(
                                query: term,
                                start: start,
                                size: batchSize,
                                filters: filters,
                                options: termOptions
                            )
                        )
                        return (termIndex: idx, rawHits: response.hits.hits, total: response.hits.total.value)
                    }
                }
                var results: [BatchResult] = []
                for try await item in group {
                    results.append(item)
                }
                return results
            }

            for result in batchResults {
                let idx = result.termIndex
                let rawHits = result.rawHits
                let total = result.total
                let stream = session.streams[idx]
                stream.total = total
                stream.nextRemoteStart += rawHits.count
                if rawHits.isEmpty || stream.nextRemoteStart >= total {
                    stream.hasMoreRemote = false
                }
                let hits = mapSearchHits(rawHits)
                for hit in hits {
                    let locatorKey = hit.locator.persistenceKey
                    if let existing = session.uniqueHitsMap[locatorKey] {
                        if (hit.score ?? 0) > (existing.score ?? 0) {
                            session.uniqueHitsMap[locatorKey] = hit
                        }
                    } else {
                        session.uniqueHitsMap[locatorKey] = hit
                    }
                }
            }

            let hasReachedTarget = session.uniqueHitsMap.count >= targetCount
            let hasAtLeastOneForOffset = session.uniqueHitsMap.count > request.offset
            let allStreamsExhausted = !session.streams.contains(where: { $0.hasMoreRemote })

            if allStreamsExhausted || hasReachedTarget {
                break
            }
            if iterations >= maxBatchesPerCall && hasAtLeastOneForOffset {
                break
            }
        }

        let sortedHits = session.uniqueHitsMap.values.sorted { a, b in
            let sa = a.score ?? 0
            let sb = b.score ?? 0
            if sa != sb {
                return sa > sb
            }
            return a.locator.persistenceKey < b.locator.persistenceKey
        }

        let slice = Array(sortedHits.dropFirst(min(request.offset, sortedHits.count)).prefix(request.limit))
        let anyStreamHasMore = session.streams.contains { $0.hasMoreRemote }
        let hasMoreHits = (sortedHits.count > request.offset + slice.count) || anyStreamHasMore
        let nextOffset = (hasMoreHits && !slice.isEmpty) ? request.offset + slice.count : nil

        let maxTermTotal = session.streams.map(\.total).max() ?? sortedHits.count
        let total = anyStreamHasMore
            ? max(sortedHits.count + (hasMoreHits ? 1 : 0), maxTermTotal)
            : sortedHits.count

        return LibrarySearchPage(hits: slice, total: total, nextOffset: nextOffset)
    }

    private func searchContains(terms: [String], request: LibrarySearchRequest) async throws -> LibrarySearchPage {
        if knownTitles.isEmpty { _ = try? await catalog(forceRefresh: false) }
        try Task.checkCancellation()

        let key = BooleanSearchSessionKey(request: request)
        let session: BooleanSearchSession
        if let existing = activeSession, activeSessionKey == key {
            session = existing
        } else {
            session = BooleanSearchSession(key: key, terms: terms)
            activeSession = session
            activeSessionKey = key
        }

        let targetCount = request.offset + request.limit
        let batchSize = max(request.limit, 25)
        let maxBatchesPerCall = 15

        typealias BatchResult = (termIndex: Int, rawHits: [SefariaSearchResponseDTO.Hit], total: Int)
        var candidateKeys: [String] = []
        var iterations = 0

        while session.streams.contains(where: { $0.hasMoreRemote }) {
            try Task.checkCancellation()
            let activeIndices = session.streams.indices.filter { session.streams[$0].hasMoreRemote }
            guard !activeIndices.isEmpty else { break }

            iterations += 1

            let batchResults = try await withThrowingTaskGroup(of: BatchResult.self) { group in
                for idx in activeIndices {
                    let term = session.streams[idx].term
                    let start = session.streams[idx].nextRemoteStart
                    let filters = request.filters
                    var termOptions = request.options
                    termOptions.searchMode = .phrase
                    termOptions.wordDistance = 0
                    let apiURL = try self.configuration.apiURL(path: "/api/search-wrapper")

                    group.addTask {
                        let response = try await self.client.post(
                            SefariaSearchResponseDTO.self,
                            url: apiURL,
                            body: SefariaSearchBody(
                                query: term,
                                start: start,
                                size: batchSize,
                                filters: filters,
                                options: termOptions
                            )
                        )
                        return (termIndex: idx, rawHits: response.hits.hits, total: response.hits.total.value)
                    }
                }
                var results: [BatchResult] = []
                for try await item in group {
                    results.append(item)
                }
                return results
            }

            for result in batchResults {
                let idx = result.termIndex
                let rawHits = result.rawHits
                let total = result.total
                let stream = session.streams[idx]
                stream.total = total
                stream.nextRemoteStart += rawHits.count
                if rawHits.isEmpty || stream.nextRemoteStart >= total {
                    stream.hasMoreRemote = false
                }
                let hits = mapSearchHits(rawHits)
                for hit in hits {
                    let locatorKey = hit.locator.persistenceKey
                    if stream.hitsByLocator[locatorKey] == nil {
                        stream.orderedLocators.append(locatorKey)
                        stream.hitsByLocator[locatorKey] = hit
                    }
                }
            }

            guard !session.streams.isEmpty else { break }
            candidateKeys = session.streams[0].orderedLocators.filter { key in
                session.streams.dropFirst().allSatisfy { $0.hitsByLocator[key] != nil }
            }

            let hasReachedTarget = candidateKeys.count >= targetCount
            let hasAtLeastOneForOffset = candidateKeys.count > request.offset
            let allStreamsExhausted = !session.streams.contains(where: { $0.hasMoreRemote })

            if allStreamsExhausted || hasReachedTarget {
                break
            }
            if iterations >= maxBatchesPerCall && hasAtLeastOneForOffset {
                break
            }
        }

        if !session.streams.isEmpty {
            candidateKeys = session.streams[0].orderedLocators.filter { key in
                session.streams.dropFirst().allSatisfy { $0.hitsByLocator[key] != nil }
            }
        }

        var commonHits: [LibrarySearchHit] = []
        for key in candidateKeys {
            guard let first = session.streams[0].hitsByLocator[key] else { continue }
            var totalScore: Double = 0
            var scoreCount = 0
            for stream in session.streams {
                if let h = stream.hitsByLocator[key], let s = h.score {
                    totalScore += s
                    scoreCount += 1
                }
            }
            let combinedScore = scoreCount > 0 ? totalScore / Double(scoreCount) : nil
            commonHits.append(LibrarySearchHit(
                locator: first.locator,
                displayRef: first.displayRef,
                heRef: first.heRef,
                snippet: first.snippet,
                score: combinedScore
            ))
        }

        commonHits.sort { a, b in
            let sa = a.score ?? 0
            let sb = b.score ?? 0
            if sa != sb {
                return sa > sb
            }
            return a.locator.persistenceKey < b.locator.persistenceKey
        }

        let slice = Array(commonHits.dropFirst(min(request.offset, commonHits.count)).prefix(request.limit))
        let anyStreamHasMore = session.streams.contains { $0.hasMoreRemote }
        let hasMoreCandidates = (commonHits.count > request.offset + slice.count) || anyStreamHasMore
        let nextOffset = (hasMoreCandidates && !slice.isEmpty) ? request.offset + slice.count : nil

        let total = anyStreamHasMore
            ? max(commonHits.count + (hasMoreCandidates ? 1 : 0), request.offset + slice.count + (hasMoreCandidates ? 1 : 0))
            : commonHits.count

        return LibrarySearchPage(hits: slice, total: total, nextOffset: nextOffset)
    }


    private func mapSearchHits(_ rawHits: [SefariaSearchResponseDTO.Hit]) -> [LibrarySearchHit] {
        rawHits.compactMap { hit -> LibrarySearchHit? in
            guard let work = SefariaRef.workKey(from: hit.source.ref, knownTitles: Array(knownTitles))
                ?? hit.source.title else { return nil }
            let snippet = hit.highlight?.values.first?.first
                ?? hit.source.content
                ?? hit.source.naiveLemmatizer
                ?? hit.source.exact
                ?? ""
            return LibrarySearchHit(
                locator: TextLocator(backend: .sefaria, workKey: work, position: .canonicalRef(hit.source.ref)),
                displayRef: hit.source.ref,
                heRef: hit.source.heRef,
                snippet: snippet,
                score: hit.score
            )
        }
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

    func links(for locator: TextLocator) async throws -> [LibraryRelatedSource] {
        guard locator.backend == .sefaria, case .canonicalRef(let ref) = locator.position else {
            throw LibraryBackendError.invalidLocator
        }
        let url = try configuration.apiURL(
            pathPrefix: "/api/links/",
            pathComponent: ref,
            queryItems: [URLQueryItem(name: "with_text", value: "1")]
        )
        // Decode rows independently: one malformed row is logged and skipped
        // rather than failing the entire relationship list.
        let rawArray = try await client.get([SefariaJSONValue].self, url: url)
        let decoder = JSONDecoder()
        var results: [LibraryRelatedSource] = []
        for (index, raw) in rawArray.enumerated() {
            guard case .object = raw else { continue }
            do {
                let data = try JSONEncoder().encode(raw)
                let row = try decoder.decode(SefariaRelationshipLinkDTO.self, from: data)
                if let source = SefariaRelationshipMapper.source(row, knownTitles: knownTitles) {
                    results.append(source)
                }
            } catch {
                print("[Sefaria] links row \(index) for '\(ref)' rejected: \(error)")
            }
        }
        return results
    }


    func topics(for locator: TextLocator) async throws -> [LibraryRelatedTopic] {
        guard locator.backend == .sefaria, case .canonicalRef(let ref) = locator.position else {
            throw LibraryBackendError.invalidLocator
        }
        let url = try configuration.apiURL(
            pathPrefix: "/api/ref-topic-links/",
            pathComponent: ref,
            queryItems: [URLQueryItem(name: "interface_lang", value: "english")]
        )
        let rows = try await client.get([SefariaRelationshipTopicDTO].self, url: url)
        return SefariaRelationshipMapper.topics(rows)
    }

    func invalidateSearchSession() {
        activeSession = nil
        activeSessionKey = nil
    }

    func clearTransientState() {
        knownTitles.removeAll()
        invalidateSearchSession()
    }

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

    private static func mapCatalog(_ entry: SefariaTOCEntryDTO, parentPath: [String]) -> LibraryCatalogNode {
        if let title = entry.title {
            let locator = TextLocator(backend: .sefaria, workKey: title, position: .canonicalRef(title))
            let work = LibraryWork(locator: locator, title: title, heTitle: entry.heTitle,
                categories: parentPath, description: nil)
            return LibraryCatalogNode(id: locator.persistenceKey, kind: .work, title: title,
                heTitle: entry.heTitle, work: work, children: [])
        }
        let title = entry.category ?? ""
        let path = parentPath + [title]
        return LibraryCatalogNode(id: SefariaCatalogIdentity.categoryID(path: path), kind: .category,
            title: title, heTitle: entry.heCategory, work: nil,
            children: entry.contents.map { mapCatalog($0, parentPath: path) })
    }

}
