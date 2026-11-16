/// Shared by the actual sidebar host and its portable, non-UI tests.
enum ReaderSidebarPolicy {
    static let minimumReaderWidth = 430.0
    static let minimumSidebarWidth = 220.0
    static let dividerAllowance = 1.0

    static func canTile(availableWidth: Double, sidebarWidth: Double, isCompact: Bool, readerWidth: Double = 430) -> Bool {
        !isCompact && availableWidth.isFinite && sidebarWidth.isFinite && readerWidth.isFinite
            && availableWidth >= max(minimumSidebarWidth, sidebarWidth) + max(minimumReaderWidth, readerWidth) + dividerAllowance
    }

    /// nil leaves the active page alone, including vertical body scrolling.
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

    var body: some View {
        // Each original NavigationStack keeps its own native search/toolbar.
        // A native page controller with no data source never writes selection
        // back over the scoped gesture; it also avoids nesting a tab bar.
        ReaderSidebarPages(showsContents: coordinator.page == .contents,
            library: library(coordinator.page == .library)
                .accessibilityHidden(coordinator.page != .library),
            contents: contents(coordinator.page == .contents)
                // Node IDs are book-local. Recreate only the TOC's local
                // search/expansion/scroll state when its reader changes.
                .id(activeContentsReaderID)
                .accessibilityHidden(coordinator.page != .contents))
        .animation(reduceMotion ? nil : .snappy, value: coordinator.page)
        .environment(\.readerSidebarOwnsToggle, true)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reader-sidebar-pager")
        .background { ReaderSidebarSplitConfiguration(onBodySwipe: selectPage) }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 0) {
                pageButton(.library, title: "ספרייה")
                pageButton(.contents, title: "תוכן עניינים")
            }
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
            .simultaneousGesture(sidebarSwipe)
        }
    }

    private var activeContentsReaderID: UUID? {
        navigationManager.openTabs.first(where: { $0.id == navigationManager.activeTabId })?.id
            ?? navigationManager.openTabs.first?.id
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

/// Retain the original SwiftUI NavigationStacks in distinct native hosts.
/// SwiftUI's page-style TabView can report an outgoing selection during its
/// transition; a nested tab-bar TabView consumes the original split toolbar.
/// UIPageViewController's public programmatic API needs neither competing
/// callbacks nor changes to any native List/TOC scroll recognizer.
private struct ReaderSidebarPages<Library: View, Contents: View>: UIViewControllerRepresentable {
    let showsContents: Bool
    let library: Library
    let contents: Contents

    @MainActor final class Coordinator {
        let library = UIHostingController(rootView: AnyView(EmptyView()))
        let contents = UIHostingController(rootView: AnyView(EmptyView()))
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let controller = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        // Public contract: nil disables gesture-driven page navigation.
        // https://developer.apple.com/documentation/uikit/uipageviewcontroller/datasource
        controller.dataSource = nil
        controller.view.backgroundColor = .clear
        updateUIViewController(controller, context: context)
        return controller
    }

    func updateUIViewController(_ controller: UIPageViewController, context: Context) {
        let owner = context.coordinator
        // Forward the existing scene's environment, including the actual
        // navigation manager, workspace, direction, theme and Dynamic Type.
        owner.library.rootView = AnyView(library.environment(\.self, context.environment))
        owner.contents.rootView = AnyView(contents.environment(\.self, context.environment))
        let target = showsContents ? owner.contents : owner.library
        guard controller.viewControllers?.first !== target else { return }
        let direction: UIPageViewController.NavigationDirection = showsContents ? .forward : .reverse
        controller.setViewControllers([target], direction: direction, animated: false)
    }
}

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
    private weak var configuredSplit: UISplitViewController?
    private weak var bodySwipeHost: UIView?
    private lazy var bodyPan = UIPanGestureRecognizer(target: self, action: #selector(bodyPanEnded(_:)))
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
        configureBodySwipe(in: split)

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

    private func configureBodySwipe(in split: UISplitViewController) {
        guard let host = split.viewController(for: .primary)?.viewIfLoaded,
              view.isDescendant(of: host), bodySwipeHost !== host else { return }
        bodySwipeHost?.removeGestureRecognizer(bodyPan)
        bodyPan.maximumNumberOfTouches = 1
        bodyPan.delegate = self
        host.addGestureRecognizer(bodyPan)
        bodySwipeHost = host
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer === bodyPan, view.window != nil else { return false }
        // The representable is the existing TabView's background. Restrict
        // the ancestor recognizer to that actual body, excluding the reader
        // and surrounding NavigationBar/search controls.
        return !view.isHidden && view.alpha > 0 && view.bounds.contains(touch.location(in: view))
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === bodyPan else { return false }
        let velocity = bodyPan.velocity(in: view)
        // Fail before beginning a vertical pan, leaving native list scrolling
        // and its touch cancellation behavior in charge of that interaction.
        return velocity.x.isFinite && velocity.y.isFinite && abs(velocity.x) > abs(velocity.y) * 1.25
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === bodyPan, let host = bodySwipeHost,
              let otherView = otherGestureRecognizer.view else { return false }
        // Both gestures stay in this primary column. Do not alter the native
        // TabView/collection recognizers or any window/reader recognizer.
        return otherView === host || otherView.isDescendant(of: host)
    }

    @objc private func bodyPanEnded(_ sender: UIPanGestureRecognizer) {
        guard sender.state == .ended, view.window != nil else { return }
        let translation = sender.translation(in: view)
        onBodySwipe?(Double(translation.x), Double(translation.y))
    }
}
#endif
