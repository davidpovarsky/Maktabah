import Foundation
import OtzariaActionCore

@MainActor private final class FixtureResourceSource {
    var databaseGeneration: UInt64 = 10
    var revision: UInt64 = 0
    func current() -> BackendCoordinator.ResourceWitness {
        .init(databaseGeneration: databaseGeneration, searchRevision: revision,
            profileID: "fixture", databasePath: "isolated-fixture.db", searchFingerprint: Data("same-final-bytes".utf8))
    }
}

extension IntegrationAcceptance {
    @MainActor static func resourceChecks(coordinator: BackendCoordinator, provider: BridgeFixtureProvider) async throws {
        coordinator.select(.otzaria)
        let selected = coordinator.activeBackendID
        let committed = coordinator.committedBackendID
        let source = FixtureResourceSource()
        let facade = ActionBackendCoordinatorFacade(coordinator: coordinator, resourceWitness: { source.current() },
            readiness: { .init(snapshot: $0, catalog: .ready, references: .ready, search: .ready) })
        let original = try facade.currentBackendSnapshot()
        check(original.generation == coordinator.generation, "resource snapshot uses only canonical coordinator generation")
        check(try facade.currentBackendSnapshot() == original, "unchanged actual source witness does not invent generations")
        source.revision += 2 // supported source invalidations A -> B -> A
        let afterABA = try facade.currentBackendSnapshot()
        check(afterABA.generation > original.generation && afterABA.backend == original.backend,
            "ABA source revision invalidates old work without switching backend")
        let query = ActionSearchQuery(backend: .otzaria, text: "fixture")
        let stale = ActionPortInvocation(requestId: UUID(), snapshot: original,
            deadlineUptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + 5_000_000_000)
        do { _ = try await facade.search(query, invocation: stale); fatalError("pre-replacement invocation accepted") }
        catch { check(true, "resource replacement before action start rejects captured snapshot") }
        let pendingInvocation = try await invocation(facade)
        await provider.beginHold()
        let pending = Task { try await facade.search(query, invocation: pendingInvocation) }
        await provider.waitForStart()
        source.databaseGeneration += 1
        let changed = try facade.currentBackendSnapshot()
        check(changed.generation > pendingInvocation.snapshot.generation, "DB replacement advances canonical generation during provider await")
        await provider.release()
        do { _ = try await pending.value; fatalError("cross-resource search result committed") }
        catch { check(true, "in-flight captured work is cancelled/rejected after resource drift") }
        check(coordinator.activeBackendID == selected && coordinator.committedBackendID == committed,
            "resource invalidation preserves backend selection and persisted defaults")
        let stable = try await facade.snapshot()
        check(stable == (try facade.currentBackendSnapshot()) && stable.generation == coordinator.generation,
            "async and synchronous snapshots observe the SAME canonical resource generation")
    }
}
