import Foundation

enum OccurrenceRepositoryCases {
    static func unopened(_ source: OtzariaExactOccurrenceSource) async throws {
        let fixture = try OccurrenceRepositoryFixture(open: false)
        let witness = try fixture.witness()
        let meta = fixture.index.appendingPathComponent("meta.json")
        let before = try Data(contentsOf: meta)
        try requireOccurrence(fixture.repository.observedOpenIndexDocumentCount(databasePath: fixture.database.path) == nil,
                              "Prepared fixture is not present in the actual repository cache")
        try await expectOccurrenceFailure(.engineUnavailable) {
            try await fixture.count(source, witness: witness)
        }
        try requireOccurrence(fixture.repository.observedOpenIndexDocumentCount(databasePath: fixture.database.path) == nil,
                              "Counting must not create/open/cache an engine")
        try requireOccurrence(try Data(contentsOf: meta) == before, "Unopened rejection must preserve fixture metadata")
    }

    static func originalCachedEngine(_ source: OtzariaExactOccurrenceSource) async throws {
        let fixture = try OccurrenceRepositoryFixture()
        let engine = try fixture.requireEngine()
        let witness = try fixture.witness()
        let result = try await fixture.count(source, witness: witness)
        try requireOccurrence(result.occurrences == 2 && result.matchingLiveDocuments == 1,
                              "Actual cached original engine must return two positions in one document")
        try requireOccurrence(result.proof.liveIndexDocuments == 1, "Actual original live index proof")
        try requireOccurrence(try fixture.repository.engine(databasePath: fixture.database.path) === engine,
                              "Count must retain the same original cache object")
        try requireOccurrence(try engine.documentCount() == 1, "Original legacy C call still works")
    }

    static func staleExpectations(_ source: OtzariaExactOccurrenceSource) async throws {
        let fixture = try OccurrenceRepositoryFixture()
        let witness = try fixture.witness()
        let wrongRevision = OccurrenceRepositoryWitness(
            revision: witness.revision + 1, fingerprint: witness.fingerprint
        )
        try await expectOccurrenceFailure(.sourceMismatch) {
            try await fixture.count(source, witness: wrongRevision)
        }
        let wrongFingerprint = OccurrenceRepositoryWitness(revision: witness.revision, fingerprint: Data("other".utf8))
        try await expectOccurrenceFailure(.sourceMismatch) {
            try await fixture.count(source, witness: wrongFingerprint)
        }
        try requireOccurrence(try fixture.requireEngine().occurrenceTestPendingCount == 0,
                              "A stale authority must be rejected before a C token is queued")
    }

    static func missingManifests(_ source: OtzariaExactOccurrenceSource) async throws {
        let fixture = try OccurrenceRepositoryFixture(manifests: false)
        let witness = try fixture.witness()
        try requireOccurrence(fixture.repository.observedOpenIndexDocumentCount(databasePath: fixture.database.path) == 1,
                              "Ordinary/custom cached readiness remains valid without optional manifests")
        try await expectOccurrenceFailure(.sourceMismatch) {
            try await fixture.count(source, witness: witness)
        }
    }

    static func manifestsEnterWitness(_ source: OtzariaExactOccurrenceSource) async throws {
        for isIndex in [true, false] {
            let fixture = try OccurrenceRepositoryFixture()
            let witness = try fixture.witness()
            try Data("{\"replacement\":true}".utf8).write(
                to: isIndex ? fixture.indexManifest : fixture.databaseManifest, options: .atomic
            )
            let changed = try fixture.witness()
            try requireOccurrence(changed.fingerprint != witness.fingerprint,
                                  "Every original installation manifest participates in the raw source witness")
            try await expectOccurrenceFailure(.sourceMismatch) {
                try await fixture.count(source, witness: witness)
            }
            try await expectOccurrenceFailure(.sourceMismatch) {
                try await fixture.count(source, witness: changed)
            }
            try requireOccurrence(fixture.repository.observedOpenIndexDocumentCount(databasePath: fixture.database.path) == nil,
                                  "Changed manifest revokes the old cached stamp without reopening")
        }
    }

    static func oversizedManifest(_ source: OtzariaExactOccurrenceSource) async throws {
        let fixture = try OccurrenceRepositoryFixture()
        let witness = try fixture.witness()
        try Data(repeating: 120, count: 1_048_577).write(to: fixture.indexManifest)
        try requireOccurrence(fixture.repository.resourceObservation(databasePath: fixture.database.path).fingerprint == nil,
                              "Oversized raw metadata cannot become a bounded fingerprint")
        try await expectOccurrenceFailure(.sourceMismatch) {
            try await fixture.count(source, witness: witness)
        }
    }

