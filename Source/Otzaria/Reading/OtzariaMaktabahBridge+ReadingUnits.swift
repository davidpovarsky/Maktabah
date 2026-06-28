import Foundation

extension OtzariaMaktabahBridge {
    func getAvailableReadingUnitModes(bookId: Int) -> [OtzariaUnitLevelOption] {
        let start = Date()
        print("[Otzaria] getAvailableReadingUnitModes start bookId=\(bookId)")

        let modes = withReadingUnitService { service -> [OtzariaUnitLevelOption] in
            do {
                return try service.availableModes(bookId: bookId)
            } catch {
                print("[Otzaria] getAvailableReadingUnitModes error bookId=\(bookId) error=\(error.localizedDescription)")
                return [
                    OtzariaUnitLevelOption(id: OtzariaUnitMode.automatic.storageValue, title: "Automatic", level: nil, mode: .automatic),
                    OtzariaUnitLevelOption(id: OtzariaUnitMode.sourceLine.storageValue, title: "Source line", level: nil, mode: .sourceLine)
                ]
            }
        } ?? []

        print("[Otzaria] getAvailableReadingUnitModes done bookId=\(bookId) count=\(modes.count) durationMs=\(otzariaElapsedMs(start))")
        return modes
    }

    func getReadingUnit(bookId: Int, containingLineIndex lineIndex: Int, mode: OtzariaUnitMode) -> OtzariaReadingUnit? {
        let start = Date()
        print("[Otzaria] getReadingUnit start bookId=\(bookId) lineIndex=\(lineIndex) mode=\(mode.storageValue)")

        let unit = withReadingUnitService { service -> OtzariaReadingUnit? in
            do {
                return try service.readingUnit(bookId: bookId, containingLineIndex: lineIndex, mode: mode)
            } catch {
                print("[Otzaria] getReadingUnit error bookId=\(bookId) lineIndex=\(lineIndex) mode=\(mode.storageValue) error=\(error.localizedDescription)")
                return nil
            }
        } ?? nil

        print("[Otzaria] getReadingUnit done bookId=\(bookId) lineIndex=\(lineIndex) mode=\(mode.storageValue) result=\(unit == nil ? "nil" : "ok") \(otzariaUnitSummary(unit)) durationMs=\(otzariaElapsedMs(start))")
        return unit
    }

    func getFirstReadingUnit(bookId: Int, mode: OtzariaUnitMode) -> OtzariaReadingUnit? {
        let start = Date()
        print("[Otzaria] getFirstReadingUnit start bookId=\(bookId) mode=\(mode.storageValue)")

        let unit = withReadingUnitService { service -> OtzariaReadingUnit? in
            do {
                return try service.firstReadingUnit(bookId: bookId, mode: mode)
            } catch {
                print("[Otzaria] getFirstReadingUnit error bookId=\(bookId) mode=\(mode.storageValue) error=\(error.localizedDescription)")
                return nil
            }
        } ?? nil

        print("[Otzaria] getFirstReadingUnit done bookId=\(bookId) mode=\(mode.storageValue) result=\(unit == nil ? "nil" : "ok") \(otzariaUnitSummary(unit)) durationMs=\(otzariaElapsedMs(start))")
        return unit
    }

    func getNextReadingUnit(bookId: Int, afterLineIndex lineIndex: Int, mode: OtzariaUnitMode) -> OtzariaReadingUnit? {
        let start = Date()
        print("[Otzaria] getNextReadingUnit start bookId=\(bookId) afterLineIndex=\(lineIndex) mode=\(mode.storageValue)")

        let unit = withReadingUnitService { service -> OtzariaReadingUnit? in
            do {
                return try service.nextReadingUnit(bookId: bookId, afterLineIndex: lineIndex, mode: mode)
            } catch {
                print("[Otzaria] getNextReadingUnit error bookId=\(bookId) afterLineIndex=\(lineIndex) mode=\(mode.storageValue) error=\(error.localizedDescription)")
                return nil
            }
        } ?? nil

        print("[Otzaria] getNextReadingUnit done bookId=\(bookId) afterLineIndex=\(lineIndex) mode=\(mode.storageValue) result=\(unit == nil ? "nil" : "ok") \(otzariaUnitSummary(unit)) durationMs=\(otzariaElapsedMs(start))")
        return unit
    }

