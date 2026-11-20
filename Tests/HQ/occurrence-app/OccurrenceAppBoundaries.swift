import Foundation

// Explicit app-shell boundaries only. The complete original AccessController,
// Repository, Swift bridge, Core DTOs, artifact policy and SQLite connection
// compile as production bytes. No count, engine, registry or hash is injected.
final class OccurrenceAppEnvironment: @unchecked Sendable {
    static let shared = OccurrenceAppEnvironment()
    private let lock = NSLock()
    private var configuredRoot: URL?
    func configure(root: URL) {
        lock.withLock {
            precondition(configuredRoot == nil || configuredRoot == root)
            configuredRoot = root
        }
    }
    var root: URL {
        lock.withLock {
            guard let configuredRoot else { preconditionFailure("Owned fixture root not configured") }
            return configuredRoot
        }
    }
}

struct OtzariaDatabaseStorage {
    let finalDatabaseURL: URL
    let installationManifestURL: URL
    init(profileID: String = OtzariaDataProfileRegistry.activeProfileID) throws {
        guard profileID == OtzariaDataProfileRegistry.miniTest10ID else {
            throw OccurrenceAppFailure(description: "Fixture storage accepts only original miniTest10")
        }
        let root = OccurrenceAppEnvironment.shared.root
        finalDatabaseURL = root.appendingPathComponent("seforim.db")
        installationManifestURL = root.appendingPathComponent("seforim-installation.json")
    }
}

final class OtzariaMaktabahBridge: @unchecked Sendable {
    static let shared = OtzariaMaktabahBridge()
    private let lock = NSLock()
    private var generation: UInt64 = 1
    var databasePath: String? { OtzariaDatabaseAccessController.shared.currentURL?.path }
    func generationSnapshot() -> UInt64 { lock.withLock { generation } }
    func occurrenceFixtureAdvanceGeneration() { lock.withLock { generation &+= 1 } }
}

final class OtzariaSearchIndexManager: @unchecked Sendable {
    static let shared = OtzariaSearchIndexManager()
    func indexURL(for databasePath: String) -> URL {
        URL(fileURLWithPath: databasePath).deletingLastPathComponent().appendingPathComponent("index")
    }
    func identityURL(indexURL: URL) -> URL {
        indexURL.appendingPathComponent("otzaria_search_identity.json")
    }
    func currentFingerprint(databasePath: String) throws -> OtzariaIndexFingerprint {
        let attributes = try FileManager.default.attributesOfItem(atPath: databasePath)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber,
              let date = attributes[.modificationDate] as? Date else {
            throw OccurrenceAppFailure(description: "Fixture fingerprint requires actual regular file metadata")
        }
        return .init(databasePath: databasePath, fileSize: size.uint64Value,
                     modificationTime: date.timeIntervalSince1970)
    }
}

final class OtzariaMagicDictionaryManager: @unchecked Sendable {
    static let shared = OtzariaMagicDictionaryManager()
    // Optional lexical expansion is not used by exact-token postings.
    var validatedDatabaseURL: URL? { nil }
}
enum OtzariaIndexFileLogger { static func log(_ value: String) {} }

// These OS/persistence operations are outside this fixture. Their types permit
// compiling the complete owner, but any accidental operation terminates the run.
struct OtzariaSecurityScopedBookmarkStore {
    var hasBookmark: Bool { fatalError("Bookmark persistence is outside this fixture") }
    func restore() throws -> (url: URL, isStale: Bool)? { fatalError("Unexpected bookmark restore") }
    func save(url: URL) throws { fatalError("Unexpected bookmark save") }
    func forget() { fatalError("Unexpected bookmark removal") }
}
struct OtzariaSecurityScopedAccess {
    static func start(for url: URL) throws -> Self { fatalError("Unexpected security-scoped access") }
    func stop() { fatalError("Unexpected security-scoped stop") }
}
enum ITorahSharedContainer {
    private final class ValidatorStore: @unchecked Sendable {
        let lock = NSLock()
        var value: (@Sendable (URL, String) -> Bool)?
    }
    private static let store = ValidatorStore()
    static var databaseValidator: (@Sendable (URL, String) -> Bool)? {
        get { store.lock.withLock { store.value } }
        set { store.lock.withLock { store.value = newValue } }
    }
    static func migrateLegacyDataIfNeeded() { fatalError("Unexpected persistent migration") }
}
enum ITorahStorageLock {
    static func withLock<T>(name: String, _ body: () throws -> T) rethrows -> T {
        fatalError("Unexpected persistent storage mutation")
    }
}

// Unexecuted UI-rendering shells needed by the whole repository source.
enum OtzariaSearchSnippetRenderer {
    static func plainText(fromHTML value: String) -> String { fatalError("No UI rendering in occurrence fixture") }
}
enum OccurrenceFixtureBackend { case otzaria }
enum OccurrenceFixturePosition { case legacyLine(Int) }
struct TextLocator {
    init(backend: OccurrenceFixtureBackend, workKey: String, position: OccurrenceFixturePosition) {}
}
struct SearchResultItem {
    init(archive: String, tableName: String, bookId: Int, bookTitle: String,
         page: Int, part: Int, attributedText: NSAttributedString,
         backendLocator: TextLocator, locationDisplayText: String?,
         highlightTerms: [String]?, backendHitID: String) {}
}
