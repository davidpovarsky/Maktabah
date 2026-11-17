/// Shared by the actual sidebar host and its portable, non-UI tests.
enum ReaderSidebarPolicy {
    static let minimumReaderWidth = 430.0
    static let minimumSidebarWidth = 220.0
    static let dividerAllowance = 1.0

    static func canTile(availableWidth: Double, sidebarWidth: Double, isCompact: Bool, readerWidth: Double = 430) -> Bool {
        !isCompact && availableWidth.isFinite && sidebarWidth.isFinite && readerWidth.isFinite
            && availableWidth >= max(minimumSidebarWidth, sidebarWidth) + max(minimumReaderWidth, readerWidth) + dividerAllowance
    }

    /// nil leaves the active page alone; vertical native scrolling stays with
    /// the original list. Body and page-control strip share this direction rule.
    static func swipeSelectsContents(horizontal: Double, vertical: Double, isRTL: Bool) -> Bool? {
        guard horizontal.isFinite, vertical.isFinite,
              abs(horizontal) >= 44, abs(horizontal) > abs(vertical) * 1.25 else { return nil }
        return isRTL ? horizontal > 0 : horizontal < 0
    }

    /// Avoids trapping on finite values outside `Int` bounds in debug breadcrumbs.
    static func debugRounded(_ value: Double) -> String {
        if let rounded = Int(exactly: value.rounded()) {
            return String(rounded)
        }
        return String(describing: value)
    }
}

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

struct ReaderSidebarPager<Library: View, Contents: View>: View {
    @Bindable var coordinator: ReaderSidebarPageCoordinator
    let library: (Bool) -> Library
    let contents: (Bool) -> Contents
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(iOSNavigationManager.self) private var navigationManager
    @Environment(\.readerSidebarUsesSharedSearch) private var usesSharedSearch

    var body: some View {
        // One native navigation owner contains the original page bodies.
        // The scoped directional recognizer below arbitrates body paging:
        // horizontal drags select once; vertical drags stay with the real list.
        TabView(selection: $coordinator.page) {
            if layoutDirection == .rightToLeft {
                contentsPage
                libraryPage
            } else {
                libraryPage
                contentsPage
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .environment(\.layoutDirection, .leftToRight)
        .animation(reduceMotion ? nil : .snappy, value: coordinator.page)
        .environment(\.readerSidebarOwnsToggle, true)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reader-sidebar-pager")
        .modifier(ReaderSidebarSearchSurface(isEnabled: usesSharedSearch,
            query: activeSearchQuery, contentsQuery: $coordinator.contentsQuery,
            prompt: coordinator.page == .library ? String(localized: "Search Library") : String(localized: "Search Contents"),
            title: coordinator.page == .library ? String(localized: "Library") : String(localized: "Table of Contents"),
            subtitle: coordinator.page == .contents ? activeContentsBookTitle : ""))
        .onChange(of: activeContentsReaderID) { _, _ in coordinator.contentsQuery = "" }
        .background { splitConfigurationBackground }
        .modifier(ReaderSidebarPageDiagnosticObserver(page: coordinator.page))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 0) {
                pageButton(.library, title: "ספרייה")
                pageButton(.contents, title: "תוכן עניינים")
            }
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
            .simultaneousGesture(sidebarSwipe)
            .environment(\.layoutDirection, layoutDirection)
        }
    }

    private var libraryPage: some View {
        library(coordinator.page == .library)
            .environment(\.layoutDirection, layoutDirection)
            .accessibilityHidden(coordinator.page != .library)
            .tag(ReaderSidebarPageCoordinator.Page.library)
    }

    private var contentsPage: some View {
        contents(coordinator.page == .contents)
            .id(activeContentsReaderID)
            .environment(\.layoutDirection, layoutDirection)
            .accessibilityHidden(coordinator.page != .contents)
            .tag(ReaderSidebarPageCoordinator.Page.contents)
    }

