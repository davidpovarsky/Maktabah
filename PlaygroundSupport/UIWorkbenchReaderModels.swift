import Foundation

struct TOCRange {
    let start: Int
    let end: Int
    let node: TOCNode
}

enum OtzariaUnitMode: Equatable, Codable {
    case line
    case paragraph
    case chapter

    var storageValue: String {
        switch self {
        case .line: "line"
        case .paragraph: "paragraph"
        case .chapter: "chapter"
        }
    }
}

struct OtzariaUnitLevelOption: Identifiable, Equatable {
    let id: String
    let title: String
    let level: Int?
    let mode: OtzariaUnitMode
}
