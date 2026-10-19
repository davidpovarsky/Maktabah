import Foundation

final class OtzariaReadingUnitSideCache {
    static let shared = OtzariaReadingUnitSideCache()

    private let lock = NSLock()
    private var units: [String: OtzariaReadingUnit] = [:]
    private var lruKeys: [String] = []
    private var currentCost: Int = 0
    private var generation: Int = 0
    private let capacity = 50
    private let maxCost = 20 * 1024 * 1024 // 20 MB text limit

    func set(_ unit: OtzariaReadingUnit, mode: OtzariaUnitMode) {
        lock.lock()
        defer { lock.unlock() }

        let primaryKey = key(generation: generation, bookId: unit.bookId, contentId: unit.startLineIndex, mode: mode)
        let cost = unit.plainText.utf16.count + unit.html.utf16.count

        if let old = units.removeValue(forKey: primaryKey) {
            currentCost -= (old.plainText.utf16.count + old.html.utf16.count)
        }
        units[primaryKey] = unit
        currentCost += cost
        touch(primaryKey)

        while lruKeys.count > capacity || currentCost > maxCost {
            guard !lruKeys.isEmpty else { break }
            let oldest = lruKeys.removeFirst()
            if let evicted = units.removeValue(forKey: oldest) {
                currentCost -= (evicted.plainText.utf16.count + evicted.html.utf16.count)
            }
        }
    }

    func unit(bookId: Int, contentId: Int, mode: OtzariaUnitMode) -> OtzariaReadingUnit? {
        lock.lock()
        defer { lock.unlock() }

        let directKey = key(generation: generation, bookId: bookId, contentId: contentId, mode: mode)
        if let direct = units[directKey], direct.mode == mode {
            touch(directKey)
            return direct
        }

        // Strict range check: only units matching current generation, bookId, and identical mode
        for (k, cached) in units {
            guard cached.bookId == bookId, cached.mode == mode else { continue }
            if (cached.startLineIndex...cached.endLineIndex).contains(contentId) {
                touch(k)
                return cached
            }
        }
        return nil
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        units.removeAll()
        lruKeys.removeAll()
        currentCost = 0
        generation += 1
    }

    private func touch(_ key: String) {
        lruKeys.removeAll { $0 == key }
        lruKeys.append(key)
    }

    private func key(generation: Int, bookId: Int, contentId: Int, mode: OtzariaUnitMode) -> String {
        "\(generation):\(bookId):\(contentId):\(mode.storageValue)"
    }
}

extension OtzariaMaktabahBridge {
    func cacheReadingUnit(_ unit: OtzariaReadingUnit, mode: OtzariaUnitMode? = nil) {
        OtzariaReadingUnitSideCache.shared.set(unit, mode: mode ?? unit.mode)
    }

    func cachedReadingUnit(bookId: Int, contentId: Int, mode: OtzariaUnitMode? = nil) -> OtzariaReadingUnit? {
        let requestedMode = mode ?? currentReadingUnitMode
        return OtzariaReadingUnitSideCache.shared.unit(bookId: bookId, contentId: contentId, mode: requestedMode)
    }

    func clearReadingUnitCache() {
        OtzariaReadingUnitSideCache.shared.clear()
    }

    private func resolvedLineIndex(from contentId: Int) -> Int {
        if let loc = LegacyIdentityRegistry.shared.locator(for: contentId),
           case .legacyLine(let line) = loc.position {
            return line
        }
        return contentId
    }

    func lineAnchor(bookId: Int, contentId: Int, characterIndex: Int) -> OtzariaLineAnchor? {
        let lineIndex = resolvedLineIndex(from: contentId)
        let mode = currentReadingUnitMode
        let unit = cachedReadingUnit(bookId: bookId, contentId: lineIndex, mode: mode)
            ?? (Thread.isMainThread ? nil : getReadingUnit(bookId: bookId, containingLineIndex: lineIndex, mode: mode))

        if let unit {
            cacheReadingUnit(unit, mode: mode)
        }

        guard let unit, !unit.lineAnchors.isEmpty else {
            OtzariaFileLogger.shared.log("[OtzariaMaktabahBridge] lineAnchor missing unit bookId=\(bookId) contentId=\(contentId) lineIndex=\(lineIndex) characterIndex=\(characterIndex)")
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

    func lineAnchorAsync(bookId: Int, contentId: Int, characterIndex: Int) async -> OtzariaLineAnchor? {
        let lineIndex = resolvedLineIndex(from: contentId)
        if let direct = lineAnchor(bookId: bookId, contentId: lineIndex, characterIndex: characterIndex) {
            return direct
        }
        let mode = currentReadingUnitMode
        let unit = await Task.detached(priority: .userInitiated) { [weak self] () -> OtzariaReadingUnit? in
            self?.getReadingUnit(bookId: bookId, containingLineIndex: lineIndex, mode: mode)
        }.value
        if let unit {
            cacheReadingUnit(unit, mode: mode)
            return lineAnchor(bookId: bookId, contentId: lineIndex, characterIndex: characterIndex)
        }
        return nil
    }

    private func distance(from index: Int, to range: NSRange) -> Int {
        if NSLocationInRange(index, range) { return 0 }
        if index < range.location { return range.location - index }
        return index - (range.location + range.length)
    }
}
