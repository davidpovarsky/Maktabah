import Foundation

struct OtzariaTopicsRepository: Sendable {
    var context: OtzariaSchemaAwareReadContext = .shared
    func topics(for locator: TextLocator) async throws -> [LibraryRelatedTopic] {
        guard locator.backend == .otzaria else { throw LibraryBackendError.invalidLocator }
        return try await context.read { database, capabilities in
            guard capabilities.hasTable("topic"), capabilities.hasTable("book_topic"),
                  capabilities.hasColumn("name", in: "topic") else { return [] }
            let bookID = try OtzariaCanonicalLineLocatorResolver.bookID(for: locator.workKey, database: database, capabilities: capabilities)
            return try database.fetch(query: """
                SELECT DISTINCT t.id, t.name FROM topic t
                JOIN book_topic bt ON bt.topicId = t.id
                WHERE bt.bookId = ? ORDER BY t.name, t.id
                """, parameters: [bookID]) { row in
                LibraryRelatedTopic(slug: "otzaria-topic:\(row.int(at: 0))", titleHe: row.string(at: 1), titleEn: nil)
            }
        }
    }
}
