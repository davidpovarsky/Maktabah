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

        // Reader content IDs are qualified registry surrogates, not SQL line
        // indices. Use the same exact locator on a new or already open tab so
        // the content request and its search event identify the same render.
        let locator = TextLocator(backend: .otzaria, workKey: "book:\(bookID)",
                                  position: .legacyLine(hit.lineIndex))
        let contentID = LegacyIdentityRegistry.shared.id(for: locator)
        navigationManager.openBook(
            book,
            options: OpenBookOptions(
                contentId: contentID,
                // These are provider-authored matched terms, not a legacy FTS
                // expression. Retain them verbatim in the renderer's existing
                // term path instead of joining them into a synthetic query event.
                searchText: hit.matchedTerms.joined(separator: " "),
                highlightTerms: hit.matchedTerms
            )
        )
        return true
    }
}
