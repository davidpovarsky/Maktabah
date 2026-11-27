#if os(iOS)
import SwiftUI
import UIKit
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

/// Finite existing top-level tabs. Availability delegates to the original UI
/// capability rules; this contains no resolver, search engine or write action.
@MainActor enum MaktabahNativeRootDestination: String, CaseIterable {
    case library = "native.library"
    case tableOfContents = "native.reader.toc"
    case history = "native.history"
    case search = "native.search"
    case annotations = "native.annotations"

    var tab: iOSTab {
        switch self {
        case .library, .tableOfContents: .viewer
        case .history: .history
        case .search: .search
        case .annotations: .annotations
        }
    }
    var isAvailable: Bool {
        tab.isAvailable(for: BackendCoordinator.shared.activeCapabilities)
            && (self != .history || HistoryViewModel.shared.searchText.isEmpty)
            && (self != .tableOfContents || MaktabahApp.isIpad)
    }
}

/// Thin access to existing scene bindings. No new navigation UI or renderer.
@MainActor
struct MaktabahNativeSceneBindings {
    let manager: iOSNavigationManager
    let selectedTab: Binding<iOSTab>
    let columnVisibility: Binding<NavigationSplitViewVisibility>
    let showSettings: Binding<Bool>
    let sidebar: ReaderSidebarPageCoordinator?
    let rootPublications: MaktabahNativeRootPublicationSource?

    init(manager: iOSNavigationManager, selectedTab: Binding<iOSTab>,
         columnVisibility: Binding<NavigationSplitViewVisibility>, showSettings: Binding<Bool>,
         sidebar: ReaderSidebarPageCoordinator?, rootPublications: MaktabahNativeRootPublicationSource? = nil) {
        self.manager = manager; self.selectedTab = selectedTab; self.columnVisibility = columnVisibility
        self.showSettings = showSettings; self.sidebar = sidebar; self.rootPublications = rootPublications
    }

    func isRootAvailable(_ root: MaktabahNativeRootDestination) -> Bool {
        root.isAvailable && (root != .tableOfContents
            || (sidebar != nil && Self.hasOriginalTableOfContents(manager)))
    }

    /// Read only the actual selected original Reader and TOC. Do not substitute
    /// a first tab, open a book, load a different corpus or clear a private filter.
    static func hasOriginalTableOfContents(_ manager: iOSNavigationManager) -> Bool {
        guard let id = manager.activeTabId,
              let tab = manager.openTabs.first(where: { $0.id == id }),
              let book = tab.book.backendLocator,
              let section = tab.viewModel.backendSection?.locator,
              book.backend == BackendCoordinator.shared.activeBackendID,
              section.backend == book.backend, section.workKey == book.workKey,
              !tab.viewModel.tocViewModel.isLoading,
              tab.viewModel.tocViewModel.loadFailure == nil,
              !tab.viewModel.tocViewModel.tocNodes.isEmpty else { return false }
        return true
    }

    var isPresentationReady: Bool {
        !DonationManager.shared.showDonationSheet && manager.selectedBookForInfo == nil
            && !manager.showingTabsList && manager.activeReaderViewModel?.isPopoverPresented != true
            && sidebar?.overview.blocksRouting != true
    }

    /// Workspace routing separately validates the exact original Overview and
    /// Profiles hosts. Unrelated original presentations still block that route.
    var isWorkspaceParentPresentationReady: Bool {
        !showSettings.wrappedValue && !DonationManager.shared.showDonationSheet
            && manager.selectedBookForInfo == nil
            && manager.activeReaderViewModel?.isPopoverPresented != true
    }

    func selectOriginalWorkspaceParent() {
        selectedTab.wrappedValue = .viewer
        // Preserve the original TabView's mode publication and all existing
        // tabs/models. The actual original parent host must still appear.
    }

