import Foundation

extension LibraryPresentationPolicy {
    static func workTitle(
        title: String,
        heTitle: String?,
        localeIdentifier: String? = Locale.preferredLanguages.first
    ) -> String {
        let canonical = title.nonEmpty
        let hebrew = heTitle?.nonEmpty
        return prefersHebrew(localeIdentifier: localeIdentifier)
            ? (hebrew ?? canonical ?? "")
            : (canonical ?? hebrew ?? "")
    }

    static func categoryTitle(
        title: String,
        heTitle: String?,
        localeIdentifier: String? = Locale.preferredLanguages.first
    ) -> String {
        workTitle(title: title, heTitle: heTitle, localeIdentifier: localeIdentifier)
    }

    static func reference(
        displayRef: String,
        heRef: String?,
        localeIdentifier: String? = Locale.preferredLanguages.first
    ) -> String {
        let canonical = displayRef.nonEmpty
        let hebrew = heRef?.nonEmpty
        return prefersHebrew(localeIdentifier: localeIdentifier)
            ? (hebrew ?? canonical ?? "")
            : (canonical ?? hebrew ?? "")
    }

    static func interfaceDirection(
        presentedText: String? = nil,
        localeIdentifier: String? = Locale.preferredLanguages.first
    ) -> LibraryTextDirection {
        if let presentedText, presentedText.range(of: "[\\u{0590}-\\u{08FF}]", options: .regularExpression) != nil {
            return .rightToLeft
        }
        return prefersHebrew(localeIdentifier: localeIdentifier) ? .rightToLeft : .leftToRight
    }

    static func localizedNumber(_ value: Int, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
