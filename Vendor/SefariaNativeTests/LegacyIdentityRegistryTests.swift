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

    let tocLocator = TextLocator(backend: .sefaria, workKey: "Berakhot", position: .canonicalRef("Berakhot 2a"))
    let tocSurrogateID = registry.id(for: tocLocator, title: "ברכות")
    try expect(registry.locator(for: tocSurrogateID) == tocLocator, "TOC locator round-trips through registry")
    try expect(registry.title(for: tocLocator) == "ברכות", "title is retrieved by locator")
    try expect(registry.title(for: tocSurrogateID) == "ברכות", "title is retrieved by surrogate ID")
    try expect(registry.locator(for: 999_999_999) == nil, "unregistered surrogate ID returns nil")

    // Test HTML sanitization for annotation excerpts
    let rawHTML = "<span class=\"hebrew\">בראשית ברא</span><br/>אלהים &amp; שמים"
    let cleanText = rawHTML.readerPlainText
    try expect(cleanText == "בראשית ברא\nאלהים & שמים", "readerPlainText strips tags and decodes entities properly")
}
