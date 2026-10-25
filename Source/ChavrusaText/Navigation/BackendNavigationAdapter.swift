import Foundation

enum BackendNavigationAdapterError: Error, Equatable, LocalizedError {
    case invalidBackendID(String)
    case writeFailed(String)
    case corruptedSnapshot(String)

    var errorDescription: String? {
        switch self {
        case .invalidBackendID(let id):
            return "Invalid backend ID '\(id)'. Must be a canonical BackendID."
        case .writeFailed(let msg):
            return "Failed to write backend session snapshot: \(msg)"
        case .corruptedSnapshot(let msg):
            return "Corrupted backend session snapshot: \(msg)"
        }
    }
}

/// Lifecycle state of a transactional library backend switch.
enum BackendTransitionState: Equatable, Sendable {
    case idle
    case prepared(outgoing: BackendID, incoming: BackendID)
    case outgoingSnapshotPersisted(outgoing: BackendID, incoming: BackendID)
    case uiTransitionCommitted(incoming: BackendID)
    case incomingSnapshotRestored(incoming: BackendID)
    case failed(error: String, rolledBack: Bool)
}

/// Adapter managing persistent per-backend tab sessions in ChavrusaText.
/// Fixes SESSION-03 by preserving durable tab state per canonical backend on disk
/// rather than destructively discarding all open tabs when switching between backends.
/// P3-2 & Final Gate: Ensures strict transaction ordering (disk write before cache update),
/// serialized disk I/O under lock protection, and input validation without phantom cache states.
final class BackendNavigationAdapter: @unchecked Sendable {
    static let shared = BackendNavigationAdapter()

    private let lock = NSLock()
    private var inMemoryCache: [String: Data] = [:]
    private let storageDirectory: URL

    private(set) var transitionState: BackendTransitionState = .idle
    private(set) var lastTransitionError: String? = nil

    init(storageDirectory: URL? = nil) {
        if let storageDirectory {
            self.storageDirectory = storageDirectory
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.storageDirectory = appSupport.appendingPathComponent("ChavrusaText/BackendSessions", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.storageDirectory, withIntermediateDirectories: true)
    }

    /// Resolves canonical file URL for a validated BackendID.
    private func fileURL(for backend: BackendID) -> URL {
        storageDirectory.appendingPathComponent("\(backend.rawValue).session.json")
    }

    /// Validates raw string against canonical BackendID, rejecting path traversal and unknown backends.
    func validateBackendID(_ rawID: String) throws -> BackendID {
        guard !rawID.contains("/"), !rawID.contains("\\"), !rawID.contains("..") else {
            throw BackendNavigationAdapterError.invalidBackendID(rawID)
        }
        guard let backend = BackendID(rawValue: rawID) else {
            throw BackendNavigationAdapterError.invalidBackendID(rawID)
        }
        return backend
    }

    /// Saves session snapshot for a canonical BackendID.
    /// Serialized under lock: disk write MUST succeed before updating in-memory cache.
    func saveBackendSessionSnapshot(backend: BackendID, sessionData: Data) throws {
        guard !sessionData.isEmpty else {
            throw BackendNavigationAdapterError.corruptedSnapshot("Cannot save empty snapshot data for \(backend.rawValue)")
        }
        lock.lock()
        defer { lock.unlock() }

        let targetURL = fileURL(for: backend)
        let parentDir = targetURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

        let tempURL = parentDir.appendingPathComponent(".backend_tmp_\(UUID().uuidString)")
        do {
            try sessionData.write(to: tempURL, options: [.atomic])
            #if os(iOS) || os(macOS)
            if FileManager.default.fileExists(atPath: targetURL.path) {
                _ = try FileManager.default.replaceItemAt(
                    targetURL,
                    withItemAt: tempURL,
                    backupItemName: nil,
                    options: .usingNewMetadataOnly
                )
            } else {
                try FileManager.default.moveItem(at: tempURL, to: targetURL)
            }
            #else
            let backupURL = parentDir.appendingPathComponent(".backend_bak_\(UUID().uuidString)")
            let hadExisting = FileManager.default.fileExists(atPath: targetURL.path)
            if hadExisting {
                try FileManager.default.moveItem(at: targetURL, to: backupURL)
            }
            do {
                try FileManager.default.moveItem(at: tempURL, to: targetURL)
                if hadExisting {
                    _ = try? FileManager.default.removeItem(at: backupURL)
                }
            } catch {
                if hadExisting {
                    _ = try? FileManager.default.moveItem(at: backupURL, to: targetURL)
                }
                throw error
            }
            #endif
        } catch {
            _ = try? FileManager.default.removeItem(at: tempURL)
            throw BackendNavigationAdapterError.writeFailed(error.localizedDescription)
        }

        // Update cache ONLY AFTER successful disk write
        inMemoryCache[backend.rawValue] = sessionData
    }

    /// Convenience overload accepting raw string ID.
    func saveBackendSessionSnapshot(backendID: String, sessionData: Data) throws {
        let backend = try validateBackendID(backendID)
        try saveBackendSessionSnapshot(backend: backend, sessionData: sessionData)
    }

    /// Retrieves saved session snapshot for a canonical BackendID.
    /// Serialized under lock to avoid phantom cache reads.
    func retrieveBackendSessionSnapshot(backend: BackendID) -> Data? {
        lock.lock()
        defer { lock.unlock() }

        if let cached = inMemoryCache[backend.rawValue] {
            return cached
        }

        let targetURL = fileURL(for: backend)
        guard let data = try? Data(contentsOf: targetURL), !data.isEmpty else {
            return nil
        }

        inMemoryCache[backend.rawValue] = data
        return data
    }

    /// Convenience overload accepting raw string ID.
    func retrieveBackendSessionSnapshot(backendID: String) -> Data? {
        guard let backend = try? validateBackendID(backendID) else {
            return nil
        }
        return retrieveBackendSessionSnapshot(backend: backend)
    }

    /// Clears saved session for a canonical BackendID from disk and cache.
    /// Serialized under lock; propagates removal errors.
    @discardableResult
    func clearBackendSessionSnapshot(backend: BackendID) throws -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let targetURL = fileURL(for: backend)
        let fileExisted = FileManager.default.fileExists(atPath: targetURL.path)
        if fileExisted {
            do {
                try FileManager.default.removeItem(at: targetURL)
            } catch {
                throw BackendNavigationAdapterError.writeFailed("Failed to remove snapshot file for \(backend.rawValue): \(error.localizedDescription)")
            }
        }

        inMemoryCache.removeValue(forKey: backend.rawValue)
        return fileExisted
    }

