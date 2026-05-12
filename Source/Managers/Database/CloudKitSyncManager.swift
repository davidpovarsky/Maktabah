//
//  CloudKitSyncManager.swift
//  Maktabah
//

import CloudKit
import Foundation

final class CloudKitSyncManager {
    static let shared = CloudKitSyncManager()

    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let zoneId: CKRecordZone.ID

    private let changeTokenKey = "CKServerChangeToken_AnnotationsZone"
    private let isSyncingKey = "CloudKitSyncManager_IsSyncing"

    private let recordType = "Annotation"

    private init() {
        container = CKContainer(identifier: "iCloud.Maktabah")
        privateDatabase = container.privateCloudDatabase
        zoneId = CKRecordZone.ID(zoneName: "AnnotationsZone", ownerName: CKCurrentUserDefaultName)

        setupAccountChangeObserver()
    }

    private func setupAccountChangeObserver() {
        NotificationCenter.default.addObserver(
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
        if let db = AnnotationManager.shared.db {
            try? AnnotationManager.shared.backfillCloudKitFieldsIfNeeded(in: db) { backfilled in
                if !backfilled.isEmpty {
                    #if DEBUG
                    print("CloudKitSyncManager: Backfilled \(backfilled.count) annotations, uploading...")
                    #endif
                    self.upload(annotations: backfilled)
                }
            }
        }

        if !UserDefaults.standard.bool(forKey: "CloudKitSyncManager_InitialUploadDone") {
            print("CloudKitSyncManager: Performing initial upload of all data...")
            uploadAllLocalData()
            UserDefaults.standard.set(true, forKey: "CloudKitSyncManager_InitialUploadDone")
        }
    }

    private func uploadAllLocalData() {
        let allAnnotations = AnnotationManager.shared.loadAnnotations()
        let batchSize = 200
        for i in stride(from: 0, to: allAnnotations.count, by: batchSize) {
            let endIndex = min(i + batchSize, allAnnotations.count)
            let batch = Array(allAnnotations[i ..< endIndex])
            upload(annotations: batch)
        }
    }

    // MARK: - Upload (Insert/Update)

    func upload(annotations: [Annotation]) {
        guard AppConfig.useICloud else { return }

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

        guard !recordsToSave.isEmpty else { return }

        let operation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: nil)
        operation.savePolicy = .changedKeys
        operation.modifyRecordsResultBlock = { result in
            #if DEBUG
            switch result {
            case .success:
                print("CloudKitSyncManager: Berhasil upload \(recordsToSave.count) anotasi.")
            case .failure(let error):
                print("CloudKitSyncManager: Gagal upload. Error: \(error.localizedDescription)")
                if let ckError = error as? CKError {
                    print("Detail CKError: code=\(ckError.code.rawValue), info=\(ckError.userInfo)")
                }
            }
            #endif
        }
        operation.qualityOfService = .userInitiated
        privateDatabase.add(operation)
    }

    // MARK: - Delete

    func delete(ckRecordIds: [String]) {
        guard AppConfig.useICloud else { return }

        let recordIdsToDelete = ckRecordIds.map { CKRecord.ID(recordName: $0, zoneID: zoneId) }
        guard !recordIdsToDelete.isEmpty else { return }

        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIdsToDelete)
        #if DEBUG
        operation.modifyRecordsResultBlock = { result in
            switch result {
            case .success:
                print("CloudKitSyncManager: Successfully deleted \(recordIdsToDelete.count) records.")
            case .failure(let error):
                print("CloudKitSyncManager: Failed to delete records: \(error.localizedDescription)")
            }
        }
        #endif
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

    func fetchChanges() {
        guard AppConfig.useICloud else { return }

        // Prevent concurrent syncs
        if UserDefaults.standard.bool(forKey: isSyncingKey) { return }
        UserDefaults.standard.set(true, forKey: isSyncingKey)

        var previousToken: CKServerChangeToken?

        if let data = UserDefaults.standard.data(forKey: changeTokenKey) {
            previousToken = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
        }

        var changedRecords: [CKRecord] = []
        var deletedRecordIds: [CKRecord.ID] = []
        var finalToken: CKServerChangeToken?
        var moreComing = false

        let options = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        options.previousServerChangeToken = previousToken

        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zoneId], configurationsByRecordZoneID: [zoneId: options])

        operation.recordWasChangedBlock = { _, recordResult in
            if let record = try? recordResult.get() {
                changedRecords.append(record)
            }
        }

        operation.recordWithIDWasDeletedBlock = { recordId, _ in
            deletedRecordIds.append(recordId)
        }

        operation.recordZoneFetchResultBlock = { _, result in
            switch result {
            case .success(let successData):
                finalToken = successData.serverChangeToken
                moreComing = successData.moreComing
            case .failure(let error):
                print("CloudKitSyncManager: Error fetching zone changes: \(error)")
            }
        }

        operation.fetchRecordZoneChangesResultBlock = { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success:
                if !changedRecords.isEmpty || !deletedRecordIds.isEmpty {
                    self.applyChangesLocally(recordsToSave: changedRecords, recordIDsToDelete: deletedRecordIds)
                }

                // Only save token after applying changes locally
                if let token = finalToken {
                    self.saveToken(token)
                }

                self.resetSyncingKey(syncing: false)

                if moreComing {
                    self.fetchChanges()
                }
            case .failure(let error):
                #if DEBUG
                print("error saat fetch changes:", error.localizedDescription)
                #endif
                self.resetSyncingKey(syncing: false)
            }
        }

        operation.qualityOfService = .userInitiated
        privateDatabase.add(operation)
    }

    func resetSyncingKey(syncing: Bool) {
        UserDefaults.standard.set(syncing, forKey: isSyncingKey)
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

        for record in recordsToSave {
            if record.recordType == recordType {
                if let ann = parseAnnotation(from: record) {
                    annotations.append(ann)
                }
            }
        }

        let idsToDelete = recordIDsToDelete.map { $0.recordName }

        if !annotations.isEmpty || !recordIDsToDelete.isEmpty {
            AnnotationManager.shared.applyCloudKitChanges(annotationsToSave: annotations, recordIdsToDelete: idsToDelete)
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
                print("CloudKitSyncManager: Subscribed to zone changes")
            case .failure(let error):
                print("CloudKitSyncManager: Failed to subscribe: \(error.localizedDescription)")
            }
        }
        operation.qualityOfService = .utility
        privateDatabase.add(operation)
    }

    func resetChangeToken() {
        UserDefaults.standard.removeObject(forKey: changeTokenKey)
        UserDefaults.standard.removeObject(forKey: "CloudKitSyncManager_InitialUploadDone")
        print("Change token direset, fetch ulang dari awal")
        fetchChanges()
    }
}
