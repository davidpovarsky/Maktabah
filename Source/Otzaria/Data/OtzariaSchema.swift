import Foundation
import SQLite3

enum OtzariaSchema {
    enum Table {
        static let category = "category"
        static let categoryClosure = "category_closure"
        static let book = "book"
        static let source = "source"
        static let author = "author"
        static let bookAuthor = "book_author"
        static let topic = "topic"
        static let bookTopic = "book_topic"
        static let generation = "generation"
        static let bookGeneration = "book_generation"
        static let bookBaseText = "book_base_text"
        static let pubPlace = "pub_place"
        static let bookPubPlace = "book_pub_place"
        static let pubDate = "pub_date"
        static let bookPubDate = "book_pub_date"
        static let line = "line"
        static let lineContent = "line_content"
        static let zstdDictionary = "zstd_dict"
        static let lineReference = "line_ref"
        static let lineDiburHamatchil = "line_dh"
        static let tocEntry = "tocEntry"
        static let tocText = "tocText"
        static let lineTOC = "line_toc"
        static let link = "link"
        static let connectionType = "connection_type"
        static let linkAnchor = "link_anchor"
        static let linkRange = "link_range"
        static let linkCoverage = "link_coverage"
        static let linkSuppressedSide = "link_suppressed_side"
        static let bookHasLinks = "book_has_links"
        static let externalLink = "external_link"
        static let bookAcronym = "book_acronym"
        static let alternateTOCStructure = "alt_toc_structure"
        static let alternateTOCEntry = "alt_toc_entry"
        static let lineAlternateTOC = "line_alt_toc"
        static let defaultCommentator = "default_commentator"
        static let defaultTargum = "default_targum"
        static let bookVersion = "book_version"
        static let versionLine = "version_line"
        static let schemaMetadata = "schema_meta"
        static let databaseMetadata = "db_meta"
    }

    static let knownTables: Set<String> = [
        Table.category, Table.categoryClosure, Table.book, Table.source,
        Table.author, Table.bookAuthor, Table.topic, Table.bookTopic,
        Table.generation, Table.bookGeneration, Table.bookBaseText,
        Table.pubPlace, Table.bookPubPlace, Table.pubDate, Table.bookPubDate,
        Table.line, Table.lineContent, Table.zstdDictionary,
        Table.lineReference, Table.lineDiburHamatchil, Table.tocText,
        Table.tocEntry, Table.lineTOC, Table.connectionType, Table.link,
        Table.linkAnchor, Table.linkRange, Table.linkCoverage,
        Table.linkSuppressedSide, Table.bookHasLinks, Table.externalLink,
        Table.bookAcronym, Table.alternateTOCStructure, Table.alternateTOCEntry,
        Table.lineAlternateTOC, Table.defaultCommentator, Table.defaultTargum,
        Table.bookVersion, Table.versionLine, Table.schemaMetadata,
        Table.databaseMetadata
    ]

    static let requiredTables: Set<String> = [
        Table.category,
        Table.book,
        Table.line,
        Table.tocEntry,
        Table.tocText,
        Table.link,
        Table.connectionType
    ]
}

struct OtzariaDatabaseCapabilities: Equatable, Sendable {
    let tables: Set<String>
    let columns: [String: Set<String>]
    let indexes: Set<String>
    let userVersion: Int
    let schemaMetadata: [String: String]
    let databaseMetadata: [String: String]

    func hasTable(_ name: String) -> Bool { tables.contains(name.lowercased()) }
    func hasColumn(_ name: String, in table: String) -> Bool {
        columns[table.lowercased()]?.contains(name.lowercased()) == true
    }
    func hasIndex(_ name: String) -> Bool { indexes.contains(name.lowercased()) }

    var hasSplitLineContent: Bool {
        hasTable(OtzariaSchema.Table.lineContent)
            && !hasColumn("content", in: OtzariaSchema.Table.line)
    }
    var hasZstdDictionaries: Bool { hasTable(OtzariaSchema.Table.zstdDictionary) }
    var hasLinkRanges: Bool {
        hasTable(OtzariaSchema.Table.linkRange) && hasTable(OtzariaSchema.Table.linkCoverage)
    }
    var hasSuppressedLinkSides: Bool { hasTable(OtzariaSchema.Table.linkSuppressedSide) }
    var hasAlternateTOC: Bool {
        hasTable(OtzariaSchema.Table.alternateTOCStructure)
            && hasTable(OtzariaSchema.Table.alternateTOCEntry)
    }
    var hasVersions: Bool {
        hasTable(OtzariaSchema.Table.bookVersion) && hasTable(OtzariaSchema.Table.versionLine)
    }

