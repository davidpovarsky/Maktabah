import Foundation

enum OtzariaSearchTextNormalizer {
    private static let hebrewNikudScalarValues: ClosedRange<UInt32> = 0x0591...0x05C7

    static func normalizeForIndexing(_ input: String) -> String {
        var text = htmlToSearchText(input)
        text = removeHebrewNikud(text)
        text = sanitizeQueryLikeOtzaria(text)
        return text
    }

    static func plainTextFromSnippetHTML(_ input: String) -> String {
        htmlToSearchText(input)
            .replacingOccurrences(of: "<font color=red>", with: "")
            .replacingOccurrences(of: "</font>", with: "")
            .replacingOccurrences(of: "<mark>", with: "")
            .replacingOccurrences(of: "</mark>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func htmlToSearchText(_ input: String) -> String {
        var text = input
        let replacements: [(String, String)] = [
            ("<br>", "\n"), ("<br/>", "\n"), ("<br />", "\n"),
            ("&nbsp;", " "), ("&quot;", "\""), ("&apos;", "'"),
            ("&#39;", "'"), ("&lt;", "<"), ("&gt;", ">"), ("&amp;", "&")
        ]
        for (from, to) in replacements {
            text = text.replacingOccurrences(of: from, with: to, options: [.caseInsensitive])
        }
        text = text.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        return text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func removeHebrewNikud(_ input: String) -> String {
        String(input.unicodeScalars.filter { !hebrewNikudScalarValues.contains($0.value) })
    }

    static func sanitizeQueryLikeOtzaria(_ input: String) -> String {
        var text = input
        text = text.replacingOccurrences(of: "׳", with: "'")
        text = text.replacingOccurrences(of: "‘", with: "'")
        text = text.replacingOccurrences(of: "’", with: "'")
        text = text.replacingOccurrences(of: "״", with: "\"")
        text = text.replacingOccurrences(of: "“", with: "\"")
        text = text.replacingOccurrences(of: "”", with: "\"")
        text = text.replacingOccurrences(of: #"[-־–—]"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: #"[,;!?:*()\[\]{}^$|\\+.~]"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
