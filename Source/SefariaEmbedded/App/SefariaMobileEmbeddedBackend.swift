//
//  SefariaMobileEmbeddedBackend.swift
//  Maktabah
//
//  Downstream-owned registration coordinator for the embedded original Sefaria-Mobile engine.
//

import Foundation

@MainActor
public final class SefariaMobileEmbeddedBackend {
    public static let shared = SefariaMobileEmbeddedBackend()

    public let catalog: SefariaEmbeddedCatalogAdapter
    public let text: SefariaEmbeddedTextAdapter
    public let navigation: SefariaEmbeddedNavigationAdapter
    public let search: SefariaEmbeddedSearchAdapter
    public let relationships: SefariaEmbeddedRelationshipsAdapter
    public let downloads: SefariaEmbeddedDownloadAdapter

    private init() {
        let bridge = SefariaJSRPCBridge.shared
        self.catalog = SefariaEmbeddedCatalogAdapter(bridge: bridge)
        self.text = SefariaEmbeddedTextAdapter(bridge: bridge)
        self.navigation = SefariaEmbeddedNavigationAdapter(bridge: bridge)
        self.search = SefariaEmbeddedSearchAdapter(bridge: bridge)
        self.relationships = SefariaEmbeddedRelationshipsAdapter(bridge: bridge)
        self.downloads = SefariaEmbeddedDownloadAdapter(bridge: bridge)
    }

    public func register(with coordinator: BackendCoordinator = .shared) {
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
