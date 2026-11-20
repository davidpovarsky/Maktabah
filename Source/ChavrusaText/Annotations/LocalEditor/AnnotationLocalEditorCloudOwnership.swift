import Foundation
import Synchronization

/// Fixed categories only. Private account identities and configured request
/// bytes are retained internally and never included in diagnostics.
enum AnnotationLocalEditorCloudDeferral: Error, Sendable, Equatable {
    case unavailable, accountUnavailable, accountChanged, permissionLost
    case ownerRetired, sourceChanged, pendingChanged, alreadyConsumed
    case durableReplay, invalidRecord, invalidPublication, workerChanged, remoteFailure
}

struct AnnotationLocalEditorCloudAccount: Sendable, Equatable {
    private let record: Data
    private let zone: Data
    private let owner: Data

    init(recordName: String, zoneName: String, ownerName: String) throws {
        guard !recordName.isEmpty, !zoneName.isEmpty, !ownerName.isEmpty else {
            throw AnnotationLocalEditorCloudDeferral.accountUnavailable
        }
        record = Data(recordName.utf8); zone = Data(zoneName.utf8); owner = Data(ownerName.utf8)
    }
}

/// Observe before the first identity lookup. Delivery on the posting thread
/// retires this one-way lifetime synchronously; there is no actor hop or revival
/// after a sign-out/sign-in sequence. Actual OS notification timing is a separate
/// live CloudKit qualification, not a claim made by component controls.
final class AnnotationLocalEditorCloudAccountObservation: Sendable {
    let lifetime = AnnotationLocalEditorLifetime()
    private let center: NotificationCenter
    private let observer: Mutex<(any NSObjectProtocol)?>

    init(center: NotificationCenter, changedNotification: Notification.Name) {
        self.center = center; observer = Mutex(nil)
        let lifetime = lifetime
        let token = center.addObserver(forName: changedNotification, object: nil, queue: nil) { _ in
            lifetime.retire()
        }
        observer.withLock { $0 = token }
    }

    deinit {
        let token = observer.withLock { value in
            let result = value; value = nil; return result
        }
        if let token { center.removeObserver(token) }
    }
}

enum AnnotationLocalEditorCloudRemoteResult: Sendable {
    case notAttempted(AnnotationLocalEditorCloudDeferral)
    case succeeded
    /// This is the actual admitted operation's error. It does not assert that
    /// no remote side effect occurred, and never authorizes a retry.
    case failed(any Error)
}

enum AnnotationLocalEditorCloudPendingResult: Sendable, Equatable {
    case acknowledged
    case retained(AnnotationLocalEditorCloudDeferral)
}

enum AnnotationLocalEditorCloudWorkerResult: Sendable {
    case notConfigured
    case notAttempted(AnnotationLocalEditorCloudDeferral)
    case completed
    case failed(any Error)
}

struct AnnotationLocalEditorCloudCompletion: Sendable {
    let remote: AnnotationLocalEditorCloudRemoteResult
    let pending: AnnotationLocalEditorCloudPendingResult
    let worker: AnnotationLocalEditorCloudWorkerResult
    let mayDeliverToOriginalOwner: Bool
}

/// Explicit boundary bundle. The actual consumer obtains it only from
/// `original()`; component tests provide identity/transport/wait doubles.
/// Each bundle owns its original container/zone via its closures and its own
/// account observation. It never resolves a live repository or pending store.
struct AnnotationLocalEditorCloudClient: Sendable {
    let account: AnnotationLocalEditorCloudAccountObservation
    let isPermitted: @Sendable () -> Bool
    let resolveAccount: @Sendable () async throws -> AnnotationLocalEditorCloudAccount?
    let debounce: @Sendable (Annotation) async throws -> Annotation
    let upload: @Sendable (Annotation) async -> AnnotationLocalEditorCloudRemoteResult
    let workerRequest: @Sendable () -> URLRequest?
    let waitForWorker: @Sendable () async throws -> Void
    let sendWorker: @Sendable (URLRequest) async -> Result<Void, any Error>
}

/// Immutable local intent and original account proof, captured before commit.
/// Absence of a proven account remains a refusal; save never adopts a later one.
final class AnnotationLocalEditorCloudPreparation: Sendable {
    let intent: AnnotationLocalEditorIntent
    let sessionID: UUID
    fileprivate let client: AnnotationLocalEditorCloudClient?
    fileprivate let identity: AnnotationLocalEditorCloudAccount?
    fileprivate let request: URLRequest?
    fileprivate let refusal: AnnotationLocalEditorCloudDeferral?
    private let consumed = Mutex(false)

