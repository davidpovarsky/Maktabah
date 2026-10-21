//
//  CloudKitCoreManager.swift
//  Maktabah
//

import CloudKit
import Foundation
import OSLog
import Synchronization

/// Manajer inti untuk operasi CloudKit yang kompatibel penuh dengan Swift 6.
///
/// Menggunakan `Synchronization.Mutex` (macOS 15+ / iOS 18+) untuk menggantikan `DispatchQueue.sync`
/// dan barrier queue, sehingga thread-safe tanpa risiko deadlock saat dipanggil
/// dari dalam konteks `actor` atau Swift Concurrency Task.
final class CloudKitCoreManager: Sendable {
    /// Struktur data internal untuk membungkus state yang membutuhkan sinkronisasi mutual exclusion.
    private struct ManagerState {
        var isSyncing: Bool = false
        var notifyTask: Task<Void, Never>?
    }

    /// Singleton instance thread-safe yang valid dalam Swift 6 tanpa perlu `nonisolated(unsafe)`.
    static let shared = CloudKitCoreManager()

    static let containerIdentifier = "iCloud.com.davidpovarsky.chavrusatext"

    let container: CKContainer?
    let privateDatabase: CKDatabase?
    let zoneId: CKRecordZone.ID
    let configurationError: String?

    var isAvailable: Bool { container != nil && privateDatabase != nil }

    let changeTokenKey = "CKServerChangeToken_AnnotationsZone"

