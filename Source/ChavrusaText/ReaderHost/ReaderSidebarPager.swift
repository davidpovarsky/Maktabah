import SwiftUI

struct ReaderSidebarPager<Library: View, Contents: View>: View {
    @Bindable var coordinator: ReaderSidebarPageCoordinator
    let library: Library
    let contents: Contents

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $coordinator.page) {
                library.tag(ReaderSidebarPageCoordinator.Page.library)
                contents.tag(ReaderSidebarPageCoordinator.Page.contents)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
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
