import Foundation

struct OtzariaReadingUnit: Identifiable, Equatable {
    let id: String
    let bookId: Int
    let tocEntryId: Int?
    let title: String?
    let level: Int?
    let startLineIndex: Int
    let endLineIndex: Int
    let sourceLineIndices: [Int]
    let html: String
    let plainText: String
    let heRef: String?
}

struct OtzariaUnitLevelOption: Identifiable, Equatable {
    let id: String
    let title: String
    let level: Int?
    let mode: OtzariaUnitMode
}

enum OtzariaUnitMode: Equatable, Codable {
    case line
    case paragraph
    case chapter

    var storageValue: String {
        switch self {
        case .line: return "line"
        case .paragraph: return "paragraph"
        case .chapter: return "chapter"
        }
    }

    init(storageValue: String) {
        switch storageValue {
        case "line", "sourceLine":
            self = .line
        case "chapter":
            self = .chapter
        case "paragraph", "leaf", "automatic":
            self = .paragraph
        default:
            if storageValue.hasPrefix("tocLevel:") {
                self = .chapter
            } else {
                self = .paragraph
            }
        }
    }
}
