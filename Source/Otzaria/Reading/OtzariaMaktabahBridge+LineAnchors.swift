import Foundation

private final class OtzariaReadingUnitSideCache {
    static let shared = OtzariaReadingUnitSideCache()

    private let lock = NSLock()
    private var units: [String: OtzariaReadingUnit] = [:]

    func set(_ unit: OtzariaReadingUnit) {
        lock.lock()
        units[key(bookId: unit.bookId, contentId: unit.startLineIndex)] = unit
        lock.unlock()
    }

    func unit(bookId: Int, contentId: Int) -> OtzariaReadingUnit? {
        lock.lock()
        let unit = units[key(bookId: bookId, contentId: contentId)]
        lock.unlock()
        return unit
    }

    private func key(bookId: Int, contentId: Int) -> String {
        "\(bookId):\(contentId)"
    }
}

extension OtzariaMaktabahBridge {
    func cacheReadingUnit(_ unit: OtzariaReadingUnit) {
        OtzariaReadingUnitSideCache.shared.set(unit)
    }

    func cachedReadingUnit(bookId: Int, contentId: Int) -> OtzariaReadingUnit? {
        OtzariaReadingUnitSideCache.shared.unit(bookId: bookId, contentId: contentId)
    }

    func lineAnchor(bookId: Int, contentId: Int, characterIndex: Int) -> OtzariaLineAnchor? {
        let unit = cachedReadingUnit(bookId: bookId, contentId: contentId)
            ?? getReadingUnit(bookId: bookId, containingLineIndex: contentId, mode: currentReadingUnitMode)

        if let unit {
            cacheReadingUnit(unit)
        }

        guard let unit, !unit.lineAnchors.isEmpty else {
            OtzariaFileLogger.shared.log("[OtzariaMaktabahBridge] lineAnchor missing unit bookId=\(bookId) contentId=\(contentId) characterIndex=\(characterIndex)")
            return nil
        }

        if let anchor = unit.lineAnchors.first(where: { NSLocationInRange(characterIndex, $0.range) }) {
            return anchor
        }

        let closest = unit.lineAnchors.min { lhs, rhs in
            distance(from: characterIndex, to: lhs.range) < distance(from: characterIndex, to: rhs.range)
        }
        return closest ?? unit.lineAnchors.first
    }

    private func distance(from index: Int, to range: NSRange) -> Int {
        if NSLocationInRange(index, range) { return 0 }
        if index < range.location { return range.location - index }
        return index - (range.location + range.length)
    }
}