    private var activeContentsReaderID: UUID? {
        navigationManager.openTabs.first(where: { $0.id == navigationManager.activeTabId })?.id
            ?? navigationManager.openTabs.first?.id
    }

    private var activeContentsBookTitle: String {
        navigationManager.openTabs.first(where: { $0.id == activeContentsReaderID })?.book.book ?? ""
    }

    private var activeSearchQuery: Binding<String> {
        // Retain the page owning this binding, so a late old native callback
        // cannot write the other page's query after a page transition.
        let page = coordinator.page, readerID = activeContentsReaderID
        return Binding(get: {
            page == .library ? navigationManager.libraryViewModel.searchQuery : coordinator.contentsQuery
        }, set: { value in
            if page == .library { navigationManager.libraryViewModel.searchQuery = value }
            else if activeContentsReaderID == readerID { coordinator.contentsQuery = value }
        })
    }

    private var sidebarSwipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                selectPage(horizontal: Double(value.translation.width), vertical: Double(value.translation.height))
            }
    }

    private var splitConfigurationBackground: some View {
        #if DEBUG
        ReaderSidebarSplitConfiguration(onBodySwipe: selectPage, onDiagnostic: ReaderSidebarDebugLog.log)
        #else
        ReaderSidebarSplitConfiguration(onBodySwipe: selectPage)
        #endif
    }

    private func selectPage(horizontal: Double, vertical: Double) {
        let isRTL = layoutDirection == .rightToLeft
        let selectsContents = ReaderSidebarPolicy.swipeSelectsContents(
            horizontal: horizontal, vertical: vertical, isRTL: isRTL
        )
        #if DEBUG
        let current = coordinator.page == .library ? "library" : "contents"
        let target = selectsContents.map { $0 ? "contents" : "library" } ?? "nil"
        let dx = ReaderSidebarPolicy.debugRounded(horizontal)
        let dy = ReaderSidebarPolicy.debugRounded(vertical)
        ReaderSidebarDebugLog.log("swipeDecision page=\(current) isRTL=\(isRTL) dx=\(dx) dy=\(dy) target=\(target)")
        #endif
        guard let selectsContents else { return }
        withAnimation(reduceMotion ? nil : .snappy) {
            coordinator.page = selectsContents ? .contents : .library
        }
    }

    private func pageButton(_ page: ReaderSidebarPageCoordinator.Page, title: String) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .snappy) { coordinator.page = page }
        } label: {
            Image(systemName: coordinator.page == page ? "circle.fill" : "circle")
                .font(.system(size: 8))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(coordinator.page == page ? .isSelected : [])
        .accessibilityIdentifier("reader-sidebar-page-\(page.rawValue)")
    }
}

private enum ReaderSidebarDebugLog {
    #if DEBUG
    @MainActor static func log(_ message: String) {
        OtzariaFileLogger.shared.log("[ReaderSidebarPager] \(message)")
    }
    #endif
}

private struct ReaderSidebarPageDiagnosticObserver: ViewModifier {
    let page: ReaderSidebarPageCoordinator.Page

    func body(content: Content) -> some View {
        #if DEBUG
        content.onChange(of: page) { oldPage, newPage in
            let from = oldPage == .library ? "library" : "contents"
            let to = newPage == .library ? "library" : "contents"
            ReaderSidebarDebugLog.log("pageChanged from=\(from) to=\(to)")
        }
        #else
        content
        #endif
    }
}

// BEGIN SELF-CONTAINED SIDEBAR SEARCH ADAPTERS
private struct ReaderSidebarUsesSharedSearchKey: EnvironmentKey {
    static let defaultValue = false
}

private struct ReaderSidebarContentsQueryKey: EnvironmentKey {
    static var defaultValue: Binding<String>? { nil }
}