    /// Antrean operasi CloudKit untuk membatasi konkurensi agar terhindar dari rate limit.
    private let operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.maktabah.cloudkitcore.operation"
        queue.maxConcurrentOperationCount = 2
        return queue
    }()

    /// Mutex state pengganti concurrent DispatchQueue / queue.sync
    private let state: Mutex<ManagerState>

    private init() {
        zoneId = CKRecordZone.ID(zoneName: "AnnotationsZone", ownerName: CKCurrentUserDefaultName)
        state = Mutex(ManagerState())

        guard Self.hasContainerEntitlement(Self.containerIdentifier) else {
            let message = "CloudKit container is unavailable or unentitled: \(Self.containerIdentifier)"
            container = nil
            privateDatabase = nil
            configurationError = message
            #if DEBUG
            print("CloudKit configuration notice: \(message)")
            #endif
            return
        }
        let resolvedContainer = CKContainer(identifier: Self.containerIdentifier)
        container = resolvedContainer
        privateDatabase = resolvedContainer.privateCloudDatabase
        configurationError = nil
    }

    private static func hasContainerEntitlement(_ identifier: String) -> Bool {
        #if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("-enableSimulatorCloudKit") {
            return true
        }
        return false
        #else
        if let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
           let data = try? Data(contentsOf: url) {
            guard let string = String(data: data, encoding: .ascii),
                  let start = string.range(of: "<plist"),
                  let end = string.range(of: "</plist>") else {
                return false
            }
            let plistString = String(string[start.lowerBound..<end.upperBound])
            guard let plistData = plistString.data(using: .utf8),
                  let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
                  let entitlements = plist["Entitlements"] as? [String: Any] else {
                return false
            }

            if let containers = entitlements["com.apple.developer.icloud-container-identifiers"] as? [String] {
                return containers.contains(identifier)
            }
            if let singleContainer = entitlements["com.apple.developer.icloud-container-identifiers"] as? String {
                return singleContainer == identifier
            }
            return false
        }
        return true
        #endif
    }

    /// Membaca status sinkronisasi secara thread-safe menggunakan Mutex `withLock`.
    /// Aman dipanggil secara sinkron dari dalam `actor` tanpa risiko blocking thread pool GCD.
    var isSyncing: Bool {
        state.withLock { $0.isSyncing }
    }

    /// Mengubah status sinkronisasi secara atomik dengan Mutex.
    func setSyncing(_ syncing: Bool, completion: (@Sendable () -> Void)? = nil) {
        state.withLock {
            $0.isSyncing = syncing
        }
        completion?()
    }

    /// Mencoba memulai sinkronisasi secara atomik. Mengembalikan `true` jika berhasil memulai, `false` jika sedang berjalan.
    func tryBeginSyncing() -> Bool {
        state.withLock { state in
            guard !state.isSyncing else { return false }
            state.isSyncing = true
            return true
        }
    }

    // MARK: - Token Management

    func saveToken(_ token: CKServerChangeToken?) {
        guard let token else { return }
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: changeTokenKey)
        }
    }

    func loadToken() -> CKServerChangeToken? {
        guard let data = UserDefaults.standard.data(forKey: changeTokenKey) else { return nil }
        do {
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
            unarchiver.requiresSecureCoding = true
            return unarchiver.decodeObject(of: CKServerChangeToken.self, forKey: NSKeyedArchiveRootObjectKey)
        } catch {
            return nil
        }
    }

    func resetToken() {
        UserDefaults.standard.removeObject(forKey: changeTokenKey)
        UserDefaults.standard.removeObject(forKey: "CloudKitSyncManager_InitialUploadDone")
        setSyncing(false)
    }

    // MARK: - Core Operations

    func upload(records: [CKRecord], completion: (@Sendable (Result<Void, any Error>) -> Void)? = nil) {
        guard let privateDatabase else {
            completion?(.failure(CloudKitConfigurationError.unavailable(configurationError)))
            return
        }
        guard !records.isEmpty else {
            completion?(.success(()))
            return
        }

        let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        operation.savePolicy = .changedKeys

        operation.modifyRecordsResultBlock = { [weak self] result in
            completion?(result)
            self?.notifyWorkerToSync()
        }

        operation.database = privateDatabase
        operation.qualityOfService = .userInitiated
        operationQueue.addOperation(operation)
    }

    func delete(recordIds: [CKRecord.ID], completion: (@Sendable (Result<Void, any Error>) -> Void)? = nil) {
        guard let privateDatabase else {
            completion?(.failure(CloudKitConfigurationError.unavailable(configurationError)))
            return
        }
        guard !recordIds.isEmpty else {
            completion?(.success(()))
            return
        }

        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIds)
        operation.modifyRecordsResultBlock = { [weak self] result in
            completion?(result)
            self?.notifyWorkerToSync()
        }

        operation.database = privateDatabase
        operation.qualityOfService = .userInitiated
        operationQueue.addOperation(operation)
    }

    func fetchChanges(
        previousToken: CKServerChangeToken?,
        recordChanged: @escaping @Sendable (CKRecord) -> Void,
        recordDeleted: @escaping @Sendable (CKRecord.ID) -> Void,
        completion: @escaping @Sendable (Result<(CKServerChangeToken?, Bool), any Error>) -> Void
    ) {
        guard let privateDatabase else {
            completion(.failure(CloudKitConfigurationError.unavailable(configurationError)))
            return
        }
        let options = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        options.previousServerChangeToken = previousToken

        let operation = CKFetchRecordZoneChangesOperation(
            recordZoneIDs: [zoneId],
            configurationsByRecordZoneID: [zoneId: options]
        )

        struct FetchResultState: Sendable {
            var finalToken: CKServerChangeToken?
            var moreComing: Bool = false
        }
        let fetchState = Mutex(FetchResultState())

        operation.recordWasChangedBlock = { _, recordResult in
            if let record = try? recordResult.get() {
                recordChanged(record)
            }
        }

        operation.recordWithIDWasDeletedBlock = { recordId, _ in
            recordDeleted(recordId)
        }

        operation.recordZoneFetchResultBlock = { _, result in
            if case let .success(successData) = result {
                fetchState.withLock {
                    $0.finalToken = successData.serverChangeToken
                    $0.moreComing = successData.moreComing
                }
            }
        }

        operation.fetchRecordZoneChangesResultBlock = { result in
            switch result {
            case .success:
                let extracted = fetchState.withLock { ($0.finalToken, $0.moreComing) }
                completion(.success(extracted))
            case let .failure(error):
                completion(.failure(error))
            }
        }

        operation.database = privateDatabase
        operation.qualityOfService = .userInitiated
        operationQueue.addOperation(operation)
    }

    // MARK: - Modern Swift Concurrency (Actor-Friendly Async APIs)

    /// Wrapper modern berbasis async/await untuk dipanggil langsung dari konteks `actor` atau Task.
    func upload(records: [CKRecord]) async throws {
        try await withCheckedThrowingContinuation { continuation in
            upload(records: records) { result in
                continuation.resume(with: result)
            }
        }
    }

    /// Wrapper modern berbasis async/await untuk penghapusan record.
    func delete(recordIds: [CKRecord.ID]) async throws {
        try await withCheckedThrowingContinuation { continuation in
            delete(recordIds: recordIds) { result in
                continuation.resume(with: result)
            }
        }
    }

    // MARK: - Cross-Platform Sync Notification

    private func makeWorker() -> URLRequest? {
        guard AppConfig.useCrossPlatformSync else { return nil }

        var urlString = AppConfig.customWorkerURL
        if urlString.isEmpty {
            urlString = Bundle.main.object(forInfoDictionaryKey: "WorkerURL") as? String ?? ""
        }

        guard !urlString.isEmpty, urlString != "$(WORKER_URL)",
              let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        return request
    }

    private func asyncWorker() {
        guard let request = makeWorker() else { return }
        URLSession.shared.dataTask(with: request).resume()
    }

    func notifyWorkerToSync() {
        state.withLock { s in
            guard s.notifyTask == nil else { return }

            s.notifyTask = Task { [weak self] in
                defer {
                    self?.state.withLock { state in
                        state.notifyTask = nil
                    }
                }

                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { return }
                self?.asyncWorker()
            }
        }
    }

    func syncWorker() {
        let hasPendingTask = state.withLock { s -> Bool in
            guard s.notifyTask != nil else { return false }
            s.notifyTask?.cancel()
            s.notifyTask = nil
            return true
        }

        guard hasPendingTask, let request = makeWorker() else { return }

        let semaphore = DispatchSemaphore(value: 0)
        let errorState = Mutex<(any Error)?>(nil)

        URLSession.shared.dataTask(with: request) { _, _, error in
            errorState.withLock { $0 = error }
            semaphore.signal()
        }.resume()

        let timeoutResult = semaphore.wait(timeout: .now() + 3.0)

        let requestError = errorState.withLock { $0 }
        if timeoutResult == .timedOut {
            Logger.sync.error("CloudKitSyncManager: Sync worker timed out on exit.")
        } else if let requestError {
            Logger.sync.error("CloudKitSyncManager: Failed to notify Android: \(requestError.localizedDescription, privacy: .public)")
        } else {
            Logger.sync.debug("CloudKitSyncManager: Successfully notified Android to sync before termination.")
        }
    }
}

enum CloudKitConfigurationError: LocalizedError {
    case unavailable(String?)

    var errorDescription: String? {
        switch self {
        case .unavailable(let detail):
            return detail ?? "CloudKit is unavailable for this signed application."
        }
    }
}
