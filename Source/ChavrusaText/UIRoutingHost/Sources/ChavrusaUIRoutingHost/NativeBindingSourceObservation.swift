import Observation

/// Future binding adapter's synchronous invalidation trigger, not an authority
/// or a mapping cache. Keep ONE observer per fixed real source owner, rather
/// than registering one per request. Native source mutations MUST be MainActor
/// isolated (as StudyWorkspaceStore.snapshot is). The read must track that fixed
/// owner's observable stored revision/snapshot, not a constant or desired state.
/// A broad checkpoint/render revision is NOT a mapping epoch: the native owner
/// must distinguish invalidation from its own permitted presentation/reservation
/// transition before wiring this trigger. This helper does not classify writes.
///
/// Observation calls onChange during the setter, before its return. Invalidation
/// must only revoke the existing admitted native authority/local reservations;
/// it must not mutate this source. Rearming tracks the same fixed property, so
/// it needs no Task/actor hop or reread of the pending new value. There is no
/// async/coalesced onChange window. A nil revision is unavailable source state,
/// never permission or an observed-absent binding; the binding port must refuse
/// unavailable observations independently.
@MainActor
public final class NativeBindingSourceObservation {
    private let readRevision: @MainActor () -> UInt64?
    private let invalidate: @MainActor () -> Void
    private var cancelled = false

    public init(readRevision: @escaping @MainActor () -> UInt64?, onInvalidation: @escaping @MainActor () -> Void) {
        self.readRevision = readRevision; invalidate = onInvalidation
        arm()
    }

    /// Cancels this owner lifetime. The one remaining tracking callback captures
    /// self weakly, performs no later invalidation and does not rearm. No task,
    /// continuation or strong source→observer retain cycle survives teardown.
    public func cancel() { cancelled = true }

    private func arm() {
        guard !cancelled else { return }
        withObservationTracking { _ = readRevision() } onChange: { [weak self] in
            // The fixed source contract requires MainActor-isolated setters;
            // invalidation must occur synchronously on that same executor.
            MainActor.assumeIsolated {
                guard let self, !self.cancelled else { return }
                self.invalidate()
                self.arm()
            }
        }
    }
}
