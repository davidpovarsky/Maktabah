import Foundation

struct StudyWorkspaceGroupNativeTab: Equatable {
    let id: UUID
    let bookOwner: ObjectIdentifier
    let target: StudyWorkspaceMappingTarget
}

/// Actual original setter state, including the temporary states inside the
/// original empty-group close loop. Never serialized or used as permission.
struct StudyWorkspaceGroupNativeState: Equatable {
    var tabs: [StudyWorkspaceGroupNativeTab]
    var activeID: UUID?
    var selectedBookOwner: ObjectIdentifier?
    var selectedBookID: Int?
    var selectedBookMode: AppMode?
    var overviewRequested: Bool
    var overviewRevision: UInt64?
    var bookRevision: UInt64?
    var groupID: UUID?
    var backend: BackendID?
}

@MainActor
final class StudyWorkspaceGroupSelectionReservation {
    enum Phase: Equatable { case reserved, preparing, prepared, persisting, publishing, committed, invalid, released }
    enum Operation: Equatable {
        case installTabs, restoreClosingTabs, select(UUID), close(UUID), liveContext
    }
    enum Mutation: Equatable {
        case tabs([StudyWorkspaceGroupNativeTab])
        case active(UUID?)
        case book(ObjectIdentifier?, Int?)
        case overview(Bool)
        case context(UUID, BackendID)
    }
    private struct Step {
        let operation: Operation
        let mutations: [Mutation]
    }
    private struct Header: Equatable {
        struct Tab: Equatable {
            let id: UUID
            let backend: BackendID
            let bookID: Int
            let workKey: String?
            let locatorWorkKey: String?
        }
        let id: UUID
        let profileID: UUID
        let name: String
        let order: Int
        let activeID: UUID?
        let tabs: [Tab]
    }
    private struct CheckpointIdentity: Equatable {
        let profiles: [StudyProfile]
        let groups: [Header]
        let scenes: [String: StudySceneSelection]
        let lastScene: String?
        init(_ value: StudyWorkspaceSnapshot) {
            profiles = value.profiles; scenes = value.scenes; lastScene = value.lastActiveSceneID
            groups = value.groups.map { group in
                .init(id: group.id, profileID: group.profileID, name: group.name,
                    order: group.order, activeID: group.activeTabID, tabs: group.tabs.map {
                        .init(id: $0.id, backend: $0.backend, bookID: $0.session.bookId,
                            workKey: $0.session.backendLocator?.workKey,
                            locatorWorkKey: $0.session.locator?.workKey)
                    })
            }
        }
    }
    private enum StorePhase { case armed, publishing }
    private struct StorePublication {
        let expected: StudyWorkspaceSnapshot
        let checkpoint: Bool
        let reasons: Set<StudyWorkspaceMappingChangeReason>
        var phase: StorePhase = .armed
        var mappingChanging = false
        var mappingPublished = false
    }

    let requestID: UUID
    let source: StudyWorkspaceMappingSource
    let epoch: StudyWorkspaceMappingEpoch
    let workspaceSource: StudyWorkspaceMappingSource
    let scene: String
    let profileID: UUID
    let groupID: UUID
    let backend: BackendID
    let selectsProfile: Bool
    private(set) var workspaceEpoch: StudyWorkspaceMappingEpoch
    private(set) var phase: Phase = .reserved
    private(set) var snapshot: StudyWorkspaceSnapshot
    private(set) var expectedNative: StudyWorkspaceGroupNativeState
    private var steps: [Step] = []
    private var stepIndex = 0
    private var currentOperation: Operation?
    private var mutations: [Mutation] = []
    private var pendingNative: StudyWorkspaceGroupNativeState?
    private var storePublication: StorePublication?
    private var committedCheckpointIdentity: CheckpointIdentity?
    private var pendingClearArmed = false
    private var pendingClearConsumed = false
    private var pendingClearFinished = false

    var isPublishing: Bool {
        phase == .persisting || phase == .publishing || storePublication != nil || pendingNative != nil
    }
    var ownsStorePublication: Bool { storePublication?.phase == .publishing }
    var hasPendingNativePublication: Bool { pendingNative != nil }
    private var fresh: Bool {
        phase != .invalid && phase != .released
            && source.event.phase == .available && source.event.epoch == epoch
    }

