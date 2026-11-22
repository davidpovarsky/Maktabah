#if DEBUG && os(iOS) && targetEnvironment(simulator) && canImport(AnytypeOriginalEditor)
import Foundation
@preconcurrency import Combine
import AnytypeOriginalEditor

/// Observes the actual annotation store and the scene's existing native mapping
/// generation. It reuses the local editor's one-way lifetime and never reads the
/// database from the original SDK's synchronous source-currentness callback.
@MainActor
final class AnnotationOriginalEditorSourceObservation {
    let annotationID: Int64
    let annotationUUID: UUID
    let profileID: UUID
    private let lifetime = AnnotationLocalEditorLifetime()
    private let presentationLifetime: AnnotationLocalEditorLifetime
    private let expectedMapping: StudyWorkspaceMappingObservation
    private weak var workspace: StudyWorkspaceNavigationAdapter?
    private let store: AnnotationStore
    private var mappingSubscription: StudyWorkspaceMappingSubscription?
    private var annotationSubscription: AnyCancellable?
    private var nativeSource: AnytypeOriginalEditorSourceLifetime?
    private var localSession: AnnotationLocalEditorSession?

    init(annotation: Annotation, store: AnnotationStore,
         workspace: StudyWorkspaceNavigationAdapter,
         presentationLifetime: AnnotationLocalEditorLifetime) throws {
        guard let id = annotation.id, id > 0,
              let uuid = annotation.ckRecordId.flatMap(UUID.init(uuidString:)),
              let mapping = workspace.mappingOwnershipObservation(),
              mapping.coverage == .liveNativeSetters,
              mapping.source.event.phase == .available,
              mapping.source.event.epoch == mapping.epoch else {
            throw AnnotationLocalEditorError.wrongOwner
        }
        self.presentationLifetime = presentationLifetime
        annotationID = id
        annotationUUID = uuid
        profileID = mapping.projection.profileID
        expectedMapping = mapping
        self.workspace = workspace
        self.store = store
        mappingSubscription = mapping.source.subscribeInvalidation(owner: self) { owner, _ in
            owner.retire()
        }
        annotationSubscription = store.events.sink { [lifetime] event in
            if Self.affects(event, id: id, uuid: uuid) { lifetime.retire() }
        }
        try requireCurrent()
    }

    var isCurrent: Bool {
        guard presentationLifetime.isCurrent, lifetime.isCurrent,
              let current = workspace?.mappingOwnershipObservation(),
              current.coverage == .liveNativeSetters,
              current.source === expectedMapping.source,
              current.owner == expectedMapping.owner,
              current.scene.utf8.elementsEqual(expectedMapping.scene.utf8),
              current.epoch == expectedMapping.epoch,
              current.projection == expectedMapping.projection,
              current.source.event.phase == .available,
              current.source.event.epoch == expectedMapping.epoch else {
            retire()
            return false
        }
        return true
    }

    func requireCurrent() throws {
        guard isCurrent else { throw AnnotationLocalEditorError.retired }
    }

    /// The actual local transaction owner must observe the same retirement as
    /// the native SDK, including while its detached save worker is suspended.
    /// Both subscriptions overlap during replacement; no await creates a gap.
    func bindLocal(_ session: AnnotationLocalEditorSession) throws {
        try requireCurrent()
        guard session.annotationUUID == annotationUUID, session.isCurrent else {
            throw AnnotationLocalEditorError.wrongOwner
        }
        if let localSession {
            guard localSession === session else { throw AnnotationLocalEditorError.wrongOwner }
            return
        }
        localSession = session
        let next = store.events.sink { [lifetime, id = annotationID, uuid = annotationUUID, session] event in
            if Self.affects(event, id: id, uuid: uuid) {
                lifetime.retire()
                session.retire()
            }
        }
        annotationSubscription?.cancel()
        annotationSubscription = next
        try requireCurrent()
    }

    /// Install the actual SDK generation only after its real binding exists.
    /// The earlier subscription covers all awaits before this handoff. During
    /// handoff the two idempotent invalidation sinks overlap without a gap.
    func bind(_ source: AnytypeOriginalEditorSourceLifetime) throws {
        try requireCurrent()
        guard nativeSource == nil, let localSession,
              source.binding.annotationUUID == annotationUUID,
              source.binding.hostProfileID.utf8.elementsEqual(profileID.uuidString.utf8) else {
            throw AnnotationLocalEditorError.wrongOwner
        }
        nativeSource = source
        let next = store.events.sink { [lifetime, id = annotationID, uuid = annotationUUID, localSession, source] event in
            if Self.affects(event, id: id, uuid: uuid) {
                lifetime.retire()
                localSession.retire()
                // Nonisolated SDK retirement also fences a queued native RPC
                // before its dispatch, even when this event came off MainActor.
                source.retire()
            }
        }
        annotationSubscription?.cancel()
        annotationSubscription = next
        try requireCurrent()
    }

    func retire() {
        lifetime.retire()
        localSession?.retire()
        nativeSource?.retire()
        mappingSubscription?.cancel()
        mappingSubscription = nil
        annotationSubscription?.cancel()
        annotationSubscription = nil
        localSession = nil
    }

    private nonisolated static func affects(_ event: AnnotationEvent, id: Int64, uuid: UUID) -> Bool {
        func matches(_ annotation: Annotation) -> Bool {
            annotation.id == id || annotation.ckRecordId.flatMap(UUID.init(uuidString:)) == uuid
        }
        switch event {
        case .added(let annotation), .updated(let annotation): return matches(annotation)
        case .deleted(let deletedID, let annotation): return deletedID == id || annotation.map(matches) == true
        case .batchUpdated(let annotations): return annotations.contains(where: matches)
        case .treeInvalidated: return true
        }
    }

    isolated deinit {
        lifetime.retire()
        localSession?.retire()
        nativeSource?.retire()
        mappingSubscription?.cancel()
        annotationSubscription?.cancel()
    }
}
#endif
