import Foundation
import HanlinMiniAppsBridge

/// The result ID is committed with the host's edit. A crash between commit and
/// transport acknowledgement therefore replays the receipt, never the edit.
enum OtzariaMiniAppsReceiptJournal {
    struct Commit<Value> {
        let value: Value
        let replayed: Bool
    }

    static func commit<Value>(requestID: UUID, resultJSON: String, documentID: String,
                              database: SQLiteDatabase, validate: () throws -> Void,
                              read: (Int64) throws -> Value?,
                              apply: () throws -> (id: Int64, value: Value)) throws -> Commit<Value> {
        var committed: Commit<Value>?
        try database.transaction {
            try validate()
            try database.execute(query: """
                CREATE TABLE IF NOT EXISTS miniapps_result_receipts (
                    request_id TEXT PRIMARY KEY, result_json TEXT NOT NULL,
                    annotation_id INTEGER NOT NULL, annotation_uuid TEXT NOT NULL
                );
                """)
            let prior = try database.fetch(query: """
                SELECT result_json, annotation_id, annotation_uuid FROM miniapps_result_receipts WHERE request_id = ?;
                """, parameters: [requestID.uuidString]) {
                    ($0.string(at: 0) ?? "", $0.int64(at: 1), $0.string(at: 2) ?? "")
                }.first
            if let prior {
                guard prior.0 == resultJSON, prior.2 == documentID,
                      let value = try read(prior.1) else { throw MiniAppBridgeError.conflictingResult }
                try validate()
                committed = .init(value: value, replayed: true)
                return
            }
            let saved = try apply()
            try database.execute(query: """
                INSERT INTO miniapps_result_receipts (request_id, result_json, annotation_id, annotation_uuid)
                VALUES (?, ?, ?, ?);
                """, parameters: [requestID.uuidString, resultJSON, saved.id, documentID])
            try validate()
            committed = .init(value: saved.value, replayed: false)
        }
        // There must be no new throwing cancellation/ownership check after COMMIT.
        guard let committed else { throw MiniAppBridgeError.missingRequest }
        return committed
    }
}
