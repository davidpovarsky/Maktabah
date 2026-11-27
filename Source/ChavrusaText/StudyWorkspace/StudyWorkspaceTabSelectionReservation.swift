import Foundation

/// Retains one EXISTING native tab and the original per-scene store mapping.
/// This is ownership metadata, never permission. Only Core's original native
/// commit may invoke the owner's apply. No reader is created or hydrated here.
@MainActor
final class StudyWorkspaceTabSelectionReservation {
    enum Phase: Equatable { case reserved, applying, selected, committed, invalid, released }
    private enum Checkpoint: Equatable { case waiting, changing, published }
    let requestID: UUID
    let source: StudyWorkspaceMappingSource
    let epoch: StudyWorkspaceMappingEpoch
    let owner: ObjectIdentifier
    let scene: String
    let target: StudyWorkspaceNativeMappingTab
    let original: StudyWorkspaceMappingProjection
    let selected: StudyWorkspaceMappingProjection
    let originalWorkspace: StudyWorkspaceMappingProjection
    let persisted: StudyWorkspaceMappingProjection
    let workspaceSource: StudyWorkspaceMappingSource
    let workspaceOwner: ObjectIdentifier
    private(set) var workspaceEpoch: StudyWorkspaceMappingEpoch
    private(set) var phase: Phase = .reserved
    private var selectionPending = false
    private var selectionConsumed = false
    private var checkpoint: Checkpoint?
    private var checkpointConsumed = false

    var isPublishing: Bool { selectionPending || checkpoint != nil }
    var changesSelection: Bool { original.activeTabID != target.id }

    init(requestID: UUID, observation: StudyWorkspaceMappingObservation,
         workspace: StudyWorkspaceMappingObservation, targetID: UUID) throws {
        guard observation.coverage == .liveNativeSetters, workspace.coverage == .workspaceStoreOnly,
              observation.source !== workspace.source, observation.scene == workspace.scene,
              observation.source.event.phase == .available, observation.source.event.epoch == observation.epoch,
              workspace.source.event.phase == .available, workspace.source.event.epoch == workspace.epoch,
              observation.projection.profileID == workspace.projection.profileID,
              observation.projection.groupID == workspace.projection.groupID,
              observation.projection.profileIDs == workspace.projection.profileIDs,
              observation.projection.groupIDs == workspace.projection.groupIDs,
              observation.projection.activeTabID != nil,
              let target = observation.projection.targets[targetID], target.readerOwner != nil,
              target.workKey?.isEmpty == false,
              let saved = workspace.projection.targets[targetID],
              saved.backend == target.backend, saved.bookID == target.bookID, saved.workKey == target.workKey,
              observation.projection.targets.values.allSatisfy({ $0.backend == target.backend }),
              Set(workspace.projection.targets.filter { $0.value.backend == target.backend }.keys)
                  == Set(observation.projection.targets.keys),
              observation.projection.targets.allSatisfy({ id, value in
                  guard let document = workspace.projection.targets[id] else { return false }
                  return document.backend == value.backend && document.bookID == value.bookID
                      && document.workKey == value.workKey && value.readerOwner != nil
              }) else { throw StudyWorkspaceError.invalidMembership }
        self.requestID = requestID; source = observation.source; epoch = observation.epoch
        owner = observation.owner; scene = observation.scene
        self.target = .init(id: targetID, target: target)
        original = observation.projection; originalWorkspace = workspace.projection
        workspaceSource = workspace.source; workspaceOwner = workspace.owner; workspaceEpoch = workspace.epoch
        selected = Self.selecting(targetID, in: observation.projection)
        persisted = Self.selecting(targetID, in: workspace.projection)
    }

