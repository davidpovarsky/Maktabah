import Foundation

enum OtzariaSearchScope: String, Codable, CaseIterable, Sendable {
    case wordDistance
    case sameParagraph
    case sameSection
}

enum OtzariaWordMatchMode: String, Codable, CaseIterable, Sendable {
    case all
    case anyWord
    case mostWords
    case atLeast
}

enum OtzariaResultGrouping: String, Codable, CaseIterable, Sendable {
    case sameSection
    case identicalText
}

struct OtzariaSearchRequest: Codable, Sendable {
    var query: String
    var mode: OtzariaSearchMode
    var facets: [String]
    var limit: Int
    var offset: Int
    var order: OtzariaSearchOrder
    var distance: Int
    var negativeQuery: String
    var negativeDistance: Int
    var scope: OtzariaSearchScope
    var negativeScope: OtzariaSearchScope
    var wordMatchMode: OtzariaWordMatchMode
    var wordMatchCount: Int?
    var customSpacing: [String: String]
    var negativeCustomSpacing: [String: String]
    var alternativeWords: [String: [String]]
    var negativeAlternativeWords: [String: [String]]
    var searchOptions: [String: [String: Bool]]
    var negativeSearchOptions: [String: [String: Bool]]
    var matchNikud: Bool
    var matchTaamim: Bool
    var grouping: OtzariaResultGrouping?

    init(
        query: String,
        mode: OtzariaSearchMode = .advanced,
        facets: [String] = ["/"],
        limit: Int = 100,
        offset: Int = 0,
        order: OtzariaSearchOrder = .catalogue,
        distance: Int = 0,
        negativeQuery: String = "",
        negativeDistance: Int = 0,
        scope: OtzariaSearchScope = .wordDistance,
        negativeScope: OtzariaSearchScope = .wordDistance,
        wordMatchMode: OtzariaWordMatchMode = .all,
        wordMatchCount: Int? = nil,
        customSpacing: [String: String] = [:],
        negativeCustomSpacing: [String: String] = [:],
        alternativeWords: [String: [String]] = [:],
        negativeAlternativeWords: [String: [String]] = [:],
        searchOptions: [String: [String: Bool]] = [:],
        negativeSearchOptions: [String: [String: Bool]] = [:],
        matchNikud: Bool = false,
        matchTaamim: Bool = false,
        grouping: OtzariaResultGrouping? = nil
    ) {
        self.query = query
        self.mode = mode
        self.facets = facets
        self.limit = limit
        self.offset = offset
        self.order = order
        self.distance = distance
        self.negativeQuery = negativeQuery
        self.negativeDistance = negativeDistance
        self.scope = scope
        self.negativeScope = negativeScope
        self.wordMatchMode = wordMatchMode
        self.wordMatchCount = wordMatchCount
        self.customSpacing = customSpacing
        self.negativeCustomSpacing = negativeCustomSpacing
        self.alternativeWords = alternativeWords
        self.negativeAlternativeWords = negativeAlternativeWords
        self.searchOptions = searchOptions
        self.negativeSearchOptions = negativeSearchOptions
        self.matchNikud = matchNikud
        self.matchTaamim = matchTaamim
        self.grouping = grouping
    }

