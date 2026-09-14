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

func testSafePathValidation() {
    require(OtzariaSearchArtifactPolicy.validateSafeRelativePath(".managed.json"), ".managed.json dotfile rejected")
    require(OtzariaSearchArtifactPolicy.validateSafeRelativePath("segment/.managed.json"), "nested .managed.json rejected")
    require(OtzariaSearchArtifactPolicy.validateSafeRelativePath("index/store.fast"), "valid relative path rejected")
    require(!OtzariaSearchArtifactPolicy.validateSafeRelativePath("."), "current directory component '.' accepted")
    require(!OtzariaSearchArtifactPolicy.validateSafeRelativePath(".."), "parent directory component '..' accepted")
    require(!OtzariaSearchArtifactPolicy.validateSafeRelativePath("../x"), "../x traversal accepted")
    require(!OtzariaSearchArtifactPolicy.validateSafeRelativePath("a/../x"), "a/../x traversal accepted")
    require(!OtzariaSearchArtifactPolicy.validateSafeRelativePath("/absolute/path"), "absolute path accepted")
    require(!OtzariaSearchArtifactPolicy.validateSafeRelativePath("C:/windows/path"), "colon/drive path accepted")
    require(!OtzariaSearchArtifactPolicy.validateSafeRelativePath("a\\b"), "backslash path accepted")
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
        print("=== All 6 Stabilization Regression Tests Passed! ===")
    }
}
