import Foundation

enum BackendID: String, Codable, CaseIterable, Identifiable, Sendable {
    case otzaria
    case sefaria

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

struct BackendCapabilities: OptionSet, Codable, Sendable {
    let rawValue: Int

    static let catalog = Self(rawValue: 1 << 0)
    static let reading = Self(rawValue: 1 << 1)
    static let navigation = Self(rawValue: 1 << 2)
    static let search = Self(rawValue: 1 << 3)
    static let authors = Self(rawValue: 1 << 4)
    static let links = Self(rawValue: 1 << 5)
    static let versions = Self(rawValue: 1 << 6)
    static let offlineLibrary = Self(rawValue: 1 << 7)
    static let offlineSearch = Self(rawValue: 1 << 8)
}

enum TextPosition: Codable, Hashable, Sendable {
    case legacyLine(Int)
    case canonicalRef(String)

    private enum CodingKeys: String, CodingKey { case kind, integer, string }
    private enum Kind: String, Codable { case legacyLine, canonicalRef }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        switch try values.decode(Kind.self, forKey: .kind) {
        case .legacyLine: self = .legacyLine(try values.decode(Int.self, forKey: .integer))
        case .canonicalRef: self = .canonicalRef(try values.decode(String.self, forKey: .string))
        }
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .legacyLine(let value):
            try values.encode(Kind.legacyLine, forKey: .kind)
            try values.encode(value, forKey: .integer)
        case .canonicalRef(let value):
            try values.encode(Kind.canonicalRef, forKey: .kind)
            try values.encode(value, forKey: .string)
        }
    }
}

struct TextLocator: Codable, Hashable, Sendable {
    let backend: BackendID
    let workKey: String
    let position: TextPosition

    var persistenceKey: String {
        let positionKey: String
        switch position {
        case .legacyLine(let value): positionKey = "line:\(value)"
        case .canonicalRef(let value): positionKey = "ref:\(value)"
        }
        return "\(backend.rawValue)|\(workKey)|\(positionKey)"
    }
}

struct LibraryWork: Codable, Hashable, Identifiable, Sendable {
    let locator: TextLocator
    let title: String
    let heTitle: String?
    let categories: [String]
    let description: String?

    var id: String { locator.persistenceKey }
}

struct LibraryAuthor: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let biography: String?
}

struct LibraryCatalogNode: Codable, Hashable, Identifiable, Sendable {
    enum Kind: String, Codable, Sendable { case category, work }
    let id: String
    let kind: Kind
    let title: String
    let heTitle: String?
    let work: LibraryWork?
    let children: [LibraryCatalogNode]
}

struct LibraryTOCNode: Codable, Hashable, Identifiable, Sendable {
    let locator: TextLocator
    let title: String
    let children: [LibraryTOCNode]
    var id: String { locator.persistenceKey }
}

struct TextVersionMetadata: Codable, Hashable, Sendable {
    let title: String
    let language: String
    let actualLanguage: String?
    let sourceURL: URL?
    let license: String?
    let notes: String?
    let isPrimary: Bool
}

struct LibraryTextSegment: Codable, Hashable, Identifiable, Sendable {
    let locator: TextLocator
    let heRef: String?
    let primaryText: String
    let translation: String?
    var id: String { locator.persistenceKey }

    /// Backend-neutral name used by the reader. `primaryText` remains encoded for
    /// compatibility with already persisted values.
    var sourceText: String { primaryText }
}

enum LibraryReaderTextMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case source
    case translation
    case both

    var id: String { rawValue }
}

enum LibraryTextDirection: String, Codable, Hashable, Sendable {
    case leftToRight
    case rightToLeft
    case natural

    static func inferred(from language: String?) -> Self {
        switch language?.lowercased() {
        case "he", "hebrew", "ar", "arabic", "arc", "aramaic": .rightToLeft
        case nil, "": .natural
        default: .leftToRight
        }
    }
}

struct LibraryReaderCapabilities: Codable, Hashable, Sendable {
    let availableModes: [LibraryReaderTextMode]
    let sourceDirection: LibraryTextDirection
    let translationDirection: LibraryTextDirection

    var supportsTranslation: Bool { availableModes.contains(.translation) }
}

struct LibraryRenderedSegment: Codable, Hashable, Identifiable, Sendable {
    let rangeLocation: Int
    let rangeLength: Int
    let segment: LibraryTextSegment

    var id: String { segment.id }
    var range: NSRange { NSRange(location: rangeLocation, length: rangeLength) }
    var locator: TextLocator { segment.locator }

    func contains(characterIndex: Int) -> Bool {
        characterIndex >= rangeLocation && characterIndex < rangeLocation + rangeLength
    }
}

/// Immutable reader payload that keeps semantic identity alongside the legacy
/// plain string consumed by Maktabah's existing text view.
struct LibraryReaderRenderModel: Codable, Hashable, Sendable {
    let text: String
    let mode: LibraryReaderTextMode
    let capabilities: LibraryReaderCapabilities
    let renderedSegments: [LibraryRenderedSegment]

