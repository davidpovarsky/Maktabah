import Observation
import Synchronization
import OtzariaUIRouting

/// Passive publication from an ORIGINAL MainActor setter. There is no value,
/// observer callback, authority, reset or rearm here. All retained records are
/// invalidated before that setter continues; the JS thread only sees the
/// existing thread-safe one-way latch and never calls back to this owner.
@MainActor
public final class NativeComponentSourcePublication {
    private struct Retained { weak var value: NativeComponentSourceObservation? }
    private var retained: [Retained] = []

    public init() {}

    fileprivate func register(_ observation: NativeComponentSourceObservation) {
        retained.removeAll { $0.value == nil }
        guard !retained.contains(where: { $0.value === observation }) else { return }
        retained.append(.init(value: observation))
    }

    public func invalidateRetainedSources() {
        let original = retained
        retained.removeAll(keepingCapacity: true)
        // invalidate() only takes its own Boolean lock. It cannot execute an
        // arbitrary observer or reenter the ORIGINAL setter/counter.
        for item in original { item.value?.invalidate() }
    }
}

/// A one-shot cancellation witness over ORIGINAL observable source reads.
/// Restoring the same values cannot restore a captured request. This is not a
/// source cache or an authority; the original identity/generation checks remain.
public final class NativeComponentSourceObservation: Sendable {
    private let invalidated = Mutex(false)

    @MainActor
    public init(publications: [NativeComponentSourcePublication] = [], read: @MainActor () -> Void) {
        // Registration precedes every original getter. A source publication
        // reentering a read therefore retires this exact observation too.
        for publication in publications { publication.register(self) }
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

    /// A source-locked final Boolean claim for the private RN handoff. The only
    /// application caller nests fixed one-way source latches and consumes its
    /// fixed ticket; it does not run UIKit, JS, actor work or a user callback.
    /// There is deliberately no reset or observation refresh in this operation.
    public func claimIfCurrent(_ claim: () -> Bool) -> Bool {
        invalidated.withLock { retired in
            guard !retired else { return false }
            return claim()
        }
    }
}
