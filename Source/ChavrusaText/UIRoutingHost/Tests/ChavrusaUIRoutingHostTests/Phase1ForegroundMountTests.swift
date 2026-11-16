import Foundation
import XCTest
import OtzariaUIRouting

@MainActor final class Phase1ForegroundMountTests: XCTestCase, @unchecked Sendable {
    private func cancelled(_ task: Task<UIStableID, any Error>) async {
        do { _ = try await task.value; XCTFail("Cancellation completed as a mount") }
        catch { XCTAssertTrue(error is CancellationError, "Unexpected error: \(error)") }
    }
    func testExactAlreadyMountedManagerReturnsWithoutWaiter() async throws {
        let owner = NSObject(), other = NSObject(), b = Phase1MountWaitBoundary()
        b.existing(ObjectIdentifier(other), scene: "other")
        b.existing(ObjectIdentifier(owner), scene: "exact")
        let result = try await b.run(ObjectIdentifier(owner))
        XCTAssertEqual(result.rawValue, "exact"); XCTAssertEqual(b.waiterCount, 0)
    }
    func testCancellationBeforeEntryRefusesEvenAlreadyMountedScene() async throws {
        let owner = NSObject(), b = Phase1MountWaitBoundary(), id = ObjectIdentifier(owner)
        b.existing(id, scene: "exact")
        let task = Task { @MainActor in try await b.run(id) }
        task.cancel(); await cancelled(task)
        XCTAssertEqual(b.waiterCount, 0)
    }
    func testCancellationBetweenEntryCheckAndContinuationNeverQueues() async throws {
        let owner = NSObject(), b = Phase1MountWaitBoundary(), id = ObjectIdentifier(owner)
        let holder = Phase1WaitTaskHolder()
        b.beforeSceneRead = { b.beforeSceneRead = nil; holder.task?.cancel() }
        let task = Task { @MainActor in try await b.run(id) }; holder.task = task
        await cancelled(task)
        XCTAssertEqual(b.waiterCount, 0)
    }
    func testQueuedCancellationResumesAndRemovesItsOwnWaiter() async throws {
        let owner = NSObject(), b = Phase1MountWaitBoundary(), id = ObjectIdentifier(owner)
        let task = Task { @MainActor in try await b.run(id) }
        try await b.untilCount(1); task.cancel(); await cancelled(task)
        XCTAssertEqual(b.waiterCount, 0)
        b.mount(id, scene: "late") // No second resume after cancellation.
        XCTAssertEqual(b.waiterCount, 0)
    }
    func testMountResumesOnlyMatchingManagerAndCleansLedger() async throws {
        let a = NSObject(), z = NSObject(), b = Phase1MountWaitBoundary()
        let first = Task { @MainActor in try await b.run(ObjectIdentifier(a)) }
        let second = Task { @MainActor in try await b.run(ObjectIdentifier(z)) }
        try await b.untilCount(2)
        b.mount(ObjectIdentifier(a), scene: "A")
        let firstResult = try await first.value
        XCTAssertEqual(firstResult.rawValue, "A")
        XCTAssertTrue(b.queued(ObjectIdentifier(z))); XCTAssertEqual(b.waiterCount, 1)
        b.mount(ObjectIdentifier(z), scene: "Z")
        let secondResult = try await second.value
        XCTAssertEqual(secondResult.rawValue, "Z"); XCTAssertEqual(b.waiterCount, 0)
    }
    func testDuplicateAmbiguousAndFiniteCapacityRefuseWithoutStealingWaiters() async throws {
        let b = Phase1MountWaitBoundary(), owners = (0..<18).map { _ in NSObject() }
        var tasks: [Task<UIStableID, any Error>] = []
        for index in 0..<16 {
            let id = ObjectIdentifier(owners[index])
            tasks.append(Task { @MainActor in try await b.run(id) })
        }
        try await b.untilCount(16)
        for id in [ObjectIdentifier(owners[0]), ObjectIdentifier(owners[16])] {
            do { _ = try await b.run(id); XCTFail("Duplicate/full capacity admitted") }
            catch { XCTAssertEqual((error as? UIRouteError)?.code, "native_mount_admission_rejected") }
        }
        let mounted = ObjectIdentifier(owners[17]); b.existing(mounted, scene: "ready")
        let ready = try await b.run(mounted)
        XCTAssertEqual(ready.rawValue, "ready")
        b.existing(mounted, scene: "ambiguous")
        do { _ = try await b.run(mounted); XCTFail("Ambiguous mounted owner selected") }
        catch { XCTAssertEqual((error as? UIRouteError)?.code, "native_mount_admission_rejected") }
        for task in tasks { task.cancel() }
        for task in tasks { await cancelled(task) }
        XCTAssertEqual(b.waiterCount, 0)
    }
    func testOldCancellationTaskCannotRemoveOrResumeReplacementToken() async throws {
        let owner = NSObject(), b = Phase1MountWaitBoundary(), id = ObjectIdentifier(owner)
        let old = Task { @MainActor in try await b.run(id) }
        try await b.untilCount(1)
        let replacement = Task { @MainActor in try await b.prepareReplacement(id) }
        try await b.untilPrimed(id)
        // No await before replacement: old onCancel's MainActor Task is queued.
        old.cancel(); b.replaceLedger(id)
        let reads = b.waiterReadCount
        await cancelled(old)
        // Await the old cleanup's actual ledger read; no scheduling assumption.
        try await b.untilRead(after: reads)
        XCTAssertTrue(b.queued(id)); XCTAssertEqual(b.waiterCount, 1)
        b.mount(id, scene: "replacement")
        let replacementResult = try await replacement.value
        XCTAssertEqual(replacementResult.rawValue, "replacement")
        XCTAssertEqual(b.waiterCount, 0)
    }
}
@MainActor private final class Phase1WaitTaskHolder { var task: Task<UIStableID, any Error>? }

extension Phase1ForegroundMountTests {
    func testAlreadyMountedInactiveOwnerWaitsForItsOwnActivation() async throws {
        let owner = NSObject(), other = NSObject(), b = Phase1MountWaitBoundary()
        let id = ObjectIdentifier(owner)
        b.existing(id, scene: "inactive-exact", foreground: false)
        b.existing(ObjectIdentifier(other), scene: "active-other")
        let task = Task { @MainActor in try await b.run(id) }
        try await b.untilCount(1)
        XCTAssertTrue(b.queued(id), "An external URL must await the exact scene's activation, not fail before system foreground delivery")
        b.activate(ObjectIdentifier(other))
        XCTAssertTrue(b.queued(id), "Another foreground scene cannot consume this request")
        b.activate(id)
        let actual = try await task.value
        XCTAssertEqual(actual.rawValue, "inactive-exact")
        XCTAssertEqual(b.waiterCount, 0)
    }
    func testInactiveSceneWaitRemainsCancellableAndDoesNotRetarget() async throws {
        let owner = NSObject(), b = Phase1MountWaitBoundary(), id = ObjectIdentifier(owner)
        b.existing(id, scene: "inactive", foreground: false)
        let task = Task { @MainActor in try await b.run(id) }
        try await b.untilCount(1)
        task.cancel()
        do { _ = try await task.value; XCTFail("Inactive wait ignored cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(b.waiterCount, 0)
        b.activate(id)
        XCTAssertEqual(b.waiterCount, 0)
    }
}