    enum CodingKeys: String, CodingKey {
        case query, facets, limit, offset, order, distance, negativeQuery, negativeDistance
        case scope, negativeScope, wordMatchMode, wordMatchCount, customSpacing
        case negativeCustomSpacing, alternativeWords, negativeAlternativeWords
        case searchOptions, negativeSearchOptions, matchNikud, matchTaamim, grouping
        case mode
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(query, forKey: .query)
        try container.encode(mode.engineValue, forKey: .mode)
        try container.encode(facets, forKey: .facets)
        try container.encode(limit, forKey: .limit)
        try container.encode(offset, forKey: .offset)
        try container.encode(order.rawValue, forKey: .order)
        try container.encode(distance, forKey: .distance)
        try container.encode(negativeQuery, forKey: .negativeQuery)
        try container.encode(negativeDistance, forKey: .negativeDistance)
        try container.encode(scope, forKey: .scope)
        try container.encode(negativeScope, forKey: .negativeScope)
        try container.encode(wordMatchMode, forKey: .wordMatchMode)
        try container.encodeIfPresent(wordMatchCount, forKey: .wordMatchCount)
        try container.encode(customSpacing, forKey: .customSpacing)
        try container.encode(negativeCustomSpacing, forKey: .negativeCustomSpacing)
        try container.encode(alternativeWords, forKey: .alternativeWords)
        try container.encode(negativeAlternativeWords, forKey: .negativeAlternativeWords)
        try container.encode(searchOptions, forKey: .searchOptions)
        try container.encode(negativeSearchOptions, forKey: .negativeSearchOptions)
        try container.encode(matchNikud, forKey: .matchNikud)
        try container.encode(matchTaamim, forKey: .matchTaamim)
        try container.encodeIfPresent(grouping, forKey: .grouping)
    }
}

struct OtzariaMergedSibling: Codable, Hashable, Sendable {
    let title: String
    let reference: String
    let id: UInt64
    let segment: UInt64
    let isPdf: Bool
    let filePath: String
}

struct OtzariaEngineSearchResult: Codable, Hashable, Sendable {
    let title: String
    let reference: String
    let text: String
    let id: UInt64
    let segment: UInt64
    let isPdf: Bool
    let filePath: String
    let mergedCount: UInt32
    let merged: [OtzariaMergedSibling]
}

struct OtzariaSearchPage: Codable, Sendable {
    let totalCount: UInt32
    let groupCount: UInt32?
    let truncated: Bool
    let results: [OtzariaEngineSearchResult]
}

struct OtzariaBookCounts: Codable, Sendable {
    let counts: [String: UInt32]
    let truncated: Bool
}

struct OtzariaFacetCount: Codable, Sendable {
    let path: String
    let count: UInt64
}

struct OtzariaFacetCounts: Codable, Sendable {
    let counts: [OtzariaFacetCount]
    let truncated: Bool
}

enum OtzariaSemanticRetrievalMode: String, Codable, CaseIterable, Sendable {
    case hybrid
    case semanticOnly
    case lexicalOnly
}

enum OtzariaSemanticLexicalMode: String, Codable, CaseIterable, Sendable {
    case exact
    case fuzzy
}

struct OtzariaSemanticStatus: Codable, Sendable {
    let enabled: Bool
    let available: Bool
    let modelLoaded: Bool
    let indexedBookCount: UInt32
    let vectorCount: UInt32
    let modelId: String
    let embeddingDim: UInt32
    let embeddingBackend: String?
    let vectorBackend: String
    let vectorsPersisted: Bool
    let needsFullReindex: String?
    let lastError: String?
}

struct OtzariaSemanticDiff: Codable, Sendable {
    let enabled: Bool
    let newBooks: [String]
    let changedBooks: [String]
    let unverifiableBooks: [String]
    let removedBooks: [String]
    let modelMismatch: Bool
    let chunkingMismatch: Bool
    let normalizationMismatch: Bool
}

struct OtzariaSemanticMutationResult: Codable, Sendable {
    let enabled: Bool
    let vectorsRemoved: UInt32
}

struct OtzariaSemanticIndexResult: Codable, Sendable {
    let enabled: Bool
    let booksIndexed: UInt32
    let booksSkipped: UInt32
    let booksEmpty: UInt32
    let chunksWritten: UInt32
}

struct OtzariaSemanticLineInput: Codable, Sendable {
    let lineId: UInt64
    let sectionId: UInt64
    let text: String
    let lineHash: UInt64
    let reference: String
    let segment: UInt64
}

struct OtzariaSemanticBookInput: Codable, Sendable {
    let sourceBookKey: String
    let title: String
    let contentFingerprint: UInt64
    let isPdf: Bool
    let topics: String
    let extraFacets: [String]
    let lines: [OtzariaSemanticLineInput]
}

