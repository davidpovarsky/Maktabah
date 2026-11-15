import Foundation

@main struct ServiceTests {
    static func main() async throws {
        var failures: [String] = []
        func check(_ value: Bool, _ message: String) { if !value { failures.append(message) } }
        let db = SQLiteDatabase()
        let service = OtzariaReadingUnitService(database: db)
        let first = try service.firstDescriptor(bookId: 103, mode: .paragraph)!
        check(db.sourceFetches == 0, "descriptor is metadata only")
        check(first.sourceLineIndices == [0, 1], "first unit exact lines")
        let built = try service.buildUnit(from: first)!
        check(built.lineAnchors.map(\.id) == [100, 101], "real line IDs retained")
        check(built.lineAnchors[1].range.location == "שָׁלוֹם 😀".utf16.count + 1, "anchor uses UTF16")
        check(try service.previousDescriptor(bookId: 103, beforeLineIndex: 1, mode: .paragraph) == nil, "previous within first unit must not duplicate its first line")
        check(try service.nextDescriptor(bookId: 103, afterLineIndex: 2, mode: .paragraph) == nil, "last unit terminates")

        let sparseDB = SQLiteDatabase()
        sparseDB.mappings = [(0, 11), (1, 12), (2, 11)]
        let sparse = OtzariaReadingUnitService(database: sparseDB)
        check(try sparse.descriptor(bookId: 103, containingLineIndex: 1, mode: .paragraph)?.tocEntryId == 12, "exact sparse descriptor ownership")
        let sparseFirst = try sparse.firstDescriptor(bookId: 103, mode: .paragraph)!
        check(try sparse.nextDescriptor(bookId: 103, afterLineIndex: sparseFirst.endLineIndex, mode: .paragraph)?.tocEntryId == 12, "sparse next visits overlapping unit")
        let sparseUnit = try sparse.buildUnit(from: sparseFirst)!
        check(sparseUnit.sourceLineIndices == [0, 2], "sparse query excludes hole")

        let partialDB = SQLiteDatabase()
        partialDB.mappings = [(0, 11), (2, 12)]
        let partial = OtzariaReadingUnitService(database: partialDB)
        check(try partial.descriptor(bookId: 103, containingLineIndex: 1, mode: .paragraph)?.sourceLineIndices == [1], "unmapped source line retained")
        check(try partial.descriptor(bookId: 103, containingLineIndex: 99, mode: .paragraph) == nil, "missing locator never maps to nearby content")
        for mode in [OtzariaUnitMode.line, .paragraph, .chapter] {
            var descriptor = try partial.firstDescriptor(bookId: 103, mode: mode)
            var seen: [Int] = []
            var starts = Set<Int>()
            while let current = descriptor {
                guard starts.insert(current.startLineIndex).inserted else { failures.append("navigation loop"); break }
                let unit = try partial.buildUnit(from: current)!
                seen += unit.sourceLineIndices
                descriptor = try partial.nextDescriptor(bookId: 103, afterLineIndex: current.endLineIndex, mode: mode)
            }
            check(seen.sorted() == [0, 1, 2], "complete once-only traversal in \(mode)")
        }
        let duplicate = OtzariaReadingUnitDescriptor(id: "malformed", bookId: 103, tocEntryId: nil, title: nil, level: nil,
            startLineIndex: 0, endLineIndex: 2, sourceLineIndices: [2, 0, 0], heRef: nil)
        check(try service.buildUnit(from: duplicate)?.sourceLineIndices == [0, 2], "normalize descriptor ordering/duplicates before IN scan")
        let missing = OtzariaReadingUnitDescriptor(id: "missing", bookId: 103, tocEntryId: nil, title: nil, level: nil,
            startLineIndex: 0, endLineIndex: 3, sourceLineIndices: [0, 3], heRef: nil)
        do {
            _ = try service.buildUnit(from: missing)
            failures.append("partial read must fail explicitly")
        } catch OtzariaReadingUnitError.inconsistentSourceLines {}

        let cycleDB = SQLiteDatabase()
        cycleDB.entries = [[11, 12, "א", 1], [12, 11, "ב", 2]]
        let cycle = OtzariaReadingUnitService(database: cycleDB)
        check(try cycle.firstDescriptor(bookId: 103, mode: .chapter) != nil, "cyclic TOC terminates")

        let rootsDB = SQLiteDatabase()
        rootsDB.entries = [[10, nil, "root A", 0], [11, 10, "child A", 1], [20, nil, "root B", 0], [21, 20, "child B", 1]]
        rootsDB.lines.append([103, 3, "four", nil])
        rootsDB.mappings = [(0, 10), (1, 11), (2, 20), (3, 21)]
        let roots = OtzariaReadingUnitService(database: rootsDB)
        for mode in [OtzariaUnitMode.paragraph, .chapter] {
            check(try roots.firstDescriptor(bookId: 103, mode: mode)?.sourceLineIndices == [0, 1], "root A lines isolated")
            check(try roots.nextDescriptor(bookId: 103, afterLineIndex: 1, mode: mode)?.sourceLineIndices == [2, 3], "root B lines isolated")
        }

        let chunkDB = SQLiteDatabase()
        let indices = (0..<901).map { $0 * 2 }
        chunkDB.lines = indices.map { [1000 + $0, $0, "😀", nil] }
        let chunkService = OtzariaReadingUnitService(database: chunkDB)
        let chunkDescriptor = OtzariaReadingUnitDescriptor(id: "chunk", bookId: 103, tocEntryId: nil, title: nil, level: nil,
            startLineIndex: 0, endLineIndex: 1800, sourceLineIndices: indices, heRef: nil)
        check(try chunkService.buildUnit(from: chunkDescriptor)?.sourceLineIndices == indices, "901 discontiguous rows cross chunk boundary exactly once")
        check(chunkDB.sourceFetches == 2, "IN scan bounded to 900 indices per query")

        let oversizedDB = SQLiteDatabase()
        oversizedDB.entries = [[11, nil, String(repeating: "x", count: 250_001), 0]]
        oversizedDB.mappings = [(0, 11), (1, 11), (2, 11)]
        let oversized = OtzariaReadingUnitService(database: oversizedDB)
        _ = try oversized.firstDescriptor(bookId: 103, mode: .paragraph)
        let state = Mirror(reflecting: oversized)
        check(state.children.first(where: { $0.label == "indexCacheCost" })?.value as? Int == 0, "oversized index not retained")
        check(state.children.first(where: { $0.label == "summariesCacheCost" })?.value as? Int == 0, "oversized summaries not retained")

        let cancelDB = SQLiteDatabase()
        let cancelService = OtzariaReadingUnitService(database: cancelDB)
        cancelDB.onFetch = { withUnsafeCurrentTask { $0?.cancel() } }
        let cancelled = Task.detached { () -> Bool in
            do { _ = try cancelService.firstDescriptor(bookId: 103, mode: .paragraph); return false }
            catch is CancellationError { return true }
            catch { return false }
        }
        let didCancel = await cancelled.value
        check(didCancel && cancelDB.sourceFetches == 0, "cancelled metadata fetch propagates before decode")
        print("service: \(failures.isEmpty ? "PASS" : "FAIL") — \(failures.joined(separator: "; "))")
        if !failures.isEmpty { exit(1) }
    }
}
