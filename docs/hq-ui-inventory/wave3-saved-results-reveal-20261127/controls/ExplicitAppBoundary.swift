import Foundation
import Observation
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

// EXPLICIT application/UIKit boundary. These fixtures do not represent an app,
// database, Core executor, real window/geometry, or Apple native qualification.
@MainActor final class UIWindow {}
@MainActor final class UIView { var window: UIWindow?; var visible = true; init(_ window: UIWindow?) { self.window = window } }
@MainActor enum MaktabahNativeSavedResultsGeometry {
    static func isVisible(_ view: UIView, in sheet: UIView, window: UIWindow, sceneID: UIStableID) -> Bool {
        view.visible && sheet.visible && view.window === window && sheet.window === window
    }
}
@MainActor struct Binding<Value> {
    let get: () -> Value
    let set: (Value) -> Void
    init(get: @escaping () -> Value, set: @escaping (Value) -> Void) { self.get = get; self.set = set }
    init(get: @escaping () -> Value, set: @escaping (Value, Transaction) -> Void) {
        self.get = get; self.set = { set($0, Transaction()) }
    }
    func transaction(_ value: Transaction) -> Self { self }
    var wrappedValue: Value { get { get() } nonmutating set { set(newValue) } }
}
struct Transaction {}
@MainActor final class Cell<T> { var value: T; init(_ value: T) { self.value = value }
    var binding: Binding<T> { Binding(get: { self.value }, set: { self.value = $0 }) }
}
enum BackendID { case otzaria, sefaria }
enum AppMode { case search, viewer }
enum iOSTab { case search, viewer
    func isAvailable(for enabled: Bool) -> Bool { enabled }
}
@Observable @MainActor final class BackendCoordinator {
    static let shared = BackendCoordinator()
    var activeBackendID = BackendID.otzaria
    var usesNativeMaktabahDataPath = true
    var activeCapabilities = true
    var generation: UInt64 = 0
    var isTransitioning = false
}
// The production Combine bridge is separately preserved; this explicit
// observable backend fixture substitutes only that external publisher.
@MainActor final class MaktabahNativeComponentSourceObservation {
    let value: NativeComponentSourceObservation
    init(read: @MainActor () -> Void) {
        value = NativeComponentSourceObservation {
            _ = BackendCoordinator.shared.activeBackendID; _ = BackendCoordinator.shared.generation
            _ = BackendCoordinator.shared.isTransitioning
            read()
        }
    }
    func validate() throws { try value.validate() }
}
@Observable @MainActor final class BooksData {}
@Observable @MainActor final class ReaderViewModel {
    var currentBook: BooksData?; var currentDestination: Int?; var isPopoverPresented = false
    var readerInspectorVisible = false
}
@Observable @MainActor final class SearchViewModel {}
@Observable @MainActor final class SearchSession {
    var query = "unchanged query"; var scope = 1; var requestConfiguration = 1
    var selectedBookIds: [Int] = []; var resultKitabFilter = ""
    var showsBookFilterSheet = false; var showsSearchDataSheet = false; var showsAdvancedOptions = false
    var searchViewModel: SearchViewModel?
}
@Observable @MainActor final class iOSNavigationManager {
    var currentMode = AppMode.search; var selectedBook: BooksData?; var selectedBookPresentationMode: AppMode?
    var nativeModePresentationRevision: UInt64? = 0; var selectedBookPresentationRevision: UInt64? = 0
    var openTabs: [UUID] = []; var activeTabId: UUID?; var selectedContentId: Int?
    var unifiedSearchSession = SearchSession(); var searchViewModel = SearchViewModel()
    var selectedBookForInfo: BooksData?; var showingTabsList = false; var alertMessage: String?
    var activeReaderViewModel: ReaderViewModel?
    init() { unifiedSearchSession.searchViewModel = searchViewModel }
}
@Observable @MainActor final class DonationManager { static let shared = DonationManager(); var showDonationSheet = false }
typealias RootPublications = MaktabahNativeRootPublicationSource
@MainActor struct MaktabahNativeSceneBindings {
    let manager: iOSNavigationManager
    let selectedTab: Binding<iOSTab>
    let showSettings: Binding<Bool>
    let rootPublications: RootPublications?
    var isPresentationReady: Bool { !DonationManager.shared.showDonationSheet && manager.selectedBookForInfo == nil && !manager.showingTabsList }
}
struct MappingEvent: Equatable { var epoch: UInt64; var phase = 0 }
@Observable @MainActor final class MappingSource { var event = MappingEvent(epoch: 0) }
enum MappingCoverage { case liveNativeSetters, workspaceStoreOnly }
@MainActor struct Mapping {
    let source: MappingSource; let owner: ObjectIdentifier; let scene: String
    let coverage: MappingCoverage
    let epoch: UInt64
    var projection: Int { 1 }
}
@Observable @MainActor final class Store {
    var loadError: String?; let source = MappingSource()
    func mappingObservation(scene: String) -> Mapping? { .init(source: source, owner: ObjectIdentifier(self), scene: scene, coverage: .workspaceStoreOnly, epoch: source.event.epoch) }
}
@Observable @MainActor final class Workspace {
    var attached = true; var isSwitching = false; var sceneID = "original-scene"; var errorMessage: String?
    let store = Store(); let source = MappingSource(); let manager: iOSNavigationManager
    init(_ manager: iOSNavigationManager) { self.manager = manager }
    func mappingOwnershipObservation() -> Mapping? { .init(source: source, owner: ObjectIdentifier(manager), scene: sceneID, coverage: .liveNativeSetters, epoch: source.event.epoch) }
}
@MainActor final class MaktabahNativeWorkspaceProjectionSource {
    var isAuthoritative = true; var value: Workspace
    init(_ value: Workspace) { self.value = value }
    func read() throws -> Workspace? { value }
}
@Observable @MainActor final class MaktabahNativeWorkspacePresentationBinding { var originalStateRevision: UInt64? = 0 }
@Observable @MainActor final class ResultsViewModel {
    static let shared = ResultsViewModel()
    let nativeLoadLifetime = OriginalSavedResultsLoadLifetime()
    var folderRoots: [FolderNode] = []; var folderResults: [Int64?: [ResultNode]] = [:]
    var folderById: [Int64: FolderNode] = [:]; var parentById: [Int64: Int64?] = [:]
    var resultById: [Int64: ResultNode] = [:]
    func notifyChange(_ change: BookmarkTreeChange) {}
}
enum BookmarkTreeChange { case fullReload }
// Read-only DB boundary for the verbatim original async load methods. The
// fixture returns exact original nodes, exercising equal published collections.
final class ResultsHandler: @unchecked Sendable {
    static let shared = ResultsHandler()
    private let lock = NSLock()
    private var roots: [FolderNode] = []
    private var results: [Int64?: [ResultNode]] = [:]
    func prepare(roots: [FolderNode], results: [Int64?: [ResultNode]]) {
        lock.lock(); defer { lock.unlock() }; self.roots = roots; self.results = results
    }
    func fetchFolderTree() -> [FolderNode] {
        lock.lock(); defer { lock.unlock() }; return roots
    }
    func fetchAllResultsGroupedByFolder() -> [Int64?: [ResultNode]] {
        lock.lock(); defer { lock.unlock() }; return results
    }
}
@MainActor final class TestSession {
    var savedResultsBinding: MaktabahNativeSavedResultsBinding?
    var onSearchWrite: (() -> Void)?
    func originalSearchPresentationWillChange(owner: UUID) { onSearchWrite?() }
}
