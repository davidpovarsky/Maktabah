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
    @State private var detailWidth: CGFloat = 640
    @State private var toolbarWindowY: CGFloat = 0
    @State private var searchOverlayWindowY: CGFloat = 0
    @State private var sceneID = ""
    @State private var navigationChrome = ReaderNavigationChromeState()
    @Namespace private var searchMorph
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var sidebarIsOpen: Bool {
        horizontalSizeClass == .compact ? preferredCompactColumn == .sidebar : columnVisibility != .detailOnly
    }
    private var needsCustomSidebarToggle: Bool {
        // iPadOS27 supplies the real split-view action even after toolbar
        // removal preferences. A second action was visible in native captures.
        if #available(iOS 27.0, *) { return false }
        return horizontalSizeClass != .compact
    }
    private var readerChromeColor: Color {
        manager.openTabs.isEmpty ? Color.appBackground : TextViewState.shared.backgroundColor.color
    }
    private var morphSpring: Animation { .spring(response: 0.47, dampingFraction: 0.84) }
    private var chromeAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.90)
    }

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
                                 backgroundColor: UIColor(readerChromeColor))
                    .frame(height: navigationChrome.isVisible && !manager.openTabs.isEmpty ? TabsBarViewController.Constants.buttonHeight : 0)
                    .opacity(navigationChrome.isVisible && !manager.openTabs.isEmpty ? 1 : 0)
                    .clipped()
                    .allowsHitTesting(navigationChrome.isVisible && !manager.openTabs.isEmpty)
                    .accessibilityHidden(!navigationChrome.isVisible || manager.openTabs.isEmpty)
                    .accessibilityIdentifier("reader-document-tabs")
                reader
            }
                .background(readerChromeColor)
                .modifier(ReaderSidebarToggleRemoval())
                // SafariGlass owns each surface. The opaque navigation-bar
                // backing otherwise becomes a second layer under those groups.
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    // Keep the prototype's HStack and groups together inside
                    // one native item; independent items change their spacing
                    // and allow the system to overflow only part of the row.
                    ToolbarItem(placement: .principal) {
                        safariToolbar(compact: detailWidth < 740)
                            .frame(width: max(0, detailWidth - (needsCustomSidebarToggle ? 38 : 100)))
                            .background(alignment: .topLeading) {
                                ReaderToolbarOriginReader(tracksPosition: searchIsExpanded) { toolbarWindowY = $0 }
                                    .frame(width: 0, height: 0)
                                    .accessibilityHidden(true)
                            }
                    }
                    .readerSourceGlassBackground()
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { detailWidth = $0 }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbarVisibility(navigationChrome.isVisible ? .visible : .hidden, for: .tabBar)
        .modifier(ReaderSidebarToggleRemoval())
        .background(readerChromeColor.ignoresSafeArea())
        .environment(\.chavrusaReaderSidebar, sidebar)
        .environment(\.chavrusaReaderNavigationChromeVisible, navigationChrome.isVisible)
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
            GeometryReader { geometry in
                if searchIsExpanded {
                    Color.black.opacity(0.13)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture(perform: closeSearch)
                        .transition(.opacity)
                    expandedSearch(availableWidth: geometry.size.width)
                        // The prototype toolbar has 7pt top padding; its
                        // expandedSearch retains its original 6pt padding.
                        // Both anchors use actual UIWindow coordinates because
                        // native toolbar hosting has its own SwiftUI graph.
                        .offset(y: toolbarWindowY - searchOverlayWindowY - 7)
                }
            }
            .background(alignment: .topLeading) {
                ReaderToolbarOriginReader(tracksPosition: searchIsExpanded) { searchOverlayWindowY = $0 }
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            }
            .allowsHitTesting(searchIsExpanded)
            .accessibilityHidden(!searchIsExpanded)
            .zIndex(3)
        }
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
            revealNavigationChrome()
            workspace?.synchronize(manager)
            if horizontalSizeClass == .compact { preferredCompactColumn = .detail }
        }
        .onChange(of: sidebarIsOpen) { _, open in
            if open { revealNavigationChrome() }
        }
        .onChange(of: manager.activeReaderViewModel?.currentContentId) { _, _ in revealNavigationChrome() }
        .onChange(of: manager.activeReaderViewModel?.readerInspectorVisible) { _, visible in
            if visible == true { revealNavigationChrome() }
        }
        .onChange(of: manager.activeReaderViewModel?.isPopoverPresented) { _, presented in
            if presented == true { revealNavigationChrome() }
        }
        .onChange(of: showsOverview) { _, showing in if showing { revealNavigationChrome() } }
        .onChange(of: showsProfiles) { _, showing in if showing { revealNavigationChrome() } }
        .onDisappear {
            navigationChrome.reveal()
            closeSearch()
        }
        .onChange(of: workspace?.selection?.groupID) { _, _ in
            Task { await workspace?.reconcileSceneSelection(manager) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .activeLibraryBackendDidChange)) { _ in workspace?.synchronize(manager) }
        .onReceive(NotificationCenter.default.publisher(for: .chavrusaReaderDidScroll)) { note in
            guard let source = note.object as? ReaderViewModel,
                  source === manager.activeReaderViewModel,
                  !searchIsExpanded, !showsOverview, !showsProfiles,
                  source.isPopoverPresented == false, source.readerInspectorVisible == false,
                  let translationY = note.userInfo?[ChavrusaReaderScrollKey.translationY] as? CGFloat,
                  let isAtTop = note.userInfo?[ChavrusaReaderScrollKey.isAtTop] as? Bool
            else { return }
            if note.userInfo?[ChavrusaReaderScrollKey.beginsDrag] as? Bool == true {
                navigationChrome.beginDragging()
            } else {
                withAnimation(chromeAnimation) {
                    navigationChrome.consume(translationY: translationY, isAtTop: isAtTop)
                }
            }
        }
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

    // Owner prototype safariToolbar(compact:): same 6/11pt spacing, 54pt
    // row, 52pt glass groups and 39×44pt buttons. Browser-only share/download
    // and back actions are omitted; the native split supplies its own sidebar
    // action where required. The original Maktabah actions remain elsewhere.
    private func safariToolbar(compact: Bool) -> some View {
        HStack(spacing: compact ? 6 : 11) {
            GlassButtonGroup {
                toolbarButton("square.on.square", title: "כל הכרטיסיות", identifier: "reader-tabs-overview") {
                    withAnimation(.smooth(duration: 0.25)) { showsOverview = true }
                }
                toolbarButton("plus", title: "פתח ספר מהספרייה", identifier: "reader-open-book", action: openLibrary)
            }
            collapsedSearchField
                .frame(maxWidth: .infinity)
            if let workspace {
                StudyProfileMenu(workspace: workspace, manager: manager, compact: compact) { showsProfiles = true }
            }
            if needsCustomSidebarToggle {
                ReaderToolbarActionAdapter(sidebarIsOpen: sidebarIsOpen) {
                    let wasOpen = sidebarIsOpen
                    withAnimation(.smooth(duration: 0.24)) {
                        preferredCompactColumn = wasOpen ? .detail : .sidebar
                        columnVisibility = wasOpen ? .detailOnly : .all
                    }
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .frame(height: 54)
    }

    private func toolbarButton(_ symbol: String, title: String, identifier: String,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .regular))
                .frame(width: 39, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private var collapsedSearchField: some View {
        if !searchIsExpanded {
            SafariLibrarySearchField(query: Bindable(manager.libraryViewModel).searchQuery,
                                     quickAddressFocused: $quickAddressFocused, onExpand: openSearch)
                .frame(maxWidth: .infinity)
                .matchedGeometryEffect(id: "browser.search.surface", in: searchMorph)
        } else {
            Color.clear
                .frame(height: 52)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
        }
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
        revealNavigationChrome()
        quickAddressFocused = false
        searchIsExpanded = true
    }
    private func closeSearch() {
        guard searchIsExpanded else { return }
        searchIsExpanded = false
        quickAddressFocused = false
    }
    private func openLibrary() {
        revealNavigationChrome()
        sidebar.showLibrary()
        preferredCompactColumn = .sidebar
        withAnimation(.snappy) { columnVisibility = .all }
    }

    private func revealNavigationChrome() {
        withAnimation(chromeAnimation) {
            navigationChrome.reveal()
        }
    }
}

extension Notification.Name {
    static let chavrusaReaderDidScroll = Notification.Name("ChavrusaText.readerDidScroll")
}

enum ChavrusaReaderScrollKey {
    static let translationY = "translationY"
    static let isAtTop = "isAtTop"
    static let beginsDrag = "beginsDrag"
}

/// Called only from the original scroll delegate's existing callbacks. No
/// delegate replacement, content offset changes or renderer state writes.
@MainActor
enum ReaderNavigationChromeScrollReporter {
    static func report(_ scrollView: UIScrollView, reader: ReaderViewModel, beginsDrag: Bool = false, reachedTop: Bool = false) {
        let isAtTop = scrollView.contentOffset.y <= -scrollView.adjustedContentInset.top + 2
        guard !((scrollView as? iOSCustomIbarotTextView)?.isRestoringScroll ?? false),
              scrollView.window != nil,
              beginsDrag || reachedTop || scrollView.isDragging || scrollView.isTracking || (scrollView.isDecelerating && isAtTop) else { return }
        NotificationCenter.default.post(name: .chavrusaReaderDidScroll, object: reader, userInfo: [
            ChavrusaReaderScrollKey.beginsDrag: beginsDrag,
            ChavrusaReaderScrollKey.translationY: scrollView.panGestureRecognizer.translation(in: scrollView).y,
            ChavrusaReaderScrollKey.isAtTop: isAtTop,
        ])
    }
}

private struct ReaderSidebarToggleRemoval: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 27.0, *) {
            content
        } else {
            content.toolbar(removing: .sidebarToggle)
        }
    }
}

/// UIKit owns the durable identity of the actual containing window. Do not
/// choose an arbitrary connected scene or generate another ID on cold launch.
struct ReaderSceneIdentityReader: UIViewRepresentable {
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

final class ReaderSceneIdentityView: UIView {
    var onResolve: ((String) -> Void)?
    private var publishedID: String?
    override func didMoveToWindow() {
        super.didMoveToWindow()
        publishIdentity()
    }
    func publishIdentity() {
        guard let identifier = window?.windowScene?.session.persistentIdentifier,
              identifier != publishedID else { return }
        Task { @MainActor [weak self] in
            guard let self, self.window?.windowScene?.session.persistentIdentifier == identifier,
                  self.publishedID != identifier else { return }
            self.publishedID = identifier
            self.onResolve?(identifier)
        }
    }
}

/// Keep high-frequency viewport observation out of the split-view/toolbar invalidation graph.
struct StudyWorkspaceCheckpointObserver: View {
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
