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
    var overview = ReaderOverviewPresentationState() {
        willSet {
            if newValue.requestID != overview.requestID || newValue.isRequested != overview.isRequested {
                for notify in Array(overviewRequestObservers.values) { notify() }
            }
        }
    }
    @ObservationIgnored private var overviewRequestObservers: [UUID: @MainActor () -> Void] = [:]

    func observeOverviewRequestChanges(_ notify: @escaping @MainActor () -> Void) -> UUID {
        let token = UUID(); overviewRequestObservers[token] = notify; return token
    }

    func removeOverviewRequestObserver(_ token: UUID) { overviewRequestObservers.removeValue(forKey: token) }
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

    // Presentation belongs to this reader scene; the LibraryViewModel remains
    // the sole owner of the actual query and filtered library membership.
    var librarySearchIsPresented = false
    var librarySearchIsPressed = false
    private var librarySearchAnchor = CGRect.null
    private var librarySearchContainer = CGRect.null
    private var librarySearchGeometryRevision = 0
    @ObservationIgnored private weak var librarySearchAnchorOwner: UIView?
    @ObservationIgnored private weak var librarySearchAnchorWindow: UIWindow?
    @ObservationIgnored private weak var librarySearchContainerOwner: UIView?
    @ObservationIgnored private weak var librarySearchContainerWindow: UIWindow?

    var librarySearchFrames: (anchor: CGRect, container: CGRect)? {
        _ = librarySearchGeometryRevision
        guard let window = librarySearchAnchorWindow,
              librarySearchContainerWindow === window,
              librarySearchAnchorOwner?.window === window,
              librarySearchContainerOwner?.window === window,
              !librarySearchAnchor.isNull, !librarySearchContainer.isNull,
              librarySearchAnchor.width > 0, librarySearchAnchor.height > 0,
              librarySearchContainer.width > 0, librarySearchContainer.height > 0
        else { return nil }
        return (librarySearchAnchor, librarySearchContainer)
    }

    func observeLibrarySearchAnchor(owner: UIView, frame: CGRect, window: UIWindow?) {
        if let window {
            let changedWindow = librarySearchAnchorWindow !== window
            librarySearchAnchorOwner = owner
            librarySearchAnchorWindow = window
            librarySearchAnchor = frame
            if changedWindow { librarySearchGeometryRevision += 1 }
        } else if librarySearchAnchorOwner === owner {
            librarySearchAnchorOwner = nil
            librarySearchAnchorWindow = nil
            librarySearchAnchor = .null
            dismissLibrarySearch()
        }
    }

    func observeLibrarySearchContainer(owner: UIView, frame: CGRect, window: UIWindow?) {
        if let window {
            let changedWindow = librarySearchContainerWindow !== window
            librarySearchContainerOwner = owner
            librarySearchContainerWindow = window
            librarySearchContainer = frame
            if changedWindow { librarySearchGeometryRevision += 1 }
        } else if librarySearchContainerOwner === owner {
            librarySearchContainerOwner = nil
            librarySearchContainerWindow = nil
            librarySearchContainer = .null
            dismissLibrarySearch()
        }
    }

    func presentLibrarySearch() {
        #if DEBUG
        LibraryCommandPaletteEscapeObservation.recordHost(.viewerOpenEnter, presented: librarySearchIsPresented)
        #endif
        navigationChrome.reveal()
        librarySearchIsPresented = true
        #if DEBUG
        LibraryCommandPaletteEscapeObservation.recordHost(.viewerOpenReturned, presented: librarySearchIsPresented)
        #endif
    }

    func dismissLibrarySearch() {
        #if DEBUG
        LibraryCommandPaletteEscapeObservation.recordHost(.viewerCloseEnter, presented: librarySearchIsPresented)
        #endif
        librarySearchIsPresented = false
        librarySearchIsPressed = false
        #if DEBUG
        LibraryCommandPaletteEscapeObservation.recordHost(.viewerCloseReturned, presented: librarySearchIsPresented)
        #endif
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
    @State private var showsProfiles = false
    @State private var presentationViewID = UUID()
    @State private var detailWidth: CGFloat = 0
    @Environment(\.exact9401Workspace) private var workspace
    @Environment(\.chavrusaReaderSidebar) private var sidebar
    @Environment(\.maktabahNativeRoutingSession) private var routingSession

    private var profilesBinding: Binding<Bool> {
        maktabahWorkspaceOriginalBinding($showsProfiles, binding: routingSession?.workspacePresentation,
            host: .tabletToolbar, stateOwnerID: presentationViewID, change: .profiles)
    }

    private var isPresented: Bool { sidebar?.librarySearchIsPresented == true }
    private var compactSearchWidth: CGFloat {
        // Keep the original native title/actions usable in narrow windows.
        // The bridge measures the final proposed Button bounds, not this ideal.
        detailWidth >= 700 ? min(240, detailWidth * 0.28) : 44
    }

    func body(content: Content) -> some View {
        content
            .background {
                if let workspace {
                    Color.clear.modifier(MaktabahNativeWorkspaceOriginalHost(
                        binding: routingSession?.workspacePresentation, kind: .tabletToolbar, stateOwnerID: presentationViewID,
                        workspace: workspace, manager: manager,
                        profilesPresented: { showsProfiles },
                        presentProfiles: {
                            sidebar?.dismissLibrarySearch()
                            sidebar?.navigationChrome.reveal()
                            profilesBinding.wrappedValue = true
                        },
                        blocked: { workspace.isSwitching || workspace.errorMessage != nil }))
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        guard workspace?.attached == true, let sidebar else { return }
                        sidebar.dismissLibrarySearch()
                        profilesBinding.wrappedValue = false
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
                        sidebar?.presentLibrarySearch()
                    } label: {
                        // The split-level morph owns the sole visible surface.
                        // This remains the real native toolbar activation target.
                        Color.clear
                            .frame(minWidth: 44, idealWidth: compactSearchWidth, maxWidth: compactSearchWidth)
                            .frame(height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(LibrarySearchPressStyle { sidebar?.librarySearchIsPressed = $0 })
                    .background {
                        ReaderToolbarFrameReader(tracksPosition: isPresented) { owner, frame, window in
                            sidebar?.observeLibrarySearchAnchor(owner: owner, frame: frame, window: window)
                        }
                        .accessibilityHidden(true)
                    }
                    .accessibilityLabel("חיפוש מהיר בספרייה")
                    .accessibilityValue(manager.libraryViewModel.searchQuery)
                    .accessibilityIdentifier("reader-command-palette-launcher")
                }
                .readerSourceGlassBackground()
                ToolbarItem(placement: .topBarTrailing) {
                    if let workspace {
                        StudyProfileMenu(workspace: workspace, manager: manager, usesNativeToolbar: true) {
                            sidebar?.dismissLibrarySearch()
                            sidebar?.navigationChrome.reveal()
                            profilesBinding.wrappedValue = true
                        }
                    }
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { detailWidth = $0 }
            .sheet(isPresented: profilesBinding) {
                if let workspace {
                    StudyProfileManagementView(workspace: workspace, manager: manager)
                        .environment(\.maktabahNativeRoutingSession, routingSession)
                }
            }
            #if DEBUG
            .onChange(of: isPresented) { _, presented in
                LibraryCommandPaletteEscapeObservation.recordHost(.viewerStateChanged, presented: presented)
            }
            #endif
            .onChange(of: workspace?.selection?.profileID) { _, _ in sidebar?.dismissLibrarySearch() }
            .onChange(of: sidebar?.overview.requestID) { _, id in
                if id != nil { sidebar?.dismissLibrarySearch(); profilesBinding.wrappedValue = false }
            }
            .onDisappear { sidebar?.dismissLibrarySearch(); profilesBinding.wrappedValue = false }
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
