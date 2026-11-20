import Foundation
import OtzariaActionCore

struct OccurrenceAppFailure: Error, CustomStringConvertible, Sendable {
    let description: String
}
func requireAppOccurrence(_ condition: Bool, _ message: String) throws {
    if !condition { throw OccurrenceAppFailure(description: message) }
}
func requireAppFailure<T>(_ expected: ActionOccurrenceFailure, _ operation: () throws -> T) throws {
    do {
        _ = try operation()
        throw OccurrenceAppFailure(description: "Unexpected successful value; expected \(expected)")
    } catch let actual as ActionOccurrenceFailure {
        try requireAppOccurrence(actual == expected, "Expected \(expected), received \(actual)")
    }
}
func requireAppAsyncFailure(
    _ expected: ActionOccurrenceFailure,
    _ operation: @escaping @Sendable () async throws -> ActionExactOccurrenceCount
) async throws {
    do {
        _ = try await operation()
        throw OccurrenceAppFailure(description: "Unexpected successful scalar; expected \(expected)")
    } catch let actual as ActionOccurrenceFailure {
        try requireAppOccurrence(actual == expected, "Expected \(expected), received \(actual)")
    }
}
func requireAppNoScalar(_ operation: @escaping @Sendable () async throws -> ActionExactOccurrenceCount) async throws {
    do {
        _ = try await operation()
        throw OccurrenceAppFailure(description: "Unexpected successful scalar")
    } catch is ActionOccurrenceFailure {} catch is ActionPortError {}
}

struct OccurrenceAppCaseRecord: Codable, Sendable {
    let name: String
    let category: String
    let passed: Bool
    let seconds: Double
    let detail: String?
}
struct OccurrenceAppRunner {
    var records: [OccurrenceAppCaseRecord] = []
    mutating func run(_ name: String, category: String, _ operation: @escaping @Sendable () async throws -> Void) async {
        let started = Date()
        do {
            try await operation()
            records.append(.init(name: name, category: category, passed: true,
                                 seconds: Date().timeIntervalSince(started), detail: nil))
            print("PASS \(name)")
        } catch {
            records.append(.init(name: name, category: category, passed: false,
                                 seconds: Date().timeIntervalSince(started), detail: String(describing: error)))
            print("FAIL \(name): \(error)")
        }
    }
}

struct OccurrenceAppDescriptor: Decodable, Sendable {
    let root: String
    let miniManifest: String
    let fullManifest: String
    let sqlOracle: String
    let ownerMarker: String
    let databaseSHA256: String
    let miniManifestSHA256: String
    let sqlOracleSHA256: String
}
struct OccurrenceSQLOracle: Decodable, Sendable {
    struct Count: Decodable, Sendable {
        let occurrences: UInt64
        let matchingLiveDocuments: UInt64
    }
    struct Query: Decodable, Sendable {
        let occurrences: UInt64
        let matchingLiveDocuments: UInt64
        let books: [String: Count]
    }
    let databaseSHA256: String
    let rowsScanned: UInt64
    let allSQLDocuments: UInt64
    let allSQLSources: Int
    let bookIds: [UInt64]
    let queries: [String: Query]
}

final class OccurrenceAppFixture: @unchecked Sendable {
    let descriptor: OccurrenceAppDescriptor
    let directory: URL
    let databaseURL: URL
    let indexURL: URL
    let indexManifestURL: URL
    let databaseManifestURL: URL
    let identityURL: URL
    let mini: OtzariaSearchArtifactManifest
    let full: OtzariaSearchArtifactManifest
    let build: OtzariaSearchEngineBuildInfo
    let oracle: OccurrenceSQLOracle
    let database: OtzariaDatabaseInstallationManifest
    let current: OtzariaIndexFingerprint
    let identity: OtzariaIndexBuildIdentity
    let indexManifestBytes: Data
    let databaseManifestBytes: Data
    let identityBytes: Data
    let repository = OtzariaTantivySearchRepository.shared

