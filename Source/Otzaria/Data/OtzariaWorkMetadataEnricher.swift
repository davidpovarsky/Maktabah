import Foundation

struct OtzariaWorkMetadataEnricher: Sendable {
    var context: OtzariaSchemaAwareReadContext = .shared

    func metadata(for workKey: String, hebrew: Bool) async throws -> LibraryWorkMetadata? {
        try await context.read { database, capabilities in
            let bookID = try OtzariaCanonicalLineLocatorResolver.bookID(for: workKey, database: database, capabilities: capabilities)
            guard let base = try Self.baseMetadata(bookId: bookID, db: database) else { return nil }
            var fields = base.factualFields
            func append(key: String, he: String, en: String, tables: [String], query: String) throws {
                guard tables.allSatisfy(capabilities.hasTable) else { return }
                let values = try database.fetch(query: query, parameters: [bookID]) { $0.string(at: 0) ?? "" }.filter { !$0.isEmpty }
                guard !values.isEmpty else { return }
                fields.append(.init(key: key, label: hebrew ? he : en, value: values.joined(separator: ", ")))
            }
            try append(key: "publicationPlaces", he: "מקום פרסום", en: "Publication places", tables: ["pub_place", "book_pub_place"],
                query: "SELECT p.name FROM pub_place p JOIN book_pub_place bp ON bp.pubPlaceId = p.id WHERE bp.bookId = ? ORDER BY p.name")
            try append(key: "publicationDates", he: "תאריך פרסום", en: "Publication dates", tables: ["pub_date", "book_pub_date"],
                query: "SELECT p.date FROM pub_date p JOIN book_pub_date bp ON bp.pubDateId = p.id WHERE bp.bookId = ? ORDER BY p.date")
            try append(key: "baseTexts", he: "ספרי בסיס", en: "Base texts", tables: ["book_base_text"],
                query: "SELECT b.title FROM book b JOIN book_base_text bt ON bt.baseBookId = b.id WHERE bt.bookId = ? ORDER BY b.title")
            try append(key: "dependentBooks", he: "ספרים נסמכים", en: "Dependent books", tables: ["book_base_text"],
                query: "SELECT b.title FROM book b JOIN book_base_text bt ON bt.bookId = b.id WHERE bt.baseBookId = ? ORDER BY b.title")
            try append(key: "defaultCommentators", he: "מפרשי ברירת מחדל", en: "Default commentators", tables: ["default_commentator"],
                query: "SELECT b.title FROM book b JOIN default_commentator d ON d.commentatorBookId = b.id WHERE d.bookId = ? ORDER BY d.position")
            try append(key: "defaultTargums", he: "תרגומי ברירת מחדל", en: "Default translations", tables: ["default_targum"],
                query: "SELECT b.title FROM book b JOIN default_targum d ON d.targumBookId = b.id WHERE d.bookId = ? ORDER BY d.position")
            for (column, label) in [("dependenceType", hebrew ? "סוג זיקה" : "Dependence"), ("collectiveTitleHe", hebrew ? "שם כולל" : "Collective title")] where capabilities.hasColumn(column, in: "book") {
                if let value = try database.fetch(query: "SELECT \(column) FROM book WHERE id = ?", parameters: [bookID], mapping: { $0.string(at: 0) }).first ?? nil, !value.isEmpty {
                    fields.append(.init(key: column, label: label, value: value))
                }
            }
            return .init(workKey: workKey, title: base.title, heTitle: base.heTitle, authors: base.authors,
                description: base.description, categories: base.categories, factualFields: fields)
        }
    }

    static func baseMetadata(bookId: Int, db: SQLiteDatabase) throws -> LibraryWorkMetadata? {
        let schema = try OtzariaBookSchemaCompatibility.projection(in: db)
        let capabilities = try OtzariaDatabaseCapabilities(database: db)
        func bookColumn(_ name: String, fallback: String = "NULL") -> String {
            capabilities.hasColumn(name, in: "book") ? "b.\(name)" : fallback
        }
        let hasSource = capabilities.hasTable("source") && capabilities.hasColumn("sourceId", in: "book")
        let sourceName = hasSource ? "s.name" : "NULL"
        let sourceJoin = hasSource ? "LEFT JOIN source s ON s.id = b.sourceId" : ""
        let authors = capabilities.hasTable("book_author") && capabilities.hasTable("author")
            ? "(SELECT group_concat(a.name, ', ') FROM book_author ba JOIN author a ON a.id = ba.authorId WHERE ba.bookId = b.id)" : "NULL"
        let category = capabilities.hasTable("category") && capabilities.hasColumn("categoryId", in: "book")
            ? "(SELECT c.title FROM category c WHERE c.id = b.categoryId)" : "NULL"


        return try db.fetch(query: """
            SELECT b.title,
                   COALESCE(\(bookColumn("heShortDesc")), ''),
                   COALESCE(\(schema.filePath), ''),
                   COALESCE(\(sourceName), ''),
                   COALESCE(\(schema.fileType), ''),
                   COALESCE(\(schema.volume), ''),
                   COALESCE(\(schema.pages), ''),
                   COALESCE(\(bookColumn("totalLines")), 0),
                   COALESCE(\(authors), ''),
                   COALESCE(\(category), '')
            FROM book b
            \(sourceJoin)
            WHERE b.id = ?
            LIMIT 1
        """, parameters: [bookId], mapping: { row -> LibraryWorkMetadata in
            let title = row.string(at: 0) ?? ""
            let shortDescription = row.string(at: 1) ?? ""
            let sourceName = row.string(at: 3) ?? ""
            let fileType = row.string(at: 4) ?? ""
            let volume = row.string(at: 5) ?? ""
            let pages = row.string(at: 6) ?? ""
            let totalLines = row.int(at: 7)
            let authorsString = row.string(at: 8) ?? ""
            let categoryName = row.string(at: 9) ?? ""

            let authorsList = authorsString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            var fields: [LibraryMetadataField] = []
            if !authorsString.isEmpty {
                fields.append(LibraryMetadataField(key: "authors", label: "מחבר", value: authorsString))
            }
            if !categoryName.isEmpty {
                fields.append(LibraryMetadataField(key: "category", label: "קטגוריה", value: categoryName))
            }
            if !sourceName.isEmpty {
                fields.append(LibraryMetadataField(key: "source", label: "מקור", value: sourceName))
            }
            if !volume.isEmpty {
                fields.append(LibraryMetadataField(key: "volume", label: "כרך", value: volume))
            }
            if !pages.isEmpty {
                fields.append(LibraryMetadataField(key: "pages", label: "עמודים", value: pages))
            }
            if totalLines > 0 {
                fields.append(LibraryMetadataField(key: "lines", label: "שורות", value: "\(totalLines)"))
            }
            if !fileType.isEmpty {
                fields.append(LibraryMetadataField(key: "fileType", label: "סוג קובץ", value: fileType))
            }

            return LibraryWorkMetadata(
                workKey: "book:\(bookId)",
                title: title,
                heTitle: title,
                authors: authorsList,
                description: shortDescription.isEmpty ? nil : shortDescription,
                categories: categoryName.isEmpty ? [] : [categoryName],
                factualFields: fields
            )
        }).first
    }
}
