import Foundation

@MainActor
final class SefariaBackend {
    static let shared = SefariaBackend()

    let remote: SefariaRemoteStore
    let offline: SefariaOfflineStore
    let packages: SefariaPackageManager
    let hybrid: SefariaHybridStore

    private init() {
        let client = SefariaHTTPClient()
        let paths = SefariaOfflinePaths()
        let remote = SefariaRemoteStore(client: client)
        let offline = SefariaOfflineStore(paths: paths)
        let updates = SefariaUpdateManager(configuration: .production, client: client, paths: paths)
        self.remote = remote
        self.offline = offline
        self.packages = SefariaPackageManager(client: client, paths: paths, updates: updates)
        self.hybrid = SefariaHybridStore(offline: offline, remote: remote)
    }

    func register() {
        register(with: .shared)
    }

    func register(with coordinator: BackendCoordinator) {
        coordinator.register(LibraryBackendRegistration(
            id: .sefaria,
            sourceDescription: "Read from Sefaria downloads first, with cloud fallback when needed.",
            capabilities: [.catalog, .reading, .navigation, .search, .links, .versions, .offlineLibrary],
            catalog: remote,
            text: hybrid,
            navigation: remote,
            search: remote,
            authors: nil,
            metadata: remote,
            relationships: remote,
            offline: packages,
            usesNativeMaktabahDataPath: false,
            invalidateTransientState: { [remote = self.remote, offline = self.offline,
                hybrid = self.hybrid, packages = self.packages] in
                await packages.cancelInstall()
                await remote.clearTransientState()
                await offline.clearTransientState()
                await hybrid.clearTransientState()
            }
        ))
    }
}
