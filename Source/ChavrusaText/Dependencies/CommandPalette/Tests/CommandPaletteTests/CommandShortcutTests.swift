import SwiftUI
import Testing
@testable import CommandPalette

@Suite("Command shortcuts")
struct CommandShortcutTests {
    @Test(arguments: [
        ("⌘N", "⌘N"),
        ("⇧⌘N", "⇧⌘N"),
        ("⌘⇧n", "⇧⌘N"),
        ("cmd+shift+n", "⇧⌘N"),
        ("Command+Shift+N", "⇧⌘N"),
        ("ctrl+option+space", "⌃⌥Space"),
        ("⌥⌘←", "⌥⌘←"),
        ("cmd+return", "⌘↩"),
        ("⌘⌫", "⌘⌫"),
        ("⌘,", "⌘,"),
        ("⌘ + K", "⌘K"),
        ("cmd++", "⌘+"),
        ("esc", "⎋"),
    ])
    func parsesAndDisplays(input: String, display: String) throws {
        let shortcut = try #require(CommandShortcut(input))
        #expect(shortcut.displayString == display)
    }

    @Test(arguments: ["", "⌘", "cmd+", "hyper+k", "cmd+kk", "⌘⇧"])
    func rejectsInvalidStrings(input: String) {
        #expect(CommandShortcut(input) == nil)
    }

    @Test func keyCapsInMenuOrder() throws {
        let shortcut = try #require(CommandShortcut("cmd+shift+ctrl+n"))
        #expect(shortcut.keyCaps == ["⌃", "⇧", "⌘", "N"])
    }

    @Test func characterInitializerLowercases() {
        let shortcut = CommandShortcut("N", modifiers: [.command, .option])
        #expect(shortcut.key == .character("n"))
        #expect(shortcut.displayString == "⌥⌘N")
        #expect(shortcut == CommandShortcut("⌥⌘n"))
    }

    @Test func commandKConvertsToSwiftUI() throws {
        let shortcut = CommandShortcut.commandK
        #expect(shortcut.displayString == "⌘K")
        #expect(shortcut.keyboardShortcut.key == KeyEquivalent("k"))
        #expect(shortcut.keyboardShortcut.modifiers == EventModifiers.command)

        let send = try #require(CommandShortcut("⇧⌘↩")).keyboardShortcut
        #expect(send.key == KeyEquivalent.return)
        #expect(send.modifiers == EventModifiers([.shift, .command]))
    }
}
