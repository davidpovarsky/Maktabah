import Foundation
import SQLite3

@main struct OtzariaSchema7Tests {
    static func main() async throws {
        var assertions = 0
        func check(_ value: Bool, _ message: String) throws {
            guard value else { throw NSError(domain: "OtzariaSchema7Tests", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
            assertions += 1
            print("PASS: \(message)")
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("otzaria-schema7-\(UUID()).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let db = try SQLiteDatabase(path: url.path, flags: SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX)
        func sql(_ query: String) throws { try db.execute(query: query) }
        try sql("CREATE TABLE book (id INTEGER PRIMARY KEY, title TEXT, filePath TEXT)")
        try sql("CREATE TABLE line (id INTEGER PRIMARY KEY, bookId INTEGER, lineIndex INTEGER, content TEXT, heRef TEXT)")
        try sql("INSERT INTO book VALUES (1, 'Book One', 'one.txt'), (2, 'Book Two', 'two.txt')")
        try sql("INSERT INTO line VALUES (100,1,7,'merged-7','ref7'),(101,1,11,'merged-11','ref11'),(200,2,7,'foreign','foreign')")
        let context = OtzariaSchemaAwareReadContext(database: db)
        let first = try context.snapshot(database: db) { _, caps in caps }
        try check(!first.hasVersions && !first.hasAlternateTOC, "Minimal schema has no invented optional capabilities")
        let noTopics = try await OtzariaTopicsRepository(context: context).topics(for: .init(backend: .otzaria, workKey: "book:1", position: .legacyLine(7)))
        try check(noTopics.isEmpty, "Optional topics absent on a minimal database")
        try sql("CREATE TABLE topic(id INTEGER PRIMARY KEY,name TEXT)")
        try sql("CREATE TABLE book_topic(bookId INTEGER,topicId INTEGER)")
        try sql("INSERT INTO topic VALUES(9,'בריאה')")
        try sql("INSERT INTO book_topic VALUES(1,9)")
        try sql("CREATE TABLE book_version(id INTEGER PRIMARY KEY,bookId INTEGER,versionTitle TEXT,priority REAL,hasContent INTEGER)")
        try sql("CREATE TABLE version_line(versionId INTEGER,lineId INTEGER,content TEXT,charCount INTEGER)")
        try sql("INSERT INTO book_version VALUES(11,1,'Edition A',2,1),(12,1,'Edition B',1,1),(22,2,'Edition A',3,1)")
        try sql("INSERT INTO version_line VALUES(11,100,'edition-A',9),(12,101,'edition-B',9),(22,200,'foreign-edition',15)")
        let changed = try context.snapshot(database: db) { _, caps in caps }
        try check(changed.hasVersions, "Schema cache refreshes after a schema generation changes")
        let versions = try await OtzariaVersionsRepository(context: context).versions(for: "one.txt")
        try check(versions.map(\.title) == ["Edition A", "Edition B"], "Edition priority and work identity preserved")
        let loc = TextLocator(backend: .otzaria, workKey: "book:1", position: .legacyLine(7))
        let loc11 = TextLocator(backend: .otzaria, workKey: "book:1", position: .legacyLine(11))
        let original = LibraryTextSection(locator: loc, displayRef: "ref7", heRef: nil,
            segments: [.init(locator: loc, heRef: nil, primaryText: "merged-7", translation: nil),
                       .init(locator: loc11, heRef: nil, primaryText: "merged-11", translation: nil)],
            previous: nil, next: nil, versions: [], links: [], origin: .offline)
        let edition = try await OtzariaVersionedContentRepository(context: context).section(original, version: versions[0])
        try check(edition.segments.map(\.primaryText) == ["edition-A", ""], "Missing edition segment is empty, never merged or foreign text")
        let second = try await OtzariaVersionedContentRepository(context: context).section(original, version: versions[1])
        try check(second.segments.map(\.primaryText) == ["", "edition-B"], "Switching edition does not retain previous edition text")
        let topics = try await OtzariaTopicsRepository(context: context).topics(for: loc)
        try check(topics.first?.titleHe == "בריאה" && topics.first?.titleEn == nil, "Topics retain original language without an invented translation")
        let real = try OtzariaCanonicalLineLocatorResolver.locator(bookID: 1, lineIndex: 7, database: db)
        try check(real == loc, "Canonical lineIndex differs from SQLite primary key")
        do {
            _ = try OtzariaCanonicalLineLocatorResolver.locator(bookID: 1, lineIndex: 100, database: db)
            try check(false, "Primary key must not be accepted as a lineIndex")
        } catch LibraryBackendError.invalidLocator { try check(true, "Primary key rejected as canonical lineIndex") }
        try sql("CREATE TABLE tocText(id INTEGER PRIMARY KEY,text TEXT)")
        try sql("CREATE TABLE alt_toc_structure(id INTEGER PRIMARY KEY,bookId INTEGER,key TEXT,title TEXT,heTitle TEXT)")
        try sql("CREATE TABLE alt_toc_entry(id INTEGER PRIMARY KEY,structureId INTEGER,parentId INTEGER,textId INTEGER,level INTEGER,lineId INTEGER)")
        try sql("INSERT INTO tocText VALUES(1,'Parent'),(2,'Child'),(3,'Invalid')")
        try sql("INSERT INTO alt_toc_structure VALUES(5,1,'Parasha','Portions','פרשות')")
        try sql("INSERT INTO alt_toc_entry VALUES(10,5,NULL,1,1,NULL),(11,5,10,2,2,100),(12,5,NULL,3,1,200),(13,5,999,3,1,101),(14,5,15,3,1,100),(15,5,14,3,1,101)")
        let structures = try await OtzariaAlternativeTOCRepository(context: context).structures(for: "book:1", hebrew: true)
        try check(structures.count == 1 && structures[0].title == "פרשות", "Alternative structure title comes from original metadata")
        try check(structures[0].nodes.count == 1, "Foreign anchors, orphan entries and cycles are excluded")
        try check(structures[0].nodes[0].locator == loc && structures[0].nodes[0].children[0].locator == loc, "Parent uses a real descendant anchor without using entry IDs")
        try sql("CREATE TABLE link(id INTEGER PRIMARY KEY,sourceLineId INTEGER,targetLineId INTEGER)")
        try sql("CREATE TABLE link_anchor(linkId INTEGER,side INTEGER,charStart INTEGER,charEnd INTEGER,label TEXT)")
        try sql("INSERT INTO link VALUES(40,100,200)")
        try sql("INSERT INTO link_anchor VALUES(40,0,1,3,'a')")
        let caps = try OtzariaDatabaseCapabilities(database: db)
        let anchors = try OtzariaLinkAnchorRepository.anchors(linkIDs: [40], bookID: 1, lines: [7], database: db, capabilities: caps)
        try check(anchors[40]?.first?.charEnd == 3, "Word anchor retained on its actual starting line")
        let coverage = try OtzariaLinkAnchorRepository.anchors(linkIDs: [40], bookID: 1, lines: [11], database: db, capabilities: caps)
        try check(coverage.isEmpty, "Coverage lines do not inherit a starting line's word offsets")
        try check(OtzariaSourceToDisplayRangeMap.utf16Range(start: 0, end: 2, fullVisibleSource: "אב", displayedText: "אב") == NSRange(location: 0, length: 2), "Verified Hebrew visible range maps to UTF16")
        try check(OtzariaSourceToDisplayRangeMap.utf16Range(start: 0, end: 2, fullVisibleSource: "אב", displayedText: "א ב") == nil, "Unmapped transformations do not produce guessed highlights")
        try sql("INSERT INTO book VALUES (3,'Multiline','three.txt')")
        try sql("INSERT INTO line VALUES (300,3,7,'alpha' || char(10) || 'beta','a'),(301,3,11,'gamma','b')")
        let multi = try OtzariaSearchLineIndexResolver.resolve(ordinals: [0,1,2], bookID: 3, database: db, capabilities: .init(database: db))
        try check(multi == [0:7,1:7,2:11], "Raw text ordinals map through embedded newlines to sparse real lineIndex")
        try sql("CREATE TABLE line_ref(bookId INTEGER,refKeyHash INTEGER,lineIndex INTEGER)")
        let refHash = Int(truncatingIfNeeded: OtzariaReferenceKey.hash("א"))
        try sql("INSERT INTO line_ref VALUES(1,\(refHash),7),(2,\(refHash),7)")
        let references = try await OtzariaReferenceResolutionRepository(context: context).resolve(workKey: "book:1", reference: "Book One א")
        try check(references == [loc], "RefKey lookup stays within its verified book")
        let metadata = try await OtzariaWorkMetadataEnricher(context: context).metadata(for: "book:1", hebrew: true)
        try check(metadata?.title == "Book One", "Minimal metadata schema preserves the original title")
        try sql("CREATE TABLE pub_place(id INTEGER PRIMARY KEY,name TEXT)")
        try sql("CREATE TABLE book_pub_place(bookId INTEGER,pubPlaceId INTEGER)")
        try sql("INSERT INTO pub_place VALUES(1,'ירושלים')")
        try sql("INSERT INTO book_pub_place VALUES(1,1)")
        let enriched = try await OtzariaWorkMetadataEnricher(context: context).metadata(for: "book:1", hebrew: true)
        try check(enriched?.factualFields.contains(where: { $0.key == "publicationPlaces" && $0.value == "ירושלים" }) == true, "Metadata enrichment uses original publication places")
        try sql("CREATE TABLE book_protection(bookId INTEGER PRIMARY KEY,level INTEGER)")
        try sql("INSERT INTO book_protection VALUES(1,99)")
        let restricted = try await OtzariaLineDecorationRepository(context: context).allowsTextExport(workKey: "book:1")
        let unrestricted = try await OtzariaLineDecorationRepository(context: context).allowsTextExport(workKey: "book:2")
        try check(!restricted && unrestricted, "Unknown protection levels deny export without blocking other books")
        let span = OtzariaDivineNameSpan(lineIndex: 7, noteIndex: nil, charStart: 2, packedSpan: (4 << 7) | (2 << 4) | 3)
        try check(span.length == 4 && span.sourceCode == 2 && span.kindCode == 3, "Packed sacred-name metadata decodes original length/source/kind bits")
        let noteVersion = TextVersionMetadata(title: "Edition A", language: "he", actualLanguage: nil, sourceURL: nil, license: nil, notes: nil, isPrimary: true)
        var tabA = OtzariaVersionSelectionStore()
        let tabB = OtzariaVersionSelectionStore()
        tabA.select(noteVersion, workKey: "book:1", generation: 1)
        try check(tabA.selection(workKey: "book:1", generation: 1) == noteVersion && tabB.selection(workKey: "book:1", generation: 1) == nil, "Edition choices belong to one reader tab")
        try check(tabA.selection(workKey: "book:1", generation: 2) == nil && tabA.selection(workKey: "book:2", generation: 1) == nil, "Edition choice cannot cross database generations or books")
        try sql("CREATE TABLE line_note(lineId INTEGER,noteIndex INTEGER,charPos INTEGER,hasMarker INTEGER,body TEXT)")
        try sql("INSERT INTO book VALUES(4,'Notes','notes.txt')")
        try sql("INSERT INTO line VALUES(400,4,0,'alpha','n0'),(401,4,1,'gamma','n1')")
        try sql("INSERT INTO line_note VALUES(400,0,5,0,'note' || char(10) || 'continuation')")
        let noteMap = try OtzariaSearchLineIndexResolver.resolve(ordinals: [0,1,2], bookID: 4, database: db, capabilities: .init(database: db))
        try check(noteMap == [0:0,1:0,2:1], "Restored note newlines preserve the original Rust raw-text ordinal mapping")
        let decorations = try await OtzariaLineDecorationRepository(context: context).decorations(for: .init(backend: .otzaria, workKey: "book:4", position: .legacyLine(0)))
        try check(decorations.notes.first?.body == "note\ncontinuation" && decorations.notes.first?.charPosition == 5,
                  "Edition footnotes retain original body and insertion coordinates")
        func note(_ position: Int, marker: Bool = false, body: String = "הערה", index: Int = 0) -> OtzariaLineNote {
            .init(lineIndex: 7, noteIndex: index, charPosition: position, hasMarker: marker, body: body)
        }
        try check(try OtzariaInlineNotePresentation.restoring([note(2)], in: "אבגד") == "אב<i class=\"footnote\">הערה</i>גד", "Native footnote restoration uses original visible UTF16 coordinates")
        try check(try OtzariaInlineNotePresentation.restoring([note(2)], in: "<b>א&amp;</b>ב") == "<b>א&amp;</b><i class=\"footnote\">הערה</i>ב", "Entities count once and inline closing tags stay with their text")
        try check(try OtzariaInlineNotePresentation.restoring([note(-1, marker: true)], in: "א<sup class=\"footnote-marker\">1</sup>ב") == "א<sup class=\"footnote-marker\">1</sup><i class=\"footnote\">הערה</i>ב", "An extracted marker retains its own note body")
        try check(try OtzariaInlineNotePresentation.restoring([note(1)], in: "א</p><p>ב") == "א<i class=\"footnote\">הערה</i></p><p>ב", "Restoration does not cross paragraph boundaries")
        let restored = "א<i class=\"footnote\">הערה</i>ב"
        try check(try OtzariaInlineNotePresentation.restoring([note(1)], in: restored) == restored, "Already restored original footnotes are not duplicated")
        try check(try OtzariaInlineNotePresentation.restoring([note(2)], in: "😀א") == "😀<i class=\"footnote\">הערה</i>א", "Astral characters retain their original two UTF16 units")
        do {
            _ = try OtzariaInlineNotePresentation.restoring([note(1)], in: "😀א")
            try check(false, "Split scalar insertion must not be guessed")
        } catch LibraryBackendError.invalidResponse { try check(true, "A split scalar insertion fails explicitly") }
        try check(try OtzariaInlineNotePresentation.restoring([note(1, body: "ראשון"), note(1, body: "שני", index: 1)], in: "אב") == "א<i class=\"footnote\">ראשון</i><i class=\"footnote\">שני</i>ב", "Notes sharing an insertion point keep their original order")
        try sql("CREATE TABLE zstd_dict(id INTEGER PRIMARY KEY,dict BLOB)")
        try sql("INSERT INTO zstd_dict VALUES(1,X'7261772064696374696f6e6172792073656564')")
        let compressedText = "בראשית ברא אלהים את השמים ואת הארץ"
        let input = Data(compressedText.utf8)
        var frame = Data(count: ZSTD_compressBound(input.count))
        let compressedBytes = frame.withUnsafeMutableBytes { output in
            input.withUnsafeBytes { source in ZSTD_compress(output.baseAddress, output.count, source.baseAddress, source.count, 3) }
        }
        try check(ZSTD_isError(compressedBytes) == 0, "Fixture compression uses the actual native zstd library")
        frame.count = compressedBytes
        let decoder = try OtzariaLineContentDecoder(database: db, capabilities: .init(database: db))
        try check(try decoder.decode(frame: frame) == compressedText, "Production decoder preserves compressed Hebrew UTF8")
        do {
            _ = try decoder.decode(frame: Data([1,2,3]))
            try check(false, "Corrupt compressed rows must fail")
        } catch OtzariaLineContentError.invalidFrameSize { try check(true, "Corrupt compressed frames never become empty text") }
        if let path = CommandLine.arguments.dropFirst().first {
            let actual = try SQLiteDatabase(path: path, flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX)
            let actualContext = OtzariaSchemaAwareReadContext(database: actual)
            let actualCaps = try OtzariaDatabaseCapabilities(database: actual)
            try check(actualCaps.hasVersions && actualCaps.hasAlternateTOC, "Authenticated v36 subset exposes actual schema7 capabilities")
            let refs = try await OtzariaReferenceResolutionRepository(context: actualContext).resolve(workKey: "book:1", reference: "בראשית, א, א")
            try check(refs.contains(.init(backend: .otzaria, workKey: "book:1", position: .legacyLine(2))), "Real schema7 reference hashes locate Genesis 1:1 at canonical lineIndex 2")
            let actualVersions = try await OtzariaVersionsRepository(context: actualContext).versions(for: "book:1")
            try check(actualVersions.count == 4 && actualVersions.first?.title == "Miqra according to the Masorah", "Real SQLite edition metadata preserves original priority")
            try check(actualVersions.first?.heTitle == "מקרא על פי המסורה" && actualVersions.first?.sourceIdentity == "otzaria-version:1:3", "Edition display uses original Hebrew while selection retains the true SQLite edition ID")
            let actualLoc = TextLocator(backend: .otzaria, workKey: "book:1", position: .legacyLine(1))
            let actualSection = LibraryTextSection(locator: actualLoc, displayRef: "בראשית", heRef: nil,
                segments: [1,97].map { .init(locator: .init(backend: .otzaria, workKey: "book:1", position: .legacyLine($0)), heRef: nil, primaryText: "merged-must-not-leak", translation: nil) },
                previous: nil, next: nil, versions: [], links: [], origin: .offline)
            let actualEdition = try await OtzariaVersionedContentRepository(context: actualContext).section(actualSection, version: actualVersions[0])
            try check(actualEdition.segments[0].primaryText.isEmpty && actualEdition.segments[1].primaryText.unicodeScalars.contains(where: { (0x05D0...0x05EA).contains($0.value) }), "Real compressed edition reads its body and leaves an absent heading empty")
            let actualDecoder = try OtzariaLineContentDecoder(database: actual, capabilities: actualCaps)
            let projection = OtzariaLineContentCompatibility.projection(capabilities: actualCaps)
            let noteLines = try actual.fetch(query: "SELECT DISTINCT l.lineIndex, \(projection.expression) FROM line l \(projection.join) JOIN line_note n ON n.lineId=l.id WHERE l.bookId=1 ORDER BY l.lineIndex") { row in
                (row.int(at: 0), try actualDecoder.decode(row: row, at: 1))
            }
            try check(noteLines.count == 7, "Actual v36 miniature preserves all seven extracted footnote lines")
            for (line, source) in noteLines {
                let locator = TextLocator(backend: .otzaria, workKey: "book:1", position: .legacyLine(line))
                let content = LibraryTextSection(locator: locator, displayRef: "בראשית", heRef: nil,
                    segments: [.init(locator: locator, heRef: nil, primaryText: source, translation: nil)], previous: nil, next: nil, versions: [], links: [], origin: .offline)
                let originalNotes = try await OtzariaLineDecorationRepository(context: actualContext).decorations(for: locator)
                let presented = try await OtzariaLineDecorationRepository(context: actualContext).restoringNotes(in: content)
                try check(presented.segments[0].locator == locator && originalNotes.notes.allSatisfy({ presented.segments[0].primaryText.contains($0.body) }), "Real compressed footnote restored without changing canonical anchor \(line)")
            }
        }
        print("PASS: \(assertions) real SQLite production repository fixture assertions; not a Hermes or device acceptance claim")
    }
}
