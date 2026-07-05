import SwiftUI

#if os(iOS)
struct OtzariaAuthorsModeView: View {
    @StateObject private var viewModel = OtzariaAuthorsViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.authors.isEmpty {
                ProgressView("טוען מחברים...")
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
                List {
                    ForEach(viewModel.filteredAuthors) { author in
                        NavigationLink {
                            OtzariaAuthorBooksView(author: author, viewModel: viewModel)
                        } label: {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(author.name)
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .trailing)

                                Text("\(author.bookCount) ספרים")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .searchable(
                    text: $viewModel.searchText,
                    placement: .navigationBarDrawer(displayMode: .automatic),
                    prompt: "חפש מחבר"
                )
                .themeBackground()
            }
        }
        .navigationTitle("מחברים")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadAuthors()
        }
    }
}

private struct OtzariaAuthorBooksView: View {
    let author: OtzariaAuthor
    @ObservedObject var viewModel: OtzariaAuthorsViewModel
    @Environment(iOSNavigationManager.self) private var navigationManager
    @State private var books: [BooksData] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("טוען ספרים...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .themeBackground()
            } else if books.isEmpty {
                ContentUnavailableView("לא נמצאו ספרים", systemImage: "books.vertical")
                    .themeBackground()
            } else {
                List(books, id: \.id) { book in
                    Button {
                        navigationManager.openBook(book)
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
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(author.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            books = await viewModel.books(for: author)
            isLoading = false
        }
    }
}
#endif
