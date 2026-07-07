import Foundation
import SQLite3

final class OtzariaSQLiteConnection: @unchecked Sendable {
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.goldcreative.otsaria.sqlite", qos: .userInitiated)

    private init(db: OpaquePointer) {
        self.db = db
    }

    deinit {
        close()
    }

    static func openReadOnly(url: URL) throws -> OtzariaSQLiteConnection {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw OtzariaSQLiteError.openFailed(
                message: "הקובץ לא נמצא במכשיר. אם הוא ב-iCloud, פתח אותו פעם אחת באפליקציית Files כדי שיורד למכשיר.",
                code: SQLITE_CANTOPEN
            )
        }

        var opened: OpaquePointer?
        let sqliteURI = url.absoluteString + "?mode=ro&immutable=1"
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_URI
        let result = sqlite3_open_v2(sqliteURI, &opened, flags, nil)

        guard result == SQLITE_OK, let opened else {
            let message = otzariaSQLiteMessage(opened)
            if let opened { sqlite3_close(opened) }
            throw OtzariaSQLiteError.openFailed(message: message, code: result)
        }

        sqlite3_extended_result_codes(opened, 1)
        sqlite3_exec(opened, "PRAGMA query_only=ON;", nil, nil, nil)
        sqlite3_exec(opened, "PRAGMA foreign_keys=ON;", nil, nil, nil)

        return OtzariaSQLiteConnection(db: opened)
    }

    func read<T>(_ work: @escaping (OpaquePointer) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self, let db = self.db else {
                    continuation.resume(throwing: OtzariaSQLiteError.databaseClosed)
                    return
                }

                do {
                    continuation.resume(returning: try work(db))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func close() {
        queue.sync {
            if let db {
                sqlite3_close(db)
                self.db = nil
            }
        }
    }
}
