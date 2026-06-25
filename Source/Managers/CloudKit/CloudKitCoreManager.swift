//
//  CloudKitCoreManager.swift
//  Maktabah
//

import CloudKit
import Foundation
import Security

final class CloudKitCoreManager {
    static let shared = CloudKitCoreManager()

    let container: CKContainer?
    let privateDatabase: CKDatabase?
    let zoneId: CKRecordZone.ID?

    let changeTokenKey = "CKServerChangeToken_AnnotationsZone"
    private(set) var isSyncing = false
    private let syncQueue = DispatchQueue(label: "com.maktabah.cloudkitcore.sync", attributes: .concurrent)

    /// Using OperationQueue to prevent spamming CloudKit with too many concurrent operations
    private let operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.maktabah.cloudkitcore.operation"
        queue.maxConcurrentOperationCount = 2
        return queue
    }()

    private init() {
        let containerIdentifier = "iCloud.Maktabah"

        guard Self.hasICloudContainerEntitlement(containerIdentifier) else {
            container = nil
            privateDatabase = nil
            zoneId = nil
            print("CloudKit disabled: missing entitlement for \(containerIdentifier)")
            return
        }

        let resolvedContainer = CKContainer(identifier: containerIdentifier)
        container = resolvedContainer
        privateDatabase = resolvedContainer.privateCloudDatabase
        zoneId = CKRecordZone.ID(zoneName: "AnnotationsZone", ownerName: CKCurrentUserDefaultName)
    }

    private static func hasICloudContainerEntitlement(_ identifier: String) -> Bool {
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        guard let value = SecTaskCopyValueForEntitlement(
            task,
            "com.apple.developer.icloud-container-identifiers" as CFString,
            nil
        ) else {
            return false
        }

        if let containers = value as? [String] {
            return containers.contains(identifier)
        }

        if let container = value as? String {
            return container == identifier
        }

        return false
    }

    var isAvailable: Bool {
        privateDatabase != nil && zoneId != nil
    }

    func setSyncing(_ syncing: Bool, completion: (() -> Void)? = nil) {
        syncQueue.async(flags: .barrier) { [weak self] in
            self?.isSyncing = syncing
            completion?()
        }
    }

    // MARK: - Save Token

    func saveToken(_ token: CKServerChangeToken?) {
        guard isAvailable else { return }
        guard let token = token else { return }
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: changeTokenKey)
        }
    }

    func loadToken() -> CKServerChangeToken? {
        guard isAvailable else { return nil }
        guard let data = UserDefaults.standard.data(forKey: changeTokenKey) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
    }

    func resetToken() {
        UserDefaults.standard.removeObject(forKey: changeTokenKey)
        UserDefaults.standard.removeObject(forKey: "CloudKitSyncManager_InitialUploadDone")
        setSyncing(false)
    }

    // MARK: - Core Operations

    func upload(records: [CKRecord], completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard isAvailable, let privateDatabase else {
            completion?(.success(()))
            return
        }

        guard !records.isEmpty else {
            completion?(.success(()))
            return
        }

        let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        operation.savePolicy = .changedKeys

        operation.modifyRecordsResultBlock = { result in
            completion?(result)
        }

        operation.database = privateDatabase
        operation.qualityOfService = .userInitiated
        operationQueue.addOperation(operation)
    }

    func delete(recordIds: [CKRecord.ID], completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard isAvailable, let privateDatabase else {
            completion?(.success(()))
            return
        }

        guard !recordIds.isEmpty else {
            completion?(.success(()))
            return
        }

        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIds)
        operation.modifyRecordsResultBlock = { result in
            completion?(result)
        }

        operation.database = privateDatabase
        operation.qualityOfService = .userInitiated
        operationQueue.addOperation(operation)
    }

    func fetchChanges(
        previousToken: CKServerChangeToken?,
        recordChanged: @escaping (CKRecord) -> Void,
        recordDeleted: @escaping (CKRecord.ID) -> Void,
        completion: @escaping (Result<(CKServerChangeToken?, Bool), Error>) -> Void
    ) {
        guard isAvailable, let privateDatabase, let zoneId else {
            completion(.success((previousToken, false)))
            return
        }

        let options = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        options.previousServerChangeToken = previousToken

        let operation = CKFetchRecordZoneChangesOperation(
            recordZoneIDs: [zoneId],
            configurationsByRecordZoneID: [zoneId: options]
        )

        var finalToken: CKServerChangeToken?
        var moreComing = false

        operation.recordWasChangedBlock = { _, recordResult in
            if let record = try? recordResult.get() {
                recordChanged(record)
            }
        }

        operation.recordWithIDWasDeletedBlock = { recordId, _ in
            recordDeleted(recordId)
        }

        operation.recordZoneFetchResultBlock = { _, result in
            switch result {
            case .success(let successData):
                finalToken = successData.serverChangeToken
                moreComing = successData.moreComing
            case .failure:
                break
            }
        }

        operation.fetchRecordZoneChangesResultBlock = { result in
            switch result {
            case .success:
                completion(.success((finalToken, moreComing)))
            case .failure(let error):
                completion(.failure(error))
            }
        }

        operation.database = privateDatabase
        operation.qualityOfService = .userInitiated
        operationQueue.addOperation(operation)
    }
}
