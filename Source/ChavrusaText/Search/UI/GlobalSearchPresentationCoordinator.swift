import SwiftUI

/// Presentation only. Query, selected books, options and history stay in their existing owners.
private struct GlobalSearchBookChooserKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    var globalSearchBookChooser: (() -> Void)? {
        get { self[GlobalSearchBookChooserKey.self] }
        set { self[GlobalSearchBookChooserKey.self] = newValue }
    }
}

@Observable @MainActor
final class GlobalSearchPresentationCoordinator {
    var columnVisibility: NavigationSplitViewVisibility = .all

    func showBooks() {
        columnVisibility = .all
    }
}
