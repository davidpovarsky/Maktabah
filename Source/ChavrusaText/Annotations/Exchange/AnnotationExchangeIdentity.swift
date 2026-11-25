import Foundation
import SQLite3

/// The original CloudKit record name stays authoritative and unchanged.
/// Legacy aliases are installed only by an explicit migration transaction;
/// lookup, construction, editor inspection and cancellation never create them.
enum AnnotationExchangeIdentity {
    static let migrationNamespace = "otzaria.annotation.backfill.v1"

    private static let table = "otzaria_annotation_exchange_legacy_identities"
    private static let createSQL = """
        CREATE TABLE otzaria_annotation_exchange_legacy_identities (
            original_record_id TEXT PRIMARY KEY NOT NULL CHECK(typeof(original_record_id) = 'text' AND length(CAST(original_record_id AS BLOB)) BETWEEN 1 AND 512 AND instr(original_record_id, char(0)) = 0),
            annotation_uuid TEXT NOT NULL UNIQUE CHECK(typeof(annotation_uuid) = 'text' AND length(CAST(annotation_uuid AS BLOB)) = 36),
            mapping_version INTEGER NOT NULL CHECK(typeof(mapping_version) = 'integer' AND mapping_version = 1)
        )
        """

    /// Resolves an existing UUID or a previously registered legacy alias.
    /// An unregistered, well-formed legacy record returns nil without any DDL.
    static func resolve(
        database: SQLiteDatabase, annotationID: Int64, originalRecordID: String?
    ) throws -> UUID? {
        try Task.checkCancellation()
        var result: UUID?
        try database.transaction {
            let record = try requireSource(database, annotationID: annotationID, originalRecordID: originalRecordID)
            guard let record else { return }
            let installed = try hasMappingSchema(database)
            if let uuid = originalUUID(record) {
                if installed {
                    guard try aliases(database, uuid: uuid).isEmpty else {
                        throw AnnotationExchangeError.ambiguousSource
                    }
                }
                result = uuid
            } else {
                let expected = try legacyUUID(record)
                guard installed else { return }
                let rows = try aliases(database, record: record)
                guard rows.count <= 1 else { throw AnnotationExchangeError.ambiguousSource }
                guard let row = rows.first else { return }
                guard row.uuid == expected, sameBytes(row.record, record),
                      (try aliases(database, uuid: expected)).count == 1 else {
                    throw AnnotationExchangeError.corruptRecord
                }
                guard try sourceRows(database, record: expected.uuidString).isEmpty else {
                    throw AnnotationExchangeError.ambiguousSource
                }
                result = expected
            }
            try Task.checkCancellation()
        }
        return result
    }

    /// The caller chooses the migration explicitly. Only this owned alias table
    /// is created/written. Original rows, tags, clocks and sync queues are untouched.
    /// Nested calls participate in the caller's original SQLite transaction.
    @discardableResult
    static func registerLegacy(
        database: SQLiteDatabase, annotationID: Int64, originalRecordID: String
    ) throws -> UUID {
        try Task.checkCancellation()
        let expected = try legacyUUID(originalRecordID)
        try database.transaction {
            _ = try requireSource(database, annotationID: annotationID, originalRecordID: originalRecordID)
            let installed = try hasMappingSchema(database)
            guard try sourceRows(database, record: expected.uuidString).isEmpty else {
                throw AnnotationExchangeError.ambiguousSource
            }
            if !installed {
                try database.execute(query: createSQL)
                guard try hasMappingSchema(database) else { throw AnnotationExchangeError.schemaMismatch }
            }
            let byRecord = try aliases(database, record: originalRecordID)
            let byUUID = try aliases(database, uuid: expected)
            guard byRecord.count <= 1, byUUID.count <= 1 else { throw AnnotationExchangeError.ambiguousSource }
            if let existing = byRecord.first {
                guard existing.uuid == expected, sameBytes(existing.record, originalRecordID),
                      byUUID.count == 1, sameBytes(byUUID[0].record, originalRecordID) else {
                    throw AnnotationExchangeError.ambiguousSource
                }
            } else {
                guard byUUID.isEmpty else { throw AnnotationExchangeError.ambiguousSource }
                try Task.checkCancellation()
                try database.execute(query: """
                    INSERT INTO main.\(table) (original_record_id, annotation_uuid, mapping_version)
                    VALUES (?, ?, 1);
                    """, parameters: [originalRecordID, expected.uuidString])
                guard sqlite3_changes64(database.dbPointer) == 1 else { throw AnnotationExchangeError.corruptRecord }
            }
            guard try resolve(database: database, annotationID: annotationID,
                              originalRecordID: originalRecordID) == expected else {
                throw AnnotationExchangeError.corruptRecord
            }
            try Task.checkCancellation()
        }
        return expected
    }