    /// Convenience overload accepting raw string ID.
    @discardableResult
    func clearBackendSessionSnapshot(backendID: String) throws -> Bool {
        let backend = try validateBackendID(backendID)
        return try clearBackendSessionSnapshot(backend: backend)
    }

    /// Strongly typed transactional preparation: validates and persists outgoing snapshot, then validates incoming snapshot.
    /// Preserves last-good outgoing session on error or when outgoing session is nil.
    func prepareTransition(
        outgoingBackend: BackendID,
        outgoingSession: () throws -> Data?,
        incomingBackend: BackendID,
        incomingValidator: ((Data) throws -> [PreparedBackendTransition.StagedTabSession])? = nil,
        token: UInt64 = 0
    ) throws -> PreparedBackendTransition {
        lock.lock()
        transitionState = .prepared(outgoing: outgoingBackend, incoming: incomingBackend)
        lastTransitionError = nil
        lock.unlock()

        // 1. Snapshot outgoing backend if tabs exist (preserve last good if nil/empty)
        var outgoingData: Data? = nil
        do {
            if let data = try outgoingSession(), !data.isEmpty {
                outgoingData = data
                try saveBackendSessionSnapshot(backend: outgoingBackend, sessionData: data)
            } else {
                outgoingData = retrieveBackendSessionSnapshot(backend: outgoingBackend)
            }
        } catch {
            let msg = "Failed to persist outgoing session for \(outgoingBackend.rawValue): \(error.localizedDescription)"
            lock.lock()
            lastTransitionError = msg
            transitionState = .failed(error: msg, rolledBack: true)
            lock.unlock()
            throw BackendNavigationAdapterError.writeFailed(msg)
        }

        lock.lock()
        transitionState = .outgoingSnapshotPersisted(outgoing: outgoingBackend, incoming: incomingBackend)
        lock.unlock()

        // 2. Validate incoming snapshot before any UI mutation
        let incomingData = retrieveBackendSessionSnapshot(backend: incomingBackend)
        if let incomingData, !incomingData.isEmpty {
            var stagedTabs: [PreparedBackendTransition.StagedTabSession] = []
            if let incomingValidator {
                do {
                    stagedTabs = try incomingValidator(incomingData)
                } catch let err as BackendNavigationAdapterError {
                    let msg = "Validation failed for incoming backend \(incomingBackend.rawValue): \(err.localizedDescription)"
                    lock.lock()
                    lastTransitionError = msg
                    transitionState = .failed(error: msg, rolledBack: true)
                    lock.unlock()
                    throw err
                } catch let err as BackendTransitionError {
                    let msg = "Validation failed for incoming backend \(incomingBackend.rawValue): \(err.localizedDescription)"
                    lock.lock()
                    lastTransitionError = msg
                    transitionState = .failed(error: msg, rolledBack: true)
                    lock.unlock()
                    throw err
                } catch {
                    let msg = "Corrupted snapshot for incoming backend \(incomingBackend.rawValue): \(error.localizedDescription)"
                    lock.lock()
                    lastTransitionError = msg
                    transitionState = .failed(error: msg, rolledBack: true)
                    lock.unlock()
                    throw BackendNavigationAdapterError.corruptedSnapshot(msg)
                }
            }
            return PreparedBackendTransition(
                transitionToken: token,
                outgoingBackend: outgoingBackend,
                incomingBackend: incomingBackend,
                outgoingSnapshotData: outgoingData,
                incomingSnapshotData: incomingData,
                isCleanDestination: false,
                stagedTabs: stagedTabs,
                targetActiveTabId: stagedTabs.first?.id
            )
        } else {
            return PreparedBackendTransition(
                transitionToken: token,
                outgoingBackend: outgoingBackend,
                incomingBackend: incomingBackend,
                outgoingSnapshotData: outgoingData,
                incomingSnapshotData: nil,
                isCleanDestination: true,
                stagedTabs: [],
                targetActiveTabId: nil
            )
        }
    }

