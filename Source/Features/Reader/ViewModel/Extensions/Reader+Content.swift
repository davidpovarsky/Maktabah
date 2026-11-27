//
//  Reader+Content.swift
//  Maktabah
//

import Foundation
import Observation
import OSLog

extension ReaderViewModel {
    // MARK: - Book Loading

    /// Retain the exact original invocation before callbacks or suspension.
    /// Ordinary UI calls have no native deadline. Native selection supplies its
    /// already-existing absolute deadline only during canonical apply.
    func makeInitialContentRequest(initialContentId: Int? = nil,
                                   deadlineUptimeNanoseconds: UInt64? = nil) -> ReaderInitialContentRequest? {
        makeContentRequest(input: .initial(initialContentId), deadlineUptimeNanoseconds: deadlineUptimeNanoseconds)
    }

    func makeBackendContentRequest(locator: TextLocator,
                                   deadlineUptimeNanoseconds: UInt64? = nil) -> ReaderInitialContentRequest? {
        makeContentRequest(input: .locator(locator), deadlineUptimeNanoseconds: deadlineUptimeNanoseconds)
    }

    private func contentRequestSource(book: BooksData, input: ReaderInitialContentRequest.Input,
                                      originalDestination: LibraryReaderDestination?) -> ReaderInitialContentRequest.Source {
        .init(reader: ObjectIdentifier(self), book: ObjectIdentifier(book), bookID: book.id,
            bookLocator: book.backendLocator, input: input,
            backend: BackendCoordinator.shared.activeBackendID,
            backendGeneration: BackendCoordinator.shared.generation, originalDestination: originalDestination)
    }

    private func makeContentRequest(input: ReaderInitialContentRequest.Input,
                                    deadlineUptimeNanoseconds: UInt64? = nil) -> ReaderInitialContentRequest? {
        guard let book = currentBook else { return nil }
        return contentLoadCoordinator.beginInitialContentRequest(source: contentRequestSource(book: book,
            input: input, originalDestination: currentDestination), deadlineUptimeNanoseconds: deadlineUptimeNanoseconds)
    }

    private func claimContentRequest(_ supplied: ReaderInitialContentRequest?,
                                      input: ReaderInitialContentRequest.Input, book: BooksData) -> ReaderInitialContentRequest? {
        guard let request = supplied ?? makeContentRequest(input: input),
              contentLoadCoordinator.claimInitialContentRequest(request,
                source: contentRequestSource(book: book, input: input, originalDestination: currentDestination)) else { return nil }
        // The actual book owner is @Observable. One-way invalidation detects a
        // book A→B→A even before the first original section token is issued.
        withObservationTracking { _ = self.currentBook } onChange: { [weak request] in request?.invalidate() }
        guard contentRequestIsCurrent(request, book: book) else { return nil }
        return request
    }

    private func contentRequestIsCurrent(_ request: ReaderInitialContentRequest, book: BooksData) -> Bool {
        guard let actual = request.state, currentBook === book,
              request.source == contentRequestSource(book: book, input: request.source.input,
                originalDestination: request.source.originalDestination),
              currentDestination == actual.destination else {
            request.invalidate()
            return false
        }
        return true
    }