extension EnvironmentValues {
    /// Enabled only by the reviewed original sidebar composition hook. Other
    /// Library/TOC presentations retain their existing independent search.
    var readerSidebarUsesSharedSearch: Bool {
        get { self[ReaderSidebarUsesSharedSearchKey.self] }
        set { self[ReaderSidebarUsesSharedSearchKey.self] = newValue }
    }
    var readerSidebarContentsQuery: Binding<String>? {
        get { self[ReaderSidebarContentsQueryKey.self] }
        set { self[ReaderSidebarContentsQueryKey.self] = newValue }
    }
}

/// One native UISearchController for the original split's paged sidebar.
/// Query storage remains in the original Library model / scene coordinator;
/// this modifier does not implement filtering or create a second text field.
struct ReaderSidebarSearchSurface: ViewModifier {
    let isEnabled: Bool
    @Binding var query: String
    let contentsQuery: Binding<String>
    let prompt: String
    let title: String
    let subtitle: String

    func body(content: Content) -> some View {
        if isEnabled {
            NavigationStack {
                content
                    .environment(\.readerSidebarContentsQuery, contentsQuery)
                    .navigationTitle(Text(title))
                    .navigationSubtitle(subtitle)
                    .navigationBarTitleDisplayMode(.inline)
                    .searchable(text: $query,
                                placement: .navigationBarDrawer(displayMode: .always),
                                prompt: Text(prompt))
            }
        } else {
            content
        }
    }
}

/// Bridge the TOC's original private filter state without replacing its list,
/// nodes, matching algorithm or standalone-sheet behavior. Sidebar context is
/// fixed for this view's lifetime; changing pages does not replace its content.
struct ReaderSidebarContentsSearch: ViewModifier {
    @Binding var text: String
    @Environment(\.readerSidebarContentsQuery) private var sidebarQuery

    func body(content: Content) -> some View {
        if let sidebarQuery {
            content
                .onChange(of: sidebarQuery.wrappedValue, initial: true) { _, value in
                    if text != value { text = value }
                }
                .onChange(of: text) { _, value in
                    if sidebarQuery.wrappedValue != value { sidebarQuery.wrappedValue = value }
                }
        } else {
            content.searchable(text: $text, prompt: String(localized: "Search Contents"))
        }
    }
}

/// Native semantic title/subtitle avoids the custom principal title's duplicate
/// accessibility representation observed in the real iOS27 navigation bar.
@available(iOS 26.0, *)
struct ReaderContentsNavigationTitle: ViewModifier {
    let bookTitle: String?
    @Environment(\.readerSidebarUsesSharedSearch) private var usesSharedSearch

    func body(content: Content) -> some View {
        if usesSharedSearch {
            // The single sidebar navigation owner projects the active title.
            // Hidden pager children must not compete for its navigation item.
            content
        } else {
            content
        }
    }
}
// END SELF-CONTAINED SIDEBAR SEARCH ADAPTERS

/// Configure the public ancestor of the original NavigationSplitView. This
/// attachment creates no split, navigation controller, reader or toolbar item.
private struct ReaderSidebarSplitConfiguration: UIViewControllerRepresentable {
    let onBodySwipe: @MainActor (Double, Double) -> Void
    #if DEBUG
    var onDiagnostic: (@MainActor (String) -> Void)? = nil
    #endif

    func makeUIViewController(context: Context) -> ReaderSidebarSplitConfigurationController {
        let controller = ReaderSidebarSplitConfigurationController()
        controller.onBodySwipe = onBodySwipe
        #if DEBUG
        controller.onDiagnostic = onDiagnostic
        #endif
        return controller
    }

    func updateUIViewController(_ controller: ReaderSidebarSplitConfigurationController, context: Context) {
        controller.onBodySwipe = onBodySwipe
        #if DEBUG
        controller.onDiagnostic = onDiagnostic
        #endif
        controller.configureExistingSplit()
    }

    static func dismantleUIViewController(_ controller: ReaderSidebarSplitConfigurationController, coordinator: ()) {
        controller.restoreConfiguration()
    }
}

