import Foundation
import OtzariaActionCore

// These cases execute only when the actual compiled production registry is
// qualified by its separately reviewed source commit. They never modify it.
enum OccurrenceAppQualifiedCases {
    static func coverageRejections(_ fixture: OccurrenceAppFixture) throws {
        func reject(_ database: OtzariaDatabaseInstallationManifest? = nil,
                    _ current: OtzariaIndexFingerprint? = nil,
                    _ identity: OtzariaIndexBuildIdentity? = nil,
                    _ profile: String = "miniTest10") throws {
            do {
                _ = try ActionOccurrenceCoveragePolicy.validate(manifest: fixture.mini, database: database ?? fixture.database,
                    current: current ?? fixture.current, identity: identity ?? fixture.identity, build: fixture.build, profileID: profile)
            } catch { return }
            throw OccurrenceAppFailure(description: "Changed managed coverage unexpectedly admitted")
        }
        try reject(fixture.database, fixture.current, fixture.identity, "custom")
        let databaseChanges: [([String], OccurrenceJSONValue)] = [
            (["profileID"], .string("production")),
            (["profileVersion"], .integer(7)),
            (["databaseFileSize"], .integer(15_470_593)),
            (["releaseID"], .integer(409_213_894)),
            (["digest"], .string("sha256:" + String(repeating: "a", count: 64)))
        ]
        for (path, value) in databaseChanges {
            let changed: OtzariaDatabaseInstallationManifest = try occurrenceMutated(fixture.database, path: path, value: value)
            try reject(changed)
        }
        try reject(fixture.database,
                   .init(databasePath: fixture.current.databasePath, fileSize: fixture.current.fileSize + 1,
                         modificationTime: fixture.current.modificationTime))
        try reject(fixture.database,
                   .init(databasePath: fixture.current.databasePath, fileSize: fixture.current.fileSize,
                         modificationTime: .nan))
        let identityChanges: [([String], OccurrenceJSONValue)] = [
            (["upstreamCommit"], .string(fixture.build.upstreamCommit)),
            (["catalogueHash"], .string("unknown-catalogue")),
            (["resourceHashes", "Vendor/OtzariaSearchEngine/Resources/dictionary.json"], .string(String(repeating: "0", count: 64))),
            (["database", "databasePath"], .string("different-source"))
        ]
        for (path, value) in identityChanges {
            let changed: OtzariaIndexBuildIdentity = try occurrenceMutated(fixture.identity, path: path, value: value)
            try reject(fixture.database, fixture.current, changed)
        }
    }

    static func originalCounts(_ fixture: OccurrenceAppFixture, scoped: Bool) async throws {
        try fixture.restoreMetadata()
        let engine = try fixture.repository.engine(databasePath: fixture.databaseURL.path)
        defer { engine.close(); fixture.repository.closeAllEngines() }
        try requireAppOccurrence(try engine.documentCount() == 18_879,
                                 "Explicit original engine opening must observe the complete mini corpus")
        let queries: [(String, [UInt64])] = scoped
            ? [("תורה", [1]), ("שלום", [1, 103]), ("אלהים", [1, 28]),
               ("רבי", [103]), ("רמב\"ם", [3891])]
            : [("תורה", []), ("שלום", []), ("אלהים", []), ("ישראל", []),
               ("רבי", []), ("רמבם", []), ("רמב\"ם", []), ("אברהם", [])]
        for (text, books) in queries {
            guard let oracle = fixture.oracle.queries[text] else {
                throw OccurrenceAppFailure(description: "Independent SQL query oracle is absent")
            }
            var count = oracle.occurrences
            var documents = oracle.matchingLiveDocuments
            if !books.isEmpty {
                count = 0; documents = 0
                for book in books {
                    guard let part = oracle.books[String(book)] else {
                        throw OccurrenceAppFailure(description: "Independent SQL scope oracle is absent")
                    }
                    count += part.occurrences; documents += part.matchingLiveDocuments
                }
            }
            let query = fixture.query(text, books: books)
            let invocation = fixture.invocation()
            let result = try await ActionLiveOccurrenceCounter.count(query, invocation: invocation)
            try requireAppOccurrence(result.count == count && result.matchingDocuments == documents,
                                     "Actual whole app -> original C positions differs from independent SQL: \(text), \(books)")
            try requireAppOccurrence(result.requestId == invocation.requestId && result.snapshot == invocation.snapshot &&
                                     result.query == query && Array(result.query.text.utf8) == Array(text.utf8),
                                     "Original Core DTO must retain exact request/source/query identity")
            let evidence = result.evidence
            try requireAppOccurrence(evidence.completeManagedArtifact &&
                                     evidence.contract == ActionOccurrenceEvidence.requiredContract &&
                                     evidence.engineRevision == fixture.build.upstreamCommit &&
                                     evidence.artifactIdentity == fixture.mini.artifactIdentity &&
                                     evidence.databaseSHA256 == fixture.descriptor.databaseSHA256 &&
                                     evidence.observedIndexedDocuments == 18_879 &&
                                     evidence.expectedIndexedDocuments == 18_879 &&
                                     evidence.visitedDocuments >= documents && evidence.visitedPositions >= count &&
                                     evidence.engineSnapshotSHA256.utf8.count == 64 &&
                                     evidence.engineSnapshotSHA256.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
                                     "Actual response proof must bind complete managed coverage, real work, and original source")
        }
    }

