//
//  ReaderNavigationDisplayPolicy.swift
//  Maktabah
//
//  Downstream-owned semantic navigation slider and reference header policy (Plan E2 & E4).
//

import Foundation

/// Governs the granularity of the reader navigation slider and the formatting of section vs. segment labels
/// across Otzaria and Sefaria backends.
enum ReaderNavigationDisplayPolicy {
    /// Extracts canonical structural navigation items (chapters, dafim, simanim, or primary TOC sections)
    /// from a hierarchical `LibraryTOCNode` tree.
    ///
    /// - If a node has children that are fine-grained paragraph/se'if leaves (e.g., numeric or short markers),
    ///   the parent chapter/section node itself is used as the slider step rather than flooding the slider
    ///   with ratusan/thousands of paragraph leaves.
    /// - If a book is flat (only leaf nodes at root), falls back gracefully to all leaf nodes.
    static func canonicalNavigationItems(from toc: [LibraryTOCNode]) -> [LibraryNavigationItem] {
        guard !toc.isEmpty else { return [] }

        var collectedNodes: [LibraryTOCNode] = []

        func visit(_ nodes: [LibraryTOCNode], depth: Int) {
            for node in nodes {
                if node.children.isEmpty {
                    collectedNodes.append(node)
                } else if areChildrenParagraphGranularity(node.children, parentTitle: node.title, depth: depth) {
                    // Stop at the chapter/siman/daf node instead of descending into paragraph-level children
                    collectedNodes.append(node)
                } else {
                    visit(node.children, depth: depth + 1)
                }
            }
        }

        visit(toc, depth: 0)

        if collectedNodes.isEmpty {
            // Defensive fallback to standard leaf collection
            func collectAllLeaves(_ nodes: [LibraryTOCNode]) {
                for node in nodes {
                    if node.children.isEmpty {
                        collectedNodes.append(node)
                    } else {
                        collectAllLeaves(node.children)
                    }
                }
            }
            collectAllLeaves(toc)
        }

        return collectedNodes.enumerated().map { idx, node in
            LibraryNavigationItem(
                locator: node.locator,
                title: sanitizeSectionTitle(node.title),
                index: idx
            )
        }
    }

    /// Evaluates whether a set of child TOC nodes represent fine-grained paragraph/se'if/verse/halakha/mishnah subdivisions
    /// under a canonical section parent node (`פרק`, `סימן`, `דף`, `Chapter`, `Siman`, `Daf`).
    ///
    /// Semantic rules across Torah literature structures:
    /// 1. Bavli / Yerushalmi (`מסכת -> פרק -> דף ב ע"א / דף ב:`): Daf/Amud nodes are primary structural units (never collapsed into Perek).
    /// 2. Tanakh (`ספר -> פרק א -> פסוק א`): Stops at `פרק א` when children are `פסוק` or verse numerals under a `פרק`.
    /// 3. Mishnah / Rambam (`ספר -> הלכות -> פרק א -> הלכה א / משנה א`): Descends through `הלכות`/`מסכת` and stops at `פרק א`.
    /// 4. Shulchan Aruch (`חלק -> סימן א -> סעיף א`): Descends through `חלק`/`הלכות` and stops at `סימן א`.
    /// 5. Multi-volume / Essay / Responsa (`חלק א -> מאמר א, מאמר ב`): Descends to `מאמר`/`פרק`/`תשובה` leaves at any depth.
    static func areChildrenParagraphGranularity(
        _ children: [LibraryTOCNode],
        parentTitle: String,
        depth: Int
    ) -> Bool {
        guard !children.isEmpty else { return false }
        // Only leaf children can be fine-grained paragraph/verse/se'if subdivisions
        let allChildrenAreLeaves = children.allSatisfy { $0.children.isEmpty }
        guard allChildrenAreLeaves else { return false }

        let normalizedParent = parentTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        // Rule A: If children themselves are major structural sections (Daf/Amud, Perek/Chapter, Siman, Maamar, Shaar, Chelek),
        // they must NEVER be collapsed into their parent, regardless of depth.
        let structuralSectionCount = children.filter { isMajorStructuralUnitTitle($0.title) }.count
        if structuralSectionCount * 2 >= children.count {
            return false
        }

        // Rule B: Explicit fine-grained leaf prefixes (סעיף, הלכה, משנה, פסוק, אות, פיסקה, פסקא, שורה, קטע, Verse, Paragraph)
        let fineGrainedLeafPrefixes = [
            "סעיף", "אות", "פסוק", "משנה", "הלכה", "פיסקה", "פסקא", "שורה", "קטע",
            "Seif", "Se'if", "Halakhah", "Halacha", "Mishnah", "Mishna", "Verse", "Paragraph", "Segment"
        ]

        let parentIsCanonicalSection = isCanonicalSectionContainerTitle(normalizedParent)

        let fineGrainedMatchCount = children.filter { child in
            let trimmed = child.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }

            // Avoid confusing "הלכות ..." (a collection of chapters in Rambam/Tur) with "הלכה א" (a single halakha inside a chapter)
            if trimmed.hasPrefix("הלכות") {
                return false
            }

            if fineGrainedLeafPrefixes.contains(where: { matchesWordPrefix(trimmed, prefix: $0) }) {
                return true
            }

            // Bare numeral/letter markers (e.g., "א", "ב", "י״ב", "1", "2") are paragraph/verse/se'if subdivisions
            // ONLY when nested under a canonical section container (פרק, סימן, דף, Chapter, Siman, Daf).
            if parentIsCanonicalSection && isBareNumeralOrLetterToken(trimmed) {
                return true
            }

            return false
        }.count

