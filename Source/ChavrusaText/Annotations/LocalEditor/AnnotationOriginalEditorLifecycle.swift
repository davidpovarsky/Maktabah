#if os(iOS) && canImport(AnytypeOriginalEditor)
import Foundation
import CryptoKit
import AnytypeOriginalEditor

enum AnnotationOriginalEditorLifecyclePreparationOutcome {
    case prepared(AnnotationOriginalEditorLifecycleAttempt)
    case recordedWithoutOwnership(AnnotationLocalEditorNativeAttemptObservation)
}

enum AnnotationOriginalEditorLifecycleError: Error {
    case wrongAttempt, unsafeStorage, conflictingHistory, unobservedDrain
}

struct AnnotationOriginalEditorLifecycleOutcome: Sendable {
    enum Kind: String, Codable, Sendable {
        case verified = "LOCAL_NATIVE_LIFECYCLE_READBACK_VERIFIED"
        case conflict = "NATIVE_LIFECYCLE_CONFLICT"
        case unverified = "NATIVE_LIFECYCLE_UNVERIFIED"
    }
    let kind: Kind
    let url: URL
}

/// The actual drained callback owns this write independently of the awaiting UI.
/// A late result remains historical data, never a new dispatch or remote ACK.
@MainActor
final class AnnotationOriginalEditorLifecycleHistory {
    let preparation: AnnotationLocalEditorNativeAttemptObservation
    private(set) var dispatch: AnnotationLocalEditorNativeAttemptObservation?
    private(set) var native: AnytypeOriginalAnnotationLifecycleHistory?
    private(set) var witness: AnnotationOriginalEditorLifecycleFile.Witness?
    private(set) var witnessURL: URL?
    private let databaseURL: URL
    private var durableWrite: Task<AnnotationOriginalEditorLifecycleOutcome, Error>?
    private var waiters: [CheckedContinuation<Void, Never>] = []

    fileprivate init(_ prepared: AnnotationLocalEditorNativeRevisionPreparation) {
        preparation = prepared.observation
        databaseURL = prepared.snapshot.databaseURL
    }

    fileprivate func recordWitness(_ witness: AnnotationOriginalEditorLifecycleFile.Witness, url: URL) {
        self.witness = witness; witnessURL = url
    }

    fileprivate func recordDispatch(_ actual: AnnotationLocalEditorNativeAttemptObservation) {
        dispatch = actual
    }

    fileprivate func recordNative(_ actual: AnytypeOriginalAnnotationLifecycleHistory) {
        guard native == nil else { return }
        native = actual
        if let witness, let witnessURL {
            let possible = dispatch?.state == .dispatchMayHaveOccurred
            let databaseURL = self.databaseURL
            durableWrite = Task.detached {
                try AnnotationOriginalEditorLifecycleFile.persistHistory(actual,
                    witness: witness, witnessURL: witnessURL,
                    capturedDatabaseURL: databaseURL, dispatched: possible)
            }
        }
        let pending = waiters; waiters.removeAll()
        for waiter in pending { waiter.resume() }
    }

    func durableOutcome() async throws -> AnnotationOriginalEditorLifecycleOutcome {
        if native == nil { await withCheckedContinuation { waiters.append($0) } }
        guard let durableWrite else { throw AnnotationOriginalEditorLifecycleError.unobservedDrain }
        return try await durableWrite.value
    }

    /// A thrown await can be unknown. Do not wait on a callback that has not
    /// occurred, infer rollback, or turn an error into a native retry.
    func recordedOutcomeIfDrained() async throws -> AnnotationOriginalEditorLifecycleOutcome? {
        guard native != nil, let durableWrite else { return nil }
        return try await durableWrite.value
    }
}

@MainActor
final class AnnotationOriginalEditorLifecycleAttempt {
    let history: AnnotationOriginalEditorLifecycleHistory
    private let local: AnnotationLocalEditorSession
    private let prepared: AnnotationLocalEditorNativeRevisionPreparation
    private let observation: AnnotationOriginalEditorSourceObservation
    private let sourceLifetime: AnytypeOriginalAnnotationImportSourceLifetime
    private var native: AnytypeOriginalAnnotationLifecycleAttempt?
    private var invocationStarted = false

