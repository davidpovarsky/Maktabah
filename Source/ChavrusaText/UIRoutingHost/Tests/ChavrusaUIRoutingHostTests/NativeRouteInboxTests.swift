import Foundation
import XCTest
import OtzariaActionCore
import OtzariaUIRouting
@testable import ChavrusaUIRoutingHost

@MainActor final class NativeRouteInboxTests: XCTestCase, @unchecked Sendable {
    private let scene = UIStableID(rawValue: "scene.A")!
    private let context = ActionExecutionContext(subjectID: "user", origin: .deepLink, allowedBackends: [.otzaria], scopes: [.navigation])
    private func route(requestID: UUID = UUID(), destination: String = "native.history") -> RouteSpec {
        .init(requestId: requestID, destination: UIDestinationID(rawValue: destination)!, backend: .otzaria)
    }
    func testReplayIsIdempotentButConflictingDestinationFails() async throws {
        let inbox = try NativeRouteInbox(), route = route(), lifetime = UUID()
        let first = try inbox.enqueue(route, sceneID: scene, sceneLifetime: lifetime, context: context, deadline: UInt64.max)
        let again = try inbox.enqueue(route, sceneID: scene, sceneLifetime: lifetime, context: context, deadline: UInt64.max)
        XCTAssertEqual(first, again); XCTAssertEqual(inbox.count, 1)
        XCTAssertThrowsError(try inbox.enqueue(self.route(requestID: route.requestId, destination: "native.settings"), sceneID: scene,
                                               sceneLifetime: lifetime, context: context, deadline: UInt64.max))
    }
    func testSameIDOtherSceneLifetimeCannotTakeOrReplace() async throws {
        let inbox = try NativeRouteInbox(), route = route(), lifetime = UUID()
        _ = try inbox.enqueue(route, sceneID: scene, sceneLifetime: lifetime, context: context, deadline: UInt64.max)
        XCTAssertThrowsError(try inbox.take(requestID: route.requestId, sceneID: scene, sceneLifetime: UUID(), context: context))
        XCTAssertEqual(inbox.count, 1)
        let value = try inbox.take(requestID: route.requestId, sceneID: scene, sceneLifetime: lifetime, context: context)
        XCTAssertEqual(value?.route, route); XCTAssertNil(try inbox.take(requestID: route.requestId, sceneID: scene, sceneLifetime: lifetime, context: context))
    }
    func testFiniteCapacityAndRevocationReleasePrivateState() async throws {
        let inbox = try NativeRouteInbox(capacity: 1), lifetime = UUID()
        _ = try inbox.enqueue(route(), sceneID: scene, sceneLifetime: lifetime, context: context, deadline: UInt64.max)
        XCTAssertThrowsError(try inbox.enqueue(route(), sceneID: scene, sceneLifetime: lifetime, context: context, deadline: UInt64.max))
        inbox.revoke(sceneID: scene, sceneLifetime: UUID()); XCTAssertEqual(inbox.count, 1)
        inbox.revoke(sceneID: scene, sceneLifetime: lifetime); XCTAssertEqual(inbox.count, 0)
    }
    func testCancellationBoundToSubject() async throws {
        let inbox = try NativeRouteInbox(), route = route()
        _ = try inbox.enqueue(route, sceneID: scene, sceneLifetime: UUID(), context: context, deadline: UInt64.max)
        inbox.cancel(requestID: route.requestId, subjectID: "other"); XCTAssertEqual(inbox.count, 1)
        inbox.cancel(requestID: route.requestId, subjectID: "user"); XCTAssertEqual(inbox.count, 0)
    }
    func testExpiredInputNeverQueues() async throws {
        let inbox = try NativeRouteInbox()
        XCTAssertThrowsError(try inbox.enqueue(route(), sceneID: scene, sceneLifetime: UUID(), context: context, deadline: 0))
        XCTAssertEqual(inbox.count, 0)
    }
}
