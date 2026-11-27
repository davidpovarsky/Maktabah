import Foundation
import Observation

// Explicit source-control boundary. These are small test inputs for UIKit,
// Combine and the app domain, NOT an app host, engine or native witness.
struct UIDestinationID: RawRepresentable, Equatable, Hashable, Sendable {
    let rawValue: String
    init?(rawValue: String) { self.rawValue = rawValue }
}
struct UIStableID: RawRepresentable, Equatable, Hashable, Sendable {
    let rawValue: String
    init?(rawValue: String) { self.rawValue = rawValue }
}
struct FocusSpec: Equatable, Sendable {
    enum Kind: Sendable { case component }
    let kind: Kind
    let anchor: UIDestinationID?
}
struct PresentationSpec { enum Kind: Sendable { case currentTab } }
struct UIRouteError: Error {
    enum Code { case unavailable, staleState, failed, notSupported }
    let code: Code
    let reason: String
    init(_ code: Code, _ reason: String) { self.code = code; self.reason = reason }
}
extension String { init(localized value: String) { self = value } }

@MainActor final class AnyCancellable {
    private let cancel: @MainActor () -> Void
    init(_ cancel: @escaping @MainActor () -> Void) { self.cancel = cancel }
    isolated deinit { cancel() }
}
@MainActor final class BoundaryPublisher<Value> {
    var callbacks: [UUID: (Value) -> Void] = [:]
    func send(_ value: Value) { for callback in Array(callbacks.values) { callback(value) } }
    func sink(_ receive: @escaping (Value) -> Void) -> AnyCancellable {
        let id = UUID(); callbacks[id] = receive
        return AnyCancellable { [weak self] in self?.callbacks.removeValue(forKey: id) }
    }
    // No current-value event is sent by this boundary; product dropFirst only
    // removes Combine Published's synchronous subscription value.
    func dropFirst() -> BoundaryPublisher<Value> { self }
}
@MainActor @propertyWrapper final class BoundaryPublished<Value> {
    private var value: Value
    let projectedValue = BoundaryPublisher<Value>()
    init(wrappedValue: Value) { value = wrappedValue }
    var wrappedValue: Value {
        get { value }
        set { projectedValue.send(newValue); value = newValue }
    }
}
enum BackendID: String { case otzaria, alternate }
@MainActor final class BackendCoordinator {
    static let shared = BackendCoordinator()
    var activeBackendID: BackendID = .otzaria
    var generation: UInt64 = 1
    var isTransitioning = false
    let objectWillChange = BoundaryPublisher<Void>()
}
@MainActor enum MaktabahApp { static var isIpad = false }
enum iOSTab: Equatable {
    case viewer, search, history, legacy
    var canonical: iOSTab { self == .legacy ? .search : self }
    var appMode: AppMode { self == .viewer ? .viewer : (self == .history ? .history : .search) }
}
enum AppMode { case viewer, search, history }
@MainActor enum MaktabahNativeRootDestination {
    case search
    static var supported = true
    var isAvailable: Bool { Self.supported }
}
@MainActor @Observable final class BooksData {}
@MainActor @Observable final class ReaderViewModel {
    var currentBook: BooksData?
    var currentDestination = "original-location"
    var currentContentId = 523
    var isPopoverPresented = false
    var readerInspectorVisible = false
}
@MainActor @Observable final class SearchViewModel {
    var selectedBookIds: Set<Int> = []
    var filterText = ""
    var query = ""
    var searchMode = "phrase"
    var nearDistance = 0
    var sortKey = "title"
    var sortAscending = true
    var resultKitabFilter = ""
    var backendSearchGeneration = 1
}
enum UnifiedSearchScope: String { case exact, advanced }
@MainActor final class BoundaryZayitModel {
    @BoundaryPublished var matchMode = "flexible"
}
@MainActor final class BoundaryZayitSession { let model = BoundaryZayitModel() }
@MainActor @Observable final class UnifiedSearchSessionController {
    var query = ""
    var scope = UnifiedSearchScope.exact
    var selectedBookIds: Set<Int> = []
    var hasSubmitted = false
    var resultKitabFilter = ""
    var submissionRevision = 0
    var cancellationRevision = 0
    var paginationRevision = 0
    var showsBookFilterSheet = false
    var showsSearchDataSheet = false
    var showsAdvancedOptions = false
    weak var searchViewModel: SearchViewModel?
    let zayitSession = BoundaryZayitSession()
    var availableScopes: [UnifiedSearchScope] { [.exact, .advanced] }
    var requestConfiguration: [String] { [query, scope.rawValue, selectedBookIds.sorted().map(String.init).joined(separator: ",")] }
}
@MainActor @Observable final class DonationManager {
    static let shared = DonationManager()
    var showDonationSheet = false
}
@MainActor @Observable final class BoundaryOverview { var blocksRouting = false }
@MainActor final class ReaderSidebarPageCoordinator { let overview = BoundaryOverview() }
@MainActor struct Binding<Value> {
    let get: () -> Value
    let set: (Value) -> Void
    var wrappedValue: Value { get { get() } nonmutating set { set(newValue) } }
}

