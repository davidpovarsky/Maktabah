import Foundation

@main struct HebrewMatchingRangesTests {
    struct Case {
        let name: String
        let source: String
        let keywords: [String]
        let expectedFragments: [String]
    }

    static func main() throws {
        let cases: [Case] = [
            .init(name: "Original Hebrew niqqud remains in the highlighted source range",
                  source: "בְּרֵאשִׁית בָּרָא", keywords: ["בראשית"], expectedFragments: ["בְּרֵאשִׁית"]),
            .init(name: "Combining Latin prefix does not move a Hebrew highlight",
                  source: "e\u{301} בְּרֵאשִׁית", keywords: ["בראשית"], expectedFragments: ["בְּרֵאשִׁית"]),
            .init(name: "Family emoji prefix retains the exact following source range",
                  source: "👨‍👩‍👧‍👦 תּוֹרָה", keywords: ["תורה"], expectedFragments: ["תּוֹרָה"]),
            .init(name: "Regional-indicator flag prefix retains the exact source range",
                  source: "🇮🇱 תּוֹרָה", keywords: ["תורה"], expectedFragments: ["תּוֹרָה"]),
            .init(name: "Variation selector prefix retains the exact source range",
                  source: "✡️ שָׁלוֹם", keywords: ["שלום"], expectedFragments: ["שָׁלוֹם"]),
            .init(name: "Supplementary scalar prefix uses its original UTF16 width",
                  source: "😀 תּוֹרָה", keywords: ["תורה"], expectedFragments: ["תּוֹרָה"]),
            .init(name: "Canonical-equivalent combining characters within a match retain its full extent",
                  source: "פתיחה e\u{301}תּוֹרָה סוף", keywords: ["éתורה"], expectedFragments: ["e\u{301}תּוֹרָה"]),
            .init(name: "Joined emoji inside the match is not truncated",
                  source: "תּוֹרָה👨‍👩‍👧‍👦 סוף", keywords: ["תורה👨‍👩‍👧‍👦"], expectedFragments: ["תּוֹרָה👨‍👩‍👧‍👦"]),
            .init(name: "Repeated matches after a multi-scalar prefix preserve both positions",
                  source: "👨‍👩‍👧‍👦 תּוֹרָה | תּוֹרָה", keywords: ["תורה"], expectedFragments: ["תּוֹרָה", "תּוֹרָה"]),
            .init(name: "Repeated keywords do not duplicate a source highlight",
                  source: "e\u{301} תּוֹרָה | תּוֹרָה", keywords: ["תורה", " תוֹרה "], expectedFragments: ["תּוֹרָה", "תּוֹרָה"]),
            .init(name: "Bidi isolates remain outside the selected Hebrew word",
                  source: "\u{2067}בְּרֵאשִׁית\u{2069}", keywords: ["בראשית"], expectedFragments: ["בְּרֵאשִׁית"]),
            .init(name: "Hebrew maqaf remains meaningful during matching",
                  source: "תורה־שלום", keywords: ["תורה שלום"], expectedFragments: []),
            .init(name: "Whitespace-only keywords produce no highlight",
                  source: "תורה", keywords: [" ", "\n\t"], expectedFragments: []),
            .init(name: "Empty source produces no highlight",
                  source: "", keywords: ["תורה"], expectedFragments: []),
            .init(name: "Case-insensitive Latin match after combining prefix retains source spelling",
                  source: "e\u{301} ABC שָׁלוֹם", keywords: ["abc"], expectedFragments: ["ABC"])
        ]
        var outcomes: [[String: Any]] = []
        for item in cases {
            let source = item.source as NSString
            var expected: [NSRange] = []
            var cursor = 0
            for fragment in item.expectedFragments {
                let range = source.range(of: fragment, options: .literal,
                    range: NSRange(location: cursor, length: source.length - cursor))
                precondition(range.location != NSNotFound, "Invalid independent source fixture")
                expected.append(range)
                cursor = NSMaxRange(range)
            }
            let actual = item.source.findHebrewMatchingRanges(keywords: item.keywords)
            let bounded = actual.allSatisfy { $0.location != NSNotFound && $0.location >= 0 && $0.length > 0
                && $0.location <= source.length && $0.length <= source.length - $0.location }
            let exact = actual == expected
            outcomes.append(["name": item.name, "passed": bounded && exact,
                "actual": actual.map { ["location": $0.location, "length": $0.length] },
                "expected": expected.map { ["location": $0.location, "length": $0.length] }])
        }
        let failures = outcomes.filter { $0["passed"] as? Bool != true }.count
        let report: [String: Any] = ["tests": cases.count, "passed": cases.count - failures, "failed": failures,
            "cases": outcomes, "native_passes": 0,
            "boundary": "Complete original String extension with real Swift/Foundation; independent literal source-span oracles. No UIKit/TextKit or device claim."]
        let data = try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys])
        print(String(decoding: data, as: UTF8.self))
        exit(failures == 0 ? 0 : 1)
    }
}
