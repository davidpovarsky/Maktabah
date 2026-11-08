import SwiftUI
import UIKit

private struct ReaderContentBoundsKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? { nil }
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

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
                                 onOpenLibrary: openLibrary, onOverview: { showsOverview = true },
                                 backgroundColor: UIColor(readerChromeColor))
                    .frame(height: navigationChrome.isVisible ? TabsBarViewController.Constants.buttonHeight : 0)
                    .opacity(navigationChrome.isVisible ? 1 : 0)
                    .clipped()
                    .allowsHitTesting(navigationChrome.isVisible)
                    .accessibilityHidden(!navigationChrome.isVisible)
                    .accessibilityIdentifier("reader-document-tabs")
                reader
            }
                .anchorPreference(key: ReaderContentBoundsKey.self, value: .bounds) { $0 }
                .background(readerChromeColor)
                .modifier(ReaderSidebarToggleRemoval())
                // The measured strip ends the original reader's underlap.
                // Preserve its actual reading theme behind the native bar.
                .toolbarBackground(readerChromeColor, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    // A compact split already has the native Back-to-sidebar
                    // action. Duplicating it also displaced the search field
                    // in the genuine 375pt system window.
                    if needsCustomSidebarToggle {
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
                    if horizontalSizeClass == .compact {
                        ToolbarItem(placement: .topBarLeading) {
                            collapsedSearchField(minWidth: 72, idealWidth: 96, maxWidth: 112)
                        }
                        .readerSourceGlassBackground()
                    } else {
                        ToolbarItem(placement: .principal) {
                            collapsedSearchField(minWidth: detailWidth < 740 ? 100 : 150,
                                                 idealWidth: detailWidth < 740 ? 200 : 350,
                                                 maxWidth: 520)
                        }
                        .readerSourceGlassBackground()
                    }
                    ToolbarItem(placement: horizontalSizeClass == .compact ? .secondaryAction : .topBarTrailing) {
                        if let workspace { StudyProfileMenu(workspace: workspace, manager: manager, compact: detailWidth < 740) { showsProfiles = true } }
                    }
                    .readerSourceGlassBackground()
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { detailWidth = $0 }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbarVisibility(navigationChrome.isVisible ? .automatic : .hidden, for: .tabBar)
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
        .overlayPreferenceValue(ReaderContentBoundsKey.self) { contentBounds in
            if searchIsExpanded, let contentBounds {
                GeometryReader { geometry in
                    Color.black.opacity(0.13)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture(perform: closeSearch)
                        .transition(.opacity)
                    expandedSearch(availableWidth: geometry.size.width)
                        // Anchor to the real detail content below native bars,
                        // including iPad's floating global tabs and window chrome.
                        .padding(.top, max(0, geometry[contentBounds].minY))
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
        .onDisappear { navigationChrome.reveal() }
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
        .alert("לא ניתן לשנות את סביבת הלימוד", isPresented: workspaceErrorIsPresented) {
            Button("אישור") { workspace?.errorMessage = nil }
        } message: { Text(workspace?.errorMessage ?? "") }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chavrusa-reader-host")
    }

    private var workspaceErrorIsPresented: Binding<Bool> {
        Binding<Bool>(get: {
            workspace?.errorMessage != nil && !showsOverview && !showsProfiles
        }, set: { presented in
            guard !presented, !showsOverview, !showsProfiles else { return }
            workspace?.errorMessage = nil
        })
    }

    @ViewBuilder
    private func collapsedSearchField(minWidth: CGFloat, idealWidth: CGFloat, maxWidth: CGFloat) -> some View {
        if !searchIsExpanded {
            SafariLibrarySearchField(query: Bindable(manager.libraryViewModel).searchQuery,
                                     quickAddressFocused: $quickAddressFocused, onExpand: openSearch)
                .frame(minWidth: minWidth, idealWidth: idealWidth, maxWidth: maxWidth)
                .matchedGeometryEffect(id: "browser.search.surface", in: searchMorph)
        } else {
            Color.clear
                .frame(width: min(maxWidth, max(minWidth, availableWidth - 220)), height: 52)
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
