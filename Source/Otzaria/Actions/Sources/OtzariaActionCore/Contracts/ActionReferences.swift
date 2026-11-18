import Foundation

public struct ActionWorkRef: Codable, Sendable, Equatable, Hashable {
    public let backend: ActionBackendID
    public let workKey: String
    public let catalogRevision: String?
    public init(backend: ActionBackendID, workKey: String, catalogRevision: String? = nil) {
        self.backend = backend; self.workKey = workKey; self.catalogRevision = catalogRevision
    }
}

/// Wire shape stays {kind,value}; it is not the app's persistence encoding.
public enum ActionTextPosition: Codable, Sendable, Equatable, Hashable {
    case legacyLine(Int64), canonicalRef(String)
    private enum Keys: String, CodingKey { case kind, value }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        switch try c.decode(String.self, forKey: .kind) {
        case "legacyLine":
            let value = try c.decode(ActionJSON.self, forKey: .value)
            guard let index = value.integer, index >= 0 else { throw ActionContractError.invalid("position.value") }
            self = .legacyLine(index)
        case "canonicalRef":
            let value = try c.decode(String.self, forKey: .value)
            guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ActionContractError.invalid("position.value") }
            self = .canonicalRef(value)
        default: throw ActionContractError.invalid("position.kind")
        }
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .legacyLine(let value): try c.encode("legacyLine", forKey: .kind); try c.encode(value, forKey: .value)
        case .canonicalRef(let value): try c.encode("canonicalRef", forKey: .kind); try c.encode(value, forKey: .value)
        }
    }
}

public struct ActionTextRef: Codable, Sendable, Equatable, Hashable {
    public let backend: ActionBackendID
    public let workKey: String
    public let catalogRevision: String?
    public let position: ActionTextPosition
    public let dataRevision: String?
    public init(backend: ActionBackendID, workKey: String, position: ActionTextPosition, catalogRevision: String? = nil, dataRevision: String? = nil) {
        self.backend = backend; self.workKey = workKey; self.position = position
        self.catalogRevision = catalogRevision; self.dataRevision = dataRevision
    }
}

public struct ActionReaderDestination: Codable, Sendable, Equatable {
    public let sectionLocator: ActionTextRef
    public let focusLocator: ActionTextRef?
    public let presentationMode: PresentationMode
    public enum PresentationMode: String, Codable, Sendable { case sameTab, newTab }
    public init(sectionLocator: ActionTextRef, focusLocator: ActionTextRef? = nil, presentationMode: PresentationMode = .sameTab) {
        self.sectionLocator = sectionLocator; self.focusLocator = focusLocator; self.presentationMode = presentationMode
    }
}

public struct ActionResolveWorkQuery: Sendable, Equatable {
    public let backend: ActionBackendID
    public let query: String?
    public let workRef: ActionWorkRef?
    public let limit: Int
    public init(backend: ActionBackendID, query: String? = nil, workRef: ActionWorkRef? = nil, limit: Int = 25) {
        self.backend = backend; self.query = query; self.workRef = workRef; self.limit = limit
    }
}
public struct ActionResolveReferenceQuery: Sendable, Equatable {
    public let backend: ActionBackendID
    public let text: String?
    public let workRef: ActionWorkRef?
    public let section: String?
    public init(backend: ActionBackendID, text: String? = nil, workRef: ActionWorkRef? = nil, section: String? = nil) {
        self.backend = backend; self.text = text; self.workRef = workRef; self.section = section
    }
}
public enum ActionResolution<Value: Sendable & Equatable>: Sendable, Equatable {
    case unique(Value), ambiguous([ActionCandidate]), notFound
}

/// Source-owned aliases and provenance; the resolver never turns trimming into proof.
public struct ActionCatalogEntry: Sendable, Equatable {
    public let workRef: ActionWorkRef
    public let title: String
    public let aliases: [String]
    public let kind: ActionCandidate.Kind
    public let provenance: String
    public init(workRef: ActionWorkRef, title: String, aliases: [String] = [], kind: ActionCandidate.Kind = .work, provenance: String) {
        self.workRef = workRef; self.title = title; self.aliases = aliases; self.kind = kind; self.provenance = provenance
    }
}


/// A section title and locator read from the selected work's original TOC.
/// This is source data, not an existence proof or a navigation grant.
public struct ActionSourceSectionEntry: Sendable, Equatable {
    public let locator: ActionTextRef
    public let title: String
    public init(locator: ActionTextRef, title: String) {
        self.locator = locator; self.title = title
    }
}

/// The same conservative name normalization used by the canonical catalog
/// resolver. No transliteration, numerical conversion or inferred references.
enum ActionSourceName {
    static func normalize(_ value: String, field: String) throws -> String {
        guard !value.isEmpty, value.utf8.count <= 512 * 8, value.count <= 512,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !value.unicodeScalars.contains(where: {
                  CharacterSet.controlCharacters.contains($0) && !CharacterSet.whitespacesAndNewlines.contains($0)
              }) else { throw ActionContractError.invalid(field) }
        let quoted = value.precomposedStringWithCanonicalMapping.map { character -> Character in
            switch character {
            case "\u{05f3}", "\u{2018}", "\u{2019}": return "'"
            case "\u{05f4}", "\u{201c}", "\u{201d}": return "\""
            default: return character
            }
        }
        return String(quoted).split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}
