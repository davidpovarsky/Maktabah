import SwiftUI

#if os(iOS)
/// Otzaria data rendered through Maktabah's original hierarchical people UI.
struct OtzariaAuthorsModeView: View {
    let onOpenBook: ((BooksData) -> Void)?

    @StateObject private var viewModel = OtzariaAuthorsViewModel()
    @State private var selectedAuthor: OtzariaAuthor?

    init(onOpenBook: ((BooksData) -> Void)? = nil) {
        self.onOpenBook = onOpenBook
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.authors.isEmpty {
                ProgressView("טוען מחברים…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .themeBackground()
            } else if let error = viewModel.errorMessage, viewModel.authors.isEmpty {
                ContentUnavailableView(
                    "טעינת המחברים נכשלה",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
                .themeBackground()
            } else {
                iOSRowiSidebarView(
                    groups: { viewModel.maktabahGroups },
                    searchQuery: viewModel.searchText,
                    onSelectRowi: { rowi in
                        selectedAuthor = viewModel.author(id: rowi.id)
                    },
                    onLoadMore: { group, completion in
                        group.loadMore()
                        completion()
                    }
                )
                .themeTint()
                .ignoresSafeArea(edges: [.vertical])
                .searchable(
                    text: $viewModel.searchText,
                    placement: .navigationBarDrawer(displayMode: .automatic),
                    prompt: "חפש מחבר"
                )
                .themeBackground()
                .navigationDestination(item: $selectedAuthor) { author in
                    OtzariaAuthorBooksView(
                        author: author,
                        viewModel: viewModel,
                        onOpenBook: onOpenBook
                    )
                    .id(author.id)
                }
            }
        }
        .navigationTitle("מחברים")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.layoutDirection, .rightToLeft)
        .task { await viewModel.loadAuthors() }
    }
}

private struct OtzariaAuthorBooksView: View {
    let author: OtzariaAuthor
    @ObservedObject var viewModel: OtzariaAuthorsViewModel
    let onOpenBook: ((BooksData) -> Void)?
    @Environment(iOSNavigationManager.self) private var navigationManager
    @State private var books: [BooksData] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("טוען ספרים…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .themeBackground()
            } else if books.isEmpty {
                ContentUnavailableView("לא נמצאו ספרים", systemImage: "books.vertical")
                    .themeBackground()
            } else {
                List(books, id: \.id) { book in
                    Button {
                        if let onOpenBook { onOpenBook(book) }
                        else { navigationManager.openBook(book) }
                    } label: {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(book.book)
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            if !book.info.isEmpty {
                                Text(book.info)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                        .contentShape(Rectangle())
                        .environment(\.layoutDirection, .rightToLeft)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(author.name)
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.layoutDirection, .rightToLeft)
        .task(id: author.id) {
            isLoading = true
            books = await viewModel.books(for: author)
            isLoading = false
        }
    }
}
#endif
