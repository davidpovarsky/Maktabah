import Foundation

enum OtzariaBookConnectionAdapter {
    static var isEnabled: Bool {
        OtzariaMaktabahBridge.shared.isEnabled
    }

    @discardableResult
    static func connectIfEnabled(archive: Int) throws -> Bool {
        guard isEnabled else { return false }

        let start = Date()
        log("connect start enabled=true archive=\(archive)")
        do {
            try OtzariaMaktabahBridge.shared.openIfNeeded()
            log("connect done enabled=true archive=\(archive) durationMs=\(elapsedMs(start))")
            return true
        } catch {
            log("connect error enabled=true archive=\(archive) error=\(error.localizedDescription) durationMs=\(elapsedMs(start))")
            throw error
        }
    }

    static func getContent(bkid: String, contentId: Int) -> BookContent? {
        guard isEnabled, let bookId = Int(bkid) else { return nil }

        let start = Date()
        let content = OtzariaMaktabahBridge.shared.getContent(
            bookId: bookId,
            contentId: contentId
        )
        log("getContent enabled=true bookId=\(bookId) contentId=\(contentId) result=\(content == nil ? "nil" : "ok") durationMs=\(elapsedMs(start))")
        return content
    }

    static func getFirstContent(bkid: String) -> BookContent? {
        guard isEnabled, let bookId = Int(bkid) else { return nil }

        let start = Date()
        let content = OtzariaMaktabahBridge.shared.getFirstContent(bookId: bookId)
        log("getFirstContent enabled=true bookId=\(bookId) result=\(content == nil ? "nil" : "ok") durationMs=\(elapsedMs(start))")
        return content
    }

    static func getContent(bkid: String, part: Int, page: Int) -> BookContent? {
        guard isEnabled, let bookId = Int(bkid) else { return nil }

        return OtzariaMaktabahBridge.shared.getContent(
            bookId: bookId,
            contentId: page
        )
    }

    static func getNextPage(from currentBook: BooksData, contentId: Int) -> BookContent? {
        guard isEnabled else { return nil }

        let start = Date()
        let content = OtzariaMaktabahBridge.shared.getNextContent(
            bookId: currentBook.id,
            after: contentId
        )
        log("getNextPage enabled=true bookId=\(currentBook.id) contentId=\(contentId) result=\(content == nil ? "nil" : "ok") durationMs=\(elapsedMs(start))")
        return content
    }

    static func getPrevPage(from currentBook: BooksData, contentId: Int) -> BookContent? {
        guard isEnabled else { return nil }

        let start = Date()
        let content = OtzariaMaktabahBridge.shared.getPreviousContent(
            bookId: currentBook.id,
            before: contentId
        )
        log("getPrevPage enabled=true bookId=\(currentBook.id) contentId=\(contentId) result=\(content == nil ? "nil" : "ok") durationMs=\(elapsedMs(start))")
        return content
    }

    static func getTotalParts(bkid: String) -> Int? {
        guard isEnabled, let bookId = Int(bkid) else { return nil }
        return OtzariaMaktabahBridge.shared.getTotalParts(bookId: bookId)
    }

    static func getMaxPage(bkid: String) -> Int? {
        guard isEnabled, let bookId = Int(bkid) else { return nil }
        return OtzariaMaktabahBridge.shared.getMaxPage(bookId: bookId)
    }

    static func getMinPage(bkid: String) -> Int? {
        guard isEnabled, let bookId = Int(bkid) else { return nil }
        return OtzariaMaktabahBridge.shared.getMinPage(bookId: bookId)
    }

    static func getTOCEntries(for book: BooksData) -> [TOC]? {
        guard isEnabled else { return nil }

        let start = Date()
        let entries = OtzariaMaktabahBridge.shared.getTOCEntries(for: book)
        log("getTOCEntries enabled=true bookId=\(book.id) count=\(entries.count) durationMs=\(elapsedMs(start))")
        return entries
    }

    private static func log(_ message: String) {
        OtzariaFileLogger.shared.log("[BookConnection] \(message)")
    }

    private static func elapsedMs(_ start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * 1000)
    }
}