    /// Reveal only the SAME original phone Reader. The source-owned revision
    /// declares exactly zero or one selectedBook assignment; no tab/book opener
    /// or fallback Reader is involved. Its parent proof validates this again.
    func presentOriginalPhoneTOCReader(_ tab: iOSNavigationManager.ReaderTab) throws {
        let matches = manager.openTabs.filter { $0.id == tab.id }
        guard !MaktabahApp.isIpad, !showSettings.wrappedValue, isPresentationReady,
              MaktabahNativeRootDestination.library.isAvailable,
              manager.activeTabId == tab.id, matches.count == 1, let original = matches.first,
              original.book === tab.book, original.viewModel === tab.viewModel,
              manager.selectedBook == nil || manager.selectedBook === tab.book,
              let revision = manager.selectedBookPresentationRevision else {
            throw UIRouteError(.staleState, "native_phone_toc_reader_owner_changed")
        }
        let assignsBook = manager.selectedBook !== tab.book || manager.selectedBookPresentationMode != .viewer
        guard !assignsBook || revision < .max else {
            throw UIRouteError(.staleState, "native_phone_toc_presentation_exhausted")
        }
        let expectedRevision = assignsBook ? revision + 1 : revision
        selectedTab.wrappedValue = .viewer
        // selectedBook.didSet captures the ORIGINAL currentMode synchronously.
        manager.switchToMode(.viewer)
        if assignsBook { manager.selectedBook = tab.book }
        let after = manager.openTabs.filter { $0.id == tab.id }
        guard manager.activeTabId == tab.id, after.count == 1, let retained = after.first,
              retained.book === tab.book, retained.viewModel === tab.viewModel,
              manager.selectedBook === tab.book, manager.currentMode == .viewer,
              manager.selectedBookPresentationMode == .viewer,
              manager.selectedBookPresentationRevision == expectedRevision else {
            throw UIRouteError(.staleState, "native_phone_toc_reader_transition_changed")
        }
    }

    /// Additive Search entry opens the original parent without dismissing
    /// Settings, submitting a query or selecting a substitute Reader. TabView
    /// remains the sole mode publisher, including its asynchronous callback.
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

    func apply(_ command: UISceneCommand, reservedTab: iOSNavigationManager.ReaderTab? = nil) throws {
        switch command.route.route.destination.rawValue {
        case "native.settings": showSettings.wrappedValue = true
        case "native.library", "native.reader.toc", "native.history", "native.search", "native.annotations":
            guard let root = MaktabahNativeRootDestination(rawValue: command.route.route.destination.rawValue),
                  isRootAvailable(root) else { throw UIRouteError(.notSupported, "native_root_unavailable") }
            showSettings.wrappedValue = false
            if root == .library {
                sidebar?.showLibrary()
                columnVisibility.wrappedValue = .all
            } else if root == .tableOfContents {
                guard let sidebar else { throw UIRouteError(.unavailable, "native_sidebar_unavailable") }
                sidebar.showContents()
                columnVisibility.wrappedValue = .all
            }
            // The original phone stacks share this optional navigation item.
            // Pop the presented reader without closing its tab or replacing
            // its model; original onDisappear persists the reading position.
            if !MaktabahApp.isIpad { manager.selectedBook = nil }
            // The original TabView selection observer owns mode publication.
            // Use the same selection transition as an original native tab tap.
            selectedTab.wrappedValue = root.tab
        case "native.reader":
            if let reservedTab {
                guard let content = command.route.route.content, content.presentationMode == .newTab,
                      command.route.route.presentation.kind == .newTab,
                      command.route.route.presentation.tabID?.rawValue == reservedTab.id.uuidString else {
                    throw UIRouteError(.staleState, "reserved_reader_target_changed")
                }
                let destination = try MaktabahNativeReaderBinding.appDestination(content)
                showSettings.wrappedValue = false
                selectedTab.wrappedValue = .viewer
                guard manager.presentPreparedNativeReaderTab(reservedTab, destination: destination) else {
                    throw UIRouteError(.staleState, "reserved_reader_presentation_failed")
                }
                return
            }
            // Selection/tab ownership is retained by the caller and rechecked
            // synchronously inside the canonical orchestrator's commit fence.
            guard let content = command.route.route.content,
                  let tabID = command.route.route.presentation.tabID,
                  let id = manager.activeTabId, id.uuidString == tabID.rawValue,
                  let tab = manager.openTabs.first(where: { $0.id == id }),
                  selectedTab.wrappedValue.canonical == .viewer,
                  manager.currentMode == .viewer, !showSettings.wrappedValue,
                  tab.book.backendLocator?.backend.rawValue == content.sectionLocator.backend.rawValue,
                  tab.book.backendLocator?.workKey == content.sectionLocator.workKey else {
                throw UIRouteError(.staleState, "current_reader_target_changed")
            }
            let destination = try MaktabahNativeReaderBinding.appDestination(content)
            if tab.viewModel.currentDestination != destination { tab.viewModel.loadBackendContent(destination) }
        default: throw UIRouteError(.notSupported, "native_surface_not_installed")
        }
    }
}

