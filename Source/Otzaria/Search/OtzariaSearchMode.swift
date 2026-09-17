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

enum OtzariaSearchOrder: String, CaseIterable, Identifiable, Codable, Sendable {
    case catalogue
    case relevance

    var id: String { rawValue }

    var label: String {
        switch self {
        case .catalogue: return "סדר קטלוגי"
        case .relevance: return "רלוונטיות"
        }
    }
}
