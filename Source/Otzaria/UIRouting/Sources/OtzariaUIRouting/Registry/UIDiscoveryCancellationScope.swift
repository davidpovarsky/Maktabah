import Foundation
import OtzariaActionCore

/// Structured composition only: one discovery operation and one deadline wait.
/// Timely return/cleanup requires cancellation-cooperative participating ports.
/// This does not interrupt an uncooperative await or supply admission/worker
/// bounds. No detached task, business execution, authorization or retained work.
enum UIDiscoveryCancellationScope {
    static func run<Value: Sendable>(until deadline: UInt64, clock: any ActionClock,
        operation: @escaping @Sendable () async throws -> Value) async throws -> Value {
        try Task.checkCancellation()
        guard clock.now() < deadline else { throw UIRouteError(.cancelled, "deadline_exceeded") }
        return try await withThrowingTaskGroup(of: Value.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await clock.sleep(until: deadline)
                try Task.checkCancellation()
                throw UIRouteError(.cancelled, "deadline_exceeded")
            }
            defer { group.cancelAll() }
            guard let value = try await group.next() else { throw CancellationError() }
            try Task.checkCancellation()
            guard clock.now() < deadline else { throw UIRouteError(.cancelled, "deadline_exceeded") }
            return value
        }
    }
}
