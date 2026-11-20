import Foundation

private actor FixtureHybridNavigation: LibraryNavigationProviding, LibraryWorkMetadataProviding {
    let items: [LibraryNavigationItem]
    let fails: Bool

    init(items: [LibraryNavigationItem], fails: Bool = false) {
        self.items = items
        self.fails = fails
    }

    func normalizedLocator(for input: String) throws -> TextLocator {
        if fails { throw LibraryBackendError.unavailableOffline }
        return items.first?.locator ?? TextLocator(backend: .sefaria, workKey: input, position: .canonicalRef(input))
    }

    func tableOfContents(for work: LibraryWork) throws -> [LibraryTOCNode] {
        if fails { throw LibraryBackendError.unavailableOffline }
        return items.map { LibraryTOCNode(locator: $0.locator, title: $0.title, children: []) }
    }

    func navigationItems(for work: LibraryWork) throws -> [LibraryNavigationItem] {
        if fails { throw LibraryBackendError.unavailableOffline }
        return items
    }

    func workMetadata(for workKey: String) throws -> LibraryWorkMetadata? {
        if fails { throw LibraryBackendError.unavailableOffline }
        return LibraryWorkMetadata(workKey: workKey, title: workKey)
    }
}

func runNavigationAndPackageTests() async throws {
    for check in try sefariaNavigationLanguageChecks() {
        try expect(check.passed, "navigation language \(check.name): expected \(check.expected), got \(check.actual)")
    }
    let firstRepeatedLeaf = SefariaCatalogIdentity.categoryID(path: ["Tanakh", "Commentary"])
    let secondRepeatedLeaf = SefariaCatalogIdentity.categoryID(path: ["Talmud", "Commentary"])
    try expect(firstRepeatedLeaf != secondRepeatedLeaf, "category identity includes full path")
    try expect(firstRepeatedLeaf == SefariaCatalogIdentity.categoryID(path: ["Tanakh", "Commentary"]),
        "category identity is deterministic")
    try expect(
        SefariaCatalogIdentity.searchPath(
            parentPath: ["Tanakh", "Commentary", "Rashi", "Torah"],
            title: "Rashi on Genesis"
        ) == "Tanakh/Commentary/Rashi/Torah/Rashi on Genesis",
        "catalog search path retains the exact backend hierarchy"
    )

    let repeatedLocator = TextLocator(
        backend: .sefaria,
        workKey: "Repeated Work",
        position: .canonicalRef("Repeated Work")
    )
    let repeatedWork = LibraryWork(
        locator: repeatedLocator,
        title: "Repeated Work",
        heTitle: "ספר חוזר",
        categories: [],
        description: nil
    )
    let repeatedLeaf = LibraryCatalogNode(
        id: repeatedLocator.persistenceKey,
        kind: .work,
        title: repeatedWork.title,
        heTitle: repeatedWork.heTitle,
        work: repeatedWork,
        children: []
    )
    let auditTree = [
        LibraryCatalogNode(id: "colliding-category", kind: .category, title: "First", heTitle: nil,
            work: nil, children: [repeatedLeaf]),
        LibraryCatalogNode(id: "colliding-category", kind: .category, title: "Second", heTitle: nil,
            work: nil, children: [repeatedLeaf]),
    ]
    let collisions = LibraryCatalogIntegrityAudit.collisions(in: auditTree)
    try expect(collisions.count == 2, "catalog audit exposes category and work identity collisions")
    try expect(collisions.first(where: { $0.kind == .workLocator })?.paths == [["First"], ["Second"]],
        "catalog audit retains every display path for a repeated canonical work")
    let index = try JSONDecoder().decode(SefariaIndexDTO.self, from: fixture("index-complex.json"))
    let nodes = SefariaNavigationParser.nodes(schema: index.schema, indexTitle: index.title, baseRef: index.title, prefersHebrew: true)
    try expect(nodes.count == 2, "complex root nodes")
    try expect(nodes[0].title == "קדש", "Hebrew display title")
    try expect(nodes[0].locator.position == .canonicalRef("Pesach Haggadah, Kadesh"), "English schema key in ref")
    try expect(nodes[1].children.first?.locator.position == .canonicalRef("Pesach Haggadah, Magid, The Four Sons"),
        "nested complex ref")
    let ordinary: SefariaJSONValue = .object([
        "content_counts": .array([.number(2)]),
        "addressTypes": .array([.string("Integer")])
    ])
    let chapters = SefariaNavigationParser.nodes(schema: ordinary, indexTitle: "Genesis", baseRef: "Genesis")
    try expect(chapters.map(\.title) == ["1", "2"], "ordinary content_counts navigation")
    let bavli: SefariaJSONValue = .object([
        "lengths": .array([.number(2)]),
        "addressTypes": .array([.string("Talmud")])
    ])
    let dapim = SefariaNavigationParser.nodes(schema: bavli, indexTitle: "Berakhot", baseRef: "Berakhot")
    try expect(dapim.map(\.title) == ["2a", "2b"], "Bavli daf/amud navigation")

    let ordinaryItems = chapters.enumerated().map {
        LibraryNavigationItem(locator: $0.element.locator, title: $0.element.title, index: $0.offset)
    }
    let genesisRoot = TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis"))
    let resolvedGenesisRoot = try LibraryReadingUnitPolicy.resolve(genesisRoot, navigationItems: ordinaryItems)
    try expect(resolvedGenesisRoot.position == .canonicalRef("Genesis 1"),
        "ordinary work root resolves to the first bounded chapter")
    try expect(LibraryReadingUnitPolicy.requiresBoundedResolution(genesisRoot, hasExplicitLocator: false),
        "an implicit work root requires bounded-unit resolution")
    let explicitOtzariaLineZero = TextLocator(
        backend: .otzaria,
        workKey: "book:1",
        position: .legacyLine(0)
    )
    try expect(
        !LibraryReadingUnitPolicy.requiresBoundedResolution(explicitOtzariaLineZero, hasExplicitLocator: true),
        "an explicit Otzaria line-zero search result remains the exact reader target"
    )
    let savedGenesis = TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 2"))
    let restoredGenesis = LibraryReadingUnitPolicy.preferringRecent(genesisRoot, recentLocator: savedGenesis)
    let resolvedSavedGenesis = try LibraryReadingUnitPolicy.resolve(restoredGenesis, navigationItems: ordinaryItems)
    try expect(resolvedSavedGenesis == savedGenesis,
        "a saved recent section beats the first-section fallback")

    let complexItems = [LibraryNavigationItem(locator: nodes[0].locator, title: nodes[0].title, index: 0)]
    let complexRoot = TextLocator(backend: .sefaria, workKey: "Pesach Haggadah",
        position: .canonicalRef("Pesach Haggadah"))
    let resolvedComplexRoot = try LibraryReadingUnitPolicy.resolve(complexRoot, navigationItems: complexItems)
    try expect(resolvedComplexRoot.position == .canonicalRef("Pesach Haggadah, Kadesh"),
        "complex work root resolves to its first bounded node")

    let bavliItems = dapim.enumerated().map {
        LibraryNavigationItem(locator: $0.element.locator, title: $0.element.title, index: $0.offset)
    }
    let bavliRoot = TextLocator(backend: .sefaria, workKey: "Berakhot", position: .canonicalRef("Berakhot"))
    let resolvedBavliRoot = try LibraryReadingUnitPolicy.resolve(bavliRoot, navigationItems: bavliItems)
    try expect(resolvedBavliRoot.position == .canonicalRef("Berakhot 2a"), "Bavli root resolves to daf 2a")

    let localProvider = FixtureHybridNavigation(items: ordinaryItems)
    let unavailableRemote = FixtureHybridNavigation(items: [], fails: true)
    let hybridNavigation = SefariaHybridNavigationStore(
        isInstalled: { $0 == "Genesis" },
        local: localProvider,
        remote: unavailableRemote
    )
    let offlineItems = try await hybridNavigation.navigationItems(for: LibraryWork(
        locator: genesisRoot, title: "Genesis", heTitle: nil, categories: [], description: nil
    ))
    try expect(offlineItems == ordinaryItems,
        "hybrid navigation serves local metadata when the remote provider is unavailable")

    let deepShape = SefariaShapeDTO(isComplex: false, heTitle: nil, title: "Deep Work", length: nil,
        chapters: .array([
            .array([.number(2), .number(1)]),
            .array([.number(1)])
        ]))
    let deepSchema: SefariaJSONValue = .object([
        "addressTypes": .array([.string("Integer"), .string("Integer"), .string("Integer")])
    ])
    let deep = SefariaNavigationParser.nodes(shapes: [deepShape], schema: deepSchema, indexTitle: "Deep Work")
    try expect(deep[0].locator.position == .canonicalRef("Deep Work 1"), "depth-one ref")
    try expect(deep[0].children[0].locator.position == .canonicalRef("Deep Work 1:1"), "depth-two ref")
    try expect(deep[0].children.map(\.title) == ["1", "2"], "depth-three shape")

    let liveComplexShape = try JSONDecoder().decode([SefariaShapeDTO].self, from: Data(#"[{"isComplex":true,"section":"Haggadah","book":"Pesach Haggadah","chapters":[{"heTitle":"קדש","title":"Pesach Haggadah, Kadesh","chapters":2}]}]"#.utf8))
    try expect(liveComplexShape.first?.title == "Pesach Haggadah", "complex shape accepts book as root title")
    let liveComplexNodes = SefariaNavigationParser.nodes(shapes: liveComplexShape, schema: deepSchema,
        indexTitle: "Pesach Haggadah", prefersHebrew: true)
    try expect(liveComplexNodes.first?.children.first?.locator.position == .canonicalRef("Pesach Haggadah, Kadesh"),
        "complex shape uses exact child ref")
    try expect(liveComplexNodes.first?.children.first?.title == "קדש", "complex shape uses Hebrew child title")

    let schemaWithDefault: SefariaJSONValue = .object(["nodes": .array([
        .object(["key": .string("default"), "default": .bool(true), "lengths": .array([.number(2)]),
            "addressTypes": .array([.string("Integer")])]),
        .object(["key": .string("Appendix"), "wholeRef": .string("Complex Work, Appendix")])
    ])])
    let defaultNodes = SefariaNavigationParser.nodes(schema: schemaWithDefault,
        indexTitle: "Complex Work", baseRef: "Complex Work")
    try expect(defaultNodes[0].locator.position == .canonicalRef("Complex Work"), "default node keeps base ref")
    try expect(defaultNodes[1].locator.position == .canonicalRef("Complex Work, Appendix"), "wholeRef node")

    let alternatives: [String: SefariaJSONValue] = ["Parasha": .object(["nodes": .array([
        .object(["nodeType": .string("ArrayMapNode"), "wholeRef": .string("Genesis 1:1-6:8"),
            "titles": .array([.object(["lang": .string("en"), "primary": .bool(true), "text": .string("Bereshit")])])]),
        .object(["nodeType": .string("ArrayMapNode"), "refs": .array([.string("Genesis 6:9-11:32")]),
            "key": .string("Noach")])
    ])])]
    let structures = SefariaNavigationParser.structures(schema: ordinary,
        alternateStructures: alternatives, indexTitle: "Genesis", baseRef: "Genesis")
    try expect(structures.count == 2, "structures separated into primary and alternate")
    try expect(structures[0].id == "primary", "primary structure ID")
    try expect(structures[1].id == "Parasha", "alternate structure ID")
    let altNodes = structures[1].nodes
    try expect(altNodes.contains { $0.locator.position == .canonicalRef("Genesis 1:1-6:8") },
        "alternate wholeRef navigation")
    try expect(altNodes.contains { $0.locator.position == .canonicalRef("Genesis 6:9-11:32") },
        "alternate refs navigation")
    let primaryOnly = SefariaNavigationParser.nodes(schema: ordinary,
        alternateStructures: alternatives, indexTitle: "Genesis", baseRef: "Genesis")
    try expect(!primaryOnly.contains { $0.locator.position == .canonicalRef("Genesis 1:1-6:8") },
        "nodes does not contaminate primary structure with alternate structures")

    let exportedIndexData = Data(#"""
    {
      "title":"Genesis",
      "schema":{"content_counts":[2],"addressTypes":["Integer"]},
      "alts":{"Parasha":{"nodes":[
        {"nodeType":"ArrayMapNode","wholeRef":"Genesis 1:1-6:8","key":"Bereshit","addressTypes":["Aliyah"],"refs":["Genesis 1:1-2:3","Genesis 2:4-3:21"]},
        {"nodeType":"ArrayMapNode","refs":["Genesis 6:9-11:32"],"key":"Noach"}
      ]}}
    }
    """#.utf8)
    let liveIndexData = Data(#"""
    {
      "title":"Genesis",
      "schema":{"content_counts":[2],"addressTypes":["Integer"]},
      "alt_structs":{"Parasha":{"nodes":[
        {"nodeType":"ArrayMapNode","wholeRef":"Genesis 1:1-6:8","key":"Bereshit","addressTypes":["Aliyah"],"refs":["Genesis 1:1-2:3","Genesis 2:4-3:21"]},
        {"nodeType":"ArrayMapNode","refs":["Genesis 6:9-11:32"],"key":"Noach"}
      ]}}
    }
    """#.utf8)
    let exportedIndex = try JSONDecoder().decode(SefariaOfflineIndexDTO.self, from: exportedIndexData)
    let liveIndex = try JSONDecoder().decode(SefariaIndexDTO.self, from: liveIndexData)
    try expect(exportedIndex.alternateStructures == liveIndex.alternateStructures,
        "offline export alts decodes with parity to live alt_structs")
    let exportedStructures = SefariaNavigationParser.structures(
        schema: exportedIndex.schema,
        alternateStructures: exportedIndex.alternateStructures,
        indexTitle: exportedIndex.title,
        baseRef: exportedIndex.title
    )
    let liveStructures = SefariaNavigationParser.structures(
        schema: liveIndex.schema,
        alternateStructures: liveIndex.alternateStructures,
        indexTitle: liveIndex.title,
        baseRef: liveIndex.title
    )
    try expect(exportedStructures.map(\.id) == liveStructures.map(\.id),
        "offline and online navigation expose the same structures")
    try expect(exportedStructures[1].nodes.map(\.locator) == liveStructures[1].nodes.map(\.locator),
        "offline and online alternate structures expose the same locators")
    try expect(exportedStructures[1].nodes.first?.children.map(\.locator) == [
        TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 1:1-2:3")),
        TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 2:4-3:21"))
    ], "offline Parasha structure retains Aliyah child references")
    let legacyOfflineIndex = try JSONDecoder().decode(
        SefariaOfflineIndexDTO.self,
        from: Data(#"{"title":"Genesis","schema":{"content_counts":[1]}}"#.utf8)
    )
    try expect(legacyOfflineIndex.alternateStructures == nil && legacyOfflineIndex.versions.isEmpty,
        "older offline index metadata remains decodable without alternate structures")

    let metadataCandidates = try JSONDecoder().decode(
        [SefariaOfflineMetadataDTO].self,
        from: Data(#"""
        [
          {"ref":"Genesis 1","sectionRef":"Genesis 1","indexTitle":"Genesis"},
          {"ref":"Genesis 10","sectionRef":"Genesis 10","indexTitle":"Genesis"},
          {"ref":"Rashi on Genesis 1:1","sectionRef":"Rashi on Genesis 1:1","indexTitle":"Rashi on Genesis"}
        ]
        """#.utf8)
    )
    try expect(
        SefariaOfflineMetadataResolver.metadata(for: "Genesis 1:2", in: metadataCandidates)?.sectionRef
            == "Genesis 1",
        "offline metadata resolves a segment to its exact section"
    )
    try expect(
        SefariaOfflineMetadataResolver.metadata(for: "Genesis 10:2", in: metadataCandidates)?.sectionRef
            == "Genesis 10",
        "offline metadata does not confuse Genesis 1 with Genesis 10"
    )
    try expect(
        SefariaOfflineMetadataResolver.metadata(for: "Genesis 1:1-6:8", in: metadataCandidates)?.sectionRef
            == "Genesis 1",
        "offline alternate-structure ranges resolve to their first local section"
    )
    try expect(
        SefariaOfflineMetadataResolver.metadata(
            for: "Rashi on Genesis 1:1:3",
            in: metadataCandidates
        )?.sectionRef == "Rashi on Genesis 1:1",
        "offline metadata resolves multi-level commentary references"
    )
    try expect(!SefariaRef.sectionMatches("Genesis 1", "Genesis 10"),
        "section matching observes address boundaries")

    let offlineLinksFixture = try JSONDecoder().decode(
        SefariaOfflineMetadataDTO.self,
        from: fixture("offline-metadata.json")
    )
    let offlineSources = SefariaOfflineRelationshipMapper.sources(
        linksBySegment: offlineLinksFixture.links ?? [],
        requestedRef: "Genesis 1:1",
        sectionRef: "Genesis 1",
        knownTitles: ["Genesis", "Rashi on Genesis"]
    )
    try expect(offlineSources.count == 1, "offline metadata supplies inspector relationships")
    try expect(
        offlineSources.first?.locator == TextLocator(
            backend: .sefaria,
            workKey: "Rashi on Genesis",
            position: .canonicalRef("Rashi on Genesis 1:1:1")
        ),
        "offline inspector relationship preserves its exact linked locator"
    )
    try expect(metadataCandidates.first?.links == nil,
        "offline metadata without exported links remains distinguishable for remote fallback")
    try expect(SefariaOfflineRelationshipMapper.sources(
        linksBySegment: [],
        requestedRef: "Genesis 1:1",
        sectionRef: "Genesis 1",
        knownTitles: ["Genesis"]
    ).isEmpty, "missing offline relationship data is empty rather than a corrupt-text failure")
    let hebrewChapters = SefariaNavigationParser.nodes(schema: ordinary, indexTitle: "Genesis", baseRef: "Genesis", prefersHebrew: true)
    try expect(hebrewChapters.map(\.title) == ["פרק א׳", "פרק ב׳"], "Hebrew chapter titles")

    let offsetSchema: SefariaJSONValue = .object([
        "lengths": .array([.number(2)]), "addressTypes": .array([.string("Integer")]),
        "startingAddress": .string("3")
    ])
    let offsetNodes = SefariaNavigationParser.nodes(schema: offsetSchema,
        indexTitle: "Offset Work", baseRef: "Offset Work")
    try expect(offsetNodes.map(\.title) == ["3", "4"], "startingAddress offset navigation")

    let dictionary: SefariaJSONValue = .object(["nodes": .array([
        .object(["nodeType": .string("DictionaryNode"), "default": .bool(true),
            "headwordMap": .array([
                .array([.string("א"), .string("Jastrow, א")]),
                .array([.string("ב"), .string("Jastrow, ב")])
            ])])
    ])])
    let dictionaryNodes = SefariaNavigationParser.nodes(schema: dictionary,
        indexTitle: "Jastrow", baseRef: "Jastrow")
    try expect(dictionaryNodes.first?.children.map(\.title) == ["א", "ב"],
        "DictionaryNode headword navigation")

    let packages = try JSONDecoder().decode([SefariaPackageManifestEntry].self, from: fixture("packages.json"))
        .map(\.package)
    let parentWins = SefariaPackagePolicy.resolve(["TANAKH and all commentaries", "TANAKH with Rashi"], from: packages)
    try expect(parentWins.map(\.id) == ["TANAKH and all commentaries"], "parent package supersedes child")
    let completeWins = SefariaPackagePolicy.resolve(["COMPLETE LIBRARY", "TANAKH with Rashi"], from: packages)
    try expect(completeWins.count == 1 && completeWins[0].isCompleteLibrary, "complete library supersedes packages")
    try SefariaExportContract.validate(schema: "7")
    do {
        try SefariaExportContract.validate(schema: "999")
        throw TestFailure.failed("unsupported schema was accepted")
    } catch LibraryBackendError.unsupportedSchema {}

    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let target = directory.appendingPathComponent("installed")
    let staged = directory.appendingPathComponent("staged")
    try Data("old".utf8).write(to: target)
    try Data("new".utf8).write(to: staged)
    try SefariaFileTransaction.atomicReplace(staged, target: target)
    let replacedData = try Data(contentsOf: target)
    try expect(replacedData == Data("new".utf8), "atomic replacement")
    let interrupted = directory.appendingPathComponent("interrupted")
    try Data("partial".utf8).write(to: interrupted)
    let preservedData = try Data(contentsOf: target)
    try expect(preservedData == Data("new".utf8), "staging cannot corrupt known-good target")

    // Bug C regression test: Entity decoding in readerPlainText
    let sampleWithEntities = "שלום&thinsp;עליכם&#8201;ורחמים&nbsp;&quot;ספר&quot;&ensp;&emsp;חדש"
    let decoded = sampleWithEntities.readerPlainText
    try expect(decoded.contains("\u{2009}"), "thinsp is converted to Unicode thin space U+2009")
    try expect(!decoded.contains("&thinsp;"), "literal &thinsp; entity is not present")
    try expect(!decoded.contains("&#8201;"), "literal numeric &#8201; entity is not present")
    try expect(decoded.contains("\u{2002}"), "ensp is converted to Unicode en space U+2002")
    try expect(decoded.contains("\u{2003}"), "emsp is converted to Unicode em space U+2003")
    try expect(decoded.contains("\"ספר\""), "quot is decoded to double quotes")
    try expect(
        "פסוק{p}פתוחה{s}סתומה".readerPlainText == "פסוק\nפתוחה\nסתומה",
        "Latin Sefaria paragraph markers become plain-text line breaks"
    )
    try expect(
        "פסוק{פ}פתוחה{ס}סתומה".readerPlainText == "פסוק\nפתוחה\nסתומה",
        "Hebrew Sefaria paragraph markers become plain-text line breaks"
    )

    // Bug A regression test: Leaf navigation items from TOC
    let sampleTOC = [
        LibraryTOCNode(
            locator: TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 1")),
            title: "Chapter 1",
            children: [
                LibraryTOCNode(
                    locator: TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 1:1-5")),
                    title: "Section 1",
                    children: []
                ),
                LibraryTOCNode(
                    locator: TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 1:6-10")),
                    title: "Section 2",
                    children: []
                )
            ]
        ),
        LibraryTOCNode(
            locator: TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 2")),
            title: "Chapter 2",
            children: []
        )
    ]
    var leafItems: [LibraryNavigationItem] = []
    func collectLeaves(_ nodes: [LibraryTOCNode]) {
        for node in nodes {
            if node.children.isEmpty {
                leafItems.append(LibraryNavigationItem(locator: node.locator, title: node.title, index: leafItems.count))
            } else {
                collectLeaves(node.children)
            }
        }
    }
    collectLeaves(sampleTOC)
    try expect(leafItems.count == 3, "correct count of leaf navigation items")
    try expect(leafItems[0].title == "Section 1", "first leaf title")
    try expect(leafItems[1].title == "Section 2", "second leaf title")
    try expect(leafItems[2].title == "Chapter 2", "third leaf title (flat node)")
    try expect(leafItems.map(\.index) == [0, 1, 2], "sequential indices")

    // Bug F regression test: Section with ref == sectionRef and count == 1 generates segment ref with offset
    let singleCommentarySection = SefariaSection(
        ref: "Rashbam on Genesis 1:1",
        heRef: "רשב\"ם על בראשית א׳:א׳",
        sectionRef: "Rashbam on Genesis 1:1",
        indexTitle: "Rashbam on Genesis",
        next: nil,
        prev: nil,
        versions: [
            SefariaVersion(
                versionTitle: "Rashbam",
                language: "he",
                actualLanguage: "he",
                versionSource: nil,
                license: nil,
                versionNotes: nil,
                priority: nil,
                isPrimary: true,
                isSource: true,
                direction: "rtl",
                text: .array([.string("בשלמא")])
            )
        ],
        linksBySegment: [[]],
        origin: .remote
    )
    let mappedSection = singleCommentarySection.asLibrarySection()
    try expect(mappedSection.segments.count == 1, "one segment in section")
    try expect(mappedSection.segments[0].locator == TextLocator(backend: .sefaria, workKey: "Rashbam on Genesis", position: .canonicalRef("Rashbam on Genesis 1:1:1")),
        "single segment section derives segment ref with offset when ref == sectionRef")
    try expect(mappedSection.segments[0].heRef == "רשב\"ם על בראשית א׳:א׳:1",
        "single segment section derives segment heRef with offset when ref == sectionRef")

    // P1-D: Reader Title Hierarchy & Canonical Book Presentation
    func resolveReaderHeader(
        bookTitle: String,
        currentBookTitle: String?,
        tocNodeBab: String?,
        statusSubtitle: String,
        navigationTitle: String?
    ) -> (title: String, subtitle: String) {
        let title: String
        let cleanBookTitle = bookTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanBookTitle.isEmpty {
            title = cleanBookTitle
        } else if let currentBook = currentBookTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !currentBook.isEmpty {
            title = currentBook
        } else if let bab = tocNodeBab?.trimmingCharacters(in: .whitespacesAndNewlines), !bab.isEmpty {
            title = bab
        } else {
            title = ""
        }

        let subtitle: String
        let cleanStatus = statusSubtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanStatus.isEmpty && cleanStatus != title {
            subtitle = cleanStatus
        } else if let nav = navigationTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !nav.isEmpty && nav != title {
            subtitle = nav
        } else if let bab = tocNodeBab?.trimmingCharacters(in: .whitespacesAndNewlines), !bab.isEmpty && bab != title {
            subtitle = bab
        } else {
            subtitle = ""
        }

        return (title, subtitle)
    }

    // When book is "תורה תמימה על התורה" and navigation item is "2", title remains canonical "תורה תמימה על התורה", while subtitle is "2"
    let header1 = resolveReaderHeader(
        bookTitle: "תורה תמימה על התורה",
        currentBookTitle: "תורה תמימה על התורה",
        tocNodeBab: nil,
        statusSubtitle: "",
        navigationTitle: "2"
    )
    try expect(header1.title == "תורה תמימה על התורה", "Canonical book title must never be replaced by numeric navigation title")
    try expect(header1.subtitle == "2", "Numeric navigation index is relegated to subtitle")

    // When statusSubtitle has a descriptive locator (e.g. "בראשית א:ב"), subtitle reflects it
    let header2 = resolveReaderHeader(
        bookTitle: "תורה תמימה על התורה",
        currentBookTitle: "תורה תמימה על התורה",
        tocNodeBab: "בראשית",
        statusSubtitle: "בראשית א:ב",
        navigationTitle: "2"
    )
    try expect(header2.title == "תורה תמימה על התורה", "Title remains canonical book name")
    try expect(header2.subtitle == "בראשית א:ב", "Subtitle preserves locator")

    // When subtitle equals title, redundant display is suppressed
    let header3 = resolveReaderHeader(
        bookTitle: "תורה תמימה על התורה",
        currentBookTitle: "תורה תמימה על התורה",
        tocNodeBab: nil,
        statusSubtitle: "תורה תמימה על התורה",
        navigationTitle: nil
    )
    try expect(header3.subtitle == "", "Redundant subtitle matching title is suppressed")
}

// BEGIN SEFARIA_NAVIGATION_LANGUAGE_CASES
// Test-only fixtures exercise the complete production parser and DTO decoder.
// Display-language changes must never alter the canonical source references.
struct SefariaNavigationLanguageCheck {
    let name: String
    let actual: [String]
    let expected: [String]
    var passed: Bool { actual == expected }
}

func sefariaNavigationLanguageChecks() throws -> [SefariaNavigationLanguageCheck] {
    var checks: [SefariaNavigationLanguageCheck] = []
    func check(_ name: String, _ actual: [String], _ expected: [String]) {
        checks.append(.init(name: name, actual: actual, expected: expected))
    }
    func canonicalTree(_ nodes: [LibraryTOCNode]) -> [String] {
        nodes.flatMap { [$0.locator.persistenceKey] + canonicalTree($0.children) }
    }

    let index = try JSONDecoder().decode(SefariaIndexDTO.self, from: fixture("index-complex.json"))
    let hebrew = SefariaNavigationParser.nodes(
        schema: index.schema, indexTitle: index.title, baseRef: index.title, prefersHebrew: true)
    let english = SefariaNavigationParser.nodes(
        schema: index.schema, indexTitle: index.title, baseRef: index.title, prefersHebrew: false)
    check("schema.hebrew.root", hebrew.map(\.title), ["קדש", "מגיד"])
    check("schema.english.root", english.map(\.title), ["Kadesh", "Magid"])
    check("schema.hebrew.nested", hebrew.last?.children.map(\.title) ?? [], ["ארבעת הבנים"])
    check("schema.english.nested", english.last?.children.map(\.title) ?? [], ["The Four Sons"])
    let originalReferences = [
        "sefaria|Pesach Haggadah|ref:Pesach Haggadah, Kadesh",
        "sefaria|Pesach Haggadah|ref:Pesach Haggadah, Kadesh 1",
        "sefaria|Pesach Haggadah|ref:Pesach Haggadah, Kadesh 2",
        "sefaria|Pesach Haggadah|ref:Pesach Haggadah, Magid",
        "sefaria|Pesach Haggadah|ref:Pesach Haggadah, Magid, The Four Sons",
        "sefaria|Pesach Haggadah|ref:Pesach Haggadah, Magid, The Four Sons 1",
    ]
    check("schema.hebrew.canonical-tree", canonicalTree(hebrew), originalReferences)
    check("schema.english.canonical-tree", canonicalTree(english), originalReferences)

    let fallbackSchema = try JSONDecoder().decode(SefariaJSONValue.self, from: Data(#"""
    {"nodes":[
      {"key":"EnglishOnly","titles":[{"lang":"en","text":"English title","primary":true}]},
      {"key":"HebrewOnly","titles":[{"lang":"he","text":"כותרת עברית","primary":true}]},
      {"key":"EmptyEnglish","titles":[{"lang":"en","text":"","primary":true},{"lang":"he","text":"עברית זמינה","primary":true}]},
      {"key":"BlankHebrew","titles":[{"lang":"en","text":"Available English","primary":true},{"lang":"he","text":" \n\t ","primary":true}]},
      {"key":"BothBlank","titles":[{"lang":"en","text":" \t ","primary":true},{"lang":"he","text":"\n","primary":true}]},
      {"key":"MissingTitles"},
      {"key":"Primary","titles":[{"lang":"en","text":"English alias"},{"lang":"he","text":"כינוי"},{"lang":"en","text":"Primary English","primary":true},{"lang":"he","text":"עברית ראשית","primary":true}]},
      {"key":"default","default":true},
      {"key":"ExplicitRef","wholeRef":"Another Work, Explicit","titles":[{"lang":"en","text":"Explicit English","primary":true},{"lang":"he","text":"עברית מפורשת","primary":true}]}
    ]}
    """#.utf8))
    let fallbackHE = SefariaNavigationParser.nodes(
        schema: fallbackSchema, indexTitle: "Complex Work", baseRef: "Complex Work", prefersHebrew: true)
    let fallbackEN = SefariaNavigationParser.nodes(
        schema: fallbackSchema, indexTitle: "Complex Work", baseRef: "Complex Work", prefersHebrew: false)
    let commonFallbacks = [
        "English title", "כותרת עברית", "עברית זמינה", "Available English", "BothBlank", "MissingTitles",
    ]
    check("schema.hebrew.missing-empty-whitespace", Array(fallbackHE.prefix(6)).map(\.title), commonFallbacks)
    check("schema.english.missing-empty-whitespace", Array(fallbackEN.prefix(6)).map(\.title), commonFallbacks)
    check("schema.hebrew.primary-over-alias", fallbackHE.dropFirst(6).prefix(1).map(\.title), ["עברית ראשית"])
    check("schema.english.primary-over-alias", fallbackEN.dropFirst(6).prefix(1).map(\.title), ["Primary English"])
    let canonicalFallbacks = [
        "EnglishOnly", "HebrewOnly", "EmptyEnglish", "BlankHebrew", "BothBlank", "MissingTitles", "Primary",
    ].map { "sefaria|Complex Work|ref:Complex Work, \($0)" } + [
        "sefaria|Complex Work|ref:Complex Work",
        "sefaria|Complex Work|ref:Another Work, Explicit",
    ]
    check("schema.hebrew.default-wholeRef-identity", canonicalTree(fallbackHE), canonicalFallbacks)
    check("schema.english.default-wholeRef-identity", canonicalTree(fallbackEN), canonicalFallbacks)

    let shapeSchema: SefariaJSONValue = .object(["addressTypes": .array([.string("Integer")])])
    let roots = try JSONDecoder().decode([SefariaShapeDTO].self, from: Data(#"""
    [
      {"isComplex":true,"title":"Complex Work, Introduction","heTitle":"מבוא","chapters":[]},
      {"isComplex":true,"title":"Complex Work, Missing Hebrew","chapters":[]},
      {"isComplex":true,"title":"Complex Work, Blank Hebrew","heTitle":" \n\t ","chapters":[]},
      {"isComplex":true,"title":"","heTitle":"עברית בלבד","chapters":[]}
    ]
    """#.utf8))
    let rootsHE = SefariaNavigationParser.nodes(
        shapes: roots, schema: shapeSchema, indexTitle: "Complex Work", prefersHebrew: true)
    let rootsEN = SefariaNavigationParser.nodes(
        shapes: roots, schema: shapeSchema, indexTitle: "Complex Work", prefersHebrew: false)
    check("shape.hebrew.complex-root", rootsHE.prefix(1).map(\.title), ["מבוא"])
    check("shape.english.complex-root", rootsEN.prefix(1).map(\.title), ["Complex Work, Introduction"])
    let rootFallbacks = ["Complex Work, Missing Hebrew", "Complex Work, Blank Hebrew", "עברית בלבד"]
    check("shape.hebrew.missing-empty-whitespace", rootsHE.dropFirst().map(\.title), rootFallbacks)
    check("shape.english.missing-empty-whitespace", rootsEN.dropFirst().map(\.title), rootFallbacks)
    let rootReferences = [
        "sefaria|Complex Work|ref:Complex Work, Introduction",
        "sefaria|Complex Work|ref:Complex Work, Missing Hebrew",
        "sefaria|Complex Work|ref:Complex Work, Blank Hebrew",
        "sefaria|Complex Work|ref:",
    ]
    check("shape.hebrew.canonical-roots", canonicalTree(rootsHE), rootReferences)
    check("shape.english.canonical-roots", canonicalTree(rootsEN), rootReferences)

    let nested = try JSONDecoder().decode([SefariaShapeDTO].self, from: Data(#"""
    [{"isComplex":true,"book":"Complex Work","heTitle":"ספר מורכב","chapters":[
      {"title":"Complex Work, Kadesh","heTitle":"קדש","chapters":2},
      {"book":"Complex Work, Appendix","heTitle":"","chapters":1},
      {"section":"Complex Work, Section","heTitle":"מדור","chapters":1},
      {"title":"Complex Work, No Hebrew","chapters":1}
    ]}]
    """#.utf8))
    let nestedHE = SefariaNavigationParser.nodes(
        shapes: nested, schema: shapeSchema, indexTitle: "Complex Work", prefersHebrew: true)
    let nestedEN = SefariaNavigationParser.nodes(
        shapes: nested, schema: shapeSchema, indexTitle: "Complex Work", prefersHebrew: false)
    check("shape-child.hebrew.titles-and-fallbacks", nestedHE.first?.children.map(\.title) ?? [],
        ["קדש", "Complex Work, Appendix", "מדור", "Complex Work, No Hebrew"])
    check("shape-child.english.titles-and-fallbacks", nestedEN.first?.children.map(\.title) ?? [],
        ["Complex Work, Kadesh", "Complex Work, Appendix", "Complex Work, Section", "Complex Work, No Hebrew"])
    let nestedReferences = [
        "sefaria|Complex Work|ref:Complex Work",
        "sefaria|Complex Work|ref:Complex Work, Kadesh",
        "sefaria|Complex Work|ref:Complex Work, Kadesh 1",
        "sefaria|Complex Work|ref:Complex Work, Kadesh 2",
        "sefaria|Complex Work|ref:Complex Work, Appendix",
        "sefaria|Complex Work|ref:Complex Work, Appendix 1",
        "sefaria|Complex Work|ref:Complex Work, Section",
        "sefaria|Complex Work|ref:Complex Work, Section 1",
        "sefaria|Complex Work|ref:Complex Work, No Hebrew",
        "sefaria|Complex Work|ref:Complex Work, No Hebrew 1",
    ]
    check("shape-child.hebrew.canonical-tree", canonicalTree(nestedHE), nestedReferences)
    check("shape-child.english.canonical-tree", canonicalTree(nestedEN), nestedReferences)

    let talmud: SefariaJSONValue = .object([
        "lengths": .array([.number(2)]), "startingAddress": .number(21),
        "addressTypes": .array([.string("Talmud")]),
    ])
    let talmudHE = SefariaNavigationParser.nodes(
        schema: talmud, indexTitle: "Berakhot", baseRef: "Berakhot", prefersHebrew: true)
    let talmudEN = SefariaNavigationParser.nodes(
        schema: talmud, indexTitle: "Berakhot", baseRef: "Berakhot", prefersHebrew: false)
    check("adjacent.talmud.hebrew", talmudHE.map(\.title), ["י״ב ע״א", "י״ב ע״ב"])
    check("adjacent.talmud.english", talmudEN.map(\.title), ["12a", "12b"])
    let talmudReferences = ["sefaria|Berakhot|ref:Berakhot 12a", "sefaria|Berakhot|ref:Berakhot 12b"]
    check("adjacent.talmud.canonical-both", canonicalTree(talmudHE) + canonicalTree(talmudEN),
        talmudReferences + talmudReferences)

    let alt: SefariaJSONValue = .object([
        "nodeType": .string("ArrayMapNode"), "wholeRef": .string("Genesis 1:1-6:8"),
        "titles": .array([
            .object(["lang": .string("en"), "primary": .bool(true), "text": .string("Bereshit")]),
            .object(["lang": .string("he"), "primary": .bool(true), "text": .string("בראשית")]),
        ]),
    ])
    let altHE = SefariaNavigationParser.structures(
        schema: .object([:]), alternateStructures: ["Parasha": alt], indexTitle: "Genesis", prefersHebrew: true)
    let altEN = SefariaNavigationParser.structures(
        schema: .object([:]), alternateStructures: ["Parasha": alt], indexTitle: "Genesis", prefersHebrew: false)
    check("adjacent.alternate.hebrew", altHE.last?.nodes.map(\.title) ?? [], ["בראשית"])
    check("adjacent.alternate.english", altEN.last?.nodes.map(\.title) ?? [], ["Bereshit"])
    check("adjacent.alternate.canonical-both",
        canonicalTree(altHE.last?.nodes ?? []) + canonicalTree(altEN.last?.nodes ?? []),
        ["sefaria|Genesis|ref:Genesis 1:1-6:8", "sefaria|Genesis|ref:Genesis 1:1-6:8"])

    let dictionary: SefariaJSONValue = .object([
        "nodeType": .string("DictionaryNode"),
        "headwordMap": .array([.array([.string("א"), .string("Jastrow, א")])]),
    ])
    let dictionaryHE = SefariaNavigationParser.nodes(
        schema: dictionary, indexTitle: "Jastrow", baseRef: "Jastrow", prefersHebrew: true)
    let dictionaryEN = SefariaNavigationParser.nodes(
        schema: dictionary, indexTitle: "Jastrow", baseRef: "Jastrow", prefersHebrew: false)
    check("adjacent.dictionary.literal-headword-both",
        dictionaryHE.map(\.title) + dictionaryEN.map(\.title), ["א", "א"])
    check("adjacent.dictionary.canonical-both",
        canonicalTree(dictionaryHE) + canonicalTree(dictionaryEN),
        ["sefaria|Jastrow|ref:Jastrow, א", "sefaria|Jastrow|ref:Jastrow, א"])

    let implicit = SefariaNavigationParser.nodes(schema: index.schema, indexTitle: index.title, baseRef: index.title)
    check("default.follows-original-language-policy", implicit.map(\.title),
        LibraryPresentationPolicy.prefersHebrew() ? ["קדש", "מגיד"] : ["Kadesh", "Magid"])
    return checks
}
// END SEFARIA_NAVIGATION_LANGUAGE_CASES
