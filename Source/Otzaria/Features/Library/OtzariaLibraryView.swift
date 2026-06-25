import SwiftUI

struct OtzariaLibraryView: View {
    @ObservedObject var viewModel: OtzariaLibraryViewModel
    @Binding var selectedBook: OtzariaBook?
    @Binding var showDatabaseImporter: Bool

    @State private var searchText = ""

    var body: some View {
        content
            .navigationTitle("ספרייה")
            .searchable(text: $searchText, placement: .sidebar, prompt: "חיפוש ספר")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("בחר DB", systemImage: "folder") {
                        showDatabaseImporter = true
                    }
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            OtzariaLoadingStateView(title: "טוען ספרייה")
        case .empty(let message):
            ContentUnavailableView {
                Label("אין ספרייה טעונה", systemImage: "books.vertical")
            } description: {
                Text(message)
            } actions: {
                Button("בחר seforim.db", systemImage: "folder") {
                    showDatabaseImporter = true
                }
                .buttonStyle(.borderedProminent)
            }
        case .failed(let message):
            OtzariaErrorStateView(title: "טעינת הספרייה נכשלה", message: message)
        case .loaded:
            libraryList
        }
    }

    private var libraryList: some View {
        List {
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                OutlineGroup(viewModel.nodes, children: \.children) { node in
                    OtzariaLibraryNodeRow(node: node, selectedBook: $selectedBook)
                }
            } else {
                Section("תוצאות") {
                    ForEach(viewModel.searchResults(for: searchText)) { book in
                        Button {
                            selectedBook = book
                        } label: {
                            OtzariaBookResultRow(book: book)
                        }
                    }
                }
            }
        }
    }
}

struct OtzariaLibraryNodeRow: View {
    let node: OtzariaLibraryNode
    @Binding var selectedBook: OtzariaBook?

    var body: some View {
        if let book = node.book {
            Button {
                selectedBook = book
            } label: {
                OtzariaBookResultRow(book: book)
            }
            .buttonStyle(.plain)
        } else {
            Label(node.title, systemImage: node.systemImage)
                .font(.headline)
        }
    }
}

struct OtzariaBookResultRow: View {
    let book: OtzariaBook

    var body: some View {
        Label {
            VStack(alignment: .trailing, spacing: 3) {
                Text(book.title)
                    .font(.body)
                if !book.subtitle.isEmpty {
                    Text(book.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        } icon: {
            Image(systemName: book.hasLinks ? "book.closed.fill" : "book.closed")
        }
    }
}
