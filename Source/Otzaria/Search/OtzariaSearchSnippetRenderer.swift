import Foundation

/// Presentation-only decoding for snippets already normalized and highlighted
/// by upstream. This type must never alter a query or indexing input.
enum OtzariaSearchSnippetRenderer {
    static func plainText(fromHTML input: String) -> String {
        var text = input
        let replacements: [(String, String)] = [
            ("<br>", "\n"), ("<br/>", "\n"), ("<br />", "\n"),
            ("&nbsp;", " "), ("&quot;", "\""), ("&apos;", "'"),
            ("&#39;", "'"), ("&lt;", "<"), ("&gt;", ">"), ("&amp;", "&")
        ]
        for (source, destination) in replacements {
            text = text.replacingOccurrences(of: source, with: destination, options: .caseInsensitive)
        }
        text = text.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        return text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
