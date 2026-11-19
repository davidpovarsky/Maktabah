import Foundation

extension String {
    var otsariaPlainText: String {
        var text = self
        // Preserve the existing transformation order. Most TOC/source rows are
        // already plain text, so do not run every replacement/regex on them.
        if text.utf8.contains(0x3C) { // <
            text = text
                .replacingOccurrences(of: "<br>", with: "\n", options: .caseInsensitive)
                .replacingOccurrences(of: "<br/>", with: "\n", options: .caseInsensitive)
                .replacingOccurrences(of: "<br />", with: "\n", options: .caseInsensitive)
                .replacingOccurrences(of: "</p>", with: "\n", options: .caseInsensitive)
                .replacingOccurrences(of: "</h1>", with: "\n", options: .caseInsensitive)
                .replacingOccurrences(of: "</h2>", with: "\n", options: .caseInsensitive)
                .replacingOccurrences(of: "</h3>", with: "\n", options: .caseInsensitive)
                .replacingOccurrences(of: "</h4>", with: "\n", options: .caseInsensitive)
            text = text.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        }

        if text.utf8.contains(0x26) { // &
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
        }

        if text.utf8.contains(0x0A) { // newline
            text = text.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var otsariaLooksLikeHTMLHeading: Bool {
        let lowered = trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return lowered.hasPrefix("<h1") || lowered.hasPrefix("<h2") || lowered.hasPrefix("<h3") || lowered.hasPrefix("<h4")
    }

    var containsHebrewCharacters: Bool {
        unicodeScalars.contains { ($0.value >= 0x0590 && $0.value <= 0x05FF) || ($0.value >= 0xFB1D && $0.value <= 0xFB4F) }
    }

    func removingHebrewNikudAndTaamim() -> String {
        String(unicodeScalars.filter { !$0.isHebrewNikudOrTaamim })
    }

    func findHebrewMatchingRanges(keywords: [String]) -> [NSRange] {
        guard !keywords.isEmpty, !self.isEmpty else { return [] }

        var normalizedScalars: [UnicodeScalar] = []
        var indexMap: [Int] = []
        var utf16Offset = 0

        for scalar in self.unicodeScalars {
            let len = scalar.utf16.count
            if scalar.isHebrewNikudOrTaamim {
                utf16Offset += len
                continue
            }
            // Foundation match ranges use UTF16 offsets. A displayed Character
            // can contain several scalars (combining marks, flags or ZWJ emoji),
            // and a scalar can occupy two UTF16 units. Preserve every source unit.
            for unitOffset in 0..<len { indexMap.append(utf16Offset + unitOffset) }
            normalizedScalars.append(scalar)
            utf16Offset += len
        }

        let normText = String(String.UnicodeScalarView(normalizedScalars))
        var ranges: [NSRange] = []

        for keyword in keywords {
            var normKeyScalars: [UnicodeScalar] = []
            for scalar in keyword.unicodeScalars {
                if !scalar.isHebrewNikudOrTaamim {
                    normKeyScalars.append(scalar)
                }
            }
            let normKey = String(String.UnicodeScalarView(normKeyScalars))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normKey.isEmpty else { continue }

            var searchStart = normText.startIndex
            while searchStart < normText.endIndex,
                  let found = normText.range(of: normKey, options: [.caseInsensitive], range: searchStart..<normText.endIndex) {
                let normalizedRange = NSRange(found, in: normText)
                let endOffset = NSMaxRange(normalizedRange)

                if normalizedRange.location < indexMap.count, endOffset <= indexMap.count {
                    let startUtf16 = indexMap[normalizedRange.location]
                    let endUtf16 = endOffset < indexMap.count ? indexMap[endOffset] : self.utf16.count
                    let range = NSRange(location: startUtf16, length: max(0, endUtf16 - startUtf16))
                    if !ranges.contains(where: { $0.location == range.location && $0.length == range.length }) {
                        ranges.append(range)
                    }
                }

                searchStart = found.upperBound
            }
        }

        return ranges.sorted { $0.location < $1.location }
    }
}

extension UnicodeScalar {
    var isHebrewNikudOrTaamim: Bool {
        return ((value >= 0x0591 && value <= 0x05AF) || (value >= 0x05B0 && value <= 0x05C7))
            && value != 0x05BE && value != 0x05C0 && value != 0x05C3
    }
}

