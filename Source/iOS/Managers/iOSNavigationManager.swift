import SwiftUI

/// Manages the navigation and current mode for the iOS application.
@MainActor
@Observable
class iOSNavigationManager {
    struct AlertMessage: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    struct ReaderTab: Identifiable, Equatable {
        let id: UUID
        let book: BooksData
        var initialContentId: Int?
        var viewModel: iOSReaderViewModel

        static func == (lhs: ReaderTab, rhs: ReaderTab) -> Bool {
            lhs.id == rhs.id
        }
    }

    var currentMode: AppMode = .viewer
    var selectedBook: BooksData?
    var selectedContentId: Int?
    var searchText: String = ""
    var showViewOptions: Bool = false
    var bookIntegrationState: BundleArchiveDownloadProgressState?
    var alertMessage: AlertMessage?

    var libraryViewModel = iOSLibraryViewModel()
    var searchViewModel = iOSSearchViewModel()
    var annotationViewModel = iOSAnnotationViewModel()

    var openTabs: [ReaderTab] = []
    var activeTabId: UUID?

    private var pendingBook: BooksData?
    private var pendingContentId: Int?

    func switchToMode(_ mode: AppMode) {
        currentMode = mode
    }

    func openBook(_ book: BooksData, initialContentId: Int? = nil) {
        Task {
            await openBookAsync(book, initialContentId: initialContentId)
        }
    }

    func closeTab(id: UUID) {
        if let index = openTabs.firstIndex(where: { $0.id == id }) {
            if activeTabId == id {
                openTabs[index].viewModel.saveCurrentState()
            }

            openTabs.remove(at: index)
            if activeTabId == id {
                activeTabId = openTabs.last?.id
            }
        }
    }

    func selectTab(id: UUID) {
        if let activeId = activeTabId, let currentTab = openTabs.first(where: { $0.id == activeId })
        {
            currentTab.viewModel.saveCurrentState()
        }
        activeTabId = id
    }

    func confirmPendingBookIntegration() {
        guard let book = pendingBook,
              let state = bookIntegrationState
        else {
            return
        }

        state.mode = .downloading
        state.message = NSLocalizedString(
            "Downloading book file from server...",
            comment: "Book integrate downloading message"
        )
        state.detail = ""
        state.progress = 0

        Task {
            do {
                try await BookArchiveIntegrator.shared.ensureBookIntegrated(
                    book,
                    onIntegrating: { [weak self] in
                        await MainActor.run { [weak self] in
                            self?.showIntegratingState()
                        }
                    }
                )

                await MainActor.run {
                    self.presentReader(book, initialContentId: self.pendingContentId)
                    self.clearPendingBookIntegration()
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.clearPendingBookIntegration()
                }
            } catch {
                await MainActor.run {
                    self.clearPendingBookIntegration()
                    self.alertMessage = AlertMessage(
                        title: NSLocalizedString("Download Failed", comment: "Download failed alert title"),
                        message: error.localizedDescription
                    )
                }
            }
        }
    }

    func cancelPendingBookIntegration() {
        clearPendingBookIntegration()
    }

    private func openBookAsync(_ book: BooksData, initialContentId: Int?) async {
        if !CoreDatabaseDownloader().areCoreFilesReady() {
            alertMessage = AlertMessage(
                title: NSLocalizedString("Database File Needed", comment: "Missing core files alert title"),
                message: NSLocalizedString(
                    "The core database files are not ready yet. Finish the initial download first.",
                    comment: "Missing core files alert message"
                )
            )
            return
        }

        if AppConfig.isUsingBundleMode,
           !BookArchiveIntegrator.shared.isBookIntegrated(book)
        {
            showBookIntegrationConfirmation(for: book, initialContentId: initialContentId)
            return
        }

        await MainActor.run {
            iOSHistoryViewModel.shared.addBookToHistory(book.id, lastContentId: initialContentId)
        }

        presentReader(book, initialContentId: initialContentId)
    }

    private func showBookIntegrationConfirmation(
        for book: BooksData,
        initialContentId: Int?
    ) {
        pendingBook = book
        pendingContentId = initialContentId

        let bodyFormat = String(localized: "Confirm Download Message")
        let message = String(
            format: bodyFormat,
            locale: Locale.current,
            book.book
        )

        var sizeString = ""
        if let size = book.compressedDownloadSize, size > 0 {
            sizeString = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }

        bookIntegrationState = BundleArchiveDownloadProgressState(
            title: book.book,
            message: message,
            mode: .confirmation,
            totalSizeString: sizeString
        )
    }

    private func showIntegratingState() {
        guard let state = bookIntegrationState else { return }
        state.mode = .integrating
        state.title = NSLocalizedString(
            "Integrating Book",
            comment: "Book integrate phase title"
        )
        state.message = NSLocalizedString(
            "Copying tables and rebuilding FTS index...",
            comment: "Book integrate phase message"
        )
        state.detail = NSLocalizedString(
            "Please wait, this process cannot be cancelled.",
            comment: "Book integrate phase detail"
        )
        state.progress = 0
    }

    private func presentReader(_ book: BooksData, initialContentId: Int?) {
        switchToMode(.viewer)

        if let activeId = activeTabId, let currentTab = openTabs.first(where: { $0.id == activeId })
        {
            currentTab.viewModel.saveCurrentState()
        }

        if let existingTabIndex = openTabs.firstIndex(where: { $0.book.id == book.id }) {
            activeTabId = openTabs[existingTabIndex].id
            // Update initialContentId if provided, so the reader can jump to it
            if let contentId = initialContentId {
                var updatedTab = openTabs[existingTabIndex]
                updatedTab.initialContentId = contentId
                updatedTab.viewModel.fetchContentById(contentId)
                openTabs[existingTabIndex] = updatedTab
            }
        } else {
            let viewModel = iOSReaderViewModel(book: book)
            viewModel.loadInitialContent(initialContentId: initialContentId)
            let newTab = ReaderTab(id: UUID(), book: book, initialContentId: initialContentId, viewModel: viewModel)
            openTabs.append(newTab)
            activeTabId = newTab.id
        }

        selectedContentId = initialContentId
        selectedBook = book
    }

    private func clearPendingBookIntegration() {
        pendingBook = nil
        pendingContentId = nil
        bookIntegrationState = nil
    }
}
