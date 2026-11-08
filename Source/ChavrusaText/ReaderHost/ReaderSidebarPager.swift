import SwiftUI

struct ReaderSidebarPager<Library: View, Contents: View>: View {
    @Bindable var coordinator: ReaderSidebarPageCoordinator
    let library: (Bool) -> Library
    let contents: (Bool) -> Contents
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        // Keep both original UIKit trees mounted; only change visibility.
        ZStack {
            page(library(coordinator.page == .library), page: .library)
            page(contents(coordinator.page == .contents), page: .contents)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(sidebarSwipe)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reader-sidebar-pager")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 0) {
                pageButton(.library, title: "ספרייה")
                pageButton(.contents, title: "תוכן עניינים")
            }
            .foregroundStyle(.secondary)
        }
    }

    private func page<PageContent: View>(
        _ content: PageContent,
        page: ReaderSidebarPageCoordinator.Page
    ) -> some View {
        content
            .opacity(coordinator.page == page ? 1 : 0)
            .allowsHitTesting(coordinator.page == page)
            .accessibilityHidden(coordinator.page != page)
    }

    private var sidebarSwipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) >= 44, abs(horizontal) > abs(vertical) * 1.25 else { return }
                let movesForward = layoutDirection == .rightToLeft ? horizontal > 0 : horizontal < 0
                withAnimation(.snappy) {
                    coordinator.page = movesForward ? .contents : .library
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
