import Foundation
import SQLite3
import OtzariaActionCore

struct IdentityFailure: Error, CustomStringConvertible, Sendable {
    let description: String
    init(_ value: String) { description = value }
}
func expectIdentity(_ value: @autoclosure () throws -> Bool, _ reason: String) throws {
    guard try value() else { throw IdentityFailure(reason) }
}
func refuseIdentity(_ expected: AnnotationExchangeError, _ body: () throws -> Void) throws {
    do { try body() }
    catch let value as AnnotationExchangeError {
        try expectIdentity(value == expected, "Expected \(expected), observed \(value)")
        return
    }
    throw IdentityFailure("Unexpectedly accepted \(expected)")
}

let identityFormat = try! AnnotationLocalEditorBodyFormat(identifier: "org.otzaria.acceptance.legacy-identity", version: 1)
func identityBody(_ suffix: String = "one") -> TorahAnnotationEnvelope.RichBody {
    // Opaque component bytes, never claimed as native Anytype serialization.
    .init(format: identityFormat.identifier, formatVersion: 1,
          bytes: Data("opaque owned legacy body \u{05E9}\u{05DC}\u{05D5}\u{05DD} \(suffix)".utf8))
}

@MainActor
struct IdentityFixture {
    let profile: URL
    let id: Int64
    let db: SQLiteDatabase

    init(root: URL, name: String, legacy: Bool = true) throws {
        profile = root.appendingPathComponent(name, isDirectory: true)
        AnnotationStore.shared.disconnect()
        try AnnotationStore.shared.setup(at: profile)
        let originalUUID = UUID().uuidString
        let value = Annotation(id: nil, bkId: 28, contentId: 2, range: NSRange(location: 4, length: 5),
            rangeDiacritics: NSRange(location: 6, length: 7), colorHex: "#123456", type: .underline,
            note: "original legacy note", createdAt: 1_700_000_001, context: "original \u{05E9}\u{05DC}\u{05D5}\u{05DD} context",
            page: 9, part: 1, tags: ["\u{05E9}\u{05DC}\u{05D5}\u{05DD}", "second"], ckRecordId: originalUUID,
            lastModified: nil, backendLocator: .init(backend: .fixture, workKey: "fixture:28:2"))
        id = try AnnotationStore.shared.addAnnotation(value)
        guard let originalDB = AnnotationRepository.shared.db else { throw IdentityFailure("Original DB absent") }
        db = originalDB
        if legacy {
            // Own fixture only: model a pre-CloudKit row, then call the actual
            // original repository backfill, not a replacement ID generator.
            try db.execute(query: "UPDATE annotations SET ckRecordId = NULL WHERE id = ?;", parameters: [id])
            let backfilled = try AnnotationRepository.shared.backfillCloudKitFieldsIfNeeded()
            try expectIdentity(backfilled.count == 1 && backfilled[0].id == id, "Actual original backfill did not run")
            try db.execute(query: "DELETE FROM sync_pending WHERE ck_record_id = ?;", parameters: [originalUUID])
            try AnnotationRepository.shared.addPendingSync(ckRecordId: backfilled[0].ckRecordId!, operation: "upload")
        }
        try AnnotationRepository.shared.addPendingSync(ckRecordId: "unrelated-delete", operation: "delete")
        CloudKitSyncManager.shared.resetObservation()
    }

