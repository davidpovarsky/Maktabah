//
//  StudyWorkspaceNavigationAdapter.swift
//  Maktabah
//
//  Downstream-owned adapter projecting active StudyTabGroup tabs to/from iOSNavigationManager
//  while preserving live ReaderViewModel instances across group and profile switches.
//

import Foundation
import Observation

#if os(iOS)
/// Synchronizes a scene's active `StudyTabGroup` in `StudyWorkspaceStore` with `iOSNavigationManager.openTabs`
/// without requiring invasive changes to `iOSNavigationManager`.
/// Each `StudyWorkspaceSceneCoordinator` owns a dedicated `StudyWorkspaceNavigationAdapter` instance with an
/// isolated `liveViewModelsByTabID` cache so multiple iPad scenes never collide on `ReaderViewModel` instances.
@MainActor
@Observable
final class StudyWorkspaceNavigationAdapter {
    static let shared = StudyWorkspaceNavigationAdapter(sceneID: "default-main-scene")

    let sceneID: String
    private let store: StudyWorkspaceStore
    private var liveViewModelsByTabID: [UUID: ReaderViewModel] = [:]
    private(set) var isApplyingProjection: Bool = false
    private(set) var projectionGeneration: UInt64 = 0

    init(
        sceneID: String = "default-main-scene",
        store: StudyWorkspaceStore? = nil
    ) {
        self.sceneID = sceneID
        self.store = store ?? .shared
    }

    var cachedViewModelCount: Int {
        liveViewModelsByTabID.count
    }

    /// Captures the current live state of `navigationManager.openTabs` into the specified group
    /// before switching groups or persisting.
    /// Does nothing if `studyWorkspaceEnabled` is false (unless `forceWhenDisabled` is true for explicit unit testing)
    /// or if a projection transaction is currently in flight.
    func captureLiveState(
        from navigationManager: iOSNavigationManager,
        intoGroup groupID: UUID? = nil,
        forceWhenDisabled: Bool = false
    ) {
        guard forceWhenDisabled || ChavrusaTextFeatureFlags.shared.effectiveStudyWorkspaceEnabled else { return }
        guard !isApplyingProjection else { return }
        performCaptureLiveState(from: navigationManager, intoGroup: groupID)
    }

    private func performCaptureLiveState(
        from navigationManager: iOSNavigationManager,
        intoGroup groupID: UUID? = nil
    ) {
        let defaultSceneGroupID = store.sceneSelection(for: sceneID).activeGroupID
        let targetGroupID = groupID ?? defaultSceneGroupID
        guard store.group(for: targetGroupID) != nil else { return }

        let activeBackend = BackendCoordinator.shared.activeBackendID
        var syncedTabIDs: [UUID] = []

        for readerTab in navigationManager.openTabs {
            let vm = readerTab.viewModel
            if navigationManager.activeTabId == readerTab.id {
                vm.saveCurrentState()
            }
            liveViewModelsByTabID[readerTab.id] = vm

            let state = vm.readerState
            let locator = vm.currentLocator ?? state.currentLocator ?? readerTab.book.backendLocator
            let resolvedBackend = locator?.backend ?? activeBackend
            let resolvedWorkKey = locator?.workKey ?? readerTab.book.backendLocator?.workKey

            let existing = store.tab(for: readerTab.id)
            let updatedTab = ReaderDocumentTab(
                id: readerTab.id,
                backend: resolvedBackend,
                bookId: readerTab.book.id,
                bookTitle: readerTab.book.title,
                workKey: resolvedWorkKey,
                sectionLocator: locator,
                focusLocator: vm.selectedSegmentLocator,
                contentId: vm.currentID ?? readerTab.initialContentId ?? state.currentID ?? (vm.currentContentId > 0 ? vm.currentContentId : nil),
                page: vm.currentPage ?? state.currentPage,
                part: vm.currentPart ?? state.currentPart,
                scrollPosition: state.scrollPosition ?? vm.fetchScrollPosition?(),
                selectedRange: state.selectedRange ?? vm.fetchSelectedRange?(),
                expandedNodeIDs: state.expandedNodeIDs,
                sidebarScrollPosition: state.sidebarScrollPosition,
                isSidebarCollapsed: state.isSidebarCollapsed,
                searchText: vm.searchText.isEmpty ? nil : vm.searchText,
                searchModeRaw: vm.searchMode?.rawValue,
                nearDistance: vm.nearDistance,
                highlightTerms: vm.highlightTerms,
                isDormantUnavailable: existing?.isDormantUnavailable ?? false,
                createdAt: existing?.createdAt ?? Date(),
                updatedAt: Date()
            )

            if store.tab(for: readerTab.id) != nil {
                store.updateTab(readerTab.id) { tab in
                    tab = updatedTab
                }
            } else {
                store.addTab(updatedTab, toGroup: targetGroupID, activate: navigationManager.activeTabId == readerTab.id)
            }
            syncedTabIDs.append(readerTab.id)
        }

        // Preserve any dormant/unavailable tabs in the group that are not currently active in `openTabs`
        let currentGroupTabs = store.tabs(in: targetGroupID)
        for docTab in currentGroupTabs where docTab.isDormantUnavailable && !syncedTabIDs.contains(docTab.id) {
            syncedTabIDs.append(docTab.id)
        }

        // Remove tabs that were closed via `navigationManager.closeTab`
        for docTab in currentGroupTabs where !docTab.isDormantUnavailable && !syncedTabIDs.contains(docTab.id) {
            store.closeTab(docTab.id, inGroup: targetGroupID)
        }

        if let activeID = navigationManager.activeTabId, syncedTabIDs.contains(activeID) {
            store.setActiveTab(activeID, inGroup: targetGroupID)
        }
    }

