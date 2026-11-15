import SwiftUI
#if os(iOS)
import UIKit
#endif

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
            PaletteSearchTextField(text: $query, placeholder: placeholder,
                wantsFocus: isSearchFieldFocused,
                onFocusChange: { focused in
                    if isSearchFieldFocused != focused { isSearchFieldFocused = focused }
                },
                onSubmit: runSelection, onEscape: onDismiss,
                onUp: { selection.moveUp() }, onDown: { selection.moveDown() })
            #else
            TextField(placeholder, text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 20))
                .focused($isSearchFieldFocused)
                .autocorrectionDisabled()
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

            Button(action: onDismiss) {
                KeyCap(label: "esc")
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel(Text("Close command palette"))
            .accessibilityIdentifier("command-palette-close")
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

#if os(iOS)
/// The palette's actual text input owns keyboard commands, rather than relying
/// on an ancestor hosting controller while text input has keyboard focus.
@MainActor
private struct PaletteSearchTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let wantsFocus: Bool
    let onFocusChange: (Bool) -> Void
    let onSubmit: () -> Void
    let onEscape: () -> Void
    let onUp: () -> Void
    let onDown: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PaletteTextField {
        let field = PaletteTextField()
        field.borderStyle = .none
        field.backgroundColor = .clear
        field.font = .systemFont(ofSize: 20)
        field.textColor = .label
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.returnKeyType = .go
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        return field
    }

    func updateUIView(_ field: PaletteTextField, context: Context) {
        context.coordinator.parent = self
        if field.text != text, field.markedTextRange == nil { field.text = text }
        field.placeholder = placeholder
        field.accessibilityLabel = placeholder
        field.textAlignment = context.environment.layoutDirection == .rightToLeft ? .right : .left
        field.semanticContentAttribute = context.environment.layoutDirection == .rightToLeft ? .forceRightToLeft : .forceLeftToRight
        field.onEscape = onEscape
        field.onUp = onUp
        field.onDown = onDown
        field.wantsFocus = wantsFocus
        field.reconcileFocus()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: PaletteTextField, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? max(0, uiView.intrinsicContentSize.width), height: uiView.intrinsicContentSize.height)
    }

    static func dismantleUIView(_ field: PaletteTextField, coordinator: Coordinator) {
        field.delegate = nil
        field.onEscape = nil
        field.onUp = nil
        field.onDown = nil
        field.resignFirstResponder()
    }

    @MainActor final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: PaletteSearchTextField
        init(_ parent: PaletteSearchTextField) { self.parent = parent }

        @objc func editingChanged(_ field: UITextField) {
            let value = field.text ?? ""
            if parent.text != value { parent.text = value }
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.onFocusChange(true)
        }
        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.onFocusChange(false)
        }
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onSubmit()
            return false
        }
    }
}

@MainActor
private final class PaletteTextField: UITextField {
    var onEscape: (() -> Void)?
    var onUp: (() -> Void)?
    var onDown: (() -> Void)?
    var wantsFocus = false

    override func didMoveToWindow() {
        super.didMoveToWindow()
        reconcileFocus()
    }

    func reconcileFocus() {
        guard window != nil else { return }
        if wantsFocus, !isFirstResponder { becomeFirstResponder() }
        else if !wantsFocus, isFirstResponder { resignFirstResponder() }
    }

    override var keyCommands: [UIKeyCommand]? {
        // The visible SwiftUI cancel Button owns the Escape shortcut. Do not
        // also register Escape on the focused field. Keep one registered
        // Escape shortcut in the hosting responder chain.
        let commands = [
            UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [], action: #selector(up(_:))),
            UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [], action: #selector(down(_:)))
        ]
        for command in commands { command.wantsPriorityOverSystemBehavior = true }
        return commands + (super.keyCommands ?? [])
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(up(_:)) || action == #selector(down(_:)) {
            return isFirstResponder && window != nil
        }
        return super.canPerformAction(action, withSender: sender)
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let remaining = presses.filter { $0.key?.keyCode != .keyboardEscape }
        if remaining.count != presses.count { dismissFromKeyboard() }
        if !remaining.isEmpty { super.pressesBegan(Set(remaining), with: event) }
    }

    override func insertText(_ text: String) {
        // Accept Escape delivered directly through UIKeyInput or presses,
        // without inserting the control character in the query.
        if text == "\u{1b}" { dismissFromKeyboard() }
        else { super.insertText(text) }
    }

    private func dismissFromKeyboard() {
        guard isFirstResponder else { return }
        resignFirstResponder()
        onEscape?()
    }

    @objc private func up(_ command: UIKeyCommand) { onUp?() }
    @objc private func down(_ command: UIKeyCommand) { onDown?() }
}

#endif
