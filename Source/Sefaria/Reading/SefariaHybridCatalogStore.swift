import Foundation

actor SefariaHybridCatalogStore: LibraryCatalogProviding {
    private let remote: SefariaRemoteStore
    private let packages: SefariaPackageManager
    private let offline: SefariaOfflineStore
    private let snapshot: SefariaCatalogSnapshotStore
    private var refreshTask: Task<Void, Never>?

    init(
        remote: SefariaRemoteStore,
        packages: SefariaPackageManager,
        offline: SefariaOfflineStore,
        snapshot: SefariaCatalogSnapshotStore = SefariaCatalogSnapshotStore()
    ) {
        self.remote = remote
        self.packages = packages
        self.offline = offline
        self.snapshot = snapshot
    }

    func catalog(forceRefresh: Bool) async throws -> [LibraryCatalogNode] {
        if !forceRefresh, let stored = await snapshot.load() {
            if stored.isStale, refreshTask == nil {
                refreshTask = Task { [remote, snapshot] in
                    defer { Task { await self.clearRefreshTask() } }
                    guard let refreshed = try? await remote.catalog(forceRefresh: true) else { return }
                    try? await snapshot.save(refreshed)
                }
            }
            return stored.nodes
        }

        do {
            let nodes = try await remote.catalog(forceRefresh: forceRefresh)
            try? await snapshot.save(nodes)
            return nodes
        } catch {
            if let stored = await snapshot.load() {
                return stored.nodes
            }
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

    private func clearRefreshTask() {
        refreshTask = nil
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

actor SefariaCatalogSnapshotStore {
    struct StoredCatalog: Codable, Sendable {
        let schemaVersion: Int
        let savedAt: Date
        let nodes: [LibraryCatalogNode]

        var isStale: Bool {
            Date().timeIntervalSince(savedAt) > 6 * 60 * 60
        }
    }

    private let fileURL: URL

    init(directory: URL? = nil) {
        let base = directory
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("Maktabah/Sefaria", isDirectory: true)
        fileURL = base.appendingPathComponent("catalog-v1.json", isDirectory: false)
    }

    func load() -> StoredCatalog? {
        let startedAt = Date()
        guard let data = try? Data(contentsOf: fileURL),
              let stored = try? JSONDecoder().decode(StoredCatalog.self, from: data),
              stored.schemaVersion == 1,
              !stored.nodes.isEmpty else { return nil }
        let milliseconds = Int(Date().timeIntervalSince(startedAt) * 1_000)
        print("[SefariaCatalog] source=application-support decodeMs=\(milliseconds) nodes=\(stored.nodes.count)")
        return stored
    }

    func save(_ nodes: [LibraryCatalogNode]) throws {
        guard !nodes.isEmpty else { return }
        let startedAt = Date()
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let stored = StoredCatalog(schemaVersion: 1, savedAt: Date(), nodes: nodes)
        try JSONEncoder().encode(stored).write(to: fileURL, options: .atomic)
        let milliseconds = Int(Date().timeIntervalSince(startedAt) * 1_000)
        print("[SefariaCatalog] writeMs=\(milliseconds) nodes=\(nodes.count)")
    }
}
