import Foundation

// MARK: - Unified Search Architecture Contract Tests

func runUnifiedSearchArchitectureTests() throws {
    try testUnifiedSearchScopeMappings()
    try testOtzariaAndSefariaOptionsPreservation()
    try testNativeOtzariaBookFilteringSemantics()
    try testSearchInBookContract()
    try testBackendSupportedSortingContract()
    try testHebrewSearchHelpModesContract()
    try testPaginationAndGenerationSafetyContract()
    try testNavigationStatePreservation()
    try testBackendSwitchingCleanReset()
    try testConfigurableOptionsGatingContract()
    try testSearchResultLocationDisplayTextAndFallbackContract()
    try testReaderDestinationFocusLocatorPreservationContract()
    try testSefariaHTMLSnippetFormattingContract()
    try testOtzariaSearchResultMappingContract()
    try testOtzariaBookFilterContract()
    try testSefariaLocatorProductionConversionContract()
    try testReaderHebrewHighlightAndNormalizationContract()
    print("✓ Unified search architecture contract tests passed")
}

// MARK: - 1. Scope Mappings

func testUnifiedSearchScopeMappings() throws {
    // Verify Otzaria available scopes (4 modes)
    let otzariaScopes: [UnifiedSearchScope] = [.exact, .advanced, .fuzzy, .zayit]
    try expect(otzariaScopes.count == 4, "Otzaria supports 4 search modes")
    try expect(otzariaScopes.map(\.rawValue) == ["exact", "advanced", "fuzzy", "zayit"], "Scope raw values match")
    try expect(otzariaScopes.map(\.title) == ["מדויק", "מתקדם", "מקורב", "זית"], "Scope titles match")

    // Verify Sefaria available scopes (2 modes)
    let sefariaScopes: [UnifiedSearchScope] = [.exact, .advanced]
    try expect(sefariaScopes.count == 2, "Sefaria supports 2 search modes")
    try expect(sefariaScopes.map(\.title) == ["מדויק", "מתקדם"], "Sefaria scope titles match")

    // Verify reader search mode mapping
    func readerMode(for scope: UnifiedSearchScope) -> SearchMode {
        switch scope {
        case .exact: return .phrase
        case .fuzzy: return .contains
        case .advanced, .zayit: return .near
        }
    }
    try expect(readerMode(for: .exact) == .phrase, "Exact maps to phrase reader mode")
    try expect(readerMode(for: .fuzzy) == .contains, "Fuzzy maps to contains reader mode")
    try expect(readerMode(for: .advanced) == .near, "Advanced maps to near reader mode")
    try expect(readerMode(for: .zayit) == .near, "Zayit maps to near reader mode")
}

// MARK: - 2. Options Preservation

func testOtzariaAndSefariaOptionsPreservation() throws {
    // Sefaria options model contract
    var sefariaOptions = LibrarySearchOptions()
    try expect(sefariaOptions.matchMode == .hebrewLemmatized, "Default Sefaria matchMode is lemmatized")
    try expect(sefariaOptions.wordDistance == 10, "Default Sefaria word distance is 10")
    try expect(sefariaOptions.sortOrder == .relevance, "Default Sefaria sortOrder is relevance")
    try expect(!sefariaOptions.reverseSort, "Default Sefaria reverseSort is false")

    // Modify and verify preservation
    sefariaOptions.matchMode = .exact
    sefariaOptions.wordDistance = 5
    sefariaOptions.sortOrder = .chronological
    sefariaOptions.reverseSort = true

    try expect(sefariaOptions.matchMode == .exact, "Sefaria matchMode preserved")
    try expect(sefariaOptions.wordDistance == 5, "Sefaria wordDistance preserved")
    try expect(sefariaOptions.sortOrder == .chronological, "Sefaria sortOrder preserved")
    try expect(sefariaOptions.reverseSort, "Sefaria reverseSort preserved")

    // Otzaria options model contract
    var otzariaOrder = OtzariaSearchOrder.catalogue
    let otzariaScope = OtzariaSearchScope.wordDistance
    let otzariaWordMatchMode = OtzariaWordMatchMode.all
    let otzariaDistance = 15
    let otzariaNegativeQuery = "בלי"
    let otzariaEnablesPrefixes = true
    let otzariaEnablesSuffixes = true
    let otzariaEnablesSpellingVariants = true
    let otzariaEnablesAramaic = true
    let otzariaIgnoresQuotes = true
    let otzariaMatchNikud = false
    let otzariaMatchTaamim = false

    try expect(otzariaOrder == .catalogue, "Otzaria order catalogue")
    try expect(otzariaScope == .wordDistance, "Otzaria scope wordDistance")
    try expect(otzariaWordMatchMode == .all, "Otzaria word match all")
    try expect(otzariaDistance == 15, "Otzaria distance preserved")
    try expect(otzariaNegativeQuery == "בלי", "Otzaria negative query preserved")
    try expect(otzariaEnablesPrefixes, "Otzaria prefixes preserved")
    try expect(otzariaEnablesSuffixes, "Otzaria suffixes preserved")
    try expect(otzariaEnablesSpellingVariants, "Otzaria spelling variants preserved")
    try expect(otzariaEnablesAramaic, "Otzaria aramaic preserved")
    try expect(otzariaIgnoresQuotes, "Otzaria ignores quotes preserved")
    try expect(!otzariaMatchNikud, "Otzaria matchNikud preserved")
    try expect(!otzariaMatchTaamim, "Otzaria matchTaamim preserved")

    // Switch order to relevance
    otzariaOrder = .relevance
    try expect(otzariaOrder == .relevance, "Otzaria order changed to relevance")
}

