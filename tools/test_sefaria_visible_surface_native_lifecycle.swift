// VERBATIM original native callback/reset method bodies are inserted by the
// source runner. React/UIKit are boundary fixtures, not compiled native SDKs.
// The actual bridge actor, transition tokens, epochs and locks run unchanged.
import Foundation

private struct HookFailure: Error { let message: String }
@MainActor private class NativeEmitterBoundary {
    var superInvalidateObservation: SefariaEmbeddedSurfaceRuntimeObservation?
    func startObserving() {}
    func stopObserving() {}
    func invalidate() { superInvalidateObservation = SefariaJSRPCBridge.shared.currentSurfaceRuntimeObservation }
}
@MainActor private final class NativeModuleBoundary: NativeEmitterBoundary, SefariaJSTransport {
    var publications: [SefariaEmbeddedSurfaceRuntimeObservation] = []
    var hasListeners = false {
        willSet { publications.append(SefariaJSRPCBridge.shared.currentSurfaceRuntimeObservation) }
    }
    var customExecutor: (@Sendable (String) async throws -> Void)? {
        willSet { publications.append(SefariaJSRPCBridge.shared.currentSurfaceRuntimeObservation) }
    }
    func sendToJS(jsonString: String) async throws {}
__NATIVE_METHODS__
}
@MainActor private final class RuntimeResetBoundary {
    var observation: SefariaEmbeddedSurfaceRuntimeObservation?
    private func resetState() { observation = SefariaJSRPCBridge.shared.currentSurfaceRuntimeObservation }
__RESET_METHOD__
}

