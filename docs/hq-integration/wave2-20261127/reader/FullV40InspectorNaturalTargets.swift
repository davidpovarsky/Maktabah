import Foundation
import SQLite3
import CryptoKit
import TorahInspectorCore

// Standalone source oracle, never application state or a UI data provider.
// These host/DTO/logging boundaries do not return injected query results. The
// complete original ReadingUnitService, LineSourcesService, schema, decoder,
// classifier, models and SQLite wrapper are compiled unchanged.
final class OtzariaMaktabahBridge: @unchecked Sendable {
    let database: SQLiteDatabase
    init(database: SQLiteDatabase) { self.database = database }
    func withDatabase<T>(_ work: (SQLiteDatabase) throws -> T) throws -> T {
        try work(database)
    }
}
struct CategoryData {
    let id: Int
    let name: String
    let level: Int
    let order: Int
    let parentId: Int?
}
struct OtzariaPerformanceTelemetry: Sendable {
    static let shared = Self()
    struct Interval { func end(extra: String) {} }
    func begin(_ name: String) -> Interval { .init() }
}
struct OtzariaFileLogger: Sendable {
    static let shared = Self()
    func log(_ value: String) {}
}
private struct NaturalTargetError: Error { let message: String }
private func require(_ value: @autoclosure () throws -> Bool, _ message: String) throws {
    if try !value() { throw NaturalTargetError(message: message) }
}
private func sha(_ bytes: Data) -> String {
    SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
}
private func json(_ value: Any) throws -> Data {
    try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
}
private func writeNew(_ bytes: Data, to path: URL) throws {
    try require(bytes.count <= 16 * 1024 * 1024, "A single bounded source-oracle artifact exceeded 16 MiB")
    try require(!FileManager.default.fileExists(atPath: path.path), "Never overwrite an original catalog artifact")
    try bytes.write(to: path, options: .withoutOverwriting)
}

// This is an identity projection, not an adapter/session implementation. Use
// the complete original provider.map, byte-exact original Formatting enum and
// canonical Core DTO's computed id. Author/body fields omitted here do not
// participate in the original native cache digest; no lifecycle/cache result
// is injected and native observation must independently match the full array.
private func projectedNativeIdentity(_ source: LibraryRelatedSource) -> TorahLinkedSource {
    TorahLinkedSource(
        sourceRef: MaktabahTorahInspectorFormatting.reference(for: source.locator),
        sourceHebrewRef: source.heRef,
        category: source.category, type: source.type,
        versionTitle: source.versionTitle,
        canonicalBookID: "\(source.locator.backend.rawValue):\(source.locator.workKey)",
        anchorRefs: source.anchorRefs,
        relationshipKind: MaktabahTorahInspectorFormatting.relationshipKind(category: source.category, type: source.type),
        semanticCategory: MaktabahTorahInspectorFormatting.semanticCategory(category: source.category, type: source.type),
        rawProviderPayload: source.locator.persistenceKey)
}

private func fullNativeIdentityProjection(_ links: [TorahLinkedSource]) throws -> [String: Any] {
    try require(links.count <= 10_000, "This bounded natural catalog admits at most 10000 complete relationships per target")
    var hash = SHA256()
    var hashedBytes = 0
    func append(_ value: String) throws {
        try require(value.utf8.prefix(8193).count <= 8192, "Oversized identity cannot be truncated")
        let bytes = Data(value.utf8)
        try require(hashedBytes <= 32 * 1024 * 1024 - bytes.count - 8, "Original native identity byte bound exceeded")
        var length = UInt64(bytes.count).bigEndian
        withUnsafeBytes(of: &length) { hash.update(data: Data($0)) }
        hash.update(data: bytes)
        hashedBytes += bytes.count + 8
    }
    try append("otzaria.original-inspector-membership/1")
    try append(String(links.count))
    var identities: [[String: Any]] = []
    for (ordinal, link) in links.enumerated() {
        let fields = [link.canonicalBookID, link.sourceRef, link.type, link.category, link.versionTitle ?? ""]
        try require(link.anchorRefs.count <= 32 && fields.allSatisfy { $0.utf8.prefix(1025).count <= 1024 }
            && link.anchorRefs.allSatisfy { $0.utf8.prefix(1025).count <= 1024 }
            && fields.reduce(0, { $0 + $1.utf8.count })
                + link.anchorRefs.reduce(0, { $0 + $1.utf8.count }) + link.anchorRefs.count + 6 <= 4096
            && link.rawProviderPayload.utf8.prefix(1025).count <= 1024
            && (link.sourceHebrewRef?.utf8.prefix(2049).count ?? 0) <= 2048,
            "Full identity must fit the original native observer's metadata bounds")
        let identity = link.id
        try append(String(ordinal)); try append(identity); try append(link.sourceRef); try append(link.rawProviderPayload)
        identities.append(["ordinal": ordinal, "id": identity, "sourceRef": link.sourceRef,
            "rawProviderPayload": link.rawProviderPayload, "canonicalBookID": link.canonicalBookID,
            "category": link.category, "type": link.type, "anchorRefs": link.anchorRefs,
            "versionTitle": link.versionTitle as Any? ?? NSNull()])
    }
    return ["schema": 1, "status": "ORIGINAL_IDENTITY_PROJECTION_REQUIRES_NATIVE_ARRAY_COMPARISON",
        "count": links.count, "orderedIdentitySHA256": hash.finalize().map { String(format: "%02x", $0) }.joined(),
        "hashedBytes": hashedBytes, "identities": identities,
        "identityDigestEncoding": "SHA256 of eight-byte unsigned big-endian UTF8 byte lengths then exact UTF8; header,count,then original array ordinal,id,sourceRef,rawProviderPayload",
        "scope": "Entire unchanged metadata service order projected through original provider.map, original Formatting and canonical Core.id; not whole adapter/session execution or full-row rendering"]
}

