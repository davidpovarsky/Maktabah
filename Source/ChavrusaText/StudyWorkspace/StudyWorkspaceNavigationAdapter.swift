import SwiftUI

/// Projects saved groups through the existing navigation/backend coordinators.
/// Retains existing tab objects in memory; only cold, inactive tabs need hydration.
@MainActor @Observable
final class StudyWorkspaceNavigationAdapter {
    let sceneID: String
    let store: StudyWorkspaceStore
    private(set) var attached = false
    private(set) var isSwitching = false
    var errorMessage: String?
    private var liveGroupID: UUID?
    private var liveBackend: BackendID?
    private var cache: [UUID: [BackendID: [iOSNavigationManager.ReaderTab]]] = [:]

    init(sceneID: String, store: StudyWorkspaceStore = .shared) {
        self.sceneID = sceneID
        self.store = store
    }

    var selection: StudySceneSelection? { store.snapshot?.scenes[sceneID] }
    var group: StudyTabGroup? { store.selectedGroup(scene: sceneID) }
    var profile: StudyProfile? { store.snapshot?.profiles.first { $0.id == selection?.profileID } }
    var groups: [StudyTabGroup] {
        (store.snapshot?.groups.filter { $0.profileID == selection?.profileID } ?? []).sorted { $0.order < $1.order }
    }

