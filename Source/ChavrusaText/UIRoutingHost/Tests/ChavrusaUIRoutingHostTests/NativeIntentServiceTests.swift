import Foundation
import XCTest
import OtzariaActionCore
import OtzariaUIRouting
@testable import ChavrusaUIRoutingHost

@MainActor final class NativeIntentServiceTests: XCTestCase, @unchecked Sendable {
    func testRootAndComponentEntitiesRemainDistinctAndRetainOriginalRootID() async throws {
        let root = NativeIntentService.Destination(backend: .otzaria, destination: UIDestinationID(rawValue: "native.search")!,
            title: "Search", sceneID: UIStableID(rawValue: "scene.A")!)
        let component = NativeIntentService.Destination(backend: .otzaria, destination: root.destination,
            title: "Search field", sceneID: root.sceneID, component: UIDestinationID(rawValue: "native.search.query")!)
        let state = IntentTestState()
        let service = NativeIntentService(discover: { [root, component] }, navigate: { target in
            state.selectedScene = target.sceneID; state.selectedComponent = target.component
            return .requiresForeground
        })
        XCTAssertEqual(root.id, "otzaria:scene.A:native.search")
        XCTAssertNotEqual(root.id, component.id)
        let matches = try await service.destinations(matching: "Search field")
        XCTAssertEqual(matches, [component])
        _ = try await service.open(identifier: component.id)
        XCTAssertEqual(state.selectedScene, root.sceneID)
        XCTAssertEqual(state.selectedComponent, component.component)
    }

    func testUnavailableComponentEntityCannotReuseVisibleRootAuthority() async throws {
        let root = NativeIntentService.Destination(backend: .otzaria, destination: UIDestinationID(rawValue: "native.search")!,
            title: "Search", sceneID: UIStableID(rawValue: "scene.A")!)
        let component = NativeIntentService.Destination(backend: .otzaria, destination: root.destination,
            title: "Search field", sceneID: root.sceneID, component: UIDestinationID(rawValue: "native.search.query")!)
        let state = IntentTestState()
        let service = NativeIntentService(discover: { state.available ? [root, component] : [root] },
            navigate: { target in state.calls += 1; state.selectedComponent = target.component; return .requiresForeground })
        let cached = try await service.destinations(identifiers: [component.id])
        XCTAssertEqual(cached, [component])
        state.available = false
        do { _ = try await service.open(identifier: component.id); XCTFail("A visible root does not authorize a missing control") }
        catch { XCTAssertEqual((error as? UIRouteError)?.code, "intent_entity_no_longer_available") }
        XCTAssertEqual(state.calls, 0)
        _ = try await service.open(identifier: root.id)
        XCTAssertEqual(state.calls, 1); XCTAssertNil(state.selectedComponent)
    }

    func testBackendQualifiedEntitiesRemainDistinctAndQueryUsesActualCatalog() async throws {
        let id = UIDestinationID(rawValue: "native.history")!
        let service = NativeIntentService(discover: { [
            .init(backend: .otzaria, destination: id, title: "History", sceneID: UIStableID(rawValue: "scene.A")!),
            .init(backend: .sefaria, destination: id, title: "History", sceneID: UIStableID(rawValue: "scene.A")!)
        ] }, navigate: { _ in .requiresForeground })
        let values = try await service.destinations(matching: "hist")
        XCTAssertEqual(values.count, 2); XCTAssertNotEqual(values[0].id, values[1].id)
        let selected = try await service.destinations(identifiers: [values[1].id]); XCTAssertEqual(selected, [values[1]])
    }
    func testStaleEntityFailsBeforeNavigationAndQueuedIsNeverAcknowledged() async throws {
        let state = IntentTestState(), id = UIDestinationID(rawValue: "native.history")!
        let service = NativeIntentService(discover: { state.available ? [.init(backend: .otzaria, destination: id, title: "History", sceneID: UIStableID(rawValue: "scene.A")!)] : [] },
            navigate: { _ in state.calls += 1; return .queued(handle: "pending_native") })
        let entity = try await service.destinations()[0]
        let result = try await service.open(identifier: entity.id)
        XCTAssertEqual(result, .queued(handle: "pending_native")); XCTAssertEqual(state.calls, 1)
        state.available = false
        do { _ = try await service.open(identifier: entity.id); XCTFail("stale entity") }
        catch { XCTAssertEqual((error as? UIRouteError)?.status, .staleState) }
        XCTAssertEqual(state.calls, 1)
    }
    func testDuplicateLiveEntitiesFailClosed() async throws {
        let value = NativeIntentService.Destination(backend: .otzaria, destination: UIDestinationID(rawValue: "native.history")!, title: "History", sceneID: UIStableID(rawValue: "scene.A")!)
        let service = NativeIntentService(discover: { [value, value] }, navigate: { _ in .requiresForeground })
        do { _ = try await service.destinations(); XCTFail("duplicate catalog") }
        catch { XCTAssertEqual((error as? UIRouteError)?.code, "invalid_live_intent_catalog") }
    }
    func testNoncompletionStatusesRemainDistinctSystemIntentErrors() async throws {
        let failure = ActionFailure(code: "native_not_ready", message: "Safe native error")
        let values: [(UISceneAcknowledgement, ActionStatus)] = [
            (.queued(handle: "pending_native"), .uiQueued), (.requiresForeground, .requiresForeground),
            (.requiresBackendSwitch(.sefaria), .requiresBackendSwitch), (.staleState(failure), .staleState),
            (.notSupported(failure), .notSupported), (.cancelled, .cancelled)
        ]
        for (value, expected) in values {
            do { try NativeIntentOutcome.requireVisibleAcknowledgement(value); XCTFail("noncompletion became success") }
            catch { XCTAssertEqual((error as? NativeIntentOutcome)?.status, expected) }
        }
    }
    func testSameBackendDestinationsBindExactUserSelectedWindow() async throws {
        let destination = UIDestinationID(rawValue: "native.history")!, state = IntentTestState()
        let a = NativeIntentService.Destination(backend: .otzaria, destination: destination, title: "History A", sceneID: UIStableID(rawValue: "scene.A")!)
        let b = NativeIntentService.Destination(backend: .otzaria, destination: destination, title: "History B", sceneID: UIStableID(rawValue: "scene.B")!)
        let service = NativeIntentService(discover: { [a, b] }, navigate: { target in
            state.selectedScene = target.sceneID; return .requiresForeground
        })
        XCTAssertNotEqual(a.id, b.id)
        _ = try await service.open(identifier: b.id)
        XCTAssertEqual(state.selectedScene, b.sceneID)
    }