    func annotation() throws -> Annotation {
        guard let row = try AnnotationRepository.shared.loadAnnotationById(id) else {
            throw IdentityFailure("Original row disappeared")
        }
        return row
    }
    func record() throws -> String {
        guard let value = try annotation().ckRecordId else { throw IdentityFailure("No original CloudKit identity") }
        return value
    }
    func resolve() throws -> UUID? {
        try AnnotationExchangeIdentity.resolve(database: db, annotationID: id, originalRecordID: record())
    }
    func register() throws -> UUID {
        try AnnotationExchangeIdentity.registerLegacy(database: db, annotationID: id, originalRecordID: record())
    }
    func session() throws -> AnnotationLocalEditorSession {
        try AnnotationStore.shared.makeLocalAnnotationEditor(annotation: annotation(), supportedFormats: [identityFormat])
    }
    func ledger() -> AnnotationExchangeLedger {
        .init(database: db, digest: AnnotationExchangePlatformDigest())
    }
    func scalar(_ query: String, _ parameters: [Any] = []) throws -> Int64 {
        try db.fetch(query: query, parameters: parameters) { $0.int64(at: 0) }.first ?? -1
    }
    func image() throws -> Data {
        try db.withSerializedAccess {
            var count: sqlite3_int64 = 0
            guard let bytes = sqlite3_serialize(db.dbPointer, "main", &count, 0), count > 0 else {
                throw IdentityFailure("Actual SQLite image unavailable")
            }
            defer { sqlite3_free(bytes) }
            return Data(bytes: bytes, count: Int(count))
        }
    }
    func originalBytes() throws -> Data {
        var result: [String: [[String]]] = [:]
        for table in ["annotations", "tags", "annotation_tags", "sync_pending"] {
            let columns = try db.fetch(query: "PRAGMA main.table_info(\(table));") { $0.string(at: 1)! }
            let select = columns.flatMap { name -> [String] in
                let quoted = "\"" + name.replacingOccurrences(of: "\"", with: "\"\"") + "\""
                return ["typeof(\(quoted))", "hex(CAST(\(quoted) AS BLOB))"]
            }.joined(separator: ", ")
            result[table] = try db.fetch(query: "SELECT \(select) FROM main.\(table) ORDER BY rowid;") { row in
                (0..<row.columnCount).map { row.string(at: $0) ?? "<NULL>" }
            }
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(result)
    }
    func save(_ session: AnnotationLocalEditorSession, snapshot: AnnotationLocalEditorSnapshot? = nil,
              suffix: String = "one") async throws -> AnnotationLocalEditorCommitted {
        let source: AnnotationLocalEditorSnapshot
        if let snapshot { source = snapshot } else { source = try await session.read() }
        let intent = try session.prepareSave(snapshot: source, mutationID: UUID(), body: identityBody(suffix),
                                             textPreview: "legacy preview \(suffix)", editorRevision: suffix)
        guard case .committed(let saved) = try await session.save(intent) else {
            throw IdentityFailure("Original local transaction lost ownership")
        }
        return saved
    }
}

@MainActor
final class IdentityCases {
    struct Row: Codable { let name: String; let status: String; let error: String? }
    let root: URL
    var rows: [Row] = []
    init(root: URL) { self.root = root }
    func run(_ name: String, _ work: @MainActor () async throws -> Void) async {
        do { try await work(); rows.append(.init(name: name, status: "PASS", error: nil)); print("PASS \(name)") }
        catch { rows.append(.init(name: name, status: "FAIL", error: String(describing: error))); print("FAIL \(name): \(error)") }
    }
    func fixture(_ name: String, legacy: Bool = true) throws -> IdentityFixture {
        try .init(root: root, name: name, legacy: legacy)
    }
    func execute() async {
        await run("existing_lowercase_uuid_remains_mapping_free") {
            let f = try fixture("existing-uuid", legacy: false)
            let record = try f.record().lowercased()
            try f.db.execute(query: "UPDATE annotations SET ckRecordId = ? WHERE id = ?;", parameters: [record, f.id])
            let before = try f.image()
            let value = try f.resolve()
            try expectIdentity(value == UUID(uuidString: record), "Existing UUID changed")
            try expectIdentity(try f.image() == before && f.record() == record, "Read changed original UUID bytes")
            try expectIdentity(try f.scalar("SELECT COUNT(*) FROM sqlite_master WHERE name LIKE 'otzaria_annotation_exchange_%';") == 0,
                               "Read installed schema")
        }
        await run("legacy_read_is_unregistered_without_side_effects") {
            let f = try fixture("unregistered")
            let before = try f.image()
            try expectIdentity(try f.resolve() == nil, "Implicit legacy registration")
            try expectIdentity(try AnnotationStore.shared.resolveAnnotationExchangeIdentity(annotation: f.annotation()) == nil,
                               "Store read registered legacy identity")
            do { _ = try f.session(); throw IdentityFailure("Unregistered legacy editor opened") }
            catch AnnotationLocalEditorError.missingAnnotation {}
            try expectIdentity(try f.image() == before, "Read or rejected open mutated SQLite")
        }
        await run("explicit_registration_preserves_original_rows_and_cloud_queue") {
            let f = try fixture("preservation")
            let before = try f.originalBytes(), record = try f.record()
            let uuid = try f.register()
            try expectIdentity(try f.resolve() == uuid, "Registered identity missing")
            try expectIdentity(try f.originalBytes() == before && f.record() == record, "Original data or queue changed")
            try expectIdentity(CloudKitSyncManager.shared.observation.uploads.isEmpty, "Migration dispatched cloud work")
            try expectIdentity(try !f.ledger().hasInstalledSchema(), "Migration installed exchange/outbox schema")
        }
        await run("registration_retry_is_exactly_idempotent") {
            let f = try fixture("retry")
            let first = try f.register(), before = try f.image()
            try expectIdentity(try f.register() == first && f.image() == before, "Retry wrote identity again")
        }
        await run("stable_uuid_uses_original_record_not_rowid_or_profile") {
            let first = try fixture("profile-a")
            let record = try first.record(), uuid = try first.register()
            let second = try fixture("profile-b")
            try second.db.execute(query: "UPDATE annotations SET id = 7001 WHERE id = ?;", parameters: [second.id])
            try second.db.execute(query: "UPDATE annotation_tags SET annotationId = 7001 WHERE annotationId = ?;", parameters: [second.id])
            let other = try AnnotationExchangeIdentity.registerLegacy(database: second.db, annotationID: 7001, originalRecordID: record)
            try expectIdentity(other == uuid, "Local row/profile changed stable CloudKit-derived identity")
        }
        await run("distinct_original_record_ids_have_distinct_aliases") {
            let a = try fixture("record-a"); let first = try a.register()
            let b = try fixture("record-b")
            let changed = "legacy_28_2_4_1700000002"
            try b.db.execute(query: "UPDATE annotations SET ckRecordId = ? WHERE id = ?;", parameters: [changed, b.id])
            try expectIdentity(try b.register() != first, "Distinct original identities collapsed")
        }
        await run("canonical_int64_legacy_fields_preserve_original_interpolation") {
            let f = try fixture("integer-bounds")
            let record = "legacy_-9223372036854775808_9223372036854775807_-1_0"
            try f.db.execute(query: "UPDATE annotations SET ckRecordId = ? WHERE id = ?;", parameters: [record, f.id])
            let uuid = try f.register()
            try expectIdentity(try f.resolve() == uuid && f.record() == record, "Canonical Int64 identity changed")
        }
        await run("malformed_or_unknown_legacy_identifiers_fail_closed") {
            let records = ["foreign_28_2_4_1700000001", "legacy_028_2_4_1700000001", "legacy_+28_2_4_1",
                           "legacy_28_2_4_9223372036854775808", "legacy_28_2_4_1_", "legacy_28__4_1", "legacy_28_2_4_-0"]
            for (index, record) in records.enumerated() {
                let f = try fixture("malformed-\(index)")
                try f.db.execute(query: "UPDATE annotations SET ckRecordId = ? WHERE id = ?;", parameters: [record, f.id])
                let before = try f.image()
                try refuseIdentity(.invalidScope) { _ = try f.register() }
                try refuseIdentity(.invalidScope) { _ = try f.resolve() }
                try expectIdentity(try f.image() == before, "Rejected identifier mutated original image")
            }
        }
        await run("duplicate_original_record_ids_refuse_before_schema_install") {
            let f = try fixture("duplicate")
            try f.db.execute(query: "INSERT INTO annotations (ckRecordId) VALUES (?);", parameters: [try f.record()])
            let before = try f.image()
            try refuseIdentity(.ambiguousSource) { _ = try f.register() }
            try expectIdentity(try f.image() == before, "Duplicate rejection changed DB")
        }
        await run("changed_original_record_is_not_silently_adopted") {
            let f = try fixture("changed")
            let old = try f.record()
            try f.db.execute(query: "UPDATE annotations SET ckRecordId = ? WHERE id = ?;",
                             parameters: ["legacy_28_2_4_1700000002", f.id])
            let before = try f.image()
            try refuseIdentity(.staleSource) {
                _ = try AnnotationExchangeIdentity.registerLegacy(database: f.db, annotationID: f.id, originalRecordID: old)
            }
            try expectIdentity(try f.image() == before, "Stale identity registered")
        }
        await run("duplicate_direct_uuid_case_variants_are_ambiguous") {
            let f = try fixture("uuid-duplicate", legacy: false)
            let original = try f.record()
            try f.db.execute(query: "INSERT INTO annotations (ckRecordId) VALUES (?);", parameters: [original.lowercased()])
            try refuseIdentity(.ambiguousSource) { _ = try f.resolve() }
            try refuseIdentity(.ambiguousSource) {
                _ = try AnnotationExchangeIdentity.originalRecordID(database: f.db, annotationUUID: UUID(uuidString: original)!)
            }
        }
        await run("mapped_and_direct_uuid_collision_is_rejected_in_both_directions") {
            let f = try fixture("collision")
            let uuid = try f.register()
            try f.db.execute(query: "INSERT INTO annotations (ckRecordId) VALUES (?);", parameters: [uuid.uuidString])
            try refuseIdentity(.ambiguousSource) { _ = try f.resolve() }
            try refuseIdentity(.ambiguousSource) {
                _ = try AnnotationExchangeIdentity.originalRecordID(database: f.db, annotationUUID: uuid)
            }
            let id = try f.scalar("SELECT id FROM annotations WHERE ckRecordId = ?;", [uuid.uuidString])
            try refuseIdentity(.ambiguousSource) {
                _ = try AnnotationExchangeIdentity.resolve(database: f.db, annotationID: id, originalRecordID: uuid.uuidString)
            }
        }
        await run("unknown_mapping_schema_is_preserved_and_refused") {
            let f = try fixture("wrong-schema")
            try f.db.execute(query: "CREATE TABLE otzaria_annotation_exchange_legacy_identities (original_record_id TEXT);")
            let before = try f.image()
            try refuseIdentity(.schemaMismatch) { _ = try f.register() }
            try expectIdentity(try f.image() == before, "Unknown schema rewritten")
        }
        await run("unknown_mapping_trigger_is_preserved_and_refused") {
            let f = try fixture("trigger"); _ = try f.register()
            try f.db.execute(query: """
                CREATE TRIGGER unknown_mapping_trigger AFTER INSERT ON otzaria_annotation_exchange_legacy_identities
                BEGIN SELECT 1; END;
                """)
            let before = try f.image()
            try refuseIdentity(.schemaMismatch) { _ = try f.register() }
            try expectIdentity(try f.image() == before, "Unknown trigger changed")
        }
        await run("temporary_shadow_cannot_capture_identity") {
            let f = try fixture("shadow")
            try f.db.execute(query: "CREATE TEMP TABLE otzaria_annotation_exchange_legacy_identities (value TEXT);")
            let before = try f.image()
            try refuseIdentity(.schemaMismatch) { _ = try f.register() }
            try expectIdentity(try f.image() == before, "Shadow refusal changed main DB")
        }
        await run("corrupt_alias_uuid_does_not_rebind_original_note") {
            let f = try fixture("corrupt"); _ = try f.register()
            try f.db.execute(query: "UPDATE otzaria_annotation_exchange_legacy_identities SET annotation_uuid = ?;",
                             parameters: [UUID().uuidString])
            let before = try f.image()
            try refuseIdentity(.corruptRecord) { _ = try f.resolve() }
            try expectIdentity(try f.image() == before, "Corrupt alias repaired implicitly")
        }
        await run("outer_transaction_rollback_removes_identity_and_ddl") {
            let f = try fixture("rollback"); let before = try f.image()
            do {
                try f.db.transaction { _ = try f.register(); throw IdentityFailure("deliberate owned rollback") }
            } catch is IdentityFailure {}
            try expectIdentity(try f.image() == before && f.resolve() == nil, "Outer rollback retained identity")
        }
        await run("cancelled_registration_cannot_write_or_create_schema") {
            let f = try fixture("cancel")
            let before = try f.image(), record = try f.record(), database = f.db, id = f.id
            let task = Task { @MainActor in
                try AnnotationExchangeIdentity.registerLegacy(database: database, annotationID: id, originalRecordID: record)
            }
            task.cancel()
            do { _ = try await task.value; throw IdentityFailure("Cancelled migration completed") }
            catch is CancellationError {}
            try expectIdentity(try f.image() == before, "Cancellation changed SQLite")
        }
        await run("deleted_mapped_source_stays_absent_without_identity_reuse") {
            let f = try fixture("deleted"); let uuid = try f.register()
            try f.db.execute(query: "DELETE FROM annotation_tags WHERE annotationId = ?;", parameters: [f.id])
            try f.db.execute(query: "DELETE FROM annotations WHERE id = ?;", parameters: [f.id])
            let before = try f.image()
            try expectIdentity(try AnnotationExchangeIdentity.originalRecordID(database: f.db, annotationUUID: uuid) == nil,
                               "Deleted source recreated")
            try expectIdentity(try !f.ledger().captureSource(annotationUUID: uuid).exists, "Ledger fabricated source")
            try expectIdentity(try f.image() == before, "Absent read wrote data")
        }
        await run("legacy_editor_saves_rich_body_with_original_cloudkit_key") {
            let f = try fixture("saved"); let record = try f.record(), uuid = try f.register()
            let local = try f.session(), saved = try await f.save(local)
            try expectIdentity(saved.snapshot.annotationUUID == uuid && saved.snapshot.annotation.ckRecordId == record,
                               "Save rewrote CloudKit identity")
            try expectIdentity(saved.receipt.revision == 1 && saved.receipt.deliveries.isEmpty, "Unexpected revision/delivery")
            try expectIdentity(try f.scalar("SELECT COUNT(*) FROM sync_pending WHERE ck_record_id = ? AND operation = 'upload';", [record]) == 1,
                               "Original CloudKit queue key missing")
            try expectIdentity(try f.scalar("SELECT COUNT(*) FROM sync_pending WHERE ck_record_id = ?;", [uuid.uuidString]) == 0,
                               "Derived UUID replaced CloudKit record name")
        }
        await run("registered_legacy_rich_body_blocks_plain_overwrite") {
            let f = try fixture("plain-guard"); _ = try f.register()
            let local = try f.session(); _ = try await f.save(local)
            var edited = try f.annotation(); edited.note = "unsafe plain replacement"
            let before = try f.image()
            do { try AnnotationStore.shared.updateAnnotation(edited); throw IdentityFailure("Plain overwrite accepted") }
            catch AnnotationPlainWriteError.requiresExpandedEditor {}
            try expectIdentity(try f.image() == before, "Rejected plain Save changed rich note")
        }
        await run("two_legacy_editors_keep_original_compare_and_swap") {
            let f = try fixture("stale-editor"); _ = try f.register()
            let first = try f.session(), second = try f.session()
            let before = try await first.read(), stale = try await second.read()
            _ = try await f.save(first, snapshot: before)
            do { _ = try await f.save(second, snapshot: stale, suffix: "stale"); throw IdentityFailure("Stale editor saved") }
            catch AnnotationExchangeError.staleSource {}
            try expectIdentity(try f.scalar("SELECT COUNT(*) FROM otzaria_annotation_exchange_versions;") == 1, "Duplicate legacy revision")
        }
        await run("profile_switch_retires_legacy_session_even_for_same_stable_uuid") {
            let old = try fixture("retire-a"); let firstUUID = try old.register(), session = try old.session()
            let snapshot = try await session.read()
            let new = try fixture("retire-b"); let secondUUID = try new.register()
            try expectIdentity(firstUUID == secondUUID, "Fixture CloudKit records should share stable identity")
            let newBefore = try new.image()
            do { _ = try await old.save(session, snapshot: snapshot); throw IdentityFailure("Retired profile wrote") }
            catch AnnotationLocalEditorError.retired {}
            try expectIdentity(try new.image() == newBefore, "Retired session modified new profile")
        }
        await run("concurrent_connections_preserve_one_durable_identity") {
            let f = try fixture("concurrent")
            let record = try f.record(), id = f.id, first = f.db
            let second = try SQLiteDatabase(path: f.profile.appendingPathComponent("Annotations.sqlite").path)
            let before = try f.originalBytes()
            struct Result: Sendable { let uuid: UUID?; let error: String? }
            let results = await withTaskGroup(of: Result.self) { group in
                for database in [first, second] {
                    group.addTask {
                        do {
                            return Result(uuid: try AnnotationExchangeIdentity.registerLegacy(
                                database: database, annotationID: id, originalRecordID: record), error: nil)
                        } catch { return Result(uuid: nil, error: String(describing: error)) }
                    }
                }
                var values: [Result] = []
                for await value in group { values.append(value) }
                return values
            }
            try expectIdentity(results.contains(where: { $0.uuid != nil }), "Neither concurrent registration committed")
            try expectIdentity(results.allSatisfy { $0.uuid != nil || $0.error?.contains("locked") == true || $0.error?.contains("busy") == true },
                               "Unexpected concurrent error")
            let final = try f.register()
            try expectIdentity(results.compactMap(\.uuid).allSatisfy { $0 == final }, "Connections chose different identities")
            try expectIdentity(try f.scalar("SELECT COUNT(*) FROM otzaria_annotation_exchange_legacy_identities;") == 1
                               && f.originalBytes() == before, "Concurrency changed source or duplicated identity")
        }
    }
}

struct IdentityColdReceipt: Codable {
    let mode: String
    let processID: Int32
    let priorProcessID: Int32?
    let annotationID: Int64
    let annotationUUID: UUID
    let originalRecordID: String
    let revision: Int64
    let payloadSHA256: String
    let sourceSHA256: String
    let databasePath: String
}

@main
enum LegacyAnnotationIdentityAcceptance {
    @MainActor static func main() async throws {
        guard CommandLine.arguments.count == 3 else { throw IdentityFailure("mode and owned fixture directory required") }
        let mode = CommandLine.arguments[1]
        let root = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if mode == "self-tests" {
            let cases = IdentityCases(root: root); await cases.execute()
            try encoder.encode(cases.rows).write(to: root.appendingPathComponent("CASES.json"))
            try expectIdentity(cases.rows.count == 24 && Set(cases.rows.map(\.name)).count == 24, "Exact 24 declarations required")
            try expectIdentity(cases.rows.allSatisfy { $0.status == "PASS" }, "Legacy identity cases failed")
            return
        }
        let pid = ProcessInfo.processInfo.processIdentifier
        let expectedPath = root.appendingPathComponent("legacy-write.json")
        let saved: AnnotationLocalEditorCommitted
        let prior: IdentityColdReceipt?
        if mode == "legacy-write" {
            try expectIdentity(!FileManager.default.fileExists(atPath: expectedPath.path), "Cold writer must be fresh")
            let f = try IdentityFixture(root: root, name: "legacy-cold-profile")
            _ = try f.register(); let session = try f.session()
            saved = try await f.save(session); prior = nil
        } else {
            try expectIdentity(mode == "legacy-reopen", "Unknown cold mode")
            let original = try JSONDecoder().decode(IdentityColdReceipt.self, from: Data(contentsOf: expectedPath))
            try expectIdentity(original.processID != pid, "Cold reopen must use another process")
            let profile = root.appendingPathComponent("legacy-cold-profile", isDirectory: true)
            try expectIdentity(original.databasePath == profile.appendingPathComponent("Annotations.sqlite").path, "Wrong owned database")
            try AnnotationStore.shared.setup(at: profile)
            guard let annotation = try AnnotationRepository.shared.loadAnnotationById(original.annotationID) else {
                throw IdentityFailure("Cold original row missing")
            }
            let session = try AnnotationStore.shared.makeLocalAnnotationEditor(annotation: annotation, supportedFormats: [identityFormat])
            let snapshot = try await session.read()
            try expectIdentity(snapshot.annotationUUID == original.annotationUUID && snapshot.annotation.ckRecordId == original.originalRecordID,
                               "Cold identity changed")
            try expectIdentity(snapshot.version?.payloadDigest == original.payloadSHA256 && snapshot.source.digest == original.sourceSHA256,
                               "Cold source or rich bytes changed")
            let intent = try session.prepareSave(snapshot: snapshot, mutationID: UUID(), body: identityBody("reopen"),
                                                 textPreview: "legacy preview reopen", editorRevision: "reopen")
            guard case .committed(let value) = try await session.save(intent) else { throw IdentityFailure("Cold save lost ownership") }
            saved = value; prior = original
            try expectIdentity(saved.receipt.revision == original.revision + 1, "Cold revision did not advance")
        }
        guard let originalID = saved.snapshot.annotation.ckRecordId, let version = saved.snapshot.version else {
            throw IdentityFailure("Original saved identity/version missing")
        }
        let receipt = IdentityColdReceipt(mode: mode, processID: pid, priorProcessID: prior?.processID,
            annotationID: saved.snapshot.annotation.id!, annotationUUID: saved.snapshot.annotationUUID,
            originalRecordID: originalID, revision: saved.receipt.revision, payloadSHA256: version.payloadDigest,
            sourceSHA256: saved.snapshot.source.digest, databasePath: saved.snapshot.databaseURL.path)
        try encoder.encode(receipt).write(to: root.appendingPathComponent(mode + ".json"))
        print("LEGACY_COLD_PROCESS \(mode) PID \(pid) REVISION \(receipt.revision)")
    }
}
