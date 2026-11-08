import Foundation

struct OtzariaVersionsRepository: LibraryMetadataProviding, Sendable {
    var context: OtzariaSchemaAwareReadContext = .shared
    func versions(for workKey: String) async throws -> [TextVersionMetadata] {
        try await context.read { database, capabilities in
            guard capabilities.hasVersions else { return [] }
            let bookID = try OtzariaCanonicalLineLocatorResolver.bookID(for: workKey, database: database, capabilities: capabilities)
            func column(_ name: String) -> String { capabilities.hasColumn(name, in: "book_version") ? name : "NULL" }
            return try database.fetch(query: """
                SELECT versionTitle, \(column("versionSource")), \(column("license")),
                       \(column("heVersionNotes")), \(column("versionNotes"))
                FROM book_version WHERE bookId = ?
                ORDER BY \(column("priority")) DESC, versionTitle, id
                """, parameters: [bookID]) { row in
                let url = row.string(at: 1).flatMap(URL.init(string:)).flatMap { ["https", "http"].contains($0.scheme?.lowercased() ?? "") ? $0 : nil }
                return TextVersionMetadata(title: row.string(at: 0) ?? "", language: "he", actualLanguage: "he",
                    sourceURL: url, license: row.string(at: 2), notes: row.string(at: 3) ?? row.string(at: 4), isPrimary: true)
            }
        }
    }

    func related(to locator: TextLocator) async throws -> [TextLocator] {
        #if os(iOS)
        try await OtzariaInspectorRelationshipsProvider().links(for: locator).map(\.locator)
        #else
        throw LibraryBackendError.capabilityUnavailable
        #endif
    }
}