    func testBackgroundIdentityResolvesButOnlyFreshForegroundDiscoveryCanNavigate() async throws {
        let state = IntentTestState(); state.available = false
        let root = NativeIntentService.Destination(backend: .otzaria,
            destination: UIDestinationID(rawValue: "native.search")!, title: "Search",
            sceneID: UIStableID(rawValue: "scene.A")!)
        let service = NativeIntentService(discover: { state.available ? [root] : [] },
            resolveEntities: { [root] }, navigate: { target in
                state.calls += 1; state.selectedScene = target.sceneID; return .requiresForeground
            })
        let named = try await service.destinations(matching: "Search")
        let exact = try await service.destinations(identifiers: [root.id])
        XCTAssertEqual(named, [root]); XCTAssertEqual(exact, [root])
        XCTAssertEqual(state.calls, 0)
        do { _ = try await service.open(identifier: root.id); XCTFail("Metadata is not foreground authority") }
        catch { XCTAssertEqual((error as? UIRouteError)?.code, "intent_entity_no_longer_available") }
        XCTAssertEqual(state.calls, 0)
        state.available = true
        _ = try await service.open(identifier: root.id)
        XCTAssertEqual(state.calls, 1); XCTAssertEqual(state.selectedScene, root.sceneID)
    }

    func testRemovedWindowIsOmittedAndCannotBeRecreatedFromCachedEntity() async throws {
        let state = IntentTestState()
        let root = NativeIntentService.Destination(backend: .otzaria,
            destination: UIDestinationID(rawValue: "native.library")!, title: "Library",
            sceneID: UIStableID(rawValue: "scene.A")!)
        let service = NativeIntentService(discover: { state.available ? [root] : [] },
            resolveEntities: { state.available ? [root] : [] },
            navigate: { _ in state.calls += 1; return .requiresForeground })
        let initial = try await service.destinations(identifiers: [root.id]); XCTAssertEqual(initial, [root])
        state.available = false
        let removed = try await service.destinations(identifiers: [root.id]); XCTAssertTrue(removed.isEmpty)
        do { _ = try await service.open(identifier: root.id); XCTFail("No recreation or first-window fallback") }
        catch { XCTAssertEqual((error as? UIRouteError)?.status, .staleState) }
        XCTAssertEqual(state.calls, 0)
    }

    func testResolvedMetadataCannotBorrowAnotherBackendOrWindow() async throws {
        let state = IntentTestState(), destination = UIDestinationID(rawValue: "native.library")!
        let cached = NativeIntentService.Destination(backend: .otzaria, destination: destination,
            title: "Library", sceneID: UIStableID(rawValue: "scene.A")!)
        let changedBackend = NativeIntentService.Destination(backend: .sefaria, destination: destination,
            title: "Library", sceneID: cached.sceneID)
        let otherWindow = NativeIntentService.Destination(backend: .otzaria, destination: destination,
            title: "Library", sceneID: UIStableID(rawValue: "scene.B")!)
        let service = NativeIntentService(discover: { [changedBackend, otherWindow] },
            resolveEntities: { [cached] }, navigate: { _ in state.calls += 1; return .requiresForeground })
        let identities = try await service.destinations(identifiers: [cached.id]); XCTAssertEqual(identities, [cached])
        do { _ = try await service.open(identifier: cached.id); XCTFail("Metadata cannot choose a replacement") }
        catch { XCTAssertEqual((error as? UIRouteError)?.status, .staleState) }
        XCTAssertEqual(state.calls, 0)
    }