    static func originalAnalyzerRejectsMultipleTokens(_ fixture: OccurrenceAppFixture) async throws {
        try fixture.restoreMetadata()
        let engine = try fixture.repository.engine(databasePath: fixture.databaseURL.path)
        defer { engine.close(); fixture.repository.closeAllEngines() }
        try await requireAppAsyncFailure(.unsupportedQuery) {
            try await ActionLiveOccurrenceCounter.count(fixture.query("בראשית ברא"), invocation: fixture.invocation())
        }
    }

    static func postCountMutation(_ fixture: OccurrenceAppFixture, kind: String) async throws {
        try fixture.restoreMetadata()
        let engine = try fixture.repository.engine(databasePath: fixture.databaseURL.path)
        let barrier = OccurrenceAppBarrier()
        engine.occurrenceTestAfterCount { barrier.block() }
        defer {
            barrier.release()
            engine.occurrenceTestAfterCount(nil)
            engine.close()
            fixture.repository.closeAllEngines()
            try? fixture.restoreMetadata()
        }
        let before = OtzariaDatabaseAccessController.shared.selectionObservation()
        let generation = OtzariaMaktabahBridge.shared.generationSnapshot()
        let (task, observation) = launchAppOccurrence(fixture)
        guard await appOccurrenceWait(barrier.entered, deadline: .now() + .seconds(3)) else {
            task.cancel(); barrier.release(); await task.value
            throw OccurrenceAppFailure(description: "Actual C count did not reach its original post-count hook")
        }
        switch kind {
        case "selectionABA":
            let owner = OtzariaDatabaseAccessController.shared
            owner.occurrenceFixturePublish(url: fixture.directory.appendingPathComponent("other.db"), source: .externalBookmark)
            owner.occurrenceFixturePublish(url: fixture.databaseURL, source: .managedInternal)
            let after = owner.selectionObservation()
            try requireAppOccurrence(after.url == before.url && after.source == before.source &&
                                     after.revision == before.revision + 2 &&
                                     generation == OtzariaMaktabahBridge.shared.generationSnapshot(),
                                     "Only actual owner revision changes across the A -> B -> A publication")
        case "generation":
            OtzariaMaktabahBridge.shared.occurrenceFixtureAdvanceGeneration()
        case "manifest":
            var bytes = fixture.databaseManifestBytes
            bytes.append(contentsOf: [0x20, 0x0a])
            try bytes.write(to: fixture.databaseManifestURL, options: .atomic)
        default: throw OccurrenceAppFailure(description: "Unknown post-count mutation")
        }
        barrier.release()
        guard await appOccurrenceWait(observation.completed, deadline: .now() + .seconds(3)) else {
            task.cancel(); await task.value
            throw OccurrenceAppFailure(description: "Post-count source revocation did not complete")
        }
        await task.value
        try observation.requireFailure(.staleIndex)
        try barrier.assertDidNotExpire()
    }

