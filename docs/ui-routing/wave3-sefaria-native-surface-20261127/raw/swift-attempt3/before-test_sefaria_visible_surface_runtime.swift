// Appended to the exact production bridge for access to its fileprivate source
// authority. The only test-only extension seeds the otherwise unreachable UInt64
// exhaustion boundary; production has no setter or rearming API for that value.
import Dispatch

fileprivate extension SefariaRPCSessionEpoch {
    func controlSeed(revision: UInt64) {
        lock.lock(); defer { lock.unlock() }
        state = .init(epoch: 7, revision: revision, ready: true, listeners: true,
                      transport: true, resourceMutation: false, transitioning: false, exhausted: false)
    }
}

private struct SurfaceControlFailure: Error { let message: String }
private struct SurfaceControlResult: Codable {
    let name: String
    let passed: Bool
    let detail: String?
}
private final class SurfaceControlTransport: SefariaJSTransport, @unchecked Sendable {
    let receive: @Sendable (String) async throws -> Void
    init(receive: @escaping @Sendable (String) async throws -> Void = { _ in }) { self.receive = receive }
    func sendToJS(jsonString: String) async throws { try await receive(jsonString) }
}
private actor SurfaceControlCapture {
    private var packet: SefariaRPCEnvelope?
    private var waiter: CheckedContinuation<SefariaRPCEnvelope, Never>?
    func receive(_ json: String) throws {
        let value = try JSONDecoder().decode(SefariaRPCEnvelope.self, from: Data(json.utf8))
        packet = value; waiter?.resume(returning: value); waiter = nil
    }
    func wait() async -> SefariaRPCEnvelope {
        if let packet { return packet }
        return await withCheckedContinuation { waiter = $0 }
    }
}

@main private struct SurfaceRuntimeControls {
    @MainActor private static var results: [SurfaceControlResult] = []
    @MainActor private static func expect(_ value: @autoclosure () -> Bool, _ message: String) throws {
        if !value() { throw SurfaceControlFailure(message: message) }
    }
    @MainActor private static func rejects(_ operation: () throws -> Void) -> Bool {
        do { try operation(); return false } catch { return true }
    }
    @MainActor private static func test(_ name: String, _ operation: () async throws -> Void) async {
        do { try await operation(); results.append(.init(name: name, passed: true, detail: nil)) }
        catch { results.append(.init(name: name, passed: false, detail: String(describing: error))) }
    }
    @MainActor private static func event(_ name: String) async throws {
        let value = SefariaRPCEvent(event: name, sequence: 1, payloadJson: nil)
        let json = String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
        await SefariaJSRPCBridge.shared.handleIncomingEvent(jsonString: json)
    }
    @MainActor private static func ready(_ transport: SurfaceControlTransport = .init()) async throws {
        let bridge = SefariaJSRPCBridge.shared
        await bridge.setTransport(transport)
        await bridge.notifyListenersActive(true)
        try await event("ready")
        try expect(bridge.currentSurfaceRuntimeObservation.canPresent, "original handshake did not become ready")
    }

