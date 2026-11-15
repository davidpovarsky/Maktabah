#if os(iOS)
import SwiftUI
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

/// Thin access to existing scene bindings. No new navigation UI or renderer.
@MainActor
struct MaktabahNativeSceneBindings {
    let manager: iOSNavigationManager
    let selectedTab: Binding<iOSTab>
    let columnVisibility: Binding<NavigationSplitViewVisibility>
    let showSettings: Binding<Bool>

    func apply(_ command: UISceneCommand) throws {
        switch command.route.route.destination.rawValue {
        case "native.settings": showSettings.wrappedValue = true
        case "native.history":
            showSettings.wrappedValue = false
            selectedTab.wrappedValue = .history
            manager.switchToMode(.history)
        default: throw UIRouteError(.notSupported, "native_surface_not_installed")
        }
    }
}
