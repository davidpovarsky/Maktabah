import Foundation
import SQLite3
import OtzariaActionCore

private let nativeAttempts = "otzaria_annotation_exchange_native_create_attempts"
private let nativeIdentities = "otzaria_annotation_exchange_native_identities"
private let nativeSchema = "otzaria_annotation_exchange_native_schema"

private func expectNative(_ expected: AnnotationExchangeNativeCreationError, _ body: () throws -> Void) throws {
    do { try body() }
    catch let error as AnnotationExchangeNativeCreationError {
        try require(error == expected, "native error mismatch: \(error)"); return
    }
    catch { throw CheckFailure("expected \(expected), got \(error)") }
    throw CheckFailure("expected native refusal \(expected)")
}

private func pending(_ fixture: Fixture, _ destination: AnnotationExchangeDestination? = nil) throws -> [AnnotationExchangeDelivery] {
    try fixture.ledger.pending(for: destination ?? scope())
}

private func prepare(_ fixture: Fixture) throws -> AnnotationExchangeDelivery {
    try fixture.ledger.installNativeCreationSchema()
    let delivery = try fixture.commit().deliveries[0]
    _ = try fixture.ledger.prepareNativeCreation(for: delivery)
    return delivery
}

private func readFence(_ fixture: Fixture, _ destination: AnnotationExchangeDestination? = nil) throws -> AnnotationExchangeNativeCreationFence? {
    try fixture.ledger.nativeCreationFence(destination: destination ?? scope(), namespace: namespace, annotationUUID: fixture.uuid)
}

private func schemaSnapshot(_ fixture: Fixture) throws -> Data {
    let rows = try fixture.db.fetch(query: "SELECT type,name,tbl_name,sql FROM sqlite_master WHERE tbl_name NOT LIKE 'otzaria_annotation_exchange_native_%' ORDER BY type,name;") { row in
        (0..<row.columnCount).map { row.string(at: $0) ?? "<NULL>" }
    }
    return try JSONEncoder().encode(rows)
}

/// This SQL is fixture-only. It is not a producer receipt, native readback,
/// production identity writer, body application or transport acceptance.
private func seedIdentity(_ fixture: Fixture, _ delivery: AnnotationExchangeDelivery, _ objectID: String) throws {
    try fixture.db.execute(query: """
        INSERT INTO \(nativeIdentities)
        (destination,account_id,space_id,namespace,annotation_uuid,message_id,native_object_id)
        VALUES (?,?,?,?,?,?,?);
        """, parameters: [delivery.destination.destination, delivery.destination.account, delivery.destination.space,
                           delivery.namespace, delivery.annotationUUID.uuidString, delivery.messageID.uuidString, objectID])
}

private func altered(_ d: AnnotationExchangeDelivery, messageID: UUID? = nil, destination: AnnotationExchangeDestination? = nil,
                     namespace: String? = nil, annotationUUID: UUID? = nil, revision: Int64? = nil,
                     payloadDigest: String? = nil, payload: Data? = nil, acknowledged: Bool? = nil) -> AnnotationExchangeDelivery {
    .init(messageID: messageID ?? d.messageID, mutationID: d.mutationID, destination: destination ?? d.destination,
          namespace: namespace ?? d.namespace, annotationUUID: annotationUUID ?? d.annotationUUID,
          revision: revision ?? d.revision, payloadDigest: payloadDigest ?? d.payloadDigest,
          payload: payload ?? d.payload, acknowledged: acknowledged ?? d.acknowledged)
}

private func cancelNativeFenceUpdate(_ context: UnsafeMutableRawPointer?, _ action: Int32,
                                    _ first: UnsafePointer<CChar>?, _ second: UnsafePointer<CChar>?,
                                    _ database: UnsafePointer<CChar>?, _ trigger: UnsafePointer<CChar>?) -> Int32 {
    if action == SQLITE_UPDATE, let first, let second,
       String(cString: first) == nativeAttempts, String(cString: second) == "dispatch_state" {
        withUnsafeCurrentTask { $0?.cancel() }
    }
    return SQLITE_OK
}

private struct CaseResult: Codable {
    let name: String
    let status: String
    let error: String?
}

