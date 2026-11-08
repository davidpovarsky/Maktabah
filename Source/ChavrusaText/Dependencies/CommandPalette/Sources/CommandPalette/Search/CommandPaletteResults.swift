import Foundation

/// A command in the palette's list, with what made it match.
public struct CommandPaletteItem: Identifiable, Hashable, Sendable {
    /// Unique in the list: the section's id plus the command's id, because a recent command is
    /// listed both under "Recent" and in its own section.
    public let id: String
    public let command: Command
    /// The matched characters of the title, as character offsets. Empty when the query is empty or
    /// only a keyword matched.
    public let titleHighlights: [Range<Int>]
    /// The match score; 0 when the query is empty.
    public let score: Int

    public init(id: String, command: Command, titleHighlights: [Range<Int>] = [], score: Int = 0) {
        self.id = id
        self.command = command
        self.titleHighlights = titleHighlights
        self.score = score
    }
}

/// A group of items under an optional header.
public struct CommandPaletteSection: Identifiable, Hashable, Sendable {
    public let id: String
    /// The header, or `nil` for commands without a section.
    public let title: String?
    public let items: [CommandPaletteItem]

    public init(id: String, title: String?, items: [CommandPaletteItem]) {
        self.id = id
        self.title = title
        self.items = items
    }
}

/// One line of the palette's list: a section header or a command.
public enum CommandPaletteRow: Identifiable, Hashable, Sendable {
    case header(id: String, title: String)
    case command(CommandPaletteItem)

    public var id: String {
        switch self {
        case .header(let id, _): id
        case .command(let item): item.id
        }
    }

    /// The item, or `nil` for a header.
    public var item: CommandPaletteItem? {
        if case .command(let item) = self { return item }
        return nil
    }

    /// Only commands can be selected; headers are skipped.
    public var isSelectable: Bool { item != nil }
}

/// Turns a query and a list of commands into the sections the palette shows.
///
/// - **Empty query**: a "Recent" section with the recent commands, newest first, then every command
///   grouped by section, in the order the sections and commands first appear in the list.
/// - **A query**: only matching commands, best first (score, then shorter title, then list order),
///   grouped by section. Sections are ordered by their best match.
///
/// A command matches when its title matches ``FuzzyMatcher``, or one of its keywords starts with
/// the query. A keyword match counts half and highlights nothing.
public enum CommandPaletteResults {
    /// The id prefix of the recent section.
    public static let recentSectionID = "recent"

    /// Builds the sections for `query`.
    /// - Parameters:
    ///   - query: What the user typed.
    ///   - commands: All commands, in the order they should be listed.
    ///   - recentIDs: Ids of recently run commands, newest first. Unknown ids are skipped.
    ///   - recentTitle: The header of the recent section.
    public static func sections(
        for query: String,
        in commands: [Command],
        recentIDs: [String] = [],
        recentTitle: String = "Recent"
    ) -> [CommandPaletteSection] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return browsingSections(commands: commands, recentIDs: recentIDs, recentTitle: recentTitle)
        }
        return searchSections(query: trimmed, commands: commands)
    }

    /// The sections as a flat list of headers and items.
    public static func rows(for sections: [CommandPaletteSection]) -> [CommandPaletteRow] {
        sections.flatMap { section -> [CommandPaletteRow] in
            let header: [CommandPaletteRow] = section.title.map { [.header(id: "header:" + section.id, title: $0)] } ?? []
            return header + section.items.map(CommandPaletteRow.command)
        }
    }

    /// Scores one command, or returns `nil` when it does not match.
    public static func match(_ query: String, command: Command) -> FuzzyMatch? {
        if let title = FuzzyMatcher.match(query, in: command.title) {
            return title
        }
        let foldedQuery = query.trimmingCharacters(in: .whitespaces).map(FuzzyMatcher.fold).joined()
        let keywordScore = command.keywords.compactMap { keyword -> Int? in
            let folded = keyword.map(FuzzyMatcher.fold).joined()
            guard !foldedQuery.isEmpty, folded.hasPrefix(foldedQuery) else { return nil }
            return FuzzyMatcher.match(query, in: keyword)?.score
        }.max()
        return keywordScore.map { FuzzyMatch(score: $0 / 2, ranges: []) }
    }

    // MARK: - Private

    private static func browsingSections(commands: [Command], recentIDs: [String], recentTitle: String) -> [CommandPaletteSection] {
        var result: [CommandPaletteSection] = []

        var seen = Set<String>()
        let recent = recentIDs.compactMap { id -> Command? in
            guard seen.insert(id).inserted else { return nil }
            return commands.first { $0.id == id }
        }
        if !recent.isEmpty {
            result.append(CommandPaletteSection(
                id: recentSectionID,
                title: recentTitle,
                items: recent.map { CommandPaletteItem(id: recentSectionID + "/" + $0.id, command: $0) }
            ))
        }

        let indexed = commands.enumerated().map { (offset: $0.offset, command: $0.element, match: FuzzyMatch(score: 0, ranges: [])) }
        result += grouped(indexed)
        return result
    }

    private static func searchSections(query: String, commands: [Command]) -> [CommandPaletteSection] {
        let matches = commands.enumerated().compactMap { offset, command -> (offset: Int, command: Command, match: FuzzyMatch)? in
            guard let result = match(query, command: command) else { return nil }
            return (offset: offset, command: command, match: result)
        }
        let sorted = matches.sorted { lhs, rhs in
            if lhs.match.score != rhs.match.score { return lhs.match.score > rhs.match.score }
            if lhs.command.title.count != rhs.command.title.count { return lhs.command.title.count < rhs.command.title.count }
            return lhs.offset < rhs.offset
        }
        return grouped(sorted)
    }

    /// Groups commands by section, keeping the given order inside a section and ordering sections
    /// by their first command.
    private static func grouped(_ entries: [(offset: Int, command: Command, match: FuzzyMatch)]) -> [CommandPaletteSection] {
        var order: [String] = []
        var titles: [String: String?] = [:]
        var items: [String: [CommandPaletteItem]] = [:]
        for entry in entries {
            let sectionID = "section:" + (entry.command.section ?? "")
            if items[sectionID] == nil {
                order.append(sectionID)
                titles[sectionID] = entry.command.section
                items[sectionID] = []
            }
            items[sectionID]?.append(CommandPaletteItem(
                id: sectionID + "/" + entry.command.id,
                command: entry.command,
                titleHighlights: entry.match.ranges,
                score: entry.match.score
            ))
        }
        return order.map { id in
            CommandPaletteSection(id: id, title: titles[id] ?? nil, items: items[id] ?? [])
        }
    }
}
