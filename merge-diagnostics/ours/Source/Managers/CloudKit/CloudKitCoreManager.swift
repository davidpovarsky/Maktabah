//
//  CloudKitCoreManager.swift
//  Maktabah
//

import CloudKit
import Foundation

final class CloudKitCoreManager {
    static let shared = CloudKitCoreManager()

    let container: CKContainer
    let privateDatabase: CKDatabase
    let zoneId: CKRecordZone.ID
    let isAvailable: Bool

    let changeTokenKey = "CKServerChangeToken_AnnotationsZone"
    private(set) var isSyncing = false
    private let syncQueue = DispatchQueue(label: "com.maktabah.cloudkitcore.sync", attributes: .concurrent)
    private var notifyTask: Task<Void, Never>?

    private let operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.maktabah.cloudkitcore.operation"
        queue.maxConcurrentOperationCount = 2
        return queue
    }()

    private init() {
        // Do not force CKContainer(identifier: "iCloud.Maktabah") in side-loaded builds.
        // Re-signed IPAs often lack the matching iCloud entitlement and can crash at launch.
        container = CKContainer.default()
        privateDatabase = container.privateCloudDatabase
        zoneId = CKRecordZone.ID(zoneName: "AnnotationsZone", ownerName: CKCurrentUserDefaultName)
        isAvailable = false
    }

    func setSyncing(_ syncing: Bool, completion: (() -> Void)? = nil) {
        syncQueue.async(flags: .barrier) { [weak self] in
            self?.isSyncing = syncing
            completion?()
        }
    }

    func saveToken(_ token: CKServerChangeToken?) {}

    func loadToken() -> CKServerChangeToken? { nil }

    func resetToken() {
        UserDefaults.standard.removeObject(forKey: changeTokenKey)
        UserDefaults.standard.removeObject(forKey: "CloudKitSyncManager_InitialUploadDone")
        setSyncing(false)
    }

    func upload(records: [CKRecord], completion: ((Result<Void, Error>) -> Void)? = nil) {
        completion?(.success(()))
    }

    func delete(recordIds: [CKRecord.ID], completion: ((Result<Void, Error>) -> Void)? = nil) {
        completion?(.success(()))
    }

    func fetchChanges(
        previousToken: CKServerChangeToken?,
        recordChanged: @escaping (CKRecord) -> Void,
        recordDeleted: @escaping (CKRecord.ID) -> Void,
        completion: @escaping (Result<(CKServerChangeToken?, Bool), Error>) -> Void
    ) {
        completion(.success((previousToken, false)))
    }

    // MARK: - Cross-Platform Sync Notification

    /// Private, penjagaan untuk tidak diakses dari luar ``CloudKitCoreManager``.
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

    /// Private, penjagaan untuk tidak dijalankan di luar `notifyTask`.
    private func asyncWorker() {
        guard let request = makeWorker() else { return }
        URLSession.shared.dataTask(with: request).resume()
    }

    /// Sync `HTTP POST` ke cloudFlare worker dengan DispatchSemaphore timeout 3 detik.
    func syncWorker() {
        guard notifyTask != nil,  let request = makeWorker() else { return }
        let semaphore = DispatchSemaphore(value: 0)
        var requestError: Error?
        URLSession.shared.dataTask(with: request) { _, _, error in
            requestError = error
            semaphore.signal()
        }.resume()

        let timeoutResult = semaphore.wait(timeout: .now() + 3.0)

        #if DEBUG
        if timeoutResult == .timedOut {
            print("CloudKitSyncManager: Sync worker timed out on exit.")
        } else if let error = requestError {
            print("CloudKitSyncManager: Failed to notify Android: \(error)")
        } else {
            print("CloudKitSyncManager: Successfully notified Android to sync before termination.")
        }
        #endif
    }

    func notifyWorkerToSync() {
        notifyTask?.cancel()
        notifyTask = Task {
            try? await Task.sleep(for: .seconds(60))
            guard !Task.isCancelled else { return }
            asyncWorker()
            notifyTask = nil
        }
    }
}
