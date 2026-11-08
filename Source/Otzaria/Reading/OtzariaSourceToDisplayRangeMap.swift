import Foundation

/// A highlight is optional. Refuse ambiguous HTML/note transformations instead of painting the wrong word.
enum OtzariaSourceToDisplayRangeMap {
    static func utf16Range(start: Int, end: Int, fullVisibleSource: String, displayedText: String) -> NSRange? {
        guard start >= 0, end >= start, fullVisibleSource.utf8.elementsEqual(displayedText.utf8),
              !fullVisibleSource.contains("<"), !fullVisibleSource.contains("&"),
              fullVisibleSource.unicodeScalars.allSatisfy({ $0.value <= 0xFFFF }),
              end <= fullVisibleSource.utf16.count else { return nil }
        return NSRange(location: start, length: end - start)
    }
}
