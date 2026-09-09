import Foundation

func runDecodingTests() throws {
    let decoder = JSONDecoder()
    let genesis = try decoder.decode(SefariaTextsV3DTO.self, from: fixture("texts-genesis.json"))
    let section = SefariaSection(ref: genesis.ref, heRef: genesis.heRef, sectionRef: genesis.sectionRef,
        indexTitle: genesis.indexTitle, next: genesis.next, prev: genesis.prev,
        versions: genesis.versions, linksBySegment: [], origin: .remote).asLibrarySection()
    try expect(section.segments.count == 2, "ordinary text segments")
    try expect(section.segments[0].translation == "In the beginning", "translation pairing")
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
    do {
        _ = try decoder.decode(SefariaTextsV3DTO.self, from: Data("{bad".utf8))
        throw TestFailure.failed("malformed response was accepted")
    } catch is DecodingError {}

    try runReaderRenderModelTests()
    try runSearchContractMappingTests()
    try runNestedOfflineDecodingTests()
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
}

private func runNestedOfflineDecodingTests() throws {
    let nested = Data(#"{
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
    }"#.utf8)
    let metadata = try JSONDecoder().decode(SefariaOfflineMetadataDTO.self, from: nested)
    let flattened = metadata.flattenedSections
    try expect(flattened.map(\.sectionRef) == ["Deep Work 1:1", "Deep Work 1:2"],
        "nested metadata sections are retained")
    try expect(flattened.allSatisfy { $0.containerRef == "Deep Work 1" },
        "nested metadata retains wrapper filename ref")

    let wrappedVersion = try JSONDecoder().decode(SefariaJSONValue.self, from: Data(#"{
      "ref":"Deep Work 1","sections":{"Deep Work 1:1":["א","ב"],"Deep Work 1:2":["ג"]}
    }"#.utf8))
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
