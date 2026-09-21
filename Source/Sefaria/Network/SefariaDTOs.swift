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
    let field: String
    let start: Int
    let size: Int
    let slop: Int
    let sortMethod: String
    let sortFields: [String]
    let sortReverse: Bool
    let sortScoreMissing = 0.04
    let sourceProjection = true
    let filters: [String]
    let filterFields: [String]
    let aggregations: [String] = []

    init(
        query: String,
        start: Int,
        size: Int,
        filters: [String] = [],
        options: LibrarySearchOptions = LibrarySearchOptions()
    ) {
        self.query = query
        self.start = start
        self.size = size
        let containsHebrew = query.unicodeScalars.contains { (0x0590...0x05FF).contains(Int($0.value)) }
        field = options.matchMode == .hebrewLemmatized && containsHebrew
            ? "naive_lemmatizer"
            : "exact"
        slop = max(0, options.wordDistance)
        switch options.sortOrder {
        case .relevance:
            sortMethod = "score"
            sortFields = ["pagesheetrank"]
        case .canonical:
            sortMethod = "sort"
            sortFields = ["order"]
        case .chronological:
            sortMethod = "sort"
            sortFields = ["comp_date"]
        }
        sortReverse = options.reverseSort
        self.filters = filters
        self.filterFields = Array(repeating: "path", count: filters.count)
    }

    enum CodingKeys: String, CodingKey {
        case query, type, field, start, size, slop, filters
        case sortMethod = "sort_method"
        case sortFields = "sort_fields"
        case sortReverse = "sort_reverse"
        case sortScoreMissing = "sort_score_missing"
        case sourceProjection = "source_proj"
        case filterFields = "filter_fields"
        case aggregations = "aggs"
    }
}

struct SefariaSearchResponseDTO: Decodable, Sendable {
    struct Hits: Decodable, Sendable {
        struct Total: Decodable, Sendable {
            let value: Int

            enum CodingKeys: String, CodingKey {
                case value
            }

            init(from decoder: Decoder) throws {
                if let single = try? decoder.singleValueContainer(),
                   let integer = try? single.decode(Int.self) {
                    self.value = integer
                    return
                }
                if let container = try? decoder.container(keyedBy: CodingKeys.self),
                   let integer = try? container.decodeIfPresent(Int.self, forKey: .value) {
                    self.value = integer
                    return
                }
                self.value = 0
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
            let exact: String?
            let naiveLemmatizer: String?

            enum CodingKeys: String, CodingKey {
                case ref, heRef, title, version, lang, content, exact
                case naiveLemmatizer = "naive_lemmatizer"
            }
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

/// Flexible string field that tolerates String, [], or [String] from the Sefaria /api/links/ API.
private enum SefariaFlexString: Decodable, Hashable, Sendable {
    case string(String)
    case none

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = value.isEmpty ? .none : .string(value)
            return
        }
        if let array = try? container.decode([String].self) {
            let nonEmpty = array.filter { !$0.isEmpty }
            self = nonEmpty.isEmpty ? .none : .string(nonEmpty.joined(separator: "\n"))
            return
        }
        self = .none
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }
}

struct SefariaRelationshipLinkDTO: Hashable, Sendable {
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

