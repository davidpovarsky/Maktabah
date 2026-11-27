import Foundation
public struct TextDeltaEvent: Codable, Hashable, Sendable {
    public let oldOffset: Int
    public let delta: Int

    public init(oldOffset: Int, delta: Int) {
        self.oldOffset = oldOffset
        self.delta = delta
    }

    public static func mapRange(_ range: NSRange, with events: [TextDeltaEvent]) -> NSRange {
        guard !events.isEmpty else { return range }
        var locDelta = 0
        for event in events {
            if range.location >= event.oldOffset {
                locDelta = event.delta
            } else {
                break
            }
        }
        let newLocation = range.location + locDelta

        var endDelta = 0
        let rangeEnd = range.location + range.length
        for event in events {
            if rangeEnd >= event.oldOffset {
                endDelta = event.delta
            } else {
                break
            }
        }
        let newEnd = rangeEnd + endDelta
        let newLength = max(0, newEnd - newLocation)
        return NSRange(location: max(0, newLocation), length: newLength)
    }

    public static func reverseMapOffset(_ displayedOffset: Int, with events: [TextDeltaEvent]) -> Int {
        var currentDelta = 0
        for event in events {
            let newPoint = event.oldOffset + event.delta
            if displayedOffset < newPoint {
                let oldPoint = event.oldOffset + currentDelta
                if displayedOffset >= oldPoint {
                    return max(0, event.oldOffset - 1)
                }
                break
            }
            currentDelta = event.delta
        }
        return max(0, displayedOffset - currentDelta)
    }
}

