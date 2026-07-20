import Foundation

@MainActor
enum ZayitSearchReaderNavigationAdapter {
    @discardableResult
    static func open(
        _ hit: ZayitSearchHit,
        using navigationManager: iOSNavigationManager
    ) -> Bool {
        let bookID = Int(hit.bookId)
        let book = (try? OtzariaDatabaseManagerAdapter.fetchBook(byId: bookID))
            ?? LibraryDataManager.shared.getBook([bookID]).first

        guard let book else {
            navigationManager.alertMessage = .init(
                title: "Zayit Search",
                message: "The selected result's book is not available in the current library."
            )
            return false
        }

        navigationManager.openBook(
            book,
            initialContentId: hit.lineIndex
        )
        return true
    }
}
