import Foundation
import ChavrusaUIRoutingHost
import OtzariaUIRouting

typealias MaktabahNativeComponentDescriptor = NativeComponentDescriptor
typealias MaktabahNativeComponentOwner = NativeComponentRevealOwner

/// Application lifetime bridge for the actual backend publisher and original
/// @Observable feature fields. The portable one-shot latch never changes a
/// coordinator, feature value, canonical route, grant or source generation.
@MainActor final class MaktabahNativeComponentSourceObservation {
    nonisolated private let observation: NativeComponentSourceObservation
    private let coordinator: BackendCoordinator
    private let backend: BackendID
    private let generation: UInt64
    private let backendChanges: AnyCancellable

    init(publications: [NativeComponentSourcePublication] = [], read: @MainActor () -> Void) {
        let coordinator = BackendCoordinator.shared
        let observation = NativeComponentSourceObservation(publications: publications, read: read)
        self.coordinator = coordinator
        self.observation = observation
        backend = coordinator.activeBackendID
        generation = coordinator.generation
        backendChanges = coordinator.objectWillChange.sink { _ in
            observation.invalidate()
        }
    }

    func validate() throws {
        try observation.validate()
        guard BackendCoordinator.shared === coordinator, !coordinator.isTransitioning,
              coordinator.activeBackendID == backend, coordinator.generation == generation else {
            throw UIRouteError(.staleState, "native_component_backend_changed")
        }
    }

    /// The exact pre-await latch, including its ORIGINAL backend publisher.
    /// Returning it neither captures a new source nor grants an operation.
    nonisolated var retainedClaimObservation: NativeComponentSourceObservation { observation }
    nonisolated func invalidate() { observation.invalidate() }
}

