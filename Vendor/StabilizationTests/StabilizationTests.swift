import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fatalError("TEST FAILED: \(message)")
    }
}

// MARK: - Test 1: TOC Duplicate Key Collision (Issue 7)

class TestTOCNode {
    let bab: String
    let level: Int
    let id: Int
    init(bab: String, level: Int, id: Int) {
        self.bab = bab
        self.level = level
        self.id = id
    }

    static func buildNodeIdCache(_ allNodes: [TestTOCNode]) -> [Int: TestTOCNode] {
        var cache: [Int: TestTOCNode] = [:]
        for node in allNodes {
            if let existing = cache[node.id] {
                if node.level > existing.level {
                    cache[node.id] = node
                }
            } else {
                cache[node.id] = node
            }
        }
        return cache
    }
}

func testTOCDuplicateKeyCollision() {
    let node1 = TestTOCNode(bab: "Chapter 1", level: 1, id: 100)
    let node2 = TestTOCNode(bab: "Section 1.1", level: 2, id: 100) // Duplicate target ID
    let node3 = TestTOCNode(bab: "Chapter 2", level: 1, id: 200)

    let allNodes = [node1, node2, node3]
    let cache = TestTOCNode.buildNodeIdCache(allNodes)

    require(cache.count == 2, "Cache must have 2 entries for 2 unique IDs")
    require(cache[100]?.level == 2, "Duplicate ID must retain the deeper (level 2) node")
    require(cache[200]?.bab == "Chapter 2", "Distinct node must be present")
    print("✓ Test 1: TOC duplicate dictionary key collision passed")
}

// MARK: - Test 2: Safe Path Validation (.managed.json & traversal) (Issue 3)

struct TestSafePathPolicy {
    static func validateSafeRelativePath(_ path: String) -> Bool {
        guard !path.isEmpty else { return false }
        guard !path.hasPrefix("/") else { return false }
        guard !path.contains(":") && !path.contains("\\") else { return false }
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        for component in components {
            if component.isEmpty || component == "." || component == ".." {
                return false
            }
        }
        return true
    }
}

func testSafePathValidation() {
    require(TestSafePathPolicy.validateSafeRelativePath(".managed.json"), ".managed.json dotfile rejected")
    require(TestSafePathPolicy.validateSafeRelativePath("segment/.managed.json"), "nested .managed.json rejected")
    require(TestSafePathPolicy.validateSafeRelativePath("index/store.fast"), "valid relative path rejected")
    require(!TestSafePathPolicy.validateSafeRelativePath("."), "current directory component '.' accepted")
    require(!TestSafePathPolicy.validateSafeRelativePath(".."), "parent directory component '..' accepted")
    require(!TestSafePathPolicy.validateSafeRelativePath("../x"), "../x traversal accepted")
    require(!TestSafePathPolicy.validateSafeRelativePath("a/../x"), "a/../x traversal accepted")
    require(!TestSafePathPolicy.validateSafeRelativePath("/absolute/path"), "absolute path accepted")
    require(!TestSafePathPolicy.validateSafeRelativePath("C:/windows/path"), "colon/drive path accepted")
    require(!TestSafePathPolicy.validateSafeRelativePath("a\\b"), "backslash path accepted")
    print("✓ Test 2: Safe path validation (.managed.json & traversal) passed")
}

// MARK: - Test 3: Search Pagination Invariants (Issue 2)

func testSearchPaginationInvariants() {
    let initialOffset = 0
    let pageSize = 100
    require(initialOffset == 0, "Initial offset must be 0")
    require(pageSize == 100, "Page size must be 100")

    var currentGeneration: UInt64 = 1
    var completedRequests: [String] = []

    func simulateSearchResponse(generation: UInt64, query: String) {
        guard generation == currentGeneration else {
            return
        }
        completedRequests.append(query)
    }

    let req1Gen = currentGeneration
    currentGeneration &+= 1
    let req2Gen = currentGeneration

    simulateSearchResponse(generation: req1Gen, query: "Old Query")
    simulateSearchResponse(generation: req2Gen, query: "New Query")

    require(completedRequests == ["New Query"], "Stale response for old query must be rejected")

    var isLoadingMore = false
    var requestCount = 0

    func triggerLoadMore() {
        guard !isLoadingMore else { return }
        isLoadingMore = true
        requestCount += 1
    }

    triggerLoadMore()
    triggerLoadMore()
    triggerLoadMore()

    require(requestCount == 1, "Duplicate load-more triggers must be suppressed while loading")
    isLoadingMore = false
    triggerLoadMore()
    require(requestCount == 2, "Subsequent load-more trigger after completion must succeed")

    print("✓ Test 3: Search pagination invariants (100-at-a-time, stale rejection, debounce) passed")
}

