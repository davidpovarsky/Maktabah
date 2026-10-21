import Foundation

#if canImport(TorahInspectorCore)
import TorahInspectorCore
#else
enum TorahRelationshipKind: String, Sendable, Codable {
    case commentary
    case quotingCommentary
    case link
}

enum TorahSourceCategory: String, Sendable, Codable {
    case commentary
    case quotingCommentary
    case tanakh
    case talmud
    case midrash
    case targum
    case halakhah
    case other
}
#endif

struct OtzariaRelationshipClassification: Equatable, Sendable {
    let relationshipKind: TorahRelationshipKind
    let semanticCategory: TorahSourceCategory
    let displayCategory: String
    let displayType: String
}

enum OtzariaRelationshipClassifier {
    private static let commentaryTypes: Set<String> = [
        "COMMENTARY", "SUPER_COMMENTARY", "PARSHANUT", "DIBUR_HAMATCHIL",
        "ELUCIDATION", "EXPLICATION", "FOOTNOTES"
    ]

    static func classify(
        rawConnectionType: String,
        matchedSide: Int,
        currentBookId: Int,
        currentBookIsBaseBook: Bool,
        linkedBookId: Int,
        linkedBookTitle: String,
        linkedBookIsBaseBook: Bool,
        linkedBookDependenceType: String?,
        linkedCategoryPath: [String]
    ) -> OtzariaRelationshipClassification {
        let normalizedType = rawConnectionType.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        // Case 1: Commentary types
        if commentaryTypes.contains(normalizedType) {
            if matchedSide == 0 {
                // Current book is source (base text), linked book is target (commentary)
                return OtzariaRelationshipClassification(
                    relationshipKind: .commentary,
                    semanticCategory: .commentary,
                    displayCategory: "Commentary",
                    displayType: localizedType(normalizedType)
                )
            } else {
                // matchedSide == 1: Current book is target, linked book is source
                // If linked book is a base text (reader is in commentary looking at base text)
                if linkedBookIsBaseBook {
                    let cat = categoryFromPath(linkedCategoryPath) ?? .tanakh
                    return OtzariaRelationshipClassification(
                        relationshipKind: .link,
                        semanticCategory: cat,
                        displayCategory: "Source",
                        displayType: "מקור"
                    )
                } else if currentBookIsBaseBook || linkedBookDependenceType == "commentary" || isCommentaryByPathOrTitle(path: linkedCategoryPath, title: linkedBookTitle) {
                    // Current book is base text, linked book is the commentary found via inverse link
                    return OtzariaRelationshipClassification(
                        relationshipKind: .commentary,
                        semanticCategory: .commentary,
                        displayCategory: "Commentary",
                        displayType: localizedType(normalizedType)
                    )
                } else {
                    return OtzariaRelationshipClassification(
                        relationshipKind: .link,
                        semanticCategory: categoryFromPath(linkedCategoryPath) ?? .other,
                        displayCategory: "Source",
                        displayType: "מקור"
                    )
                }
            }
        }

        // Case 2: Specific canonical connection types
        switch normalizedType {
        case "TARGUM":
            return OtzariaRelationshipClassification(
                relationshipKind: .link,
                semanticCategory: .targum,
                displayCategory: "Targum",
                displayType: "תרגום"
            )

        case "MIDRASH":
            return OtzariaRelationshipClassification(
                relationshipKind: .link,
                semanticCategory: .midrash,
                displayCategory: "Midrash",
                displayType: "מדרש"
            )

        case "EIN_MISHPAT", "SIFREI_MITZVOT":
            return OtzariaRelationshipClassification(
                relationshipKind: .link,
                semanticCategory: .halakhah,
                displayCategory: "Halakhah",
                displayType: normalizedType == "EIN_MISHPAT" ? "עין משפט" : "ספרי מצוות"
            )

        case "MESORAT_HASHAS", "MISHNAH_IN_TALMUD":
            return OtzariaRelationshipClassification(
                relationshipKind: .link,
                semanticCategory: .talmud,
                displayCategory: "Talmud",
                displayType: "מסורת הש״ס"
            )

        case "QUOTATION":
            if linkedBookDependenceType == "commentary" || isCommentaryByPathOrTitle(path: linkedCategoryPath, title: linkedBookTitle) {
                return OtzariaRelationshipClassification(
                    relationshipKind: .quotingCommentary,
                    semanticCategory: .quotingCommentary,
                    displayCategory: "Quoting Commentary",
                    displayType: "ציטוט פירוש"
                )
            }
            return OtzariaRelationshipClassification(
                relationshipKind: .link,
                semanticCategory: categoryFromPath(linkedCategoryPath) ?? .other,
                displayCategory: "Quotation",
                displayType: "ציטוט"
            )

        case "SOURCE":
            return OtzariaRelationshipClassification(
                relationshipKind: .link,
                semanticCategory: categoryFromPath(linkedCategoryPath) ?? .other,
                displayCategory: "Source",
                displayType: "מקור"
            )

        case "REFERENCE":
            return OtzariaRelationshipClassification(
                relationshipKind: .link,
                semanticCategory: categoryFromPath(linkedCategoryPath) ?? .other,
                displayCategory: "Reference",
                displayType: "מראה מקום"
            )

        default:
            // "OTHER", "LINKER", "RELATED", or other unlisted
            // If current book is base book and linked book is a commentary
            if currentBookIsBaseBook && !linkedBookIsBaseBook && (linkedBookDependenceType == "commentary" || isCommentaryByPathOrTitle(path: linkedCategoryPath, title: linkedBookTitle)) {
                return OtzariaRelationshipClassification(
                    relationshipKind: .commentary,
                    semanticCategory: .commentary,
                    displayCategory: "Commentary",
                    displayType: "פירוש"
                )
            }
            let cat = categoryFromPath(linkedCategoryPath) ?? .other
            let displayCat = linkedCategoryPath.isEmpty ? "Other" : linkedCategoryPath.joined(separator: " / ")
            return OtzariaRelationshipClassification(
                relationshipKind: .link,
                semanticCategory: cat,
                displayCategory: displayCat,
                displayType: "קישור"
            )
        }
    }

