import Foundation

enum OtzariaSearchMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case exact
    case advanced
    case fuzzy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .exact: return "מדויק"
        case .advanced: return "מתקדם"
        case .fuzzy: return "מקורב"
        }
    }

    var engineValue: String { rawValue }
}

enum OtzariaSearchOrder: String, Codable, Sendable {
    case catalogue
    case relevance
}
