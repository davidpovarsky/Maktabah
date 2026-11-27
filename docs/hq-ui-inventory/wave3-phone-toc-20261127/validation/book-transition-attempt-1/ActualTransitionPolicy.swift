@MainActor
private struct MaktabahNativePhoneTOCBookTransition {
    let book: BooksData
    let beforeBook: BooksData?
    let beforeMode: AppMode?
    let beforeRevision: UInt64
    let afterRevision: UInt64
    let assignsBook: Bool

    init(manager: iOSNavigationManager, book: BooksData) throws {
        guard manager.selectedBook == nil || manager.selectedBook === book,
              let revision = manager.selectedBookPresentationRevision else {
            throw UIRouteError(.unavailable, "native_phone_toc_book_unavailable")
        }
        self.book = book
        beforeBook = manager.selectedBook
        beforeMode = manager.selectedBookPresentationMode
        beforeRevision = revision
        assignsBook = manager.selectedBook !== book || manager.selectedBookPresentationMode != .viewer
        if assignsBook {
            guard revision < .max else {
                throw UIRouteError(.staleState, "native_phone_toc_presentation_exhausted")
            }
            afterRevision = revision + 1
        } else {
            afterRevision = revision
        }
    }

    func validateBefore(_ manager: iOSNavigationManager) throws {
        guard manager.selectedBook === beforeBook,
              manager.selectedBookPresentationMode == beforeMode,
              manager.selectedBookPresentationRevision == beforeRevision else {
            throw UIRouteError(.staleState, "native_phone_toc_book_changed")
        }
    }

    func validateAfter(_ manager: iOSNavigationManager) throws {
        guard manager.selectedBook === book, manager.currentMode == .viewer,
              manager.selectedBookPresentationMode == .viewer,
              manager.selectedBookPresentationRevision == afterRevision else {
            throw UIRouteError(.staleState, "native_phone_toc_book_transition_changed")
        }
    }
}

