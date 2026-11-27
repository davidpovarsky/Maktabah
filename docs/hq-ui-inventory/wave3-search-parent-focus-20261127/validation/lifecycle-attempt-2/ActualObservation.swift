import Foundation
import Observation
import Synchronization

/// A one-shot cancellation witness over ORIGINAL observable source reads.
/// Restoring the same values cannot restore a captured request. This is not a
/// source cache or an authority; the original identity/generation checks remain.
public final class NativeComponentSourceObservation: Sendable {
    private let invalidated = Mutex(false)

    @MainActor
    public init(read: @MainActor () -> Void) {
        withObservationTracking {
            read()
        } onChange: { [weak self] in
            // Observation fires at willSet. Do not enqueue a Task: a complete
            // A -> B -> A edit can happen before a MainActor task resumes.
            self?.invalidate()
        }
    }

    /// Original non-Observation publishers may revoke this same latch. There is
    /// deliberately no reset, rearm or setter that can make a request live again.
    public func invalidate() {
        invalidated.withLock { $0 = true }
    }

    public func validate() throws {
        guard !invalidated.withLock({ $0 }) else {
            throw UIRouteError(.staleState, "native_component_source_changed")
        }
    }
}
