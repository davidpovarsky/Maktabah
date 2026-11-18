import Foundation
import Observation

/// Source-owned change metadata only. These values never authorize navigation
/// and are deliberately absent from Codable persistence and public wire DTOs.
enum StudyWorkspaceMappingChangeReason: String, Hashable, Sendable {
    case availability, selection, profileMembership, groupMembership
    case tabMembership, targetIdentity, backend, ownerLifetime, epochExhausted, readerReservation
}

struct StudyWorkspaceMappingEpoch: Equatable, Sendable {
    let sourceID: UUID
    let revision: UInt64
}

struct StudyWorkspaceMappingEvent: Equatable, Sendable {
    enum Phase: Equatable, Sendable { case unavailable, changing, available }
    let phase: Phase
    let epoch: StudyWorkspaceMappingEpoch?
    let reasons: Set<StudyWorkspaceMappingChangeReason>
}

enum StudyWorkspaceMappingCoverage: Sendable { case workspaceStoreOnly, liveNativeSetters }

struct StudyWorkspaceMappingObservation {
    let source: StudyWorkspaceMappingSource
    let owner: ObjectIdentifier
    let scene: String
    let epoch: StudyWorkspaceMappingEpoch
    let coverage: StudyWorkspaceMappingCoverage
    let projection: StudyWorkspaceMappingProjection
}

@MainActor final class StudyWorkspaceMappingSubscription {
    private var source: StudyWorkspaceMappingSource?
    private let id: UUID
    fileprivate init(source: StudyWorkspaceMappingSource, id: UUID) { self.source = source; self.id = id }
    func cancel() { source?.removeListener(id); source = nil }
    isolated deinit { source?.removeListener(id) }
}

/// One fixed observable property per real owner/scene. During publication its
/// revision is nil: an invalidation callback cannot admit a new request against
/// the old mapping with a new, prematurely stable epoch.
@MainActor @Observable
final class StudyWorkspaceMappingSource {
    private(set) var event: StudyWorkspaceMappingEvent
    var mappingRevision: UInt64? { event.epoch?.revision }
    @ObservationIgnored private let sourceID = UUID()
    @ObservationIgnored private var revision: UInt64 = 0
    @ObservationIgnored private let maximumRevision: UInt64
    @ObservationIgnored private var retired = false
    private struct Listener {
        weak var owner: AnyObject?
        let callback: @MainActor (AnyObject, StudyWorkspaceMappingEvent) -> Void
    }
    @ObservationIgnored private var listeners: [UUID: Listener] = [:]

    init(available: Bool, maximumRevision: UInt64 = .max) {
        self.maximumRevision = maximumRevision
        event = .init(phase: .unavailable, epoch: nil, reasons: [])
        if available { event = .init(phase: .available, epoch: .init(sourceID: sourceID, revision: 0), reasons: []) }
    }

    /// One subscription per consumer/owner lifetime, never per request. The
    /// callback receives its weak owner as an argument instead of retaining it.
    func subscribe<Owner: AnyObject>(owner: Owner, _ listener: @escaping @MainActor (Owner, StudyWorkspaceMappingEvent) -> Void) -> StudyWorkspaceMappingSubscription {
        let id = UUID()
        listeners = listeners.filter { $0.value.owner != nil && $0.value.owner !== owner }
        guard !retired else { return .init(source: self, id: id) }
        listeners[id] = .init(owner: owner, callback: { owner, event in
            guard let owner = owner as? Owner else { return }
            listener(owner, event)
        })
        return .init(source: self, id: id)
    }

    /// Authority consumers invalidate only before publication/unavailability.
    /// A ready notification must not revoke a new admission made after publish.
    func subscribeInvalidation<Owner: AnyObject>(owner: Owner, _ listener: @escaping @MainActor (Owner, StudyWorkspaceMappingEvent) -> Void) -> StudyWorkspaceMappingSubscription {
        subscribe(owner: owner) { owner, event in
            guard event.phase != .available else { return }
            listener(owner, event)
        }
    }