    /// Projects the tabs of `targetGroupID` onto `navigationManager.openTabs` in a strict, non-reentrant transaction:
    /// 1. `captureLiveState(previousGroup)`
    /// 2. `projectGroup(nextGroup)`
    /// 3. `resolveActiveTab`
    /// 4. `persist`
    /// If `targetGroupID` is invalid or projection fails, rolls back `navigationManager` to its pre-transaction snapshot.
    @discardableResult
    func projectGroup(
        _ targetGroupID: UUID,
        onto navigationManager: iOSNavigationManager,
        previousGroupID: UUID? = nil,
        forceWhenDisabled: Bool = false
    ) -> Bool {
        guard forceWhenDisabled || ChavrusaTextFeatureFlags.shared.effectiveStudyWorkspaceEnabled else { return false }
        guard !isApplyingProjection else { return false }

        // Snapshot pre-transaction state for rollback safety
        let snapshotOpenTabs = navigationManager.openTabs
        let snapshotActiveTabId = navigationManager.activeTabId
        let snapshotSelectedBook = navigationManager.selectedBook
        let snapshotSelectedContentId = navigationManager.selectedContentId

        guard let targetGroup = store.group(for: targetGroupID) else {
            navigationManager.openTabs = snapshotOpenTabs
            navigationManager.activeTabId = snapshotActiveTabId
            navigationManager.selectedBook = snapshotSelectedBook
            navigationManager.selectedContentId = snapshotSelectedContentId
            return false
        }

        isApplyingProjection = true
        projectionGeneration &+= 1
        defer { isApplyingProjection = false }

        // Step 1: Capture live state of previous group before mutating navigationManager
        if let previousGroupID, previousGroupID != targetGroupID {
            performCaptureLiveState(from: navigationManager, intoGroup: previousGroupID)
        }

        // Step 2: Update scene selection for this sceneID and build projected tabs
        store.updateSceneSelection(
            StudySceneSelectionState(
                sceneID: sceneID,
                activeProfileID: targetGroup.profileID,
                activeGroupID: targetGroup.id,
                isOverviewPresented: store.sceneStatesByID[sceneID]?.isOverviewPresented ?? false,
                updatedAt: Date()
            )
        )
        let groupTabs = store.tabs(in: targetGroupID)
        let activeBackend = BackendCoordinator.shared.activeBackendID
        let ldm = LibraryDataManager.shared

        var projectedTabs: [iOSNavigationManager.ReaderTab] = []

        for docTab in groupTabs {
            // If the tab belongs to a different backend, keep it safely in the group as dormant
            // rather than injecting a foreign locator into the active backend's reader list.
            if docTab.backend != activeBackend {
                store.setTabDormantUnavailable(docTab.id, isDormant: true)
                continue
            }

            let resolvedBook = ldm.booksById[docTab.bookId]
                ?? (docTab.sectionLocator.flatMap { loc in ldm.booksById.values.first(where: { $0.backendLocator?.workKey == loc.workKey }) })
                ?? ldm.getBook([docTab.bookId]).first

            let book: BooksData
            if let resolvedBook {
                book = resolvedBook
                if docTab.isDormantUnavailable {
                    store.setTabDormantUnavailable(docTab.id, isDormant: false)
                }
            } else {
                // Keep tab resiliently with a placeholder BooksData and mark dormant flag if book catalog is missing it
                let fallbackLocator = docTab.sectionLocator
                    ?? docTab.workKey.map { TextLocator(backend: docTab.backend, workKey: $0, position: .legacyLine(0)) }
                book = BooksData(
                    id: docTab.bookId,
                    title: docTab.bookTitle ?? "ספר \(docTab.bookId)",
                    backendLocator: fallbackLocator
                )
            }

            let vm: ReaderViewModel
            if let cachedVM = liveViewModelsByTabID[docTab.id] {
                vm = cachedVM
                vm.currentBook = book
            } else if let existingOpen = navigationManager.openTabs.first(where: { $0.id == docTab.id }) {
                vm = existingOpen.viewModel
                liveViewModelsByTabID[docTab.id] = vm
            } else {
                let newVM = ReaderViewModel(book: book)
                newVM.recordHistory = false
                newVM.needsScrollRestore = true
                if let pos = docTab.scrollPosition { newVM.readerState.scrollPosition = pos }
                if let range = docTab.selectedRange { newVM.readerState.selectedRange = range }
                if let exp = docTab.expandedNodeIDs { newVM.readerState.expandedNodeIDs = exp }
                if let col = docTab.isSidebarCollapsed { newVM.readerState.isSidebarCollapsed = col }
                if let sidePos = docTab.sidebarScrollPosition { newVM.readerState.sidebarScrollPosition = sidePos }
                if let search = docTab.searchText { newVM.searchText = search }
                if let modeRaw = docTab.searchModeRaw, let mode = SearchMode(rawValue: modeRaw) { newVM.searchMode = mode }
                if let near = docTab.nearDistance { newVM.nearDistance = near }
                if let terms = docTab.highlightTerms { newVM.highlightTerms = terms }

                if let locator = docTab.sectionLocator {
                    newVM.loadBackendContent(locator)
                } else if let contentId = docTab.contentId {
                    newVM.loadInitialContent(initialContentId: contentId)
                } else {
                    newVM.loadInitialContent(initialContentId: nil)
                }
                newVM.loadTOC(book: book)
                liveViewModelsByTabID[docTab.id] = newVM
                vm = newVM
            }

            projectedTabs.append(
                iOSNavigationManager.ReaderTab(
                    id: docTab.id,
                    book: book,
                    initialContentId: docTab.contentId,
                    viewModel: vm
                )
            )
        }

        // Step 3: Resolve active tab and commit to navigationManager
        navigationManager.openTabs = projectedTabs
        let targetActiveID = store.group(for: targetGroupID)?.activeTabID
        let resolution = ReaderSessionRestoreCoordinator().resolveActiveTab(
            savedActiveId: targetActiveID,
            restoredTabs: projectedTabs
        )
        navigationManager.activeTabId = resolution.activeTabId
        if let activeTab = resolution.activeTab {
            navigationManager.selectedBook = activeTab.book
            navigationManager.selectedContentId = activeTab.initialContentId ?? activeTab.viewModel.currentContentId
            store.setActiveTab(activeTab.id, inGroup: targetGroupID)
        } else {
            navigationManager.selectedBook = nil
            navigationManager.selectedContentId = nil
        }

        // Step 4: Persist session
        navigationManager.persistCurrentSession(immediate: false)
        store.scheduleSave()
        return true
    }

