import Foundation

@MainActor
final class OtzariaReaderViewModel: ObservableObject {
    @Published private(set) var lines: [OtzariaBookLine] = []
    @Published private(set) var tocEntries: [OtzariaTOCEntry] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let book: OtzariaBook
    private let repository: any OtzariaBookTextRepository
    private let pageSize = 180
    private var nextLineIndex = 0
    private var allLoaded = false

    init(book: OtzariaBook, repository: any OtzariaBookTextRepository) {
        self.book = book
        self.repository = repository
    }

    func loadInitial() async {
        guard lines.isEmpty else { return }
        await loadTOC()
        await loadNextPage()
    }

    func loadNextPage() async {
        guard !isLoading, !allLoaded else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let newLines = try await repository.lines(bookId: book.id, startingAtLineIndex: nextLineIndex, limit: pageSize)
            lines.append(contentsOf: newLines)
            if let last = newLines.last {
                nextLineIndex = last.lineIndex + 1
            }
            allLoaded = newLines.count < pageSize
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func jump(to entry: OtzariaTOCEntry) async {
        guard let lineIndex = entry.lineIndex else { return }
        lines = []
        nextLineIndex = max(0, lineIndex)
        allLoaded = false
        await loadNextPage()
    }

    private func loadTOC() async {
        do {
            tocEntries = try await repository.tableOfContents(bookId: book.id)
        } catch {
            tocEntries = []
        }
    }
}
