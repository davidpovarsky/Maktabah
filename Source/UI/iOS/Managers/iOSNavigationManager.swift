import Foundation
import OSLog
import SwiftUI
import UIKit

/// Manages the navigation and current mode for the iOS application.
@MainActor
@Observable
class iOSNavigationManager: BackendSwitchParticipant {
    struct AlertMessage: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    struct ReaderTab: Identifiable, Equatable {
        let id: UUID
        let book: BooksData
        var initialContentId: Int?
        var viewModel: ReaderViewModel

        static func == (lhs: ReaderTab, rhs: ReaderTab) -> Bool {
            lhs.id == rhs.id
        }
    }

    var currentMode: AppMode = .viewer
    var selectedBook: BooksData?
    var selectedBookForInfo: BooksData?
    var selectedContentId: Int?
    var searchText: String = ""
    var showViewOptions: Bool = false
    var activeIntegrationStates: [BundleArchiveDownloadProgressState] = []
    var alertMessage: AlertMessage?

    var libraryViewModel = LibraryViewModel()
    var searchViewModel = SearchViewModel()
    var unifiedSearchSession = UnifiedSearchSessionController()
    var authorViewModel = NarratorViewModel()
    var annotationViewModel = AnnotationViewModel()

    var openTabs: [ReaderTab] = []
    var activeTabId: UUID?
    var showingTabsList: Bool = false

    var activeTab: ReaderTab? {
        openTabs.first(where: { $0.id == activeTabId }) ?? openTabs.first
    }

    var activeReaderViewModel: ReaderViewModel? {
        activeTab?.viewModel
    }

    private var observerTokens: [NotificationToken] = []
    private var lastKnownBackendID: BackendID = BackendCoordinator.shared.activeBackendID
    private var isSwitchingBackend: Bool = false
    private var stagedTransition: PreparedBackendTransition?

    init() {
        unifiedSearchSession.searchViewModel = searchViewModel
        setupObservers()
        BackendCoordinator.shared.addSwitchParticipant(self)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupObservers() {
        observerTokens.append(
            NotificationToken(
                token: NotificationCenter.default.addObserver(
                    forName: .bookIntegrated,
                    object: nil,
                    queue: .main
                ) { [weak self] notification in
                    guard let bookId = notification.object as? Int else {
                        return
                    }
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        handleBookIntegrationChanged(bookId: bookId)
                    }
                }
            )
        )

        observerTokens.append(
            NotificationToken(
                token: NotificationCenter.default.addObserver(
                    forName: .libraryFolderChanged,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.clearAllTabs()
                    }
                }
            )
        )

        observerTokens.append(
            NotificationToken(
                token: NotificationCenter.default.addObserver(
                    forName: .bookIdMigrated,
                    object: nil,
                    queue: .main
                ) { [weak self] notification in
                    guard let migration = notification.bookIdMigration else { return }
                    Task { @MainActor [weak self] in
                        self?.handleBookIdMigrated(oldId: migration.oldId, newId: migration.newId)
                    }
                }
            )
        )

        // Note: Library backend switching is orchestrated fail-closed via BackendSwitchParticipant