    /// Opens a fresh independent document tab for `book` in the scene's active group even if another tab for the same book exists.
    @discardableResult
    func openIndependentTab(
        for book: BooksData,
        in navigationManager: iOSNavigationManager,
        groupID: UUID? = nil,
        contentId: Int? = nil,
        sectionLocator: TextLocator? = nil
    ) -> ReaderDocumentTab {
        let activeBackend = book.backendLocator?.backend ?? BackendCoordinator.shared.activeBackendID
        let targetGroupID = groupID ?? store.sceneSelection(for: sceneID).activeGroupID
        let docTab = ReaderDocumentTab(
            id: UUID(),
            backend: activeBackend,
            bookId: book.id,
            bookTitle: book.title,
            workKey: book.backendLocator?.workKey,
            sectionLocator: sectionLocator ?? book.backendLocator,
            contentId: contentId
        )

        let vm = ReaderViewModel(book: book)
        if let locator = docTab.sectionLocator {
            vm.loadBackendContent(locator)
        } else {
            vm.loadInitialContent(initialContentId: contentId)
        }
        vm.loadTOC(book: book)
        liveViewModelsByTabID[docTab.id] = vm

        if ChavrusaTextFeatureFlags.shared.effectiveStudyWorkspaceEnabled {
            store.addTab(docTab, toGroup: targetGroupID, activate: true)
        }
        let readerTab = iOSNavigationManager.ReaderTab(
            id: docTab.id,
            book: book,
            initialContentId: contentId,
            viewModel: vm
        )
        navigationManager.openTabs.append(readerTab)
        navigationManager.activeTabId = readerTab.id
        navigationManager.selectedBook = book
        navigationManager.selectedContentId = contentId ?? vm.currentContentId
        navigationManager.persistCurrentSession(immediate: false)
        return docTab
    }
}
#endif
