import Foundation

/// Stable negative IDs for old Maktabah APIs. Canonical persistence remains TextLocator.
final class LegacyIdentityRegistry: @unchecked Sendable {
    static let shared = LegacyIdentityRegistry()
    private let lock = NSLock()
    private let defaults = UserDefaults.standard
    private let mapKey = "qualifiedLocatorSurrogates.v1"
    private let locatorKey = "qualifiedLocatorReverse.v1"
    private var map: [String: Int]
    private var reverse: [Int: TextLocator]

    private init() {
        map = defaults.dictionary(forKey: mapKey) as? [String: Int] ?? [:]
        reverse = [:]
        if let data = defaults.data(forKey: locatorKey),
           let stored = try? JSONDecoder().decode([String: TextLocator].self, from: data) {
            reverse = Dictionary(uniqueKeysWithValues: stored.compactMap { key, value in Int(key).map { ($0, value) } })
        }
    }

    func id(for locator: TextLocator) -> Int {
        lock.lock(); defer { lock.unlock() }
        if let existing = map[locator.persistenceKey] { return existing }
        let next = (map.values.min() ?? 0) - 1
        map[locator.persistenceKey] = next
        reverse[next] = locator
        defaults.set(map, forKey: mapKey)
        if let data = try? JSONEncoder().encode(Dictionary(uniqueKeysWithValues: reverse.map { (String($0.key), $0.value) })) {
            defaults.set(data, forKey: locatorKey)
        }
        return next
    }

    func locator(for id: Int) -> TextLocator? {
        lock.lock(); defer { lock.unlock() }
        return reverse[id]
    }
}