    init(requestID: UUID, native: StudyWorkspaceMappingObservation,
         workspace: StudyWorkspaceMappingObservation, snapshot: StudyWorkspaceSnapshot,
         actual: StudyWorkspaceGroupNativeState, profileID: UUID, groupID: UUID,
         backend: BackendID, selectsProfile: Bool) throws {
        guard native.coverage == .liveNativeSetters, workspace.coverage == .workspaceStoreOnly,
              native.scene == workspace.scene, native.source !== workspace.source,
              native.source.event.phase == .available, native.source.event.epoch == native.epoch,
              workspace.source.event.phase == .available, workspace.source.event.epoch == workspace.epoch,
              snapshot.revision < .max, actual.bookRevision != nil, actual.overviewRevision != nil,
              let selected = snapshot.scenes[native.scene],
              selected.profileID == native.projection.profileID,
              selected.groupID == native.projection.groupID,
              selectsProfile || profileID == selected.profileID,
              actual.groupID == selected.groupID, actual.backend == backend,
              snapshot.groups.contains(where: { $0.id == groupID && $0.profileID == profileID }),
              !selectsProfile || snapshot.groups.filter({ $0.profileID == profileID })
                .sorted(by: { $0.order < $1.order }).first?.id == groupID else {
            throw StudyWorkspaceError.invalidMembership
        }
        self.requestID = requestID; source = native.source; epoch = native.epoch
        workspaceSource = workspace.source; workspaceEpoch = workspace.epoch
        scene = native.scene; self.profileID = profileID; self.groupID = groupID
        self.backend = backend; self.selectsProfile = selectsProfile
        self.snapshot = snapshot; expectedNative = actual
    }

    func matches(actual: StudyWorkspaceGroupNativeState, snapshot: StudyWorkspaceSnapshot?) -> Bool {
        fresh && pendingNative == nil && actual == expectedNative && snapshot == self.snapshot
            && (storePublication != nil || (workspaceSource.event.phase == .available
                && workspaceSource.event.epoch == workspaceEpoch))
    }

    func beginPreparation(actual: StudyWorkspaceGroupNativeState, snapshot: StudyWorkspaceSnapshot?) throws {
        guard phase == .reserved, matches(actual: actual, snapshot: snapshot) else { throw invalid() }
        phase = .preparing
    }

    /// Build the finite sequence from the actual original selectTab/closeTab
    /// behavior. Each step is armed only around that exact original call.
    func finishPreparation(staged: [StudyWorkspaceGroupNativeTab], requested: UUID?,
                           actual: StudyWorkspaceGroupNativeState, snapshot: StudyWorkspaceSnapshot?) throws {
        guard phase == .preparing, matches(actual: actual, snapshot: snapshot),
              Set(staged.map(\.id)).count == staged.count,
              staged.allSatisfy({ $0.target.backend == backend }) else { throw invalid() }
        var state = actual
        var planned: [Step] = []
        func append(_ operation: Operation, _ changes: [Mutation]) throws {
            planned.append(.init(operation: operation, mutations: changes))
            for change in changes { state = try applying(change, to: state) }
        }
        try append(.installTabs, [.tabs(staged)])
        if let selected = staged.first(where: { $0.id == requested }) ?? staged.first {
            let changes: [Mutation] = state.activeID == selected.id ? []
                : [.active(selected.id), .book(selected.bookOwner, selected.target.bookID)]
            try append(.select(selected.id), changes)
        } else {
            try append(.restoreClosingTabs, [.tabs(actual.tabs)])
            for closing in actual.tabs {
                let remaining = state.tabs.filter { $0.id != closing.id }
                var changes: [Mutation] = [.tabs(remaining)]
                if state.activeID == closing.id {
                    let next = remaining.last
                    changes += [.active(next?.id), .book(next?.bookOwner, next?.target.bookID)]
                } else if state.selectedBookID == closing.target.bookID {
                    changes.append(.book(nil, nil))
                }
                if remaining.isEmpty { changes.append(.overview(false)) }
                try append(.close(closing.id), changes)
            }
        }
        try append(.liveContext, [.context(groupID, backend)])
        steps = planned; phase = .prepared
    }

