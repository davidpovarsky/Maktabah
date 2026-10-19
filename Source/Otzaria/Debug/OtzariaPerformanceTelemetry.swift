import Foundation
#if canImport(os)
import os
#endif

/// Lightweight telemetry for profiling Otzaria operations.
/// Emits OSSignposts when available on Apple platforms and structured timing logs.
public final class OtzariaPerformanceTelemetry: @unchecked Sendable {
    public static let shared = OtzariaPerformanceTelemetry()

    #if canImport(os)
    @available(iOS 15.0, macOS 12.0, *)
    private struct SignposterHolder {
        static let subsystem = "org.maktabah.otzaria"
        static let readerSignposter = OSSignposter(subsystem: subsystem, category: "ReaderPerformance")
        static let inspectorSignposter = OSSignposter(subsystem: subsystem, category: "InspectorPerformance")
    }
    #endif

    public struct Interval: Sendable {
        let name: StaticString
        let startTime: Date
        #if canImport(os)
        let stateValue: Any?
        #endif

        init(name: StaticString) {
            self.name = name
            self.startTime = Date()
            #if canImport(os)
            if #available(iOS 15.0, macOS 12.0, *) {
                let id = SignposterHolder.readerSignposter.makeSignpostID()
                let state = SignposterHolder.readerSignposter.beginInterval(name, id: id)
                self.stateValue = state
            } else {
                self.stateValue = nil
            }
            #endif
        }

        public func end(extra: String? = nil) {
            let elapsedMs = Int(Date().timeIntervalSince(startTime) * 1000)
            #if canImport(os)
            if #available(iOS 15.0, macOS 12.0, *),
               let state = stateValue as? OSSignpostIntervalState {
                SignposterHolder.readerSignposter.endInterval(name, state)
            }
            #endif
            let details = extra.map { " \($0)" } ?? ""
            OtzariaFileLogger.shared.log("[Perf] [\(name)] finished in \(elapsedMs)ms\(details)")
        }
    }

    private init() {}

    public func begin(_ name: StaticString) -> Interval {
        Interval(name: name)
    }

    public func measure<T>(_ name: StaticString, extra: ((T) -> String)? = nil, work: () throws -> T) rethrows -> T {
        let interval = begin(name)
        let result = try work()
        interval.end(extra: extra?(result))
        return result
    }

    public func measureAsync<T>(_ name: StaticString, extra: ((T) -> String)? = nil, work: () async throws -> T) async rethrows -> T {
        let interval = begin(name)
        let result = try await work()
        interval.end(extra: extra?(result))
        return result
    }
}
