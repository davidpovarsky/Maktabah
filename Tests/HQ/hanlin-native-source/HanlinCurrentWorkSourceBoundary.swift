import Foundation

// Explicit UIKit/SwiftUI, navigation-manager and Action/UI DTO boundaries.
// The real Library models, render model, content coordinator, destination resolver,
// entire surface() method, and current-work source method are compiled unchanged.
struct UIStableID: RawRepresentable, Hashable {
    let rawValue: String
    init?(rawValue: String) { guard !rawValue.isEmpty else { return nil }; self.rawValue = rawValue }
}
typealias UIDestinationID = UIStableID
typealias ActionTextRef = TextLocator
struct UIStateSpec: Equatable {
    var workspaceID: UIStableID? = nil
    var profileID: UIStableID? = nil
    var selectedItemID: UIStableID? = nil
    var inspectorVisible: Bool? = nil
}
enum PresentationMode { case sameTab, newTab }
struct ActionReaderDestination: Equatable {
    let sectionLocator: TextLocator
    let focusLocator: TextLocator?
    let presentationMode: PresentationMode
}
struct NativeSurfaceState {
    struct Presentation {
        enum Kind { case currentTab, newTab, sheet, inspector }
        var kind: Kind = .currentTab
        var tabID: UIStableID? = nil
    }
    let destination: UIDestinationID
    let presentation: Presentation
    let content: ActionReaderDestination?
    let state: UIStateSpec
    let focus: String?
}
enum ActionAppIdentityBridge {
    static func actionRef(_ value: TextLocator) throws -> TextLocator { value }
}
enum ReaderScrollTarget: Equatable, Sendable { case top, bottom }
enum SefariaRef {
    static func canonicalInput(_ value: String) -> String { preconditionFailure("Unexecuted Sefaria boundary") }
    static func sectionAncestors(of value: String) -> [String] { preconditionFailure("Unexecuted Sefaria boundary") }
}
enum iOSTab { case viewer, history, search, annotations
    var canonical: Self { self }
    var appMode: Self { self }
}
enum NavigationSplitViewVisibility { case all, doubleColumn, detailOnly }
@MainActor final class BackendCoordinator {
    static let shared = BackendCoordinator()
    var activeBackendID: BackendID = .otzaria
}
@MainActor final class BooksData {
    let id: Int
    var backendLocator: TextLocator?
    init(id: Int, backendLocator: TextLocator?) { self.id = id; self.backendLocator = backendLocator }
}
@MainActor final class ReaderViewModel {
    enum State { case loaded, loading, error }
    var state: State = .loaded
    var currentBook: BooksData?
    var currentDestination: LibraryReaderDestination?
    var backendSection: LibraryTextSection?
    var backendRenderModel: LibraryReaderRenderModel?
    var contentText = ""
    var readerInspectorVisible = false
    let contentLoadCoordinator = ReaderContentLoadCoordinator()
}
@MainActor final class iOSNavigationManager {
    struct ReaderTab {
        let id: UUID
        let book: BooksData
        let viewModel: ReaderViewModel
    }
    final class Search {
        var hasSubmitted = false, isSearching = false, resultsAreDirty = false
        var errorMessage: String?
    }
    var activeTabId: UUID?
    var openTabs: [ReaderTab] = []
    var currentMode: iOSTab = .viewer
    var selectedBook: BooksData?
    let unifiedSearchSession = Search()
}
@MainActor final class HistoryViewModel {
    static let shared = HistoryViewModel()
    var searchText = ""
}
@MainActor enum MaktabahApp { static var isIpad = true }
@MainActor final class ReaderSidebarPageCoordinator {
    enum Page { case library, contents }
    var page: Page = .library
}
@MainActor final class StudyWorkspaceNavigationAdapter {
    struct Selection { let groupID: UUID; let profileID: UUID }
    var selection: Selection?
    func hasCommittedNativeReader(tabID: UUID) -> Bool { false }
}
@MainActor enum MaktabahNativeRootDestination: String {
    case search = "native.search", annotations = "native.annotations"
    var isAvailable: Bool { true }
    var tab: iOSTab { self == .search ? .search : .annotations }
}
@MainActor enum MaktabahNativeSceneBindings {
    static func hasOriginalTableOfContents(_ manager: iOSNavigationManager) -> Bool {
        preconditionFailure("Unexecuted TOC boundary")
    }
}
@MainActor enum MaktabahNativeInspectorBinding {
    static func currentReader(in manager: iOSNavigationManager) -> ReaderViewModel? {
        preconditionFailure("Unexecuted Inspector boundary")
    }
}
@MainActor struct MaktabahNativeSceneProjection {
    enum Surface { case library, tableOfContents, reader, history, search, searchResults, annotations, settings, inspector, noteDraft }
    let manager: iOSNavigationManager
    var selectedTab: iOSTab = .viewer
    var columnVisibility: NavigationSplitViewVisibility = .all
    var settingsPresented = false
    var sidebar: ReaderSidebarPageCoordinator? = nil
    var workspace: StudyWorkspaceNavigationAdapter? = nil
    private var activeTab: iOSNavigationManager.ReaderTab? {
        guard let id = manager.activeTabId else { return nil }
        return manager.openTabs.first { $0.id == id }
    }
    private func stable(_ id: UUID?) -> UIStableID? { id.flatMap { UIStableID(rawValue: $0.uuidString) } }
    private func id(_ value: String) -> UIDestinationID { UIDestinationID(rawValue: value)! }
    // ACTUAL_SURFACE
    // ACTUAL_CURRENT_WORK_SOURCE
}

struct ObservedReadSource: Equatable {
    let readerOwner: ObjectIdentifier
    let requested: LibraryReaderDestination
    let loaded: LibraryReaderDestination
    let requestToken: ReaderContentRequestToken?
}
@MainActor func observe(_ projection: MaktabahNativeSceneProjection) throws -> ObservedReadSource? {
    // ACTUAL_CONSUMER_SELECTION
}