/// One original Reader owner retained for the whole Core result. A new-tab
/// reservation belongs to R's actual scene owner, never to this permission port.
@MainActor final class MaktabahNativeReaderBinding {
    private let manager: iOSNavigationManager
    private let reader: ReaderViewModel
    private let tabID: UUID
    private let destination: LibraryReaderDestination
    private let workspace: StudyWorkspaceNavigationAdapter?
    private let reservation: StudyWorkspaceNativeReaderReservation?
    private let historySource: MaktabahNativeHistoryReaderSource?
    private let revoke: @MainActor () -> Void
    private(set) var valid = true
    private var applying = false
    private var installed = false
    var isNewTab: Bool { reservation != nil }
    var targetTabID: UIStableID { UIStableID(rawValue: tabID.uuidString)! }
    var inspectorVisible: Bool { reader.readerInspectorVisible }
    var reservedTab: iOSNavigationManager.ReaderTab? { reservation?.tab }

    init(manager: iOSNavigationManager, currentTabID: UIStableID?,
         workspace: StudyWorkspaceNavigationAdapter?, requestID: UUID, content: ActionReaderDestination,
         historySource: MaktabahNativeHistoryReaderSource? = nil,
         revoke: @escaping @MainActor () -> Void) throws {
        if let historySource {
            try historySource.validate()
            guard historySource.request.invocation.requestId == requestID,
                  (content.focusLocator ?? content.sectionLocator) == historySource.locator,
                  (content.presentationMode == .newTab) == historySource.request.newTab else {
                throw UIRouteError(.staleState, "history_reader_request_changed")
            }
        }
        let destination = try Self.appDestination(content)
        let tab: iOSNavigationManager.ReaderTab
        let reserved: StudyWorkspaceNativeReaderReservation?
        if content.presentationMode == .newTab {
            guard let workspace,
                  let book = MaktabahBackendAdapter.resolveBook(for: destination.sectionLocator, in: LibraryDataManager.shared),
                  book.backendLocator?.backend == destination.sectionLocator.backend,
                  book.backendLocator?.workKey == destination.sectionLocator.workKey else {
                throw UIRouteError(.unavailable, "new_reader_target_unavailable")
            }
            let owned = try workspace.reserveNativeReader(requestID: requestID, book: book,
                destination: destination, manager: manager)
            tab = owned.tab; reserved = owned
        } else {
            guard let id = manager.activeTabId, id.uuidString == currentTabID?.rawValue,
                  let current = manager.openTabs.first(where: { $0.id == id }),
                  current.viewModel.nativeReaderDestinationWillChange == nil,
                  current.book.backendLocator?.backend == destination.sectionLocator.backend,
                  current.book.backendLocator?.workKey == destination.sectionLocator.workKey else {
                throw UIRouteError(.unavailable, "current_reader_target_unavailable")
            }
            tab = current; reserved = nil
        }
        self.manager = manager; reader = tab.viewModel; tabID = tab.id
        self.destination = destination; self.revoke = revoke
        self.workspace = workspace; reservation = reserved
        self.historySource = historySource
        reader.nativeReaderDestinationWillChange = { [weak self] next in
            guard let self, valid else { return }
            // Only this synchronous, already authorized native apply may
            // publish its exact canonical target. Every other change revokes.
            if applying && next == destination { return }
            valid = false; revoke()
        }
        installed = true
    }
    static func appDestination(_ content: ActionReaderDestination) throws -> LibraryReaderDestination {
        guard content.presentationMode == .sameTab || content.presentationMode == .newTab else { throw ActionPortError.notSupported }
        let section = try ActionAppIdentityBridge.appLocator(content.sectionLocator)
        let focus = try content.focusLocator.map(ActionAppIdentityBridge.appLocator)
        let original = ReaderDestinationResolver.resolve(locator: section)
        // Never silently re-normalize the command granted by Core. Clients
        // supply the original bounded section and explicit segment, if any.
        guard original.sectionLocator == section,
              (focus ?? original.focusLocator) == focus else { throw ActionPortError.notSupported }
        return .init(sectionLocator: section, focusLocator: focus)
    }
    func accepts(_ content: ActionReaderDestination) -> Bool {
        (content.presentationMode == .newTab) == isNewTab && (try? Self.appDestination(content)) == destination
    }
    func validate() throws {
        guard valid, installed else { throw UIRouteError(.staleState, "reader_binding_revoked") }
        try historySource?.validate()
        if let reservation {
            guard let workspace, reservation.tab.viewModel === reader,
                  reservation.tab.id == tabID,
                  reservation.tab.book.backendLocator?.backend == destination.sectionLocator.backend,
                  reservation.tab.book.backendLocator?.workKey == destination.sectionLocator.workKey else {
                throw UIRouteError(.staleState, "reserved_reader_owner_changed")
            }
            try workspace.validateNativeReader(reservation)
        } else {
            guard manager.activeTabId == tabID,
                  let tab = manager.openTabs.first(where: { $0.id == tabID }),
                  tab.viewModel === reader,
                  tab.book.backendLocator?.backend == destination.sectionLocator.backend,
                  tab.book.backendLocator?.workKey == destination.sectionLocator.workKey else {
                throw UIRouteError(.staleState, "current_reader_owner_changed")
            }
        }
    }
    func apply(_ operation: () throws -> Void) throws {
        try validate()
        guard !applying else { throw UIRouteError(.failed, "reader_apply_reentered") }
        applying = true
        defer { applying = false }
        try withHistorySource {
            if let reservation {
                guard let workspace else { throw ActionPortError.staleState }
                try workspace.applyNativeReader(reservation, operation: operation)
            } else { try operation() }
        }
        try validate()
        guard reader.currentDestination == destination else { throw ActionPortError.invalidResponse }
    }
    private func withHistorySource(_ operation: () throws -> Void) throws {
        if let historySource { try historySource.performOriginalApply(operation) }
        else { try operation() }
    }
    func release() {
        guard installed else { return }
        installed = false
        reader.nativeReaderDestinationWillChange = nil
        if let reservation { workspace?.releaseNativeReader(reservation) }
    }
    isolated deinit {
        if installed {
            reader.nativeReaderDestinationWillChange = nil
            if let reservation { workspace?.releaseNativeReader(reservation) }
        }
    }
}

