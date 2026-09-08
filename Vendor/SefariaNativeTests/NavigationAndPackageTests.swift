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
