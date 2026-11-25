import Foundation
import SQLite3
import OtzariaActionCore

let budgetSeedNames = ["legacy-read", "upgrade", "raw-preservation", "outer-rollback",
    "cas-rollback", "denied-write", "cancelled-migration", "future", "partial",
    "altered", "user-index", "trigger", "external-reference", "scratch-collision",
    "temp-shadow", "incoming-upgrade"]

func storageVersion(_ fixture: Fixture) throws -> Int64 {
    try fixture.scalar("SELECT version FROM otzaria_annotation_exchange_schema;")
}

func databaseRows(_ fixture: Fixture, exceptStorageVersion: Bool = false) throws -> Data {
    let names = try fixture.db.fetch(query: "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;") {
        $0.string(at: 0)!
    }
    var all: [String: [[String]]] = [:]
    for name in names {
        let columns = try fixture.db.fetch(query: "PRAGMA main.table_info('\(name)');") { $0.string(at: 1)! }
            .filter { !(exceptStorageVersion && name == "otzaria_annotation_exchange_schema" && $0 == "version") }
        let projection = (["rowid"] + columns).flatMap { ["typeof(\($0))", "hex(CAST(\($0) AS BLOB))"] }
            .joined(separator: ", ")
        all[name] = try fixture.db.fetch(query: "SELECT \(projection) FROM main.\(name) ORDER BY rowid;") {
            row in (0..<row.columnCount).map { row.string(at: $0) ?? "<NULL>" }
        }
    }
    return try AnnotationExchangeValidation.canonical(.object(
        all.mapValues { .array($0.map { .array($0.map(ActionJSON.string)) }) }))
}

func schemaBytes(_ fixture: Fixture) throws -> Data {
    let rows = try fixture.db.fetch(query: """
        SELECT type,name,tbl_name,sql FROM sqlite_master ORDER BY type,name;
        """) { row in
            (0..<row.columnCount).map { row.string(at: $0) ?? "<NULL>" }
        }
    return try JSONEncoder().encode(rows)
}

func exactEnvelope(_ fixture: Fixture, byteCount: Int) throws -> Data {
    var object = try AnnotationEnvelopeJSONCodec.decodeObject(fixture.payload())
    object["privateOriginalMetadata"] = .string("")
    let empty = try AnnotationExchangeValidation.canonical(.object(object))
    guard byteCount >= empty.count else { throw CheckFailure("bad exact-size fixture") }
    object["privateOriginalMetadata"] = .string(String(repeating: "p", count: byteCount - empty.count))
    let bytes = try AnnotationExchangeValidation.canonical(.object(object))
    try require(bytes.count == byteCount, "whole envelope fixture size mismatch")
    return bytes
}

func denyOriginalVersionInsert(_ context: UnsafeMutableRawPointer?, _ action: Int32,
    _ first: UnsafePointer<CChar>?, _ second: UnsafePointer<CChar>?,
    _ database: UnsafePointer<CChar>?, _ trigger: UnsafePointer<CChar>?) -> Int32 {
    if action == SQLITE_INSERT, let first,
       String(cString: first) == "otzaria_annotation_exchange_versions" { return SQLITE_DENY }
    return SQLITE_OK
}

func cancelOnOriginalSchemaDrop(_ context: UnsafeMutableRawPointer?, _ action: Int32,
    _ first: UnsafePointer<CChar>?, _ second: UnsafePointer<CChar>?,
    _ database: UnsafePointer<CChar>?, _ trigger: UnsafePointer<CChar>?) -> Int32 {
    if action == SQLITE_DROP_TABLE, let first,
       String(cString: first) == "otzaria_annotation_exchange_schema" {
        context?.assumingMemoryBound(to: Int32.self).pointee += 1
        withUnsafeCurrentTask { $0?.cancel() }
    }
    return SQLITE_OK
}
