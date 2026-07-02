import Foundation
import Combine

@MainActor
final class OtzariaTextSearchViewModel: ObservableObject, @unchecked Sendable {
    @Published var query: String = ""
    @Published var results: [SearchResultItem] = []
    @Published var mode: OtzariaSearchMode = .advanced
    @Published var order: OtzariaSearchOrder = .catalogue
    @Published var isSearching = false
    @Published var isIndexing = false
    @Published var status: OtzariaSearchIndexStatus = .unavailable
    @Published var errorMessage: String?

    private let repository = OtzariaTantivySearchRepository.shared
    private let indexingService = OtzariaSearchIndexingService.shared
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
        guard let path = OtzariaMaktabahBridge.shared.databasePath else {
            status = .unavailable
            return
        }

        isIndexing = true
        status = .indexing(processedBooks: 0, totalBooks: 0, processedLines: 0)
        errorMessage = nil

        currentTask = Task.detached(priority: .utility) { [indexingService] in
            do {
                let count = try await indexingService.rebuildIndex(databasePath: path) { progress in
                    Task { @MainActor in
                        guard self.currentTask?.isCancelled == false else { return }
                        self.status = .indexing(
                            processedBooks: progress.processedBooks,
                            totalBooks: progress.totalBooks,
                            processedLines: progress.processedLines
                        )
                    }
                }
                try Task.checkCancellation()
                await MainActor.run {
                    self.status = .ready(documentCount: count)
                    self.isIndexing = false
                    self.currentTask = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.errorMessage = OtzariaSearchError.indexingCancelled.localizedDescription
                    self.status = .cancelled
                    self.isIndexing = false
                    self.currentTask = nil
                }
            } catch OtzariaSearchError.indexingCancelled {
                await MainActor.run {
                    self.errorMessage = OtzariaSearchError.indexingCancelled.localizedDescription
                    self.status = .cancelled
                    self.isIndexing = false
                    self.currentTask = nil
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.status = .failed(error.localizedDescription)
                    self.isIndexing = false
                    self.currentTask = nil
                }
            }
        }
    }

    func cancelIndexing() {
        currentTask?.cancel()
        errorMessage = OtzariaSearchError.indexingCancelled.localizedDescription
        status = .cancelled
        isIndexing = false
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
