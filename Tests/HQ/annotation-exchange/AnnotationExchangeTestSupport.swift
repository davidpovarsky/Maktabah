import Foundation
import SQLite3
import OtzariaActionCore
#if os(Windows)
import WinSDK
#else
import Darwin
#endif

// Test harness support only. The original full SQLiteDatabase and
// SyncPendingStore sources are compiled unchanged by the runner.
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

#if os(Windows)
/// Actual Windows CNG SHA-256, not a crypto double. Apple runs use the
/// production CryptoKit implementation, which Windows cannot validate.
struct AcceptanceDigest: AnnotationExchangeDigesting {
    func sha256(_ data: Data) throws -> String {
        var algorithm: BCRYPT_ALG_HANDLE?
        let name = Array("SHA256".utf16) + [0]
        let opened = name.withUnsafeBufferPointer { BCryptOpenAlgorithmProvider(&algorithm, $0.baseAddress, nil, 0) }
        guard opened == 0, let algorithm else { throw CheckFailure("CNG open: \(opened)") }
        defer { BCryptCloseAlgorithmProvider(algorithm, 0) }
        var output = [UInt8](repeating: 0, count: 32)
        let status = data.withUnsafeBytes { input in
            output.withUnsafeMutableBufferPointer { bytes in
                BCryptHash(algorithm, nil, 0, UnsafeMutablePointer(mutating: input.bindMemory(to: UInt8.self).baseAddress),
                           ULONG(input.count), bytes.baseAddress, ULONG(bytes.count))
            }
        }
        guard status == 0 else { throw CheckFailure("CNG hash: \(status)") }
        return output.map { String(format: "%02x", $0) }.joined()
    }
}
#else
typealias AcceptanceDigest = AnnotationExchangePlatformDigest
#endif

struct CheckFailure: Error, CustomStringConvertible, Sendable {
    let description: String
    init(_ description: String) { self.description = description }
}

func require(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    guard try condition() else { throw CheckFailure(message) }
}

func rejects(_ expected: AnnotationExchangeError, _ body: () throws -> Void) throws {
    do { try body() }
    catch let error as AnnotationExchangeError {
        try require(error == expected, "expected \(expected), got \(error)"); return
    }
    catch { throw CheckFailure("expected \(expected), got \(error)") }
    throw CheckFailure("expected \(expected), accepted")
}

func sqliteRejects(_ body: () throws -> Void) throws {
    do { try body() }
    catch is SQLiteError { return }
    throw CheckFailure("expected SQLite constraint failure")
}

let namespace = "org.otzaria.annotation"
let fixedAnnotationID = Foundation.UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
let fixedMutationID = Foundation.UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!

func scope(_ account: String = "account-a", _ space: String = "space-a", _ app: String = "anytype-contract") throws -> AnnotationExchangeDestination {
    try .init(destination: app, account: account, space: space)
}

struct Fixture: Sendable {
    let path: URL
    let db: SQLiteDatabase
    let ledger: AnnotationExchangeLedger
    let queue: SyncPendingStore
    let uuid: Foundation.UUID

    init(root: URL, name: String, create: Bool = true, install: Bool = true, uuid: Foundation.UUID = fixedAnnotationID) throws {
        path = root.appendingPathComponent(name + ".sqlite")
        db = try SQLiteDatabase(path: path.path)
        ledger = AnnotationExchangeLedger(database: db, digest: AcceptanceDigest())
        queue = SyncPendingStore(database: db)
        self.uuid = uuid
        if create {
            // Owned fixture mirrors all original annotation/tag columns and
            // indexes. AnnotationRepository/UI/CloudKit runtime is not mocked
            // into a claim of execution: only its real SQLite/queue seam runs.
            let statements = [
                """
                CREATE TABLE annotations (
                    id INTEGER PRIMARY KEY AUTOINCREMENT, bkId INTEGER, contentId INTEGER,
                    startIndex INTEGER, length INTEGER, startIndexDiac INTEGER, lengthDiac INTEGER,
                    color TEXT, type INTEGER, note TEXT, createdAt INTEGER, context TEXT,
                    part INTEGER, page INTEGER, ckRecordId TEXT, lastModified INTEGER, backendLocator TEXT
                );
                """,
                "CREATE INDEX idx_ann_bk_content ON annotations (bkId, contentId);",
                "CREATE INDEX idx_ann_ck_record_id ON annotations (ckRecordId);",
                "CREATE TABLE tags (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, normalizedName TEXT UNIQUE);",
                "CREATE TABLE annotation_tags (annotationId INTEGER, tagId INTEGER);",
                "CREATE UNIQUE INDEX idx_ann_tag_ids ON annotation_tags(annotationId, tagId);"
            ]
            try db.transaction {
                for sql in statements { try db.execute(query: sql) }
                try queue.createTable()
                try db.execute(query: """
                    INSERT INTO annotations (id,bkId,contentId,startIndex,length,startIndexDiac,lengthDiac,color,type,note,createdAt,context,part,page,ckRecordId,lastModified,backendLocator)
                    VALUES (1,2,3,4,5,6,7,'#FFFF00',1,?,1700000000,'מקור exact',1,9,?,1700000001,?);
                    """, parameters: ["הערה <b>original</b>", uuid.uuidString, "{\"backend\":\"fixture-original\",\"opaque\":\"9:1\"}"])
                try db.execute(query: "INSERT INTO tags(id,name,normalizedName) VALUES (1,'עיון','עיון');")
                try db.execute(query: "INSERT INTO annotation_tags(annotationId,tagId) VALUES (1,1);")
                try queue.addPendingSync(ckRecordId: uuid.uuidString, operation: "upload")
                try queue.addPendingSync(ckRecordId: "unrelated-deletion", operation: "delete")
                try queue.addPendingSync(ckRecordId: "unrelated-deletion", operation: "upload")
            }
            if install { try ledger.installSchema() }
        }
    }

