import Foundation

actor SefariaHybridCatalogStore: LibraryCatalogProviding {
    private let remote: SefariaRemoteStore
    private let packages: SefariaPackageManager
    private let offline: SefariaOfflineStore

    init(
        remote: SefariaRemoteStore,
        packages: SefariaPackageManager,
        offline: SefariaOfflineStore
    ) {
        self.remote = remote
        self.packages = packages
        self.offline = offline
    }

    func catalog(forceRefresh: Bool) async throws -> [LibraryCatalogNode] {
        do {
            return try await remote.catalog(forceRefresh: forceRefresh)
        } catch {
            let installed = await packages.installedWorkKeys()
            guard !installed.isEmpty else { throw error }
            var indexes: [SefariaOfflineIndexDTO] = []
            for title in installed.sorted() {
                if let index = try? await offline.index(for: title) {
                    indexes.append(index)
                }
            }
            guard !indexes.isEmpty else { throw error }
            return Self.offlineCatalog(from: indexes)
        }
    }

    private static func offlineCatalog(
        from indexes: [SefariaOfflineIndexDTO]
    ) -> [LibraryCatalogNode] {
        final class MutableCategory {
            let title: String
            var heTitle: String?
            var categories: [String: MutableCategory] = [:]
            var works: [LibraryCatalogNode] = []

            init(title: String, heTitle: String? = nil) {
                self.title = title
                self.heTitle = heTitle
            }
        }

        let root = MutableCategory(title: "")
        for index in indexes.sorted(by: {
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }) {
            let categories = index.categories ?? ["Downloaded"]
            let hebrewCategories = index.heCategories ?? []
            var node = root
            for (offset, title) in categories.enumerated() {
                if node.categories[title] == nil {
                    node.categories[title] = MutableCategory(
                        title: title,
                        heTitle: hebrewCategories.indices.contains(offset)
                            ? hebrewCategories[offset]
                            : nil
                    )
                }
                node = node.categories[title]!
            }

            let locator = TextLocator(
                backend: .sefaria,
                workKey: index.title,
                position: .canonicalRef(index.title)
            )
            var work = LibraryWork(
                locator: locator,
                title: index.title,
                heTitle: index.heTitle,
                categories: categories,
                description: index.enDesc ?? index.heDesc
            )
            work.searchPath = SefariaCatalogIdentity.searchPath(
                parentPath: categories,
                title: index.title
            )
            node.works.append(LibraryCatalogNode(
                id: locator.persistenceKey,
                kind: .work,
                title: index.title,
                heTitle: index.heTitle,
                work: work,
                children: []
            ))
        }

        func freeze(_ category: MutableCategory, path: [String]) -> LibraryCatalogNode {
            let currentPath = path + [category.title]
            let nested = category.categories.values
                .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
                .map { freeze($0, path: currentPath) }
            return LibraryCatalogNode(
                id: SefariaCatalogIdentity.categoryID(path: currentPath),
                kind: .category,
                title: category.title,
                heTitle: category.heTitle,
                work: nil,
                children: nested + category.works
            )
        }

        return root.categories.values
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            .map { freeze($0, path: []) }
    }
}