    private init(local: AnnotationLocalEditorSession,
                 prepared: AnnotationLocalEditorNativeRevisionPreparation,
                 observation: AnnotationOriginalEditorSourceObservation,
                 sourceLifetime: AnytypeOriginalAnnotationImportSourceLifetime) {
        self.local = local; self.prepared = prepared; self.observation = observation
        self.sourceLifetime = sourceLifetime
        history = .init(prepared)
    }

    static func prepare(
        local: AnnotationLocalEditorSession,
        snapshot: AnnotationLocalEditorSnapshot,
        observation: AnnotationOriginalEditorSourceObservation,
        readSource: AnytypeOriginalEditorSourceLifetime,
        read: AnytypeOriginalAnnotationLifecycleObservation,
        action: AnytypeOriginalAnnotationLifecycleAction,
        retainedReadURL: URL,
        account: AnytypeOriginalEditorAccountSession
    ) async throws -> AnnotationOriginalEditorLifecyclePreparationOutcome {
        try observation.requireCurrent(); try account.validateCurrent()
        try AnnotationOriginalEditorMount.assertUnchanged(snapshot, try await local.read())
        try observation.requireCurrent()
        let comparison = try AnnotationLocalEditorNativeComparison(
            accountID: account.identity.accountID, spaceID: account.identity.spaceID)
        let target = try AnnotationLocalEditorNativeRevisionTarget(objectID: read.objectID,
            expectedHeads: read.nativeHeads, expectedRootDigest: read.nativeRootSHA256)
        let outcome = try await local.prepareNativeRevision(
            snapshot: snapshot, comparison: comparison, target: target)
        let prepared: AnnotationLocalEditorNativeRevisionPreparation
        switch outcome {
        case .recordedWithoutOwnership(let receipt):
            observation.retire(); local.retire()
            return .recordedWithoutOwnership(receipt)
        case .prepared(let value): prepared = value
        }

        var lifetime: AnytypeOriginalAnnotationImportSourceLifetime?
        do {
            guard observation.isCurrent, local.ownsNativeRevisionPreparation(prepared) else {
                observation.retire(); local.retire()
                return .recordedWithoutOwnership(prepared.observation)
            }
            try Task.checkCancellation(); try account.validateCurrent()
            guard let version = prepared.snapshot.version,
                  let body = try AnnotationOriginalEditorMount.nativeBody(in: prepared.snapshot) else {
                throw AnnotationLocalEditorNativeAttemptError.unsupportedSavedBody
            }
            let receipt = prepared.observation
            let source = try AnytypeOriginalAnnotationImportSource(namespace: version.namespace,
                annotationUUID: receipt.annotationUUID, preparedSessionID: receipt.preparedSessionID,
                attemptID: receipt.attemptID, savedRevision: receipt.savedRevision,
                sourceDigest: receipt.sourceDigest, payloadDigest: receipt.payloadDigest,
                bodyDigest: receipt.bodyDigest, accountID: comparison.accountID, spaceID: comparison.spaceID)
            let actualLifetime = AnytypeOriginalAnnotationImportSourceLifetime(source: source)
            lifetime = actualLifetime
            try local.bindNativeRevisionRetirement(actualLifetime, prepared: prepared)
            try observation.bindReplacement(actualLifetime, readSource: readSource, local: local)
            let owner = AnnotationOriginalEditorLifecycleAttempt(local: local, prepared: prepared,
                observation: observation, sourceLifetime: actualLifetime)
            let retained = owner.history
            let native: AnytypeOriginalAnnotationLifecycleAttempt
            if action == .replacePromotedDocument {
                native = try account.preparePromotedDocumentReplacement(snapshot: body,
                    observation: read, sourceLifetime: actualLifetime,
                    sourceIsCurrent: { [weak owner] candidate in owner?.isCurrent(candidate) == true },
                    onDrained: { [retained] actual in retained.recordNative(actual) })
            } else {
                native = try account.prepareAnnotationLifecycle(action: action,
                    observation: read, sourceLifetime: actualLifetime,
                    sourceIsCurrent: { [weak owner] candidate in owner?.isCurrent(candidate) == true },
                    onDrained: { [retained] actual in retained.recordNative(actual) })
            }
            owner.native = native
            let readDigest = try await Task.detached {
                try AnnotationOriginalEditorLifecycleFile.readHistoryDigest(retainedReadURL)
            }.value
            let witness = try AnnotationOriginalEditorLifecycleFile.Witness(
                actual: native, read: read, retainedReadURL: retainedReadURL,
                retainedReadSHA256: readDigest)
            let databaseURL = prepared.snapshot.databaseURL
            let url = try await Task.detached {
                try AnnotationOriginalEditorLifecycleFile.persistWitness(witness, capturedDatabaseURL: databaseURL)
            }.value
            retained.recordWitness(witness, url: url)
            guard owner.isCurrent(source) else {
                owner.retire()
                return .recordedWithoutOwnership(receipt)
            }
            return .prepared(owner)
        } catch {
            lifetime?.retire(); observation.retire(); local.retire()
            throw AnnotationOriginalEditorImportFailure(stage: .sdkPreparation,
                prepared: prepared.observation, dispatch: nil, underlying: error)
        }
    }

