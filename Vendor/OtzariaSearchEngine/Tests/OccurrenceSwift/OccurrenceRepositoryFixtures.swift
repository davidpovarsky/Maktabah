import Foundation

// Filesystem path resolution and UI result types are explicit boundary doubles.
// The WHOLE production Repository and Bridge, and real C/Rust engine, compile
// unchanged. No provider, engine handle, count, or cache entry is injected here.
enum OtzariaDataProfileRegistry {
    static var activeProfileID: String { "owned-occurrence-repository-fixture" }
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
        return .init(databasePath: databasePath,
                     fileSize: (attributes[.size] as! NSNumber).uint64Value,
                     modificationTime: (attributes[.modificationDate] as! Date).timeIntervalSince1970)
    }
}

final class OtzariaMagicDictionaryManager: @unchecked Sendable {
    static let shared = OtzariaMagicDictionaryManager()
    var validatedDatabaseURL: URL? { nil }
}
enum OtzariaIndexFileLogger { static func log(_ value: String) {} }
enum OtzariaSearchSnippetRenderer { static func plainText(fromHTML value: String) -> String { value } }
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

struct OccurrenceRepositoryWitness: Sendable {
    let revision: UInt64
    let fingerprint: Data
}

final class OccurrenceRepositoryFixture: @unchecked Sendable {
    let directory: URL
    let database: URL
    let index: URL
    let indexManifest: URL
    let databaseManifest: URL
    let identity: URL
    let repository = OtzariaTantivySearchRepository.shared
    private(set) var opened: OtzariaSearchEngineBridge?

    init(open: Bool = true, manifests: Bool = true) throws {
        directory = try OccurrenceFixtureRegistry.shared.makeDirectory()
        database = directory.appendingPathComponent("seforim.db")
        index = directory.appendingPathComponent("index")
        indexManifest = index.appendingPathComponent("otzaria_prebuilt_installation.json")
        databaseManifest = directory.appendingPathComponent("seforim-installation.json")
        identity = index.appendingPathComponent("otzaria_search_identity.json")
        // These bytes are only a filesystem identity witness, not a SQLite
        // corpus, trusted installation, or application managed-coverage proof.
        try Data("owned fixture database identity only".utf8).write(to: database)
        let seed = try OtzariaSearchEngineBridge(indexURL: index)
        do {
            try seed.addTextBook(title: "Real repository count fixture", topics: "/fixtures",
                                 filePath: "otzaria-book:1", catalogueOrder: 1,
                                 generationOrder: 5, text: "משה משה", extraFacets: ["/book/1"])
            try seed.commit()
            seed.close()
        } catch { seed.close(); throw error }
        try Data("{\"fixtureIdentity\":1}".utf8).write(to: identity)
        if manifests {
            try Data("{\"fixtureIndexInstallation\":1}".utf8).write(to: indexManifest)
            try Data("{\"fixtureDatabaseInstallation\":1}".utf8).write(to: databaseManifest)
        }
        if open { opened = try repository.engine(databasePath: database.path) }
    }

    deinit { repository.closeAllEngines() }

    func witness() throws -> OccurrenceRepositoryWitness {
        let observed = repository.resourceObservation(databasePath: database.path)
        guard let fingerprint = observed.fingerprint else {
            throw OccurrenceTestFailure(description: "Expected a bounded original repository resource witness")
        }
        return .init(revision: observed.revision, fingerprint: fingerprint)
    }

    func requireEngine() throws -> OtzariaSearchEngineBridge {
        guard let opened else { throw OccurrenceTestFailure(description: "Fixture engine was not explicitly opened") }
        return opened
    }

    func count(
        _ source: OtzariaExactOccurrenceSource,
        witness: OccurrenceRepositoryWitness,
        timeoutMs: UInt64 = 5_000,
        deadline: UInt64? = nil
    ) async throws -> OtzariaExactOccurrenceResult {
        try await repository.countExactTokenOccurrences(
            databasePath: database.path,
            request: OtzariaExactOccurrenceRequest(query: "משה", timeoutMs: timeoutMs),
            expectedSource: source, expectedRevision: witness.revision,
            expectedFingerprint: witness.fingerprint,
            deadlineUptimeNanoseconds: deadline ?? (DispatchTime.now() + .seconds(5)).uptimeNanoseconds
        )
    }
}

func launchRepositoryOccurrence(
    _ fixture: OccurrenceRepositoryFixture,
    source: OtzariaExactOccurrenceSource,
    witness: OccurrenceRepositoryWitness,
    timeoutMs: UInt64 = 5_000,
    deadline: UInt64? = nil,
    started: DispatchSemaphore? = nil
) -> (Task<Void, Never>, OccurrenceObservation) {
    let observed = OccurrenceObservation()
    let task = Task {
        started?.signal()
        do {
            observed.store(.success(try await fixture.count(
                source, witness: witness, timeoutMs: timeoutMs, deadline: deadline
            )))
        } catch let failure as OtzariaExactOccurrenceError {
            observed.store(.failure(failure))
        } catch {
            observed.store(.unexpected(String(describing: error)))
        }
    }
    return (task, observed)
}

func holdOccurrenceRepositoryLock(
    _ repository: OtzariaTantivySearchRepository
) -> OccurrenceQueueBarrier {
    let barrier = OccurrenceQueueBarrier()
    DispatchQueue.global(qos: .userInitiated).async {
        repository.occurrenceTestWithCacheLock { barrier.block() }
    }
    return barrier
}
