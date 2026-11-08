import Foundation

/// Independent Swift implementation of the documented RefKey wire format.
/// Compatibility is gated by the pinned upstream JSON fixture, not by guessed Hebrew parsing.
enum OtzariaReferenceKey {
    private static let quotes: Set<UInt32> = [34, 39, 0x05F3, 0x05F4]
    private static let locatorWords: Set<String> = ["פרק", "פסוק", "פסקה", "סעיף", "סימן", "הלכה", "משנה", "מאמר", "דף", "עמוד", "אות"]
    private static func hebrew(_ scalar: Unicode.Scalar) -> Bool { (0x05D0...0x05EA).contains(scalar.value) }
    private static func text<S: Sequence>(_ scalars: S) -> String where S.Element == Unicode.Scalar {
        String(String.UnicodeScalarView(scalars))
    }
    private static func numeralAtom(_ value: String) -> Bool {
        let pattern = "^(?:[0-9]+|[א-ת]{1,3}(?:[\"'״׳][א-ת]{1,2})?)[.:]?$"
        return value.range(of: pattern, options: .regularExpression) != nil
    }
    private static func rangeStart(_ input: String) -> String {
        guard let dash = input.lastIndex(where: { "-–־".contains($0) }), dash != input.startIndex else { return input }
        let right = String(input[input.index(after: dash)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        let left = String(input[..<dash]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !left.isEmpty, numeralAtom(right) else { return input }
        let searchEnd = left.last == "." || left.last == ":" ? left.index(before: left.endIndex) : left.endIndex
        let separator = left[..<searchEnd].lastIndex(where: { $0.isWhitespace || ",.:".contains($0) })
        let suffix = separator.map { String(left[left.index(after: $0)...]) } ?? left
        return numeralAtom(suffix) ? String(input[..<dash]) : input
    }
    private static func explicitDafSides(_ input: String) -> String {
        let scalars = Array(input.unicodeScalars)
        var output = ""
        var i = 0
        while i < scalars.count {
            if hebrew(scalars[i]), i == 0 || (!hebrew(scalars[i - 1]) && !quotes.contains(scalars[i - 1].value)) {
                var end = i
                while end < scalars.count && hebrew(scalars[end]) { end += 1 }
                if end - i <= 3, end < scalars.count, [46, 58].contains(scalars[end].value),
                   end + 1 == scalars.count || scalars[end + 1].value == 44 || CharacterSet.whitespacesAndNewlines.contains(scalars[end + 1]) {
                    output += text(scalars[i..<end]) + (scalars[end].value == 46 ? " א" : " ב")
                    i = end + 1
                    continue
                }
            }
            output.unicodeScalars.append(scalars[i])
            i += 1
        }
        return output
    }
    static func tokens(_ input: String) -> [String] {
        let expanded = explicitDafSides(rangeStart(input))
        let unpointed = expanded.unicodeScalars.flatMap { scalar -> [Unicode.Scalar] in
            if [0x05BE, 0x05C0, 124].contains(scalar.value) { return [" "] }
            if (0x0591...0x05C7).contains(scalar.value) { return [] }
            return [scalar]
        }
        var sideExpanded: [Unicode.Scalar] = []
        var i = 0
        while i < unpointed.count {
            if unpointed[i].value == 0x05E2, i + 2 < unpointed.count,
               quotes.contains(unpointed[i + 1].value), [0x05D0, 0x05D1].contains(unpointed[i + 2].value),
               (i == 0 || !hebrew(unpointed[i - 1])),
               (i + 3 == unpointed.count || !hebrew(unpointed[i + 3])) {
                sideExpanded.append(unpointed[i + 2]); i += 3
            } else { sideExpanded.append(unpointed[i]); i += 1 }
        }
        var cleaned = ""
        for scalar in sideExpanded {
            if quotes.contains(scalar.value) { continue }
            let n = scalar.value
            let allowed = (65...90).contains(n) || (97...122).contains(n) || (48...57).contains(n) || (0x0590...0x05FF).contains(n)
            cleaned.unicodeScalars.append(allowed ? scalar : " ")
        }
        return cleaned.lowercased().split(whereSeparator: \.isWhitespace).map(String.init).filter { !locatorWords.contains($0) }
    }
    static func key(_ input: String) -> String? {
        let value = tokens(input).joined(separator: " ")
        return value.isEmpty ? nil : value
    }
    private static func literalSuffix(_ reference: String, aliases: [String]) -> String? {
        let ref = Array(reference.unicodeScalars)
        for alias in aliases.filter({ !$0.isEmpty }).sorted(by: { $0.utf16.count > $1.utf16.count }) {
            let prefix = Array(alias.unicodeScalars)
            guard ref.starts(with: prefix) else { continue }
            if ref.count > prefix.count {
                let next = Character(String(ref[prefix.count]))
                if next.isLetter || next.isNumber { continue }
            }
            return text(ref.dropFirst(prefix.count))
        }
        return nil
    }
    static func lineKey(_ reference: String, aliases: [String]) -> String? {
        if let suffix = literalSuffix(reference, aliases: aliases) { return key(suffix) }
        let words = tokens(reference)
        let matching = aliases.map(tokens).filter { !$0.isEmpty && words.starts(with: $0) }.max(by: { $0.count < $1.count })
        let result = words.dropFirst(matching?.count ?? 0).joined(separator: " ")
        return result.isEmpty ? nil : result
    }
    static func partialKey(_ input: String) -> String? { key(input).map { "~ " + $0 } }
    static func partialLineKeys(_ reference: String, aliases: [String]) -> [String] {
        guard let suffix = literalSuffix(reference, aliases: aliases) else { return [] }
        let parts = suffix.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let letters = Array("אבגדהוזחטיכלמנסעפצקרשת")
        let values = Dictionary(uniqueKeysWithValues: zip(letters, [1,2,3,4,5,6,7,8,9,10,20,30,40,50,60,70,80,90,100,200,300,400]))
        func isNumeric(_ component: String) -> Bool {
            let words = tokens(component)
            return !words.isEmpty && words.allSatisfy { word in
                if word.allSatisfy(\.isNumber) { return true }
                guard word.count <= 6 else { return false }
                let numbers = word.compactMap { values[$0] }
                return numbers.count == word.count && zip(numbers, numbers.dropFirst()).allSatisfy { $0 >= $1 }
            }
        }
        let named = parts.firstIndex(where: isNumeric) ?? parts.count
        guard named > 0, parts.count - named >= 2, parts.dropFirst(named).allSatisfy(isNumeric) else { return [] }
        var seen = Set<String>()
        return (1...named).compactMap { partialKey(parts.dropFirst($0).joined(separator: ", ")) }.filter { seen.insert($0).inserted }
    }
    static func hash(_ key: String) -> UInt64 {
        key.utf8.reduce(UInt64(14695981039346656037)) { ($0 ^ UInt64($1)) &* 1099511628211 }
    }
}
