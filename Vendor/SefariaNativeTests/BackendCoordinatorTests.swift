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
    try expect(coordinator.committedBackendID == nil, "default backend is not committed")
    try expect(coordinator.resolveStartup(hasValidOtzariaInstallation: false) == .chooseSource,
        "fresh install chooses source")
    coordinator.beginConfiguration(of: .otzaria)
    try expect(coordinator.pendingBackendID == .otzaria, "Otzaria selection remains pending")
    try expect(defaults.object(forKey: BackendCoordinator.selectionDefaultsKey) == nil,
        "pending Otzaria does not persist")
    let unfinishedRelaunch = BackendCoordinator(defaults: defaults)
    try expect(unfinishedRelaunch.resolveStartup(hasValidOtzariaInstallation: false) == .chooseSource,
        "unfinished Otzaria configuration returns to chooser on relaunch")
    coordinator.cancelConfiguration()
    try expect(coordinator.pendingBackendID == nil, "pending selection cancels")
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

    let relaunch = BackendCoordinator(defaults: defaults)
    try expect(relaunch.committedBackendID == .sefaria, "committed Sefaria survives relaunch")
    try expect(relaunch.resolveStartup(hasValidOtzariaInstallation: false) == .ready(.sefaria),
        "persisted Sefaria bypasses Otzaria bootstrap")
    relaunch.beginConfiguration(of: .otzaria)
    try expect(relaunch.activeBackendID == .sefaria,
        "pending Otzaria switch does not replace the committed backend")
    relaunch.cancelConfiguration()
    try expect(relaunch.committedBackendID == .sefaria,
        "cancelling an Otzaria switch preserves committed Sefaria")

    relaunch.beginConfiguration(of: .otzaria)
    relaunch.commit(.otzaria)
    try expect(relaunch.pendingBackendID == nil, "successful Otzaria setup clears pending state")
    try expect(relaunch.committedBackendID == .otzaria,
        "successful Otzaria setup commits the backend")
    let installedRelaunch = BackendCoordinator(defaults: defaults)
    try expect(installedRelaunch.resolveStartup(hasValidOtzariaInstallation: true) == .ready(.otzaria),
        "committed Otzaria with a valid installation is ready on relaunch")
    try expect(installedRelaunch.resolveStartup(hasValidOtzariaInstallation: false) == .configureOtzaria,
        "committed Otzaria without an installation resumes configuration")

    defaults.removeObject(forKey: BackendCoordinator.selectionDefaultsKey)
    let legacy = BackendCoordinator(defaults: defaults)
    try expect(legacy.resolveStartup(hasValidOtzariaInstallation: true) == .ready(.otzaria),
        "legacy valid Otzaria installation is preserved")
    try expect(legacy.committedBackendID == .otzaria, "legacy Otzaria migration commits selection")
}
