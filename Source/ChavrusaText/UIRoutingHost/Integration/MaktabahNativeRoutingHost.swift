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
    @State private var guidedTour: UIGuideRun?
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
            .environment(\.otzariaGuidedTour, guidedTour)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let guidedTour { OtzariaGuidedTourPanel(run: guidedTour) }
            }
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
                    stopGuidedTour()
                    MaktabahNativeRoutingComposition.shared.unmount(session)
                    self.session = nil
                }
                mountIfReady()
            }
            .onChange(of: phase) { _, new in
                guard let session else { mountIfReady(); return }
                if new != .active, let guidedTour { Task { await guidedTour.stop() } }
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
                stopGuidedTour()
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
        guidedTour?.revalidateCoaching()
    }
    private func stopGuidedTour() {
        guard let run = guidedTour else { return }
        guidedTour = nil
        Task { await run.stop() }
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
            if let definition = try? OtzariaGuidedTourPanel.appTour() {
                guidedTour = MaktabahNativeRoutingComposition.shared.makeGuide(definition, session: value, manager: manager)
            }
            try MaktabahNativeRoutingComposition.shared.installPublicBindingIfReady(
                session: value, manager: manager, workspace: workspace, owner: workspaceOwner)
            MaktabahNativeRoutingComposition.shared.installIntentDependency()
        } catch {
            manager.alertMessage = .init(title: "Navigation unavailable", message: "This window is not ready for navigation. Try again.")
        }
    }
}

private struct OtzariaGuidedTourKey: EnvironmentKey {
    static let defaultValue: UIGuideRun? = nil
}

fileprivate extension EnvironmentValues {
    var otzariaGuidedTour: UIGuideRun? {
        get { self[OtzariaGuidedTourKey.self] }
        set { self[OtzariaGuidedTourKey.self] = newValue }
    }
}

struct OtzariaGuidedTourButton: View {
    @Environment(\.otzariaGuidedTour) private var run
    @Environment(\.locale) private var locale
    var body: some View {
        if let run {
            let language = locale.language.languageCode?.identifier ?? "en"
            let title = guideText("Guided tour", "סיור מודרך", language: language)
            Menu {
                if run.phase == .exploring {
                    Button(guideText("Resume", "המשך", language: language)) { run.resume() }
                    Button(guideText("Stop", "סיום", language: language)) { Task { await run.stop() } }
                } else {
                    if run.phase == .completed || run.phase == .stopped {
                        Button(guideText("Replay", "הפעלה מחדש", language: language)) { run.replay() }
                    }
                    Button(guideText("Automatic", "אוטומטי", language: language)) { run.start(.automatic) }
                    Button(guideText("Practice", "תרגול", language: language)) { run.start(.manual) }
                }
            } label: {
                Image(systemName: "questionmark.circle")
            }
            .accessibilityLabel(title)
            .accessibilityIdentifier("otzaria-guided-tour")
            .disabled(![.ready, .completed, .stopped, .exploring].contains(run.phase))
        }
    }
}

private struct OtzariaGuidedTourPanel: View {
    let run: UIGuideRun
    @Environment(\.locale) private var locale
    private var language: String { locale.language.languageCode?.identifier ?? "en" }
    private func text(_ english: String, _ hebrew: String) -> String { guideText(english, hebrew, language: language) }

    var body: some View {
        switch run.phase {
        case .ready, .exploring, .completed, .stopped: EmptyView()
        default:
            VStack(alignment: .leading, spacing: 10) {
                if run.phase == .navigating {
                    ProgressView(text("Opening…", "פותח…"))
                } else if case .blocked = run.phase {
                    Text(text("This step is unavailable.", "השלב הזה אינו זמין."))
                } else {
                    Text(run.step.coachingText(language: language))
                }
                ViewThatFits(in: .horizontal) {
                    HStack { controls }
                    VStack(alignment: .leading) { controls }
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial)
            .accessibilityIdentifier("otzaria-guided-tour-panel")
        }
    }

    @ViewBuilder private var controls: some View {
        if run.phase == .awaitingUser {
            Button(text("Open", "פתיחה")) { run.performManualNavigation() }
        }
        if run.phase == .coaching {
            if run.stepIndex > 0 { Button(text("Back", "חזרה")) { run.back() } }
            Button(text("Next", "הבא")) { run.next() }
        }
        if run.phase != .navigating {
            Button(text("Explore", "שיטוט חופשי")) { Task { await run.explore() } }
        }
        Button(text("Stop", "סיום")) { Task { await run.stop() } }
    }

    static func appTour() throws -> UIGuideDefinition {
        try .init(steps: [
            .init(destination: .init(destination: UIDestinationID(rawValue: "native.library")!),
                  english: "Browse the library by topic or collection.", hebrew: "אפשר לעיין בספרייה לפי נושא או אוסף."),
            .init(destination: .init(destination: UIDestinationID(rawValue: "native.search")!),
                  english: "Search for a title or words within a text.", hebrew: "אפשר לחפש כותר או מילים בתוך הטקסט."),
            .init(destination: .init(destination: UIDestinationID(rawValue: "native.history")!),
                  english: "Return to recently opened texts from the history.", hebrew: "בהיסטוריה אפשר לחזור לטקסטים שנפתחו לאחרונה.")
        ])
    }
}

private func guideText(_ english: String, _ hebrew: String, language: String) -> String {
    language == "he" || language == "iw" ? hebrew : english
}

/// Attach to the actual existing screen. The marker occupies its background,
/// and derives visibility from the real foreground UIKit session after layout.
struct MaktabahNativeRoutingSurface: ViewModifier {
    let kind: MaktabahNativeSceneProjection.Surface
    var inspectorReader: ReaderViewModel? = nil

    func body(content: Content) -> some View {
        content.background {
            MaktabahNativeRoutingWitness(kind: kind, inspectorReader: inspectorReader)
        }
    }
}

struct MaktabahNativeRoutingWitness: View {
    let kind: MaktabahNativeSceneProjection.Surface
    var inspectorReader: ReaderViewModel? = nil
    var noteReader: ReaderViewModel? = nil
    var noteDraft: Annotation? = nil
    @Environment(\.maktabahNativeRoutingSession) private var session

    var body: some View {
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
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}
#endif
