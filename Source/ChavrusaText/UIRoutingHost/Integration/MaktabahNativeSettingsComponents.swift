import SwiftUI
#if os(iOS)
import OtzariaUIRouting
#endif

/// Fixed original controls. Revealing these never activates their action or
/// changes the setting value. Conditional controls keep their original rules.
enum MaktabahSettingsComponent: String, CaseIterable {
    case backend, offline, databaseMode, history, storage, annotations, cloud
    case appearance, searchData, searchCredits, searchIndex, optimization, updates, downloads, miniApps
    var anchorString: String { "native.settings." + rawValue }
}

#if os(iOS)
@MainActor enum MaktabahNativeSettingsComponents {
    static let destination = UIDestinationID(rawValue: "native.settings")!
    static let descriptors = MaktabahSettingsComponent.allCases.map { component in
        MaktabahNativeComponentDescriptor(anchor: UIDestinationID(rawValue: component.anchorString)!,
                                          title: title(component))
    }
    static func title(_ component: MaktabahSettingsComponent) -> String {
        switch component {
        case .backend: "Library Source".localized
        case .offline: "Manage Offline Library".localized
        case .databaseMode: String(localized: .Setting.databaseMode)
        case .history: String(localized: .Setting.history)
        case .storage: String(localized: .Setting.libraryStorage)
        case .annotations: String(localized: .Setting.annotationsAndSearchResults)
        case .cloud: String(localized: .Setting.useCloudKit)
        case .appearance: String(localized: .Setting.appearance)
        case .searchData: "Search Data".localized
        case .searchCredits: "Zayit Search Credits".localized
        case .searchIndex: String(localized: .Setting.searchIndex)
        case .optimization: String(localized: .Setting.optimization)
        case .updates: String(localized: .Setting.updates)
        case .downloads: String(localized: .Setting.downloads)
        case .miniApps: "Mini Apps".localized
        }
    }
    static func makeOwner() -> MaktabahNativeComponentOwner {
        .init(destination: destination, presentation: .sheet, descriptors: descriptors, available: { anchor in
            guard let component = MaktabahSettingsComponent.allCases.first(where: { $0.anchorString == anchor.rawValue }) else { return false }
            let backend = BackendCoordinator.shared, model = SettingsViewModel.shared
            guard !backend.isTransitioning, !model.showCollisionAlert else { return false }
            switch component {
            case .offline:
                return backend.activeCapabilities.contains(.offlineLibrary) && backend.offlineProvider() != nil
            case .databaseMode, .storage, .downloads:
                return backend.usesNativeMaktabahDataPath
            case .searchIndex:
                return backend.usesNativeMaktabahDataPath && FtsMigrationManager.shared.needsMigration
            case .optimization:
                return backend.usesNativeMaktabahDataPath && AppConfig.isUsingBundleMode
                    && (model.hasPendingVacuum || model.isVacuuming)
            case .updates:
                return backend.usesNativeMaktabahDataPath && AppConfig.isUsingBundleMode
            default: return true
            }
        }, captureSource: { anchor in
            guard let component = MaktabahSettingsComponent.allCases.first(where: { $0.anchorString == anchor.rawValue }) else {
                throw UIRouteError(.unavailable, "native_settings_component_unavailable")
            }
            let model = SettingsViewModel.shared, migration = FtsMigrationManager.shared
            let bundleMode = AppConfig.isUsingBundleMode
            let observation = MaktabahNativeComponentSourceObservation {
                _ = model.showCollisionAlert
                _ = model.isBundleMode
                switch component {
                case .appearance: _ = model.useDefaultTheme
                case .history: _ = model.recordSearchHistory
                case .annotations: _ = model.hideMissingBookAnnotations
                case .cloud:
                    _ = model.useICloud; _ = model.isProcessingICloud
                case .storage:
                    _ = model.databaseFilesPath; _ = model.archiveFilesPath
                case .optimization:
                    _ = model.hasPendingVacuum; _ = model.isVacuuming
                case .updates: _ = model.enableAutoCoreVersionCheck
                case .searchIndex:
                    _ = migration.needsMigration; _ = migration.isMigrating
                    _ = migration.isCancelled; _ = migration.isOptimizationOnly
                    _ = migration.totalArchivesToMigrate
                default: break
                }
            }
            return { [weak model, weak migration] in
                try observation.validate()
                guard let model, let migration,
                      SettingsViewModel.shared === model, FtsMigrationManager.shared === migration,
                      !model.showCollisionAlert, AppConfig.isUsingBundleMode == bundleMode else {
                    throw UIRouteError(.staleState, "native_settings_component_source_changed")
                }
            }
        })
    }

    /// Called synchronously by the original overlay setters. SwiftUI @State is
    /// not claimed as an Observation source and an onChange callback can coalesce
    /// a complete open/close cycle while a retained request is suspended.
    static func originalOverlayWillChange(_ session: MaktabahNativeSceneSession?) {
        session?.componentOwner(for: destination)?.retirePresentation()
    }
}

private struct MaktabahNativeSettingsComponentMarker: ViewModifier {
    let component: MaktabahSettingsComponent
    @Environment(\.maktabahNativeRoutingSession) private var session
    func body(content: Content) -> some View {
        content.id(component.anchorString).background {
            if let owner = session?.componentOwner(for: MaktabahNativeSettingsComponents.destination),
               let anchor = UIDestinationID(rawValue: component.anchorString) {
                MaktabahNativeComponentWitness(anchor: anchor, owner: owner)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
        }
    }
}
#endif

extension View {
    @ViewBuilder func maktabahSettingsComponent(_ component: MaktabahSettingsComponent) -> some View {
        #if os(iOS)
        modifier(MaktabahNativeSettingsComponentMarker(component: component))
        #else
        self
        #endif
    }
}