    private init(intent: AnnotationLocalEditorIntent, sessionID: UUID,
                 client: AnnotationLocalEditorCloudClient?, identity: AnnotationLocalEditorCloudAccount?,
                 request: URLRequest?, refusal: AnnotationLocalEditorCloudDeferral?) {
        self.intent = intent; self.sessionID = sessionID; self.client = client
        self.identity = identity; self.request = request; self.refusal = refusal
    }

    static func prepare(intent: AnnotationLocalEditorIntent, storage: AnnotationLocalEditorPersistence,
                        client: AnnotationLocalEditorCloudClient?) async throws -> AnnotationLocalEditorCloudPreparation {
        try storage.requireUnchanged(intent.snapshot)
        let recomputed = try storage.prepare(snapshot: intent.snapshot, mutationID: intent.mutationID,
            body: intent.body, textPreview: intent.textPreview, editorRevision: intent.editorRevision)
        guard recomputed.intentDigest == intent.intentDigest else { throw AnnotationLocalEditorError.invalidIntent }
        var identity: AnnotationLocalEditorCloudAccount?
        var refusal: AnnotationLocalEditorCloudDeferral?
        let request = client?.workerRequest()
        if let client {
            if !client.isPermitted() { refusal = .permissionLost }
            else if !client.account.lifetime.isCurrent { refusal = .accountChanged }
            else {
                do { identity = try await client.resolveAccount() }
                catch { refusal = .accountUnavailable }
                if !client.account.lifetime.isCurrent { refusal = .accountChanged }
                else if !client.isPermitted() { refusal = .permissionLost }
                else if identity == nil { refusal = .accountUnavailable }
            }
        } else { refusal = .unavailable }
        try storage.requireUnchanged(intent.snapshot)
        try Task.checkCancellation()
        return .init(intent: intent, sessionID: storage.sessionID, client: client,
            identity: refusal == nil ? identity : nil, request: request, refusal: refusal)
    }

    func consume(for storage: AnnotationLocalEditorPersistence) throws {
        guard sessionID == storage.sessionID, intent.snapshot.sessionID == storage.sessionID else {
            throw AnnotationLocalEditorError.wrongOwner
        }
        try consumed.withLock { value in
            guard !value else { throw AnnotationLocalEditorCloudDeferral.alreadyConsumed }
            value = true
        }
    }

    fileprivate func requireAccount() async throws -> AnnotationLocalEditorCloudClient {
        if let refusal { throw refusal }
        guard let client, let identity else { throw AnnotationLocalEditorCloudDeferral.accountUnavailable }
        guard client.account.lifetime.isCurrent else { throw AnnotationLocalEditorCloudDeferral.accountChanged }
        guard client.isPermitted() else { throw AnnotationLocalEditorCloudDeferral.permissionLost }
        let observed: AnnotationLocalEditorCloudAccount?
        do { observed = try await client.resolveAccount() }
        catch { throw AnnotationLocalEditorCloudDeferral.accountUnavailable }
        guard client.account.lifetime.isCurrent else { throw AnnotationLocalEditorCloudDeferral.accountChanged }
        guard client.isPermitted() else { throw AnnotationLocalEditorCloudDeferral.permissionLost }
        guard observed == identity else { throw AnnotationLocalEditorCloudDeferral.accountChanged }
        return client
    }
}

struct AnnotationLocalEditorCloudWriteStamp: Sendable, Equatable {
    let totalChanges: Int64
    let dataVersion: Int64
}

struct AnnotationLocalEditorCloudPendingRow: Sendable, Equatable {
    let rowID: Int64
    let recordID: String
    let operation: String
    let queuedAt: Int64

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.rowID == rhs.rowID && lhs.recordID.utf8.elementsEqual(rhs.recordID.utf8)
            && lhs.operation.utf8.elementsEqual(rhs.operation.utf8) && lhs.queuedAt == rhs.queuedAt
    }
}

struct AnnotationLocalEditorCloudWitness: Sendable {
    let saved: AnnotationLocalEditorCommitted
    let pending: AnnotationLocalEditorCloudPendingRow?
    let writes: AnnotationLocalEditorCloudWriteStamp
}

struct AnnotationLocalEditorCloudCommitted: Sendable {
    let saved: AnnotationLocalEditorCommitted
    let witness: AnnotationLocalEditorCloudWitness?
    let refusal: AnnotationLocalEditorCloudDeferral?
}

/// Waiting observes the actual result of an already-admitted operation. Dropping
/// or retiring the editor cannot fabricate remote cancellation or local rollback.
final class AnnotationLocalEditorCloudPublication: Sendable {
    private let task: Task<AnnotationLocalEditorCloudCompletion, Never>

    init(storage: AnnotationLocalEditorPersistence, preparation: AnnotationLocalEditorCloudPreparation,
         committed: AnnotationLocalEditorCloudCommitted) {
        task = Task.detached {
            await Self.perform(storage: storage, preparation: preparation, committed: committed)
        }
    }

