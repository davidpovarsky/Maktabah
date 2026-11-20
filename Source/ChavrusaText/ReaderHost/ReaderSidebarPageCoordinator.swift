import SwiftUI
import UIKit

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
    var contentsQuery = ""
    var requestsLibrary = false
    var overview = ReaderOverviewPresentationState()
    var navigationChrome = ReaderNavigationChromeState()
    @ObservationIgnored private weak var navigationChromeWindowOwner: UIView?
    @ObservationIgnored private weak var navigationChromeWindow: UIWindow?

    func observeNavigationChromeWindow(owner: UIView, window: UIWindow?) {
        if let window {
            navigationChromeWindowOwner = owner
            navigationChromeWindow = window
        } else if navigationChromeWindowOwner === owner {
            navigationChromeWindowOwner = nil
            navigationChromeWindow = nil
        }
    }

    func ownsNavigationChromeWindow(_ scrollView: UIScrollView, sceneID: String) -> Bool {
        guard let window = navigationChromeWindow,
              navigationChromeWindowOwner?.window === window,
              scrollView.window === window,
              window.isKeyWindow, !window.isHidden, window.alpha > 0,
              let scene = window.windowScene,
              scene.activationState == .foregroundActive,
              scene.session.persistentIdentifier == sceneID
        else { return false }
        return true
    }
    func showContents() { page = .contents }
    func showLibrary() { page = .library; requestsLibrary.toggle() }
}

private struct ReaderSidebarCoordinatorKey: EnvironmentKey {
    static let defaultValue: ReaderSidebarPageCoordinator? = nil
}

/// Scoped to the pager, not the scene: standalone TOC sheets retain Close.
private struct ReaderSidebarOwnsToggleKey: EnvironmentKey {
    static let defaultValue = false
}

private struct Exact9401WorkspaceKey: EnvironmentKey {
    static let defaultValue: StudyWorkspaceNavigationAdapter? = nil
}

extension EnvironmentValues {
    var readerSidebarOwnsToggle: Bool {
        get { self[ReaderSidebarOwnsToggleKey.self] }
        set { self[ReaderSidebarOwnsToggleKey.self] = newValue }
    }

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
    @Environment(\.chavrusaReaderSidebar) private var sidebar

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        guard workspace?.attached == true, let sidebar else { return }
                        isPresented = false
                        showsProfiles = false
                        sidebar.navigationChrome.reveal()
                        sidebar.overview.request()
                    } label: {
                        Label("כל הכרטיסיות", systemImage: "square.on.square")
                    }
                    .accessibilityIdentifier("reader-tabs-overview")
                    .disabled(workspace?.attached != true || sidebar == nil)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    OtzariaHanlinChatLaunchButton(identifier: "otzaria-hanlin-reader-launch")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        sidebar?.navigationChrome.reveal()
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
                            sidebar?.navigationChrome.reveal()
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
            .onChange(of: sidebar?.overview.requestID) { _, id in
                if id != nil { isPresented = false; showsProfiles = false }
            }
            .onDisappear { isPresented = false; showsProfiles = false }
    }
}

/// Mounted by the already scene-lived main-view modifier, outside the global
/// tabs. The iPhone keeps its existing compact implementation and exposes that
/// same owner to routing; it never creates a second adapter/store for routing.
struct Exact9401WorkspaceLifecycle: ViewModifier {
    let manager: iOSNavigationManager
    var compactWorkspaceOwner: MaktabahNativeWorkspaceOwner? = nil
    @State private var workspaceOwner = MaktabahNativeWorkspaceOwner()
    private var workspace: StudyWorkspaceNavigationAdapter? {
        // A disabled process must not create, expose or checkpoint workspace
        // state, including an owner retained from an earlier view evaluation.
        ChavrusaTextReaderUI.isEnabled ? workspaceOwner.current : nil
    }
    private var routingWorkspaceOwner: MaktabahNativeWorkspaceOwner? {
        guard ChavrusaTextReaderUI.isEnabled else { return nil }
        return MaktabahApp.isIpad ? workspaceOwner : compactWorkspaceOwner
    }
    @State private var sceneID = ""
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .environment(\.exact9401Workspace, routingWorkspaceOwner?.current)
            .environment(\.maktabahNativeWorkspaceOwner, routingWorkspaceOwner)
            .background {
                if ChavrusaTextReaderUI.isEnabled && MaktabahApp.isIpad {
                    ReaderSceneIdentityReader { sceneID = $0 }
                        .frame(width: 0, height: 0)
                        .accessibilityHidden(true)
                    if let workspace {
                        StudyWorkspaceCheckpointObserver(manager: manager, workspace: workspace)
                    }
                    #if DEBUG
                    // The original iPad split uses this scene-lived adapter;
                    // ChavrusaReaderHost is not mounted on that path. Reuse the
                    // existing read-only observer at the actual active host.
                    ReaderViewportAcceptanceObserver().frame(width: 0, height: 0).accessibilityHidden(true)
                    #endif
                }
            }
            .task(id: sceneID) {
                guard ChavrusaTextReaderUI.isEnabled, MaktabahApp.isIpad, workspace == nil, !sceneID.isEmpty else { return }
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