    private func isCurrent(_ source: AnytypeOriginalAnnotationImportSource) -> Bool {
        source == sourceLifetime.source && sourceLifetime.isCurrent && observation.isCurrent
            && local.ownsNativeRevisionPreparation(prepared)
    }

    func invoke() async throws -> AnnotationOriginalEditorImportInvocationOutcome {
        guard !invocationStarted else { throw AnnotationLocalEditorError.busy }
        invocationStarted = true
        guard let native, let witness = history.witness, let witnessURL = history.witnessURL,
              isCurrent(sourceLifetime.source) else {
            retire(); throw AnnotationLocalEditorError.retired
        }
        let local = self.local, lifetime = sourceLifetime
        let databaseURL = prepared.snapshot.databaseURL
        return try await withTaskCancellationHandler {
            let transition: AnnotationLocalEditorNativeTransitionOutcome
            do {
                try await Task.detached {
                    try AnnotationOriginalEditorLifecycleFile.verifyWitness(witness, at: witnessURL,
                        capturedDatabaseURL: databaseURL)
                }.value
                try Task.checkCancellation()
                guard isCurrent(sourceLifetime.source) else { throw AnnotationLocalEditorError.retired }
                transition = try await local.markNativeRevisionMayHaveDispatched(prepared,
                    requestBytes: native.requestBytes, requestSHA256: native.requestSHA256)
            } catch {
                retire()
                throw AnnotationOriginalEditorImportFailure(stage: .dispatchTransition,
                    prepared: prepared.observation, dispatch: history.dispatch, underlying: error)
            }
            switch transition {
            case .recordedWithoutOwnership(let receipt):
                history.recordDispatch(receipt); retire()
                return .recordedWithoutOwnership(receipt)
            case .recorded(let receipt):
                history.recordDispatch(receipt)
                // No await separates currentness from this exact one-use SDK call.
                guard !Task.isCancelled, isCurrent(sourceLifetime.source) else {
                    retire(); return .recordedWithoutOwnership(receipt)
                }
                do {
                    try await native.invoke()
                    retire()
                    return .nativeAwaitReturned(receipt)
                } catch {
                    retire()
                    throw AnnotationOriginalEditorImportFailure(stage: .nativeAwait,
                        prepared: prepared.observation, dispatch: receipt, underlying: error)
                }
            }
        } onCancel: {
            lifetime.retire(); local.retire()
        }
    }

    @discardableResult
    func requestCancellation() -> AnytypeOriginalAnnotationImportAttempt.CancellationScheduling? {
        native?.requestCancellation()
    }

    func retire() {
        sourceLifetime.retire(); observation.retire(); local.retire()
    }

    isolated deinit {
        sourceLifetime.retire(); observation.retire(); local.retire()
    }
}

/// Immutable local lifecycle evidence. Decoding these files only discovers
/// history; every operation still requires a fresh closed native observation.
enum AnnotationOriginalEditorLifecycleFile {
    typealias Source = AnnotationOriginalEditorRevisionFile.Source

    struct Action: Codable, Equatable, Sendable {
        let name: String
        let role: String?

