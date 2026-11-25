import Foundation
import SQLite3
import Darwin

private struct NativeBackfillFailure: Error, CustomStringConvertible {
    let description: String
}
private func require(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    guard try condition() else { throw NativeBackfillFailure(description: message) }
}
private func refuses(_ operation: () throws -> Void) throws {
    do { try operation() }
    catch is NativeBackfillFailure { throw NativeBackfillFailure(description: "fixture assertion failed") }
    catch { return }
    throw NativeBackfillFailure(description: "operation unexpectedly accepted")
}

private struct Fixture {
    let directory: URL
    let connection: AnnotationLocalEditorConnection
    let database: SQLiteDatabase
    let owner = AnnotationLocalEditorLifetime()
    let formats: Set<AnnotationLocalEditorBodyFormat>
    let planner: AnnotationBackfillPlanner
    let catalog: AnnotationNativeBackfillCatalog

    init(root: URL, name: String, texts: [String] = [], legacy: Bool = false, reopen: Bool = false) throws {
        directory = root.appendingPathComponent(name)
        if !reopen {
            try require(!FileManager.default.fileExists(atPath: directory.path), "fixture already exists")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        }
        _ = try AnnotationRepository.shared.setupAnnotationsDatabase(at: directory)
        connection = try AnnotationRepository.shared.captureLocalEditorConnection()
        database = connection.database
        formats = [try .init(identifier: "test.opaque", version: 1)]
        planner = try .init(connection: connection, owner: owner, digest: AnnotationExchangePlatformDigest())
        catalog = try .init(connection: connection, owner: owner, formats: formats,
                            digest: AnnotationExchangePlatformDigest())
        if !reopen {
            try database.transaction {
                for (offset, text) in texts.enumerated() {
                    let id = Int64(offset + 1)
                    let record = legacy ? "legacy_2_\(id)_0_1700000000" : Self.record(id)
                    try database.execute(query: """
                        INSERT INTO annotations
                        (id,bkId,contentId,startIndex,length,startIndexDiac,lengthDiac,color,type,note,
                         createdAt,context,part,page,ckRecordId,lastModified,backendLocator)
                        VALUES (?,2,?,0,8,0,8,'#FFFF00',0,?,1700000000,'context',1,1,?,1700000001,NULL);
                        """, parameters: [id, id, text, record])
                }
                try database.execute(query: "INSERT INTO tags(id,name,normalizedName) VALUES (1,'Study','study');")
                if !texts.isEmpty {
                    try database.execute(query: "INSERT INTO annotation_tags(annotationId,tagId) VALUES (1,1);")
                }
                try connection.syncPending.addPendingSync(ckRecordId: "other-upload", operation: "upload")
                try connection.syncPending.addPendingSync(ckRecordId: "other-delete", operation: "delete")
            }
        }
    }

    static func record(_ id: Int64) -> String {
        String(format: "00000000-0000-4000-8000-%012lld", id)
    }
    func scalar(_ query: String, _ parameters: [Any] = []) throws -> Int64 {
        try database.fetch(query: query, parameters: parameters) { $0.int64(at: 0) }.first ?? -1
    }
    func text(_ id: Int64) throws -> String? {
        try database.fetch(query: "SELECT note FROM annotations WHERE id=?;", parameters: [id]) { $0.string(at: 0) }.first ?? nil
    }
    func prepare() throws {
        let scan = try planner.inspect()
        var cursor: Int64 = 0
        while true {
            let batch = try planner.prepareBatch(scan, afterAnnotationID: cursor)
            cursor = batch.lastAnnotationID
            if batch.isComplete { return }
        }
    }
    func items(_ chosen: AnnotationNativeBackfillCatalog? = nil) throws -> [AnnotationNativeBackfillItem] {
        let chosen = chosen ?? catalog
        let scan = try chosen.inspect()
        var cursor: Int64 = 0
        var result: [AnnotationNativeBackfillItem] = []
        while true {
            let batch = try chosen.readBatch(scan, afterAnnotationID: cursor, limit: 2)
            result.append(contentsOf: batch.items)
            cursor = batch.lastAnnotationID
            if batch.isComplete { return result }
        }
    }
    func storage(_ id: Int64) throws -> AnnotationLocalEditorPersistence {
        let record = try database.fetch(query: "SELECT ckRecordId FROM annotations WHERE id=?;",
            parameters: [id]) { $0.string(at: 0) }.first ?? nil
        guard let uuid = try AnnotationExchangeIdentity.resolve(database: database,
            annotationID: id, originalRecordID: record) else {
            throw NativeBackfillFailure(description: "fixture identity is absent")
        }
        return try .init(connection: connection, annotationID: id, annotationUUID: uuid,
            sessionID: UUID(), owner: AnnotationLocalEditorLifetime(), formats: formats,
            digest: AnnotationExchangePlatformDigest())
    }
    func noWrites<Value>(_ operation: () throws -> Value) throws -> Value {
        let count = sqlite3_total_changes64(database.dbPointer)
        let schema = try database.fetch(query: "SELECT type,name,coalesce(sql,'') FROM sqlite_master ORDER BY type,name;") {
            [$0.string(at: 0) ?? "", $0.string(at: 1) ?? "", $0.string(at: 2) ?? ""]
        }
        let result = try operation()
        try require(sqlite3_total_changes64(database.dbPointer) == count, "read-only selection performed an SQLite write")
        let after = try database.fetch(query: "SELECT type,name,coalesce(sql,'') FROM sqlite_master ORDER BY type,name;") {
            [$0.string(at: 0) ?? "", $0.string(at: 1) ?? "", $0.string(at: 2) ?? ""]
        }
        try require(schema == after, "read-only selection changed schema")
        return result
    }
}

