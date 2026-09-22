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
    static let workMetadata = Self(rawValue: 1 << 9)
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

/// A canonical reader destination: load the section, optionally focus on a
/// specific segment within it.  Used by TOC, search-hit-to-reader routing,
/// and history restoration.
struct LibraryReaderDestination: Codable, Hashable, Sendable {
    /// The section to load (e.g., "Genesis 1" or a reading-unit locator).
    let sectionLocator: TextLocator
    /// An optional segment within the section to highlight/scroll to
    /// (e.g., "Genesis 1:3" or a specific line index).
    let focusLocator: TextLocator?
}

/// A navigable unit within a work, supplied by the backend provider.
/// The bottom-bar navigator uses these to show a picker/stepper of
/// chapters, folios, or reading-units instead of the legacy part/page sliders.
struct LibraryNavigationItem: Codable, Hashable, Identifiable, Sendable {
    let locator: TextLocator
    let title: String
    let index: Int

    var id: String { locator.persistenceKey }
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

struct LibraryNavigationStructure: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let title: String
    let nodes: [LibraryTOCNode]
}

struct LibraryMetadataField: Codable, Hashable, Identifiable, Sendable {
    let key: String
    let label: String
    let value: String

    var id: String { key }

    init(key: String, label: String, value: String) {
        self.key = key
        self.label = label
        self.value = value
    }
}

struct LibraryWorkMetadata: Codable, Hashable, Sendable {
    let workKey: String
    let title: String
    let heTitle: String?
    let authors: [String]
    let description: String?
    let categories: [String]
    let factualFields: [LibraryMetadataField]

    init(
        workKey: String,
        title: String,
        heTitle: String? = nil,
        authors: [String] = [],
        description: String? = nil,
        categories: [String] = [],
        factualFields: [LibraryMetadataField] = []
    ) {
        self.workKey = workKey
        self.title = title
        self.heTitle = heTitle
        self.authors = authors
        self.description = description
        self.categories = categories
        self.factualFields = factualFields
    }
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

enum LibraryPresentationPolicy {
    static func prefersHebrew(localeIdentifier: String? = Locale.preferredLanguages.first) -> Bool {
        guard let language = localeIdentifier?.lowercased() else { return false }
        return language.hasPrefix("he") || language.hasPrefix("iw")
    }

    static func defaultReaderMode(localeIdentifier: String? = Locale.preferredLanguages.first) -> LibraryReaderTextMode {
        prefersHebrew(localeIdentifier: localeIdentifier) ? .source : .translation
    }

    static func text(
        source: String,
        translation: String?,
        mode: LibraryReaderTextMode
    ) -> String {
        let source = source.readerPlainText
        let translation = translation?.readerPlainText ?? ""
        switch mode {
        case .source:
            return source.isEmpty ? translation : source
        case .translation:
            return translation.isEmpty ? source : translation
        case .both:
            return [source, translation].filter { !$0.isEmpty }.joined(separator: "\n")
        }
    }
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

public struct TextDeltaEvent: Codable, Hashable, Sendable {
    public let oldOffset: Int
    public let delta: Int

    public init(oldOffset: Int, delta: Int) {
        self.oldOffset = oldOffset
        self.delta = delta
    }

    public static func mapRange(_ range: NSRange, with events: [TextDeltaEvent]) -> NSRange {
        guard !events.isEmpty else { return range }
        var locDelta = 0
        for event in events {
            if range.location >= event.oldOffset {
                locDelta = event.delta
            } else {
                break
            }
        }
        let newLocation = range.location + locDelta

        var endDelta = 0
        let rangeEnd = range.location + range.length
        for event in events {
            if rangeEnd >= event.oldOffset {
                endDelta = event.delta
            } else {
                break
            }
        }
        let newEnd = rangeEnd + endDelta
        let newLength = max(0, newEnd - newLocation)
        return NSRange(location: max(0, newLocation), length: newLength)
    }

    public static func reverseMapOffset(_ displayedOffset: Int, with events: [TextDeltaEvent]) -> Int {
        var currentDelta = 0
        for event in events {
            let newPoint = event.oldOffset + event.delta
            if displayedOffset < newPoint {
                let oldPoint = event.oldOffset + currentDelta
                if displayedOffset >= oldPoint {
                    return max(0, event.oldOffset - 1)
                }
                break
            }
            currentDelta = event.delta
        }
        return max(0, displayedOffset - currentDelta)
    }
}

struct LibraryRenderedSegment: Codable, Hashable, Identifiable, Sendable {
    let rangeLocation: Int
    let rangeLength: Int
    let visualRangeLocation: Int
    let visualRangeLength: Int
    let segment: LibraryTextSegment

    var id: String { segment.id }
    var range: NSRange { NSRange(location: rangeLocation, length: rangeLength) }
    var visualRange: NSRange { NSRange(location: visualRangeLocation, length: visualRangeLength) }
    var locator: TextLocator { segment.locator }

