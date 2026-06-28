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
    case automatic
    case tocLevel(Int)
    case leaf
    case sourceLine

    var storageValue: String {
        switch self {
        case .automatic: return "automatic"
        case .tocLevel(let level): return "tocLevel:\(level)"
        case .leaf: return "leaf"
        case .sourceLine: return "sourceLine"
        }
    }

    init(storageValue: String) {
        if storageValue == "leaf" {
            self = .leaf
        } else if storageValue == "sourceLine" {
            self = .sourceLine
        } else if storageValue.hasPrefix("tocLevel:"),
                  let level = Int(storageValue.dropFirst("tocLevel:".count)) {
            self = .tocLevel(level)
        } else {
            self = .automatic
        }
    }
}

enum OtzariaReaderMode: String, Codable {
    case paged
    case continuous
}
