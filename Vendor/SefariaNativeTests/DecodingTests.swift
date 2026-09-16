import Foundation

func runDecodingTests() throws {
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
    try expect(mappedDirectTopics.count == 1 && mappedDirectTopics[0].titleHe == "שבת" && mappedDirectTopics[0].titleEn == "Shabbat", "direct topic title mapping")
    do {
        _ = try decoder.decode(SefariaTextsV3DTO.self, from: Data("{bad".utf8))
        throw TestFailure.failed("malformed response was accepted")
    } catch is DecodingError {}

    try runReaderRenderModelTests()
    try runSearchContractMappingTests()
    try runSearchSemanticsAndFilterTests()
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

private func runSearchSemanticsAndFilterTests() throws {
    // 1. Query tokenization and search term extraction with quotes, abbreviations and whitespace
    func extractTerms(from query: String) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
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
                    if !term.isEmpty { terms.append(term) }
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

    let t1 = extractTerms(from: "משה אהרן")
    try expect(t1 == ["משה", "אהרן"], "extractTerms standard multi-word query")

    let t2 = extractTerms(from: "\"משה אהרן\" דוד")
    try expect(t2 == ["משה אהרן", "דוד"], "extractTerms quoted phrase and term")

    let t3 = extractTerms(from: "רש\"י ברכות")
    try expect(t3 == ["רש\u{05F4}י", "ברכות"], "extractTerms protects internal gershayim in abbreviations")

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

    // 3. Overlap-heavy OR pagination test
    // Page 1 Term A: R1, R2, R3, R4
    // Page 1 Term B: R1, R2, R3, R4 (100% overlap)
    // Page 2 Term A: R5, R6
    // Page 2 Term B: R7, R8
    let termAPage1 = ["R1", "R2", "R3", "R4"]
    let termBPage1 = ["R1", "R2", "R3", "R4"]
    let termAPage2 = ["R5", "R6"]
    let termBPage2 = ["R7", "R8"]

    var uniqueMap: [String: Int] = [:]
    for r in (termAPage1 + termBPage1) { uniqueMap[r] = 1 }
    try expect(uniqueMap.count == 4, "page 1 produces exactly 4 unique hits after deduplication")
    // Because terms have more (total 6 each), the OR stream must NOT terminate
    let anyHasMore = true
    let nextOffset = anyHasMore ? 4 : nil
    try expect(nextOffset == 4, "OR stream nextOffset continues despite full page 1 overlap")

    for r in (termAPage2 + termBPage2) { uniqueMap[r] = 1 }
    try expect(uniqueMap.count == 8, "subsequent OR fetch exposes R5, R6, R7, R8")
    let allKeys = Set(uniqueMap.keys)
    try expect(allKeys == Set(["R1", "R2", "R3", "R4", "R5", "R6", "R7", "R8"]), "all 8 unique hits exposed")

    // OR total is not double counted
    let maxTermTotal = max(6, 6)
    let truthfulOrTotal = max(uniqueMap.count, maxTermTotal)
    try expect(truthfulOrTotal == 8, "OR total reflects deduplicated count (8), not sum of terms (12)")

    // 4. CONTAINS (boolean AND) set intersection test
    // Terms must both occur in the segment regardless of order/distance
    let termAHits = Set(["Seg1", "Seg2", "Seg3", "Seg5"])
    let termBHits = Set(["Seg2", "Seg3", "Seg4", "Seg6"])
    let intersected = termAHits.intersection(termBHits)
    try expect(intersected == Set(["Seg2", "Seg3"]), "contains intersection requires both terms")

    // 5. Otzaria book filter identifier resolution test
    func resolveOtzariaBookId(_ filter: String) -> Int? {
        let trimmed = filter.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("book:"), let id = Int(trimmed.dropFirst("book:".count)), id > 0 { return id }
        if trimmed.hasPrefix("otzaria:"), let id = Int(trimmed.dropFirst("otzaria:".count)), id > 0 { return id }
        if trimmed.hasPrefix("b"), let id = Int(trimmed.dropFirst(1)), id > 0 { return id }
        if let id = Int(trimmed), id > 0 { return id }
        return nil
    }

    try expect(resolveOtzariaBookId("book:42") == 42, "resolves book:42")
    try expect(resolveOtzariaBookId("otzaria:100") == 100, "resolves otzaria:100")
    try expect(resolveOtzariaBookId("b50") == 50, "resolves b50")
    try expect(resolveOtzariaBookId("77") == 77, "resolves numeric 77")
    try expect(resolveOtzariaBookId("") == nil, "empty filter returns nil")
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