@MainActor @Observable final class MappingSource { var event = 1 }
enum MappingCoverage { case liveNativeSetters }
struct MappingProjection: Equatable { var value = "original-profile/group/tab" }
struct MappingEpoch: Equatable { var revision: UInt64 = 1 }
@MainActor struct MappingObservation {
    let source: MappingSource
    let owner: ObjectIdentifier
    let scene: String
    let epoch: MappingEpoch
    let projection: MappingProjection
    let coverage: MappingCoverage = .liveNativeSetters
}
@MainActor @Observable final class StudyWorkspaceNavigationAdapter {
    var attached = true
    var isSwitching = false
    var sceneID = "original-scene"
    var mappingOwnershipSource = MappingSource()
    var epoch = MappingEpoch()
    var projection = MappingProjection()
    let manager: iOSNavigationManager
    init(_ manager: iOSNavigationManager) { self.manager = manager }
    func mappingOwnershipObservation() -> MappingObservation? {
        .init(source: mappingOwnershipSource, owner: ObjectIdentifier(manager), scene: sceneID, epoch: epoch, projection: projection)
    }
}
@MainActor @Observable final class MaktabahNativeWorkspaceProjectionSource {
    var current: StudyWorkspaceNavigationAdapter?
    var isAuthoritative = true
    init(_ current: StudyWorkspaceNavigationAdapter) { self.current = current }
    func read() throws -> StudyWorkspaceNavigationAdapter? { current }
}

struct UIEdgeInsets { var top: CGFloat = 0; var left: CGFloat = 0; var bottom: CGFloat = 0; var right: CGFloat = 0 }
extension CGRect {
    func inset(by value: UIEdgeInsets) -> CGRect {
        .init(x: minX + value.left, y: minY + value.top,
              width: width - value.left - value.right, height: height - value.top - value.bottom)
    }
}
@MainActor class UIView {
    weak var window: UIWindow?
    weak var superview: UIView?
    var bounds = CGRect(x: 0, y: 0, width: 300, height: 44)
    var offset = CGPoint.zero
    var isHidden = false
    var alpha: CGFloat = 1
    var clipsToBounds = false
    func convert(_ rect: CGRect, to: UIView?) -> CGRect { rect.offsetBy(dx: offset.x, dy: offset.y) }
    func isDescendant(of other: UIView) -> Bool {
        var value: UIView? = self
        while let current = value { if current === other { return true }; value = current.superview }
        return false
    }
}
@MainActor final class UIScrollView: UIView {
    var isDragging = false; var isDecelerating = false
    var adjustedContentInset = UIEdgeInsets()
}
@MainActor final class UIWindow: UIView {
    var isKeyWindow = true
    var windowScene: UIWindowScene? = UIWindowScene()
    var rootViewController: UIViewController? = UIViewController()
}
@MainActor final class UIWindowScene {
    enum Activation { case foregroundActive, background }
    var activationState = Activation.foregroundActive
    let session = Session()
    final class Session { var persistentIdentifier = "original-scene" }
}
@MainActor final class UIViewController {
    var view = UIView()
    var presentedViewController: UIViewController?
    var isBeingPresented = false
    var isBeingDismissed = false
    var transitionCoordinator: NSObject?
}
@MainActor final class UISearchTextField: UIView {
    var isEnabled = true
    var canBecomeFirstResponder = true
    var isFirstResponder = false
    var markedTextRange: NSObject?
    var text: String? = ""
    var focusCalls = 0
    var beforeFocus: (() -> Void)?
    func becomeFirstResponder() -> Bool {
        focusCalls += 1; beforeFocus?()
        guard canBecomeFirstResponder else { return false }
        isFirstResponder = true
        return true
    }
}

