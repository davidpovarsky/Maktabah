import Foundation

/// Error types for annotation bridging and locator validation.
public enum AnnotationBridgeError: Error, Equatable, LocalizedError {
    case missingLocator
    case emptyWorkKey
    case missingContentPosition
    case invalidRange(location: Int, length: Int, sourceLength: Int)
    case persistenceFailed(String)

    public var errorDescription: String? {
        switch self {
        case .missingLocator:
            return "Target TextLocator is missing; cannot bind annotation to backend."
        case .emptyWorkKey:
            return "TextLocator workKey is empty; invalid canonical book identity."
        case .missingContentPosition:
            return "Content position is missing; whole-book annotations without position are not permitted."
        case .invalidRange(let loc, let len, let srcLen):
            return "Annotation range [\(loc)..<\(loc + len)] is invalid for source length \(srcLen)."
        case .persistenceFailed(let msg):
            return "Failed to persist annotation: \(msg)"
        }
    }
}

/// Lightweight record representing an annotation persisted through the backend adapter.
public struct PersistedAnnotationRecord: Equatable, Sendable {
    public let id: String
    public let locatorPersistenceKey: String
    public let range: NSRange
    public let selectedText: String
    public let colorHex: String
    public let createdAt: Date

    public init(
        id: String,
        locatorPersistenceKey: String,
        range: NSRange,
        selectedText: String,
        colorHex: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.locatorPersistenceKey = locatorPersistenceKey
        self.range = range
        self.selectedText = selectedText
        self.colorHex = colorHex
        self.createdAt = createdAt
    }
}

/// Interface for downstream annotation persistence adapters.
protocol AnnotationPersistenceAdapter: Sendable {
    func persistAnnotation(
        locator: TextLocator,
        range: NSRange,
        text: String,
        colorHex: String
    ) throws -> PersistedAnnotationRecord

    func fetchAnnotations(for locator: TextLocator) throws -> [PersistedAnnotationRecord]
}

/// Thread-safe in-memory adapter FOR UNIT TESTING ONLY.
final class InMemoryAnnotationPersistenceAdapter: AnnotationPersistenceAdapter, @unchecked Sendable {
    private let lock = NSLock()
    private var records: [String: [PersistedAnnotationRecord]] = [:]

    init() {}

    func persistAnnotation(
        locator: TextLocator,
        range: NSRange,
        text: String,
        colorHex: String
    ) throws -> PersistedAnnotationRecord {
        lock.lock()
        defer { lock.unlock() }

        let record = PersistedAnnotationRecord(
            id: UUID().uuidString,
            locatorPersistenceKey: locator.persistenceKey,
            range: range,
            selectedText: text,
            colorHex: colorHex
        )
        records[locator.persistenceKey, default: []].append(record)
        return record
    }

    func fetchAnnotations(for locator: TextLocator) throws -> [PersistedAnnotationRecord] {
        lock.lock()
        defer { lock.unlock() }
        return records[locator.persistenceKey] ?? []
    }
}

/// Downstream adapter bridging backend text locators with Maktabah annotations.
/// Isolates multi-backend (Otzaria, Sefaria, Zayit) locator binding from upstream reader view models.
/// P3-3: Prohibits fabricated default line 0; requires exact canonical position.
final class BackendAnnotationBridge: Sendable {
    static let shared = BackendAnnotationBridge()

    private init() {}

    /// Resolves canonical backend text locator for a book and page offset.
    /// P3-3: Prohibits fabricated positions (e.g. contentId ?? 0); requires valid contentId.
    func resolveLocator(
        bookId: Int,
        workKey: String?,
        backendID: String,
        contentId: Int?
    ) throws -> TextLocator {
        guard let backend = BackendID(rawValue: backendID) else {
            throw AnnotationBridgeError.missingLocator
        }
        guard let contentId else {
            throw AnnotationBridgeError.missingContentPosition
        }
        let resolvedWork: String
        if let workKey, !workKey.trimmingCharacters(in: .whitespaces).isEmpty {
            resolvedWork = workKey
        } else {
            resolvedWork = "book:\(bookId)"
        }
        return TextLocator(
            backend: backend,
            workKey: resolvedWork,
            position: .legacyLine(contentId)
        )
    }

    /// Validates an annotation target before persistence, checking both range bounds AND locator identity.
    func validateTarget(
        range: NSRange,
        sourceLength: Int,
        locator: TextLocator?
    ) throws {
        guard let locator else {
            throw AnnotationBridgeError.missingLocator
        }
        guard !locator.workKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw AnnotationBridgeError.emptyWorkKey
        }
        guard range.location != NSNotFound, range.location >= 0, range.length > 0 else {
            throw AnnotationBridgeError.invalidRange(location: range.location, length: range.length, sourceLength: sourceLength)
        }
        guard Int.max - range.location >= range.length, range.location + range.length <= sourceLength else {
            throw AnnotationBridgeError.invalidRange(location: range.location, length: range.length, sourceLength: sourceLength)
        }
    }
}
