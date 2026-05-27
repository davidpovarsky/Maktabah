//
//  HistorySyncHandler.swift
//  Maktabah
//

import CloudKit
import Foundation

final class HistorySyncHandler: CloudKitRecordParser {
    typealias Model = ReadingEntry

    static let shared = HistorySyncHandler()
    static let recordType = "ReadingEntry"

    private init() {}

    static func parse(from record: CKRecord) -> ReadingEntry? {
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
}

extension ReadingEntry: CloudKitSyncable {
    func toCKRecord(zoneID: CKRecordZone.ID) -> CKRecord? {
        guard let ckRecordIdStr = self.ckRecordId else { return nil }
        let recordId = CKRecord.ID(recordName: ckRecordIdStr, zoneID: zoneID)
        let record = CKRecord(recordType: HistorySyncHandler.recordType, recordID: recordId)

        record["bookId"] = self.bookId
        record["lastContentId"] = self.lastContentId
        record["lastOpenedAt"] = self.lastOpenedAt
        record["favoritedAt"] = self.favoritedAt
        record["positionUpdatedAt"] = self.positionUpdatedAt
        record["isFavorite"] = self.isFavorite
        record["lastModified"] = Int64(self.updatedAt.timeIntervalSince1970)

        return record
    }
}
