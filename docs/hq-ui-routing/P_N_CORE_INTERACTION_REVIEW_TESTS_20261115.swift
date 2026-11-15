import Foundation
import XCTest
import OtzariaActionCore
import OtzariaUIRouting
@testable import ChavrusaUIRoutingHost

/// P-owned review fixture, run only in an ignored exact 7be2aba snapshot.
/// Never inserted into N's worktree or native target.
@MainActor final class PNativeCoreInteractionReviewTests: XCTestCase, @unchecked Sendable {
    func testDetachedDriverCannotApplyAfterCanonicalGuard() async throws {
        let f = try await PublicConsumerFixture(.otzaria)
        defer { f.authority.release(f.admitted) }
        let prepared = try await f.surfacePlan()
        var detached = false
        f.backend.onSynchronousSnapshot = {
            // beginObservation has happened; no apply has happened. This is
            // the same synchronous-source callback model as N's final checks.
            if f.driver.command != nil && f.driver.applied == 0 && !detached {
                detached = true
                f.orchestrator.unregister(f.driver)
            }
        }
        let result = await f.orchestrator.commitPrepared(prepared, admitted: f.admitted)
        XCTAssertTrue(detached)
        if case .acknowledged = result { XCTFail("Detached owner acknowledged") }
        XCTAssertEqual(f.driver.applied, 0, "Unregistered driver must be refused BEFORE its native effect")
    }

    func testDelayedCoreRelativeStartStillCannotOutliveOriginalRetainedGuard() async throws {
        let clock = PReaderQueueReviewClock()
        let f = try await PublicConsumerFixture(.otzaria, reader: true, clock: clock, deadline: 3_000_000_000)
        defer { f.authority.release(f.admitted) }
        guard case .reader(let retained) = try await f.bind() else { return XCTFail("Missing original reader plan") }
        // N's three now() reads precede the Core actor's relative-deadline read.
        // Simulate elapsed actor queue time at that boundary, without modifying
        // either production executor or pretending to measure real scheduling.
        clock.advanceOnRead(4, to: 2_900_000_000)
        f.sink.onOpen = { issued in
            XCTAssertEqual(issued.invocation.deadlineUptimeNanoseconds, 4_900_000_000)
            XCTAssertGreaterThan(issued.invocation.deadlineUptimeNanoseconds, f.invocation.deadlineUptimeNanoseconds)
            clock.advance(to: 3_100_000_000)
            let scene = try await f.directory.currentScene(sceneID: f.sceneID, context: f.context, invocation: issued.invocation)
            let command = try UISceneCommand(route: retained, invocation: issued.invocation, scene: scene)
            let result = await f.orchestrator.commit(command, readerCommand: issued, context: f.context)
            guard case .acknowledged(let receipt) = result, let coreReceipt = receipt.coreReceipt else { throw ActionPortError.invalidResponse }
            return .acknowledged(coreReceipt)
        }
        let result = try await f.orchestrator.executeReaderPlan(retained, originalInvocation: f.invocation, admitted: f.admitted)
        XCTAssertNotEqual(result.status, .completed)
        XCTAssertEqual(f.sink.calls, 1); XCTAssertEqual(f.driver.applied, 0)
        XCTAssertEqual(try f.authority.navigationState(sceneID: f.sceneID.rawValue).authorityRevision, f.admitted.authorityRevision)
    }
}

private final class PReaderQueueReviewClock: ActionClock, @unchecked Sendable {
    private let lock = NSLock()
    private var value: UInt64 = 1_000_000_000
    private var read = 0
    private var advanceAt: (Int, UInt64)?
    func now() -> UInt64 {
        lock.withLock {
            read += 1
            if let scheduled = advanceAt, read == scheduled.0 { value = scheduled.1; advanceAt = nil }
            return value
        }
    }
    func advance(to value: UInt64) { lock.withLock { self.value = value } }
    func advanceOnRead(_ read: Int, to value: UInt64) { lock.withLock { self.read = 0; advanceAt = (read, value) } }
    func sleep(until deadline: UInt64) async throws { try await Task.sleep(nanoseconds: 60_000_000_000) }
}