// BEGIN NATIVE INSPECTOR OWNER BINDING
/// A retained original Reader, not a resolver or a second inspector. Opening the
/// existing panel may change only its visibility; source and private selection
/// must survive every Core/native await.
@MainActor final class MaktabahNativeInspectorBinding {
    private let manager: iOSNavigationManager
    private let reader: ReaderViewModel
    private let tabID: UUID
    private let destination: LibraryReaderDestination
    private let selectedLocator: TextLocator?
    private let lineAnchor: OtzariaLineAnchor?
    private let selectedRange: NSRange?
    private let textMode: LibraryReaderTextMode
    private let contentID: Int

    init(manager: iOSNavigationManager) throws {
        guard let reader = Self.currentReader(in: manager), let tabID = manager.activeTabId,
              let destination = reader.currentDestination else {
            throw UIRouteError(.unavailable, "native_inspector_reader_unavailable")
        }
        self.manager = manager; self.reader = reader; self.tabID = tabID
        self.destination = destination; selectedLocator = reader.selectedSegmentLocator
        lineAnchor = reader.otzariaSelectedLineAnchor; selectedRange = reader.readerState.selectedRange
        textMode = reader.currentReaderTextMode; contentID = reader.currentContentId
    }

    static func currentReader(in manager: iOSNavigationManager) -> ReaderViewModel? {
        guard manager.currentMode == .viewer, let id = manager.activeTabId,
              let tab = manager.openTabs.first(where: { $0.id == id }),
              let destination = tab.viewModel.currentDestination,
              let section = tab.viewModel.backendSection?.locator,
              section == destination.sectionLocator,
              section.backend == BackendCoordinator.shared.activeBackendID,
              tab.book.backendLocator?.backend == section.backend,
              tab.book.backendLocator?.workKey == section.workKey,
              !tab.viewModel.contentText.isEmpty,
              case .loaded = tab.viewModel.state else { return nil }
        let reader = tab.viewModel
        if let selected = reader.selectedSegmentLocator,
           selected.backend != section.backend || selected.workKey != section.workKey { return nil }
        if let anchor = reader.otzariaSelectedLineAnchor,
           section.backend != .otzaria || section.workKey != "book:\(anchor.bookId)" { return nil }
        if section.backend == .otzaria {
            guard let book = reader.currentBook, section.workKey == "book:\(book.id)" else { return nil }
        }
        return reader
    }

