import Foundation

/// Localization resolver for ChavrusaText UI.
/// Provides authoritative Hebrew/English translations for tabs, navigation structures, and TOC titles.
public struct ChavrusaTextLocalizationResolver: Sendable {
    public enum TabKey: String, CaseIterable, Sendable {
        case library = "Library"
        case search = "Search"
        case narrators = "Narrators"
        case annotations = "Annotations"
        case history = "History"
    }

    /// Resolves the localized title for a tab key using the specified bundle, table, and optional forced locale.
    public static func resolveTabTitle(
        for key: TabKey,
        bundle: Bundle = .main,
        tableName: String? = nil,
        forcedLocaleIdentifier: String? = nil
    ) -> String {
        let effectiveLocale = forcedLocaleIdentifier
            ?? Locale.preferredLanguages.first
            ?? Locale.current.language.languageCode?.identifier
            ?? "en"

        // If forced locale is provided or running in test harness without compiled string catalog tables,
        // use canonical translations matching Source/Localizable.xcstrings:
        if effectiveLocale.hasPrefix("he") {
            switch key {
            case .library: return "ספרייה"
            case .search: return "חיפוש"
            case .narrators: return "מוסרים"
            case .annotations: return "הערות"
            case .history: return "היסטוריה"
            }
        } else if effectiveLocale.hasPrefix("en") {
            switch key {
            case .library: return "Library"
            case .search: return "Search"
            case .narrators: return "Narrators"
            case .annotations: return "Annotations"
            case .history: return "History"
            }
        }

        // Default: query bundle
        let localized = bundle.localizedString(forKey: key.rawValue, value: nil, table: tableName)
        if !localized.isEmpty && localized != key.rawValue {
            return localized
        }

        return key.rawValue
    }

    /// Resolves Sefaria navigation structure identifiers (e.g. "Chapters", "Folios", "Parashot")
    /// into traditional Hebrew when `prefersHebrew` is true, or English when false.
    public static func resolveNavigationStructureTitle(for key: String, prefersHebrew: Bool) -> String {
        if prefersHebrew {
            switch key.trimmingCharacters(in: .whitespacesAndNewlines) {
            case "Chapters": return "פרקים"
            case "Chapter": return "פרק"
            case "Folios": return "דפים"
            case "Folio": return "דף"
            case "Parashot", "Parashiot": return "פרשות"
            case "Parasha", "Parashah": return "פרשה"
            case "Perek": return "פרקים"
            case "Perakim": return "פרקים"
            case "Sections": return "סעיפים"
            case "Section": return "סעיף"
            case "Halakhot", "Halachot": return "הלכות"
            case "Halakha", "Halacha": return "הלכה"
            case "Mishnayot": return "משניות"
            case "Mishnah": return "משנה"
            case "Simanim": return "סימנים"
            case "Siman": return "סימן"
            case "Verses": return "פסוקים"
            case "Verse": return "פסוק"
            case "Teshuvot": return "תשובות"
            case "Teshuvah": return "תשובה"
            default: return key
            }
        } else {
            switch key.trimmingCharacters(in: .whitespacesAndNewlines) {
            case "פרקים", "Perek", "Perakim": return "Chapters"
            case "פרק": return "Chapter"
            case "דפים": return "Folios"
            case "דף": return "Folio"
            case "פרשות", "Parasha", "Parashot": return "Parashot"
            case "פרשה": return "Parasha"
            case "סעיפים": return "Sections"
            case "סעיף": return "Section"
            case "הלכות": return "Halakhot"
            case "הלכה": return "Halakhah"
            case "משניות": return "Mishnayot"
            case "משנה": return "Mishnah"
            case "סימנים": return "Simanim"
            case "סימן": return "Siman"
            case "פסוקים": return "Verses"
            case "פסוק": return "Verse"
            default: return key
            }
        }
    }


    /// Resolves the localized display title for a backend.
    /// Hebrew: "אוצריא", "ספריא (ישן)", "ספריא"
    /// English: "Otzaria", "Sefaria (Legacy)", "Sefaria"
    static func resolveBackendTitle(
        for backend: BackendID,
        forcedLocaleIdentifier: String? = nil
    ) -> String {
        let effectiveLocale = forcedLocaleIdentifier
            ?? Locale.preferredLanguages.first
            ?? Locale.current.language.languageCode?.identifier
            ?? "he"

        if effectiveLocale.hasPrefix("en") {
            switch backend {
            case .otzaria: return "Otzaria"
            case .sefaria: return "Sefaria (Legacy)"
            case .sefariaEmbedded: return "Sefaria"
            }
        } else {
            switch backend {
            case .otzaria: return "אוצריא"
            case .sefaria: return "ספריא (ישן)"
            case .sefariaEmbedded: return "ספריא"
            }
        }
    }
}
