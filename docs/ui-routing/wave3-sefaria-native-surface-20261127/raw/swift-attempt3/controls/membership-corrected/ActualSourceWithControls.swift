//
//  SefariaJSRPCBridge.swift
//  Maktabah
//
//  Downstream-owned asynchronous RPC bridge between Swift and Sefaria-Mobile JS runtime.
//  Enforces single-resume continuations, actor-owned timeout handling, zero leaks,
//  generation guards, and event listener dispatching.
//

import Foundation

protocol SefariaJSTransport: AnyObject, Sendable {
    func sendToJS(jsonString: String) async throws
}

/// A synchronous, source-owned observation of the same RPC lifecycle fields.
/// The revision also changes for repeated listener/ready lifecycle publications.
struct SefariaEmbeddedSurfaceRuntimeObservation: Sendable, Equatable {
    fileprivate(set) var epoch: UInt64 = 1
    fileprivate(set) var revision: UInt64 = 0
    fileprivate(set) var ready = false
    fileprivate(set) var listeners = false
    fileprivate(set) var transport = false
    fileprivate(set) var resourceMutation = false
    fileprivate(set) var transitioning = false
    fileprivate(set) var exhausted = false
    var canPresent: Bool { ready && listeners && transport && !resourceMutation && !transitioning && !exhausted }
}

/// The RPC actor owns its readiness fields. The original native module also
/// begins invalidation boundaries synchronously, BEFORE queueing actor updates.
/// The same recursive lock covers native commit/report and these publications.
/// No actor call or suspension is permitted in that native critical section.
fileprivate final class SefariaRPCSessionEpoch: @unchecked Sendable {
    private let lock = NSRecursiveLock()
    private var state = SefariaEmbeddedSurfaceRuntimeObservation()
    private var transitionDepth: UInt64 = 0
    func read() -> UInt64 { surface().epoch }
    func surface() -> SefariaEmbeddedSurfaceRuntimeObservation {
        lock.lock(); defer { lock.unlock() }; return state
    }
    func update(_ change: (inout SefariaEmbeddedSurfaceRuntimeObservation) -> Void) {
        lock.lock(); defer { lock.unlock() }
        change(&state)
        if state.revision == .max { state.exhausted = true } else { state.revision += 1 }
    }
    func write(_ value: UInt64) { update { $0.epoch = value } }
    // The public bump operation is also called directly by RuntimeManager.reset.
    // Nested callers keep the OUTERMOST lifecycle boundary closed. No callback
    // or continuation is invoked while this short state-publication lock is held.
    func beginTransition() {
        lock.lock(); defer { lock.unlock() }
        if transitionDepth == .max { state.exhausted = true }
        else { transitionDepth += 1 }
        update { $0.transitioning = true }
    }
    func endTransition() {
        lock.lock(); defer { lock.unlock() }
        guard transitionDepth > 0 else {
            update { $0.exhausted = true }; return
        }
        transitionDepth -= 1
        update { $0.transitioning = transitionDepth > 0 }
    }
    func retainSurface() throws -> SefariaEmbeddedSurfaceRuntimeToken {
        lock.lock(); defer { lock.unlock() }
        guard state.canPresent else { throw unavailable() }
        return .init(authority: self, observation: state)
    }
    func validate(_ expected: SefariaEmbeddedSurfaceRuntimeObservation) throws {
        lock.lock(); defer { lock.unlock() }
        guard state == expected, state.canPresent else { throw unavailable() }
    }
    @MainActor func withSurface<T>(_ expected: SefariaEmbeddedSurfaceRuntimeObservation,
                                  operation: @MainActor () throws -> T) throws -> T {
        lock.lock(); defer { lock.unlock() }
        guard state == expected, state.canPresent else { throw unavailable() }
        let value = try operation()
        guard state == expected, state.canPresent else { throw unavailable() }
        return value
    }
    private func unavailable() -> SefariaRPCError {
        .init(code: "SURFACE_RUNTIME_CHANGED", message: "The original Sefaria runtime is not available for this retained surface.")
    }
}