@MainActor @Observable final class iOSNavigationManager {
    struct ReaderTab {
        let id: UUID
        let book: BooksData
        var viewModel: ReaderViewModel
    }
    var currentMode: AppMode = .viewer {
        willSet {
            // Observe every original mode publication, including equal writes.
            // This metadata neither selects a mode nor replaces TabView's owner.
            if let revision = nativeModePresentationRevision, revision < .max {
                nativeModePresentationRevision = revision + 1
            } else {
                nativeModePresentationRevision = nil
            }
        }
    }
    private(set) var nativeModePresentationRevision: UInt64? = 0
    var selectedBook: BooksData? {
        willSet {
            // Original presentation ownership metadata. Every setter, including
            // an equal-value write, advances; exhaustion can never recycle it.
            if let revision = selectedBookPresentationRevision, revision < .max {
                selectedBookPresentationRevision = revision + 1
            } else {
                selectedBookPresentationRevision = nil
            }
        }
        didSet { selectedBookPresentationMode = selectedBook.map { _ in currentMode } }
    }
    private(set) var selectedBookPresentationRevision: UInt64? = 0
    private(set) var selectedBookPresentationMode: AppMode?

    var unifiedSearchSession = UnifiedSearchSessionController()
    var searchViewModel = SearchViewModel()
    var openTabs: [ReaderTab] = []
    var activeTabId: UUID?
    var selectedContentId: Int? = 523
    var selectedBookForInfo: BooksData?
    var showingTabsList = false
    var alertMessage: String?
    var activeReaderViewModel: ReaderViewModel? {
        openTabs.first { $0.id == activeTabId }?.viewModel
    }
    init(modeSeed: UInt64? = 0, bookSeed: UInt64? = 0) {
        nativeModePresentationRevision = modeSeed
        selectedBookPresentationRevision = bookSeed
        unifiedSearchSession.searchViewModel = searchViewModel
    }
}
@MainActor struct MaktabahNativeSceneBindings {
    let manager: iOSNavigationManager
    let selectedTab: Binding<iOSTab>
    let showSettings: Binding<Bool>
    let sidebar: ReaderSidebarPageCoordinator? = nil
    var isPresentationReady: Bool {
        !DonationManager.shared.showDonationSheet && manager.selectedBookForInfo == nil
            && !manager.showingTabsList && manager.activeReaderViewModel?.isPopoverPresented != true
            && sidebar?.overview.blocksRouting != true
    }
    func presentOriginalSearchEntry(_ expected: MaktabahNativeSearchEntryParentTransition) throws {
        guard !showSettings.wrappedValue, isPresentationReady,
              MaktabahNativeRootDestination.search.isAvailable else {
            throw UIRouteError(.unavailable, "native_search_entry_presentation_blocked")
        }
        try expected.validateBefore(self)
        if expected.popsBook { manager.selectedBook = nil }
        if expected.changesTab { selectedTab.wrappedValue = .search }
        guard !showSettings.wrappedValue, isPresentationReady else {
            throw UIRouteError(.staleState, "native_search_entry_presentation_changed")
        }
        try expected.validateAfter(self, requiresPublishedMode: false)
    }
}
