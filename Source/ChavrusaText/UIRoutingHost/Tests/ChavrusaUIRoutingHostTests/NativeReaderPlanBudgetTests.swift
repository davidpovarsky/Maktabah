import Foundation
import XCTest
import OtzariaActionCore
import OtzariaUIRouting
@testable import ChavrusaUIRoutingHost

@MainActor final class NativeReaderPlanBudgetTests: XCTestCase, @unchecked Sendable {
    func testRemainingRequestBudgetRoundsDownAndUsesActualCoreSchemaBounds() async throws {
        let clock = ReaderBudgetTestClock(now: 1_000_000_000)
        let f = try await PublicConsumerFixture(.otzaria, reader: true, clock: clock, deadline: 6_000_999_999)
        defer { f.authority.release(f.admitted) }
        guard case .reader(let retained) = try await f.bind() else { return XCTFail("Missing retained reader route") }
        clock.advance(to: 2_000_000_000)
        let request = try NativeReaderPlanBudget.request(for: retained, original: f.invocation, now: clock.now())
        XCTAssertEqual(request.deadlineMs, 4_000)
        XCTAssertEqual(request.requestId, f.invocation.requestId)
        XCTAssertEqual(request.expectedBackend, f.invocation.snapshot.backend)
        XCTAssertEqual(request.expectedGeneration, f.invocation.snapshot.generation)
        let schema = try ActionRegistry.schema("action-request.v1.schema.json")
        try ActionSchemaValidator.validate(try ActionJSON.encoded(request), schema: schema)
        let bounds = try XCTUnwrap(schema.object?["properties"]?.object?["deadlineMs"]?.object)
        let minimum = try XCTUnwrap(bounds["minimum"]?.unsignedInteger)
        let atMinimum = try NativeReaderPlanBudget.request(for: retained, original: f.invocation,
            now: f.invocation.deadlineUptimeNanoseconds - minimum * 1_000_000)
        XCTAssertEqual(atMinimum.deadlineMs, Int(minimum))
        let wrongID = ActionPortInvocation(requestId: UUID(), snapshot: f.invocation.snapshot,
            deadlineUptimeNanoseconds: f.invocation.deadlineUptimeNanoseconds)
        XCTAssertThrowsError(try NativeReaderPlanBudget.request(for: retained, original: wrongID, now: clock.now()))

        let unlimited = try await PublicConsumerFixture(.sefariaEmbedded, reader: true)
        defer { unlimited.authority.release(unlimited.admitted) }
        guard case .reader(let other) = try await unlimited.bind() else { return XCTFail("Missing second retained route") }
        let bounded = try NativeReaderPlanBudget.request(for: other, original: unlimited.invocation, now: unlimited.clock.now())
        XCTAssertEqual(bounded.deadlineMs, Int(try XCTUnwrap(bounds["maximum"]?.unsignedInteger)))
        XCTAssertEqual(f.sink.calls, 0); XCTAssertEqual(unlimited.sink.calls, 0)
    }

    func testActualCoreReceivesOnlyRemainingBudgetAndKeepsOriginalAdmissionOnAllBackends() async throws {
        for backend in ActionBackendID.allCases {
            let clock = ReaderBudgetTestClock(now: 1_000_000_000)
            let f = try await PublicConsumerFixture(backend, reader: true, clock: clock, deadline: 3_000_000_000)
            defer { f.authority.release(f.admitted) }
            guard case .reader(let retained) = try await f.bind() else { return XCTFail("Missing retained route") }
            clock.advance(to: 2_500_000_001)
            f.sink.onOpen = { issued in
                XCTAssertEqual(issued.invocation.deadlineUptimeNanoseconds, 2_999_000_001)
                XCTAssertLessThan(issued.invocation.deadlineUptimeNanoseconds, f.invocation.deadlineUptimeNanoseconds)
                return try await Self.commitActualSink(f, retained: retained, issued: issued)
            }
            let result = try await f.orchestrator.executeReaderPlan(retained, originalInvocation: f.invocation, admitted: f.admitted)
            XCTAssertEqual(result.status, .completed, "\(String(describing: result.error))")
            XCTAssertEqual(f.sink.calls, 1); XCTAssertEqual(f.driver.applied, 1)
            XCTAssertEqual(try f.authority.navigationState(sceneID: f.sceneID.rawValue).authorityRevision, f.admitted.authorityRevision)
        }
    }