        return fineGrainedMatchCount * 2 >= children.count
    }

    private static func isMajorStructuralUnitTitle(_ rawTitle: String) -> Bool {
        let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let structuralPrefixes = [
            "דף", "עמוד", "פרק", "סימן", "חלק", "שער", "מאמר", "תשובה", "דרוש", "מסכת", "סדר", "הלכות", "מבוא", "הקדמה",
            "Daf", "Chapter", "Perek", "Siman", "Part", "Volume", "Section", "Gate", "Tractate", "Essay"
        ]
        if structuralPrefixes.contains(where: { matchesWordPrefix(trimmed, prefix: $0) }) {
            return true
        }
        // English Talmud daf notation such as "2a", "2b", "15a"
        if trimmed.range(of: #"^\d{1,3}[abAB]$"#, options: .regularExpression) != nil {
            return true
        }
        // Hebrew Talmud daf notation ending in "." or ":" such as "ב.", "ב:", "י״ב."
        if trimmed.hasSuffix(".") || trimmed.hasSuffix(":") {
            let core = String(trimmed.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
            if isBareHebrewLetterOrNumeral(core) {
                return true
            }
        }
        return false
    }

    private static func isCanonicalSectionContainerTitle(_ rawTitle: String) -> Bool {
        let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let containerPrefixes = [
            "פרק", "סימן", "דף", "עמוד",
            "Chapter", "Perek", "Siman", "Daf"
        ]
        if containerPrefixes.contains(where: { matchesWordPrefix(trimmed, prefix: $0) }) {
            return true
        }
        if trimmed.range(of: #"^\d{1,3}[abAB]$"#, options: .regularExpression) != nil {
            return true
        }
        return false
    }

    private static func matchesWordPrefix(_ text: String, prefix: String) -> Bool {
        guard text.hasPrefix(prefix) else { return false }
        if text.count == prefix.count { return true }
        let nextIndex = text.index(text.startIndex, offsetBy: prefix.count)
        let nextChar = text[nextIndex]
        return nextChar.isWhitespace || nextChar == ":" || nextChar == "." || nextChar == "-" || nextChar == "׳" || nextChar == "'"
    }

    private static func isBareNumeralOrLetterToken(_ token: String) -> Bool {
        let cleaned = token.trimmingCharacters(in: CharacterSet(charactersIn: " .,'\"׳״()[]"))
        guard !cleaned.isEmpty, cleaned.count <= 4 else { return false }
        if cleaned.allSatisfy(\.isNumber) { return true }
        return isBareHebrewLetterOrNumeral(cleaned)
    }

    private static func isBareHebrewLetterOrNumeral(_ token: String) -> Bool {
        let cleaned = token.trimmingCharacters(in: CharacterSet(charactersIn: " .,'\"׳״"))
        guard !cleaned.isEmpty, cleaned.count <= 4 else { return false }
        return cleaned.unicodeScalars.allSatisfy { scalar in
            (0x05D0...0x05EA).contains(scalar.value)
        }
    }

    /// Distinguishes between:
    /// 1. Ordinary reading position (`selectedSegmentLocator == nil`, `isInspectorVisible == false`) -> returns `nil`
    /// 2. Link-opened or search-opened focus (`selectedSegmentLocator == destinationFocusLocator` or `searchHighlightFocusLocator`
    ///    while `isInspectorVisible == false`) -> returns `nil` (not an explicit user segment tap)
    /// 3. Explicit user segment selection (`isInspectorVisible == true` after `didTapReaderText(at:)`) -> returns the selected `TextLocator`.
    static func resolveExplicitUserSelectedSegmentLocator(
        selectedSegmentLocator: TextLocator?,
        otzariaSelectedLineIndex: Int? = nil,
        otzariaBookId: Int? = nil,
        destinationFocusLocator: TextLocator? = nil,
        searchHighlightFocusLocator: TextLocator? = nil,
        isInspectorVisible: Bool
    ) -> TextLocator? {
        // In ReaderViewModel, loadBackendContentInternal sets `selectedSegmentLocator = currentDestination?.focusLocator`
        // when opening a book from a link or search result while `readerInspectorVisible` remains `false`.
        // An explicit user selection (`didTapReaderText`) always sets `readerInspectorVisible = true`.
        guard isInspectorVisible else {
            return nil
        }
        if let selectedSegmentLocator {
            return selectedSegmentLocator
        }
        if let lineIndex = otzariaSelectedLineIndex, let bookId = otzariaBookId {
            return TextLocator(
                backend: .otzaria,
                workKey: "book:\(bookId)",
                position: .legacyLine(lineIndex)
            )
        }
        return nil
    }

    /// Formats the primary section title displayed in the navigation slider popover header.
    /// Shows only the canonical section/chapter/daf name (stripping trailing `:segment` or line numbers)
    /// unless an explicit segment is selected.
    static func formattedCurrentSectionLabel(
        sectionDisplayRef: String?,
        sectionHeRef: String?,
        activeNavigationItemTitle: String?,
        explicitSelectedSegmentLocator: TextLocator?,
        prefersHebrew: Bool = true
    ) -> (sectionTitle: String, selectedSegmentBadge: String?) {
        let rawSection = (prefersHebrew ? (sectionHeRef ?? sectionDisplayRef) : (sectionDisplayRef ?? sectionHeRef))
            ?? activeNavigationItemTitle
            ?? ""

        let cleanSection: String
        if let navTitle = activeNavigationItemTitle, !navTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            cleanSection = sanitizeSectionTitle(navTitle)
        } else {
            cleanSection = sanitizeSectionTitle(rawSection)
        }

        guard let explicitLocator = explicitSelectedSegmentLocator else {
            return (cleanSection, nil)
        }

        let segmentBadge = extractExplicitSegmentBadge(from: explicitLocator, prefersHebrew: prefersHebrew)
        return (cleanSection, segmentBadge)
    }

    /// Strips paragraph/segment suffixes (such as `"Genesis 1:3"` -> `"Genesis 1"` or `"בראשית א׳:ד׳"` -> `"בראשית א׳"`)
    /// while preserving Hebrew Talmud Amud Bet notation (`"דף ב:"`, `"שבת ב:"`) and general titles containing colons.
    static func sanitizeSectionTitle(_ rawTitle: String) -> String {
        let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        // Never strip a trailing colon used as Talmud Amud Bet notation (e.g. "דף ב:", "שבת דף י״ב:")
        if trimmed.hasSuffix(":") {
            return trimmed
        }

        // Only strip ":<segment>" when the suffix after the last colon is a short numeral/Hebrew verse token
        if let colonIndex = trimmed.lastIndex(of: ":"), colonIndex > trimmed.startIndex {
            let prefix = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            let suffix = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !prefix.isEmpty, isBareNumeralOrLetterToken(suffix) {
                return prefix
            }
        }
        return trimmed
    }

    /// Resolves the active slider index (`0 ..< items.count`) for the current reader locator or line index.
    static func resolveActiveNavigationIndex(
        in items: [LibraryNavigationItem],
        currentLocator: TextLocator?,
        currentContentId: Int?
    ) -> Int? {
        guard !items.isEmpty else { return nil }

        if let currentLocator {
            if let exact = items.firstIndex(where: { $0.locator == currentLocator }) {
                return exact
            }

            switch currentLocator.position {
            case .legacyLine(let currentLine):
                return resolveBestLineIndexMatch(in: items, targetLine: currentLine)
            case .canonicalRef(let ref):
                let sectionRef = sanitizeSectionTitle(ref)
                if let match = items.firstIndex(where: {
                    if case .canonicalRef(let itemRef) = $0.locator.position {
                        return itemRef == sectionRef || ref.hasPrefix(itemRef + ":") || ref.hasPrefix(itemRef + ".")
                    }
                    return false
                }) {
                    return match
                }
            }
        }

        if let currentContentId, currentContentId > 0 {
            return resolveBestLineIndexMatch(in: items, targetLine: currentContentId)
        }

        return 0
    }

    private static func resolveBestLineIndexMatch(in items: [LibraryNavigationItem], targetLine: Int) -> Int? {
        var bestIndex: Int?
        var bestLine = Int.min

        for (index, item) in items.enumerated() {
            guard case .legacyLine(let itemLine) = item.locator.position else { continue }
            if itemLine <= targetLine && itemLine >= bestLine {
                bestLine = itemLine
                bestIndex = index
            }
        }

        return bestIndex ?? 0
    }

    private static func extractExplicitSegmentBadge(from locator: TextLocator, prefersHebrew: Bool) -> String? {
        switch locator.position {
        case .legacyLine(let line):
            guard line > 0 else { return nil }
            return prefersHebrew ? "קטע \(line)" : "Segment \(line)"
        case .canonicalRef(let ref):
            if let colonIdx = ref.lastIndex(of: ":") {
                let seg = String(ref[ref.index(after: colonIdx)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !seg.isEmpty else { return nil }
                return prefersHebrew ? "קטע \(seg)" : "Segment \(seg)"
            }
            return nil
        }
    }

    /// Resolves the unified semantic reference string across all reader chrome surfaces:
    /// - `iOSReaderNavigationPopoverView`
    /// - `iOSReaderBottomToolbarView`
    /// - `ReaderLibraryToolbarHost` (Safari Top Toolbar)
    /// Guarantees that without an explicit user selection (`readerInspectorVisible == true` and selected line),
    /// neither Otzaria nor Sefaria displays an unrequested paragraph or line number.
    static func resolveUnifiedSemanticDisplayLabel(
        sectionDisplayRef: String?,
        sectionHeRef: String?,
        activeNavigationItemTitle: String?,
        explicitSelectedSegmentLocator: TextLocator?,
        fallbackSubtitle: String? = nil
    ) -> String {
        let formatted = formattedCurrentSectionLabel(
            sectionDisplayRef: sectionDisplayRef,
            sectionHeRef: sectionHeRef,
            activeNavigationItemTitle: activeNavigationItemTitle,
            explicitSelectedSegmentLocator: explicitSelectedSegmentLocator
        )
        if let badge = formatted.selectedSegmentBadge {
            return "\(formatted.sectionTitle) (\(badge))"
        }
        if !formatted.sectionTitle.isEmpty {
            return formatted.sectionTitle
        }
        return fallbackSubtitle ?? ""
    }
}