        init(_ action: AnytypeOriginalAnnotationLifecycleAction) {
            switch action {
            case .archive: name = "archive"; role = nil
            case .restore: name = "restore"; role = nil
            case .promote(let value): name = "promote"; role = value.rawValue
            case .revertPromotion: name = "revert-promotion"; role = nil
            case .replacePromotedDocument: name = "replace-promoted-document"; role = nil
            }
        }

        func accepts(_ receipt: AnytypeOriginalAnnotationLifecycleReceipt, witness: Witness) -> Bool {
            guard self == Action(receipt.action) else { return false }
            switch name {
            case "archive": return receipt.isArchived && receipt.documentRole?.rawValue == witness.documentRole
            case "restore": return !receipt.isArchived && receipt.documentRole?.rawValue == witness.documentRole
            case "promote":
                return receipt.documentRole?.rawValue == role && receipt.isArchived == witness.isArchived
            case "revert-promotion":
                return receipt.documentRole == nil && receipt.isArchived == witness.isArchived
            case "replace-promoted-document":
                return witness.documentRole != nil && receipt.documentRole?.rawValue == witness.documentRole
                    && receipt.isArchived == witness.isArchived
            default: return false
            }
        }
    }

    struct Witness: Codable, Sendable {
        let schema: String
        let remoteDeviceAcknowledgement: Bool
        let action: Action
        let source: Source
        let objectID: String
        let expectedHeads: [String]
        let expectedRootSHA256: String
        let archiveObjectID: String
        let archiveHeads: [String]
        let isArchived: Bool
        let documentRole: String?
        let promotionRole: String?
        let requestSHA256: String
        let requestBytes: Data
        let originalReadResponseSHA256: String
        let originalReadResponseBytes: Data
        let retainedReadSHA256: String
        let retainedReadURL: URL

        @MainActor
        init(actual: AnytypeOriginalAnnotationLifecycleAttempt,
             read: AnytypeOriginalAnnotationLifecycleObservation,
             retainedReadURL: URL, retainedReadSHA256: String) throws {
            let provenance = read.nativeCapture.snapshot.provenance
            guard actual.objectID.utf8.elementsEqual(read.objectID.utf8),
                  actual.source.annotationUUID == provenance.annotationUUID,
                  actual.source.savedRevision == provenance.capturedAgainstRevision,
                  actual.source.sourceDigest == provenance.sourceWitnessSHA256,
                  !actual.requestBytes.isEmpty, actual.requestBytes.count <= 2 * 1_024 * 1_024,
                  sha256(actual.requestBytes) == actual.requestSHA256,
                  !read.nativeResponseBytes.isEmpty,
                  read.nativeResponseBytes.count <= 2 * 1_024 * 1_024,
                  sha256(read.nativeResponseBytes) == read.nativeResponseSHA256,
                  retainedReadURL.isFileURL else { throw AnnotationOriginalEditorLifecycleError.wrongAttempt }
            schema = "otzaria.original.annotation.lifecycle-witness.v1"
            remoteDeviceAcknowledgement = false
            action = Action(actual.action); source = Source(actual.source); objectID = actual.objectID
            expectedHeads = read.nativeHeads; expectedRootSHA256 = read.nativeRootSHA256
            archiveObjectID = read.archiveObjectID; archiveHeads = read.archiveHeads
            isArchived = read.isArchived; documentRole = read.documentRole?.rawValue
            promotionRole = read.promotionRole?.rawValue
            requestSHA256 = actual.requestSHA256; requestBytes = actual.requestBytes
            originalReadResponseSHA256 = read.nativeResponseSHA256
            originalReadResponseBytes = read.nativeResponseBytes
            self.retainedReadSHA256 = retainedReadSHA256; self.retainedReadURL = retainedReadURL
        }
    }

    private struct ReadRecord: Codable {
        let schema: String
        let remoteDeviceAcknowledgement: Bool
        let readID: UUID
        let annotationUUID: UUID
        let capturedLocalRevision: Int64
        let capturedLocalSourceDigest: String
        let capturedLocalPayload: Data
        let nativeBody: Data
        let nativeBodySHA256: String
        let nativeResponse: Data
        let nativeResponseSHA256: String
        let objectID: String
        let nativeHeads: [String]
        let nativeRootSHA256: String
        let archiveObjectID: String
        let archiveHeads: [String]
        let isArchived: Bool
        let documentRole: String?
        let promotionRole: String?
    }