    func getPreviousReadingUnit(bookId: Int, beforeLineIndex lineIndex: Int, mode: OtzariaUnitMode) -> OtzariaReadingUnit? {
        let start = Date()
        print("[Otzaria] getPreviousReadingUnit start bookId=\(bookId) beforeLineIndex=\(lineIndex) mode=\(mode.storageValue)")

        let unit = withReadingUnitService { service -> OtzariaReadingUnit? in
            do {
                return try service.previousReadingUnit(bookId: bookId, beforeLineIndex: lineIndex, mode: mode)
            } catch {
                print("[Otzaria] getPreviousReadingUnit error bookId=\(bookId) beforeLineIndex=\(lineIndex) mode=\(mode.storageValue) error=\(error.localizedDescription)")
                return nil
            }
        } ?? nil

        print("[Otzaria] getPreviousReadingUnit done bookId=\(bookId) beforeLineIndex=\(lineIndex) mode=\(mode.storageValue) result=\(unit == nil ? "nil" : "ok") \(otzariaUnitSummary(unit)) durationMs=\(otzariaElapsedMs(start))")
        return unit
    }

    func getReadingUnitsWindow(bookId: Int, aroundLineIndex lineIndex: Int, mode: OtzariaUnitMode, before: Int, after: Int) -> [OtzariaReadingUnit] {
        let start = Date()
        print("[Otzaria] getReadingUnitsWindow start bookId=\(bookId) aroundLineIndex=\(lineIndex) mode=\(mode.storageValue) before=\(before) after=\(after)")

        let units = withReadingUnitService { service -> [OtzariaReadingUnit] in
            do {
                return try service.readingUnitsWindow(bookId: bookId, aroundLineIndex: lineIndex, mode: mode, before: before, after: after)
            } catch {
                print("[Otzaria] getReadingUnitsWindow error bookId=\(bookId) aroundLineIndex=\(lineIndex) mode=\(mode.storageValue) error=\(error.localizedDescription)")
                return []
            }
        } ?? []

        print("[Otzaria] getReadingUnitsWindow done bookId=\(bookId) aroundLineIndex=\(lineIndex) count=\(units.count) durationMs=\(otzariaElapsedMs(start))")
        return units
    }

    func makeBookContent(from unit: OtzariaReadingUnit) -> BookContent {
        print("[Otzaria] makeBookContent \(otzariaUnitSummary(unit)) plainChars=\(unit.plainText.count) htmlChars=\(unit.html.count)")

        return BookContent(
            id: unit.startLineIndex,
            nash: unit.plainText,
            page: unit.startLineIndex,
            part: 1,
            heRef: unit.heRef ?? unit.title
        )
    }

    func getLinksForReadingUnit(bookId: Int, unit: OtzariaReadingUnit) -> [OtzariaLinkedSource] {
        print("[Otzaria] getLinksForReadingUnit placeholder bookId=\(bookId) \(otzariaUnitSummary(unit))")
        // TODO: Wire this to Otzaria's link/source tables once the schema is confirmed.
        return []
    }

    private func otzariaUnitSummary(_ unit: OtzariaReadingUnit?) -> String {
        guard let unit else {
            return "unit=nil"
        }

        return "unitId=\(unit.id) tocEntryId=\(unit.tocEntryId.map(String.init) ?? "nil") title=\(unit.title ?? "") level=\(unit.level.map(String.init) ?? "nil") start=\(unit.startLineIndex) end=\(unit.endLineIndex) lines=\(unit.sourceLineIndices.count)"
    }

    private func otzariaUnitSummary(_ unit: OtzariaReadingUnit) -> String {
        otzariaUnitSummary(Optional(unit))
    }

    private func otzariaElapsedMs(_ start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * 1000)
    }
}