struct OtzariaSemanticSearchRequest: Encodable, Sendable {
    let operation = "search"
    var query: String
    var facets: [String] = ["/"]
    var limit: UInt32 = 100
    var offset: UInt32 = 0
    var lexicalMode: OtzariaSemanticLexicalMode = .exact
    var fuzzyMaxDistance: UInt8 = 0
    var retrievalMode: OtzariaSemanticRetrievalMode = .hybrid
    var grouping: OtzariaResultGrouping?
    var matchNikud = false
    var matchTaamim = false
}

struct OtzariaSemanticSearchResult: Codable, Sendable {
    let title: String
    let reference: String
    let text: String
    let isHighlighted: Bool
    let id: UInt64
    let segment: UInt64
    let isPdf: Bool
    let filePath: String
    let mergedCount: UInt32
    let merged: [OtzariaMergedSibling]
    let lexicalScore: Double?
    let semanticScore: Double?
    let fusedScore: Double
    let source: String
    let needsHydration: Bool
}

struct OtzariaSemanticSearchResponse: Codable, Sendable {
    let results: [OtzariaSemanticSearchResult]
    let totalCount: UInt32
    let lexicalTotalCount: UInt32
    let groupCount: UInt32?
    let countsAreExact: Bool
    let requestedMode: String
    let executedMode: String
    let semanticAvailable: Bool
    let fallbackReason: String?
    let latencyMs: UInt64
    let candidateWindowTruncated: Bool
    let truncated: Bool
}

struct OtzariaEngineResponse<T: Decodable>: Decodable {
    let ok: Bool
    let value: T?
    let error: String?
}

struct OtzariaIndexCompatibility: Codable, Equatable, Sendable {
    let compatible: Bool
    let status: String
    let foundSchemaVersion: UInt32?
    let requiredSchemaVersion: UInt32
    let engineVersion: String
    let metadataPath: String
    let reason: String?

    var requiresRebuild: Bool {
        status == "rebuild_required" || status == "engine_too_old"
    }
}

struct OtzariaSearchEngineBuildInfo: Codable, Equatable, Sendable {
    let upstreamRepository: String
    let upstreamBranch: String
    let upstreamCommit: String
    let engineVersion: String
    let indexSchemaVersion: UInt32
    let defaultGenerationOrder: UInt32
    let semanticEnabled: Bool
    let semanticSidecarRevision: String
    let syncedAt: String
    let adapterVersion: String
    let resourceHashes: [String: String]
}

struct OtzariaBookIndexInput: Codable, Sendable {
    let title: String
    let topics: String
    let filePath: String
    let catalogueOrder: UInt32
    let generationOrder: UInt32
    let text: String?
    let textBase64: String?
    let extraFacets: [String]?
}

struct OtzariaPDFPageInput: Codable, Sendable {
    let reference: String
    let text: String
    let pageIndex: UInt32
}

struct OtzariaPDFBookIndexInput: Codable, Sendable {
    let title: String
    let topics: String
    let filePath: String
    let catalogueOrder: UInt32
    let generationOrder: UInt32
    let pages: [OtzariaPDFPageInput]
    let extraFacets: [String]?
}

struct OtzariaIndexFingerprint: Codable, Equatable, Sendable {
    let databasePath: String
    let fileSize: UInt64
    let modificationTime: TimeInterval
}

struct OtzariaSemanticArtifactIdentity: Codable, Equatable, Sendable {
    let modelID: String
    let modelSHA256: String
    let corpusIdentity: String
    let sidecarRevision: String
    let embeddingDimension: UInt32
}

struct OtzariaIndexBuildIdentity: Codable, Equatable, Sendable {
    let database: OtzariaIndexFingerprint
    let upstreamCommit: String
    let engineVersion: String
    let indexSchemaVersion: UInt32
    let defaultGenerationOrder: UInt32
    let adapterVersion: String
    let resourceHashes: [String: String]
    let catalogueHash: String
    let semanticArtifactIdentity: OtzariaSemanticArtifactIdentity?
}