    init(section: LibraryTextSection, preferredMode: LibraryReaderTextMode) {
        let hasSource = section.segments.contains { !$0.sourceText.readerPlainText.isEmpty }
        let hasTranslation = section.segments.contains { !($0.translation?.readerPlainText ?? "").isEmpty }
        var modes: [LibraryReaderTextMode] = []
        if hasSource { modes.append(.source) }
        if hasTranslation { modes.append(.translation) }
        if hasSource && hasTranslation { modes.append(.both) }
        if modes.isEmpty { modes = [.source] }

        let resolvedMode = modes.contains(preferredMode) ? preferredMode : (hasSource ? .source : .translation)
        let sourceVersion = section.versions.first(where: { $0.isPrimary })
            ?? section.versions.first(where: { LibraryTextDirection.inferred(from: $0.actualLanguage ?? $0.language) == .rightToLeft })
            ?? section.versions.first
        let translationVersion = section.versions.first(where: { version in
            guard let sourceVersion else { return true }
            return version.title != sourceVersion.title || version.language != sourceVersion.language
        })
        capabilities = LibraryReaderCapabilities(
            availableModes: modes,
            sourceDirection: .inferred(from: sourceVersion?.actualLanguage ?? sourceVersion?.language),
            translationDirection: .inferred(from: translationVersion?.actualLanguage ?? translationVersion?.language)
        )
        mode = resolvedMode

        var output = ""
        var mappings: [LibraryRenderedSegment] = []
        for segment in section.segments {
            let source = segment.sourceText.readerPlainText
            let translation = segment.translation?.readerPlainText ?? ""
            let block: String
            switch resolvedMode {
            case .source:
                block = Self.directional(source, direction: capabilities.sourceDirection)
            case .translation:
                block = Self.directional(translation, direction: capabilities.translationDirection)
            case .both:
                let parts = [
                    Self.directional(source, direction: capabilities.sourceDirection),
                    Self.directional(translation, direction: capabilities.translationDirection)
                ].filter { !$0.isEmpty }
                block = parts.joined(separator: "\n")
            }
            guard !block.isEmpty else { continue }
            if !output.isEmpty { output += "\n\n" }
            let location = (output as NSString).length
            output += block
            mappings.append(LibraryRenderedSegment(
                rangeLocation: location,
                rangeLength: (block as NSString).length,
                segment: segment
            ))
        }
        text = output
        renderedSegments = mappings
    }

    func renderedSegment(at characterIndex: Int) -> LibraryRenderedSegment? {
        renderedSegments.first { $0.contains(characterIndex: characterIndex) }
    }

    func renderedSegment(for locator: TextLocator?) -> LibraryRenderedSegment? {
        guard let locator else { return nil }
        return renderedSegments.first { $0.locator == locator }
    }

    private static func directional(_ value: String, direction: LibraryTextDirection) -> String {
        guard !value.isEmpty else { return "" }
        switch direction {
        case .rightToLeft: return "\u{202B}\(value)\u{202C}"
        case .leftToRight: return "\u{202A}\(value)\u{202C}"
        case .natural: return value
        }
    }
}

extension String {
    var readerPlainText: String {
        replacingOccurrences(of: #"(?i)<br\s*/?>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct LibraryTextLink: Codable, Hashable, Sendable {
    let ref: String?
    let heRef: String?
    let category: String?
    let type: String?
    let anchorRef: String?
    let sourceRef: String?
}

struct LibraryRelatedSource: Codable, Hashable, Identifiable, Sendable {
    let locator: TextLocator
    let displayRef: String
    let heRef: String?
    let category: String
    let type: String
    let collectiveTitle: String?
    let heCollectiveTitle: String?
    let primaryText: String?
    let translation: String?
    let versionTitle: String?
    let heVersionTitle: String?
    let license: String?

    var id: String { "\(locator.persistenceKey)|\(type)|\(category)" }
}

struct LibraryRelatedTopic: Codable, Hashable, Identifiable, Sendable {
    let slug: String
    let titleHe: String?
    let titleEn: String?

    var id: String { slug }
}

struct LibraryTextSection: Codable, Hashable, Sendable {
    enum Origin: String, Codable, Sendable { case offline, remote, diskCache }
    let locator: TextLocator
    let displayRef: String
    let heRef: String?
    let segments: [LibraryTextSegment]
    let previous: TextLocator?
    let next: TextLocator?
    let versions: [TextVersionMetadata]
    let links: [LibraryTextLink]
    let origin: Origin
}

struct LibrarySearchRequest: Codable, Hashable, Sendable {
    let query: String
    let offset: Int
    let limit: Int
    var filters: [String] = []
}

struct LibrarySearchHit: Codable, Hashable, Identifiable, Sendable {
    let locator: TextLocator
    let displayRef: String
    let heRef: String?
    let snippet: String
    let score: Double?
    var id: String { locator.persistenceKey }
}

struct LibrarySearchPage: Codable, Hashable, Sendable {
    let hits: [LibrarySearchHit]
    let total: Int
    let nextOffset: Int?
}

enum LibraryBackendError: LocalizedError, Equatable, Sendable {
    case capabilityUnavailable
    case staleRequest
    case invalidLocator
    case unavailableOffline
    case unsupportedSchema(found: String, supported: [String])
    case invalidResponse(String)
    case httpStatus(Int)
    case corruptData(String)
    case insufficientDiskSpace(required: Int64, available: Int64)

    var errorDescription: String? {
        switch self {
        case .capabilityUnavailable: return "This library source does not provide that capability."
        case .staleRequest: return "The library source changed before the request completed."
        case .invalidLocator: return "The saved text location is invalid."
        case .unavailableOffline: return "This text is not downloaded and the network is unavailable."
        case .unsupportedSchema(let found, let supported):
            return "Sefaria offline schema \(found) requires an app update (supported: \(supported.joined(separator: ", ")))."
        case .invalidResponse(let reason): return "Invalid server response: \(reason)"
        case .httpStatus(let status): return "The server returned HTTP \(status)."
        case .corruptData(let reason): return "Downloaded library data is corrupt: \(reason)"
        case .insufficientDiskSpace(let required, let available):
            return "Not enough free space (requires \(required) bytes; \(available) available)."
        }
    }
}
