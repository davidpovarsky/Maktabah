import Foundation

/// Pure decisions shared by the app and the macOS CI recovery harness.
enum OtzariaSearchIndexingPolicy {
    static func quarantineMatches(
        recordSourceKey: String,
        recordSourceIdentity: String,
        sourceKey: String,
        sourceIdentity: String
    ) -> Bool {
        recordSourceKey == sourceKey && recordSourceIdentity == sourceIdentity
    }

    /// A native PDF fingerprint of zero is deliberately ignored. Freshness is
    /// proven only by the local DB-backed source identity plus indexed presence.
    static func pdfIsFresh(
        storedLocalIdentity: String?,
        currentLocalIdentity: String,
        indexedPathExists: Bool
    ) -> Bool {
        indexedPathExists && storedLocalIdentity == currentLocalIdentity
    }

    static func canIncludeNextBook(
        booksWritten: Int,
        documentsWritten: Int,
        bytesWritten: UInt64,
        nextDocuments: Int,
        nextBytes: UInt64,
        elapsed: TimeInterval,
        maxBooks: Int,
        maxDocuments: Int,
        maxBytes: UInt64,
        elapsedBudget: TimeInterval
    ) -> Bool {
        booksWritten == 0 || (
            booksWritten < maxBooks
            && documentsWritten + max(nextDocuments, 1) <= maxDocuments
            && bytesWritten + nextBytes <= maxBytes
            && elapsed < elapsedBudget
        )
    }

    static func isOversized(documents: Int, bytes: UInt64, maxDocuments: Int, maxBytes: UInt64) -> Bool {
        max(documents, 1) > maxDocuments || bytes > maxBytes
    }
}