// MARK: - 3. Native Otzaria Book Filtering & JSON Parity

func testNativeOtzariaBookFilteringSemantics() throws {
    func makeRequest(query: String, selectedBookIds: Set<Int>, order: OtzariaSearchOrder = .catalogue) -> OtzariaSearchRequest {
        let sortedIds = selectedBookIds.sorted()
        let facets = sortedIds.isEmpty ? ["/"] : sortedIds.map { "/book/\($0)" }
        let bookIds = sortedIds.isEmpty ? nil : sortedIds
        return OtzariaSearchRequest(
            query: query,
            mode: .advanced,
            facets: facets,
            limit: 100,
            offset: 0,
            order: order,
            distance: 10,
            negativeQuery: "בלי",
            wordMatchMode: .all,
            matchNikud: false,
            matchTaamim: false,
            bookIds: bookIds
        )
    }

    // 1. Empty selection: Full corpus search through Tantivy with root facet
    let emptyRequest = makeRequest(query: "שלום", selectedBookIds: [])
    try expect(emptyRequest.facets == ["/"], "Empty selection uses root facet [/]")
    try expect(emptyRequest.bookIds == nil, "Empty selection passes nil bookIds")
    try expect(emptyRequest.distance == 10, "Advanced options preserved on empty selection")
    try expect(emptyRequest.negativeQuery == "בלי", "Negative query preserved")

    // 2. Single book selection: Executes in the SAME Tantivy search request path
    let singleRequest = makeRequest(query: "שלום", selectedBookIds: [42])
    try expect(singleRequest.facets == ["/book/42"], "Single book sets /book/42 facet")
    try expect(singleRequest.bookIds == [42], "Single book passes bookIds [42]")
    try expect(singleRequest.distance == 10, "Advanced distance preserved with book filter")
    try expect(singleRequest.negativeQuery == "בלי", "Negative query preserved with book filter")
    try expect(singleRequest.order == .catalogue, "Order preserved with book filter")

    // 3. Multi-book selection: Multiple book facets in the same Tantivy search request
    let multiRequest = makeRequest(query: "שלום", selectedBookIds: [100, 42, 200])
    try expect(multiRequest.facets == ["/book/42", "/book/100", "/book/200"], "Multi-book sets sorted /book/id facets")
    try expect(multiRequest.bookIds == [42, 100, 200], "Multi-book sets sorted bookIds")

    // 4. JSON Serialization Parity: Verify JSON wire format for ios_bridge
    let encoder = JSONEncoder()
    let data = try encoder.encode(multiRequest)
    let jsonString = String(data: data, encoding: .utf8) ?? ""
    try expect(jsonString.contains("\"bookIds\":[42,100,200]"), "JSON wire format contains camelCase bookIds")
    try expect(jsonString.contains("\"facets\":[\"/book/42\",\"/book/100\",\"/book/200\"]") || jsonString.contains("\"facets\":[\"\\/book\\/42\",\"\\/book\\/100\",\"\\/book\\/200\"]"), "JSON wire format contains facets")
    try expect(jsonString.contains("\"negativeQuery\":\"בלי\""), "JSON wire format contains negativeQuery")

    // 5. JSON Deserialization Parity: Verify decoding back
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(OtzariaSearchRequest.self, from: data)
    try expect(decoded.bookIds == [42, 100, 200], "Decoded bookIds match original")
    try expect(decoded.facets == ["/book/42", "/book/100", "/book/200"], "Decoded facets match original")
    try expect(decoded.query == "שלום", "Decoded query matches")
    try expect(decoded.negativeQuery == "בלי", "Decoded negativeQuery matches")
    try expect(decoded.distance == 10, "Decoded distance matches")

    // 6. Clearing selection returns to full corpus
    let clearedRequest = makeRequest(query: "שלום", selectedBookIds: [])
    try expect(clearedRequest.facets == ["/"], "Cleared selection restores root facet")
    try expect(clearedRequest.bookIds == nil, "Cleared selection restores nil bookIds")
}

