@testable import CommandPalette

enum Fixtures {
    /// A small notes app. The order matters: it is the order of the list with an empty query.
    static let commands: [Command] = [
        Command("New Note", id: "new-note", section: "Notes", keywords: ["create", "add"], shortcut: CommandShortcut("⌘N")),
        Command("Rename Note", id: "rename-note", section: "Notes"),
        Command("New Folder", id: "new-folder", section: "Folders", shortcut: CommandShortcut("⇧⌘N")),
        Command("Insert Web Link", id: "insert-link", section: "Format"),
        Command("Sort by Newest First", id: "sort-newest", section: "View"),
        Command("New Window", id: "new-window", section: "View"),
        Command("Create Checklist", id: "checklist", section: "Notes", keywords: ["todo", "new list"]),
        Command("Settings…", id: "settings"),
    ]

    static func rows(_ query: String, recentIDs: [String] = []) -> [CommandPaletteRow] {
        CommandPaletteResults.rows(for: CommandPaletteResults.sections(for: query, in: commands, recentIDs: recentIDs))
    }

    /// Row ids, with headers written as "# Title".
    static func outline(_ rows: [CommandPaletteRow]) -> [String] {
        rows.map { row -> String in
            switch row {
            case .header(_, let title): "# " + title
            case .command(let item): item.command.id
            }
        }
    }
}
