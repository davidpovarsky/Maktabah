#if os(iOS)
import Foundation
import OtzariaUIRouting
import ChavrusaUIRoutingHost

/// Passive lifetime of an ORIGINAL annotations model or collection publication.
/// It owns no annotation, database, filter, selection or navigation authority.
/// Equal input publications and A -> B -> A retire existing witnesses forever.
@MainActor final class MaktabahNativeAnnotationListPublication {
    final class Witness {
        nonisolated let invalidation: NativeComponentSourceObservation
        private weak var owner: MaktabahNativeAnnotationListPublication?
        private let revision: UInt64
        fileprivate init(owner: MaktabahNativeAnnotationListPublication, revision: UInt64) {
            self.owner = owner; self.revision = revision
            invalidation = NativeComponentSourceObservation(read: {})
        }
        func validate() throws {
            try invalidation.validate()
            guard let owner, owner.revision == revision, !owner.searchPending else {
                throw UIRouteError(.staleState, "native_annotation_publication_changed")
            }
        }
    }
    private final class WeakWitness {
        weak var value: Witness?
        init(_ value: Witness) { self.value = value }
    }
    private(set) var revision: UInt64? = 0
    private var witnesses: [WeakWitness] = []
    private var search: UUID?
    var searchPending: Bool { search != nil }

    /// Called BEFORE an original mutation. Fixed one-way invalidation invokes
    /// no observer, external callback, UIKit operation or feature setter.
    func willPublish() {
        let current = witnesses
        witnesses.removeAll()
        for witness in current { witness.value?.invalidation.invalidate() }
        if let revision, revision < .max { self.revision = revision + 1 }
        else { revision = nil }
    }

    func beginOriginalSearch() -> UUID {
        willPublish()
        let token = UUID(); search = token
        return token
    }

    /// An old cancelled task may drain after a newer original search began.
    /// Only the exact latest task can settle this passive readiness flag.
    func finishOriginalSearch(_ token: UUID) {
        guard search == token else { return }
        willPublish(); search = nil
    }

    func capture() throws -> Witness {
        guard let revision, !searchPending else {
            throw UIRouteError(.unavailable, "native_annotation_source_not_settled")
        }
        witnesses.removeAll { $0.value == nil }
        guard witnesses.count < 64 else {
            throw UIRouteError(.unavailable, "native_annotation_observation_busy")
        }
        let witness = Witness(owner: self, revision: revision)
        witnesses.append(WeakWitness(witness))
        try witness.validate()
        return witness
    }
}
#endif
