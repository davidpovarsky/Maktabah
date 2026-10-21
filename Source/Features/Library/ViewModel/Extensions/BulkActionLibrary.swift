//
//  BulkActionLibrary.swift
//  Maktabah
//

import Foundation

extension LibraryViewModel {
    // MARK: - Bulk Download Actions

    func cancelBulkDownload() {
        bulkDownloadTask?.cancel()
        bulkDownloadTask = nil
        isBulkDownloading = false
        Task {
            if let provider = await BackendCoordinator.shared.offlineWorkProvider() {
                await provider.cancelWorkInstall()
            } else {
                await BookDownloadManager.shared.cancelAllDownloads()
            }
        }
    }

    func startBulkDownload(
        progressState: BundleArchiveDownloadProgressState,
        onFinished: @escaping (String?) -> Void
    ) {
        if OtzariaLibraryPolicy.finishBulkDownloadIfEnabled(onFinished: onFinished) {
            return
        }
        let books = selectedDownloadBooks
        guard !books.isEmpty else { return }
        isBulkDownloading = true
        progressState.mode = .downloading
        progressState.title = String(localized: .Library.downloadBook)
        progressState.message = String(localized: .Library.beginDownloading)
        progressState.detail = "0 / \(books.count)"
        progressState.progress = 0

        if let provider = BackendCoordinator.shared.offlineWorkProvider() {
            let workKeys = Set(books.compactMap { $0.backendLocator?.workKey })
            bulkDownloadTask = Task { [weak self] in
                do {
                    try await provider.install(workKeys: workKeys) { update in
                        Task { @MainActor in
                            progressState.message = update.phase.rawValue.capitalized
                            progressState.detail = update.totalBytes > 0
                                ? ByteCountFormatter.string(fromByteCount: update.completedBytes, countStyle: .file)
                                : ""
                            progressState.progress = update.totalBytes > 0
                                ? Double(update.completedBytes) / Double(update.totalBytes) : 0
                        }
                    }
                    await LibraryOfflineAvailabilityController.shared.refresh()
                    await MainActor.run {
                        self?.isBulkDownloading = false
                        self?.updateDisplayedCategories()
                        onFinished(nil)
                    }
                } catch is CancellationError {
                    await MainActor.run { self?.isBulkDownloading = false; onFinished(nil) }
                } catch {
                    await MainActor.run { self?.isBulkDownloading = false; onFinished(error.localizedDescription) }
                }
            }
            return
        }

        bulkDownloadTask = Task { [weak self] in
            guard let self else { return }
            await runBulkDownload(books: books, progressState: progressState, onFinished: onFinished)
        }
    }

    private func runBulkDownload(
        books: [BooksData],
        progressState: BundleArchiveDownloadProgressState,
        onFinished: @escaping (String?) -> Void
    ) async {
        var (downloadResults, stoppedByNetwork) = await performBulkDownloadPhase(
            books: books,
            progressState: progressState
        )

        let successfulDownloads = books.filter {
            if case .success = downloadResults[$0.id] {
                return true
            }
            return false
        }

        let completedIntegrations = await performBulkIntegrationPhase(
            successfulDownloads: successfulDownloads,
            downloadResults: &downloadResults,
            progressState: progressState
        )

        let failedCount = books.count(where: {
            if case .failure = downloadResults[$0.id] {
                return true
            }
            return false
        })

        selectedBookIds.subtract(books.map(\.id))
        isBulkDownloading = false
        bulkDownloadTask = nil

        let message = buildBulkCompletionMessage(
            isCancelled: Task.isCancelled,
            stoppedByNetwork: stoppedByNetwork,
            completedIntegrations: completedIntegrations,
            failedCount: failedCount
        )
        onFinished(message)
    }

    private func performBulkDownloadPhase(
        books: [BooksData],
        progressState: BundleArchiveDownloadProgressState
    ) async -> ([Int: Result<URL, Error>], Bool) {
        let (downloadResults, stoppedByNetwork) = await BoundedBulkDownloader.run(
            books: books,
            onProgressUpdate: { report in
                Task { @MainActor in
                    Self.updateBulkProgressUI(report: report, progressState: progressState)
                }
            },
            onBookCompleted: { _, _, report in
                Task { @MainActor in
                    Self.updateBulkProgressUI(report: report, progressState: progressState)
                }
            }
        )
        return (downloadResults, stoppedByNetwork)
    }

    private static func updateBulkProgressUI(
        report: BoundedBulkDownloader.ProgressReport,
        progressState: BundleArchiveDownloadProgressState
    ) {
        progressState.message = String(localized: .Library.downloadingCountOfTotal(report.completed, report.total))
        if report.totalBytes > 0 {
            let writtenStr = report.downloadedBytes.formattedByteCount
            let totalStr = report.totalBytes.formattedByteCount
            progressState.detail = "\(report.completed)/\(report.total) (\(writtenStr) / \(totalStr))"
            progressState.progress = min(1.0, Double(report.downloadedBytes) / Double(report.totalBytes))
        } else {
            progressState.detail = "\(report.completed) / \(report.total)"
            progressState.progress = report.total > 0 ? Double(report.completed) / Double(report.total) : 0
        }
    }

    private func performBulkIntegrationPhase(
        successfulDownloads: [BooksData],
        downloadResults: inout [Int: Result<URL, Error>],
        progressState: BundleArchiveDownloadProgressState
    ) async -> Int {
        let integrateTotal = successfulDownloads.count
        var completedIntegrations = 0

        progressState.mode = .integrating
        progressState.message = String(localized: .Library.downloadCompleteBeginIntegrating)
        progressState.detail = "0 / \(integrateTotal)"
        progressState.progress = 0

        for book in successfulDownloads {
            guard !Task.isCancelled else { break }
            if !BookArchiveIntegrator.shared.isBookIntegrated(book) {
                do {
                    try await BookArchiveIntegrator.shared.ensureBookIntegrated(
                        book,
                        onIntegrating: {},
                        onProgress: { phase in
                            await MainActor.run {
                                progressState.message = "\(phase == .fts ? "FTS" : "Data"): \(book.book)"
                            }
                        }
                    )
                } catch {
                    downloadResults[book.id] = .failure(error)
                }
            }
            completedIntegrations += 1
            progressState.detail = "\(completedIntegrations) / \(integrateTotal)"
            progressState.progress = integrateTotal > 0 ? Double(completedIntegrations) / Double(integrateTotal) : 0
        }
        return completedIntegrations
    }

    private func buildBulkCompletionMessage(
        isCancelled: Bool,
        stoppedByNetwork: Bool,
        completedIntegrations: Int,
        failedCount: Int
    ) -> String? {
        if isCancelled {
            String(localized: .Library.stoppedBooksCompleted(completedIntegrations))
        } else if stoppedByNetwork {
            String(localized: .Library.checkInternetConnection)
        } else if failedCount > 0 {
            String(localized: .Library.completedAndFailedCount(completedIntegrations, failedCount))
        } else {
            String(localized: .Library.allBooksProcessedSuccessfully(completedIntegrations))
        }
    }
}
