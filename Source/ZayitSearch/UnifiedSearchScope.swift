import Foundation

enum UnifiedSearchScope: String, CaseIterable, Identifiable, Sendable {
    case exact
    case advanced
    case fuzzy
    case zayit

    var id: Self { self }
    var title: String {
        switch self {
        case .exact: "מדויק"
        case .advanced: "מתקדם"
        case .fuzzy: "מקורב"
        case .zayit: "זית"
        }
    }
}