    func removeListener(_ id: UUID) { listeners.removeValue(forKey: id) }

    func beginChange(_ reasons: Set<StudyWorkspaceMappingChangeReason>) {
        guard !retired, !reasons.isEmpty else { return }
        // Overflow fails closed rather than recycling an old epoch.
        guard revision < maximumRevision else { retire(reason: .epochExhausted); return }
        revision += 1
        publish(.init(phase: .changing, epoch: nil, reasons: reasons))
    }

    func finishChange(available: Bool) {
        guard !retired else { return }
        let phase: StudyWorkspaceMappingEvent.Phase = available ? .available : .unavailable
        let next = StudyWorkspaceMappingEvent(phase: phase,
            epoch: available ? .init(sourceID: sourceID, revision: revision) : nil, reasons: event.reasons)
        if next != event { publish(next) }
    }

    func retire(reason: StudyWorkspaceMappingChangeReason = .ownerLifetime) {
        guard !retired else { return }
        retired = true
        publish(.init(phase: .unavailable, epoch: nil, reasons: [reason]))
        listeners.removeAll()
    }

    private func publish(_ next: StudyWorkspaceMappingEvent) {
        event = next
        for id in Array(listeners.keys) {
            guard let listener = listeners[id] else { continue }
            guard let owner = listener.owner else { listeners.removeValue(forKey: id); continue }
            listener.callback(owner, next)
        }
    }
}

struct StudyWorkspaceMappingTarget: Equatable {
    let backend: BackendID
    let bookID: Int
    let workKey: String?
    // Used only by live owners; a replaced reader object is a different lifetime.
    let readerOwner: ObjectIdentifier?
}

struct StudyWorkspaceMappingProjection: Equatable {
    let profileID: UUID
    let groupID: UUID
    let profileIDs: Set<UUID>
    let groupIDs: Set<UUID>
    let activeTabID: UUID?
    let targets: [UUID: StudyWorkspaceMappingTarget]
}

struct StudyWorkspaceNativeMappingTab {
    let id: UUID
    let target: StudyWorkspaceMappingTarget
}

enum StudyWorkspaceMappingPolicy {
    static func native(workspace: StudyWorkspaceMappingProjection?, groupID: UUID?,
                       backend: BackendID?, tabs: [StudyWorkspaceNativeMappingTab], activeID: UUID?) -> StudyWorkspaceMappingProjection? {
        guard let workspace, groupID == workspace.groupID, let backend,
              Set(tabs.map(\.id)).count == tabs.count,
              tabs.allSatisfy({ $0.target.backend == backend }),
              activeID.map({ id in tabs.contains { $0.id == id } }) ?? true else { return nil }
        return .init(profileID: workspace.profileID, groupID: workspace.groupID,
            profileIDs: workspace.profileIDs, groupIDs: workspace.groupIDs,
            activeTabID: activeID, targets: Dictionary(uniqueKeysWithValues: tabs.map { ($0.id, $0.target) }))
    }

    /// No position, scroll, selection range, title, ordering or persisted revision
    /// participates. Invalid/missing owner data has no stable projection.
    static func workspace(_ snapshot: StudyWorkspaceSnapshot?, scene: String) -> StudyWorkspaceMappingProjection? {
        guard let snapshot, (try? snapshot.validate()) != nil,
              let selection = snapshot.scenes[scene],
              let group = snapshot.groups.first(where: { $0.id == selection.groupID && $0.profileID == selection.profileID }) else { return nil }
        if let requested = selection.activeTabIDsByGroup?[group.id], !group.tabs.contains(where: { $0.id == requested }) { return nil }
        var targets: [UUID: StudyWorkspaceMappingTarget] = [:]
        for document in group.tabs {
            let primary = document.session.backendLocator?.workKey
            let current = document.session.locator?.workKey
            if let primary, let current, primary != current { return nil }
            targets[document.id] = .init(backend: document.backend, bookID: document.session.bookId,
                workKey: primary ?? current, readerOwner: nil)
        }
        return .init(profileID: selection.profileID, groupID: group.id,
            profileIDs: [selection.profileID],
            groupIDs: [group.id],
            activeTabID: selection.activeTabIDsByGroup?[group.id] ?? group.activeTabID, targets: targets)
    }

