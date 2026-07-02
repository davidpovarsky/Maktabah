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
    @Published var indexStatusDetail: String?

    private let repository = OtzariaTantivySearchRepository.shared
    private let indexingService = OtzariaSearchIndexingService.shared
    private var currentTask: Task<Void, Never>?

    func refreshStatus() {
        OtzariaIndexFileLogger.log("viewModel refreshStatus start")
        if isIndexing {
            OtzariaIndexFileLogger.log("viewModel refreshStatus skipped because indexing active")
            return
        }
        guard let path = OtzariaMaktabahBridge.shared.databasePath else {
            OtzariaIndexFileLogger.log("viewModel refreshStatus databasePath missing")
            status = .unavailable
            indexStatusDetail = nil
            return
        }

        do {
            let isCurrent = OtzariaSearchIndexManager.shared.isIndexCurrent(databasePath: path)
            OtzariaIndexFileLogger.log("viewModel refreshStatus isIndexCurrent=\(isCurrent)")
            if isCurrent {
                let count = try repository.documentCount(databasePath: path)
                OtzariaIndexFileLogger.log("viewModel refreshStatus documentCount=\(count)")
                status = .ready(documentCount: count)
                indexStatusDetail = nil
            } else {
                let count = partialDocumentCount(databasePath: path)
                OtzariaIndexFileLogger.log("viewModel refreshStatus partialDocumentCount=\(count)")
                status = .missing
                indexStatusDetail = count > 0 ? "אינדקס חלקי קיים — ניתן להמשיך אינדוקס" : nil
            }
        } catch {
            OtzariaIndexFileLogger.logError("viewModel refreshStatus failed", error: error)
            status = .failed(error.localizedDescription)
            indexStatusDetail = nil
        }
    }

    func rebuildIndex() {
        OtzariaIndexFileLogger.clearLog()
        OtzariaIndexFileLogger.log("manual rebuildIndex requested")
        currentTask?.cancel()
        guard let path = OtzariaMaktabahBridge.shared.databasePath else {
            OtzariaIndexFileLogger.log("viewModel rebuildIndex databasePath missing")
            status = .unavailable
            indexStatusDetail = nil
            return
        }

        isIndexing = true
        status = .indexing(processedBooks: 0, totalBooks: 0, processedLines: 0)
        errorMessage = nil
        indexStatusDetail = nil

        currentTask = Task.detached(priority: .utility) { [indexingService] in
            OtzariaIndexFileLogger.log("viewModel indexing task started")
            do {
                let count = try await indexingService.rebuildIndex(databasePath: path) { progress in
                    if progress.processedBooks % 25 == 0 || progress.processedBooks == progress.totalBooks {
                        OtzariaIndexFileLogger.log("viewModel progress update processedBooks=\(progress.processedBooks) totalBooks=\(progress.totalBooks) processedLines=\(progress.processedLines)")
                    }
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
                    self.indexStatusDetail = nil
                    self.isIndexing = false
                    self.currentTask = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    OtzariaIndexFileLogger.log("viewModel indexing cancelled CancellationError")
                    self.errorMessage = OtzariaSearchError.indexingCancelled.localizedDescription
                    self.status = .cancelled
                    self.indexStatusDetail = nil
                    self.isIndexing = false
                    self.currentTask = nil
                }
            } catch OtzariaSearchError.indexingCancelled {
                await MainActor.run {
                    OtzariaIndexFileLogger.log("viewModel indexing cancelled OtzariaSearchError.indexingCancelled")
                    self.errorMessage = OtzariaSearchError.indexingCancelled.localizedDescription
                    self.status = .cancelled
                    self.indexStatusDetail = nil
                    self.isIndexing = false
                    self.currentTask = nil
                }
            } catch {
                await MainActor.run {
                    OtzariaIndexFileLogger.logError("viewModel indexing failed", error: error)
                    self.errorMessage = error.localizedDescription
                    self.status = .failed(error.localizedDescription)
                    self.indexStatusDetail = nil
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
        indexStatusDetail = nil
        isIndexing = false
    }

    func search() {
        OtzariaIndexFileLogger.log("viewModel search called")
        if isIndexing {
            OtzariaIndexFileLogger.log("viewModel search blocked because indexing active")
            errorMessage = "האינדוקס פעיל — המתן לסיום או בטל אותו לפני חיפוש."
            return
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            return
        }
        guard let path = OtzariaMaktabahBridge.shared.databasePath else {
            errorMessage = OtzariaSearchError.databaseNotSelected.localizedDescription
            status = .unavailable
            indexStatusDetail = nil
            return
        }

        if !OtzariaSearchIndexManager.shared.isIndexCurrent(databasePath: path) {
            let count = partialDocumentCount(databasePath: path)
            if count == 0 {
                OtzariaIndexFileLogger.log("viewModel search blocked because index missing path=\(path)")
                status = .missing
                indexStatusDetail = nil
                errorMessage = "Index is not ready. Build or resume the Otzaria index before searching."
                return
            }
            status = .missing
            indexStatusDetail = "אינדקס חלקי קיים — ניתן להמשיך אינדוקס"
            OtzariaIndexFileLogger.log("viewModel search allowed partial index documentCount=\(count)")
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

    func indexLogCopyText() -> String {
        let databasePath = OtzariaMaktabahBridge.shared.databasePath
        let indexURL = databasePath.map { OtzariaSearchIndexManager.shared.indexURL(for: $0) }
        let documentCount = isIndexing ? nil : databasePath.map { partialDocumentCount(databasePath: $0) }
        let logPath = OtzariaIndexFileLogger.logFileURL()?.path ?? "unavailable"
        return """
        Log file: \(logPath)
        Database path: \(databasePath ?? "unavailable")
        Index path: \(indexURL?.path ?? "unavailable")
        Document count: \(isIndexing ? "indexing" : (documentCount.map { String($0) } ?? "unavailable"))

        \(OtzariaIndexFileLogger.readLogText())
        """
    }

    private func partialDocumentCount(databasePath: String) -> UInt64 {
        let indexURL = OtzariaSearchIndexManager.shared.indexURL(for: databasePath)
        guard FileManager.default.fileExists(atPath: indexURL.path) else { return 0 }
        return (try? repository.documentCount(databasePath: databasePath)) ?? 0
    }
}
