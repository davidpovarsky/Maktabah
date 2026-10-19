import Foundation

func runOtzariaPerformanceUnitTests() throws {
    print("[OtzariaPerformanceUnitTests] Running...")

    // 1. Test Mode Isolation in OtzariaReadingUnitSideCache
    do {
        let cache = OtzariaReadingUnitSideCache.shared
        cache.clear()

        let unitParagraph = OtzariaReadingUnit(
            id: "unit-paragraph-1",
            bookId: 103,
            mode: .paragraph,
            tocEntryId: 1558,
            title: "דף ב.",
            level: 1,
            startLineIndex: 0,
            endLineIndex: 15,
            sourceLineIndices: Array(0...15),
            lineAnchors: [
                OtzariaLineAnchor(id: 1, bookId: 103, lineIndex: 0, heRef: "ברכות", text: "ברכות", range: NSRange(location: 0, length: 5))
            ],
            html: "<h1>ברכות</h1>",
            plainText: "ברכות",
            heRef: "ברכות דף ב."
        )

        cache.set(unitParagraph, mode: .paragraph)

        // Exact match
        let fetchedParagraph = cache.unit(bookId: 103, contentId: 0, mode: .paragraph)
        try expect(fetchedParagraph != nil, "SideCache must return paragraph unit when requested with .paragraph")
        try expect(fetchedParagraph?.id == "unit-paragraph-1", "SideCache must return exact unit")
        try expect(fetchedParagraph?.mode == .paragraph, "Unit mode must be .paragraph")

        // Range check in paragraph mode
        let fetchedMid = cache.unit(bookId: 103, contentId: 7, mode: .paragraph)
        try expect(fetchedMid != nil, "SideCache must resolve intermediate line 7 in paragraph mode")
        try expect(fetchedMid?.id == "unit-paragraph-1", "SideCache must resolve line 7 to unit-paragraph-1")

        // STRICT ISOLATION: Must NEVER return paragraph unit when chapter or line mode is requested!
        let fetchedChapter = cache.unit(bookId: 103, contentId: 0, mode: .chapter)
        try expect(fetchedChapter == nil, "SideCache MUST NOT return paragraph unit when .chapter mode is requested")

        let fetchedChapterMid = cache.unit(bookId: 103, contentId: 7, mode: .chapter)
        try expect(fetchedChapterMid == nil, "SideCache MUST NOT resolve line 7 in .chapter mode when only paragraph is cached")

        let fetchedLine = cache.unit(bookId: 103, contentId: 0, mode: .line)
        try expect(fetchedLine == nil, "SideCache MUST NOT return paragraph unit when .line mode is requested")

        // Now cache a different unit under .chapter mode
        let unitChapter = OtzariaReadingUnit(
            id: "unit-chapter-1",
            bookId: 103,
            mode: .chapter,
            tocEntryId: 1557,
            title: "פרק ראשון",
            level: 0,
            startLineIndex: 0,
            endLineIndex: 400,
            sourceLineIndices: Array(0...400),
            lineAnchors: [],
            html: "פרק",
            plainText: "פרק",
            heRef: "פרק א"
        )
        cache.set(unitChapter, mode: .chapter)

        let recheckParagraph = cache.unit(bookId: 103, contentId: 0, mode: .paragraph)
        try expect(recheckParagraph?.id == "unit-paragraph-1", "Paragraph lookup must still return unit-paragraph-1")

        let recheckChapter = cache.unit(bookId: 103, contentId: 0, mode: .chapter)
        try expect(recheckChapter?.id == "unit-chapter-1", "Chapter lookup must return unit-chapter-1")
    }

    // 2. Test Generation Isolation in OtzariaReadingUnitSideCache
    do {
        let cache = OtzariaReadingUnitSideCache.shared
        cache.clear()

        let unit = OtzariaReadingUnit(
            id: "unit-gen-1",
            bookId: 42,
            mode: .paragraph,
            tocEntryId: nil,
            title: "Unit",
            level: nil,
            startLineIndex: 10,
            endLineIndex: 20,
            sourceLineIndices: Array(10...20),
            lineAnchors: [],
            html: "",
            plainText: "hello",
            heRef: nil
        )
        cache.set(unit, mode: .paragraph)
        try expect(cache.unit(bookId: 42, contentId: 10, mode: .paragraph) != nil, "Unit must exist before clear")

        // Clear increments generation
        cache.clear()
        try expect(cache.unit(bookId: 42, contentId: 10, mode: .paragraph) == nil, "Unit from previous generation must be purged after clear()")
    }

    // 3. Test Descriptor Semantic Parity
    do {
        let desc = OtzariaReadingUnitDescriptor(
            id: "desc-1",
            bookId: 103,
            mode: .chapter,
            includeDescendants: true,
            tocEntryId: 1557,
            title: "ברכות",
            level: 0,
            startLineIndex: 0,
            endLineIndex: 2874,
            sourceLineIndices: [0, 1, 2],
            heRef: "ספר ברכות",
            previousStartLineIndex: nil,
            nextStartLineIndex: 2875
        )

        try expect(desc.mode == .chapter, "Descriptor preserves mode .chapter")
        try expect(desc.includeDescendants == true, "Descriptor preserves includeDescendants")
        try expect(desc.startLineIndex == 0, "Descriptor preserves startLineIndex")
        try expect(desc.endLineIndex == 2874, "Descriptor preserves endLineIndex")

        let updated = desc.withNavigation(previousStartLineIndex: 10, nextStartLineIndex: 20)
        try expect(updated.mode == .chapter, "withNavigation preserves mode")
        try expect(updated.includeDescendants == true, "withNavigation preserves includeDescendants")
        try expect(updated.previousStartLineIndex == 10, "withNavigation updates previous")
        try expect(updated.nextStartLineIndex == 20, "withNavigation updates next")
    }

    // 4. Test Descriptor Unit Building & Mode Preservation
    do {
        let desc = OtzariaReadingUnitDescriptor(
            id: "desc-berakhot-p1",
            bookId: 103,
            mode: .paragraph,
            includeDescendants: false,
            tocEntryId: 1558,
            title: "דף ב.",
            level: 1,
            startLineIndex: 0,
            endLineIndex: 15,
            sourceLineIndices: Array(0...15),
            heRef: "ברכות דף ב.",
            previousStartLineIndex: nil,
            nextStartLineIndex: 16
        )

        try expect(desc.mode == .paragraph, "Descriptor mode is .paragraph")
        try expect(desc.sourceLineIndices.count == 16, "Descriptor covers 16 lines")
        try expect(desc.sourceLineIndices.first == 0, "Descriptor starts at 0")
        try expect(desc.sourceLineIndices.last == 15, "Descriptor ends at 15")
    }

    // 5. Test Multi-Root Title Line Policy Simulation
    do {
        struct MockEntry {
            let id: Int
            let parentId: Int?
        }
        let entries: [Int: MockEntry] = [
            100: MockEntry(id: 100, parentId: nil),
            101: MockEntry(id: 101, parentId: 100),
            200: MockEntry(id: 200, parentId: nil),
            201: MockEntry(id: 201, parentId: 200)
        ]
        let leafEntryByLine: [(Int, Int)] = [
            (0, 100), // Root 1 title line
            (1, 101),
            (2, 101),
            (3, 101),
            (4, 200), // Root 2 title line
            (5, 201),
            (6, 201)
        ]
        func rootId(for entryId: Int) -> Int {
            var curr = entryId
            while let e = entries[curr], let p = e.parentId {
                curr = p
            }
            return curr
        }

        let rootTitleLines: [Int: [Int]] = [
            100: [0],
            200: [4]
        ]
        var lineIndicesByUnitId: [Int: [Int]] = [:]
        var heldRootLinesByRootId: [Int: [Int]] = [:]

        for (lineIndex, leafId) in leafEntryByLine {
            if rootTitleLines[leafId] != nil {
                heldRootLinesByRootId[leafId, default: []].append(lineIndex)
                continue
            }
            let unitId = leafId
            if lineIndicesByUnitId[unitId] == nil {
                lineIndicesByUnitId[unitId] = []
                let rootOfUnit = rootId(for: unitId)
                if let held = heldRootLinesByRootId.removeValue(forKey: rootOfUnit) {
                    lineIndicesByUnitId[unitId]?.append(contentsOf: held)
                }
            }
            lineIndicesByUnitId[unitId, default: []].append(lineIndex)
        }

        let unit1Lines = lineIndicesByUnitId[101] ?? []
        let unit2Lines = lineIndicesByUnitId[201] ?? []

        try expect(unit1Lines == [0, 1, 2, 3], "Root 1's title line (0) must be attached to Child 1A [0, 1, 2, 3], actual: \(unit1Lines)")
        try expect(unit2Lines == [4, 5, 6], "Root 2's title line (4) must be attached to Child 2A [4, 5, 6], actual: \(unit2Lines)")
        try expect(!unit2Lines.contains(0), "Root 1's title line (0) must NEVER leak into Root 2's child unit!")
        try expect(!unit1Lines.contains(4), "Root 2's title line (4) must NEVER leak into Root 1's child unit!")
    }

    // 6. Test Database Switch Atomic Cache Clearance
    do {
        let cache = OtzariaReadingUnitSideCache.shared
        cache.clear()

        let dummyUnit = OtzariaReadingUnit(
            id: "dummy-db-1",
            bookId: 999,
            mode: .paragraph,
            tocEntryId: 1,
            title: "Test",
            level: 0,
            startLineIndex: 0,
            endLineIndex: 10,
            sourceLineIndices: Array(0...10),
            lineAnchors: [],
            html: "",
            plainText: "Test",
            heRef: nil
        )
        cache.set(dummyUnit, mode: .paragraph)
        try expect(cache.unit(bookId: 999, contentId: 0, mode: .paragraph) != nil, "Dummy unit cached")

        cache.clear()
        try expect(cache.unit(bookId: 999, contentId: 0, mode: .paragraph) == nil, "Reading units cache cleared")
    }

    print("[OtzariaPerformanceUnitTests] All tests passed!")
}
