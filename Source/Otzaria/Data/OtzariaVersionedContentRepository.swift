import Foundation

enum OtzariaVersionContentError: LocalizedError {
    case unavailableForPassage
    var errorDescription: String? {
        LibraryPresentationPolicy.prefersHebrew()
            ? "למהדורה שנבחרה אין טקסט זמין במקטע זה. ניתן לבחור מהדורה אחרת או לחזור לנוסח המשולב."
            : "The selected edition has no available text for this passage. Choose another edition or return to the merged text."
    }
}

struct OtzariaVersionedContentRepository: Sendable {
    var context: OtzariaSchemaAwareReadContext = .shared
    /// Missing version_line rows are preserved as empty edition segments, never replaced with merged text.
    func section(_ original: LibraryTextSection, version: TextVersionMetadata) async throws -> LibraryTextSection {
        guard original.locator.backend == .otzaria,
              LibraryLanguage.normalized(version.language) == "he" else { throw LibraryBackendError.invalidLocator }
        return try await context.read { database, capabilities in
            guard capabilities.hasVersions else { throw LibraryBackendError.capabilityUnavailable }
            let bookID = try OtzariaCanonicalLineLocatorResolver.bookID(for: original.locator.workKey, database: database, capabilities: capabilities)
            var query = "SELECT id, hasContent FROM book_version WHERE bookId = ? AND versionTitle = ?"
            var parameters: [Any] = [bookID, version.title]
            let prefix = "otzaria-version:\(bookID):"
            guard let identity = version.sourceIdentity, identity.hasPrefix(prefix),
                  let versionID = Int(identity.dropFirst(prefix.count)), versionID > 0 else {
                throw LibraryBackendError.invalidLocator
            }
            query += " AND id = ?"
            parameters.append(versionID)
            let versions = try database.fetch(query: query + " LIMIT 2", parameters: parameters) { ($0.int(at: 0), $0.int(at: 1)) }
            guard versions.count == 1, let edition = versions.first, edition.1 == 1 else {
                throw LibraryBackendError.capabilityUnavailable
            }
            let indices = original.segments.compactMap { segment -> Int? in
                guard segment.locator.backend == .otzaria else { return nil }
                if case .legacyLine(let line) = segment.locator.position { return line }
                return nil
            }
            guard indices.count == original.segments.count else { throw LibraryBackendError.invalidLocator }
            let decoder = try OtzariaLineContentDecoder(database: database, capabilities: capabilities)
            var textByLine: [Int: String] = [:]
            let unique = Array(Set(indices)).sorted()
            for offset in stride(from: 0, to: unique.count, by: 400) {
                try Task.checkCancellation()
                let lines = Array(unique[offset..<min(offset + 400, unique.count)])
                let placeholders = Array(repeating: "?", count: lines.count).joined(separator: ",")
                let values = try database.fetch(query: """
                    SELECT l.lineIndex, v.content FROM line l
                    LEFT JOIN version_line v ON v.lineId = l.id AND v.versionId = ?
                    WHERE l.bookId = ? AND l.lineIndex IN (\(placeholders))
                    """, parameters: [edition.0, bookID] + lines.map { $0 as Any }) { row in
                    (row.int(at: 0), try decoder.decode(row: row, at: 1))
                }
                for (line, text) in values { textByLine[line] = text }
            }
            let segments = zip(original.segments, indices).map { segment, line in
                LibraryTextSegment(locator: segment.locator, heRef: segment.heRef,
                    primaryText: textByLine[line] ?? "", translation: nil)
            }
            guard segments.contains(where: { !$0.primaryText.isEmpty }) else { throw OtzariaVersionContentError.unavailableForPassage }
            return LibraryTextSection(locator: original.locator, displayRef: original.displayRef, heRef: original.heRef,
                segments: segments, previous: original.previous, next: original.next, versions: [version], links: original.links, origin: .offline)
        }
    }
}