    static func changes(from old: StudyWorkspaceMappingProjection?, to new: StudyWorkspaceMappingProjection?) -> Set<StudyWorkspaceMappingChangeReason> {
        guard old != new else { return [] }
        guard let old, let new else { return [.availability] }
        var result = Set<StudyWorkspaceMappingChangeReason>()
        if old.profileID != new.profileID || old.groupID != new.groupID || old.activeTabID != new.activeTabID { result.insert(.selection) }
        if old.profileIDs != new.profileIDs { result.insert(.profileMembership) }
        if old.groupIDs != new.groupIDs { result.insert(.groupMembership) }
        return result.union(targetChanges(from: old.targets, to: new.targets))
    }

    static func nativeTargetChanges(from old: [StudyWorkspaceNativeMappingTab], to new: [StudyWorkspaceNativeMappingTab]) -> Set<StudyWorkspaceMappingChangeReason> {
        targetChanges(from: Dictionary(old.map { ($0.id, $0.target) }, uniquingKeysWith: { first, _ in first }),
                      to: Dictionary(new.map { ($0.id, $0.target) }, uniquingKeysWith: { first, _ in first }))
    }

    private static func targetChanges(from old: [UUID: StudyWorkspaceMappingTarget], to new: [UUID: StudyWorkspaceMappingTarget]) -> Set<StudyWorkspaceMappingChangeReason> {
        var result = Set<StudyWorkspaceMappingChangeReason>()
        if Set(old.keys) != Set(new.keys) { result.insert(.tabMembership) }
        for id in Set(old.keys).intersection(new.keys) {
            guard let lhs = old[id], let rhs = new[id] else { continue }
            if lhs.backend != rhs.backend { result.insert(.backend) }
            if lhs.bookID != rhs.bookID || lhs.workKey != rhs.workKey { result.insert(.targetIdentity) }
            if lhs.readerOwner != rhs.readerOwner { result.insert(.ownerLifetime) }
        }
        return result
    }
}


/// A scene-owner reservation is mapping data, never a navigation permission.
/// Core's original grant remains mandatory at the actual synchronous apply.
/// Only two exact native publications are owned: append this new tab, then
/// activate this same tab. Every other transition invalidates the reservation.
@MainActor
final class StudyWorkspaceReaderReservation {
    enum Phase: Equatable { case reserved, applying, committed, invalid, released }
    let requestID: UUID
    let source: StudyWorkspaceMappingSource
    let epoch: StudyWorkspaceMappingEpoch
    let owner: ObjectIdentifier
    let scene: String
    let target: StudyWorkspaceNativeMappingTab
    let original: StudyWorkspaceMappingProjection
    let originalWorkspace: StudyWorkspaceMappingProjection
    let tabsPublished: StudyWorkspaceMappingProjection
    let committed: StudyWorkspaceMappingProjection
    let persisted: StudyWorkspaceMappingProjection
    private(set) var phase: Phase = .reserved
    private var step = 0
    private var pending: (step: Int, projection: StudyWorkspaceMappingProjection)?
    var isPublishing: Bool { pending != nil }

