import Testing
@testable import CommandPalette

@Suite("Sections and ranking")
struct CommandPaletteResultsTests {
    @Test func emptyQueryListsRecentsThenSectionsInListOrder() {
        let rows = Fixtures.rows("", recentIDs: ["new-window", "missing", "new-note", "new-window"])
        #expect(Fixtures.outline(rows) == [
            "# Recent", "new-window", "new-note",
            "# Notes", "new-note", "rename-note", "checklist",
            "# Folders", "new-folder",
            "# Format", "insert-link",
            "# View", "sort-newest", "new-window",
            "settings", // no section, no header
        ])
    }

    @Test func rowIDsAreUniqueEvenForRecentCommands() {
        let rows = Fixtures.rows("", recentIDs: ["new-note"])
        let ids = rows.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(rows[1].id == "recent/new-note")
    }

    @Test func noRecentsNoRecentSection() {
        let rows = Fixtures.rows("")
        #expect(Fixtures.outline(rows).first == "# Notes")
    }

    @Test func searchRanksMatchesAndOrdersSectionsByBestMatch() {
        let rows = Fixtures.rows("new", recentIDs: ["insert-link"])
        // Recents are not listed while searching. Equal scores: shorter title, then list order.
        #expect(Fixtures.outline(rows) == [
            "# Notes", "new-note", "checklist",     // "checklist" matches its keyword "new list"
            "# Folders", "new-folder",
            "# View", "new-window", "sort-newest",
            "# Format", "insert-link",
        ])
    }

    @Test func searchCarriesTitleHighlights() throws {
        let rows = Fixtures.rows("new")
        let sort = try #require(rows.compactMap(\.item).first { $0.command.id == "sort-newest" })
        #expect(sort.titleHighlights == [8..<11])
        let keywordOnly = try #require(rows.compactMap(\.item).first { $0.command.id == "checklist" })
        #expect(keywordOnly.titleHighlights.isEmpty)
    }

    @Test func keywordsMatchByPrefixAndCountHalf() throws {
        let checklist = Fixtures.commands[6]
        let keyword = try #require(CommandPaletteResults.match("todo", command: checklist))
        let full = try #require(FuzzyMatcher.match("todo", in: "todo"))
        #expect(keyword.score == full.score / 2)
        #expect(keyword.ranges.isEmpty)
        // "odo" is inside "todo" but not a prefix of it.
        #expect(CommandPaletteResults.match("odo", command: checklist) == nil)
    }

    @Test func noMatchesNoRows() {
        #expect(Fixtures.rows("zzz").isEmpty)
    }

    @Test func whitespaceOnlyQueryBrowses() {
        #expect(Fixtures.outline(Fixtures.rows("  ")) == Fixtures.outline(Fixtures.rows("")))
    }
}