    static func postCountSourceMutation(_ source: OtzariaExactOccurrenceSource) async throws {
        for field in 0..<4 {
            let fixture = try OccurrenceRepositoryFixture()
            let engine = try fixture.requireEngine()
            let witness = try fixture.witness()
            let counted = OccurrenceQueueBarrier()
            defer { counted.release(); engine.occurrenceTestAfterCount(nil) }
            engine.occurrenceTestAfterCount { counted.block() }
            let (task, observed) = launchRepositoryOccurrence(fixture, source: source, witness: witness)
            defer { task.cancel() }
            let entered = await occurrenceWait(counted.entered, deadline: .now() + .seconds(2))
            try requireOccurrence(entered, "Actual native count must finish before the source mutation")
            let target = [fixture.indexManifest, fixture.databaseManifest, fixture.identity, fixture.database][field]
            try Data("owned fixture changed AFTER real native count field \(field)".utf8).write(to: target)
            counted.release()
            let completed = await occurrenceWait(observed.completed, deadline: .now() + .seconds(2))
            try requireOccurrence(completed, "Post-count source failure must complete within its bound")
            await task.value
            try observed.requireFailure(.sourceMismatch)
            try counted.assertDidNotTimeOut()
        }
    }

    static func invalidationCancelsLease(_ source: OtzariaExactOccurrenceSource) async throws {
        let fixture = try OccurrenceRepositoryFixture()
        let engine = try fixture.requireEngine()
        let witness = try fixture.witness()
        let counted = OccurrenceQueueBarrier()
        defer { counted.release(); engine.occurrenceTestAfterCount(nil) }
        engine.occurrenceTestAfterCount { counted.block() }
        let (task, observed) = launchRepositoryOccurrence(fixture, source: source, witness: witness)
        defer { task.cancel() }
        let entered = await occurrenceWait(counted.entered, deadline: .now() + .seconds(2))
        try requireOccurrence(entered, "Invalidate race begins after an actual native count")
        let invalidated = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            fixture.repository.invalidate(databasePath: fixture.database.path)
            invalidated.signal()
        }
        let completed = await occurrenceWait(observed.completed, deadline: .now() + .milliseconds(500))
        try requireOccurrence(completed, "Repository close cancels the lease before native worker/free can finish")
        try observed.requireFailure(.engineClosed)
        let live = fixture.repository.resourceObservation(databasePath: fixture.database.path)
        try requireOccurrence(live.revision > witness.revision,
                              "Publication revision is visible while invalidation waits for engine cleanup")
        counted.release()
        let closed = await occurrenceWait(invalidated, deadline: .now() + .seconds(2))
        try requireOccurrence(closed, "Invalidate can finish after the actual worker releases")
        await task.value
        try counted.assertDidNotTimeOut()
    }

    static func cacheLockCancellation(_ source: OtzariaExactOccurrenceSource) async throws {
        let fixture = try OccurrenceRepositoryFixture()
        let engine = try fixture.requireEngine()
        let witness = try fixture.witness()
        let held = holdOccurrenceRepositoryLock(fixture.repository)
        defer { held.release() }
        try requireOccurrence(await occurrenceWait(held.entered, deadline: .now() + .seconds(2)),
                              "Actual repository lock must be held")
        let started = DispatchSemaphore(value: 0)
        let (task, observed) = launchRepositoryOccurrence(
            fixture, source: source, witness: witness, started: started
        )
        defer { task.cancel() }
        try requireOccurrence(await occurrenceWait(started, deadline: .now() + .seconds(2)), "Awaiting task began")
        let premature = await occurrenceWait(observed.completed, deadline: .now() + .milliseconds(50))
        try requireOccurrence(!premature && engine.occurrenceTestPendingCount == 0,
                              "Busy capture has not created a C request or returned a scalar")
        task.cancel()
        try requireOccurrence(await occurrenceWait(observed.completed, deadline: .now() + .milliseconds(500)),
                              "Cancellation must not wait for repository lock release")
        try observed.requireFailure(.cancelled)
        held.release()
        await task.value
        try held.assertDidNotTimeOut()
    }

    static func cacheLockDeadline(_ source: OtzariaExactOccurrenceSource) async throws {
        let fixture = try OccurrenceRepositoryFixture()
        let engine = try fixture.requireEngine()
        let witness = try fixture.witness()
        let held = holdOccurrenceRepositoryLock(fixture.repository)
        defer { held.release() }
        try requireOccurrence(await occurrenceWait(held.entered, deadline: .now() + .seconds(2)), "Lock acquired")
        let (task, observed) = launchRepositoryOccurrence(
            fixture, source: source, witness: witness, timeoutMs: 100
        )
        defer { task.cancel() }
        try requireOccurrence(await occurrenceWait(observed.completed, deadline: .now() + .milliseconds(750)),
                              "Deadline must terminate a busy cache capture before lock release")
        try observed.requireFailure(.deadlineExceeded)
        try requireOccurrence(engine.occurrenceTestPendingCount == 0, "Expired capture did not enqueue a native request")
        held.release()
        await task.value
        try held.assertDidNotTimeOut()
    }

    static func cacheWaitConsumesDeadline(_ source: OtzariaExactOccurrenceSource) async throws {
        let fixture = try OccurrenceRepositoryFixture()
        let engine = try fixture.requireEngine()
        let witness = try fixture.witness()
        let held = holdOccurrenceRepositoryLock(fixture.repository)
        let engineHeld = OccurrenceQueueBarrier()
        defer { held.release(); engineHeld.release() }
        try requireOccurrence(await occurrenceWait(held.entered, deadline: .now() + .seconds(2)), "Cache lock acquired")
        engine.occurrenceTestEnqueue { engineHeld.block() }
        try requireOccurrence(await occurrenceWait(engineHeld.entered, deadline: .now() + .seconds(2)), "Engine queue acquired")
        let deadline = DispatchTime.now() + .seconds(1)
        let (task, observed) = launchRepositoryOccurrence(
            fixture, source: source, witness: witness, timeoutMs: 5_000,
            deadline: deadline.uptimeNanoseconds
        )
        defer { task.cancel() }
        try await Task<Never, Never>.sleep(nanoseconds: 200_000_000)
        held.release()
        try await occurrenceEventually(deadline: .now() + .milliseconds(500)) {
            engine.occurrenceTestPendingCount == 1
        }
        try requireOccurrence(await occurrenceWait(observed.completed, deadline: deadline + .milliseconds(400)),
                              "Native queued deadline must consume prior cache wait, not restart five seconds")
        try observed.requireFailure(.deadlineExceeded)
        engineHeld.release()
        await task.value
        try held.assertDidNotTimeOut()
        try engineHeld.assertDidNotTimeOut()
    }

    static func postCountLock(_ source: OtzariaExactOccurrenceSource, cancel: Bool) async throws {
        let fixture = try OccurrenceRepositoryFixture()
        let engine = try fixture.requireEngine()
        let witness = try fixture.witness()
        let counted = OccurrenceQueueBarrier()
        defer { counted.release(); engine.occurrenceTestAfterCount(nil) }
        engine.occurrenceTestAfterCount { counted.block() }
        let deadline = DispatchTime.now() + .seconds(cancel ? 5 : 2)
        let (task, observed) = launchRepositoryOccurrence(
            fixture, source: source, witness: witness, deadline: deadline.uptimeNanoseconds
        )
        defer { task.cancel() }
        try requireOccurrence(await occurrenceWait(counted.entered, deadline: .now() + .seconds(1)),
                              "Real native result is ready")
        let held = holdOccurrenceRepositoryLock(fixture.repository)
        defer { held.release() }
        try requireOccurrence(await occurrenceWait(held.entered, deadline: .now() + .seconds(1)),
                              "Repository lock must be free while the actual Bridge worker is in flight")
        counted.release()
        try await occurrenceEventually(deadline: .now() + .seconds(1)) {
            engine.occurrenceTestPendingCount == 0
        }
        if cancel { task.cancel() }
        let completionDeadline = cancel ? DispatchTime.now() + .milliseconds(500) : deadline + .milliseconds(500)
        try requireOccurrence(await occurrenceWait(observed.completed, deadline: completionDeadline),
                              "Post-count cache revalidation must remain cancellable and deadline bounded")
        try observed.requireFailure(cancel ? .cancelled : .deadlineExceeded)
        held.release()
        await task.value
        try held.assertDidNotTimeOut()
        try counted.assertDidNotTimeOut()
    }

    static func publicationABA(_ source: OtzariaExactOccurrenceSource) async throws {
        let fixture = try OccurrenceRepositoryFixture()
        let witness = try fixture.witness()
        fixture.repository.invalidate(databasePath: fixture.database.path)
        _ = try fixture.repository.engine(databasePath: fixture.database.path)
        let after = try fixture.witness()
        try requireOccurrence(after.fingerprint == witness.fingerprint && after.revision > witness.revision,
                              "Supported reopen retains bytes but advances authority revision")
        try await expectOccurrenceFailure(.sourceMismatch) {
            try await fixture.count(source, witness: witness)
        }
        let result = try await fixture.count(source, witness: after)
        try requireOccurrence(result.occurrences == 2, "New explicit cache owner with fresh authority still counts")
    }
}
