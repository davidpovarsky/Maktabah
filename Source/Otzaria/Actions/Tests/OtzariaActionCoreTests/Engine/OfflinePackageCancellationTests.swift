import Foundation
import XCTest
@testable import OtzariaActionCore

@MainActor
private final class OriginalPackageCancellationFixture: ActionSynchronousBackendStatePort,
    ActionOfflinePackageObservationPort, ActionOfflinePackageCancellationPort, ActionNavigationAuthority {
    let snapshotValue = ActionBackendSnapshot(backend: .sefaria, generation: 1)
    let scene = "offline-package-scene"
    let lifetime = UUID()
    var revision: UInt64 = 1
    var active = true
    var operation: UUID? = UUID()
    var cancelRequests: [UUID] = []
    var revokeBeforeCancellation = false

    lazy var context: ActionExecutionContext = {
        .init(subjectID: "offline-package", origin: .inApp, allowedBackends: [.sefaria],
              contentRights: [.sefaria], scopes: [.discovery, .contentRead, .navigation], foregroundSceneID: scene)
    }()

    func snapshot() async -> ActionBackendSnapshot { snapshotValue }
    func currentBackendSnapshot() throws -> ActionBackendSnapshot { snapshotValue }
    func navigationState(sceneID: String) throws -> ActionNavigationState {
        .init(context: context, sceneID: scene, lifetimeID: lifetime, authorityRevision: revision, active: active)
    }
    func report(for backend: ActionBackendID) async -> ActionBackendReport {
        .init(id: backend, operations: ["packages.cancel":
            .init(registered: true, supported: backend == .sefaria, availableNow: backend == .sefaria)])
    }
    func assess(action: String, arguments: ActionObject,
                invocation: ActionPortInvocation) async -> ActionCapabilityAssessment {
        .init(registered: true, supported: true, availableNow: true)
    }
    func offlinePackages(forceRefresh: Bool, invocation: ActionPortInvocation) async -> [ActionOfflinePackage] { [] }
    func offlinePackageStatus(includeWorks: Bool, invocation: ActionPortInvocation) async -> ActionOfflinePackageStatus {
        .init(installedPackageIDs: [], installedWorkKeys: includeWorks ? [] : nil, activeOperationHandle: operation)
    }
    func offlinePackageUpdates(invocation: ActionPortInvocation) async -> ActionOfflinePackageUpdates {
        .init(changedWorkCount: 0, affectedPackageIDs: [])
    }
    func offlinePackageCancellationAvailable(invocation: ActionPortInvocation) async -> Bool { operation != nil }
    func cancelOfflinePackage(operationHandle: UUID?, sceneID: String, invocation: ActionPortInvocation,
                              authorization: ActionNavigationPreparation) async throws -> UUID {
        guard let operation, operationHandle == nil || operationHandle == operation else {
            throw ActionPortError.notFound
        }
        if revokeBeforeCancellation { revision += 1 }
        try authorization.authorizeCommit(invocation: invocation, sceneID: sceneID)
        cancelRequests.append(operation)
        self.operation = nil
        return operation
    }
}

final class OfflinePackageCancellationTests: XCTestCase, @unchecked Sendable {
    @MainActor
    private func makeEngine(_ fixture: OriginalPackageCancellationFixture) throws -> ActionExecutor {
        let original = MockPorts(backend: .sefaria)
        return try .init(state: fixture, resolver: original, search: original, navigationAuthority: fixture)
    }

    private func cancellation(handle: String? = nil) -> ActionRequest {
        var arguments: ActionObject = ["backend": .string("sefaria")]
        if let handle { arguments["operationHandle"] = .string(handle) }
        return .init(action: "packages.cancel", arguments: arguments, requestedPresentation: .foreground)
    }

    @MainActor
    func testCancelUsesExactOperationAndReplayDoesNotTouchReplacement() async throws {
        let fixture = OriginalPackageCancellationFixture()
        let engine = try makeEngine(fixture)
        let current = try XCTUnwrap(fixture.operation)
        let request = cancellation(handle: current.uuidString)
        let first = await engine.execute(request, context: fixture.context)
        XCTAssertEqual(first.status, .completed)
        XCTAssertEqual(first.data?["operationHandle"], .string(current.uuidString))
        XCTAssertEqual(first.data?["cancellationRequested"], .bool(true))
        let replacement = UUID()
        fixture.operation = replacement
        let replay = await engine.execute(request, context: fixture.context)
        XCTAssertEqual(first, replay)
        XCTAssertEqual(fixture.cancelRequests, [current])
        XCTAssertEqual(fixture.operation, replacement)
    }

    @MainActor
    func testOldHandleAndRevokedSceneCannotCancelCurrentOperation() async throws {
        let fixture = OriginalPackageCancellationFixture()
        let engine = try makeEngine(fixture)
        let token = try XCTUnwrap(fixture.operation)
        let stale = await engine.execute(cancellation(handle: UUID().uuidString), context: fixture.context)
        XCTAssertEqual(stale.error?.code, "not_found")
        let malformed = await engine.execute(cancellation(handle: "not-an-operation"), context: fixture.context)
        XCTAssertEqual(malformed.error?.code, "invalid_arguments")
        fixture.revokeBeforeCancellation = true
        let revoked = await engine.execute(cancellation(handle: token.uuidString), context: fixture.context)
        XCTAssertEqual(revoked.error?.code, "navigation_authority_changed")
        XCTAssertTrue(fixture.cancelRequests.isEmpty)
        XCTAssertEqual(fixture.operation, token)
    }

    @MainActor
    func testDiscoveryRequiresActiveOperationAndForegroundAuthority() async throws {
        let fixture = OriginalPackageCancellationFixture()
        let engine = try makeEngine(fixture)
        let ready = await engine.advertisedActions(for: .sefaria, context: fixture.context)
        XCTAssertTrue(ready.contains { $0.id == "packages.cancel" })
        fixture.active = false
        let background = await engine.advertisedActions(for: .sefaria, context: fixture.context)
        XCTAssertFalse(background.contains { $0.id == "packages.cancel" })
        fixture.active = true
        fixture.operation = nil
        let idle = await engine.advertisedActions(for: .sefaria, context: fixture.context)
        XCTAssertFalse(idle.contains { $0.id == "packages.cancel" })
    }
}
