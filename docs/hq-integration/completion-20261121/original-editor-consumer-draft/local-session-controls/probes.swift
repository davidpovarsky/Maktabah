import Foundation
import Synchronization

// Explicit portable persistence, event, and CloudKit probes. No database,
// transaction, original Combine subscription, or network transport runs here.
enum ProbeError: Error { case invariant(String), timeout }
struct Annotation: Sendable {
    let id: Int64?
    let ckRecordId: String?
    let note: String?
}
struct AnnotationLocalEditorBodyFormat: Sendable, Hashable {}
enum TorahAnnotationEnvelope {
    struct RichBody: Sendable {}
}
struct AnnotationLocalEditorSnapshot: Sendable {
    let annotation: Annotation
    let sessionID: UUID
}
struct AnnotationLocalEditorIntent: Sendable {
    let mutationID: UUID
    let snapshot: AnnotationLocalEditorSnapshot
}
struct AnnotationExchangeCommit: Sendable, Equatable {
    let mutationID: UUID
    let revision: Int64
    let replayed: Bool
}
struct AnnotationLocalEditorCommitted: Sendable {
    let receipt: AnnotationExchangeCommit
    let snapshot: AnnotationLocalEditorSnapshot
}
enum AnnotationLocalEditorOutcome: Sendable {
    case committed(AnnotationLocalEditorCommitted)
    case completedWithoutOwnership(AnnotationExchangeCommit)
}
struct AnnotationExchangePlatformDigest: Sendable {}

final class HeldWorkerProbe: @unchecked Sendable {
    enum Position: Sendable { case none, beforeCurrentness, afterCommittedReceipt }
    struct State: Sendable {
        var entered = false
        var calls = 0
        var committedReceipts = 0
        var owner: AnnotationLocalEditorLifetime?
    }
    let position: Position
    let state = Mutex(State())
    private let release = DispatchSemaphore(value: 0)

    init(_ position: Position) { self.position = position }
    func waitAtHoldPoint() throws {
        state.withLock { $0.entered = true }
        guard release.wait(timeout: .now() + 12) == .success else { throw ProbeError.timeout }
    }
    func resume() { release.signal() }
    func waitUntilEntered() async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(5))
        while !state.withLock({ $0.entered }) {
            guard clock.now < deadline else { throw ProbeError.timeout }
            try await clock.sleep(for: .milliseconds(1))
        }
    }
}

struct AnnotationLocalEditorConnection: Sendable {
    let databaseURL = URL(fileURLWithPath: "C:/explicit-probe/not-a-database.sqlite")
    let lifetime: AnnotationLocalEditorLifetime
    let probe: HeldWorkerProbe
}

final class AnnotationLocalEditorPersistence: Sendable {
    let connection: AnnotationLocalEditorConnection
    let annotationID: Int64
    let annotationUUID: UUID
    let sessionID: UUID
    let owner: AnnotationLocalEditorLifetime

