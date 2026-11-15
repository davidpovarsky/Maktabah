import Foundation
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

/// Native registration is a shell. The COMPLETE production waitForMount body
/// and exact waiter type are inserted unchanged; UIKit/AppIntents are not run.
@MainActor final class NMountWaitBoundary {
    struct Session { let sceneID: UIStableID }
    struct Registration { let managerID: ObjectIdentifier; let session: Session }
    private var registrations: [UIStableID: Registration] = [:]
    var beforeSceneRead: (() -> Void)?
    private var scenes: [UIStableID: Registration] {
        beforeSceneRead?(); return registrations
    }
    // EXACT_WAITER_TYPE
    private var waiterStorage: [ObjectIdentifier: MountWaiter] = [:]
    private(set) var waiterReadCount = 0
    private let readChanges: AsyncStream<Int>
    private let readEvents: AsyncStream<Int>.Continuation
    private var mountWaiters: [ObjectIdentifier: MountWaiter] {
        get { waiterReadCount += 1; readEvents.yield(waiterReadCount); return waiterStorage }
        set { waiterStorage = newValue; events.yield(newValue.count) }
    }
    private let changes: AsyncStream<Int>
    private let events: AsyncStream<Int>.Continuation
    private var primed: [ObjectIdentifier: MountWaiter] = [:]
    private let primeChanges: AsyncStream<Void>
    private let primeEvents: AsyncStream<Void>.Continuation
    init() {
        (changes, events) = AsyncStream<Int>.makeStream(bufferingPolicy: .bufferingNewest(64))
        (primeChanges, primeEvents) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(4))
        (readChanges, readEvents) = AsyncStream<Int>.makeStream(bufferingPolicy: .bufferingNewest(64))
    }
    var waiterCount: Int { mountWaiters.count }
    func queued(_ manager: ObjectIdentifier) -> Bool { mountWaiters[manager] != nil }
    func run(_ manager: ObjectIdentifier) async throws -> UIStableID { try await waitForMount(managerID: manager) }
    func existing(_ manager: ObjectIdentifier, scene: String) {
        let sceneID = UIStableID(rawValue: scene)!
        registrations[sceneID] = .init(managerID: manager, session: .init(sceneID: sceneID))
    }
    func mount(_ manager: ObjectIdentifier, scene: String) {
        existing(manager, scene: scene)
        mountWaiters.removeValue(forKey: manager)?.continuation.resume(returning: UIStableID(rawValue: scene)!)
    }
    func untilCount(_ count: Int) async throws {
        if mountWaiters.count == count { return }
        let clock = SystemActionClock()
        try await NativeObservationDeadline.run(until: clock.now() + 5_000_000_000, clock: clock) { @MainActor [self] in
            for await _ in changes { if mountWaiters.count == count { return } }
            throw ActionPortError.unavailable
        }
    }
    /// Prepare a genuinely separate checked continuation before injecting the
    /// ledger replacement synchronously ahead of the queued cancellation task.
    func prepareReplacement(_ manager: ObjectIdentifier) async throws -> UIStableID {
        try await withCheckedThrowingContinuation { continuation in
            primed[manager] = .init(token: UUID(), continuation: continuation)
            primeEvents.yield(())
        }
    }
    func untilPrimed(_ manager: ObjectIdentifier) async throws {
        if primed[manager] != nil { return }
        let clock = SystemActionClock()
        try await NativeObservationDeadline.run(until: clock.now() + 5_000_000_000, clock: clock) { @MainActor [self] in
            for await _ in primeChanges { if primed[manager] != nil { return } }
            throw ActionPortError.unavailable
        }
    }
    func replaceLedger(_ manager: ObjectIdentifier) {
        let old = mountWaiters.removeValue(forKey: manager)!
        let replacement = primed.removeValue(forKey: manager)!
        precondition(old.token != replacement.token)
        mountWaiters[manager] = replacement
        old.continuation.resume(throwing: CancellationError())
    }
    func untilRead(after original: Int) async throws {
        if waiterReadCount > original { return }
        let clock = SystemActionClock()
        try await NativeObservationDeadline.run(until: clock.now() + 5_000_000_000, clock: clock) { @MainActor [self] in
            for await _ in readChanges { if waiterReadCount > original { return } }
            throw ActionPortError.unavailable
        }
    }
    // EXACT_WAIT_FOR_MOUNT_METHOD
}
