#if os(iOS)
import SwiftUI

struct iOSTabBarVisibilityPolicy: ViewModifier {
    let hiddenOnPhone: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if MaktabahApp.isIpad {
            content.toolbarVisibility(.visible, for: .tabBar)
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