    var completion: AnnotationLocalEditorCloudCompletion { get async { await task.value } }

    private static func reason(_ error: any Error) -> AnnotationLocalEditorCloudDeferral {
        if let value = error as? AnnotationLocalEditorCloudDeferral { return value }
        if let value = error as? AnnotationLocalEditorError, value == .retired { return .ownerRetired }
        return .sourceChanged
    }

    private static func perform(storage: AnnotationLocalEditorPersistence,
                                preparation: AnnotationLocalEditorCloudPreparation,
                                committed: AnnotationLocalEditorCloudCommitted) async -> AnnotationLocalEditorCloudCompletion {
        let saved = committed.saved
        guard let witness = committed.witness else {
            let refusal = committed.refusal ?? .pendingChanged
            return .init(remote: .notAttempted(refusal), pending: .retained(refusal),
                worker: .notAttempted(refusal), mayDeliverToOriginalOwner: false)
        }
        let client: AnnotationLocalEditorCloudClient
        do {
            if let refusal = preparation.refusal { throw refusal }
            guard let original = preparation.client else { throw AnnotationLocalEditorCloudDeferral.unavailable }
            let debounced = try await original.debounce(saved.snapshot.annotation)
            guard debounced == saved.snapshot.annotation else { throw AnnotationLocalEditorCloudDeferral.invalidRecord }
            client = try await preparation.requireAccount()
            try storage.requireCloudWitness(witness, account: client.account.lifetime)
        } catch {
            let refusal = reason(error)
            return .init(remote: .notAttempted(refusal), pending: .retained(refusal),
                worker: .notAttempted(refusal), mayDeliverToOriginalOwner: false)
        }

        // The original operation is admitted now. The checks above do not claim
        // an atomic OS account/remote transaction. Keep its actual outcome even
        // if a later notification, source write or retirement refuses local ACK.
        let remote = await client.upload(saved.snapshot.annotation)
        var pending: AnnotationLocalEditorCloudPendingResult = .retained(.sourceChanged)
        var continuationWitness: AnnotationLocalEditorCloudWitness? = witness
        switch remote {
        case .notAttempted(let refusal):
            return .init(remote: remote, pending: .retained(refusal), worker: .notAttempted(refusal),
                mayDeliverToOriginalOwner: false)
        case .succeeded:
            do {
                _ = try await preparation.requireAccount()
                continuationWitness = try storage.acknowledgeCloud(witness, account: client.account.lifetime)
                // Returning from acknowledgeCloud proves its real COMMIT; no
                // post-COMMIT refusal can turn this acknowledgement into rollback.
                pending = .acknowledged
            } catch {
                pending = .retained(reason(error)); continuationWitness = nil
            }
        case .failed:
            // No retry, conflict merge, live coordinator or pending deletion.
            pending = .retained(.remoteFailure)
            do {
                _ = try await preparation.requireAccount()
                try storage.requireCloudWitness(witness, account: client.account.lifetime)
            } catch {
                pending = .retained(reason(error)); continuationWitness = nil
            }
        }

        let worker: AnnotationLocalEditorCloudWorkerResult
        if let request = preparation.request {
            do {
                guard let continuationWitness else { throw AnnotationLocalEditorCloudDeferral.pendingChanged }
                try await client.waitForWorker()
                _ = try await preparation.requireAccount()
                try storage.requireCloudWitness(continuationWitness, account: client.account.lifetime)
                guard let current = client.workerRequest(), current == request,
                      let currentURL = current.url?.absoluteString, let originalURL = request.url?.absoluteString,
                      currentURL.utf8.elementsEqual(originalURL.utf8) else {
                    throw AnnotationLocalEditorCloudDeferral.workerChanged
                }
                switch await client.sendWorker(request) {
                case .success: worker = .completed
                case .failure(let error): worker = .failed(error)
                }
            } catch { worker = .notAttempted(reason(error)) }
        } else { worker = .notConfigured }
        var mayDeliver = false
        do {
            guard let continuationWitness else { throw AnnotationLocalEditorCloudDeferral.pendingChanged }
            _ = try await preparation.requireAccount()
            try storage.requireCloudWitness(continuationWitness, account: client.account.lifetime)
            mayDeliver = storage.canDeliver(saved)
        } catch { /* Preserve actual remote/ACK/worker effects; refuse old-owner delivery. */ }
        return .init(remote: remote, pending: pending, worker: worker, mayDeliverToOriginalOwner: mayDeliver)
    }
}

struct AnnotationLocalEditorCloudSaveOutcome: Sendable {
    let local: AnnotationLocalEditorOutcome
    let publication: AnnotationLocalEditorCloudPublication
}
