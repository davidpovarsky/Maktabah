import Foundation
struct ArabicRenderResult {
    let sourceText: String
    let attributedString: NSAttributedString
    let replacementEvents: [HonorificReplacementEvent]
    let footnoteRanges: [NSRange]
    let harakatEvents: [TextDeltaEvent]
    let cleaningEvents: [TextDeltaEvent]

    init(
        sourceText: String,
        attributedString: NSAttributedString,
        replacementEvents: [HonorificReplacementEvent],
        footnoteRanges: [NSRange],
        harakatEvents: [TextDeltaEvent] = [],
        cleaningEvents: [TextDeltaEvent] = []
    ) {
        self.sourceText = sourceText
        self.attributedString = attributedString
        self.replacementEvents = replacementEvents
        self.footnoteRanges = footnoteRanges
        self.harakatEvents = harakatEvents
        self.cleaningEvents = cleaningEvents
    }

    func displayedRange(forSourceRange range: NSRange) -> NSRange {
        let afterHarakat = TextDeltaEvent.mapRange(range, with: harakatEvents)
        let afterCleaning = TextDeltaEvent.mapRange(afterHarakat, with: cleaningEvents)
        return remapDisplayedRange(afterCleaning)
    }

    func sourceCharacterIndex(forDisplayedIndex displayedIndex: Int) -> Int {
        let afterHonorific = sourceOffset(forDisplayedOffset: displayedIndex, affinity: .leading)
        let afterCleaning = TextDeltaEvent.reverseMapOffset(afterHonorific, with: cleaningEvents)
        return TextDeltaEvent.reverseMapOffset(afterCleaning, with: harakatEvents)
    }

    func remapDisplayedRange(_ range: NSRange) -> NSRange {
        guard range.location != NSNotFound, range.location >= 0, !replacementEvents.isEmpty else { return range }

        let start = displayedOffset(forSourceOffset: range.location, affinity: .leading)
        let end = displayedOffset(forSourceOffset: range.location + range.length, affinity: .trailing)
        return NSRange(location: start, length: max(0, end - start))
    }

    func remapSourceRange(_ range: NSRange) -> NSRange {
        guard range.location != NSNotFound, range.location >= 0 else { return range }
        let start = sourceCharacterIndex(forDisplayedIndex: range.location)
        let end = sourceCharacterIndex(forDisplayedIndex: range.location + range.length)
        return NSRange(location: start, length: max(0, end - start))
    }

    func displayedOffset(forSourceOffset oldOffset: Int, affinity: HonorificBoundaryAffinity) -> Int {
        var delta = 0

        for event in replacementEvents {
            let start = event.oldRange.location
            let end = event.oldRange.location + event.oldRange.length

            if oldOffset < start {
                break
            }

            if oldOffset == start {
                return start + delta
            }

            if oldOffset < end {
                return start + delta + (affinity == .trailing ? event.newLength : 0)
            }

            delta += event.newLength - event.oldRange.length
        }

        return oldOffset + delta
    }

    func sourceOffset(forDisplayedOffset displayedOffset: Int, affinity: HonorificBoundaryAffinity) -> Int {
        var delta = 0

        for event in replacementEvents {
            let oldStart = event.oldRange.location
            let oldEnd = event.oldRange.location + event.oldRange.length
            let newStart = oldStart + delta
            let newEnd = newStart + event.newLength

            if displayedOffset < newStart {
                break
            }

            if displayedOffset == newStart {
                return oldStart
            }

            if displayedOffset < newEnd {
                return affinity == .trailing ? oldEnd : oldStart
            }

            delta += event.newLength - event.oldRange.length
        }

        return displayedOffset - delta
    }
}

struct HonorificReplacementEvent {
    let oldRange: NSRange
    let newLength: Int
}

enum HonorificBoundaryAffinity {
    case leading
    case trailing
}

