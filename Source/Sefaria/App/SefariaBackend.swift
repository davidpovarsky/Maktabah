import Foundation

@MainActor
final class SefariaBackend {
    static let shared = SefariaBackend()

    let remote: SefariaRemoteStore
    let offline: SefariaOfflineStore
    let packages: SefariaPackageManager
    let hybrid: SefariaHybridStore
    let navigation: SefariaHybridNavigationStore
    let relationships: SefariaHybridRelationshipsStore
    let catalog: SefariaHybridCatalogStore

    private init() {
        let client = SefariaHTTPClient()
        let paths = SefariaOfflinePaths()
        let remote = SefariaRemoteStore(client: client)
        let offline = SefariaOfflineStore(paths: paths)
        let updates = SefariaUpdateManager(configuration: .production, client: client, paths: paths)
        let packages = SefariaPackageManager(client: client, paths: paths, updates: updates)
        let localNavigation = SefariaOfflineNavigationStore(offline: offline)
        let navigation = SefariaHybridNavigationStore(
            isInstalled: { workKey in await offline.contains(workKey: workKey) },
            local: localNavigation,
            remote: remote
        )
        self.remote = remote
        self.offline = offline
        self.packages = packages
        self.navigation = navigation
        self.relationships = SefariaHybridRelationshipsStore(offline: offline, remote: remote)
        self.catalog = SefariaHybridCatalogStore(remote: remote, packages: packages)
        self.hybrid = SefariaHybridStore(offline: offline, remote: remote, navigation: navigation)
    }

    func register() {
        register(with: .shared)
    }

    func register(with coordinator: BackendCoordinator) {
        coordinator.register(LibraryBackendRegistration(
            id: .sefaria,
            sourceDescription: String(localized: "Read from Sefaria downloads first, with cloud fallback when needed."),
            capabilities: [.catalog, .reading, .navigation, .search, .links, .versions, .offlineLibrary, .workMetadata],
            catalog: catalog,
            text: hybrid,
            navigation: navigation,
            search: remote,
            authors: nil,
            metadata: remote,
            workMetadata: navigation,
            relationships: relationships,
            offline: packages,
            offlineWorks: packages,
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
