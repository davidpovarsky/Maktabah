import CommandPalette
import SwiftUI

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