    func beginApply(actual: StudyWorkspaceGroupNativeState, snapshot: StudyWorkspaceSnapshot?) throws {
        guard phase == .prepared, !steps.isEmpty, stepIndex == 0,
              matches(actual: actual, snapshot: snapshot) else { throw invalid() }
        phase = .persisting
    }

    /// Called inside the ORIGINAL transaction closure, after its candidate is
    /// formed and before the ORIGINAL revision increment/validation/file save.
    func armStorePublication(candidate: StudyWorkspaceSnapshot, before: StudyWorkspaceSnapshot?,
                             actual: StudyWorkspaceGroupNativeState, checkpoint: Bool) throws {
        guard fresh, storePublication == nil, pendingNative == nil,
              actual == expectedNative, before == snapshot, candidate.revision == snapshot.revision,
              snapshot.revision < .max,
              (checkpoint ? phase == .committed : phase == .persisting),
              candidate.scenes[scene]?.profileID == profileID,
              candidate.scenes[scene]?.groupID == groupID,
              !selectsProfile || candidate.groups.filter({ $0.profileID == profileID })
                .sorted(by: { $0.order < $1.order }).first?.id == groupID else { throw invalid() }
        if checkpoint {
            guard let identity = committedCheckpointIdentity,
                  CheckpointIdentity(candidate) == identity else { throw invalid() }
        }
        var expected = candidate; expected.revision += 1
        storePublication = .init(expected: expected, checkpoint: checkpoint,
            reasons: StudyWorkspaceMappingPolicy.changes(
                from: StudyWorkspaceMappingPolicy.workspace(snapshot, scene: scene),
                to: StudyWorkspaceMappingPolicy.workspace(expected, scene: scene)))
    }

    func snapshotWillPublish(before: StudyWorkspaceSnapshot?, after: StudyWorkspaceSnapshot) -> Bool {
        guard fresh, var publication = storePublication, publication.phase == .armed,
              before == snapshot, after == publication.expected else { invalidate(); return false }
        // Consume before an observer can reenter with another publication.
        publication.phase = .publishing; storePublication = publication
        return true
    }

    func observesOwnedMapping(_ event: StudyWorkspaceMappingEvent) -> Bool {
        guard fresh, var publication = storePublication, publication.phase == .publishing,
              !publication.reasons.isEmpty, event.reasons == publication.reasons,
              workspaceSource.event == event else { invalidate(); return false }
        switch event.phase {
        case .changing:
            guard !publication.mappingChanging, !publication.mappingPublished,
                  event.epoch == nil else { invalidate(); return false }
            publication.mappingChanging = true
        case .available:
            guard publication.mappingChanging, !publication.mappingPublished,
                  workspaceEpoch.revision < .max, let next = event.epoch,
                  next.sourceID == workspaceEpoch.sourceID,
                  next.revision == workspaceEpoch.revision + 1 else { invalidate(); return false }
            publication.mappingPublished = true; workspaceEpoch = next
        case .unavailable: invalidate(); return false
        }
        storePublication = publication
        return true
    }

    func snapshotDidPublish(_ actual: StudyWorkspaceSnapshot) -> Bool {
        guard fresh, let publication = storePublication, publication.phase == .publishing,
              actual == publication.expected,
              publication.reasons.isEmpty || publication.mappingPublished,
              workspaceSource.event.phase == .available, workspaceSource.event.epoch == workspaceEpoch else {
            invalidate(); return false
        }
        snapshot = actual; storePublication = nil
        if !publication.checkpoint { phase = .publishing }
        return true
    }

    func beginOperation(_ operation: Operation, actual: StudyWorkspaceGroupNativeState) throws {
        guard fresh, phase == .publishing, storePublication == nil,
              currentOperation == nil, pendingNative == nil, actual == expectedNative,
              steps.indices.contains(stepIndex), steps[stepIndex].operation == operation else { throw invalid() }
        currentOperation = operation; mutations = steps[stepIndex].mutations
    }

