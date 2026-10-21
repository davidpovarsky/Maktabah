//
//  SearchResultItem.swift
//  Maktabah
//

import Foundation

struct SearchHit: Sendable, Identifiable, Hashable {
    let archive: String
    let tableName: String
    let rowId: Int
    let page: Int
    let part: Int

    var id: String { "\(archive)_\(tableName)_\(rowId)" }
}

struct SearchResultItem: Codable, CopyableResult, Hashable, Sendable, Identifiable {
    let archive: String
    let tableName: String
    let bookId: Int
    let bookTitle: String
    let page: Int
    let part: Int
    let backendLocator: TextLocator?
    let locationDisplayText: String?
    let highlightTerms: [String]?
    let versionTitle: String?
    let resultLanguage: String?
    private nonisolated(unsafe) let rawAttributedText: NSAttributedString?

    var attributedText: NSAttributedString {
        rawAttributedText ?? NSAttributedString(string: "")
    }

    var hasResolvedSnippet: Bool {
        rawAttributedText != nil
    }

    var stableID: String {
        let locator = backendLocator?.persistenceKey
            ?? "legacy:\(archive):\(tableName):\(bookId):\(part):\(page)"
        return "\(locator)|\(versionTitle ?? "")|\(resultLanguage ?? "")"
    }

    var id: String {
        if let backendLocator {
            return "\(backendLocator.persistenceKey)_\(versionTitle ?? "")"
        }
        return "\(archive)_\(tableName)_\(bookId)_\(part)_\(page)"
    }

    var uniqueId: String { stableID }

    enum CodingKeys: String, CodingKey {
        case archive
        case tableName
        case bookId
        case bookTitle
        case page
        case part
        case attributedText
        case backendLocator
        case locationDisplayText
        case highlightTerms
        case versionTitle
        case resultLanguage
    }

    init(
        archive: String,
        tableName: String,
        bookId: Int,
        bookTitle: String,
        page: Int,
        part: Int,
        attributedText: NSAttributedString? = nil,
        backendLocator: TextLocator? = nil,
        locationDisplayText: String? = nil,
        highlightTerms: [String]? = nil,
        versionTitle: String? = nil,
        resultLanguage: String? = nil
    ) {
        self.archive = archive
        self.tableName = tableName
        self.bookId = bookId
        self.bookTitle = bookTitle
        self.page = page
        self.part = part
        self.backendLocator = backendLocator
        self.locationDisplayText = locationDisplayText
        self.highlightTerms = highlightTerms
        self.versionTitle = versionTitle
        self.resultLanguage = resultLanguage
        rawAttributedText = attributedText
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(archive, forKey: .archive)
        try container.encode(tableName, forKey: .tableName)
        try container.encode(bookId, forKey: .bookId)
        try container.encode(bookTitle, forKey: .bookTitle)
        try container.encode(page, forKey: .page)
        try container.encode(part, forKey: .part)
        try container.encodeIfPresent(backendLocator, forKey: .backendLocator)
        try container.encodeIfPresent(locationDisplayText, forKey: .locationDisplayText)
        try container.encodeIfPresent(highlightTerms, forKey: .highlightTerms)
        try container.encodeIfPresent(versionTitle, forKey: .versionTitle)
        try container.encodeIfPresent(resultLanguage, forKey: .resultLanguage)

        if let rawAttributedText {
            try container.encode(rawAttributedText.archivedData(), forKey: .attributedText)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        archive = try container.decode(String.self, forKey: .archive)
        tableName = try container.decode(String.self, forKey: .tableName)
        bookId = try container.decode(Int.self, forKey: .bookId)
        bookTitle = try container.decode(String.self, forKey: .bookTitle)
        page = try container.decode(Int.self, forKey: .page)
        part = try container.decode(Int.self, forKey: .part)
        backendLocator = try container.decodeIfPresent(TextLocator.self, forKey: .backendLocator)
        locationDisplayText = try container.decodeIfPresent(String.self, forKey: .locationDisplayText)
        highlightTerms = try container.decodeIfPresent([String].self, forKey: .highlightTerms)
        versionTitle = try container.decodeIfPresent(String.self, forKey: .versionTitle)
        resultLanguage = try container.decodeIfPresent(String.self, forKey: .resultLanguage)

        if let data = try container.decodeIfPresent(Data.self, forKey: .attributedText) {
            rawAttributedText = NSAttributedString.unarchiveSecure(from: data)
        } else {
            rawAttributedText = nil
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(stableID)
    }

    static func == (lhs: SearchResultItem, rhs: SearchResultItem) -> Bool {
        lhs.stableID == rhs.stableID
    }

    func formatForClipboard() -> String {
        let isHebrewBackend = backendLocator != nil || archive == "Otzaria" || archive == "Sefaria"
        if isHebrewBackend {
            if let locationDisplayText, !locationDisplayText.isEmpty {
                return "\(bookTitle) - \(locationDisplayText)\n\(attributedText.string)\n\n"
            }
            var locationParts: [String] = []
            if part > 0 { locationParts.append("כרך: \(part)") }
            if page > 0 { locationParts.append("עמ': \(page)") }
            let location = locationParts.joined(separator: " • ")
            if !location.isEmpty {
                return "\(bookTitle) - \(location)\n\(attributedText.string)\n\n"
            }
            return "\(bookTitle)\n\(attributedText.string)\n\n"
        }
        let pageArab = String(page).convertToArabicDigits()
        let partArab = String(part).convertToArabicDigits()
        if page != -1, part != -1 {
            return "\(bookTitle) - ج: \(partArab) • ص: \(pageArab)\n\(attributedText.string)\n\n"
        }
        return "\(bookTitle)\n\(attributedText.string)\n\n"
    }
}