    private struct Mapping: Codable {
        let sourceSpaceID: String
        let sourceObjectID: String
        let objectID: String
    }

    private struct Record: Codable {
        let schema: String
        let remoteDeviceAcknowledgement: Bool
        let action: Action
        let kind: AnnotationOriginalEditorLifecycleOutcome.Kind
        let source: Source
        let objectID: String
        let requestSHA256: String
        let nativeHeads: [String]?
        let nativeRootSHA256: String?
        let archiveObjectID: String?
        let archiveHeads: [String]?
        let isArchived: Bool?
        let documentRole: String?
        let wasUnchanged: Bool?
        let nativeArchiveSHA256: String?
        let nativeResponseBytes: Data?
        let nativeResponseSHA256: String?
        let nativeResponseCopyError: String?
        let cancellationResponseBytes: Data?
        let cancellationResponseCopyError: String?
        let cancellationWasScheduled: Bool
        let cancellationAwaitFailed: Bool
        let nativeApplyAttempted: Bool?
        let nativeWriteObserved: Bool?
        let objectMappings: [Mapping]
    }

    static func persistRead(_ actual: AnytypeOriginalAnnotationLifecycleObservation,
                            captured: AnnotationLocalEditorSnapshot, readID: UUID) throws -> URL {
        let provenance = actual.nativeCapture.snapshot.provenance
        guard let payload = captured.version?.payload,
              provenance.annotationUUID == captured.annotationUUID,
              provenance.capturedAgainstRevision == captured.revision,
              provenance.sourceWitnessSHA256 == captured.source.digest,
              sha256(actual.nativeResponseBytes) == actual.nativeResponseSHA256 else {
            throw AnnotationOriginalEditorLifecycleError.wrongAttempt
        }
        let body = actual.nativeCapture.snapshot.bodyBytes
        let record = ReadRecord(schema: "otzaria.original.annotation.lifecycle-read.v1", remoteDeviceAcknowledgement: false,
            readID: readID, annotationUUID: captured.annotationUUID,
            capturedLocalRevision: captured.revision, capturedLocalSourceDigest: captured.source.digest,
            capturedLocalPayload: payload, nativeBody: body, nativeBodySHA256: sha256(body),
            nativeResponse: actual.nativeResponseBytes, nativeResponseSHA256: actual.nativeResponseSHA256,
            objectID: actual.objectID, nativeHeads: actual.nativeHeads, nativeRootSHA256: actual.nativeRootSHA256,
            archiveObjectID: actual.archiveObjectID, archiveHeads: actual.archiveHeads,
            isArchived: actual.isArchived, documentRole: actual.documentRole?.rawValue,
            promotionRole: actual.promotionRole?.rawValue)
        let root = try readRoot(database: captured.databaseURL)
        let note = root.appendingPathComponent(captured.annotationUUID.uuidString, isDirectory: true)
        for directory in [root, note] { try createDirectory(directory) }
        let url = note.appendingPathComponent(readID.uuidString + ".json")
        try write(record, at: url, maximum: 64 * 1_024 * 1_024)
        return url
    }

    static func persistWitness(_ witness: Witness, capturedDatabaseURL: URL) throws -> URL {
        try requireReadPath(witness.retainedReadURL, source: witness.source, database: capturedDatabaseURL)
        let folder = try directory(database: capturedDatabaseURL,
            annotation: witness.source.annotationUUID, attempt: witness.source.attemptID)
        let url = folder.appendingPathComponent("request.json")
        try write(witness, at: url, maximum: 8 * 1_024 * 1_024)
        try verifyWitness(witness, at: url, capturedDatabaseURL: capturedDatabaseURL)
        return url
    }

