import Foundation

struct OtzariaSecurityScopedBookmarkStore {
    struct RestoredBookmark {
        let url: URL
        let isStale: Bool
    }

    private let key = "goldcreative.otzaria.databaseBookmark.v2"
    private let legacyKey = "goldcreative.otsaria.databaseBookmark"

    private var bookmarkResolutionOptions: URL.BookmarkResolutionOptions {
        #if os(macOS)
        [.withSecurityScope]
        #else
        []
        #endif
    }

    private var bookmarkCreationOptions: URL.BookmarkCreationOptions {
        #if os(macOS)
        [.withSecurityScope]
        #else
        []
        #endif
    }

    var hasBookmark: Bool {
        UserDefaults.standard.data(forKey: key) != nil
    }

    func save(url: URL) throws {
        let data = try url.bookmarkData(
            options: bookmarkCreationOptions,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(data, forKey: key)
    }

    func restore() throws -> RestoredBookmark? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        var stale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: bookmarkResolutionOptions,
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
        return RestoredBookmark(url: url, isStale: stale)
    }

    func forget() {
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: legacyKey)
    }
}
