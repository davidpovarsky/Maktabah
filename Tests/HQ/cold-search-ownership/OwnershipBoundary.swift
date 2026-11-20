import Foundation
import CryptoKit

// Explicit app boundaries for this standalone Foundation fixture. The whole
// repository, whole Swift C bridge, models and occurrence operation are original
// source. No real Tantivy engine, corpus, SQLite DB or UI is substituted as proof.
final class OwnershipBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value
    init(_ value: Value) { self.value = value }
    func read() -> Value { lock.withLock { value } }
    func update(_ body: (inout Value) -> Void) { lock.withLock { body(&value) } }
}

enum OwnershipEnvironment {
    static let root = URL(fileURLWithPath: ProcessInfo.processInfo.environment["COLD_OWNERSHIP_ROOT"]!)
    static let current = OwnershipBox((directory: root, profile: "fixture"))
    static func begin(_ name: String) throws {
        let directory = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        current.update { $0 = (directory, "fixture") }
    }
}

enum OwnershipFixtureEvidence {
    static let sourceSetup = OwnershipBox<[[String: String]]>([])
    static let refusals = OwnershipBox<[[String: String]]>([])
}

enum ITorahSharedContainer {
    static var otzariaRootURL: URL { OwnershipEnvironment.current.read().directory.appendingPathComponent("Shared") }
}
enum OtzariaDataProfileRegistry {
    static var activeProfileID: String { OwnershipEnvironment.current.read().profile }
}
final class OtzariaSearchIndexManager: @unchecked Sendable {
    static let shared = OtzariaSearchIndexManager()
    func indexURL(for databasePath: String) -> URL {
        URL(fileURLWithPath: databasePath).deletingLastPathComponent().appendingPathComponent("Index")
    }
    func identityURL(indexURL: URL) -> URL { indexURL.appendingPathComponent("identity.json") }
    func sentinelURL(for databasePath: String) -> URL { indexURL(for: databasePath).appendingPathExtension("sentinel") }
    func buildingIndexURL(for databasePath: String) -> URL { indexURL(for: databasePath).appendingPathExtension("building") }
    func currentFingerprint(databasePath: String) throws -> OtzariaIndexFingerprint {
        let attributes = try FileManager.default.attributesOfItem(atPath: databasePath)
        return .init(databasePath: databasePath,
                     fileSize: (attributes[.size] as! NSNumber).uint64Value,
                     modificationTime: (attributes[.modificationDate] as! Date).timeIntervalSince1970)
    }
}
final class OtzariaMagicDictionaryManager: @unchecked Sendable {
    static let shared = OtzariaMagicDictionaryManager()
    var validatedDatabaseURL: URL? { nil }
}
enum OtzariaIndexFileLogger { static func log(_ message: String) {} }
struct TextLocator {
    enum Backend { case otzaria }
    enum Position { case legacyLine(Int) }
    let backend: Backend
    let workKey: String
    let position: Position
}
struct SearchResultItem {
    let archive: String
    let tableName: String
    let bookId: Int
    let bookTitle: String
    let page: Int
    let part: Int
    let attributedText: NSAttributedString
    let backendLocator: TextLocator
    let locationDisplayText: String?
    let highlightTerms: [String]?
    let backendHitID: String
}

// The generator inserts only the exact original generationSnapshot and
// candidate tryGenerationSnapshot bodies here. Fixture-only scheduling methods
// use that same NSRecursiveLock, reproducing the documented original
// bridge -> migration ordering without pretending to open an SQLite database.
final class OwnershipBridgeProbe: @unchecked Sendable {
    private let lock = NSRecursiveLock()
    private(set) var dbGeneration: UInt64 = 1
    // ORIGINAL_GENERATION_METHODS
    func advance() { lock.withLock { dbGeneration &+= 1 } }
    func withOwner(_ work: () -> Void) { lock.withLock(work) }
}

