import SwiftUI

enum ChavrusaTextReaderUI {
    static var isEnabled: Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "ChavrusaTextFaithfulReaderUIEnabled") != nil else { return true }
        return defaults.bool(forKey: "ChavrusaTextFaithfulReaderUIEnabled")
    }
}

@MainActor @Observable
final class ReaderSidebarPageCoordinator {
    enum Page: Int, CaseIterable, Identifiable { case library, contents; var id: Int { rawValue } }
    var page: Page = .library
    var requestsLibrary = false
    func showContents() { page = .contents }
    func showLibrary() { page = .library; requestsLibrary.toggle() }
}

private struct ReaderSidebarCoordinatorKey: EnvironmentKey {
    static let defaultValue: ReaderSidebarPageCoordinator? = nil
}

extension EnvironmentValues {
    var chavrusaReaderSidebar: ReaderSidebarPageCoordinator? {
        get { self[ReaderSidebarCoordinatorKey.self] }
        set { self[ReaderSidebarCoordinatorKey.self] = newValue }
    }
}
