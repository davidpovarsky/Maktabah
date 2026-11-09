import SwiftUI

/// Adds no phone reader chrome. The existing book-title action opens the same
/// source overview, with a scene-lived adapter so overview transitions cannot lose
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
            .modifier(Exact9401WorkspaceLifecycle(manager: manager))
            .background {
                if Self.isEnabled {
                    ReaderSceneIdentityReader { sceneID = $0 }
                        .frame(width: 0, height: 0).accessibilityHidden(true)
                    if let workspace {
                        StudyWorkspaceCheckpointObserver(manager: manager, workspace: workspace)
                    }
                    #if DEBUG
                    ReaderViewportAcceptanceObserver().frame(width: 0, height: 0).accessibilityHidden(true)
                    #endif
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
            .overlay {
                if Self.isEnabled {
                    ReaderOverviewPresentation(isPresented: $showsOverview, onDismiss: {
                        manager.showingTabsList = false
                        workspace?.synchronize(manager)
                    }) {
                        if let workspace {
                            StudyGroupsOverview(workspace: workspace, manager: manager, onOpenLibrary: {
                                manager.switchToMode(.viewer)
                                // Keep the original phone NavigationStack's Back action.
                                manager.selectedBook = nil
                            }, onClose: { showsOverview = false })
                        } else {
                            ProgressView().accessibilityLabel("טעינת סביבת הלימוד")
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                }
            }
    }
}
