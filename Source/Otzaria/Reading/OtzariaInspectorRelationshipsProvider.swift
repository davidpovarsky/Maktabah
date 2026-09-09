import Foundation

enum OtzariaInspectorDocumentMapper {
    static func section(
        from unit: OtzariaReadingUnit,
        previous: OtzariaReadingUnit?,
        next: OtzariaReadingUnit?
    ) -> LibraryTextSection {
        let locator = lineLocator(bookID: unit.bookId, lineIndex: unit.startLineIndex)
        return LibraryTextSection(
            locator: locator,
            displayRef: unit.title ?? unit.heRef ?? locator.persistenceKey,
            heRef: unit.heRef,
            segments: unit.lineAnchors.map { anchor in
                LibraryTextSegment(
                    locator: lineLocator(bookID: unit.bookId, lineIndex: anchor.lineIndex),
                    heRef: anchor.heRef,
                    primaryText: anchor.text,
                    translation: nil
                )
            },
            previous: previous.map { lineLocator(bookID: $0.bookId, lineIndex: $0.startLineIndex) },
            next: next.map { lineLocator(bookID: $0.bookId, lineIndex: $0.startLineIndex) },
            versions: [TextVersionMetadata(
                title: "Otzaria local library",
                language: "he",
                actualLanguage: "he",
                sourceURL: nil,
                license: nil,
                notes: nil,
                isPrimary: true
            )],
            links: [],
            origin: .offline
        )
    }

    private static func lineLocator(bookID: Int, lineIndex: Int) -> TextLocator {
        TextLocator(backend: .otzaria, workKey: "book:\(bookID)", position: .legacyLine(lineIndex))
    }
}

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
        let sources = OtzariaMaktabahBridge.shared.getLinksForLine(anchor).map(Self.map)
        var seen = Set<String>()
        var deduplicated: [LibraryRelatedSource] = []
        for source in sources {
            let key = "\(source.locator.persistenceKey)|\(source.type)|\(source.category)"
            if seen.insert(key).inserted {
                deduplicated.append(source)
            }
        }
        return deduplicated
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
