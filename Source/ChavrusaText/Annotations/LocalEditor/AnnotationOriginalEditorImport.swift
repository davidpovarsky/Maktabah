#if os(iOS) && canImport(AnytypeOriginalEditor)
import Foundation
import CryptoKit
import AnytypeOriginalEditor

enum AnnotationOriginalEditorImportPreparationOutcome {
    case prepared(AnnotationOriginalEditorImportAttempt)
    /// The original SQLite transaction committed. No SDK handle was invoked.
    case recordedWithoutOwnership(AnnotationLocalEditorNativeAttemptObservation)
}

enum AnnotationOriginalEditorImportInvocationOutcome {
    /// Only the original await returned. Native history remains separate;
    /// this is neither a destination mapping nor an acknowledgement.
    case nativeAwaitReturned(AnnotationLocalEditorNativeAttemptObservation)
    case recordedWithoutOwnership(AnnotationLocalEditorNativeAttemptObservation)
}

/// Even a failure after a successful preparation retains that durable fact.
/// No thrown await is interpreted as rollback or permission to retry.
struct AnnotationOriginalEditorImportFailure: Error {
    enum Stage: Sendable { case sdkPreparation, dispatchTransition, nativeAwait }
    let stage: Stage
    let prepared: AnnotationLocalEditorNativeAttemptObservation
    let dispatch: AnnotationLocalEditorNativeAttemptObservation?
    let underlying: any Error
}

/// Retain this object independently of the editor/presentation/awaiting task.
/// Only an actual local receipt and the SDK's real drained callback can fill it.
/// There is no decoder, public initializer, mapping writer or ACK constructor.
@MainActor
final class AnnotationOriginalEditorImportHistory {
    let preparation: AnnotationLocalEditorNativeAttemptObservation
    private(set) var dispatch: AnnotationLocalEditorNativeAttemptObservation?
    private(set) var native: AnytypeOriginalAnnotationImportHistory?
    private let savedDatabaseURL: URL
    private let comparison: AnnotationLocalEditorNativeComparison
    private var durableWrite: Task<URL, Error>?
    private var nativeWaiters: [CheckedContinuation<Void, Never>] = []

    fileprivate init(prepared: AnnotationLocalEditorNativePreparation) {
        preparation = prepared.observation
        savedDatabaseURL = prepared.snapshot.databaseURL
        comparison = prepared.comparison
    }

    fileprivate func recordDispatch(_ receipt: AnnotationLocalEditorNativeAttemptObservation) {
        dispatch = receipt
    }

    fileprivate func recordNative(_ receipt: AnytypeOriginalAnnotationImportHistory) {
        // The concrete original native owner delivers once, after both drains.
        guard native == nil else { return }
        native = receipt
        if let verified = receipt.verifiedNativeReceipt {
            let expected = preparation, target = comparison, databaseURL = savedDatabaseURL
            let dispatched = dispatch?.state == .dispatchMayHaveOccurred
            // The actual drained callback owns this independent durable write.
            // Dismissing or cancelling its UI never converts native effects into
            // rollback, nor loses a late successful native readback.
            durableWrite = Task.detached {
                guard dispatched,
                      verified.source.attemptID == expected.attemptID,
                      verified.source.preparedSessionID == expected.preparedSessionID,
                      verified.source.annotationUUID == expected.annotationUUID,
                      verified.source.savedRevision == expected.savedRevision,
                      verified.source.sourceDigest == expected.sourceDigest,
                      verified.source.payloadDigest == expected.payloadDigest,
                      verified.source.bodyDigest == expected.bodyDigest,
                      verified.source.accountID.utf8.elementsEqual(target.accountID.utf8),
                      verified.source.spaceID.utf8.elementsEqual(target.spaceID.utf8) else {
                    throw AnnotationOriginalEditorReceiptError.wrongAttempt
                }
                return try AnnotationOriginalEditorNativeReceiptFile.persist(
                    verified, capturedDatabaseURL: databaseURL)
            }
        }
        let waiters = nativeWaiters
        nativeWaiters.removeAll()
        for waiter in waiters { waiter.resume() }
    }

    /// Waits for actual drain and its durable local receipt, never for an elapsed
    /// timeout or merely a returned invocation. This is not a remote-device ACK.
    func durableNativeReceipt() async throws -> URL {
        if native == nil {
            await withCheckedContinuation { nativeWaiters.append($0) }
        }
        guard let durableWrite else { throw AnnotationOriginalEditorReceiptError.unverifiedNativeResult }
        return try await durableWrite.value
    }
}

