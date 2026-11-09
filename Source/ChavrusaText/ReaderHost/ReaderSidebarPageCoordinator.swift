import SwiftUI

enum ChavrusaTextReaderUI {
    static var isEnabled: Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "ChavrusaTextFaithfulReaderUIEnabled") != nil else { return true }
        return defaults.bool(forKey: "ChavrusaTextFaithfulReaderUIEnabled")
    }
}

@MainActor @Observable
final class ReaderSidebarPageCoordinator {
    enum Page: Int, CaseIterable, Identifiable { case library, contents; var id: Int { rawValue } }
    var page: Page = .library
    var requestsLibrary = false
    func showContents() { page = .contents }
    func showLibrary() { page = .library; requestsLibrary.toggle() }
}

private struct ReaderSidebarCoordinatorKey: EnvironmentKey {
    static let defaultValue: ReaderSidebarPageCoordinator? = nil
}

private struct Exact9401WorkspaceKey: EnvironmentKey {
    static let defaultValue: StudyWorkspaceNavigationAdapter? = nil
}

extension EnvironmentValues {
    var exact9401Workspace: StudyWorkspaceNavigationAdapter? {
        get { self[Exact9401WorkspaceKey.self] }
        set { self[Exact9401WorkspaceKey.self] = newValue }
    }
    var chavrusaReaderSidebar: ReaderSidebarPageCoordinator? {
        get { self[ReaderSidebarCoordinatorKey.self] }
        set { self[ReaderSidebarCoordinatorKey.self] = newValue }
    }
}

/// Viewer-only native search and study profile actions. Existing components
/// continue to own palette commands and profile/group management behavior.
struct Exact9401ViewerToolbar: ViewModifier {
    let manager: iOSNavigationManager
    @State private var isPresented = false
    @State private var showsProfiles = false
    @Environment(\.exact9401Workspace) private var workspace

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresented = true
                    } label: {
                        Label("חיפוש מהיר בספרייה", systemImage: "magnifyingglass")
                    }
                    .accessibilityIdentifier("reader-command-palette-launcher")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let workspace {
                        StudyProfileMenu(workspace: workspace, manager: manager, usesNativeToolbar: true) {
                            isPresented = false
                            showsProfiles = true
                        }
                    }
                }
            }
            .overlay(alignment: .top) {
                if isPresented {
                    GeometryReader { geometry in
                        Color.black.opacity(0.13)
                            .ignoresSafeArea()
                            .onTapGesture { isPresented = false }
                        LibraryCommandPaletteAdapter(manager: manager) { isPresented = false }
                            .gelatinMotionOnly()
                            .frame(maxWidth: min(CGFloat(690), max(0, geometry.size.width - 30)))
                            .padding(.top, 6)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .sheet(isPresented: $showsProfiles) {
                if let workspace {
                    StudyProfileManagementView(workspace: workspace, manager: manager)
                }
            }
            .onChange(of: workspace?.selection?.profileID) { _, _ in isPresented = false }
            .onDisappear { isPresented = false; showsProfiles = false }
    }
}

/// Mounted by the already scene-lived main-view modifier, outside the global
/// tabs. The iPhone keeps its existing independent compact implementation.
struct Exact9401WorkspaceLifecycle: ViewModifier {
    let manager: iOSNavigationManager
    @State private var workspace: StudyWorkspaceNavigationAdapter?
    @State private var sceneID = ""
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .environment(\.exact9401Workspace, workspace)
            .background {
                if MaktabahApp.isIpad {
                    ReaderSceneIdentityReader { sceneID = $0 }
                        .frame(width: 0, height: 0)
                        .accessibilityHidden(true)
                    if let workspace {
                        StudyWorkspaceCheckpointObserver(manager: manager, workspace: workspace)
                    }
                }
            }
            .task(id: sceneID) {
                guard MaktabahApp.isIpad, workspace == nil, !sceneID.isEmpty else { return }
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
            .alert("לא ניתן לשנות את סביבת הלימוד", isPresented: Binding(
                get: { workspace?.errorMessage != nil },
                set: { if !$0 { workspace?.errorMessage = nil } }
            )) {
                Button("אישור") { workspace?.errorMessage = nil }
            } message: {
                Text(workspace?.errorMessage ?? "")
            }
    }
}
