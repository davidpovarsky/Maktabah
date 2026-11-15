import Foundation
import XCTest
import OtzariaActionCore
@testable import OtzariaUIRouting

final class NPublicV2ConsumerReviewTests: XCTestCase, @unchecked Sendable {
    @MainActor func testBoundSurfaceCannotAcknowledgeActualWorkspaceProfileProjection() async throws {
        let backend = ActionBackendID.otzaria
        let context = ActionExecutionContext(subjectID: "native-scene", origin: .deepLink,
            allowedBackends: [backend], scopes: [.discovery, .navigation], foregroundSceneID: "native-scene")
        let host = NavigationAuthorityFixture(context: context)
        let core = try ActionExecutor(state: host, resolver: host, search: host, navigationAuthority: host)
        let destination = UIDestinationID(rawValue: "native.history")!
        let registry = try UIDestinationRegistry(descriptors: [.init(id: destination, title: "History",
            implementation: .implemented, supportedBackends: [backend], presentations: [.currentTab],
            publicNavigationV2: .init(rules: [.init(presentation: .currentTab)]))])
        let invocation = ActionPortInvocation(requestId: UUID(), snapshot: host.backend, deadlineUptimeNanoseconds: UInt64.max)
        let plan = try await registry.bindPublicV2(.init(destination: destination), scene: host.scene,
            context: context, invocation: invocation, core: core, host: NPublicV2ConsumerHost(host))
        guard case .surface(let prepared) = plan else { return XCTFail("Expected guarded surface") }
        let command = prepared.command, bound = command.route.route
        XCTAssertNil(bound.state.workspaceID); XCTAssertNil(bound.state.profileID)
        let actualState = UIStateSpec(workspaceID: .init(rawValue: UUID().uuidString), profileID: .init(rawValue: UUID().uuidString))
        // The current concrete MaktabahNativeSceneProjection always projects
        // the independently observed group/profile IDs, including History.
        let observedRoute = RouteSpec(version: bound.version, requestId: bound.requestId, destination: destination,
            backend: backend, presentation: bound.presentation, state: actualState,
            scene: bound.scene, expectedBackendSnapshot: bound.expectedBackendSnapshot)
        XCTAssertNotEqual(bound.state, actualState)
        try prepared.authorizeCommit(current: host.scene)
        let observed = UISceneSnapshot(sceneID: host.scene.sceneID, revision: host.sceneRevision + 1,
            backendSnapshot: host.backend, visibleRoute: observedRoute)
        let receipt = UISceneReceipt(requestId: invocation.requestId, route: observedRoute, backendSnapshot: host.backend,
            sceneID: host.scene.sceneID, basedOnSceneRevision: host.sceneRevision, appliedSceneRevision: observed.revision)
        XCTAssertThrowsError(try prepared.validateCompletion(receipt: receipt, observed: observed)) {
            XCTAssertEqual(($0 as? UIRouteError)?.code, "scene_receipt_mismatch")
        }
    }
}
@MainActor private final class NPublicV2ConsumerHost: UIPublicNavigationEligibilityPort {
    let source: NavigationAuthorityFixture
    init(_ source: NavigationAuthorityFixture) { self.source = source }
    func currentScene(sceneID: UIStableID, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws -> UISceneSnapshot {
        try await source.currentScene(sceneID: sceneID, context: context, invocation: invocation)
    }
    func assess(_ descriptor: UIDestinationDescriptor, scene: UISceneSnapshot, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws -> UIRouteEligibility {
        try await source.assess(descriptor, scene: scene, context: context, invocation: invocation)
    }
    func assessPublicVariant(_ variant: UIPublicNavigationVariantV2, scene: UISceneSnapshot, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws -> UIRouteEligibility { assessment(scene) }
    func assessPublicNavigation(_ intent: PublicNavigationSpecV2, scene: UISceneSnapshot, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws -> UIRouteEligibility { assessment(scene) }
    private func assessment(_ scene: UISceneSnapshot) -> UIRouteEligibility {
        .init(sceneID: scene.sceneID, sceneRevision: scene.revision, backendSnapshot: scene.backendSnapshot,
            supported: true, ready: true, allowed: true)
    }
}
