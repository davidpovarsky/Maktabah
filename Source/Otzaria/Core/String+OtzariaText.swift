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
            indexMap.append(utf16Offset)
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
                let startScalarIdx = normText.distance(from: normText.startIndex, to: found.lowerBound)
                let endScalarIdx = normText.distance(from: normText.startIndex, to: found.upperBound)

                if startScalarIdx < indexMap.count {
                    let startUtf16 = indexMap[startScalarIdx]
                    let endUtf16 = endScalarIdx < indexMap.count ? indexMap[endScalarIdx] : self.utf16.count
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

