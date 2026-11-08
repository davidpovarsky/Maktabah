import Foundation
import SwiftUI

/// A keyboard shortcut such as ⇧⌘N: one key plus modifier keys.
///
/// The palette shows a command's shortcut as key caps at the trailing edge of its row, and
/// ``commandK`` is the default shortcut that opens the palette.
///
/// ```swift
/// CommandShortcut("⌘N")               // ⌘N
/// CommandShortcut("cmd+shift+n")      // ⇧⌘N
/// CommandShortcut("n", modifiers: [.command, .option]).displayString // "⌥⌘N"
/// ```
public struct CommandShortcut: Hashable, Sendable, CustomStringConvertible {
    public var key: Key
    public var modifiers: Modifiers

    public init(_ key: Key, modifiers: Modifiers = []) {
        self.key = key
        self.modifiers = modifiers
    }

    /// A shortcut for a character key: `CommandShortcut("n", modifiers: .command)`.
    public init(_ character: Character, modifiers: Modifiers) {
        self.init(.character(Character(character.lowercased())), modifiers: modifiers)
    }

    /// Parses glyph strings (`"⇧⌘N"`, `"⌘↩"`) and words joined by `+` (`"cmd+shift+n"`,
    /// `"ctrl+option+space"`). Modifiers may come in any order. Returns `nil` when the key is
    /// missing or unknown, or a modifier word is not recognized.
    public init?(_ string: String) {
        var rest = Substring(string.trimmingCharacters(in: .whitespaces))
        var modifiers: Modifiers = []

        // Leading modifier glyphs: "⇧⌘N".
        while let first = rest.first, let modifier = Modifiers(glyph: first) {
            modifiers.insert(modifier)
            rest = rest.dropFirst()
        }

        // Words: "cmd+shift+n". A single remaining character is always the key, so "⌘+" works.
        if rest.count > 1, rest.contains("+") {
            var parts = rest.split(separator: "+", omittingEmptySubsequences: false).map(String.init)
            // "cmd++": the empty tail means "+" itself is the key.
            if parts.count >= 2, parts[parts.count - 1].isEmpty, parts[parts.count - 2].isEmpty {
                parts.removeLast(2)
                parts.append("+")
            }
            guard let keyName = parts.popLast(), !keyName.isEmpty else { return nil }
            for word in parts where !word.trimmingCharacters(in: .whitespaces).isEmpty {
                guard let modifier = Modifiers(word: word) else { return nil }
                modifiers.insert(modifier)
            }
            rest = Substring(keyName)
        }

        guard let key = Key(name: String(rest)) else { return nil }
        self.init(key, modifiers: modifiers)
    }

    /// ⌘K, the shortcut people expect to open a command palette.
    public static let commandK = CommandShortcut(.character("k"), modifiers: .command)

    /// The shortcut as menus show it, modifiers in the order ⌃⌥⇧⌘: `"⇧⌘N"`.
    public var displayString: String {
        modifiers.displayString + key.displayName
    }

    /// One string per key cap: `["⇧", "⌘", "N"]`.
    public var keyCaps: [String] {
        Modifiers.displayOrder.compactMap { modifiers.contains($0.0) ? String($0.1) : nil } + [key.displayName]
    }

    public var description: String { displayString }

    /// The same shortcut for SwiftUI's `.keyboardShortcut(_:)`.
    public var keyboardShortcut: KeyboardShortcut {
        KeyboardShortcut(key.keyEquivalent, modifiers: modifiers.eventModifiers)
    }
}

// MARK: - Modifiers

extension CommandShortcut {
    /// The modifier keys of a shortcut.
    public struct Modifiers: OptionSet, Hashable, Sendable {
        public let rawValue: UInt8
        public init(rawValue: UInt8) { self.rawValue = rawValue }

