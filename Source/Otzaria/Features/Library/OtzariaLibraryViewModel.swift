import Foundation

@MainActor
final class OtzariaLibraryViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case loaded
        case empty(String)
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var nodes: [OtzariaLibraryNode] = []
    @Published private(set) var books: [OtzariaBook] = []

    func load(using repository: (any OtzariaLibraryRepository)?) async {
        guard let repository else {
            nodes = []
            books = []
            state = .empty("בחר את seforim.db כדי לטעון את הספרייה")
            return
        }

        state = .loading
        do {
            let result = try await repository.loadLibrary()
            nodes = result.nodes
            books = result.books
            state = result.books.isEmpty ? .empty("לא נמצאו ספרים במסד הנתונים") : .loaded
        } catch {
            nodes = []
            books = []
            state = .failed(error.localizedDescription)
        }
    }

    func searchResults(for text: String) -> [OtzariaBook] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return Array(
            books.lazy.filter { book in
                book.title.localizedCaseInsensitiveContains(query)
                || (book.filePath?.localizedCaseInsensitiveContains(query) ?? false)
            }.prefix(200)
        )
    }
}
