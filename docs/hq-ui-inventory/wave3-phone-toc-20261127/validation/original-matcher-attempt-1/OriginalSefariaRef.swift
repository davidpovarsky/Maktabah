import Foundation
enum SefariaRef {
    static func canonicalInput(_ input: String) -> String {
        var value = input.removingPercentEncoding ?? input
        value = value.replacingOccurrences(of: "_", with: " ")
        if let firstSectionDot = value.range(of: #"\.(?=\d)"#, options: .regularExpression) {
            value.replaceSubrange(firstSectionDot, with: " ")
            let suffix = firstSectionDot.lowerBound..<value.endIndex
            value = value.replacingOccurrences(of: ".", with: ":", options: [], range: suffix)
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    static func segmentRef(sectionRef: String, offset: Int) -> String {
        if sectionRef.range(of: #"\d[ab]$"#, options: .regularExpression) != nil {
            return "\(sectionRef):\(offset)"
        }
        return sectionRef.contains(":") ? "\(sectionRef):\(offset)" : "\(sectionRef):\(offset)"
    }

    static func workKey(from canonicalRef: String, knownTitles: [String]) -> String? {
        knownTitles.filter { canonicalRef == $0 || canonicalRef.hasPrefix($0 + " ") }
            .max(by: { $0.count < $1.count })
    }

    static func talmudAddress(offset: Int) -> String {
        "\(offset / 2 + 2)\(offset.isMultiple(of: 2) ? "a" : "b")"
    }

    static func sectionMatches(_ lhs: String, _ rhs: String) -> Bool {
        let lhs = canonicalInput(lhs)
        let rhs = canonicalInput(rhs)
        return lhs == rhs || lhs.hasPrefix(rhs + ":") || rhs.hasPrefix(lhs + ":")
    }

    static func sectionAncestors(of input: String) -> [String] {
        var current = canonicalInput(input)
        var result = [current]
        while let range = current.range(
            of: #":[0-9]+[ab]?(?:-[^:\s]+)?$"#,
            options: [.regularExpression, .caseInsensitive]
        ) {
            current.removeSubrange(range)
            result.append(current)
        }
        return result
    }

    static func inferredWorkKey(from input: String) -> String {
        let canonical = canonicalInput(input)
        guard let range = canonical.range(
            of: #"\s+[0-9]+[ab]?(?::[0-9]+[ab]?)*(?:-\S+)?$"#,
            options: [.regularExpression, .caseInsensitive]
        ) else { return canonical }
        return String(canonical[..<range.lowerBound])
    }

    static func segmentOffset(in input: String, relativeTo sectionRef: String) -> Int? {
        let input = canonicalInput(input)
        let section = canonicalInput(sectionRef)
        guard input.hasPrefix(section + ":") else { return nil }
        let suffix = input.dropFirst(section.count + 1)
        guard !suffix.contains(":"), let first = suffix.split(separator: "-").first else { return nil }
        return Int(first)
    }

    static func anchorReference(_ anchor: String, contains requestedRef: String) -> Bool {
        let anchor = canonicalInput(anchor)
        let requested = canonicalInput(requestedRef)
        if anchor == requested { return true }
        guard let dash = anchor.lastIndex(of: "-") else { return false }
        let startText = String(anchor[..<dash])
        let endText = String(anchor[anchor.index(after: dash)...])
        guard let start = finalNumericAddress(startText),
              let requestedAddress = finalNumericAddress(requested) else { return false }
        let end: (prefix: String, value: Int)
        if let value = Int(endText) {
            end = (start.prefix, value)
        } else if let fullEnd = finalNumericAddress(endText) {
            end = fullEnd
        } else {
            return false
        }
        guard start.prefix == requestedAddress.prefix,
              end.prefix == requestedAddress.prefix else { return false }
        return requestedAddress.value >= min(start.value, end.value)
            && requestedAddress.value <= max(start.value, end.value)
    }

    private static func finalNumericAddress(_ input: String) -> (prefix: String, value: Int)? {
        let canonical = canonicalInput(input)
        guard let range = canonical.range(of: #"[0-9]+$"#, options: .regularExpression),
              let value = Int(canonical[range]) else { return nil }
        return (String(canonical[..<range.lowerBound]), value)
    }
}
