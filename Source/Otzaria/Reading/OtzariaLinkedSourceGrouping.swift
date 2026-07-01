import Foundation

struct OtzariaLinkedSourceConnectionGroup: Identifiable {
    let id: String
    let title: String
    let categoryGroups: [OtzariaLinkedSourceCategoryGroup]
}

struct OtzariaLinkedSourceCategoryGroup: Identifiable {
    let id: String
    let title: String
    let bookGroups: [OtzariaLinkedSourceBookGroup]
}

struct OtzariaLinkedSourceBookGroup: Identifiable {
    let id: String
    let title: String
    let sources: [OtzariaLinkedSource]
}

struct OtzariaLinkedSourceDisplaySection: Identifiable {
    let id: String
    let title: String
    let sources: [OtzariaLinkedSource]
}

enum OtzariaLinkedSourceGrouping {
    static func groups(from sources: [OtzariaLinkedSource]) -> [OtzariaLinkedSourceConnectionGroup] {
        let groupedByConnection = Dictionary(grouping: sources, by: \.connectionType)

        return groupedByConnection.keys.sorted(by: compareConnectionTypes).compactMap { connectionType in
            guard let connectionSources = groupedByConnection[connectionType], !connectionSources.isEmpty else {
                return nil
            }

            let groupedByCategory = Dictionary(grouping: connectionSources) { source in
                categoryTitle(for: source)
            }

            let categoryGroups = groupedByCategory.keys.sorted {
                compareCategoryTitles($0, $1, connectionType: connectionType)
            }.compactMap { categoryTitle -> OtzariaLinkedSourceCategoryGroup? in
                guard let categorySources = groupedByCategory[categoryTitle], !categorySources.isEmpty else {
                    return nil
                }

                let groupedByBook = Dictionary(grouping: categorySources, by: \.bookTitle)
                let bookGroups = groupedByBook.keys.sorted {
                    compareBookTitles($0, $1, groupedByBook: groupedByBook)
                }.compactMap { bookTitle -> OtzariaLinkedSourceBookGroup? in
                    guard let bookSources = groupedByBook[bookTitle], !bookSources.isEmpty else {
                        return nil
                    }

                    return OtzariaLinkedSourceBookGroup(
                        id: "\(connectionType)-\(categoryTitle)-\(bookTitle)",
                        title: bookTitle,
                        sources: bookSources.sorted(by: compareSources)
                    )
                }

                return OtzariaLinkedSourceCategoryGroup(
                    id: "\(connectionType)-\(categoryTitle)",
                    title: categoryTitle,
                    bookGroups: bookGroups
                )
            }

            return OtzariaLinkedSourceConnectionGroup(
                id: connectionType,
                title: connectionTitle(for: connectionType),
                categoryGroups: categoryGroups
            )
        }
    }

    static func displaySections(from sources: [OtzariaLinkedSource]) -> [OtzariaLinkedSourceDisplaySection] {
        groups(from: sources).flatMap { connectionGroup in
            connectionGroup.categoryGroups.map { categoryGroup in
                let sectionTitle: String
                if connectionGroup.title == categoryGroup.title {
                    sectionTitle = connectionGroup.title
                } else {
                    sectionTitle = "\(connectionGroup.title) · \(categoryGroup.title)"
                }

                let flattenedSources = categoryGroup.bookGroups.flatMap { $0.sources }

                return OtzariaLinkedSourceDisplaySection(
                    id: "\(connectionGroup.id)-\(categoryGroup.id)",
                    title: sectionTitle,
                    sources: flattenedSources
                )
            }
        }
        .filter { !$0.sources.isEmpty }
    }

