import Foundation

/// Native presentation of schema7's documented UTF16/entity insertion coordinates.
/// Positions are measured against the stored source before any note is inserted.
enum OtzariaInlineNotePresentation {
    private static let inlineTags: Set<String> = ["b", "i", "em", "strong", "u", "s", "strike", "span", "sup", "sub", "small", "big", "font", "del", "ins", "a", "abbr", "acronym", "cite", "code", "dfn", "kbd", "q", "samp", "tt", "var", "mark", "bdi", "bdo", "ruby", "rt", "rp"]

    static func restoring(_ notes: [OtzariaLineNote], in source: String) throws -> String {
        guard !notes.isEmpty else { return source }
        let raw = source as NSString
        func ranges(_ pattern: String) throws -> [NSRange] {
            try NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
                .matches(in: source, range: NSRange(location: 0, length: raw.length)).map(\.range)
        }
        let sups = try ranges(#"<sup\b[^>]*>.*?</sup>"#)
        let bodies = try ranges(#"<i\b[^>]*\bclass\s*=\s*["'][^"']*\bfootnote\b[^"']*["'][^>]*>"#)
        // Original bodies already present outside a marker must never be duplicated.
        if bodies.contains(where: { body in !sups.contains(where: { NSLocationInRange(body.location, $0) }) }) { return source }
        let markers = try ranges(#"<sup\b[^>]*\bfootnote-marker\b[^>]*>.*?</sup>"#)
        func afterInlineClosings(_ initial: Int) -> Int {
            var position = initial
            while position + 2 <= raw.length, raw.substring(with: NSRange(location: position, length: 2)) == "</" {
                let end = raw.range(of: ">", range: NSRange(location: position, length: raw.length - position))
                guard end.location != NSNotFound else { break }
                let name = raw.substring(with: NSRange(location: position + 2, length: end.location - position - 2)).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard inlineTags.contains(name) else { break }
                position = end.location + 1
            }
            return position
        }
        func insertion(visible: Int) throws -> Int {
            var position = 0, seen = 0
            while position < raw.length, seen < visible {
                let unit = raw.character(at: position)
                if unit == 60 { // HTML tag
                    let end = raw.range(of: ">", range: NSRange(location: position, length: raw.length - position))
                    guard end.location != NSNotFound else { return raw.length }
                    position = end.location + 1
                    continue
                }
                if unit == 38 {
                    let entity = raw.range(of: ";", range: NSRange(location: position, length: min(10, raw.length - position)))
                    if entity.location != NSNotFound { position = entity.location + 1; seen += 1; continue }
                }
                if (0xD800...0xDBFF).contains(unit), position + 1 < raw.length,
                   (0xDC00...0xDFFF).contains(raw.character(at: position + 1)) {
                    guard seen + 1 != visible else { throw LibraryBackendError.invalidResponse("A note insertion splits a UTF16 scalar") }
                    position += 2; seen += 2
                } else { position += 1; seen += 1 }
            }
            return afterInlineClosings(position)
        }
        func onlyTags(from start: Int, to end: Int) -> Bool {
            var position = start
            while position < end {
                guard raw.character(at: position) == 60 else { return false }
                let close = raw.range(of: ">", range: NSRange(location: position, length: end - position))
                guard close.location != NSNotFound else { return false }
                position = close.location + 1
            }
            return position == end
        }
        var markerIndex = 0
        var insertions: [Int: String] = [:]
        for note in notes.sorted(by: { $0.noteIndex < $1.noteIndex }) {
            let marker = note.hasMarker && markerIndex < markers.count ? markers[markerIndex] : nil
            if note.hasMarker { markerIndex += 1 }
            var position = note.charPosition >= 0 ? try insertion(visible: note.charPosition) : marker.map(NSMaxRange) ?? raw.length
            if let containing = sups.first(where: { $0.location < position && position < NSMaxRange($0) }) {
                position = afterInlineClosings(NSMaxRange(containing))
            } else if let marker, position <= marker.location, onlyTags(from: position, to: marker.location) {
                position = afterInlineClosings(NSMaxRange(marker))
            }
            guard position >= 0, position <= raw.length else { throw LibraryBackendError.invalidLocator }
            insertions[position, default: ""] += "<i class=\"footnote\">\(note.body)</i>"
        }
        let result = NSMutableString(string: source)
        for position in insertions.keys.sorted(by: >) { result.insert(insertions[position]!, at: position) }
        return result as String
    }
}