        public static let control = Modifiers(rawValue: 1 << 0)
        public static let option = Modifiers(rawValue: 1 << 1)
        public static let shift = Modifiers(rawValue: 1 << 2)
        public static let command = Modifiers(rawValue: 1 << 3)

        /// The order macOS uses in menus.
        static let displayOrder: [(Modifiers, Character)] = [
            (.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘"),
        ]

        /// `"⌃⌥⇧⌘"` for all four, in menu order.
        public var displayString: String {
            String(Self.displayOrder.compactMap { contains($0.0) ? $0.1 : nil })
        }

        /// SwiftUI's modifiers.
        public var eventModifiers: EventModifiers {
            var result: EventModifiers = []
            if contains(.control) { result.insert(.control) }
            if contains(.option) { result.insert(.option) }
            if contains(.shift) { result.insert(.shift) }
            if contains(.command) { result.insert(.command) }
            return result
        }

        init?(glyph: Character) {
            switch glyph {
            case "⌘": self = .command
            case "⇧": self = .shift
            case "⌥": self = .option
            case "⌃": self = .control
            default: return nil
            }
        }

        init?(word: String) {
            let trimmed = word.trimmingCharacters(in: .whitespaces)
            if trimmed.count == 1, let glyph = trimmed.first, let modifier = Modifiers(glyph: glyph) {
                self = modifier
                return
            }
            switch trimmed.lowercased() {
            case "cmd", "command", "meta", "super": self = .command
            case "shift": self = .shift
            case "opt", "option", "alt": self = .option
            case "ctrl", "control", "ctl": self = .control
            default: return nil
            }
        }
    }
}

// MARK: - Keys

extension CommandShortcut {
    /// The key of a shortcut.
    public enum Key: Hashable, Sendable, CustomStringConvertible {
        /// A key that types a character, stored lowercased: `"n"`, `","`, `"1"`.
        case character(Character)
        case returnKey
        case escape
        case delete
        case tab
        case space
        case upArrow
        case downArrow
        case leftArrow
        case rightArrow

        /// A key by name or glyph: `"n"`, `"N"`, `","`, `"return"`, `"↩"`, `"esc"`, `"⌫"`,
        /// `"space"`, `"up"`, `"↑"`.
        public init?(name: String) {
            if name == " " {
                self = .space
                return
            }
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            switch trimmed.lowercased() {
            case "return", "enter", "↩", "⏎": self = .returnKey
            case "esc", "escape", "⎋": self = .escape
            case "delete", "backspace", "⌫": self = .delete
            case "tab", "⇥": self = .tab
            case "space", "␣": self = .space
            case "up", "uparrow", "↑": self = .upArrow
            case "down", "downarrow", "↓": self = .downArrow
            case "left", "leftarrow", "←": self = .leftArrow
            case "right", "rightarrow", "→": self = .rightArrow
            default:
                guard trimmed.count == 1, let character = trimmed.first,
                      !character.isWhitespace, Modifiers(glyph: character) == nil
                else { return nil }
                self = .character(Character(character.lowercased()))
            }
        }

        /// How the key is shown: `"N"`, `","`, `"↩"`, `"Space"`.
        public var displayName: String {
            switch self {
            case .character(let character): character.uppercased()
            case .returnKey: "↩"
            case .escape: "⎋"
            case .delete: "⌫"
            case .tab: "⇥"
            case .space: "Space"
            case .upArrow: "↑"
            case .downArrow: "↓"
            case .leftArrow: "←"
            case .rightArrow: "→"
            }
        }

        public var description: String { displayName }

        /// SwiftUI's key equivalent.
        public var keyEquivalent: KeyEquivalent {
            switch self {
            case .character(let character): KeyEquivalent(character)
            case .returnKey: .return
            case .escape: .escape
            case .delete: .delete
            case .tab: .tab
            case .space: .space
            case .upArrow: .upArrow
            case .downArrow: .downArrow
            case .leftArrow: .leftArrow
            case .rightArrow: .rightArrow
            }
        }
    }
}
