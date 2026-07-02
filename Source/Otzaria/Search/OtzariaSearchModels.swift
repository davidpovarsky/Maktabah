import Foundation

struct OtzariaSearchRequest: Codable, Sendable {
    var query: String
    var mode: OtzariaSearchMode
    var facets: [String]
    var limit: Int
    var offset: Int
    var order: OtzariaSearchOrder
    var distance: Int?
    var customSpacing: [String: String]
    var alternativeWords: [Int: [String]]
    var searchOptions: [String: [String: Bool]]

    init(
        query: String,
        mode: OtzariaSearchMode = .advanced,
        facets: [String] = ["/"],
        limit: Int = 100,
        offset: Int = 0,
        order: OtzariaSearchOrder = .catalogue,
        distance: Int? = nil,
        customSpacing: [String: String] = [:],
        alternativeWords: [Int: [String]] = [:],
        searchOptions: [String: [String: Bool]] = [:]
    ) {
        self.query = query
        self.mode = mode
        self.facets = facets
        self.limit = limit
        self.offset = offset
        self.order = order
        self.distance = distance
        self.customSpacing = customSpacing
        self.alternativeWords = alternativeWords
        self.searchOptions = searchOptions
    }

    enum CodingKeys: String, CodingKey {
        case query, mode, facets, limit, offset, order, distance, customSpacing, alternativeWords, searchOptions
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(query, forKey: .query)
        try container.encode(mode.engineValue, forKey: .mode)
        try container.encode(facets, forKey: .facets)
        try container.encode(limit, forKey: .limit)
        try container.encode(offset, forKey: .offset)
        try container.encode(order.rawValue, forKey: .order)
        try container.encodeIfPresent(distance, forKey: .distance)
        try container.encode(customSpacing, forKey: .customSpacing)
        try container.encode(alternativeWords, forKey: .alternativeWords)
        try container.encode(searchOptions, forKey: .searchOptions)
    }
}

struct OtzariaSearchDocument: Codable, Sendable {
    let id: UInt64
    let title: String
    let reference: String
    let topics: String
    let text: String
    let segment: UInt64
    let isPdf: Bool
    let filePath: String

    enum CodingKeys: String, CodingKey {
        case id, title, reference, topics, text, segment
        case isPdf = "is_pdf"
        case filePath = "file_path"
    }
}

struct OtzariaEngineSearchResult: Codable, Hashable, Sendable {
    let title: String
    let reference: String
    let text: String
    let id: UInt64
    let segment: UInt64
    let isPdf: Bool
    let filePath: String
}

struct OtzariaEngineResponse<T: Decodable>: Decodable {
    let ok: Bool
    let value: T?
    let error: String?
}

struct OtzariaIndexFingerprint: Codable, Equatable, Sendable {
    let databasePath: String
    let fileSize: UInt64
    let modificationTime: TimeInterval
}

enum OtzariaSearchIndexStatus: Equatable {
    case unavailable
    case missing
    case ready(documentCount: UInt64)
    case indexing(processedBooks: Int, totalBooks: Int, processedLines: Int)
    case failed(String)

    var label: String {
        switch self {
        case .unavailable:
            return "לא נבחר מסד אוצריא"
        case .missing:
            return "האינדקס עדיין לא נבנה"
        case .ready(let count):
            return "האינדקס מוכן (\(count) מסמכים)"
        case .indexing(let processedBooks, let totalBooks, let processedLines):
            return "מאנדקס \(processedBooks)/\(totalBooks) ספרים · \(processedLines) שורות"
        case .failed(let message):
            return "שגיאת אינדוקס: \(message)"
        }
    }
}

enum OtzariaSearchError: Error, LocalizedError {
    case databaseNotSelected
    case engineNotAvailable
    case invalidEngineResponse(String)
    case indexingCancelled

    var errorDescription: String? {
        switch self {
        case .databaseNotSelected:
            return "לא נבחר seforim.db של אוצריא."
        case .engineNotAvailable:
            return "מנוע החיפוש של אוצריא לא נטען. ודא שה־XCFramework נוסף ל־target."
        case .invalidEngineResponse(let message):
            return message
        case .indexingCancelled:
            return "האינדוקס בוטל."
        }
    }
}
