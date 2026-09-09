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

struct SefariaLocalizedTitleDTO: Codable, Hashable, Sendable {
    let en: String?
    let he: String?
}

struct SefariaRelationshipLinkDTO: Codable, Hashable, Sendable {
    let sourceRef: String?
    let sourceHeRef: String?
    let ref: String?
    let heRef: String?
    let category: String?
    let type: String?
    let collectiveTitle: SefariaLocalizedTitleDTO?
    let he: String?
    let text: String?
    let versionTitle: String?
    let heVersionTitle: String?
    let heLicense: String?
    let license: String?
    let indexTitle: String?
}

struct SefariaTopicDescriptionDTO: Codable, Hashable, Sendable {
    let title: String?
}

struct SefariaRelationshipTopicDTO: Codable, Hashable, Sendable {
    let topic: String?
    let descriptions: [String: SefariaTopicDescriptionDTO]?
}

enum SefariaRelationshipMapper {
    static func source(
        _ row: SefariaRelationshipLinkDTO,
        knownTitles: Set<String>
    ) -> LibraryRelatedSource? {
        guard let reference = (row.sourceRef ?? row.ref)?.nonEmpty else { return nil }
        let workKey = row.indexTitle?.nonEmpty
            ?? SefariaRef.workKey(from: reference, knownTitles: Array(knownTitles))
            ?? reference
        return LibraryRelatedSource(
            locator: TextLocator(backend: .sefaria, workKey: workKey, position: .canonicalRef(reference)),
            displayRef: reference,
            heRef: (row.sourceHeRef ?? row.heRef)?.nonEmpty,
            category: row.category?.nonEmpty ?? "Other",
            type: row.type?.nonEmpty ?? "link",
            collectiveTitle: row.collectiveTitle?.en?.nonEmpty,
            heCollectiveTitle: row.collectiveTitle?.he?.nonEmpty,
            primaryText: row.he?.nonEmpty,
            translation: row.text?.nonEmpty,
            versionTitle: row.versionTitle?.nonEmpty,
            heVersionTitle: row.heVersionTitle?.nonEmpty,
            license: (row.heLicense ?? row.license)?.nonEmpty
        )
    }

    static func topics(_ rows: [SefariaRelationshipTopicDTO]) -> [LibraryRelatedTopic] {
        var seen = Set<String>()
        return rows.compactMap { row in
            guard let slug = row.topic?.nonEmpty, seen.insert(slug).inserted else { return nil }
            return LibraryRelatedTopic(
                slug: slug,
                titleHe: row.descriptions?["he"]?.title?.nonEmpty,
                titleEn: row.descriptions?["en"]?.title?.nonEmpty
            )
        }
    }
}

private extension String {
    var nonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

struct SefariaIndexDTO: Decodable, Sendable {
    let title: String
    let categories: [String]
    let schema: SefariaJSONValue
}
