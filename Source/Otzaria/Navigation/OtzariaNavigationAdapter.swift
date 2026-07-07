import Foundation

#if os(iOS)
@MainActor
enum OtzariaNavigationAdapter {
    static var isEnabled: Bool {
        OtzariaMaktabahBridge.shared.isEnabled
    }

    static func shouldIgnoreBookIntegrationChange() -> Bool {
        isEnabled
    }

    @discardableResult
    static func confirmPendingBookIntegrationIfEnabled(
        state: BundleArchiveDownloadProgressState,
        presentReader: (BooksData, Int?) -> Void,
        removeState: (UUID) -> Void
    ) -> Bool {
        guard isEnabled else { return false }

        if case .single(let book, let initialContentId) = state.pendingData {
            presentReader(book, initialContentId)
        }
        removeState(state.id)
        return true
    }

    @discardableResult
    static func openBookIfEnabled(
        _ book: BooksData,
        initialContentId: Int?,
        searchText: String?,
        targetAnnotation: Annotation?,
        presentReader: (BooksData, Int?, String?, Annotation?) -> Void
    ) -> Bool {
        guard isEnabled else { return false }

        HistoryViewModel.shared.addBookToHistory(book.id)
        if let initialContentId {
            HistoryViewModel.shared.updateLastContentId(initialContentId, for: book.id)
        }
        presentReader(book, initialContentId, searchText, targetAnnotation)
        return true
    }

    @discardableResult
    static func presentReaderForIntegrationIfEnabled(
        _ book: BooksData,
        initialContentId: Int?,
        presentReader: (BooksData, Int?) -> Void
    ) -> Bool {
        guard isEnabled else { return false }
        presentReader(book, initialContentId)
        return true
    }

    static func bulkDownloadMessageIfEnabled() -> iOSNavigationManager.AlertMessage? {
        guard isEnabled else { return nil }
        return iOSNavigationManager.AlertMessage(
            title: NSLocalizedString("Download Book", comment: "Bulk download window title"),
            message: NSLocalizedString("Books are already available from the selected Otzaria database.", comment: "Otzaria bulk download not needed")
        )
    }
}
#endif
