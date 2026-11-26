#if os(iOS) && canImport(AnytypeOriginalEditor)
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
    private let originalRecordID: String
    let profileID: UUID
    private let lifetime = AnnotationLocalEditorLifetime()
    private let presentationLifetime: AnnotationLocalEditorLifetime
    private let expectedMapping: StudyWorkspaceMappingObservation
    private weak var workspace: StudyWorkspaceNavigationAdapter?
    private let store: AnnotationStore
    private var mappingSubscription: StudyWorkspaceMappingSubscription?
    private var annotationSubscription: AnyCancellable?
    private var nativeSource: AnytypeOriginalEditorSourceLifetime?
    private var nativeImport: AnytypeOriginalAnnotationImportSourceLifetime?
    private var localAnnotation: AnytypeOriginalEditorLocalAnnotationSourceLifetime?
    private var localSession: AnnotationLocalEditorSession?

    init(annotation: Annotation, store: AnnotationStore,
         workspace: StudyWorkspaceNavigationAdapter,
         presentationLifetime: AnnotationLocalEditorLifetime) throws {
        guard let id = annotation.id, id > 0,
              let recordID = annotation.ckRecordId,
              let uuid = try store.resolveAnnotationExchangeIdentity(annotation: annotation),
              let mapping = workspace.mappingOwnershipObservation(),
              mapping.coverage == .liveNativeSetters,
              mapping.source.event.phase == .available,
              mapping.source.event.epoch == mapping.epoch else {
            throw AnnotationLocalEditorError.wrongOwner
        }
        self.presentationLifetime = presentationLifetime
        annotationID = id
        annotationUUID = uuid
        originalRecordID = recordID
        profileID = mapping.projection.profileID
        expectedMapping = mapping
        self.workspace = workspace
        self.store = store
        mappingSubscription = mapping.source.subscribeInvalidation(owner: self) { owner, _ in
            owner.retire()
        }
        annotationSubscription = store.events.sink { [lifetime, recordID] event in
            if Self.affects(event, id: id, uuid: uuid, recordID: recordID) { lifetime.retire() }
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
        let next = store.events.sink { [lifetime, id = annotationID, uuid = annotationUUID, recordID = originalRecordID, session, sessionID = session.id] event in
            if Self.affects(event, id: id, uuid: uuid, recordID: recordID, sessionID: sessionID) {
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
        guard nativeSource == nil, nativeImport == nil, localAnnotation == nil, let localSession,
              source.binding.annotationUUID == annotationUUID,
              source.binding.hostProfileID.utf8.elementsEqual(profileID.uuidString.utf8) else {
            throw AnnotationLocalEditorError.wrongOwner
        }
        nativeSource = source
        let next = store.events.sink { [lifetime, id = annotationID, uuid = annotationUUID, recordID = originalRecordID, localSession, source, sessionID = localSession.id] event in
            if Self.affects(event, id: id, uuid: uuid, recordID: recordID, sessionID: sessionID) {
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

    /// A completed read-only original search never becomes write authority.
    /// Release only that exact lookup token before binding the separately
    /// selected native read. The Host/session observers remain installed.
    func finishOriginalCopyDiscovery(_ source: AnytypeOriginalEditorLocalAnnotationSourceLifetime) throws {
        try requireCurrent()
        guard localAnnotation === source, nativeSource == nil, nativeImport == nil else {
            throw AnnotationLocalEditorError.wrongOwner
        }
        source.retire()
        localAnnotation = nil
        try requireCurrent()
    }

    /// A pre-import saved source has no existing-object binding. Link the
    /// actual source/presentation generations before native preparation begins.
    func bindImport(_ source: AnytypeOriginalAnnotationImportSourceLifetime,
                    local: AnnotationLocalEditorSession) throws {
        do {
            try requireCurrent()
            guard nativeSource == nil, nativeImport == nil, localAnnotation == nil,
                  localSession === local,
                  source.source.annotationUUID == annotationUUID,
                  source.source.preparedSessionID == local.id else {
                throw AnnotationLocalEditorError.wrongOwner
            }
            try lifetime.bindNativeImportRetirement(source)
            try presentationLifetime.bindNativeImportRetirement(source)
            nativeImport = source
            try requireCurrent()
            guard source.isCurrent else { throw AnnotationLocalEditorError.retired }
        } catch {
            source.retire()
            throw error
        }
    }


    /// Preserve the already-observed native read owner while binding the new,
    /// separate conditional replacement owner. Both retire on the same source,
    /// DB, presentation and scene invalidation; neither is adopted from history.
    func bindReplacement(_ source: AnytypeOriginalAnnotationImportSourceLifetime,
                         readSource: AnytypeOriginalEditorSourceLifetime,
                         local: AnnotationLocalEditorSession) throws {
        do {
            try requireCurrent()
            let binding = readSource.binding
            guard nativeSource === readSource, readSource.isCurrent,
                  nativeImport == nil, localAnnotation == nil, localSession === local,
                  source.source.annotationUUID == annotationUUID,
                  source.source.preparedSessionID == local.id,
                  source.source.annotationUUID == binding.annotationUUID,
                  source.source.savedRevision == binding.expectedRevision,
                  source.source.sourceDigest == binding.sourceWitnessSHA256,
                  source.source.accountID.utf8.elementsEqual(binding.accountID.utf8),
                  source.source.spaceID.utf8.elementsEqual(binding.spaceID.utf8) else {
                throw AnnotationLocalEditorError.wrongOwner
            }
            try lifetime.bindNativeImportRetirement(source)
            try presentationLifetime.bindNativeImportRetirement(source)
            nativeImport = source
            try requireCurrent()
            guard source.isCurrent else { throw AnnotationLocalEditorError.retired }
        } catch {
            source.retire()
            throw error
        }
    }

    /// Link the canonical saved row, native draft, original DB and presentation
    /// before the factory can suspend or dispatch any native work.
    func bindLocalAnnotation(
        _ source: AnytypeOriginalEditorLocalAnnotationSourceLifetime,
        local: AnnotationLocalEditorSession,
        snapshot: AnnotationLocalEditorSnapshot
    ) throws {
        do {
            try requireCurrent()
            guard nativeSource == nil, nativeImport == nil, localAnnotation == nil,
                  localSession === local,
                  source.source.annotationUUID == annotationUUID,
                  source.source.hostProfileID.utf8.elementsEqual(profileID.uuidString.utf8) else {
                throw AnnotationLocalEditorError.wrongOwner
            }
            try local.bindLocalAnnotationRetirement(source, snapshot: snapshot)
            try lifetime.bindLocalAnnotationRetirement(source)
            try presentationLifetime.bindLocalAnnotationRetirement(source)
            localAnnotation = source
            let next = store.events.sink { [lifetime, id = annotationID, uuid = annotationUUID, recordID = originalRecordID, local, source, sessionID = local.id] event in
                if Self.affects(event, id: id, uuid: uuid, recordID: recordID, sessionID: sessionID) {
                    lifetime.retire()
                    local.retire()
                    source.retire()
                }
            }
            annotationSubscription?.cancel()
            annotationSubscription = next
            try requireCurrent()
            guard source.isCurrent else { throw AnnotationLocalEditorError.retired }
        } catch {
            source.retire()
            throw error
        }
    }

    func retire() {
        lifetime.retire()
        localSession?.retire()
        nativeSource?.retire()
        nativeImport?.retire()
        localAnnotation?.retire()
        mappingSubscription?.cancel()
        mappingSubscription = nil
        annotationSubscription?.cancel()
        annotationSubscription = nil
        localSession = nil
    }

    private nonisolated static func affects(_ event: AnnotationEvent, id: Int64, uuid: UUID,
                                            recordID: String, sessionID: UUID? = nil) -> Bool {
        func matches(_ annotation: Annotation) -> Bool {
            annotation.id == id || annotation.ckRecordId.flatMap(UUID.init(uuidString:)) == uuid
                || annotation.ckRecordId.map({ $0.utf8.elementsEqual(recordID.utf8) }) == true
        }
        switch event {
        case .added(let annotation), .updated(let annotation): return matches(annotation)
        case .deleted(let deletedID, let annotation): return deletedID == id || annotation.map(matches) == true
        case .batchUpdated(let annotations): return annotations.contains(where: matches)
        case .treeInvalidated: return true
        case .localEditorCommitted(let committingSessionID):
            // Keep the committing owner alive long enough to deliver its receipt.
            // Other editors still observe the same source invalidation.
            return committingSessionID != sessionID
        }
    }

    isolated deinit {
        lifetime.retire()
        localSession?.retire()
        nativeSource?.retire()
        nativeImport?.retire()
        localAnnotation?.retire()
        mappingSubscription?.cancel()
        annotationSubscription?.cancel()
    }
}
#endif
