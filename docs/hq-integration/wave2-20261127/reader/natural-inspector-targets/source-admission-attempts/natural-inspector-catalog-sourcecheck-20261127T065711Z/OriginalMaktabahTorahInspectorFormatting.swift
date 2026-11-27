import Foundation
import TorahInspectorCore

enum MaktabahTorahInspectorFormatting {
    static func reference(for locator: TextLocator) -> String {
        switch (locator.backend, locator.position) {
        case (.sefaria, .canonicalRef(let reference)), (.sefariaEmbedded, .canonicalRef(let reference)):
            return reference
        case (.otzaria, .legacyLine(let lineIndex)):
            return "otzaria:v1:\(otzariaBookID(from: locator.workKey) ?? 0):\(lineIndex)"
        default:
            return locator.persistenceKey
        }
    }

    static func unitReference(for unit: OtzariaReadingUnit) -> String {
        let safeUnitId = unit.id.replacingOccurrences(of: ":", with: "_")
        return "otzaria:unit:v1:\(unit.bookId):\(safeUnitId):\(unit.startLineIndex):\(unit.endLineIndex)"
    }

    static func otzariaBookID(from workKey: String) -> Int? {
        guard workKey.hasPrefix("book:") else { return nil }
        return Int(workKey.dropFirst("book:".count))
    }

    static func relationshipKind(
        category: String,
        type: String
    ) -> TorahRelationshipKind {
        OtzariaRelationshipClassifier.classify(category: category, type: type).relationshipKind
    }

    static func semanticCategory(
        category: String,
        type: String
    ) -> TorahSourceCategory {
        OtzariaRelationshipClassifier.classify(category: category, type: type).semanticCategory
    }
}
