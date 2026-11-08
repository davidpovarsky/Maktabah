import Testing
@testable import CommandPalette

@Suite("Keyboard selection")
struct SelectionTests {
    /// [# Notes, new-note, rename-note, checklist, # Folders, new-folder, # Format, insert-link,
    ///  # View, sort-newest, new-window, settings]
    let rows = Fixtures.rows("")

    @Test func startsOnTheFirstCommandNotTheHeader() {
        let selection = CommandPaletteSelection(rows: rows)
        #expect(selection.index == 1)
        #expect(selection.selectedItem?.command.id == "new-note")
    }

    @Test func moveDownSkipsHeaders() {
        var selection = CommandPaletteSelection(rows: rows)
        selection.select(commandID: "checklist")
        selection.moveDown()
        let afterHeader = selection.selectedItem?.command.id
        #expect(afterHeader == "new-folder")
        selection.moveDown()
        let afterSecondHeader = selection.selectedItem?.command.id
        #expect(afterSecondHeader == "insert-link")
    }

    @Test func moveUpSkipsHeaders() {
        var selection = CommandPaletteSelection(rows: rows)
        selection.select(commandID: "new-folder")
        selection.moveUp()
        let id = selection.selectedItem?.command.id
        #expect(id == "checklist")
    }

    @Test func wrapsAtBothEnds() {
        var selection = CommandPaletteSelection(rows: rows)
        selection.moveUp()
        let last = selection.selectedItem?.command.id
        #expect(last == "settings")
        selection.moveDown()
        let first = selection.selectedItem?.command.id
        #expect(first == "new-note")
    }

    @Test func walksEveryCommandOnceBeforeWrapping() {
        var selection = CommandPaletteSelection(rows: rows)
        var visited: [String] = []
        for _ in 0..<8 {
            visited.append(selection.selectedItem?.command.id ?? "-")
            selection.moveDown()
        }
        #expect(visited == ["new-note", "rename-note", "checklist", "new-folder", "insert-link", "sort-newest", "new-window", "settings"])
        let wrapped = selection.selectedItem?.command.id
        #expect(wrapped == "new-note")
    }

    @Test func noCommandsNothingSelected() {
        var selection = CommandPaletteSelection(rows: [.header(id: "h", title: "Empty")])
        #expect(selection.index == nil)
        selection.moveDown()
        let afterDown = selection.index
        #expect(afterDown == nil)
        selection.moveUp()
        let afterUp = selection.selectedItem
        #expect(afterUp == nil)

        let empty = CommandPaletteSelection(rows: [])
        #expect(empty.selectedRowID == nil)
    }

    @Test func singleCommandWrapsToItself() {
        let rows = Fixtures.rows("rename")
        var selection = CommandPaletteSelection(rows: rows)
        selection.moveDown()
        let down = selection.selectedItem?.command.id
        #expect(down == "rename-note")
        selection.moveUp()
        let up = selection.selectedItem?.command.id
        #expect(up == "rename-note")
    }

    @Test func initialRowIDMustBeACommand() {
        let onHeader = CommandPaletteSelection(rows: rows, selectedRowID: "header:section:Folders")
        #expect(onHeader.selectedItem?.command.id == "new-note")
        let onCommand = CommandPaletteSelection(rows: rows, selectedRowID: "section:Folders/new-folder")
        #expect(onCommand.selectedItem?.command.id == "new-folder")
    }

    @Test func selectingAnUnknownCommandKeepsTheSelection() {
        var selection = CommandPaletteSelection(rows: rows)
        selection.select(commandID: "insert-link")
        let found = selection.select(commandID: "nope")
        #expect(found == false)
        #expect(selection.selectedItem?.command.id == "insert-link")
    }

    @Test func selectFirstAndLast() {
        var selection = CommandPaletteSelection(rows: rows)
        selection.selectLast()
        let last = selection.selectedItem?.command.id
        #expect(last == "settings")
        selection.selectFirst()
        let first = selection.selectedItem?.command.id
        #expect(first == "new-note")
    }

    @Test func newSearchSelectsTheBestMatch() {
        var selection = CommandPaletteSelection(rows: rows)
        selection.select(commandID: "new-window")
        selection.update(rows: Fixtures.rows("new"))
        let id = selection.selectedItem?.command.id
        #expect(id == "new-note")
    }

    @Test func updateCanKeepTheSelectedRow() {
        var selection = CommandPaletteSelection(rows: rows)
        selection.select(commandID: "new-window")
        selection.update(rows: Fixtures.rows(""), keepingSelection: true)
        let kept = selection.selectedItem?.command.id
        #expect(kept == "new-window")

        // Gone from the new rows: back to the first command.
        selection.update(rows: Fixtures.rows("folder"), keepingSelection: true)
        let fallback = selection.selectedItem?.command.id
        #expect(fallback == "new-folder")
    }
}