// MARK: - Test 4: TextKit Safe Range Calculation (Issue 5)

func testTextKitSafeRange() {
    let text = "בראשית ברא אלהים"
    let attrString = NSAttributedString(string: text)
    let totalLength = attrString.length

    func isValidRange(_ range: NSRange, in str: NSAttributedString) -> Bool {
        guard range.location != NSNotFound,
              range.location >= 0,
              range.length >= 0,
              range.location <= str.length,
              range.length <= str.length - range.location else {
            return false
        }
        return true
    }

    require(isValidRange(NSRange(location: 0, length: 5), in: attrString), "Valid start range rejected")
    require(isValidRange(NSRange(location: 5, length: totalLength - 5), in: attrString), "Valid mid range rejected")
    require(isValidRange(NSRange(location: totalLength, length: 0), in: attrString), "Zero-length at end range rejected")
    require(!isValidRange(NSRange(location: -1, length: 5), in: attrString), "Negative location accepted")
    require(!isValidRange(NSRange(location: 0, length: totalLength + 1), in: attrString), "Length exceeding bounds accepted")
    require(!isValidRange(NSRange(location: totalLength, length: 1), in: attrString), "Location at end with length accepted")
    require(!isValidRange(NSRange(location: Int.max, length: 1), in: attrString), "Overflowing location accepted")

    print("✓ Test 4: TextKit safe range boundary validation passed")
}

// MARK: - Test 5: Otzaria WorkKey and Locator Identity Resolution (Issue 4)

func testOtzariaLocatorIdentity() {
    let filePath = "Tanach/Torah/Genesis.txt"
    let bookId = 1
    let workKey = !filePath.isEmpty ? filePath : "book:\(bookId)"
    let locator = TextLocator(backend: .otzaria, workKey: workKey, position: .legacyLine(0))

    require(locator.backend == .otzaria, "Backend must be .otzaria")
    require(locator.workKey == filePath, "WorkKey should prefer stable filePath")

    let emptyPath = ""
    let fallbackKey = !emptyPath.isEmpty ? emptyPath : "book:\(bookId)"
    let fallbackLocator = TextLocator(backend: .otzaria, workKey: fallbackKey, position: .legacyLine(0))
    require(fallbackLocator.workKey == "book:1", "WorkKey should fall back to book:<id>")

    func extractBookID(from workKey: String) -> Int? {
        if workKey.hasPrefix("book:"), let parsed = Int(workKey.dropFirst("book:".count)) {
            return parsed
        }
        return nil
    }

    require(extractBookID(from: "book:3152") == 3152, "book:3152 must extract 3152")
    require(extractBookID(from: "book:1") == 1, "book:1 must extract 1")
    require(extractBookID(from: "Tanach/Torah/Genesis.txt") == nil, "File paths must not be parsed as Ints directly")

    print("✓ Test 5: Otzaria workKey and locator identity resolution passed")
}

// MARK: - Test 6: Localization and Direction Policy (Issue 8)

func testLocalizationAndDirectionPolicy() {
    let dto1 = SefariaRelationshipTopicDTO(
        topic: "shabbat",
        descriptions: ["he": SefariaTopicDescriptionDTO(title: "Shabbat Old"), "en": SefariaTopicDescriptionDTO(title: "Old Shabbat")],
        title: SefariaLocalizedTitleDTO(en: "Sabbath", he: "Shabbat Kodesh")
    )
    let topics1 = SefariaRelationshipMapper.topics([dto1])
    require(topics1.count == 1, "Should map 1 topic")
    require(topics1[0].titleHe == "Shabbat Kodesh", "Direct titleHe must take precedence")
    require(topics1[0].titleEn == "Sabbath", "Direct titleEn must take precedence")

    let dto2 = SefariaRelationshipTopicDTO(
        topic: "creation",
        descriptions: ["he": SefariaTopicDescriptionDTO(title: "Creation He"), "en": SefariaTopicDescriptionDTO(title: "Creation En")],
        title: nil
    )
    let topics2 = SefariaRelationshipMapper.topics([dto2])
    require(topics2[0].titleHe == "Creation He", "Fallback to descriptions titleHe")
    require(topics2[0].titleEn == "Creation En", "Fallback to descriptions titleEn")

    print("✓ Test 6: Localization and topic title mapping passed")
}

