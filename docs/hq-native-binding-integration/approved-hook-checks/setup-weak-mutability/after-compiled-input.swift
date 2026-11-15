
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

@main struct ApprovedHookChecks {
    @MainActor static func main() {
        var failures = 0
        func check(_ value: Bool, _ name: String) {
            print("\(value ? "PASS" : "FAIL") \(name)")
            if !value { failures += 1 }
        }
        var owner: iOSNavigationManager? = iOSNavigationManager()
        check(StudyWorkspaceNavigationAdapter.events == ["init-after-registration"],
              "actual initializer publishes coverage after original registration")
        StudyWorkspaceNavigationAdapter.events = []
        let first = iOSNavigationManager.ReaderTab(id: UUID(), book: BooksData(id: 1),
            initialContentId: nil, viewModel: ReaderViewModel())
        owner!.openTabs = [first]
        check(StudyWorkspaceNavigationAdapter.events == ["tabs-before:0->1", "after:1:nil"],
              "actual observed setter brackets real reference publication")
        StudyWorkspaceNavigationAdapter.events = []
        owner!.activeTabId = first.id
        check(StudyWorkspaceNavigationAdapter.events == ["selection-before:nil->set", "after:1:set"],
              "actual selection setter brackets publication")
        StudyWorkspaceNavigationAdapter.events = []
        owner!.openTabs.append(.init(id: UUID(), book: BooksData(id: 2),
            initialContentId: nil, viewModel: ReaderViewModel()))
        check(StudyWorkspaceNavigationAdapter.events == ["tabs-before:1->2", "after:2:set"],
              "actual Observation modify accessor preserves append notifications")
        StudyWorkspaceNavigationAdapter.events = []
        owner!.openTabs[0] = .init(id: first.id, book: BooksData(id: 3),
            initialContentId: nil, viewModel: ReaderViewModel())
        check(StudyWorkspaceNavigationAdapter.events == ["tabs-before:2->2", "after:2:set"]
            && owner!.openTabs[0].book.id == 3,
              "same UUID target replacement still traverses actual hook")
        StudyWorkspaceNavigationAdapter.events = []
        owner!.activeTabId = nil
        check(StudyWorkspaceNavigationAdapter.events == ["selection-before:set->nil", "after:2:nil"],
              "actual nil selection is synchronously published")
        StudyWorkspaceNavigationAdapter.events = []
        weak var weakOwner = owner
        owner = nil
        check(weakOwner == nil && StudyWorkspaceNavigationAdapter.events == ["owner-deinit"],
              "actual isolated deinit retires owner without retaining it")
        print("ASSERTIONS=7 FAILURES=\(failures) PORTABLE_SHELLS_NOT_APPLE_SDK")
        exit(failures == 0 ? 0 : 1)
    }
}
