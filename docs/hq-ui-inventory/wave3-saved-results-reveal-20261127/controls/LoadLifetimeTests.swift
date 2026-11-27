import Foundation
import Observation

@main struct LoadLifetimeTests {
    @MainActor static func main() {
        var passed = 0, failed = 0
        func check(_ name: String, _ body: @MainActor () -> Bool) {
            let value = body(); value ? (passed += 1) : (failed += 1)
            print("\(value ? "PASS" : "FAIL") \(name)")
        }
        check("fresh exact revision") {
            let value = OriginalSavedResultsLoadLifetime()
            return value.settledRevision == 0 && value.isCurrent(0)
        }
        check("begin invalidates before publication completes") {
            let value = OriginalSavedResultsLoadLifetime()
            _ = value.beginOriginalLoad()
            return value.settledRevision == nil && !value.isCurrent(0)
        }
        check("original completion publishes a new lifetime") {
            let value = OriginalSavedResultsLoadLifetime(); let load = value.beginOriginalLoad()
            value.endOriginalLoad(load, cancelled: false)
            return value.settledRevision == 2 && !value.isCurrent(0) && !value.lastCompletionWasCancelled
        }
        check("two real loads remain closed until both complete") {
            let value = OriginalSavedResultsLoadLifetime()
            let first = value.beginOriginalLoad(), second = value.beginOriginalLoad()
            value.endOriginalLoad(first, cancelled: false)
            guard value.settledRevision == nil else { return false }
            value.endOriginalLoad(second, cancelled: false)
            return value.settledRevision == 4
        }
        check("out of order completions retain exact tokens") {
            let value = OriginalSavedResultsLoadLifetime()
            let first = value.beginOriginalLoad(), second = value.beginOriginalLoad()
            value.endOriginalLoad(second, cancelled: false)
            guard value.settledRevision == nil else { return false }
            value.endOriginalLoad(first, cancelled: false)
            return value.settledRevision == 4
        }
        check("cancellation is recorded and cannot restore prior revision") {
            let value = OriginalSavedResultsLoadLifetime(); let load = value.beginOriginalLoad()
            value.endOriginalLoad(load, cancelled: true)
            return value.lastCompletionWasCancelled && value.settledRevision == 2 && !value.isCurrent(0)
        }
        check("duplicate actual completion fails closed") {
            let value = OriginalSavedResultsLoadLifetime(); let load = value.beginOriginalLoad()
            value.endOriginalLoad(load, cancelled: false); value.endOriginalLoad(load, cancelled: false)
            return value.settledRevision == nil
        }
        check("foreign token cannot complete another owner") {
            let first = OriginalSavedResultsLoadLifetime(), second = OriginalSavedResultsLoadLifetime()
            let load = first.beginOriginalLoad(); second.endOriginalLoad(load, cancelled: false)
            guard second.settledRevision == nil && first.settledRevision == nil else { return false }
            first.endOriginalLoad(load, cancelled: false)
            return first.settledRevision == 2
        }
        check("begin revision exhaustion stays closed") {
            let value = OriginalSavedResultsLoadLifetime(initialRevision: .max)
            let load = value.beginOriginalLoad(); value.endOriginalLoad(load, cancelled: false)
            return value.settledRevision == nil
        }
        check("completion revision exhaustion stays closed") {
            let value = OriginalSavedResultsLoadLifetime(initialRevision: .max - 1)
            let load = value.beginOriginalLoad(); value.endOriginalLoad(load, cancelled: false)
            return value.settledRevision == nil
        }
        check("bounded concurrent loads refuse metadata without stopping original calls") {
            let value = OriginalSavedResultsLoadLifetime()
            let loads = (0..<129).map { _ in value.beginOriginalLoad() }
            for load in loads { value.endOriginalLoad(load, cancelled: false) }
            return loads.count == 129 && value.settledRevision == nil
        }
        check("real Observation reentry cannot resurrect retired metadata") {
            let value = OriginalSavedResultsLoadLifetime()
            withObservationTracking { _ = value.revision } onChange: {
                MainActor.assumeIsolated { _ = value.beginOriginalLoad() }
            }
            let outer = value.beginOriginalLoad()
            value.endOriginalLoad(outer, cancelled: false)
            return value.settledRevision == nil && !value.isCurrent(2)
        }
        check("completion callback reentry stays retired") {
            let value = OriginalSavedResultsLoadLifetime(); let load = value.beginOriginalLoad()
            withObservationTracking { _ = value.revision } onChange: {
                MainActor.assumeIsolated { value.endOriginalLoad(load, cancelled: false) }
            }
            value.endOriginalLoad(load, cancelled: false)
            return value.settledRevision == nil
        }
        check("old completion after a new load cannot rearm") {
            let value = OriginalSavedResultsLoadLifetime(); let first = value.beginOriginalLoad()
            value.endOriginalLoad(first, cancelled: false)
            let second = value.beginOriginalLoad(); value.endOriginalLoad(first, cancelled: false)
            value.endOriginalLoad(second, cancelled: false)
            return value.settledRevision == nil
        }
        print("RESULT passed=\(passed) failed=\(failed)")
        if failed != 0 { exit(1) }
    }
}
