import Foundation
import HanlinMiniAppsBridge

@main
enum OtzariaMiniAppsReceiptChecks {
    static let requestID = UUID(uuidString: "796BC118-D81E-420E-987E-5660D7799338")!
    static func main() throws {
        if CommandLine.arguments.count == 3 {
            let database = try SQLiteDatabase(path: CommandLine.arguments[2])
            let result = try write(database: database, id: requestID, result: "first", text: "שלום")
            if CommandLine.arguments[1] == "write" {
                guard !result.replayed else { throw Failure() }
                print("COMMITTED_WITHOUT_TRANSPORT_ACK")
                return
            }
            guard result.replayed, result.value == "שלום", try count(database, table: "notes") == 1 else { throw Failure() }
            print("REPLAYED_WITHOUT_SECOND_EDIT")
            return
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("notes.sqlite").path
        let database = try SQLiteDatabase(path: path)
        try database.execute(query: "CREATE TABLE notes (id INTEGER PRIMARY KEY, text TEXT NOT NULL);")
        var passed = 0
        func check(_ value: @autoclosure () throws -> Bool, _ label: String) throws {
            guard try value() else { throw Failure() }
            passed += 1; print("PASS " + label)
        }
        let first = try write(database: database, id: requestID, result: "one", text: "עברית")
        try check(!first.replayed && first.value == "עברית"
            && count(database, table: "notes") == 1 && count(database, table: "miniapps_result_receipts") == 1,
            "edit_and_receipt_commit_in_original_sqlite_transaction")
        let replay = try write(database: database, id: requestID, result: "one", text: "must not replace")
        try check(replay.replayed && replay.value == "עברית" && count(database, table: "notes") == 1,
            "same_result_replay_does_not_run_edit")
        do {
            _ = try write(database: database, id: requestID, result: "conflict", text: "must not replace")
            throw Failure()
        } catch MiniAppBridgeError.conflictingResult {
            try check(count(database, table: "notes") == 1, "conflicting_callback_preserves_original_edit")
        }
        var validations = 0
        do {
            _ = try OtzariaMiniAppsReceiptJournal.commit(requestID: UUID(), resultJSON: "retired",
                documentID: "note", database: database, validate: {
                    validations += 1
                    if validations == 2 { throw Failure() }
                }, read: { _ in Optional<String>.none }, apply: {
                    try database.execute(query: "INSERT INTO notes(text) VALUES ('must roll back');")
                    return (id: database.lastInsertRowId(), value: "must roll back")
                })
            throw Failure()
        } catch is Failure {
            try check(validations == 2 && count(database, table: "notes") == 1
                && count(database, table: "miniapps_result_receipts") == 1,
                "profile_retirement_rolls_back_edit_and_receipt")
        }
        do {
            _ = try OtzariaMiniAppsReceiptJournal.commit(requestID: UUID(), resultJSON: "error",
                documentID: "note", database: database, validate: {}, read: { _ in Optional<String>.none },
                apply: { () throws -> (id: Int64, value: String) in
                    try database.execute(query: "UPDATE notes SET text = 'must roll back';")
                    throw Failure()
                })
            throw Failure()
        } catch is Failure {
            let original = try database.fetch(query: "SELECT text FROM notes;") { $0.string(at: 0) ?? "" }.first
            try check(original == "עברית" && count(database, table: "miniapps_result_receipts") == 1,
                "failed_native_edit_never_leaves_ack_receipt")
        }

        let restartPath = directory.appendingPathComponent("restart.sqlite").path
        do {
            let fixture = try SQLiteDatabase(path: restartPath)
            try fixture.execute(query: "CREATE TABLE notes (id INTEGER PRIMARY KEY, text TEXT NOT NULL);")
        }
        for mode in ["write", "replay"] {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
            process.arguments = [mode, restartPath]
            try process.run(); process.waitUntilExit()
            try check(process.terminationStatus == 0, mode == "write"
                ? "first_process_durably_saves_before_callback_ack"
                : "new_process_replays_saved_receipt_without_duplicate")
        }
        print("RESULT \(passed) PASS / 0 FAIL")
    }

    static func count(_ db: SQLiteDatabase, table: String) throws -> Int {
        try db.fetch(query: "SELECT COUNT(*) FROM \(table);") { $0.int(at: 0) }.first ?? -1
    }

    static func write(database: SQLiteDatabase, id: UUID, result: String, text: String)
        throws -> OtzariaMiniAppsReceiptJournal.Commit<String> {
        try OtzariaMiniAppsReceiptJournal.commit(requestID: id, resultJSON: result,
            documentID: "note", database: database, validate: {}, read: { id in
                try database.fetch(query: "SELECT text FROM notes WHERE id = ?;", parameters: [id]) {
                    $0.string(at: 0) ?? ""
                }.first
            }, apply: {
                try database.execute(query: "INSERT INTO notes(text) VALUES (?);", parameters: [text])
                return (id: database.lastInsertRowId(), value: text)
            })
    }

    struct Failure: Error {}
}
