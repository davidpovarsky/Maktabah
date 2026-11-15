import Foundation
import OtzariaActionCore
import OtzariaUIRouting

/// Structured cooperative observation lifetime. Both children are joined and
/// cancelled on exit. Native/Core ports must cooperate; admission stays occupied
/// until they actually finish, so timeouts cannot create unlimited hidden work.
public enum NativeObservationDeadline {
    public static func run<T: Sendable>(until deadline: UInt64, clock: any ActionClock,
                                 operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await clock.sleep(until: deadline)
                try Task.checkCancellation()
                throw UIRouteError(.cancelled, "deadline_exceeded")
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else { throw CancellationError() }
            return result
        }
    }
}
