import Foundation
import SQLite3

/// Downstream boundary for the original Maktabah updater. Validation never creates a database.
enum MaktabahBookUpdateSafety {
    struct Context: Equatable, Sendable {
        let generation: UInt64
        let main: String
        let special: String
        let archives: String
    }

    @TaskLocal static var operationContext: Context?

    enum Failure: LocalizedError {
        case unsupportedBackend, missingFile, incompatibleSchema, changedLibrary, invalidArchive, malformedCatalog, insufficientSpace

        var errorDescription: String? {
            switch self {
            case .unsupportedBackend: "Maktabah Books Updates is unavailable for this library source. Its update catalog is not compatible with the selected library."
            case .missingFile: "The required update database is missing or inaccessible. No database was created."
            case .incompatibleSchema: "This library does not support Maktabah book updates."
            case .changedLibrary: "The library changed during the update. Reopen Books Updates before continuing."
            case .invalidArchive: "The book archive or search database is not compatible with this update."
            case .malformedCatalog: "The book update catalog contains an invalid row. No updates were applied."
            case .insufficientSpace: "There is not enough available storage to safely stage these book updates."
            }
        }
    }

    static func canonical(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
    }

    /// Requires SQLITE_OPEN_URI on the host connection; mode=rw/ro cannot create a missing attachment.
    static func existingDatabaseURI(path: String, readOnly: Bool = false) -> String {
        URL(fileURLWithPath: canonical(path)).absoluteString + (readOnly ? "?mode=ro" : "?mode=rw")
    }

    /// Consumes the caller's connection on both success and failure. SQLite owns
    /// WAL/SHM cleanup: a busy checkpoint must never be followed by file deletion.
    /// This preserves recovery data; it does not make separate commits atomic.
    static func checkpointAndClose(_ db: OpaquePointer, schemas: [String] = ["main", "fts_db"]) throws {
        defer { sqlite3_close_v2(db) }
        for schema in schemas {
            let rc = sqlite3_wal_checkpoint_v2(db, schema, SQLITE_CHECKPOINT_TRUNCATE, nil, nil)
            guard rc == SQLITE_OK else {
                let detail = String(cString: sqlite3_errmsg(db))
                throw NSError(domain: "MaktabahBookUpdateRecovery", code: Int(rc), userInfo: [
                    NSLocalizedDescriptionKey: "Unable to checkpoint book update database \(schema) (SQLite \(rc): \(detail)). Recovery files were preserved.",
                ])
            }
        }
    }

    /// Strict CSV decoding lives downstream; the original parser discards escaped quotes
    /// and accepts quotes in unquoted fields. Reject a malformed batch before staging.
    static func catalogRows(_ csv: String) throws -> [[String]] {
        guard csv.utf8.count <= 8 * 1024 * 1024 else { throw Failure.malformedCatalog }
        enum State { case start, unquoted, quoted, closed }
        var state = State.start
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        let input = csv.hasPrefix("\u{FEFF}") ? csv.dropFirst() : csv[...]
        for char in input {
            guard char != "\0" else { throw Failure.malformedCatalog }
            if state == .quoted {
                if char == "\"" { state = .closed } else { field.append(char) }
                continue
            }
            if state == .closed, char == "\"" {
                field.append("\"")
                state = .quoted
                continue
            }
            switch char {
            case ";":
                row.append(field); field = ""; state = .start
            case "\n", "\r\n", "\r":
                row.append(field)
                rows.append(row)
                guard rows.count <= 100_000 else { throw Failure.malformedCatalog }
                row = []; field = ""; state = .start
            case "\"":
                guard state == .start else { throw Failure.malformedCatalog }
                state = .quoted
            default:
                guard state != .closed else { throw Failure.malformedCatalog }
                field.append(char)
                state = .unquoted
            }
        }
        guard state != .quoted else { throw Failure.malformedCatalog }
        if !row.isEmpty || !field.isEmpty || state == .closed {
            row.append(field)
            rows.append(row)
        }
        guard rows.count <= 100_000 else { throw Failure.malformedCatalog }
        return rows
    }

    static func validateCatalogText(_ csv: String) throws {
        _ = try catalogRows(csv)
    }