        observerTokens.append(
            NotificationToken(
                token: NotificationCenter.default.addObserver(
                    forName: UIApplication.didEnterBackgroundNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.persistCurrentSession(immediate: true)
                    }
                }
            )
        )
    }

    private func handleBookIdMigrated(oldId: Int, newId: Int) {
        let ldm = LibraryDataManager.shared
        guard let newBookData = ldm.booksById[newId] else { return }

        for i in 0 ..< openTabs.count where openTabs[i].book.id == oldId {
            let oldTab = openTabs[i]
            openTabs[i] = ReaderTab(
                id: oldTab.id,
                book: newBookData,
                initialContentId: oldTab.initialContentId,
                viewModel: oldTab.viewModel
            )
            openTabs[i].viewModel.currentBook = newBookData
        }

        if selectedBook?.id == oldId {
            selectedBook = newBookData
        }
    }

    private func handleBookIntegrationChanged(bookId: Int) {
        if OtzariaNavigationAdapter.shouldIgnoreBookIntegrationChange() { return }
        // If a book is no longer integrated, close its tab
        let tabsToClose = openTabs.filter { tab in
            tab.book.id == bookId && !BookArchiveIntegrator.shared.isBookIntegrated(tab.book)
        }

        for tab in tabsToClose {
            closeTab(id: tab.id)
        }
    }

    func switchToMode(_ mode: AppMode) {
        currentMode = mode
    }

    func openBook(_ book: BooksData, options: OpenBookOptions = .init()) {
        Task {
            await openBookAsync(book, options: options)
        }
    }

    func openBook(
        _ book: BooksData,
        initialContentId: Int? = nil,
        searchText: String? = nil,
        searchMode: SearchMode? = nil,
        nearDistance: Int = 10,
        targetAnnotation: Annotation? = nil,
        recordHistory: Bool = true,
        highlightTerms: [String]? = nil
    ) {
        let options = OpenBookOptions(
            contentId: initialContentId,
            searchEvent: (searchText != nil && !searchText!.isEmpty)
                ? ReaderHighlightEvent(
                    query: searchText!,
                    contentId: initialContentId,
                    mode: searchMode,
                    nearDistance: nearDistance
                )
                : nil,
            annotationEvent: nil,
            recordHistory: recordHistory,
            searchText: searchText,
            searchMode: searchMode,
            nearDistance: nearDistance,
            targetAnnotation: targetAnnotation,
            highlightTerms: highlightTerms
        )
        openBook(book, options: options)
    }

    func closeTab(id: UUID) {
        if let index = openTabs.firstIndex(where: { $0.id == id }) {
            let tab = openTabs[index]
            if activeTabId == id {
                tab.viewModel.saveCurrentState()
            }

            openTabs.remove(at: index)
            if activeTabId == id {
                activeTabId = openTabs.last?.id
                if let nextTabId = activeTabId, let nextTab = openTabs.first(where: { $0.id == nextTabId }) {
                    nextTab.viewModel.annotationEvent = nil
                    nextTab.viewModel.searchEvent = nil
                    nextTab.viewModel.needsScrollRestore = true
                    selectedBook = nextTab.book
                    selectedContentId = nextTab.viewModel.currentContentId
                } else {
                    selectedBook = nil
                    selectedContentId = nil
                }
            } else if selectedBook?.id == tab.book.id {
                selectedBook = nil
            }

            if openTabs.isEmpty {
                showingTabsList = false
            }
            persistCurrentSession(immediate: true)
        }
    }

    func clearAllTabs() {
        for tab in openTabs {
            if activeTabId == tab.id {
                tab.viewModel.saveCurrentState()
            }
            tab.viewModel.closeReaderInspector()
            tab.viewModel.clearSearchHighlight()
        }
        openTabs.removeAll()
        activeTabId = nil
        selectedBook = nil
        selectedContentId = nil
        showingTabsList = false
        persistCurrentSession(immediate: true)
    }

    func selectTab(id: UUID) {
        guard activeTabId != id else { return }
        if let activeId = activeTabId, let currentTab = openTabs.first(where: { $0.id == activeId }) {
            currentTab.viewModel.saveCurrentState()
            if activeId != id { currentTab.viewModel.closeReaderInspector() }
        }
        activeTabId = id
        if let nextTab = openTabs.first(where: { $0.id == id }) {
            nextTab.viewModel.annotationEvent = nil
            nextTab.viewModel.searchEvent = nil
            nextTab.viewModel.needsScrollRestore = true
            selectedBook = nextTab.book
            selectedContentId = nextTab.viewModel.currentContentId
        }
        persistCurrentSession(immediate: false)
    }

    func confirmPendingBookIntegration(state: BundleArchiveDownloadProgressState) {
        if OtzariaNavigationAdapter.confirmPendingBookIntegrationIfEnabled(
            state: state,
            presentReader: { [weak self] book, initialContentId in
                self?.presentReader(book, initialContentId: initialContentId)
            },
            removeState: { [weak self] stateId in
                self?.activeIntegrationStates.removeAll { $0.id == stateId }
            }
        ) {
            return
        }
        guard let pendingData = state.pendingData else { return }

        switch pendingData {
        case .bulk:
            handleBulkIntegration(state: state)
        case let .single(book, initialContentId):
            handleSingleIntegration(state: state, book: book, initialContentId: initialContentId)
        }
    }

    private func handleBulkIntegration(state: BundleArchiveDownloadProgressState) {
        state.mode = .downloading
        libraryViewModel.startBulkDownload(progressState: state) { [weak self] message in
            self?.activeIntegrationStates.removeAll { $0.id == state.id }
            self?.libraryViewModel.exitSelectionMode()

            if let message {
                self?.alertMessage = AlertMessage(
                    title: String(localized: .Library.downloadBook),
                    message: message
                )
            }
        }
    }

    private func handleSingleIntegration(
        state: BundleArchiveDownloadProgressState,
        book: BooksData,
        initialContentId: Int?
    ) {
        state.mode = .downloading
        state.message = String(localized: .Library.downloadingBookFromServer)
        state.detail = ""
        state.progress = 0

        if let provider = BackendCoordinator.shared.offlineWorkProvider(),
           let locator = book.backendLocator,
           locator.backend == BackendCoordinator.shared.activeBackendID {
            Task {
                do {
                    try await provider.install(workKeys: [locator.workKey]) { update in
                        Task { @MainActor in
                            state.message = update.phase.rawValue.capitalized
                            state.detail = update.totalBytes > 0
                                ? ByteCountFormatter.string(fromByteCount: update.completedBytes, countStyle: .file)
                                : ""
                            state.progress = update.totalBytes > 0
                                ? Double(update.completedBytes) / Double(update.totalBytes) : 0
                        }
                    }
                    await LibraryOfflineAvailabilityController.shared.refresh()
                    await MainActor.run {
                        self.libraryViewModel.updateDisplayedCategories()
                        self.presentReader(book, options: OpenBookOptions(contentId: initialContentId))
                        self.activeIntegrationStates.removeAll { $0.id == state.id }
                    }
                } catch is CancellationError {
                    await MainActor.run { self.activeIntegrationStates.removeAll { $0.id == state.id } }
                } catch {
                    await MainActor.run {
                        self.activeIntegrationStates.removeAll { $0.id == state.id }
                        self.alertMessage = AlertMessage(
                            title: String(localized: .Library.downloadFailed),
                            message: error.localizedDescription
                        )
                    }
                }
            }
            return
        }

        Task { [weak self] in
            do {
                try await BookArchiveIntegrator.shared.ensureBookIntegrated(
                    book,
                    onDownloadProgress: { written, total in
                        let writtenStr = written.formattedByteCount
                        let totalStr = total > 0 ? total.formattedByteCount : ""
                        let progress = total > 0 ? min(1.0, Double(written) / Double(total)) : 0
                        Task { @MainActor in
                            guard state.mode == .downloading else { return }
                            state.detail = total > 0 ? "\(writtenStr) / \(totalStr)" : writtenStr
                            withAnimation(.linear(duration: 0.15)) {
                                state.progress = progress
                            }
                        }
                    },
                    onIntegrating: { [weak self] in
                        await self?.completeDownloadBeforeIntegrating(for: state)
                    },
                    onProgress: { [weak self] phase in
                        await self?.updateProgressPhase(for: state, phase: phase)
                    }
                )

                withAnimation(.easeInOut(duration: 0.15)) {
                    state.progress = 1.0
                }
                await Task.yield()

                if !MaktabahApp.isIpad, self?.selectedBook != nil {
                    // Do not automatically push a new book if there is already an active reader on iPhone
                } else {
                    self?.presentReader(book, options: OpenBookOptions(contentId: initialContentId))
                }
                self?.activeIntegrationStates.removeAll { $0.id == state.id }
            } catch is CancellationError {
                await MainActor.run { [weak self] in
                    self?.activeIntegrationStates.removeAll { $0.id == state.id }
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.activeIntegrationStates.removeAll { $0.id == state.id }
                    self?.alertMessage = AlertMessage(
                        title: String(localized: .Library.downloadFailed),
                        message: error.localizedDescription
                    )
                }
            }
        }
    }

    func cancelPendingBookIntegration(state: BundleArchiveDownloadProgressState) {
        if case .bulk = state.pendingData {
            libraryViewModel.exitSelectionMode()
        }
        activeIntegrationStates.removeAll { $0.id == state.id }
        if BackendCoordinator.shared.offlineWorkProvider() != nil {
            Task { await BackendCoordinator.shared.offlineWorkProvider()?.cancelWorkInstall() }
        }
    }

    private func openBookAsync(_ book: BooksData, options: OpenBookOptions) async {
        if book.backendLocator != nil {
            presentReader(book, options: options)
            return
        }
        if OtzariaNavigationAdapter.openBookIfEnabled(
            book,
            initialContentId: options.contentId,
            searchText: options.searchText,
            targetAnnotation: options.targetAnnotation,
            presentReader: { [weak self] book, initialContentId, searchText, targetAnnotation in
                var modOptions = options
                modOptions.contentId = initialContentId
                modOptions.searchText = searchText
                modOptions.targetAnnotation = targetAnnotation
                self?.presentReader(book, options: modOptions)
            }
        ) {
            return
        }
        if AppConfig.isUsingBundleMode,
           !BookArchiveIntegrator.shared.isBookIntegrated(book)
        {
            showBookIntegrationConfirmation(for: book, initialContentId: options.contentId)
            return
        }

        presentReader(book, options: options)

        await Task.yield()

        if options.recordHistory {
            HistoryViewModel.shared.addBookToHistory(book.id)
        }
    }

    func showBookIntegrationConfirmation(
        for book: BooksData,
        initialContentId: Int?
    ) {
        if OtzariaNavigationAdapter.presentReaderForIntegrationIfEnabled(
            book,
            initialContentId: initialContentId,
            presentReader: { [weak self] book, initialContentId in
                self?.presentReader(book, initialContentId: initialContentId)
            }
        ) {
            return
        }
        // Prevent duplicate confirmation for the same book
        if activeIntegrationStates.contains(where: {
            if case let .single(b, _) = $0.pendingData { return b.id == book.id }
            return false
        }) {
            return
        }

        let state = BundleArchiveDownloadProgressState.makeConfirmation(for: book)
        state.pendingData = .single(book: book, contentId: initialContentId)
        activeIntegrationStates.append(state)
    }

    func showBulkDownloadConfirmation(books: [BooksData]) {
        if let message = OtzariaNavigationAdapter.bulkDownloadMessageIfEnabled() {
            alertMessage = message
            return
        }
        // Prevent multiple bulk confirmations
        if activeIntegrationStates.contains(where: {
            if case .bulk = $0.pendingData { return true }
            return false
        }) {
            return
        }

        let totalSize = books.reduce(0 as Int64) { $0 + ($1.compressedDownloadSize ?? 0) }
        var sizeString = ""
        if totalSize > 0 {
            sizeString = totalSize.formattedByteCount
        }

        let message = String(localized: .Library.bulkBookDownloadAlert(books.count))

        let state = BundleArchiveDownloadProgressState(
            title: String(localized: .Library.downloadBook),
            message: message,
            mode: .confirmation,
            totalSizeString: sizeString
        )
        state.pendingData = .bulk(books: books)
        activeIntegrationStates.append(state)
    }

    private func showIntegratingState(for state: BundleArchiveDownloadProgressState) {
        state.transitionToIntegrating()
    }

    private func completeDownloadBeforeIntegrating(for state: BundleArchiveDownloadProgressState) async {
        withAnimation(.linear(duration: 0.15)) {
            state.progress = 1.0
        }
        try? await Task.sleep(for: .milliseconds(450))
        withAnimation(.easeInOut(duration: 0.25)) {
            showIntegratingState(for: state)
        }
    }

    private func updateProgressPhase(for state: BundleArchiveDownloadProgressState, phase: IntegratePhase) {
        withAnimation(.easeInOut(duration: 0.3)) {
            state.updateIntegrationPhase(phase)
        }
    }

    private func presentReader(
        _ book: BooksData,
        initialContentId: Int?,
        searchText: String? = nil,
        searchMode: SearchMode? = nil,
        nearDistance: Int = 10,
        targetAnnotation: Annotation? = nil,
        recordHistory: Bool = true,
        highlightTerms: [String]? = nil
    ) {
        let options = OpenBookOptions(
            contentId: initialContentId,
            searchEvent: nil,
            annotationEvent: nil,
            recordHistory: recordHistory,
            searchText: searchText,
            searchMode: searchMode,
            nearDistance: nearDistance,
            targetAnnotation: targetAnnotation,
            highlightTerms: highlightTerms
        )
        presentReader(book, options: options)
    }

    private func presentReader(_ book: BooksData, options: OpenBookOptions) {
        switchToMode(.viewer)
        clearPendingBookIntegration()

        if let activeId = activeTabId, let currentTab = openTabs.first(where: { $0.id == activeId }) {
            currentTab.viewModel.saveCurrentState()
            if currentTab.book.id != book.id { currentTab.viewModel.closeReaderInspector() }
        }

        if let existingTabIndex = openTabs.firstIndex(where: { $0.book.id == book.id }) {
            activeTabId = openTabs[existingTabIndex].id
            // Update initialContentId if provided, so the reader can jump to it
            let updatedTab = openTabs[existingTabIndex]
            updatedTab.viewModel.recordHistory = updatedTab.viewModel.recordHistory || options.recordHistory
            updatedTab.viewModel.needsScrollRestore = true
            if let terms = options.highlightTerms {
                updatedTab.viewModel.highlightTerms = terms
            }
            if let search = options.searchText {
                updatedTab.viewModel.searchText = search
            }
            if let mode = options.searchMode {
                updatedTab.viewModel.searchMode = mode
            }
            updatedTab.viewModel.nearDistance = options.nearDistance
            if let target = options.targetAnnotation {
                updatedTab.viewModel.targetAnnotation = target
            }
            if let contentId = options.contentId {
                let isSameContent = updatedTab.viewModel.currentContentId == contentId
                if let event = options.searchEvent {
                    updatedTab.viewModel.searchEvent = event
                }
                updatedTab.viewModel.annotationEvent = options.annotationEvent

                if !isSameContent {
                    updatedTab.viewModel.fetchContentById(contentId)
                }

                openTabs[existingTabIndex] = updatedTab
            } else {
                updatedTab.viewModel.searchEvent = options.searchEvent
                updatedTab.viewModel.annotationEvent = options.annotationEvent
                openTabs[existingTabIndex] = updatedTab
            }
        } else {
            let viewModel = ReaderViewModel(book: book)
            viewModel.recordHistory = options.recordHistory
            viewModel.searchEvent = options.searchEvent
            viewModel.annotationEvent = options.annotationEvent
            viewModel.searchText = options.searchText ?? ""
            viewModel.searchMode = options.searchMode
            viewModel.nearDistance = options.nearDistance
            viewModel.targetAnnotation = options.targetAnnotation
            viewModel.highlightTerms = options.highlightTerms
            viewModel.loadInitialContent(initialContentId: options.contentId)
            let newTab = ReaderTab(id: UUID(), book: book, initialContentId: options.contentId, viewModel: viewModel)
            openTabs.append(newTab)
            activeTabId = newTab.id
        }

        selectedContentId = options.contentId
        selectedBook = book
        persistCurrentSession(immediate: false)
    }

    private func clearPendingBookIntegration() {
        activeIntegrationStates.removeAll { $0.mode == .confirmation }
    }

    // MARK: - Durable Session Persistence (F01)

    private var isRestoringSession = false

    func restoreSessionIfNeeded() {
        guard openTabs.isEmpty, !isRestoringSession else { return }
        isRestoringSession = true
        defer { isRestoringSession = false }

        guard let session = iOSReaderSessionManager.shared.loadSession(),
              !session.tabs.isEmpty else {
            return
        }
        let activeBackend = BackendNavigationAdapter.shared.activeBackend
        let (sanitized, foreignTabs, _) = BackendSessionIntegrityRepair.shared.repairSessionSnapshot(
            session: session,
            targetBackend: activeBackend
        )
        if !foreignTabs.isEmpty {
            Logger.app.warning("restoreSessionIfNeeded detected \(foreignTabs.count) foreign tabs for active backend \(activeBackend.rawValue)")
            if sanitized.tabs.isEmpty {
                if let backendData = BackendNavigationAdapter.shared.retrieveBackendSessionSnapshot(backend: activeBackend),
                   let backendSession = try? JSONDecoder().decode(iOSReaderSession.self, from: backendData),
                   !backendSession.tabs.isEmpty {
                    restoreSessionFromData(backendSession)
                    return
                }
                return
            }
        }
        restoreSessionFromData(sanitized)
    }

    // MARK: - BackendSwitchParticipant (Two-Phase Fail-Closed Boundary)

    func prepareTransition(from currentBackend: BackendID, to targetBackend: BackendID, token: UInt64) throws -> PreparedBackendTransition? {
        let resolver = DefaultTargetBackendBookResolver.shared
        let transition = try BackendNavigationAdapter.shared.prepareTransition(
            outgoingBackend: currentBackend,
            outgoingSession: { [weak self] in
                guard let self, !self.openTabs.isEmpty else { return nil }
                if let active = self.activeTab {
                    active.viewModel.saveCurrentState()
                }
                let tabSessions = self.createTabSessions(from: self.openTabs)
                let session = iOSReaderSession(
                    schemaVersion: iOSReaderSession.currentSchemaVersion,
                    savedAt: Date(),
                    activeTabId: self.activeTabId,
                    selectedTabModeRaw: self.currentMode.rawValue,
                    tabs: tabSessions,
                    backend: currentBackend.rawValue
                )
                return try JSONEncoder().encode(session)
            },
            incomingBackend: targetBackend,
            incomingValidator: { [weak self] data in
                let session = try JSONDecoder().decode(iOSReaderSession.self, from: data)
                let repairResult = BackendSessionIntegrityRepair.shared.repairSessionSnapshot(
                    session: session,
                    targetBackend: targetBackend,
                    rawIncomingData: data
                )
                let sanitized = repairResult.sanitizedSession
                if !repairResult.foreignTabs.isEmpty {
                    Logger.app.warning("Repaired incoming snapshot for \(targetBackend.rawValue): quarantined \(repairResult.foreignTabs.count) foreign tabs")
                    if let sanitizedData = try? JSONEncoder().encode(sanitized) {
                        try? BackendNavigationAdapter.shared.saveBackendSessionSnapshot(backend: targetBackend, sessionData: sanitizedData)
                    }
                }
                var staged: [PreparedBackendTransition.StagedTabSession] = []
                for tabSession in sanitized.tabs {
                    if let locator = tabSession.locator {
                        guard locator.backend == targetBackend else {
                            throw BackendTransitionError.foreignBackendLocator(
                                locator: "\(locator.backend.rawValue):\(locator.workKey)",
                                expectedBackend: targetBackend
                            )
                        }
                    }
                    if let backendLocator = tabSession.backendLocator {
                        guard backendLocator.backend == targetBackend else {
                            throw BackendTransitionError.foreignBackendLocator(
                                locator: "\(backendLocator.backend.rawValue):\(backendLocator.workKey)",
                                expectedBackend: targetBackend
                            )
                        }
                    }

                    let resolvedBook = try resolver.resolveBook(
                        id: tabSession.bookId,
                        backendLocator: tabSession.backendLocator?.workKey,
                        title: tabSession.bookTitle,
                        in: targetBackend
                    )

                    staged.append(PreparedBackendTransition.StagedTabSession(
                        id: tabSession.id,
                        bookId: tabSession.bookId,
                        bookTitle: tabSession.bookTitle ?? "Book \(tabSession.bookId)",
                        backendLocator: tabSession.backendLocator?.workKey,
                        contentId: tabSession.contentId,
                        locator: tabSession.locator,
                        page: tabSession.page,
                        part: tabSession.part,
                        scrollPosition: tabSession.scrollPosition,
                        selectedRange: tabSession.selectedRange,
                        expandedNodeIDs: tabSession.expandedNodeIDs,
                        sidebarScrollPosition: tabSession.sidebarScrollPosition,
                        isSidebarCollapsed: tabSession.isSidebarCollapsed,
                        searchText: tabSession.searchText,
                        searchModeRaw: tabSession.searchModeRaw,
                        nearDistance: tabSession.nearDistance,
                        highlightTerms: tabSession.highlightTerms,
                        retainedBook: resolvedBook
                    ))
                }
                return staged
            },
            token: token
        )
        self.stagedTransition = transition
        return transition
    }

    func prepareTransitionAsync(from currentBackend: BackendID, to targetBackend: BackendID, token: UInt64) async throws -> PreparedBackendTransition? {
        if targetBackend == .sefaria {
            do {
                _ = try await MaktabahBackendAdapter.loadLibraryIfNeeded()
            } catch {
                Logger.app.error("Failed to preload Sefaria library: \(error.localizedDescription)")
            }
        }
        return try prepareTransition(from: currentBackend, to: targetBackend, token: token)
    }

    func publishTransition(to targetBackend: BackendID, transition: PreparedBackendTransition?) {
        let activeTransition = transition ?? self.stagedTransition

        if let activeTransition, !activeTransition.isCleanDestination, !activeTransition.stagedTabs.isEmpty {
            // Priority B1 & B2: Atomically prepare all tabs from pre-resolved retained books
            // NO second throwing book resolver call and NO `continue` dropping failed tabs.
            var restoredTabs: [ReaderTab] = []
            var allSucceeded = true

            for staged in activeTransition.stagedTabs {
                guard let book = staged.retainedBook as? BooksData else {
                    allSucceeded = false
                    break
                }

                let viewModel = ReaderViewModel(book: book)
                viewModel.recordHistory = false
                viewModel.needsScrollRestore = true
                if let pos = staged.scrollPosition { viewModel.readerState.scrollPosition = pos }
                if let range = staged.selectedRange { viewModel.readerState.selectedRange = range }
                if let exp = staged.expandedNodeIDs { viewModel.readerState.expandedNodeIDs = exp }
                if let col = staged.isSidebarCollapsed { viewModel.readerState.isSidebarCollapsed = col }
                if let sidePos = staged.sidebarScrollPosition { viewModel.readerState.sidebarScrollPosition = sidePos }
                if let search = staged.searchText { viewModel.searchText = search }
                if let raw = staged.searchModeRaw, let mode = SearchMode(rawValue: raw) { viewModel.searchMode = mode }
                if let near = staged.nearDistance { viewModel.nearDistance = near }
                if let terms = staged.highlightTerms { viewModel.highlightTerms = terms }

                if let locator = staged.locator {
                    viewModel.loadBackendContent(locator)
                } else if let contentId = staged.contentId {
                    viewModel.loadInitialContent(initialContentId: contentId)
                } else {
                    viewModel.loadInitialContent(initialContentId: nil)
                }
                viewModel.loadTOC(book: book)

                restoredTabs.append(ReaderTab(
                    id: staged.id,
                    book: book,
                    initialContentId: staged.contentId,
                    viewModel: viewModel
                ))
            }

            // ATOMICITY: If ANY tab failed to restore or count does not match stagedTabs, ABORT!
            guard allSucceeded && restoredTabs.count == activeTransition.stagedTabs.count else {
                Logger.app.error("publishTransition failed atomic restoration (\(restoredTabs.count)/\(activeTransition.stagedTabs.count) tabs ready). Preserving existing tabs without mutating state.")
                self.stagedTransition = nil
                self.isSwitchingBackend = false
                return
            }

            // Only AFTER all tabs are safely constructed and verified do we perform irreversible UI modifications
            isSwitchingBackend = true
            clearTabsForBackendSwitch()
            clearPendingBookIntegration()
            alertMessage = nil
            unifiedSearchSession.handleBackendChanged()
            lastKnownBackendID = targetBackend
            BackendNavigationAdapter.shared.commitTransition(incomingBackend: targetBackend)

            self.openTabs = restoredTabs
            let resolution = ReaderSessionRestoreCoordinator().resolveActiveTab(
                savedActiveId: activeTransition.targetActiveTabId,
                restoredTabs: restoredTabs
            )
            self.activeTabId = resolution.activeTabId
            if let targetActiveId = resolution.activeTabId,
               let active = restoredTabs.first(where: { $0.id == targetActiveId }) {
                self.selectedBook = active.book
                self.selectedContentId = active.initialContentId ?? active.viewModel.currentContentId
            }
            self.stagedTransition = nil
            self.isSwitchingBackend = false
            self.persistCurrentSession(immediate: true)
        } else {
            // Clean destination or empty stagedTabs
            isSwitchingBackend = true
            clearTabsForBackendSwitch()
            clearPendingBookIntegration()
            alertMessage = nil
            unifiedSearchSession.handleBackendChanged()
            lastKnownBackendID = targetBackend
            BackendNavigationAdapter.shared.commitTransition(incomingBackend: targetBackend)

            self.openTabs = []
            self.activeTabId = nil
            self.stagedTransition = nil
            self.isSwitchingBackend = false
            self.persistCurrentSession(immediate: true)
        }
    }

    func completeTransition(to targetBackend: BackendID) {
        BackendNavigationAdapter.shared.completeTransition(incomingBackend: targetBackend)
    }

    func abortTransition(from currentBackend: BackendID, to targetBackend: BackendID, error: Error) {
        BackendNavigationAdapter.shared.resetTransition()
        self.stagedTransition = nil
        self.isSwitchingBackend = false
        alertMessage = AlertMessage(
            title: "Backend Switch Failed",
            message: "Unable to switch backend: \(error.localizedDescription)"
        )
    }

    private func clearTabsForBackendSwitch() {
        for tab in openTabs {
            tab.viewModel.closeReaderInspector()
            tab.viewModel.clearSearchHighlight()
        }
        openTabs.removeAll()
        activeTabId = nil
        selectedBook = nil
        selectedContentId = nil
        showingTabsList = false
    }

    private func createTabSessions(from tabs: [ReaderTab]) -> [iOSReaderTabSession] {
        tabs.map { tab in
            let vm = tab.viewModel
            let state = vm.readerState
            return iOSReaderTabSession(
                id: tab.id,
                bookId: tab.book.id,
                bookTitle: tab.book.title,
                backendLocator: tab.book.backendLocator,
                contentId: vm.currentID ?? tab.initialContentId ?? state.currentID ?? (vm.currentContentId > 0 ? vm.currentContentId : nil),
                locator: vm.currentLocator ?? state.currentLocator,
                page: vm.currentPage ?? state.currentPage,
                part: vm.currentPart ?? state.currentPart,
                scrollPosition: state.scrollPosition ?? vm.fetchScrollPosition?(),
                selectedRange: state.selectedRange ?? vm.fetchSelectedRange?(),
                expandedNodeIDs: state.expandedNodeIDs,
                sidebarScrollPosition: state.sidebarScrollPosition,
                isSidebarCollapsed: state.isSidebarCollapsed,
                searchText: vm.searchText.isEmpty ? nil : vm.searchText,
                searchModeRaw: vm.searchMode?.rawValue,
                nearDistance: vm.nearDistance,
                highlightTerms: vm.highlightTerms
            )
        }
    }

    private func restoreSessionFromData(_ session: iOSReaderSession) {
        var restoredTabs: [ReaderTab] = []
        let ldm = LibraryDataManager.shared

        for tabSession in session.tabs {
            // Find book by ID or backend locator
            var book: BooksData? = ldm.booksById[tabSession.bookId]
            if book == nil, let locator = tabSession.backendLocator {
                book = ldm.booksById.values.first(where: { $0.backendLocator == locator })
            }
            if book == nil {
                book = ldm.getBook([tabSession.bookId]).first
            }

            // Resilient placeholder if catalog is still indexing
            let validBook = book ?? BooksData(
                id: tabSession.bookId,
                title: tabSession.bookTitle ?? "Book \(tabSession.bookId)",
                backendLocator: tabSession.backendLocator
            )

            let viewModel = ReaderViewModel(book: validBook)
            viewModel.recordHistory = false
            viewModel.needsScrollRestore = true
            if let pos = tabSession.scrollPosition {
                viewModel.readerState.scrollPosition = pos
            }
            if let range = tabSession.selectedRange {
                viewModel.readerState.selectedRange = range
            }
            if let expanded = tabSession.expandedNodeIDs {
                viewModel.readerState.expandedNodeIDs = expanded
            }
            if let collapsed = tabSession.isSidebarCollapsed {
                viewModel.readerState.isSidebarCollapsed = collapsed
            }
            if let sidebarPos = tabSession.sidebarScrollPosition {
                viewModel.readerState.sidebarScrollPosition = sidebarPos
            }
            if let search = tabSession.searchText {
                viewModel.searchText = search
            }
            if let modeRaw = tabSession.searchModeRaw, let mode = SearchMode(rawValue: modeRaw) {
                viewModel.searchMode = mode
            }
            if let near = tabSession.nearDistance {
                viewModel.nearDistance = near
            }
            if let terms = tabSession.highlightTerms {
                viewModel.highlightTerms = terms
            }

            if let locator = tabSession.locator {
                viewModel.loadBackendContent(locator)
            } else if let contentId = tabSession.contentId {
                viewModel.loadInitialContent(initialContentId: contentId)
            } else {
                viewModel.loadInitialContent(initialContentId: nil)
            }
            viewModel.loadTOC(book: validBook)

            let tab = ReaderTab(
                id: tabSession.id,
                book: validBook,
                initialContentId: tabSession.contentId,
                viewModel: viewModel
            )
            restoredTabs.append(tab)
        }

        guard !restoredTabs.isEmpty else { return }

        self.openTabs = restoredTabs
        let resolution = ReaderSessionRestoreCoordinator().resolveActiveTab(
            savedActiveId: session.activeTabId,
            restoredTabs: restoredTabs
        )
        let targetActiveId = resolution.activeTabId
        self.activeTabId = targetActiveId
        if let targetActiveId, let active = restoredTabs.first(where: { $0.id == targetActiveId }) {
            self.selectedBook = active.book
            self.selectedContentId = active.initialContentId ?? active.viewModel.currentContentId
        }
        self.currentMode = session.selectedTabMode
    }

    func persistCurrentSession(immediate: Bool = false) {
        guard !isRestoringSession && !isSwitchingBackend else { return }
        if let active = activeTab {
            active.viewModel.saveCurrentState()
        }

        let tabSessions = createTabSessions(from: openTabs)
        let currentBackend = BackendNavigationAdapter.shared.activeBackend

        let session = iOSReaderSession(
            schemaVersion: iOSReaderSession.currentSchemaVersion,
            savedAt: Date(),
            activeTabId: activeTabId,
            selectedTabModeRaw: currentMode.rawValue,
            tabs: tabSessions,
            backend: currentBackend.rawValue
        )

        if immediate {
            iOSReaderSessionManager.shared.saveSessionImmediately(session)
        } else {
            iOSReaderSessionManager.shared.scheduleSaveSession(session)
        }
    }
}

// MARK: - Target Backend Book Resolution

@MainActor
protocol TargetBackendBookResolver: Sendable {
    func resolveBook(
        id: Int,
        backendLocator: String?,
        title: String?,
        in backend: BackendID
    ) throws -> BooksData
}

@MainActor
final class DefaultTargetBackendBookResolver: TargetBackendBookResolver {
    static let shared = DefaultTargetBackendBookResolver()

    func resolveBook(
        id: Int,
        backendLocator: String?,
        title: String?,
        in backend: BackendID
    ) throws -> BooksData {
        try ChavrusaTextTargetBackendBookResolver.shared.resolveBook(
            id: id,
            backendLocator: backendLocator,
            title: title,
            in: backend
        )
    }
}
