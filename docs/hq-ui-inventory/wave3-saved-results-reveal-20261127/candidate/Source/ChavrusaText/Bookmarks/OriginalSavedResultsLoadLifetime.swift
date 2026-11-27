import Foundation
import Observation

/// Passive metadata for the ORIGINAL ResultsViewModel loads. A load continues
/// unchanged when this observer is exhausted; only native cached references
/// become unavailable. No database, task, UI action or navigation grant lives
/// here. A completed reload can never restore an older source revision.
@Observable @MainActor
final class OriginalSavedResultsLoadLifetime {
    final class Load {
        fileprivate weak var owner: OriginalSavedResultsLoadLifetime?
        fileprivate let id = UUID()
        fileprivate var admitted = false
        fileprivate var ended = false
        fileprivate init(owner: OriginalSavedResultsLoadLifetime) { self.owner = owner }
    }

    private(set) var revision: UInt64?
    private(set) var lastCompletionWasCancelled = false
    @ObservationIgnored private var active: [UUID: Load] = [:]
    @ObservationIgnored private var publishing = false
    @ObservationIgnored private var retired = false

    init(initialRevision: UInt64 = 0) { revision = initialRevision }

    /// A nil value means a real original reload/publication is in progress, or
    /// the finite metadata lifetime has been exhausted. It is never a grant.
    var settledRevision: UInt64? {
        guard !retired, !publishing, active.isEmpty else { return nil }
        return revision
    }

    func beginOriginalLoad() -> Load {
        let load = Load(owner: self)
        guard !retired, !publishing, revision != nil, active.count < 128 else {
            retireMetadata()
            return load
        }
        publishing = true
        defer { publishing = false }
        advance()
        guard !retired, revision != nil else { return load }
        load.admitted = true
        active[load.id] = load
        return load
    }

    func endOriginalLoad(_ load: Load, cancelled: Bool) {
        guard load.owner === self else { retireMetadata(); return }
        // A load admitted after exhaustion does not acquire an active slot.
        guard load.admitted else { return }
        guard !publishing, !load.ended, active[load.id] === load else {
            retireMetadata()
            return
        }
        publishing = true
        defer { publishing = false }
        // Consume before Observation can synchronously re-enter this owner.
        load.ended = true
        active.removeValue(forKey: load.id)
        advance()
        lastCompletionWasCancelled = cancelled
    }

    func isCurrent(_ expected: UInt64) -> Bool { settledRevision == expected }

    private func advance() {
        guard !retired, let current = revision, current < .max else {
            retireMetadata()
            return
        }
        revision = current + 1
        // Observation invokes willSet callbacks synchronously. A nested retire
        // must survive the outer observed property's eventual assignment.
        if retired { revision = nil }
    }

    private func retireMetadata() {
        // Reentrant invalidation does not reopen an outer transition.
        guard !retired else { return }
        retired = true
        revision = nil
    }
}
