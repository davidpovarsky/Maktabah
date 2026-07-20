import Foundation
import UniformTypeIdentifiers

@MainActor
final class ZayitSearchFolderAccess: ObservableObject {
    @Published private(set) var folderURL: URL?
    private let key = "zayit-search-folder-bookmark-v2"
    private let legacyKey = "zayit-search-folder-bookmark-v1"
    private var activeURL: URL?

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
        UserDefaults.standard.data(forKey: key) != nil ||
            UserDefaults.standard.data(forKey: legacyKey) != nil
    }

    deinit {
        activeURL?.stopAccessingSecurityScopedResource()
    }

    func selectAndActivate(_ url: URL) throws -> URL {
        deactivate()
        guard url.startAccessingSecurityScopedResource() else {
            throw AccessError.permissionDenied
        }

        do {
            try saveBookmark(for: url)
            UserDefaults.standard.removeObject(forKey: legacyKey)
            activeURL = url
            folderURL = url
            return url
        } catch {
            url.stopAccessingSecurityScopedResource()
            throw error
        }
    }

    func restoreAndActivate() throws -> URL? {
        if let activeURL { return activeURL }

        let defaults = UserDefaults.standard
        let currentData = defaults.data(forKey: key)
        let isLegacy = currentData == nil
        guard let data = currentData ?? defaults.data(forKey: legacyKey) else { return nil }

        var stale = false
        let url: URL
        do {
            url = try URL(
                resolvingBookmarkData: data,
                options: bookmarkResolutionOptions,
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
        } catch {
            if isLegacy {
                defaults.removeObject(forKey: legacyKey)
                throw AccessError.legacyBookmarkRequiresReselection
            }
            throw error
        }

        guard url.startAccessingSecurityScopedResource() else {
            if isLegacy {
                defaults.removeObject(forKey: legacyKey)
                throw AccessError.legacyBookmarkRequiresReselection
            }
            throw AccessError.permissionDenied
        }

        do {
            if stale || isLegacy {
                try saveBookmark(for: url)
            }
            defaults.removeObject(forKey: legacyKey)
            activeURL = url
            folderURL = url
            return url
        } catch {
            url.stopAccessingSecurityScopedResource()
            if isLegacy {
                defaults.removeObject(forKey: legacyKey)
                throw AccessError.legacyBookmarkRequiresReselection
            }
            throw error
        }
    }

    func deactivate() {
        activeURL?.stopAccessingSecurityScopedResource()
        activeURL = nil
    }

    func clear() {
        deactivate()
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: legacyKey)
        folderURL = nil
    }

    private func saveBookmark(for url: URL) throws {
        let data = try url.bookmarkData(
            options: bookmarkCreationOptions,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(data, forKey: key)
    }

    enum AccessError: LocalizedError {
        case notConfigured
        case permissionDenied
        case legacyBookmarkRequiresReselection

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "No Zayit Search data folder is configured."
            case .permissionDenied:
                return "The selected folder is no longer accessible. Choose it again."
            case .legacyBookmarkRequiresReselection:
                return "Choose the Zayit Search data folder again to renew access."
            }
        }
    }
}