/// This token cannot be decoded from public navigation input or rearmed after a
/// lifecycle change. It retains the bridge's authority, not a MainActor cache.
final class SefariaEmbeddedSurfaceRuntimeToken: @unchecked Sendable {
    fileprivate let authority: SefariaRPCSessionEpoch
    let observation: SefariaEmbeddedSurfaceRuntimeObservation
    fileprivate init(authority: SefariaRPCSessionEpoch, observation: SefariaEmbeddedSurfaceRuntimeObservation) {
        self.authority = authority; self.observation = observation
    }
    func validate() throws { try authority.validate(observation) }
    @MainActor func withValidRuntime<T>(_ operation: @MainActor () throws -> T) throws -> T {
        try authority.withSurface(observation, operation: operation)
    }
}

/// One exact source-owned native lifecycle boundary. Queueing an actor update
/// never leaves a window in which its already-started native mutation can borrow
/// an earlier ready state. Nested/out-of-order boundaries stay closed until all
/// finish. Dropping an unfinished lease does NOT manufacture completion.
final class SefariaEmbeddedSurfaceRuntimeTransition: @unchecked Sendable {
    private let authority: SefariaRPCSessionEpoch
    private let completionLock = NSLock()
    private var finished = false
    fileprivate init(authority: SefariaRPCSessionEpoch) {
        self.authority = authority
        authority.beginTransition()
    }
    func finish() {
        completionLock.lock()
        guard !finished else { completionLock.unlock(); return }
        finished = true
        completionLock.unlock()
        authority.endTransition()
    }
}

