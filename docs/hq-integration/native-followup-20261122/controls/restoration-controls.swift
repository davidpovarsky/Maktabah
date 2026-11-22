
enum AppMode { case viewer, search, narrator, annotations, history }
struct BackendCapabilities: OptionSet, Sendable {
    let rawValue: Int
    static let search = Self(rawValue: 1)
    static let authors = Self(rawValue: 2)
}
extension String { var localized: String { self } }
@propertyWrapper struct State<Value> {
    var wrappedValue: Value
    init(initialValue: Value) { wrappedValue = initialValue }
}
@MainActor final class UserDefaults {
    static let standard = UserDefaults()
    var storedTab: Int?
    var reads = 0
    func integer(forKey key: String) -> Int {
        precondition(key == "lastSelectedTab")
        reads += 1
        return storedTab ?? 0
    }
}
@MainActor final class BackendCoordinator {
    static let shared = BackendCoordinator()
    var activeCapabilities: BackendCapabilities = [.search, .authors]
}
@MainActor final class iOSNavigationManager {
    static var creations = 0
    var currentMode: AppMode = .viewer
    var modeChanges = 0
    init() { Self.creations += 1 }
    func switchToMode(_ mode: AppMode) { currentMode = mode; modeChanges += 1 }
}

enum iOSTab: Int, CaseIterable, Identifiable {
    case viewer = 0
    case textSearch = 1
    case zayitSearch = 2
    case search = 3
    case author = 4
    case annotations = 5
    case history = 6

    static var allCases: [iOSTab] {
        [.viewer, .search, .author, .annotations, .history]
    }

    var id: Int {
        rawValue
    }

    var canonical: iOSTab {
        switch self {
        case .textSearch, .zayitSearch: .search
        default: self
        }
    }

    var title: String {
        switch self {
        case .viewer: "Library".localized
        case .search, .textSearch, .zayitSearch: "Search".localized
        case .author: "Narrators".localized
        case .annotations: "Annotations".localized
        case .history: "History".localized
        }
    }

    var icon: String {
        switch self {
        case .viewer: "books.vertical.fill"
        case .search, .textSearch, .zayitSearch: "magnifyingglass"
        case .author: "person.text.rectangle.fill"
        case .annotations: "quote.closing"
        case .history: "clock.fill"
        }
    }

    var appMode: AppMode {
        switch self {
        case .viewer: .viewer
        case .search, .textSearch, .zayitSearch: .search
        case .author: .narrator
        case .annotations: .annotations
        case .history: .history
        }
    }

    func isAvailable(for capabilities: BackendCapabilities) -> Bool {
        switch canonical {
        case .search: capabilities.contains(.search)
        case .author: capabilities.contains(.authors)
        default: true
        }
    }

    init(appMode: AppMode) {
        switch appMode {
        case .viewer: self = .viewer
        case .search: self = .search
        case .narrator: self = .author
        case .annotations: self = .annotations
        case .history: self = .history
        }
    }
}
@MainActor struct iOSMainView {
    @State private var navigationManager: iOSNavigationManager
    @State private var selectedTab: iOSTab
    init() {
        let manager = iOSNavigationManager()
        let savedTab = iOSTab(rawValue: UserDefaults.standard.integer(forKey: "lastSelectedTab")) ?? .viewer
        let canonicalTab = savedTab.canonical
        let initialTab = canonicalTab.isAvailable(for: BackendCoordinator.shared.activeCapabilities)
            ? canonicalTab : .viewer
        manager.switchToMode(initialTab.appMode)
        _navigationManager = State(initialValue: manager)
        _selectedTab = State(initialValue: initialTab)
    }
var observedTab: iOSTab { selectedTab }
var observedManager: iOSNavigationManager { navigationManager }
}

@main struct RestorationControls {
    @MainActor static func main() {
        let all: BackendCapabilities = [.search, .authors]
        let cases: [(String, Int?, BackendCapabilities, iOSTab)] = [
            ("missing preference", nil, all, .viewer),
            ("viewer", 0, all, .viewer),
            ("legacy text search", 1, all, .search),
            ("legacy Zayit search", 2, all, .search),
            ("global search", 3, all, .search),
            ("authors", 4, all, .author),
            ("annotations", 5, all, .annotations),
            ("history", 6, all, .history),
            ("negative corrupt preference", -1, all, .viewer),
            ("unknown corrupt preference", 99, all, .viewer),
            ("unsupported legacy text search", 1, [.authors], .viewer),
            ("unsupported legacy Zayit search", 2, [.authors], .viewer),
            ("unsupported global search", 3, [.authors], .viewer),
            ("unsupported authors", 4, [.search], .viewer),
            ("viewer with no optional capabilities", 0, [], .viewer),
            ("annotations with no optional capabilities", 5, [], .annotations),
            ("history with no optional capabilities", 6, [], .history)
        ]
        for (name, raw, capabilities, expected) in cases {
            UserDefaults.standard.storedTab = raw
            UserDefaults.standard.reads = 0
            BackendCoordinator.shared.activeCapabilities = capabilities
            let count = iOSNavigationManager.creations
            let scene = iOSMainView()
            precondition(scene.observedTab == expected, name)
            precondition(scene.observedManager.currentMode == expected.appMode, name)
            precondition(scene.observedManager.modeChanges == 1, name)
            precondition(iOSNavigationManager.creations == count + 1, name)
            precondition(UserDefaults.standard.reads == 1, name)
            precondition(UserDefaults.standard.storedTab == raw, name)
            print("PASS \(name)")
        }
        BackendCoordinator.shared.activeCapabilities = all
        UserDefaults.standard.storedTab = 3
        let first = iOSMainView()
        UserDefaults.standard.storedTab = 6
        let second = iOSMainView()
        precondition(first.observedTab == .search && first.observedManager.currentMode == .search)
        precondition(second.observedTab == .history && second.observedManager.currentMode == .history)
        precondition(first.observedManager !== second.observedManager)
        second.observedManager.switchToMode(.annotations)
        precondition(first.observedManager.currentMode == .search)
        print("PASS separate scene owners retain their own initialized destination")
        print("PASS 18 restoration controls; Native UI acceptance is NOT_RUN by this harness")
    }
}
