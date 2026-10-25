//
//  Reader+Content.swift
//  Maktabah
//

import Foundation
import OSLog

extension ReaderViewModel {
    // MARK: - Book Loading

    /// Loads initial content, optionally restoring a specific contentId
    func loadInitialContent(initialContentId: Int? = nil) {
        guard let book = currentBook else { return }
        loadTOC(book: book)
        if let locator = book.backendLocator {
            loadBackendInitialContent(book: book, locator: locator, initialContentId: initialContentId)
            return
        }

        do {
            try bookConnection.connect(archive: book.archive)
        } catch {
            contentText = DatabaseError.bookNotFound(book.archive).localizedDescription
        }

        guard let initialContentId else {
            loadFromHistory(for: book)
            return
        }

        if let content = getContent(
            bkId: book.id,
            contentId: initialContentId
        ) {
            updateContentState(with: content)
        } else {
            contentText = "Content ID not found."
        }
    }

    private func loadBackendInitialContent(book: BooksData, locator: TextLocator, initialContentId: Int? = nil) {
        backendLoadTask?.cancel()
        backendLoadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            var target = locator
            var hasExplicitLocator = false
            if let initialContentId {
                if let initialLocator = LegacyIdentityRegistry.shared.locator(for: initialContentId) {
                    let resolved = ReaderDestinationResolver.resolve(locator: initialLocator)
                    target = resolved.sectionLocator
                    if let focus = resolved.focusLocator {
                        self.selectedSegmentLocator = focus
                        self.currentDestination = resolved.destination
                    }
                    hasExplicitLocator = true
                } else if locator.backend == .otzaria {
                    target = TextLocator(backend: locator.backend, workKey: locator.workKey, position: .legacyLine(initialContentId))
                }
            } else {
                if LibraryReadingUnitPolicy.isWorkRoot(locator),
                   let recent = await QualifiedLocatorStore.shared.entries().first(where: {
                       $0.locator.backend == locator.backend && $0.locator.workKey == locator.workKey
                   }) {
                    target = LibraryReadingUnitPolicy.preferringRecent(
                        target,
                        recentLocator: recent.locator
                    )
                }
            }
            if LibraryReadingUnitPolicy.requiresBoundedResolution(
                target,
                hasExplicitLocator: hasExplicitLocator
            ) {
                let work = LibraryWork(
                    locator: locator,
                    title: locator.workKey,
                    heTitle: book.book,
                    categories: [],
                    description: nil
                )
                do {
                    let items = try await BackendCoordinator.shared.navigationItems(for: work)
                    self.navigationItems = items
                    target = try LibraryReadingUnitPolicy.resolve(target, navigationItems: items)
                } catch is CancellationError {
                    return
                } catch {
                    self.backendLoadTask = nil
                    self.contentText = error.localizedDescription
                    self.state = .error(error.localizedDescription)
                    return
                }
            }
            self.backendLoadTask = nil
            self.loadBackendContent(LibraryReaderDestination(sectionLocator: target, focusLocator: nil))
        }
    }

    func loadBackendContent(_ destination: LibraryReaderDestination) {
        currentDestination = destination
        loadBackendContentInternal(locator: destination.sectionLocator, focusLocator: destination.focusLocator)
    }

    func loadBackendContent(_ locator: TextLocator) {
        if let current = currentDestination, current.sectionLocator == locator {
            loadBackendContentInternal(locator: locator, focusLocator: current.focusLocator)
        } else {
            loadBackendContentInternal(locator: locator, focusLocator: nil)
        }
    }

    private func loadBackendContentInternal(locator: TextLocator, focusLocator: TextLocator?) {
        let resolved = ReaderDestinationResolver.resolve(locator: locator)
        let effectiveSection = resolved.sectionLocator
        let effectiveFocus = focusLocator ?? resolved.focusLocator
        currentDestination = LibraryReaderDestination(
            sectionLocator: effectiveSection,
            focusLocator: effectiveFocus
        )
        selectedSegmentLocator = effectiveFocus
        backendLoadTask?.cancel()
        state = .loading
        let scrollTarget: ReaderScrollTarget? = pendingReaderScrollTarget == .top ? .top : (pendingReaderScrollTarget == .bottom ? .bottom : nil)
        let token = contentLoadCoordinator.beginRequest(
            backend: effectiveSection.backend,
            workKey: effectiveSection.workKey,
            sectionLocator: effectiveSection,
            scrollTarget: scrollTarget
        )
        backendLoadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let section = try await BackendCoordinator.shared.section(at: effectiveSection)
                try Task.checkCancellation()
                guard self.contentLoadCoordinator.canApplyContent(token: token, currentBookLocator: self.currentBook?.backendLocator) else {
                    return
                }
                self.backendSection = section
                let renderModel = MaktabahBackendAdapter.renderModel(
                    from: section,
                    preferredMode: TextViewState.shared.readerTextMode
                )
                guard self.contentLoadCoordinator.canApplyContent(token: token, currentBookLocator: self.currentBook?.backendLocator) else {
                    return
                }
                self.backendRenderModel = renderModel
                let content = MaktabahBackendAdapter.content(from: section, renderModel: renderModel)
                if let bookID = self.currentBook?.id {
                    BookPageCache.shared.set(bookId: bookID, content: content)
                }
                self.updateContentState(with: content)
                self.selectedSegmentLocator = self.currentDestination?.focusLocator
                self.state = .loaded
                if let workLocator = self.currentBook?.backendLocator, self.navigationItems.isEmpty {
                    let work = LibraryWork(
                        locator: workLocator,
                        title: workLocator.workKey,
                        heTitle: self.currentBook?.book,
                        categories: [],
                        description: nil
                    )
                    let navGen = self.contentLoadCoordinator.beginNavigationItemsRequest(for: workLocator.workKey)
                    Task { [weak self] in
                        guard let self else { return }
                        if let items = try? await BackendCoordinator.shared.navigationItems(for: work) {
                            await MainActor.run {
                                guard self.contentLoadCoordinator.isNavigationItemsRequestActive(generation: navGen, workKey: workLocator.workKey) else {
                                    return
                                }
                                self.navigationItems = items
                            }
                        }
                    }
                }
            } catch is CancellationError {
                return
            } catch LibraryBackendError.staleRequest {
                return
            } catch {
                guard !Task.isCancelled, self.contentLoadCoordinator.isTokenActive(token) else { return }
                self.contentText = error.localizedDescription
                self.state = .error(error.localizedDescription)
            }
            if self.contentLoadCoordinator.isTokenActive(token) {
                self.backendLoadTask = nil
            }
        }
    }

    func loadTOC(book: BooksData) {
        tocViewModel.loadTOC(book: book)
    }

    func getContent(bkId: Int, contentId: Int) -> BookContent? {
        bookConnection.getContent(bkid: String(bkId), contentId: contentId)
    }

    func loadFromHistory(for book: BooksData) {
        // Try to restore from history first
        guard let lastContentId = historyVM.entriesByBookId[book.id]?.lastContentId,
              let content = bookConnection.getContent(bkid: String(book.id), contentId: lastContentId)
        else {
            getFirstBookContent(for: book)
            return
        }

        updateContentState(with: content)
    }

    func getFirstBookContent(for book: BooksData) {
        if let content = bookConnection.getFirstContent(bkid: String(book.id)) {
            updateContentState(with: content)
        } else {
            contentText = "No content found for this book."
        }
    }

    func fetchBookInfo(completion: @escaping (BooksData?) -> Void) {
        guard let currentBook else {
            completion(nil)
            return
        }
        let dm = LibraryDataManager.shared
        guard let bookOnLibrary = dm.getBook([currentBook.id]).first else {
            completion(nil)
            return
        }
        self.currentBook = bookOnLibrary
        dm.loadBookInfo(bookOnLibrary.id) {
            completion(bookOnLibrary)
        }
    }

    #if os(macOS)
    /// Connects to book archive with bundle fallback (macOS only)
    func connectBookWithBundleFallback(_ book: BooksData) async throws {
        guard AppConfig.isUsingBundleMode else {
            try bookConnection.connect(archive: book.archive)
            return
        }

        guard !BookArchiveIntegrator.shared.isBookIntegrated(book) else {
            try bookConnection.connect(archive: book.archive)
            return
        }

        let confirmed = await BookIntegrateModalCenter.shared
            .presentAndWaitForConfirmation(book: book)
        guard confirmed else { throw CancellationError() }

        defer {
            Task { @MainActor in
                BookIntegrateModalCenter.shared.dismiss()
            }
        }

        try await BookArchiveIntegrator.shared.ensureBookIntegrated(
            book,
            onIntegrating: {
                await BookIntegrateModalCenter.shared.showIntegrating()
            }
        )

        try bookConnection.connect(archive: book.archive)
    }
    #endif
}
