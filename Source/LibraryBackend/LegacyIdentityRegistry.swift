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

/// Canonical book IDs shared by backend-specific locators. Otzaria's database
/// ID remains the stable ID when the same work is present in both catalogs.
/// Only unique, exact normalized titles are linked so similarly named
/// commentaries cannot be attached to the wrong work.
final class CrossBackendBookIdentityIndex: @unchecked Sendable {
    static let shared = CrossBackendBookIdentityIndex()

    private let lock = NSLock()
    private var otzariaIDsByTitle: [String: Int] = [:]
    private var canonicalIDsByWork: [String: Int] = [:]

    func prepare(otzariaBooks: [(id: Int, title: String)]) {
        var candidates: [String: [Int]] = [:]
        for book in otzariaBooks {
            candidates[Self.normalizedTitle(book.title), default: []].append(book.id)
        }
        let unique = candidates.compactMapValues { ids in
            ids.count == 1 ? ids[0] : nil
        }
        lock.synchronized {
            otzariaIDsByTitle = unique
            for book in otzariaBooks {
                canonicalIDsByWork[Self.workKey(.otzaria, "book:\(book.id)")] = book.id
            }
        }
    }

    func register(_ work: LibraryWork, canonicalID: Int) {
        lock.synchronized {
            canonicalIDsByWork[Self.workKey(work.locator.backend, work.locator.workKey)] = canonicalID
        }
    }

    func canonicalID(for work: LibraryWork) -> Int? {
        if let existing = canonicalID(for: work.locator) { return existing }
        let candidates = [work.heTitle, work.title].compactMap { $0 }.map(Self.normalizedTitle)
        let matched = lock.synchronized {
            candidates.compactMap { otzariaIDsByTitle[$0] }.first
        }
        if let matched { register(work, canonicalID: matched) }
        return matched
    }

    func canonicalID(for locator: TextLocator) -> Int? {
        lock.synchronized {
            canonicalIDsByWork[Self.workKey(locator.backend, locator.workKey)]
        }
    }

    func areEquivalent(_ lhs: TextLocator, _ rhs: TextLocator) -> Bool {
        guard lhs.backend != rhs.backend,
              let left = canonicalID(for: lhs),
              let right = canonicalID(for: rhs) else { return false }
        return left == right
    }

    private static func workKey(_ backend: BackendID, _ workKey: String) -> String {
        "\(backend.rawValue)|\(workKey)"
    }

    private static func normalizedTitle(_ title: String) -> String {
        let scalars = title.decomposedStringWithCanonicalMapping.unicodeScalars.filter { scalar in
            !CharacterSet.nonBaseCharacters.contains(scalar)
                && (CharacterSet.letters.contains(scalar) || CharacterSet.decimalDigits.contains(scalar))
        }
        return String(String.UnicodeScalarView(scalars)).lowercased()
    }
}
