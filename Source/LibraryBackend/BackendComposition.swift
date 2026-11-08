import Foundation

@MainActor
enum BackendComposition {
    private static var didRegister = false

    static func registerAll() {
        guard !didRegister else { return }
        didRegister = true
        let otzaria = OtzariaGenericBackendAdapter()
        let otzariaRelationships = OtzariaInspectorRelationshipsProvider()
        BackendCoordinator.shared.register(.init(
            id: .otzaria,
            sourceDescription: "Use the existing local Otzaria library.",
            capabilities: [.catalog, .reading, .navigation, .search, .authors, .links, .workMetadata],
            runtimeCapabilities: {
                [.catalog, .reading, .navigation, .search, .authors, .links, .workMetadata]
                    .union(OtzariaMaktabahBridge.shared.metadataCapabilities)
            },
            catalog: otzaria,
            text: otzaria,
            navigation: otzaria,
            search: otzaria,
            authors: otzaria,
            metadata: OtzariaVersionsRepository(),
            workMetadata: otzaria,
            relationships: otzariaRelationships,
            offline: nil,
            offlineWorks: nil,
            usesNativeMaktabahDataPath: true,
            invalidateTransientState: {}
        ))
        SefariaBackend.shared.register()
        SefariaMobileEmbeddedBackend.shared.register()
    }
}