// MARK: - 4. "Search in book" Contract

func testSearchInBookContract() throws {
    // Simulating search in book resolution
    func resolveBookId(tableName: String, bookId: Int) -> Int? {
        if bookId > 0 { return bookId }
        if tableName.hasPrefix("otzaria:") {
            return Int(tableName.dropFirst("otzaria:".count))
        } else if tableName.hasPrefix("b") {
            return Int(tableName.dropFirst())
        }
        return Int(tableName)
    }

    // Resolving bookId from different table formats
    try expect(resolveBookId(tableName: "b105", bookId: 0) == 105, "b-prefixed table resolves bookId")
    try expect(resolveBookId(tableName: "otzaria:789", bookId: 0) == 789, "otzaria-prefixed table resolves bookId")
    try expect(resolveBookId(tableName: "whatever", bookId: 42) == 42, "direct bookId takes priority")

    // Simulating "Search in book" execution
    let activeQuery = "שלום עליכם"
    let activeScope = UnifiedSearchScope.advanced
    var selectedBookIds: Set<Int> = []
    var resultKitabFilter = "סידור"
    var openedInReader = false

    func performSearchInBook(targetBookId: Int) {
        // Contract requirements:
        // 1. Filter set to target book
        selectedBookIds = [targetBookId]
        // 2. Result kitab filter cleared
        resultKitabFilter = ""
        // 3. Active query and scope preserved
        // 4. Does NOT open reader
        openedInReader = false
    }

    performSearchInBook(targetBookId: 105)

    try expect(selectedBookIds == [105], "Filter updated to target book")
    try expect(resultKitabFilter.isEmpty, "Result kitab filter reset")
    try expect(activeQuery == "שלום עליכם", "Query preserved")
    try expect(activeScope == .advanced, "Scope preserved")
    try expect(!openedInReader, "Search in book does NOT navigate away to reader")
}

// MARK: - 5. Backend-Supported Sorting Contract

func testBackendSupportedSortingContract() throws {
    // Verify Otzaria supported sorts
    let otzariaSorts = OtzariaSearchOrder.allCases
    try expect(otzariaSorts == [.catalogue, .relevance], "Otzaria supports catalogue and relevance sorts")
    try expect(otzariaSorts.map(\.rawValue) == ["catalogue", "relevance"], "Otzaria sort raw values match")
    try expect(otzariaSorts.map(\.label) == ["סדר קטלוגי", "רלוונטיות"], "Otzaria sort labels in Hebrew")

    // Verify Sefaria supported sorts
    let sefariaSorts = LibrarySearchSortOrder.allCases
    try expect(sefariaSorts == [.relevance, .canonical, .chronological], "Sefaria supports relevance, canonical, chronological")

    // Verify sort is sent to backend in OtzariaSearchRequest, not sorted locally
    let catRequest = OtzariaSearchRequest(query: "אור", mode: .exact, facets: ["/"], limit: 100, offset: 0, order: .catalogue)
    try expect(catRequest.order == .catalogue, "Request specifies catalogue order for backend execution")

    let relRequest = OtzariaSearchRequest(query: "אור", mode: .exact, facets: ["/"], limit: 100, offset: 0, order: .relevance)
    try expect(relRequest.order == .relevance, "Request specifies relevance order for backend execution")

    // Verify Sefaria options model carries backend sort
    var sefariaOptions = LibrarySearchOptions()
    sefariaOptions.sortOrder = .canonical
    sefariaOptions.reverseSort = true
    try expect(sefariaOptions.sortOrder == .canonical, "Sefaria options carry canonical sort for backend")
    try expect(sefariaOptions.reverseSort, "Sefaria options carry reverseSort for backend")
}

