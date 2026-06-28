import Foundation

extension OtzariaMaktabahBridge {
    func getAvailableReadingUnitModes(bookId: Int) -> [OtzariaUnitLevelOption] {
        withReadingUnitService { service in
            (try? service.availableModes(bookId: bookId)) ?? [
                OtzariaUnitLevelOption(id: OtzariaUnitMode.automatic.storageValue, title: "Automatic", level: nil, mode: .automatic),
                OtzariaUnitLevelOption(id: OtzariaUnitMode.sourceLine.storageValue, title: "Source line", level: nil, mode: .sourceLine)
            ]
        } ?? []
    }

    func getReadingUnit(bookId: Int, containingLineIndex lineIndex: Int, mode: OtzariaUnitMode) -> OtzariaReadingUnit? {
        withReadingUnitService { service in
            try? service.readingUnit(bookId: bookId, containingLineIndex: lineIndex, mode: mode)
        } ?? nil
    }

    func getFirstReadingUnit(bookId: Int, mode: OtzariaUnitMode) -> OtzariaReadingUnit? {
        withReadingUnitService { service in
            try? service.firstReadingUnit(bookId: bookId, mode: mode)
        } ?? nil
    }

    func getNextReadingUnit(bookId: Int, afterLineIndex lineIndex: Int, mode: OtzariaUnitMode) -> OtzariaReadingUnit? {
        withReadingUnitService { service in
            try? service.nextReadingUnit(bookId: bookId, afterLineIndex: lineIndex, mode: mode)
        } ?? nil
    }

    func getPreviousReadingUnit(bookId: Int, beforeLineIndex lineIndex: Int, mode: OtzariaUnitMode) -> OtzariaReadingUnit? {
        withReadingUnitService { service in
            try? service.previousReadingUnit(bookId: bookId, beforeLineIndex: lineIndex, mode: mode)
        } ?? nil
    }

    func getReadingUnitsWindow(bookId: Int, aroundLineIndex lineIndex: Int, mode: OtzariaUnitMode, before: Int, after: Int) -> [OtzariaReadingUnit] {
        withReadingUnitService { service in
            (try? service.readingUnitsWindow(bookId: bookId, aroundLineIndex: lineIndex, mode: mode, before: before, after: after)) ?? []
        } ?? []
    }

    func makeBookContent(from unit: OtzariaReadingUnit) -> BookContent {
        BookContent(
            id: unit.startLineIndex,
            nash: unit.plainText,
            page: unit.startLineIndex,
            part: 1,
            heRef: unit.heRef ?? unit.title
        )
    }

    func getLinksForReadingUnit(bookId: Int, unit: OtzariaReadingUnit) -> [OtzariaLinkedSource] {
        // TODO: Wire this to Otzaria's link/source tables once the schema is confirmed.
        []
    }
}