@main private struct NativeLifecycleControls {
    struct Result: Codable { let name: String; let passed: Bool; let detail: String? }
    @MainActor static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw HookFailure(message: message) }
    }
    @MainActor static func rejects(_ operation: () throws -> Void) -> Bool {
        do { try operation(); return false } catch { return true }
    }
    @MainActor static func settle() async throws {
        let clock = ContinuousClock(), deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while SefariaJSRPCBridge.shared.currentSurfaceRuntimeObservation.transitioning {
            if clock.now >= deadline { throw HookFailure(message: "source callback did not settle") }
            await Task.yield()
        }
        // Let the original callback task run in the historical unfenced variant
        // too. The extra actor read never contributes to any acceptance claim.
        for _ in 0..<8 { await Task.yield() }
    }
    @MainActor static func ready() async throws -> NativeModuleBoundary {
        let module = NativeModuleBoundary(), bridge = SefariaJSRPCBridge.shared
        await bridge.setTransport(module); await bridge.notifyListenersActive(true)
        let event = SefariaRPCEvent(event: "ready", sequence: 1, payloadJson: nil)
        await bridge.handleIncomingEvent(jsonString: String(decoding: try JSONEncoder().encode(event), as: UTF8.self))
        try expect(bridge.currentSurfaceRuntimeObservation.canPresent, "original actor did not become ready")
        return module
    }
    @MainActor static func event(_ name: String) throws -> String {
        String(decoding: try JSONEncoder().encode(SefariaRPCEvent(event: name, sequence: 1, payloadJson: nil)), as: UTF8.self)
    }
    @MainActor static func main() async throws {
        var results: [Result] = []
        func test(_ name: String, _ operation: () async throws -> Void) async {
            do { try await operation(); results.append(.init(name: name, passed: true, detail: nil)) }
            catch { results.append(.init(name: name, passed: false, detail: String(describing: error))) }
            try? await settle()
        }
        await test("native listener start is fenced before its own setter and queued actor work") {
            let module = try await ready(), token = try SefariaJSRPCBridge.shared.retainSurfaceRuntime()
            module.startObserving()
            try expect(module.publications.last?.transitioning == true, "native start setter preceded source invalidation")
            try expect(rejects { try token.validate() }, "native start returned with an earlier token still valid")
            try await settle()
            let listeners = await SefariaJSRPCBridge.shared.hasActiveListeners
            try expect(listeners, "original listener start did not execute")
        }
        await test("native listener stop is fenced before its own setter") {
            let module = try await ready(), token = try SefariaJSRPCBridge.shared.retainSurfaceRuntime()
            module.stopObserving()
            try expect(module.publications.last?.transitioning == true, "native stop setter preceded source invalidation")
            try expect(rejects { try token.validate() }, "native stop retained earlier authority")
            try await settle()
            let listeners = await SefariaJSRPCBridge.shared.hasActiveListeners
            try expect(!listeners, "original listener stop did not execute")
        }
        await test("native invalidate remains closed through original super invalidation") {
            let module = try await ready(), token = try SefariaJSRPCBridge.shared.retainSurfaceRuntime()
            module.invalidate()
            try expect(module.publications.last?.transitioning == true, "native invalidate setter preceded source boundary")
            try expect(module.superInvalidateObservation?.transitioning == true, "source reopened before super.invalidate returned")
            try expect(rejects { try token.validate() }, "invalidated native module retained token")
            try await settle()
            let transport = await SefariaJSRPCBridge.shared.hasTransport
            try expect(!transport, "original matching transport clear did not execute")
        }
        await test("executor replacement invalidates synchronously before original assignment") {
            let module = try await ready(), token = try SefariaJSRPCBridge.shared.retainSurfaceRuntime()
            module.setJSExecutor { _ in }
            try expect(module.publications.last?.transitioning == true, "executor write preceded source boundary")
            try expect(rejects { try token.validate() }, "executor replacement retained earlier authority")
        }
        await test("equal ready event invalidates before its queued actor handling") {
            let module = try await ready(), token = try SefariaJSRPCBridge.shared.retainSurfaceRuntime()
            module.deliverEvent(try event("ready"))
            try expect(rejects { try token.validate() }, "queued equal-ready event retained token")
            try expect(rejects { _ = try SefariaJSRPCBridge.shared.retainSurfaceRuntime() }, "queued event issued new authority")
            try await settle(); try SefariaJSRPCBridge.shared.retainSurfaceRuntime().validate()
        }
        await test("queued bootstrap error cannot lend actor's previous ready state") {
            let module = try await ready(), token = try SefariaJSRPCBridge.shared.retainSurfaceRuntime()
            module.deliverEvent(try event("bootstrapError"))
            try expect(rejects { try token.validate() }, "queued bootstrap error retained ready token")
            try await settle()
            try expect(!SefariaJSRPCBridge.shared.currentSurfaceRuntimeObservation.ready, "original bootstrap error did not execute")
        }
        await test("unrelated original events do not invalidate surface authority") {
            let module = try await ready(), token = try SefariaJSRPCBridge.shared.retainSurfaceRuntime()
            module.deliverEvent(try event("downloadProgress")); try token.validate()
            try await settle(); try token.validate()
        }
        await test("RuntimeManager reset fences its first original mutation before the actor hop") {
            _ = try await ready(); let runtime = RuntimeResetBoundary()
            let token = try SefariaJSRPCBridge.shared.retainSurfaceRuntime(), epoch = SefariaJSRPCBridge.shared.currentSessionEpoch
            await runtime.reset()
            try expect(runtime.observation?.transitioning == true, "resetState ran before the reset boundary")
            try expect(SefariaJSRPCBridge.shared.currentSessionEpoch == epoch + 1, "original reset bump changed")
            try expect(rejects { try token.validate() }, "reset retained an earlier native token")
        }
        let failures = results.filter { !$0.passed }.count
        struct Output: Codable { let scope: String; let passed: Int; let failed: Int; let results: [Result] }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let bytes = try encoder.encode(Output(scope: "verbatim native callback/reset boundary controls; React/UIKit NOT_RUN",
            passed: results.count - failures, failed: failures, results: results))
        print(String(decoding: bytes, as: UTF8.self)); exit(failures == 0 ? 0 : 1)
    }
}