    private static func selecting(_ id: UUID, in projection: StudyWorkspaceMappingProjection) -> StudyWorkspaceMappingProjection {
        .init(profileID: projection.profileID, groupID: projection.groupID,
              profileIDs: projection.profileIDs, groupIDs: projection.groupIDs,
              activeTabID: id, targets: projection.targets)
    }
    private var nativeFresh: Bool {
        source.event.phase == .available && source.event.epoch == epoch
            && phase != .invalid && phase != .released
    }
    private func workspaceMatches(_ observation: StudyWorkspaceMappingObservation,
                                  projection: StudyWorkspaceMappingProjection) -> Bool {
        observation.source === workspaceSource && observation.owner == workspaceOwner
            && observation.scene == scene && observation.coverage == .workspaceStoreOnly
            && observation.epoch == workspaceEpoch && observation.projection == projection
            && workspaceSource.event.phase == .available && workspaceSource.event.epoch == workspaceEpoch
    }
    func matches(_ observation: StudyWorkspaceMappingObservation,
                 workspace: StudyWorkspaceMappingObservation) -> Bool {
        let after = phase == .selected || phase == .committed
        return nativeFresh && !isPublishing && observation.source === source && observation.epoch == epoch
            && observation.owner == owner && observation.scene == scene && observation.coverage == .liveNativeSetters
            && observation.projection == (after ? selected : original)
            && workspaceMatches(workspace, projection: phase == .committed ? persisted : originalWorkspace)
    }
    func beginApply(_ observation: StudyWorkspaceMappingObservation,
                    workspace: StudyWorkspaceMappingObservation) throws {
        guard phase == .reserved, !selectionConsumed, !checkpointConsumed, matches(observation, workspace: workspace) else {
            invalidate(); throw StudyWorkspaceError.invalidMembership
        }
        // The original selectTab no-ops when this exact tab is already selected.
        phase = changesSelection ? .applying : .selected
    }
    func permitsSelectionPublication(from before: StudyWorkspaceMappingProjection?,
                                     to after: StudyWorkspaceMappingProjection?) -> Bool {
        guard nativeFresh, phase == .applying, changesSelection, !selectionConsumed,
              !isPublishing, before == original, after == selected else { invalidate(); return false }
        // Consume at the REAL willSet boundary. A second/reentrant or equal
        // publication cannot borrow the first setter's allowance.
        selectionConsumed = true; selectionPending = true
        return true
    }
    func didPublishSelection(actual: StudyWorkspaceMappingProjection?) -> Bool {
        guard nativeFresh, phase == .applying, selectionConsumed, selectionPending,
              checkpoint == nil, actual == selected else { invalidate(); return false }
        selectionPending = false; phase = .selected
        return true
    }
    func beginCheckpoint(native: StudyWorkspaceMappingObservation,
                         workspace: StudyWorkspaceMappingObservation,
                         candidate: StudyWorkspaceMappingProjection?) throws {
        guard phase == .selected, !checkpointConsumed, matches(native, workspace: workspace),
              candidate == persisted,
              originalWorkspace == persisted || workspaceEpoch.revision < .max else {
            invalidate(); throw StudyWorkspaceError.invalidMembership
        }
        checkpointConsumed = true; checkpoint = .waiting
    }

    /// Called only from the original store's synchronous publication callback
    /// while its exact owning persistProjection transaction is on the stack.
    /// The epoch can advance only once for this known selection checkpoint.
    func observesOwnedStorePublication(_ event: StudyWorkspaceMappingEvent) -> Bool {
        guard nativeFresh, phase == .selected, let checkpoint,
              originalWorkspace != persisted,
              event.reasons == StudyWorkspaceMappingPolicy.changes(from: originalWorkspace, to: persisted) else {
            invalidate(); return false
        }
        switch (checkpoint, event.phase) {
        case (.waiting, .changing):
            guard event.epoch == nil, workspaceSource.event == event else { invalidate(); return false }
            self.checkpoint = .changing
            return true
        case (.changing, .available):
            guard let next = event.epoch, workspaceEpoch.revision < .max,
                  next.sourceID == workspaceEpoch.sourceID, next.revision == workspaceEpoch.revision + 1,
                  workspaceSource.event == event else { invalidate(); return false }
            workspaceEpoch = next; self.checkpoint = .published
            return true
        default: invalidate(); return false
        }
    }
    func finishCheckpoint(nativeProjection: StudyWorkspaceMappingProjection?,
                          workspace: StudyWorkspaceMappingObservation) throws {
        let expectedCheckpoint: Checkpoint = originalWorkspace == persisted ? .waiting : .published
        guard nativeFresh, phase == .selected, checkpointConsumed, checkpoint == expectedCheckpoint,
              nativeProjection == selected, workspaceMatches(workspace, projection: persisted) else {
            invalidate(); throw StudyWorkspaceError.invalidMembership
        }
        checkpoint = nil; phase = .committed
    }
    func finishApply(_ observation: StudyWorkspaceMappingObservation,
                     workspace: StudyWorkspaceMappingObservation) throws {
        guard phase == .committed, checkpointConsumed,
              selectionConsumed == changesSelection, matches(observation, workspace: workspace) else {
            invalidate(); throw StudyWorkspaceError.invalidMembership
        }
    }
    func invalidate() { phase = .invalid; selectionPending = false; checkpoint = nil }
    func release() { phase = .released; selectionPending = false; checkpoint = nil }
}