    func testInsufficientOrExpiredOriginalBudgetNeverStartsCoreOrRoundsUp() async throws {
        let schema = try ActionRegistry.schema("action-request.v1.schema.json")
        let minimum = try XCTUnwrap(schema.object?["properties"]?.object?["deadlineMs"]?.object?["minimum"]?.unsignedInteger)
        for expired in [false, true] {
            let clock = ReaderBudgetTestClock(now: 1_000_000_000)
            let f = try await PublicConsumerFixture(.otzaria, reader: true, clock: clock, deadline: 3_000_000_000)
            defer { f.authority.release(f.admitted) }
            guard case .reader(let retained) = try await f.bind() else { return XCTFail("Missing retained route") }
            clock.advance(to: expired ? f.invocation.deadlineUptimeNanoseconds : f.invocation.deadlineUptimeNanoseconds - minimum * 1_000_000 + 1)
            let before = f.backend.asynchronousSnapshots
            do {
                _ = try await f.orchestrator.executeReaderPlan(retained, originalInvocation: f.invocation, admitted: f.admitted)
                XCTFail("Budget was restarted/rounded up")
            } catch { XCTAssertEqual((error as? UIRouteError)?.status, .cancelled) }
            XCTAssertEqual(f.backend.asynchronousSnapshots, before)
            XCTAssertEqual(f.sink.calls, 0); XCTAssertEqual(f.driver.applied, 0)
            XCTAssertEqual(try f.authority.navigationState(sceneID: f.sceneID.rawValue).authorityRevision, f.admitted.authorityRevision)
        }
    }

    func testOriginalOwnerRevocationDuringOuterScopeCleanupCannotEscapeAsCompletion() async throws {
        let clock = ReaderBudgetTestClock(now: 1_000_000_000)
        let f = try await PublicConsumerFixture(.otzaria, reader: true, clock: clock, deadline: 3_000_000_000)
        defer { f.authority.release(f.admitted) }
        guard case .reader(let retained) = try await f.bind() else { return XCTFail("Missing retained route") }
        clock.advance(to: 2_500_000_001)
        var cleanupRevocations = 0
        f.sink.onOpen = { issued in try await Self.commitActualSink(f, retained: retained, issued: issued) }
        // The outer deadline differs from Core's rounded-down deadline. Its
        // timer cleanup runs only after the Core operation returned its result.
        clock.onCancellation(of: f.invocation.deadlineUptimeNanoseconds) {
            cleanupRevocations += 1
            do { try f.authority.invalidate(f.lease) }
            catch { f.authority.unmount(f.lease); XCTFail("Fixture cleanup revocation failed: \(error)") }
        }
        do {
            _ = try await f.orchestrator.executeReaderPlan(retained, originalInvocation: f.invocation, admitted: f.admitted)
            XCTFail("Late original-owner revocation escaped the final await boundary")
        } catch { XCTAssertEqual((error as? UIRouteError)?.code, "native_effect_uncertain") }
        XCTAssertEqual(cleanupRevocations, 1)
        XCTAssertEqual(f.sink.calls, 1); XCTAssertEqual(f.driver.applied, 1); XCTAssertNil(f.driver.command)
        XCTAssertThrowsError(try f.authority.navigationState(sceneID: f.sceneID.rawValue))
    }

    func testReissuedAdmissionIsRefusedBeforeCoreAndOldCleanupPreservesReplacement() async throws {
        let f = try await PublicConsumerFixture(.otzaria, reader: true)
        guard case .reader(let retained) = try await f.bind() else { return XCTFail("Missing retained route") }
        try f.authority.invalidate(f.lease)
        let replacement = try f.authority.admit(context: f.context, sceneID: f.sceneID)
        defer { f.authority.release(replacement) }
        let before = f.backend.asynchronousSnapshots
        do {
            _ = try await f.orchestrator.executeReaderPlan(retained, originalInvocation: f.invocation, admitted: f.admitted)
            XCTFail("A replacement context was used for the old plan")
        } catch { XCTAssertEqual((error as? UIRouteError)?.code, "native_context_changed") }
        XCTAssertEqual(f.backend.asynchronousSnapshots, before); XCTAssertEqual(f.sink.calls, 0)
        f.authority.release(f.admitted)
        XCTAssertEqual(try f.authority.navigationState(sceneID: f.sceneID.rawValue).authorityRevision, replacement.authorityRevision)
    }