/// Joins one original saved-row preparation to one closed original account/Space
/// import. The durable possible-dispatch transition precedes every native call.
/// Nothing in history can recreate this owner or replace its exact SDK handle.
@MainActor
final class AnnotationOriginalEditorImportAttempt {
    let history: AnnotationOriginalEditorImportHistory
    private let local: AnnotationLocalEditorSession
    private let prepared: AnnotationLocalEditorNativePreparation
    private let observation: AnnotationOriginalEditorSourceObservation
    private let sourceLifetime: AnytypeOriginalAnnotationImportSourceLifetime
    private var native: AnytypeOriginalAnnotationImportAttempt?
    private var invocationStarted = false

    private init(
        local: AnnotationLocalEditorSession,
        prepared: AnnotationLocalEditorNativePreparation,
        observation: AnnotationOriginalEditorSourceObservation,
        sourceLifetime: AnytypeOriginalAnnotationImportSourceLifetime
    ) {
        self.local = local
        self.prepared = prepared
        self.observation = observation
        self.sourceLifetime = sourceLifetime
        history = .init(prepared: prepared)
    }

    static func prepare(
        local: AnnotationLocalEditorSession,
        snapshot: AnnotationLocalEditorSnapshot,
        observation: AnnotationOriginalEditorSourceObservation,
        account: AnytypeOriginalEditorAccountSession
    ) async throws -> AnnotationOriginalEditorImportPreparationOutcome {
        try observation.bindLocal(local)
        try observation.requireCurrent()
        try account.validateCurrent()
        let comparison = try AnnotationLocalEditorNativeComparison(
            accountID: account.identity.accountID, spaceID: account.identity.spaceID
        )
        let outcome = try await local.prepareNativeAttempt(snapshot: snapshot, comparison: comparison)
        let prepared: AnnotationLocalEditorNativePreparation
        switch outcome {
        case .recordedWithoutOwnership(let receipt):
            observation.retire()
            local.retire()
            return .recordedWithoutOwnership(receipt)
        case .prepared(let actual):
            prepared = actual
        }

        // From here on, every error carries the actual committed preparation.
        var lifetime: AnytypeOriginalAnnotationImportSourceLifetime?
        do {
            guard observation.isCurrent, local.ownsNativePreparation(prepared) else {
                observation.retire()
                local.retire()
                return .recordedWithoutOwnership(prepared.observation)
            }
            try Task.checkCancellation()
            try account.validateCurrent()
            guard let version = prepared.snapshot.version,
                  let nativeSnapshot = try AnnotationOriginalEditorMount.nativeBody(in: prepared.snapshot) else {
                throw AnnotationLocalEditorNativeAttemptError.unsupportedSavedBody
            }
            let receipt = prepared.observation
            let source = try AnytypeOriginalAnnotationImportSource(
                namespace: version.namespace,
                annotationUUID: receipt.annotationUUID,
                preparedSessionID: receipt.preparedSessionID,
                attemptID: receipt.attemptID,
                savedRevision: receipt.savedRevision,
                sourceDigest: receipt.sourceDigest,
                payloadDigest: receipt.payloadDigest,
                bodyDigest: receipt.bodyDigest,
                accountID: prepared.comparison.accountID,
                spaceID: prepared.comparison.spaceID
            )
            let actualLifetime = AnytypeOriginalAnnotationImportSourceLifetime(source: source)
            lifetime = actualLifetime
            // Each link is registered outside all transaction/repository locks.
            // Session, DB, annotation, scene and presentation retirement now all
            // synchronously invalidate this exact SDK token before replacement.
            try local.bindNativeImportRetirement(actualLifetime, prepared: prepared)
            try observation.bindImport(actualLifetime, local: local)
            let owner = AnnotationOriginalEditorImportAttempt(
                local: local, prepared: prepared, observation: observation,
                sourceLifetime: actualLifetime
            )
            let retainedHistory = owner.history
            owner.native = try account.prepareAnnotationImport(
                snapshot: nativeSnapshot, sourceLifetime: actualLifetime,
                sourceIsCurrent: { [weak owner] candidate in
                    owner?.isCurrent(candidate) == true
                },
                onDrained: { [retainedHistory] actual in
                    retainedHistory.recordNative(actual)
                }
            )
            guard owner.isCurrent(source) else {
                owner.retire()
                return .recordedWithoutOwnership(receipt)
            }
            return .prepared(owner)
        } catch {
            lifetime?.retire()
            observation.retire()
            local.retire()
            throw AnnotationOriginalEditorImportFailure(
                stage: .sdkPreparation, prepared: prepared.observation,
                dispatch: nil, underlying: error
            )
        }
    }