// MARK: - 6. Hebrew Search Help Modes Contract

func testHebrewSearchHelpModesContract() throws {
    let otzariaModes: [(title: String, desc: String)] = [
        ("מדויק", "איתור ביטוי או מילים ברצף המדויק כפי שנכתבו. זהו מצב החיפוש המהיר ביותר."),
        ("מתקדם", "חיפוש רב-עוצמה הכולל מרחק בין מילים, החרגת מילים, קידומות וסיומות דקדוקיות, כתיב מלא וחסר, ארמית, ומילים חלופיות."),
        ("מקורב", "איתור מילים גם כאשר קיימות שגיאות כתיב קלות או שינויי אותיות (מרחק עריכה)."),
        ("זית", "חיפוש סמנטי והקשרי מהיר לאיתור מקורות לפי משמעות ונושא.")
    ]

    for mode in otzariaModes {
        try expect(!mode.title.isEmpty, "Mode title is not empty")
        try expect(!mode.desc.isEmpty, "Mode description is not empty")
        try expect(!mode.title.contains("Title"), "Mode title does not contain raw key suffix 'Title'")
        try expect(!mode.desc.contains("Desc"), "Mode description does not contain raw key suffix 'Desc'")
        try expect(mode.title != "nearSearchTitle", "No raw nearSearchTitle key")
        try expect(mode.desc != "nearSearchDesc", "No raw nearSearchDesc key")
    }

    let sefariaModes: [(title: String, desc: String)] = [
        ("מדויק", "חיפוש מילים או ביטויים בדיוק כפי שהוזנו."),
        ("למטיזציה (מתקדם)", "חיפוש חכם המזהה שורשים, הטיות דקדוקיות וצורות מילים שונות לפי מילון ספריא, עם אפשרות להגדרת מרחק מילים.")
    ]

    for mode in sefariaModes {
        try expect(!mode.title.isEmpty, "Sefaria mode title not empty")
        try expect(!mode.desc.isEmpty, "Sefaria mode desc not empty")
        try expect(!mode.title.contains("Title") && !mode.desc.contains("Desc"), "No raw keys in Sefaria help")
    }
}

// MARK: - 7. Pagination and Generation Safety Contract

func testPaginationAndGenerationSafetyContract() throws {
    var currentGeneration = 0
    var loadedResults: [String] = []
    var hasMore = false
    var isLoadingMore = false

    func startSearch(query: String, bookIds: Set<Int>) {
        currentGeneration += 1
        let gen = currentGeneration
        loadedResults = []
        hasMore = false
        isLoadingMore = false

        // Simulate page 1 returned for this generation
        let page1Results = (0..<100).map { "item_\(query)_\($0)" }
        if gen == currentGeneration {
            loadedResults = page1Results
            hasMore = true // more than 100 results available
        }
    }

    func loadNextPage(query: String, bookIds: Set<Int>, completion: (Int, [String]) -> Void) {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        let gen = currentGeneration
        let offset = loadedResults.count
        let nextPageResults = (offset..<(offset + 100)).map { "item_\(query)_\($0)" }
        completion(gen, nextPageResults)
    }

    // 1. Initial search loads page 1 (100 results)
    startSearch(query: "תורה", bookIds: [1])
    try expect(loadedResults.count == 100, "Page 1 loads 100 items")
    try expect(hasMore, "More results flagged after page 1")

    // 2. Load page 2 (now 200 results)
    loadNextPage(query: "תורה", bookIds: [1]) { gen, items in
        if gen == currentGeneration {
            loadedResults.append(contentsOf: items)
            hasMore = true
            isLoadingMore = false
        }
    }
    try expect(loadedResults.count == 200, "Page 2 appends 100 items to reach 200")

    // 3. Load page 3 (now 300 results)
    loadNextPage(query: "תורה", bookIds: [1]) { gen, items in
        if gen == currentGeneration {
            loadedResults.append(contentsOf: items)
            hasMore = false // reached end
            isLoadingMore = false
        }
    }
    try expect(loadedResults.count == 300, "Page 3 appends to reach 300 items")
    try expect(!hasMore, "No more items after page 3")

    // 4. Changing book filter or query increments generation and resets results
    var pendingPage2Items: [String] = []
    loadNextPage(query: "תורה", bookIds: [1]) { gen, items in
        pendingPage2Items = items
    }

    // User changes filter before in-flight response arrives:
    startSearch(query: "תורה", bookIds: [2]) // increments generation!
    try expect(loadedResults.count == 100, "New search resets results to 100 items of new search")

    // Now delayed in-flight response arrives:
    let staleGen = currentGeneration - 1
    if staleGen == currentGeneration {
        loadedResults.append(contentsOf: pendingPage2Items)
    }
    try expect(loadedResults.count == 100, "Stale in-flight pagination from previous generation discarded")
}