    private enum CodingKeys: String, CodingKey {
        case sourceRef, sourceHeRef, ref, heRef, category, type, collectiveTitle
        case he, text, versionTitle, heVersionTitle, heLicense, license
        case indexTitle = "index_title"
        case indexTitleCamel = "indexTitle"
    }
}

extension SefariaRelationshipLinkDTO: Decodable {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        sourceRef = try values.decodeIfPresent(String.self, forKey: .sourceRef)
        sourceHeRef = try values.decodeIfPresent(String.self, forKey: .sourceHeRef)
        ref = try values.decodeIfPresent(String.self, forKey: .ref)
        heRef = try values.decodeIfPresent(String.self, forKey: .heRef)
        category = try values.decodeIfPresent(String.self, forKey: .category)
        type = try values.decodeIfPresent(String.self, forKey: .type)
        collectiveTitle = try values.decodeIfPresent(SefariaLocalizedTitleDTO.self, forKey: .collectiveTitle)
        he = (try values.decodeIfPresent(SefariaFlexString.self, forKey: .he))?.stringValue
        text = (try values.decodeIfPresent(SefariaFlexString.self, forKey: .text))?.stringValue
        versionTitle = try values.decodeIfPresent(String.self, forKey: .versionTitle)
        heVersionTitle = try values.decodeIfPresent(String.self, forKey: .heVersionTitle)
        heLicense = try values.decodeIfPresent(String.self, forKey: .heLicense)
        license = try values.decodeIfPresent(String.self, forKey: .license)
        indexTitle = try values.decodeIfPresent(String.self, forKey: .indexTitle)
            ?? values.decodeIfPresent(String.self, forKey: .indexTitleCamel)
    }
}

struct SefariaTopicDescriptionDTO: Codable, Hashable, Sendable {
    let title: String?
}

struct SefariaRelationshipTopicDTO: Codable, Hashable, Sendable {
    let topic: String?
    let descriptions: [String: SefariaTopicDescriptionDTO]?
    let title: SefariaLocalizedTitleDTO?
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
            let titleHe = row.title?.he?.nonEmpty ?? row.descriptions?["he"]?.title?.nonEmpty
            let titleEn = row.title?.en?.nonEmpty ?? row.descriptions?["en"]?.title?.nonEmpty
            return LibraryRelatedTopic(
                slug: slug,
                titleHe: titleHe,
                titleEn: titleEn
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
    let heTitle: String?
    let categories: [String]
    let heCategories: [String]?
    let schema: SefariaJSONValue
    let alternateStructures: [String: SefariaJSONValue]?
    let authors: SefariaJSONValue?
    let enDesc: String?
    let heDesc: String?
    let compDate: SefariaJSONValue?
    let compPlace: SefariaJSONValue?
    let pubDate: SefariaJSONValue?
    let pubPlace: SefariaJSONValue?
    let era: String?

    enum CodingKeys: String, CodingKey {
        case title, heTitle, categories, heCategories, schema
        case alternateStructures = "alt_structs"
        case authors, enDesc, heDesc, compDate, compPlace, pubDate, pubPlace, era
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        title = try values.decode(String.self, forKey: .title)
        heTitle = try values.decodeIfPresent(String.self, forKey: .heTitle)
        categories = try values.decodeIfPresent([String].self, forKey: .categories) ?? []
        heCategories = try values.decodeIfPresent([String].self, forKey: .heCategories)
        schema = try values.decodeIfPresent(SefariaJSONValue.self, forKey: .schema) ?? .null
        alternateStructures = try values.decodeIfPresent([String: SefariaJSONValue].self, forKey: .alternateStructures)
        authors = try values.decodeIfPresent(SefariaJSONValue.self, forKey: .authors)
        enDesc = try values.decodeIfPresent(String.self, forKey: .enDesc)
        heDesc = try values.decodeIfPresent(String.self, forKey: .heDesc)
        compDate = try values.decodeIfPresent(SefariaJSONValue.self, forKey: .compDate)
        compPlace = try values.decodeIfPresent(SefariaJSONValue.self, forKey: .compPlace)
        pubDate = try values.decodeIfPresent(SefariaJSONValue.self, forKey: .pubDate)
        pubPlace = try values.decodeIfPresent(SefariaJSONValue.self, forKey: .pubPlace)
        era = try values.decodeIfPresent(String.self, forKey: .era)
    }

    init(
        title: String,
        heTitle: String? = nil,
        categories: [String] = [],
        heCategories: [String]? = nil,
        schema: SefariaJSONValue = .null,
        alternateStructures: [String: SefariaJSONValue]? = nil,
        authors: SefariaJSONValue? = nil,
        enDesc: String? = nil,
        heDesc: String? = nil,
        compDate: SefariaJSONValue? = nil,
        compPlace: SefariaJSONValue? = nil,
        pubDate: SefariaJSONValue? = nil,
        pubPlace: SefariaJSONValue? = nil,
        era: String? = nil
    ) {
        self.title = title
        self.heTitle = heTitle
        self.categories = categories
        self.heCategories = heCategories
        self.schema = schema
        self.alternateStructures = alternateStructures
        self.authors = authors
        self.enDesc = enDesc
        self.heDesc = heDesc
        self.compDate = compDate
        self.compPlace = compPlace
        self.pubDate = pubDate
        self.pubPlace = pubPlace
        self.era = era
    }

    func asWorkMetadata(workKey: String) -> LibraryWorkMetadata {
        let authorList = parseAuthors(authors)
        let compDateStr = parseString(compDate)
        let compPlaceStr = parseString(compPlace)
        let pubDateStr = parseString(pubDate)
        let pubPlaceStr = parseString(pubPlace)
        let eraStr = era?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? era : nil

        var fields: [LibraryMetadataField] = []
        if !authorList.isEmpty {
            fields.append(LibraryMetadataField(key: "authors", label: "מחבר", value: authorList.joined(separator: ", ")))
        }
        if !categories.isEmpty {
            fields.append(LibraryMetadataField(key: "categories", label: "קטגוריה", value: categories.joined(separator: " > ")))
        }
        if let compDateStr {
            fields.append(LibraryMetadataField(key: "compDate", label: "זמן חיבור", value: compDateStr))
        }
        if let compPlaceStr {
            fields.append(LibraryMetadataField(key: "compPlace", label: "מקום חיבור", value: compPlaceStr))
        }
        if let pubDateStr {
            fields.append(LibraryMetadataField(key: "pubDate", label: "שנת דפוס", value: pubDateStr))
        }
        if let pubPlaceStr {
            fields.append(LibraryMetadataField(key: "pubPlace", label: "מקום דפוס", value: pubPlaceStr))
        }
        if let eraStr {
            fields.append(LibraryMetadataField(key: "era", label: "תקופה", value: eraStr))
        }

        return LibraryWorkMetadata(
            workKey: workKey,
            title: title,
            heTitle: heTitle,
            authors: authorList,
            description: heDesc ?? enDesc,
            categories: categories,
            factualFields: fields
        )
    }

    private func parseAuthors(_ value: SefariaJSONValue?) -> [String] {
        guard let value = value else { return [] }
        switch value {
        case .string(let s):
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? [] : [trimmed]
        case .array(let items):
            return items.compactMap { item in
                switch item {
                case .string(let s):
                    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
                    return trimmed.isEmpty ? nil : trimmed
                case .object(let dict):
                    if case .string(let he) = dict["he"], !he.isEmpty { return he }
                    if case .string(let en) = dict["en"], !en.isEmpty { return en }
                    if case .string(let name) = dict["name"], !name.isEmpty { return name }
                    return nil
                default:
                    return nil
                }
            }
        default:
            return []
        }
    }

    private func parseString(_ value: SefariaJSONValue?) -> String? {
        guard let value = value else { return nil }
        switch value {
        case .string(let s):
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case .number(let n):
            if n.rounded() == n {
                return String(Int(n))
            } else {
                return String(n)
            }
        case .object(let dict):
            if case .string(let he) = dict["he"], !he.isEmpty { return he }
            if case .string(let en) = dict["en"], !en.isEmpty { return en }
            return nil
        default:
            return nil
        }
    }
}


struct SefariaShapeDTO: Decodable, Sendable {
    let isComplex: Bool?
    let heTitle: String?
    let title: String
    let length: Int?
    let chapters: SefariaJSONValue

    private enum CodingKeys: String, CodingKey {
        case isComplex, heTitle, title, book, section, length, chapters
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        isComplex = try values.decodeIfPresent(Bool.self, forKey: .isComplex)
        heTitle = try values.decodeIfPresent(String.self, forKey: .heTitle)
        title = try values.decodeIfPresent(String.self, forKey: .title)
            ?? values.decodeIfPresent(String.self, forKey: .book)
            ?? values.decodeIfPresent(String.self, forKey: .section)
            ?? ""
        length = try values.decodeIfPresent(Int.self, forKey: .length)
        chapters = try values.decodeIfPresent(SefariaJSONValue.self, forKey: .chapters) ?? .array([])
    }

    init(isComplex: Bool?, heTitle: String?, title: String, length: Int?, chapters: SefariaJSONValue) {
        self.isComplex = isComplex
        self.heTitle = heTitle
        self.title = title
        self.length = length
        self.chapters = chapters
    }
}
