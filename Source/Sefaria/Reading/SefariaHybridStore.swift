import Foundation

actor SefariaHybridStore: LibraryTextProviding {
    private let offline: SefariaOfflineStore
    private let remote: SefariaRemoteStore
    private let navigation: any LibraryNavigationProviding
    private var memoryCache: [String: LibraryTextSection] = [:]
    private var cacheOrder: [String] = []
    private let cacheLimit: Int

    init(
        offline: SefariaOfflineStore,
        remote: SefariaRemoteStore,
        navigation: any LibraryNavigationProviding,
        cacheLimit: Int = 12
    ) {
        self.offline = offline
        self.remote = remote
        self.navigation = navigation
        self.cacheLimit = cacheLimit
    }

    func section(at locator: TextLocator) async throws -> LibraryTextSection {
        if LibraryReadingUnitPolicy.isWorkRoot(locator) {
            let work = LibraryWork(locator: locator, title: locator.workKey, heTitle: nil,
                categories: [], description: nil)
            let items = try await navigation.navigationItems(for: work)
            return try await section(at: LibraryReadingUnitPolicy.resolve(locator, navigationItems: items))
        }
        if let cached = memoryCache[locator.persistenceKey] { return cached }
        do {
            let local = try await offline.section(at: locator)
            remember(local)
            return local
        } catch LibraryBackendError.unavailableOffline {
            do {
                let fetched = try await remote.section(at: locator)
                remember(fetched)
                prefetch(fetched.next)
                return fetched
            } catch is URLError {
                throw LibraryBackendError.unavailableOffline
            }
        }
    }

    func clearTransientState() {
        memoryCache.removeAll()
        cacheOrder.removeAll()
    }

    private func remember(_ section: LibraryTextSection) {
        let key = section.locator.persistenceKey
        memoryCache[key] = section
        cacheOrder.removeAll { $0 == key }
        cacheOrder.append(key)
        while cacheOrder.count > cacheLimit, let oldest = cacheOrder.first {
            cacheOrder.removeFirst()
            memoryCache.removeValue(forKey: oldest)
        }
    }

    private func prefetch(_ locator: TextLocator?) {
        guard let locator, memoryCache[locator.persistenceKey] == nil else { return }
        Task(priority: .utility) { [weak self] in _ = try? await self?.section(at: locator) }
    }
}

actor SefariaHybridRelationshipsStore: LibraryRelationshipsProviding {
    private let offline: SefariaOfflineStore
    private let remote: SefariaRemoteStore

    init(offline: SefariaOfflineStore, remote: SefariaRemoteStore) {
        self.offline = offline
        self.remote = remote
    }

    func links(for locator: TextLocator) async throws -> [LibraryRelatedSource] {
        let installed = await offline.contains(workKey: locator.workKey)
        if installed {
            do {
                if let local = try await offline.relatedSources(at: locator) { return local }
            } catch LibraryBackendError.unavailableOffline {
                // The requested linked work may not belong to this local archive.
            }
        }
        do {
            return try await remote.links(for: locator)
        } catch LibraryBackendError.unavailableOffline {
            throw LibraryBackendError.unavailableOffline
        }
    }

    func topics(for locator: TextLocator) async throws -> [LibraryRelatedTopic] {
        do {
            return try await remote.topics(for: locator)
        } catch LibraryBackendError.unavailableOffline {
            throw LibraryBackendError.unavailableOffline
        }
    }
}