    /// Legacy overload returning tuple for backward compatibility.
    func prepareTransitionLegacy(
        outgoingBackend: BackendID,
        outgoingSession: () throws -> Data?,
        incomingBackend: BackendID,
        incomingValidator: ((Data) throws -> Void)? = nil
    ) throws -> (snapshotRestored: Data?, isCleanDestination: Bool) {
        lock.lock()
        transitionState = .prepared(outgoing: outgoingBackend, incoming: incomingBackend)
        lastTransitionError = nil
        lock.unlock()

        // 1. Snapshot outgoing backend if tabs exist (preserve last good if nil/empty)
        do {
            if let data = try outgoingSession(), !data.isEmpty {
                try saveBackendSessionSnapshot(backend: outgoingBackend, sessionData: data)
            }
        } catch {
            let msg = "Failed to persist outgoing session for \(outgoingBackend.rawValue): \(error.localizedDescription)"
            lock.lock()
            lastTransitionError = msg
            transitionState = .failed(error: msg, rolledBack: true)
            lock.unlock()
            throw BackendNavigationAdapterError.writeFailed(msg)
        }

        lock.lock()
        transitionState = .outgoingSnapshotPersisted(outgoing: outgoingBackend, incoming: incomingBackend)
        lock.unlock()

        // 2. Validate incoming snapshot before any UI mutation
        let incomingData = retrieveBackendSessionSnapshot(backend: incomingBackend)
        if let incomingData, !incomingData.isEmpty {
            if let incomingValidator {
                do {
                    try incomingValidator(incomingData)
                } catch {
                    let msg = "Corrupted snapshot for incoming backend \(incomingBackend.rawValue): \(error.localizedDescription)"
                    lock.lock()
                    lastTransitionError = msg
                    transitionState = .failed(error: msg, rolledBack: true)
                    lock.unlock()
                    throw BackendNavigationAdapterError.corruptedSnapshot(msg)
                }
            }
            return (snapshotRestored: incomingData, isCleanDestination: false)
        } else {
            return (snapshotRestored: nil, isCleanDestination: true)
        }
    }

    /// Marks the UI transition as committed.
    func commitTransition(incomingBackend: BackendID) {
        lock.lock()
        transitionState = .uiTransitionCommitted(incoming: incomingBackend)
        lock.unlock()
    }

    /// Marks the transition as completed.
    func completeTransition(incomingBackend: BackendID) {
        lock.lock()
        transitionState = .incomingSnapshotRestored(incoming: incomingBackend)
        lock.unlock()
    }

    /// Explicitly resets transition state to idle or failed.
    func resetTransition() {
        lock.lock()
        transitionState = .idle
        lastTransitionError = nil
        lock.unlock()
    }
}
