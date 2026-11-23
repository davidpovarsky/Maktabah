import Foundation
import Dispatch

/// XCTest still invokes some legacy synchronous callers outside an actor.
/// Establish the real main queue before entering the native observer; only
/// Sendable observer ownership or diagnostic values cross this synchronous seam.
private enum NativeCaptureMainActorEntry {
    static func run<Value: Sendable>(_ operation: @MainActor () -> Value) -> Value {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { operation() }
        }
        return DispatchQueue.main.sync {
            MainActor.assumeIsolated { operation() }
        }
    }
}


@MainActor private final class NativeCaptureBridgeProbe {
    private var evaluations: [[String: Any]] = []
    func evaluate(_ value: Int) -> Bool {
        precondition(Thread.isMainThread)
        evaluations.append(["value": value, "onMainThread": true])
        return true
    }
    func diagnostic() -> String {
        precondition(Thread.isMainThread)
        return String(decoding: try! JSONSerialization.data(withJSONObject: evaluations, options: [.sortedKeys]), as: UTF8.self)
    }
}

private final class Completion: @unchecked Sendable {
    private let lock = NSLock()
    private var finished = false
    private var evidence = ""
    func finish(_ value: String) {
        lock.lock(); evidence = value; finished = true; lock.unlock()
    }
    func snapshot() -> (Bool, String) {
        lock.lock(); defer { lock.unlock() }; return (finished, evidence)
    }
}

@main private enum BridgeControl {
    static func main() {
        precondition(Thread.isMainThread)
        let observation = NativeCaptureMainActorEntry.run { NativeCaptureBridgeProbe() }
        precondition(NativeCaptureMainActorEntry.run { observation.evaluate(1) })
        let first = NativeCaptureMainActorEntry.run { observation.diagnostic() }
        precondition(first.contains("\"value\":1"))
        let completion = Completion()
        DispatchQueue.global(qos: .userInitiated).async {
            precondition(!Thread.isMainThread)
            precondition(NativeCaptureMainActorEntry.run { observation.evaluate(2) })
            completion.finish(NativeCaptureMainActorEntry.run { observation.diagnostic() })
        }
        let deadline = Date().addingTimeInterval(5)
        while !completion.snapshot().0 && Date() < deadline {
            _ = RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
        let final = completion.snapshot()
        precondition(final.0 && final.1.contains("\"value\":1") && final.1.contains("\"value\":2"))
        print("{\"status\":\"DISPATCH_MAIN_ACTOR_BRIDGE_CONTROL_PASS\",\"directMainThread\":true,\"backgroundSynchronousEntry\":true,\"sendableObserverAndString\":true,\"nativeUIKitExecuted\":0}")
    }
}
