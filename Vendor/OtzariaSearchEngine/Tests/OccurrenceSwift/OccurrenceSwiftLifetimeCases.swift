import Foundation

final class OccurrenceCloseObservation: @unchecked Sendable {
    let completed = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var finished = false
    var isFinished: Bool { lock.withLock { finished } }
    func finish() { lock.withLock { finished = true }; completed.signal() }
}

final class WeakOccurrenceEngine: @unchecked Sendable {
    private weak var engine: OtzariaSearchEngineBridge?
    init(_ engine: OtzariaSearchEngineBridge) { self.engine = engine }
    var isGone: Bool { engine == nil }
}

enum OccurrenceLifetimeCases {
    private static func waitEntered(_ barrier: OccurrenceQueueBarrier) async throws {
        let entered = await occurrenceWait(barrier.entered, deadline: .now() + .seconds(2))
        try requireOccurrence(entered, "Original engine queue fixture did not enter")
    }

    static func cancelBeforeContinuation(_ source: OtzariaExactOccurrenceSource) async throws {
        let operation = try OtzariaExactOccurrenceOperation.create(
            request: .init(query: "משה"), expectedSource: source, deadline: .now() + .seconds(5)
        )
        defer { operation.releaseAfterWorker() } // This operation was never queued.
        operation.cancel(.cancelled)
        operation.cancel(.deadlineExceeded)
        operation.startDeadlineTimer()
        try await expectOccurrenceFailure(.cancelled) {
            try await withCheckedThrowingContinuation { operation.install($0) }
        }
    }

