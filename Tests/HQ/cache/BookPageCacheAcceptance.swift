import Foundation
import Dispatch
import Synchronization

@main
struct CacheBudgetAcceptance {
    static func processed(_ source: String, _ display: String) -> ProcessedArabicContent {
        ProcessedArabicContent(sourceText: source, displayText: display,
            coloredRanges: [NSRange(location: 1, length: 2)],
            footnoteRanges: [NSRange(location: 3, length: 4)],
            replacementEvents: [HonorificReplacementEvent(oldRange: NSRange(location: 5, length: 6), newLength: 7)],
            importedHeaderRanges: [NSRange(location: 8, length: 9)],
            ligatureRanges: [NSRange(location: 10, length: 11)],
            harakatEvents: [TextDeltaEvent(oldOffset: 12, delta: -2)],
            cleaningEvents: [TextDeltaEvent(oldOffset: 14, delta: -3)])
    }

    static func main() {
        let cache = BookPageCache.shared
        let mib = 1024 * 1024
        let maximumPayload = 32 * 1024 * 1024
        let key = CleanedTextKey(showHarakat: true, isMultiLanguage: false, isImported: false, textHash: 17)
        var passed = [String]()
        var failed = [String]()
        func check(_ name: String, _ condition: Bool) {
            if condition { passed.append(name); print("PASS: " + name) }
            else { failed.append(name); print("FAIL: " + name) }
        }

        cache.removeAll()
        let locator = TextLocator(backend: .otzaria, workKey: "book:17", position: .canonicalRef("בראשית א:א"))
        let raw = BookContent(id: 7, nash: "בְּרֵאשִׁית 👨‍👩‍👧‍👦 العربية", page: 2, part: 3,
            surah: 4, aya: 5, heRef: "בראשית א:א", backendLocator: locator)
        cache.set(bookId: 11, content: raw)
        let read = cache.get(bookId: 11, contentId: 7)
        check("Raw text and all original metadata survive unchanged",
            read?.nash == raw.nash && read?.id == 7 && read?.page == 2 && read?.part == 3 &&
            read?.surah == 4 && read?.aya == 5 && read?.heRef == raw.heRef && read?.backendLocator == locator)
        cache.set(bookId: 12, content: BookContent(id: 7, nash: "other book"))
        check("Same content ID stays scoped to its book",
            cache.get(bookId: 11, contentId: 7)?.nash == raw.nash &&
            cache.get(bookId: 12, contentId: 7)?.nash == "other book")
        cache.set(bookId: 11, content: BookContent(id: 7, nash: "replacement"))
        check("Small replacement returns only the current value", cache.get(bookId: 11, contentId: 7)?.nash == "replacement")

        let rich = processed(raw.nash, "display")
        cache.setProcessed(bookId: 11, contentId: 7, key: key, content: rich)
        let richRead = cache.getProcessed(bookId: 11, contentId: 7, key: key)
        check("Processed value keeps its original immutable identity", richRead === rich)
        check("Every renderer range and delta remains unchanged",
            richRead?.coloredRanges == rich.coloredRanges && richRead?.footnoteRanges == rich.footnoteRanges &&
            richRead?.importedHeaderRanges == rich.importedHeaderRanges && richRead?.ligatureRanges == rich.ligatureRanges &&
            richRead?.replacementEvents.first?.oldRange == rich.replacementEvents.first?.oldRange &&
            richRead?.replacementEvents.first?.newLength == 7 &&
            richRead?.harakatEvents == rich.harakatEvents && richRead?.cleaningEvents == rich.cleaningEvents)
        for mask in 0..<16 {
            let variant = CleanedTextKey(showHarakat: mask & 1 != 0, isMultiLanguage: mask & 2 != 0,
                isImported: mask & 4 != 0, textHash: mask & 8 == 0 ? 100 : 200)
            cache.setProcessed(bookId: 20, contentId: 8, key: variant, content: processed("s\(mask)", "d\(mask)"))
        }
        check("All render flags and both text hashes remain isolated", (0..<16).allSatisfy { mask in
            let variant = CleanedTextKey(showHarakat: mask & 1 != 0, isMultiLanguage: mask & 2 != 0,
                isImported: mask & 4 != 0, textHash: mask & 8 == 0 ? 100 : 200)
            return cache.getProcessed(bookId: 20, contentId: 8, key: variant)?.displayText == "d\(mask)"
        })
        cache.remove(bookId: 11)
        check("Per-book removal clears raw and processed together",
            cache.get(bookId: 11, contentId: 7) == nil && cache.getProcessed(bookId: 11, contentId: 7, key: key) == nil)
        check("Per-book removal preserves another book", cache.get(bookId: 12, contentId: 7)?.nash == "other book")
        cache.removeAll()
        check("Global removal clears both stores", cache.get(bookId: 12, contentId: 7) == nil &&
            cache.getProcessed(bookId: 20, contentId: 8, key: CleanedTextKey(showHarakat: false, isMultiLanguage: false, isImported: false, textHash: 100)) == nil)

        cache.set(bookId: 30, content: BookContent(id: 1, nash: "old"))
        cache.set(bookId: 30, content: BookContent(id: 1, nash: String(repeating: "A", count: 40 * mib)))
        check("A raw page larger than the byte budget is not retained and invalidates the old identity",
            cache.get(bookId: 30, contentId: 1) == nil)
        cache.removeAll()
        cache.set(bookId: 31, content: BookContent(id: 1, nash: "small", heRef: String(repeating: "R", count: 12 * mib)))
        check("Large reference metadata contributes to retention cost", cache.get(bookId: 31, contentId: 1) == nil)
        cache.removeAll()
        cache.set(bookId: 32, content: BookContent(id: 1, nash: "small", backendLocator:
            TextLocator(backend: .otzaria, workKey: String(repeating: "K", count: 6 * mib),
                position: .canonicalRef(String(repeating: "R", count: 6 * mib)))))
        check("Both locator strings contribute to retention cost", cache.get(bookId: 32, contentId: 1) == nil)
        cache.removeAll()
        cache.setProcessed(bookId: 33, contentId: 1, key: key, content: processed("old", "old"))
        cache.setProcessed(bookId: 33, contentId: 1, key: key,
            content: processed(String(repeating: "S", count: 20 * mib), String(repeating: "D", count: 20 * mib)))
        check("Oversized processed text is not retained and invalidates the old identity",
            cache.getProcessed(bookId: 33, contentId: 1, key: key) == nil)
        cache.removeAll()
        cache.setProcessed(bookId: 34, contentId: 1, key: key, content:
            ProcessedArabicContent(sourceText: "", displayText: "",
                coloredRanges: Array(repeating: NSRange(location: 0, length: 1), count: 1_100_000),
                footnoteRanges: [], replacementEvents: [], importedHeaderRanges: [], ligatureRanges: []))
        check("Range storage contributes to processed retention cost", cache.getProcessed(bookId: 34, contentId: 1, key: key) == nil)
        cache.removeAll()
        cache.setProcessed(bookId: 35, contentId: 1, key: key, content:
            ProcessedArabicContent(sourceText: "", displayText: "", coloredRanges: [], footnoteRanges: [],
                replacementEvents: Array(repeating: HonorificReplacementEvent(oldRange: NSRange(location: 0, length: 1), newLength: 1), count: 800_000),
                importedHeaderRanges: [], ligatureRanges: []))
        check("Replacement event storage contributes to retention cost", cache.getProcessed(bookId: 35, contentId: 1, key: key) == nil)
        cache.removeAll()
        cache.setProcessed(bookId: 36, contentId: 1, key: key, content:
            ProcessedArabicContent(sourceText: "", displayText: "", coloredRanges: [], footnoteRanges: [],
                replacementEvents: [], importedHeaderRanges: [], ligatureRanges: [],
                harakatEvents: Array(repeating: TextDeltaEvent(oldOffset: 0, delta: 1), count: 600_000),
                cleaningEvents: Array(repeating: TextDeltaEvent(oldOffset: 1, delta: -1), count: 600_000)))
        check("Both delta event arrays contribute to retention cost", cache.getProcessed(bookId: 36, contentId: 1, key: key) == nil)
        cache.removeAll()

        for book in 100..<110 {
            cache.set(bookId: book, content: BookContent(id: 1, nash: String(repeating: Character(UnicodeScalar(65 + book - 100)!), count: 8 * mib)))
        }
        let rawBytes = (100..<110).reduce(0) { $0 + (cache.get(bookId: $1, contentId: 1)?.nash.utf8.count ?? 0) }
        check("Retained raw payload across books stays within the byte budget", rawBytes <= maximumPayload)
        check("The latest fitting raw page remains usable", cache.get(bookId: 109, contentId: 1)?.nash.utf8.count == 8 * mib)
        cache.removeAll()
        for page in 0..<10 {
            cache.set(bookId: 200, content: BookContent(id: page, nash: String(repeating: Character(UnicodeScalar(65 + page)!), count: 8 * mib)))
        }
        let sameBookBytes = (0..<10).reduce(0) { $0 + (cache.get(bookId: 200, contentId: $1)?.nash.utf8.count ?? 0) }
        check("Retained raw payload within one book stays within the byte budget", sameBookBytes <= maximumPayload)
        cache.removeAll()
        for book in 300..<310 {
            cache.setProcessed(bookId: book, contentId: 1, key: key, content: processed(
                String(repeating: Character(UnicodeScalar(65 + book - 300)!), count: 2 * mib),
                String(repeating: Character(UnicodeScalar(97 + book - 300)!), count: 2 * mib)))
        }
        let processedBytes = (300..<310).reduce(0) { total, book in
            guard let value = cache.getProcessed(bookId: book, contentId: 1, key: key) else { return total }
            return total + value.sourceText.utf8.count + value.displayText.utf8.count
        }
        check("Retained processed payload across books stays within the byte budget", processedBytes <= maximumPayload)
        cache.removeAll()
        for book in 0..<201 { cache.set(bookId: book, content: BookContent(id: 1, nash: "small")) }
        check("The original book limit remains bounded", (0..<201).filter { cache.get(bookId: $0, contentId: 1) != nil }.count <= 200)
        cache.removeAll()
        for page in 0..<5001 { cache.set(bookId: 400, content: BookContent(id: page, nash: "small")) }
        check("The page count remains bounded even for tiny values", (0..<5001).filter { cache.get(bookId: 400, contentId: $0) != nil }.count <= 5000)
        cache.removeAll()
        weak var released: ProcessedArabicContent?
        do {
            let value = processed("only cache", "only cache")
            released = value
            cache.setProcessed(bookId: 500, contentId: 1, key: key, content: value)
        }
        check("A small processed value is retained while cached", released != nil)
        cache.removeAll()
        check("Removal releases values; the ledger owns no payload", released == nil)
        cache.set(bookId: 600, content: BookContent(id: 1, nash: "after reset"))
        check("Capacity is reusable after clear", cache.get(bookId: 600, contentId: 1)?.nash == "after reset")
        cache.removeAll()
        let violations = Mutex<[String]>([])
        DispatchQueue.concurrentPerform(iterations: 8) { worker in
            for iteration in 0..<500 {
                let text = "\(worker):\(iteration)"
                cache.set(bookId: worker, content: BookContent(id: iteration, nash: text))
                if let value = cache.get(bookId: worker, contentId: iteration), value.nash != text {
                    violations.withLock { $0.append(text) }
                }
                let variant = CleanedTextKey(showHarakat: true, isMultiLanguage: false, isImported: false, textHash: iteration)
                cache.setProcessed(bookId: worker, contentId: iteration, key: variant, content: processed(text, text))
                if let value = cache.getProcessed(bookId: worker, contentId: iteration, key: variant), value.displayText != text {
                    violations.withLock { $0.append(text) }
                }
                if iteration % 17 == 0 { cache.remove(bookId: worker) }
            }
        }
        check("Concurrent reads writes and removals never return a foreign payload", violations.withLock { $0.isEmpty })
        cache.removeAll()
        let result: [String: Any] = ["passed": passed, "failed": failed, "count": passed.count + failed.count,
            "native_ui_executed": 0, "physical_device_executed": 0,
            "boundary": "Actual BookPageCache, models, NSCache and Mutex; OSLog is a no-op boundary on Windows. Payload-retention policy, not RSS or UI performance."]
        print(String(data: try! JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]), encoding: .utf8)!)
        if !failed.isEmpty { exit(1) }
    }
}
