import Foundation

/// Non-destructive sidecar persistence for source-qualified positions. Existing numeric
/// Maktabah records remain authoritative until an associated locator is written.
actor QualifiedLocatorStore {
    static let shared = QualifiedLocatorStore()

    private struct State: Codable {
        var schemaVersion = 1
        var locatorsByLegacyKey: [String: TextLocator] = [:]
        var favorites: [String: TextLocator] = [:]
        var history: [HistoryEntry] = []
    }

    struct HistoryEntry: Codable, Hashable, Identifiable, Sendable {
        let locator: TextLocator
        var title: String
        var lastOpened: Date
        var isFavorite: Bool
        var id: String { locator.persistenceKey }
    }

    private let fileURL: URL
    private var state: State

    init(fileURL: URL? = nil) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.fileURL = fileURL ?? base.appendingPathComponent("Maktabah/qualified-locators-v1.json")
        if let data = try? Data(contentsOf: self.fileURL),
           let decoded = try? JSONDecoder().decode(State.self, from: data) {
            state = decoded
        } else {
            state = State()
        }
    }

    func associate(_ locator: TextLocator, withLegacyKey key: String) async throws {
        state.locatorsByLegacyKey[key] = locator
        try persist()
    }

    func locator(forLegacyKey key: String) -> TextLocator? { state.locatorsByLegacyKey[key] }

    func record(_ locator: TextLocator, title: String) async throws {
        let favorite = state.favorites[locator.persistenceKey] != nil
        state.history.removeAll { $0.id == locator.persistenceKey }
        state.history.insert(.init(locator: locator, title: title, lastOpened: Date(), isFavorite: favorite), at: 0)
        state.history = Array(state.history.prefix(500))
        try persist()
    }

    func setFavorite(_ favorite: Bool, locator: TextLocator, title: String) async throws {
        if favorite { state.favorites[locator.persistenceKey] = locator }
        else { state.favorites.removeValue(forKey: locator.persistenceKey) }
        if let index = state.history.firstIndex(where: { $0.id == locator.persistenceKey }) {
            state.history[index].isFavorite = favorite
        } else if favorite {
            state.history.insert(.init(locator: locator, title: title, lastOpened: Date(), isFavorite: true), at: 0)
        }
        try persist()
    }

    func entries() -> [HistoryEntry] { state.history }

    func removeHistory(_ locator: TextLocator) async throws {
        if let index = state.history.firstIndex(where: { $0.id == locator.persistenceKey }) {
            if state.history[index].isFavorite {
                state.history[index].lastOpened = .distantPast
            } else {
                state.history.remove(at: index)
            }
            try persist()
        }
    }

    private func persist() throws {
        let manager = FileManager.default
        let directory = fileURL.deletingLastPathComponent()
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(state)
        let temporary = directory.appendingPathComponent(".qualified-locators-\(UUID().uuidString).tmp")
        try data.write(to: temporary, options: .atomic)
        if manager.fileExists(atPath: fileURL.path) {
            _ = try manager.replaceItemAt(fileURL, withItemAt: temporary)
        } else {
            try manager.moveItem(at: temporary, to: fileURL)
        }
    }
}
