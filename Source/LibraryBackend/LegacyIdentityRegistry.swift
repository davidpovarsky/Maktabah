import Foundation

/// Stable negative IDs for old Maktabah APIs. Canonical persistence remains TextLocator.
final class LegacyIdentityRegistry: @unchecked Sendable {
    static let shared = LegacyIdentityRegistry()
    private let lock = NSLock()
    private let defaults: UserDefaults
    private let mapKey = "qualifiedLocatorSurrogates.v1"
    private let locatorKey = "qualifiedLocatorReverse.v1"
    private let titleKey = "qualifiedLocatorTitles.v1"
    private let persistenceQueue = DispatchQueue(label: "com.maktabah.legacy-identity.persistence", qos: .utility)
    private let persistenceDelay: TimeInterval
    private var map: [String: Int]
    private var reverse: [Int: TextLocator]
    private var titles: [String: String]
    private var nextID: Int
    private var mutationGeneration: UInt64 = 0
    private var persistedGeneration: UInt64 = 0
    private var persistenceScheduled = false
    private(set) var persistenceBatchCount = 0

    init(defaults: UserDefaults = .standard, persistenceDelay: TimeInterval = 0.25) {
        self.defaults = defaults
        self.persistenceDelay = persistenceDelay
        let storedMap = defaults.dictionary(forKey: mapKey) as? [String: Int] ?? [:]
        map = storedMap
        reverse = [:]
        titles = defaults.dictionary(forKey: titleKey) as? [String: String] ?? [:]
        if let data = defaults.data(forKey: locatorKey),
           let stored = try? JSONDecoder().decode([String: TextLocator].self, from: data) {
            reverse = Dictionary(uniqueKeysWithValues: stored.compactMap { key, value in Int(key).map { ($0, value) } })
        }
        nextID = (storedMap.values.min() ?? 0) - 1
    }

    func id(for locator: TextLocator) -> Int {
        id(for: locator, title: nil)
    }

    func id(for locator: TextLocator, title: String?) -> Int {
        lock.lock(); defer { lock.unlock() }
        if let title = title, titles[locator.persistenceKey] != title {
            titles[locator.persistenceKey] = title
            mutationGeneration &+= 1
            schedulePersistenceLocked()
        }
        if let existing = map[locator.persistenceKey] { return existing }
        let next = nextID
        nextID -= 1
        map[locator.persistenceKey] = next
        reverse[next] = locator
        mutationGeneration &+= 1
        schedulePersistenceLocked()
        return next
    }

    func register(title: String, for locator: TextLocator) {
        lock.lock(); defer { lock.unlock() }
        guard titles[locator.persistenceKey] != title else { return }
        titles[locator.persistenceKey] = title
        mutationGeneration &+= 1
        schedulePersistenceLocked()
    }

    func title(for locator: TextLocator) -> String? {
        lock.lock(); defer { lock.unlock() }
        return titles[locator.persistenceKey]
    }

    func title(for id: Int) -> String? {
        lock.lock(); defer { lock.unlock() }
        guard let locator = reverse[id] else { return nil }
        return titles[locator.persistenceKey]
    }

    func locator(for id: Int) -> TextLocator? {
        lock.lock(); defer { lock.unlock() }
        return reverse[id]
    }

    func flush() {
        let snapshot: ([String: Int], [Int: TextLocator], [String: String], UInt64)? = lock.synchronized {
            guard mutationGeneration > persistedGeneration else {
                persistenceScheduled = false
                return nil
            }
            return (map, reverse, titles, mutationGeneration)
        }
        guard let snapshot else { return }
        persist(snapshot)
        lock.synchronized {
            persistedGeneration = max(persistedGeneration, snapshot.3)
            persistenceScheduled = false
        }
    }

    private func schedulePersistenceLocked() {
        guard !persistenceScheduled else { return }
        persistenceScheduled = true
        persistenceQueue.asyncAfter(deadline: .now() + persistenceDelay) { [weak self] in
            self?.persistPendingChanges()
        }
    }

    private func persistPendingChanges() {
        let snapshot: ([String: Int], [Int: TextLocator], [String: String], UInt64)? = lock.synchronized {
            guard persistenceScheduled, mutationGeneration > persistedGeneration else { return nil }
            return (map, reverse, titles, mutationGeneration)
        }
        guard let snapshot else { return }
        persist(snapshot)
        lock.synchronized {
            persistedGeneration = max(persistedGeneration, snapshot.3)
            persistenceScheduled = false
            if mutationGeneration > persistedGeneration {
                schedulePersistenceLocked()
            }
        }
    }

    private func persist(_ snapshot: ([String: Int], [Int: TextLocator], [String: String], UInt64)) {
        defaults.set(snapshot.0, forKey: mapKey)
        defaults.set(snapshot.2, forKey: titleKey)
        let storedReverse = Dictionary(uniqueKeysWithValues: snapshot.1.map { (String($0.key), $0.value) })
        if let data = try? JSONEncoder().encode(storedReverse) {
            defaults.set(data, forKey: locatorKey)
        }
        lock.synchronized { persistenceBatchCount += 1 }
    }
}

private extension NSLock {
    func synchronized<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
