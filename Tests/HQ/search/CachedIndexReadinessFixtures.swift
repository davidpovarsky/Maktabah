import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(ucrt)
import ucrt
#endif
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
    static var countEntered: DispatchSemaphore?
    static var releaseCount: DispatchSemaphore?
    init(indexURL: URL) throws { Self.constructions += 1 }
    func close() {}
    func countExactTokenOccurrences(request: OtzariaExactOccurrenceRequest,
                                    expectedSource: OtzariaExactOccurrenceSource) async throws -> OtzariaExactOccurrenceResult {
        throw OtzariaExactOccurrenceError.engineUnavailable // unused boundary double; no FFI count claim
    }
    func configureDictionaries(magic: URL?, translation: URL?, acronyms: URL?) throws -> [String: Bool] {
        ["translation": true, "acronyms": true]
    }
    func documentCount() throws -> UInt64 {
        Self.countEntered?.signal()
        Self.releaseCount?.wait()
        return 125
    }
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
    static var failures = 0
    static func check(_ value: Bool, _ message: String) {
        assertions += 1
        if !value { failures += 1; print("FAIL assertion \(assertions): \(message)") }
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
        let originalResource = repository.resourceObservation(databasePath: database.path)
        check(repository.observedOpenIndexDocumentCount(databasePath: database.path) == nil, "unopened index must be unknown")
        check(OtzariaSearchEngineBridge.constructions == 0, "readiness must never construct a writer-capable engine")
        // Bundle resources are supplied by the runner beside this executable.
        _ = try repository.engine(databasePath: database.path)
        check(repository.observedOpenIndexDocumentCount(databasePath: database.path) == 125, "matching live cached count is observed")
        let constructions = OtzariaSearchEngineBridge.constructions
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        OtzariaSearchEngineBridge.countEntered = entered
        OtzariaSearchEngineBridge.releaseCount = release
        let countFinished = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            _ = repository.observedOpenIndexDocumentCount(databasePath: database.path)
            countFinished.signal()
        }
        let began = entered.wait(timeout: .now() + 2) == .success
        let witnessFinished = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            _ = repository.resourceObservation(databasePath: database.path)
            witnessFinished.signal()
        }
        let observedWithoutQueryLock = witnessFinished.wait(timeout: .now() + 2) == .success
        release.signal()
        _ = countFinished.wait(timeout: .now() + 2)
        OtzariaSearchEngineBridge.countEntered = nil; OtzariaSearchEngineBridge.releaseCount = nil
        check(began && observedWithoutQueryLock, "source witness must remain observable while FFI holds the repository query lock")
        try Data("replacement-index".utf8).write(to: meta)
        check(repository.observedOpenIndexDocumentCount(databasePath: database.path) == nil, "replaced index metadata revokes cache evidence")
        check(OtzariaSearchEngineBridge.constructions == constructions, "readiness must not silently reopen after replacement")
        repository.invalidate(databasePath: database.path)
        let invalidatedResource = repository.resourceObservation(databasePath: database.path)
        check(invalidatedResource.revision > originalResource.revision, "source invalidation advances the true publication revision")
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
        let beforeABA = repository.resourceObservation(databasePath: database.path)
        repository.invalidate(databasePath: database.path)
        repository.invalidate(databasePath: database.path)
        let afterABA = repository.resourceObservation(databasePath: database.path)
        check(afterABA.revision > beforeABA.revision && afterABA.fingerprint == beforeABA.fingerprint,
            "A-to-B-to-A invalidation remains observable even when final disk bytes are identical")
        // Original/custom cache discovery keeps working without installation
        // manifests, while each existing original manifest is a raw witness.
        let indexManifest = root.appendingPathComponent("otzaria_prebuilt_installation.json")
        let databaseManifest = root.appendingPathComponent("seforim-installation.json")
        _ = try repository.engine(databasePath: database.path)
        let withoutManifests = repository.resourceObservation(databasePath: database.path)
        check(repository.observedOpenIndexDocumentCount(databasePath: database.path) == 125,
              "optional manifest absence preserves ordinary/custom cache readiness")
        try Data("{\"index\":1}".utf8).write(to: indexManifest)
        let withIndex = repository.resourceObservation(databasePath: database.path)
        check(withIndex.fingerprint != withoutManifests.fingerprint &&
              repository.observedOpenIndexDocumentCount(databasePath: database.path) == nil,
              "adding the original index manifest revokes the old raw stamp")
        repository.invalidate(databasePath: database.path)
        _ = try repository.engine(databasePath: database.path)
        check(repository.observedOpenIndexDocumentCount(databasePath: database.path) == 125,
              "explicit reopen can observe the newly installed index manifest")
        try Data("{\"database\":1}".utf8).write(to: databaseManifest)
        let withBoth = repository.resourceObservation(databasePath: database.path)
        check(withBoth.fingerprint != withIndex.fingerprint &&
              repository.observedOpenIndexDocumentCount(databasePath: database.path) == nil,
              "adding the original adjacent DB manifest revokes the old stamp")
        repository.invalidate(databasePath: database.path)
        _ = try repository.engine(databasePath: database.path)
        check(repository.observedOpenIndexDocumentCount(databasePath: database.path) == 125,
              "both unchanged manifests permit an ordinary cached observation")
        try Data("{\"database\":2}".utf8).write(to: databaseManifest)
        check(repository.resourceObservation(databasePath: database.path).fingerprint != withBoth.fingerprint &&
              repository.observedOpenIndexDocumentCount(databasePath: database.path) == nil,
              "same-sized manifest replacement changes raw fingerprint and revokes cached evidence")
        repository.invalidate(databasePath: database.path)
        _ = try repository.engine(databasePath: database.path)
        try FileManager.default.removeItem(at: indexManifest)
        check(repository.observedOpenIndexDocumentCount(databasePath: database.path) == nil,
              "removing a previously observed manifest revokes its cached stamp")
        repository.invalidate(databasePath: database.path)
        _ = try repository.engine(databasePath: database.path)
        try FileManager.default.removeItem(at: databaseManifest)
        check(repository.observedOpenIndexDocumentCount(databasePath: database.path) == nil,
              "removing the adjacent DB manifest also revokes its cached stamp")
        repository.invalidate(databasePath: database.path)
        _ = try repository.engine(databasePath: database.path)
        check(repository.observedOpenIndexDocumentCount(databasePath: database.path) == 125,
              "explicit original reopen restores custom readiness with both optional manifests absent")
        try Data(repeating: 120, count: 1_048_577).write(to: indexManifest)
        check(repository.resourceObservation(databasePath: database.path).fingerprint == nil &&
              repository.observedOpenIndexDocumentCount(databasePath: database.path) == nil,
              "existing oversized optional metadata fails closed rather than becoming absent")
        try FileManager.default.removeItem(at: indexManifest)
        check(repository.resourceObservation(databasePath: database.path).fingerprint == withoutManifests.fingerprint &&
              repository.observedOpenIndexDocumentCount(databasePath: database.path) == 125,
              "removing only the owned oversized fixture restores the unchanged optional-nil stamp")
        repository.closeAllEngines()
        print("RESULT: \(assertions - failures) PASS \(failures) FAIL; \(assertions) real-repository cached readiness assertions; FFI/storage dependencies are doubles")
        if failures > 0 { exit(1) }
    }
}
