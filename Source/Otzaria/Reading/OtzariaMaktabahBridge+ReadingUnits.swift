import Foundation

extension OtzariaMaktabahBridge {
    func getAvailableReadingUnitModes(bookId: Int) -> [OtzariaUnitLevelOption] {
        let start = Date()
        otzariaLog("getAvailableReadingUnitModes start bookId=\(bookId)")

        let modes = withReadingUnitService { service -> [OtzariaUnitLevelOption] in
            do {
                return try service.availableModes(bookId: bookId)
            } catch {
                otzariaLog("getAvailableReadingUnitModes error bookId=\(bookId) error=\(error.localizedDescription)")
                return [
                    OtzariaUnitLevelOption(id: OtzariaUnitMode.paragraph.storageValue, title: "Paragraph", level: nil, mode: .paragraph),
                    OtzariaUnitLevelOption(id: OtzariaUnitMode.line.storageValue, title: "Line", level: nil, mode: .line)
                ]
            }
        } ?? []

        otzariaLog("getAvailableReadingUnitModes done bookId=\(bookId) count=\(modes.count) durationMs=\(otzariaElapsedMs(start))")
        return modes
    }

    func getReadingUnit(bookId: Int, containingLineIndex lineIndex: Int, mode: OtzariaUnitMode) -> OtzariaReadingUnit? {
        let start = Date()
        otzariaLog("getReadingUnit start bookId=\(bookId) lineIndex=\(lineIndex) mode=\(mode.storageValue)")

        let unit = withReadingUnitService { service -> OtzariaReadingUnit? in
            do {
                return try service.readingUnit(bookId: bookId, containingLineIndex: lineIndex, mode: mode)
            } catch {
                otzariaLog("getReadingUnit error bookId=\(bookId) lineIndex=\(lineIndex) mode=\(mode.storageValue) error=\(error.localizedDescription)")
                return nil
            }
        } ?? nil

        otzariaLog("getReadingUnit done bookId=\(bookId) lineIndex=\(lineIndex) mode=\(mode.storageValue) result=\(unit == nil ? "nil" : "ok") \(otzariaUnitSummary(unit)) durationMs=\(otzariaElapsedMs(start))")
        return unit
    }

    func getFirstReadingUnit(bookId: Int, mode: OtzariaUnitMode) -> OtzariaReadingUnit? {
        let start = Date()
        otzariaLog("getFirstReadingUnit start bookId=\(bookId) mode=\(mode.storageValue)")

        let unit = withReadingUnitService { service -> OtzariaReadingUnit? in
            do {
                return try service.firstReadingUnit(bookId: bookId, mode: mode)
            } catch {
                otzariaLog("getFirstReadingUnit error bookId=\(bookId) mode=\(mode.storageValue) error=\(error.localizedDescription)")
                return nil
            }
        } ?? nil

        otzariaLog("getFirstReadingUnit done bookId=\(bookId) mode=\(mode.storageValue) result=\(unit == nil ? "nil" : "ok") \(otzariaUnitSummary(unit)) durationMs=\(otzariaElapsedMs(start))")
        return unit
    }

    func getNextReadingUnit(bookId: Int, afterLineIndex lineIndex: Int, mode: OtzariaUnitMode) -> OtzariaReadingUnit? {
        let start = Date()
        otzariaLog("getNextReadingUnit start bookId=\(bookId) afterLineIndex=\(lineIndex) mode=\(mode.storageValue)")

        let unit = withReadingUnitService { service -> OtzariaReadingUnit? in
            do {
                return try service.nextReadingUnit(bookId: bookId, afterLineIndex: lineIndex, mode: mode)
            } catch {
                otzariaLog("getNextReadingUnit error bookId=\(bookId) afterLineIndex=\(lineIndex) mode=\(mode.storageValue) error=\(error.localizedDescription)")
                return nil
            }
        } ?? nil

        otzariaLog("getNextReadingUnit done bookId=\(bookId) afterLineIndex=\(lineIndex) mode=\(mode.storageValue) result=\(unit == nil ? "nil" : "ok") \(otzariaUnitSummary(unit)) durationMs=\(otzariaElapsedMs(start))")
        return unit
    }

    func getPreviousReadingUnit(bookId: Int, beforeLineIndex lineIndex: Int, mode: OtzariaUnitMode) -> OtzariaReadingUnit? {
        let start = Date()
        otzariaLog("getPreviousReadingUnit start bookId=\(bookId) beforeLineIndex=\(lineIndex) mode=\(mode.storageValue)")

        let unit = withReadingUnitService { service -> OtzariaReadingUnit? in
            do {
                return try service.previousReadingUnit(bookId: bookId, beforeLineIndex: lineIndex, mode: mode)
            } catch {
                otzariaLog("getPreviousReadingUnit error bookId=\(bookId) beforeLineIndex=\(lineIndex) mode=\(mode.storageValue) error=\(error.localizedDescription)")
                return nil
            }
        } ?? nil

        otzariaLog("getPreviousReadingUnit done bookId=\(bookId) beforeLineIndex=\(lineIndex) mode=\(mode.storageValue) result=\(unit == nil ? "nil" : "ok") \(otzariaUnitSummary(unit)) durationMs=\(otzariaElapsedMs(start))")
        return unit
    }

    func makeBookContent(from unit: OtzariaReadingUnit) -> BookContent {
        otzariaLog("makeBookContent \(otzariaUnitSummary(unit)) plainChars=\(unit.plainText.count) htmlChars=\(unit.html.count)")

        return BookContent(
            id: unit.startLineIndex,
            nash: unit.plainText,
            page: unit.startLineIndex,
            part: 1,
            heRef: unit.heRef ?? unit.title
        )
    }

    private func otzariaLog(_ message: String) {
        OtzariaFileLogger.shared.log("[OtzariaMaktabahBridge] \(message)")
        NSLog("%@", "[Otzaria] \(message)")
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