    private static func compareConnectionTypes(_ lhs: String, _ rhs: String) -> Bool {
        let order = ["COMMENTARY", "TARGUM", "REFERENCE", "SOURCE", "OTHER"]
        let lhsIndex = order.firstIndex(of: lhs)
        let rhsIndex = order.firstIndex(of: rhs)

        switch (lhsIndex, rhsIndex) {
        case let (lhsIndex?, rhsIndex?):
            return lhsIndex < rhsIndex
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
    }

    private static func connectionTitle(for connectionType: String) -> String {
        switch connectionType {
        case "COMMENTARY": return "כל המפרשים"
        case "TARGUM": return "תרגום"
        case "REFERENCE": return "מראי מקומות"
        case "SOURCE": return "מקורות"
        case "OTHER": return "אחר"
        default: return connectionType
        }
    }

    private static func compareCategoryTitles(_ lhs: String, _ rhs: String, connectionType: String) -> Bool {
        guard connectionType == "COMMENTARY" else {
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }

        let order = ["ראשונים", "אחרונים", "מפרשים אחרים", "אחר"]
        let lhsIndex = order.firstIndex(of: lhs)
        let rhsIndex = order.firstIndex(of: rhs)

        switch (lhsIndex, rhsIndex) {
        case let (lhsIndex?, rhsIndex?):
            return lhsIndex < rhsIndex
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
    }

    private static func compareBookTitles(
        _ lhs: String,
        _ rhs: String,
        groupedByBook: [String: [OtzariaLinkedSource]]
    ) -> Bool {
        let lhsFirst = groupedByBook[lhs]?.min(by: compareSources)
        let rhsFirst = groupedByBook[rhs]?.min(by: compareSources)
        let lhsOrder = lhsFirst?.linkedBookOrderIndex
        let rhsOrder = rhsFirst?.linkedBookOrderIndex

        switch (lhsOrder, rhsOrder) {
        case let (lhsOrder?, rhsOrder?) where lhsOrder != rhsOrder:
            return lhsOrder < rhsOrder
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            let titleComparison = lhs.localizedStandardCompare(rhs)
            if titleComparison != .orderedSame {
                return titleComparison == .orderedAscending
            }
            return (lhsFirst?.linkedLineIndex ?? 0) < (rhsFirst?.linkedLineIndex ?? 0)
        }
    }

    private static func compareSources(_ lhs: OtzariaLinkedSource, _ rhs: OtzariaLinkedSource) -> Bool {
        if lhs.linkedLineIndex != rhs.linkedLineIndex {
            return lhs.linkedLineIndex < rhs.linkedLineIndex
        }
        return (lhs.heRef ?? "").localizedStandardCompare(rhs.heRef ?? "") == .orderedAscending
    }

    private static func categoryTitle(for source: OtzariaLinkedSource) -> String {
        if source.connectionType == "COMMENTARY" {
            if source.linkedCategoryPath.contains("ראשונים") {
                return "ראשונים"
            }
            if source.linkedCategoryPath.contains("אחרונים") {
                return "אחרונים"
            }
            if source.linkedCategoryPath.contains("מפרשים") {
                return "מפרשים אחרים"
            }
            if let categoryTitle = nearestCategoryTitle(for: source) {
                return categoryTitle
            }
            if pathComponents(from: source.bookPath).contains("ראשונים") {
                return "ראשונים"
            }
            if pathComponents(from: source.bookPath).contains("אחרונים") {
                return "אחרונים"
            }
            return "מפרשים אחרים"
        }

        if let categoryTitle = nearestCategoryTitle(for: source) {
            return categoryTitle
        }
        if let folderTitle = pathComponents(from: source.bookPath).dropLast().last, !folderTitle.isEmpty {
            return folderTitle
        }
        return source.localizedConnectionType
    }

    private static func nearestCategoryTitle(for source: OtzariaLinkedSource) -> String? {
        source.linkedCategoryPath.last { title in
            !title.isEmpty && title != source.bookTitle
        }
    }

    private static func pathComponents(from path: String?) -> [String] {
        guard let path, !path.isEmpty else { return [] }
        return path
            .split { character in character == "/" || character == "\\" }
            .map(String.init)
            .filter { !$0.isEmpty }
    }
}