@main
struct NativeCreationFenceAcceptance {
    @MainActor
    static func main() async {
        do {
            let args = CommandLine.arguments
            guard args.count == 3 else { throw CheckFailure("mode and owned fixture directory required") }
            let root = URL(fileURLWithPath: args[2], isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            switch args[1] {
            case "controls": try await controls(root)
            case "crash-prepared": try crash(root, phase: "prepared")
            case "crash-marked": try crash(root, phase: "marked")
            case "crash-nested": try crash(root, phase: "nested")
            case "reopen-prepared": try reopen(root, phase: "prepared")
            case "reopen-marked": try reopen(root, phase: "marked")
            case "reopen-nested": try reopen(root, phase: "nested")
            default: throw CheckFailure("unknown owned fixture mode")
            }
        } catch {
            acceptancePrint("FAILED: \(error)")
            failAcceptance()
        }
    }

    @MainActor
    private static func controls(_ root: URL) async throws {
        var results: [CaseResult] = []
        func run(_ name: String, _ body: @MainActor () async throws -> Void) async {
            do { try await body(); results.append(.init(name: name, status: "PASS", error: nil)) }
            catch { results.append(.init(name: name, status: "FAIL", error: String(describing: error))) }
        }
        await run("explicit_native_install_requires_original_base") {
            let f = try Fixture(root: root, name: "base-required", install: false)
            let before = try f.originals()
            try require(!f.ledger.hasInstalledSchema() && !f.ledger.hasNativeCreationSchema(), "unexpected initial schema")
            try rejects(.schemaMismatch) { try f.ledger.installNativeCreationSchema() }
            try require(!f.ledger.hasInstalledSchema() && !f.ledger.hasNativeCreationSchema(), "auto-installed base/native")
            try require(f.originals() == before, "changed original fixture")
        }
        await run("opt_in_idempotence_preserves_v1_and_user_version") {
            let f = try Fixture(root: root, name: "opt-in")
            try f.db.execute(query: "PRAGMA user_version=173;")
            let before = try f.originals(), schema = try schemaSnapshot(f)
            try require(!f.ledger.hasNativeCreationSchema(), "constructor/base install activated native extension")
            try f.ledger.installNativeCreationSchema()
            try f.ledger.installNativeCreationSchema()
            try require(f.ledger.hasNativeCreationSchema(), "native schema absent")
            try require(f.scalar("PRAGMA user_version;") == 173, "global user_version changed")
            try require(f.originals() == before && schemaSnapshot(f) == schema, "v1/original data changed")
        }
        await run("partial_schema_is_refused_without_repair") {
            let f = try Fixture(root: root, name: "partial")
            try f.db.execute(query: "CREATE TABLE \(nativeSchema)(singleton INTEGER PRIMARY KEY,version INTEGER NOT NULL);")
            let count = try f.scalar("SELECT COUNT(*) FROM sqlite_master WHERE name LIKE 'otzaria_annotation_exchange_native_%';")
            try rejects(.schemaMismatch) { try f.ledger.installNativeCreationSchema() }
            try require(f.scalar("SELECT COUNT(*) FROM sqlite_master WHERE name LIKE 'otzaria_annotation_exchange_native_%';") == count, "partial schema repaired")
        }
        await run("future_schema_is_refused_without_mutation") {
            let f = try Fixture(root: root, name: "future")
            try f.ledger.installNativeCreationSchema()
            try f.db.execute(query: "DROP TABLE \(nativeSchema);")
            try f.db.execute(query: "CREATE TABLE \(nativeSchema)(singleton INTEGER PRIMARY KEY,version INTEGER NOT NULL CHECK(version=2));")
            try f.db.execute(query: "INSERT INTO \(nativeSchema) VALUES(1,2);")
            try rejects(.schemaMismatch) { _ = try f.ledger.hasNativeCreationSchema() }
            try rejects(.schemaMismatch) { try f.ledger.installNativeCreationSchema() }
            try require(f.scalar("SELECT version FROM \(nativeSchema);") == 2, "future version overwritten")
        }
        await run("foreign_trigger_cannot_turn_prepare_into_ack") {
            let f = try Fixture(root: root, name: "trigger")
            try f.ledger.installNativeCreationSchema()
            let d = try f.commit().deliveries[0]
            try f.db.execute(query: "CREATE TRIGGER native_attempt_bad_ack AFTER INSERT ON \(nativeAttempts) BEGIN UPDATE otzaria_annotation_exchange_outbox SET status='acknowledged'; END;")
            try rejects(.schemaMismatch) { _ = try f.ledger.prepareNativeCreation(for: d) }
            try require(pending(f) == [d] && f.scalar("SELECT COUNT(*) FROM \(nativeAttempts);") == 0, "trigger executed")
        }
        await run("prepared_replay_retains_one_exact_pending_commitment") {
            let f = try Fixture(root: root, name: "prepared")
            let before = try f.originals()
            let d = try prepare(f)
            let again = try f.ledger.prepareNativeCreation(for: d)
            try require(again.delivery == d && again.dispatchState == .prepared, "prepared replay changed")
            try require(f.scalar("SELECT COUNT(*) FROM \(nativeAttempts);") == 1 && pending(f) == [d], "duplicated/ACKed delivery")
            try require(f.originals() == before, "original rows/CloudKit queue changed")
        }
        await run("dispatch_requires_prepared_intent") {
            let f = try Fixture(root: root, name: "unprepared")
            try f.ledger.installNativeCreationSchema()
            let d = try f.commit().deliveries[0]
            try expectNative(.noPreparedAttempt) { _ = try f.ledger.markNativeCreationMayHaveDispatched(d) }
            try require(readFence(f) == nil && pending(f) == [d], "created fence or ACK")
        }
        await run("dispatch_transition_is_one_way_and_visible_to_new_handle") {
            let f = try Fixture(root: root, name: "one-way")
            let d = try prepare(f)
            let before = try f.originals()
            let marked = try f.ledger.markNativeCreationMayHaveDispatched(d)
            try require(marked.dispatchState == .dispatchMayHaveOccurred && sqlite3_get_autocommit(f.db.dbPointer) != 0, "transition was not committed")
            try expectNative(.dispatchMayHaveOccurred) { _ = try f.ledger.markNativeCreationMayHaveDispatched(d) }
            let reopened = try Fixture(root: root, name: "one-way", create: false)
            try require(readFence(reopened) == marked && pending(reopened) == [d], "second handle cannot observe durable fence")
            try require(reopened.originals() == before, "original data changed")
        }
        await run("forged_pending_commitments_are_refused") {
            let f = try Fixture(root: root, name: "forged")
            try f.ledger.installNativeCreationSchema()
            let d = try f.commit().deliveries[0]
            let variants = try [altered(d, messageID: UUID()), altered(d, destination: scope("other-account")),
                altered(d, destination: scope("account-a", "other-space")), altered(d, namespace: "other.namespace"),
                altered(d, annotationUUID: UUID()), altered(d, revision: d.revision + 1),
                altered(d, payloadDigest: String(repeating: "a", count: 64)),
                altered(d, payload: Data("wrong".utf8)), altered(d, acknowledged: true)]
            for value in variants {
                try expectNative(.commitmentNotPending) { _ = try f.ledger.prepareNativeCreation(for: value) }
            }
            try require(readFence(f) == nil && pending(f) == [d], "forgery created an intent/ACK")
        }
        await run("source_change_blocks_dispatch_and_retains_preparation") {
            let f = try Fixture(root: root, name: "source-change")
            let d = try prepare(f)
            try f.db.execute(query: "UPDATE annotations SET note='changed source' WHERE id=1;")
            let changed = try f.originals()
            try rejects(.staleSource) { _ = try f.ledger.markNativeCreationMayHaveDispatched(d) }
            try require(readFence(f)?.dispatchState == .prepared && pending(f) == [d], "stale source dispatched/ACKed")
            try require(f.originals() == changed, "source mutation was overwritten")
        }
        await run("new_revision_cannot_bypass_earlier_uncertain_create") {
            let f = try Fixture(root: root, name: "new-revision")
            let old = try prepare(f)
            let uncertain = try f.ledger.markNativeCreationMayHaveDispatched(old)
            let later = try f.commit(expectedRevision: 1, preview: "later revision").deliveries[0]
            try expectNative(.conflictingAttempt) { _ = try f.ledger.prepareNativeCreation(for: later) }
            try expectNative(.conflictingAttempt) { _ = try f.ledger.markNativeCreationMayHaveDispatched(later) }
            try require(readFence(f) == uncertain && pending(f) == [old, later], "earlier uncertainty or newer outbox lost")
        }
        await run("destination_account_and_space_scopes_are_independent") {
            let f = try Fixture(root: root, name: "scopes")
            try f.ledger.installNativeCreationSchema()
            let scopes = [try scope(), try scope("account-b"), try scope("account-a", "space-b"),
                          try scope("account-a", "space-a", "other-destination")]
            let deliveries = try f.commit(destinations: scopes).deliveries
            for d in deliveries { _ = try f.ledger.prepareNativeCreation(for: d) }
            _ = try f.ledger.markNativeCreationMayHaveDispatched(deliveries[0])
            for (index, d) in deliveries.enumerated() {
                let fence = try readFence(f, d.destination)
                try require(fence?.delivery == d && fence?.dispatchState == (index == 0 ? .dispatchMayHaveOccurred : .prepared), "scope leakage")
                try require(pending(f, d.destination) == [d], "scope ACK")
            }
        }
        await run("highlight_only_and_tombstone_never_prepare_creation") {
            let h = try Fixture(root: root, name: "highlight")
            try h.ledger.installNativeCreationSchema()
            let witness = try h.witness()
            let payload = try TorahAnnotationEnvelopeCodec.encode(.init(namespace: namespace, annotationUUID: h.uuid,
                originatingApp: "otzaria", source: witness.metadata, richBody: nil, textPreview: "", editorRevision: nil,
                title: nil, deletionState: .active))
            let highlight = try h.ledger.commit(mutationID: UUID(), payload: payload, expectedSource: witness,
                expectedRevision: 0, destinations: [scope()]).deliveries[0]
            try expectNative(.nonMaterializable) { _ = try h.ledger.prepareNativeCreation(for: highlight) }
            let t = try Fixture(root: root, name: "tombstone")
            try t.ledger.installNativeCreationSchema()
            _ = try t.commit()
            try t.db.execute(query: "DELETE FROM annotation_tags;")
            try t.db.execute(query: "DELETE FROM annotations;")
            let absent = try t.witness()
            let tombstone = try t.ledger.commit(mutationID: UUID(), payload: t.payload(absent, state: .tombstone),
                expectedSource: absent, expectedRevision: 1, destinations: [scope()]).deliveries[0]
            try expectNative(.nonMaterializable) { _ = try t.ledger.prepareNativeCreation(for: tombstone) }
            try require(readFence(h) == nil && readFence(t) == nil, "non-materializable fence created")
        }
        await run("acknowledged_delivery_cannot_begin_or_dispatch_creation") {
            let f = try Fixture(root: root, name: "acked")
            let d = try prepare(f)
            try require(f.ledger.acknowledge(ack(d)), "fixture ACK setup failed")
            try expectNative(.commitmentNotPending) { _ = try f.ledger.markNativeCreationMayHaveDispatched(d) }
            try expectNative(.commitmentNotPending) { _ = try f.ledger.prepareNativeCreation(for: d) }
            try require(readFence(f)?.dispatchState == .prepared && pending(f).isEmpty, "acknowledged delivery changed")
        }
        await run("nested_dispatch_refusal_preserves_outer_rollback") {
            let f = try Fixture(root: root, name: "nested")
            let d = try prepare(f)
            let before = try f.originals()
            do {
                try f.db.transaction {
                    try require(sqlite3_get_autocommit(f.db.dbPointer) == 0, "outer transaction not active")
                    try expectNative(.nestedDispatchTransition) { _ = try f.ledger.markNativeCreationMayHaveDispatched(d) }
                    try require(readFence(f)?.dispatchState == .prepared, "nested dispatch changed fence")
                    try f.db.execute(query: "UPDATE annotations SET note='outer rollback';")
                    throw CheckFailure("owned outer rollback")
                }
            } catch let error as CheckFailure {
                try require(error.description == "owned outer rollback", "unexpected outer failure")
            }
            try require(f.originals() == before && readFence(f)?.dispatchState == .prepared, "outer rollback did not restore original data")
            try require(sqlite3_get_autocommit(f.db.dbPointer) != 0 && pending(f) == [d], "transaction/ACK leaked")
        }
        await run("two_original_connections_allow_one_dispatch_transition") {
            let f = try Fixture(root: root, name: "concurrent")
            let d = try prepare(f)
            let other = try Fixture(root: root, name: "concurrent", create: false)
            let attempts = await withTaskGroup(of: String.self, returning: [String].self) { group in
                for ledger in [f.ledger, other.ledger] {
                    group.addTask {
                        do { _ = try ledger.markNativeCreationMayHaveDispatched(d); return "committed" }
                        catch AnnotationExchangeNativeCreationError.dispatchMayHaveOccurred { return "uncertain-refused" }
                        catch is SQLiteError { return "sqlite-contention-refused" }
                        catch { return "unexpected:\(error)" }
                    }
                }
                var outcomes: [String] = []
                for await value in group { outcomes.append(value) }
                return outcomes
            }
            try require(attempts.filter { $0 == "committed" }.count == 1 && attempts.allSatisfy { !$0.hasPrefix("unexpected:") },
                        "incorrect concurrent transitions \(attempts)")
            try require(readFence(f)?.dispatchState == .dispatchMayHaveOccurred && pending(f) == [d], "concurrent state/ACK wrong")
        }
        await run("identity_storage_uniqueness_and_reads_are_not_receipts") {
            let f = try Fixture(root: root, name: "identity")
            try f.ledger.installNativeCreationSchema()
            let deliveries = try f.commit(destinations: [scope(), scope("account-a", "space-b")]).deliveries
            for d in deliveries { _ = try f.ledger.prepareNativeCreation(for: d) }
            let first = deliveries.first { $0.destination.space == "space-a" }!
            let second = deliveries.first { $0.destination.space == "space-b" }!
            try seedIdentity(f, first, "owned-fixture-native-id")
            try seedIdentity(f, second, "owned-fixture-native-id")
            let stored = try f.ledger.recordedNativeIdentity(destination: first.destination, namespace: namespace, annotationUUID: f.uuid)
            try require(stored?.nativeObjectID == "owned-fixture-native-id" && stored?.messageID == first.messageID, "identity observation mismatch")
            try sqliteRejects { try seedIdentity(f, first, "replacement-id") }
            try expectNative(.identityAlreadyRecorded) { _ = try f.ledger.prepareNativeCreation(for: first) }
            let secondUUID = UUID()
            try f.db.execute(query: """
                INSERT INTO annotations (bkId,contentId,startIndex,length,startIndexDiac,lengthDiac,color,type,note,createdAt,context,part,page,ckRecordId,lastModified,backendLocator)
                SELECT bkId,contentId,startIndex,length,startIndexDiac,lengthDiac,color,type,note,createdAt,context,part,page,?,lastModified,backendLocator FROM annotations WHERE id=1;
                """, parameters: [secondUUID.uuidString])
            let another = try Fixture(root: root, name: "identity", create: false, uuid: secondUUID)
            let otherDelivery = try another.commit().deliveries[0]
            _ = try another.ledger.prepareNativeCreation(for: otherDelivery)
            try sqliteRejects { try seedIdentity(another, otherDelivery, "owned-fixture-native-id") }
            try require(pending(f).count == 2 && pending(f, second.destination) == [second], "identity seeded an ACK")
            try f.db.execute(query: "UPDATE \(nativeIdentities) SET native_object_id='bad object id' WHERE message_id=?;", parameters: [first.messageID.uuidString])
            try rejects(.corruptRecord) { _ = try f.ledger.recordedNativeIdentity(destination: first.destination, namespace: namespace, annotationUUID: f.uuid) }
        }
        await run("cancellation_at_actual_sql_update_rolls_back_dispatch") {
            let f = try Fixture(root: root, name: "cancel")
            let d = try prepare(f)
            let set = f.db.withSerializedAccess { sqlite3_set_authorizer(f.db.dbPointer, cancelNativeFenceUpdate, nil) }
            try require(set == SQLITE_OK, "authorizer setup")
            defer { _ = f.db.withSerializedAccess { sqlite3_set_authorizer(f.db.dbPointer, nil, nil) } }
            let cancelled = await Task.detached {
                do { _ = try f.ledger.markNativeCreationMayHaveDispatched(d); return false }
                catch is CancellationError { return true }
                catch { return false }
            }.value
            try require(cancelled, "SQL boundary cancellation not propagated")
            try require(readFence(f)?.dispatchState == .prepared && pending(f) == [d], "cancelled update persisted/ACKed")
            try require(sqlite3_get_autocommit(f.db.dbPointer) != 0, "cancel left transaction open")
        }
        let bytes = try JSONEncoder().encode(results)
        try bytes.write(to: root.appendingPathComponent("CASES.json"), options: .atomic)
        acceptancePrint(String(decoding: bytes, as: UTF8.self))
        try require(results.count == 18 && results.allSatisfy { $0.status == "PASS" }, "one or more native-fence component controls failed")
    }

    private static func crash(_ root: URL, phase: String) throws {
        let f = try Fixture(root: root, name: "crash-\(phase)")
        try f.ledger.installNativeCreationSchema()
        let commit = try f.commit(fixedMutationID)
        let d = commit.deliveries[0]
        try writeCrashReceipt(f, phase: phase, commit: commit, originals: f.originals(), cloudRows: f.cloudRows(), root: root)
        let process = ["phase": phase, "pid": String(ProcessInfo.processInfo.processIdentifier), "sqlite": String(cString: sqlite3_libversion())]
        try JSONEncoder().encode(process).write(to: root.appendingPathComponent("writer-\(phase).json"), options: .atomic)
        if phase == "nested" {
            try f.db.transaction {
                _ = try f.ledger.prepareNativeCreation(for: d)
                try expectNative(.nestedDispatchTransition) { _ = try f.ledger.markNativeCreationMayHaveDispatched(d) }
                abruptlyTerminate()
            }
        } else {
            _ = try f.ledger.prepareNativeCreation(for: d)
            if phase == "marked" { _ = try f.ledger.markNativeCreationMayHaveDispatched(d) }
            abruptlyTerminate()
        }
    }

    private static func reopen(_ root: URL, phase: String) throws {
        let f = try Fixture(root: root, name: "crash-\(phase)", create: false)
        let receipt = try JSONDecoder().decode(CrashReceipt.self, from: Data(contentsOf: root.appendingPathComponent("crash-\(phase).json")))
        let deliveries = try pending(f)
        try require(deliveries.count == 1, "pending outbox not preserved")
        let d = deliveries[0]
        try require(d.messageID == receipt.messageID && d.mutationID == receipt.mutationID &&
                    d.payloadDigest == receipt.payloadDigest && d.payload.base64EncodedString() == receipt.payloadBase64, "exact commitment lost")
        try require(f.originals().base64EncodedString() == receipt.originalsBase64 &&
                    f.cloudRows().base64EncodedString() == receipt.cloudRowsBase64, "original rows/queue lost")
        let before = try readFence(f)
        if phase == "nested" {
            try require(before == nil, "uncommitted SAVEPOINT survived process termination")
        } else if phase == "prepared" {
            try require(before?.dispatchState == .prepared, "prepared fence lost")
            _ = try f.ledger.markNativeCreationMayHaveDispatched(d)
        } else {
            try require(before?.dispatchState == .dispatchMayHaveOccurred, "committed uncertain fence lost")
            try expectNative(.dispatchMayHaveOccurred) { _ = try f.ledger.markNativeCreationMayHaveDispatched(d) }
        }
        try require(f.ledger.recordedNativeIdentity(destination: d.destination, namespace: d.namespace, annotationUUID: d.annotationUUID) == nil,
                    "invented native identity")
        try require(pending(f) == [d], "recovery emitted ACK")
        let result = ["phase": phase, "status": "PASS", "pid": String(ProcessInfo.processInfo.processIdentifier),
                      "sqlite": String(cString: sqlite3_libversion()), "payloadDigest": d.payloadDigest,
                      "nativeRPC": "0", "identityWrite": "0", "ACK": "0"]
        try JSONEncoder().encode(result).write(to: root.appendingPathComponent("reopen-\(phase).json"), options: .atomic)
        acceptancePrint(String(decoding: try JSONEncoder().encode(result), as: UTF8.self))
    }
}
