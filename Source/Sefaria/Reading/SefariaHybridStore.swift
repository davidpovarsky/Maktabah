import Foundation

actor SefariaHybridStore: LibraryTextProviding {
    private let offline: SefariaOfflineStore
    private let remote: SefariaRemoteStore
    private var memoryCache: [String: LibraryTextSection] = [:]
    private var cacheOrder: [String] = []
    private let cacheLimit: Int

    init(offline: SefariaOfflineStore, remote: SefariaRemoteStore, cacheLimit: Int = 12) {
        self.offline = offline
        self.remote = remote
        self.cacheLimit = cacheLimit
    }

    func section(at locator: TextLocator) async throws -> LibraryTextSection {
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
        Task(priority: .utility) { [remote] in _ = try? await remote.section(at: locator) }
    }
}
