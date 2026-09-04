import Foundation

enum OtzariaLibraryPolicy {
    static var isEnabled: Bool {
        #if os(iOS)
        OtzariaMaktabahBridge.shared.isEnabled
        #else
        false
        #endif
    }

    static func isBookDownloaded(_ book: BooksData) -> Bool? {
        guard isEnabled else { return nil }
        return true
    }

    @discardableResult
    static func finishBulkDeletionIfEnabled(
        exitSelectionMode: () -> Void,
        onFinished: () -> Void
    ) -> Bool {
        guard isEnabled else { return false }
        exitSelectionMode()
        onFinished()
        return true
    }

    static func shouldSkipSingleBookDeletion() -> Bool {
        isEnabled
    }

    @MainActor
    @discardableResult
    static func finishBulkDownloadIfEnabled(
        onFinished: (String?) -> Void
    ) -> Bool {
        guard isEnabled else { return false }
        onFinished(nil)
        return true
    }
}
