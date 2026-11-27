import SwiftUI
import Combine

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
    @ObservationIgnored private var tabSelectionReservation: StudyWorkspaceNativeTabSelectionReservation?
    @ObservationIgnored private var tabSelectionCheckpoint: StudyWorkspaceNativeTabSelectionReservation?
    @ObservationIgnored private var groupSelectionReservation: StudyWorkspaceNativeGroupSelectionReservation?
    @ObservationIgnored private var snapshotObservation: UUID?
    @ObservationIgnored private(set) var nativeOverviewPublicationRevision: UInt64? = 0
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
        if let snapshotObservation { store.removeSnapshotPublicationObserver(snapshotObservation) }
        groupSelectionReservation?.policy.invalidate()
        mappingSubscription?.cancel()
        mappingOwnershipSource.retire()
        Self.mappingAdapters.removeValue(forKey: ObjectIdentifier(self))
    }

    func mappingOwnershipObservation() -> StudyWorkspaceMappingObservation? {
        guard readerReservation?.policy.isPublishing != true, tabSelectionReservation?.policy.isPublishing != true,
              groupSelectionReservation?.policy.isPublishing != true,
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
        snapshotObservation = store.observeSnapshotPublication(self)
        mappingSubscription = store.mappingSource(scene: sceneID).subscribe(owner: self) { adapter, event in
            if (event.reasons.contains(.ownerLifetime) || event.reasons.contains(.epochExhausted)) && event.phase == .unavailable {
                adapter.tabSelectionReservation?.policy.invalidate()
                adapter.groupSelectionReservation?.policy.invalidate()
                adapter.mappingOwnershipSource.retire()
            } else if let selection = adapter.groupSelectionReservation,
                      selection.policy.ownsStorePublication {
                // Only the exact original transaction candidate may change the
                // saved scene mapping during this synchronous native apply.
                if !selection.policy.observesOwnedMapping(event) {
                    adapter.invalidateNativeGroupSelection(selection)
                }
            } else if let checkpoint = adapter.tabSelectionCheckpoint,
                      checkpoint === adapter.tabSelectionReservation {
                guard checkpoint.policy.observesOwnedStorePublication(event) else {
                    adapter.mappingOwnershipSource.beginChange([.readerReservation])
                    adapter.finishMappingPublication()
                    return
                }
                if event.phase == .available { adapter.finishMappingPublication() }
            } else if event.phase == .changing {
                // Only the exact already committed native reservation's own
                // normal checkpoint preserves this native owner epoch.
                if let checkpoint = adapter.reservedCheckpoint,
                   checkpoint === adapter.readerReservation,
                   checkpoint.policy.phase == .committed,
                   checkpoint.policy.epoch == adapter.mappingOwnershipSource.event.epoch { return }
                adapter.readerReservation?.policy.invalidate()
                adapter.tabSelectionReservation?.policy.invalidate()
                adapter.groupSelectionReservation?.policy.invalidate()
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

    private func groupNativeTabs(_ tabs: [iOSNavigationManager.ReaderTab]) -> [StudyWorkspaceGroupNativeTab] {
        zip(tabs, mappingTabs(tabs)).map { tab, mapping in
            .init(id: tab.id, bookOwner: ObjectIdentifier(tab.book), target: mapping.target)
        }
    }

    private func groupNativeState(_ manager: iOSNavigationManager) -> StudyWorkspaceGroupNativeState {
        .init(tabs: groupNativeTabs(manager.openTabs), activeID: manager.activeTabId,
            selectedBookOwner: manager.selectedBook.map(ObjectIdentifier.init), selectedBookID: manager.selectedBook?.id,
            selectedBookMode: manager.selectedBookPresentationMode,
            overviewRequested: manager.showingTabsList,
            overviewRevision: nativeOverviewPublicationRevision,
            bookRevision: manager.selectedBookPresentationRevision, groupID: liveGroupID, backend: liveBackend)
    }

    private func setMappingLiveContext(groupID: UUID, backend: BackendID, manager: iOSNavigationManager) {
        if let selection = groupSelectionReservation,
           !(selection.policy.phase == .committed && liveGroupID == groupID && liveBackend == backend
                && selection.policy.matches(actual: groupNativeState(manager), snapshot: store.snapshot)) {
            // Ordinary current-group checkpoints repeat this original private
            // assignment. They own no identity change and no public setter.
            if selection.policy.willPublish(.context(groupID, backend), actual: groupNativeState(manager)) {
                liveGroupID = groupID
                liveBackend = backend
                if !selection.policy.didPublish(actual: groupNativeState(manager)) { invalidateNativeGroupSelection(selection) }
                return
            }
            // A passive observer never suppresses an unrelated original UI
            // action. It revokes the retained command before that action runs.
            invalidateNativeGroupSelection(selection)
        }
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

    /// Saved group documents remain authoritative; only obsolete in-memory
    /// reader instances are discarded after a managed Otzaria snapshot update.
    static func managedLibraryDidUpdate(_ manager: iOSNavigationManager) {
        withMappingAdapters(manager) { adapter in
            for id in Array(adapter.cache.keys) {
                adapter.cache[id]?.removeValue(forKey: .otzaria)
            }
            adapter.synchronize(manager)
        }
    }

    static func nativeMappingOwnerWillDeinitialize(_ manager: iOSNavigationManager) {
        for adapter in mappingAdapters.values.compactMap(\.value) where adapter.mappingOwnerID == ObjectIdentifier(manager) {
            adapter.mappingOwnershipSource.retire()
            adapter.groupSelectionReservation?.policy.invalidate()
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
            if let selection = adapter.groupSelectionReservation {
                if !selection.policy.willPublish(.tabs(adapter.groupNativeTabs(tabs)), actual: adapter.groupNativeState(manager)) {
                    adapter.invalidateNativeGroupSelection(selection)
                }
                return
            }
            let before = adapter.currentMappingProjection(manager)
            let after = adapter.mappingProjection(manager, tabs: tabs, activeID: manager.activeTabId,
                groupID: adapter.liveGroupID, backend: adapter.liveBackend)
            let reasons = StudyWorkspaceMappingPolicy.changes(from: before, to: after)
                .union(StudyWorkspaceMappingPolicy.nativeTargetChanges(from: adapter.mappingTabs(manager.openTabs), to: adapter.mappingTabs(tabs)))
            if let reservation = adapter.tabSelectionReservation {
                // Existing-tab selection owns no array publication, even an
                // equal-value setter or a reentrant replacement with the same IDs.
                reservation.policy.invalidate()
                adapter.mappingOwnershipSource.beginChange(reasons.union([.tabMembership]))
                return
            }
            guard !reasons.isEmpty else { return }
            if let reservation = adapter.readerReservation,
               reservation.policy.permitsTabsPublication(from: before, to: after) { return }
            adapter.mappingOwnershipSource.beginChange(reasons)
        }
    }

    static func nativeMappingSelectionWillChange(_ manager: iOSNavigationManager, to activeID: UUID?) {
        withMappingAdapters(manager) { adapter in
            if let selection = adapter.groupSelectionReservation {
                if !selection.policy.willPublish(.active(activeID), actual: adapter.groupNativeState(manager)) {
                    adapter.invalidateNativeGroupSelection(selection)
                }
                return
            }
            let before = adapter.currentMappingProjection(manager)
            let after = adapter.mappingProjection(manager, tabs: manager.openTabs, activeID: activeID,
                groupID: adapter.liveGroupID, backend: adapter.liveBackend)
            var reasons = StudyWorkspaceMappingPolicy.changes(from: before, to: after)
            if manager.activeTabId != activeID { reasons.insert(.selection) }
            if let reservation = adapter.tabSelectionReservation {
                guard reservation.policy.permitsSelectionPublication(from: before, to: after) else {
                    adapter.mappingOwnershipSource.beginChange(reasons.union([.selection]))
                    return
                }
                return
            }
            guard !reasons.isEmpty else { return }
            if let reservation = adapter.readerReservation,
               reservation.policy.permitsSelectionPublication(from: before, to: after) { return }
            adapter.mappingOwnershipSource.beginChange(reasons)
        }
    }

    static func nativeMappingDidChange(_ manager: iOSNavigationManager) {
        withMappingAdapters(manager) { adapter in
            if let selection = adapter.groupSelectionReservation {
                if !selection.policy.didPublish(actual: adapter.groupNativeState(manager)) {
                    adapter.invalidateNativeGroupSelection(selection)
                }
                return
            }
            if let reservation = adapter.tabSelectionReservation, reservation.policy.isPublishing,
               !reservation.policy.didPublishSelection(actual: adapter.currentMappingProjection(manager)) {
                adapter.mappingOwnershipSource.beginChange([.readerReservation])
            }
            if let reservation = adapter.readerReservation, reservation.policy.isPublishing,
               !reservation.policy.didPublish(actual: adapter.currentMappingProjection(manager)) {
                adapter.mappingOwnershipSource.beginChange([.readerReservation])
            }
            adapter.finishMappingPublication()
        }
    }

    /// Passive hooks surround the ORIGINAL selectedBook revision and mode
    /// assignment. An equal or nested setter must consume its own publication;
    /// no total-count allowance or callback-wide exception is used.
    static func nativeGroupBookWillChange(_ manager: iOSNavigationManager, to book: BooksData?) {
        withMappingAdapters(manager) { adapter in
            guard let selection = adapter.groupSelectionReservation else { return }
            if !selection.policy.willPublish(.book(book.map(ObjectIdentifier.init), book?.id),
                                             actual: adapter.groupNativeState(manager)) {
                adapter.invalidateNativeGroupSelection(selection)
            }
        }
    }

    static func nativeGroupBookDidChange(_ manager: iOSNavigationManager) {
        withMappingAdapters(manager) { adapter in
            guard let selection = adapter.groupSelectionReservation else { return }
            if !selection.policy.didPublish(actual: adapter.groupNativeState(manager)) {
                adapter.invalidateNativeGroupSelection(selection)
            }
        }
    }

    static func nativeGroupOverviewWillChange(_ manager: iOSNavigationManager, to requested: Bool) {
        withMappingAdapters(manager) { adapter in
            if let selection = adapter.groupSelectionReservation,
               !selection.policy.willPublish(.overview(requested), actual: adapter.groupNativeState(manager)) {
                adapter.invalidateNativeGroupSelection(selection)
            }
            // This actual original-owner history also covers the foreground
            // await before a reservation exists. It never resets on selection.
            if let revision = adapter.nativeOverviewPublicationRevision, revision < .max {
                adapter.nativeOverviewPublicationRevision = revision + 1
            } else { adapter.nativeOverviewPublicationRevision = nil }
        }
    }

    static func nativeGroupOverviewDidChange(_ manager: iOSNavigationManager) {
        withMappingAdapters(manager) { adapter in
            guard let selection = adapter.groupSelectionReservation else { return }
            if !selection.policy.didPublish(actual: adapter.groupNativeState(manager)) {
                adapter.invalidateNativeGroupSelection(selection)
            }
        }
    }

    // MARK: Original native reader ownership

    /// Reserves an original ReaderTab/ReaderViewModel before Core admission.
    /// This does not load, select, persist or authorize content.
    func reserveNativeReader(requestID: UUID, book: BooksData, destination: LibraryReaderDestination,
                             manager: iOSNavigationManager) throws -> StudyWorkspaceNativeReaderReservation {
        guard attached, !isSwitching, mappingManager === manager, readerReservation == nil, tabSelectionReservation == nil,
              groupSelectionReservation == nil,
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

    // MARK: Existing original Reader-tab selection

    func reserveNativeTabSelection(requestID: UUID, tabID: UUID,
                                   manager: iOSNavigationManager) throws -> StudyWorkspaceNativeTabSelectionReservation {
        let targets = manager.openTabs.filter { $0.id == tabID }
        guard attached, !isSwitching, mappingManager === manager,
              readerReservation == nil, tabSelectionReservation == nil, groupSelectionReservation == nil,
              targets.count == 1, let tab = targets.first,
              tab.book.backendLocator?.backend == BackendCoordinator.shared.activeBackendID,
              mappingOwnershipObservation() != nil else { throw StudyWorkspaceError.invalidMembership }
        // Retire prior requests before admitting the new, existing-tab contract.
        mappingOwnershipSource.beginChange([.readerReservation])
        finishMappingPublication()
        guard let native = mappingOwnershipObservation(), let saved = store.mappingObservation(scene: sceneID) else {
            throw StudyWorkspaceError.invalidMembership
        }
        let policy = try StudyWorkspaceTabSelectionReservation(requestID: requestID,
            observation: native, workspace: saved, targetID: tabID)
        let reservation = StudyWorkspaceNativeTabSelectionReservation(policy: policy, tab: tab)
        tabSelectionReservation = reservation
        return reservation
    }

    func validateNativeTabSelection(_ reservation: StudyWorkspaceNativeTabSelectionReservation) throws {
        guard attached, !isSwitching, tabSelectionReservation === reservation,
              let manager = mappingManager, let native = mappingOwnershipObservation(),
              let saved = store.mappingObservation(scene: sceneID),
              reservation.policy.matches(native, workspace: saved) else { throw StudyWorkspaceError.invalidMembership }
        let tabs = manager.openTabs.filter { $0.id == reservation.tab.id }
        guard tabs.count == 1, let tab = tabs.first, tab.book === reservation.tab.book,
              tab.viewModel === reservation.tab.viewModel else { throw StudyWorkspaceError.invalidMembership }
    }

    func applyNativeTabSelection(_ reservation: StudyWorkspaceNativeTabSelectionReservation,
                                 operation: () throws -> Void) throws {
        try validateNativeTabSelection(reservation)
        guard let manager = mappingManager, let native = mappingOwnershipObservation(),
              let saved = store.mappingObservation(scene: sceneID) else { throw StudyWorkspaceError.invalidMembership }
        do {
            try reservation.policy.beginApply(native, workspace: saved)
            // The caller invokes only the original manager.selectTab action.
            // Its real willSet/didSet consumes the exact one-shot allowance.
            try operation()
            try persistProjection(manager.openTabs, activeID: manager.activeTabId,
                groupID: reservation.policy.original.groupID, backend: reservation.policy.target.target.backend)
            guard let actual = mappingOwnershipObservation(), let persisted = store.mappingObservation(scene: sceneID) else {
                throw StudyWorkspaceError.invalidMembership
            }
            try reservation.policy.finishApply(actual, workspace: persisted)
        } catch {
            reservation.policy.invalidate()
            mappingOwnershipSource.beginChange([.readerReservation])
            finishMappingPublication()
            throw error
        }
    }

    func releaseNativeTabSelection(_ reservation: StudyWorkspaceNativeTabSelectionReservation) {
        guard tabSelectionReservation === reservation else { return }
        reservation.policy.release()
        tabSelectionReservation = nil
        // No tab closure, rollback, new admission or source-observation rearm.
        mappingOwnershipSource.beginChange([.readerReservation])
        finishMappingPublication()
    }

    // MARK: Original profile/group selection

    /// Read-only captured input for native metadata/selection. This is the SAME
    /// original staging record later retained across foreground and catalog
    /// waits; no cached Reader is replaced by a later lookup.
    func captureNativeGroupSelection(profileID: UUID, groupID: UUID, selectsProfile: Bool,
                                     manager: iOSNavigationManager) throws -> StudyWorkspacePreparedGroupSelection {
        guard attached, !isSwitching, mappingManager === manager,
              readerReservation == nil, tabSelectionReservation == nil, groupSelectionReservation == nil,
              store.loadError == nil, errorMessage == nil,
              let native = mappingOwnershipObservation(), native.owner == ObjectIdentifier(manager),
              let target = store.snapshot?.groups.first(where: { $0.id == groupID && $0.profileID == profileID }),
              (selectsProfile ? firstGroup(in: profileID)?.id == target.id : selection?.profileID == profileID) else {
            throw StudyWorkspaceError.invalidMembership
        }
        return try makeGroupSelection(to: groupID, documentID: nil, manager: manager, restoringBackend: nil)
    }

    /// Retains inactive documents and original first-group selection before the
    /// catalog await. No Store write, backend switch or Reader load occurs here.
    func reserveNativeGroupSelection(requestID: UUID, profileID: UUID, groupID: UUID,
                                     selectsProfile: Bool, manager: iOSNavigationManager,
                                     backendObservation: StudyWorkspaceGroupBackendObservation,
                                     prepared: StudyWorkspacePreparedGroupSelection) throws
        -> StudyWorkspaceNativeGroupSelectionReservation {
        try backendObservation.validate()
        guard attached, !isSwitching, mappingManager === manager,
              readerReservation == nil, tabSelectionReservation == nil, groupSelectionReservation == nil,
              store.loadError == nil, errorMessage == nil,
              let before = mappingOwnershipObservation(), before.owner == ObjectIdentifier(manager),
              let target = store.snapshot?.groups.first(where: { $0.id == groupID && $0.profileID == profileID }),
              !selectsProfile || firstGroup(in: profileID)?.id == target.id else {
            throw StudyWorkspaceError.invalidMembership
        }
        let current = try makeGroupSelection(to: groupID, documentID: nil, manager: manager, restoringBackend: nil)
        func sameReaders(_ lhs: [iOSNavigationManager.ReaderTab], _ rhs: [iOSNavigationManager.ReaderTab]) -> Bool {
            lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { left, right in
                left.id == right.id && left.book === right.book && left.viewModel === right.viewModel
            }
        }
        guard prepared.snapshot == current.snapshot, prepared.target == current.target,
              prepared.requested == current.requested, prepared.documents == current.documents,
              prepared.previousActive == current.previousActive, prepared.previousGroup == current.previousGroup,
              prepared.previousGeneration == current.previousGeneration,
              sameReaders(prepared.previousTabs, current.previousTabs), sameReaders(prepared.retained, current.retained),
              prepared.staged.isEmpty, prepared.freshlyHydratedIDs.isEmpty else {
            throw StudyWorkspaceError.invalidMembership
        }
        guard prepared.target == target, prepared.previousBackend == BackendCoordinator.shared.committedBackendID,
              !BackendCoordinator.shared.isTransitioning else { throw StudyWorkspaceError.backendMismatch }
        // One next native epoch, before this request is admitted by Core.
        mappingOwnershipSource.beginChange([.readerReservation])
        finishMappingPublication()
        guard let native = mappingOwnershipObservation(), let stored = store.mappingObservation(scene: sceneID),
              let snapshot = store.snapshot, snapshot == prepared.snapshot else {
            throw StudyWorkspaceError.invalidMembership
        }
        let policy = try StudyWorkspaceGroupSelectionReservation(requestID: requestID, native: native,
            workspace: stored, snapshot: snapshot, actual: groupNativeState(manager),
            profileID: profileID, groupID: groupID, backend: prepared.desiredBackend, selectsProfile: selectsProfile)
        let reservation = StudyWorkspaceNativeGroupSelectionReservation(policy: policy, prepared: prepared,
            backendObservation: backendObservation)
        do {
            try backendObservation.bind(policy) { [weak self, weak reservation] in
                guard let self, let reservation else { return }
                self.invalidateNativeGroupSelection(reservation)
            }
            groupSelectionReservation = reservation
            try validateNativeGroupSelection(reservation)
            return reservation
        } catch {
            if groupSelectionReservation === reservation { releaseNativeGroupSelection(reservation) }
            else { policy.release(); backendObservation.retire() }
            throw error
        }
    }

    func prepareNativeGroupSelection(_ reservation: StudyWorkspaceNativeGroupSelectionReservation,
                                     validate: @MainActor () throws -> Void) async throws {
        try validateNativeGroupSelection(reservation)
        guard let manager = mappingManager, !reservation.ownsSwitching else { throw StudyWorkspaceError.invalidMembership }
        try reservation.policy.beginPreparation(actual: groupNativeState(manager), snapshot: store.snapshot)
        reservation.ownsSwitching = true
        isSwitching = true
        do {
            try await ChavrusaTextTargetBackendBookResolver.shared.withTargetCatalog(in: reservation.prepared.desiredBackend) {
                try validate()
                try validateNativeGroupSelection(reservation)
                try stageOriginalGroupSelection(reservation.prepared, owner: reservation)
                try validate()
                try validateNativeGroupSelection(reservation)
                try reservation.captureOriginalReaderSources()
                try reservation.policy.finishPreparation(staged: groupNativeTabs(reservation.prepared.staged),
                    requested: reservation.prepared.requested, actual: groupNativeState(manager), snapshot: store.snapshot)
            }
            try validate()
            try validateNativeGroupSelection(reservation)
        } catch {
            invalidateNativeGroupSelection(reservation)
            if reservation.ownsSwitching { reservation.ownsSwitching = false; isSwitching = false }
            throw error
        }
    }

    func validateNativeGroupSelection(_ reservation: StudyWorkspaceNativeGroupSelectionReservation) throws {
        try reservation.backendObservation.validate()
        guard attached, groupSelectionReservation === reservation, let manager = mappingManager,
              isSwitching == reservation.ownsSwitching, store.loadError == nil, errorMessage == nil,
              BackendCoordinator.shared.activeBackendID == reservation.policy.backend,
              BackendCoordinator.shared.committedBackendID == reservation.policy.backend,
              BackendCoordinator.shared.pendingBackendID == nil,
              BackendCoordinator.shared.generation == reservation.prepared.previousGeneration,
              !BackendCoordinator.shared.isTransitioning,
              reservation.policy.matches(actual: groupNativeState(manager), snapshot: store.snapshot) else {
            throw StudyWorkspaceError.invalidMembership
        }
        try reservation.validateOriginalReaderSources()
    }

    /// Called only inside the original synchronous Core apply. Staging and all
    /// asynchronous work completed earlier under this same retained source.
    func applyNativeGroupSelection(_ reservation: StudyWorkspaceNativeGroupSelectionReservation,
                                   validate: @MainActor () throws -> Void) throws {
        try validateNativeGroupSelection(reservation)
        guard let manager = mappingManager, reservation.ownsSwitching else { throw StudyWorkspaceError.invalidMembership }
        try reservation.policy.beginApply(actual: groupNativeState(manager), snapshot: store.snapshot)
        do {
            try BackendCoordinator.shared.commitPreparedSameBackend(reservation.policy.backend,
                expectedGeneration: reservation.prepared.previousGeneration, validate: {
                    try validate()
                    try validateNativeGroupSelection(reservation)
                }, beforeCommit: {
                    try persistOriginalGroupSelection(reservation.prepared, manager: manager, owner: reservation)
                    // The Store checkpoint may call arbitrary synchronous
                    // observers. Revalidate before the first native setter.
                    try validate()
                    try validateNativeGroupSelection(reservation)
                }, publish: {
                    publishOriginalGroupSelection(reservation.prepared, manager: manager, owner: reservation)
                }, willClearPending: {
                    do {
                        try reservation.policy.beginPendingBackendClear(actual: groupNativeState(manager), snapshot: store.snapshot)
                    } catch { reservation.recordPublicationFailure(error); invalidateNativeGroupSelection(reservation) }
                }, didClearPending: {
                    do {
                        try reservation.policy.finishPendingBackendClear(actual: groupNativeState(manager),
                            snapshot: store.snapshot, pendingIsNil: BackendCoordinator.shared.pendingBackendID == nil)
                    } catch { reservation.recordPublicationFailure(error); invalidateNativeGroupSelection(reservation) }
                })
            // A callback failure after native publication must not extend the
            // snapshot rollback scope into visibility, or pretend UI rollback.
            if let failure = reservation.publicationFailure { throw failure }
            try reservation.policy.finishApply(actual: groupNativeState(manager), snapshot: store.snapshot)
            manager.persistCurrentSession(immediate: true)
            reservation.ownsSwitching = false
            isSwitching = false
            try validate()
            try validateNativeGroupSelection(reservation)
        } catch {
            invalidateNativeGroupSelection(reservation)
            if reservation.ownsSwitching { reservation.ownsSwitching = false; isSwitching = false }
            throw error
        }
    }

    private func invalidateNativeGroupSelection(_ reservation: StudyWorkspaceNativeGroupSelectionReservation) {
        guard groupSelectionReservation === reservation, !reservation.didInvalidateNativeSource else { return }
        reservation.didInvalidateNativeSource = true
        reservation.invalidateOriginalLoads()
        reservation.policy.invalidate()
        // Leave admission unavailable until the original publication/release
        // finishes. Never expose old native values with a new ready epoch.
        mappingOwnershipSource.beginChange([.readerReservation])
    }

    func releaseNativeGroupSelection(_ reservation: StudyWorkspaceNativeGroupSelectionReservation) {
        guard groupSelectionReservation === reservation else { return }
        reservation.backendObservation.retire()
        reservation.policy.release()
        if reservation.ownsSwitching { reservation.ownsSwitching = false; isSwitching = false }
        groupSelectionReservation = nil
        mappingOwnershipSource.beginChange([.readerReservation])
        finishMappingPublication()
    }

    private func performOriginalGroupOperation(_ operation: StudyWorkspaceGroupSelectionReservation.Operation,
                                               selection: StudyWorkspacePreparedGroupSelection,
                                               manager: iOSNavigationManager, owner: StudyWorkspaceNativeGroupSelectionReservation?,
                                               body: () -> Void) -> Bool {
        guard let reservation = owner else { body(); return true }
        do {
            guard groupSelectionReservation === reservation, reservation.prepared === selection else {
                throw StudyWorkspaceError.invalidMembership
            }
            try reservation.policy.beginOperation(operation, actual: groupNativeState(manager))
            body()
            try reservation.policy.finishOperation(operation, actual: groupNativeState(manager))
            try validateNativeGroupSelection(reservation)
            return true
        } catch {
            reservation.recordPublicationFailure(error)
            invalidateNativeGroupSelection(reservation)
            return false
        }
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
        if let reservation = groupSelectionReservation { invalidateNativeGroupSelection(reservation) }
        #if DEBUG
        let performance = StudyGroupSwitchPerformanceObservation.begin(
            sceneID: sceneID, fromGroupID: liveGroupID, toGroupID: id,
            fromDocumentID: manager.activeTabId, beforeRevision: store.snapshot?.revision,
            backend: BackendCoordinator.shared.activeBackendID.rawValue)
        var performanceReturnedNormally = false
        defer {
            if let performance {
                StudyGroupSwitchPerformanceObservation.finish(
                    performance, returnedNormally: performanceReturnedNormally,
                    observedGroupID: liveGroupID, observedDocumentID: manager.activeTabId,
                    afterRevision: store.snapshot?.revision,
                    backend: BackendCoordinator.shared.activeBackendID.rawValue)
            }
        }
        #endif
        isSwitching = true
        defer { isSwitching = false }
        let prepared = try makeGroupSelection(to: id, documentID: documentID,
            manager: manager, restoringBackend: restoringBackend)
        try await ChavrusaTextTargetBackendBookResolver.shared.withTargetCatalog(in: prepared.desiredBackend) {
            try stageOriginalGroupSelection(prepared)
            try await BackendCoordinator.shared.commitCheckedAsync(prepared.desiredBackend, beforeCommit: {
                try persistOriginalGroupSelection(prepared, manager: manager)
            }, publish: {
                publishOriginalGroupSelection(prepared, manager: manager)
            })
        }
        manager.persistCurrentSession(immediate: true)
        #if DEBUG
        performanceReturnedNormally = true
        #endif
    }

    /// The original first-group policy, shared by the menu and typed selection.
    func firstGroup(in profileID: UUID) -> StudyTabGroup? {
        store.snapshot?.groups.filter { $0.profileID == profileID }.sorted { $0.order < $1.order }.first
    }

    private func makeGroupSelection(to id: UUID, documentID: UUID?, manager: iOSNavigationManager,
                                    restoringBackend: BackendID?) throws -> StudyWorkspacePreparedGroupSelection {
        let previousTabs = manager.openTabs
        let previousActive = manager.activeTabId
        let previousBackend = BackendCoordinator.shared.activeBackendID
        let previousGroup = liveGroupID
        let previousGeneration = BackendCoordinator.shared.generation
        let previousSelection = selection
        guard let target = store.snapshot?.groups.first(where: { $0.id == id }) else { throw StudyWorkspaceError.invalidMembership }
        let requested = documentID ?? selection?.activeTabIDsByGroup?[id] ?? target.activeTabID
        let desiredBackend = StudyWorkspaceProjectionPolicy.backend(restoring: restoringBackend, requestedID: requested,
                                                                   documents: target.tabs, fallback: previousBackend)
        // A study profile/group is not a library-source choice. Preserve its
        // saved foreign documents and the outgoing scene until the user makes
        // an explicit change through the original backend owner.
        guard desiredBackend == previousBackend else { throw StudyWorkspaceError.backendMismatch }
        let documents = target.tabs.filter { $0.backend == desiredBackend }
        let retained = cache[id]?[desiredBackend] ?? []
        guard let snapshot = store.snapshot else { throw StudyWorkspaceError.invalidMembership }
        return .init(target: target, requested: requested, desiredBackend: desiredBackend,
            documents: documents, retained: retained, previousTabs: previousTabs,
            previousActive: previousActive, previousBackend: previousBackend,
            previousGroup: previousGroup, previousGeneration: previousGeneration,
            previousSelection: previousSelection, restoringBackend: restoringBackend, snapshot: snapshot)
    }

    private func stageOriginalGroupSelection(_ selection: StudyWorkspacePreparedGroupSelection,
                                             owner: StudyWorkspaceNativeGroupSelectionReservation? = nil) throws {
        let previousBackend = selection.previousBackend, desiredBackend = selection.desiredBackend
        let previousGeneration = selection.previousGeneration
        let previousTabs = selection.previousTabs, documents = selection.documents, retained = selection.retained
        guard BackendCoordinator.shared.activeBackendID == previousBackend,
              BackendCoordinator.shared.generation == previousGeneration else {
            throw BackendTransitionError.transitionSuperseded
        }
        // Every document is resolved against the target catalog while the
        // outgoing reader and committed backend are still intact.
        selection.staged = try documents.map { document in
            if let owner { try validateNativeGroupSelection(owner) }
            let resolved = try ChavrusaTextTargetBackendBookResolver.shared.resolveBook(
                id: document.session.bookId,
                backendLocator: document.session.backendLocator?.workKey ?? document.session.locator?.workKey,
                title: document.session.bookTitle, in: document.backend)
            if let existing = retained.first(where: { $0.id == document.id }), matches(existing, document),
               existing.book.backendLocator?.workKey == resolved.backendLocator?.workKey { return existing }
            if previousBackend == desiredBackend,
               let existing = previousTabs.first(where: { $0.id == document.id }), matches(existing, document),
               existing.book.backendLocator?.workKey == resolved.backendLocator?.workKey { return existing }
            let hydrated = try hydrate(document)
            selection.freshlyHydratedIDs.insert(hydrated.id)
            return hydrated
        }
    }

    private func persistOriginalGroupSelection(_ selection: StudyWorkspacePreparedGroupSelection,
                                               manager: iOSNavigationManager,
                                               owner: StudyWorkspaceNativeGroupSelectionReservation? = nil) throws {
        if let owner { try validateNativeGroupSelection(owner) }
        let id = selection.target.id, target = selection.target
        let previousTabs = selection.previousTabs, previousActive = selection.previousActive
        let previousBackend = selection.previousBackend, previousGroup = selection.previousGroup
        let previousGeneration = selection.previousGeneration, previousSelection = selection.previousSelection
        let desiredBackend = selection.desiredBackend, restoringBackend = selection.restoringBackend
        var staged = selection.staged, requested = selection.requested
        defer { selection.staged = staged; selection.requested = requested }
        var startupDocuments: [ReaderDocumentTab]?
        if restoringBackend != nil, previousGroup == nil {
            try Task.checkCancellation()
            guard BackendCoordinator.shared.activeBackendID == previousBackend,
                  BackendCoordinator.shared.generation == previousGeneration else {
                throw BackendTransitionError.transitionSuperseded
            }
            guard self.selection == previousSelection else { throw StudyWorkspaceError.invalidMembership }
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
            if let reservation = owner {
                guard groupSelectionReservation === reservation, reservation.prepared === selection else {
                    throw StudyWorkspaceError.invalidMembership
                }
                try reservation.policy.armStorePublication(candidate: value, before: store.snapshot,
                    actual: groupNativeState(manager), checkpoint: false)
            }
        }
    }

    private func publishOriginalGroupSelection(_ selection: StudyWorkspacePreparedGroupSelection,
                                               manager: iOSNavigationManager,
                                               owner: StudyWorkspaceNativeGroupSelectionReservation? = nil) {
        let id = selection.target.id, requested = selection.requested, staged = selection.staged
        let documents = selection.documents, previousTabs = selection.previousTabs
        let previousGroup = selection.previousGroup, previousBackend = selection.previousBackend
        let desiredBackend = selection.desiredBackend
        // Nonthrowing publication, before the backend notification.
        guard performOriginalGroupOperation(.installTabs, selection: selection, manager: manager, owner: owner, body: { manager.openTabs = staged }) else { return }
        for document in documents {
            guard let tab = staged.first(where: { $0.id == document.id }), tab.viewModel.contentText.isEmpty else { continue }
            let initialRequest: ReaderInitialContentRequest?
            if let reservation = owner {
                do {
                    try validateNativeGroupSelection(reservation)
                    initialRequest = try reservation.willLoadOriginal(tab: tab)
                } catch { reservation.recordPublicationFailure(error); invalidateNativeGroupSelection(reservation); return }
            } else { initialRequest = nil }
            if let locator = document.session.locator {
                tab.viewModel.loadBackendContent(locator, continuing: initialRequest)
            } else {
                tab.viewModel.loadInitialContent(initialContentId: document.session.contentId, continuing: initialRequest)
            }
            tab.viewModel.loadTOC(book: tab.book)
            if let reservation = owner {
                do { try reservation.didLoadOriginal(tab: tab); try validateNativeGroupSelection(reservation) }
                catch { reservation.recordPublicationFailure(error); invalidateNativeGroupSelection(reservation); return }
            }
        }
        if let active = staged.first(where: { $0.id == requested }) ?? staged.first {
            guard performOriginalGroupOperation(.select(active.id), selection: selection, manager: manager, owner: owner,
                body: { manager.selectTab(id: active.id) }) else { return }
            active.viewModel.needsScrollRestore = true
        } else {
            guard performOriginalGroupOperation(.restoreClosingTabs, selection: selection, manager: manager, owner: owner,
                body: { manager.openTabs = previousTabs }) else { return }
            for tab in previousTabs {
                guard performOriginalGroupOperation(.close(tab.id), selection: selection, manager: manager, owner: owner,
                    body: { manager.closeTab(id: tab.id) }) else { return }
            }
        }
        if let previousGroup { cache[previousGroup, default: [:]][previousBackend] = previousTabs }
        guard performOriginalGroupOperation(.liveContext, selection: selection, manager: manager, owner: owner,
            body: { setMappingLiveContext(groupID: id, backend: desiredBackend, manager: manager) }) else { return }
        cache[id, default: [:]][desiredBackend] = staged
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
        let savedObservation = store.mappingObservation(scene: sceneID)
        var tabCheckpointCompleted = false
        var groupCheckpoint: StudyWorkspaceNativeGroupSelectionReservation?
        var groupCheckpointCompleted = false
        defer {
            reservedCheckpoint = nil
            if let checkpoint = tabSelectionCheckpoint, !tabCheckpointCompleted {
                checkpoint.policy.invalidate()
                mappingOwnershipSource.beginChange([.readerReservation])
                finishMappingPublication()
            }
            tabSelectionCheckpoint = nil
            if let checkpoint = groupCheckpoint, !groupCheckpointCompleted { invalidateNativeGroupSelection(checkpoint) }
        }
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
            if let reservation = tabSelectionReservation, reservation.policy.phase == .selected,
               let native, let savedObservation {
                try reservation.policy.beginCheckpoint(native: native, workspace: savedObservation,
                    candidate: StudyWorkspaceMappingPolicy.workspace(value, scene: sceneID))
                tabSelectionCheckpoint = reservation
            }
            if let reservation = groupSelectionReservation, reservation.policy.phase == .committed,
               let manager = mappingManager {
                try reservation.policy.armStorePublication(candidate: value, before: store.snapshot,
                    actual: groupNativeState(manager), checkpoint: true)
                groupCheckpoint = reservation
            }
        }
        if let checkpoint = tabSelectionCheckpoint {
            guard let manager = mappingManager, let saved = store.mappingObservation(scene: sceneID) else {
                throw StudyWorkspaceError.invalidMembership
            }
            try checkpoint.policy.finishCheckpoint(nativeProjection: currentMappingProjection(manager), workspace: saved)
            tabCheckpointCompleted = true
        }
        if let checkpoint = groupCheckpoint {
            try validateNativeGroupSelection(checkpoint)
            groupCheckpointCompleted = true
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

extension StudyWorkspaceNavigationAdapter: StudyWorkspaceSnapshotObserver {
    func workspaceSnapshotWillPublish(before: StudyWorkspaceSnapshot?, after: StudyWorkspaceSnapshot) {
        guard let reservation = groupSelectionReservation else { return }
        if !reservation.policy.snapshotWillPublish(before: before, after: after) {
            invalidateNativeGroupSelection(reservation)
        }
    }

    func workspaceSnapshotDidPublish(_ snapshot: StudyWorkspaceSnapshot) {
        guard let reservation = groupSelectionReservation else { return }
        if !reservation.policy.snapshotDidPublish(snapshot) { invalidateNativeGroupSelection(reservation) }
    }

    func workspaceSnapshotOwnerDidRetire() {
        groupSelectionReservation?.policy.invalidate()
        mappingOwnershipSource.retire()
    }
}

/// One real backend publisher observation starts BEFORE the first activation or
/// catalog await. Binding the later original stage never resets or resubscribes
/// it. Only that stage's exact terminal pending-clear publication is permitted.
@MainActor final class StudyWorkspaceGroupBackendObservation {
    let backend: BackendID
    let generation: UInt64
    private let coordinator: BackendCoordinator
    private var valid = true
    private var changes: AnyCancellable?
    private var policy: StudyWorkspaceGroupSelectionReservation?
    private var invalidated: (@MainActor () -> Void)?

    init() {
        coordinator = BackendCoordinator.shared
        backend = coordinator.activeBackendID; generation = coordinator.generation
        changes = coordinator.objectWillChange.sink { [weak self] _ in
            guard let self, self.valid else { return }
            if let policy = self.policy, policy.backendWillPublish() { return }
            self.valid = false
            self.invalidated?()
        }
    }
    func bind(_ policy: StudyWorkspaceGroupSelectionReservation,
              invalidated: @escaping @MainActor () -> Void) throws {
        try validate()
        guard self.policy == nil, policy.backend == backend, policy.phase == .reserved else {
            throw StudyWorkspaceError.invalidMembership
        }
        self.policy = policy; self.invalidated = invalidated
    }
    func validate() throws {
        guard valid, BackendCoordinator.shared === coordinator,
              coordinator.activeBackendID == backend, coordinator.committedBackendID == backend,
              coordinator.generation == generation, !coordinator.isTransitioning,
              coordinator.pendingBackendID == nil else { throw StudyWorkspaceError.invalidMembership }
    }
    func retire() { valid = false; changes?.cancel(); changes = nil; invalidated = nil }
}

/// A single original stage retained across async catalog preparation and the
/// existing synchronous Core apply. It is not permission or a second store.
@MainActor final class StudyWorkspaceNativeGroupSelectionReservation {
    struct ReaderSource {
        let tab: iOSNavigationManager.ReaderTab
        let book: BooksData
        let bookLocator: TextLocator
        let needsLoad: Bool
        let input: ReaderInitialContentRequest.Input
        let sourceObservation: ReaderInitialContentSourceObservation
        let previousToken: ReaderContentRequestToken?
        let previousDestination: LibraryReaderDestination?
        var initialRequest: ReaderInitialContentRequest?
        var issuing = false
        var issued = false
    }
    let policy: StudyWorkspaceGroupSelectionReservation
    let prepared: StudyWorkspacePreparedGroupSelection
    var ownsSwitching = false
    var didInvalidateNativeSource = false
    let backendObservation: StudyWorkspaceGroupBackendObservation
    private(set) var readerSources: [UUID: ReaderSource] = [:]
    private(set) var publicationFailure: Error?
    private var initialContentDeadline: UInt64?

    init(policy: StudyWorkspaceGroupSelectionReservation, prepared: StudyWorkspacePreparedGroupSelection,
         backendObservation: StudyWorkspaceGroupBackendObservation) {
        self.policy = policy; self.prepared = prepared; self.backendObservation = backendObservation
    }
    func recordPublicationFailure(_ error: Error) { publicationFailure = publicationFailure ?? error }

    func bindInitialContentDeadline(_ deadline: UInt64) throws {
        guard initialContentDeadline == nil, policy.phase == .prepared,
              DispatchTime.now().uptimeNanoseconds < deadline,
              readerSources.values.allSatisfy({ !$0.issuing && !$0.issued }) else { throw StudyWorkspaceError.invalidMembership }
        initialContentDeadline = deadline
    }

    func captureOriginalReaderSources() throws {
        guard readerSources.isEmpty else { throw StudyWorkspaceError.invalidMembership }
        for tab in prepared.staged {
            guard let document = prepared.documents.first(where: { $0.id == tab.id }),
                  let book = tab.book.backendLocator, book.backend == policy.backend,
                  tab.viewModel.currentBook === tab.book,
                  book.workKey == (document.session.backendLocator?.workKey ?? document.session.locator?.workKey),
                  let observation = tab.viewModel.contentLoadCoordinator.initialContentSourceObservation(),
                  observation.isCurrent, observation.pendingRequestID == nil else { throw StudyWorkspaceError.unavailableBook }
            let prior = tab.viewModel.contentLoadCoordinator.currentRequestToken()
            let empty = tab.viewModel.contentText.isEmpty
            let input: ReaderInitialContentRequest.Input
            if let locator = document.session.locator {
                guard locator.backend == policy.backend, locator.workKey == book.workKey else { throw StudyWorkspaceError.unavailableBook }
                input = .locator(locator)
            } else { input = .initial(document.session.contentId) }
            if !empty {
                guard case .loaded = tab.viewModel.state, let prior,
                      let destination = tab.viewModel.currentDestination,
                      prior.backend == policy.backend, prior.workKey == book.workKey,
                      prior.sectionLocator == destination.sectionLocator,
                      tab.viewModel.contentLoadCoordinator.canApplyContent(token: prior, currentBookLocator: book) else {
                    throw StudyWorkspaceError.unavailableBook
                }
            }
            // The original backendLoadTask IS retained. The former limitation
            // was missing pre-token invocation identity, now supplied by the
            // original coordinator; no expected-generation guess is required.
            readerSources[tab.id] = .init(tab: tab, book: tab.book, bookLocator: book, needsLoad: empty,
                input: input, sourceObservation: observation, previousToken: prior,
                previousDestination: tab.viewModel.currentDestination)
        }
    }

    func validateOriginalReaderSources() throws {
        for source in readerSources.values {
            let actual = prepared.staged.filter { $0.id == source.tab.id }
            guard actual.count == 1, let tab = actual.first,
                  tab.book === source.book, tab.viewModel === source.tab.viewModel,
                  source.book.backendLocator == source.bookLocator,
                  tab.viewModel.currentBook === source.book, !source.issuing else { throw StudyWorkspaceError.invalidMembership }
            if source.issued {
                guard let request = source.initialRequest, let actual = request.state,
                      request.source.reader == ObjectIdentifier(tab.viewModel), request.source.book == ObjectIdentifier(source.book),
                      request.source.bookID == source.book.id, request.source.bookLocator == source.bookLocator,
                      request.source.input == source.input, request.source.backend == policy.backend,
                      request.source.backendGeneration == prepared.previousGeneration,
                      request.deadlineUptimeNanoseconds == initialContentDeadline,
                      tab.viewModel.currentDestination == actual.destination else { throw StudyWorkspaceError.invalidMembership }
                if let token = actual.token {
                    guard token == request.issuedToken, token == tab.viewModel.contentLoadCoordinator.currentRequestToken(),
                          token.backend == policy.backend, token.workKey == source.bookLocator.workKey,
                          token.sectionLocator == actual.destination?.sectionLocator,
                          tab.viewModel.contentLoadCoordinator.canApplyContent(token: token, currentBookLocator: source.bookLocator) else {
                        throw StudyWorkspaceError.invalidMembership
                    }
                } else {
                    guard actual.phase == .resolving, tab.viewModel.contentText.isEmpty,
                          tab.viewModel.contentLoadCoordinator.currentRequestToken() == nil else { throw StudyWorkspaceError.invalidMembership }
                }
            } else {
                guard source.sourceObservation.isCurrent,
                      tab.viewModel.contentLoadCoordinator.currentRequestToken() == source.previousToken,
                      tab.viewModel.currentDestination == source.previousDestination else { throw StudyWorkspaceError.invalidMembership }
                if source.needsLoad {
                    guard tab.viewModel.contentText.isEmpty else { throw StudyWorkspaceError.invalidMembership }
                } else {
                    guard case .loaded = tab.viewModel.state, !tab.viewModel.contentText.isEmpty else { throw StudyWorkspaceError.unavailableBook }
                }
            }
        }
    }

    func willLoadOriginal(tab: iOSNavigationManager.ReaderTab) throws -> ReaderInitialContentRequest {
        guard policy.phase == .publishing, var source = readerSources[tab.id],
              source.tab.viewModel === tab.viewModel, source.tab.book === tab.book,
              source.needsLoad, !source.issuing, !source.issued, source.sourceObservation.isCurrent,
              tab.viewModel.contentLoadCoordinator.currentRequestToken() == source.previousToken,
              tab.viewModel.contentText.isEmpty, let deadline = initialContentDeadline else { throw StudyWorkspaceError.invalidMembership }
        // Consume before the original callback; retain its issuer, not a token
        // sampled from the Reader after asynchronous initial resolution.
        source.issuing = true; readerSources[tab.id] = source
        let request: ReaderInitialContentRequest?
        switch source.input {
        case .initial(let contentID):
            request = tab.viewModel.makeInitialContentRequest(initialContentId: contentID, deadlineUptimeNanoseconds: deadline)
        case .locator(let locator):
            request = tab.viewModel.makeBackendContentRequest(locator: locator, deadlineUptimeNanoseconds: deadline)
        case .destination: throw StudyWorkspaceError.invalidMembership
        }
        guard let request, request.isCurrent else { throw StudyWorkspaceError.invalidMembership }
        source.initialRequest = request; readerSources[tab.id] = source
        return request
    }

    func didLoadOriginal(tab: iOSNavigationManager.ReaderTab) throws {
        guard policy.phase == .publishing, var source = readerSources[tab.id], source.issuing, !source.issued,
              source.tab.viewModel === tab.viewModel, source.tab.book === tab.book,
              let state = source.initialRequest?.state,
              state.phase == .resolving || state.phase == .issued else { throw StudyWorkspaceError.invalidMembership }
        source.issuing = false; source.issued = true; readerSources[tab.id] = source
        try validateOriginalReaderSources()
    }

    func invalidateOriginalLoads() {
        for source in readerSources.values {
            guard let request = source.initialRequest, request.state?.phase != .completed else { continue }
            request.invalidate()
        }
    }

    var selectedTab: iOSNavigationManager.ReaderTab? {
        prepared.staged.first(where: { $0.id == prepared.requested }) ?? prepared.staged.first
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


/// Original existing objects, retained only for their single source-bound
/// selection. No replacement Book/ReaderViewModel or copied reader state.
@MainActor final class StudyWorkspaceNativeTabSelectionReservation {
    let policy: StudyWorkspaceTabSelectionReservation
    let tab: iOSNavigationManager.ReaderTab
    init(policy: StudyWorkspaceTabSelectionReservation, tab: iOSNavigationManager.ReaderTab) {
        self.policy = policy; self.tab = tab
    }
}