    /// Reverse lookup used by the exchange ledger. A removed source stays absent;
    /// the retained alias is never reused to invent an annotation or an ACK.
    static func originalRecordID(database: SQLiteDatabase, annotationUUID: UUID) throws -> String? {
        try Task.checkCancellation()
        var result: String?
        try database.transaction {
            try requireSourceSchema(database)
            let direct = try sourceRows(database, record: annotationUUID.uuidString)
            let mapped: [Alias]
            if try hasMappingSchema(database) { mapped = try aliases(database, uuid: annotationUUID) }
            else { mapped = [] }
            guard direct.count <= 1, mapped.count <= 1,
                  direct.count + mapped.count <= 1 else { throw AnnotationExchangeError.ambiguousSource }
            if let row = direct.first {
                guard let record = row.record, originalUUID(record) == annotationUUID else {
                    throw AnnotationExchangeError.corruptRecord
                }
                result = record
            } else if let alias = mapped.first {
                let rows = try sourceRows(database, record: alias.record)
                guard rows.count <= 1 else { throw AnnotationExchangeError.ambiguousSource }
                if let row = rows.first {
                    guard let record = row.record, sameBytes(record, alias.record) else {
                        throw AnnotationExchangeError.corruptRecord
                    }
                    result = record
                }
            }
            try Task.checkCancellation()
        }
        return result
    }

    private static func originalUUID(_ record: String) -> UUID? {
        guard record.utf8.count == 36, let value = UUID(uuidString: record),
              record.lowercased().utf8.elementsEqual(value.uuidString.lowercased().utf8) else { return nil }
        return value
    }