@main struct FullV40InspectorNaturalTargets {
    struct Candidate: Decodable {
        let bookID: Int
        let bookTitle: String
        let mode: String
        let unitID: String
        let unitStartLineIndex: Int
        let unitEndLineIndex: Int
        let unitRowCount: Int
        let sourceLineIndices: [Int]
        let sourceIndicesSHA256: String
        let requestedCount: Int
        let candidateRawRelationshipCount: Int
        let candidateRawMembership: [[Int]]
        let rawMembershipSHA256: String
    }
    struct Input: Decodable {
        let databaseURI: String
        let databaseSHA256: String
        let candidates: [Candidate]
        let candidateReceiptSHA256: String
        let installedSQLReceiptSHA256: String
        let compileInputsSHA256: String
        let sourceSHA256: [String: String]
        let pinnedCoreManifestSHA256: String
    }

    static func main() throws {
        try require(CommandLine.arguments.count == 3, "Input and fresh output directory are required")
        let inputBytes = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        try require(inputBytes.count <= 4 * 1024 * 1024, "Bound the actual complete candidate input before decoding")
        let input = try JSONDecoder().decode(Input.self, from: inputBytes)
        try require(input.databaseSHA256 == "8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01",
                    "Only the separately verified full-v40 database is admitted")
        try require(input.databaseURI.contains("mode=ro") && input.databaseURI.contains("immutable=1"),
                    "The current verified installation must be read-only and immutable")
        try require(input.candidates.map(\.requestedCount) == [100, 500, 2000]
                    && input.candidates.allSatisfy { $0.candidateRawRelationshipCount >= $0.requestedCount
                        && $0.candidateRawRelationshipCount <= 10_000 },
                    "Require three complete natural workloads at least the original requested scales; never use a prefix")
        try require(Set(input.candidates.map { "\($0.bookID):\($0.unitID)" }).count == 3
                    && input.candidates.allSatisfy { ![103, 28, 3152].contains($0.bookID) },
                    "Additional natural targets must be distinct from the retained nine original explorations")
        for digest in [input.candidateReceiptSHA256, input.installedSQLReceiptSHA256,
                       input.compileInputsSHA256, input.pinnedCoreManifestSHA256] {
            try require(digest.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil,
                        "Exact independent input identities are required")
        }
        let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let database = try SQLiteDatabase(path: input.databaseURI,
            flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_FULLMUTEX, queryOnly: true)
        try require(sqlite3_db_readonly(database.dbPointer, "main") == 1,
                    "Original full database must remain read-only")
        let capabilities = try OtzariaDatabaseCapabilities(database: database)
        try require(capabilities.hasSplitLineContent && capabilities.hasZstdDictionaries
                    && capabilities.hasLinkRanges && capabilities.hasSuppressedLinkSides,
                    "Exact schema-7 content/range/suppression capabilities are required")
        let service = OtzariaReadingUnitService(database: database)
        let bridge = OtzariaMaktabahBridge(database: database)
        var scales: [[String: Any]] = []
        var artifactBytes = 0

        for candidate in input.candidates {
            let required = candidate.requestedCount
            let actualCount = candidate.candidateRawRelationshipCount
            let indices = candidate.sourceLineIndices
            try require(candidate.mode == "chapter" && !indices.isEmpty && indices.count <= 50_000
                        && indices == Array(Set(indices)).sorted() && indices.first! >= 0
                        && candidate.unitStartLineIndex == indices.first
                        && candidate.unitEndLineIndex == indices.last && candidate.unitRowCount == indices.count,
                        "A complete natural chapter membership is required")
            try require(sha(try json(indices)) == candidate.sourceIndicesSHA256,
                        "Retained independent source-index membership changed")
            let focus = indices[indices.count / 2]
            guard let descriptor = try service.descriptor(bookId: candidate.bookID,
                      containingLineIndex: focus, mode: .chapter),
                  let unit = try service.readingUnit(bookId: candidate.bookID,
                      containingLineIndex: focus, mode: .chapter) else {
                throw NaturalTargetError(message: "The original complete natural chapter is unavailable")
            }
            try require(unit.mode == .chapter && descriptor.mode == .chapter
                        && unit.id == candidate.unitID && descriptor.id == unit.id
                        && unit.sourceLineIndices == indices && descriptor.sourceLineIndices == indices,
                        "Original Swift unit membership must exactly match independent SQL; fallback is not accepted")
            let books = try database.fetch(query: "SELECT title,totalLines FROM book WHERE id=?",
                parameters: [candidate.bookID]) { ($0.string(at: 0) ?? "", $0.int(at: 1)) }
            try require(books.count == 1 && books[0].0 == candidate.bookTitle,
                        "Exact canonical book identity changed")
            let rows = try database.fetch(query: "SELECT id,lineIndex,heRef FROM line WHERE bookId=? ORDER BY lineIndex",
                parameters: [candidate.bookID]) { ($0.int(at: 0), $0.int(at: 1), $0.string(at: 2)) }
            try require(rows.count == books[0].1 && rows.count <= 50_000,
                        "Complete actual book rows must agree with their retained canonical metadata")
            let membership = Set(indices)
            let actual = rows.filter { membership.contains($0.1) }
            try require(actual.count == indices.count && unit.lineAnchors.count == indices.count,
                        "Every original unit line must have an actual immutable SQL anchor")
            let plain = unit.plainText as NSString
            var cursor = 0
            var anchorsHash = SHA256()
            for (row, anchor) in zip(actual, unit.lineAnchors) {
                try require(row.0 == anchor.id && row.1 == anchor.lineIndex && row.2 == anchor.heRef
                            && anchor.bookId == candidate.bookID && anchor.range.location == cursor
                            && anchor.range.length == anchor.text.utf16.count
                            && NSMaxRange(anchor.range) <= plain.length,
                            "Exact original SQL/Swift UTF16 anchor identity differs")
                try require(Data(plain.substring(with: anchor.range).utf8) == Data(anchor.text.utf8),
                            "The original source slice is not the full original anchor text")
                anchorsHash.update(data: try json([anchor.id, anchor.lineIndex,
                    anchor.range.location, anchor.range.length, sha(Data(anchor.text.utf8))]))
                anchorsHash.update(data: Data([10]))
                cursor = NSMaxRange(anchor.range) + 1
            }
            try require(cursor - 1 == plain.length && plain.length > 0,
                        "The final complete source anchor must reach the complete unit boundary")
            let focused = unit.lineAnchors.filter { $0.lineIndex == focus }
            try require(focused.count == 1, "Focus must be a unique actual original anchor")

            OtzariaLineSourcesService.clearCategoryCache()
            let sources = try bridge.getLinksMetadataForReadingUnit(unit, includeContent: false)
            let actualMembership = sources.map { [$0.id, $0.linkedBookId, $0.linkedLineId] }
                .sorted { $0.lexicographicallyPrecedes($1) }
            try require(sources.count == actualCount && actualCount >= required && sources.allSatisfy { $0.content.isEmpty },
                        "Unchanged original metadata service must return the entire independently recorded natural workload")
            try require(Set(actualMembership.map { $0.map(String.init).joined(separator: ":") }).count == actualCount
                        && actualMembership == candidate.candidateRawMembership
                        && sha(try json(actualMembership)) == candidate.rawMembershipSHA256,
                        "Every original relationship identity must equal the complete independent SQL membership")
            let records: [[String: Any]] = sources.map { source in
                ["id": source.id, "linkedBookID": source.linkedBookId, "linkedLineID": source.linkedLineId,
                 "linkedLineIndex": source.linkedLineIndex, "bookTitle": source.bookTitle,
                 "rawConnectionType": source.rawConnectionType, "connectionType": source.connectionType,
                 "matchedSide": source.matchedSide, "sourceBookID": source.sourceBookId,
                 "targetBookID": source.targetBookId, "heRef": source.heRef as Any? ?? NSNull(),
                 "linkedCategoryPath": source.linkedCategoryPath, "contentBytes": source.content.utf8.count]
            }
            let identities = try fullNativeIdentityProjection(sources.map(OtzariaInspectorRelationshipsProvider.map)
                .map(projectedNativeIdentity))
            let stem = "natural-inspector-\(required)-actual-\(actualCount)-book-\(candidate.bookID)"
            let sourceBytes = Data(unit.plainText.utf8)
            let metadataBytes = try json(records)
            let identityBytes = try json(identities)
            artifactBytes += sourceBytes.count + metadataBytes.count + identityBytes.count
            try require(artifactBytes <= 64 * 1024 * 1024, "Complete natural source-oracle artifacts exceeded the 64 MiB budget")
            try writeNew(sourceBytes, to: output.appendingPathComponent(stem + ".source.utf8"))
            try writeNew(metadataBytes, to: output.appendingPathComponent(stem + ".metadata.json"))
            try writeNew(identityBytes, to: output.appendingPathComponent(stem + ".identities.json"))
            let target: [String: Any] = [
                "key": stem, "bookID": candidate.bookID, "bookTitle": books[0].0,
                "position": "separate-natural-requested-\(required)-actual-\(actualCount)", "focusLineIndex": focus,
                "unitID": unit.id, "unitMode": unit.mode.rawValue,
                "unitStartLineIndex": unit.startLineIndex, "unitEndLineIndex": unit.endLineIndex,
                "unitRowCount": indices.count, "sourceLineIndices": indices,
                "tocEntryID": unit.tocEntryId as Any? ?? NSNull(),
                "sourceUTF16Length": plain.length, "sourceUTF8Bytes": sourceBytes.count,
                "sourceSHA256": sha(sourceBytes), "sourceFile": stem + ".source.utf8",
                "allOriginalAnchorsChecked": unit.lineAnchors.count,
                "anchorsIdentitySHA256": anchorsHash.finalize().map { String(format: "%02x", $0) }.joined(),
                "focusRangeLocation": focused[0].range.location, "focusRangeLength": focused[0].range.length,
                "focusUTF8SHA256": sha(Data(focused[0].text.utf8)),
                "sectionLocator": "otzaria|book:\(candidate.bookID)|line:\(unit.startLineIndex)",
                "focusLocator": "otzaria|book:\(candidate.bookID)|line:\(focus)"
            ]
            scales.append(["requestedCount": required, "originalMetadataCount": sources.count,
                "rawMembershipSHA256": sha(try json(actualMembership)),
                "sourceIndicesSHA256": sha(try json(indices)), "target": target,
                "metadataFile": stem + ".metadata.json", "metadataSHA256": sha(metadataBytes),
                "metadataBytes": metadataBytes.count,
                "identityProjectionFile": stem + ".identities.json", "identityProjectionSHA256": sha(identityBytes),
                "identityProjectionBytes": identityBytes.count,
                "nativeOrderedIdentitySHA256": identities["orderedIdentitySHA256"]!,
                "nativeIdentityHashedBytes": identities["hashedBytes"]!,
                "atLeastRequestedCount": actualCount >= required, "exactRequestedCount": actualCount == required,
                "scope": "Complete original ReadingUnit/LineSources result and SQL membership plus original identity projection; entire native cache digest/UI still required"])
        }
        let catalog: [String: Any] = ["schema": 1, "corpusProfile": "full-v40",
            "status": "ORIGINAL_NATURAL_UNIT_AND_METADATA_CATALOG_NOT_NATIVE_ACCEPTANCE",
            "databaseSHA256": input.databaseSHA256, "scales": scales,
            "candidateReceiptSHA256": input.candidateReceiptSHA256,
            "installedSQLReceiptSHA256": input.installedSQLReceiptSHA256,
            "compileInputsSHA256": input.compileInputsSHA256, "sourceSHA256": input.sourceSHA256,
            "pinnedCoreManifestSHA256": input.pinnedCoreManifestSHA256,
            "nativeUIExecuted": 0, "nativeCacheObserved": false,
            "artifactBytes": artifactBytes,
            "boundaryScope": "Pass-through host database access and host CategoryData/logging only; original identity projection excludes adapter lifecycle/author/body behavior; no result injection or app session/cache simulation"]
        try writeNew(try json(catalog), to: output.appendingPathComponent("natural-inspector-targets.json"))
    }
}
