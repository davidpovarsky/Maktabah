import Foundation
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

/// Native registration is a shell. The COMPLETE production waitForMount body
/// and exact waiter type are inserted unchanged; UIKit/AppIntents are not run.
@MainActor final class Phase1MountWaitBoundary {
    @MainActor final class Session {
        let sceneID: UIStableID; var foreground: Bool
        init(sceneID: UIStableID, foreground: Bool) { self.sceneID = sceneID; self.foreground = foreground }
    }
    struct Registration { let managerID: ObjectIdentifier; let session: Session }
    private var registrations: [UIStableID: Registration] = [:]
    var beforeSceneRead: (() -> Void)?
    private var scenes: [UIStableID: Registration] {
        beforeSceneRead?(); return registrations
    }
    private struct MountWaiter {
        let token: UUID
        let continuation: CheckedContinuation<UIStableID, any Error>
    }
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
    func existing(_ manager: ObjectIdentifier, scene: String, foreground: Bool = true) {
        let sceneID = UIStableID(rawValue: scene)!
        registrations[sceneID] = .init(managerID: manager, session: .init(sceneID: sceneID, foreground: foreground))
    }
    func mount(_ manager: ObjectIdentifier, scene: String, foreground: Bool = true) {
        existing(manager, scene: scene, foreground: foreground)
        if foreground { activate(manager) }
    }
    func activate(_ manager: ObjectIdentifier) {
        guard let entry = registrations.values.first(where: { $0.managerID == manager }) else { return }
        entry.session.foreground = true
        let scene = entry.session.sceneID.rawValue
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
    private func waitForMount(managerID: ObjectIdentifier) async throws -> UIStableID {
        try Task.checkCancellation()
        let existing = scenes.values.filter { $0.managerID == managerID }
        if existing.count == 1, let value = existing.first, value.session.foreground { return value.session.sceneID }
        // A system URL can arrive after mount but before scenePhase becomes
        // active. Await only this manager's activation, within the original
        // URL deadline; never pick a different foreground window or re-admit.
        guard existing.count <= 1, mountWaiters[managerID] == nil, mountWaiters.count < 16 else { throw UIRouteError(.unavailable, "native_mount_admission_rejected") }
        let token = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                if Task.isCancelled { continuation.resume(throwing: CancellationError()) }
                else { mountWaiters[managerID] = .init(token: token, continuation: continuation) }
            }
        } onCancel: { [weak self] in
            Task { @MainActor in
                guard let self, self.mountWaiters[managerID]?.token == token else { return }
                self.mountWaiters.removeValue(forKey: managerID)?.continuation.resume(throwing: CancellationError())
            }
        }
    }
}
