#if os(iOS)
import SwiftUI
import OtzariaUIRouting
import ChavrusaUIRoutingHost

private struct MaktabahNativeRoutingSessionKey: EnvironmentKey {
    static let defaultValue: MaktabahNativeSceneSession? = nil
}
extension EnvironmentValues {
    var maktabahNativeRoutingSession: MaktabahNativeSceneSession? {
        get { self[MaktabahNativeRoutingSessionKey.self] }
        set { self[MaktabahNativeRoutingSessionKey.self] = newValue }
    }
}

/// Mount outside native tabs, inside the existing workspace lifecycle modifier.
/// Existing UIKit supplies identity; no global connected-scene lookup is used.
struct MaktabahNativeRoutingHost: ViewModifier {
    let manager: iOSNavigationManager
    @Binding var selectedTab: iOSTab
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @Binding var showSettings: Bool
    @Environment(\.scenePhase) private var phase
    @Environment(\.exact9401Workspace) private var workspace
    @State private var sceneID = ""
    @State private var session: MaktabahNativeSceneSession?
    private var ready: Bool { MaktabahApp.isIpad && (!ChavrusaTextReaderUI.isEnabled || workspace?.attached == true) && !sceneID.isEmpty }
    private var bindings: MaktabahNativeSceneBindings {
        .init(manager: manager, selectedTab: $selectedTab, columnVisibility: $columnVisibility, showSettings: $showSettings)
    }
    private var projection: MaktabahNativeSceneProjection {
        .init(manager: manager, selectedTab: selectedTab, columnVisibility: columnVisibility,
              settingsPresented: showSettings, sidebar: nil, workspace: workspace)
    }
    func body(content: Content) -> some View {
        content
            .environment(\.maktabahNativeRoutingSession, session)
            .background {
                ReaderSceneIdentityReader { sceneID = $0 }
                    .frame(width: 0, height: 0).accessibilityHidden(true)
            }
            .onChange(of: ready, initial: true) { _, _ in mountIfReady() }
            .onAppear { mountIfReady() }
            .onChange(of: sceneID) { _, current in
                if let session, session.sceneID.rawValue != current {
                    MaktabahNativeRoutingComposition.shared.unmount(session)
                    self.session = nil
                }
                mountIfReady()
            }
            .onChange(of: phase) { _, new in
                guard let session else { mountIfReady(); return }
                do { try MaktabahNativeRoutingComposition.shared.setForeground(new == .active, session: session) }
                catch { session.presentation.revoke() }
            }
            .onChange(of: workspace?.selection) { _, _ in
                guard let session else { mountIfReady(); return }
                let bindings = bindings, workspace = workspace
                session.updateProjection {
                    .init(manager: bindings.manager, selectedTab: bindings.selectedTab.wrappedValue,
                          columnVisibility: bindings.columnVisibility.wrappedValue, settingsPresented: bindings.showSettings.wrappedValue,
                          sidebar: nil, workspace: workspace)
                }
                try? MaktabahNativeRoutingComposition.shared.workspaceProjectionDidUpdate(session, workspace: workspace)
            }
            .onDisappear {
                if let session { MaktabahNativeRoutingComposition.shared.unmount(session) }
                session = nil
            }
    }
    private func mountIfReady() {
        guard ready, session == nil, let id = UIStableID(rawValue: sceneID) else { return }
        do {
            let bindings = bindings, workspace = workspace
            let value = try MaktabahNativeRoutingComposition.shared.mount(sceneID: id, manager: manager, bindings: bindings, foreground: phase == .active) {
                .init(manager: bindings.manager, selectedTab: bindings.selectedTab.wrappedValue,
                      columnVisibility: bindings.columnVisibility.wrappedValue, settingsPresented: bindings.showSettings.wrappedValue,
                      sidebar: nil, workspace: workspace)
            }
            session = value
            MaktabahNativeRoutingComposition.shared.installIntentDependency()
        } catch {
            manager.alertMessage = .init(title: "Navigation unavailable", message: "This window is not ready for navigation. Try again.")
        }
    }
}

/// Attach to the actual existing screen. The marker occupies its background,
/// and derives visibility from the real foreground UIKit session after layout.
struct MaktabahNativeRoutingSurface: ViewModifier {
    let kind: MaktabahNativeSceneProjection.Surface
    @Environment(\.maktabahNativeRoutingSession) private var session
    func body(content: Content) -> some View {
        content.background {
            if let session, let state = try? session.surface(kind) {
                NativeSurfaceWitness(surface: state, submissionID: session.submissionID,
                    observeVisibility: { session.observeVisibility(for: state.destination, check: $0) }) { session.observe($0) }
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
        }
    }
}
#endif
