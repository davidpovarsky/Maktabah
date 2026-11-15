#if os(iOS)
import Foundation
import SwiftUI
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

/// Read-only projection of the existing native controls and reader. This file
/// belongs to the app target (manager-owned membership), not the portable SPM
/// target. It neither saves reader state nor resolves a requested locator.
@MainActor
struct MaktabahNativeSceneProjection {
    enum Surface { case library, tableOfContents, reader, history, settings }
    let manager: iOSNavigationManager
    let selectedTab: iOSTab
    let columnVisibility: NavigationSplitViewVisibility
    let settingsPresented: Bool
    let sidebar: ReaderSidebarPageCoordinator?
    let workspace: StudyWorkspaceNavigationAdapter?

    private var activeTab: iOSNavigationManager.ReaderTab? {
        guard let id = manager.activeTabId else { return nil }
        // Never substitute a first tab for a missing/stale active ID.
        return manager.openTabs.first { $0.id == id }
    }
    private func stable(_ id: UUID?) -> UIStableID? { id.flatMap { UIStableID(rawValue: $0.uuidString) } }
    private func id(_ value: String) -> UIDestinationID { UIDestinationID(rawValue: value)! }

    func identity() throws -> NativeSceneIdentity {
        let reader = activeTab?.viewModel
        let section = try reader?.currentLocator.map(ActionAppIdentityBridge.actionRef)
        var selection: UIUTF16Range?
        if let range = reader?.readerState.selectedRange, range.location != NSNotFound {
            guard let location = UInt64(exactly: range.location), let length = UInt64(exactly: range.length) else {
                throw UIRouteError(.unavailable, "native_selection_unavailable")
            }
            selection = .init(location: location, length: length)
        }
        let sidebarVisible: Bool? = columnVisibility == .all || columnVisibility == .doubleColumn ? true : columnVisibility == .detailOnly ? false : nil
        let state = UIStateSpec(workspaceID: stable(workspace?.selection?.groupID), profileID: stable(workspace?.selection?.profileID),
                               selectedItemID: sidebar?.page == .contents ? stable(activeTab?.id) : nil,
                               sidebarVisible: sidebarVisible, inspectorVisible: reader?.readerInspectorVisible,
                               sheet: settingsPresented ? id("native.settings") : nil)
        return .init(topLevel: selectedTab.canonical.rawValue, activeTabID: stable(manager.activeTabId), section: section,
                     selectedRange: selection, state: state, libraryQuery: manager.libraryViewModel.searchQuery, globalQuery: manager.searchText)
    }

    /// Only return states which can actually be observed from this host. Unknown
    /// compact-column visibility, unread content or source mismatch stays nil.
    func surface(_ surface: Surface) throws -> NativeSurfaceState? {
        let state = UIStateSpec(workspaceID: stable(workspace?.selection?.groupID),
            profileID: stable(workspace?.selection?.profileID), selectedItemID: nil)
        switch surface {
        case .settings:
            guard settingsPresented else { return nil }
            return .init(destination: id("native.settings"), presentation: .init(kind: .sheet), content: nil, state: state, focus: nil)
        case .history:
            guard !settingsPresented, selectedTab.canonical == .history, manager.currentMode == .history,
                  HistoryViewModel.shared.searchText.isEmpty else { return nil }
            return .init(destination: id("native.history"), presentation: .init(), content: nil, state: state, focus: nil)
        case .library, .tableOfContents:
            guard !settingsPresented, selectedTab.canonical == .viewer, manager.currentMode == .viewer,
                  let sidebar else { return nil }
            let requestedPage: ReaderSidebarPageCoordinator.Page = surface == .library ? .library : .contents
            guard sidebar.page == requestedPage, columnVisibility == .all || columnVisibility == .doubleColumn else { return nil }
            let destination = surface == .library ? "native.library" : "native.reader.toc"
            let visible = UIStateSpec(workspaceID: state.workspaceID, profileID: state.profileID,
                                      sidebarVisible: true, inspectorVisible: activeTab?.viewModel.readerInspectorVisible)
            return .init(destination: id(destination), presentation: .init(kind: .sidebar, tabID: stable(activeTab?.id)),
                         content: nil, state: visible, focus: nil)
        case .reader:
            guard !settingsPresented, selectedTab.canonical == .viewer, manager.currentMode == .viewer,
                  let tab = activeTab, let destination = tab.viewModel.currentDestination,
                  destination.focusLocator == nil,
                  let actual = tab.viewModel.backendSection?.locator,
                  actual == destination.sectionLocator,
                  actual.backend == BackendCoordinator.shared.activeBackendID,
                  tab.book.backendLocator?.workKey == actual.workKey,
                  !tab.viewModel.contentText.isEmpty else { return nil }
            let content = ActionReaderDestination(sectionLocator: try ActionAppIdentityBridge.actionRef(actual),
                focusLocator: try destination.focusLocator.map(ActionAppIdentityBridge.actionRef), presentationMode: .sameTab)
            let actualState = UIStateSpec(workspaceID: state.workspaceID, profileID: state.profileID,
                                          inspectorVisible: tab.viewModel.readerInspectorVisible)
            // Selection/highlight/scroll require the original TextKit witness.
            // Model destination alone must not certify those variants.
            return .init(destination: id("native.reader"), presentation: .init(kind: .currentTab, tabID: stable(tab.id)),
                         content: content, state: actualState, focus: nil)
        }
    }
}
#endif
