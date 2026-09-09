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
        case .sefaria:
            guard let book = MaktabahBackendAdapter.resolveBook(
                for: locator,
                in: LibraryDataManager.shared
            ) else { return }
            openBookInNewTab(book, initialContentId: nil)
        }
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
