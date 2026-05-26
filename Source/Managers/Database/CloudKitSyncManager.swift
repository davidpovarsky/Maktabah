//
//  CloudKitSyncManager.swift
//  Maktabah
//

import CloudKit
import Foundation

final class CloudKitSyncManager {
    static let shared = CloudKitSyncManager()

    enum SyncTarget {
        case annotation
        case result
        case history
    }

    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let zoneId: CKRecordZone.ID

    private let changeTokenKey = "CKServerChangeToken_AnnotationsZone"
    private let pendingUploadsKey = "CloudKitSyncManager_PendingUploads"
    private let pendingDeletesKey = "CloudKitSyncManager_PendingDeletes"
    private var isSyncing = false
    private let syncQueue = DispatchQueue(label: "com.maktabah.cloudkitsync", attributes: .concurrent)

    private let recordType = "Annotation"
    private var accountChangeObserver: NSObjectProtocol?

    private init() {
        container = CKContainer(identifier: "iCloud.Maktabah")
        privateDatabase = container.privateCloudDatabase
        zoneId = CKRecordZone.ID(zoneName: "AnnotationsZone", ownerName: CKCurrentUserDefaultName)

        setupAccountChangeObserver()
    }

    private func addPendingUploads(_ ids: [String], target: SyncTarget) {
        syncQueue.async(flags: .barrier) {
            for id in ids {
                switch target {
                case .annotation:
                    AnnotationManager.shared.addPendingSync(ckRecordId: id, operation: "upload")
                case .result:
                    ResultsHandler.shared.addPendingSync(ckRecordId: id, operation: "upload")
                case .history:
                    HistoryViewModel.shared.addPendingSync(ckRecordId: id, operation: "upload")
                }
            }
        }
    }

    private func removePendingUploads(_ ids: [String]) {
        syncQueue.async(flags: .barrier) {
            AnnotationManager.shared.removePendingSync(ckRecordIds: ids)
            ResultsHandler.shared.removePendingSync(ckRecordIds: ids)
            HistoryViewModel.shared.removePendingSync(ckRecordIds: ids)
        }
    }

    private func addPendingDeletes(_ ids: [String], target: SyncTarget) {
        syncQueue.async(flags: .barrier) {
            for id in ids {
                switch target {
                case .annotation:
                    AnnotationManager.shared.addPendingSync(ckRecordId: id, operation: "delete")
                case .result:
                    ResultsHandler.shared.addPendingSync(ckRecordId: id, operation: "delete")
                case .history:
                    HistoryViewModel.shared.addPendingSync(ckRecordId: id, operation: "delete")
                }
            }
        }
    }

    private func removePendingDeletes(_ ids: [String]) {
        syncQueue.async(flags: .barrier) {
            AnnotationManager.shared.removePendingSync(ckRecordIds: ids)
            ResultsHandler.shared.removePendingSync(ckRecordIds: ids)
            HistoryViewModel.shared.removePendingSync(ckRecordIds: ids)
        }
    }

    private func retryPendingUploads() {
        let annPending = AnnotationManager.shared.fetchPendingSync(operation: "upload")
        let resPending = ResultsHandler.shared.fetchPendingSync(operation: "upload")
        let histPending = HistoryViewModel.shared.fetchPendingSync(operation: "upload")
        
        guard !annPending.isEmpty || !resPending.isEmpty || !histPending.isEmpty else { return }
        
        if !annPending.isEmpty {
            let allAnnotations = AnnotationManager.shared.loadAnnotations()
            let toUploadAnn = allAnnotations.filter { ann in
                guard let ckId = ann.ckRecordId else { return false }
                return annPending.contains(ckId)
            }
            if !toUploadAnn.isEmpty {
                #if DEBUG
                print("CloudKitSyncManager: Retrying \(toUploadAnn.count) pending annotation uploads...")
                #endif
                upload(annotations: toUploadAnn)
            }
        }
        
        if !resPending.isEmpty {
            let allFolders = ResultsHandler.shared.fetchAllSyncFolders()
            let toUploadFolders = allFolders.filter { f in
                guard let ckId = f.ckRecordId else { return false }
                return resPending.contains(ckId)
            }
            
            let allResults = ResultsHandler.shared.fetchAllSyncResults()
            let toUploadResults = allResults.filter { r in
                guard let ckId = r.ckRecordId else { return false }
                return resPending.contains(ckId)
            }
            
            if !toUploadFolders.isEmpty || !toUploadResults.isEmpty {
                #if DEBUG
                print("CloudKitSyncManager: Retrying pending folder/result uploads...")
                #endif
                uploadResultsData(folders: toUploadFolders, results: toUploadResults)
            }
        }
        
        if !histPending.isEmpty {
            let allHist = HistoryViewModel.shared.getAllEntries()
            let toUploadHist = allHist.filter { entry in
                guard let ckId = entry.ckRecordId else { return false }
                return histPending.contains(ckId)
            }
            if !toUploadHist.isEmpty {
                #if DEBUG
                print("CloudKitSyncManager: Retrying \(toUploadHist.count) pending history uploads...")
                #endif
                uploadHistory(entries: toUploadHist)
            }
        }
    }

