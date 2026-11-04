import SwiftUI

struct ReaderToolbarActionAdapter: View {
    @Environment(\.layoutDirection) private var layoutDirection
    let sidebarIsOpen: Bool
    let onToggleSidebar: () -> Void
    var body: some View {
        GlassButtonGroup {
            Button(action: onToggleSidebar) {
                Image(systemName: layoutDirection == .rightToLeft ? "sidebar.right" : "sidebar.left")
                    .font(.system(size: 19, weight: .regular))
                    .frame(width: 39, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(sidebarIsOpen ? "הסתר סרגל צד" : "הצג סרגל צד")
            .accessibilityIdentifier("reader-host-sidebar-toggle")
        }
    }
}