    static func verifyWitness(_ witness: Witness, at url: URL, capturedDatabaseURL: URL) throws {
        let root = try historyRoot(database: capturedDatabaseURL)
        let note = root.appendingPathComponent(witness.source.annotationUUID.uuidString, isDirectory: true)
        let attempt = note.appendingPathComponent(witness.source.attemptID.uuidString, isDirectory: true)
        guard witness.schema == "otzaria.original.annotation.lifecycle-witness.v1",
              !witness.remoteDeviceAcknowledgement, witness.source.namespace == "otzaria.local.annotation",
              attempt.appendingPathComponent("request.json").standardizedFileURL == url.standardizedFileURL else {
            throw AnnotationOriginalEditorLifecycleError.wrongAttempt
        }
        try requireDirectory(root); try requireDirectory(note); try requireDirectory(attempt)
        try requireReadPath(witness.retainedReadURL, source: witness.source, database: capturedDatabaseURL)
        try requireFile(url, maximum: 8 * 1_024 * 1_024)
        guard try readHistoryDigest(witness.retainedReadURL) == witness.retainedReadSHA256,
              sha256(witness.originalReadResponseBytes) == witness.originalReadResponseSHA256,
              sha256(witness.requestBytes) == witness.requestSHA256,
              try Data(contentsOf: url) == encode(witness) else {
            throw AnnotationOriginalEditorLifecycleError.conflictingHistory
        }
        let read = try JSONDecoder().decode(ReadRecord.self, from: Data(contentsOf: witness.retainedReadURL))
        guard read.schema == "otzaria.original.annotation.lifecycle-read.v1", !read.remoteDeviceAcknowledgement,
              read.readID.uuidString == witness.retainedReadURL.deletingPathExtension().lastPathComponent,
              sha256(read.capturedLocalPayload) == witness.source.payloadDigest,
              read.annotationUUID == witness.source.annotationUUID,
              read.capturedLocalRevision == witness.source.savedRevision,
              read.capturedLocalSourceDigest == witness.source.sourceDigest,
              read.objectID.utf8.elementsEqual(witness.objectID.utf8),
              read.nativeHeads == witness.expectedHeads, read.nativeRootSHA256 == witness.expectedRootSHA256,
              read.archiveObjectID.utf8.elementsEqual(witness.archiveObjectID.utf8),
              read.archiveHeads == witness.archiveHeads, read.isArchived == witness.isArchived,
              read.documentRole == witness.documentRole, read.promotionRole == witness.promotionRole,
              read.nativeResponse == witness.originalReadResponseBytes,
              sha256(read.nativeBody) == read.nativeBodySHA256,
              sha256(read.nativeResponse) == read.nativeResponseSHA256 else {
            throw AnnotationOriginalEditorLifecycleError.conflictingHistory
        }
    }

