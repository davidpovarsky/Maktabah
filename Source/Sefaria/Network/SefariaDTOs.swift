import Foundation

struct SefariaTextsV3DTO: Codable, Sendable {
    let versions: [SefariaVersion]
    let ref: String
    let heRef: String?
    let sectionRef: String
    let next: String?
    let prev: String?
    let indexTitle: String
}

struct SefariaNameDTO: Decodable, Sendable {
    let isRef: Bool?
    let ref: String?
    let completions: [String]?

    enum CodingKeys: String, CodingKey { case isRef = "is_ref", ref, completions }
}

struct SefariaTOCEntryDTO: Codable, Sendable {
    let category: String?
    let heCategory: String?
    let title: String?
    let heTitle: String?
    let contents: [SefariaTOCEntryDTO]

    enum CodingKeys: String, CodingKey { case category, heCategory, title, heTitle, contents }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        category = try values.decodeIfPresent(String.self, forKey: .category)
        heCategory = try values.decodeIfPresent(String.self, forKey: .heCategory)
        title = try values.decodeIfPresent(String.self, forKey: .title)
        heTitle = try values.decodeIfPresent(String.self, forKey: .heTitle)
        contents = try values.decodeIfPresent([Self].self, forKey: .contents) ?? []
    }
}

struct SefariaSearchBody: Encodable, Sendable {
    let query: String
    let type = "text"
    let field = "naive_lemmatizer"
    let start: Int
    let size: Int
    let sortType = "relevance"
    let exact = false
    let appliedFilters: [String] = []
    let appliedFilterAggTypes: [String] = []
    let aggregationsToUpdate: [String] = []

    enum CodingKeys: String, CodingKey {
        case query, type, field, start, size, exact
        case sortType = "sort_type"
        case appliedFilters = "applied_filters"
        case appliedFilterAggTypes, aggregationsToUpdate
    }
}

struct SefariaSearchResponseDTO: Decodable, Sendable {
    struct Hits: Decodable, Sendable {
        struct Total: Decodable, Sendable {
            let value: Int
            init(from decoder: Decoder) throws {
                let value = try decoder.singleValueContainer()
                if let integer = try? value.decode(Int.self) { self.value = integer }
                else { self.value = try value.decode([String: Int].self)["value"] ?? 0 }
            }
        }
        let total: Total
        let hits: [Hit]
    }
    struct Hit: Decodable, Sendable {
        struct Source: Decodable, Sendable {
            let ref: String
            let heRef: String?
            let title: String?
            let version: String?
            let lang: String?
            let content: String?
        }
        let score: Double?
        let source: Source
        let highlight: [String: [String]]?
        enum CodingKeys: String, CodingKey { case score = "_score", source = "_source", highlight }
    }
    let hits: Hits
}

struct SefariaRelatedDTO: Decodable, Sendable {
    let links: [SefariaLink]
}

struct SefariaIndexDTO: Decodable, Sendable {
    let title: String
    let categories: [String]
    let schema: SefariaJSONValue
}
