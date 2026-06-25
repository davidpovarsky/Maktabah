import Foundation

struct OtzariaSecurityScopedBookmarkStore {
    struct RestoredBookmark {
        let url: URL
        let access: OtzariaSecurityScopedAccess
    }

    private let key = "goldcreative.otsaria.databaseBookmark"

    func save(url: URL) throws {
        let data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(data, forKey: key)
    }

    func restore() throws -> RestoredBookmark? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        var stale = false
        let url = try URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
        let access = try OtzariaSecurityScopedAccess.start(for: url)

        if stale {
            try save(url: url)
        }

        return RestoredBookmark(url: url, access: access)
    }

    func forget() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