    /// This callback is deliberately memory-only: exact private preparation,
    /// original session/DB flags, source observation and exact immutable tuple.
    /// No SQL, file access, account creation or decoded-history adoption occurs.
    private func isCurrent(_ candidate: AnytypeOriginalAnnotationImportSource) -> Bool {
        candidate == sourceLifetime.source && sourceLifetime.isCurrent
            && local.ownsNativePreparation(prepared) && observation.isCurrent
    }

    /// Invoke only after explicit user intent. A second invocation never repeats
    /// either the durable transition or native RPC, even after a thrown await.
    func invoke() async throws -> AnnotationOriginalEditorImportInvocationOutcome {
        guard !invocationStarted else { throw AnnotationLocalEditorError.busy }
        invocationStarted = true
        guard let native, isCurrent(sourceLifetime.source) else {
            retire()
            throw AnnotationLocalEditorError.retired
        }
        let local = self.local, lifetime = sourceLifetime
        return try await withTaskCancellationHandler {
            let transition: AnnotationLocalEditorNativeTransitionOutcome
            do {
                transition = try await local.markNativeAttemptMayHaveDispatched(prepared)
            } catch {
                retire()
                throw AnnotationOriginalEditorImportFailure(
                    stage: .dispatchTransition, prepared: prepared.observation,
                    dispatch: history.dispatch, underlying: error
                )
            }
            switch transition {
            case .recordedWithoutOwnership(let receipt):
                history.recordDispatch(receipt)
                retire()
                return .recordedWithoutOwnership(receipt)
            case .recorded(let receipt):
                history.recordDispatch(receipt)
                // No await separates this check from the exact SDK invocation.
                // The SDK independently checks its synchronously retired token.
                guard !Task.isCancelled, isCurrent(sourceLifetime.source) else {
                    retire()
                    return .recordedWithoutOwnership(receipt)
                }
                do {
                    try await native.invoke()
                    retire()
                    return .nativeAwaitReturned(receipt)
                } catch {
                    retire()
                    throw AnnotationOriginalEditorImportFailure(
                        stage: .nativeAwait, prepared: prepared.observation,
                        dispatch: receipt, underlying: error
                    )
                }
            }
        } onCancel: {
            lifetime.retire()
            local.retire()
        }
    }

    @discardableResult
    func requestCancellation() -> AnytypeOriginalAnnotationImportAttempt.CancellationScheduling? {
        native?.requestCancellation()
    }

    func retire() {
        sourceLifetime.retire()
        observation.retire()
        local.retire()
    }

    isolated deinit {
        sourceLifetime.retire()
        observation.retire()
        local.retire()
    }
}

extension AnnotationStore {
    /// Explicit saved-annotation entry point. The account handle can only come
    /// from the SDK's actual account presentation and selected-Space owner.
    /// Preparation performs local bookkeeping and SDK preparation, never an RPC.
    @MainActor
    func prepareOriginalAnnotationImport(
        annotation: Annotation,
        workspace: StudyWorkspaceNavigationAdapter,
        presentationLifetime: AnnotationLocalEditorLifetime,
        account: AnytypeOriginalEditorAccountSession
    ) async throws -> AnnotationOriginalEditorImportPreparationOutcome {
        let observation = try AnnotationOriginalEditorSourceObservation(
            annotation: annotation, store: self, workspace: workspace,
            presentationLifetime: presentationLifetime
        )
        var capturedLocal: AnnotationLocalEditorSession?
        do {
            let local = try makeLocalAnnotationEditor(
                annotation: annotation,
                supportedFormats: AnnotationOriginalEditorMount.supportedFormats
            )
            capturedLocal = local
            try observation.bindLocal(local)
            let snapshot = try await local.read()
            return try await AnnotationOriginalEditorImportAttempt.prepare(
                local: local, snapshot: snapshot, observation: observation, account: account
            )
        } catch {
            observation.retire()
            capturedLocal?.retire()
            throw error
        }
    }
}

private enum AnnotationOriginalEditorReceiptError: Error {
    case wrongAttempt, unverifiedNativeResult, unsafeStorage, conflictingHistory
}