    static func classify(
        source: OtzariaLinkedSource,
        currentBookId: Int,
        currentBookIsBaseBook: Bool
    ) -> OtzariaRelationshipClassification {
        classify(
            rawConnectionType: source.rawConnectionType,
            matchedSide: source.matchedSide,
            currentBookId: currentBookId,
            currentBookIsBaseBook: currentBookIsBaseBook,
            linkedBookId: source.linkedBookId,
            linkedBookTitle: source.bookTitle,
            linkedBookIsBaseBook: source.linkedBookIsBaseBook,
            linkedBookDependenceType: source.linkedBookDependenceType,
            linkedCategoryPath: source.linkedCategoryPath
        )
    }

    static func classify(category: String, type: String) -> OtzariaRelationshipClassification {
        let tokens = "\(category) \(type)".lowercased()
        if tokens.contains("quoting commentary") || tokens.contains("ציטוט פירוש") {
            return OtzariaRelationshipClassification(
                relationshipKind: .quotingCommentary,
                semanticCategory: .quotingCommentary,
                displayCategory: "Quoting Commentary",
                displayType: "ציטוט פירוש"
            )
        }
        if tokens.contains("commentary")
            || tokens.contains("super_commentary")
            || tokens.contains("parshanut")
            || tokens.contains("dibur_hamatchil")
            || tokens.contains("elucidation")
            || tokens.contains("explication")
            || tokens.contains("footnotes")
            || tokens.contains("פירוש")
            || tokens.contains("מפרש")
            || tokens.contains("פרשנות")
            || tokens.contains("ביאור") {
            return OtzariaRelationshipClassification(
                relationshipKind: .commentary,
                semanticCategory: .commentary,
                displayCategory: "Commentary",
                displayType: "פירוש"
            )
        }
        if tokens.contains("targum") || tokens.contains("תרגום") {
            return OtzariaRelationshipClassification(
                relationshipKind: .link,
                semanticCategory: .targum,
                displayCategory: "Targum",
                displayType: "תרגום"
            )
        }
        if tokens.contains("midrash") || tokens.contains("מדרש") {
            return OtzariaRelationshipClassification(
                relationshipKind: .link,
                semanticCategory: .midrash,
                displayCategory: "Midrash",
                displayType: "מדרש"
            )
        }
        if tokens.contains("ein_mishpat") || tokens.contains("עין משפט") || tokens.contains("halakh") || tokens.contains("הלכה") {
            return OtzariaRelationshipClassification(
                relationshipKind: .link,
                semanticCategory: .halakhah,
                displayCategory: "Halakhah",
                displayType: "הלכה"
            )
        }
        if tokens.contains("mesorat_hashas") || tokens.contains("מסורת הש״ס") || tokens.contains("talmud") || tokens.contains("תלמוד") {
            return OtzariaRelationshipClassification(
                relationshipKind: .link,
                semanticCategory: .talmud,
                displayCategory: "Talmud",
                displayType: "מסורת הש״ס"
            )
        }
        if tokens.contains("tanakh") || tokens.contains("תנ״ך") || tokens.contains("תנ\"ך") || tokens.contains("תורה") {
            return OtzariaRelationshipClassification(
                relationshipKind: .link,
                semanticCategory: .tanakh,
                displayCategory: "Tanakh",
                displayType: "תנ״ך"
            )
        }
        return OtzariaRelationshipClassification(
            relationshipKind: .link,
            semanticCategory: .other,
            displayCategory: category.isEmpty ? "Other" : category,
            displayType: type.isEmpty ? "קישור" : type
        )
    }