    /// Loads initial content, optionally restoring a specific contentId.
    func loadInitialContent(initialContentId: Int? = nil,
                            continuing initialRequest: ReaderInitialContentRequest? = nil) {
        guard let book = currentBook,
              let request = claimContentRequest(initialRequest, input: .initial(initialContentId), book: book) else { return }
        loadTOC(book: book)
        guard contentRequestIsCurrent(request, book: book) else { return }
        if let locator = book.backendLocator {
            loadBackendInitialContent(book: book, locator: locator, initialContentId: initialContentId, request: request)
            return
        }

        do {
            try bookConnection.connect(archive: book.archive)
        } catch {
            guard contentRequestIsCurrent(request, book: book) else { return }
            contentText = DatabaseError.bookNotFound(book.archive).localizedDescription
        }
        guard contentRequestIsCurrent(request, book: book) else { return }

        guard let initialContentId else {
            loadFromHistory(for: book, validating: { self.contentRequestIsCurrent(request, book: book) })
            if contentRequestIsCurrent(request, book: book) { contentLoadCoordinator.finishInitialContentRequest(request) }
            return
        }

        if let content = getContent(
            bkId: book.id,
            contentId: initialContentId
        ) {
            guard contentRequestIsCurrent(request, book: book) else { return }
            updateContentState(with: content, validating: { self.contentRequestIsCurrent(request, book: book) })
        } else {
            guard contentRequestIsCurrent(request, book: book) else { return }
            contentText = "Content ID not found."
        }
        if contentRequestIsCurrent(request, book: book) { contentLoadCoordinator.finishInitialContentRequest(request) }
    }