/// Historical data only. It cannot be decoded into an SDK receipt, account,
/// source lifetime or retry permit. The original immutable attempt SQL remains
/// in dispatch_may_have_occurred, preventing duplicate native re-imports.
enum AnnotationOriginalEditorNativeReceiptFile {
    private struct Record: Codable {
        struct Mapping: Codable {
            let sourceSpaceID: String
            let sourceObjectID: String
            let objectID: String
        }
        let schema: String
        let status: String
        let remoteDeviceAcknowledgement: Bool
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
        let objectID: String
        let traceID: String
        let sourceArchiveSHA256: String
        let nativeArchiveSHA256: String
        let nativeResponseSHA256: String
        let nativeResponseBytes: Data
        let objectMappings: [Mapping]
    }

    static func persist(_ receipt: AnytypeOriginalAnnotationImportReceipt,
                        capturedDatabaseURL: URL) throws -> URL {
        guard capturedDatabaseURL.isFileURL,
              receipt.source.namespace == "otzaria.local.annotation",
              !receipt.nativeResponseBytes.isEmpty,
              receipt.nativeResponseBytes.count <= 2 * 1_024 * 1_024,
              SHA256.hash(data: receipt.nativeResponseBytes)
                .map({ String(format: "%02x", $0) }).joined() == receipt.nativeResponseSHA256 else {
            throw AnnotationOriginalEditorReceiptError.wrongAttempt
        }
        let source = receipt.source
        let record = Record(schema: "otzaria.original.annotation.native-commit.v1",
            status: "LOCAL_NATIVE_IMPORT_READBACK_VERIFIED", remoteDeviceAcknowledgement: false,
            namespace: source.namespace, annotationUUID: source.annotationUUID,
            preparedSessionID: source.preparedSessionID, attemptID: source.attemptID,
            savedRevision: source.savedRevision, sourceDigest: source.sourceDigest,
            payloadDigest: source.payloadDigest, bodyDigest: source.bodyDigest,
            accountID: source.accountID, spaceID: source.spaceID,
            objectID: receipt.objectID, traceID: receipt.traceID,
            sourceArchiveSHA256: receipt.sourceArchiveSHA256,
            nativeArchiveSHA256: receipt.nativeArchiveSHA256,
            nativeResponseSHA256: receipt.nativeResponseSHA256,
            nativeResponseBytes: receipt.nativeResponseBytes,
            objectMappings: receipt.objectMappings.map {
                .init(sourceSpaceID: $0.sourceSpaceID,
                      sourceObjectID: $0.sourceObjectID, objectID: $0.objectID)
            })
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let bytes = try encoder.encode(record)
        let manager = FileManager.default
        // Use the originally captured profile path. Never consult the current
        // global profile after the native callback or reopen an unrelated DB.
        let database = capturedDatabaseURL.standardizedFileURL.resolvingSymlinksInPath()
        let directory = database.deletingLastPathComponent()
            .appendingPathComponent(database.lastPathComponent + ".native-import-history", isDirectory: true)
        try manager.createDirectory(at: directory, withIntermediateDirectories: false,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        let values = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else {
            throw AnnotationOriginalEditorReceiptError.unsafeStorage
        }
        // Keep new histories per-note so 5,000 unrelated notes do not require
        // scanning their complete native response archives during one Receive.
        let noteDirectory = directory.appendingPathComponent(source.annotationUUID.uuidString, isDirectory: true)
        try manager.createDirectory(at: noteDirectory, withIntermediateDirectories: false,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        let noteValues = try noteDirectory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard noteValues.isDirectory == true, noteValues.isSymbolicLink != true else {
            throw AnnotationOriginalEditorReceiptError.unsafeStorage
        }
        let url = noteDirectory.appendingPathComponent(source.attemptID.uuidString + ".json", isDirectory: false)
        if manager.fileExists(atPath: url.path) {
            let existing = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard existing.isRegularFile == true, existing.isSymbolicLink != true,
                  existing.fileSize == bytes.count,
                  try Data(contentsOf: url, options: .mappedIfSafe) == bytes else {
                throw AnnotationOriginalEditorReceiptError.conflictingHistory
            }
            return url
        }
        try bytes.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        guard try Data(contentsOf: url, options: .mappedIfSafe) == bytes else {
            throw AnnotationOriginalEditorReceiptError.conflictingHistory
        }
        return url
    }

    /// Historical destination data only. Every selected destination is read
    /// afresh through an actual current original account/Space and UUID/type
    /// validation. Decoding this file grants no SDK ownership, write or ACK.
    struct HistoricalMapping: Sendable, Identifiable {
        var id: String { accountID + ":" + spaceID + ":" + objectID }
        let accountID: String
        let spaceID: String
        let objectID: String
        let savedRevision: Int64
        let bodyDigest: String
        let receiptURL: URL
    }

    static func mappings(annotationUUID: UUID, capturedDatabaseURL: URL) throws -> [HistoricalMapping] {
        guard capturedDatabaseURL.isFileURL else { throw AnnotationOriginalEditorReceiptError.unsafeStorage }
        let database = capturedDatabaseURL.standardizedFileURL.resolvingSymlinksInPath()
        let root = database.deletingLastPathComponent()
            .appendingPathComponent(database.lastPathComponent + ".native-import-history", isDirectory: true)
        let manager = FileManager.default
        let revisions = try AnnotationOriginalEditorRevisionFile.mappings(
            annotationUUID: annotationUUID, capturedDatabaseURL: capturedDatabaseURL) + AnnotationOriginalEditorLifecycleFile.mappings(
            annotationUUID: annotationUUID, capturedDatabaseURL: capturedDatabaseURL)
        guard manager.fileExists(atPath: root.path) else { return revisions }
        func files(in directory: URL) throws -> [URL] {
            let values = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true, values.isSymbolicLink != true else {
                throw AnnotationOriginalEditorReceiptError.unsafeStorage
            }
            let children = try manager.contentsOfDirectory(at: directory,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard children.count <= 10_000 else { throw AnnotationOriginalEditorReceiptError.unsafeStorage }
            return children.filter { $0.pathExtension == "json" }
        }
        let note = root.appendingPathComponent(annotationUUID.uuidString, isDirectory: true)
        var candidates = manager.fileExists(atPath: note.path) ? try files(in: note) : []
        // Read the former flat layout without moving/deleting any historical file.
        candidates += try files(in: root)
        var result: [String: HistoricalMapping] = [:]
        for url in candidates {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true,
                  let size = values.fileSize, size > 0, size <= 3 * 1_024 * 1_024 else {
                throw AnnotationOriginalEditorReceiptError.unsafeStorage
            }
            let bytes = try Data(contentsOf: url, options: .mappedIfSafe)
            guard bytes.count == size else { throw AnnotationOriginalEditorReceiptError.unsafeStorage }
            let record = try JSONDecoder().decode(Record.self, from: bytes)
            guard record.schema == "otzaria.original.annotation.native-commit.v1",
                  record.status == "LOCAL_NATIVE_IMPORT_READBACK_VERIFIED",
                  !record.remoteDeviceAcknowledgement else {
                throw AnnotationOriginalEditorReceiptError.unverifiedNativeResult
            }
            guard record.annotationUUID == annotationUUID else { continue }
            guard record.namespace == "otzaria.local.annotation", record.savedRevision >= 0,
                  !record.accountID.isEmpty, !record.spaceID.isEmpty, !record.objectID.isEmpty,
                  !record.nativeResponseBytes.isEmpty,
                  record.nativeResponseBytes.count <= 2 * 1_024 * 1_024,
                  SHA256.hash(data: record.nativeResponseBytes).map({ String(format: "%02x", $0) }).joined()
                    == record.nativeResponseSHA256,
                  record.objectMappings.contains(where: { $0.objectID.utf8.elementsEqual(record.objectID.utf8) }) else {
                throw AnnotationOriginalEditorReceiptError.unverifiedNativeResult
            }
            let value = HistoricalMapping(accountID: record.accountID, spaceID: record.spaceID,
                objectID: record.objectID, savedRevision: record.savedRevision,
                bodyDigest: record.bodyDigest, receiptURL: url)
            if let prior = result[value.id], prior.savedRevision >= value.savedRevision { continue }
            result[value.id] = value
        }
        for value in revisions {
            if let prior = result[value.id], prior.savedRevision > value.savedRevision { continue }
            if let prior = result[value.id], prior.savedRevision == value.savedRevision,
               prior.bodyDigest != value.bodyDigest { throw AnnotationOriginalEditorReceiptError.conflictingHistory }
            result[value.id] = value
        }
        return result.values.sorted {
            if $0.savedRevision != $1.savedRevision { return $0.savedRevision > $1.savedRevision }
            return $0.id.utf8.lexicographicallyPrecedes($1.id.utf8)
        }
    }

}

#endif