actor SefariaJSRPCBridge {
    static let shared = SefariaJSRPCBridge()

    private struct InFlightRequest {
        let continuation: CheckedContinuation<SefariaRPCResponse, any Error>
        let generation: UInt64
        let timeoutTask: Task<Void, Never>
    }

    private var transport: (any SefariaJSTransport)? {
        didSet { epochAuthority.update { $0.transport = transport != nil } }
    }
    private var inFlightRequests: [String: InFlightRequest] = [:]
    private var eventListeners: [String: [@Sendable (SefariaRPCEvent) -> Void]] = [:]

    private(set) var isReady: Bool {
        get { epochAuthority.surface().ready }
        set { epochAuthority.update { $0.ready = newValue } }
    }
    private(set) var hasActiveListeners: Bool {
        get { epochAuthority.surface().listeners }
        set { epochAuthority.update { $0.listeners = newValue } }
    }
    private nonisolated let epochAuthority = SefariaRPCSessionEpoch()
    private(set) var sessionEpoch: UInt64 {
        get { epochAuthority.read() }
        set { epochAuthority.write(newValue) }
    }
    nonisolated var currentSessionEpoch: UInt64 { epochAuthority.read() }
    private var resourceMutationInProgress: Bool {
        get { epochAuthority.surface().resourceMutation }
        set { epochAuthority.update { $0.resourceMutation = newValue } }
    }
    nonisolated var currentSurfaceRuntimeObservation: SefariaEmbeddedSurfaceRuntimeObservation {
        epochAuthority.surface()
    }
    nonisolated func retainSurfaceRuntime() throws -> SefariaEmbeddedSurfaceRuntimeToken {
        try epochAuthority.retainSurface()
    }
    nonisolated func beginSurfaceLifecycleTransition() -> SefariaEmbeddedSurfaceRuntimeTransition {
        .init(authority: epochAuthority)
    }

    var resourcesAreStable: Bool { !resourceMutationInProgress }

    var hasTransport: Bool {
        return transport != nil
    }

    var isTransportReady: Bool {
        return isReady && transport != nil && hasActiveListeners
    }

    private init() {}

    func setSessionEpoch(_ epoch: UInt64) {
        guard epoch != sessionEpoch else { return }
        epochAuthority.beginTransition()
        defer { epochAuthority.endTransition() }
        cancelAll(reason: "Session epoch changed")
        isReady = false
        self.sessionEpoch = epoch
    }

    func bumpSessionEpoch() -> UInt64 {
        epochAuthority.beginTransition()
        defer { epochAuthority.endTransition() }
        cancelAll(reason: "Session epoch changed")
        sessionEpoch &+= 1
        return sessionEpoch
    }

    func setTransport(_ transport: (any SefariaJSTransport)?) {
        if let current = self.transport, let transport, current === transport { return }
        epochAuthority.beginTransition()
        defer { epochAuthority.endTransition() }
        // A replacement host must repeat its handshake. Old requests and
        // readiness cannot be carried across two Hermes instances.
        _ = bumpSessionEpoch()
        isReady = false
        hasActiveListeners = false
        self.transport = transport
        if transport == nil {
            self.isReady = false
            self.hasActiveListeners = false
            cancelAll(reason: "Transport detached")
        }
    }

    func clearTransportIfMatches(_ transport: any SefariaJSTransport) {
        if let current = self.transport, (current as AnyObject) === (transport as AnyObject) {
            epochAuthority.beginTransition()
            defer { epochAuthority.endTransition() }
            NSLog("[SefariaJSRPCBridge] clearTransportIfMatches: clearing transport")
            self.transport = nil
            _ = bumpSessionEpoch()
            self.isReady = false
            self.hasActiveListeners = false
            cancelAll(reason: "Transport invalidated")
        }
    }

    func notifyListenersActive(_ active: Bool) {
        NSLog("[SefariaJSRPCBridge] notifyListenersActive: %d", active)
        self.hasActiveListeners = active
    }

    /// Awaits validated readiness from the Sefaria Hermes runtime with generation and listener checks.
    func waitForReady(timeoutSeconds: Double = 30.0, expectedGeneration: UInt64? = nil) async throws {
        if isTransportReady {
            if let expected = expectedGeneration, sessionEpoch != expected {
                // Not matching expected generation, continue waiting below
            } else {
                NSLog("[SefariaJSRPCBridge] waitForReady: already ready with active transport and listeners")
                return
            }
        }

        NSLog("[SefariaJSRPCBridge] waitForReady: awaiting ready event (timeout: %.1fs)...", timeoutSeconds)
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if isReady && transport != nil && hasActiveListeners {
                if let expected = expectedGeneration, sessionEpoch != expected {
                    // Waiting for matching epoch
                } else {
                    NSLog("[SefariaJSRPCBridge] waitForReady: successfully became ready!")
                    return
                }
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        if isReady && transport != nil && hasActiveListeners {
            if let expected = expectedGeneration, sessionEpoch != expected {
                // Mismatch
            } else {
                return
            }
        }

        let state = "isReady=\(isReady), transport=\(transport != nil), hasListeners=\(hasActiveListeners), sessionEpoch=\(sessionEpoch)"
        NSLog("[SefariaJSRPCBridge] waitForReady FAILED: %@", state)
        throw SefariaRPCError(
            code: "READY_TIMEOUT",
            message: "Timed out waiting for Sefaria JS runtime 'ready' event after \(timeoutSeconds)s (\(state))",
            retryable: true
        )
    }

    private func notifyReady() {
        NSLog("[SefariaJSRPCBridge] notifyReady: Hermes runtime ready event received!")
        isReady = true
    }

    /// Dispatches an RPC call to the Sefaria runtime with bounded timeout, generation tracking,
    /// and cancellation-safe continuation management.
    func call(
        method: String,
        paramsJson: String? = nil,
        generation: UInt64? = nil,
        timeoutMs: Int = 15000
    ) async throws -> SefariaRPCResponse {
        try Task.checkCancellation()
        // Invalidate read snapshots at both boundaries of a resource mutation.
        // Read-only action discovery never initiates one of these operations.
        let mutatesResources = ["downloads.install", "downloads.remove", "updates.download"].contains(method)
        if mutatesResources {
            guard !resourceMutationInProgress else {
                throw SefariaRPCError(code: "RESOURCE_BUSY", message: "Another resource operation is active", retryable: true)
            }
            if let generation, generation != sessionEpoch {
                throw SefariaRPCError(code: "STALE_GENERATION", message: "RPC session changed", retryable: true)
            }
            epochAuthority.beginTransition()
            _ = bumpSessionEpoch()
            resourceMutationInProgress = true
            epochAuthority.endTransition()
        }
        defer {
            if mutatesResources {
                epochAuthority.beginTransition()
                resourceMutationInProgress = false
                _ = bumpSessionEpoch()
                epochAuthority.endTransition()
            }
        }
        let requestID = UUID().uuidString
        let effectiveGeneration = mutatesResources ? sessionEpoch : generation ?? sessionEpoch
        guard effectiveGeneration == sessionEpoch else {
            throw SefariaRPCError(code: "STALE_GENERATION", message: "RPC session changed", retryable: true)
        }
        guard timeoutMs > 0, timeoutMs <= 600_000 else {
            throw SefariaRPCError(code: "INVALID_TIMEOUT", message: "RPC timeout is outside supported bounds")
        }
        let envelope = SefariaRPCEnvelope(
            protocolVersion: "1.0",
            requestID: requestID,
            method: method,
            paramsJson: paramsJson,
            backendID: BackendID.sefariaEmbedded.rawValue,
            sessionGeneration: effectiveGeneration,
            timeoutMs: timeoutMs
        )

        guard let transport = self.transport else {
            throw SefariaRPCError(
                code: "TRANSPORT_UNAVAILABLE",
                message: "React Native transport bridge is not initialized or ready.",
                retryable: true
            )
        }

        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(envelope),
              let jsonString = String(data: data, encoding: .utf8) else {
            throw SefariaRPCError(
                code: "ENVELOPE_ENCODING_FAILED",
                message: "Failed to encode RPC envelope for method '\(method)'"
            )
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.registerInFlight(
                    requestID: requestID,
                    continuation: continuation,
                    generation: effectiveGeneration,
                    timeoutMs: timeoutMs,
                    method: method
                )
                Task {
                    do {
                        guard self.inFlightRequests[requestID] != nil,
                              self.sessionEpoch == effectiveGeneration else { return }
                        try await transport.sendToJS(jsonString: jsonString)
                    } catch {
                        self.failInFlight(requestID: requestID, error: error)
                    }
                }
            }
        } onCancel: {
            Task {
                await self.cancelInFlight(requestID: requestID)
            }
        }
    }

    private func registerInFlight(
        requestID: String,
        continuation: CheckedContinuation<SefariaRPCResponse, any Error>,
        generation: UInt64,
        timeoutMs: Int,
        method: String
    ) {
        let timeoutTask = Task { [weak self, requestID, method, timeoutMs] in
            try? await Task.sleep(nanoseconds: UInt64(timeoutMs) * 1_000_000)
            await self?.handleTimeout(requestID: requestID, method: method, timeoutMs: timeoutMs)
        }
        inFlightRequests[requestID] = InFlightRequest(
            continuation: continuation,
            generation: generation,
            timeoutTask: timeoutTask
        )
    }

    private func handleTimeout(requestID: String, method: String, timeoutMs: Int) {
        guard let req = inFlightRequests.removeValue(forKey: requestID) else { return }
        req.continuation.resume(throwing: SefariaRPCError(
            code: "TIMEOUT",
            message: "RPC call to '\(method)' timed out after \(timeoutMs)ms",
            retryable: true
        ))
    }

    func handleIncomingResponse(jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let response = try? JSONDecoder().decode(SefariaRPCResponse.self, from: data) else {
            return
        }

        guard let req = inFlightRequests.removeValue(forKey: response.requestID) else {
            // Late response after timeout or stale request - safely ignored
            return
        }
        req.timeoutTask.cancel()

        // Validate protocol version
        if response.protocolVersion != "1.0" {
            req.continuation.resume(throwing: SefariaRPCError(
                code: "PROTOCOL_VERSION_MISMATCH",
                message: "Response protocol version '\(response.protocolVersion)' is incompatible with expected '1.0'",
                retryable: false
            ))
            return
        }

        // Validate backend ID if specified in response
        if let backendID = response.backendID, !backendID.isEmpty, backendID != BackendID.sefariaEmbedded.rawValue {
            req.continuation.resume(throwing: SefariaRPCError(
                code: "BACKEND_MISMATCH",
                message: "Response backend '\(backendID)' does not match expected '\(BackendID.sefariaEmbedded.rawValue)'",
                retryable: false
            ))
            return
        }

        // Strict generation validation: response must match in-flight generation (no zero-bypass)
        if response.sessionGeneration != req.generation || req.generation != sessionEpoch {
            req.continuation.resume(throwing: SefariaRPCError(
                code: "STALE_GENERATION",
                message: "Response generation \(response.sessionGeneration) does not match in-flight generation \(req.generation)",
                retryable: false
            ))
            return
        }

        req.continuation.resume(returning: response)
    }

    private func failInFlight(requestID: String, error: any Error) {
        guard let req = inFlightRequests.removeValue(forKey: requestID) else { return }
        req.timeoutTask.cancel()
        req.continuation.resume(throwing: error)
    }

    private func cancelInFlight(requestID: String) {
        guard let req = inFlightRequests.removeValue(forKey: requestID) else { return }
        req.timeoutTask.cancel()
        req.continuation.resume(throwing: CancellationError())
    }

    /// Cancels all pending in-flight requests (e.g. during a backend switch or runtime reset).
    func cancelAll(reason: String = "Session invalidated") {
        for (_, req) in inFlightRequests {
            req.timeoutTask.cancel()
            req.continuation.resume(throwing: SefariaRPCError(code: "CANCELLED", message: reason, retryable: false))
        }
        inFlightRequests.removeAll()
    }

    func cancelAllInFlight() {
        cancelAll(reason: "Backend invalidated")
    }

    // MARK: - Event Subscriptions

    func addEventListener(for eventName: String, listener: @escaping @Sendable (SefariaRPCEvent) -> Void) {
        var listeners = eventListeners[eventName] ?? []
        listeners.append(listener)
        eventListeners[eventName] = listeners
    }

    func handleIncomingEvent(jsonString: String) {
        NSLog("[SefariaJSRPCBridge] handleIncomingEvent: %@", jsonString)
        guard let data = jsonString.data(using: .utf8),
              let event = try? JSONDecoder().decode(SefariaRPCEvent.self, from: data) else {
            return
        }

        if event.event == "ready" {
            notifyReady()
        } else if event.event == "bootstrapError" {
            NSLog("[SefariaJSRPCBridge] bootstrapError received: %@", event.payloadJson ?? "")
            isReady = false
        }

        if let listeners = eventListeners[event.event] {
            for listener in listeners {
                listener(event)
            }
        }
    }
}

