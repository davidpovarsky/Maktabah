#if os(iOS)
import SwiftUI
import OtzariaUIRouting
import ChavrusaUIRoutingHost

private struct MaktabahNativeRoutingSessionKey: EnvironmentKey {
    static let defaultValue: MaktabahNativeSceneSession? = nil
}
private struct MaktabahNativeWorkspaceOwnerKey: EnvironmentKey {
    static let defaultValue: MaktabahNativeWorkspaceOwner? = nil
}
extension EnvironmentValues {
    var maktabahNativeWorkspaceOwner: MaktabahNativeWorkspaceOwner? {
        get { self[MaktabahNativeWorkspaceOwnerKey.self] }
        set { self[MaktabahNativeWorkspaceOwnerKey.self] = newValue }
    }
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
    let sidebar: ReaderSidebarPageCoordinator?
    @Environment(\.scenePhase) private var phase
    @Environment(\.exact9401Workspace) private var workspace
    @Environment(\.maktabahNativeWorkspaceOwner) private var workspaceOwner
    @State private var sceneID = ""
    @State private var session: MaktabahNativeSceneSession?
    @State private var windowSource = MaktabahNativeWindowSource()
    @State private var hanlinChat: OtzariaHanlinChatOwner?
    // Both layouts expose their original scene-lived workspace owner. Wait
    // for that actual adapter before mounting content-capable navigation.
    private var ready: Bool {
        (!ChavrusaTextReaderUI.isEnabled || workspace?.attached == true)
            && !sceneID.isEmpty
    }
    private var bindings: MaktabahNativeSceneBindings {
        .init(manager: manager, selectedTab: $selectedTab, columnVisibility: $columnVisibility, showSettings: $showSettings, sidebar: sidebar)
    }
    private var projection: MaktabahNativeSceneProjection {
        .init(manager: manager, selectedTab: selectedTab, columnVisibility: columnVisibility,
              settingsPresented: showSettings, sidebar: sidebar, workspace: workspace)
    }
    func body(content: Content) -> some View {
        content
            .environment(\.maktabahNativeRoutingSession, session)
            .modifier(OtzariaHanlinChatPresentationHost(owner: hanlinChat))
            .background {
                ReaderSceneIdentityReader(observeWindow: { source, window in
                    if windowSource.observe(window, from: source) {
                        session?.nativeWindowDidChange(windowSource)
                    }
                }) { sceneID = $0 }
                    .frame(width: 0, height: 0).accessibilityHidden(true)
            }
            .onChange(of: ready, initial: true) { _, _ in mountIfReady() }
            .onAppear { mountIfReady() }
            .onChange(of: sceneID) { _, current in
                if let session, session.sceneID.rawValue != current {
                    hanlinChat?.retire(); hanlinChat = nil
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
                refreshProjection()
            }
            // Cold restoration can publish the original live mapping after
            // attachment without changing the saved selection. Install its
            // existing binding on that publication as well; readiness never
            // substitutes for the producer's ownership and authority checks.
            .onChange(of: workspace?.mappingOwnershipSource.event) { _, event in
                guard event?.phase == .available else { return }
                refreshProjection()
            }
            // Bindings captured at mount can retain their render-time value
            // during a later SwiftUI graph evaluation. Refresh the projection
            // used by the actual destination marker after native UI changes.
            // The route's own mutation must not revoke its admitted authority.
            .onChange(of: selectedTab) { _, _ in refreshProjection(workspaceChanged: false) }
            .onChange(of: showSettings) { _, _ in refreshProjection(workspaceChanged: false) }
            .onChange(of: columnVisibility) { _, _ in refreshProjection(workspaceChanged: false) }
            .onChange(of: sidebar?.page) { _, _ in refreshProjection(workspaceChanged: false) }
            .onChange(of: sidebar?.overview) { _, _ in refreshProjection(workspaceChanged: false) }
            .onDisappear {
                hanlinChat?.retire(); hanlinChat = nil
                if let session { MaktabahNativeRoutingComposition.shared.unmount(session) }
                session = nil
            }
    }
    private func refreshProjection(workspaceChanged: Bool = true) {
        guard let session else { mountIfReady(); return }
        let bindings = bindings
        let source = session.workspaceProjectionSource.flatMap { $0.isAuthoritative ? $0 : nil }
            ?? MaktabahNativeWorkspaceProjectionSource(owner: nil, legacyWorkspace: workspace)
        session.updateProjection(source.projection { workspace in
            .init(manager: bindings.manager, selectedTab: bindings.selectedTab.wrappedValue,
                  columnVisibility: bindings.columnVisibility.wrappedValue, settingsPresented: bindings.showSettings.wrappedValue,
                  sidebar: bindings.sidebar, workspace: workspace)
        })
        if workspaceChanged {
            try? MaktabahNativeRoutingComposition.shared.workspaceProjectionDidUpdate(session, workspace: workspace)
        } else {
            try? session.nativeStateChanged()
        }
        try? MaktabahNativeRoutingComposition.shared.installPublicBindingIfReady(
            session: session, manager: manager, workspace: workspace, owner: workspaceOwner)
    }
    private func mountIfReady() {
        guard ready, session == nil, let id = UIStableID(rawValue: sceneID) else { return }
        do {
            let bindings = bindings
            let source = MaktabahNativeWorkspaceProjectionSource(owner: workspaceOwner, legacyWorkspace: workspace)
            let value = try MaktabahNativeRoutingComposition.shared.mount(sceneID: id, manager: manager, bindings: bindings, foreground: phase == .active,
                workspaceSource: source, project: source.projection { workspace in
                .init(manager: bindings.manager, selectedTab: bindings.selectedTab.wrappedValue,
                      columnVisibility: bindings.columnVisibility.wrappedValue, settingsPresented: bindings.showSettings.wrappedValue,
                      sidebar: bindings.sidebar, workspace: workspace)
            })
            value.attachWindowSource(windowSource)
            session = value
            hanlinChat = .init(manager: manager, session: value, composition: MaktabahNativeRoutingComposition.shared)
            try MaktabahNativeRoutingComposition.shared.installPublicBindingIfReady(
                session: value, manager: manager, workspace: workspace, owner: workspaceOwner)
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
    let inspectorReader: ReaderViewModel?
    let noteReader: ReaderViewModel?
    let noteDraft: Annotation?
    init(kind: MaktabahNativeSceneProjection.Surface, inspectorReader: ReaderViewModel? = nil,
         noteReader: ReaderViewModel? = nil, noteDraft: Annotation? = nil) {
        self.kind = kind; self.inspectorReader = inspectorReader
        self.noteReader = noteReader; self.noteDraft = noteDraft
    }
    @Environment(\.maktabahNativeRoutingSession) private var session
    func body(content: Content) -> some View {
        content.background {
            if let session,
               kind != .inspector || inspectorReader.map({ session.ownsInspectorReader($0) }) == true,
               kind != .noteDraft || (noteReader.flatMap { reader in
                   noteDraft.map { session.ownsNoteEditor(reader, draft: $0) }
               } == true),
               let state = try? session.surface(kind) {
                NativeSurfaceWitness(surface: state, submissionID: session.submissionID,
                    observeVisibility: { session.observeVisibility(for: state.destination, check: $0) },
                    diagnose: { flags in
                        #if DEBUG
                        OtzariaFileLogger.shared.log("[NativeSurfaceWitness] destination=\(state.destination.rawValue) \(flags)")
                        #endif
                    }) { session.observe($0) }
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
        }
    }
}
#endif