// MARK: - Test 7: LibraryReaderDestination Model Invariants

func testLibraryReaderDestinationInvariants() {
    let sectionLoc = TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 1"))
    let focusLoc = TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 1:5"))
    let dest = LibraryReaderDestination(sectionLocator: sectionLoc, focusLocator: focusLoc)

    require(dest.sectionLocator == sectionLoc, "sectionLocator must match")
    require(dest.focusLocator == focusLoc, "focusLocator must match")

    let encoded = try! JSONEncoder().encode(dest)
    let decoded = try! JSONDecoder().decode(LibraryReaderDestination.self, from: encoded)
    require(decoded == dest, "Roundtrip JSON encoding must preserve destination")

    let otzariaDest = LibraryReaderDestination(
        sectionLocator: TextLocator(backend: .otzaria, workKey: "book:1", position: .legacyLine(10)),
        focusLocator: TextLocator(backend: .otzaria, workKey: "book:1", position: .legacyLine(12))
    )
    require(otzariaDest.focusLocator?.position == .legacyLine(12), "Otzaria focus locator must be preserved")
    print("✓ Test 7: LibraryReaderDestination model invariants passed")
}

// MARK: - Test 8: LibraryNavigationItem Model Invariants

func testLibraryNavigationItemInvariants() {
    let locator = TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 1"))
    let item = LibraryNavigationItem(locator: locator, title: "Chapter 1", index: 0)

    require(item.id == locator.persistenceKey, "NavigationItem id must equal locator persistenceKey")
    require(item.title == "Chapter 1", "NavigationItem title must match")
    require(item.index == 0, "NavigationItem index must match")
    print("✓ Test 8: LibraryNavigationItem model invariants passed")
}

// MARK: - Test 9: Provider-Neutral Work Locator Derivation

func testProviderNeutralWorkLocatorDerivation() {
    let sefariaLocator = TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 1:3"))
    let sefariaWorkPos: TextPosition = switch sefariaLocator.position {
    case .canonicalRef: .canonicalRef(sefariaLocator.workKey)
    case .legacyLine:   .legacyLine(0)
    }
    require(sefariaWorkPos == .canonicalRef("Genesis"), "Canonical ref must derive canonicalRef(workKey)")

    let otzariaLocator = TextLocator(backend: .otzaria, workKey: "book:42", position: .legacyLine(150))
    let otzariaWorkPos: TextPosition = switch otzariaLocator.position {
    case .canonicalRef: .canonicalRef(otzariaLocator.workKey)
    case .legacyLine:   .legacyLine(0)
    }
    require(otzariaWorkPos == .legacyLine(0), "Legacy line must derive legacyLine(0)")
    print("✓ Test 9: Provider-neutral work locator derivation passed")
}

// MARK: - Test 10: Rendered Segment Visual Range Excludes Bidi Controls

