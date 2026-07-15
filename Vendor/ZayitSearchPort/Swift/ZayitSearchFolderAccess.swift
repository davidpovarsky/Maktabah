import Foundation
import UniformTypeIdentifiers

@MainActor
final class ZayitSearchFolderAccess: ObservableObject {
    @Published private(set) var folderURL: URL?
    private let key = "zayit-search-folder-bookmark-v1"
    private var activeURL: URL?

    deinit {
        activeURL?.stopAccessingSecurityScopedResource()
    }

    func restore() throws {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        var stale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
        if stale { try save(url) }
        folderURL = url
    }

    func save(_ url: URL) throws {
        deactivate()
        let data = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(data, forKey: key)
        folderURL = url
    }

    /// Keeps the security scope open for the whole lifetime of the search engine.
    /// The Rust engine opens SQLite and Tantivy files lazily during searches, so
    /// access must not be stopped immediately after validation.
    func activate() throws -> URL {
        guard let url = folderURL else { throw AccessError.notConfigured }
        if activeURL == url { return url }
        deactivate()
        guard url.startAccessingSecurityScopedResource() else {
            throw AccessError.permissionDenied
        }
        activeURL = url
        return url
    }

    func deactivate() {
        activeURL?.stopAccessingSecurityScopedResource()
        activeURL = nil
    }

    func clear() {
        deactivate()
        UserDefaults.standard.removeObject(forKey: key)
        folderURL = nil
    }

    enum AccessError: LocalizedError {
        case notConfigured
        case permissionDenied

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "No Zayit Search data folder is configured."
            case .permissionDenied:
                return "The selected folder is no longer accessible. Choose it again."
            }
        }
    }
}