    static func precancelledTask(_ source: OtzariaExactOccurrenceSource) async throws {
        let fixture = try OccurrenceFixture()
        let observation = OccurrenceObservation()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            do {
                observation.store(.success(try await fixture.engine.countExactTokenOccurrences(
                    request: .init(query: "משה"), expectedSource: source
                )))
            } catch let failure as OtzariaExactOccurrenceError {
                observation.store(.failure(failure))
            } catch { observation.store(.unexpected(String(describing: error))) }
        }
        await task.value
        try observation.requireFailure(.cancelled)
        try requireOccurrence(fixture.engine.occurrenceTestPendingCount == 0,
                              "Precancelled task must not enqueue")
    }

    static func queuedCancellation(_ source: OtzariaExactOccurrenceSource) async throws {
        let fixture = try OccurrenceFixture()
        let barrier = OccurrenceQueueBarrier()
        fixture.engine.occurrenceTestEnqueue { barrier.block() }
        defer { barrier.release() }
        try await waitEntered(barrier)
        let (task, observed) = launchOccurrence(
            engine: fixture.engine, request: try .init(query: "משה", timeoutMs: 60_000), source: source
        )
        try await occurrenceEventually(deadline: .now() + .seconds(2)) {
            fixture.engine.occurrenceTestPendingCount == 1
        }
        task.cancel()
        let prompt = await occurrenceWait(observed.completed, deadline: .now() + .milliseconds(500))
        try requireOccurrence(prompt, "Cancellation must return while original queue remains blocked")
        try observed.requireFailure(.cancelled)
        try requireOccurrence(fixture.engine.occurrenceTestPendingCount == 1,
                              "Cancelled queued work must retain its owner/capacity")
        barrier.release()
        await task.value
        try await occurrenceEventually(deadline: .now() + .seconds(2)) {
            fixture.engine.occurrenceTestPendingCount == 0
        }
        try barrier.assertDidNotTimeOut()
    }

    static func queuedDeadline(_ source: OtzariaExactOccurrenceSource) async throws {
        let fixture = try OccurrenceFixture()
        let barrier = OccurrenceQueueBarrier()
        fixture.engine.occurrenceTestEnqueue { barrier.block() }
        defer { barrier.release() }
        try await waitEntered(barrier)
        let (task, observed) = launchOccurrence(
            engine: fixture.engine, request: try .init(query: "משה", timeoutMs: 100), source: source
        )
        let prompt = await occurrenceWait(observed.completed, deadline: .now() + .milliseconds(750))
        try requireOccurrence(prompt, "Deadline must return while original queue remains blocked")
        try observed.requireFailure(.deadlineExceeded)
        try requireOccurrence(fixture.engine.occurrenceTestPendingCount == 1,
                              "Expired queued work must keep its capacity until worker cleanup")
        barrier.release()
        await task.value
        try await occurrenceEventually(deadline: .now() + .seconds(2)) {
            fixture.engine.occurrenceTestPendingCount == 0
        }
        try barrier.assertDidNotTimeOut()
    }

    static func cancellationIsolation(_ source: OtzariaExactOccurrenceSource) async throws {
        let fixture = try OccurrenceFixture()
        let barrier = OccurrenceQueueBarrier()
        fixture.engine.occurrenceTestEnqueue { barrier.block() }
        defer { barrier.release() }
        try await waitEntered(barrier)
        let request = try OtzariaExactOccurrenceRequest(query: "משה", timeoutMs: 60_000)
        let (first, firstResult) = launchOccurrence(engine: fixture.engine, request: request, source: source)
        let (second, secondResult) = launchOccurrence(engine: fixture.engine, request: request, source: source)
        try await occurrenceEventually(deadline: .now() + .seconds(2)) {
            fixture.engine.occurrenceTestPendingCount == 2
        }
        first.cancel()
        let prompt = await occurrenceWait(firstResult.completed, deadline: .now() + .milliseconds(500))
        try requireOccurrence(prompt, "First cancellation did not return promptly")
        try firstResult.requireFailure(.cancelled)
        barrier.release()
        await first.value; await second.value
        _ = try secondResult.requireCount(2)
        try barrier.assertDidNotTimeOut()
    }

    static func retainedCapacity(_ source: OtzariaExactOccurrenceSource) async throws {
        let fixture = try OccurrenceFixture()
        let barrier = OccurrenceQueueBarrier()
        fixture.engine.occurrenceTestEnqueue { barrier.block() }
        defer { barrier.release() }
        try await waitEntered(barrier)
        let request = try OtzariaExactOccurrenceRequest(query: "משה", timeoutMs: 60_000)
        for index in 1...64 {
            let (task, observed) = launchOccurrence(engine: fixture.engine, request: request, source: source)
            try await occurrenceEventually(deadline: .now() + .seconds(2)) {
                fixture.engine.occurrenceTestPendingCount == index
            }
            task.cancel()
            let prompt = await occurrenceWait(observed.completed, deadline: .now() + .milliseconds(500))
            try requireOccurrence(prompt, "Cancellation \(index) did not return while queue held")
            try observed.requireFailure(.cancelled)
            await task.value
        }
        try await expectOccurrenceFailure(.requestCapacity) {
            try await fixture.engine.countExactTokenOccurrences(request: request, expectedSource: source)
        }
        try requireOccurrence(fixture.engine.occurrenceTestPendingCount == 64,
                              "Released callers must not create unbounded cancelled queued work")
        barrier.release()
        try await occurrenceEventually(deadline: .now() + .seconds(3)) {
            fixture.engine.occurrenceTestPendingCount == 0
        }
        let recovered = try await fixture.engine.countExactTokenOccurrences(request: request, expectedSource: source)
        try requireOccurrence(recovered.occurrences == 2, "C capacity did not recover after queue cleanup")
        try barrier.assertDidNotTimeOut()
    }

    static func closeBeforeQueueSync(_ source: OtzariaExactOccurrenceSource) async throws {
        let fixture = try OccurrenceFixture()
        let barrier = OccurrenceQueueBarrier()
        fixture.engine.occurrenceTestEnqueue { barrier.block() }
        defer { barrier.release() }
        try await waitEntered(barrier)
        let (task, observed) = launchOccurrence(
            engine: fixture.engine, request: try .init(query: "משה", timeoutMs: 60_000), source: source
        )
        try await occurrenceEventually(deadline: .now() + .seconds(2)) {
            fixture.engine.occurrenceTestPendingCount == 1
        }
        let closed = OccurrenceCloseObservation()
        DispatchQueue.global(qos: .userInitiated).async {
            fixture.engine.close(); closed.finish()
        }
        let prompt = await occurrenceWait(observed.completed, deadline: .now() + .milliseconds(500))
        try requireOccurrence(prompt, "close must cancel before waiting for the blocked queue")
        try observed.requireFailure(.engineClosed)
        try requireOccurrence(!closed.isFinished, "close must not free an engine before queue drain")
        barrier.release()
        let returned = await occurrenceWait(closed.completed, deadline: .now() + .seconds(3))
        try requireOccurrence(returned, "close did not return after queue cleanup")
        await task.value
        try barrier.assertDidNotTimeOut()
    }

    static func concurrentCloseAfterRealCount(_ source: OtzariaExactOccurrenceSource) async throws {
        let fixture = try OccurrenceFixture()
        let barrier = OccurrenceQueueBarrier()
        fixture.engine.occurrenceTestAfterCount { barrier.block() }
        defer { barrier.release() }
        let (task, observed) = launchOccurrence(
            engine: fixture.engine, request: try .init(query: "משה", timeoutMs: 60_000), source: source
        )
        // The scheduling hook is reached only after a real native count and
        // validated genuine proof, before the async result is published.
        try await waitEntered(barrier)
        let closers = (0..<4).map { _ in OccurrenceCloseObservation() }
        for closer in closers {
            DispatchQueue.global(qos: .userInitiated).async {
                fixture.engine.close(); closer.finish()
            }
        }
        let prompt = await occurrenceWait(observed.completed, deadline: .now() + .milliseconds(500))
        try requireOccurrence(prompt, "In-flight close must revoke an already computed result")
        try observed.requireFailure(.engineClosed)
        try requireOccurrence(closers.allSatisfy { !$0.isFinished },
                              "No concurrent close may free the still-owned worker engine")
        barrier.release()
        for closer in closers {
            let returned = await occurrenceWait(closer.completed, deadline: .now() + .seconds(3))
            try requireOccurrence(returned, "Concurrent close did not finish")
        }
        await task.value
        fixture.engine.close()
        try await expectOccurrenceFailure(.engineClosed) {
            try await fixture.engine.countExactTokenOccurrences(request: .init(query: "משה"), expectedSource: source)
        }
        do {
            _ = try fixture.engine.documentCount()
            throw OccurrenceTestFailure(description: "Legacy closed engine unexpectedly remained usable")
        } catch OtzariaSearchError.engineNotAvailable {}
        let reopened = try OtzariaSearchEngineBridge(indexURL: fixture.directory.appendingPathComponent("index"))
        defer { reopened.close() }
        let count = try reopened.documentCount()
        try requireOccurrence(count == 1, "Concurrent close/free corrupted original index")
        try barrier.assertDidNotTimeOut()
    }

    static func ownQueueClose() async throws {
        let fixture = try OccurrenceFixture()
        let closed = OccurrenceCloseObservation()
        fixture.engine.occurrenceTestEnqueue {
            fixture.engine.close(); closed.finish()
        }
        let returned = await occurrenceWait(closed.completed, deadline: .now() + .seconds(2))
        try requireOccurrence(returned, "close self-synchronized on its original engine queue")
        fixture.engine.close()
    }

    static func finalRetainOnOwnQueue(_ source: OtzariaExactOccurrenceSource) async throws {
        let directory = try OccurrenceFixtureRegistry.shared.makeDirectory()
        var owner: OtzariaSearchEngineBridge? = try .init(indexURL: directory.appendingPathComponent("index"))
        try owner!.addTextBook(title: "final retain", topics: "/fixtures", filePath: "otzaria-book:1",
                               catalogueOrder: 1, generationOrder: 5, text: "משה משה")
        try owner!.commit()
        let weakOwner = WeakOccurrenceEngine(owner!)
        let barrier = OccurrenceQueueBarrier()
        owner!.occurrenceTestAfterCount { barrier.block() }
        defer { barrier.release(); owner?.close() }
        var running: (Task<Void, Never>, OccurrenceObservation)? = launchOccurrence(
            engine: owner!, request: try .init(query: "משה", timeoutMs: 60_000), source: source
        )
        let observed = running!.1
        try await waitEntered(barrier)
        running!.0.cancel()
        let prompt = await occurrenceWait(observed.completed, deadline: .now() + .milliseconds(500))
        try requireOccurrence(prompt, "Final-retain task cancellation did not return")
        try observed.requireFailure(.cancelled)
        await running!.0.value
        running = nil
        owner = nil
        try requireOccurrence(!weakOwner.isGone, "In-flight original worker lost its engine owner")
        barrier.release()
        try await occurrenceEventually(deadline: .now() + .seconds(3)) { weakOwner.isGone }
        // Successful reopening also establishes that deinit completed the real
        // engine free/writer-lock release, not merely that a weak ref was zeroed.
        let reopened = try OtzariaSearchEngineBridge(indexURL: directory.appendingPathComponent("index"))
        defer { reopened.close() }
        let count = try reopened.documentCount()
        try requireOccurrence(count == 1, "Final owner release did not preserve original index")
        try barrier.assertDidNotTimeOut()
    }

    static func timerDoesNotRetainOwner(_ source: OtzariaExactOccurrenceSource) async throws {
        for _ in 0..<128 {
            var owner: OtzariaExactOccurrenceOperation? = try .create(
                request: .init(query: "משה", timeoutMs: 60_000),
                expectedSource: source, deadline: .now() + .seconds(60)
            )
            weak var observed = owner
            owner!.startDeadlineTimer()
            owner = nil
            try requireOccurrence(observed == nil, "Deadline timer formed a retained owner cycle")
        }
        let fixture = try OccurrenceFixture()
        let count = try await fixture.engine.countExactTokenOccurrences(
            request: .init(query: "משה"), expectedSource: source
        )
        try requireOccurrence(count.occurrences == 2, "Timer owner teardown leaked bounded C capacity")
    }
}