    static func queuedRevocation(_ fixture: OccurrenceAppFixture, cancel: Bool) async throws {
        try fixture.restoreMetadata()
        let engine = try fixture.repository.engine(databasePath: fixture.databaseURL.path)
        let barrier = OccurrenceAppBarrier()
        engine.occurrenceTestEnqueue { barrier.block() }
        defer { barrier.release(); engine.close(); fixture.repository.closeAllEngines() }
        guard await appOccurrenceWait(barrier.entered, deadline: .now() + .seconds(3)) else {
            throw OccurrenceAppFailure(description: "Actual original engine queue was not held")
        }
        let (task, observation) = launchAppOccurrence(fixture, milliseconds: cancel ? 5_000 : 1_000)
        let pendingDeadline = (DispatchTime.now() + .seconds(2)).uptimeNanoseconds
        while engine.occurrenceTestPendingCount != 1 {
            guard DispatchTime.now().uptimeNanoseconds < pendingDeadline else {
                task.cancel(); barrier.release(); await task.value
                throw OccurrenceAppFailure(description: "Whole app count did not register with actual original queue")
            }
            try await Task<Never, Never>.sleep(nanoseconds: 1_000_000)
        }
        if cancel { task.cancel() }
        guard await appOccurrenceWait(observation.completed, deadline: .now() + .seconds(2)) else {
            task.cancel(); barrier.release(); await task.value
            throw OccurrenceAppFailure(description: "Cancellation/deadline waited for the blocked engine queue")
        }
        try observation.requireFailure(cancel ? .cancelled : .deadlineExceeded)
        try requireAppOccurrence(engine.occurrenceTestPendingCount == 1,
                                 "A completed cancelled caller must not release queued C capacity before worker cleanup")
        barrier.release()
        await task.value
        let cleanupDeadline = (DispatchTime.now() + .seconds(3)).uptimeNanoseconds
        while engine.occurrenceTestPendingCount != 0 {
            guard DispatchTime.now().uptimeNanoseconds < cleanupDeadline else {
                throw OccurrenceAppFailure(description: "Original worker did not release retained operation capacity")
            }
            try await Task<Never, Never>.sleep(nanoseconds: 1_000_000)
        }
        try barrier.assertDidNotExpire()
    }
}

final class OccurrenceAppBarrier: @unchecked Sendable {
    let entered = DispatchSemaphore(value: 0)
    private let signal = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var released = false
    private var expired = false
    func block() {
        entered.signal()
        let didExpire = signal.wait(timeout: .now() + .seconds(8)) != .success
        lock.withLock { expired = didExpire }
    }
    func release() {
        let shouldSignal = lock.withLock {
            if released { return false }
            released = true
            return true
        }
        if shouldSignal { signal.signal() }
    }
    func assertDidNotExpire() throws {
        try requireAppOccurrence(!lock.withLock({ expired }), "Bounded scheduling hook expired")
    }
}

final class OccurrenceAppObservation: @unchecked Sendable {
    enum Value: Sendable {
        case success(ActionExactOccurrenceCount)
        case failure(ActionOccurrenceFailure)
        case unexpected(String)
    }
    let completed = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var value: Value?
    func store(_ result: Value) {
        lock.withLock {
            precondition(value == nil, "Counter task completed twice")
            value = result
        }
        completed.signal()
    }
    func requireFailure(_ expected: ActionOccurrenceFailure) throws {
        guard let value = lock.withLock({ value }), case .failure(let actual) = value, actual == expected else {
            throw OccurrenceAppFailure(description: "Expected fixed source/lifetime failure \(expected)")
        }
    }
}
func launchAppOccurrence(_ fixture: OccurrenceAppFixture, milliseconds: UInt64 = 5_000)
    -> (Task<Void, Never>, OccurrenceAppObservation) {
    let observation = OccurrenceAppObservation()
    let task = Task {
        do {
            observation.store(.success(try await ActionLiveOccurrenceCounter.count(
                fixture.query(), invocation: fixture.invocation(milliseconds: milliseconds))))
        } catch let failure as ActionOccurrenceFailure {
            observation.store(.failure(failure))
        } catch { observation.store(.unexpected(String(describing: error))) }
    }
    return (task, observation)
}
