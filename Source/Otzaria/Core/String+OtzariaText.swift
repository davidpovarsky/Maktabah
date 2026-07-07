import Foundation

extension String {
    var otsariaPlainText: String {
        var text = self
            .replacingOccurrences(of: "<br>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<br/>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<br />", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "</p>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "</h1>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "</h2>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "</h3>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "</h4>", with: "\n", options: .caseInsensitive)

        text = text.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)

        let entities: [(String, String)] = [
            ("&nbsp;", " "),
            ("&quot;", "\""),
            ("&apos;", "'"),
            ("&#39;", "'"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&amp;", "&")
        ]

        for (source, replacement) in entities {
            text = text.replacingOccurrences(of: source, with: replacement)
        }

        return text
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var otsariaLooksLikeHTMLHeading: Bool {
        let lowered = trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return lowered.hasPrefix("<h1") || lowered.hasPrefix("<h2") || lowered.hasPrefix("<h3") || lowered.hasPrefix("<h4")
    }
}