private final class ReaderSidebarSplitConfigurationController: UIViewController, UIGestureRecognizerDelegate {
    var onBodySwipe: (@MainActor (Double, Double) -> Void)?
    #if DEBUG
    var onDiagnostic: (@MainActor (String) -> Void)?
    #endif
    private weak var bodySwipeHost: UIView?
    private lazy var bodyPan = UIPanGestureRecognizer(target: self, action: #selector(bodyPanEnded(_:)))
    private weak var configuredSplit: UISplitViewController?
    private var originalBehavior: UISplitViewController.SplitBehavior?
    private var originalButtonVisibility: UISplitViewController.DisplayModeButtonVisibility?

    override func loadView() {
        view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        configureExistingSplit()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        configureExistingSplit()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        configureExistingSplit()
    }

    func configureExistingSplit() {
        guard let split = splitViewController, split.style == .doubleColumn else { return }
        if configuredSplit !== split {
            restoreConfiguration()
            configuredSplit = split
            originalBehavior = split.preferredSplitBehavior
            originalButtonVisibility = split.displayModeButtonVisibility
        }
        #if DEBUG
        var attachedHost: UIView?
        #endif
        if let primary = split.viewController(for: .primary)?.viewIfLoaded,
           view.isDescendant(of: primary), bodySwipeHost !== primary {
            bodySwipeHost?.removeGestureRecognizer(bodyPan)
            bodyPan.maximumNumberOfTouches = 1
            bodyPan.delegate = self
            primary.addGestureRecognizer(bodyPan)
            bodySwipeHost = primary
            #if DEBUG
            attachedHost = primary
            #endif
        }

        let availableWidth = split.view.safeAreaLayoutGuide.layoutFrame.width
        let primaryWidth = split.viewController(for: .primary)?.viewIfLoaded?.bounds.width ?? 0
        // A collapsed primary can occupy the whole window. It is not the
        // sidebar's width after expansion; use the native primary constraints.
        let constrainedWidth = max(split.minimumPrimaryColumnWidth, min(320, split.maximumPrimaryColumnWidth))
        let measuredWidth = !split.isCollapsed && primaryWidth > 0 && primaryWidth < availableWidth
            ? primaryWidth : constrainedWidth
        let sidebarWidth = max(constrainedWidth, measuredWidth)
        let readerWidth = UIFontMetrics.default.scaledValue(for: 430, compatibleWith: split.traitCollection)
        let tiles = ReaderSidebarPolicy.canTile(
            availableWidth: Double(availableWidth),
            sidebarWidth: Double(sidebarWidth),
            isCompact: split.traitCollection.horizontalSizeClass == .compact,
            readerWidth: Double(readerWidth)
        )
        #if DEBUG
        if let attachedHost {
            onDiagnostic?("attach host=\(Self.debugTypeName(attachedHost)) viewBounds=\(Self.debugRounded(view.bounds.width))x\(Self.debugRounded(view.bounds.height)) hostBounds=\(Self.debugRounded(attachedHost.bounds.width))x\(Self.debugRounded(attachedHost.bounds.height)) collapsed=\(split.isCollapsed) tiles=\(tiles)")
        }
        #endif
        let behavior = tiles ? UISplitViewController.SplitBehavior.tile : (originalBehavior ?? .automatic)
        if split.preferredSplitBehavior != behavior {
            split.preferredSplitBehavior = behavior
        }
        // On 27 the original reader intentionally supplies no manual fallback.
        // Explicitly request the existing system button; do not manufacture a
        // second toolbar item or infer its presence from the OS version alone.
        if #available(iOS 27.0, *) {
            if split.displayModeButtonVisibility != .always {
                split.displayModeButtonVisibility = .always
            }
        }
    }