// The runner inserts VERBATIM methods from the production scene binding below.
// UIKit/source-owner collaborators are reduced to boundary fixtures; the runtime
// token and its synchronous lock are the real production bridge implementation.
// These controls do not claim a compiled iOS host or native acceptance.
import Foundation

fileprivate extension SefariaRPCSessionEpoch {
    func membershipControlReady() {
        update { $0.ready = true; $0.listeners = true; $0.transport = true }
    }
}
private struct UIRouteError: Error {
    enum Code { case unavailable, staleState }
    let code: Code
    let detail: String
    init(_ code: Code, _ detail: String) { self.code = code; self.detail = detail }
}
private struct MembershipFailure: Error { let message: String }

@MainActor private final class MembershipBoundary {
    private final class OriginalSourceProof {
        let runtime: SefariaEmbeddedSurfaceRuntimeToken
        private var valid = true
        init() throws {
            let authority = SefariaRPCSessionEpoch(); authority.membershipControlReady()
            runtime = try authority.retainSurface()
        }
        func invalidate() { valid = false }
        func validate() throws {
            try runtime.validate()
            guard valid else { throw UIRouteError(.staleState, "fixture original source invalidated") }
        }
    }
    @MainActor private final class SourceEntry {
        let original: OriginalSourceProof
        init() throws { original = try .init() }
    }
    private struct Pending {
        let token = UUID()
        let requestID: UUID
        let validate: @MainActor () throws -> Void
        var applied = false
        var openedNewSurface = false
    }
    private struct RetainedRequest: Sendable {
        let requestID: UUID
        let pendingToken: UUID
        let source: SourceEntry
    }
    private struct Observed { let source: SourceEntry }
    private struct Completed { let observed: Observed }
    private var sources: [UUID: SourceEntry] = [:]
    private var pending: Pending?
    private var completed: Completed?
    private var finishes = 0

