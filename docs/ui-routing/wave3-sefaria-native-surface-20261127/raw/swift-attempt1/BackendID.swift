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