    static func validateCatalogIDs(_ rows: [[String]]) throws {
        var seen = Set<Int>()
        for row in rows where !row.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            guard let first = row.first, let id = Int(first), id > 0,
                  seen.insert(id).inserted else { throw Failure.malformedCatalog }
        }
    }

    private static func validDownloadID(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.allSatisfy {
            (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95
        }
    }

    static func validateAuthorCatalogRow(_ columns: [String]) throws {
        guard columns.count == 3, let id = Int(columns[0]), id > 0,
              let version = Int64(columns[1]), version >= 0,
              validDownloadID(columns[2]) else { throw Failure.malformedCatalog }
    }

    static func validateStagingCapacity(requiredBytes: Int64, availableBytes: Int64) throws {
        let (copies, overflow) = requiredBytes.multipliedReportingOverflow(by: 3)
        let (budget, overheadOverflow) = copies.addingReportingOverflow(64 * 1024 * 1024)
        guard requiredBytes >= 0, !overflow, !overheadOverflow, availableBytes >= budget else { throw Failure.insufficientSpace }
    }

    static func validateBookIdentity(expected: Int, actual: Int, archive: Int) throws {
        guard expected > 0, actual == expected, archive > 0 else { throw Failure.incompatibleSchema }
    }

    static func validateCatalogRow(_ columns: [String]) throws {
        guard columns.count == 6,
              let id = Int(columns[0]), id > 0,
              let category = Int(columns[1]), category >= 0,
              let version = Int64(columns[2]), version >= 0,
              validDownloadID(columns[3]),
              let size = Int64(columns[4]), size >= 0,
              !columns[5].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw Failure.malformedCatalog }
    }

    /// Pure validation entry also used by disposable fixtures; no installed-data discovery.
    static func validateLibrary(backend: String?, main: String?, special: String?) throws {
        guard backend == "maktabah" else { throw Failure.unsupportedBackend }
        guard let main, let special, canonical(main) != canonical(special) else { throw Failure.missingFile }
        try requireColumns(path: main, table: "0bok", columns: [
            "bkid", "cat", "bk", "archive", "betaka", "authno", "inf", "tafseernam", "bver", "pdfcs",
        ])
        try requireColumns(path: special, table: "Auth", columns: ["authid", "auth", "inf", "lng", "higrid", "over"])
    }

    static func openReadOnly(path: String) throws -> OpaquePointer {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue,
              FileManager.default.isReadableFile(atPath: path) else { throw Failure.missingFile }
        var db: OpaquePointer?
        let rc = sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil)
        guard rc == SQLITE_OK, let db else {
            if let db { sqlite3_close_v2(db) }
            throw Failure.missingFile
        }
        return db
    }

    static func requireColumns(path: String, table: String, columns: Set<String>) throws {
        let db = try openReadOnly(path: path)
        defer { sqlite3_close_v2(db) }
        // Identifiers come from this adapter/sqlite_master, never from a catalog row.
        guard table.range(of: "^[A-Za-z0-9_]+$", options: .regularExpression) != nil else { throw Failure.incompatibleSchema }
        var kind: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT 1 FROM sqlite_master WHERE type='table' AND name=? COLLATE NOCASE", -1, &kind, nil) == SQLITE_OK,
              let kind else { throw Failure.incompatibleSchema }
        defer { sqlite3_finalize(kind) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        _ = table.withCString { sqlite3_bind_text(kind, 1, $0, -1, transient) }
        guard sqlite3_step(kind) == SQLITE_ROW else { throw Failure.incompatibleSchema }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA table_info('\(table)')", -1, &statement, nil) == SQLITE_OK,
              let statement else { throw Failure.incompatibleSchema }
        defer { sqlite3_finalize(statement) }
        var actual = Set<String>()
        var rc = sqlite3_step(statement)
        while rc == SQLITE_ROW {
            if let text = sqlite3_column_text(statement, 1) { actual.insert(String(cString: text).lowercased()) }
            rc = sqlite3_step(statement)
        }
        guard rc == SQLITE_DONE, columns.isSubset(of: actual) else { throw Failure.incompatibleSchema }
    }

    private static func requireFTS5(path: String, table: String) throws {
        let db = try openReadOnly(path: path)
        defer { sqlite3_close_v2(db) }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT sql FROM sqlite_master WHERE type='table' AND name=?", -1, &stmt, nil) == SQLITE_OK,
              let stmt else { throw Failure.invalidArchive }
        defer { sqlite3_finalize(stmt) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        _ = table.withCString { sqlite3_bind_text(stmt, 1, $0, -1, transient) }
        guard sqlite3_step(stmt) == SQLITE_ROW, let sql = sqlite3_column_text(stmt, 0),
              String(cString: sql).range(of: "(?i)\\busing\\s+fts5\\s*\\(", options: .regularExpression) != nil else { throw Failure.invalidArchive }
    }

    static func validateArchive(path: String, ftsPath: String) throws {
        guard canonical(path) != canonical(ftsPath) else { throw Failure.invalidArchive }
        for (target, isFTS) in [(path, false), (ftsPath, true)] {
            let db = try openReadOnly(path: target)
            defer { sqlite3_close_v2(db) }
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, "SELECT name FROM sqlite_master WHERE type='table'", -1, &stmt, nil) == SQLITE_OK,
                  let stmt else { throw Failure.invalidArchive }
            defer { sqlite3_finalize(stmt) }
            var names = Set<String>()
            var rc = sqlite3_step(stmt)
            while rc == SQLITE_ROW {
                if let text = sqlite3_column_text(stmt, 0) { names.insert(String(cString: text)) }
                rc = sqlite3_step(stmt)
            }
            guard rc == SQLITE_DONE else { throw Failure.invalidArchive }
            let compatible: Bool
            if isFTS {
                compatible = names.contains("archive_index") && names.contains("archive_fts")
                    || names.contains { $0.range(of: "^b[0-9]+_fts$", options: .regularExpression) != nil }
            } else {
                compatible = names.contains { name in
                    name.range(of: "^b[0-9]+$", options: .regularExpression) != nil
                        && names.contains("t" + name.dropFirst())
                }
            }
            guard compatible else { throw Failure.invalidArchive }
            if isFTS {
                if names.contains("archive_index"), names.contains("archive_fts") {
                    try requireColumns(path: target, table: "archive_index", columns: ["rowid", "book_id", "page", "id", "part"])
                    try requireColumns(path: target, table: "archive_fts", columns: ["nass_clean"])
                    try requireFTS5(path: target, table: "archive_fts")
                } else if let legacy = names.sorted().first(where: { $0.range(of: "^b[0-9]+_fts$", options: .regularExpression) != nil }) {
                    try requireColumns(path: target, table: legacy, columns: ["nass_clean"])
                    try requireFTS5(path: target, table: legacy)
                }
            } else if let book = names.sorted().first(where: { $0.range(of: "^b[0-9]+$", options: .regularExpression) != nil && names.contains("t" + $0.dropFirst()) }) {
                try requireColumns(path: target, table: book, columns: ["nass", "part", "id", "page"])
                try requireColumns(path: target, table: "t" + book.dropFirst(), columns: ["tit", "lvl", "sub", "id"])
            }
        }
    }

    #if !HQ_UPDATES_FIXTURE
    /// Exhaustive on purpose: adding a backend must not opt it into a foreign
    /// catalog based on a saved raw string or usesNativeMaktabahDataPath.
    static func supportsLegacyUpdates(_ backend: BackendID) -> Bool {
        switch backend {
        case .otzaria, .sefaria, .sefariaEmbedded: false
        }
    }

    @MainActor
    static var isMaktabahActive: Bool {
        // Otzaria also uses the legacy data path. That flag is not update ownership.
        // Current downstream-only BackendID cases intentionally all fail this gate.
        supportsLegacyUpdates(BackendCoordinator.shared.activeBackendID) && !BackendCoordinator.shared.isTransitioning
    }

    static func preflight() async throws -> Context {
        let context = try await MainActor.run {
            guard isMaktabahActive else { throw Failure.unsupportedBackend }
            guard let main = AppConfig.mainDatabasePath, let special = AppConfig.specialDatabasePath,
                  let archives = AppConfig.archiveFilesPath else { throw Failure.missingFile }
            return Context(generation: BackendCoordinator.shared.generation,
                           main: canonical(main), special: canonical(special), archives: canonical(archives))
        }
        try requireCurrent(context)
        return context
    }

    static func revalidate(_ context: Context) async throws {
        guard try await preflight() == context else { throw Failure.changedLibrary }
    }

    /// Synchronous check used immediately before original SQL opens/mutations.
    static func requireCurrent(_ expected: Context? = operationContext) throws {
        let backend = UserDefaults.standard.string(forKey: BackendCoordinator.selectionDefaultsKey)
        guard let backend, let identity = BackendID(rawValue: backend), supportsLegacyUpdates(identity) else {
            throw Failure.unsupportedBackend
        }
        try validateLibrary(backend: backend, main: AppConfig.mainDatabasePath, special: AppConfig.specialDatabasePath)
        if let expected {
            guard AppConfig.mainDatabasePath.map(canonical) == expected.main,
                  AppConfig.specialDatabasePath.map(canonical) == expected.special,
                  AppConfig.archiveFilesPath.map(canonical) == expected.archives else { throw Failure.changedLibrary }
        }
    }

    static func requireExistingWritableFile(_ path: String) throws {
        try requireCurrent()
        let db = try openReadOnly(path: path)
        sqlite3_close_v2(db)
        guard FileManager.default.isWritableFile(atPath: path) else { throw Failure.missingFile }
    }

    static func requireStagingCapacity(_ requiredBytes: Int64) throws {
        try requireCurrent()
        guard let main = AppConfig.mainDatabasePath, let special = AppConfig.specialDatabasePath,
              FileManager.default.isWritableFile(atPath: main), FileManager.default.isWritableFile(atPath: special) else { throw Failure.missingFile }
        let parent = URL(fileURLWithPath: main).deletingLastPathComponent().path
        let attributes = try FileManager.default.attributesOfFileSystem(forPath: parent)
        guard let free = attributes[.systemFreeSize] as? NSNumber else { throw Failure.insufficientSpace }
        try validateStagingCapacity(requiredBytes: requiredBytes, availableBytes: free.int64Value)
    }

    static func requireArchive(_ archiveID: Int) throws {
        try requireCurrent()
        guard archiveID > 0, let archive = AppConfig.archiveDatabasePath(archiveId: archiveID),
              let fts = AppConfig.archiveFtsDatabasePath(archiveId: archiveID) else { throw Failure.invalidArchive }
        try validateArchive(path: archive, ftsPath: fts)
    }
    #endif
}