    func testConsumerRejectsCachedCompletionInsteadOfReusingOldNativeReceipt() async throws {
        let f = try await PublicConsumerFixture(.otzaria, reader: true)
        defer { f.authority.release(f.admitted) }
        guard case .reader(let retained) = try await f.bind() else { return XCTFail("Missing retained route") }
        f.sink.onOpen = { issued in try await Self.commitActualSink(f, retained: retained, issued: issued) }
        let first = try await f.orchestrator.executeReaderPlan(retained, originalInvocation: f.invocation, admitted: f.admitted)
        XCTAssertEqual(first.status, .completed)
        let before = f.backend.asynchronousSnapshots
        do {
            _ = try await f.orchestrator.executeReaderPlan(retained, originalInvocation: f.invocation, admitted: f.admitted)
            XCTFail("Core's cached completed result was reused as a new native completion")
        } catch { XCTAssertEqual((error as? UIRouteError)?.status, .staleState) }
        XCTAssertEqual(f.backend.asynchronousSnapshots, before)
        XCTAssertEqual(f.sink.calls, 1); XCTAssertEqual(f.driver.applied, 1)
    }

    func testConsumerRejectsCoreACKWithoutOwnFullNativeReceipt() async throws {
        let f = try await PublicConsumerFixture(.otzaria, reader: true)
        defer { f.authority.release(f.admitted) }
        guard case .reader(let retained) = try await f.bind() else { return XCTFail("Missing retained route") }
        f.sink.onOpen = { issued in
            // An alternate/adversarial sink can consume the semantic grant and
            // acknowledge its content without N's exact private-route witness.
            // It must not satisfy this consumer's full native completion.
            let grant = try XCTUnwrap(issued.navigationAuthorization)
            try grant.authorizeCommit(invocation: issued.invocation, sceneID: issued.sceneID, destination: issued.destination)
            return .acknowledged(.init(requestId: issued.invocation.requestId, snapshot: issued.invocation.snapshot,
                sceneID: issued.sceneID, destination: issued.destination))
        }
        do {
            _ = try await f.orchestrator.executeReaderPlan(retained, originalInvocation: f.invocation, admitted: f.admitted)
            XCTFail("Semantic ACK without N's actual full native receipt became completed")
        } catch { XCTAssertEqual((error as? UIRouteError)?.code, "native_effect_uncertain") }
        XCTAssertEqual(f.sink.calls, 1); XCTAssertEqual(f.driver.applied, 0)
    }

    func testOneReaderExecutionPerSceneIsAdmittedBeforeAnySecondCoreCall() async throws {
        let f = try await PublicConsumerFixture(.otzaria, reader: true)
        defer { f.authority.release(f.admitted) }
        guard case .reader(let retained) = try await f.bind() else { return XCTFail("Missing retained route") }
        let (entered, enteredSignal) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let (release, releaseSignal) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        var safetyReleased = false
        let safety = Task {
            do {
                try await Task.sleep(nanoseconds: 2_000_000_000)
                safetyReleased = true; enteredSignal.finish(); releaseSignal.finish()
            } catch {}
        }
        defer { safety.cancel(); enteredSignal.finish(); releaseSignal.finish() }
        f.sink.onOpen = { issued in
            enteredSignal.yield(())
            var iterator = release.makeAsyncIterator(); _ = await iterator.next()
            try Task.checkCancellation()
            return try await Self.commitActualSink(f, retained: retained, issued: issued)
        }
        let first = Task { try await f.orchestrator.executeReaderPlan(retained, originalInvocation: f.invocation, admitted: f.admitted) }
        defer { first.cancel() }
        var iterator = entered.makeAsyncIterator()
        guard case .some = await iterator.next() else {
            _ = try? await first.value; XCTFail("Actual Core sink was not entered"); return
        }
        let before = f.backend.asynchronousSnapshots
        do {
            _ = try await f.orchestrator.executeReaderPlan(retained, originalInvocation: f.invocation, admitted: f.admitted)
            XCTFail("A second reader execution used the same scene admission")
        } catch { XCTAssertEqual((error as? UIRouteError)?.code, "native_reader_execution_in_progress") }
        XCTAssertEqual(f.backend.asynchronousSnapshots, before)
        releaseSignal.yield(())
        let completed = try await first.value
        XCTAssertEqual(completed.status, .completed); XCTAssertFalse(safetyReleased)
        XCTAssertEqual(f.sink.calls, 1); XCTAssertEqual(f.driver.applied, 1)
        safety.cancel(); await safety.value
    }