@_silgen_name("cold_fixture_reset") private func nativeReset()
@_silgen_name("cold_fixture_set_compatibility") private func nativeCompatibility(_ value: Int32)
@_silgen_name("cold_fixture_set_count") private func nativeCount(_ value: UInt64)
@_silgen_name("cold_fixture_set_configuration") private func nativeConfiguration(_ value: Int32)
@_silgen_name("cold_fixture_set_constructor_failure") private func nativeConstructorFailure(_ value: Int32)
@_silgen_name("cold_fixture_stats") private func nativeStats(_ output: UnsafeMutablePointer<UInt64>)

enum OwnershipNativeDouble {
    static let afterConstructor = OwnershipBox<(@Sendable () -> Void)?>(nil)
    static func reset() { afterConstructor.update { $0 = nil }; nativeReset() }
    static func compatibility(_ value: Int32) { nativeCompatibility(value) }
    static func count(_ value: UInt64) { nativeCount(value) }
    static func configuration(_ value: Bool) { nativeConfiguration(value ? 1 : 0) }
    static func constructorFailure(_ value: Bool) { nativeConstructorFailure(value ? 1 : 0) }
    static func stats() -> (constructors: UInt64, closes: UInt64, counts: UInt64, dictionaries: UInt64, compatibilities: UInt64) {
        var values = [UInt64](repeating: 0, count: 5)
        values.withUnsafeMutableBufferPointer { nativeStats($0.baseAddress!) }
        return (values[0], values[1], values[2], values[3], values[4])
    }
}
@_cdecl("cold_fixture_after_constructor")
func coldFixtureAfterConstructor() { OwnershipNativeDouble.afterConstructor.read()?() }

struct OwnershipSource: Sendable {
    let database: String
    let index: URL
    let profile: String
    let revision: UInt64
    let fingerprint: Data
    let sidecar: Data
    let hashes: [String: String]
    let bridge: OwnershipBridgeProbe
    let generation: UInt64