    func validate() throws {
        guard manager.activeTabId == tabID, Self.currentReader(in: manager) === reader,
              reader.currentDestination == destination, reader.currentContentId == contentID,
              reader.currentReaderTextMode == textMode,
              reader.selectedSegmentLocator == selectedLocator, reader.otzariaSelectedLineAnchor == lineAnchor,
              reader.readerState.selectedRange == selectedRange else {
            throw UIRouteError(.staleState, "native_inspector_reader_changed")
        }
    }

    #if DEBUG
    func noteDraftSourceDiagnostic() -> String {
        "activeTab=\(manager.activeTabId == tabID)"
            + " currentReader=\(Self.currentReader(in: manager) === reader)"
            + " destination=\(reader.currentDestination == destination)"
            + " contentID=\(reader.currentContentId == contentID)"
            + " textMode=\(reader.currentReaderTextMode == textMode)"
            + " selectedLocator=\(reader.selectedSegmentLocator == selectedLocator)"
            + " lineAnchor=\(reader.otzariaSelectedLineAnchor == lineAnchor)"
            + " selectedRange=\(reader.readerState.selectedRange == selectedRange)"
    }
    #endif

    func apply() throws {
        try validate()
        reader.readerInspectorVisible = true
    }
}
// END NATIVE INSPECTOR OWNER BINDING

// BEGIN ORIGINAL NOTE EDITOR OWNER
/// The existing SwiftUI Annotation binding and its original UITextView belong
/// to the mounted Reader. This is neither a note store nor another editor.
@MainActor final class MaktabahNativeNoteEditorOwner {
    let id: UUID
    weak var reader: ReaderViewModel?
    private let annotation: Binding<Annotation?>
    private let presentationID: @MainActor () -> UUID
    private var retiredPresentationID: UUID?
    weak var textView: UITextView?
    private(set) var presentationActive = false
    @discardableResult
    func observeTextView(_ value: UITextView?, presentationID: UUID) -> Bool {
        // Reader ownership survives sheet dismissal/reopening. Only the
        // presentation captured by this original editor may publish a view.
        guard current != nil, self.presentationID() == presentationID,
              retiredPresentationID != presentationID else { return false }
        if value == nil {
            // onDisappear closes this presentation even when its asynchronous
            // onCreated callback has not arrived. Late creation cannot revive it.
            retiredPresentationID = presentationID
        }
        textView = value
        if value != nil { presentationActive = true }
        return true
    }
    @discardableResult
    func didDismiss(presentationID: UUID) -> Bool {
        guard current == nil, self.presentationID() == presentationID,
              presentationActive || textView != nil || retiredPresentationID != presentationID else { return false }
        retiredPresentationID = presentationID
        presentationActive = false
        textView = nil
        return true
    }
    init(id: UUID, reader: ReaderViewModel, annotation: Binding<Annotation?>,
         presentationID: @escaping @MainActor () -> UUID) {
        self.id = id; self.reader = reader; self.annotation = annotation
        self.presentationID = presentationID
    }
    var current: Annotation? { annotation.wrappedValue }
    func present(_ draft: Annotation) throws {
        guard current == nil, draft.id == nil else { throw ActionPortError.staleState }
        presentationActive = true
        annotation.wrappedValue = draft
    }
}

/// Retain a proven original paragraph/line selection and an unsaved original
/// Annotation value. Preparation never calls any annotation persistence API.
@MainActor final class MaktabahNativeNoteDraftBinding {
    let owner: MaktabahNativeNoteEditorOwner
    let request: ActionNoteDraftRequest
    let draft: Annotation
    private let reader: ReaderViewModel
    private let sourceGuard: MaktabahNativeInspectorBinding
    private let sourceText: String
    private let sceneID: UIStableID
    private let sourceFence: (@MainActor () throws -> Void)?
    private(set) var isApplied = false

