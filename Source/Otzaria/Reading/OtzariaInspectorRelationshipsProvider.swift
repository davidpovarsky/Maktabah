import Foundation

struct OtzariaInspectorRelationshipsProvider: LibraryRelationshipsProviding, @unchecked Sendable {
    func links(for locator: TextLocator) async throws -> [LibraryRelatedSource] {
        #if os(iOS)
        guard locator.backend == .otzaria,
              let bookID = Self.bookID(from: locator.workKey),
              case .legacyLine(let lineIndex) = locator.position,
              let unit = OtzariaMaktabahBridge.shared.getReadingUnit(
                bookId: bookID,
                containingLineIndex: lineIndex,
                mode: OtzariaMaktabahBridge.shared.currentReadingUnitMode
              ),
              let anchor = unit.lineAnchors.first(where: { $0.lineIndex == lineIndex })
                ?? unit.lineAnchors.first else {
            throw LibraryBackendError.invalidLocator
        }
        return OtzariaMaktabahBridge.shared.getLinksForLine(anchor).map(Self.map)
        #else
        throw LibraryBackendError.capabilityUnavailable
        #endif
    }

    func topics(for locator: TextLocator) async throws -> [LibraryRelatedTopic] {
        guard locator.backend == .otzaria else { throw LibraryBackendError.invalidLocator }
        return []
    }

    static func map(_ source: OtzariaLinkedSource) -> LibraryRelatedSource {
        let category = source.connectionType.caseInsensitiveCompare("COMMENTARY") == .orderedSame
            ? "Commentary"
            : (source.linkedCategoryPath.isEmpty
                ? source.localizedConnectionType
                : source.linkedCategoryPath.joined(separator: " / "))
        return LibraryRelatedSource(
            locator: TextLocator(
                backend: .otzaria,
                workKey: "book:\(source.linkedBookId)",
                position: .legacyLine(source.linkedLineIndex)
            ),
            displayRef: source.bookTitle,
            heRef: source.heRef,
            category: category,
            type: source.connectionType,
            collectiveTitle: source.bookTitle,
            heCollectiveTitle: source.bookTitle,
            primaryText: source.text,
            translation: nil,
            versionTitle: nil,
            heVersionTitle: nil,
            license: nil
        )
    }

    private static func bookID(from workKey: String) -> Int? {
        guard workKey.hasPrefix("book:") else { return nil }
        return Int(workKey.dropFirst("book:".count))
    }
}
