import Foundation

func runLegacyIdentityRegistryTests() throws {
    let suite = "LegacyIdentityRegistryTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }

    let registry = LegacyIdentityRegistry(defaults: defaults, persistenceDelay: 60)
    let locators = (0..<500).map {
        TextLocator(backend: .sefaria, workKey: "Work \($0)", position: .canonicalRef("Work \($0) 1"))
    }
    let firstIDs = locators.map(registry.id(for:))
    try expect(Set(firstIDs).count == locators.count, "legacy surrogate IDs are unique")
    try expect(registry.persistenceBatchCount == 0, "lookups do not synchronously rewrite UserDefaults")
    registry.flush()
    try expect(registry.persistenceBatchCount == 1, "bulk identity creation is persisted in one batch")

    let reloaded = LegacyIdentityRegistry(defaults: defaults, persistenceDelay: 60)
    try expect(locators.map(reloaded.id(for:)) == firstIDs, "legacy surrogate IDs remain stable after reload")
    try expect(reloaded.persistenceBatchCount == 0, "cached legacy lookups do not write UserDefaults")
    try expect(reloaded.locator(for: firstIDs[200]) == locators[200], "reverse identity mapping survives reload")
}
