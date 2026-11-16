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
        // Retain the original native page container and NavigationStacks.
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
            prompt: coordinator.page == .library ? String(localized: "Search Library") : String(localized: "Search Contents")))
        .onChange(of: activeContentsReaderID) { _, _ in coordinator.contentsQuery = "" }
        .background { ReaderSidebarSplitConfiguration(onBodySwipe: selectPage) }
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

    private func selectPage(horizontal: Double, vertical: Double) {
        guard let selectsContents = ReaderSidebarPolicy.swipeSelectsContents(
            horizontal: horizontal, vertical: vertical, isRTL: layoutDirection == .rightToLeft
        ) else { return }
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

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .environment(\.readerSidebarContentsQuery, contentsQuery)
                .searchable(text: $query,
                            placement: .navigationBarDrawer(displayMode: .always),
                            prompt: Text(prompt))
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
            content
                .navigationTitle(Text(String(localized: "Table of Contents")))
                .navigationSubtitle(bookTitle ?? "")
                .navigationBarTitleDisplayMode(.inline)
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
    func makeUIViewController(context: Context) -> ReaderSidebarSplitConfigurationController {
        let controller = ReaderSidebarSplitConfigurationController()
        controller.onBodySwipe = onBodySwipe
        return controller
    }

    func updateUIViewController(_ controller: ReaderSidebarSplitConfigurationController, context: Context) {
        controller.onBodySwipe = onBodySwipe
        controller.configureExistingSplit()
    }

    static func dismantleUIViewController(_ controller: ReaderSidebarSplitConfigurationController, coordinator: ()) {
        controller.restoreConfiguration()
    }
}

private final class ReaderSidebarSplitConfigurationController: UIViewController, UIGestureRecognizerDelegate {
    var onBodySwipe: (@MainActor (Double, Double) -> Void)?
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
        if let primary = split.viewController(for: .primary)?.viewIfLoaded,
           view.isDescendant(of: primary), bodySwipeHost !== primary {
            bodySwipeHost?.removeGestureRecognizer(bodyPan)
            bodyPan.maximumNumberOfTouches = 1
            bodyPan.delegate = self
            primary.addGestureRecognizer(bodyPan)
            bodySwipeHost = primary
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
        guard gestureRecognizer === bodyPan, view.window != nil else { return false }
        // Exclude native navigation/search controls, page dots and the reader.
        return !view.isHidden && view.alpha > 0 && view.bounds.contains(touch.location(in: view))
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === bodyPan else { return false }
        let velocity = bodyPan.velocity(in: view)
        return velocity.x.isFinite && velocity.y.isFinite && abs(velocity.x) > abs(velocity.y) * 1.25
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === bodyPan, otherGestureRecognizer is UIPanGestureRecognizer,
              let host = bodySwipeHost, let otherView = otherGestureRecognizer.view else { return false }
        // Dynamic failure priority, rather than simultaneous recognition:
        // the page/list pan waits for this horizontal-only recognizer to fail.
        // No scroll view is disabled and no permanent dependency is installed.
        return otherView === host || otherView.isDescendant(of: host)
    }

    @objc private func bodyPanEnded(_ sender: UIPanGestureRecognizer) {
        guard sender.state == .ended, view.window != nil else { return }
        let translation = sender.translation(in: view)
        onBodySwipe?(Double(translation.x), Double(translation.y))
    }
}
#endif
