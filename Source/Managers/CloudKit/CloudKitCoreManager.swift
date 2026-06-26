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
}
