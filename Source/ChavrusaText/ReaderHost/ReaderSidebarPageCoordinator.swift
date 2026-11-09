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

extension EnvironmentValues {
    var chavrusaReaderSidebar: ReaderSidebarPageCoordinator? {
        get { self[ReaderSidebarCoordinatorKey.self] }
        set { self[ReaderSidebarCoordinatorKey.self] = newValue }
    }
}

/// One viewer-only native action. The existing palette owns its input, material,
/// command identity, dismissal and UIKit Escape handling.
struct Exact9401PaletteLauncher: ViewModifier {
    let manager: iOSNavigationManager
    @State private var isPresented = false

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
            .onDisappear { isPresented = false }
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