    /// Version 8 UUID, RFC variant, from the first 128 SHA-256 bits after
    /// domain separation. The exact CloudKit name, never a local row/profile ID,
    /// is the input, so independently migrated devices retain the same identity.
    private static func legacyUUID(_ record: String) throws -> UUID {
        let fields = record.split(separator: "_", omittingEmptySubsequences: false)
        guard fields.count == 5, fields[0] == "legacy",
              fields.dropFirst().allSatisfy({ field in
                  guard let value = Int64(field) else { return false }
                  return String(value).utf8.elementsEqual(field.utf8)
              }) else { throw AnnotationExchangeError.invalidScope }
        var input = Data((migrationNamespace + "\u{0}cloudkit-record-id\u{0}").utf8)
        input.append(contentsOf: record.utf8)
        let hash = try legacyDigest(input)
        guard AnnotationExchangeValidation.digest(hash) else { throw AnnotationExchangeError.corruptRecord }
        let hex = Array(hash.utf8)
        var bytes: [UInt8] = []
        for offset in stride(from: 0, to: 32, by: 2) {
            guard let value = UInt8(String(decoding: hex[offset..<(offset + 2)], as: UTF8.self), radix: 16) else {
                throw AnnotationExchangeError.corruptRecord
            }
            bytes.append(value)
        }
        bytes[6] = (bytes[6] & 0x0f) | 0x80
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    private static func legacyDigest(_ input: Data) throws -> String {
        #if canImport(CryptoKit)
        return AnnotationExchangePlatformDigest().sha256(input)
        #else
        // Native application migration requires the existing Apple digest.
        // Original portable UUID-only exchange controls remain read-only.
        throw AnnotationExchangeError.invalidScope
        #endif
    }

    private static func sameBytes(_ left: String, _ right: String) -> Bool {
        left.utf8.elementsEqual(right.utf8)
    }

    private static func text(_ row: SQLiteRow, _ column: Int32) throws -> String {
        guard row.type(at: column) == SQLITE_TEXT, let value = row.string(at: column),
              value.utf8.count == Int(sqlite3_column_bytes(row.stmt, column)),
              !value.utf8.contains(0) else { throw AnnotationExchangeError.corruptRecord }
        return value
    }

    private static func requireSourceSchema(_ database: SQLiteDatabase) throws {
        let temporary = try database.fetch(query: """
            SELECT name, tbl_name FROM sqlite_temp_master
            WHERE name COLLATE NOCASE IN (?, 'annotations') OR tbl_name COLLATE NOCASE IN (?, 'annotations');
            """, parameters: [table, table]) { (try text($0, 0), try text($0, 1)) }
        guard temporary.isEmpty else { throw AnnotationExchangeError.schemaMismatch }
        let source = try database.fetch(query: """
            SELECT name, type FROM main.sqlite_master WHERE name = 'annotations' COLLATE NOCASE;
            """) { (try text($0, 0), try text($0, 1)) }
        guard source.count == 1, source[0].0 == "annotations", source[0].1 == "table" else {
            throw AnnotationExchangeError.schemaMismatch
        }
        let columns = try database.fetch(query: "PRAGMA main.table_info(annotations);") {
            (try text($0, 1), try text($0, 2), $0.int64(at: 5))
        }
        let id = columns.filter { $0.0 == "id" }, record = columns.filter { $0.0 == "ckRecordId" }
        guard id.count == 1, id[0].1.uppercased() == "INTEGER", id[0].2 == 1,
              columns.filter({ $0.2 != 0 }).count == 1,
              record.count == 1, record[0].1.uppercased() == "TEXT" else {
            throw AnnotationExchangeError.schemaMismatch
        }
    }

    private struct SourceRow {
        let id: Int64
        let record: String?
    }

    private static func sourceRows(_ database: SQLiteDatabase, record: String) throws -> [SourceRow] {
        try database.fetch(query: """
            SELECT id, ckRecordId FROM main.annotations WHERE ckRecordId = ? COLLATE NOCASE;
            """, parameters: [record]) { row in
                guard row.type(at: 0) == SQLITE_INTEGER, row.int64(at: 0) > 0 else {
                    throw AnnotationExchangeError.corruptRecord
                }
                return SourceRow(id: row.int64(at: 0), record: row.isNull(at: 1) ? nil : try text(row, 1))
            }
    }

    private static func requireSource(
        _ database: SQLiteDatabase, annotationID: Int64, originalRecordID: String?
    ) throws -> String? {
        guard annotationID > 0 else { throw AnnotationExchangeError.missingSource }
        try requireSourceSchema(database)
        let rows = try database.fetch(query: "SELECT ckRecordId FROM main.annotations WHERE id = ?;",
                                      parameters: [annotationID]) { row -> String? in
            row.isNull(at: 0) ? nil : try text(row, 0)
        }
        guard rows.count == 1 else { throw AnnotationExchangeError.missingSource }
        guard rows[0].map({ Array($0.utf8) }) == originalRecordID.map({ Array($0.utf8) }) else {
            throw AnnotationExchangeError.staleSource
        }
        if let record = rows[0] {
            let matching = try sourceRows(database, record: record)
            guard matching.count == 1, matching[0].id == annotationID else {
                throw AnnotationExchangeError.ambiguousSource
            }
        }
        return rows[0]
    }

    private struct Alias {
        let record: String
        let uuid: UUID
    }

    private static func aliases(_ database: SQLiteDatabase, record: String) throws -> [Alias] {
        try aliases(database, predicate: "original_record_id = ? COLLATE NOCASE", parameter: record)
    }

    private static func aliases(_ database: SQLiteDatabase, uuid: UUID) throws -> [Alias] {
        try aliases(database, predicate: "annotation_uuid = ? COLLATE NOCASE", parameter: uuid.uuidString)
    }

    private static func aliases(_ database: SQLiteDatabase, predicate: String, parameter: String) throws -> [Alias] {
        try database.fetch(query: """
            SELECT original_record_id, annotation_uuid, mapping_version FROM main.\(table) WHERE \(predicate);
            """, parameters: [parameter]) { row in
                let original = try text(row, 0), rawUUID = try text(row, 1)
                guard row.type(at: 2) == SQLITE_INTEGER, row.int64(at: 2) == 1,
                      let uuid = UUID(uuidString: rawUUID), sameBytes(uuid.uuidString, rawUUID),
                      try legacyUUID(original) == uuid else { throw AnnotationExchangeError.corruptRecord }
                return Alias(record: original, uuid: uuid)
            }
    }

    private static func hasMappingSchema(_ database: SQLiteDatabase) throws -> Bool {
        let rows = try database.fetch(query: """
            SELECT name, type, tbl_name, sql FROM main.sqlite_master
            WHERE name COLLATE NOCASE = ? OR tbl_name COLLATE NOCASE = ?;
            """, parameters: [table, table]) { row in
                (try text(row, 0), try text(row, 1), try text(row, 2), row.isNull(at: 3) ? nil : try text(row, 3))
            }
        guard !rows.isEmpty else { return false }
        let actual = rows.filter { $0.0 == table }
        guard actual.count == 1, actual[0].1 == "table", actual[0].2 == table,
              actual[0].3 == createSQL else { throw AnnotationExchangeError.schemaMismatch }
        let indexes = rows.filter { $0.0 != table }
        let expected = Set(["sqlite_autoindex_\(table)_1", "sqlite_autoindex_\(table)_2"])
        guard indexes.count == 2, Set(indexes.map { $0.0 }) == expected,
              indexes.allSatisfy({ $0.1 == "index" && $0.2 == table && $0.3 == nil }) else {
            throw AnnotationExchangeError.schemaMismatch
        }
        return true
    }
}
