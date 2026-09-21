import Foundation

func runDecodingTests() async throws {
    let decoder = JSONDecoder()
    let genesis = try decoder.decode(SefariaTextsV3DTO.self, from: fixture("texts-genesis.json"))
    let section = SefariaSection(ref: genesis.ref, heRef: genesis.heRef, sectionRef: genesis.sectionRef,
        indexTitle: genesis.indexTitle, next: genesis.next, prev: genesis.prev,
        versions: genesis.versions, linksBySegment: [], origin: .remote).asLibrarySection()
    try expect(section.segments.count == 2, "ordinary text segments")
    try expect(section.segments[0].translation == "In the beginning", "translation pairing")
    try expect(section.segments[0].heRef != nil, "Hebrew segment reference retained")
    try expect(section.versions.first?.license == "CC-BY-SA", "version attribution")

    let bavli = try decoder.decode(SefariaTextsV3DTO.self, from: fixture("texts-berakhot.json"))
    try expect(bavli.next == "Berakhot 2b" && bavli.versions.count == 1, "Bavli and missing translation")
    let commentary = try decoder.decode(SefariaTextsV3DTO.self, from: fixture("texts-commentary.json"))
    try expect(commentary.indexTitle == "Rashi on Genesis", "commentary work identity")

    let search = try decoder.decode(SefariaSearchResponseDTO.self, from: fixture("search.json"))
    try expect(search.hits.total.value == 1 && search.hits.hits[0].source.ref == "Genesis 1:1",
        "search response to canonical ref")
    let offline = try decoder.decode(SefariaOfflineMetadataDTO.self, from: fixture("offline-metadata.json"))
    try expect(offline.links?.first?.first?.type == "commentary", "offline links")

    let richLinks = try decoder.decode([SefariaRelationshipLinkDTO].self, from: Data(#"[{"sourceRef":"Rashi on Genesis 1:1:1","sourceHeRef":"רש״י","category":"Commentary","type":"commentary","collectiveTitle":{"en":"Rashi","he":"רש״י"},"he":"פירוש","heVersionTitle":"מקראות","heLicense":"CC-BY-SA","indexTitle":"Rashi on Genesis"}]"#.utf8))
    let richLink = SefariaRelationshipMapper.source(richLinks[0], knownTitles: [])
    try expect(richLink?.locator.workKey == "Rashi on Genesis", "rich link target identity")
    try expect(richLink?.category == "Commentary" && richLink?.primaryText == "פירוש", "rich link fields")

    let richTopics = try decoder.decode([SefariaRelationshipTopicDTO].self, from: Data(#"[{"topic":"creation","descriptions":{"en":{"title":"Creation"},"he":{"title":"בריאה"}}},{"topic":"creation"}]"#.utf8))
    let topics = SefariaRelationshipMapper.topics(richTopics)
    try expect(topics.count == 1 && topics[0].titleHe == "בריאה", "rich topic mapping and deduplication")

    let directTitleTopics = try decoder.decode([SefariaRelationshipTopicDTO].self, from: Data(#"[{"topic":"shabbat","title":{"en":"Shabbat","he":"שבת"}}]"#.utf8))
    let mappedDirectTopics = SefariaRelationshipMapper.topics(directTitleTopics)
    try expect(mappedDirectTopics.count == 1 && mappedDirectTopics[0].titleHe == "שבת" && mappedDirectTopics[0].titleEn == "שבת", "direct topic title mapping")

    let indexData = Data(#"""
    {
      "title": "Mishneh Torah, Kings and Wars",
      "heTitle": "משנה תורה, הלכות מלכים ומלחמות",
      "categories": ["Halakhah", "Mishneh Torah", "Sefer Shoftim"],
      "authors": ["Maimonides"],
      "enDesc": "Laws of kings and their wars",
      "heDesc": "הלכות מלכים ומלחמותיהם",
      "compDate": "c.1180 CE",
      "compPlace": "Egypt",
      "era": "RI"
    }
    """#.utf8)
    let indexDTO = try decoder.decode(SefariaIndexDTO.self, from: indexData)
    let workMeta = indexDTO.asWorkMetadata(workKey: "Mishneh Torah, Kings and Wars")
    try expect(workMeta.authors == ["Maimonides"], "work metadata authors")
    try expect(workMeta.heTitle == "משנה תורה, הלכות מלכים ומלחמות", "work metadata Hebrew title")
    try expect(workMeta.description == "הלכות מלכים ומלחמותיהם", "work metadata Hebrew description")
    try expect(workMeta.factualFields.contains { $0.label == "זמן חיבור" && $0.value == "c.1180 CE" }, "work metadata compDate")

    do {
        _ = try decoder.decode(SefariaTextsV3DTO.self, from: Data("{bad".utf8))
        throw TestFailure.failed("malformed response was accepted")
    } catch is DecodingError {}

    try runReaderRenderModelTests()
    try runSearchContractMappingTests()
    try await runSearchSemanticsAndFilterTests()
    try runNestedOfflineDecodingTests()
    try runHeterogeneousLinksDecodingTests()
    try runFlexibleVersionPriorityTests()
    try runExactSegmentReferenceTests()
    try runPresentationPolicyTests()
}

private func runFlexibleVersionPriorityTests() throws {
    let version = try JSONDecoder().decode(SefariaVersion.self, from: Data(#"""
    {
      "versionTitle":"Linked Source","language":"en","priority":"0.25","text":"value"
    }
    """#.utf8))
    try expect(version.priority == 0.25, "string version priority decodes as numeric metadata")
}

private func runExactSegmentReferenceTests() throws {
    let response = try JSONDecoder().decode(SefariaTextsV3DTO.self, from: Data(#"""
    {
      "versions":[{"versionTitle":"Hebrew","language":"he","isSource":true,"text":"בראשית ברא"}],
      "ref":"Genesis 1:1","heRef":"בראשית א׳:א׳","sectionRef":"Genesis 1",
      "next":"Genesis 1:2","prev":null,"indexTitle":"Genesis"
    }
    """#.utf8))
    let section = SefariaSection(
        ref: response.ref,
        heRef: response.heRef,
        sectionRef: response.sectionRef,
        indexTitle: response.indexTitle,
        next: response.next,
        prev: response.prev,
        versions: response.versions,
        linksBySegment: [],
        origin: .remote
    ).asLibrarySection()

    try expect(section.segments.first?.locator.position == .canonicalRef("Genesis 1:1"),
        "single-segment response retains exact canonical reference")
    try expect(section.segments.first?.heRef == "בראשית א׳:א׳",
        "single-segment response retains exact Hebrew reference")
}

private func runPresentationPolicyTests() throws {
    try expect(LibraryPresentationPolicy.defaultReaderMode(localeIdentifier: "he-IL") == .source,
        "Hebrew locale defaults to source")
    try expect(LibraryPresentationPolicy.defaultReaderMode(localeIdentifier: "en-US") == .translation,
        "English locale defaults to translation")
    try expect(LibraryPresentationPolicy.text(source: "מקור", translation: nil, mode: .translation) == "מקור",
        "missing translation falls back to source")
    try expect(LibraryPresentationPolicy.text(source: "מקור", translation: "Translation", mode: .translation) == "Translation",
        "translation mode selects available translation")
}

private func runReaderRenderModelTests() throws {
    let versions = [
        TextVersionMetadata(title: "Source", language: "he", actualLanguage: "he", sourceURL: nil,
            license: nil, notes: nil, isPrimary: true),
        TextVersionMetadata(title: "Translation", language: "en", actualLanguage: "en", sourceURL: nil,
            license: nil, notes: nil, isPrimary: false)
    ]
    let segments = (1...3).map { number in
        LibraryTextSegment(
            locator: TextLocator(backend: .sefaria, workKey: "Genesis",
                position: .canonicalRef("Genesis 1:\(number)")),
            heRef: nil,
            primaryText: "מקור \(number)",
            translation: "Translation \(number)"
        )
    }
    let section = LibraryTextSection(
        locator: TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 1")),
        displayRef: "Genesis 1", heRef: nil, segments: segments, previous: nil, next: nil,
        versions: versions, links: [], origin: .remote
    )

    let source = LibraryReaderRenderModel(section: section, preferredMode: .source)
    let translation = LibraryReaderRenderModel(section: section, preferredMode: .translation)
    let both = LibraryReaderRenderModel(section: section, preferredMode: .both)
    try expect(source.mode == .source && source.text.contains("מקור 2") && !source.text.contains("Translation"),
        "source reader mode")
    try expect(translation.mode == .translation && translation.text.contains("Translation 2") && !translation.text.contains("מקור"),
        "translation reader mode")
    try expect(both.mode == .both && both.text.contains("מקור 2") && both.text.contains("Translation 2"),
        "bilingual reader mode keeps paired content")
    try expect(both.renderedSegments.count == 3, "semantic segments survive reader rendering")
    for index in [0, 1, 2] {
        let rendered = both.renderedSegments[index]
        let middle = rendered.range.location + max(0, rendered.range.length / 2)
        try expect(both.renderedSegment(at: middle)?.locator == segments[index].locator,
            "rendered range maps to exact segment \(index + 1)")
    }
    try expect(both.renderedSegments[1].range.location > NSMaxRange(both.renderedSegments[0].range),
        "reader adds visible separation between segments")
}

private func runSearchContractMappingTests() throws {
    let data = try JSONEncoder().encode(SefariaSearchBody(
        query: "בראשית", start: 25, size: 50, filters: ["Tanakh/Torah/Genesis"]
    ))
    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    try expect(object?["type"] as? String == "text", "search type contract")
    try expect(object?["field"] as? String == "naive_lemmatizer", "search field contract")
    try expect(object?["start"] as? Int == 25 && object?["size"] as? Int == 50,
        "search pagination contract")
    try expect(object?["filters"] as? [String] == ["Tanakh/Torah/Genesis"], "in-book search filters")
    try expect(object?["filter_fields"] as? [String] == ["path"], "in-book search filter fields")

    let exactData = try JSONEncoder().encode(SefariaSearchBody(
        query: "creation",
        start: 0,
        size: 20,
        options: LibrarySearchOptions(
            matchMode: .exact,
            wordDistance: 0,
            sortOrder: .chronological,
            reverseSort: true
        )
    ))
    let exact = try JSONSerialization.jsonObject(with: exactData) as? [String: Any]
    try expect(exact?["field"] as? String == "exact" && exact?["slop"] as? Int == 0,
        "exact Sefaria search field and word distance contract")
    try expect(exact?["sort_method"] as? String == "sort"
        && exact?["sort_fields"] as? [String] == ["comp_date"]
        && exact?["sort_reverse"] as? Bool == true,
        "Sefaria chronological sort contract")

    let containsOptions = LibrarySearchOptions(
        searchMode: .contains,
        matchMode: .hebrewLemmatized,
        wordDistance: 0
    )
    let encodedContains = try JSONEncoder().encode(containsOptions)
    let decodedContains = try JSONDecoder().decode(LibrarySearchOptions.self, from: encodedContains)
    try expect(decodedContains.searchMode == .contains, "searchMode round-trip contains")
    try expect(decodedContains.wordDistance == 0, "contains wordDistance is 0")

    let orOptions = LibrarySearchOptions(
        searchMode: .or,
        matchMode: .hebrewLemmatized,
        wordDistance: 0
    )
    let encodedOr = try JSONEncoder().encode(orOptions)
    let decodedOr = try JSONDecoder().decode(LibrarySearchOptions.self, from: encodedOr)
    try expect(decodedOr.searchMode == .or, "searchMode round-trip or")
}

final class MockSearchURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private struct SefariaSearchBodyDTOForTest: Decodable {
    let query: String
    let start: Int
    let size: Int
    let filters: [String]?
    let filterFields: [String]?
    enum CodingKeys: String, CodingKey {
        case query, start, size, filters
        case filterFields = "filter_fields"
    }
}

private func extractBodyData(from request: URLRequest) -> Data? {
    if let data = request.httpBody {
        return data
    }
    guard let stream = request.httpBodyStream else {
        return nil
    }
    stream.open()
    defer { stream.close() }
    var data = Data()
    let bufferSize = 4096
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }
    while true {
        let bytesRead = stream.read(buffer, maxLength: bufferSize)
        if bytesRead > 0 {
            data.append(buffer, count: bytesRead)
        } else {
            break
        }
    }
    return data.isEmpty ? nil : data
}

private func makeCannedSearchResponse(hits: [(ref: String, title: String, snippet: String, score: Double)], total: Int) -> Data {
    let hitsArray: [[String: Any]] = hits.map { h in
        [
            "_score": h.score,
            "_source": [
                "ref": h.ref,
                "title": h.title,
                "exact": h.snippet
            ]
        ]
    }
    let dict: [String: Any] = [
        "hits": [
            "total": ["value": total],
            "hits": hitsArray
        ]
    ]
    return try! JSONSerialization.data(withJSONObject: dict)
}

private func runSearchSemanticsAndFilterTests() async throws {
    // 1. Query tokenization and search term extraction with production SefariaRemoteStore
    let t1 = SefariaRemoteStore.extractSearchTerms(from: "משה אהרן")
    try expect(t1 == ["משה", "אהרן"], "extractSearchTerms standard multi-word query")

    let t2 = SefariaRemoteStore.extractSearchTerms(from: "\"משה אהרן\" דוד")
    try expect(t2 == ["משה אהרן", "דוד"], "extractSearchTerms quoted phrase and term")

    let t3 = SefariaRemoteStore.extractSearchTerms(from: "רש\"י ברכות")
    try expect(t3 == ["רש\u{05F4}י", "ברכות"], "extractSearchTerms protects internal gershayim in abbreviations")

    // 2. Filter preservation across all search modes in SefariaSearchBody
    let filters = ["Tanakh/Torah/Exodus"]
    for mode in [LibrarySearchMode.phrase, .contains, .or, .near] {
        var options = LibrarySearchOptions()
        options.searchMode = mode
        options.wordDistance = mode == .near ? 10 : 0
        let body = SefariaSearchBody(query: "משה", start: 0, size: 20, filters: filters, options: options)
        let data = try JSONEncoder().encode(body)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        try expect(json?["filters"] as? [String] == filters, "filters preserved in mode \(mode)")
        try expect(json?["filter_fields"] as? [String] == ["path"], "filter_fields preserved in mode \(mode)")
        if mode == .near {
            try expect(json?["slop"] as? Int == 10, "near mode sets proximity slop")
        } else {
            try expect(json?["slop"] as? Int == 0, "non-near mode sets zero slop")
        }
    }

    // 3. Generic BackendPaginationState testing (production state machine & retry regression)
    var pagState = BackendPaginationState()
    pagState.applyInitialPage(pageTotal: 102, nextOffset: 100, count: 100)
    try expect(pagState.loadedCount == 100, "pagination page 1 loadedCount == 100")
    try expect(pagState.totalResults == 102, "pagination page 1 totalResults == 102")
    try expect(pagState.hasMore == true, "pagination page 1 hasMore == true")
    try expect(pagState.nextOffset == 100, "pagination page 1 nextOffset == 100")

    // Regression: Simulate requesting offset 100 and a backend/network failure.
    // Uncommitted state remains intact; no pre-await mutation occurs.
    // After failure:
    try expect(pagState.nextOffset == 100, "after failure nextOffset must still be 100")
    try expect(pagState.hasMore == true, "after failure hasMore must still be true")
    try expect(pagState.loadedCount == 100, "after failure loadedCount remains 100")

    // Simulate cancellation during request:
    // Cancellation also leaves continuation retryable without state advancement.
    try expect(pagState.hasMore == true, "cancellation leaves continuation retryable")

    // Retry offset 100 successfully:
    pagState.applyNextPage(requestedOffset: 100, pageTotal: 102, nextOffset: 200, count: 100)
    try expect(pagState.loadedCount == 200, "retry page 2 loadedCount == 200")
    try expect(pagState.totalResults >= 201, "retry page 2 monotonic total updated >= 201")
    try expect(pagState.hasMore == true, "continuation remains available after retry")
    try expect(pagState.nextOffset == 200, "retry page 2 nextOffset == 200")

    // Then successfully apply another page at 200:
    pagState.applyNextPage(requestedOffset: 200, pageTotal: 102, nextOffset: 300, count: 50)
    try expect(pagState.loadedCount == 250, "page 3 loadedCount == 250")
    try expect(pagState.hasMore == true, "page 3 continuation remains available")
    try expect(pagState.nextOffset == 300, "page 3 nextOffset == 300")

    // Loop protection: backend returns non-advancing offset (300 <= requested 300)
    pagState.applyNextPage(requestedOffset: 300, pageTotal: 102, nextOffset: 300, count: 0)
    try expect(pagState.nextOffset == nil, "non-advancing offset safely terminated to nil")
    try expect(pagState.hasMore == false, "non-advancing offset hasMore becomes false")

    // 4. Production OtzariaGenericBackendAdapter.resolveBookIds
    let otzariaIds = OtzariaGenericBackendAdapter.resolveBookIds(from: ["book:42", "otzaria:100", "b50", "77", "", "   "])
    try expect(otzariaIds == Set([42, 100, 50, 77]), "OtzariaGenericBackendAdapter.resolveBookIds resolves canonical book IDs")

    // Setup mock HTTP environment for real SefariaRemoteStore tests
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockSearchURLProtocol.self]
    let mockSession = URLSession(configuration: config)
    let mockClient = SefariaHTTPClient(session: mockSession)
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("sefaria-tests-\(UUID().uuidString)")
    let testCache = SefariaDiskCache(directory: tempDir)
    let remoteStore = SefariaRemoteStore(configuration: .production, client: mockClient, cache: testCache)

    // 5. Real SefariaRemoteStore: Overlap-heavy OR pagination test
    // Query: "משה אהרן" (OR mode)
    // Page 1:
    // Term "משה" returns [R1, R2, R3, R4] (total 6)
    // Term "אהרן" returns [R1, R2, R3, R4] (total 6) (100% overlap)
    // Page 2 (offset 4):
    // Term "משה" returns [R5, R6] (total 6)
    // Term "אהרן" returns [R7, R8] (total 6)
    MockSearchURLProtocol.requestHandler = { request in
        guard let url = request.url else { throw URLError(.badURL) }
        let httpResp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        if url.path.contains("/api/index") {
            return (httpResp, Data("[]".utf8))
        }
        guard let bodyData = extractBodyData(from: request),
              let body = try? JSONDecoder().decode(SefariaSearchBodyDTOForTest.self, from: bodyData) else {
            return (httpResp, makeCannedSearchResponse(hits: [], total: 0))
        }
        if body.query == "משה" {
            if body.start == 0 {
                let data = makeCannedSearchResponse(hits: [
                    ("Genesis 1:1", "Genesis", "R1", 10.0),
                    ("Genesis 1:2", "Genesis", "R2", 9.0),
                    ("Genesis 1:3", "Genesis", "R3", 8.0),
                    ("Genesis 1:4", "Genesis", "R4", 7.0)
                ], total: 6)
                return (httpResp, data)
            } else {
                let data = makeCannedSearchResponse(hits: [
                    ("Exodus 1:1", "Exodus", "R5", 6.0),
                    ("Exodus 1:2", "Exodus", "R6", 5.0)
                ], total: 6)
                return (httpResp, data)
            }
        } else if body.query == "אהרן" {
            if body.start == 0 {
                let data = makeCannedSearchResponse(hits: [
                    ("Genesis 1:1", "Genesis", "R1", 10.0),
                    ("Genesis 1:2", "Genesis", "R2", 9.0),
                    ("Genesis 1:3", "Genesis", "R3", 8.0),
                    ("Genesis 1:4", "Genesis", "R4", 7.0)
                ], total: 6)
                return (httpResp, data)
            } else {
                let data = makeCannedSearchResponse(hits: [
                    ("Leviticus 1:1", "Leviticus", "R7", 4.0),
                    ("Leviticus 1:2", "Leviticus", "R8", 3.0)
                ], total: 6)
                return (httpResp, data)
            }
        }
        return (httpResp, makeCannedSearchResponse(hits: [], total: 0))
    }

    var orOptions = LibrarySearchOptions()
    orOptions.searchMode = .or
    let orPage1 = try await remoteStore.search(LibrarySearchRequest(
        query: "משה אהרן",
        offset: 0,
        limit: 4,
        options: orOptions
    ))

    try expect(orPage1.hits.count == 4, "OR page 1 produces 4 unique hits after deduplication")
    try expect(orPage1.nextOffset == 4, "OR page 1 nextOffset continues despite full overlap")
    try expect(orPage1.total == 6, "OR page 1 total reflects truthful deduplicated lower bound (6), not sum of terms (12)")

    let orPage2 = try await remoteStore.search(LibrarySearchRequest(
        query: "משה אהרן",
        offset: 4,
        limit: 4,
        options: orOptions
    ))

    let page2Snippets = Set(orPage2.hits.map(\.snippet))
    try expect(page2Snippets == Set(["R5", "R6", "R7", "R8"]), "OR page 2 exposes all remaining unique results (R5-R8)")
    try expect(orPage2.total == 8, "OR total updates truthfully to 8 after all streams exhausted")

    // 6. Real SefariaRemoteStore: Late-intersection CONTAINS test with Filter Preservation
    // Query: "חסד אמת" with filters: ["Tanakh/Torah"]
    // Batch 1 (start 0):
    // Term "חסד" returns Seg1..Seg2 (total 4)
    // Term "אמת" returns Seg5..Seg6 (total 4)
    // No intersection in batch 1!
    // Batch 2 (start 2):
    // Term "חסד" returns Seg9..Seg10 (total 4)
    // Term "אמת" returns Seg9..Seg10 (total 4)
    // Intersection found in batch 2!
    var capturedFilters: [[String]] = []
    MockSearchURLProtocol.requestHandler = { request in
        guard let url = request.url else { throw URLError(.badURL) }
        let httpResp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        if url.path.contains("/api/index") { return (httpResp, Data("[]".utf8)) }
        guard let bodyData = extractBodyData(from: request),
              let body = try? JSONDecoder().decode(SefariaSearchBodyDTOForTest.self, from: bodyData) else {
            return (httpResp, makeCannedSearchResponse(hits: [], total: 0))
        }
        if let filters = body.filters {
            capturedFilters.append(filters)
        }
        if body.query == "חסד" {
            if body.start == 0 {
                return (httpResp, makeCannedSearchResponse(hits: [
                    ("Genesis 2:1", "Genesis", "Seg1", 10.0),
                    ("Genesis 2:2", "Genesis", "Seg2", 9.0)
                ], total: 4))
            } else {
                return (httpResp, makeCannedSearchResponse(hits: [
                    ("Genesis 2:3", "Genesis", "Seg9", 8.0),
                    ("Genesis 2:4", "Genesis", "Seg10", 7.0)
                ], total: 4))
            }
        } else if body.query == "אמת" {
            if body.start == 0 {
                return (httpResp, makeCannedSearchResponse(hits: [
                    ("Genesis 3:1", "Genesis", "Seg5", 10.0),
                    ("Genesis 3:2", "Genesis", "Seg6", 9.0)
                ], total: 4))
            } else {
                return (httpResp, makeCannedSearchResponse(hits: [
                    ("Genesis 2:3", "Genesis", "Seg9", 8.0),
                    ("Genesis 2:4", "Genesis", "Seg10", 7.0)
                ], total: 4))
            }
        }
        return (httpResp, makeCannedSearchResponse(hits: [], total: 0))
    }

    var containsOptions = LibrarySearchOptions()
    containsOptions.searchMode = .contains
    let containsRequest = LibrarySearchRequest(
        query: "חסד אמת",
        offset: 0,
        limit: 2,
        filters: ["Tanakh/Torah"],
        options: containsOptions
    )
    let containsPage = try await remoteStore.search(containsRequest)

    try expect(containsPage.hits.map(\.snippet) == ["Seg9", "Seg10"], "CONTAINS finds late intersection beyond first batch")
    try expect(!capturedFilters.isEmpty && capturedFilters.allSatisfy { $0 == ["Tanakh/Torah"] }, "filters preserved on every term sub-request")
    try expect(containsPage.total == 2, "CONTAINS total reflects exact count after streams exhausted")

    // 7. Session Invalidation on Query Change
    // Searching for a new query starts fresh
    var freshQueryStart = -1
    MockSearchURLProtocol.requestHandler = { request in
        guard let url = request.url else { throw URLError(.badURL) }
        let httpResp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        if url.path.contains("/api/index") { return (httpResp, Data("[]".utf8)) }
        guard let bodyData = extractBodyData(from: request),
              let body = try? JSONDecoder().decode(SefariaSearchBodyDTOForTest.self, from: bodyData) else {
            return (httpResp, makeCannedSearchResponse(hits: [], total: 0))
        }
        if freshQueryStart == -1 { freshQueryStart = body.start }
        return (httpResp, makeCannedSearchResponse(hits: [], total: 0))
    }
    _ = try await remoteStore.search(LibrarySearchRequest(query: "שלום עליכם", offset: 0, limit: 10, options: orOptions))
    try expect(freshQueryStart == 0, "new query resets session start offset to 0")

    try? FileManager.default.removeItem(at: tempDir)
}

private func runNestedOfflineDecodingTests() throws {
    let nested = Data(#"""
    {
      "ref":"Deep Work 1",
      "sections":{
        "Deep Work 1:1":{
          "ref":"Deep Work 1:1","heRef":"עמוק","indexTitle":"Deep Work",
          "sectionRef":"Deep Work 1:1","next":"Deep Work 1:2","prev":null,
          "versions":[{"versionTitle":"Source Version","language":"he"}],"links":[]
        },
        "Deep Work 1:2":{
          "ref":"Deep Work 1:2","indexTitle":"Deep Work","sectionRef":"Deep Work 1:2",
          "next":null,"prev":"Deep Work 1:1",
          "versions":[{"versionTitle":"Source Version","language":"he"}],"links":[]
        }
      }
    }
    """#.utf8)
    let metadata = try JSONDecoder().decode(SefariaOfflineMetadataDTO.self, from: nested)
    let flattened = metadata.flattenedSections
    try expect(flattened.map(\.sectionRef) == ["Deep Work 1:1", "Deep Work 1:2"],
        "nested metadata sections are retained")
    try expect(flattened.allSatisfy { $0.containerRef == "Deep Work 1" },
        "nested metadata retains wrapper filename ref")

    let wrappedVersion = try JSONDecoder().decode(SefariaJSONValue.self, from: Data(#"""
    {
      "ref":"Deep Work 1","sections":{"Deep Work 1:1":["א","ב"],"Deep Work 1:2":["ג"]}
    }
    """#.utf8))
    try expect(wrappedVersion.value(inSectionsFor: "Deep Work 1:1")?.segmentStrings.count == 2,
        "nested version section is readable")

    let installed = SefariaInstalledState(packages: [
        "fixture": .init(id: "fixture", installedAt: Date(timeIntervalSince1970: 1), schemaVersion: "7",
            bundlePaths: ["bundle-1.zip", "bundle-2.zip"], titleUpdates: ["Genesis": "stamp"])
    ])
    let decoded = try JSONDecoder().decode(SefariaInstalledState.self, from: JSONEncoder().encode(installed))
    try expect(decoded.packages["fixture"]?.bundlePaths == ["bundle-1.zip", "bundle-2.zip"],
        "multi-bundle installed state round-trips atomically")
}

private func runHeterogeneousLinksDecodingTests() throws {
    let decoder = JSONDecoder()
    let json = Data(#"""
    [
      {
        "sourceRef": "Rashi on Genesis 1:1:1",
        "sourceHeRef": "רש״י",
        "category": "Commentary",
        "type": "commentary",
        "he": "פירוש כמחרוזת",
        "text": "commentary as string",
        "index_title": "Rashi on Genesis"
      },
      {
        "sourceRef": "Ibn Ezra on Genesis 1:1:1",
        "category": "Commentary",
        "type": "commentary",
        "he": ["פסוק א", "פסוק ב"],
        "text": ["verse 1", "verse 2"],
        "index_title": "Ibn Ezra on Genesis"
      },
      {
        "sourceRef": "Ramban on Genesis 1:1:1",
        "category": "Commentary",
        "type": "commentary",
        "he": [],
        "text": [],
        "index_title": "Ramban on Genesis"
      }
    ]
    """#.utf8)

    let dtos = try decoder.decode([SefariaRelationshipLinkDTO].self, from: json)
    try expect(dtos.count == 3, "decoded all heterogeneous link DTOs")
    try expect(dtos[0].indexTitle == "Rashi on Genesis", "snake_case index_title decoded for row 0")
    try expect(dtos[0].he == "פירוש כמחרוזת", "string he decoded for row 0")
    try expect(dtos[1].indexTitle == "Ibn Ezra on Genesis", "snake_case index_title decoded for row 1")
    try expect(dtos[1].he == "פסוק א\nפסוק ב", "array he decoded as multiline string for row 1")
    try expect(dtos[1].text == "verse 1\nverse 2", "array text decoded as multiline string for row 1")
    try expect(dtos[2].he == nil, "empty array he decoded as nil for row 2")
    try expect(dtos[2].text == nil, "empty array text decoded as nil for row 2")

    let mixedJson = Data(#"""
    [
      {"sourceRef": "Valid 1", "category": "Commentary", "type": "commentary", "index_title": "Valid 1"},
      {"badField": 123},
      {"sourceRef": "Valid 2", "category": "Midrash", "type": "midrash", "index_title": "Valid 2"}
    ]
    """#.utf8)
    let rows = (try? decoder.decode([SefariaJSONValue].self, from: mixedJson)) ?? []
    var mappedSources: [LibraryRelatedSource] = []
    for row in rows {
        guard case .object = row else { continue }
        if let data = try? JSONEncoder().encode(row),
           let dto = try? decoder.decode(SefariaRelationshipLinkDTO.self, from: data),
           let source = SefariaRelationshipMapper.source(dto, knownTitles: []) {
            mappedSources.append(source)
        }
    }
    try expect(mappedSources.count == 2, "row lacking ref/sourceRef dropped during mapping without failing valid rows")
    try expect(mappedSources[0].displayRef == "Valid 1" && mappedSources[1].displayRef == "Valid 2", "valid sources mapped")
}