    func willPublish(_ mutation: Mutation, actual: StudyWorkspaceGroupNativeState) -> Bool {
        guard fresh, phase == .publishing, currentOperation != nil, pendingNative == nil,
              actual == expectedNative, mutations.first == mutation,
              let after = try? applying(mutation, to: expectedNative) else { invalidate(); return false }
        mutations.removeFirst(); pendingNative = after
        return true
    }

    func didPublish(actual: StudyWorkspaceGroupNativeState) -> Bool {
        guard fresh, phase == .publishing, currentOperation != nil,
              let pendingNative, actual == pendingNative else { invalidate(); return false }
        expectedNative = actual; self.pendingNative = nil
        return true
    }

    func finishOperation(_ operation: Operation, actual: StudyWorkspaceGroupNativeState) throws {
        guard fresh, phase == .publishing, currentOperation == operation,
              mutations.isEmpty, pendingNative == nil, actual == expectedNative else { throw invalid() }
        currentOperation = nil; stepIndex += 1
    }

    func finishApply(actual: StudyWorkspaceGroupNativeState, snapshot: StudyWorkspaceSnapshot?) throws {
        guard phase == .publishing, stepIndex == steps.count,
              currentOperation == nil, mutations.isEmpty, storePublication == nil,
              pendingClearFinished,
              matches(actual: actual, snapshot: snapshot), actual.groupID == groupID,
              actual.backend == backend else { throw invalid() }
        phase = .committed; committedCheckpointIdentity = .init(self.snapshot)
    }

    /// The original coordinator publishes pendingBackendID = nil exactly once
    /// after its original native publisher. This is the only owned backend
    /// notification; even an equal, nested or aborted foreign write revokes us.
    func beginPendingBackendClear(actual: StudyWorkspaceGroupNativeState,
                                  snapshot: StudyWorkspaceSnapshot?) throws {
        guard phase == .publishing, stepIndex == steps.count, currentOperation == nil,
              !pendingClearArmed, !pendingClearConsumed, !pendingClearFinished,
              matches(actual: actual, snapshot: snapshot) else { throw invalid() }
        pendingClearArmed = true
    }

    func backendWillPublish() -> Bool {
        guard fresh, phase == .publishing, pendingClearArmed,
              !pendingClearConsumed, !pendingClearFinished else { invalidate(); return false }
        // Consume before another subscriber or callback can publish again.
        pendingClearArmed = false; pendingClearConsumed = true
        return true
    }

    func finishPendingBackendClear(actual: StudyWorkspaceGroupNativeState,
                                   snapshot: StudyWorkspaceSnapshot?, pendingIsNil: Bool) throws {
        guard phase == .publishing, !pendingClearArmed, pendingClearConsumed,
              !pendingClearFinished, pendingIsNil,
              matches(actual: actual, snapshot: snapshot) else { throw invalid() }
        pendingClearFinished = true
    }

    private func applying(_ mutation: Mutation, to before: StudyWorkspaceGroupNativeState) throws
        -> StudyWorkspaceGroupNativeState {
        var after = before
        switch mutation {
        case .tabs(let tabs): after.tabs = tabs
        case .active(let id): after.activeID = id
        case .book(let owner, let id):
            guard let revision = before.bookRevision, revision < .max else { throw StudyWorkspaceError.invalidMembership }
            after.selectedBookOwner = owner; after.selectedBookID = id; after.bookRevision = revision + 1
            after.selectedBookMode = owner == nil ? nil : .viewer
        case .overview(let requested):
            guard let revision = before.overviewRevision, revision < .max else { throw StudyWorkspaceError.invalidMembership }
            after.overviewRequested = requested; after.overviewRevision = revision + 1
        case .context(let group, let backend): after.groupID = group; after.backend = backend
        }
        return after
    }

    private func invalid() -> StudyWorkspaceError { invalidate(); return .invalidMembership }
    func invalidate() {
        phase = .invalid; currentOperation = nil; pendingNative = nil; storePublication = nil; mutations = []
        pendingClearArmed = false
    }
    func release() { invalidate(); phase = .released }
}
