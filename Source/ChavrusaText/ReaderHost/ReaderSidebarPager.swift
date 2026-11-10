/// Shared by the actual sidebar host and its portable, non-UI tests.
enum ReaderSidebarPolicy {
    static let minimumReaderWidth = 430.0
    static let minimumSidebarWidth = 220.0
    static let dividerAllowance = 1.0

    static func canTile(availableWidth: Double, sidebarWidth: Double, isCompact: Bool, readerWidth: Double = 430) -> Bool {
        !isCompact && availableWidth.isFinite && sidebarWidth.isFinite && readerWidth.isFinite
            && availableWidth >= max(minimumSidebarWidth, sidebarWidth) + max(minimumReaderWidth, readerWidth) + dividerAllowance
    }

    /// nil leaves the active page alone. Only the page-control strip owns this
    /// gesture; reading/list scrolling and the native screen-edge swipe do not.
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

    var body: some View {
        // Each original page owns its NavigationStack. An unselected page must
        // not remain in the hierarchy publishing search/principal toolbar items.
        Group {
            if coordinator.page == .library {
                library(true)
            } else {
                contents(true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reader-sidebar-pager")
        .background { ReaderSidebarSplitConfiguration() }
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

    private var sidebarSwipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard let selectsContents = ReaderSidebarPolicy.swipeSelectsContents(
                    horizontal: Double(value.translation.width),
                    vertical: Double(value.translation.height),
                    isRTL: layoutDirection == .rightToLeft
                ) else { return }
                withAnimation(.snappy) {
                    coordinator.page = selectsContents ? .contents : .library
                }
            }
    }

    private func pageButton(_ page: ReaderSidebarPageCoordinator.Page, title: String) -> some View {
        Button {
            withAnimation(.snappy) { coordinator.page = page }
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

/// Configure the public ancestor of the original NavigationSplitView. This
/// attachment creates no split, navigation controller, reader or toolbar item.
private struct ReaderSidebarSplitConfiguration: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ReaderSidebarSplitConfigurationController {
        ReaderSidebarSplitConfigurationController()
    }

    func updateUIViewController(_ controller: ReaderSidebarSplitConfigurationController, context: Context) {
        controller.configureExistingSplit()
    }

    static func dismantleUIViewController(_ controller: ReaderSidebarSplitConfigurationController, coordinator: ()) {
        controller.restoreConfiguration()
    }
}

private final class ReaderSidebarSplitConfigurationController: UIViewController {
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
        if let split = configuredSplit {
            if let originalBehavior { split.preferredSplitBehavior = originalBehavior }
            if let originalButtonVisibility { split.displayModeButtonVisibility = originalButtonVisibility }
        }
        configuredSplit = nil
        originalBehavior = nil
        originalButtonVisibility = nil
    }
}
#endif
