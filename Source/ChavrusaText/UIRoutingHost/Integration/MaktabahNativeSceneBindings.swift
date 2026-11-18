#if os(iOS)
import SwiftUI
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

/// Finite existing top-level tabs. Availability delegates to the original UI
/// capability rules; this contains no resolver, search engine or write action.
@MainActor enum MaktabahNativeRootDestination: String, CaseIterable {
    case history = "native.history"
    case search = "native.search"
    case annotations = "native.annotations"

    var tab: iOSTab {
        switch self { case .history: .history; case .search: .search; case .annotations: .annotations }
    }
    var isAvailable: Bool {
        tab.isAvailable(for: BackendCoordinator.shared.activeCapabilities)
            && (self != .history || HistoryViewModel.shared.searchText.isEmpty)
    }
}

/// Thin access to existing scene bindings. No new navigation UI or renderer.
@MainActor
struct MaktabahNativeSceneBindings {
    let manager: iOSNavigationManager
    let selectedTab: Binding<iOSTab>
    let columnVisibility: Binding<NavigationSplitViewVisibility>
    let showSettings: Binding<Bool>

    var isPresentationReady: Bool {
        !DonationManager.shared.showDonationSheet && manager.selectedBookForInfo == nil
            && !manager.showingTabsList && manager.activeReaderViewModel?.isPopoverPresented != true
    }

    func apply(_ command: UISceneCommand) throws {
        switch command.route.route.destination.rawValue {
        case "native.settings": showSettings.wrappedValue = true
        case "native.history", "native.search", "native.annotations":
            guard let root = MaktabahNativeRootDestination(rawValue: command.route.route.destination.rawValue),
                  root.isAvailable else { throw UIRouteError(.notSupported, "native_root_unavailable") }
            showSettings.wrappedValue = false
            // The original phone stacks share this optional navigation item.
            // Pop the presented reader without closing its tab or replacing
            // its model; original onDisappear persists the reading position.
            if !MaktabahApp.isIpad { manager.selectedBook = nil }
            selectedTab.wrappedValue = root.tab
            manager.switchToMode(root.tab.appMode)
        case "native.reader":
            // Selection/tab ownership is retained by the caller and rechecked
            // synchronously inside the canonical orchestrator's commit fence.
            guard let content = command.route.route.content,
                  let tabID = command.route.route.presentation.tabID,
                  let id = manager.activeTabId, id.uuidString == tabID.rawValue,
                  let tab = manager.openTabs.first(where: { $0.id == id }),
                  selectedTab.wrappedValue.canonical == .viewer,
                  manager.currentMode == .viewer, !showSettings.wrappedValue,
                  tab.book.backendLocator?.backend.rawValue == content.sectionLocator.backend.rawValue,
                  tab.book.backendLocator?.workKey == content.sectionLocator.workKey else {
                throw UIRouteError(.staleState, "current_reader_target_changed")
            }
            let destination = try MaktabahNativeReaderBinding.appDestination(content)
            if tab.viewModel.currentDestination != destination { tab.viewModel.loadBackendContent(destination) }
        default: throw UIRouteError(.notSupported, "native_surface_not_installed")
        }
    }
}

/// One original same-tab Reader owner retained for the whole Core result.
/// R's typed mapping publisher separately fences tab/workspace/owner ABA.
/// This fence covers passage changes which do not change the selected tab.
@MainActor final class MaktabahNativeReaderBinding {
    private let manager: iOSNavigationManager
    private let reader: ReaderViewModel
    private let tabID: UUID
    private let destination: LibraryReaderDestination
    private let revoke: @MainActor () -> Void
    private(set) var valid = true
    private var applying = false
    private var installed = false

    init(manager: iOSNavigationManager, tabID: UIStableID, content: ActionReaderDestination,
         revoke: @escaping @MainActor () -> Void) throws {
        guard let id = manager.activeTabId, id.uuidString == tabID.rawValue,
              let tab = manager.openTabs.first(where: { $0.id == id }),
              tab.viewModel.nativeReaderDestinationWillChange == nil,
              tab.book.backendLocator?.backend.rawValue == content.sectionLocator.backend.rawValue,
              tab.book.backendLocator?.workKey == content.sectionLocator.workKey else {
            throw UIRouteError(.unavailable, "current_reader_target_unavailable")
        }
        self.manager = manager; reader = tab.viewModel; self.tabID = id
        destination = try Self.appDestination(content); self.revoke = revoke
        reader.nativeReaderDestinationWillChange = { [weak self] next in
            guard let self, valid else { return }
            // Only this synchronous, already authorized native apply may
            // publish its exact canonical target. Every other change revokes.
            if applying && next == destination { return }
            valid = false; revoke()
        }
        installed = true
    }
    static func appDestination(_ content: ActionReaderDestination) throws -> LibraryReaderDestination {
        guard content.presentationMode == .sameTab else { throw ActionPortError.notSupported }
        let section = try ActionAppIdentityBridge.appLocator(content.sectionLocator)
        let focus = try content.focusLocator.map(ActionAppIdentityBridge.appLocator)
        let original = ReaderDestinationResolver.resolve(locator: section)
        // Never silently re-normalize the command granted by Core. Clients
        // supply the original bounded section and explicit segment, if any.
        guard original.sectionLocator == section,
              (focus ?? original.focusLocator) == focus else { throw ActionPortError.notSupported }
        return .init(sectionLocator: section, focusLocator: focus)
    }
    func validate() throws {
        guard valid, installed, manager.activeTabId == tabID,
              let tab = manager.openTabs.first(where: { $0.id == tabID }),
              tab.viewModel === reader,
              tab.book.backendLocator?.backend == destination.sectionLocator.backend,
              tab.book.backendLocator?.workKey == destination.sectionLocator.workKey else {
            throw UIRouteError(.staleState, "current_reader_owner_changed")
        }
    }
    func apply(_ operation: () throws -> Void) throws {
        try validate()
        guard !applying else { throw UIRouteError(.failed, "reader_apply_reentered") }
        applying = true
        defer { applying = false }
        try operation()
        try validate()
        guard reader.currentDestination == destination else { throw ActionPortError.invalidResponse }
    }
    func release() {
        guard installed else { return }
        installed = false
        reader.nativeReaderDestinationWillChange = nil
    }
    isolated deinit { if installed { reader.nativeReaderDestinationWillChange = nil } }
}
#endif
