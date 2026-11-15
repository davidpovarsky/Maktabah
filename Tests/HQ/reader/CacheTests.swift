import Foundation

func unit(_ start: Int, indices: [Int]? = nil, text: String = "שָׁלוֹם 😀", mode: OtzariaUnitMode = .paragraph, title: String? = nil) -> OtzariaReadingUnit {
    let lines = indices ?? [start]
    return OtzariaReadingUnit(id: "unit:\(start)", bookId: 103, mode: mode, tocEntryId: nil, title: title, level: nil,
        startLineIndex: lines.first!, endLineIndex: lines.last!, sourceLineIndices: lines, lineAnchors: [],
        html: text, plainText: text, heRef: nil)
}

@main struct CacheTests {
    static func main() {
        let cache = OtzariaReadingUnitSideCache.shared
        cache.clear()
        cache.set(unit(0, indices: [0, 2]), mode: .paragraph)
        var failures: [String] = []
        func check(_ value: Bool, _ message: String) { if !value { failures.append(message) } }
        check(cache.unit(bookId: 103, contentId: 1, mode: .paragraph) == nil, "sparse unit must not claim missing line 1")
        check(cache.unit(bookId: 103, contentId: 2, mode: .paragraph)?.sourceLineIndices == [0, 2], "sparse actual member resolves")
        check(cache.unit(bookId: 103, contentId: 0, mode: .chapter) == nil, "mode isolated")
        check(cache.unit(bookId: 104, contentId: 0, mode: .paragraph) == nil, "book isolated")
        cache.clear()
        check(cache.unit(bookId: 103, contentId: 0, mode: .paragraph) == nil, "clear invalidates")
        for index in 0..<50 { cache.set(unit(index), mode: .paragraph) }
        _ = cache.unit(bookId: 103, contentId: 0, mode: .paragraph)
        cache.set(unit(50), mode: .paragraph)
        check(cache.unit(bookId: 103, contentId: 0, mode: .paragraph) != nil, "recently read entry retained")
        check(cache.unit(bookId: 103, contentId: 1, mode: .paragraph) == nil, "least recent entry evicted")
        cache.set(unit(999, text: String(repeating: "x", count: 6 * 1024 * 1024)), mode: .paragraph)
        check(cache.unit(bookId: 103, contentId: 999, mode: .paragraph) == nil, "oversized payload not retained")
        cache.set(unit(1000, mode: .chapter), mode: .paragraph)
        check(cache.unit(bookId: 103, contentId: 1000, mode: .paragraph) == nil, "mismatched publication mode rejected")
        cache.set(unit(1001, title: String(repeating: "x", count: 11 * 1024 * 1024)), mode: .paragraph)
        check(cache.unit(bookId: 103, contentId: 1001, mode: .paragraph) == nil, "oversized metadata not retained")
        print("cache: \(failures.isEmpty ? "PASS" : "FAIL") — \(failures.joined(separator: "; "))")
        if !failures.isEmpty { exit(1) }
    }
}
