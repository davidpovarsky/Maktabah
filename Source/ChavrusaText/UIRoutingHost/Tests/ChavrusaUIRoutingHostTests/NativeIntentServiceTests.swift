import Foundation
import XCTest
import OtzariaActionCore
import OtzariaUIRouting
@testable import ChavrusaUIRoutingHost

@MainActor final class NativeIntentServiceTests: XCTestCase, @unchecked Sendable {
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
}
@MainActor private final class IntentTestState { var available = true; var calls = 0; var selectedScene: UIStableID? }