    func testFullNativeLedgerRefusesNewReaderBeforeCore() async throws {
        let f = try await PublicConsumerFixture(.otzaria, reader: true, dispatchCapacity: 1)
        defer { f.authority.release(f.admitted) }
        guard case .reader(let retained) = try await f.bind() else { return XCTFail("Missing retained route") }
        f.sink.onOpen = { issued in try await Self.commitActualSink(f, retained: retained, issued: issued) }
        let first = try await f.orchestrator.executeReaderPlan(retained, originalInvocation: f.invocation, admitted: f.admitted)
        XCTAssertEqual(first.status, .completed)
        let next = ActionPortInvocation(requestId: UUID(), snapshot: f.invocation.snapshot, deadlineUptimeNanoseconds: UInt64.max)
        let scene = try await f.directory.currentScene(sceneID: f.sceneID, context: f.context, invocation: next)
        let host = PublicConsumerBindingHost(directory: f.directory, backend: f.backend, driver: f.driver,
            context: f.context, invocation: next, hasReaderTarget: true)
        guard case .reader(let following) = try await f.registry.bindPublicV2(f.intent, scene: scene, context: f.context,
            invocation: next, core: f.core, host: host) else { return XCTFail("Missing following retained route") }
        let before = f.backend.asynchronousSnapshots
        do {
            _ = try await f.orchestrator.executeReaderPlan(following, originalInvocation: next, admitted: f.admitted)
            XCTFail("Full native ledger admitted another semantic read")
        } catch { XCTAssertEqual((error as? UIRouteError)?.code, "native_dispatch_ledger_full") }
        XCTAssertEqual(f.backend.asynchronousSnapshots, before)
        XCTAssertEqual(f.sink.calls, 1); XCTAssertEqual(f.driver.applied, 1)
    }

    private static func commitActualSink(_ f: PublicConsumerFixture, retained: UIValidatedRoute,
                                         issued: ActionOpenReaderCommand) async throws -> ActionUIAcknowledgement {
        let scene = try await f.directory.currentScene(sceneID: f.sceneID, context: f.context, invocation: issued.invocation)
        let command = try UISceneCommand(route: retained, invocation: issued.invocation, scene: scene)
        let result = await f.orchestrator.commit(command, readerCommand: issued, context: f.context)
        guard case .acknowledged(let receipt) = result, let coreReceipt = receipt.coreReceipt else { throw ActionPortError.invalidResponse }
        return .acknowledged(coreReceipt)
    }
}

private final class ReaderBudgetTestClock: ActionClock, @unchecked Sendable {
    private let lock = NSLock()
    private var value: UInt64
    private var cancellation: (UInt64, @MainActor @Sendable () -> Void)?
    init(now: UInt64) { value = now }
    func now() -> UInt64 { lock.withLock { value } }
    func advance(to value: UInt64) { lock.withLock { self.value = value } }
    func onCancellation(of deadline: UInt64, perform: @escaping @MainActor @Sendable () -> Void) {
        lock.withLock { cancellation = (deadline, perform) }
    }
    func sleep(until deadline: UInt64) async throws {
        do { try await Task.sleep(nanoseconds: 60_000_000_000) }
        catch {
            let callback = lock.withLock { () -> (@MainActor @Sendable () -> Void)? in
                guard cancellation?.0 == deadline else { return nil }
                let callback = cancellation?.1; cancellation = nil; return callback
            }
            if let callback { await callback() }
            throw error
        }
    }
}