    static func persistHistory(_ actual: AnytypeOriginalAnnotationLifecycleHistory,
                               witness: Witness, witnessURL: URL,
                               capturedDatabaseURL: URL, dispatched: Bool) throws
        -> AnnotationOriginalEditorLifecycleOutcome {
        try verifyWitness(witness, at: witnessURL, capturedDatabaseURL: capturedDatabaseURL)
        let verified = actual.verifiedNativeReceipt
        let matches = verified.map {
            witness.source.matches($0.source) && $0.objectID.utf8.elementsEqual(witness.objectID.utf8)
                && witness.action.accepts($0, witness: witness)
                && !$0.nativeResponseBytes.isEmpty && $0.nativeResponseBytes.count <= 2 * 1_024 * 1_024
                && sha256($0.nativeResponseBytes) == $0.nativeResponseSHA256
                && actual.nativeResponseBytes == $0.nativeResponseBytes
        } ?? false
        // A conflict label means a genuine no-effect refusal. A graph effect
        // followed by a root conflict remains unverified and is never retried.
        let noEffectConflict = actual.conflictObserved
            && actual.nativeApplyAttempted == false && actual.nativeWriteObserved == false
        let kind: AnnotationOriginalEditorLifecycleOutcome.Kind = dispatched && matches ? .verified :
            (dispatched && noEffectConflict ? .conflict : .unverified)
        let record = Record(schema: "otzaria.original.annotation.lifecycle-result.v1",
            remoteDeviceAcknowledgement: false, action: witness.action, kind: kind, source: witness.source,
            objectID: witness.objectID, requestSHA256: witness.requestSHA256,
            nativeHeads: matches ? verified?.nativeHeads : nil,
            nativeRootSHA256: matches ? verified?.nativeRootSHA256 : nil,
            archiveObjectID: matches ? verified?.archiveObjectID : nil,
            archiveHeads: matches ? verified?.archiveHeads : nil,
            isArchived: matches ? verified?.isArchived : nil,
            documentRole: matches ? verified?.documentRole?.rawValue : nil,
            wasUnchanged: matches ? verified?.wasUnchanged : nil,
            nativeArchiveSHA256: matches ? verified?.nativeArchiveSHA256 : nil,
            nativeResponseBytes: actual.nativeResponseBytes,
            nativeResponseSHA256: actual.nativeResponseBytes.map(sha256),
            nativeResponseCopyError: actual.nativeResponseCopyError.map { String(describing: $0) },
            cancellationResponseBytes: actual.cancellationResponseBytes,
            cancellationResponseCopyError: actual.cancellationResponseCopyError.map { String(describing: $0) },
            cancellationWasScheduled: actual.cancellationWasScheduled,
            cancellationAwaitFailed: actual.cancellationAwaitFailed,
            nativeApplyAttempted: actual.nativeApplyAttempted, nativeWriteObserved: actual.nativeWriteObserved,
            objectMappings: matches ? (verified?.objectMappings ?? []).map {
                .init(sourceSpaceID: $0.sourceSpaceID, sourceObjectID: $0.sourceObjectID, objectID: $0.objectID)
            } : [])
        let folder = try directory(database: capturedDatabaseURL,
            annotation: witness.source.annotationUUID, attempt: witness.source.attemptID)
        guard folder.appendingPathComponent("request.json").standardizedFileURL == witnessURL.standardizedFileURL else {
            throw AnnotationOriginalEditorLifecycleError.unsafeStorage
        }
        let url = folder.appendingPathComponent("result.json")
        try write(record, at: url, maximum: 8 * 1_024 * 1_024)
        return .init(kind: kind, url: url)
    }

