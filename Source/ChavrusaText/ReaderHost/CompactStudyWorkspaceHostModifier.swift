import SwiftUI

/// The original phone title action is supplied only in compact width. A phone
/// with a regular-width window still needs that same action to open its tabs.
struct PhoneRegularReaderOverviewAction: ViewModifier {
    let bookTitle: String
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(iOSNavigationManager.self) private var manager

    func body(content: Content) -> some View {
        content.toolbar {
            if !MaktabahApp.isIpad, ChavrusaTextReaderUI.isEnabled, horizontalSizeClass == .regular {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { manager.showingTabsList.toggle() } label: {
                        Text(bookTitle)
                            .lineLimit(1)
                            .frame(maxWidth: 190)
                            .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("reader-book-tabs-overview")
                }
            }
        }
    }
}

/// Adds no phone reader chrome. The existing book-title action opens the same
/// source overview, with a scene-lived adapter so dismissed sheets cannot lose
/// the reader's later checkpoints.
struct CompactStudyWorkspaceHostModifier: ViewModifier {
    let manager: iOSNavigationManager
    @State private var workspace: StudyWorkspaceNavigationAdapter?
    @State private var sceneID = ""
    @State private var showsOverview = false
    @Environment(\.scenePhase) private var scenePhase

    private static var isEnabled: Bool {
        !MaktabahApp.isIpad && ChavrusaTextReaderUI.isEnabled
    }

    /// Preserve the original presentation for iPad/flags off. The enabled
    /// compact overview keeps its own presentation lifetime when the native
    /// manager closes the last tab while creating an empty group.
    static func legacyTabsPresentation(_ original: Binding<Bool>) -> Binding<Bool> {
        Binding(get: { !isEnabled && original.wrappedValue }, set: {
            if !isEnabled { original.wrappedValue = $0 }
        })
    }

    func body(content: Content) -> some View {
        content
            .background {
                if Self.isEnabled {
                    ReaderSceneIdentityReader { sceneID = $0 }
                        .frame(width: 0, height: 0).accessibilityHidden(true)
                    if let workspace {
                        StudyWorkspaceCheckpointObserver(manager: manager, workspace: workspace)
                    }
                }
            }
            .task(id: sceneID) {
                guard Self.isEnabled, workspace == nil, !sceneID.isEmpty else { return }
                manager.restoreSessionIfNeeded()
                let adapter = StudyWorkspaceNavigationAdapter(sceneID: sceneID, store: .forCurrentProcess())
                workspace = adapter
                await adapter.attach(manager)
            }
            .onChange(of: manager.openTabs.map(\.id)) { _, _ in workspace?.synchronize(manager) }
            .onChange(of: manager.activeTabId) { _, _ in workspace?.synchronize(manager) }
            .onChange(of: workspace?.selection?.groupID) { _, _ in
                Task { await workspace?.reconcileSceneSelection(manager) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .activeLibraryBackendDidChange)) { _ in
                workspace?.synchronize(manager)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { workspace?.synchronize(manager) }
            }
            .onChange(of: manager.showingTabsList, initial: true) { _, showing in
                if Self.isEnabled && showing { showsOverview = true }
            }
            .sheet(isPresented: $showsOverview, onDismiss: {
                manager.showingTabsList = false
                workspace?.synchronize(manager)
            }) {
                if let workspace {
                    StudyGroupsOverview(workspace: workspace, manager: manager) {
                        manager.switchToMode(.viewer)
                        // This is the same canonical binding used by the
                        // original phone NavigationStack's Back action.
                        manager.selectedBook = nil
                    }
                } else {
                    ProgressView().accessibilityLabel("טעינת סביבת הלימוד")
                }
            }
    }
}