    init(connection: AnnotationLocalEditorConnection, annotationID: Int64, annotationUUID: UUID,
         sessionID: UUID, owner: AnnotationLocalEditorLifetime,
         formats: Set<AnnotationLocalEditorBodyFormat>, digest: AnnotationExchangePlatformDigest) throws {
        self.connection = connection
        self.annotationID = annotationID
        self.annotationUUID = annotationUUID
        self.sessionID = sessionID
        self.owner = owner
        connection.probe.state.withLock { $0.owner = owner }
    }
    var isOwned: Bool { owner.isCurrent && connection.lifetime.isCurrent }
    func read() throws -> AnnotationLocalEditorSnapshot {
        try owner.requireCurrent()
        return .init(annotation: .init(id: annotationID, ckRecordId: annotationUUID.uuidString, note: "probe"), sessionID: sessionID)
    }
    func prepare(snapshot: AnnotationLocalEditorSnapshot, mutationID: UUID,
                 body: TorahAnnotationEnvelope.RichBody, textPreview: String,
                 editorRevision: String?) throws -> AnnotationLocalEditorIntent {
        try owner.requireCurrent()
        return .init(mutationID: mutationID, snapshot: snapshot)
    }
    func commit(_ intent: AnnotationLocalEditorIntent) throws -> AnnotationLocalEditorCommitted {
        let probe = connection.probe
        probe.state.withLock { $0.calls += 1 }
        if probe.position == .beforeCurrentness { try probe.waitAtHoldPoint() }
        try owner.requireCurrent()
        try connection.lifetime.requireCurrent()
        probe.state.withLock { $0.committedReceipts += 1 }
        let saved = AnnotationLocalEditorCommitted(
            receipt: .init(mutationID: intent.mutationID, revision: 1, replayed: false),
            snapshot: intent.snapshot
        )
        // Explicitly model an already committed result: no later retirement
        // turns this receipt into a rollback or silently drops it.
        if probe.position == .afterCommittedReceipt { try probe.waitAtHoldPoint() }
        return saved
    }
    func requireUnchanged(_ snapshot: AnnotationLocalEditorSnapshot) throws { try owner.requireCurrent() }
    func canDeliver(_ saved: AnnotationLocalEditorCommitted) -> Bool { isOwned }
    func commitForOwnedCloud(_ intent: AnnotationLocalEditorIntent) throws -> AnnotationLocalEditorCloudCommitted {
        .init(saved: try commit(intent))
    }
}

enum AnnotationEvent { case treeInvalidated }
@MainActor final class AnnotationEventProbe {
    var sent = 0
    var listener: ((AnnotationEvent) -> Void)?
    func send(_ event: AnnotationEvent) { sent += 1; listener?(event) }
}
@MainActor final class RepositoryProbe {
    let connection: AnnotationLocalEditorConnection
    init(probe: HeldWorkerProbe) {
        connection = .init(lifetime: AnnotationLocalEditorLifetime(), probe: probe)
    }
    func captureLocalEditorConnection() throws -> AnnotationLocalEditorConnection { connection }
}
@MainActor final class AnnotationStore {
    let repository: RepositoryProbe
    let events = AnnotationEventProbe()
    var cacheInvalidations = 0
    init(probe: HeldWorkerProbe) { repository = RepositoryProbe(probe: probe) }
    func clearAllCaches() { cacheInvalidations += 1 }
}
@MainActor final class CloudKitSyncManager {
    static let shared = CloudKitSyncManager()
    var uploads = 0
    func upload(annotations: [Annotation], trackPending: Bool) { uploads += 1 }
}

// Compile-only probes for the unchanged optional owned-cloud methods. None of
// these methods is executed and they provide no CloudKit acceptance credit.
enum AnnotationLocalEditorCloudDeferral: Error { case invalidPublication }
struct AnnotationLocalEditorCloudClient: Sendable {
    static func original() -> Self? { nil }
}
struct AnnotationLocalEditorCloudPreparation: Sendable {
    let intent: AnnotationLocalEditorIntent
    static func prepare(intent: AnnotationLocalEditorIntent, storage: AnnotationLocalEditorPersistence,
                        client: AnnotationLocalEditorCloudClient?) async throws -> Self { .init(intent: intent) }
    func consume(for persistence: AnnotationLocalEditorPersistence) throws {}
}
struct AnnotationLocalEditorCloudCommitted: Sendable { let saved: AnnotationLocalEditorCommitted }
struct AnnotationLocalEditorCloudPublication: Sendable {
    init(storage: AnnotationLocalEditorPersistence, preparation: AnnotationLocalEditorCloudPreparation,
         committed: AnnotationLocalEditorCloudCommitted) {}
}
struct AnnotationLocalEditorCloudSaveOutcome: Sendable {
    let local: AnnotationLocalEditorOutcome
    let publication: AnnotationLocalEditorCloudPublication
}