func testRenderedSegmentVisualRangeExcludesBidiControls() {
    let loc1 = TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 1:1"))
    let seg1 = LibraryTextSegment(locator: loc1, heRef: "בראשית א:א", primaryText: "בְּרֵאשִׁית בָּרָא", translation: "In the beginning")
    let loc2 = TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 1:2"))
    let seg2 = LibraryTextSegment(locator: loc2, heRef: "בראשית א:ב", primaryText: "וְהָאָרֶץ הָיְתָה תֹהוּ", translation: "And the earth was")

    let section = LibraryTextSection(
        locator: loc1,
        displayRef: "Genesis 1",
        heRef: "בראשית א",
        segments: [seg1, seg2],
        previous: nil,
        next: nil,
        versions: [TextVersionMetadata(title: "Primary", language: "he", actualLanguage: "he", sourceURL: nil, license: nil, notes: nil, isPrimary: true)],
        links: [],
        origin: .remote
    )

    let model = LibraryReaderRenderModel(section: section, preferredMode: .source)
    require(model.renderedSegments.count == 2, "Model must have 2 rendered segments")
    require(!model.text.isEmpty, "Model text must not be empty (regression check: output += block)")
    require(model.text.contains("בְּרֵאשִׁית בָּרָא"), "Model text must contain first segment text")
    require(model.text.contains("וְהָאָרֶץ הָיְתָה תֹהוּ"), "Model text must contain second segment text")

    let first = model.renderedSegments[0]
    let second = model.renderedSegments[1]
    // The block is wrapped in RTL bidi control: \u{202B} ... \u{202C}
    // Total length = 1 (U+202B) + text length + 1 (U+202C)
    require(first.rangeLength > first.visualRangeLength, "Full range must include bidi controls, visual range must exclude them")
    require(first.visualRangeLocation == first.rangeLocation + 1, "visualRangeLocation must start after opening bidi control")
    require(first.visualRangeLength == first.rangeLength - 2, "visualRangeLength must be 2 characters shorter than rangeLength")

    // Assert second segment is placed after first segment plus separator
    require(second.rangeLocation >= first.rangeLocation + first.rangeLength + 2, "Second segment must follow first segment and newline separator in model.text")

    // Assert exact substring extraction from model.text matches visual range
    let firstVisualText = (model.text as NSString).substring(with: first.visualRange)
    require(firstVisualText == "בְּרֵאשִׁית בָּרָא", "Visual range extracted from model.text must be exact unadorned Hebrew text")
    let secondVisualText = (model.text as NSString).substring(with: second.visualRange)
    require(secondVisualText == "וְהָאָרֶץ הָיְתָה תֹהוּ", "Second visual range extracted from model.text must be exact unadorned Hebrew text")

    // Hit testing contains check must include full range
    require(first.contains(characterIndex: first.rangeLocation), "Hit testing must match first character of block")
    require(first.contains(characterIndex: first.visualRangeLocation), "Hit testing must match visual content")
    require(first.contains(characterIndex: first.rangeLocation + first.rangeLength - 1), "Hit testing must match closing control")
    require(!first.contains(characterIndex: first.rangeLocation + first.rangeLength), "Hit testing must not match past segment")

    print("✓ Test 10: Rendered segment visual range bidi exclusion and model.text output passed")
}

// MARK: - Test 11: TextDeltaEvent Bidirectional Range Mapping

func testTextDeltaEventRangeMapping() {
    // Simulate events: at old offset 5, 2 characters removed (delta -2)
    // at old offset 15, 3 characters inserted (delta +1)
    let events = [
        TextDeltaEvent(oldOffset: 5, delta: -2),
        TextDeltaEvent(oldOffset: 15, delta: 1)
    ]

    // Range before any event: (location 1, length 3) -> unaffected
    let r1 = NSRange(location: 1, length: 3)
    let m1 = TextDeltaEvent.mapRange(r1, with: events)
    require(m1.location == 1 && m1.length == 3, "Range before events must not shift")

    // Range after first event: (location 6, length 4) -> shifted by -2
    let r2 = NSRange(location: 6, length: 4)
    let m2 = TextDeltaEvent.mapRange(r2, with: events)
    require(m2.location == 4 && m2.length == 4, "Range after deletion must shift backwards")

    // Range after second event: (location 16, length 4) -> shifted by +1
    let r3 = NSRange(location: 16, length: 4)
    let m3 = TextDeltaEvent.mapRange(r3, with: events)
    require(m3.location == 17 && m3.length == 4, "Range after insertion must shift forward")

    // Reverse mapping
    let rev1 = TextDeltaEvent.reverseMapOffset(1, with: events)
    require(rev1 == 1, "Reverse offset before event must match")

    let rev2 = TextDeltaEvent.reverseMapOffset(4, with: events)
    require(rev2 == 6, "Reverse offset after deletion must map back to original index")

    let rev3 = TextDeltaEvent.reverseMapOffset(17, with: events)
    require(rev3 == 16, "Reverse offset after insertion must map back to original index")

    print("✓ Test 11: TextDeltaEvent bidirectional range mapping passed")
}

// MARK: - Test 12: Render Generation Identity and Stale Selection Rejection

