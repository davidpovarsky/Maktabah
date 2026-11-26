import Foundation
@main struct PlainTextParity {
    struct Source: Decodable { let id: String; let text: String }
    static func main() throws {
        let sources = try JSONDecoder().decode([Source].self,
            from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
        let edgeCases: [(String, String)] = [
            ("  plain שָׁלוֹם 😀  ", "plain שָׁלוֹם 😀"),
            ("<BR />א<br>ב", "א\nב"),
            ("א<BR/>ב</H4>ג</P>ד", "א\nב\nג\nד"),
            ("א<br  />ב<<br>>ג", "אבג"),
            ("&lt;b&gt;literal&lt;/b&gt;", "<b>literal</b>"),
            ("&amp;lt;", "&lt;"), ("&amp;nbsp;", "&nbsp;"),
            ("a\n\n\n\nb", "a\n\nb"), ("a{p}b", "a{p}b"),
            ("<H1>כותרת</H1><p>טקסט</p>", "כותרת\nטקסט"),
            ("e\u{301} مرحبا 👨‍👩‍👧‍👦", "e\u{301} مرحبا 👨‍👩‍👧‍👦"),
            ("<b>&amp;lt;</b>", "&lt;"), ("&quot;&apos;&#39;", "\"''")
        ]
        for (input, expected) in edgeCases {
            precondition(input.otsariaPlainText == expected)
            precondition(input.otsariaPlainText == input.baselineOtzariaPlainText)
        }
        var beforeTimes: [Double] = []
        var afterTimes: [Double] = []
        var before: [String] = []
        var after: [String] = []
        for pass in 0..<1 {
            let first = Date()
            let original = sources.map { $0.text.baselineOtzariaPlainText }
            beforeTimes.append(Date().timeIntervalSince(first) * 1_000)
            let second = Date()
            let optimized = sources.map { $0.text.otsariaPlainText }
            afterTimes.append(Date().timeIntervalSince(second) * 1_000)
            precondition(original == optimized, "exact original normalizer output is required for every real source")
            if pass == 0 { before = original; after = optimized }
        }
        let directory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        for (name, strings) in [("baseline", before), ("optimized", after)] {
            let url = directory.appendingPathComponent(name + ".json")
            try JSONEncoder().encode(strings).write(to: url)
        }
        let report: [String: Any] = ["status": "EXACT_TEXT_PARITY_PASS_NOT_UI",
            "actual_source_strings": sources.count, "edge_cases": edgeCases.count, "timing_passes": 1,
            "baseline_ms": beforeTimes, "optimized_ms": afterTimes,
            "native_ui_executed": 0, "physical_device_executed": 0]
        try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys, .prettyPrinted])
            .write(to: directory.appendingPathComponent("RESULT.json"))
        print("PASS exact text parity for \(sources.count) genuine source strings and \(edgeCases.count) Unicode/markup edge cases")
    }
}
