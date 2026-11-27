import Foundation
enum BackendID: String, Codable, CaseIterable, Identifiable, Sendable {
    case otzaria
    case sefaria
    case sefariaEmbedded

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .otzaria: return "אוצריא"
        case .sefaria: return "ספריא (ישן)"
        case .sefariaEmbedded: return "ספריא"
        }
    }

    var englishDisplayName: String {
        switch self {
        case .otzaria: return "Otzaria"
        case .sefaria: return "Sefaria (Legacy)"
        case .sefariaEmbedded: return "Sefaria"
        }
    }
}

enum TextPosition: Codable, Hashable, Sendable, CustomStringConvertible {
    case legacyLine(Int)
    case canonicalRef(String)

    private enum CodingKeys: String, CodingKey { case kind, integer, string }
    private enum Kind: String, Codable { case legacyLine, canonicalRef }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        switch try values.decode(Kind.self, forKey: .kind) {
        case .legacyLine: self = .legacyLine(try values.decode(Int.self, forKey: .integer))
        case .canonicalRef: self = .canonicalRef(try values.decode(String.self, forKey: .string))
        }
    }

    var description: String {
        switch self {
        case .legacyLine(let value): return "line:\(value)"
        case .canonicalRef(let value): return value
        }
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .legacyLine(let value):
            try values.encode(Kind.legacyLine, forKey: .kind)
            try values.encode(value, forKey: .integer)
        case .canonicalRef(let value):
            try values.encode(Kind.canonicalRef, forKey: .kind)
            try values.encode(value, forKey: .string)
        }
    }
}

struct TextLocator: Codable, Hashable, Sendable {
    let backend: BackendID
    let workKey: String
    let position: TextPosition

    var persistenceKey: String {
        let positionKey: String
        switch position {
        case .legacyLine(let value): positionKey = "line:\(value)"
        case .canonicalRef(let value): positionKey = "ref:\(value)"
        }
        return "\(backend.rawValue)|\(workKey)|\(positionKey)"
    }
}
