import Foundation

enum OtzariaProfileStorage {
    static func applicationSupportRoot(
        base: URL = ITorahSharedContainer.sharedRootURL,
        component: OtzariaDataComponent,
        profileID: String = OtzariaDataProfileRegistry.activeProfileID
    ) -> URL {
        guard profileID != OtzariaDataProfileRegistry.productionID else {
            switch component {
            case .database: return base.appendingPathComponent("Otzaria", isDirectory: true)
            case .otzariaSearch: return base.appendingPathComponent("Otzaria/TantivySearchIndex", isDirectory: true)
            case .zayitSearch: return base.appendingPathComponent("Otzaria/Zayit", isDirectory: true)
            }
        }
        return base
            .appendingPathComponent("Otzaria/Profiles", isDirectory: true)
            .appendingPathComponent(profileID, isDirectory: true)
            .appendingPathComponent(component.rawValue, isDirectory: true)
    }

    static func downloadsRoot(
        base: URL = ITorahSharedContainer.downloadsRootURL,
        component: OtzariaDataComponent,
        profileID: String = OtzariaDataProfileRegistry.activeProfileID
    ) -> URL {
        guard profileID != OtzariaDataProfileRegistry.productionID else {
            switch component {
            case .database, .otzariaSearch:
                return base.appendingPathComponent("Maktabah/Otzaria/Downloads", isDirectory: true)
            case .zayitSearch:
                return base.appendingPathComponent("Maktabah/Zayit/Downloads", isDirectory: true)
            }
        }
        return base
            .appendingPathComponent("Maktabah/Otzaria/Profiles", isDirectory: true)
            .appendingPathComponent(profileID, isDirectory: true)
            .appendingPathComponent(component.rawValue, isDirectory: true)
            .appendingPathComponent("Downloads", isDirectory: true)
    }
}
