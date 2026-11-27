import Foundation
import SQLite3
import CryptoKit

// Offline identity oracle only. The original Reader service/SQLite/ZSTD bytes
// are compiled unchanged; none of this executable supplies the application's UI.
struct OtzariaPerformanceTelemetry: Sendable {
    static let shared = Self()
    struct Interval { func end(extra: String) {} }
    func begin(_ name: String) -> Interval { .init() }
}
struct OtzariaFileLogger: Sendable {
    static let shared = Self()
    func log(_ value: String) {}
}
private struct CatalogError: Error { let message: String }
private func require(_ value: @autoclosure () -> Bool, _ message: String) throws {
    if !value() { throw CatalogError(message: message) }
}
private func sha(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

@main struct FullV40ObservationCatalog {
    struct Book: Decodable { let bookID: Int; let title: String; let lineCount: Int }
    struct Chapter: Decodable {
        let bookID: Int
        let focusLineIndex: Int
        let unitID: String
        let unitRowCount: Int
        let unitStartLineIndex: Int
        let unitEndLineIndex: Int
        let sourceUTF16Length: Int
    }
    struct Targets: Decodable { let books: [Book]; let retainedChapter: Chapter }
    struct PreviewTarget: Decodable { let bookID: Int; let focusLineIndex: Int; let mode: String }
    struct ServiceIdentity: Decodable { let path: String; let sha256: String; let compileInputsPath: String }
    struct Input: Decodable {
        let databaseURI: String
        let databaseSHA256: String
        let v40Targets: Targets
        let previewTargets: [PreviewTarget]?
        let sourceService: ServiceIdentity?
        let presentationSource: ServiceIdentity?
    }
    static func main() throws {
        let input = try JSONDecoder().decode(Input.self, from: Data(contentsOf:
            URL(fileURLWithPath: CommandLine.arguments[1])))
        try require(input.databaseSHA256 == "8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01",
                    "Only the independently verified full-v40 database is admitted")
        try require(input.v40Targets.books.map(\.bookID) == [103, 28, 3152]
                    && input.v40Targets.books.map(\.lineCount) == [2875, 2678, 528],
                    "Require the independently queried exact v40 book identities, not a v32 catalog")
        let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let database = try SQLiteDatabase(path: input.databaseURI,
            flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_FULLMUTEX, queryOnly: true)
        try require(sqlite3_db_readonly(database.dbPointer, "main") == 1, "Original full DB must be read-only")
        let service = OtzariaReadingUnitService(database: database)
        var targets: [[String: Any]] = []
        var writtenUnits = Set<String>()

        func target(bookID: Int, focus: Int, position: String, expectedCount: Int?,
                    mode: OtzariaUnitMode = .chapter, includeAnchorDetails: Bool = false) throws -> [String: Any] {
            let titles = try database.fetch(query: "SELECT title FROM book WHERE id = ?", parameters: [bookID]) { $0.string(at: 0) }
            try require(titles.count == 1 && titles[0]?.isEmpty == false, "Exact actual book identity missing")
            guard let descriptor = try service.descriptor(bookId: bookID, containingLineIndex: focus, mode: mode),
                  let unit = try service.readingUnit(bookId: bookID, containingLineIndex: focus, mode: mode) else {
                throw CatalogError(message: "Original containing reading unit is unavailable")
            }
            try require(unit.mode == mode && descriptor.mode == mode,
                        "A fallback cannot stand in for the requested original reading-unit mode")
            try require(unit.id == descriptor.id && unit.sourceLineIndices == descriptor.sourceLineIndices,
                        "Original descriptor and source unit disagree")
            let rows = try database.fetch(query:
                "SELECT id,lineIndex,heRef FROM line WHERE bookId = ? ORDER BY lineIndex",
                parameters: [bookID]) { ($0.int(at: 0), $0.int(at: 1), $0.string(at: 2)) }
            if let expectedCount { try require(rows.count == expectedCount, "Qualified actual book row count changed") }
            let membership = Set(unit.sourceLineIndices)
            let actual = rows.filter { membership.contains($0.1) }
            try require(actual.count == unit.sourceLineIndices.count && actual.count == unit.lineAnchors.count,
                        "Every original chapter line/anchor must have an actual SQL identity")
            var next = 0
            let plain = unit.plainText as NSString
            var anchorHash = SHA256()
            for (row, anchor) in zip(actual, unit.lineAnchors) {
                try require(row.0 == anchor.id && row.1 == anchor.lineIndex && row.2 == anchor.heRef,
                            "Original anchor identity differs from immutable SQL")
                try require(anchor.bookId == bookID && anchor.range.location == next
                            && anchor.range.length == anchor.text.utf16.count
                            && NSMaxRange(anchor.range) <= plain.length,
                            "Original UTF16 anchor range changed")
                try require(Data(plain.substring(with: anchor.range).utf8) == Data(anchor.text.utf8),
                            "Original anchor exact UTF8 differs from its source slice")
                let rowBytes = try JSONSerialization.data(withJSONObject: [
                    anchor.id, anchor.lineIndex, anchor.range.location, anchor.range.length,
                    sha(Data(anchor.text.utf8))
                ], options: [.sortedKeys])
                anchorHash.update(data: rowBytes); anchorHash.update(data: Data([10]))
                next = NSMaxRange(anchor.range) + 1
            }
            try require(next - 1 == plain.length, "The full final source anchor must end at the full source boundary")
            let focused = unit.lineAnchors.filter { $0.lineIndex == focus }
            try require(focused.count == 1, "Focus must be an actual unique original anchor")
            let anchor = focused[0]
            let basename = includeAnchorDetails
                ? "\(bookID)-\(mode.rawValue)-\(unit.startLineIndex)-\(unit.endLineIndex).source.utf8"
                : "\(bookID)-\(unit.startLineIndex)-\(unit.endLineIndex).source.utf8"
            let bytes = Data(unit.plainText.utf8)
            if writtenUnits.insert(basename).inserted {
                try bytes.write(to: output.appendingPathComponent(basename), options: .atomic)
            }
            var result: [String: Any] = [
                "key": "\(bookID)-\(position)", "bookID": bookID, "bookTitle": titles[0]!,
                "position": position, "focusLineIndex": focus, "unitID": unit.id,
                "unitMode": unit.mode.rawValue, "unitStartLineIndex": unit.startLineIndex,
                "unitEndLineIndex": unit.endLineIndex, "unitRowCount": unit.sourceLineIndices.count,
                "tocEntryID": unit.tocEntryId as Any? ?? NSNull(),
                "sourceUTF16Length": plain.length, "sourceUTF8Bytes": bytes.count,
                "sourceSHA256": sha(bytes), "sourceFile": basename,
                "allOriginalAnchorsChecked": unit.lineAnchors.count,
                "anchorsIdentitySHA256": anchorHash.finalize().map { String(format: "%02x", $0) }.joined(),
                "focusRangeLocation": anchor.range.location, "focusRangeLength": anchor.range.length,
                "focusUTF8SHA256": sha(Data(anchor.text.utf8)),
                "sectionLocator": "otzaria|book:\(bookID)|line:\(unit.startLineIndex)",
                "focusLocator": "otzaria|book:\(bookID)|line:\(focus)"
            ]
            if includeAnchorDetails {
                result["sourceUTF8"] = unit.plainText
                result["anchors"] = unit.lineAnchors.map { anchor -> [String: Any] in
                    // OtzariaInspectorDocumentMapper supplies anchor.text unchanged
                    // as primaryText. Use the whole original presentation model,
                    // including its ordered entity handling, for the UI oracle.
                    let segment = LibraryTextSegment(
                        locator: TextLocator(backend: .otzaria, workKey: "book:\(bookID)",
                                             position: .legacyLine(anchor.lineIndex)),
                        heRef: anchor.heRef, primaryText: anchor.text, translation: nil)
                    let preview = segment.primaryText.readerPlainText
                    return ["lineID": anchor.id, "bookID": anchor.bookId, "lineIndex": anchor.lineIndex,
                     "heRef": anchor.heRef as Any? ?? NSNull(), "rangeLocation": anchor.range.location,
                     "rangeLength": anchor.range.length, "text": anchor.text,
                     "textSHA256": sha(Data(anchor.text.utf8)), "segmentID": segment.id,
                     "previewPlainText": preview, "previewPlainTextSHA256": sha(Data(preview.utf8)),
                     "previewUTF16Length": preview.utf16.count]
                }
            }
            return result
        }
        if let requests = input.previewTargets {
            // Selected hit identities must come from an actual original provider
            // result/trace. This source oracle does not fabricate or run search.
            try require(!requests.isEmpty && requests.count <= 9,
                        "One to nine independently selected preview/mode targets required")
            guard let identity = input.sourceService else {
                throw CatalogError(message: "Actual compiled ReadingUnitService identity is required")
            }
            let serviceURL = URL(fileURLWithPath: identity.path)
            let serviceBytes = try Data(contentsOf: serviceURL)
            try require(serviceURL.lastPathComponent == "OtzariaReadingUnitService.swift"
                        && identity.sha256.count == 64
                        && sha(serviceBytes) == identity.sha256,
                        "The actual original service source hash changed")
            let compileURL = URL(fileURLWithPath: identity.compileInputsPath)
            let compileBytes = try Data(contentsOf: compileURL)
            guard let compile = try JSONSerialization.jsonObject(with: compileBytes) as? [String: Any],
                  let hashes = compile["source_sha256"] as? [String: String],
                  let command = compile["command"] as? [String]
            else { throw CatalogError(message: "Retained actual catalog compile inputs are missing") }
            try require(hashes["Source/Otzaria/Reading/OtzariaReadingUnitService.swift"] == identity.sha256
                        && command.contains(identity.path),
                        "The preview oracle must bind the service to its actual catalog compile command")
            guard let presentation = input.presentationSource else {
                throw CatalogError(message: "Actual compiled LibraryBackendModels identity is required")
            }
            let presentationURL = URL(fileURLWithPath: presentation.path)
            let presentationBytes = try Data(contentsOf: presentationURL)
            try require(presentationURL.lastPathComponent == "LibraryBackendModels.swift"
                        && presentation.sha256.count == 64
                        && presentation.compileInputsPath == identity.compileInputsPath
                        && sha(presentationBytes) == presentation.sha256
                        && hashes["Source/LibraryBackend/LibraryBackendModels.swift"] == presentation.sha256
                        && command.contains(presentation.path),
                        "Preview presentation must use the exact whole original compiled model/helper")
            var keys = Set<String>()
            for (index, request) in requests.enumerated() {
                let mode: OtzariaUnitMode
                switch request.mode {
                case "line": mode = .line
                case "paragraph": mode = .paragraph
                case "chapter": mode = .chapter
                default: throw CatalogError(message: "Unknown original reading-unit mode")
                }
                try require(request.bookID > 0 && request.focusLineIndex >= 0
                            && keys.insert("\(request.bookID):\(request.focusLineIndex):\(request.mode)").inserted,
                            "Preview targets must have unique actual book/line/mode identities")
                targets.append(try target(bookID: request.bookID, focus: request.focusLineIndex,
                    position: "preview-\(request.mode)-\(index)", expectedCount: nil,
                    mode: mode, includeAnchorDetails: true))
            }
            let previews: [String: Any] = [
                "schema": 1, "status": "ORIGINAL_SOURCE_PREVIEW_CATALOG_ONLY_NOT_SEARCH_OR_UI",
                "corpusProfile": "full-v40", "databaseSHA256": input.databaseSHA256,
                "sourceServiceSHA256": identity.sha256,
                "presentationSourceSHA256": presentation.sha256,
                "catalogCompileInputsSHA256": sha(compileBytes), "targets": targets,
                "uiExecuted": 0, "searchProviderExecuted": false,
                "identityRequirement": "Native test must match the actual provider hit book/line tuple before using these original complete-unit bytes"
            ]
            try JSONSerialization.data(withJSONObject: previews, options: [.prettyPrinted, .sortedKeys])
                .write(to: output.appendingPathComponent("preview-targets.json"), options: .atomic)
            return
        }
        for book in input.v40Targets.books {
            let bookID = book.bookID, count = book.lineCount
            let titles = try database.fetch(query: "SELECT title FROM book WHERE id = ?", parameters: [bookID]) { $0.string(at: 0) }
            try require(titles.count == 1 && titles[0] == book.title, "Canonical v40 book title changed")
            let indices = try database.fetch(query:
                "SELECT lineIndex FROM line WHERE bookId = ? ORDER BY lineIndex",
                parameters: [bookID]) { $0.int(at: 0) }
            try require(indices.count == count && Set(indices).count == count, "Actual full-v40 target row set changed")
            for (name, offset) in [("first", 0), ("middle", indices.count / 2), ("last", indices.count - 1)] {
                targets.append(try target(bookID: bookID, focus: indices[offset], position: name, expectedCount: count))
            }
        }
        let retained = input.v40Targets.retainedChapter
        try require(retained.bookID == 8042 && retained.unitRowCount == 52332
                    && retained.sourceUTF16Length == 8307947,
                    "The retained exact v40 measured chapter identity changed")
        let largest = try target(bookID: retained.bookID, focus: retained.focusLineIndex,
                                 position: "retained-measured-chapter", expectedCount: nil)
        try require(largest["unitID"] as? String == retained.unitID
                    && largest["unitRowCount"] as? Int == retained.unitRowCount
                    && largest["unitStartLineIndex"] as? Int == retained.unitStartLineIndex
                    && largest["unitEndLineIndex"] as? Int == retained.unitEndLineIndex
                    && largest["sourceUTF16Length"] as? Int == retained.sourceUTF16Length,
                    "Actual Swift reading unit does not match the independently selected exact full-v40 DB chapter")
        targets.append(largest)
        try require(targets.count == 10 && Set(targets.compactMap { $0["key"] as? String }).count == 10,
                    "Exactly ten independent target identities required")
        let catalog: [String: Any] = [
            "schema": 1, "status": "ORIGINAL_SOURCE_CATALOG_ONLY_NOT_UI",
            "databaseSHA256": input.databaseSHA256, "targets": targets,
            "corpusProfile": "full-v40", "inspectorBookIDs": input.v40Targets.books.map(\.bookID),
            "unitMode": "chapter", "uiExecuted": 0,
            "largestScope": "Runtime revalidation of the retained 52,332-row measured chapter on the exact hash-bound full-v40 database; no new global-largest claim",
            "originalSourcePayloadsOutsideMeasurement": true,
            "independentSQL": "SELECT id,lineIndex,heRef FROM line WHERE bookId = ? ORDER BY lineIndex",
            "sqliteRuntimeVersion": String(cString: sqlite3_libversion())
        ]
        try JSONSerialization.data(withJSONObject: catalog, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("catalog.json"), options: .atomic)
    }
}