    static func make(_ name: String) throws -> OwnershipSource {
        let repository = OtzariaTantivySearchRepository.shared
        repository.closeAllEngines()
        OwnershipNativeDouble.reset()
        try OwnershipEnvironment.begin(name)
        let directory = OwnershipEnvironment.current.read().directory
        let database = directory.appendingPathComponent("seforim.db")
        // This is an explicit metadata-only file double, not an SQLite fixture.
        try Data("metadata-only-db-double".utf8).write(to: database)
        let beforeCreation = directory.appendingPathComponent("Index")
        try FileManager.default.createDirectory(at: beforeCreation, withIntermediateDirectories: true)
        // The original repository requires exact manager URL identity. Ask the
        // fixture's same manager after the directory exists, while retaining
        // the implicit pre-creation URL as evidence of the first-run boundary.
        let index = OtzariaSearchIndexManager.shared.indexURL(for: database.path)
        try require(beforeCreation.standardizedFileURL.path == index.standardizedFileURL.path,
                    "fixture_manager_changed_index_path")
        OwnershipFixtureEvidence.sourceSetup.update { rows in
            rows.append(["caseSetup": name, "beforeCreationURL": beforeCreation.absoluteString,
                         "managerExistingURL": index.absoluteString,
                         "beforeCreationHasDirectoryPath": String(beforeCreation.hasDirectoryPath),
                         "managerHasDirectoryPath": String(index.hasDirectoryPath),
                         "originalExactURLEquality": String(beforeCreation == index)])
        }
        let sidecar = Data("{\"fixture\":\"native-compatibility-double\"}".utf8)
        for (name, bytes) in [("meta.json", Data("{\"fixture\":\"tantivy-metadata-double\"}".utf8)),
                              ("identity.json", Data("{\"fixture\":\"identity-double\"}".utf8)),
                              ("otzaria_index_meta.json", sidecar),
                              ("otzaria_prebuilt_installation.json", Data("{}".utf8))] {
            try bytes.write(to: index.appendingPathComponent(name))
        }
        try Data("{}".utf8).write(to: directory.appendingPathComponent("seforim-installation.json"))
        let observation = repository.resourceObservation(databasePath: database.path)
        guard let fingerprint = observation.fingerprint else { throw OwnershipFailure("missing_initial_observation") }
        var hashes: [String: String] = [:]
        for name in ["dictionary", "Acronyms"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
                throw OwnershipFailure("missing_fixture_bundle_resource")
            }
            hashes["Vendor/OtzariaSearchEngine/Resources/" + name + ".json"] =
                SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
        }
        let bridge = OwnershipBridgeProbe()
        return .init(database: database.path, index: index, profile: "fixture", revision: observation.revision,
                     fingerprint: fingerprint, sidecar: sidecar, hashes: hashes,
                     bridge: bridge, generation: bridge.generationSnapshot())
    }

    func validate() throws {
        guard let observed = bridge.tryGenerationSnapshot() else { throw OtzariaSearchExecutionPreparationError.sourceBusy }
        guard observed == generation else { throw OtzariaSearchExecutionPreparationError.sourceChanged }
    }
    func prepare(milliseconds: UInt64 = 1500, expectedRevision: UInt64? = nil,
                 hashes supplied: [String: String]? = nil,
                 validate: (@Sendable () throws -> Void)? = nil) async throws {
        try await OtzariaTantivySearchRepository.shared.prepareExistingSearchExecution(
            databasePath: database, profileID: profile, expectedIndexURL: index,
            expectedRevision: expectedRevision ?? revision, expectedFingerprint: fingerprint,
            expectedIndexMetadata: sidecar, expectedDocumentCount: 17,
            requiredResourceHashes: supplied ?? hashes,
            deadlineUptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + milliseconds * 1_000_000,
            validateSource: validate ?? { try self.validate() })
    }
    func requireNoOpenOrPublication() throws {
        let stats = OwnershipNativeDouble.stats()
        try require(stats.constructors == 0 && stats.dictionaries == 0 && stats.counts == 0, "unexpected_native_engine_side_effect")
        try require(OtzariaTantivySearchRepository.shared.observedOpenIndexDocumentCount(databasePath: database) == nil,
                    "unexpected_cache_publication")
    }
}

struct OwnershipFailure: Error { let code: String; init(_ code: String) { self.code = code } }
func require(_ condition: @autoclosure () throws -> Bool, _ code: String) throws {
    if try condition() == false { throw OwnershipFailure(code) }
}

final class OwnershipHeldLock: @unchecked Sendable {
    let entered = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    let completed = DispatchSemaphore(value: 0)
    init(storage name: String) throws {
        DispatchQueue.global().async { [self] in
            ITorahStorageLock.withLock(name: name) {
                entered.signal()
                _ = release.wait(timeout: .now() + 5)
            }
            completed.signal()
        }
        try require(entered.wait(timeout: .now() + 2) == .success, "storage_holder_did_not_start")
    }
    init(owner: OwnershipBridgeProbe) throws {
        DispatchQueue.global().async { [self] in
            owner.withOwner { entered.signal(); _ = release.wait(timeout: .now() + 5) }
            completed.signal()
        }
        try require(entered.wait(timeout: .now() + 2) == .success, "bridge_holder_did_not_start")
    }
    init(repository: OtzariaTantivySearchRepository) throws {
        DispatchQueue.global().async { [self] in
            repository.occurrenceTestWithCacheLock { entered.signal(); _ = release.wait(timeout: .now() + 5) }
            completed.signal()
        }
        try require(entered.wait(timeout: .now() + 2) == .success, "cache_holder_did_not_start")
    }
    func finish() throws {
        release.signal()
        try require(completed.wait(timeout: .now() + 2) == .success, "holder_did_not_release")
    }
}
