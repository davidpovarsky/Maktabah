import Foundation

#if os(iOS)
@MainActor
enum OtzariaLibraryImportActions {
    static var isEnabled: Bool {
        OtzariaMaktabahBridge.shared.isEnabled
    }

    static func handleDownloadSingleBook(
        _ book: BooksData,
        viewModel: LibraryViewModel,
        navigationManager: iOSNavigationManager
    ) {
        if isEnabled {
            viewModel.selectBook(book, using: navigationManager)
        } else {
            navigationManager.showBookIntegrationConfirmation(
                for: book,
                initialContentId: nil
            )
        }
    }

    static func handleSelectionChange(
        viewModel: LibraryViewModel,
        navigationManager: iOSNavigationManager
    ) {
        guard !isEnabled else { return }
        guard !viewModel.isBulkDownloading else { return }

        let downloadBooks = viewModel.selectedDownloadBooks
        if !downloadBooks.isEmpty {
            let hasBulkConfirmation = navigationManager.activeIntegrationStates.contains { state in
                if case .bulk = state.pendingData, state.mode == .confirmation { return true }
                return false
            }

            if !hasBulkConfirmation {
                navigationManager.showBulkDownloadConfirmation(books: downloadBooks)
            } else if let bulkState = navigationManager.activeIntegrationStates.first(where: {
                if case .bulk = $0.pendingData, $0.mode == .confirmation { return true }
                return false
            }) {
                navigationManager.activeIntegrationStates.removeAll { $0.id == bulkState.id }
                navigationManager.showBulkDownloadConfirmation(books: downloadBooks)
            }
        } else {
            navigationManager.activeIntegrationStates.removeAll { state in
                if case .bulk = state.pendingData, state.mode == .confirmation { return true }
                return false
            }
        }
    }

    static func disconnectDatabase(viewModel: LibraryViewModel) {
        OtzariaMaktabahBridge.shared.forgetDatabase()
        DatabaseManager.shared.reloadConnectionAndLibrary()
        Task { await viewModel.refreshLibrary() }
    }

    static func installDatabase(
        from result: Result<[URL], Error>,
        viewModel: LibraryViewModel
    ) throws {
        guard let url = try result.get().first else { return }
        try OtzariaMaktabahBridge.shared.installDatabase(from: url)
        DatabaseManager.shared.reloadConnectionAndLibrary()
        Task { await viewModel.refreshLibrary() }
    }
}
#endif
