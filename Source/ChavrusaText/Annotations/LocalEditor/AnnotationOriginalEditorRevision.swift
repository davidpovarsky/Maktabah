#if os(iOS) && canImport(AnytypeOriginalEditor)
import Foundation
import CryptoKit
import AnytypeOriginalEditor

enum AnnotationOriginalEditorRevisionPreparationOutcome {
    case prepared(AnnotationOriginalEditorRevisionAttempt)
    case recordedWithoutOwnership(AnnotationLocalEditorNativeAttemptObservation)
}

enum AnnotationOriginalEditorRevisionError: Error {
    case wrongAttempt, unsafeStorage, conflictingHistory, unobservedDrain
}

struct AnnotationOriginalEditorRevisionOutcome: Sendable {
    enum Kind: String, Codable, Sendable {
        case verified = "LOCAL_NATIVE_REVISION_READBACK_VERIFIED"
        case conflict = "NATIVE_REVISION_CONFLICT"
        case unverified = "NATIVE_REVISION_UNVERIFIED"
    }
    let kind: Kind
    let url: URL
}

/// The actual drained callback owns this write independently of the awaiting UI.
/// A late result remains historical data, never a new dispatch or remote ACK.
@MainActor
final class AnnotationOriginalEditorRevisionHistory {
    let preparation: AnnotationLocalEditorNativeAttemptObservation
    private(set) var dispatch: AnnotationLocalEditorNativeAttemptObservation?
    private(set) var native: AnytypeOriginalAnnotationRevisionHistory?
    private(set) var witness: AnnotationOriginalEditorRevisionFile.Witness?
    private(set) var witnessURL: URL?
    private let databaseURL: URL
    private let linkedCompletion: @Sendable (AnytypeOriginalAnnotationRevisionHistory) throws -> Void
    private var durableWrite: Task<AnnotationOriginalEditorRevisionOutcome, Error>?
    private var waiters: [CheckedContinuation<Void, Never>] = []

    fileprivate init(_ prepared: AnnotationLocalEditorNativeRevisionPreparation,
                     linkedCompletion: @escaping @Sendable (AnytypeOriginalAnnotationRevisionHistory) throws -> Void) {
        self.linkedCompletion = linkedCompletion
        preparation = prepared.observation
        databaseURL = prepared.snapshot.databaseURL
    }

    fileprivate func recordWitness(_ witness: AnnotationOriginalEditorRevisionFile.Witness, url: URL) {
        self.witness = witness; witnessURL = url
    }

    fileprivate func recordDispatch(_ actual: AnnotationLocalEditorNativeAttemptObservation) {
        dispatch = actual
    }

    fileprivate func recordNative(_ actual: AnytypeOriginalAnnotationRevisionHistory) {
        guard native == nil else { return }
        native = actual
        if let witness, let witnessURL {
            let possible = dispatch?.state == .dispatchMayHaveOccurred
            let databaseURL = self.databaseURL
            let complete = linkedCompletion
            durableWrite = Task.detached {
                let outcome = try AnnotationOriginalEditorRevisionFile.persistHistory(actual,
                    witness: witness, witnessURL: witnessURL,
                    capturedDatabaseURL: databaseURL, dispatched: possible)
                if possible { try complete(actual) }
                return outcome
            }
        }
        let pending = waiters; waiters.removeAll()
        for waiter in pending { waiter.resume() }
    }

    func durableOutcome() async throws -> AnnotationOriginalEditorRevisionOutcome {
        if native == nil { await withCheckedContinuation { waiters.append($0) } }
        guard let durableWrite else { throw AnnotationOriginalEditorRevisionError.unobservedDrain }
        return try await durableWrite.value
    }

    /// A thrown await can be unknown. Do not wait on a callback that has not
    /// occurred, infer rollback, or turn an error into a native retry.
    func recordedOutcomeIfDrained() async throws -> AnnotationOriginalEditorRevisionOutcome? {
        guard native != nil, let durableWrite else { return nil }
        return try await durableWrite.value
    }
}

@MainActor
final class AnnotationOriginalEditorRevisionAttempt {
    let history: AnnotationOriginalEditorRevisionHistory
    private let local: AnnotationLocalEditorSession
    private let prepared: AnnotationLocalEditorNativeRevisionPreparation
    private let observation: AnnotationOriginalEditorSourceObservation
    private let sourceLifetime: AnytypeOriginalAnnotationImportSourceLifetime
    private var native: AnytypeOriginalAnnotationRevisionAttempt?
    private var invocationStarted = false

