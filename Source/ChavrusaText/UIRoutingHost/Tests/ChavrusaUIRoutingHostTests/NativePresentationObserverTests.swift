import Foundation
import XCTest
import OtzariaActionCore
import OtzariaUIRouting
@testable import ChavrusaUIRoutingHost

@MainActor final class NativePresentationObserverTests: XCTestCase, @unchecked Sendable {
    private func command(deadline: UInt64 = UInt64.max) throws -> UISceneCommand {
        let backend = ActionBackendSnapshot(backend: .otzaria, generation: 7), id = UIStableID(rawValue: "scene.A")!
        let route = RouteSpec(destination: UIDestinationID(rawValue: "fixture.settings")!, backend: .otzaria, presentation: .init(kind: .sheet))
        return try UISceneCommand(route: UIDestinationRegistry.fixtures().validate(route),
            invocation: .init(requestId: route.requestId, snapshot: backend, deadlineUptimeNanoseconds: deadline),
            scene: .init(sceneID: id, revision: 10, backendSnapshot: backend))
    }
    private func surface(_ command: UISceneCommand) -> NativeSurfaceState {
        let route = command.route.route
        return .init(destination: route.destination, presentation: route.presentation, content: route.content, state: route.state, focus: route.focus)
    }
    func testNativeEvidenceArrivingBeforeWaitIsNotLost() async throws {
        let command = try command(), observer = NativePresentationObserver(sceneID: command.scene.sceneID)
        try observer.begin(command)
        let actual = NativePresentationObserver.Visible(sceneID: command.scene.sceneID, submissionID: command.invocation.requestId, surface: surface(command))
        observer.report(actual)
        let result = try await observer.wait(for: command)
        XCTAssertEqual(result, actual); observer.end(requestID: command.invocation.requestId)
        XCTAssertNil(observer.submissionID); XCTAssertEqual(observer.pendingWaiterCount, 0)
    }
    func testWrongSceneRequestAndFullProjectionAreIgnored() async throws {
        let command = try command(), observer = NativePresentationObserver(sceneID: command.scene.sceneID)
        try observer.begin(command)
        observer.report(.init(sceneID: UIStableID(rawValue: "scene.B")!, submissionID: command.invocation.requestId, surface: surface(command)))
        observer.report(.init(sceneID: command.scene.sceneID, submissionID: UUID(), surface: surface(command)))
        observer.report(.init(sceneID: command.scene.sceneID, submissionID: command.invocation.requestId,
                              surface: .init(destination: command.route.route.destination, presentation: .init(kind: .currentTab), content: nil, state: .init(), focus: nil)))
        let actual = NativePresentationObserver.Visible(sceneID: command.scene.sceneID, submissionID: command.invocation.requestId, surface: surface(command))
        observer.report(actual)
        let result = try await observer.wait(for: command)
        XCTAssertEqual(result, actual); observer.end(requestID: command.invocation.requestId)
    }
    func testAdmissionCannotOverwritePendingPresentation() async throws {
        let command = try command(), observer = NativePresentationObserver(sceneID: command.scene.sceneID)
        try observer.begin(command); XCTAssertThrowsError(try observer.begin(self.command()))
        XCTAssertEqual(observer.submissionID, command.invocation.requestId)
        observer.end(requestID: UUID()); XCTAssertEqual(observer.submissionID, command.invocation.requestId)
        observer.revoke(); XCTAssertNil(observer.submissionID)
    }
    func testDeadlineCleansNativeContinuationAndReservation() async throws {
        let clock = ObserverTestClock(), command = try command(deadline: 100), observer = NativePresentationObserver(sceneID: command.scene.sceneID, clock: clock)
        try observer.begin(command)
        do { _ = try await observer.wait(for: command); XCTFail("unobserved UI") }
        catch { XCTAssertTrue(error is CancellationError || (error as? UIRouteError)?.status == .cancelled) }
        XCTAssertEqual(observer.pendingWaiterCount, 0); XCTAssertNil(observer.submissionID)
    }
    func testRevokedEvidenceCannotFinishLaterRequest() async throws {
        let old = try command(), new = try command(), observer = NativePresentationObserver(sceneID: old.scene.sceneID)
        try observer.begin(old); observer.revoke(); try observer.begin(new)
        observer.report(.init(sceneID: old.scene.sceneID, submissionID: old.invocation.requestId, surface: surface(old)))
        XCTAssertEqual(observer.submissionID, new.invocation.requestId)
        observer.revoke(); XCTAssertNil(observer.submissionID)
    }
}

private final class ObserverTestClock: ActionClock, @unchecked Sendable {
    private let lock = NSLock()
    private var value: UInt64 = 0
    func now() -> UInt64 { lock.withLock { value } }
    func sleep(until deadline: UInt64) async throws {
        try await Task.sleep(nanoseconds: 30_000_000)
        lock.withLock { value = deadline }
    }
}
