import SwiftUI
import UIKit

struct ReaderSidebarPager<Library: View, Contents: View>: View {
    @Bindable var coordinator: ReaderSidebarPageCoordinator
    let library: (Bool) -> Library
    let contents: (Bool) -> Contents

    var body: some View {
        VStack(spacing: 0) {
            NativeReaderSidebarPager(selection: $coordinator.page, library: library, contents: contents)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("reader-sidebar-pager")
            HStack(spacing: 0) {
                pageButton(.library, title: "ספרייה")
                pageButton(.contents, title: "תוכן עניינים")
            }
            .frame(maxWidth: .infinity)
            .background(.bar)
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

/// Each original NavigationStack has its own hosting boundary. Keeping both
/// stacks in one SwiftUI ZStack also merges the hidden page's toolbar/search
/// preferences into the visible one. UIKit retains both pages without sharing
/// their SwiftUI preference graphs or recreating their library/TOC viewports.
private struct NativeReaderSidebarPager<Library: View, Contents: View>: UIViewControllerRepresentable {
    typealias Page = ReaderSidebarPageCoordinator.Page
    @Binding var selection: Page
    let library: (Bool) -> Library
    let contents: (Bool) -> Contents

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let controller = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        controller.view.backgroundColor = .clear
        // Page ordering is mapped explicitly below; hosted content keeps the
        // complete SwiftUI environment, including its own RTL direction.
        controller.view.semanticContentAttribute = .forceLeftToRight
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        context.coordinator.update(parent: self, environment: context.environment)
        controller.setViewControllers([context.coordinator.host(for: selection)], direction: .forward, animated: false)
        return controller
    }

    func updateUIViewController(_ controller: UIPageViewController, context: Context) {
        let coordinator = context.coordinator
        coordinator.update(parent: self, environment: context.environment)
        let target = coordinator.host(for: selection)
        guard !coordinator.isTransitioning, controller.viewControllers?.first !== target else { return }
        let old = controller.viewControllers?.first.flatMap { coordinator.visualIndex(of: $0) } ?? 0
        let next = coordinator.visualIndex(of: target) ?? 0
        controller.setViewControllers([target], direction: next > old ? .forward : .reverse, animated: false)
    }

    @MainActor final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: NativeReaderSidebarPager
        let libraryHost = UIHostingController(rootView: AnyView(EmptyView()))
        let contentsHost = UIHostingController(rootView: AnyView(EmptyView()))
        var isTransitioning = false
        private var isRTL = false

        init(parent: NativeReaderSidebarPager) {
            self.parent = parent
            super.init()
            libraryHost.view.backgroundColor = .clear
            contentsHost.view.backgroundColor = .clear
        }

        func update(parent: NativeReaderSidebarPager, environment: EnvironmentValues) {
            self.parent = parent
            isRTL = environment.layoutDirection == .rightToLeft
            // UIKit owns which page is visible. Each independent stack keeps
            // its normal bar geometry while offscreen, preserving its viewport.
            libraryHost.rootView = AnyView(parent.library(true).environment(\.self, environment))
            contentsHost.rootView = AnyView(parent.contents(true).environment(\.self, environment))
        }

        func host(for page: Page) -> UIViewController { page == .library ? libraryHost : contentsHost }
        private var visualOrder: [UIViewController] {
            isRTL ? [contentsHost, libraryHost] : [libraryHost, contentsHost]
        }
        func visualIndex(of controller: UIViewController) -> Int? { visualOrder.firstIndex { $0 === controller } }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let index = visualIndex(of: viewController), index > 0 else { return nil }
            return visualOrder[index - 1]
        }
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let index = visualIndex(of: viewController), index + 1 < visualOrder.count else { return nil }
            return visualOrder[index + 1]
        }
        func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
            isTransitioning = true
        }
        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            isTransitioning = false
            guard completed, let visible = pageViewController.viewControllers?.first else { return }
            parent.selection = visible === libraryHost ? .library : .contents
        }
    }
}