    /// Only replacement actually sends the saved local body. Archiving or
    /// changing a type must not claim that a different local body was shared.
    static func mappings(annotationUUID: UUID, capturedDatabaseURL: URL) throws
        -> [AnnotationOriginalEditorNativeReceiptFile.HistoricalMapping] {
        let root = try historyRoot(database: capturedDatabaseURL)
        let note = root.appendingPathComponent(annotationUUID.uuidString, isDirectory: true)
        guard FileManager.default.fileExists(atPath: note.path) else { return [] }
        try requireDirectory(root); try requireDirectory(note)
        let attempts = try FileManager.default.contentsOfDirectory(at: note,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard attempts.count <= 10_000 else { throw AnnotationOriginalEditorLifecycleError.unsafeStorage }
        var values: [AnnotationOriginalEditorNativeReceiptFile.HistoricalMapping] = []
        for attempt in attempts {
            try requireDirectory(attempt)
            let url = attempt.appendingPathComponent("result.json")
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            try requireFile(url, maximum: 8 * 1_024 * 1_024)
            let record = try JSONDecoder().decode(Record.self, from: Data(contentsOf: url))
            guard record.schema == "otzaria.original.annotation.lifecycle-result.v1",
                  !record.remoteDeviceAcknowledgement, record.source.annotationUUID == annotationUUID,
                  record.source.namespace == "otzaria.local.annotation",
                  record.source.attemptID.uuidString == attempt.lastPathComponent else {
                throw AnnotationOriginalEditorLifecycleError.wrongAttempt
            }
            guard record.kind == .verified && record.action.name == "replace-promoted-document" else { continue }
            let requestURL = attempt.appendingPathComponent("request.json")
            try requireFile(requestURL, maximum: 8 * 1_024 * 1_024)
            let witness = try JSONDecoder().decode(Witness.self, from: Data(contentsOf: requestURL))
            try verifyWitness(witness, at: requestURL, capturedDatabaseURL: capturedDatabaseURL)
            guard try encode(record.source) == encode(witness.source),
                  record.action == witness.action, record.documentRole == witness.documentRole,
                  record.documentRole != nil,
                  record.objectID.utf8.elementsEqual(witness.objectID.utf8),
                  record.requestSHA256 == witness.requestSHA256,
                  record.source.savedRevision > 0, !record.source.accountID.isEmpty,
                  !record.source.spaceID.isEmpty, !record.objectID.isEmpty,
                  let response = record.nativeResponseBytes, !response.isEmpty,
                  response.count <= 2 * 1_024 * 1_024, sha256(response) == record.nativeResponseSHA256,
                  record.objectMappings.contains(where: { $0.objectID.utf8.elementsEqual(record.objectID.utf8) }) else {
                throw AnnotationOriginalEditorLifecycleError.conflictingHistory
            }
            values.append(.init(accountID: record.source.accountID, spaceID: record.source.spaceID,
                objectID: record.objectID, savedRevision: record.source.savedRevision,
                bodyDigest: record.source.bodyDigest, receiptURL: url))
        }
        return values
    }

    private static func root(database: URL, suffix: String) throws -> URL {
        guard database.isFileURL else { throw AnnotationOriginalEditorLifecycleError.unsafeStorage }
        let original = database.standardizedFileURL.resolvingSymlinksInPath()
        return original.deletingLastPathComponent()
            .appendingPathComponent(original.lastPathComponent + suffix, isDirectory: true)
    }
    private static func historyRoot(database: URL) throws -> URL {
        try root(database: database, suffix: ".native-lifecycle-history")
    }
    private static func readRoot(database: URL) throws -> URL {
        try root(database: database, suffix: ".native-lifecycle-reads")
    }
    private static func directory(database: URL, annotation: UUID, attempt: UUID) throws -> URL {
        let root = try historyRoot(database: database)
        let note = root.appendingPathComponent(annotation.uuidString, isDirectory: true)
        let attempt = note.appendingPathComponent(attempt.uuidString, isDirectory: true)
        for url in [root, note, attempt] { try createDirectory(url) }
        return attempt
    }
    private static func createDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        try requireDirectory(url)
    }
    private static func requireDirectory(_ url: URL) throws {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else {
            throw AnnotationOriginalEditorLifecycleError.unsafeStorage
        }
    }
    private static func requireFile(_ url: URL, maximum: Int) throws {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              let count = values.fileSize, count > 0, count <= maximum else {
            throw AnnotationOriginalEditorLifecycleError.unsafeStorage
        }
    }
    static func readHistoryDigest(_ url: URL) throws -> String {
        guard url.isFileURL else { throw AnnotationOriginalEditorLifecycleError.unsafeStorage }
        try requireDirectory(url.deletingLastPathComponent())
        try requireFile(url, maximum: 64 * 1_024 * 1_024)
        return sha256(try Data(contentsOf: url))
    }
    private static func requireReadPath(_ url: URL, source: Source, database: URL) throws {
        guard url.isFileURL else { throw AnnotationOriginalEditorLifecycleError.unsafeStorage }
        let root = try readRoot(database: database)
        let note = root.appendingPathComponent(source.annotationUUID.uuidString, isDirectory: true)
        guard url.deletingLastPathComponent().standardizedFileURL == note,
              url.pathExtension == "json",
              let readID = UUID(uuidString: url.deletingPathExtension().lastPathComponent),
              readID.uuidString == url.deletingPathExtension().lastPathComponent else {
            throw AnnotationOriginalEditorLifecycleError.unsafeStorage
        }
        try requireDirectory(root); try requireDirectory(note)
        try requireFile(url, maximum: 64 * 1_024 * 1_024)
    }
    private static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
    private static func write<T: Encodable>(_ value: T, at url: URL, maximum: Int) throws {
        let bytes = try encode(value)
        guard !bytes.isEmpty, bytes.count <= maximum else { throw AnnotationOriginalEditorLifecycleError.unsafeStorage }
        if FileManager.default.fileExists(atPath: url.path) {
            try requireFile(url, maximum: maximum)
            guard try Data(contentsOf: url) == bytes else { throw AnnotationOriginalEditorLifecycleError.conflictingHistory }
            return
        }
        try bytes.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        guard try Data(contentsOf: url) == bytes else { throw AnnotationOriginalEditorLifecycleError.conflictingHistory }
    }
    private static func sha256(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
}
#endif