    func testDuplicateExecutionCatalogFailsDespiteUniqueResolvedMetadata() async throws {
        let state = IntentTestState()
        let root = NativeIntentService.Destination(backend: .otzaria,
            destination: UIDestinationID(rawValue: "native.search")!, title: "Search",
            sceneID: UIStableID(rawValue: "scene.A")!)
        let service = NativeIntentService(discover: { [root, root] }, resolveEntities: { [root] },
            navigate: { _ in state.calls += 1; return .requiresForeground })
        let identities = try await service.destinations(); XCTAssertEqual(identities, [root])
        do { _ = try await service.open(identifier: root.id); XCTFail("Invalid live catalog") }
        catch { XCTAssertEqual((error as? UIRouteError)?.code, "invalid_live_intent_catalog") }
        XCTAssertEqual(state.calls, 0)
    }
    func testForegroundWaitUsesExactResolvedIdentityBeforeFreshExecutionDiscovery() async throws {
        let state = IntentTestState(); state.available = false
        let root = NativeIntentService.Destination(backend: .otzaria,
            destination: UIDestinationID(rawValue: "native.search")!, title: "Search",
            sceneID: UIStableID(rawValue: "scene.A")!)
        let service = NativeIntentService(discover: { state.available ? [root] : [] },
            resolveEntities: { [root] }, awaitForeground: { selected in
                XCTAssertEqual(selected, root)
                XCTAssertEqual(state.calls, 0, "Lifecycle waiting cannot navigate or issue a receipt")
                state.prepared += 1; state.available = true
            }, navigate: { selected in
                XCTAssertEqual(state.prepared, 1)
                state.calls += 1; state.selectedScene = selected.sceneID
                return .requiresForeground
            })
        _ = try await service.open(identifier: root.id)
        XCTAssertEqual(state.prepared, 1); XCTAssertEqual(state.calls, 1)
        XCTAssertEqual(state.selectedScene, root.sceneID)
    }

    func testForegroundWaitDoesNotTurnMetadataIntoExecutionAuthority() async throws {
        let state = IntentTestState()
        let root = NativeIntentService.Destination(backend: .otzaria,
            destination: UIDestinationID(rawValue: "native.search")!, title: "Search",
            sceneID: UIStableID(rawValue: "scene.A")!)
        let service = NativeIntentService(discover: { [] }, resolveEntities: { [root] },
            awaitForeground: { _ in state.prepared += 1 },
            navigate: { _ in state.calls += 1; return .requiresForeground })
        do { _ = try await service.open(identifier: root.id); XCTFail("Fresh foreground catalog is still required") }
        catch { XCTAssertEqual((error as? UIRouteError)?.code, "intent_entity_no_longer_available") }
        XCTAssertEqual(state.prepared, 1); XCTAssertEqual(state.calls, 0)
    }

    func testChangedWindowDuringForegroundWaitCannotSubstituteAnotherScene() async throws {
        let state = IntentTestState()
        let root = NativeIntentService.Destination(backend: .otzaria,
            destination: UIDestinationID(rawValue: "native.search")!, title: "Search",
            sceneID: UIStableID(rawValue: "scene.A")!)
        let replacement = NativeIntentService.Destination(backend: .otzaria, destination: root.destination,
            title: "Search", sceneID: UIStableID(rawValue: "scene.B")!)
        let service = NativeIntentService(discover: { [replacement] }, resolveEntities: { [root] },
            awaitForeground: { selected in XCTAssertEqual(selected, root); state.prepared += 1 },
            navigate: { _ in state.calls += 1; return .requiresForeground })
        do { _ = try await service.open(identifier: root.id); XCTFail("Never pick another foreground window") }
        catch { XCTAssertEqual((error as? UIRouteError)?.status, .staleState) }
        XCTAssertEqual(state.calls, 0)
    }

    func testUnknownEntityCannotRequestForegroundPreparation() async throws {
        let state = IntentTestState()
        let service = NativeIntentService(discover: { [] }, resolveEntities: { [] },
            awaitForeground: { _ in state.prepared += 1 },
            navigate: { _ in state.calls += 1; return .requiresForeground })
        do { _ = try await service.open(identifier: "otzaria:scene.missing:native.search"); XCTFail("Unknown scene") }
        catch { XCTAssertEqual((error as? UIRouteError)?.status, .staleState) }
        XCTAssertEqual(state.prepared, 0); XCTAssertEqual(state.calls, 0)
    }

    func testCancelledForegroundWaitCannotNavigate() async throws {
        let state = IntentTestState()
        let root = NativeIntentService.Destination(backend: .otzaria,
            destination: UIDestinationID(rawValue: "native.search")!, title: "Search",
            sceneID: UIStableID(rawValue: "scene.A")!)
        let service = NativeIntentService(discover: { [root] }, resolveEntities: { [root] },
            awaitForeground: { _ in throw CancellationError() },
            navigate: { _ in state.calls += 1; return .requiresForeground })
        do { _ = try await service.open(identifier: root.id); XCTFail("Cancellation must stop before admission") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(state.calls, 0)
    }

}
@MainActor private final class IntentTestState { var available = true; var prepared = 0; var calls = 0; var selectedScene: UIStableID?; var selectedComponent: UIDestinationID? }
