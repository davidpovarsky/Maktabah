import Foundation
import Observation
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

// EXPLICIT UIKit, Combine, Store and application boundaries. These do not
// represent an actual window, database, executor or native acceptance result.
@MainActor final class UIWindowScene {
    final class Session { var persistentIdentifier = "original-scene" }
    let session = Session()
}
@MainActor final class UIWindow { let windowScene: UIWindowScene? = .init() }
@MainActor class UIView {
    var window: UIWindow?
    var frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    var visible = true
    weak var parent: UIView?
    var onLayout: (() -> Void)?
    init(_ window: UIWindow? = nil) { self.window = window }
    func layoutIfNeeded() { onLayout?() }
    func isDescendant(of view: UIView) -> Bool { self === view || parent === view }
    enum AnimationOptions { case curveEaseInOut }
    static func animate(withDuration: Double, delay: Double, options: AnimationOptions, animations: () -> Void) { animations() }
}
@MainActor class UICollectionViewCell: UIView { var isSelected = false; var contentConfiguration: Any? }
struct AnnotationContentConfiguration { let annotation: Annotation }
struct ListContentConfiguration { var isExpanded: Bool }
@MainActor final class RefreshControl { var isRefreshing = false }
@MainActor final class UICollectionView: UIView {
    struct ScrollPosition: OptionSet { let rawValue: Int; static let centeredVertically = Self(rawValue: 1) }
    var refreshControl: RefreshControl?
    var cells: [IndexPath: UICollectionViewCell] = [:]
    var indexPathsForSelectedItems: [IndexPath]? = []
    var visibleCells: [UICollectionViewCell] { Array(cells.values) }
    var scrolls = 0, selections = 0
    var onScroll: (() -> Void)?, onSelect: (() -> Void)?
    func cellForItem(at index: IndexPath) -> UICollectionViewCell? { cells[index] }
    func scrollToItem(at index: IndexPath, at position: ScrollPosition, animated: Bool) { scrolls += 1; onScroll?() }
    func selectItem(at index: IndexPath, animated: Bool, scrollPosition: ScrollPosition) {
        selections += 1
        for cell in cells.values { cell.isSelected = false }
        cells[index]?.isSelected = true; indexPathsForSelectedItems = [index]; onSelect?()
    }
}
@MainActor enum MaktabahNativeSavedResultsGeometry {
    struct Evidence { let foreground: Bool; let hidden: Bool; let transitioning: Bool; let alpha: Double; let frame: CGRect; let visible: CGRect }
    static func evidence(_ view: UIView) -> Evidence {
        .init(foreground: view.window != nil, hidden: !view.visible, transitioning: false, alpha: 1,
              frame: view.frame, visible: view.visible ? view.frame : .null)
    }
}
@MainActor struct Binding<Value> {
    let get: () -> Value; let set: (Value) -> Void
    init(get: @escaping () -> Value, set: @escaping (Value) -> Void) { self.get = get; self.set = set }
    init(get: @escaping () -> Value, set: @escaping (Value, Transaction) -> Void) { self.get = get; self.set = { set($0, Transaction()) } }
    func transaction(_ value: Transaction) -> Self { self }
    var wrappedValue: Value { get { get() } nonmutating set { set(newValue) } }
}
struct Transaction {}
@MainActor final class Cell<T> {
    var value: T; init(_ value: T) { self.value = value }
    var binding: Binding<T> { Binding(get: { self.value }, set: { self.value = $0 }) }
}
enum BackendID: Equatable { case otzaria, sefaria, sefariaEmbedded }
enum AppMode { case viewer, annotations }
enum iOSTab { case viewer, annotations; func isAvailable(for enabled: Bool) -> Bool { enabled } }
@Observable @MainActor final class BackendCoordinator {
    static let shared = BackendCoordinator()
    var activeBackendID = BackendID.otzaria
    var activeCapabilities = true
    var generation: UInt64 = 0
    var isTransitioning = false
}
@MainActor final class MaktabahNativeComponentSourceObservation {
    let value: NativeComponentSourceObservation
    init(read: @MainActor () -> Void) {
        value = NativeComponentSourceObservation {
            _ = BackendCoordinator.shared.activeBackendID; _ = BackendCoordinator.shared.generation
            _ = BackendCoordinator.shared.isTransitioning; read()
        }
    }
    func validate() throws { try value.validate() }
}
@MainActor final class AnyCancellable {
    let cancellation: () -> Void
    init(_ cancellation: @escaping () -> Void) { self.cancellation = cancellation }
    isolated deinit { cancellation() }
}
@MainActor final class EventPublisher {
    private var entries: [UUID: (Int) -> Void] = [:]
    func sink(_ read: @escaping (Int) -> Void) -> AnyCancellable {
        let id = UUID(); entries[id] = read
        return AnyCancellable { [weak self] in self?.entries.removeValue(forKey: id) }
    }
    func send() { for read in Array(entries.values) { read(1) } }
}
@MainActor final class AnnotationStore { static let shared = AnnotationStore(); let events = EventPublisher() }
struct BackendLocator: Equatable { let backend: BackendID; let identity: String }
struct Annotation: Equatable {
    var id: Int64?; var bkId = 103; var backendLocator: BackendLocator?
    var note = "original note"; var contentID = 523; var range = NSRange(location: 1, length: 5)
    var lastModified = 7; var tags = ["one"]
}
@MainActor enum ActionAppIdentityBridge {
    static func actionBackend(_ backend: BackendID) -> ActionBackendID {
        switch backend { case .otzaria: .otzaria; case .sefaria: .sefaria; case .sefariaEmbedded: .sefariaEmbedded }
    }
}
@MainActor final class LegacyIdentityRegistry {
    static let shared = LegacyIdentityRegistry()
    var values: [Int: BackendLocator] = [:]
    func locator(for id: Int) -> BackendLocator? { values[id] }
}
enum AnnotationNodeKind { case annotation, tag }
struct SwiftUIAnnotationNode {
    let id: String; let title: String; let kind: AnnotationNodeKind; var annotation: Annotation?
}
enum AnnotationItem: Hashable {
    case group(SwiftUIAnnotationNode), annotation(SwiftUIAnnotationNode)
    var node: SwiftUIAnnotationNode { switch self { case .group(let n), .annotation(let n): n } }
    var isGroup: Bool { if case .group = self { true } else { false } }
    static func == (a: Self, b: Self) -> Bool { a.node.id == b.node.id }
    func hash(into hasher: inout Hasher) { hasher.combine(node.id) }
}
struct SectionSnapshot {
    var items: [AnnotationItem]; var expanded: Set<String> = []
    func isExpanded(_ item: AnnotationItem) -> Bool { expanded.contains(item.node.id) }
    mutating func expand(_ values: [AnnotationItem]) { for v in values { expanded.insert(v.node.id) } }
    mutating func collapse(_ values: [AnnotationItem]) { for v in values { expanded.remove(v.node.id) } }
}
@MainActor final class DataSource {
    struct Snapshot { let sectionIdentifiers: [String] }
    var sections: [String: SectionSnapshot] = [:]
    var onApply: (() -> Void)?
    var applies = 0
    func snapshot() -> Snapshot { .init(sectionIdentifiers: sections.keys.sorted()) }
    func snapshot(for section: String) -> SectionSnapshot { sections[section]! }
    func apply(_ value: SectionSnapshot, to section: String, animatingDifferences: Bool) { sections[section] = value; applies += 1; onApply?() }
    func indexPath(for item: AnnotationItem) -> IndexPath? {
        for (sectionIndex, section) in sections.keys.sorted().enumerated() {
            let s = sections[section]!
            guard item.isGroup || s.expanded.contains(section) else { continue }
            if let row = s.items.firstIndex(of: item) { return IndexPath(indexes: [sectionIndex, row]) }
        }
        return nil
    }
    func itemIdentifier(for index: IndexPath) -> AnnotationItem? {
        let keys = sections.keys.sorted()
        guard index.count == 2, keys.indices.contains(index[0]), let s = sections[keys[index[0]]], s.items.indices.contains(index[1]) else { return nil }
        return s.items[index[1]]
    }
}
enum ViewModelState { case loading, loaded }
@Observable @MainActor final class AnnotationViewModel {
    @ObservationIgnored let nativeRoutingPublication = MaktabahNativeAnnotationListPublication()
    var state = ViewModelState.loaded { willSet { nativeRoutingPublication.willPublish() } }
    var searchText = "" { willSet { nativeRoutingPublication.willPublish() } }
    var searchScope = 0 { willSet { nativeRoutingPublication.willPublish() } }
    var groupingMode = 0 { willSet { nativeRoutingPublication.willPublish() } }
    var sortField = 0 { willSet { nativeRoutingPublication.willPublish() } }
    var sortAscending = false { willSet { nativeRoutingPublication.willPublish() } }
    var selectedTags: Set<String> = [] { willSet { nativeRoutingPublication.willPublish() } }
    var tagFilterMode = 0 { willSet { nativeRoutingPublication.willPublish() } }
}
@Observable @MainActor final class BooksData {}
@Observable @MainActor final class ReaderViewModel {
    var currentBook: BooksData?; var currentDestination: Int?; var isPopoverPresented = false; var readerInspectorVisible = false
}
@Observable @MainActor final class iOSNavigationManager {
    var currentMode = AppMode.annotations; var selectedBook: BooksData?; var selectedBookPresentationMode: AppMode?
    @ObservationIgnored var nativeModePresentationRevision: UInt64? = 0
    var selectedBookPresentationRevision: UInt64? = 0
    var openTabs: [UUID] = []; var activeTabId: UUID?; var selectedContentId: Int?
    var annotationViewModel = AnnotationViewModel()
    var selectedBookForInfo: BooksData?; var showingTabsList = false; var alertMessage: String?
    var activeReaderViewModel: ReaderViewModel?
}
@Observable @MainActor final class DonationManager { static let shared = DonationManager(); var showDonationSheet = false }
@MainActor struct MaktabahNativeSceneBindings {
    let manager: iOSNavigationManager; let selectedTab: Binding<iOSTab>; let showSettings: Binding<Bool>
    let rootPublications: MaktabahNativeRootPublicationSource?
    var isPresentationReady: Bool { !DonationManager.shared.showDonationSheet && manager.selectedBookForInfo == nil && !manager.showingTabsList }
}
struct MappingEvent: Equatable { var epoch: UInt64; var phase = 0 }
@Observable @MainActor final class MappingSource { var event = MappingEvent(epoch: 0) }
enum MappingCoverage { case liveNativeSetters, workspaceStoreOnly }
@MainActor struct Mapping {
    let source: MappingSource; let owner: ObjectIdentifier; let scene: String; let coverage: MappingCoverage; let epoch: UInt64
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