    private func validate(_ source: SourceEntry) throws { try source.original.validate() }
    private func validateSource(requestID: UUID) throws {
        guard let entry = sources[requestID] else { throw UIRouteError(.staleState, "missing source") }
        try validate(entry)
    }
    private func finish(requestID: UUID, completed: Bool) {
        guard pending?.requestID == requestID else { return }
        finishes += 1; pending = nil
    }

    // BEGIN_VERBATIM_PRODUCTION_METHODS
    func releaseSource(requestID: UUID) {
        guard let entry = sources.removeValue(forKey: requestID) else { return }
        // Only the exact completed receipt may retain its proof after the outer
        // public operation releases its map membership. An early/reentrant
        // release revokes the active operation and joins its normal cleanup.
        let retainsCompleted = pending == nil && completed?.observed.source === entry
        if !retainsCompleted { entry.original.invalidate() }
        if pending?.requestID == requestID { finish(requestID: requestID, completed: false) }
    }
    func begin(requestID: UUID, validate: @escaping @MainActor () throws -> Void) throws {
        guard pending == nil, let entry = sources[requestID] else {
            throw UIRouteError(.unavailable, "native_sefaria_surface_busy")
        }
        try self.validate(entry); try validate()
        guard pending == nil, sources[requestID] === entry else {
            throw UIRouteError(.staleState, "native_sefaria_observation_changed")
        }
        try self.validate(entry)
        completed = nil
        pending = .init(requestID: requestID, validate: validate)
    }
    private func withSource<T>(requestID: UUID, operation: @MainActor (SourceEntry) throws -> T) throws -> T {
        try withSource(request: retainedRequest(requestID), operation: operation)
    }
    private func retainedRequest(_ requestID: UUID) throws -> RetainedRequest {
        guard let entry = sources[requestID], let pending, pending.requestID == requestID else {
            throw UIRouteError(.staleState, "native_sefaria_observation_changed")
        }
        return .init(requestID: requestID, pendingToken: pending.token, source: entry)
    }
    private func validateMembership(_ request: RetainedRequest) throws {
        guard sources[request.requestID] === request.source,
              pending?.requestID == request.requestID, pending?.token == request.pendingToken else {
            throw UIRouteError(.staleState, "native_sefaria_observation_changed")
        }
    }
    private func withSource<T>(request: RetainedRequest, operation: @MainActor (SourceEntry) throws -> T) throws -> T {
        try validateMembership(request)
        let entry = request.source
        return try entry.original.runtime.withValidRuntime {
            try validateMembership(request); try validate(entry)
            guard let validateAdmission = pending?.validate else {
                throw UIRouteError(.staleState, "native_sefaria_observation_changed")
            }
            try validateAdmission()
            try validateMembership(request); try validate(entry)
            let value = try operation(entry)
            try validateMembership(request); try validate(entry)
            try validateAdmission()
            try validateMembership(request); try validate(entry)
            return value
        }
    }
    // END_VERBATIM_PRODUCTION_METHODS

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw MembershipFailure(message: message) }
    }
    private static func rejects(_ operation: () throws -> Void) -> Bool {
        do { try operation(); return false } catch { return true }
    }
    private static func setup(_ admission: @escaping @MainActor (MembershipBoundary, UUID) throws -> Void = { _, _ in }) throws
        -> (MembershipBoundary, UUID, SourceEntry) {
        let owner = MembershipBoundary(), requestID = UUID(), entry = try SourceEntry()
        owner.sources[requestID] = entry
        owner.pending = .init(requestID: requestID, validate: { try admission(owner, requestID) })
        return (owner, requestID, entry)
    }
    struct Result: Codable { let name: String; let passed: Bool; let detail: String? }
    static func run() -> [Result] {
        var results: [Result] = []
        func test(_ name: String, _ operation: () throws -> Void) {
            do { try operation(); results.append(.init(name: name, passed: true, detail: nil)) }
            catch { results.append(.init(name: name, passed: false, detail: String(describing: error))) }
        }
        test("exact active original source publishes once") {
            var validations = 0, publications = 0
            let (owner, requestID, _) = try setup { _, _ in validations += 1 }
            try owner.withSource(requestID: requestID) { _ in publications += 1 }
            try expect(publications == 1 && validations == 2, "one original operation was not preserved")
        }
        test("first admission callback removing map membership prevents publication") {
            var publications = 0
            let (owner, requestID, _) = try setup { owner, requestID in owner.sources.removeValue(forKey: requestID) }
            try expect(rejects { try owner.withSource(requestID: requestID) { _ in publications += 1 } }, "removed membership accepted")
            try expect(publications == 0, "source was published after callback released it")
        }
        test("reentrant active release invalidates and finishes the exact request") {
            var publications = 0
            let (owner, requestID, entry) = try setup { owner, requestID in owner.releaseSource(requestID: requestID) }
            try expect(rejects { try owner.withSource(requestID: requestID) { _ in publications += 1 } }, "active release accepted")
            try expect(publications == 0 && owner.pending == nil && owner.finishes == 1, "active release did not finish safely")
            try expect(rejects { try entry.original.validate() }, "released original proof remained live")
        }
        test("same request identifier with replacement source is not the original source") {
            var publications = 0
            let (owner, requestID, _) = try setup { owner, requestID in owner.sources[requestID] = try SourceEntry() }
            try expect(rejects { try owner.withSource(requestID: requestID) { _ in publications += 1 } }, "replacement source accepted")
            try expect(publications == 0, "replacement source inherited an earlier grant")
        }
        test("same request identifier with a replacement Pending is a different operation") {
            var publications = 0
            let (owner, requestID, _) = try setup { owner, requestID in
                owner.pending = .init(requestID: requestID, validate: {})
            }
            try expect(rejects { try owner.withSource(requestID: requestID) { _ in publications += 1 } }, "replacement pending accepted")
            try expect(publications == 0, "copied pending survived replacement")
        }
        test("finished admission cannot execute from a copied Pending") {
            var publications = 0
            let (owner, requestID, _) = try setup { owner, requestID in owner.finish(requestID: requestID, completed: false) }
            try expect(rejects { try owner.withSource(requestID: requestID) { _ in publications += 1 } }, "finished pending accepted")
            try expect(publications == 0, "finished admission published an old action")
        }
        test("report callback release is rejected on the same synchronous boundary") {
            let (owner, requestID, entry) = try setup()
            try expect(rejects { try owner.withSource(requestID: requestID) { _ in owner.releaseSource(requestID: requestID) } },
                       "report callback released source without rejection")
            try expect(rejects { try entry.original.validate() }, "released report retained authority")
        }
        test("report callback completion cannot return through stale copied Pending") {
            let (owner, requestID, _) = try setup()
            try expect(rejects { try owner.withSource(requestID: requestID) { _ in owner.finish(requestID: requestID, completed: false) } },
                       "completed report returned under stale pending")
        }
        test("last admission callback is followed by fresh membership validation") {
            var validations = 0
            let (owner, requestID, _) = try setup { owner, requestID in
                validations += 1
                if validations == 2 { owner.sources.removeValue(forKey: requestID) }
            }
            try expect(rejects { try owner.withSource(requestID: requestID) { _ in } }, "last callback removal accepted")
        }
        test("original source invalidation is checked after admission callback") {
            var publications = 0
            let (owner, requestID, _) = try setup { owner, requestID in owner.sources[requestID]?.original.invalidate() }
            try expect(rejects { try owner.withSource(requestID: requestID) { _ in publications += 1 } }, "invalid original proof accepted")
            try expect(publications == 0, "invalid source executed before the late check")
        }
        test("begin cannot publish Pending after its admission callback releases source") {
            let owner = MembershipBoundary(), requestID = UUID(), entry = try SourceEntry()
            owner.sources[requestID] = entry
            try expect(rejects { try owner.begin(requestID: requestID) { owner.releaseSource(requestID: requestID) } },
                       "begin restored released source")
            try expect(owner.pending == nil, "begin created a stale pending operation")
        }
        test("begin cannot overwrite a reentrant Pending") {
            let owner = MembershipBoundary(), requestID = UUID(), other = UUID()
            owner.sources[requestID] = try SourceEntry()
            try expect(rejects { try owner.begin(requestID: requestID) {
                owner.pending = .init(requestID: other, validate: {})
            } }, "begin overwrote another operation")
            try expect(owner.pending?.requestID == other, "earlier begin stole later ownership")
        }
        test("only exact successfully completed receipt proof survives normal release") {
            let (owner, requestID, entry) = try setup()
            owner.pending = nil; owner.completed = .init(observed: .init(source: entry))
            owner.releaseSource(requestID: requestID)
            try entry.original.validate()
            try expect(owner.sources[requestID] == nil, "normal release retained map ownership")
        }
        test("unrelated completed proof does not retain a released source") {
            let (owner, requestID, entry) = try setup()
            owner.pending = nil; owner.completed = .init(observed: .init(source: try SourceEntry()))
            owner.releaseSource(requestID: requestID)
            try expect(rejects { try entry.original.validate() }, "foreign completed proof retained source")
        }
        return results
    }
}

@main private struct MembershipControls {
    @MainActor static func main() throws {
        let results = MembershipBoundary.run(), failures = results.filter { !$0.passed }.count
        struct Output: Codable { let scope: String; let passed: Int; let failed: Int; let results: [MembershipBoundary.Result] }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let bytes = try encoder.encode(Output(scope: "verbatim source boundary controls; UIKit/native not run",
            passed: results.count - failures, failed: failures, results: results))
        print(String(decoding: bytes, as: UTF8.self)); exit(failures == 0 ? 0 : 1)
    }
}