    private init(local: AnnotationLocalEditorSession,
                 prepared: AnnotationLocalEditorNativeRevisionPreparation,
                 observation: AnnotationOriginalEditorSourceObservation,
                 sourceLifetime: AnytypeOriginalAnnotationImportSourceLifetime) {
        self.local = local; self.prepared = prepared; self.observation = observation
        self.sourceLifetime = sourceLifetime
        history = .init(prepared, linkedCompletion: local.linkedRevisionCompletion(prepared))
    }

    static func prepare(
        local: AnnotationLocalEditorSession,
        snapshot: AnnotationLocalEditorSnapshot,
        observation: AnnotationOriginalEditorSourceObservation,
        readSource: AnytypeOriginalEditorSourceLifetime,
        read: AnytypeOriginalAnnotationReadReceipt,
        retainedReadURL: URL,
        account: AnytypeOriginalEditorAccountSession,
        linkedDelivery: AnnotationExchangeLinkedDelivery? = nil
    ) async throws -> AnnotationOriginalEditorRevisionPreparationOutcome {
        try observation.requireCurrent(); try account.validateCurrent()
        try AnnotationOriginalEditorMount.assertUnchanged(snapshot, try await local.read())
        try observation.requireCurrent()
        let comparison = try AnnotationLocalEditorNativeComparison(
            accountID: account.identity.accountID, spaceID: account.identity.spaceID)
        let token = read.revisionToken
        let target = try AnnotationLocalEditorNativeRevisionTarget(objectID: token.objectID,
            expectedHeads: token.nativeHeads, expectedRootDigest: token.nativeRootSHA256)
        let outcome = try await local.prepareNativeRevision(
            snapshot: snapshot, comparison: comparison, target: target, linkedDelivery: linkedDelivery)
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
            let owner = AnnotationOriginalEditorRevisionAttempt(local: local, prepared: prepared,
                observation: observation, sourceLifetime: actualLifetime)
            let retained = owner.history
            let native = try account.prepareAnnotationReplacement(snapshot: body,
                revisionToken: token, sourceLifetime: actualLifetime,
                sourceIsCurrent: { [weak owner] candidate in owner?.isCurrent(candidate) == true },
                onDrained: { [retained] actual in retained.recordNative(actual) })
            owner.native = native
            let readDigest = try await Task.detached {
                try AnnotationOriginalEditorRevisionFile.readHistoryDigest(retainedReadURL)
            }.value
            let witness = try AnnotationOriginalEditorRevisionFile.Witness(
                actual: native, read: read, retainedReadURL: retainedReadURL,
                retainedReadSHA256: readDigest)
            let databaseURL = prepared.snapshot.databaseURL
            let url = try await Task.detached {
                try AnnotationOriginalEditorRevisionFile.persistWitness(witness, capturedDatabaseURL: databaseURL)
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
                    try AnnotationOriginalEditorRevisionFile.verifyWitness(witness, at: witnessURL,
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

/// Immutable local evidence, not a decoder for SDK receipts or source authority.
enum AnnotationOriginalEditorRevisionFile {
    struct Source: Codable, Sendable {
        let namespace: String
        let annotationUUID: UUID
        let preparedSessionID: UUID
        let attemptID: UUID
        let savedRevision: Int64
        let sourceDigest: String
        let payloadDigest: String
        let bodyDigest: String
        let accountID: String
        let spaceID: String

        init(_ source: AnytypeOriginalAnnotationImportSource) {
            namespace = source.namespace; annotationUUID = source.annotationUUID
            preparedSessionID = source.preparedSessionID; attemptID = source.attemptID
            savedRevision = source.savedRevision; sourceDigest = source.sourceDigest
            payloadDigest = source.payloadDigest; bodyDigest = source.bodyDigest
            accountID = source.accountID; spaceID = source.spaceID
        }

        func matches(_ source: AnytypeOriginalAnnotationImportSource) -> Bool {
            namespace == source.namespace && annotationUUID == source.annotationUUID
                && preparedSessionID == source.preparedSessionID && attemptID == source.attemptID
                && savedRevision == source.savedRevision && sourceDigest == source.sourceDigest
                && payloadDigest == source.payloadDigest && bodyDigest == source.bodyDigest
                && accountID.utf8.elementsEqual(source.accountID.utf8)
                && spaceID.utf8.elementsEqual(source.spaceID.utf8)
        }
    }

    struct Witness: Codable, Sendable {
        let schema: String
        let operation: String
        let remoteDeviceAcknowledgement: Bool
        let source: Source
        let objectID: String
        let expectedHeads: [String]
        let expectedRootSHA256: String
        let requestSHA256: String
        let requestBytes: Data
        let originalReadResponseSHA256: String
        let originalReadResponseBytes: Data
        let retainedReadSHA256: String
        let retainedReadURL: URL

        @MainActor
        init(actual: AnytypeOriginalAnnotationRevisionAttempt,
             read: AnytypeOriginalAnnotationReadReceipt, retainedReadURL: URL,
             retainedReadSHA256: String) throws {
            guard actual.objectID.utf8.elementsEqual(read.revisionToken.objectID.utf8),
                  actual.expectedNativeHeads == read.revisionToken.nativeHeads,
                  actual.expectedNativeRootSHA256 == read.revisionToken.nativeRootSHA256,
                  !actual.requestBytes.isEmpty, actual.requestBytes.count <= 2 * 1_024 * 1_024,
                  sha256(actual.requestBytes) == actual.requestSHA256,
                  sha256(read.nativeResponseBytes) == read.nativeResponseSHA256,
                  retainedReadURL.isFileURL else { throw AnnotationOriginalEditorRevisionError.wrongAttempt }
            schema = "otzaria.original.annotation.revision-witness.v1"
            operation = "replace-existing-native-root"; remoteDeviceAcknowledgement = false
            source = Source(actual.source); objectID = actual.objectID
            expectedHeads = actual.expectedNativeHeads
            expectedRootSHA256 = actual.expectedNativeRootSHA256
            requestSHA256 = actual.requestSHA256; requestBytes = actual.requestBytes
            originalReadResponseSHA256 = read.nativeResponseSHA256
            originalReadResponseBytes = read.nativeResponseBytes
            self.retainedReadSHA256 = retainedReadSHA256
            self.retainedReadURL = retainedReadURL
        }
    }

    private struct Mapping: Codable {
        let sourceSpaceID: String
        let sourceObjectID: String
        let objectID: String
    }

    private struct Record: Codable {
        let schema: String
        let operation: String
        let remoteDeviceAcknowledgement: Bool
        let kind: AnnotationOriginalEditorRevisionOutcome.Kind
        let source: Source
        let objectID: String
        let requestSHA256: String
        let expectedHeads: [String]
        let expectedRootSHA256: String
        let nativeHeads: [String]?
        let nativeRootSHA256: String?
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

    static func persistWitness(_ witness: Witness, capturedDatabaseURL: URL) throws -> URL {
        try requireReadPath(witness.retainedReadURL, source: witness.source, database: capturedDatabaseURL)
        let directory = try directory(database: capturedDatabaseURL,
            annotation: witness.source.annotationUUID, attempt: witness.source.attemptID)
        let url = directory.appendingPathComponent("request.json")
        try write(witness, at: url)
        try verifyWitness(witness, at: url, capturedDatabaseURL: capturedDatabaseURL)
        return url
    }

    static func verifyWitness(_ witness: Witness, at url: URL, capturedDatabaseURL: URL) throws {
        let root = try historyRoot(database: capturedDatabaseURL)
        let note = root.appendingPathComponent(witness.source.annotationUUID.uuidString, isDirectory: true)
        let attempt = note.appendingPathComponent(witness.source.attemptID.uuidString, isDirectory: true)
        guard witness.schema == "otzaria.original.annotation.revision-witness.v1",
              witness.operation == "replace-existing-native-root", !witness.remoteDeviceAcknowledgement,
              witness.source.namespace == "otzaria.local.annotation",
              attempt.appendingPathComponent("request.json").standardizedFileURL == url.standardizedFileURL else {
            throw AnnotationOriginalEditorRevisionError.wrongAttempt
        }
        try requireDirectory(root); try requireDirectory(note); try requireDirectory(attempt)
        try requireReadPath(witness.retainedReadURL, source: witness.source, database: capturedDatabaseURL)
        let bytes = try encode(witness)
        try requireFile(url, maximum: 8 * 1_024 * 1_024)
        guard try readHistoryDigest(witness.retainedReadURL) == witness.retainedReadSHA256,
              sha256(witness.originalReadResponseBytes) == witness.originalReadResponseSHA256,
              sha256(witness.requestBytes) == witness.requestSHA256,
              try Data(contentsOf: url) == bytes else {
            throw AnnotationOriginalEditorRevisionError.conflictingHistory
        }
    }

    static func persistHistory(_ actual: AnytypeOriginalAnnotationRevisionHistory,
                               witness: Witness, witnessURL: URL,
                               capturedDatabaseURL: URL, dispatched: Bool) throws
        -> AnnotationOriginalEditorRevisionOutcome {
        // Retain even unknown/incomplete/late native observations. Do not turn
        // cancelled awaits or applied_unconfirmed into rollback or success.
        let verified = actual.verifiedNativeReceipt
        let matches = verified.map {
            witness.source.matches($0.source) && $0.objectID.utf8.elementsEqual(witness.objectID.utf8)
                && !$0.nativeResponseBytes.isEmpty
                && $0.nativeResponseBytes.count <= 2 * 1_024 * 1_024
                && sha256($0.nativeResponseBytes) == $0.nativeResponseSHA256
        } ?? false
        let kind: AnnotationOriginalEditorRevisionOutcome.Kind =
            dispatched && matches ? .verified :
            (dispatched && actual.conflictObserved ? .conflict : .unverified)
        let record = Record(schema: "otzaria.original.annotation.revision-result.v1",
            operation: witness.operation, remoteDeviceAcknowledgement: false, kind: kind,
            source: witness.source, objectID: witness.objectID,
            requestSHA256: witness.requestSHA256, expectedHeads: witness.expectedHeads,
            expectedRootSHA256: witness.expectedRootSHA256,
            nativeHeads: matches ? verified?.nativeHeads : nil,
            nativeRootSHA256: matches ? verified?.nativeRootSHA256 : nil,
            nativeArchiveSHA256: matches ? verified?.nativeArchiveSHA256 : nil,
            nativeResponseBytes: actual.nativeResponseBytes,
            nativeResponseSHA256: actual.nativeResponseBytes.map(sha256),
            nativeResponseCopyError: actual.nativeResponseCopyError.map { String(describing: $0) },
            cancellationResponseBytes: actual.cancellationResponseBytes,
            cancellationResponseCopyError: actual.cancellationResponseCopyError.map { String(describing: $0) },
            cancellationWasScheduled: actual.cancellationWasScheduled,
            cancellationAwaitFailed: actual.cancellationAwaitFailed,
            nativeApplyAttempted: actual.nativeApplyAttempted,
            nativeWriteObserved: actual.nativeWriteObserved,
            objectMappings: matches ? (verified?.objectMappings ?? []).map {
                .init(sourceSpaceID: $0.sourceSpaceID, sourceObjectID: $0.sourceObjectID, objectID: $0.objectID)
            } : [])
        let directory = try directory(database: capturedDatabaseURL,
            annotation: witness.source.annotationUUID, attempt: witness.source.attemptID)
        guard directory.appendingPathComponent("request.json").standardizedFileURL == witnessURL.standardizedFileURL else {
            throw AnnotationOriginalEditorRevisionError.unsafeStorage
        }
        let url = directory.appendingPathComponent("result.json")
        try write(record, at: url)
        return .init(kind: kind, url: url)
    }

    static func mappings(annotationUUID: UUID, capturedDatabaseURL: URL) throws
        -> [AnnotationOriginalEditorNativeReceiptFile.HistoricalMapping] {
        let root = try historyRoot(database: capturedDatabaseURL)
        let note = root.appendingPathComponent(annotationUUID.uuidString, isDirectory: true)
        guard FileManager.default.fileExists(atPath: note.path) else { return [] }
        try requireDirectory(root); try requireDirectory(note)
        let attempts = try FileManager.default.contentsOfDirectory(at: note,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard attempts.count <= 10_000 else { throw AnnotationOriginalEditorRevisionError.unsafeStorage }
        var values: [AnnotationOriginalEditorNativeReceiptFile.HistoricalMapping] = []
        for attempt in attempts {
            try requireDirectory(attempt)
            let url = attempt.appendingPathComponent("result.json")
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            try requireFile(url, maximum: 8 * 1_024 * 1_024)
            let record = try JSONDecoder().decode(Record.self, from: Data(contentsOf: url))
            guard record.schema == "otzaria.original.annotation.revision-result.v1",
                  record.operation == "replace-existing-native-root",
                  !record.remoteDeviceAcknowledgement, record.source.annotationUUID == annotationUUID,
                  record.source.namespace == "otzaria.local.annotation",
                  record.source.attemptID.uuidString == attempt.lastPathComponent else {
                throw AnnotationOriginalEditorRevisionError.wrongAttempt
            }
            guard record.kind == .verified else { continue }
            let requestURL = attempt.appendingPathComponent("request.json")
            try requireFile(requestURL, maximum: 8 * 1_024 * 1_024)
            let witness = try JSONDecoder().decode(Witness.self, from: Data(contentsOf: requestURL))
            try verifyWitness(witness, at: requestURL, capturedDatabaseURL: capturedDatabaseURL)
            guard try encode(record.source) == encode(witness.source),
                  record.objectID.utf8.elementsEqual(witness.objectID.utf8),
                  record.requestSHA256 == witness.requestSHA256,
                  record.expectedRootSHA256 == witness.expectedRootSHA256,
                  try encode(record.expectedHeads) == encode(witness.expectedHeads) else {
                throw AnnotationOriginalEditorRevisionError.conflictingHistory
            }
            guard record.source.savedRevision > 0, !record.source.accountID.isEmpty,
                  !record.source.spaceID.isEmpty, !record.objectID.isEmpty,
                  let response = record.nativeResponseBytes, !response.isEmpty,
                  response.count <= 2 * 1_024 * 1_024,
                  sha256(response) == record.nativeResponseSHA256,
                  record.objectMappings.contains(where: {
                      $0.objectID.utf8.elementsEqual(record.objectID.utf8)
                  }) else { throw AnnotationOriginalEditorRevisionError.wrongAttempt }
            values.append(.init(accountID: record.source.accountID, spaceID: record.source.spaceID,
                objectID: record.objectID, savedRevision: record.source.savedRevision,
                bodyDigest: record.source.bodyDigest, receiptURL: url))
        }
        return values
    }

    private static func historyRoot(database: URL) throws -> URL {
        guard database.isFileURL else { throw AnnotationOriginalEditorRevisionError.unsafeStorage }
        let original = database.standardizedFileURL.resolvingSymlinksInPath()
        return original.deletingLastPathComponent()
            .appendingPathComponent(original.lastPathComponent + ".native-revision-history", isDirectory: true)
    }

    private static func directory(database: URL, annotation: UUID, attempt: UUID) throws -> URL {
        let root = try historyRoot(database: database)
        let note = root.appendingPathComponent(annotation.uuidString, isDirectory: true)
        let attempt = note.appendingPathComponent(attempt.uuidString, isDirectory: true)
        for url in [root, note, attempt] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
            try requireDirectory(url)
        }
        return attempt
    }

    private static func requireDirectory(_ url: URL) throws {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else {
            throw AnnotationOriginalEditorRevisionError.unsafeStorage
        }
    }

    private static func requireFile(_ url: URL, maximum: Int) throws {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              let count = values.fileSize, count > 0, count <= maximum else {
            throw AnnotationOriginalEditorRevisionError.unsafeStorage
        }
    }

    static func readHistoryDigest(_ url: URL) throws -> String {
        try requireReadHistory(url)
        return sha256(try Data(contentsOf: url))
    }

    private static func requireReadPath(_ url: URL, source: Source, database: URL) throws {
        guard database.isFileURL, url.isFileURL else { throw AnnotationOriginalEditorRevisionError.unsafeStorage }
        let database = database.standardizedFileURL.resolvingSymlinksInPath()
        let parent = database.deletingLastPathComponent()
            .appendingPathComponent(database.lastPathComponent + ".native-receive-history", isDirectory: true)
        let note = parent.appendingPathComponent(source.annotationUUID.uuidString, isDirectory: true)
        guard url.deletingLastPathComponent().standardizedFileURL == note,
              url.pathExtension == "json",
              let readID = UUID(uuidString: url.deletingPathExtension().lastPathComponent),
              readID.uuidString == url.deletingPathExtension().lastPathComponent else {
            throw AnnotationOriginalEditorRevisionError.unsafeStorage
        }
        try requireDirectory(parent); try requireDirectory(note); try requireReadHistory(url)
    }

    private static func requireReadHistory(_ url: URL) throws {
        guard url.isFileURL else { throw AnnotationOriginalEditorRevisionError.unsafeStorage }
        try requireDirectory(url.deletingLastPathComponent())
        try requireFile(url, maximum: 64 * 1_024 * 1_024)
    }

    private static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    private static func write<T: Encodable>(_ value: T, at url: URL) throws {
        let bytes = try encode(value)
        if FileManager.default.fileExists(atPath: url.path) {
            try requireFile(url, maximum: max(bytes.count, 1))
            guard try Data(contentsOf: url) == bytes else {
                throw AnnotationOriginalEditorRevisionError.conflictingHistory
            }
            return
        }
        try bytes.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        guard try Data(contentsOf: url) == bytes else {
            throw AnnotationOriginalEditorRevisionError.conflictingHistory
        }
    }

    private static func sha256(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
}
#endif
