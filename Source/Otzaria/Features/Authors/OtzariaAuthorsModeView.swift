import SwiftUI

#if os(iOS)
struct OtzariaAuthorsModeView: View {
    let onOpenBook: ((BooksData) -> Void)?

    init(onOpenBook: ((BooksData) -> Void)? = nil) {
        self.onOpenBook = onOpenBook
    }

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
                            OtzariaAuthorBooksView(
                                author: author,
                                viewModel: viewModel,
                                onOpenBook: onOpenBook
                            )
                            .id(author.id)
                        } label: {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(author.name)
                                    .font(.headline)
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: .infinity, alignment: .trailing)

                                Text("\(author.bookCount) ספרים")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .contentShape(Rectangle())
                            .environment(\.layoutDirection, .rightToLeft)
                        }
                        .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
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
        .environment(\.layoutDirection, .rightToLeft)
        .task {
            await viewModel.loadAuthors()
        }
    }
}

private struct OtzariaAuthorBooksView: View {
    let author: OtzariaAuthor
    @ObservedObject var viewModel: OtzariaAuthorsViewModel
    let onOpenBook: ((BooksData) -> Void)?
    @Environment(iOSNavigationManager.self) private var navigationManager
    @Environment(\.dismiss) private var dismiss
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
                        if let onOpenBook {
                            onOpenBook(book)
                        } else {
                            navigationManager.openBook(book)
                        }
                        dismiss()
                    } label: {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(book.book)
                                .font(.headline)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: .infinity, alignment: .trailing)

                            if !book.info.isEmpty {
                                Text(book.info)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
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
            books = []
            books = await viewModel.books(for: author)
            isLoading = false
        }
    }
}
#endif