    /// Original source selection, also retained before a system action activates
    /// this exact existing window. The original visible-selection gate remains
    /// mandatory in selection(), immediately before draft construction.
    static func sourceSelection(manager: iOSNavigationManager, owner: MaktabahNativeNoteEditorOwner)
        throws -> (ReaderViewModel, TextLocator, NSRange, String) {
        guard let reader = MaktabahNativeInspectorBinding.currentReader(in: manager), owner.reader === reader,
              owner.current == nil, let locator = reader.selectedSegmentLocator,
              let range = reader.selectedSegmentRange else {
            throw UIRouteError(.unavailable, "exact_note_selection_unavailable")
        }
        // These are the original renderer/DB anchor ranges, never a guessed
        // first character, a title-derived position or a model-supplied range.
        let rendered = reader.backendRenderModel?.renderedSegment(for: locator)?.visualRange
        let anchorMatches = reader.otzariaSelectedLineAnchor.map {
            locator.backend == .otzaria && locator.workKey == "book:\($0.bookId)"
                && locator.position == .legacyLine($0.lineIndex) && $0.range == range
        } ?? false
        guard rendered == range || anchorMatches else { throw ActionPortError.staleState }
        let ref = try ActionAppIdentityBridge.actionRef(locator)
        _ = try ActionNoteDraftSelection.validate(.init(locator: ref), observedLocator: ref,
            sourceText: reader.contentText, originalRange: range)
        return (reader, locator, range, reader.contentText)
    }

    static func selection(manager: iOSNavigationManager, owner: MaktabahNativeNoteEditorOwner,
                          sceneID: UIStableID) throws -> (ReaderViewModel, TextLocator, NSRange, String) {
        let selected = try sourceSelection(manager: manager, owner: owner)
        guard selected.0.isNativeReaderTextVisible?(sceneID.rawValue, selected.2) == true else {
            throw UIRouteError(.unavailable, "exact_note_selection_unavailable")
        }
        return selected
    }

    init(manager: iOSNavigationManager, owner: MaktabahNativeNoteEditorOwner,
         request: ActionNoteDraftRequest, sceneID: UIStableID,
         sourceFence: (@MainActor () throws -> Void)? = nil) throws {
        let (reader, locator, range, source) = try Self.selection(manager: manager, owner: owner, sceneID: sceneID)
        let actual = try ActionAppIdentityBridge.actionRef(locator)
        let snippet = try ActionNoteDraftSelection.validate(request, observedLocator: actual, sourceText: source, originalRange: range)
        let sourceGuard = try MaktabahNativeInspectorBinding(manager: manager)
        var draft = try reader.makeAnnotationDraft(in: range, mode: .highlight, sourceText: source,
            color: UIColor(named: "HighlightText") ?? .systemYellow)
        guard draft.id == nil, draft.context.utf8.elementsEqual(snippet.utf8) else { throw ActionPortError.invalidResponse }
        // Same original editor flow: use the selected source-owned locator
        // when the original generic factory falls back to its containing unit.
        draft.backendLocator = locator
        draft.note = request.proposedText
        self.owner = owner; self.reader = reader; self.request = request; self.draft = draft
        self.sourceGuard = sourceGuard; sourceText = source; self.sceneID = sceneID
        self.sourceFence = sourceFence
        try validate()
    }
    func validate() throws {
        try sourceFence?()
        try sourceGuard.validate()
        guard owner.reader === reader, reader.contentText.utf8.elementsEqual(sourceText.utf8) else { throw ActionPortError.staleState }
        if isApplied {
            guard owner.current == draft, owner.current?.id == nil else { throw ActionPortError.staleState }
        } else {
            guard owner.current == nil else { throw ActionPortError.staleState }
        }
        try sourceFence?()
    }
    func apply() throws {
        try validate()
        isApplied = true
        try owner.present(draft)
        try validate()
    }
    #if DEBUG
    func sourceDiagnostic() -> String {
        sourceGuard.noteDraftSourceDiagnostic()
            + " sourceText=\(reader.contentText.utf8.elementsEqual(sourceText.utf8))"
            + " ownerReader=\(owner.reader === reader)"
    }
    #endif