    private func loadBackendInitialContent(book: BooksData, locator: TextLocator,
                                           initialContentId: Int? = nil, request: ReaderInitialContentRequest) {
        guard contentRequestIsCurrent(request, book: book) else { return }
        backendLoadTask?.cancel()
        guard contentRequestIsCurrent(request, book: book) else { return }
        backendLoadTask = Task { @MainActor [weak self] in
            defer { if Task.isCancelled { request.invalidate() } }
            guard let self, !Task.isCancelled, self.contentRequestIsCurrent(request, book: book) else { return }
            var target = locator
            var hasExplicitLocator = false
            if let initialContentId {
                if let initialLocator = LegacyIdentityRegistry.shared.locator(for: initialContentId) {
                    // Keep the original registry lookup/resolver order and IDs.
                    // Its result must still belong to this exact original book.
                    guard initialLocator.backend == locator.backend, initialLocator.workKey == locator.workKey else {
                        request.invalidate(); return
                    }
                    let resolved = ReaderDestinationResolver.resolve(locator: initialLocator)
                    target = resolved.sectionLocator
                    if let focus = resolved.focusLocator {
                        self.selectedSegmentLocator = focus
                        guard self.contentRequestIsCurrent(request, book: book),
                              self.contentLoadCoordinator.recordInitialContentDestination(resolved.destination, request: request) else { return }
                        self.currentDestination = resolved.destination
                        guard self.contentRequestIsCurrent(request, book: book) else { return }
                    }
                    hasExplicitLocator = true
                } else if locator.backend == .otzaria {
                    target = TextLocator(backend: locator.backend, workKey: locator.workKey, position: .legacyLine(initialContentId))
                    // The original database uses zero-based line indices. An
                    // explicit search/TOC line 0 is content, not an unspecified
                    // work root to replace with the first navigation heading.
                    hasExplicitLocator = true
                }
            } else {
                if LibraryReadingUnitPolicy.isWorkRoot(locator) {
                    let entries = await QualifiedLocatorStore.shared.entries()
                    guard !Task.isCancelled, self.contentRequestIsCurrent(request, book: book) else { return }
                    if let recent = entries.first(where: {
                        $0.locator.backend == locator.backend && $0.locator.workKey == locator.workKey
                    }) {
                        target = LibraryReadingUnitPolicy.preferringRecent(target, recentLocator: recent.locator)
                    }
                }
            }
            guard !Task.isCancelled, self.contentRequestIsCurrent(request, book: book) else { return }
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
                    guard !Task.isCancelled, self.contentRequestIsCurrent(request, book: book) else { return }
                    self.navigationItems = items
                    guard self.contentRequestIsCurrent(request, book: book) else { return }
                    target = try LibraryReadingUnitPolicy.resolve(target, navigationItems: items)
                } catch is CancellationError {
                    request.invalidate()
                    return
                } catch {
                    guard !Task.isCancelled, self.contentRequestIsCurrent(request, book: book) else { return }
                    self.backendLoadTask = nil
                    guard self.contentRequestIsCurrent(request, book: book) else { return }
                    self.contentText = error.localizedDescription
                    guard self.contentRequestIsCurrent(request, book: book) else { return }
                    self.state = .error(error.localizedDescription)
                    request.invalidate()
                    return
                }
            }
            guard !Task.isCancelled, self.contentRequestIsCurrent(request, book: book) else { return }
            self.backendLoadTask = nil
            guard !Task.isCancelled, self.contentRequestIsCurrent(request, book: book) else { return }
            self.loadBackendContent(LibraryReaderDestination(sectionLocator: target, focusLocator: nil), continuing: request)
        }
    }

    func loadBackendContent(_ destination: LibraryReaderDestination,
                            continuing initialRequest: ReaderInitialContentRequest? = nil) {
        guard let book = currentBook else { return }
        let request: ReaderInitialContentRequest
        if let initialRequest {
            // Only the original initial resolver can continue its already
            // consumed invocation; it cannot claim or issue another request.
            guard case .initial = initialRequest.source.input,
                  contentRequestIsCurrent(initialRequest, book: book) else { return }
            request = initialRequest
        } else {
            guard let created = claimContentRequest(nil, input: .destination(destination), book: book) else { return }
            request = created
        }
        guard contentLoadCoordinator.beginInitialContentHandoff(request, destination: destination),
              contentLoadCoordinator.recordInitialContentDestination(destination, request: request) else { return }
        currentDestination = destination
        guard contentRequestIsCurrent(request, book: book) else { return }
        loadBackendContentInternal(locator: destination.sectionLocator, focusLocator: destination.focusLocator, request: request, book: book)
    }

    func loadBackendContent(_ locator: TextLocator,
                            continuing initialRequest: ReaderInitialContentRequest? = nil) {
        guard let book = currentBook,
              let request = claimContentRequest(initialRequest, input: .locator(locator), book: book) else { return }
        loadTOC(book: book)
        guard contentRequestIsCurrent(request, book: book) else { return }
        let focus = currentDestination?.sectionLocator == locator ? currentDestination?.focusLocator : nil
        guard contentLoadCoordinator.beginInitialContentHandoff(request,
            destination: LibraryReaderDestination(sectionLocator: locator, focusLocator: focus)) else { return }
        loadBackendContentInternal(locator: locator, focusLocator: focus, request: request, book: book)
    }

    private func loadBackendContentInternal(locator: TextLocator, focusLocator: TextLocator?,
                                            request: ReaderInitialContentRequest, book: BooksData) {
        loadTOC(book: book)
        guard contentRequestIsCurrent(request, book: book) else { return }
        let resolved = ReaderDestinationResolver.resolve(locator: locator)
        let effectiveSection = resolved.sectionLocator
        let effectiveFocus = focusLocator ?? resolved.focusLocator
        let destination = LibraryReaderDestination(sectionLocator: effectiveSection, focusLocator: effectiveFocus)
        guard contentLoadCoordinator.recordInitialContentDestination(destination, request: request) else { return }
        currentDestination = destination
        guard contentRequestIsCurrent(request, book: book) else { return }
        selectedSegmentLocator = effectiveFocus
        guard contentRequestIsCurrent(request, book: book) else { return }
        backendLoadTask?.cancel()
        guard contentRequestIsCurrent(request, book: book) else { return }
        state = .loading
        guard contentRequestIsCurrent(request, book: book) else { return }
        let scrollTarget: ReaderScrollTarget? = pendingReaderScrollTarget == .top ? .top : (pendingReaderScrollTarget == .bottom ? .bottom : nil)
        guard let token = contentLoadCoordinator.beginRequest(continuing: request,
            backend: effectiveSection.backend,
            workKey: effectiveSection.workKey,
            sectionLocator: effectiveSection,
            scrollTarget: scrollTarget
        ), contentRequestIsCurrent(request, book: book) else { return }
        backendLoadTask = Task { @MainActor [weak self] in
            defer { if Task.isCancelled { request.invalidate() } }
            guard let self, !Task.isCancelled, self.contentRequestIsCurrent(request, book: book) else { return }
            do {
                let section = try await BackendCoordinator.shared.section(at: effectiveSection)
                try Task.checkCancellation()
                guard self.contentRequestIsCurrent(request, book: book),
                      self.contentLoadCoordinator.canApplyContent(token: token, currentBookLocator: self.currentBook?.backendLocator) else { return }
                let renderModel = try await MaktabahBackendAdapter.preparedRenderModel(from: section)
                try Task.checkCancellation()
                guard self.contentRequestIsCurrent(request, book: book),
                      self.contentLoadCoordinator.canApplyContent(token: token, currentBookLocator: self.currentBook?.backendLocator) else { return }
                self.backendSection = section
                guard self.contentRequestIsCurrent(request, book: book) else { return }
                self.backendRenderModel = renderModel
                guard self.contentRequestIsCurrent(request, book: book) else { return }
                let content = MaktabahBackendAdapter.content(from: section, renderModel: renderModel)
                guard self.contentRequestIsCurrent(request, book: book) else { return }
                if let bookID = self.currentBook?.id { BookPageCache.shared.set(bookId: bookID, content: content) }
                guard self.contentRequestIsCurrent(request, book: book) else { return }
                // The original publisher checks this same retained source
                // between its existing fields/callbacks. A replacement cannot
                // let the outer publication continue or clear its new Task.
                self.updateContentState(with: content, validating: { self.contentRequestIsCurrent(request, book: book) })
                guard self.contentRequestIsCurrent(request, book: book) else { return }
                self.selectedSegmentLocator = self.currentDestination?.focusLocator
                guard self.contentRequestIsCurrent(request, book: book) else { return }
                self.state = .loaded
                guard self.contentRequestIsCurrent(request, book: book) else { return }
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
                                guard self.contentRequestIsCurrent(request, book: book),
                                      self.contentLoadCoordinator.isNavigationItemsRequestActive(generation: navGen, workKey: workLocator.workKey) else { return }
                                self.navigationItems = items
                            }
                        }
                    }
                }
            } catch is CancellationError {
                request.invalidate()
                return
            } catch LibraryBackendError.staleRequest {
                request.invalidate()
                return
            } catch {
                guard !Task.isCancelled, self.contentRequestIsCurrent(request, book: book),
                      self.contentLoadCoordinator.isTokenActive(token) else { return }
                self.contentText = error.localizedDescription
                guard self.contentRequestIsCurrent(request, book: book) else { return }
                self.state = .error(error.localizedDescription)
                if self.contentRequestIsCurrent(request, book: book) { self.backendLoadTask = nil }
                request.invalidate()
                return
            }
            if self.contentRequestIsCurrent(request, book: book), self.contentLoadCoordinator.isTokenActive(token) {
                self.backendLoadTask = nil
                if self.contentRequestIsCurrent(request, book: book) { self.contentLoadCoordinator.finishInitialContentRequest(request) }
            }
        }
    }

    func loadTOC(book: BooksData) {
        tocViewModel.loadTOC(book: book)
    }

    func getContent(bkId: Int, contentId: Int) -> BookContent? {
        bookConnection.getContent(bkid: String(bkId), contentId: contentId)
    }

    func loadFromHistory(for book: BooksData, validating isCurrent: (() -> Bool)? = nil) {
        guard isCurrent?() ?? true else { return }
        // Try to restore from history first
        guard let lastContentId = historyVM.entriesByBookId[book.id]?.lastContentId,
              let content = bookConnection.getContent(bkid: String(book.id), contentId: lastContentId)
        else {
            getFirstBookContent(for: book, validating: isCurrent)
            return
        }

        updateContentState(with: content, validating: isCurrent)
    }

    func getFirstBookContent(for book: BooksData, validating isCurrent: (() -> Bool)? = nil) {
        guard isCurrent?() ?? true else { return }
        if let content = bookConnection.getFirstContent(bkid: String(book.id)) {
            updateContentState(with: content, validating: isCurrent)
        } else {
            guard isCurrent?() ?? true else { return }
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
