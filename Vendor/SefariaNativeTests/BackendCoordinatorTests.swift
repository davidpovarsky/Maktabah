import Foundation

private actor FixtureCatalog: LibraryCatalogProviding {
    let delay: UInt64
    let title: String
    init(delay: UInt64 = 0, title: String) { self.delay = delay; self.title = title }
    func catalog(forceRefresh: Bool) async throws -> [LibraryCatalogNode] {
        if delay > 0 { try await Task.sleep(nanoseconds: delay) }
        return [.init(id: title, kind: .category, title: title, heTitle: nil, work: nil, children: [])]
    }
}

@MainActor
func runBackendCoordinatorTests() async throws {
    let suite = "SefariaNativeTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let coordinator = BackendCoordinator(defaults: defaults)
    coordinator.register(.init(id: .otzaria, sourceDescription: "O", capabilities: [.catalog],
        catalog: FixtureCatalog(delay: 500_000_000, title: "old"), text: nil, navigation: nil,
        search: nil, authors: nil, metadata: nil, offline: nil, usesNativeMaktabahDataPath: true,
        invalidateTransientState: {}))
    coordinator.register(.init(id: .sefaria, sourceDescription: "S", capabilities: [.catalog],
        catalog: FixtureCatalog(title: "new"), text: nil, navigation: nil,
        search: nil, authors: nil, metadata: nil, offline: nil, usesNativeMaktabahDataPath: false,
        invalidateTransientState: {}))
    try expect(coordinator.activeBackendID == .otzaria, "default Otzaria selection")
    let stale = Task { try await coordinator.catalog() }
    try await Task.sleep(nanoseconds: 20_000_000)
    coordinator.select(.sefaria)
    do {
        _ = try await stale.value
        throw TestFailure.failed("stale source result leaked")
    } catch is CancellationError {}
    try expect(defaults.string(forKey: BackendCoordinator.selectionDefaultsKey) == BackendID.sefaria.rawValue,
        "persistent source selection")
    let result = try await coordinator.catalog()
    try expect(result.first?.title == "new", "selected backend result")
}