    private static func localizedType(_ type: String) -> String {
        switch type {
        case "COMMENTARY": return "פירוש"
        case "SUPER_COMMENTARY": return "סופר-פירוש"
        case "PARSHANUT": return "פרשנות"
        case "DIBUR_HAMATCHIL": return "דיבור המתחיל"
        case "ELUCIDATION": return "ביאור"
        case "EXPLICATION": return "הסבר"
        case "FOOTNOTES": return "הערות"
        default: return type
        }
    }

    private static func isCommentaryByPathOrTitle(path: [String], title: String) -> Bool {
        let pathJoined = path.joined(separator: " ").lowercased()
        if pathJoined.contains("פירוש") || pathJoined.contains("מפרש") || pathJoined.contains("פרשנות") || pathJoined.contains("commentary") {
            return true
        }
        let titleLower = title.lowercased()
        if titleLower.hasPrefix("פירוש ") || titleLower.contains(" על ") || titleLower.hasPrefix("חידושי ") || titleLower.hasPrefix("ביאור ") {
            return true
        }
        return false
    }

    private static func categoryFromPath(_ path: [String]) -> TorahSourceCategory? {
        let joined = path.joined(separator: " ").lowercased()
        if joined.contains("תנ״ך") || joined.contains("תנ\"ך") || joined.contains("תורה") || joined.contains("נביאים") || joined.contains("כתובים") || joined.contains("tanakh") {
            return .tanakh
        }
        if joined.contains("בבלי") || joined.contains("ירושלמי") || joined.contains("משנה") || joined.contains("תלמוד") || joined.contains("talmud") {
            return .talmud
        }
        if joined.contains("מדרש") || joined.contains("midrash") {
            return .midrash
        }
        if joined.contains("הלכה") || joined.contains("שולחן ערוך") || joined.contains("משנה תורה") || joined.contains("halakh") {
            return .halakhah
        }
        if joined.contains("תרגום") || joined.contains("targum") {
            return .targum
        }
        return nil
    }
}
