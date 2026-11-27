import Foundation
typealias MaktabahNativeComponentDescriptor = NativeComponentDescriptor
typealias MaktabahNativeComponentOwner = NativeComponentRevealOwner
@MainActor final class MaktabahNativeComponentSourceObservation {
    private let observation: NativeComponentSourceObservation
    private let coordinator: BackendCoordinator
    private let backend: BackendID
    private let generation: UInt64
    private let backendChanges: AnyCancellable

    init(read: @MainActor () -> Void) {
        let coordinator = BackendCoordinator.shared
        let observation = NativeComponentSourceObservation(read: read)
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
}
