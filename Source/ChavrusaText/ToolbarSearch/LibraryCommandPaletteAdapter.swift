import CommandPalette
import SwiftUI
#if os(iOS)
import UIKit
#endif

struct LibraryCommandPaletteAdapter: View {
    @Bindable var manager: iOSNavigationManager
    let onDismiss: () -> Void

    private var commands: [Command] {
        // This is the original library's canonical filtered book membership, not another
        // search model or a second search-history store. IDs include the canonical locator.
        let books = manager.libraryViewModel.bookLookup.values.map(\.book)
        var seen = Set<String>()
        return books.sorted { $0.book.localizedStandardCompare($1.book) == .orderedAscending }.compactMap { book in
            let id = book.backendLocator?.persistenceKey ?? "book:\(book.id)"
            guard seen.insert(id).inserted else { return nil }
            return Command(book.book, id: id, section: "ספרים", symbol: "book.closed") {
                manager.openBook(book)
            }
        }
    }

    var body: some View {
        #if os(iOS)
        EscapeCommandHost(onEscape: onDismiss) {
            palette
        }
        #else
        palette
        #endif
    }

    private var palette: some View {
        CommandPaletteView(
            commands: commands,
            placeholder: "חפש ספר בספרייה…",
            initialQuery: manager.libraryViewModel.searchQuery,
            autofocus: true,
            queryBinding: Bindable(manager.libraryViewModel).searchQuery,
            onDismiss: onDismiss
        )
        .accessibilityIdentifier("reader-library-command-palette")
    }
}

#if os(iOS)
/// Keeps the original palette in the responder chain of a real UIKit key command.
/// SwiftUI's cancel shortcut is consumed by the focused text input on iPadOS.
private struct EscapeCommandHost<Content: View>: UIViewControllerRepresentable {
    let onEscape: () -> Void
    let content: Content

    init(onEscape: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.onEscape = onEscape
        self.content = content()
    }

    func makeUIViewController(context: Context) -> EscapeCommandHostingController<Content> {
        EscapeCommandHostingController(rootView: content, onEscape: onEscape)
    }

    func updateUIViewController(_ controller: EscapeCommandHostingController<Content>, context: Context) {
        controller.rootView = content
        controller.onEscape = onEscape
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiViewController: EscapeCommandHostingController<Content>,
        context: Context
    ) -> CGSize? {
        let width = min(proposal.width ?? 640, 640)
        let measured = uiViewController.sizeThatFits(in: CGSize(width: width, height: 10_000))
        return CGSize(width: width, height: measured.height)
    }
}

private final class EscapeCommandHostingController<Content: View>: UIHostingController<Content> {
    var onEscape: () -> Void

    init(rootView: Content, onEscape: @escaping () -> Void) {
        self.onEscape = onEscape
        super.init(rootView: rootView)
    }

    @MainActor @preconcurrency required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var canBecomeFirstResponder: Bool { true }

    override var keyCommands: [UIKeyCommand]? {
        let command = UIKeyCommand(
            input: UIKeyCommand.inputEscape,
            modifierFlags: [],
            action: #selector(handleEscape(_:))
        )
        command.wantsPriorityOverSystemBehavior = true
        // Keep the original SwiftUI hosting controller's other commands.
        return [command] + (super.keyCommands ?? [])
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(handleEscape(_:)) {
            return viewIfLoaded?.window != nil
        }
        return super.canPerformAction(action, withSender: sender)
    }

    @objc private func handleEscape(_ command: UIKeyCommand) {
        // Resign the palette's real input before removing its hosting view.
        view.endEditing(true)
        onEscape()
    }
}
#endif

/// The owner's compactSearchField, with only library-domain text/icon/binding substituted.
struct SafariLibrarySearchField: View {
    @Binding var query: String
    var quickAddressFocused: FocusState<Bool>.Binding
    let onExpand: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: "books.vertical")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("חיפוש בספרייה", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused(quickAddressFocused)
                // A native toolbar's TextField consumes its ancestor's tap.
                // Observe the same tap without replacing the original field
                // or changing the supplied source's appearance/focus behavior.
                .simultaneousGesture(TapGesture().onEnded { _ in onExpand() })
                .submitLabel(.search)
                .onSubmit(onExpand)
                .accessibilityLabel("חיפוש בספרייה")
                .accessibilityIdentifier("reader-library-search-field")
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .contentShape(RoundedRectangle(cornerRadius: 26))
        .onTapGesture(perform: onExpand)
        .modifier(SafariGlass(radius: 26))
    }
}
