import Testing
@testable import CommandPalette

@Suite("Fuzzy matching and highlights")
struct FuzzyMatcherTests {
    @Test func emptyQueryMatchesEverythingWithoutHighlights() throws {
        let match = try #require(FuzzyMatcher.match("", in: "New Note"))
        #expect(match.score == 0)
        #expect(match.ranges.isEmpty)
        let spaces = try #require(FuzzyMatcher.match("   ", in: "New Note"))
        #expect(spaces.ranges.isEmpty)
    }

    @Test(arguments: [
        ("new", "Rename Note"),   // no "w"
        ("wen", "New Note"),      // out of order
        ("xyz", "New Note"),
        ("new notes", "New Note"), // one letter too many
    ])
    func rejectsNonMatches(query: String, candidate: String) {
        #expect(FuzzyMatcher.match(query, in: candidate) == nil)
    }

    @Test(arguments: [
        ("new", "New Note", [0..<3]),
        // The consecutive "w" beats the word start "W" of "Window".
        ("new", "New Window", [0..<3]),
        ("nn", "New Note", [0..<1, 4..<5]),
        // The best fit, not the first: the word "Note", not the "n" of "Rename".
        ("note", "Rename Note", [7..<11]),
        ("wl", "Insert Web Link", [7..<8, 11..<12]),
        ("tbl", "Insert Table", [7..<8, 9..<11]),
        ("new", "Sort by Newest First", [8..<11]),
        ("new", "Insert Web Link", [1..<2, 3..<4, 7..<8]),
        // Spaces in the query are ignored.
        ("new no", "New Note", [0..<3, 4..<6]),
        // Case and diacritics are ignored.
        ("NEW", "New Folder", [0..<3]),
        ("cafe", "Café Recipes", [0..<4]),
    ] as [(String, String, [Range<Int>])])
    func highlightsTheBestFit(query: String, candidate: String, ranges: [Range<Int>]) throws {
        let match = try #require(FuzzyMatcher.match(query, in: candidate))
        #expect(match.ranges == ranges)
    }

    @Test func exactBeatsPrefixBeatsWordBeatsScattered() throws {
        let exact = try #require(FuzzyMatcher.match("bold", in: "Bold")).score
        let prefix = try #require(FuzzyMatcher.match("bold", in: "Bold Italic")).score
        #expect(exact > prefix)

        let newPrefix = try #require(FuzzyMatcher.match("new", in: "New Note")).score
        let newWord = try #require(FuzzyMatcher.match("new", in: "Sort by Newest First")).score
        let newScattered = try #require(FuzzyMatcher.match("new", in: "Insert Web Link")).score
        #expect(newPrefix > newWord)
        #expect(newWord > newScattered)
    }

    @Test func wordStartsBeatInnerLetters() throws {
        let wordStarts = try #require(FuzzyMatcher.match("ts", in: "Toggle Sidebar")).score
        let innerLetters = try #require(FuzzyMatcher.match("ts", in: "Tests")).score
        #expect(wordStarts > innerLetters)
    }

    @Test func camelCaseCountsAsWordStart() throws {
        let camel = try #require(FuzzyMatcher.match("tv", in: "tableView"))
        let plain = try #require(FuzzyMatcher.match("tv", in: "tavern"))
        #expect(camel.ranges == [0..<1, 5..<6])
        #expect(camel.score > plain.score)
    }

    @Test func rangesMergeTouchingIndices() {
        #expect(FuzzyMatcher.ranges(from: [0, 1, 2, 5]) == [0..<3, 5..<6])
        #expect(FuzzyMatcher.ranges(from: [3]) == [3..<4])
        #expect(FuzzyMatcher.ranges(from: []) == [])
    }

    @MainActor
    @Test func highlightedTextKeepsEveryCharacter() {
        let text = "Insert Web Link"
        let attributed = HighlightedText.attributed(text, highlights: [7..<8, 11..<12])
        #expect(String(attributed.characters) == text)

        // Out-of-range and overlapping ranges are ignored instead of crashing.
        let odd = HighlightedText.attributed("Note", highlights: [2..<9, 0..<2, 1..<3])
        #expect(String(odd.characters) == "Note")
    }
}