    func validateVisible() throws {
        try validate()
        guard isApplied, let textView = owner.textView,
              NativeNoteEditorTextVisibility.isVisible(textView, sceneID: sceneID,
                  expectedText: request.proposedText ?? "") else {
            throw UIRouteError(.unavailable, "original_note_editor_not_visible")
        }
    }
}

@MainActor private enum NativeNoteEditorTextVisibility {
    static func isVisible(_ textView: UITextView, sceneID: UIStableID, expectedText: String) -> Bool {
        guard textView.isEditable, (textView.text ?? "").utf8.elementsEqual(expectedText.utf8),
              let window = textView.window, window.isKeyWindow, !window.isHidden,
              let scene = window.windowScene, scene.activationState == .foregroundActive,
              scene.session.persistentIdentifier == sceneID.rawValue,
              textView.bounds.width > 1, textView.bounds.height > 1 else { return false }
        var current: UIView? = textView
        var effectiveAlpha: CGFloat = 1
        while let view = current {
            guard !view.isHidden else { return false }
            effectiveAlpha *= view.alpha
            current = view.superview
        }
        guard effectiveAlpha >= 0.95 else { return false }
        let target = textView.convert(textView.bounds, to: window)
        guard target.origin.x.isFinite, target.origin.y.isFinite, target.width.isFinite, target.height.isFinite else { return false }
        var visible = target.intersection(window.bounds)
        var ancestor = textView.superview
        while let view = ancestor {
            if view.clipsToBounds {
                let clip = view.convert(view.bounds, to: window)
                guard clip.origin.x.isFinite, clip.origin.y.isFinite, clip.width.isFinite, clip.height.isFinite else { return false }
                visible = visible.intersection(clip)
            }
            ancestor = view.superview
        }
        guard !visible.isNull, visible.width > 1, visible.height > 1 else { return false }
        var top = window.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        guard let top, top !== window.rootViewController, top.transitionCoordinator == nil,
              textView.isDescendant(of: top.view) else { return false }
        if !expectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Reuse the existing TextKit viewport/glyph proof for this actual
            // text view. Blank drafts need a visible editor, not an invented glyph.
            return ReaderNativeTextVisibility.isVisible(textView: textView, sceneID: sceneID.rawValue,
                expectedSource: expectedText, renderedSource: textView.textStorage.string,
                renderedText: textView.textStorage.string, sourceRange: nil, displayedRange: { $0 })
        }
        return true
    }
}
// END ORIGINAL NOTE EDITOR OWNER

/// Exact ownership of the original global search model for one semantic open.
/// This never runs a second provider or synthesizes hits; runSearch remains the
/// original UI submission path, including its own history and paging behavior.
@MainActor final class MaktabahNativeSearchResultsBinding {
    let requestID: UUID
    let query: ActionSearchResultsQuery
    private let manager: iOSNavigationManager
    private let session: UnifiedSearchSessionController
    private let model: SearchViewModel
    private let initialConfiguration: [String]
    private let initialText: [UInt8]
    private let initialSubmission: Int
    private let initialCancellation: Int
    private let initialPagination: Int
    private let generation: UInt64
    private let selectedBookIDs: Set<Int>
    private var submittedConfiguration: [String]?
    private(set) var submissionRevision: Int?

    init(manager: iOSNavigationManager, query: ActionSearchResultsQuery, requestID: UUID) throws {
        guard ActionSearchResultsQuery.unsupportedReason(query.search) == nil,
              query.search.backend == ActionAppIdentityBridge.actionBackend(BackendCoordinator.shared.activeBackendID) else {
            throw UIRouteError(.notSupported, "native_search_query_not_supported")
        }
        self.manager = manager; self.query = query; self.requestID = requestID
        session = manager.unifiedSearchSession; model = manager.searchViewModel
        initialConfiguration = session.requestConfiguration; initialText = Array(session.query.utf8)
        initialSubmission = session.submissionRevision; initialCancellation = session.cancellationRevision
        initialPagination = session.paginationRevision
        generation = BackendCoordinator.shared.generation
        var ids = Set<Int>()
        for ref in query.search.scopeWorkRefs {
            guard ref.backend == .otzaria, ref.catalogRevision == nil,
                  ref.workKey.hasPrefix("book:"), let id = Int(ref.workKey.dropFirst(5)), id > 0,
                  String(id) == String(ref.workKey.dropFirst(5)) else {
                throw UIRouteError(.notSupported, "native_search_scope_not_supported")
            }
            ids.insert(id)
        }
        selectedBookIDs = ids
        try validate()
    }