struct OtzariaIndexCheckpoint: Codable, Equatable, Sendable {
    let identity: OtzariaIndexBuildIdentity
    let lastCatalogueOrdinal: Int
    let lastSourceKey: String
    let committedBooks: Int
    let totalBooks: Int
    let committedDocuments: Int
    let committedBytes: UInt64
    let timestamp: Date
    let upstreamCommit: String
    let batchSequence: Int
    let quarantinedBooks: [OtzariaBookFailureRecord]
}

enum OtzariaBookFailureClassification: String, Codable, Equatable, Sendable {
    case pdfPasswordProtected
    case pdfPermission
    case pdfUnsupported
    case pdfTimeout
    case pdfCorrupt
    case invalidBookInput
}

struct OtzariaBookFailureRecord: Codable, Equatable, Sendable {
    let sourceKey: String
    let sourceIdentity: String
    let bookId: Int
    let title: String
    let catalogueOrdinal: Int
    let classification: OtzariaBookFailureClassification
    let message: String
    let failedAt: Date
}

struct OtzariaBookFailureLedger: Codable, Equatable, Sendable {
    var records: [OtzariaBookFailureRecord]
}

struct OtzariaPDFFreshnessManifest: Codable, Equatable, Sendable {
    var sourceIdentities: [String: String]
}

struct OtzariaRecoverableBookFailure: Error, LocalizedError, Sendable {
    let record: OtzariaBookFailureRecord

    var errorDescription: String? {
        "Book \(record.bookId) was quarantined as \(record.classification.rawValue): \(record.message)"
    }
}

struct OtzariaIndexedBookRecord: Codable, Equatable, Sendable {
    let bookId: Int
    let title: String
    let totalLines: Int
    let indexedLines: Int
}

struct OtzariaIndexedBooksManifest: Codable, Equatable, Sendable {
    var databasePath: String
    var indexVersion: String
    var books: [OtzariaIndexedBookRecord]
}

enum OtzariaSearchIndexStatus: Equatable, Sendable {
    case unavailable
    case notBuilt
    case ready(documentCount: UInt64)
    case rebuildRequired(String)
    case building(processedBooks: Int, totalBooks: Int, processedLines: Int)
    case paused(processedBooks: Int, totalBooks: Int)
    case finalizing
    case failed(String)

    var label: String {
        switch self {
        case .unavailable: return "לא נבחר מסד אוצריא"
        case .notBuilt: return "האינדקס עדיין לא נבנה"
        case .ready(let count): return "האינדקס מוכן (\(count) מסמכים)"
        case .rebuildRequired(let reason): return "נדרשת בנייה מחדש: \(reason)"
        case .building(let books, let total, let lines): return "מאנדקס \(books)/\(total) ספרים · \(lines) שורות"
        case .paused(let books, let total): return "האינדוקס הופסק — ניתן להמשיך מ־\(books)/\(total)"
        case .finalizing: return "מסיים ומאמת את האינדקס…"
        case .failed(let message): return "שגיאת אינדוקס: \(message)"
        }
    }
}

enum OtzariaSearchError: Error, LocalizedError {
    case databaseNotSelected
    case engineNotAvailable
    case invalidEngineResponse(String)
    case indexingCancelled
    case insufficientStorage(requiredBytes: UInt64, availableBytes: UInt64)

    var errorDescription: String? {
        switch self {
        case .databaseNotSelected: return "לא נבחר seforim.db של אוצריא."
        case .engineNotAvailable: return "מנוע החיפוש של אוצריא לא נטען. ודא שה־XCFramework נוסף ל־target."
        case .invalidEngineResponse(let message): return message
        case .insufficientStorage(let required, let available):
            return "Insufficient storage for the Otzaria index build (required \(required) bytes, available \(available) bytes)."
        case .indexingCancelled: return "האינדוקס הופסק; ההתקדמות המחויבת נשמרה."
        }
    }
}
