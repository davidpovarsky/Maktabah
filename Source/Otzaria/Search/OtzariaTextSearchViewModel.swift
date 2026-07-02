import Foundation
import Combine

@MainActor
final class OtzariaTextSearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var results: [SearchResultItem] = []
    @Published var mode: OtzariaSearchMode = .advanced
    @Published var order: OtzariaSearchOrder = .catalogue
    @Published var isSearching = false
    @Published var isIndexing = false
    @Published var status: OtzariaSearchIndexStatus = .unavailable
    @Published var errorMessage: String?

    private let repository = OtzariaTantivySearchRepository.shared
    private let indexer = OtzariaSearchIndexer()
    private var currentTask: Task<Void, Never>?

    func refreshStatus() {
        guard let path = OtzariaMaktabahBridge.shared.databasePath else {
            status = .unavailable
            return
        }
        do {
            if OtzariaSearchIndexManager.shared.isIndexCurrent(databasePath: path) {
                let count = try repository.documentCount(databasePath: path)
                status = .ready(documentCount: count)
            } else {
                status = .missing
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func rebuildIndex() {
        currentTask?.cancel()
        currentTask = Task {
            guard let path = OtzariaMaktabahBridge.shared.databasePath else {
                status = .unavailable
                return
            }
            isIndexing = true
            errorMessage = nil
            do {
                let count = try await indexer.rebuildIndex(databasePath: path) { [weak self] progress in
                    Task { @MainActor in
                        self?.status = .indexing(
                            processedBooks: progress.processedBooks,
                            totalBooks: progress.totalBooks,
                            processedLines: progress.processedLines
                        )
                    }
                }
                status = .ready(documentCount: count)
            } catch {
                errorMessage = error.localizedDescription
                status = .failed(error.localizedDescription)
            }
            isIndexing = false
        }
    }

    func search() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            return
        }
        guard let path = OtzariaMaktabahBridge.shared.databasePath else {
            errorMessage = OtzariaSearchError.databaseNotSelected.localizedDescription
            status = .unavailable
            return
        }
        if !OtzariaSearchIndexManager.shared.isIndexCurrent(databasePath: path) {
            status = .missing
            errorMessage = "האינדקס לא מוכן. לחץ 'בנה/רענן אינדקס' לפני החיפוש."
            return
        }

        isSearching = true
        errorMessage = nil
        let request = OtzariaSearchRequest(
            query: OtzariaSearchTextNormalizer.removeHebrewNikud(trimmed),
            mode: mode,
            facets: ["/"],
            limit: 100,
            offset: 0,
            order: order,
            distance: mode == .fuzzy ? 1 : 0
        )

        Task.detached(priority: .userInitiated) { [repository] in
            do {
                let found = try repository.search(databasePath: path, request: request)
                await MainActor.run {
                    self.results = found
                    self.isSearching = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.results = []
                    self.isSearching = false
                }
            }
        }
    }

    func clear() {
        query = ""
        results = []
        errorMessage = nil
    }
}
