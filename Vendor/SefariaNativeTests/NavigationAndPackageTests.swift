import Foundation

func runNavigationAndPackageTests() throws {
    let firstRepeatedLeaf = SefariaCatalogIdentity.categoryID(path: ["Tanakh", "Commentary"])
    let secondRepeatedLeaf = SefariaCatalogIdentity.categoryID(path: ["Talmud", "Commentary"])
    try expect(firstRepeatedLeaf != secondRepeatedLeaf, "category identity includes full path")
    try expect(firstRepeatedLeaf == SefariaCatalogIdentity.categoryID(path: ["Tanakh", "Commentary"]),
        "category identity is deterministic")
    let index = try JSONDecoder().decode(SefariaIndexDTO.self, from: fixture("index-complex.json"))
    let nodes = SefariaNavigationParser.nodes(schema: index.schema, indexTitle: index.title, baseRef: index.title)
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
    let withAlternatives = SefariaNavigationParser.nodes(schema: ordinary,
        alternateStructures: alternatives, indexTitle: "Genesis", baseRef: "Genesis")
    try expect(withAlternatives.contains { $0.locator.position == .canonicalRef("Genesis 1:1-6:8") },
        "alternate wholeRef navigation")
    try expect(withAlternatives.contains { $0.locator.position == .canonicalRef("Genesis 6:9-11:32") },
        "alternate refs navigation")

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
}