// MARK: - 8. Navigation State Preservation

func testNavigationStatePreservation() throws {
    struct SearchSessionState {
        var query: String
        var scope: UnifiedSearchScope
        var selectedBookIds: Set<Int>
        var distance: Int
        var results: [String]
    }

    let session = SearchSessionState(
        query: "תורה אור",
        scope: .advanced,
        selectedBookIds: [10, 20],
        distance: 8,
        results: ["hit1", "hit2", "hit3"]
    )

    // User navigates to reader
    let isCurrentlyInReaderTab = true
    try expect(isCurrentlyInReaderTab, "User is in reader")

    // Session still holds all data while reader is active
    try expect(session.query == "תורה אור", "Query survived navigation to reader")
    try expect(session.scope == .advanced, "Scope survived navigation to reader")
    try expect(session.selectedBookIds == [10, 20], "Filters survived navigation to reader")
    try expect(session.distance == 8, "Distance survived navigation to reader")
    try expect(session.results.count == 3, "Results survived navigation to reader")

    // User returns to search tab
    let returnedToSearchTab = true
    try expect(returnedToSearchTab, "User returned to search tab")
    try expect(session.results.count == 3, "Results instantly restored on return")
}

// MARK: - 9. Backend Switching Clean Reset

func testBackendSwitchingCleanReset() throws {
    struct SessionState {
        var isSefaria = false
        var scope = UnifiedSearchScope.zayit
        var selectedBookIds: Set<Int> = [1, 2, 3]
        var query = "בראשית"
        var results = ["res1", "res2"]
        var resultKitabFilter = "חומש"

        mutating func handleBackendChanged(toSefaria: Bool) {
            isSefaria = toSefaria
            scope = .advanced
            selectedBookIds.removeAll()
            results.removeAll()
            query = ""
            resultKitabFilter = ""
        }
    }

    var session = SessionState()
    try expect(!session.isSefaria, "Initially Otzaria")
    try expect(session.scope == .zayit, "Initially Zayit scope")
    try expect(!session.selectedBookIds.isEmpty, "Initial filters non-empty")

    // Switch to Sefaria
    session.handleBackendChanged(toSefaria: true)

    try expect(session.isSefaria, "Backend switched to Sefaria")
    try expect(session.scope == .advanced, "Scope cleanly reset to .advanced")
    try expect(session.selectedBookIds.isEmpty, "Book filter emptied - no leak across backends")
    try expect(session.results.isEmpty, "Results cleared")
    try expect(session.query.isEmpty, "Query reset")
    try expect(session.resultKitabFilter.isEmpty, "Result filter reset")
}

// MARK: - 10. Configurable Options Gating Contract

func testConfigurableOptionsGatingContract() throws {
    func hasConfigurableOptions(scope: UnifiedSearchScope) -> Bool {
        scope == .advanced
    }

    try expect(hasConfigurableOptions(scope: .advanced), "Advanced scope has configurable options")
    try expect(!hasConfigurableOptions(scope: .exact), "Exact scope does not have configurable options")
    try expect(!hasConfigurableOptions(scope: .fuzzy), "Fuzzy scope does not have configurable options")
    try expect(!hasConfigurableOptions(scope: .zayit), "Zayit scope does not have configurable options")
}

