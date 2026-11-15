import Foundation
protocol CopyableResult { func formatForClipboard() -> String }
extension String { func convertToArabicDigits() -> String { self } }
extension NSAttributedString {
    func archivedData() -> Data { Data(string.utf8) }
    static func unarchiveSecure(from data: Data) -> NSAttributedString? {
        NSAttributedString(string: String(decoding: data, as: UTF8.self))
    }
}

// Only filesystem/FFI dependencies are doubles. The entire production
// OtzariaTantivySearchRepository compiles unchanged in this focused invocation.
enum OtzariaDataProfileRegistry { static var activeProfileID = "fixture-profile" }
final class OtzariaSearchIndexManager {
    static let shared = OtzariaSearchIndexManager()
    var root = FileManager.default.temporaryDirectory
    func indexURL(for databasePath: String) -> URL { root }
    func identityURL(indexURL: URL) -> URL { indexURL.appendingPathComponent("identity.json") }
    func currentFingerprint(databasePath: String) throws -> OtzariaIndexFingerprint {
        let values = try FileManager.default.attributesOfItem(atPath: databasePath)
        return .init(databasePath: databasePath, fileSize: (values[.size] as! NSNumber).uint64Value,
            modificationTime: (values[.modificationDate] as! Date).timeIntervalSince1970)
    }
}
final class OtzariaSearchEngineBridge {
    static var constructions = 0
    init(indexURL: URL) throws { Self.constructions += 1 }
    func close() {}
    func configureDictionaries(magic: URL?, translation: URL?, acronyms: URL?) throws -> [String: Bool] {
        ["translation": true, "acronyms": true]
    }
    func documentCount() throws -> UInt64 { 125 }
    func search(_ request: OtzariaSearchRequest) throws -> OtzariaSearchPage { fatalError("not used") }
}
final class OtzariaMagicDictionaryManager {
    static let shared = OtzariaMagicDictionaryManager()
    var validatedDatabaseURL: URL? { nil }
}
enum OtzariaIndexFileLogger { static func log(_ value: String) {} }
enum OtzariaSearchSnippetRenderer { static func plainText(fromHTML value: String) -> String { value } }

@main struct CachedIndexReadinessFixtures {
    static var assertions = 0
    static func check(_ value: Bool, _ message: String) {
        assertions += 1
        if !value { fatalError(message) }
    }
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let database = root.appendingPathComponent("fixture.db")
        try Data("fixture-db".utf8).write(to: database)
        let manager = OtzariaSearchIndexManager.shared
        manager.root = root
        let meta = root.appendingPathComponent("meta.json")
        try Data("first-index".utf8).write(to: meta)
        let identity = manager.identityURL(indexURL: root)
        try Data("identity".utf8).write(to: identity)
        let repository = OtzariaTantivySearchRepository.shared
        check(repository.observedOpenIndexDocumentCount(databasePath: database.path) == nil, "unopened index must be unknown")
        check(OtzariaSearchEngineBridge.constructions == 0, "readiness must never construct a writer-capable engine")
        // Bundle resources are supplied by the runner beside this executable.
        _ = try repository.engine(databasePath: database.path)
        check(repository.observedOpenIndexDocumentCount(databasePath: database.path) == 125, "matching live cached count is observed")
        let constructions = OtzariaSearchEngineBridge.constructions
        try Data("replacement-index".utf8).write(to: meta)
        check(repository.observedOpenIndexDocumentCount(databasePath: database.path) == nil, "replaced index metadata revokes cache evidence")
        check(OtzariaSearchEngineBridge.constructions == constructions, "readiness must not silently reopen after replacement")
        repository.invalidate(databasePath: database.path)
        _ = try repository.engine(databasePath: database.path)
        check(repository.observedOpenIndexDocumentCount(databasePath: database.path) == 125, "explicit ordinary engine reopen can establish new evidence")
        OtzariaDataProfileRegistry.activeProfileID = "different-profile"
        check(repository.observedOpenIndexDocumentCount(databasePath: database.path) == nil, "profile switch invalidates old evidence")
        OtzariaDataProfileRegistry.activeProfileID = "fixture-profile"
        try Data("changed-identity".utf8).write(to: identity)
        check(repository.observedOpenIndexDocumentCount(databasePath: database.path) == nil, "identity replacement revokes evidence")
        repository.invalidate(databasePath: database.path)
        _ = try repository.engine(databasePath: database.path)
        try Data("changed-database-content".utf8).write(to: database)
        check(repository.observedOpenIndexDocumentCount(databasePath: database.path) == nil, "database replacement revokes evidence")
        repository.beginExclusiveIndexing(databasePath: database.path)
        check(repository.observedOpenIndexDocumentCount(databasePath: database.path) == nil, "indexing cannot advertise cached readiness")
        repository.endExclusiveIndexing(databasePath: database.path)
        repository.closeAllEngines()
        check(repository.observedOpenIndexDocumentCount(databasePath: database.path) == nil, "close all revokes all observations")
        print("PASS: \(assertions) real-repository cached readiness assertions; FFI/storage dependencies are doubles")
    }
}