    func attach(_ manager: iOSNavigationManager) async {
        guard !attached else { return }
        do {
            let backend = BackendCoordinator.shared.activeBackendID
            try store.attach(scene: sceneID, legacyTabs: capture(manager.openTabs, backend: backend), activeID: manager.activeTabId)
            attached = true
            if let selected = group, !selected.tabs.isEmpty {
                // Restore the sidecar's selected group; never import the canonical session twice.
                try await switchGroup(to: selected.id, manager: manager)
            } else {
                liveGroupID = group?.id
                liveBackend = backend
                if let id = liveGroupID { cache[id, default: [:]][backend] = manager.openTabs }
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func synchronize(_ manager: iOSNavigationManager) {
        guard attached, !isSwitching, let id = liveGroupID, let backend = liveBackend else { return }
        do {
            let currentBackend = BackendCoordinator.shared.activeBackendID
            // A backend switch publishes fresh tabs. Capture retained outgoing instances first.
            let outgoing = currentBackend == backend ? manager.openTabs : (cache[id]?[backend] ?? [])
            try persistProjection(outgoing, activeID: currentBackend == backend ? manager.activeTabId : nil, groupID: id, backend: backend)
            liveBackend = currentBackend
            cache[id, default: [:]][currentBackend] = manager.openTabs
            if currentBackend != backend {
                try persistProjection(manager.openTabs, activeID: manager.activeTabId, groupID: id, backend: currentBackend)
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func reconcileSceneSelection(_ manager: iOSNavigationManager) async {
        guard attached, !isSwitching, let id = selection?.groupID, id != liveGroupID else { return }
        do { try await switchGroup(to: id, manager: manager) }
        catch { errorMessage = error.localizedDescription }
    }

    func switchGroup(to id: UUID, documentID: UUID? = nil, manager: iOSNavigationManager) async throws {
        guard !isSwitching, store.snapshot?.groups.contains(where: { $0.id == id }) == true else { throw StudyWorkspaceError.invalidMembership }
        isSwitching = true
        defer { isSwitching = false }
        let previousTabs = manager.openTabs
        let previousActive = manager.activeTabId
        let previousBackend = BackendCoordinator.shared.activeBackendID
        let previousGroup = liveGroupID
        if let previousGroup, store.snapshot?.groups.contains(where: { $0.id == previousGroup }) == true {
            try persistProjection(previousTabs, activeID: previousActive, groupID: previousGroup, backend: previousBackend)
            cache[previousGroup, default: [:]][previousBackend] = previousTabs
        }
        guard let target = store.snapshot?.groups.first(where: { $0.id == id }) else { throw StudyWorkspaceError.invalidMembership }
        let requested = documentID ?? selection?.activeTabIDsByGroup?[id] ?? target.activeTabID
        let desiredBackend = target.tabs.first(where: { $0.id == requested })?.backend ?? previousBackend
        let documents = target.tabs.filter { $0.backend == desiredBackend }
        let retained = cache[id]?[desiredBackend] ?? []
        // Resolve every book before mutating either coordinator; no partial group publication.
        let staged: [iOSNavigationManager.ReaderTab] = try documents.map { document in
            if let existing = retained.first(where: { $0.id == document.id }) { return existing }
            if let existing = previousTabs.first(where: { $0.id == document.id }), previousBackend == desiredBackend { return existing }
            return try hydrate(document)
        }
        do {
            if desiredBackend != previousBackend {
                try await BackendCoordinator.shared.commitCheckedAsync(desiredBackend)
                guard BackendCoordinator.shared.activeBackendID == desiredBackend else { throw StudyWorkspaceError.backendMismatch }
            }
            try store.transaction { value in
                guard let current = value.groups.first(where: { $0.id == id }), current.tabs == target.tabs,
                      current.profileID == target.profileID else { throw StudyWorkspaceError.invalidMembership }
                var scene = value.scenes[sceneID] ?? .init(profileID: target.profileID, groupID: id)
                scene.profileID = target.profileID
                scene.groupID = id
                var activeIDs = scene.activeTabIDsByGroup ?? [:]
                if let active = staged.first(where: { $0.id == requested }) ?? staged.first { activeIDs[id] = active.id }
                else { activeIDs.removeValue(forKey: id) }
                scene.activeTabIDsByGroup = activeIDs
                value.scenes[sceneID] = scene
            }
            manager.openTabs = staged
            for document in documents {
                guard let tab = staged.first(where: { $0.id == document.id }), tab.viewModel.contentText.isEmpty else { continue }
                if let locator = document.session.locator {
                    tab.viewModel.loadBackendContent(locator)
                } else {
                    tab.viewModel.loadInitialContent(initialContentId: document.session.contentId)
                }
                tab.viewModel.loadTOC(book: tab.book)
            }
            if let active = requested.flatMap({ id in staged.first { $0.id == id } }) ?? staged.first {
                manager.selectTab(id: active.id)
                active.viewModel.needsScrollRestore = true
            } else {
                // Use the canonical close path to normalize an empty projection.
                manager.openTabs = previousTabs
                for tab in previousTabs { manager.closeTab(id: tab.id) }
            }
            liveGroupID = id
            liveBackend = desiredBackend
            cache[id, default: [:]][desiredBackend] = staged
            manager.persistCurrentSession(immediate: true)
        } catch {
            if BackendCoordinator.shared.activeBackendID != previousBackend {
                do { try await BackendCoordinator.shared.commitCheckedAsync(previousBackend) }
                catch { errorMessage = "לא ניתן לשחזר את מקור הספרייה: \(error.localizedDescription)" }
            }
            manager.openTabs = previousTabs
            if let previousActive { manager.selectTab(id: previousActive) }
            manager.persistCurrentSession(immediate: true)
            throw error
        }
    }

    func moveTab(_ id: UUID, to targetID: UUID, copy: Bool, manager: iOSNavigationManager) {
        synchronize(manager)
        guard let sourceID = liveGroupID, sourceID != targetID else { return }
        do {
            try store.transaction { value in
                guard let source = value.groups.firstIndex(where: { $0.id == sourceID }),
                      let target = value.groups.firstIndex(where: { $0.id == targetID }),
                      let tab = value.groups[source].tabs.first(where: { $0.id == id }) else { throw StudyWorkspaceError.invalidMembership }
                value.groups[target].tabs.append(copy ? tab.reidentified() : tab)
                if !copy {
                    value.groups[source].tabs.removeAll { $0.id == id }
                    if value.groups[source].activeTabID == id { value.groups[source].activeTabID = value.groups[source].tabs.first?.id }
                }
            }
            if !copy { manager.closeTab(id: id) }
        } catch { errorMessage = error.localizedDescription }
    }

    func reorder(_ id: UUID, to index: Int, manager: iOSNavigationManager) {
        guard let old = manager.openTabs.firstIndex(where: { $0.id == id }), manager.openTabs.indices.contains(index) else { return }
        manager.openTabs.insert(manager.openTabs.remove(at: old), at: index)
        manager.persistCurrentSession(immediate: true)
        synchronize(manager)
    }

    func createGroup(name: String, fromCurrent: Bool, manager: iOSNavigationManager) async {
        synchronize(manager)
        guard let profileID = selection?.profileID else { return }
        do {
            let tabs = fromCurrent ? (group?.tabs ?? []).map { $0.reidentified() } : []
            let id = try store.addGroup(profileID: profileID, name: name, tabs: tabs, activeID: tabs.first?.id)
            try await switchGroup(to: id, manager: manager)
        } catch { errorMessage = error.localizedDescription }
    }

    private func persistProjection(_ tabs: [iOSNavigationManager.ReaderTab], activeID: UUID?, groupID: UUID, backend: BackendID) throws {
        guard let saved = store.snapshot?.groups.first(where: { $0.id == groupID }) else { throw StudyWorkspaceError.invalidMembership }
        let foreign = saved.tabs.filter { $0.backend != backend }
        let merged = foreign + capture(tabs, backend: backend)
        try store.transaction { value in
            guard let index = value.groups.firstIndex(where: { $0.id == groupID }) else { throw StudyWorkspaceError.invalidMembership }
            value.groups[index].tabs = merged
            value.groups[index].activeTabID = (activeID ?? saved.activeTabID).flatMap { id in merged.contains { $0.id == id } ? id : nil }
            if var scene = value.scenes[sceneID] {
                var activeIDs = scene.activeTabIDsByGroup ?? [:]
                if let activeID, merged.contains(where: { $0.id == activeID }) { activeIDs[groupID] = activeID }
                else if merged.isEmpty { activeIDs.removeValue(forKey: groupID) }
                scene.activeTabIDsByGroup = activeIDs
                value.scenes[sceneID] = scene
            }
        }
        cache[groupID, default: [:]][backend] = tabs
    }

    private func capture(_ tabs: [iOSNavigationManager.ReaderTab], backend: BackendID) -> [ReaderDocumentTab] {
        tabs.map { tab in
            let vm = tab.viewModel
            var state = vm.readerState
            state.scrollPosition = vm.fetchScrollPosition?() ?? state.scrollPosition
            state.selectedRange = vm.fetchSelectedRange?() ?? state.selectedRange
            return ReaderDocumentTab(backend: backend, session: .init(
                id: tab.id, bookId: tab.book.id, bookTitle: tab.book.title, backendLocator: tab.book.backendLocator,
                contentId: vm.currentID ?? tab.initialContentId ?? state.currentID, locator: vm.currentLocator ?? state.currentLocator,
                page: vm.currentPage ?? state.currentPage, part: vm.currentPart ?? state.currentPart,
                scrollPosition: state.scrollPosition, selectedRange: state.selectedRange, expandedNodeIDs: state.expandedNodeIDs,
                sidebarScrollPosition: state.sidebarScrollPosition, isSidebarCollapsed: state.isSidebarCollapsed,
                searchText: vm.searchText, searchModeRaw: vm.searchMode?.rawValue, nearDistance: vm.nearDistance,
                highlightTerms: vm.highlightTerms))
        }
    }

    private func hydrate(_ document: ReaderDocumentTab) throws -> iOSNavigationManager.ReaderTab {
        let state = document.session
        let book = try ChavrusaTextTargetBackendBookResolver.shared.resolveBook(
            id: state.bookId, backendLocator: state.backendLocator?.workKey,
            title: state.bookTitle, in: document.backend)
        let vm = ReaderViewModel(book: book)
        vm.recordHistory = false
        vm.readerState.scrollPosition = state.scrollPosition
        vm.readerState.selectedRange = state.selectedRange
        vm.readerState.expandedNodeIDs = state.expandedNodeIDs ?? []
        vm.readerState.sidebarScrollPosition = state.sidebarScrollPosition
        vm.readerState.isSidebarCollapsed = state.isSidebarCollapsed ?? false
        vm.readerState.currentLocator = state.locator
        vm.readerState.currentPage = state.page
        vm.readerState.currentPart = state.part
        vm.searchText = state.searchText ?? ""
        vm.searchMode = state.searchModeRaw.flatMap(SearchMode.init(rawValue:))
        vm.nearDistance = state.nearDistance ?? 10
        vm.highlightTerms = state.highlightTerms
        vm.needsScrollRestore = true
        // Loading is deferred until this tab becomes live, after any backend commit.
        return .init(id: state.id, book: book, initialContentId: state.contentId, viewModel: vm)
    }
}

extension ReaderDocumentTab {
    func reidentified() -> ReaderDocumentTab {
        let s = session
        return .init(backend: backend, session: .init(
            id: UUID(), bookId: s.bookId, bookTitle: s.bookTitle, backendLocator: s.backendLocator,
            contentId: s.contentId, locator: s.locator, page: s.page, part: s.part, scrollPosition: s.scrollPosition,
            selectedRange: s.selectedRange, expandedNodeIDs: s.expandedNodeIDs, sidebarScrollPosition: s.sidebarScrollPosition,
            isSidebarCollapsed: s.isSidebarCollapsed, searchText: s.searchText, searchModeRaw: s.searchModeRaw,
            nearDistance: s.nearDistance, highlightTerms: s.highlightTerms))
    }
}
