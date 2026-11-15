import Foundation
import XCTest
import OtzariaActionCore
import OtzariaUIRouting
@testable import ChavrusaUIRoutingHost

final class NativeSurfaceStateTests: XCTestCase {
    private func command() throws -> UISceneCommand {
        let id = UIStableID(rawValue: "scene.A")!, backend = ActionBackendSnapshot(backend: .otzaria, generation: 7)
        let route = RouteSpec(destination: UIDestinationID(rawValue: "fixture.settings")!, backend: .otzaria,
                              presentation: .init(kind: .sheet), focus: .init(kind: .component, anchor: UIDestinationID(rawValue: "fixture.settings.language")!),
                              scene: .init(kind: .specific, sceneID: id, expectedRevision: 10), expectedBackendSnapshot: backend)
        return try UISceneCommand(route: UIDestinationRegistry.fixtures().validate(route),
            invocation: .init(requestId: route.requestId, snapshot: backend, deadlineUptimeNanoseconds: UInt64.max),
            scene: .init(sceneID: id, revision: 10, backendSnapshot: backend))
    }
    private func validate(_ state: NativeSurfaceState, command: UISceneCommand) throws {
        let route = state.observedRoute(for: command, backend: command.invocation.snapshot)
        let receipt = UISceneReceipt(requestId: command.invocation.requestId, route: route, backendSnapshot: command.invocation.snapshot,
                                     sceneID: command.scene.sceneID, basedOnSceneRevision: 10, appliedSceneRevision: 11)
        try receipt.validate(for: command, observed: .init(sceneID: command.scene.sceneID, revision: 11,
            backendSnapshot: command.invocation.snapshot, visibleRoute: route))
    }
    func testMatchingNativeProjectionUsesOnlyTransportMetadataFromRequest() throws {
        let command = try command(), route = command.route.route
        let state = NativeSurfaceState(destination: route.destination, presentation: route.presentation, content: nil, state: .init(), focus: route.focus)
        try validate(state, command: command)
        XCTAssertEqual(state.observedRoute(for: command, backend: command.invocation.snapshot), route)
    }
    func testSameRequestWithWrongNativeDestinationPresentationOrFocusCannotAcknowledge() throws {
        let command = try command(), route = command.route.route
        for state in [
            NativeSurfaceState(destination: UIDestinationID(rawValue: "fixture.reader")!, presentation: route.presentation, content: nil, state: .init(), focus: route.focus),
            NativeSurfaceState(destination: route.destination, presentation: .init(kind: .currentTab), content: nil, state: .init(), focus: route.focus),
            NativeSurfaceState(destination: route.destination, presentation: route.presentation, content: nil, state: .init(), focus: nil),
            NativeSurfaceState(destination: route.destination, presentation: route.presentation, content: nil,
                               state: .init(selectedItemID: UIStableID(rawValue: "different-item")!), focus: route.focus)
        ] { XCTAssertThrowsError(try validate(state, command: command)) }
    }
}
