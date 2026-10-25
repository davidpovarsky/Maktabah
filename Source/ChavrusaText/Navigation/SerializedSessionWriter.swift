import Foundation

/// Monotonically versioned, deadlock-safe serial disk writer for session persistence in ChavrusaText.
/// Fixes SESSION-02 by eliminating races between debounced and immediate saves,
/// guaranteeing that stale queued writes cannot overwrite newer immediate writes,
/// and ensuring atomic replacement preserving last-good data without deletion gaps.
/// P3-2: Adds observable error tracking for asynchronous writes and guarantees temporary cleanup.
public final class SerializedSessionWriter: @unchecked Sendable {
    public static let shared = SerializedSessionWriter()

    private let ioQueue: DispatchQueue
    private let queueKey = DispatchSpecificKey<Void>()
    private let lock = NSLock()
    private var currentRevision: UInt64 = 0
    private var lastCommittedRevision: UInt64 = 0
    private var pendingWorkItem: DispatchWorkItem?

    /// Observable error tracking for delayed asynchronous writes (P3-2).
    public var onDelayedWriteError: (@Sendable (UInt64, Error) -> Void)?
    public private(set) var lastDelayedWriteError: (revision: UInt64, errorMessage: String)?

    public init(queueLabel: String = "org.maktabah.session.writer") {
        self.ioQueue = DispatchQueue(label: queueLabel, qos: .utility)
        self.ioQueue.setSpecific(key: queueKey, value: ())
    }

    /// True if currently executing on this writer's dedicated ioQueue.
    private var isOnIOQueue: Bool {
        DispatchQueue.getSpecific(key: queueKey) != nil
    }

    /// Schedules a debounced save with a new monotonic revision.
    /// Routine saves execute asynchronously off the main thread.
    public func scheduleSave(
        to targetURL: URL,
        debounceInterval: TimeInterval = 0.5,
        producer: @escaping () throws -> Data
    ) {
        lock.lock()
        currentRevision &+= 1
        let assignedRevision = currentRevision
        pendingWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            do {
                try self.performWriteIfCurrent(
                    assignedRevision: assignedRevision,
                    targetURL: targetURL,
                    producer: producer
                )
            } catch {
                self.lock.lock()
                self.lastDelayedWriteError = (assignedRevision, error.localizedDescription)
                let callback = self.onDelayedWriteError
                self.lock.unlock()

                callback?(assignedRevision, error)

                #if DEBUG
                print("[SerializedSessionWriter] Debounced write error (rev \(assignedRevision)): \(error)")
                #endif
            }
        }
        pendingWorkItem = workItem
        lock.unlock()

        ioQueue.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
    }

    /// Performs an immediate synchronous save (e.g. on backgrounding or app quit).
    /// Guarantees write completes with the latest monotonic revision and propagates any disk/serialization errors.
    /// Reentrancy-safe: will not deadlock if invoked from within ioQueue.
    public func saveImmediately(
        to targetURL: URL,
        producer: () throws -> Data
    ) throws {
        lock.lock()
        currentRevision &+= 1
        let assignedRevision = currentRevision
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
        lock.unlock()

        if isOnIOQueue {
            try performWriteIfCurrent(
                assignedRevision: assignedRevision,
                targetURL: targetURL,
                producer: producer
            )
        } else {
            var writeError: Error?
            ioQueue.sync {
                do {
                    try self.performWriteIfCurrent(
                        assignedRevision: assignedRevision,
                        targetURL: targetURL,
                        producer: producer
                    )
                } catch {
                    writeError = error
                }
            }
            if let writeError {
                throw writeError
            }
        }
    }

    /// Clears the session file atomically and synchronously.
    /// Cancels any pending delayed saves, increments the monotonic revision to drop in-flight stale saves,
    /// and safely removes the destination file on the serial ioQueue.
    public func clear(at targetURL: URL) throws {
        lock.lock()
        currentRevision &+= 1
        let assignedRevision = currentRevision
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
        lock.unlock()

        let doRemove = {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: targetURL.path) {
                try fileManager.removeItem(at: targetURL)
            }
            self.lock.lock()
            if assignedRevision > self.lastCommittedRevision {
                self.lastCommittedRevision = assignedRevision
            }
            self.lock.unlock()
        }

        if isOnIOQueue {
            try doRemove()
        } else {
            var removeError: Error?
            ioQueue.sync {
                do {
                    try doRemove()
                } catch {
                    removeError = error
                }
            }
            if let removeError {
                throw removeError
            }
        }
    }

    /// Writes data atomically using safe replacement, ensuring no intermediate missing-file gap.
    private func performWriteIfCurrent(
        assignedRevision: UInt64,
        targetURL: URL,
        producer: () throws -> Data
    ) throws {
        lock.lock()
        // If a newer revision has already been committed, drop this stale work before spending CPU on encoding
        if assignedRevision < lastCommittedRevision {
            lock.unlock()
            return
        }
        lock.unlock()

        // Generate data outside lock
        let data = try producer()

        lock.lock()
        // Re-check after generation in case a newer immediate write committed while producer was running
        if assignedRevision < lastCommittedRevision {
            lock.unlock()
            return
        }
        lock.unlock()

        let fileManager = FileManager.default
        let parentDir = targetURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)

        let tempURL = parentDir.appendingPathComponent(".session_tmp_\(UUID().uuidString)")
        try data.write(to: tempURL, options: [.atomic])

        do {
            #if os(iOS) || os(macOS)
            if fileManager.fileExists(atPath: targetURL.path) {
                // Safe atomic replace on Darwin without pre-deleting the destination file
                _ = try fileManager.replaceItemAt(
                    targetURL,
                    withItemAt: tempURL,
                    backupItemName: nil,
                    options: .usingNewMetadataOnly
                )
            } else {
                try fileManager.moveItem(at: tempURL, to: targetURL)
            }
            #else
            // Safe replacement on Windows / Linux Foundation where replaceItemAt is not implemented
            let backupURL = parentDir.appendingPathComponent(".session_bak_\(UUID().uuidString)")
            let hadExisting = fileManager.fileExists(atPath: targetURL.path)
            if hadExisting {
                try fileManager.moveItem(at: targetURL, to: backupURL)
            }
            do {
                try fileManager.moveItem(at: tempURL, to: targetURL)
                if hadExisting {
                    _ = try? fileManager.removeItem(at: backupURL)
                }
            } catch {
                if hadExisting {
                    _ = try? fileManager.moveItem(at: backupURL, to: targetURL)
                }
                throw error
            }
            #endif

            lock.lock()
            if assignedRevision > lastCommittedRevision {
                lastCommittedRevision = assignedRevision
            }
            lock.unlock()
        } catch {
            _ = try? fileManager.removeItem(at: tempURL)
            throw error
        }
    }

    /// Accessor for testing revision tracking.
    public var currentRevisions: (current: UInt64, committed: UInt64) {
        lock.lock()
        defer { lock.unlock() }
        return (currentRevision, lastCommittedRevision)
    }
}
