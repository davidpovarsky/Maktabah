import Foundation

@main struct SelectionBackgroundTests {
    static func main() {
        let background = NSAttributedString.Key("fixture.background")
        let annotation = NSAttributedString.Key("annotationID")
        var results: [[String: Any]] = []
        func check(_ name: String, _ body: () -> Bool) { results.append(["name": name, "passed": body()]) }
        func color(_ text: NSAttributedString, _ index: Int) -> String? {
            text.attribute(background, at: index, effectiveRange: nil) as? String
        }
        check("plain selected text retains a visible selection") {
            let text = NSMutableAttributedString(string: "abcdefgh")
            ReaderSelectionBackground.apply(to: text, range: NSRange(location: 2, length: 4), attribute: background, color: "selection")
            return color(text, 1) == nil && color(text, 2) == "selection" && color(text, 5) == "selection" && color(text, 6) == nil
        }
        check("search match remains visible inside selected source line") {
            let text = NSMutableAttributedString(string: "abcdefgh")
            text.addAttribute(background, value: "search", range: NSRange(location: 2, length: 2))
            ReaderSelectionBackground.apply(to: text, range: NSRange(location: 0, length: text.length), attribute: background, color: "selection")
            return color(text, 2) == "search" && color(text, 3) == "search" && color(text, 4) == "selection"
        }
        check("persistent annotation color and identity are retained") {
            let text = NSMutableAttributedString(string: "abcdefgh")
            text.addAttributes([background: "annotation", annotation: 42], range: NSRange(location: 1, length: 3))
            ReaderSelectionBackground.apply(to: text, range: NSRange(location: 0, length: 6), attribute: background, color: "selection")
            return color(text, 2) == "annotation" && text.attribute(annotation, at: 2, effectiveRange: nil) as? Int == 42
                && color(text, 5) == "selection" && color(text, 6) == nil
        }
        check("multiple existing backgrounds survive one selected span") {
            let text = NSMutableAttributedString(string: "abcdefghij")
            text.addAttribute(background, value: "search", range: NSRange(location: 1, length: 2))
            text.addAttribute(background, value: "annotation", range: NSRange(location: 5, length: 2))
            ReaderSelectionBackground.apply(to: text, range: NSRange(location: 1, length: 7), attribute: background, color: "selection")
            return color(text, 1) == "search" && color(text, 3) == "selection" && color(text, 5) == "annotation"
                && color(text, 7) == "selection" && color(text, 8) == nil
        }
        check("Hebrew combining marks and emoji use original UTF16 ranges") {
            let value = "שָׁלוֹם 😀"
            let text = NSMutableAttributedString(string: value), source = value as NSString
            let match = source.range(of: "שָׁלוֹם")
            text.addAttribute(background, value: "search", range: match)
            ReaderSelectionBackground.apply(to: text, range: NSRange(location: 0, length: text.length), attribute: background, color: "selection")
            return text.string == value && color(text, match.location) == "search"
                && color(text, source.range(of: "😀").location) == "selection"
        }
        check("a fully highlighted selection is not recolored") {
            let text = NSMutableAttributedString(string: "שלום", attributes: [background: "search"])
            ReaderSelectionBackground.apply(to: text, range: NSRange(location: 0, length: text.length), attribute: background, color: "selection")
            return (0..<text.length).allSatisfy { color(text, $0) == "search" }
        }
        let failed = results.filter { $0["passed"] as? Bool != true }.count
        let output: [String: Any] = ["tests": results.count, "passed": results.count - failed, "failed": failed,
            "cases": results, "boundary": "Real Foundation attributed-string behavior; explicit color/key fixtures. No UIKit/TextKit/device acceptance."]
        let bytes = try! JSONSerialization.data(withJSONObject: output, options: [.sortedKeys])
        print(String(data: bytes, encoding: .utf8)!)
        exit(failed == 0 ? 0 : 1)
    }
}
