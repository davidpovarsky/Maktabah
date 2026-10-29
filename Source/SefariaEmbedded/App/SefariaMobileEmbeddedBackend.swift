//
//  SefariaMobileEmbeddedBackend.swift
//  Maktabah
//
//  Downstream-owned registration coordinator for the embedded original Sefaria-Mobile engine.
//

import Foundation

@MainActor
final class SefariaMobileEmbeddedBackend {
    static let shared = SefariaMobileEmbeddedBackend()

    let catalog: SefariaEmbeddedCatalogAdapter
    let text: SefariaEmbeddedTextAdapter
    let navigation: SefariaEmbeddedNavigationAdapter
    let search: SefariaEmbeddedSearchAdapter
    let relationships: SefariaEmbeddedRelationshipsAdapter
    let downloads: SefariaEmbeddedDownloadAdapter

    private init() {
        self.catalog = .shared
        self.text = .shared
        self.navigation = .shared
        self.search = .shared
        self.relationships = .shared
        self.downloads = .shared
    }

    func register(with coordinator: BackendCoordinator = .shared) {
        coordinator.register(LibraryBackendRegistration(
            id: .sefariaEmbedded,
            sourceDescription: String(localized: "Read from embedded Sefaria-Mobile engine with full original React Native runtime."),
            capabilities: [.catalog, .reading, .navigation, .search, .links, .versions, .offlineLibrary, .workMetadata],
            catalog: catalog,
            text: text,
            navigation: navigation,
            search: search,
            authors: nil,
            metadata: text,
            workMetadata: catalog,
            relationships: relationships,
            offline: downloads,
            offlineWorks: downloads,
            usesNativeMaktabahDataPath: false,
            invalidateTransientState: {
                await SefariaJSRPCBridge.shared.cancelAllInFlight()
            }
        ))
    }
}