private struct CaseResult: Codable {
    let name: String
    let status: String
    let seconds: Double
    let error: String?
}
private func write<Value: Encodable>(_ value: Value, _ file: URL) throws {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(value).write(to: file, options: .atomic)
}

@main
private struct NativeBackfillSelectionAcceptance {
    static func main() throws {
        guard CommandLine.arguments.count == 3 else { throw NativeBackfillFailure(description: "mode/root required") }
        let root = URL(fileURLWithPath: CommandLine.arguments[2])
        if CommandLine.arguments[1] == "cold-rescan" {
            let f = try Fixture(root: root, name: "canonical-resume", reopen: true)
            let values = try f.noWrites { try f.items() }
            try require(values.count == 1 && values[0].disposition == .existingRich, "cold rescan did not retain canonical body")
            try require(f.scalar("SELECT COUNT(*) FROM otzaria_annotation_exchange_versions WHERE namespace='otzaria.local.annotation';") == 1,
                        "cold rescan duplicated saved version")
            try write(["processID": String(getpid()), "retainedRich": "1", "newNativeOperations": "0"],
                      root.appendingPathComponent("COLD.json"))
            return
        }
        guard CommandLine.arguments[1] == "checks" else { throw NativeBackfillFailure(description: "unknown mode") }
        var results: [CaseResult] = []
        func run(_ name: String, _ body: () throws -> Void) {
            let start = DispatchTime.now().uptimeNanoseconds
            do {
                try body()
                results.append(.init(name: name, status: "PASS",
                    seconds: Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000_000, error: nil))
            } catch {
                results.append(.init(name: name, status: "FAIL",
                    seconds: Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000_000,
                    error: String(describing: error)))
            }
            print("\(results.last!.status) \(name)")
        }

        run("unprepared_discovery_does_not_install_schema_or_register_identity") {
            let f = try Fixture(root: root, name: "unprepared", texts: ["Saved Hebrew עברית"], legacy: true)
            let rows = try f.noWrites { try f.items() }
            try require(rows[0].disposition == .needsPreparation && rows[0].candidate == nil, "unprepared legacy note admitted")
            try require(f.scalar("SELECT COUNT(*) FROM sqlite_master WHERE name LIKE 'otzaria_annotation_exchange%';") == 0,
                        "selection installed an exchange schema")
        }
        run("current_plan_preserves_legacy_and_uuid_original_identity") {
            for legacy in [false, true] {
                let f = try Fixture(root: root, name: legacy ? "legacy" : "uuid", texts: ["שמורה\nSaved"], legacy: legacy)
                try f.prepare()
                let rows = try f.noWrites { try f.items() }
                try require(rows.count == 1 && rows[0].disposition == .ready, "current plan not admitted")
                let candidate = rows[0].candidate!
                let storage = try f.storage(1)
                try AnnotationNativeBackfillPolicy.requireSameCandidate(candidate, snapshot: storage.read())
                try require(candidate.annotation.ckRecordId == (legacy ? "legacy_2_1_0_1700000000" : Fixture.record(1)),
                            "original CloudKit identity changed")
                try require(candidate.annotation.tags == ["Study"], "original tags were omitted")
                try require(f.scalar("SELECT COUNT(*) FROM sync_pending;") == 2, "selection changed pending queue")
            }
        }
        run("utf8_8192_boundary_preserves_multibyte_and_long_note_bytes") {
            let boundary = String(repeating: "א", count: 4_096)
            let long = boundary + "x"
            let emojiBoundary = String(repeating: "📖", count: 2_048)
            let f = try Fixture(root: root, name: "boundaries", texts: [boundary, long, emojiBoundary])
            try f.prepare()
            let rows = try f.noWrites { try f.items() }
            try require(rows.map(\.disposition) == [.ready, .ready, .ready], "UTF-8 boundary was measured as characters")
            try require(f.text(1)?.utf8.elementsEqual(boundary.utf8) == true
                && f.text(2)?.utf8.elementsEqual(long.utf8) == true
                && f.text(3)?.utf8.elementsEqual(emojiBoundary.utf8) == true, "boundary text changed")
            try require(f.scalar("SELECT length(CAST(note AS BLOB)) FROM annotations WHERE id=2;") == 8_193,
                        "long note was truncated")
        }
        run("capture_text_comparison_rejects_normalization_nul_and_truncation") {
            let boundary = String(repeating: "א", count: 4_096)
            try AnnotationNativeBackfillPolicy.requireExactCapturedText(savedText: boundary,
                originalNativeFullPlainText: boundary, originalNativePreview: boundary)
            try AnnotationNativeBackfillPolicy.requireExactCapturedText(savedText: boundary + "x",
                originalNativeFullPlainText: boundary + "x", originalNativePreview: boundary)
            for (saved, captured, preview) in [
                ("a ", "a", "a"), ("\u{00e9}", "e\u{301}", "e\u{301}"),
                (boundary + "x", boundary, boundary), ("a\0b", "a\0b", "a\0b")
            ] {
                try refuses { try AnnotationNativeBackfillPolicy.requireExactCapturedText(savedText: saved,
                    originalNativeFullPlainText: captured, originalNativePreview: preview) }
            }
        }
        run("native_seed_1mib_boundary_retains_oversize_bytes") {
            let boundary = String(repeating: "א", count: 524_288)
            let over = boundary + "x"
            let f = try Fixture(root: root, name: "seed-limit", texts: [boundary, over])
            try f.prepare()
            let rows = try f.noWrites { try f.items() }
            try require(rows.map(\.disposition) == [.ready, .longNote],
                        "original 1 MiB UTF8 seed boundary was not enforced")
            try require(rows[1].candidate == nil, "oversize original note was offered for truncation")
            try require(f.text(1)?.utf8.elementsEqual(boundary.utf8) == true
                && f.text(2)?.utf8.elementsEqual(over.utf8) == true, "large saved bytes were changed")
            try require(f.scalar("SELECT length(CAST(note AS BLOB)) FROM annotations WHERE id=2;") == 1_048_577,
                        "oversize note was truncated")
            try AnnotationNativeBackfillPolicy.requireExactCapturedText(savedText: boundary,
                originalNativeFullPlainText: boundary,
                originalNativePreview: String(repeating: "א", count: 4_096))
            try refuses { try AnnotationNativeBackfillPolicy.requireExactCapturedText(savedText: over,
                originalNativeFullPlainText: over, originalNativePreview: String(repeating: "א", count: 4_096)) }
        }
        run("same_preview_different_full_text_is_refused") {
            let prefix = String(repeating: "a", count: 8_192)
            let saved = prefix + " complete original סוף"
            let f = try Fixture(root: root, name: "same-preview", texts: [saved])
            try f.prepare()
            try f.noWrites {
                try refuses { try AnnotationNativeBackfillPolicy.requireExactCapturedText(savedText: saved,
                    originalNativeFullPlainText: prefix + " altered", originalNativePreview: prefix) }
                try require(f.items()[0].disposition == .ready, "failed capture changed eligibility")
            }
            try require(f.text(1)?.utf8.elementsEqual(saved.utf8) == true, "mismatch overwrote original full text")
            try require(f.scalar("SELECT COUNT(*) FROM otzaria_annotation_exchange_versions WHERE namespace='otzaria.local.annotation';") == 0,
                        "mismatched capture produced a saved rich revision")
        }
        run("long_preview_requires_exact_scalar_boundary") {
            let prefix = String(repeating: "א", count: 4_095)
            let full = prefix + "📖" + "tail"
            try require(prefix.utf8.count == 8_190 && full.utf8.count > 8_192, "multibyte fixture differs")
            try AnnotationNativeBackfillPolicy.requireExactCapturedText(savedText: full,
                originalNativeFullPlainText: full, originalNativePreview: prefix)
            for bad in [String(prefix.dropLast()), prefix + "📖", prefix + "xx"] {
                try refuses { try AnnotationNativeBackfillPolicy.requireExactCapturedText(savedText: full,
                    originalNativeFullPlainText: full, originalNativePreview: bad) }
            }
        }
        run("saved_text_changed_after_plan_requires_new_explicit_preparation") {
            let f = try Fixture(root: root, name: "source-change", texts: ["first"])
            try f.prepare()
            try f.database.execute(query: "UPDATE annotations SET note='second' WHERE id=1;")
            let rows = try f.noWrites { try f.items() }
            try require(rows[0].disposition == .needsPreparation && rows[0].candidate == nil, "stale plan admitted")
            try require(f.scalar("SELECT COUNT(*) FROM otzaria_annotation_exchange_versions;") == 1, "selection repaired plan implicitly")
        }
        run("candidate_rechecks_original_metadata_and_revision_before_native_work") {
            let f = try Fixture(root: root, name: "candidate-change", texts: ["saved"])
            try f.prepare()
            let candidate = try f.items()[0].candidate!
            try f.database.execute(query: "UPDATE annotations SET color='#00FFFF' WHERE id=1;")
            let current = try f.storage(1).read()
            try f.noWrites {
                try refuses { try AnnotationNativeBackfillPolicy.requireSameCandidate(candidate, snapshot: current) }
            }
        }
        run("existing_opaque_rich_body_is_preserved_without_native_decode") {
            let f = try Fixture(root: root, name: "opaque", texts: ["saved"])
            try f.prepare()
            let storage = try f.storage(1), before = try storage.read()
            let body = TorahAnnotationEnvelope.RichBody(format: "test.opaque", formatVersion: 1, bytes: Data([0, 255, 1, 2]))
            let intent = try storage.prepare(snapshot: before, mutationID: UUID(), body: body, textPreview: "saved", editorRevision: nil)
            let saved = try storage.commit(intent)
            let rows = try f.noWrites { try f.items() }
            try require(rows[0].disposition == .existingRich, "opaque rich body selected for plain conversion")
            try require(storage.read().version == saved.snapshot.version, "opaque body/revision changed during selection")
        }
        run("future_envelope_is_retained_without_downgrade") {
            let f = try Fixture(root: root, name: "future", texts: ["saved"])
            try f.prepare()
            let storage = try f.storage(1), current = try storage.read()
            let ledger = AnnotationExchangeLedger(database: f.database, digest: AnnotationExchangePlatformDigest())
            let payload = try TorahAnnotationEnvelopeCodec.encode(.init(namespace: AnnotationLocalEditorPersistence.namespace,
                annotationUUID: current.annotationUUID, originatingApp: "test.fixture", source: current.source.metadata,
                richBody: nil, textPreview: "saved", editorRevision: nil, title: nil, deletionState: .active))
            var fields = try AnnotationEnvelopeJSONCodec.decodeObject(payload)
            fields["schemaVersion"] = .integer(2)
            let future = try AnnotationExchangeValidation.canonical(.object(fields))
            // Model bytes written by a future app version. Current production commitLocal
            // must reject that version, so first establish the real current-version row.
            let saved = try ledger.commitLocal(mutationID: UUID(), payload: payload,
                expectedSource: current.source, expectedRevision: 0)
            try f.database.execute(query: """
                UPDATE main.otzaria_annotation_exchange_versions SET payload_base64 = ?, payload_digest = ?
                WHERE mutation_id = ?;
                """, parameters: [future.base64EncodedString(),
                    try AnnotationExchangePlatformDigest().sha256(future), saved.mutationID.uuidString])
            let rows = try f.noWrites { try f.items() }
            try require(rows[0].disposition == .unsupported, "future envelope was admitted")
            try require(storage.read().version?.payload == future, "future bytes were re-encoded")
        }
        run("highlights_and_pending_deletions_are_not_converted") {
            let f = try Fixture(root: root, name: "non-notes", texts: ["", "deleted", "saved"])
            try f.connection.syncPending.addPendingSync(ckRecordId: Fixture.record(2), operation: "delete")
            try f.prepare()
            let rows = try f.noWrites { try f.items() }
            try require(rows.map(\.disposition) == [.metadataOnly, .pendingDeletion, .ready], "highlight/deletion admitted")
        }
        run("retired_run_cannot_read_or_recover_current_authority") {
            let f = try Fixture(root: root, name: "retired", texts: ["saved"])
            try f.prepare()
            let scan = try f.catalog.inspect()
            f.owner.retire()
            try f.noWrites { try refuses { _ = try f.catalog.readBatch(scan, afterAnnotationID: 0) } }
        }
        run("original_profile_switch_retires_captured_scan") {
            let f = try Fixture(root: root, name: "old-profile", texts: ["saved"])
            try f.prepare()
            let scan = try f.catalog.inspect()
            _ = try Fixture(root: root, name: "new-profile", texts: ["other"])
            try f.noWrites { try refuses { _ = try f.catalog.readBatch(scan, afterAnnotationID: 0) } }
        }
        run("bounded_scan_rejects_foreign_session_and_invalid_cursor") {
            let f = try Fixture(root: root, name: "scan-bounds", texts: ["saved"])
            let scan = try f.catalog.inspect()
            for (candidate, cursor, limit) in [
                (scan, Int64(0), 0), (scan, Int64(0), 51), (scan, Int64(-1), 25),
                (scan, Int64(2), 25),
                (.init(id: UUID(), lastAnnotationID: 1, rowCount: 1), Int64(0), 25)
            ] {
                try refuses { _ = try f.catalog.readBatch(candidate, afterAnnotationID: cursor, limit: limit) }
            }
        }
        run("resume_uses_real_canonical_saved_version_without_duplicate_conversion") {
            let f = try Fixture(root: root, name: "canonical-resume", texts: ["saved byte-exact"])
            try f.prepare()
            let storage = try f.storage(1), before = try storage.read()
            // Deliberately an opaque component fixture, not a claimed native archive.
            let body = TorahAnnotationEnvelope.RichBody(format: "test.opaque", formatVersion: 1, bytes: Data([7, 8, 9]))
            let saved = try storage.commit(storage.prepare(snapshot: before, mutationID: UUID(), body: body,
                textPreview: before.annotation.note!, editorRevision: nil))
            let fresh = try AnnotationNativeBackfillCatalog(connection: f.connection, owner: AnnotationLocalEditorLifetime(),
                formats: f.formats, digest: AnnotationExchangePlatformDigest())
            let rows = try f.noWrites { try f.items(fresh) }
            try require(rows[0].disposition == .existingRich, "resume reselected a canonical rich note")
            try require(storage.read().version == saved.snapshot.version, "resume changed canonical version")
            try require(f.scalar("SELECT COUNT(*) FROM otzaria_annotation_exchange_outbox;") == 0, "resume created a destination")
            try write(["processID": String(getpid()), "localBodyVersions": "1", "note": before.annotation.note!],
                      root.appendingPathComponent("RESUME.json"))
        }
        run("sqlite_nul_text_is_refused_without_truncated_selection") {
            let f = try Fixture(root: root, name: "nul", texts: ["saved"])
            try f.database.execute(query: "UPDATE annotations SET note=CAST(X'610062' AS TEXT) WHERE id=1;")
            try f.noWrites { try refuses { _ = try f.items() } }
            try require(f.scalar("SELECT length(CAST(note AS BLOB)) FROM annotations WHERE id=1;") == 3,
                        "NUL-containing original bytes changed")
        }
        try write(results, root.appendingPathComponent("CASES.json"))
        guard results.count == 17, results.allSatisfy({ $0.status == "PASS" }) else {
            throw NativeBackfillFailure(description: "new native-backfill selection controls failed")
        }
    }
}
