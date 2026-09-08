import Foundation

@MainActor
enum BackendComposition {
    private static var didRegister = false

    static func registerAll() {
        guard !didRegister else { return }
        didRegister = true
        let otzaria = OtzariaGenericBackendAdapter()
        BackendCoordinator.shared.register(.init(
            id: .otzaria,
            sourceDescription: "Use the existing local Otzaria library.",
            capabilities: [.catalog, .reading, .navigation, .search, .authors],
            catalog: otzaria,
            text: otzaria,
            navigation: otzaria,
            search: otzaria,
            authors: otzaria,
            metadata: nil,
            offline: nil,
            usesNativeMaktabahDataPath: true,
            invalidateTransientState: {}
        ))
        SefariaBackend.shared.register()
    }
}
