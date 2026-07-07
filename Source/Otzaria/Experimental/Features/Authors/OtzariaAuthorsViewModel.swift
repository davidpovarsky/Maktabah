import Foundation

#if canImport(SwiftUI)
import SwiftUI
#endif

@MainActor
final class OtzariaAuthorsViewModel: ObservableObject {
    @Published private(set) var authors: [OtzariaAuthor] = []
    @Published private(set) var booksByAuthor: [Int: [BooksData]] = [:]
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""

    var filteredAuthors: [OtzariaAuthor] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return authors }
        return authors.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    func loadAuthors() async {
        guard authors.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            authors = try await Task.detached(priority: .userInitiated) {
                try OtzariaMaktabahBridge.shared.fetchOtzariaAuthorsWithBookCounts()
            }.value
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func books(for author: OtzariaAuthor) async -> [BooksData] {
        if let cached = booksByAuthor[author.id] {
            return cached
        }

        do {
            let books = try await Task.detached(priority: .userInitiated) {
                try OtzariaMaktabahBridge.shared.fetchBooksForOtzariaAuthor(authorId: author.id)
            }.value
            booksByAuthor[author.id] = books
            return books
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }
}
