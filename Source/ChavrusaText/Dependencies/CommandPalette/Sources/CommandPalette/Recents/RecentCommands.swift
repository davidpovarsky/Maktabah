import Combine
import Foundation

/// The ids of recently run commands, newest first, without duplicates and at most `limit` long.
///
/// A plain value with the rules; ``RecentCommandsStore`` keeps one and saves it.
public struct RecentCommands: Hashable, Sendable {
    /// Newest first.
    public private(set) var ids: [String]
    /// How many ids are kept.
    public let limit: Int

    public init(ids: [String] = [], limit: Int = 5) {
        self.limit = max(0, limit)
        var seen = Set<String>()
        self.ids = Array(ids.filter { seen.insert($0).inserted }.prefix(self.limit))
    }

    /// Moves `id` to the front, adding it when it is new and dropping the oldest beyond the limit.
    public mutating func record(_ id: String) {
        ids.removeAll { $0 == id }
        ids.insert(id, at: 0)
        if ids.count > limit {
            ids.removeLast(ids.count - limit)
        }
    }

    /// Forgets `id`.
    public mutating func remove(_ id: String) {
        ids.removeAll { $0 == id }
    }

    /// Forgets everything.
    public mutating func removeAll() {
        ids.removeAll()
    }

    /// The commands for the recent ids, newest first. Ids of commands that no longer exist are skipped.
    public func commands(from commands: [Command]) -> [Command] {
        ids.compactMap { id in commands.first { $0.id == id } }
    }
}

// MARK: - Storage

/// Where ``RecentCommandsStore`` keeps the recent ids. Inject your own to store them elsewhere, or
/// ``InMemoryRecentCommandsStorage`` in tests and previews.
@MainActor
public protocol RecentCommandsStorage: AnyObject {
    func loadRecentCommandIDs() -> [String]
    func saveRecentCommandIDs(_ ids: [String])
}

/// Keeps the recent ids in `UserDefaults` as an array of strings.
@MainActor
public final class UserDefaultsRecentCommandsStorage: RecentCommandsStorage {
    public let key: String
    private let defaults: UserDefaults

    public init(key: String = "CommandPalette.recentCommandIDs", defaults: UserDefaults = .standard) {
        self.key = key
        self.defaults = defaults
    }

    public func loadRecentCommandIDs() -> [String] {
        defaults.stringArray(forKey: key) ?? []
    }

    public func saveRecentCommandIDs(_ ids: [String]) {
        defaults.set(ids, forKey: key)
    }
}

/// Keeps the recent ids in memory only. For tests, previews and screenshots.
@MainActor
public final class InMemoryRecentCommandsStorage: RecentCommandsStorage {
    /// What was saved last, or the initial ids.
    public private(set) var ids: [String]
    /// How often the store saved.
    public private(set) var saveCount = 0

    public init(_ ids: [String] = []) {
        self.ids = ids
    }

    public func loadRecentCommandIDs() -> [String] {
        ids
    }

    public func saveRecentCommandIDs(_ ids: [String]) {
        self.ids = ids
        saveCount += 1
    }
}

// MARK: - Store

/// Remembers which commands were run, so the palette can list them under "Recent" when the
/// search field is empty.
///
/// ```swift
/// let recents = RecentCommandsStore()                       // UserDefaults, 5 commands
/// let recents = RecentCommandsStore(storage: InMemoryRecentCommandsStorage(), limit: 3)
/// recents.record(command)                                   // done by the palette when it runs one
/// recents.ids                                               // newest first
/// ```
@MainActor
public final class RecentCommandsStore: ObservableObject {
    /// The store the palette uses when you pass none: `UserDefaults.standard`, 5 commands.
    public static let shared = RecentCommandsStore()

    @Published public private(set) var recents: RecentCommands
    private let storage: any RecentCommandsStorage

    public init(storage: (any RecentCommandsStorage)? = nil, limit: Int = 5) {
        let storage = storage ?? UserDefaultsRecentCommandsStorage()
        self.storage = storage
        self.recents = RecentCommands(ids: storage.loadRecentCommandIDs(), limit: limit)
    }

    /// Newest first.
    public var ids: [String] { recents.ids }

    /// Moves the command to the front of the recent commands and saves.
    public func record(_ command: Command) {
        record(id: command.id)
    }

    /// Moves the command with this id to the front of the recent commands and saves.
    public func record(id: String) {
        recents.record(id)
        storage.saveRecentCommandIDs(recents.ids)
    }

    /// Forgets one command and saves.
    public func remove(id: String) {
        recents.remove(id)
        storage.saveRecentCommandIDs(recents.ids)
    }

    /// Forgets all recent commands and saves.
    public func clear() {
        recents.removeAll()
        storage.saveRecentCommandIDs(recents.ids)
    }

    /// The recent commands among `commands`, newest first.
    public func commands(from commands: [Command]) -> [Command] {
        recents.commands(from: commands)
    }
}