    func restoreConfiguration() {
        #if DEBUG
        if bodySwipeHost != nil || configuredSplit != nil {
            onDiagnostic?("restore hadHost=\(bodySwipeHost != nil) hadSplit=\(configuredSplit != nil)")
        }
        #endif
        bodySwipeHost?.removeGestureRecognizer(bodyPan)
        bodySwipeHost = nil
        if let split = configuredSplit {
            if let originalBehavior { split.preferredSplitBehavior = originalBehavior }
            if let originalButtonVisibility { split.displayModeButtonVisibility = originalButtonVisibility }
        }
        configuredSplit = nil
        originalBehavior = nil
        originalButtonVisibility = nil
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer === bodyPan else { return false }
        guard view.window != nil else {
            #if DEBUG
            onDiagnostic?("shouldReceive eligible=false hasWindow=false")
            #endif
            return false
        }
        // Exclude native navigation/search controls, page dots and the reader.
        let location = touch.location(in: view)
        let inBounds = view.bounds.contains(location)
        let eligible = !view.isHidden && view.alpha > 0 && inBounds
        #if DEBUG
        onDiagnostic?("shouldReceive eligible=\(eligible) hasWindow=true hidden=\(view.isHidden) alphaPositive=\(view.alpha > 0) inBounds=\(inBounds) loc=\(Self.debugRounded(location.x)),\(Self.debugRounded(location.y)) bounds=\(Self.debugRounded(view.bounds.width))x\(Self.debugRounded(view.bounds.height)) touchView=\(Self.debugTypeName(touch.view))")
        #endif
        return eligible
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === bodyPan else { return false }
        let velocity = bodyPan.velocity(in: view)
        let allowed = velocity.x.isFinite && velocity.y.isFinite && abs(velocity.x) > abs(velocity.y) * 1.25
        #if DEBUG
        let dir = !velocity.x.isFinite ? "nonFinite" : (velocity.x > 0 ? "right" : (velocity.x < 0 ? "left" : "zero"))
        onDiagnostic?("shouldBegin allowed=\(allowed) vx=\(Self.debugRounded(velocity.x)) vy=\(Self.debugRounded(velocity.y)) dir=\(dir)")
        #endif
        return allowed
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === bodyPan, otherGestureRecognizer is UIPanGestureRecognizer,
              let host = bodySwipeHost, let otherView = otherGestureRecognizer.view else { return false }
        // Dynamic failure priority, rather than simultaneous recognition:
        // the page/list pan waits for this horizontal-only recognizer to fail.
        // No scroll view is disabled and no permanent dependency is installed.
        let inHost = otherView === host || otherView.isDescendant(of: host)
        #if DEBUG
        if otherGestureRecognizer !== bodyPan {
            onDiagnostic?("requireFail result=\(inHost) other=\(Self.debugTypeName(otherGestureRecognizer)) otherView=\(Self.debugTypeName(otherView)) inHost=\(inHost) enabled=\(otherGestureRecognizer.isEnabled) state=\(Self.debugStateName(otherGestureRecognizer.state))")
        }
        #endif
        return inHost
    }

    @objc private func bodyPanEnded(_ sender: UIPanGestureRecognizer) {
        #if DEBUG
        if sender.state != .changed {
            let translation = sender.translation(in: view)
            onDiagnostic?("panState state=\(Self.debugStateName(sender.state)) hasWindow=\(view.window != nil) dx=\(Self.debugRounded(translation.x)) dy=\(Self.debugRounded(translation.y))")
        }
        #endif
        guard sender.state == .ended, view.window != nil else { return }
        let translation = sender.translation(in: view)
        onBodySwipe?(Double(translation.x), Double(translation.y))
    }

    #if DEBUG
    private static func debugRounded(_ value: CGFloat) -> String {
        ReaderSidebarPolicy.debugRounded(Double(value))
    }

    private static func debugTypeName(_ object: Any?) -> String {
        object.map { String(describing: type(of: $0)) } ?? "nil"
    }

    private static func debugStateName(_ state: UIGestureRecognizer.State) -> String {
        switch state {
        case .possible: "possible"
        case .began: "began"
        case .changed: "changed"
        case .ended: "ended"
        case .cancelled: "cancelled"
        case .failed: "failed"
        @unknown default: "unknown(\(state.rawValue))"
        }
    }
    #endif
}
#endif
