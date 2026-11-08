#if os(iOS)
import SwiftUI

struct iOSTabBarVisibilityPolicy: ViewModifier {
    let hiddenOnPhone: Bool
    @Environment(\.chavrusaReaderNavigationChromeVisible) private var readerChromeVisible

    @ViewBuilder
    func body(content: Content) -> some View {
        if MaktabahApp.isIpad {
            if let readerChromeVisible {
                content.toolbarVisibility(readerChromeVisible ? .automatic : .hidden, for: .tabBar)
            } else {
                content
            }
        } else {
            content.toolbarVisibility(hiddenOnPhone ? .hidden : .visible, for: .tabBar)
        }
    }
}

extension View {
    func platformTabBarVisibility(hiddenOnPhone: Bool) -> some View {
        modifier(iOSTabBarVisibilityPolicy(hiddenOnPhone: hiddenOnPhone))
    }
}
#endif
