import Foundation

enum SefariaJSONValue: Codable, Hashable, Sendable {
    case string(String), array([SefariaJSONValue]), object([String: SefariaJSONValue])
    case number(Double), bool(Bool), null

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() { self = .null }
        else if let result = try? value.decode(String.self) { self = .string(result) }
        else if let result = try? value.decode([SefariaJSONValue].self) { self = .array(result) }
        else if let result = try? value.decode([String: SefariaJSONValue].self) { self = .object(result) }
        else if let result = try? value.decode(Bool.self) { self = .bool(result) }
        else if let result = try? value.decode(Double.self) { self = .number(result) }
        else { throw DecodingError.dataCorruptedError(in: value, debugDescription: "Unsupported JSON value") }
    }

    func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case .string(let result): try value.encode(result)
        case .array(let result): try value.encode(result)
        case .object(let result): try value.encode(result)
        case .number(let result): try value.encode(result)
        case .bool(let result): try value.encode(result)
        case .null: try value.encodeNil()
        }
    }

    var flattenedStrings: [String] {
        switch self {
        case .string(let value): return [value]
        case .array(let values): return values.flatMap(\.flattenedStrings)
        default: return []
        }
    }
}

struct SefariaVersion: Codable, Hashable, Sendable {
    let versionTitle: String
    let language: String
    let actualLanguage: String?
    let versionSource: String?
    let license: String?
    let versionNotes: String?
    let priority: Double?
    let isPrimary: Bool?
    let isSource: Bool?
    let direction: String?
    let text: SefariaJSONValue?
}

struct SefariaSection: Codable, Hashable, Sendable {
    let ref: String
    let heRef: String?
    let sectionRef: String
    let indexTitle: String
    let next: String?
    let prev: String?
    let versions: [SefariaVersion]
    let linksBySegment: [[SefariaLink]]
    let origin: LibraryTextSection.Origin

    func asLibrarySection() -> LibraryTextSection {
        let source = versions.first(where: { $0.isSource == true || $0.language == "he" })
            ?? versions.first(where: { $0.language == "he" }) ?? versions.first
        let translation = versions.first {
            ($0.versionTitle != source?.versionTitle || $0.language != source?.language)
                && ($0.language == "en" || $0.isSource != true)
        }
        let primary = source?.text?.flattenedStrings ?? []
        let translated = translation?.text?.flattenedStrings ?? []
        let count = max(primary.count, translated.count)
        let segments = (0..<count).map { index in
            let segmentRef = count == 1 ? sectionRef : SefariaRef.segmentRef(sectionRef: sectionRef, offset: index + 1)
            return LibraryTextSegment(
                locator: TextLocator(backend: .sefaria, workKey: indexTitle, position: .canonicalRef(segmentRef)),
                heRef: nil,
                primaryText: index < primary.count ? primary[index] : "",
                translation: index < translated.count ? translated[index] : nil
            )
        }
        let locator = TextLocator(backend: .sefaria, workKey: indexTitle, position: .canonicalRef(sectionRef))
        return LibraryTextSection(
            locator: locator,
            displayRef: ref,
            heRef: heRef,
            segments: segments,
            previous: prev.map { TextLocator(backend: .sefaria, workKey: indexTitle, position: .canonicalRef($0)) },
            next: next.map { TextLocator(backend: .sefaria, workKey: indexTitle, position: .canonicalRef($0)) },
            versions: versions.map(\.metadata),
            links: linksBySegment.flatMap { $0 }.map(\.libraryLink),
            origin: origin
        )
    }
}

extension SefariaVersion {
    var metadata: TextVersionMetadata {
        TextVersionMetadata(
            title: versionTitle,
            language: language,
            actualLanguage: actualLanguage,
            sourceURL: versionSource.flatMap(URL.init(string:)),
            license: license,
            notes: versionNotes,
            isPrimary: isPrimary == true || isSource == true
        )
    }
}

struct SefariaLink: Codable, Hashable, Sendable {
    let ref: String?
    let heRef: String?
    let category: String?
    let type: String?
    let anchorRef: String?
    let sourceRef: String?
}

extension SefariaLink {
    var libraryLink: LibraryTextLink {
        .init(ref: ref, heRef: heRef, category: category, type: type,
            anchorRef: anchorRef, sourceRef: sourceRef)
    }
}

enum SefariaRef {
    static func canonicalInput(_ input: String) -> String {
        var value = input.removingPercentEncoding ?? input
        value = value.replacingOccurrences(of: "_", with: " ")
        if let firstSectionDot = value.range(of: #"\.(?=\d)"#, options: .regularExpression) {
            value.replaceSubrange(firstSectionDot, with: " ")
            let suffix = firstSectionDot.lowerBound..<value.endIndex
            value = value.replacingOccurrences(of: ".", with: ":", options: [], range: suffix)
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    static func segmentRef(sectionRef: String, offset: Int) -> String {
        if sectionRef.range(of: #"\d[ab]$"#, options: .regularExpression) != nil {
            return "\(sectionRef):\(offset)"
        }
        return sectionRef.contains(":") ? "\(sectionRef):\(offset)" : "\(sectionRef):\(offset)"
    }

    static func workKey(from canonicalRef: String, knownTitles: [String]) -> String? {
        knownTitles.filter { canonicalRef == $0 || canonicalRef.hasPrefix($0 + " ") }
            .max(by: { $0.count < $1.count })
    }

    static func talmudAddress(offset: Int) -> String {
        "\(offset / 2 + 2)\(offset.isMultiple(of: 2) ? "a" : "b")"
    }
}
