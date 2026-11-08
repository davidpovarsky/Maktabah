import Foundation
import Testing
@testable import CommandPalette

@Suite("Recent commands")
struct RecentCommandsTests {
    @Test func recordMovesToFrontWithoutDuplicates() {
        var recents = RecentCommands(limit: 3)
        recents.record("a")
        recents.record("b")
        recents.record("a")
        #expect(recents.ids == ["a", "b"])
    }

    @Test func recordDropsTheOldestBeyondTheLimit() {
        var recents = RecentCommands(ids: ["c", "b", "a"], limit: 3)
        recents.record("d")
        #expect(recents.ids == ["d", "c", "b"])
    }

    @Test func initDeduplicatesAndTrims() {
        let recents = RecentCommands(ids: ["a", "b", "a", "c", "d"], limit: 3)
        #expect(recents.ids == ["a", "b", "c"])
        #expect(RecentCommands(ids: ["a"], limit: -1).ids.isEmpty)
    }

    @Test func zeroLimitRemembersNothing() {
        var recents = RecentCommands(limit: 0)
        recents.record("a")
        #expect(recents.ids.isEmpty)
    }

    @Test func removeAndRemoveAll() {
        var recents = RecentCommands(ids: ["a", "b", "c"])
        recents.remove("b")
        #expect(recents.ids == ["a", "c"])
        recents.removeAll()
        #expect(recents.ids.isEmpty)
    }

    @Test func commandsSkipUnknownIDs() {
        let recents = RecentCommands(ids: ["new-window", "gone", "new-note"])
        #expect(recents.commands(from: Fixtures.commands).map(\.id) == ["new-window", "new-note"])
    }
}

@MainActor
@Suite("Recent commands store")
struct RecentCommandsStoreTests {
    @Test func loadsFromStorage() {
        let storage = InMemoryRecentCommandsStorage(["new-note", "new-folder"])
        let store = RecentCommandsStore(storage: storage)
        #expect(store.ids == ["new-note", "new-folder"])
        #expect(storage.saveCount == 0)
    }

    @Test func recordSaves() {
        let storage = InMemoryRecentCommandsStorage(["new-note"])
        let store = RecentCommandsStore(storage: storage, limit: 2)
        store.record(Fixtures.commands[2])
        store.record(id: "settings")
        #expect(store.ids == ["settings", "new-folder"])
        #expect(storage.ids == ["settings", "new-folder"])
        #expect(storage.saveCount == 2)
    }

    @Test func removeAndClearSave() {
        let storage = InMemoryRecentCommandsStorage(["a", "b"])
        let store = RecentCommandsStore(storage: storage)
        store.remove(id: "a")
        #expect(storage.ids == ["b"])
        store.clear()
        #expect(storage.ids.isEmpty)
        #expect(store.ids.isEmpty)
    }

    @Test func storageAboveTheLimitIsTrimmed() {
        let storage = InMemoryRecentCommandsStorage(["a", "b", "c", "d"])
        let store = RecentCommandsStore(storage: storage, limit: 2)
        #expect(store.ids == ["a", "b"])
    }

    @Test func storeResolvesCommands() {
        let store = RecentCommandsStore(storage: InMemoryRecentCommandsStorage(["settings", "new-note"]))
        #expect(store.commands(from: Fixtures.commands).map(\.title) == ["Settings…", "New Note"])
    }

    @Test func userDefaultsStorageRoundTrips() throws {
        let suite = "CommandPaletteTests.\(UInt64.random(in: 0...UInt64.max))"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let storage = UserDefaultsRecentCommandsStorage(key: "recents", defaults: defaults)
        #expect(storage.loadRecentCommandIDs().isEmpty)
        let store = RecentCommandsStore(storage: storage)
        store.record(id: "new-note")
        #expect(defaults.stringArray(forKey: "recents") == ["new-note"])
        #expect(RecentCommandsStore(storage: storage).ids == ["new-note"])
    }
}
