import SwiftUI

/// Adds no phone reader chrome. The existing book-title action opens the same
/// source overview, with a scene-lived adapter so overview transitions cannot lose
/// the reader's later checkpoints.
struct CompactStudyWorkspaceHostModifier: ViewModifier {
    let manager: iOSNavigationManager
    @State private var workspaceOwner = MaktabahNativeWorkspaceOwner()
    private var workspace: StudyWorkspaceNavigationAdapter? { workspaceOwner.current }
    private var routingSession: MaktabahNativeSceneSession? { workspaceOwner.nativeRoutingSession }
    @State private var sceneID = ""
    @State private var showsOverview = false
    @State private var presentationViewID = UUID()
    @Environment(\.scenePhase) private var scenePhase

    private var overviewBinding: Binding<Bool> {
        maktabahWorkspaceOriginalBinding($showsOverview, binding: routingSession?.workspacePresentation,
            host: .compactRoot, stateOwnerID: presentationViewID, change: .overview)
    }

    private static var isEnabled: Bool {
        !MaktabahApp.isIpad && ChavrusaTextReaderUI.isEnabled
    }

    /// Each enabled layout owns its existing study overview presentation.
    /// The legacy sheet remains the original flags-off path. The iPad and
    /// phone hosts retain their own lifetime when closing the last tab.
    static func legacyTabsPresentation(_ original: Binding<Bool>) -> Binding<Bool> {
        Binding(get: { !ChavrusaTextReaderUI.isEnabled && original.wrappedValue }, set: {
            if !ChavrusaTextReaderUI.isEnabled { original.wrappedValue = $0 }
        })
    }

    func body(content: Content) -> some View {
        content
            .modifier(Exact9401WorkspaceLifecycle(manager: manager,
                compactWorkspaceOwner: Self.isEnabled ? workspaceOwner : nil))
            .background {
                if Self.isEnabled {
                    ReaderSceneIdentityReader { sceneID = $0 }
                        .frame(width: 0, height: 0).accessibilityHidden(true)
                    if let workspace {
                        Color.clear.modifier(MaktabahNativeWorkspaceOriginalHost(
                            binding: routingSession?.workspacePresentation, kind: .compactRoot,
                            stateOwnerID: presentationViewID, workspace: workspace, manager: manager,
                            overviewPresented: { showsOverview },
                            presentOverview: {
                                overviewBinding.wrappedValue = true
                                manager.showingTabsList = true
                            }, blocked: { workspace.isSwitching || workspace.errorMessage != nil }))
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
                do { try workspaceOwner.replace(with: adapter) } catch { return }
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
                if Self.isEnabled && showing { overviewBinding.wrappedValue = true }
            }
            .overlay {
                if Self.isEnabled {
                    ReaderOverviewPresentation(isPresented: overviewBinding, onDismiss: {
                        manager.showingTabsList = false
                        workspace?.synchronize(manager)
                    }) {
                        if let workspace {
                            StudyGroupsOverview(workspace: workspace, manager: manager, onOpenLibrary: {
                                manager.switchToMode(.viewer)
                                // Keep the original phone NavigationStack's Back action.
                                manager.selectedBook = nil
                            }, onClose: { overviewBinding.wrappedValue = false })
                                .environment(\.maktabahNativeRoutingSession, routingSession)
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