    init(
        rangeLocation: Int,
        rangeLength: Int,
        visualRangeLocation: Int? = nil,
        visualRangeLength: Int? = nil,
        segment: LibraryTextSegment
    ) {
        self.rangeLocation = rangeLocation
        self.rangeLength = rangeLength
        self.visualRangeLocation = visualRangeLocation ?? rangeLocation
        self.visualRangeLength = visualRangeLength ?? rangeLength
        self.segment = segment
    }

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
            let fullLength = (block as NSString).length
            let blockNSString = block as NSString
            var leadTrim = 0
            while leadTrim < fullLength {
                let unichar = blockNSString.character(at: leadTrim)
                if unichar == 0x202A || unichar == 0x202B || unichar == 0x202C {
                    leadTrim += 1
                } else {
                    break
                }
            }
            var trailTrim = 0
            while (fullLength - trailTrim - 1) >= leadTrim {
                let unichar = blockNSString.character(at: fullLength - trailTrim - 1)
                if unichar == 0x202A || unichar == 0x202B || unichar == 0x202C {
                    trailTrim += 1
                } else {
                    break
                }
            }
            let visualLocation = location + leadTrim
            let visualLength = max(0, fullLength - leadTrim - trailTrim)

            mappings.append(LibraryRenderedSegment(
                rangeLocation: location,
                rangeLength: fullLength,
                visualRangeLocation: visualLocation,
                visualRangeLength: visualLength,
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
            .replacingOccurrences(of: "&thinsp;", with: "\u{2009}")
            .replacingOccurrences(of: "&#8201;", with: "\u{2009}")
            .replacingOccurrences(of: "&ensp;", with: "\u{2002}")
            .replacingOccurrences(of: "&emsp;", with: "\u{2003}")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
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
    var options = LibrarySearchOptions()
}

enum LibrarySearchMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case phrase
    case contains
    case or
    case near

    var id: Self { self }
}

enum LibrarySearchMatchMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case exact
    case hebrewLemmatized

    var id: Self { self }
}

enum LibrarySearchSortOrder: String, Codable, CaseIterable, Identifiable, Sendable {
    case relevance
    case canonical
    case chronological

    var id: Self { self }
}

struct LibrarySearchOptions: Codable, Hashable, Sendable {
    var searchMode: LibrarySearchMode = .phrase
    var matchMode: LibrarySearchMatchMode = .hebrewLemmatized
    var wordDistance: Int = 10
    var sortOrder: LibrarySearchSortOrder = .relevance
    var reverseSort = false
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

/// Encapsulates generic backend pagination continuation state, truthful monotonic totals,
/// and protection against non-advancing offset loops.
public struct BackendPaginationState: Sendable, Equatable {
    public private(set) var nextOffset: Int?
    public private(set) var totalResults: Int
    public private(set) var loadedCount: Int
    public private(set) var lastCommittedOffset: Int?

    public var lastRequestedOffset: Int? { lastCommittedOffset }

    public init(
        nextOffset: Int? = nil,
        totalResults: Int = 0,
        loadedCount: Int = 0,
        lastCommittedOffset: Int? = nil
    ) {
        self.nextOffset = nextOffset
        self.totalResults = totalResults
        self.loadedCount = loadedCount
        self.lastCommittedOffset = lastCommittedOffset
    }

    /// `nextOffset` is the authoritative continuation signal, validated against non-advancing loops.
    public var hasMore: Bool {
        guard let next = nextOffset, next > 0 else { return false }
        if let last = lastCommittedOffset, next <= last { return false }
        return true
    }

    /// Resets state for a new search generation.
    public mutating func reset() {
        nextOffset = nil
        totalResults = 0
        loadedCount = 0
        lastCommittedOffset = nil
    }

    /// Applies the first page of results from the backend.
    public mutating func applyInitialPage(pageTotal: Int, nextOffset: Int?, count: Int) {
        self.lastCommittedOffset = 0
        self.loadedCount = count
        if let next = nextOffset, next > 0 {
            self.nextOffset = next
        } else {
            self.nextOffset = nil
        }
        let lowerBound = count + (self.nextOffset != nil ? 1 : 0)
        self.totalResults = max(pageTotal, lowerBound)
    }

    /// Applies a subsequent page of results from the backend, validating continuation against the requested offset.
    public mutating func applyNextPage(requestedOffset: Int, pageTotal: Int, nextOffset: Int?, count: Int) {
        self.lastCommittedOffset = requestedOffset
        self.loadedCount += count

        // Loop protection: if the backend returned a non-advancing offset, terminate safely.
        if let next = nextOffset, next > requestedOffset {
            self.nextOffset = next
        } else {
            self.nextOffset = nil
        }

        // Monotonic total: totals never shrink on later pages, and lower bound respects loaded count.
        let lowerBound = self.loadedCount + (self.nextOffset != nil ? 1 : 0)
        self.totalResults = max(self.totalResults, max(pageTotal, lowerBound))
    }

    public mutating func applyNextPage(pageTotal: Int, nextOffset: Int?, count: Int) {
        let req = self.nextOffset ?? 0
        applyNextPage(requestedOffset: req, pageTotal: pageTotal, nextOffset: nextOffset, count: count)
    }
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
