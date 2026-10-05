import Foundation

func runLocatorAndRefTests() throws {
    let sefaria = TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 1:1"))
    let otzaria = TextLocator(backend: .otzaria, workKey: "42", position: .legacyLine(7))
    let sefariaRoundTrip = try JSONDecoder().decode(TextLocator.self, from: JSONEncoder().encode(sefaria))
    let otzariaRoundTrip = try JSONDecoder().decode(TextLocator.self, from: JSONEncoder().encode(otzaria))
    try expect(sefariaRoundTrip == sefaria, "Sefaria locator round trip")
    try expect(otzariaRoundTrip == otzaria, "Otzaria locator round trip")
    try expect(sefaria.persistenceKey != otzaria.persistenceKey, "source-qualified IDs must not collide")
    try expect(SefariaRef.canonicalInput("Genesis.1.1") == "Genesis 1:1", "Tanakh URL ref")
    try expect(SefariaRef.canonicalInput("Berakhot.2a") == "Berakhot 2a", "Bavli URL ref")
    try expect(SefariaRef.canonicalInput("Rashi_on_Genesis.1.1.1") == "Rashi on Genesis 1:1:1",
        "commentary URL ref")
    try expect(SefariaRef.canonicalInput("Pesach_Haggadah,_Magid.1") == "Pesach Haggadah, Magid 1",
        "complex URL ref")
    try expect(SefariaRef.talmudAddress(offset: 0) == "2a" && SefariaRef.talmudAddress(offset: 1) == "2b",
        "Talmud address sequence")
    try expect(SefariaRef.sectionMatches("Genesis 1", "Genesis 1:9"),
        "segment belongs to its exact section")
    try expect(!SefariaRef.sectionMatches("Genesis 1", "Genesis 10"),
        "section matching does not confuse chapter 1 with chapter 10")

    var searchText = "creation"
    var highlightTerms: [String]? = ["creation"]
    var focusLocator: TextLocator? = sefaria
    var selectedLocator: TextLocator? = sefaria
    ReaderSearchHighlightPolicy.clear(
        searchText: &searchText,
        highlightTerms: &highlightTerms,
        focusLocator: &focusLocator,
        selectedLocator: &selectedLocator,
        inspectorIsVisible: true
    )
    try expect(searchText.isEmpty && highlightTerms == nil && focusLocator == nil,
        "explicit clear removes only transient search decoration state")
    try expect(selectedLocator == sefaria,
        "clearing search preserves the inspector selection while the inspector is visible")

    let unrelated = TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 1:2"))
    searchText = "creation"
    highlightTerms = ["creation"]
    focusLocator = sefaria
    selectedLocator = unrelated
    ReaderSearchHighlightPolicy.clear(
        searchText: &searchText,
        highlightTerms: &highlightTerms,
        focusLocator: &focusLocator,
        selectedLocator: &selectedLocator,
        inspectorIsVisible: false
    )
    try expect(selectedLocator == unrelated,
        "clearing search preserves unrelated text or annotation selection")
    try expect(!ReaderSearchHighlightPolicy.shouldClearAfterManualScroll(
        startOffsetY: nil,
        currentOffsetY: 400,
        viewportHeight: 600,
        hasActiveHighlight: true
    ), "programmatic scrolling does not clear search highlighting")
    try expect(!ReaderSearchHighlightPolicy.shouldClearAfterManualScroll(
        startOffsetY: 100,
        currentOffsetY: 190,
        viewportHeight: 600,
        hasActiveHighlight: true
    ), "small manual scroll keeps search highlighting")
    try expect(ReaderSearchHighlightPolicy.shouldClearAfterManualScroll(
        startOffsetY: 100,
        currentOffsetY: 230,
        viewportHeight: 600,
        hasActiveHighlight: true
    ), "manual scroll away from the result clears search highlighting")
}