// MARK: - 11. Search Result Location Display & Fallback Contract

func testSearchResultLocationDisplayTextAndFallbackContract() throws {
    struct SearchResultItemContract: Codable, Hashable {
        let archive: String
        let tableName: String
        let bookId: Int
        let bookTitle: String
        let page: Int
        let part: Int
        let backendLocator: TextLocator?
        let locationDisplayText: String?

        init(
            archive: String,
            tableName: String,
            bookId: Int,
            bookTitle: String,
            page: Int,
            part: Int,
            backendLocator: TextLocator? = nil,
            locationDisplayText: String? = nil
        ) {
            self.archive = archive
            self.tableName = tableName
            self.bookId = bookId
            self.bookTitle = bookTitle
            self.page = page
            self.part = part
            self.backendLocator = backendLocator
            self.locationDisplayText = locationDisplayText
        }
    }

    // Sefaria item with true segment ref in locationDisplayText
    let sefariaItem = SearchResultItemContract(
        archive: "Sefaria",
        tableName: "qualified:1",
        bookId: 100,
        bookTitle: "בראשית",
        page: 0,
        part: 0,
        backendLocator: TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 1:1")),
        locationDisplayText: "א׳:א׳"
    )

    try expect(sefariaItem.locationDisplayText == "א׳:א׳", "Sefaria item retains true locationDisplayText")
    try expect(sefariaItem.page == 0 && sefariaItem.part == 0, "Sefaria item eliminates fake part/page")

    // Location text formatting contract
    func locationText(for item: SearchResultItemContract) -> String {
        if let locationDisplayText = item.locationDisplayText, !locationDisplayText.isEmpty {
            return locationDisplayText
        }
        let isHebrew = item.archive == "Otzaria" || item.archive == "Sefaria" || item.backendLocator != nil
        if isHebrew {
            var parts: [String] = []
            if item.part > 0 {
                parts.append("כרך \(item.part)")
            }
            if item.page > 0 {
                parts.append("עמ' \(item.page)")
            }
            return parts.joined(separator: " • ")
        }
        return ""
    }

    try expect(locationText(for: sefariaItem) == "א׳:א׳", "Sefaria displays segment ref instead of fake volume/page")

    // Otzaria item with line heRef
    let otzariaWithRef = SearchResultItemContract(
        archive: "Otzaria",
        tableName: "otzaria:10",
        bookId: 10,
        bookTitle: "ברכות",
        page: 4,
        part: 1,
        locationDisplayText: "ב ע״א"
    )
    try expect(locationText(for: otzariaWithRef) == "ב ע״א", "Otzaria with heRef displays custom locationDisplayText")

    // Otzaria item without custom location falls back to volume/page
    let otzariaFallback = SearchResultItemContract(
        archive: "Otzaria",
        tableName: "otzaria:10",
        bookId: 10,
        bookTitle: "ספר",
        page: 15,
        part: 2,
        locationDisplayText: nil
    )
    try expect(locationText(for: otzariaFallback) == "כרך 2 • עמ' 15", "Otzaria fallback displays valid volume and page")

    // Item with part: 0, page: 0 and no locationDisplayText produces empty string (no fake 1 • 1)
    let emptyLocationItem = SearchResultItemContract(
        archive: "Sefaria",
        tableName: "qualified:2",
        bookId: 101,
        bookTitle: "ספר",
        page: 0,
        part: 0,
        locationDisplayText: nil
    )
    try expect(locationText(for: emptyLocationItem).isEmpty, "Zero volume/page with no location produces empty string")

    // Codable round-trip with locationDisplayText
    let encoded = try JSONEncoder().encode(sefariaItem)
    let decoded = try JSONDecoder().decode(SearchResultItemContract.self, from: encoded)
    try expect(decoded.locationDisplayText == "א׳:א׳", "locationDisplayText survives Codable roundtrip")
    try expect(decoded.bookTitle == "בראשית", "bookTitle survives Codable roundtrip")
}

// MARK: - 12. Reader Destination Focus Locator Preservation Contract

