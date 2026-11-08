import Foundation

/// One entry of the command palette: a title, how to find it and what it does.
///
/// ```swift
/// Command("New Note", section: "Notes", symbol: "square.and.pencil",
///         keywords: ["create", "add"], shortcut: CommandShortcut("⌘N")) {
///     model.newNote()
/// }
/// ```
///
/// Two commands are equal when everything but the action is equal, so a list of commands can be
/// compared and used with `onChange(of:)`.
public struct Command: Identifiable, Sendable {
    /// A stable identifier. Recent commands are remembered by it, so keep it the same across launches.
    public let id: String
    /// The name shown in the list and searched first, for example "New Note".
    public var title: String
    /// A second, smaller line under the title.
    public var subtitle: String?
    /// The section the command is listed under, for example "Notes". Commands without one are listed
    /// without a header.
    public var section: String?
    /// An SF Symbol name for the icon.
    public var symbol: String?
    /// Other words that find the command, for example `["create", "add"]` for "New Note".
    /// A keyword matches when it starts with the query.
    public var keywords: [String]
    /// The command's own keyboard shortcut, shown as a hint at the trailing edge of its row.
    public var shortcut: CommandShortcut?
    /// What the command does. The palette closes first, then runs it on the main actor.
    public var action: @MainActor @Sendable () -> Void

    /// Creates a command.
    /// - Parameters:
    ///   - title: The name shown in the list.
    ///   - id: A stable identifier; defaults to the section and title, such as `"Notes/New Note"`.
    ///   - subtitle: A second line under the title.
    ///   - section: The section header the command is listed under.
    ///   - symbol: An SF Symbol name.
    ///   - keywords: Other words that find the command.
    ///   - shortcut: The command's keyboard shortcut, shown as a hint.
    ///   - action: What the command does.
    public init(
        _ title: String,
        id: String? = nil,
        subtitle: String? = nil,
        section: String? = nil,
        symbol: String? = nil,
        keywords: [String] = [],
        shortcut: CommandShortcut? = nil,
        action: @escaping @MainActor @Sendable () -> Void = {}
    ) {
        self.id = id ?? [section, title].compactMap { $0 }.joined(separator: "/")
        self.title = title
        self.subtitle = subtitle
        self.section = section
        self.symbol = symbol
        self.keywords = keywords
        self.shortcut = shortcut
        self.action = action
    }
}

extension Command: Hashable {
    public static func == (lhs: Command, rhs: Command) -> Bool {
        lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.subtitle == rhs.subtitle
            && lhs.section == rhs.section
            && lhs.symbol == rhs.symbol
            && lhs.keywords == rhs.keywords
            && lhs.shortcut == rhs.shortcut
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
    }
}

extension Command: CustomStringConvertible {
    public var description: String {
        "Command(\(id))"
    }
}