    func witness() throws -> AnnotationExchangeSourceWitness { try ledger.captureSource(annotationUUID: uuid) }

    func payload(_ witness: AnnotationExchangeSourceWitness? = nil, preview: String = "תצוגה בלבד", rich: Data? = nil,
                 state: TorahAnnotationEnvelope.DeletionState = .active, extra: Bool = false) throws -> Data {
        let source = try witness ?? self.witness()
        let body = state == .active ? TorahAnnotationEnvelope.RichBody(
            format: "org.otzaria.test-opaque", formatVersion: 1,
            bytes: rich ?? Data([0, 255, 1, 10] + Array("שלום <strong>Rich</strong>".utf8))) : nil
        let encoded = try TorahAnnotationEnvelopeCodec.encode(.init(namespace: namespace, annotationUUID: uuid,
            originatingApp: "otzaria", source: source.metadata, richBody: body,
            textPreview: state == .tombstone ? "" : preview,
            editorRevision: "opaque-editor-rev", title: "כותרת", deletionState: state))
        guard extra else { return encoded }
        var object = try ActionWireCodec.decodeObject(encoded)
        object["futureMetadata"] = .object(["keepExact": .string("שלום unknown"), "number": .unsigned(UInt64.max)])
        return try AnnotationExchangeValidation.canonical(.object(object))
    }

    func commit(_ mutation: Foundation.UUID = Foundation.UUID(), expectedRevision: Int64 = 0,
                destinations: [AnnotationExchangeDestination]? = nil,
                preview: String = "תצוגה בלבד") throws -> AnnotationExchangeCommit {
        let source = try witness()
        return try ledger.commit(mutationID: mutation, payload: payload(source, preview: preview), expectedSource: source,
            expectedRevision: expectedRevision, destinations: destinations ?? [scope()])
    }

    func scalar(_ sql: String, _ parameters: [Any] = []) throws -> Int64 {
        try db.fetch(query: sql, parameters: parameters) { $0.int64(at: 0) }.first ?? -1
    }

    func originals() throws -> Data {
        let columns = [
            "annotations": ["id","bkId","contentId","startIndex","length","startIndexDiac","lengthDiac","color","type","note","createdAt","context","part","page","ckRecordId","lastModified","backendLocator"],
            "tags": ["id","name","normalizedName"],
            "annotation_tags": ["annotationId","tagId"],
            "sync_pending": ["ck_record_id","operation","queued_at"]
        ]
        var values: [String: [[String]]] = [:]
        for (table, fields) in columns {
            let projection = fields.flatMap { ["typeof(\($0))", "hex(CAST(\($0) AS BLOB))"] }.joined(separator: ",")
            values[table] = try db.fetch(query: "SELECT \(projection) FROM \(table) ORDER BY \(fields.joined(separator: ","));") { row in
                (0..<row.columnCount).map { row.string(at: $0) ?? "<SQL NULL>" }
            }
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(values)
    }

    func cloudRows() throws -> Data {
        let rows = try db.fetch(query: """
            SELECT hex(CAST(ck_record_id AS BLOB)),hex(CAST(operation AS BLOB)),typeof(queued_at),hex(CAST(queued_at AS BLOB))
            FROM sync_pending ORDER BY ck_record_id;
            """) { row in (0..<row.columnCount).map { row.string(at: $0) ?? "<NULL>" } }
        return try JSONEncoder().encode(rows)
    }
}

func ack(_ delivery: AnnotationExchangeDelivery, destination: AnnotationExchangeDestination? = nil,
         messageID: Foundation.UUID? = nil, uuid: Foundation.UUID? = nil, revision: Int64? = nil, digest: String? = nil,
         envelopeNamespace: String? = nil) -> AnnotationExchangeAcknowledgement {
    .init(messageID: messageID ?? delivery.messageID, destination: destination ?? delivery.destination,
          namespace: envelopeNamespace ?? delivery.namespace, annotationUUID: uuid ?? delivery.annotationUUID,
          revision: revision ?? delivery.revision, payloadDigest: digest ?? delivery.payloadDigest)
}

func abruptlyTerminate() -> Never {
    #if os(Windows)
    TerminateProcess(GetCurrentProcess(), 73)
    #else
    _exit(73)
    #endif
    fatalError("termination returned")
}

struct CrashReceipt: Codable {
    let phase: String
    let mutationID: Foundation.UUID
    let messageID: Foundation.UUID
    let payloadBase64: String
    let payloadDigest: String
    let originalsBase64: String
    let cloudRowsBase64: String
}

func writeCrashReceipt(_ fixture: Fixture, phase: String, commit: AnnotationExchangeCommit,
                       originals: Data, cloudRows: Data, root: URL) throws {
    let delivery = commit.deliveries[0]
    let receipt = CrashReceipt(phase: phase, mutationID: commit.mutationID, messageID: delivery.messageID,
        payloadBase64: delivery.payload.base64EncodedString(), payloadDigest: delivery.payloadDigest,
        originalsBase64: originals.base64EncodedString(), cloudRowsBase64: cloudRows.base64EncodedString())
    let path = root.appendingPathComponent("crash-\(phase).json")
    try JSONEncoder().encode(receipt).write(to: path, options: .atomic)
    let handle = try FileHandle(forWritingTo: path); try handle.synchronize(); try handle.close()
}
