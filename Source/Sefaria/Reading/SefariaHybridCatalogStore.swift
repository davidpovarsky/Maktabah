import Foundation

actor SefariaHybridCatalogStore: LibraryCatalogProviding {
    private let remote: SefariaRemoteStore
    private let packages: SefariaPackageManager

    init(remote: SefariaRemoteStore, packages: SefariaPackageManager) {
        self.remote = remote
        self.packages = packages
    }

    func catalog(forceRefresh: Bool) async throws -> [LibraryCatalogNode] {
        do { return try await remote.catalog(forceRefresh: forceRefresh) }
        catch {
            let installed = await packages.installedWorkKeys()
            guard !installed.isEmpty else { throw error }
            let children = installed.sorted().map { title -> LibraryCatalogNode in
                let locator = TextLocator(backend: .sefaria, workKey: title, position: .canonicalRef(title))
                let work = LibraryWork(locator: locator, title: title, heTitle: nil,
                    categories: ["Downloaded"], description: nil)
                return LibraryCatalogNode(id: locator.persistenceKey, kind: .work, title: title,
                    heTitle: nil, work: work, children: [])
            }
            return [LibraryCatalogNode(id: "sefaria-offline-downloaded", kind: .category,
                title: "Downloaded", heTitle: "הורדו", work: nil, children: children)]
        }
    }
}
