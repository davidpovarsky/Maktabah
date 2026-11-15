import Foundation

extension UnifiedSearchSessionController {
    /// BackendCapabilities.search guarantees text search, not individual SearchOptions.
    /// The Embedded provider currently hardcodes exact/relevance; do not offer ignored controls.
    var supportsSefariaOptions: Bool {
        BackendCoordinator.shared.activeCapabilities.contains(.search)
            && BackendCoordinator.shared.activeBackendID == .sefaria
    }

    var supportsResultSorting: Bool {
        BackendCoordinator.shared.activeCapabilities.contains(.search)
            && (supportsSefariaOptions || (!isSefaria && scope != .zayit))
    }

    /// Array equality avoids delimiter ambiguities in user-supplied expressions.
    /// Presentation-only resultKitabFilter and tree filterText are deliberately excluded.
    var requestConfiguration: [String] {
        var values = [query.trimmingCharacters(in: .whitespacesAndNewlines), scope.rawValue,
                      BackendCoordinator.shared.activeBackendID.rawValue,
                      String(describing: BackendCoordinator.shared.generation),
                      selectedBookIds.sorted().map(String.init).joined(separator: ",")]
        if isSefaria {
            if supportsSefariaOptions {
                values += [scope == .exact ? LibrarySearchMatchMode.exact.rawValue : sefariaMatchMode.rawValue,
                           String(scope == .exact ? 0 : sefariaWordDistance), sefariaSortOrder.rawValue,
                           String(sefariaReverseSort)]
            }
        } else if scope == .zayit {
            values += [zayitSession.model.matchMode.rawValue]
        } else {
            values += [otzariaOrder.rawValue]
            if scope == .advanced {
                values += [otzariaNegativeQuery, otzariaScope.rawValue, otzariaNegativeScope.rawValue,
                           otzariaWordMatchMode.rawValue, String(otzariaWordMatchCount),
                           otzariaGrouping?.rawValue ?? "", String(otzariaDistance), String(otzariaNegativeDistance),
                           String(otzariaMatchNikud), String(otzariaMatchTaamim), String(otzariaEnablesPrefixes),
                           String(otzariaEnablesSuffixes), String(otzariaEnablesSpellingVariants),
                           String(otzariaEnablesAramaic), String(otzariaIgnoresQuotes),
                           otzariaCustomSpacingText, otzariaAlternativeWordsText]
            }
        }
        return values
    }

    var resultsAreDirty: Bool {
        hasSubmitted && (configurationInvalidated || submittedConfiguration != requestConfiguration)
    }

    var filteredResults: [SearchResultItem] {
        let filter = resultKitabFilter.trimmingCharacters(in: .whitespacesAndNewlines).normalizeArabic(false)
        guard !filter.isEmpty else { return results }
        return results.filter { $0.bookTitle.normalizeArabic(false).contains(filter) }
    }

    var loadedResultsSummary: String {
        if !resultKitabFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(filteredResults.count) מתוך \(results.count) תוצאות שנטענו · סינון לפי שם הספר בלבד"
        }
        // Engine aggregate totals describe documents/groups, not necessarily displayed occurrences.
        // Legacy/Embedded precision is not carried through SearchViewModel. Never invent an exact total.
        var summary = "\(results.count) תוצאות שנטענו" + (hasMore ? " · תוצאות נוספות זמינות" : "")
        if isSefaria {
            summary += " · המספר הכולל אינו מאומת"
        } else if scope == .zayit {
            summary += " · דיווח מנוע: \(zayitSession.model.totalHits) מסמכים"
        } else if let page = otzaria.enginePage {
            summary += " · דיווח מנוע לפני מיפוי/קיבוץ: \(page.totalCount)"
        }
        return summary
    }

    var optionsValidationMessage: String? {
        guard !isSefaria, scope == .advanced else { return nil }
        guard otzariaDistance >= 0, otzariaNegativeDistance >= 0, otzariaWordMatchCount > 0 else {
            return "יש להזין מרחק שאינו שלילי ומספר מילים חיובי."
        }
        // Empty positions are meaningful. Validate without rewriting or dropping them.
        for value in otzariaCustomSpacingText.split(separator: ",", omittingEmptySubsequences: false) {
            let token = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !token.isEmpty && (Int(token) == nil || (Int(token) ?? -1) < 0) {
                return "מרווח מותאם חייב להיות מספר שלם שאינו שלילי; הפרידו בין המיקומים בפסיק."
            }
        }
        return nil
    }
}
