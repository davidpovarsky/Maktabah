import Foundation

#if os(iOS)
extension iOSNavigationManager {
    func openOtzariaLinkedSourceInNewTab(_ source: OtzariaLinkedSource) {
        guard OtzariaMaktabahBridge.shared.isEnabled else { return }

        let book = LibraryDataManager.shared.getBook([source.linkedBookId]).first
            ?? (try? OtzariaMaktabahBridge.shared.fetchBook(byId: source.linkedBookId))

        guard let book else {
            OtzariaFileLogger.shared.log("[iOSNavigationManager] Otzaria linked source missing book linkedBookId=\(source.linkedBookId) linkedLineId=\(source.linkedLineId)")
            return
        }

        openBookInNewTab(book, initialContentId: source.linkedLineIndex)
        OtzariaFileLogger.shared.log("[iOSNavigationManager] Otzaria linked source opened bookId=\(source.linkedBookId) lineIndex=\(source.linkedLineIndex) lineId=\(source.linkedLineId)")
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
