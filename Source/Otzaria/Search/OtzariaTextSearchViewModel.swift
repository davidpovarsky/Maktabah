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
        OtzariaIndexFileLogger.log("viewModel refreshStatus start")
        guard let path = OtzariaMaktabahBridge.shared.databasePath else {
            OtzariaIndexFileLogger.log("viewModel refreshStatus databasePath missing")
            status = .unavailable
            return
        }
        OtzariaIndexFileLogger.log("viewModel refreshStatus databasePath exists path=\(path)")
        do {
            let isCurrent = OtzariaSearchIndexManager.shared.isIndexCurrent(databasePath: path)
            OtzariaIndexFileLogger.log("viewModel refreshStatus isIndexCurrent=\(isCurrent)")
            if isCurrent {
                let count = try repository.documentCount(databasePath: path)
                OtzariaIndexFileLogger.log("viewModel refreshStatus documentCount=\(count)")
                status = .ready(documentCount: count)
            } else {
                status = .missing
            }
        } catch {
            OtzariaIndexFileLogger.logError("viewModel refreshStatus failed", error: error)
            status = .failed(error.localizedDescription)
        }
    }

    func rebuildIndex() {
        OtzariaIndexFileLogger.clearLog()
        OtzariaIndexFileLogger.log("manual rebuildIndex requested")
        OtzariaIndexFileLogger.log("viewModel rebuildIndex called")
        currentTask?.cancel()
        guard let path = OtzariaMaktabahBridge.shared.databasePath else {
            OtzariaIndexFileLogger.log("viewModel rebuildIndex databasePath missing")
            status = .unavailable
            return
        }
        OtzariaIndexFileLogger.log("viewModel rebuildIndex databasePath=\(path)")

        isIndexing = true
        status = .indexing(processedBooks: 0, totalBooks: 0, processedLines: 0)
        errorMessage = nil

        currentTask = Task.detached(priority: .utility) { [indexingService] in
            OtzariaIndexFileLogger.log("viewModel indexing task started")
            do {
                let count = try await indexingService.rebuildIndex(databasePath: path) { progress in
                    OtzariaIndexFileLogger.log("viewModel progress update processedBooks=\(progress.processedBooks) totalBooks=\(progress.totalBooks) processedLines=\(progress.processedLines)")
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
                    OtzariaIndexFileLogger.log("viewModel indexing success count=\(count)")
                    self.status = .ready(documentCount: count)
                    self.isIndexing = false
                    self.currentTask = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    OtzariaIndexFileLogger.log("viewModel indexing cancelled CancellationError")
                    self.errorMessage = OtzariaSearchError.indexingCancelled.localizedDescription
                    self.status = .cancelled
                    self.isIndexing = false
                    self.currentTask = nil
                }
            } catch OtzariaSearchError.indexingCancelled {
                await MainActor.run {
                    OtzariaIndexFileLogger.log("viewModel indexing cancelled OtzariaSearchError.indexingCancelled")
                    self.errorMessage = OtzariaSearchError.indexingCancelled.localizedDescription
                    self.status = .cancelled
                    self.isIndexing = false
                    self.currentTask = nil
                }
            } catch {
                await MainActor.run {
                    OtzariaIndexFileLogger.logError("viewModel indexing failed", error: error)
                    self.errorMessage = error.localizedDescription
                    self.status = .failed(error.localizedDescription)
                    self.isIndexing = false
                    self.currentTask = nil
                }
            }
        }
    }

    func cancelIndexing() {
        OtzariaIndexFileLogger.log("viewModel cancelIndexing called")
        currentTask?.cancel()
        errorMessage = OtzariaSearchError.indexingCancelled.localizedDescription
        status = .cancelled
        isIndexing = false
    }

    func search() {
        OtzariaIndexFileLogger.log("viewModel search called")
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            OtzariaIndexFileLogger.log("viewModel search ignored empty query")
            results = []
            return
        }
        guard let path = OtzariaMaktabahBridge.shared.databasePath else {
            OtzariaIndexFileLogger.log("viewModel search blocked databasePath missing")
            errorMessage = OtzariaSearchError.databaseNotSelected.localizedDescription
            status = .unavailable
            return
        }
        if !OtzariaSearchIndexManager.shared.isIndexCurrent(databasePath: path) {
            OtzariaIndexFileLogger.log("viewModel search blocked because index missing path=\(path)")
            status = .missing
            errorMessage = "האינדקס לא מוכן. לחץ 'בנה/רענן אינדקס' לפני החיפוש."
            return
        }

        isSearching = true
        errorMessage = nil
        OtzariaIndexFileLogger.log("viewModel search started path=\(path) mode=\(mode.rawValue) order=\(order.rawValue)")
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
                    OtzariaIndexFileLogger.log("viewModel search success resultCount=\(found.count)")
                    self.results = found
                    self.isSearching = false
                }
            } catch {
                await MainActor.run {
                    OtzariaIndexFileLogger.logError("viewModel search failed", error: error)
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