    init(database: OpaquePointer) throws {
        var tables = Set<String>()
        var indexes = Set<String>()
        let objects = try OtzariaSQLiteStatement(database: database, sql: """
            SELECT type, name, COALESCE(sql, '')
            FROM sqlite_master
            WHERE type IN ('table', 'index')
        """)
        while try objects.step() {
            guard let type = objects.columnString(0), let name = objects.columnString(1) else { continue }
            let normalized = name.lowercased()
            if type == "index" {
                indexes.insert(normalized)
            } else if !(objects.columnString(2) ?? "").uppercased().hasPrefix("CREATE VIRTUAL") {
                tables.insert(normalized)
            }
        }

        var columns: [String: Set<String>] = [:]
        for table in OtzariaSchema.knownTables where tables.contains(table.lowercased()) {
            let escaped = table.replacingOccurrences(of: "'", with: "''")
            let info = try OtzariaSQLiteStatement(
                database: database,
                sql: "PRAGMA table_xinfo('\(escaped)')"
            )
            while try info.step() {
                if let name = info.columnString(1) {
                    columns[table.lowercased(), default: []].insert(name.lowercased())
                }
            }
        }

        self.tables = tables
        self.columns = columns
        self.indexes = indexes
        self.userVersion = Self.scalarInt(database: database, sql: "PRAGMA user_version") ?? 0
        self.schemaMetadata = try Self.metadata(database: database, table: OtzariaSchema.Table.schemaMetadata)
        self.databaseMetadata = try Self.metadata(database: database, table: OtzariaSchema.Table.databaseMetadata)
    }

    init(database: SQLiteDatabase) throws {
        try self.init(database: database.dbPointer)
    }

    var diagnostics: [String] {
        var result: [String] = []
        if hasSplitLineContent && !hasZstdDictionaries {
            result.append("split line_content is present without zstd_dict; only TEXT rows can be decoded")
        }
        if hasTable(OtzariaSchema.Table.linkRange) != hasTable(OtzariaSchema.Table.linkCoverage) {
            result.append("link_range and link_coverage must be treated as one capability")
        }
        if hasTable(OtzariaSchema.Table.bookVersion) != hasTable(OtzariaSchema.Table.versionLine) {
            result.append("book_version and version_line must be treated as one capability")
        }
        return result
    }

    private static func scalarInt(database: OpaquePointer, sql: String) -> Int? {
        guard let statement = try? OtzariaSQLiteStatement(database: database, sql: sql),
              (try? statement.step()) == true else { return nil }
        return statement.columnInt(0)
    }

    private static func metadata(database: OpaquePointer, table: String) throws -> [String: String] {
        let exists = try OtzariaSQLiteStatement(
            database: database,
            sql: "SELECT 1 FROM sqlite_master WHERE type='table' AND lower(name)=lower(?) LIMIT 1"
        )
        try exists.bind(table, at: 1)
        guard try exists.step() else { return [:] }
        let values = try OtzariaSQLiteStatement(database: database, sql: "SELECT key, value FROM \(table)")
        var result: [String: String] = [:]
        while try values.step() {
            if let key = values.columnString(0), let value = values.columnString(1) {
                result[key] = value
            }
        }
        return result
    }
}

struct OtzariaSchemaValidator {
    static func validate(_ db: OpaquePointer) throws {
        let statement = try OtzariaSQLiteStatement(database: db, sql: """
            SELECT name
            FROM sqlite_master
            WHERE type = 'table'
        """)

        var existing = Set<String>()
        while try statement.step() {
            if let name = statement.columnString(0) {
                existing.insert(name)
            }
        }

        let missing = OtzariaSchema.requiredTables.subtracting(existing).sorted()
        if !missing.isEmpty {
            throw OtzariaSQLiteError.schemaMismatch(missingTables: missing)
        }

        _ = try OtzariaDatabaseCapabilities(database: db)
    }
}
