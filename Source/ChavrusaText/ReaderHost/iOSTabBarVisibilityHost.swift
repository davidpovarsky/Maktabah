#if os(iOS)
import SwiftUI

/// ChavrusaText fork-owned host-level Tab Bar visibility policy.
/// Enforces iPad tab bar persistence across reading modes while respecting iPhone fullscreen reading.
/// Note: Marked READY_FOR_HOOK / NOT_IN_APP until integrated into host and tested on hardware.
struct TabBarVisibilityHostModifier: ViewModifier {
    let isIpad: Bool
    let isReading: Bool

    init(isIpad: Bool = MaktabahApp.isIpad, isReading: Bool = false) {
        self.isIpad = isIpad
        self.isReading = isReading
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if isIpad {
            // On iPad, Tab Bar MUST remain visible across reader, TOC, inspector, and sheets (BUG-01)
            content.toolbarVisibility(.visible, for: .tabBar)
        } else {
            // On iPhone, Tab Bar is hidden only when actively reading, visible otherwise
            content.toolbarVisibility(isReading ? .hidden : .visible, for: .tabBar)
        }
    }
}

extension View {
    /// Applies fork-owned Tab Bar visibility host policy.
    func chavrusaTextTabBarHostPolicy(isReading: Bool = false) -> some View {
        modifier(TabBarVisibilityHostModifier(isReading: isReading))
    }
}
#endif
