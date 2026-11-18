import Foundation

#if os(iOS)
extension iOSNavigationManager {
    func openOtzariaLinkedSourceInNewTab(_ source: OtzariaLinkedSource) {
        guard OtzariaBackendActivation.isActive else { return }

        let book = LibraryDataManager.shared.getBook([source.linkedBookId]).first
            ?? (try? OtzariaMaktabahBridge.shared.fetchBook(byId: source.linkedBookId))

        guard let book else {
            OtzariaFileLogger.shared.log("[iOSNavigationManager] Otzaria linked source missing book linkedBookId=\(source.linkedBookId) linkedLineId=\(source.linkedLineId)")
            return
        }

        openBookInNewTab(book, initialContentId: source.linkedLineIndex)
        OtzariaFileLogger.shared.log("[iOSNavigationManager] Otzaria linked source opened bookId=\(source.linkedBookId) lineIndex=\(source.linkedLineIndex) lineId=\(source.linkedLineId)")
    }

    func openTorahInspectorLocationInNewTab(_ locator: TextLocator) {
        guard locator.backend == BackendCoordinator.shared.activeBackendID else { return }
        switch locator.backend {
        case .otzaria:
            guard case .legacyLine(let lineIndex) = locator.position,
                  let bookID = Int(locator.workKey.replacingOccurrences(of: "book:", with: "")),
                  let book = LibraryDataManager.shared.getBook([bookID]).first
                    ?? (try? OtzariaMaktabahBridge.shared.fetchBook(byId: bookID)) else { return }
            openBookInNewTab(book, initialContentId: lineIndex)
        case .sefaria, .sefariaEmbedded:
            var targetLocator = locator
            if case .canonicalRef(let ref) = locator.position {
                if locator.workKey == ref || locator.workKey.isEmpty {
                    let knownTitles = LibraryDataManager.shared.booksById.values.map(\.book)
                    if let resolvedWork = SefariaRef.workKey(from: ref, knownTitles: knownTitles) {
                        targetLocator = TextLocator(backend: locator.backend, workKey: resolvedWork, position: .canonicalRef(ref))
                    } else if let match = ref.range(of: #"\s+\d+.*$"#, options: .regularExpression) {
                        let work = String(ref[..<match.lowerBound])
                        targetLocator = TextLocator(backend: locator.backend, workKey: work, position: .canonicalRef(ref))
                    }
                }
            }
            let resolved = ReaderDestinationResolver.resolve(locator: targetLocator)
            guard let book = MaktabahBackendAdapter.resolveBook(
                for: resolved.sectionLocator,
                in: LibraryDataManager.shared
            ) else { return }
            openBookInNewTab(book, destination: resolved.destination)
        }
    }

    private func openBookInNewTab(_ book: BooksData, destination: LibraryReaderDestination) {
        let initialContentId = LegacyIdentityRegistry.shared.id(for: destination.sectionLocator)
        let tab = ReaderTab(id: UUID(), book: book, initialContentId: initialContentId,
                            viewModel: ReaderViewModel(book: book))
        _ = presentPreparedNativeReaderTab(tab, destination: destination)
    }

    /// Original linked-source presentation reused by the scene's Core-gated
    /// reservation. Construction alone never loads or opens a book.
    @discardableResult
    func presentPreparedNativeReaderTab(_ tab: ReaderTab, destination: LibraryReaderDestination) -> Bool {
        guard destination.sectionLocator.backend == BackendCoordinator.shared.activeBackendID,
              tab.book.backendLocator?.backend == destination.sectionLocator.backend,
              tab.book.backendLocator?.workKey == destination.sectionLocator.workKey,
              tab.viewModel.currentBook === tab.book,
              !openTabs.contains(where: { $0.id == tab.id }) else { return false }
        switchToMode(.viewer)
        if let activeId = activeTabId,
           let currentTab = openTabs.first(where: { $0.id == activeId }) {
            currentTab.viewModel.saveCurrentState()
        }
        tab.viewModel.loadBackendContent(destination)
        openTabs.append(tab)
        activeTabId = tab.id
        selectedContentId = tab.initialContentId
        selectedBook = tab.book
        return true
    }

    private func openBookInNewTab(_ book: BooksData, initialContentId: Int?) {
        switchToMode(.viewer)
        if let activeId = activeTabId,
           let currentTab = openTabs.first(where: { $0.id == activeId }) {
            currentTab.viewModel.saveCurrentState()
        }

        let viewModel = ReaderViewModel(book: book)
        viewModel.loadInitialContent(initialContentId: initialContentId)
        let newTab = ReaderTab(id: UUID(), book: book, initialContentId: initialContentId, viewModel: viewModel)
        openTabs.append(newTab)
        activeTabId = newTab.id
        selectedContentId = initialContentId
        selectedBook = book
    }
}
#endif
