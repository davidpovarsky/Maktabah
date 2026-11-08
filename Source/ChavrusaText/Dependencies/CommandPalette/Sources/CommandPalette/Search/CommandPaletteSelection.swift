import Foundation

/// Which row of the palette is selected, and how the arrow keys move it.
///
/// Only commands can be selected: moving skips section headers, and moving past the last command
/// wraps around to the first one (and back). When the list has no commands nothing is selected.
///
/// ```swift
/// var selection = CommandPaletteSelection(rows: rows)   // the first command
/// selection.moveDown()                                  // the next command, past any header
/// selection.moveUp()                                    // back; from the first, the last command
/// selection.selectedItem?.command.action()
/// ```
public struct CommandPaletteSelection: Hashable, Sendable {
    /// All rows, headers included.
    public private(set) var rows: [CommandPaletteRow]
    /// The index of the selected row in ``rows``; always a command, or `nil` when there is none.
    public private(set) var index: Int?

    /// Selects the row with id `selectedRowID`, or else the first command.
    public init(rows: [CommandPaletteRow], selectedRowID: String? = nil) {
        self.rows = rows
        self.index = nil
        if let selectedRowID, select(rowID: selectedRowID) { return }
        index = rows.firstIndex(where: \.isSelectable)
    }

    /// The selected command's row, or `nil` when the list has no commands.
    public var selectedItem: CommandPaletteItem? {
        index.flatMap { rows[$0].item }
    }

    /// The id of the selected row.
    public var selectedRowID: String? {
        selectedItem?.id
    }

    /// Selects the next command, wrapping from the last to the first.
    public mutating func moveDown() {
        move(by: 1)
    }

    /// Selects the previous command, wrapping from the first to the last.
    public mutating func moveUp() {
        move(by: -1)
    }

    /// Selects the first command.
    public mutating func selectFirst() {
        index = rows.firstIndex(where: \.isSelectable)
    }

    /// Selects the last command.
    public mutating func selectLast() {
        index = rows.lastIndex(where: \.isSelectable)
    }

    /// Selects the row with this id. Returns `false`, and keeps the selection, when there is no such
    /// command row.
    @discardableResult
    public mutating func select(rowID: String) -> Bool {
        guard let found = rows.firstIndex(where: { $0.id == rowID && $0.isSelectable }) else { return false }
        index = found
        return true
    }

    /// Selects the first row of this command. Returns `false`, and keeps the selection, when the
    /// command is not listed.
    @discardableResult
    public mutating func select(commandID: Command.ID) -> Bool {
        guard let found = rows.firstIndex(where: { $0.item?.command.id == commandID }) else { return false }
        index = found
        return true
    }

    /// Replaces the rows. With `keepingSelection`, the same row stays selected when it is still
    /// listed; otherwise, and when it is gone, the first command is selected.
    public mutating func update(rows newRows: [CommandPaletteRow], keepingSelection: Bool = false) {
        let previousID = selectedRowID
        rows = newRows
        index = nil
        if keepingSelection, let previousID, select(rowID: previousID) { return }
        selectFirst()
    }

    private mutating func move(by step: Int) {
        let selectable = rows.indices.filter { rows[$0].isSelectable }
        guard !selectable.isEmpty else {
            index = nil
            return
        }
        guard let index, let position = selectable.firstIndex(of: index) else {
            self.index = step > 0 ? selectable.first : selectable.last
            return
        }
        let count = selectable.count
        self.index = selectable[((position + step) % count + count) % count]
    }
}
