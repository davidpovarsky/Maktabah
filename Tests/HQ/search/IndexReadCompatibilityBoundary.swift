import Foundation

enum FixtureFailure: Error, CustomStringConvertible {
    case failed(String)
    var description: String { switch self { case let .failed(value): return value } }
}
struct OtzariaBookFailureRecord: Codable, Equatable, Sendable {}
enum OtzariaSearchError: Error { case invalidEngineResponse(String) }
enum OtzariaDataProfileRegistry {
    static let productionID = "production"
    nonisolated(unsafe) static var activeProfileID = "miniTest10"
    nonisolated(unsafe) static var activeVersion = 6
    static var activeIdentity: (id: String, version: Int) { (activeProfileID, activeVersion) }
}
enum OtzariaDataProfileCompatibility {
    static func matchesActiveProfile(profileID: String?, profileVersion: Int?) -> Bool {
        (profileID ?? OtzariaDataProfileRegistry.productionID) == OtzariaDataProfileRegistry.activeProfileID
            && (profileVersion ?? 1) == OtzariaDataProfileRegistry.activeVersion
    }
}
struct OtzariaLibraryRelease {
    static let repository = "fixture"
    let id: Int64
    let tag: String
    let asset: Asset
    struct Asset { let id: Int64; let name: String; let compressedSize: Int64; let digest: String? }
}
enum FixtureWorld {
    nonisolated(unsafe) static var root = URL(fileURLWithPath: "unused")
    nonisolated(unsafe) static var build: OtzariaSearchEngineBuildInfo!
    nonisolated(unsafe) static var compatible = true
    nonisolated(unsafe) static var count: UInt64 = 18_879
    nonisolated(unsafe) static var openFails = false
    nonisolated(unsafe) static var finalOpenFails = false
    nonisolated(unsafe) static var countFails = false
    nonisolated(unsafe) static var writes = 0
    nonisolated(unsafe) static var opens = 0
    nonisolated(unsafe) static var closes = 0
    static let rawPart = Data("controlled-original-index-payload".utf8)
}
final class OtzariaDatabaseAccessController: @unchecked Sendable {
    enum Source { case managedInternal, external }
    static let shared = OtzariaDatabaseAccessController()
    var source: Source = .managedInternal
}
struct OtzariaDatabaseStorage {
    var installationManifestURL: URL { FixtureWorld.root.appendingPathComponent("database-installation.json") }
    init() throws {}
}
enum ITorahStorageLock {
    static func withLock<T>(name: String, _ body: () throws -> T) rethrows -> T { try body() }
}
enum OtzariaIndexFileLogger {
    static func log(_ value: String) {}
    static func logError(_ value: String, error: Error) {}
}
struct OtzariaStorageErrorNormalizer {
    static func failure(for error: Error) -> Bool? { nil }
}
final class OtzariaTantivySearchRepository: Sendable {
    static let shared = OtzariaTantivySearchRepository()
    func invalidate(databasePath: String) {}
}
final class OtzariaSearchEngineBridge {
    struct Compatibility { let compatible: Bool; let status: String; let reason: String? }
    static func buildInfo() throws -> OtzariaSearchEngineBuildInfo { FixtureWorld.build }
    static func checkCompatibility(indexURL: URL) throws -> Compatibility {
        .init(compatible: FixtureWorld.compatible, status: "controlled-engine-boundary", reason: nil)
    }
    init(indexURL: URL) throws {
        if FixtureWorld.openFails || (FixtureWorld.finalOpenFails && indexURL.lastPathComponent == "managed-library") {
            throw FixtureFailure.failed("controlled engine open failure")
        }
        FixtureWorld.opens += 1
    }
    func documentCount() throws -> UInt64 {
        if FixtureWorld.countFails { throw FixtureFailure.failed("controlled engine count failure") }
        return FixtureWorld.count
    }
    func close() { FixtureWorld.closes += 1 }
}
struct OtzariaSearchArtifactStorage: Sendable {
    var indexRootURL: URL { OtzariaSearchIndexManager.shared.indexRootURL }
    func stagingURL(databasePath: String) -> URL {
        OtzariaSearchIndexManager.shared.indexURL(for: databasePath).appendingPathExtension("installing")
    }
}
struct OtzariaZstdStreamExtractor: Sendable {
    // Explicit raw-data extractor boundary; no compressed archive is exercised.
    func extractPart(archiveURL: URL, outputURL: URL, expectedOffset: Int64, expectedOutputBytes: Int64,
                     progress: (Int64, Int64) -> Void) throws {
        let data = try Data(contentsOf: archiveURL)
        guard expectedOffset == 0, expectedOutputBytes == data.count else {
            throw FixtureFailure.failed("controlled extraction length mismatch")
        }
        try data.write(to: outputURL)
        progress(Int64(data.count), Int64(data.count))
    }
}

/// Flow tests forward to the complete current production policy. The narrowly
/// qualified registry is compiled unchanged; no candidate-admission override.
enum OtzariaSearchArtifactPolicy {
    static func validate(_ manifest: OtzariaSearchArtifactManifest, database: OtzariaDatabaseInstallationManifest,
                         databaseBytes: Int64, build: OtzariaSearchEngineBuildInfo) throws {
        try SubjectArtifactPolicy.validate(manifest, database: database, databaseBytes: databaseBytes, build: build)
    }
    static func managedIdentityMatchesCanonicalData(_ identity: OtzariaIndexBuildIdentity,
        currentDatabase: OtzariaIndexFingerprint, build: OtzariaSearchEngineBuildInfo,
        trustedManifest: OtzariaSearchArtifactManifest? = nil) -> Bool {
        // Deliberately retains the normal production qualification gate.
        SubjectArtifactPolicy.managedIdentityMatchesCanonicalData(identity, currentDatabase: currentDatabase,
            build: build, trustedManifest: trustedManifest)
    }
    static func validateSafeRelativePath(_ path: String) -> Bool { SubjectArtifactPolicy.validateSafeRelativePath(path) }
    static func artifactProducerIdentity(manifest: OtzariaSearchArtifactManifest, database: OtzariaIndexFingerprint,
        requiredResourceNames: Set<String>) throws -> OtzariaIndexBuildIdentity {
        try SubjectArtifactPolicy.artifactProducerIdentity(manifest: manifest, database: database,
            requiredResourceNames: requiredResourceNames)
    }
}
