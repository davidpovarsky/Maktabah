import Foundation

@MainActor
enum ZayitSearchReaderNavigationAdapter {
    @discardableResult
    static func open(
        _ hit: ZayitSearchHit,
        using navigationManager: iOSNavigationManager
    ) -> Bool {
        let bookID = Int(hit.bookId)
        let book = try? OtzariaDatabaseManagerAdapter.resolveBook(
            stableKey: hit.stableBookKey,
            expectedBookId: bookID
        )

        guard let book else {
            navigationManager.alertMessage = .init(
                title: "Zayit Search",
                message: "The search index does not match the installed library. Update or repair Search Data before opening results."
            )
            return false
        }

        navigationManager.openBook(
            book,
            initialContentId: hit.lineIndex,
            searchText: hit.matchedTerms.isEmpty ? nil : hit.matchedTerms.joined(separator: "|")
        )
        return true
    }
}