    init(requestID: UUID, observation: StudyWorkspaceMappingObservation,
         workspace: StudyWorkspaceMappingProjection, target: StudyWorkspaceNativeMappingTab) throws {
        guard observation.coverage == .liveNativeSetters,
              observation.source.event.phase == .available,
              observation.source.event.epoch == observation.epoch,
              observation.projection.profileID == workspace.profileID,
              observation.projection.groupID == workspace.groupID,
              observation.projection.profileIDs == workspace.profileIDs,
              observation.projection.groupIDs == workspace.groupIDs,
              observation.projection.targets[target.id] == nil,
              workspace.targets[target.id] == nil, target.target.readerOwner != nil,
              target.target.workKey?.isEmpty == false,
              observation.projection.targets.values.allSatisfy({ $0.backend == target.target.backend }) else {
            throw StudyWorkspaceError.invalidMembership
        }
        self.requestID = requestID; source = observation.source; epoch = observation.epoch
        owner = observation.owner; scene = observation.scene; self.target = target
        original = observation.projection; originalWorkspace = workspace
        var next = observation.projection.targets; next[target.id] = target.target
        tabsPublished = Self.replacing(observation.projection, targets: next, active: observation.projection.activeTabID)
        committed = Self.replacing(observation.projection, targets: next, active: target.id)
        // The original checkpoint merges this backend's exact native tabs with
        // preserved documents from other backends. UI object IDs stay private.
        var saved = workspace.targets.filter { $0.value.backend != target.target.backend }
        for (id, native) in next {
            saved[id] = .init(backend: native.backend, bookID: native.bookID,
                             workKey: native.workKey, readerOwner: nil)
        }
        persisted = Self.replacing(workspace, targets: saved, active: target.id)
    }

    private static func replacing(_ original: StudyWorkspaceMappingProjection,
                                  targets: [UUID: StudyWorkspaceMappingTarget], active: UUID?) -> StudyWorkspaceMappingProjection {
        .init(profileID: original.profileID, groupID: original.groupID,
              profileIDs: original.profileIDs, groupIDs: original.groupIDs,
              activeTabID: active, targets: targets)
    }
    private var fresh: Bool {
        source.event.phase == .available && source.event.epoch == epoch
            && phase != .invalid && phase != .released
    }
    private var expected: StudyWorkspaceMappingProjection {
        step == 0 ? original : step == 1 ? tabsPublished : committed
    }
    func matches(_ observation: StudyWorkspaceMappingObservation) -> Bool {
        fresh && pending == nil && observation.source === source && observation.epoch == epoch
            && observation.owner == owner && observation.scene == scene
            && observation.coverage == .liveNativeSetters && observation.projection == expected
    }
    func beginApply(_ observation: StudyWorkspaceMappingObservation) throws {
        guard phase == .reserved, step == 0, matches(observation) else {
            invalidate(); throw StudyWorkspaceError.invalidMembership
        }
        phase = .applying
    }
    func permitsTabsPublication(from before: StudyWorkspaceMappingProjection?,
                                to after: StudyWorkspaceMappingProjection?) -> Bool {
        guard fresh, phase == .applying, step == 0, pending == nil,
              before == original, after == tabsPublished else { invalidate(); return false }
        pending = (1, tabsPublished); return true
    }
    func permitsSelectionPublication(from before: StudyWorkspaceMappingProjection?,
                                     to after: StudyWorkspaceMappingProjection?) -> Bool {
        guard fresh, phase == .applying, step == 1, pending == nil,
              before == tabsPublished, after == committed else { invalidate(); return false }
        pending = (2, committed); return true
    }
    /// Called by the real didSet hook, after publication, not from desired args.
    func didPublish(actual: StudyWorkspaceMappingProjection?) -> Bool {
        guard fresh, let pending, actual == pending.projection else { invalidate(); return false }
        step = pending.step; self.pending = nil
        if step == 2 { phase = .committed }
        return true
    }
    func finishApply(_ observation: StudyWorkspaceMappingObservation) throws {
        guard phase == .committed, step == 2, matches(observation) else {
            invalidate(); throw StudyWorkspaceError.invalidMembership
        }
    }
    /// A later normal checkpoint may persist only the same already committed
    /// native target. This never permits a user group/profile/tab mutation.
    func permitsCheckpoint(from before: StudyWorkspaceMappingProjection?,
                           to after: StudyWorkspaceMappingProjection?,
                           actual: StudyWorkspaceMappingObservation) -> Bool {
        phase == .committed && matches(actual) && after == persisted
            && (before == originalWorkspace || before == persisted)
    }
    func invalidate() { phase = .invalid; pending = nil }
    func release() { phase = .released; pending = nil }
}