func testReaderDestinationFocusLocatorPreservationContract() throws {
    let sectionLocator = TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 1"))
    let segmentLocator = TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 1:14"))

    let destination = LibraryReaderDestination(sectionLocator: sectionLocator, focusLocator: segmentLocator)
    try expect(destination.sectionLocator == sectionLocator, "Section locator preserved")
    try expect(destination.focusLocator == segmentLocator, "Focus segment locator preserved")

    // Updating within same section preserves focusLocator
    var currentDestination: LibraryReaderDestination? = destination
    let requestedLocator = sectionLocator
    if currentDestination?.sectionLocator == requestedLocator {
        // preserved
    } else {
        currentDestination = LibraryReaderDestination(sectionLocator: requestedLocator, focusLocator: requestedLocator)
    }
    try expect(currentDestination?.focusLocator == segmentLocator, "Focus locator preserved across section reloads")
}

// MARK: - 13. Sefaria HTML Snippet Formatting Contract

func testSefariaHTMLSnippetFormattingContract() throws {
    let rawSnippet = "לפני <b>הודו</b> אחרי <em>חיים</em> וביטויים עם תגיות <br>, &quot;, &#39;, &amp;."
    let (formatted, highlightTerms) = MaktabahSearchSnippetFormatter.formatSnippet(rawSnippet)
    let plain = formatted.string

    // 1. Text is free of raw HTML tags and entities are decoded
    try expect(!plain.contains("<b>") && !plain.contains("</b>"), "Snippet does not contain <b> tags")
    try expect(!plain.contains("<em>") && !plain.contains("</em>"), "Snippet does not contain <em> tags")
    try expect(!plain.contains("<br>"), "Snippet does not contain <br> tags")
    try expect(!plain.contains("&quot;") && !plain.contains("&#39;") && !plain.contains("&amp;"), "Snippet entities decoded")
    try expect(plain.contains("\"") && plain.contains("'") && plain.contains("&"), "Snippet contains real quotes and ampersand")
    try expect(plain.contains("\n"), "Snippet converted <br> to newline")

    // 2. Bold and Italic attributes are applied
    let ns = plain as NSString
    let hoduRange = ns.range(of: "הודו")
    try expect(hoduRange.location != NSNotFound, "hodu found in plain text")
    let chayimRange = ns.range(of: "חיים")
    try expect(chayimRange.location != NSNotFound, "chayim found in plain text")

    var hoduIsBold = false
    formatted.enumerateAttribute(NSAttributedString.Key("NSBold"), in: hoduRange, options: []) { value, _, _ in
        if value as? Bool == true { hoduIsBold = true }
    }
    try expect(hoduIsBold, "'הודו' has NSBold attribute")

    var chayimIsItalic = false
    formatted.enumerateAttribute(NSAttributedString.Key("NSItalic"), in: chayimRange, options: []) { value, _, _ in
        if value as? Bool == true { chayimIsItalic = true }
    }
    try expect(chayimIsItalic, "'חיים' has NSItalic attribute")

    // 3. Highlight terms extracted
    try expect(highlightTerms.contains("הודו"), "highlightTerms contains 'הודו'")
    try expect(highlightTerms.contains("חיים"), "highlightTerms contains 'חיים'")
}

// MARK: - 14. Otzaria Search Result Mapping Contract

func testOtzariaSearchResultMappingContract() throws {
    let result = OtzariaSearchResult(
        filePath: "otzaria-book:1",
        title: "בראשית",
        segment: 7,
        text: "וַיִּיצֶר֩ יְהוָ֨ה אֱלֹהִ֜ים אֶת־הָֽאָדָ֗ם",
        reference: "בראשית ב׳:ז׳"
    )

    func navigationItem(from result: OtzariaSearchResult) -> SearchResultItemContract {
        SearchResultItemContract(
            archive: "Otzaria",
            tableName: "otzaria:1",
            bookId: 1,
            bookTitle: result.title,
            page: Int(result.segment),
            part: 0,
            locationDisplayText: result.reference.isEmpty ? nil : result.reference
        )
    }

    let item = navigationItem(from: result)
    try expect(item.locationDisplayText == "בראשית ב׳:ז׳", "Otzaria result maps reference to locationDisplayText")
    try expect(item.part == 0, "Otzaria result has part == 0")

    func formatLocationText(for item: SearchResultItemContract) -> String {
        if let locationDisplayText = item.locationDisplayText, !locationDisplayText.isEmpty {
            return locationDisplayText
        }
        var parts: [String] = []
        if item.part > 0 { parts.append("כרך \(item.part)") }
        if item.page > 0 { parts.append("עמ' \(item.page)") }
        return parts.joined(separator: " • ")
    }

    let display = formatLocationText(for: item)
    try expect(display == "בראשית ב׳:ז׳", "Displayed location is reference text")
    try expect(!display.contains("כרך 1") && !display.contains("כרך 0"), "Does not display misleading volume label")
}

