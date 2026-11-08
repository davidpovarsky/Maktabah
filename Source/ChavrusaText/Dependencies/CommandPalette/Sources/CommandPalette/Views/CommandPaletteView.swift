import SwiftUI

/// The command palette: a search field, the matching commands in sections and a footer with the
/// keys to use.
///
/// - Type to search; matched characters are highlighted.
/// - ↑ and ↓ move the selection (skipping section headers, wrapping at the ends), ↩ runs the
///   selected command, ⎋ closes the palette. A click or tap runs a command too.
/// - With an empty search field, recently run commands are listed first.
///
/// Usually you show it with ``SwiftUI/View/commandPalette(isPresented:commands:recents:shortcut:placeholder:)``.
/// Use the view directly to put it somewhere else, or with
/// ``SwiftUI/View/commandPalette(isPresented:shortcut:palette:)`` to change its parameters.
@MainActor
public struct CommandPaletteView: View {
    private let commands: [Command]
    private let placeholder: String
    private let autofocus: Bool
    private let queryBinding: Binding<String>?
    private let onDismiss: () -> Void

    @ObservedObject private var recents: RecentCommandsStore
    @State private var query: String
    @State private var selection: CommandPaletteSelection
    #if os(iOS)
    @State private var isSearchFieldFocused = false
    #else
    @FocusState private var isSearchFieldFocused: Bool
    #endif

    /// Creates a palette.
    /// - Parameters:
    ///   - commands: All commands, in the order they are listed when the search field is empty.
    ///   - recents: Where recently run commands are remembered; ``RecentCommandsStore/shared`` when `nil`.
    ///   - placeholder: The search field's placeholder.
    ///   - initialQuery: Text already in the search field, for example to restore a search.
    ///   - initialSelection: The id of the command selected first; the first command when `nil`.
    ///   - autofocus: Puts the cursor in the search field when the palette appears.
    ///   - onDismiss: Called when the palette should close: after ⎋ and before a command runs.
    public init(
        commands: [Command],
        recents: RecentCommandsStore? = nil,
        placeholder: String = "Search for a command…",
        initialQuery: String = "",
        initialSelection: Command.ID? = nil,
        autofocus: Bool = true,
        queryBinding: Binding<String>? = nil,
        onDismiss: @escaping () -> Void = {}
    ) {
        let store = recents ?? .shared
        self.commands = commands
        self.placeholder = placeholder
        self.autofocus = autofocus
        self.queryBinding = queryBinding
        self.onDismiss = onDismiss
        self._recents = ObservedObject(wrappedValue: store)
        self._query = State(initialValue: queryBinding?.wrappedValue ?? initialQuery)

        let rows = CommandPaletteResults.rows(for: CommandPaletteResults.sections(
            for: queryBinding?.wrappedValue ?? initialQuery, in: commands, recentIDs: store.ids
        ))
        var selection = CommandPaletteSelection(rows: rows)
        if let initialSelection {
            selection.select(commandID: initialSelection)
        }
        self._selection = State(initialValue: selection)
    }

    public var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            results
            Divider()
            footer
        }
        .frame(maxWidth: 640)
        .paletteBackground(cornerRadius: 22)
        .shadow(color: .black.opacity(0.22), radius: 30, y: 14)
        .task {
            // After the palette is on screen; focus set during the first layout can be lost.
            if autofocus {
                isSearchFieldFocused = true
            }
        }
        .onChange(of: queryBinding?.wrappedValue) { _, value in
            if let value, value != query { query = value }
        }
        .onChange(of: query) { _, _ in
            if queryBinding?.wrappedValue != query { queryBinding?.wrappedValue = query }
            // A new search selects its best match.
            selection.update(rows: makeRows())
        }
        .onChange(of: commands) { _, _ in
            selection.update(rows: makeRows(), keepingSelection: true)
        }
        #if os(macOS)
        .onExitCommand(perform: onDismiss)
        #endif
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Command palette"))
    }

    // MARK: - Search field

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)

            #if os(iOS)
            PaletteNativeSearchField(
                text: $query,
                isFocused: $isSearchFieldFocused,
                placeholder: placeholder, onSubmit: runSelection, onEscape: onDismiss,
                onMoveUp: { selection.moveUp() }, onMoveDown: { selection.moveDown() }
            )
            #else
            TextField(placeholder, text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 20))
                .focused($isSearchFieldFocused)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .submitLabel(.go)
                #endif
                .onSubmit(runSelection)
                .onKeyPress(.downArrow) {
                    selection.moveDown()
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    selection.moveUp()
                    return .handled
                }
                .onKeyPress(.escape) {
                    onDismiss()
                    return .handled
                }
            #endif

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear search"))
            }

            KeyCap(label: "esc")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
    }

    // MARK: - Results

    @ViewBuilder
    private var results: some View {
        if selection.rows.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(selection.rows) { row in
                            switch row {
                            case .header(_, let title):
                                SectionHeaderView(title: title)
                            case .command(let item):
                                Button {
                                    run(item)
                                } label: {
                                    CommandRowView(item: item, isSelected: item.id == selection.selectedRowID)
                                }
                                .buttonStyle(.plain)
                                .id(item.id)
                                .accessibilityAddTraits(item.id == selection.selectedRowID ? .isSelected : [])
                            }
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: 420)
                .onChange(of: selection.selectedRowID) { _, id in
                    guard let id else { return }
                    proxy.scrollTo(id)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No commands match “\(query)”")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 14) {
            hint(["↑", "↓"], "Navigate")
            hint(["↩"], "Run")
            hint(["esc"], "Close")
            Spacer()
            Text(countLabel)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    private func hint(_ keys: [String], _ label: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { KeyCap(label: $0) }
            Text(label)
                .foregroundStyle(.secondary)
        }
    }

    private var countLabel: String {
        let count = Set(selection.rows.compactMap { $0.item?.command.id }).count
        return count == 1 ? "1 command" : "\(count) commands"
    }

    // MARK: - Actions

    private func makeRows() -> [CommandPaletteRow] {
        CommandPaletteResults.rows(for: CommandPaletteResults.sections(
            for: query, in: commands, recentIDs: recents.ids
        ))
    }

    private func runSelection() {
        guard let item = selection.selectedItem else { return }
        run(item)
    }

    /// Remembers the command, closes the palette, then runs the command.
    private func run(_ item: CommandPaletteItem) {
        let command = item.command
        recents.record(command)
        onDismiss()
        command.action()
    }
}