    @MainActor static func main() async {
        let bridge = SefariaJSRPCBridge.shared
        await test("not-started bridge cannot issue a surface token") {
            try expect(rejects { _ = try bridge.retainSurfaceRuntime() }, "unstarted token was accepted")
        }
        await test("real actor fields and synchronous observation agree") {
            try await ready()
            let actual = bridge.currentSurfaceRuntimeObservation
            let isReady = await bridge.isReady, listeners = await bridge.hasActiveListeners
            let transport = await bridge.hasTransport, stable = await bridge.resourcesAreStable
            try expect(actual.epoch == bridge.currentSessionEpoch, "different epoch authority")
            try expect(actual.ready == isReady && actual.listeners == listeners && actual.transport == transport
                       && actual.resourceMutation == !stable, "readiness is not the actual actor state")
            try bridge.retainSurfaceRuntime().validate()
        }
        await test("listener false-true ABA invalidates without changing original RPC epoch") {
            try await ready(); let token = try bridge.retainSurfaceRuntime(); let epoch = bridge.currentSessionEpoch
            await bridge.notifyListenersActive(false); await bridge.notifyListenersActive(true)
            try expect(bridge.currentSessionEpoch == epoch, "existing listener epoch behavior changed")
            try expect(rejects { try token.validate() }, "listener ABA revived a token")
            try bridge.retainSurfaceRuntime().validate()
        }
        await test("bootstrap-error to ready ABA invalidates at the same epoch") {
            try await ready(); let token = try bridge.retainSurfaceRuntime(); let epoch = bridge.currentSessionEpoch
            try await event("bootstrapError"); try await event("ready")
            try expect(bridge.currentSessionEpoch == epoch, "existing ready epoch behavior changed")
            try expect(rejects { try token.validate() }, "ready ABA revived a token")
        }
        await test("equal-value listener lifecycle publication is still a new observation") {
            try await ready(); let token = try bridge.retainSurfaceRuntime()
            await bridge.notifyListenersActive(true)
            try expect(rejects { try token.validate() }, "repeated listener callback was ignored")
        }
        await test("equal-value ready lifecycle publication is still a new observation") {
            try await ready(); let token = try bridge.retainSurfaceRuntime()
            try await event("ready")
            try expect(rejects { try token.validate() }, "repeated ready callback was ignored")
        }
        await test("epoch A-B-A cannot revive a surface token") {
            try await ready(); let token = try bridge.retainSurfaceRuntime(); let epoch = bridge.currentSessionEpoch
            await bridge.setSessionEpoch(epoch + 1); await bridge.setSessionEpoch(epoch); try await event("ready")
            try expect(rejects { try token.validate() }, "epoch ABA revived a token")
        }
        await test("direct RuntimeManager bump closes its cancellation-before-epoch boundary") {
            let capture = SurfaceControlCapture()
            try await ready(SurfaceControlTransport { try await capture.receive($0) })
            let token = try bridge.retainSurfaceRuntime(), before = bridge.currentSurfaceRuntimeObservation
            let read = Task { try await bridge.call(method: "surface.awaitVisible", generation: before.epoch, timeoutMs: 2000) }
            _ = await capture.wait()
            let next = await bridge.bumpSessionEpoch()
            var cancelled = false
            do { _ = try await read.value } catch let error as SefariaRPCError { cancelled = error.code == "CANCELLED" }
            let after = bridge.currentSurfaceRuntimeObservation
            try expect(cancelled && next == before.epoch + 1, "direct bump lost original cancellation/epoch behavior")
            try expect(after.revision >= before.revision + 3 && !after.transitioning,
                       "direct bump omitted its own begin/end boundary around original cancelAll")
            try expect(rejects { try token.validate() }, "direct bump retained a stale native publication")
        }
        await test("nested lifecycle end cannot reopen an outer transition") {
            let authority = SefariaRPCSessionEpoch(); authority.controlSeed(revision: 1)
            let before = try authority.retainSurface()
            authority.beginTransition(); authority.beginTransition()
            authority.write(8); authority.endTransition()
            try expect(authority.surface().transitioning, "nested end cleared outer transition")
            try expect(rejects { _ = try authority.retainSurface() }, "nested boundary issued a token early")
            authority.endTransition()
            try expect(!authority.surface().transitioning && authority.surface().canPresent, "balanced outer boundary did not finish")
            try expect(rejects { try before.validate() }, "balanced boundary revived an old token")
            try authority.retainSurface().validate()
        }
        await test("unmatched lifecycle completion cannot make a source available") {
            let authority = SefariaRPCSessionEpoch(); authority.controlSeed(revision: 1)
            authority.endTransition()
            try expect(authority.surface().exhausted, "unmatched completion did not fail closed")
            try expect(rejects { _ = try authority.retainSurface() }, "unmatched completion issued a token")
        }
        await test("actual transport replacement revokes token before another handshake") {
            try await ready(); let token = try bridge.retainSurfaceRuntime(); let epoch = bridge.currentSessionEpoch
            await bridge.setTransport(SurfaceControlTransport())
            try expect(!bridge.currentSurfaceRuntimeObservation.canPresent, "replacement borrowed old ready")
            try expect(bridge.currentSessionEpoch == epoch + 1, "original transport epoch changed unexpectedly")
            try expect(rejects { try token.validate() }, "replacement retained authority")
        }
        await test("unrelated transport detach cannot revoke current original owner") {
            let original = SurfaceControlTransport(); try await ready(original)
            let token = try bridge.retainSurfaceRuntime()
            await bridge.clearTransportIfMatches(SurfaceControlTransport()); try token.validate()
            await bridge.clearTransportIfMatches(original)
            try expect(rejects { try token.validate() }, "matching detach retained authority")
            try expect(!bridge.currentSurfaceRuntimeObservation.canPresent, "detached transport advertised ready")
        }
        await test("original resource begin-end is unavailable throughout and revokes old token") {
            let capture = SurfaceControlCapture()
            let transport = SurfaceControlTransport { try await capture.receive($0) }
            try await ready(transport); let token = try bridge.retainSurfaceRuntime(); let epoch = bridge.currentSessionEpoch
            let operation = Task { try await bridge.call(method: "downloads.install", generation: epoch, timeoutMs: 2000) }
            let packet = await capture.wait()
            let during = bridge.currentSurfaceRuntimeObservation
            try expect(during.resourceMutation && !during.canPresent && during.epoch == epoch + 1, "resource begin was not fenced")
            try expect(rejects { _ = try bridge.retainSurfaceRuntime() }, "resource mutation issued a token")
            let response = SefariaRPCResponse(requestID: packet.requestID, status: "success", resultJson: "{}",
                                               sessionGeneration: packet.sessionGeneration)
            await bridge.handleIncomingResponse(jsonString: String(decoding: try JSONEncoder().encode(response), as: UTF8.self))
            _ = try await operation.value
            try expect(bridge.currentSessionEpoch == epoch + 2 && bridge.currentSurfaceRuntimeObservation.canPresent,
                       "original resource end behavior was not preserved")
            try expect(rejects { try token.validate() }, "resource begin-end revived old token")
        }
        await test("failed resource operation drains and keeps its two original epoch boundaries") {
            try await ready(SurfaceControlTransport { _ in throw SurfaceControlFailure(message: "injected transport error") })
            let token = try bridge.retainSurfaceRuntime(); let epoch = bridge.currentSessionEpoch
            do { _ = try await bridge.call(method: "downloads.remove", generation: epoch, timeoutMs: 1000) }
            catch { }
            try expect(bridge.currentSessionEpoch == epoch + 2 && bridge.currentSurfaceRuntimeObservation.canPresent,
                       "failed resource operation remained mutating or lost its epoch fence")
            try expect(rejects { try token.validate() }, "failed resource operation revived token")
        }
        await test("synchronous commit permits same-thread read validation without deadlock") {
            try await ready(); let token = try bridge.retainSurfaceRuntime(); var publications = 0
            try token.withValidRuntime {
                try token.validate()
                try expect(bridge.currentSurfaceRuntimeObservation == token.observation, "recursive read changed source")
                publications += 1
            }
            try expect(publications == 1, "native publication count changed")
        }
        await test("stale token cannot enter the synchronous publication") {
            try await ready(); let token = try bridge.retainSurfaceRuntime(); var publications = 0
            await bridge.notifyListenersActive(true)
            try expect(rejects { try token.withValidRuntime { publications += 1 } }, "stale publication was allowed")
            try expect(publications == 0, "stale operation ran before validation")
        }
        await test("writer contending with synchronous commit waits until its scope ends") {
            let authority = SefariaRPCSessionEpoch(); authority.controlSeed(revision: 12)
            let token = try authority.retainSurface()
            let started = DispatchSemaphore(value: 0), finished = DispatchSemaphore(value: 0)
            var writerFinishedInside = false
            try token.withValidRuntime {
                DispatchQueue.global().async {
                    started.signal()
                    authority.update { $0.listeners = false }
                    finished.signal()
                }
                try expect(started.wait(timeout: .now() + 2) == .success, "writer did not start")
                writerFinishedInside = finished.wait(timeout: .now() + 0.15) == .success
                try expect(!writerFinishedInside, "lifecycle writer entered native commit")
                try token.validate()
            }
            if !writerFinishedInside { try expect(finished.wait(timeout: .now() + 2) == .success, "writer did not finish after commit") }
            try expect(rejects { try token.validate() }, "post-commit writer did not invalidate token")
        }
        await test("revision exhaustion fails permanently instead of wrapping") {
            let authority = SefariaRPCSessionEpoch(); authority.controlSeed(revision: .max - 1)
            let before = try authority.retainSurface()
            authority.update { $0.ready = true }
            try expect(authority.surface().revision == .max && authority.surface().canPresent, "last distinct revision was lost")
            try expect(rejects { try before.validate() }, "exhaustion predecessor survived revision")
            let last = try authority.retainSurface()
            authority.update { $0.ready = true }
            try expect(authority.surface().exhausted && !authority.surface().canPresent, "revision wrapped or remained available")
            authority.update { $0.ready = true; $0.listeners = true }
            try expect(rejects { try last.validate() }, "exhausted token was revived")
            try expect(rejects { _ = try authority.retainSurface() }, "exhausted source issued another token")
        }
        await test("retained token owns its source authority for its full lifetime") {
            var authority: SefariaRPCSessionEpoch? = .init(); authority!.controlSeed(revision: 1)
            weak var weakAuthority = authority
            var token: SefariaEmbeddedSurfaceRuntimeToken? = try authority!.retainSurface()
            authority = nil; try expect(weakAuthority != nil, "retained source was released early")
            try token!.validate(); token = nil
            try expect(weakAuthority == nil, "surface token leaked the authority")
        }
        await test("typed native lease rejects another owner and stale free-state ABA") {
            let gate = SefariaEmbeddedSurfaceLease(), owner = UUID()
            let identity = SefariaEmbeddedSurfaceIdentity(id: UUID(), mountID: UUID(), sceneID: "scene-A", epoch: 7)
            let before = gate.snapshot
            let first = try gate.acquire(ownerID: owner, identity: identity, expected: before)
            try expect(gate.owns(first), "original lease was not owned")
            try expect(rejects { _ = try gate.acquire(ownerID: UUID(), identity: identity, expected: gate.snapshot) }, "second visible root was admitted")
            gate.release(.init(ownerID: UUID(), identity: identity, revision: first.revision))
            try expect(gate.owns(first), "foreign release erased original root")
            gate.release(first)
            try expect(rejects { _ = try gate.acquire(ownerID: owner, identity: identity, expected: before) }, "free-state ABA reused stale capture")
            let next = try gate.acquire(ownerID: owner, identity: identity, expected: gate.snapshot)
            gate.release(first); try expect(gate.owns(next), "old release erased a later root")
        }
        await test("native identity rejects imprecise JavaScript epochs") {
            let invalid = SefariaEmbeddedSurfaceIdentity(id: UUID(), mountID: UUID(), sceneID: "scene-A", epoch: 9_007_199_254_740_992)
            try expect(!invalid.valid, "lossy JS epoch admitted")
        }
        let summary: [String: String] = ["sourceSHA256": CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "missing",
                                       "scope": "portable source controls; native acceptance not run"]
        struct Output: Codable { let metadata: [String: String]; let passed: Int; let failed: Int; let results: [SurfaceControlResult] }
        let failures = results.filter { !$0.passed }.count
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(Output(metadata: summary, passed: results.count - failures, failed: failures, results: results)) {
            print(String(decoding: data, as: UTF8.self))
        }
        exit(failures == 0 ? 0 : 1)
    }
}