    private func retryPendingDeletes() {
        let annPending = AnnotationManager.shared.fetchPendingSync(operation: "delete")
        let resPending = ResultsHandler.shared.fetchPendingSync(operation: "delete")
        let histPending = HistoryViewModel.shared.fetchPendingSync(operation: "delete")
        let pending = annPending + resPending + histPending
        
        guard !pending.isEmpty else { return }

        #if DEBUG
        print("CloudKitSyncManager: Retrying \(pending.count) pending deletes...")
        #endif
        delete(ckRecordIds: pending, trackPending: false)
    }

    private func setupAccountChangeObserver() {
        accountChangeObserver = NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resetChangeToken()
        }
    }

    func setupAndInitialSync() {
        initializeOnLaunch()
    }

    func initializeOnLaunch() {
        guard AppConfig.useICloud else { return }

        // Identity Lock: Cek apakah user berubah sejak terakhir kali sinkron
        checkUserIdentityChange()

        resetSyncingKey(syncing: false)

        let customZone = CKRecordZone(zoneID: zoneId)
        let operation = CKModifyRecordZonesOperation(recordZonesToSave: [customZone], recordZoneIDsToDelete: nil)

        operation.modifyRecordZonesResultBlock = { [weak self] result in
            switch result {
            case .success:
                #if DEBUG
                self?.ensureSchema()
                #endif
                self?.fetchChanges()
                self?.subscribeToChanges()

                // Check for backfill and initial upload
                self?.performInitialUploadCheck()
                
                // Retry any previously failed uploads
                self?.retryPendingUploads()
                self?.retryPendingDeletes()

            case .failure(let error):
                #if DEBUG
                print("CloudKitSyncManager: Error creating custom zone: \(error)")
                #endif
            }
        }
        operation.qualityOfService = .userInitiated
        privateDatabase.add(operation)
    }

    private func performInitialUploadCheck() {
        // 1. Backfill Annotations
        if let _ = AnnotationManager.shared.db {
            try? AnnotationManager.shared.backfillCloudKitFieldsIfNeeded { backfilled in
                if !backfilled.isEmpty {
                    #if DEBUG
                    print("CloudKitSyncManager: Backfilled \(backfilled.count) annotations, uploading...")
                    #endif
                    self.upload(annotations: backfilled)
                }
            }
        }

        // 2. Backfill Results
        if let _ = ResultsHandler.shared.db {
            try? ResultsHandler.shared.backfillResultsCloudKitFieldsIfNeeded()
        }

        // 3. Backfill History
        HistoryViewModel.shared.backfillCloudKitFieldsIfNeeded { backfilled in
            if !backfilled.isEmpty {
                #if DEBUG
                print("CloudKitSyncManager: Backfilled \(backfilled.count) history entries, uploading...")
                #endif
                self.uploadHistory(entries: backfilled)
            }
        }

        // 4. Initial Upload
        if !UserDefaults.standard.bool(forKey: "CloudKitSyncManager_InitialUploadDone") {
            #if DEBUG
            print("CloudKitSyncManager: Performing initial upload of all data...")
            #endif
            uploadAllLocalData { success in
                if success {
                    UserDefaults.standard.set(true, forKey: "CloudKitSyncManager_InitialUploadDone")
                }
            }
        }
    }

    private func uploadAllLocalData(completion: @escaping (Bool) -> Void) {
        let group = DispatchGroup()
        var hasError = false
        let batchSize = 200

        // 1. Upload Annotations
        let allAnnotations = AnnotationManager.shared.loadAnnotations()
        for i in stride(from: 0, to: allAnnotations.count, by: batchSize) {
            let endIndex = min(i + batchSize, allAnnotations.count)
            let batch = Array(allAnnotations[i ..< endIndex])
            group.enter()
            upload(annotations: batch) { result in
                if case .failure = result { hasError = true }
                group.leave()
            }
        }

        // 2. Upload Folders & Results
        let allFolders = ResultsHandler.shared.fetchAllSyncFolders()
        for i in stride(from: 0, to: allFolders.count, by: batchSize) {
            let endIndex = min(i + batchSize, allFolders.count)
            group.enter()
            uploadResultsData(folders: Array(allFolders[i ..< endIndex]), results: []) { result in
                if case .failure = result { hasError = true }
                group.leave()
            }
        }

        let allResults = ResultsHandler.shared.fetchAllSyncResults()
        for i in stride(from: 0, to: allResults.count, by: batchSize) {
            let endIndex = min(i + batchSize, allResults.count)
            group.enter()
            uploadResultsData(folders: [], results: Array(allResults[i ..< endIndex])) { result in
                if case .failure = result { hasError = true }
                group.leave()
            }
        }
        
        // 3. Upload History
        let allHistory = HistoryViewModel.shared.getAllEntries()
        for i in stride(from: 0, to: allHistory.count, by: batchSize) {
            let endIndex = min(i + batchSize, allHistory.count)
            group.enter()
            uploadHistory(entries: Array(allHistory[i ..< endIndex])) { result in
                if case .failure = result { hasError = true }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(!hasError)
        }
    }

    // MARK: - Upload (Insert/Update)

    func upload(annotations: [Annotation], completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard AppConfig.useICloud else {
            completion?(.success(()))
            return
        }

        let recordsToSave = annotations.compactMap { ann -> CKRecord? in
            guard let ckRecordIdStr = ann.ckRecordId else { return nil }
            let recordId = CKRecord.ID(recordName: ckRecordIdStr, zoneID: zoneId)
            let record = CKRecord(recordType: recordType, recordID: recordId)

            record["bkId"] = ann.bkId
            record["contentId"] = ann.contentId
            record["rangeLocation"] = ann.range.location
            record["rangeLength"] = ann.range.length
            record["rangeDiacLocation"] = ann.rangeDiacritics.location
            record["rangeDiacLength"] = ann.rangeDiacritics.length
            record["colorHex"] = ann.colorHex
            record["type"] = ann.type.rawValue
            record["note"] = ann.note
            record["createdAt"] = ann.createdAt
            record["context"] = ann.context
            record["page"] = ann.page
            record["part"] = ann.part
            record["lastModified"] = ann.lastModified ?? Int64(Date().timeIntervalSince1970)
            record["tags"] = ann.tags

            return record
        }

        guard !recordsToSave.isEmpty else {
            completion?(.success(()))
            return
        }

        let operation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: nil)
        operation.savePolicy = .changedKeys
        
        let recordIdsStrings = recordsToSave.map { $0.recordID.recordName }
        addPendingUploads(recordIdsStrings, target: .annotation)

        operation.modifyRecordsResultBlock = { [weak self] result in
            #if DEBUG
            switch result {
            case .success:
                print("CloudKitSyncManager: Berhasil upload \(recordsToSave.count) records.")
                self?.removePendingUploads(recordIdsStrings)
                completion?(.success(()))
            case .failure(let error):
                print("CloudKitSyncManager: Gagal upload. Error: \(error.localizedDescription)")
                if let ckError = error as? CKError {
                    print("Detail CKError: code=\(ckError.code.rawValue), info=\(ckError.userInfo)")
                }
                self?.handleUploadFailure(error, pendingRecordIds: recordIdsStrings, completion: completion)
            }
            #else
            if case .success = result {
                self?.removePendingUploads(recordIdsStrings)
                completion?(.success(()))
            } else if case .failure(let error) = result {
                self?.handleUploadFailure(error, pendingRecordIds: recordIdsStrings, completion: completion)
            }
            #endif
        }
        operation.qualityOfService = .userInitiated
        privateDatabase.add(operation)
    }

    func uploadResultsData(folders: [SyncFolder], results: [SyncResult], completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard AppConfig.useICloud else {
            completion?(.success(()))
            return
        }

        var recordsToSave: [CKRecord] = []

        for f in folders {
            guard let ckId = f.ckRecordId else { continue }
            let record = CKRecord(recordType: "SearchFolder", recordID: CKRecord.ID(recordName: ckId, zoneID: zoneId))
            record["name"] = f.name
            record["lastModified"] = f.lastModified ?? Int64(Date().timeIntervalSince1970)
            record["parentCkRecordId"] = f.parentCkRecordId
            recordsToSave.append(record)
        }

        for r in results {
            guard let ckId = r.ckRecordId else { continue }
            let record = CKRecord(recordType: "SearchResult", recordID: CKRecord.ID(recordName: ckId, zoneID: zoneId))
            record["name"] = r.name
            record["query"] = r.query
            record["archive"] = r.archive
            record["bkId"] = r.bkId
            record["contentId"] = r.contentId
            record["lastModified"] = r.lastModified ?? Int64(Date().timeIntervalSince1970)
            record["folderCkRecordId"] = r.folderCkRecordId
            recordsToSave.append(record)
        }

        guard !recordsToSave.isEmpty else {
            completion?(.success(()))
            return
        }

        let operation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: nil)
        operation.savePolicy = .changedKeys
        
        let recordIdsStrings = recordsToSave.map { $0.recordID.recordName }
        addPendingUploads(recordIdsStrings, target: .result)

        operation.modifyRecordsResultBlock = { [weak self] result in
            #if DEBUG
            switch result {
            case .success:
                print("CloudKitSyncManager: Berhasil upload \(recordsToSave.count) data pencarian.")
                self?.removePendingUploads(recordIdsStrings)
                completion?(.success(()))
            case .failure(let error):
                print("CloudKitSyncManager: Gagal upload data pencarian: \(error.localizedDescription)")
                if let ckError = error as? CKError {
                    print("Detail CKError: code=\(ckError.code.rawValue), info=\(ckError.userInfo)")
                }
                self?.handleUploadFailure(error, pendingRecordIds: recordIdsStrings, completion: completion)
            }
            #else
            if case .success = result {
                self?.removePendingUploads(recordIdsStrings)
                completion?(.success(()))
            } else if case .failure(let error) = result {
                self?.handleUploadFailure(error, pendingRecordIds: recordIdsStrings, completion: completion)
            }
            #endif
        }
        operation.qualityOfService = .userInitiated
        privateDatabase.add(operation)
    }

    func uploadHistory(entries: [ReadingEntry], completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard AppConfig.useICloud else {
            completion?(.success(()))
            return
        }

        let recordsToSave = entries.compactMap { entry -> CKRecord? in
            guard let ckRecordIdStr = entry.ckRecordId else { return nil }
            let recordId = CKRecord.ID(recordName: ckRecordIdStr, zoneID: zoneId)
            let record = CKRecord(recordType: "ReadingEntry", recordID: recordId)

            record["bookId"] = entry.bookId
            record["lastContentId"] = entry.lastContentId
            record["lastOpenedAt"] = entry.lastOpenedAt
            record["favoritedAt"] = entry.favoritedAt
            record["positionUpdatedAt"] = entry.positionUpdatedAt
            record["isFavorite"] = entry.isFavorite
            record["lastModified"] = Int64(entry.updatedAt.timeIntervalSince1970)

            return record
        }

        guard !recordsToSave.isEmpty else {
            completion?(.success(()))
            return
        }

        let operation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: nil)
        operation.savePolicy = .changedKeys
        
        let recordIdsStrings = recordsToSave.map { $0.recordID.recordName }
        addPendingUploads(recordIdsStrings, target: .history)

        operation.modifyRecordsResultBlock = { [weak self] result in
            #if DEBUG
            switch result {
            case .success:
                print("CloudKitSyncManager: Berhasil upload \(recordsToSave.count) data history.")
                self?.removePendingUploads(recordIdsStrings)
                completion?(.success(()))
            case .failure(let error):
                print("CloudKitSyncManager: Gagal upload data history: \(error.localizedDescription)")
                self?.handleUploadFailure(error, pendingRecordIds: recordIdsStrings, completion: completion)
            }
            #else
            if case .success = result {
                self?.removePendingUploads(recordIdsStrings)
                completion?(.success(()))
            } else if case .failure(let error) = result {
                self?.handleUploadFailure(error, pendingRecordIds: recordIdsStrings, completion: completion)
            }
            #endif
        }
        operation.qualityOfService = .userInitiated
        privateDatabase.add(operation)
    }

    // MARK: - Delete

    func delete(ckRecordIds: [String], target: SyncTarget? = nil, trackPending: Bool = true) {
        guard AppConfig.useICloud else { return }
        if trackPending, let target = target {
            addPendingDeletes(ckRecordIds, target: target)
        }

        let recordIdsToDelete = ckRecordIds.map { CKRecord.ID(recordName: $0, zoneID: zoneId) }
        guard !recordIdsToDelete.isEmpty else { return }

        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIdsToDelete)
        operation.modifyRecordsResultBlock = { [weak self] result in
            switch result {
            case .success:
                self?.removePendingDeletes(ckRecordIds)
                #if DEBUG
                print("CloudKitSyncManager: Successfully deleted \(recordIdsToDelete.count) records.")
                #endif
            case .failure(let error):
                #if DEBUG
                print("CloudKitSyncManager: Failed to delete records: \(error.localizedDescription)")
                #endif
                self?.handleCloudKitError(error, operationType: .delete)
            }
        }
        operation.qualityOfService = .userInitiated
        privateDatabase.add(operation)
    }

    #if DEBUG
    private func ensureSchema() {
        // Buat satu dummy record untuk inisialisasi schema
        let dummyId = CKRecord.ID(recordName: "schema-init-dummy", zoneID: zoneId)

        // Cek dulu apakah sudah ada
        privateDatabase.fetch(withRecordID: dummyId) { [weak self] record, error in
            if record != nil {
                print("Schema sudah terinisialisasi")
                return
            }

            // Belum ada, buat dummy untuk inisialisasi schema
            let dummy = CKRecord(recordType: "Annotation", recordID: dummyId)
            dummy["bkId"] = -1
            dummy["contentId"] = -1
            dummy["rangeLocation"] = -1
            dummy["rangeLength"] = -1
            dummy["rangeDiacLocation"] = -1
            dummy["rangeDiacLength"] = -1
            dummy["colorHex"] = "schema-init"
            dummy["type"] = -1
            dummy["createdAt"] = Int64(-1)
            dummy["context"] = "schema-init"
            dummy["page"] = -1
            dummy["part"] = -1
            dummy["lastModified"] = Int64(-1)
            dummy["tags"] = ["Init"]

            self?.privateDatabase.save(dummy) { _, error in
                if let error = error {
                    print("Schema init gagal: \(error.localizedDescription)")
                } else {
                    print("Schema berhasil diinisialisasi")
                    // Hapus dummy setelah schema terdaftar
                    self?.privateDatabase.delete(withRecordID: dummyId) { _, _ in
                        print("Dummy record dihapus")
                    }
                }
            }
        }
    }
    #endif

    // MARK: - Fetch Changes (Delta)

    func fetchChanges(retryCount: Int = 0) {
        guard AppConfig.useICloud else { return }

        // Prevent concurrent syncs
        var shouldProceed = false
        syncQueue.sync {
            if !isSyncing {
                isSyncing = true
                shouldProceed = true
            }
        }
        guard shouldProceed else { return }

        var previousToken: CKServerChangeToken?

        if let data = UserDefaults.standard.data(forKey: changeTokenKey) {
            previousToken = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
        }

        let fetchStateQueue = DispatchQueue(label: "com.maktabah.cloudkitsync.fetch-state")
        var changedRecords: [CKRecord] = []
        var deletedRecordIds: [CKRecord.ID] = []
        var finalToken: CKServerChangeToken?
        var moreComing = false

        let options = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        options.previousServerChangeToken = previousToken

        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zoneId], configurationsByRecordZoneID: [zoneId: options])

        operation.recordWasChangedBlock = { _, recordResult in
            if let record = try? recordResult.get() {
                fetchStateQueue.sync {
                    changedRecords.append(record)
                }
            }
        }

        operation.recordWithIDWasDeletedBlock = { recordId, _ in
            fetchStateQueue.sync {
                deletedRecordIds.append(recordId)
            }
        }

        operation.recordZoneFetchResultBlock = { _, result in
            switch result {
            case .success(let successData):
                fetchStateQueue.sync {
                    finalToken = successData.serverChangeToken
                    moreComing = successData.moreComing
                }
            case .failure(let error):
                print("CloudKitSyncManager: Error fetching zone changes: \(error)")
            }
        }

        operation.fetchRecordZoneChangesResultBlock = { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success:
                let snapshot = fetchStateQueue.sync {
                    (
                        changedRecords: changedRecords,
                        deletedRecordIds: deletedRecordIds,
                        finalToken: finalToken,
                        moreComing: moreComing
                    )
                }

                if !snapshot.changedRecords.isEmpty || !snapshot.deletedRecordIds.isEmpty {
                    self.applyChangesLocally(recordsToSave: snapshot.changedRecords, recordIDsToDelete: snapshot.deletedRecordIds)
                }

                // Only save token after applying changes locally
                if let token = snapshot.finalToken {
                    self.saveToken(token)
                }

                self.resetSyncingKey(syncing: false) {
                    if snapshot.moreComing {
                        self.fetchChanges(retryCount: 0)
                    }
                }
            case .failure(let error):
                self.handleCloudKitError(error, operationType: .fetchChanges, retryCount: retryCount)
                self.resetSyncingKey(syncing: false)
            }
        }

        operation.qualityOfService = .userInitiated
        privateDatabase.add(operation)
    }

    // MARK: - Error Handling

    private enum CKOperationType {
        case fetchChanges, upload, delete, subscribe
    }

    private func resolveServerRecordConflict(
        ckError: CKError,
        pendingRecordIds: [String] = [],
        completion: ((Result<Void, Error>) -> Void)? = nil
    ) {
        #if DEBUG
        print("CloudKitSyncManager: Server record changed. Resolving conflict...")
        #endif

        guard let serverRecord = ckError.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord,
              let localRecord = ckError.userInfo[CKRecordChangedErrorClientRecordKey] as? CKRecord else {
            completion?(.failure(ckError))
            return
        }

        let recordId = localRecord.recordID.recordName
        let serverLastModified = serverRecord["lastModified"] as? Int64 ?? 0
        let localLastModified = localRecord["lastModified"] as? Int64 ?? 0

        if localLastModified >= serverLastModified {
            // Overwrite must reuse the server record so the latest change tag is preserved.
            for key in localRecord.allKeys() {
                serverRecord[key] = localRecord[key]
            }

            let operation = CKModifyRecordsOperation(recordsToSave: [serverRecord], recordIDsToDelete: nil)
            operation.savePolicy = .allKeys
            operation.qualityOfService = .userInitiated
            operation.modifyRecordsResultBlock = { [weak self] result in
                switch result {
                case .success:
                    self?.removePendingUploads([recordId])
                    completion?(.success(()))
                case .failure(let error):
                    completion?(.failure(error))
                }
            }
            privateDatabase.add(operation)
        } else {
            applyChangesLocally(recordsToSave: [serverRecord], recordIDsToDelete: [])
            removePendingUploads([recordId])
            completion?(.success(()))
        }
    }

    private func handleUploadFailure(
        _ error: Error,
        pendingRecordIds: [String],
        completion: ((Result<Void, Error>) -> Void)? = nil
    ) {
        guard let ckError = error as? CKError else {
            completion?(.failure(error))
            return
        }

        switch ckError.code {
        case .serverRecordChanged:
            resolveServerRecordConflict(
                ckError: ckError,
                pendingRecordIds: pendingRecordIds,
                completion: completion
            )
        case .partialFailure:
            if let partialErrors = ckError.userInfo[CKPartialErrorsByItemIDKey] as? [CKRecord.ID: Error] {
                let conflicts = partialErrors.values.compactMap { $0 as? CKError }.filter { $0.code == .serverRecordChanged }
                
                if !conflicts.isEmpty {
                    let group = DispatchGroup()
                    var lastError: Error?
                    
                    for conflict in conflicts {
                        group.enter()
                        resolveServerRecordConflict(ckError: conflict) { result in
                            if case .failure(let error) = result {
                                lastError = error
                            }
                            group.leave()
                        }
                    }
                    
                    group.notify(queue: syncQueue) {
                        if let error = lastError {
                            completion?(.failure(error))
                        } else {
                            completion?(.success(()))
                        }
                    }
                } else {
                    completion?(.failure(error))
                }
            } else {
                completion?(.failure(error))
            }
        case .quotaExceeded:
            #if DEBUG
            print("CloudKitSyncManager: Quota exceeded. Sync paused.")
            #endif
            completion?(.failure(error))
        default:
            completion?(.failure(error))
        }
    }

    private func handleCloudKitError(_ error: Error, operationType: CKOperationType, retryCount: Int = 0) {
        guard let ckError = error as? CKError else {
            #if DEBUG
            print("CloudKitSyncManager: Non-CKError occurred: \(error.localizedDescription)")
            #endif
            return
        }

        switch ckError.code {
        case .changeTokenExpired:
            #if DEBUG
            print("CloudKitSyncManager: Token expired. Resetting and re-fetching...")
            #endif
            resetChangeToken()

        case .serviceUnavailable, .requestRateLimited, .zoneBusy:
            let baseDelay = ckError.retryAfterSeconds ?? 3.0
            let retryDelay = baseDelay * pow(2.0, Double(retryCount))
            #if DEBUG
            print("CloudKitSyncManager: Server busy/unavailable. Retrying in \(retryDelay)s (retry \(retryCount + 1))...")
            #endif
            if retryCount < 5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) {
                    switch operationType {
                    case .fetchChanges: self.fetchChanges(retryCount: retryCount + 1)
                    case .delete: self.retryPendingDeletes()
                    default: break // Simple operations might be retried by the system or user trigger
                    }
                }
            }

        case .zoneNotFound:
            #if DEBUG
            print("CloudKitSyncManager: Zone not found. Re-initializing...")
            #endif
            initializeOnLaunch()

        case .serverRecordChanged:
            resolveServerRecordConflict(ckError: ckError)

        case .partialFailure:
            #if DEBUG
            print("CloudKitSyncManager: Partial failure occurred.")
            if let partialErrors = ckError.userInfo[CKPartialErrorsByItemIDKey] as? [NSObject: Error] {
                for (id, error) in partialErrors {
                    print("   - Item \(id) failed: \(error.localizedDescription)")
                }
            }
            #endif

        case .notAuthenticated:
            #if DEBUG
            print("CloudKitSyncManager: User not authenticated. Sync disabled.")
            #endif
            DispatchQueue.main.async {
                ReusableFunc.showAlert(
                    title: "iCloud Error",
                    message: ckError.localizedDescription
                )
            }

        case .networkUnavailable, .networkFailure:
            #if DEBUG
            print("CloudKitSyncManager: Network issues. Sync will resume when online.")
            #endif

        default:
            #if DEBUG
            print("CloudKitSyncManager: Unhandled error (\(ckError.code.rawValue)): \(ckError.localizedDescription)")
            #endif
        }
    }

    func resetSyncingKey(syncing: Bool, completion: (() -> Void)? = nil) {
        syncQueue.async(flags: .barrier) { [weak self] in
            self?.isSyncing = syncing
            completion?()
        }
    }

    private func saveToken(_ token: CKServerChangeToken?) {
        guard let token = token else { return }
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: changeTokenKey)
        }
    }

    private func checkUserIdentityChange() {
        container.fetchUserRecordID { [weak self] recordID, _ in
            guard let self = self, let currentID = recordID?.recordName else { return }

            let lastID = UserDefaults.standard.string(forKey: "CloudKitSyncManager_LastUserRecordID")

            if let lastID = lastID, lastID != currentID {
                self.resetChangeToken()
            }

            UserDefaults.standard.set(currentID, forKey: "CloudKitSyncManager_LastUserRecordID")
        }
    }

    private func applyChangesLocally(recordsToSave: [CKRecord], recordIDsToDelete: [CKRecord.ID]) {
        var annotations: [Annotation] = []
        var folders: [SyncFolder] = []
        var searchResults: [SyncResult] = []
        var historyEntries: [ReadingEntry] = []

        for record in recordsToSave {
            if record.recordType == recordType {
                if let ann = parseAnnotation(from: record) {
                    annotations.append(ann)
                }
            } else if record.recordType == "SearchFolder" {
                if let folder = parseSyncFolder(from: record) {
                    folders.append(folder)
                }
            } else if record.recordType == "SearchResult" {
                if let res = parseSyncResult(from: record) {
                    searchResults.append(res)
                }
            } else if record.recordType == "ReadingEntry" {
                if let entry = parseHistoryEntry(from: record) {
                    historyEntries.append(entry)
                }
            }
        }

        let idsToDelete = recordIDsToDelete.map { $0.recordName }

        if !annotations.isEmpty || !recordIDsToDelete.isEmpty {
            AnnotationManager.shared.applyCloudKitChanges(annotationsToSave: annotations, recordIdsToDelete: idsToDelete)
        }
        
        if !folders.isEmpty || !recordIDsToDelete.isEmpty {
            ResultsHandler.shared.applyCloudKitFolderChanges(foldersToSave: folders, recordIdsToDelete: idsToDelete)
        }

        if !searchResults.isEmpty || !recordIDsToDelete.isEmpty {
            ResultsHandler.shared.applyCloudKitResultChanges(resultsToSave: searchResults, recordIdsToDelete: idsToDelete)
        }
        
        if !historyEntries.isEmpty || !recordIDsToDelete.isEmpty {
            HistoryViewModel.shared.applyCloudKitChanges(entriesToSave: historyEntries, recordIdsToDelete: idsToDelete)
        }
    }

    private func parseAnnotation(from record: CKRecord) -> Annotation? {
        guard let bkId = record["bkId"] as? Int,
              bkId >= 0,
              let contentId = record["contentId"] as? Int,
              let rangeLocation = record["rangeLocation"] as? Int,
              let rangeLength = record["rangeLength"] as? Int,
              let rangeDiacLocation = record["rangeDiacLocation"] as? Int,
              let rangeDiacLength = record["rangeDiacLength"] as? Int,
              let colorHex = record["colorHex"] as? String,
              let typeRaw = record["type"] as? Int,
              let createdAt = record["createdAt"] as? Int64,
              let context = record["context"] as? String,
              let page = record["page"] as? Int,
              let part = record["part"] as? Int
        else {
            return nil
        }

        let tags = record["tags"] as? [String] ?? []
        let note = record["note"] as? String
        let lastModified = record["lastModified"] as? Int64

        return Annotation(
            id: nil,
            bkId: bkId,
            contentId: contentId,
            range: NSRange(location: rangeLocation, length: rangeLength),
            rangeDiacritics: NSRange(location: rangeDiacLocation, length: rangeDiacLength),
            colorHex: colorHex,
            type: AnnotationMode.from(int: typeRaw),
            note: note,
            createdAt: createdAt,
            context: context,
            page: page,
            part: part,
            pageArb: String(page).convertToArabicDigits(),
            partArb: String(part).convertToArabicDigits(),
            tags: tags,
            ckRecordId: record.recordID.recordName,
            lastModified: lastModified
        )
    }

    private func parseSyncFolder(from record: CKRecord) -> SyncFolder? {
        guard let name = record["name"] as? String else { return nil }
        return SyncFolder(
            id: nil,
            name: name,
            parent: nil,
            ckRecordId: record.recordID.recordName,
            lastModified: record["lastModified"] as? Int64,
            parentCkRecordId: record["parentCkRecordId"] as? String
        )
    }

    private func parseSyncResult(from record: CKRecord) -> SyncResult? {
        guard let name = record["name"] as? String,
              let query = record["query"] as? String,
              let archive = record["archive"] as? Int,
              let bkId = record["bkId"] as? Int,
              let contentId = record["contentId"] as? String
        else { return nil }

        return SyncResult(
            id: nil,
            folderId: nil,
            name: name,
            query: query,
            archive: archive,
            bkId: bkId,
            contentId: contentId,
            ckRecordId: record.recordID.recordName,
            lastModified: record["lastModified"] as? Int64,
            folderCkRecordId: record["folderCkRecordId"] as? String
        )
    }

    private func parseHistoryEntry(from record: CKRecord) -> ReadingEntry? {
        guard let bookId = record["bookId"] as? Int,
              let isFavorite = record["isFavorite"] as? Bool
        else { return nil }
        
        return ReadingEntry(
            bookId: bookId,
            lastContentId: record["lastContentId"] as? Int,
            lastOpenedAt: record["lastOpenedAt"] as? Date,
            favoritedAt: record["favoritedAt"] as? Date,
            positionUpdatedAt: record["positionUpdatedAt"] as? Date,
            updatedAt: Date(timeIntervalSince1970: TimeInterval(record["lastModified"] as? Int64 ?? 0)),
            isFavorite: isFavorite,
            ckRecordId: record.recordID.recordName
        )
    }

    // MARK: - Subscriptions

    private func subscribeToChanges() {
        let subscriptionId = "AnnotationsZoneSubscription"
        let subscription = CKRecordZoneSubscription(zoneID: zoneId, subscriptionID: subscriptionId)

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true // Silent push
        subscription.notificationInfo = notificationInfo

        let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: nil)
        operation.modifySubscriptionsResultBlock = { result in
            switch result {
            case .success:
                #if DEBUG
                print("CloudKitSyncManager: Subscribed to zone changes")
                #endif
            case .failure(let error):
                DispatchQueue.main.async {
                    ReusableFunc.showAlert(
                        title: "CloudKitSyncManager",
                        message: "Failed to subscribe: \(error.localizedDescription)"
                    )
                }
            }
        }
        operation.qualityOfService = .utility
        privateDatabase.add(operation)
    }

    func resetChangeToken() {
        AnnotationManager.shared.db?.checkpoint()
        ResultsHandler.shared.db?.checkpoint()

        UserDefaults.standard.removeObject(forKey: changeTokenKey)
        UserDefaults.standard.removeObject(forKey: "CloudKitSyncManager_InitialUploadDone")

        // Also clear syncing key to be safe
        resetSyncingKey(syncing: false)
        fetchChanges()
    }
}
