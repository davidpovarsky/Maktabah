import Foundation
import Dispatch

public protocol ActionClock: Sendable {
    func now() -> UInt64
    func sleep(until deadline: UInt64) async throws
}
public struct SystemActionClock: ActionClock {
    public init() {}
    public func now() -> UInt64 { DispatchTime.now().uptimeNanoseconds }
    public func sleep(until deadline: UInt64) async throws {
        let current = now()
        if deadline > current { try await Task.sleep(nanoseconds: deadline - current) }
    }
}

/// Unlike a structured task-group race, returning does not wait indefinitely
/// for a provider which ignores cancellation. Ports must still cooperate; the
/// executor separately caps outstanding work until the worker really finishes.
private final class ActionRace<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, any Error>?
    private var result: Result<T, any Error>?
    private var tasks: [Task<Void, Never>] = []
    func install(_ continuation: CheckedContinuation<T, any Error>) {
        let done = lock.withLock { () -> Result<T, any Error>? in
            if let result { return result }
            self.continuation = continuation; return nil
        }
        if let done { continuation.resume(with: done) }
    }
    func track(_ tasks: [Task<Void, Never>]) {
        let cancel = lock.withLock { () -> Bool in
            if result != nil { return true }
            self.tasks = tasks; return false
        }
        if cancel { tasks.forEach { $0.cancel() } }
    }
    func finish(_ result: Result<T, any Error>) {
        let work = lock.withLock { () -> (CheckedContinuation<T, any Error>?, [Task<Void, Never>])? in
            guard self.result == nil else { return nil }
            self.result = result
            let work = (continuation, tasks); continuation = nil; tasks = []; return work
        }
        if let work { work.1.forEach { $0.cancel() }; work.0?.resume(with: result) }
    }
}

enum ActionDeadline {
    static func run<T: Sendable>(until deadline: UInt64, clock: any ActionClock,
        operation: @escaping @Sendable () async throws -> T, onWorkerFinished: @escaping @Sendable () async -> Void) async throws -> T {
        let race = ActionRace<T>()
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                race.install(continuation)
                let worker = Task {
                    do { try Task.checkCancellation(); race.finish(.success(try await operation())) }
                    catch { race.finish(.failure(error)) }
                    await onWorkerFinished()
                }
                let timer = Task {
                    do {
                        try await clock.sleep(until: deadline)
                        try Task.checkCancellation()
                        race.finish(.failure(ActionEngineFailure(.cancelled, "deadline_exceeded")))
                    } catch {}
                }
                race.track([worker, timer])
            }
        }, onCancel: { race.finish(.failure(CancellationError())) })
    }
}