    init(descriptorURL: URL) throws {
        descriptor = try JSONDecoder().decode(OccurrenceAppDescriptor.self, from: Data(contentsOf: descriptorURL))
        directory = URL(fileURLWithPath: descriptor.root)
        guard try String(contentsOf: directory.appendingPathComponent("OWNER"), encoding: .utf8) == descriptor.ownerMarker,
              directory.lastPathComponent.hasPrefix("owned-mini-") else {
            throw OccurrenceAppFailure(description: "Only the driver's owned verified fixture is permitted")
        }
        databaseURL = directory.appendingPathComponent("seforim.db")
        indexURL = directory.appendingPathComponent("index")
        indexManifestURL = indexURL.appendingPathComponent("otzaria_prebuilt_installation.json")
        databaseManifestURL = directory.appendingPathComponent("seforim-installation.json")
        identityURL = indexURL.appendingPathComponent("otzaria_search_identity.json")
        let miniBytes = try Data(contentsOf: URL(fileURLWithPath: descriptor.miniManifest))
        let oracleBytes = try Data(contentsOf: URL(fileURLWithPath: descriptor.sqlOracle))
        try requireAppOccurrence(ActionOccurrenceCoveragePolicy.sha256(miniBytes) == descriptor.miniManifestSHA256,
                                 "Raw immutable mini manifest hash")
        try requireAppOccurrence(ActionOccurrenceCoveragePolicy.sha256(oracleBytes) == descriptor.sqlOracleSHA256,
                                 "Independent SQL oracle hash")
        mini = try JSONDecoder().decode(OtzariaSearchArtifactManifest.self, from: miniBytes)
        full = try JSONDecoder().decode(OtzariaSearchArtifactManifest.self,
            from: Data(contentsOf: URL(fileURLWithPath: descriptor.fullManifest)))
        oracle = try JSONDecoder().decode(OccurrenceSQLOracle.self, from: oracleBytes)
        try requireAppOccurrence(oracle.rowsScanned == 18_879 && oracle.allSQLDocuments == 18_879 &&
                                 oracle.allSQLSources == 10 && oracle.databaseSHA256 == descriptor.databaseSHA256,
                                 "Independent oracle must describe the complete original mini corpus")
        OccurrenceAppEnvironment.shared.configure(root: directory)
        build = try OtzariaSearchEngineBridge.buildInfo()
        current = try OtzariaSearchIndexManager.shared.currentFingerprint(databasePath: databaseURL.path)
        let source = mini.sourceDatabase
        let profile = try OtzariaDataProfileRegistry.requireActiveProfile()
        let release = OtzariaLibraryRelease(id: source.releaseID, tag: source.releaseTag,
            asset: .init(id: source.assetID, name: source.assetName,
                         downloadURL: profile.databaseDownloadURL,
                         compressedSize: source.compressedBytes, digest: source.sourceAssetDigest,
                         updatedAt: nil))
        database = OtzariaDatabaseInstallationManifest(release: release,
                                                       databaseFileSize: source.databaseBytes)
        // This is the original installer's producer-identity helper using the
        // actual runtime's required-resource projection. It is not admission.
        identity = try OtzariaSearchArtifactPolicy.artifactProducerIdentity(
            manifest: mini, database: current, requiredResourceNames: Set(build.resourceHashes.keys))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        indexManifestBytes = try encoder.encode(mini)
        encoder.dateEncodingStrategy = .iso8601
        databaseManifestBytes = try encoder.encode(database)
        identityBytes = try encoder.encode(identity)
        try indexManifestBytes.write(to: indexManifestURL, options: .atomic)
        try databaseManifestBytes.write(to: databaseManifestURL, options: .atomic)
        try identityBytes.write(to: identityURL, options: .atomic)
        OtzariaDatabaseAccessController.shared.occurrenceFixturePublish(url: databaseURL, source: .managedInternal)
    }

    var snapshot: ActionBackendSnapshot {
        .init(backend: .otzaria, generation: OtzariaMaktabahBridge.shared.generationSnapshot())
    }
    func invocation(milliseconds: UInt64 = 5_000) -> ActionPortInvocation {
        .init(requestId: UUID(), snapshot: snapshot,
              deadlineUptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + milliseconds * 1_000_000)
    }
    func query(_ text: String = "שלום", books: [UInt64] = []) -> ActionOccurrenceQuery {
        .init(backend: .otzaria, text: text,
              scopeWorkRefs: books.map { .init(backend: .otzaria, workKey: "book:\($0)") })
    }
    func restoreMetadata() throws {
        repository.closeAllEngines()
        for url in [indexManifestURL, databaseManifestURL, identityURL] {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                try FileManager.default.removeItem(at: url)
            }
        }
        try indexManifestBytes.write(to: indexManifestURL, options: .atomic)
        try databaseManifestBytes.write(to: databaseManifestURL, options: .atomic)
        try identityBytes.write(to: identityURL, options: .atomic)
        OtzariaDatabaseAccessController.shared.occurrenceFixturePublish(url: databaseURL, source: .managedInternal)
    }
    func validateCoverage() throws -> ActionOccurrenceCoveragePolicy.Coverage {
        try ActionOccurrenceCoveragePolicy.validate(manifest: mini, database: database,
            current: current, identity: identity, build: build, profileID: "miniTest10")
    }
    deinit { repository.closeAllEngines() }
}

// Value-only mutation of complete original Codable models, never a hand-built
// replacement manifest or relaxed production decoder.
enum OccurrenceJSONValue: Sendable {
    case string(String), integer(Int), json(String)
    var value: Any {
        get throws {
            switch self {
            case .string(let value): return value
            case .integer(let value): return value
            case .json(let value): return try JSONSerialization.jsonObject(with: Data(value.utf8))
            }
        }
    }
}
func occurrenceMutated<T: Codable>(_ original: T, path: [String], value: OccurrenceJSONValue) throws -> T {
    func replace(_ object: Any, remaining: ArraySlice<String>) throws -> Any {
        guard let first = remaining.first else { return try value.value }
        if var dictionary = object as? [String: Any] {
            let child = dictionary[first] ?? NSNull()
            dictionary[first] = try replace(child, remaining: remaining.dropFirst())
            return dictionary
        }
        if var array = object as? [Any], let index = Int(first), array.indices.contains(index) {
            array[index] = try replace(array[index], remaining: remaining.dropFirst())
            return array
        }
        throw OccurrenceAppFailure(description: "Invalid test mutation path \(path)")
    }
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let object = try JSONSerialization.jsonObject(with: encoder.encode(original))
    let changed = try replace(object, remaining: path[...])
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(T.self, from: JSONSerialization.data(withJSONObject: changed, options: [.sortedKeys]))
}

func appOccurrenceWait(_ semaphore: DispatchSemaphore, deadline: DispatchTime) async -> Bool {
    await withCheckedContinuation { continuation in
        DispatchQueue.global(qos: .userInitiated).async {
            continuation.resume(returning: semaphore.wait(timeout: deadline) == .success)
        }
    }
}
