import SwiftUI
import UIKit

/// Viewer-only composition. The original library/TOC/reader arrive as view builders.
struct ChavrusaReaderHost<Library: View, Contents: View, Reader: View>: View {
    @Bindable var manager: iOSNavigationManager
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @Binding var preferredCompactColumn: NavigationSplitViewColumn
    let library: (Bool) -> Library
    let contents: (Bool) -> Contents
    let reader: Reader
    @State private var sidebar = ReaderSidebarPageCoordinator()
    @State private var workspace: StudyWorkspaceNavigationAdapter?
    @State private var searchIsExpanded = false
    @FocusState private var quickAddressFocused: Bool
    @State private var showsOverview = false
    @State private var showsProfiles = false
    @State private var availableWidth: CGFloat = 640
    @State private var detailWidth: CGFloat = 640
    @State private var sceneID = ""
    @Namespace private var searchMorph
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var sidebarIsOpen: Bool {
        horizontalSizeClass == .compact ? preferredCompactColumn == .sidebar : columnVisibility != .detailOnly
    }
    private var morphSpring: Animation { .spring(response: 0.47, dampingFraction: 0.84) }

    init(manager: iOSNavigationManager, columnVisibility: Binding<NavigationSplitViewVisibility>,
         preferredCompactColumn: Binding<NavigationSplitViewColumn>,
         @ViewBuilder library: @escaping (Bool) -> Library, @ViewBuilder contents: @escaping (Bool) -> Contents, @ViewBuilder reader: () -> Reader) {
        self.manager = manager
        _columnVisibility = columnVisibility
        _preferredCompactColumn = preferredCompactColumn
        self.library = library; self.contents = contents; self.reader = reader()
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility, preferredCompactColumn: $preferredCompactColumn) {
            ReaderSidebarPager(coordinator: sidebar, library: library, contents: contents)
                .navigationSplitViewColumnWidth(min: 240, ideal: 300, max: 420)
        } detail: {
            // A measured document strip belongs to this detail column's
            // content. A safe-area preference here also shifted native bars
            // in other global tabs by 20pt on the actual iPadOS 27 captures.
            VStack(spacing: 0) {
                DocumentTabsHost(tabs: manager.openTabs, selectedID: manager.activeTabId,
                                 onSelect: { manager.selectTab(id: $0) }, onClose: { manager.closeTab(id: $0) },
                                 onReorder: { workspace?.reorder($0, to: $1, manager: manager) },
                                 onOpenLibrary: openLibrary, onOverview: { showsOverview = true })
                    .frame(height: TabsBarViewController.Constants.buttonHeight)
                    .accessibilityIdentifier("reader-document-tabs")
                reader
            }
                .toolbar(removing: .sidebarToggle)
                // The measured strip ends the original reader's underlap.
                // Preserve its actual reading theme behind the native bar.
                .toolbarBackground(manager.openTabs.isEmpty ? Color.appBackground : TextViewState.shared.backgroundColor.color,
                                   for: .navigationBar)
                .toolbar {
                    // A compact split already has the native Back-to-sidebar
                    // action. Duplicating it also displaced the search field
                    // in the genuine 375pt system window.
                    if horizontalSizeClass != .compact {
                        ToolbarItem(placement: .topBarLeading) {
                            ReaderToolbarActionAdapter(sidebarIsOpen: sidebarIsOpen) {
                                let wasOpen = sidebarIsOpen
                                withAnimation(.snappy) {
                                    preferredCompactColumn = wasOpen ? .detail : .sidebar
                                    columnVisibility = wasOpen ? .detailOnly : .all
                                }
                            }
                        }
                        .readerSourceGlassBackground()
                    }
                    ToolbarItem(placement: .principal) {
                        if !searchIsExpanded {
                            SafariLibrarySearchField(query: Bindable(manager.libraryViewModel).searchQuery,
                                                     quickAddressFocused: $quickAddressFocused, onExpand: openSearch)
                                .frame(minWidth: detailWidth < 740 ? 100 : 150,
                                       idealWidth: horizontalSizeClass == .compact ? 150 : (detailWidth < 740 ? 200 : 350),
                                       maxWidth: horizontalSizeClass == .compact ? 180 : 520)
                                .matchedGeometryEffect(id: "browser.search.surface", in: searchMorph)
                        } else {
                            Color.clear.frame(width: min(350, max(150, availableWidth - 220)), height: 52).accessibilityHidden(true)
                        }
                    }
                    .readerSourceGlassBackground()
                    ToolbarItem(placement: horizontalSizeClass == .compact ? .secondaryAction : .topBarTrailing) {
                        if let workspace { StudyProfileMenu(workspace: workspace, manager: manager, compact: detailWidth < 740) { showsProfiles = true } }
                    }
                    .readerSourceGlassBackground()
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { detailWidth = $0 }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(removing: .sidebarToggle)
        .background(Color.appBackground.ignoresSafeArea())
        .environment(\.chavrusaReaderSidebar, sidebar)
        .background {
            ReaderSceneIdentityReader { identifier in
                if sceneID != identifier { sceneID = identifier }
            }
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            if let workspace { StudyWorkspaceCheckpointObserver(manager: manager, workspace: workspace) }
            #if DEBUG
            ReaderViewportAcceptanceObserver().frame(width: 0, height: 0).accessibilityHidden(true)
            #endif
        }
        .overlay(alignment: .top) {
            if searchIsExpanded {
                GeometryReader { geometry in
                    Color.black.opacity(0.13)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture(perform: closeSearch)
                        .transition(.opacity)
                    expandedSearch(availableWidth: geometry.size.width)
                }
                .zIndex(3)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
        .animation(reduceMotion ? nil : morphSpring, value: searchIsExpanded)
        .onChange(of: quickAddressFocused) { _, focused in
            if focused { quickAddressFocused = false; openSearch() }
        }
        .task(id: sceneID) {
            guard workspace == nil, !sceneID.isEmpty else { return }
            manager.restoreSessionIfNeeded()
            let adapter = StudyWorkspaceNavigationAdapter(sceneID: sceneID, store: StudyWorkspaceStore.forCurrentProcess())
            workspace = adapter
            await adapter.attach(manager)
        }
        .onChange(of: manager.openTabs.map(\.id)) { _, _ in workspace?.synchronize(manager) }
        .onChange(of: manager.activeTabId) { _, _ in
            workspace?.synchronize(manager)
            if horizontalSizeClass == .compact { preferredCompactColumn = .detail }
        }
        .onChange(of: workspace?.selection?.groupID) { _, _ in
            Task { await workspace?.reconcileSceneSelection(manager) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .activeLibraryBackendDidChange)) { _ in workspace?.synchronize(manager) }
        .onChange(of: scenePhase) { _, phase in if phase != .active { workspace?.synchronize(manager) } }
        .sheet(isPresented: $showsOverview) {
            if let workspace { StudyGroupsOverview(workspace: workspace, manager: manager, onOpenLibrary: openLibrary) }
        }
        .sheet(isPresented: $showsProfiles) {
            if let workspace { StudyProfileManagementView(workspace: workspace, manager: manager) }
        }
        .alert("לא ניתן לשנות את סביבת הלימוד", isPresented: Binding(
            get: { workspace?.errorMessage != nil && !showsOverview && !showsProfiles }, set: { if !$0 && !showsOverview && !showsProfiles { workspace?.errorMessage = nil } })) {
            Button("אישור") { workspace?.errorMessage = nil }
        } message: { Text(workspace?.errorMessage ?? "") }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chavrusa-reader-host")
    }

    // Exact expandedSearch placement and matched geometry from the owner's prototype.
    private func expandedSearch(availableWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            LibraryCommandPaletteAdapter(manager: manager, onDismiss: closeSearch)
                .gelatinMotionOnly()
                .frame(maxWidth: min(CGFloat(690), availableWidth - 30))
                .matchedGeometryEffect(id: "browser.search.surface", in: searchMorph)
                .padding(.top, 6)
                .padding(.horizontal, 15)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
    private func openSearch() {
        guard !searchIsExpanded else { return }
        quickAddressFocused = false
        searchIsExpanded = true
    }
    private func closeSearch() {
        guard searchIsExpanded else { return }
        searchIsExpanded = false
        quickAddressFocused = false
    }
    private func openLibrary() {
        sidebar.showLibrary()
        preferredCompactColumn = .sidebar
        withAnimation(.snappy) { columnVisibility = .all }
    }
}

/// UIKit owns the durable identity of the actual containing window. Do not
/// choose an arbitrary connected scene or generate another ID on cold launch.
private struct ReaderSceneIdentityReader: UIViewRepresentable {
    let resolve: (String) -> Void
    func makeUIView(context: Context) -> ReaderSceneIdentityView {
        let view = ReaderSceneIdentityView()
        view.isUserInteractionEnabled = false
        view.onResolve = resolve
        return view
    }
    func updateUIView(_ view: ReaderSceneIdentityView, context: Context) {
        view.onResolve = resolve
        view.publishIdentity()
    }
}

private final class ReaderSceneIdentityView: UIView {
    var onResolve: ((String) -> Void)?
    private var publishedID: String?
    override func didMoveToWindow() {
        super.didMoveToWindow()
        publishIdentity()
    }
    func publishIdentity() {
        guard let identifier = window?.windowScene?.session.persistentIdentifier,
              identifier != publishedID else { return }
        publishedID = identifier
        Task { @MainActor [weak self] in
            guard self?.window?.windowScene?.session.persistentIdentifier == identifier else { return }
            self?.onResolve?(identifier)
        }
    }
}

/// Keep high-frequency viewport observation out of the split-view/toolbar invalidation graph.
private struct StudyWorkspaceCheckpointObserver: View {
    let manager: iOSNavigationManager
    let workspace: StudyWorkspaceNavigationAdapter
    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onChange(of: manager.activeReaderViewModel?.currentLocator) { _, _ in workspace.scheduleCheckpoint(manager) }
            .onChange(of: manager.activeReaderViewModel?.currentID) { _, _ in workspace.scheduleCheckpoint(manager) }
            .onChange(of: manager.activeReaderViewModel?.readerState.scrollPosition) { _, _ in workspace.scheduleCheckpoint(manager) }
            .onChange(of: manager.activeReaderViewModel?.readerState.selectedRange) { _, _ in workspace.scheduleCheckpoint(manager) }
    }
}
