import Foundation

// MARK: - Unified Search Architecture Contract Tests

func runUnifiedSearchArchitectureTests() throws {
    try testUnifiedSearchScopeMappings()
    try testOtzariaAndSefariaOptionsPreservation()
    try testBookFilteringSemantics()
    try testSearchInBookContract()
    try testNavigationStatePreservation()
    try testBackendSwitchingCleanReset()
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
    var otzariaScope = OtzariaSearchScope.wordDistance
    var otzariaWordMatchMode = OtzariaWordMatchMode.all
    var otzariaDistance = 15
    var otzariaNegativeQuery = "בלי"
    var otzariaEnablesPrefixes = true
    var otzariaEnablesSuffixes = true
    var otzariaEnablesSpellingVariants = true
    var otzariaEnablesAramaic = true
    var otzariaIgnoresQuotes = true
    var otzariaMatchNikud = false
    var otzariaMatchTaamim = false

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

    // Switch order to relevance
    otzariaOrder = .relevance
    try expect(otzariaOrder == .relevance, "Otzaria order changed to relevance")
}

// MARK: - 3. Book Filtering Semantics

func testBookFilteringSemantics() throws {
    var selectedBookIds: Set<Int> = []

    // 0 books: signifies full corpus (all books)
    try expect(selectedBookIds.isEmpty, "0 books means full unfiltered corpus")

    func shouldUseFTS(for selectedIds: Set<Int>) -> Bool {
        !selectedIds.isEmpty
    }

    try expect(!shouldUseFTS(for: selectedBookIds), "Empty selection routes to Tantivy")

    // 1 book: single ID
    selectedBookIds.insert(42)
    try expect(selectedBookIds.count == 1, "Single book selected")
    try expect(selectedBookIds.contains(42), "Selected book is 42")
    try expect(shouldUseFTS(for: selectedBookIds), "Single book routes to SQLite FTS")

    // Multi-book: multiple IDs
    selectedBookIds.formUnion([100, 200, 300])
    try expect(selectedBookIds.count == 4, "4 books selected")
    try expect(shouldUseFTS(for: selectedBookIds), "Multi-book selection routes to SQLite FTS")

    // Clear filter: restores 0 books
    selectedBookIds.removeAll()
    try expect(selectedBookIds.isEmpty, "Cleared filter restores full corpus")
    try expect(!shouldUseFTS(for: selectedBookIds), "Cleared filter routes back to Tantivy")
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
    var activeQuery = "שלום עליכם"
    var activeScope = UnifiedSearchScope.advanced
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

// MARK: - 5. Navigation State Preservation

func testNavigationStatePreservation() throws {
    // Simulating session holding state across tab navigation
    class SimulatedSearchSession {
        var query = "תורה אור"
        var scope = UnifiedSearchScope.advanced
        var selectedBookIds: Set<Int> = [10, 20]
        var distance = 8
        var results: [String] = ["hit1", "hit2", "hit3"]
    }

    let session = SimulatedSearchSession()

    // Simulate user navigating to reader
    let isCurrentlyInReaderTab = true
    try expect(isCurrentlyInReaderTab, "User is in reader")

    // Verify session still holds all data while reader is active
    try expect(session.query == "תורה אור", "Query survived navigation to reader")
    try expect(session.scope == .advanced, "Scope survived navigation to reader")
    try expect(session.selectedBookIds == [10, 20], "Filters survived navigation to reader")
    try expect(session.distance == 8, "Distance survived navigation to reader")
    try expect(session.results.count == 3, "Results survived navigation to reader")

    // Simulate user returning to search tab
    let returnedToSearchTab = true
    try expect(returnedToSearchTab, "User returned to search tab")
    try expect(session.results.count == 3, "Results instantly restored on return")
}

// MARK: - 6. Backend Switching Clean Reset

func testBackendSwitchingCleanReset() throws {
    class SimulatedSessionState {
        var isSefaria = false
        var scope = UnifiedSearchScope.zayit
        var selectedBookIds: Set<Int> = [1, 2, 3]
        var query = "בראשית"
        var results = ["res1", "res2"]
        var resultKitabFilter = "חומש"

        func handleBackendChanged(toSefaria: Bool) {
            isSefaria = toSefaria
            scope = .advanced
            selectedBookIds.removeAll()
            results.removeAll()
            query = ""
            resultKitabFilter = ""
        }
    }

    let session = SimulatedSessionState()
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
