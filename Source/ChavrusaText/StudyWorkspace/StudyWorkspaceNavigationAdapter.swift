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
    private var checkpointTask: Task<Void, Never>?
    private var cache: [UUID: [BackendID: [iOSNavigationManager.ReaderTab]]] = [:]

    init(sceneID: String, store: StudyWorkspaceStore = .shared) {
        self.sceneID = sceneID
        self.store = store
    }

    // MARK: Native mapping producer

    /// Unavailable until the exact native initialization/setter/lifetime hooks
    /// are installed. Store-only checkpoints never imply native coverage.
    let mappingOwnershipSource = StudyWorkspaceMappingSource(available: false)
    @ObservationIgnored private weak var mappingManager: iOSNavigationManager?
    @ObservationIgnored private var mappingOwnerID: ObjectIdentifier?
    @ObservationIgnored private var mappingSubscription: StudyWorkspaceMappingSubscription?
    @ObservationIgnored private var readerReservation: StudyWorkspaceNativeReaderReservation?
    @ObservationIgnored private var reservedCheckpoint: StudyWorkspaceNativeReaderReservation?
    private final class WeakMappingAdapter {
        weak var value: StudyWorkspaceNavigationAdapter?
        init(_ value: StudyWorkspaceNavigationAdapter) { self.value = value }
    }
    private final class WeakMappingManager {
        weak var value: iOSNavigationManager?
        init(_ value: iOSNavigationManager) { self.value = value }
    }
    private static var mappingAdapters: [ObjectIdentifier: WeakMappingAdapter] = [:]
    private static var mappingHookOwners: [ObjectIdentifier: WeakMappingManager] = [:]

    isolated deinit {
        mappingSubscription?.cancel()
        mappingOwnershipSource.retire()
        Self.mappingAdapters.removeValue(forKey: ObjectIdentifier(self))
    }

    func mappingOwnershipObservation() -> StudyWorkspaceMappingObservation? {
        guard readerReservation?.policy.isPublishing != true,
              let manager = mappingManager, let epoch = mappingOwnershipSource.event.epoch,
              let projection = currentMappingProjection(manager) else { return nil }
        return .init(source: mappingOwnershipSource, owner: ObjectIdentifier(manager), scene: sceneID, epoch: epoch,
            coverage: .liveNativeSetters, projection: projection)
    }

    private func bindMappingOwner(_ manager: iOSNavigationManager) {
        guard mappingManager == nil else { return }
        mappingManager = manager
        mappingOwnerID = ObjectIdentifier(manager)
        Self.mappingAdapters = Self.mappingAdapters.filter { $0.value.value != nil }
        Self.mappingAdapters[ObjectIdentifier(self)] = .init(self)
        mappingSubscription = store.mappingSource(scene: sceneID).subscribe(owner: self) { adapter, event in
            if (event.reasons.contains(.ownerLifetime) || event.reasons.contains(.epochExhausted)) && event.phase == .unavailable {
                adapter.mappingOwnershipSource.retire()
            } else if event.phase == .changing {
                // Only the exact already committed native reservation's own
                // normal checkpoint preserves this native owner epoch.
                if let checkpoint = adapter.reservedCheckpoint,
                   checkpoint === adapter.readerReservation,
                   checkpoint.policy.phase == .committed,
                   checkpoint.policy.epoch == adapter.mappingOwnershipSource.event.epoch { return }
                adapter.readerReservation?.policy.invalidate()
                adapter.mappingOwnershipSource.beginChange(event.reasons)
            } else {
                adapter.finishMappingPublication()
            }
        }
    }

    private func currentMappingProjection(_ manager: iOSNavigationManager) -> StudyWorkspaceMappingProjection? {
        mappingProjection(manager, tabs: manager.openTabs, activeID: manager.activeTabId,
            groupID: liveGroupID, backend: liveBackend)
    }

    private func mappingProjection(_ manager: iOSNavigationManager, tabs: [iOSNavigationManager.ReaderTab],
                                   activeID: UUID?, groupID: UUID?, backend: BackendID?) -> StudyWorkspaceMappingProjection? {
        guard attached, mappingManager === manager,
              Self.mappingHookOwners[ObjectIdentifier(manager)]?.value === manager,
              store.mappingSource(scene: sceneID).mappingRevision != nil,
              backend == BackendCoordinator.shared.activeBackendID else { return nil }
        return StudyWorkspaceMappingPolicy.native(
            workspace: StudyWorkspaceMappingPolicy.workspace(store.snapshot, scene: sceneID),
            groupID: groupID, backend: backend, tabs: mappingTabs(tabs), activeID: activeID)
    }

    private func mappingTabs(_ tabs: [iOSNavigationManager.ReaderTab]) -> [StudyWorkspaceNativeMappingTab] {
        tabs.map { tab in
            StudyWorkspaceNativeMappingTab(id: tab.id, target: .init(
                backend: tab.book.backendLocator?.backend ?? BackendCoordinator.shared.activeBackendID,
                bookID: tab.book.id, workKey: tab.book.backendLocator?.workKey,
                readerOwner: ObjectIdentifier(tab.viewModel)))
        }
    }

    private func setMappingLiveContext(groupID: UUID, backend: BackendID, manager: iOSNavigationManager) {
        let before = currentMappingProjection(manager)
        let after = mappingProjection(manager, tabs: manager.openTabs, activeID: manager.activeTabId,
            groupID: groupID, backend: backend)
        mappingOwnershipSource.beginChange(StudyWorkspaceMappingPolicy.changes(from: before, to: after))
        liveGroupID = groupID
        liveBackend = backend
        finishMappingPublication()
    }

    private func finishMappingPublication() {
        mappingOwnershipSource.finishChange(available: mappingManager.flatMap(currentMappingProjection) != nil)
    }

    /// These entry points have no effect without a registered actual adapter.
    /// The companion exact upstream patch remains UNAPPLIED in R's worktree.
    static func nativeMappingOwnerInitialized(_ manager: iOSNavigationManager) {
        mappingHookOwners = mappingHookOwners.filter { $0.value.value != nil }
        mappingHookOwners[ObjectIdentifier(manager)] = .init(manager)
    }

    static func nativeMappingOwnerWillDeinitialize(_ manager: iOSNavigationManager) {
        for adapter in mappingAdapters.values.compactMap(\.value) where adapter.mappingOwnerID == ObjectIdentifier(manager) {
            adapter.mappingOwnershipSource.retire()
            adapter.mappingSubscription?.cancel()
        }
        mappingHookOwners.removeValue(forKey: ObjectIdentifier(manager))
    }

    private static func withMappingAdapters(_ manager: iOSNavigationManager, _ update: (StudyWorkspaceNavigationAdapter) -> Void) {
        mappingAdapters = mappingAdapters.filter { $0.value.value != nil }
        for adapter in mappingAdapters.values.compactMap(\.value) where adapter.mappingManager === manager { update(adapter) }
    }

    static func nativeMappingTabsWillChange(_ manager: iOSNavigationManager, to tabs: [iOSNavigationManager.ReaderTab]) {
        withMappingAdapters(manager) { adapter in
            let before = adapter.currentMappingProjection(manager)
            let after = adapter.mappingProjection(manager, tabs: tabs, activeID: manager.activeTabId,
                groupID: adapter.liveGroupID, backend: adapter.liveBackend)
            let reasons = StudyWorkspaceMappingPolicy.changes(from: before, to: after)
                .union(StudyWorkspaceMappingPolicy.nativeTargetChanges(from: adapter.mappingTabs(manager.openTabs), to: adapter.mappingTabs(tabs)))
            guard !reasons.isEmpty else { return }
            if let reservation = adapter.readerReservation,
               reservation.policy.permitsTabsPublication(from: before, to: after) { return }
            adapter.mappingOwnershipSource.beginChange(reasons)
        }
    }

    static func nativeMappingSelectionWillChange(_ manager: iOSNavigationManager, to activeID: UUID?) {
        withMappingAdapters(manager) { adapter in
            let before = adapter.currentMappingProjection(manager)
            let after = adapter.mappingProjection(manager, tabs: manager.openTabs, activeID: activeID,
                groupID: adapter.liveGroupID, backend: adapter.liveBackend)
            var reasons = StudyWorkspaceMappingPolicy.changes(from: before, to: after)
            if manager.activeTabId != activeID { reasons.insert(.selection) }
            guard !reasons.isEmpty else { return }
            if let reservation = adapter.readerReservation,
               reservation.policy.permitsSelectionPublication(from: before, to: after) { return }
            adapter.mappingOwnershipSource.beginChange(reasons)
        }
    }

    static func nativeMappingDidChange(_ manager: iOSNavigationManager) {
        withMappingAdapters(manager) { adapter in
            if let reservation = adapter.readerReservation, reservation.policy.isPublishing,
               !reservation.policy.didPublish(actual: adapter.currentMappingProjection(manager)) {
                adapter.mappingOwnershipSource.beginChange([.readerReservation])
            }
            adapter.finishMappingPublication()
        }
    }

    // MARK: Original native reader ownership

    /// Reserves an original ReaderTab/ReaderViewModel before Core admission.
    /// This does not load, select, persist or authorize content.
    func reserveNativeReader(requestID: UUID, book: BooksData, destination: LibraryReaderDestination,
                             manager: iOSNavigationManager) throws -> StudyWorkspaceNativeReaderReservation {
        guard attached, !isSwitching, mappingManager === manager, readerReservation == nil,
              mappingOwnershipObservation() != nil,
              book.backendLocator?.backend == destination.sectionLocator.backend,
              book.backendLocator?.workKey == destination.sectionLocator.workKey,
              destination.sectionLocator.backend == BackendCoordinator.shared.activeBackendID else {
            throw StudyWorkspaceError.invalidMembership
        }
        let tab = iOSNavigationManager.ReaderTab(id: UUID(), book: book,
            initialContentId: LegacyIdentityRegistry.shared.id(for: destination.sectionLocator),
            viewModel: ReaderViewModel(book: book))
        // A reservation changes the native mapping contract, so invalidate
        // any prior context before the caller can admit this request.
        mappingOwnershipSource.beginChange([.readerReservation])
        finishMappingPublication()
        guard let actual = mappingOwnershipObservation(),
              let saved = StudyWorkspaceMappingPolicy.workspace(store.snapshot, scene: sceneID),
              let target = mappingTabs([tab]).first else { throw StudyWorkspaceError.invalidMembership }
        let policy = try StudyWorkspaceReaderReservation(requestID: requestID, observation: actual,
            workspace: saved, target: target)
        let reservation = StudyWorkspaceNativeReaderReservation(policy: policy, tab: tab)
        readerReservation = reservation
        return reservation
    }

    func reservedNativeReader(requestID: UUID) throws -> StudyWorkspaceNativeReaderReservation {
        guard let reservation = readerReservation, reservation.policy.requestID == requestID else {
            throw StudyWorkspaceError.invalidMembership
        }
        try validateNativeReader(reservation)
        return reservation
    }

    func validateNativeReader(_ reservation: StudyWorkspaceNativeReaderReservation) throws {
        guard attached, !isSwitching, readerReservation === reservation,
              let actual = mappingOwnershipObservation(), reservation.policy.matches(actual) else {
            throw StudyWorkspaceError.invalidMembership
        }
    }

    func applyNativeReader(_ reservation: StudyWorkspaceNativeReaderReservation, operation: () throws -> Void) throws {
        try validateNativeReader(reservation)
        guard let before = mappingOwnershipObservation() else { throw StudyWorkspaceError.invalidMembership }
        do {
            try reservation.policy.beginApply(before)
            try operation()
            guard let actual = mappingOwnershipObservation() else { throw StudyWorkspaceError.invalidMembership }
            try reservation.policy.finishApply(actual)
        } catch {
            reservation.policy.invalidate()
            mappingOwnershipSource.beginChange([.readerReservation])
            finishMappingPublication()
            throw error
        }
    }

    func hasCommittedNativeReader(tabID: UUID) -> Bool {
        guard let reservation = readerReservation, reservation.tab.id == tabID,
              reservation.policy.phase == .committed,
              let actual = mappingOwnershipObservation() else { return false }
        return reservation.policy.matches(actual)
    }

    func releaseNativeReader(_ reservation: StudyWorkspaceNativeReaderReservation) {
        guard readerReservation === reservation else { return }
        reservation.policy.release()
        readerReservation = nil
        // Never remove a tab or undo user state, including a partially applied
        // command. The original orchestrator records uncertain native effects.
        mappingOwnershipSource.beginChange([.readerReservation])
        finishMappingPublication()
    }

    // MARK: Workspace presentation

    var selection: StudySceneSelection? { store.snapshot?.scenes[sceneID] }
    var group: StudyTabGroup? { store.selectedGroup(scene: sceneID) }
    var activeDocumentID: UUID? {
        guard let group else { return nil }
        return StudyWorkspaceProjectionPolicy.activeDocumentID(in: group, selection: selection)
    }
    var profile: StudyProfile? { store.snapshot?.profiles.first { $0.id == selection?.profileID } }
    var groups: [StudyTabGroup] {
        (store.snapshot?.groups.filter { $0.profileID == selection?.profileID } ?? []).sorted { $0.order < $1.order }
    }

    func attach(_ manager: iOSNavigationManager) async {
        guard !attached else { return }
        bindMappingOwner(manager)
        do {
            let backend = BackendCoordinator.shared.activeBackendID
            try store.attach(scene: sceneID, legacyTabs: capture(manager.openTabs, backend: backend), activeID: manager.activeTabId)
            attached = true
            if let selected = group {
                // Restore the sidecar's selected group; never import the canonical session twice.
                try await switchGroup(to: selected.id, manager: manager, restoringBackend: backend)
            } else { throw StudyWorkspaceError.invalidMembership }
        } catch { errorMessage = error.localizedDescription }
    }

    func synchronize(_ manager: iOSNavigationManager) {
        guard attached, !isSwitching, let id = liveGroupID, let backend = liveBackend else { return }
        checkpointTask?.cancel()
        checkpointTask = nil
        let retainedGroupIDs = Set(store.snapshot?.groups.map(\.id) ?? [])
        cache = cache.filter { retainedGroupIDs.contains($0.key) }
        do {
            let currentBackend = BackendCoordinator.shared.activeBackendID
            // A backend switch publishes fresh tabs. Capture retained outgoing instances first.
            let outgoing = currentBackend == backend ? manager.openTabs : (cache[id]?[backend] ?? [])
            try persistProjection(outgoing, activeID: currentBackend == backend ? manager.activeTabId : nil, groupID: id, backend: backend)
            setMappingLiveContext(groupID: id, backend: currentBackend, manager: manager)
            cache[id, default: [:]][currentBackend] = manager.openTabs
            if currentBackend != backend {
                try persistProjection(manager.openTabs, activeID: manager.activeTabId, groupID: id, backend: currentBackend)
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func scheduleCheckpoint(_ manager: iOSNavigationManager) {
        guard attached, !isSwitching else { return }
        checkpointTask?.cancel()
        checkpointTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(300)) }
            catch { return }
            guard !Task.isCancelled else { return }
            self?.synchronize(manager)
        }
    }

    func reconcileSceneSelection(_ manager: iOSNavigationManager) async {
        guard attached, !isSwitching, let id = selection?.groupID, id != liveGroupID else { return }
        do { try await switchGroup(to: id, manager: manager) }
        catch { errorMessage = error.localizedDescription }
    }

    func switchGroup(to id: UUID, documentID: UUID? = nil, manager: iOSNavigationManager, restoringBackend: BackendID? = nil) async throws {
        guard !isSwitching, store.snapshot?.groups.contains(where: { $0.id == id }) == true else { throw StudyWorkspaceError.invalidMembership }
        isSwitching = true
        defer { isSwitching = false }
        let previousTabs = manager.openTabs
        let previousActive = manager.activeTabId
        let previousBackend = BackendCoordinator.shared.activeBackendID
        let previousGroup = liveGroupID
        let previousGeneration = BackendCoordinator.shared.generation
        let previousSelection = selection
        guard let target = store.snapshot?.groups.first(where: { $0.id == id }) else { throw StudyWorkspaceError.invalidMembership }
        var requested = documentID ?? selection?.activeTabIDsByGroup?[id] ?? target.activeTabID
        let desiredBackend = StudyWorkspaceProjectionPolicy.backend(restoring: restoringBackend, requestedID: requested,
                                                                   documents: target.tabs, fallback: previousBackend)
        let documents = target.tabs.filter { $0.backend == desiredBackend }
        let retained = cache[id]?[desiredBackend] ?? []
        try await ChavrusaTextTargetBackendBookResolver.shared.withTargetCatalog(in: desiredBackend) {
            guard BackendCoordinator.shared.activeBackendID == previousBackend,
                  BackendCoordinator.shared.generation == previousGeneration else {
                throw BackendTransitionError.transitionSuperseded
            }
            // Every document is resolved against the target catalog while the
            // outgoing reader and committed backend are still intact.
            var staged: [iOSNavigationManager.ReaderTab] = try documents.map { document in
                let resolved = try ChavrusaTextTargetBackendBookResolver.shared.resolveBook(
                    id: document.session.bookId,
                    backendLocator: document.session.backendLocator?.workKey ?? document.session.locator?.workKey,
                    title: document.session.bookTitle, in: document.backend)
                if let existing = retained.first(where: { $0.id == document.id }), matches(existing, document),
                   existing.book.backendLocator?.workKey == resolved.backendLocator?.workKey { return existing }
                if previousBackend == desiredBackend,
                   let existing = previousTabs.first(where: { $0.id == document.id }), matches(existing, document),
                   existing.book.backendLocator?.workKey == resolved.backendLocator?.workKey { return existing }
                return try hydrate(document)
            }
            try await BackendCoordinator.shared.commitCheckedAsync(desiredBackend, beforeCommit: {
                var startupDocuments: [ReaderDocumentTab]?
                if restoringBackend != nil, previousGroup == nil {
                    try Task.checkCancellation()
                    guard BackendCoordinator.shared.activeBackendID == previousBackend,
                          BackendCoordinator.shared.generation == previousGeneration else {
                        throw BackendTransitionError.transitionSuperseded
                    }
                    guard selection == previousSelection else { throw StudyWorkspaceError.invalidMembership }
                    // A native open can finish while the initial empty restore awaits
                    // its catalog/backend. Adopt those live instances at the last
                    // throwing boundary, before publication can overwrite them.
                    if previousTabs.isEmpty, target.tabs.isEmpty, desiredBackend == previousBackend,
                       !manager.openTabs.isEmpty {
                        staged = manager.openTabs
                        requested = manager.activeTabId
                        startupDocuments = capture(staged, backend: desiredBackend)
                    }
                }
                let outgoingDocuments = capture(previousTabs, backend: previousBackend)
                try store.transaction { value in
                    guard let current = value.groups.first(where: { $0.id == id }), current.tabs == target.tabs,
                          current.profileID == target.profileID else { throw StudyWorkspaceError.invalidMembership }
                    if let startupDocuments, let index = value.groups.firstIndex(where: { $0.id == id }) {
                        value.groups[index].tabs = startupDocuments
                        value.groups[index].activeTabID = (staged.first(where: { $0.id == requested }) ?? staged.first)?.id
                    }
                    if let previousGroup,
                       let index = value.groups.firstIndex(where: { $0.id == previousGroup }) {
                        let merged = StudyWorkspaceProjectionPolicy.merging(live: outgoingDocuments,
                            into: value.groups[index].tabs, backend: previousBackend)
                        value.groups[index].tabs = merged
                        value.groups[index].activeTabID = previousActive.flatMap { active in merged.contains { $0.id == active } ? active : nil }
                    }
                    var scene = value.scenes[sceneID] ?? .init(profileID: target.profileID, groupID: id)
                    scene.profileID = target.profileID
                    scene.groupID = id
                    var activeIDs = scene.activeTabIDsByGroup ?? [:]
                    if let previousGroup, let previousActive { activeIDs[previousGroup] = previousActive }
                    if let active = staged.first(where: { $0.id == requested }) ?? staged.first { activeIDs[id] = active.id }
                    else { activeIDs.removeValue(forKey: id) }
                    scene.activeTabIDsByGroup = activeIDs
                    value.scenes[sceneID] = scene
                    value.lastActiveSceneID = sceneID
                }
            }, publish: {
                // Nonthrowing publication, before the backend notification.
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
                if let active = staged.first(where: { $0.id == requested }) ?? staged.first {
                    manager.selectTab(id: active.id)
                    active.viewModel.needsScrollRestore = true
                } else {
                    manager.openTabs = previousTabs
                    for tab in previousTabs { manager.closeTab(id: tab.id) }
                }
                if let previousGroup { cache[previousGroup, default: [:]][previousBackend] = previousTabs }
                setMappingLiveContext(groupID: id, backend: desiredBackend, manager: manager)
                cache[id, default: [:]][desiredBackend] = staged
            })
        }
        manager.persistCurrentSession(immediate: true)
    }

    private func matches(_ tab: iOSNavigationManager.ReaderTab, _ document: ReaderDocumentTab) -> Bool {
        TargetBackendBookIdentity.matches(id: document.session.bookId, backend: document.backend,
            workKey: document.session.backendLocator?.workKey ?? document.session.locator?.workKey ?? tab.book.backendLocator?.workKey,
            candidateID: tab.book.id, candidateBackend: tab.book.backendLocator?.backend,
            candidateWorkKey: tab.book.backendLocator?.workKey)
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

    func reorderDocument(_ id: UUID, to index: Int, manager: iOSNavigationManager) {
        synchronize(manager)
        guard let groupID = liveGroupID else { return }
        do {
            try store.reorderDocument(id, to: index, groupID: groupID)
            guard let saved = group else { return }
            let positions = Dictionary(uniqueKeysWithValues: saved.tabs.enumerated().map { ($0.element.id, $0.offset) })
            manager.openTabs.sort { positions[$0.id, default: .max] < positions[$1.id, default: .max] }
            if let backend = liveBackend { cache[groupID, default: [:]][backend] = manager.openTabs }
            manager.persistCurrentSession(immediate: true)
        } catch { errorMessage = error.localizedDescription }
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
        let merged = StudyWorkspaceProjectionPolicy.merging(live: capture(tabs, backend: backend), into: saved.tabs, backend: backend)
        let before = StudyWorkspaceMappingPolicy.workspace(store.snapshot, scene: sceneID)
        let native = mappingOwnershipObservation()
        defer { reservedCheckpoint = nil }
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
                value.lastActiveSceneID = sceneID
            }
            if let reservation = readerReservation, let native,
               reservation.policy.permitsCheckpoint(from: before,
                   to: StudyWorkspaceMappingPolicy.workspace(value, scene: sceneID), actual: native) {
                reservedCheckpoint = reservation
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
            id: state.bookId, backendLocator: state.backendLocator?.workKey ?? state.locator?.workKey,
            title: state.bookTitle, in: document.backend)
        guard TargetBackendBookIdentity.matches(id: state.bookId, backend: document.backend,
            workKey: state.backendLocator?.workKey ?? state.locator?.workKey ?? book.backendLocator?.workKey,
            candidateID: book.id, candidateBackend: book.backendLocator?.backend,
            candidateWorkKey: book.backendLocator?.workKey) else {
            throw StudyWorkspaceError.backendMismatch
        }
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

/// The R owner retains the actual original objects. No public DTO or permission
/// is derived from a model-only success; N still requires the visible TextKit.
@MainActor final class StudyWorkspaceNativeReaderReservation {
    let policy: StudyWorkspaceReaderReservation
    let tab: iOSNavigationManager.ReaderTab
    init(policy: StudyWorkspaceReaderReservation, tab: iOSNavigationManager.ReaderTab) {
        self.policy = policy; self.tab = tab
    }
}
