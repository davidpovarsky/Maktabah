
import Foundation
import Observation
struct BooksData { let id: Int }
@MainActor final class ReaderViewModel {}
@MainActor final class SearchViewModel {}
@MainActor final class UnifiedSearchSessionController {
    var searchViewModel: SearchViewModel?
}
@MainActor protocol BackendSwitchParticipant: AnyObject {}
@MainActor final class BackendCoordinator {
    static let shared = BackendCoordinator()
    var registered = Set<ObjectIdentifier>()
    func addSwitchParticipant(_ owner: iOSNavigationManager) {
        registered.insert(ObjectIdentifier(owner))
    }
}
@MainActor enum StudyWorkspaceNavigationAdapter {
    static var events: [String] = []
    static func nativeMappingOwnerInitialized(_ owner: iOSNavigationManager) {
        events.append(BackendCoordinator.shared.registered.contains(ObjectIdentifier(owner))
            ? "init-after-registration" : "wrong-init-order")
    }
    static func nativeMappingTabsWillChange(_ owner: iOSNavigationManager,
        to tabs: [iOSNavigationManager.ReaderTab]) {
        events.append("tabs-before:\(owner.openTabs.count)->\(tabs.count)")
    }
    static func nativeMappingSelectionWillChange(_ owner: iOSNavigationManager, to id: UUID?) {
        events.append("selection-before:\(owner.activeTabId == nil ? "nil" : "set")->\(id == nil ? "nil" : "set")")
    }
    static func nativeMappingDidChange(_ owner: iOSNavigationManager) {
        events.append("after:\(owner.openTabs.count):\(owner.activeTabId == nil ? "nil" : "set")")
    }
    static func nativeMappingOwnerWillDeinitialize(_ owner: iOSNavigationManager) {
        events.append("owner-deinit")
    }
}

@MainActor
@Observable
class iOSNavigationManager: BackendSwitchParticipant {
    struct ReaderTab: Identifiable, Equatable {
        let id: UUID
        let book: BooksData
        var initialContentId: Int?
        var viewModel: ReaderViewModel

        static func == (lhs: ReaderTab, rhs: ReaderTab) -> Bool {
            lhs.id == rhs.id
        }
    }
    var openTabs: [ReaderTab] = [] {
        willSet { StudyWorkspaceNavigationAdapter.nativeMappingTabsWillChange(self, to: newValue) }
        didSet { StudyWorkspaceNavigationAdapter.nativeMappingDidChange(self) }
    }
    var activeTabId: UUID? {
        willSet { StudyWorkspaceNavigationAdapter.nativeMappingSelectionWillChange(self, to: newValue) }
        didSet { StudyWorkspaceNavigationAdapter.nativeMappingDidChange(self) }
    }
    init() {
        unifiedSearchSession.searchViewModel = searchViewModel
        setupObservers()
        BackendCoordinator.shared.addSwitchParticipant(self)
        StudyWorkspaceNavigationAdapter.nativeMappingOwnerInitialized(self)
    }
    isolated deinit {
        StudyWorkspaceNavigationAdapter.nativeMappingOwnerWillDeinitialize(self)
        NotificationCenter.default.removeObserver(self)
    }
    var unifiedSearchSession = UnifiedSearchSessionController()
    var searchViewModel = SearchViewModel()
    private func setupObservers() {}
}