    func accepts(_ value: ActionSearchResultsQuery, requestID: UUID) -> Bool {
        query == value && self.requestID == requestID
    }
    func validate() throws {
        guard manager.unifiedSearchSession === session, manager.searchViewModel === model,
              session.searchViewModel === model,
              BackendCoordinator.shared.generation == generation,
              ActionAppIdentityBridge.actionBackend(BackendCoordinator.shared.activeBackendID) == query.search.backend,
              session.availableScopes.contains(.exact),
              !session.showsBookFilterSheet, !session.showsSearchDataSheet, !session.showsAdvancedOptions,
              session.cancellationRevision == initialCancellation else {
            throw UIRouteError(.staleState, "native_search_owner_changed")
        }
        if let submissionRevision {
            guard session.submissionRevision == submissionRevision, session.query.utf8.elementsEqual(query.search.text.utf8),
                  session.paginationRevision == initialPagination,
                  session.selectedBookIds == selectedBookIDs, model.selectedBookIds == selectedBookIDs,
                  session.scope == .exact, session.requestConfiguration == submittedConfiguration,
                  !session.resultsAreDirty else { throw UIRouteError(.staleState, "native_search_query_changed") }
        } else {
            let sameText = session.query.trimmingCharacters(in: .whitespacesAndNewlines).utf8.elementsEqual(
                query.search.text.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
            let sameSort = query.search.backend == .otzaria
                ? session.otzariaOrder.rawValue == (query.search.sortOrder == .canonical ? "catalogue" : "relevance")
                : session.sefariaSortOrder.rawValue == query.search.sortOrder.rawValue && !session.sefariaReverseSort
            guard !(session.isSearching && session.submittedConfiguration == session.requestConfiguration
                    && sameText && session.scope == .exact && session.selectedBookIds == selectedBookIDs && sameSort) else {
                throw UIRouteError(.unavailable, "native_search_already_in_progress")
            }
            guard session.submissionRevision == initialSubmission,
                  session.paginationRevision == initialPagination,
                  session.requestConfiguration == initialConfiguration,
                  session.query.utf8.elementsEqual(initialText),
                  session.selectedBookIds == model.selectedBookIds else {
                throw UIRouteError(.staleState, "native_search_query_changed")
            }
        }
    }
    func apply(_ present: @MainActor () throws -> Void) throws {
        try validate()
        guard submissionRevision == nil else { throw UIRouteError(.failed, "native_search_already_submitted") }
        // No await between the canonical grant, this ownership check and the
        // existing bindings/model mutation.
        try present()
        session.query = query.search.text; session.scope = .exact
        session.selectedBookIds = selectedBookIDs; model.setSelectedBooks(selectedBookIDs)
        session.otzariaOrder = query.search.sortOrder == .canonical ? .catalogue : .relevance
        switch query.search.sortOrder {
        case .relevance: session.sefariaSortOrder = .relevance
        case .canonical: session.sefariaSortOrder = .canonical
        case .chronological: session.sefariaSortOrder = .chronological
        }
        session.sefariaReverseSort = false
        // Accepted semantic queries always use the original exact UI mode.
        session.runSearch()
        guard session.submissionRevision == initialSubmission + 1 else {
            throw UIRouteError(.failed, "native_search_submission_not_observed")
        }
        submissionRevision = session.submissionRevision
        submittedConfiguration = session.submittedConfiguration
        try validate()
    }
    func validateCompleted() throws {
        try validate()
        guard submissionRevision != nil, session.hasSubmitted, !session.isSearching, !session.isLoadingMore,
              session.errorMessage == nil, !session.resultsAreDirty else {
            throw UIRouteError(.unavailable, "native_search_results_not_ready")
        }
    }
}

#endif
