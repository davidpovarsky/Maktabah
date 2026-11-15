import Foundation

final class OtzariaReadingUnitSideCache: @unchecked Sendable {
    static let shared = OtzariaReadingUnitSideCache()

    private let lock = NSLock()
    private var units: [String: OtzariaReadingUnit] = [:]
    private var costs: [String: Int] = [:]
    private var lruKeys: [String] = []
    private var currentCost: Int = 0
    private var generation: Int = 0
    private let capacity = 50
    private let maxCost = 20 * 1024 * 1024 // Estimated retained payload bytes, not process RSS.

    static func retainedCost(of unit: OtzariaReadingUnit) -> Int {
        // Strings can retain UTF16 storage; account for anchor text/metadata too.
        2 * (unit.plainText.utf16.count + unit.html.utf16.count
            + unit.id.utf16.count + (unit.title?.utf16.count ?? 0) + (unit.heRef?.utf16.count ?? 0)
            + unit.lineAnchors.reduce(0) { $0 + $1.text.utf16.count + ($1.heRef?.utf16.count ?? 0) })
            + MemoryLayout<OtzariaReadingUnit>.stride
            + unit.sourceLineIndices.count * MemoryLayout<Int>.stride
            + unit.lineAnchors.count * MemoryLayout<OtzariaLineAnchor>.stride
    }

    func set(_ unit: OtzariaReadingUnit, mode: OtzariaUnitMode, cost suppliedCost: Int? = nil) {
        guard unit.mode == mode else { return }
        let cost = suppliedCost ?? Self.retainedCost(of: unit)
        // Oversized units still reach the reader; simply do not retain them here.
        guard cost <= maxCost else { return }
        lock.lock()
        defer { lock.unlock() }

        let primaryKey = key(generation: generation, bookId: unit.bookId, contentId: unit.startLineIndex, mode: mode)
        currentCost -= costs[primaryKey] ?? 0
        units[primaryKey] = unit
        costs[primaryKey] = cost
        currentCost += cost
        touch(primaryKey)

        while lruKeys.count > capacity || currentCost > maxCost {
            guard !lruKeys.isEmpty else { break }
            let oldest = lruKeys.removeFirst()
            units.removeValue(forKey: oldest)
            currentCost -= costs.removeValue(forKey: oldest) ?? 0
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

        // Semantic units can have holes or overlapping min/max spans.
        for (k, cached) in units {
            guard cached.bookId == bookId, cached.mode == mode else { continue }
            if cached.sourceLineIndices.contains(contentId) {
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
        costs.removeAll()
        lruKeys.removeAll()
        currentCost = 0
        generation &+= 1
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
        guard !Task.isCancelled else { return nil }
        let generation = generationSnapshot()
        let lineIndex = resolvedLineIndex(from: contentId)
        let mode = currentReadingUnitMode
        let unit = cachedReadingUnit(bookId: bookId, contentId: lineIndex, mode: mode)
            ?? (Thread.isMainThread ? nil : getReadingUnit(bookId: bookId, containingLineIndex: lineIndex, mode: mode))

        guard let unit, !unit.lineAnchors.isEmpty else {
            OtzariaFileLogger.shared.log("[OtzariaMaktabahBridge] lineAnchor missing unit bookId=\(bookId) contentId=\(contentId) lineIndex=\(lineIndex) characterIndex=\(characterIndex)")
            return nil
        }

        guard generation == generationSnapshot(), mode == currentReadingUnitMode else { return nil }
        return lineAnchor(in: unit, characterIndex: characterIndex)
    }

    private func lineAnchor(in unit: OtzariaReadingUnit, characterIndex: Int) -> OtzariaLineAnchor? {
        if let anchor = unit.lineAnchors.first(where: { NSLocationInRange(characterIndex, $0.range) }) {
            return anchor
        }

        let closest = unit.lineAnchors.min { lhs, rhs in
            distance(from: characterIndex, to: lhs.range) < distance(from: characterIndex, to: rhs.range)
        }
        return closest ?? unit.lineAnchors.first
    }

    func lineAnchorAsync(bookId: Int, contentId: Int, characterIndex: Int) async -> OtzariaLineAnchor? {
        guard !Task.isCancelled else { return nil }
        let lineIndex = resolvedLineIndex(from: contentId)
        let mode = currentReadingUnitMode
        let generation = generationSnapshot()
        if let cached = cachedReadingUnit(bookId: bookId, contentId: lineIndex, mode: mode) {
            guard generation == generationSnapshot(), mode == currentReadingUnitMode else { return nil }
            return lineAnchor(in: cached, characterIndex: characterIndex)
        }
        let worker = Task.detached(priority: .userInitiated) { [weak self] () -> (OtzariaReadingUnit, UInt64)? in
            guard !Task.isCancelled, let self,
                  let generation = try? self.withDatabase({ _ in self.generationSnapshot() }),
                  let unit = self.getReadingUnit(bookId: bookId, containingLineIndex: lineIndex, mode: mode) else { return nil }
            return (unit, generation)
        }
        let result = await withTaskCancellationHandler(operation: {
            await worker.value
        }, onCancel: { worker.cancel() })
        guard !Task.isCancelled, currentReadingUnitMode == mode,
              let (unit, loadedGeneration) = result, loadedGeneration == generation,
              generation == generationSnapshot() else { return nil }
        return lineAnchor(in: unit, characterIndex: characterIndex)
    }

    private func distance(from index: Int, to range: NSRange) -> Int {
        if NSLocationInRange(index, range) { return 0 }
        if index < range.location { return range.location - index }
        return index - (range.location + range.length)
    }
}