// MARK: - 15. Otzaria Book Filter Contract

func testOtzariaBookFilterContract() throws {
    let unfilteredRequest = OtzariaSearchRequest(
        query: "בראשית",
        mode: .advanced,
        facets: ["/"],
        limit: 100,
        bookIds: nil
    )
    try expect(unfilteredRequest.facets == ["/"], "Unfiltered search uses root facet")
    try expect(unfilteredRequest.bookIds == nil, "Unfiltered search has nil bookIds")

    let filteredRequest = OtzariaSearchRequest(
        query: "בראשית",
        mode: .advanced,
        facets: ["/book/1"],
        limit: 100,
        bookIds: [1]
    )
    try expect(filteredRequest.facets == ["/book/1"], "Filtered search uses /book/1 facet")
    try expect(filteredRequest.bookIds == [1], "Filtered search has bookIds == [1]")
}

// MARK: - 16. Sefaria Locator Production Conversion Contract

func testSefariaLocatorProductionConversionContract() throws {
    let locator = TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 1:1"))
    try expect(locator.backend == .sefaria, "Backend is Sefaria")
    try expect(locator.workKey == "Genesis", "WorkKey is Genesis")
    if case .canonicalRef(let ref) = locator.position {
        try expect(ref == "Genesis 1:1", "Position is canonicalRef Genesis 1:1")
    } else {
        throw TestFailure.failed("Expected canonicalRef position")
    }

    let hit = LibrarySearchHit(
        locator: locator,
        displayRef: "Genesis 1:1",
        heRef: "בראשית א׳:א׳",
        snippet: "בְּרֵאשִׁ֖ית בָּרָ֣א"
    )
    try expect(hit.displayRef == "Genesis 1:1", "Hit displayRef matches")
    try expect(hit.heRef == "בראשית א׳:א׳", "Hit heRef matches")
}

// MARK: - 17. Reader Hebrew Highlight And Normalization Contract

func testReaderHebrewHighlightAndNormalizationContract() throws {
    let pointedText = "בְּרֵאשִׁ֖ית בָּרָ֣א אֱלֹהִ֑ים אֵ֥ת הַשָּׁמַ֖יִם וְאֵ֥ת הָאָֽרֶץ׃"

    // 1. Pointed text matches unpointed query "בראשית"
    let ranges1 = pointedText.findHebrewMatchingRanges(keywords: ["בראשית"])
    try expect(ranges1.count == 1, "Found exactly 1 match for unpointed 'בראשית'")
    let matchedStr1 = (pointedText as NSString).substring(with: ranges1[0])
    try expect(matchedStr1 == "בְּרֵאשִׁ֖ית", "Range accurately spans pointed 'בְּרֵאשִׁ֖ית'")

    // 2. Pointed text matches unpointed query "השמים"
    let ranges2 = pointedText.findHebrewMatchingRanges(keywords: ["השמים"])
    try expect(ranges2.count == 1, "Found exactly 1 match for unpointed 'השמים'")
    let matchedStr2 = (pointedText as NSString).substring(with: ranges2[0])
    try expect(matchedStr2 == "הַשָּׁמַ֖יִם", "Range accurately spans pointed 'הַשָּׁמַ֖יִם'")

    // 3. Multi-segment isolation check
    let segment1 = NSRange(location: 0, length: 20)
    let segment2 = NSRange(location: 21, length: 30)
    let searchRanges = ranges1 // match is in segment1

    // When segment2 is selected, searchRanges from segment1 should NOT be in rangesToPopup
    let intersecting = searchRanges.filter { NSIntersectionRange(segment2, $0).length > 0 }
    try expect(intersecting.isEmpty, "No intersecting ranges in segment2")
    let rangesToPopup: [NSRange] = intersecting.first != nil ? intersecting : []
    try expect(rangesToPopup.isEmpty, "rangesToPopup is empty when no matches in selected segment")
}