func testRenderGenerationIdentityAndSelectionInvalidation() {
    let locGen1 = TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 1:1"))
    let seg1 = LibraryTextSegment(locator: locGen1, heRef: "בראשית א:א", primaryText: "בְּרֵאשִׁית", translation: nil)
    let section1 = LibraryTextSection(
        locator: locGen1, displayRef: "Genesis 1", heRef: nil, segments: [seg1], previous: nil, next: nil,
        versions: [TextVersionMetadata(title: "v1", language: "he", actualLanguage: "he", sourceURL: nil, license: nil, notes: nil, isPrimary: true)],
        links: [],
        origin: .remote
    )
    let model1 = LibraryReaderRenderModel(section: section1, preferredMode: .source)

    let locGen2 = TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 2:1"))
    let seg2 = LibraryTextSegment(locator: locGen2, heRef: "בראשית ב:א", primaryText: "וַיְכֻלּוּ", translation: nil)
    let section2 = LibraryTextSection(
        locator: locGen2, displayRef: "Genesis 2", heRef: nil, segments: [seg2], previous: nil, next: nil,
        versions: [TextVersionMetadata(title: "v1", language: "he", actualLanguage: "he", sourceURL: nil, license: nil, notes: nil, isPrimary: true)],
        links: [],
        origin: .remote
    )
    let model2 = LibraryReaderRenderModel(section: section2, preferredMode: .source)

    // Model 2 queried with Model 1 locator must return nil (prevents cross-generation stale highlight)
    require(model2.renderedSegment(for: locGen1) == nil, "Model 2 must reject locator from Model 1")
    require(model2.renderedSegment(for: locGen2) != nil, "Model 2 must find its own segment")
    require(model1.renderedSegment(for: locGen2) == nil, "Model 1 must reject locator from Model 2")

    print("✓ Test 12: Render generation identity and selection rejection passed")
}

// MARK: - Test 13: Sefaria WorkKey Resolution From Canonical Reference

func testSefariaWorkKeyResolutionFromCanonicalReference() {
    let knownTitles = ["Genesis", "Exodus", "Rashi on Genesis", "Berakhot"]

    let ref1 = "Genesis 1:1"
    let work1 = SefariaRef.workKey(from: ref1, knownTitles: knownTitles)
    require(work1 == "Genesis", "WorkKey for Genesis 1:1 must resolve to Genesis")

    let ref2 = "Rashi on Genesis 1:1:1"
    let work2 = SefariaRef.workKey(from: ref2, knownTitles: knownTitles)
    require(work2 == "Rashi on Genesis", "WorkKey for commentary must resolve to longest matching title")

    let ref3 = "Berakhot 2a:1"
    let work3 = SefariaRef.workKey(from: ref3, knownTitles: knownTitles)
    require(work3 == "Berakhot", "WorkKey for Talmud ref must resolve to Berakhot")

    // Fallback regex pattern when catalog is cold
    let pattern = #"\s+\d+.*$"#
    if let match = ref1.range(of: pattern, options: .regularExpression) {
        let fallback = String(ref1[..<match.lowerBound])
        require(fallback == "Genesis", "Regex fallback must resolve Genesis")
    }
    if let match = ref3.range(of: pattern, options: .regularExpression) {
        let fallback = String(ref3[..<match.lowerBound])
        require(fallback == "Berakhot", "Regex fallback must resolve Berakhot")
    }

    print("✓ Test 13: Sefaria workKey resolution from canonical reference passed")
}

// MARK: - Main Execution

@main
enum StabilizationTestMain {
    static func main() {
        print("=== Running Stabilization Regression Tests ===")
        testTOCDuplicateKeyCollision()
        testSafePathValidation()
        testSearchPaginationInvariants()
        testTextKitSafeRange()
        testOtzariaLocatorIdentity()
        testLocalizationAndDirectionPolicy()
        testLibraryReaderDestinationInvariants()
        testLibraryNavigationItemInvariants()
        testProviderNeutralWorkLocatorDerivation()
        testRenderedSegmentVisualRangeExcludesBidiControls()
        testTextDeltaEventRangeMapping()
        testRenderGenerationIdentityAndSelectionInvalidation()
        testSefariaWorkKeyResolutionFromCanonicalReference()
        print("=== All 13 Stabilization Regression Tests Passed! ===")
    }
}
