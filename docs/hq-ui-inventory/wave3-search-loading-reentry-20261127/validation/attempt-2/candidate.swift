import Foundation
import XCTest

// Explicit UI-state doubles only. Every access below occurs on the XCTest
// main run loop; they do not represent an application or a native element.
final class ElementBoundary: @unchecked Sendable {
    var exists: Bool
    var isHittable = true
    var value: Any? = "בראשית"
    init(exists: Bool = true) { self.exists = exists }
}
final class RowsBoundary: @unchecked Sendable {
    var storedCount = 0
    var reads = 0
    var count: Int { reads += 1; return storedCount }
}
final class UIBoundary: @unchecked Sendable {
    let elements = [
        "global-search-count": ElementBoundary(exists: false),
        "global-search-page-error": ElementBoundary(exists: false),
        "global-search-loading": ElementBoundary(exists: false),
        "global-search-dirty": ElementBoundary(exists: false),
        "global-search-retry": ElementBoundary()
    ]
    func control(_ id: String) -> ElementBoundary { elements[id]! }
}
final class TimelineBoundary: @unchecked Sendable {
    var events: [[String: Any]] = []
}
final class RejectionStabilityTests: XCTestCase, @unchecked Sendable {
    private let ui = UIBoundary()
    func testVerbatimOriginalRejectionStability() throws {
        precondition(Thread.isMainThread)
        let fixture = try XCTUnwrap(ProcessInfo.processInfo.environment["SEARCH_LOADING_FIXTURE"])
        let output = try XCTUnwrap(ProcessInfo.processInfo.environment["SEARCH_LOADING_RECORD"])
        let rows = RowsBoundary(), text = ElementBoundary(), field = ElementBoundary()
        let query = "בראשית"
        let timeline = TimelineBoundary()
        let started = Date().timeIntervalSince1970
        XCTAssertFalse(ui.control("global-search-loading").exists)
        timeline.events.append(["event": "initial_settled_rejection", "loading": false, "at": started])
        let mutation = Timer(timeInterval: 0.08, repeats: false) { [self] _ in
            MainActor.assumeIsolated {
                precondition(Thread.isMainThread)
                if fixture == "loading_reentry_persistent" || fixture == "loading_reentry_then_recovers" {
                    self.ui.control("global-search-loading").exists = true
                    timeline.events.append(["event": "loading_reentered", "rowsEvaluatedBefore": rows.reads,
                                            "at": Date().timeIntervalSince1970])
                } else if fixture == "original_result_rows_reenter" {
                    rows.storedCount = 1
                    timeline.events.append(["event": "result_rows_reentered", "rowsEvaluatedBefore": rows.reads,
                                            "at": Date().timeIntervalSince1970])
                }
            }
        }
        let recovery = Timer(timeInterval: 0.30, repeats: false) { [self] _ in
            MainActor.assumeIsolated {
                precondition(Thread.isMainThread)
                if fixture == "loading_reentry_then_recovers" {
                    self.ui.control("global-search-loading").exists = false
                    timeline.events.append(["event": "loading_recovered", "at": Date().timeIntervalSince1970])
                }
            }
        }
        mutation.fireDate = Date(timeIntervalSinceNow: 0.08)
        recovery.fireDate = Date(timeIntervalSinceNow: 0.30)
        RunLoop.main.add(mutation, forMode: .default)
        RunLoop.main.add(recovery, forMode: .default)
        defer { mutation.invalidate(); recovery.invalidate() }
        let stale = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { rows.count > 0 || self.ui.control("global-search-count").exists
                || self.ui.control("global-search-page-error").exists
                || self.ui.control("global-search-loading").exists || !text.exists }
        }, object: nil)
        stale.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [stale], timeout: 3), .completed,
                       "The settled rejection must not be replaced by an old page")
        XCTAssertEqual(field.value as? String, query)
        XCTAssertFalse(ui.control("global-search-dirty").exists)
        XCTAssertFalse(ui.control("global-search-loading").exists)
        XCTAssertTrue(ui.control("global-search-retry").isHittable)
        XCTAssertEqual(rows.count, 0)
        XCTAssertGreaterThan(rows.reads, 0, "The actual XCTest predicate must evaluate the initial source state")
        if fixture != "stable_rejection" {
            let transition = try XCTUnwrap(timeline.events.first { $0["rowsEvaluatedBefore"] != nil })
            XCTAssertGreaterThan(try XCTUnwrap(transition["at"] as? Double) - started, 0.05,
                                 "The explicit original-state transition must occur after its scheduled delay")
            XCTAssertGreaterThan(try XCTUnwrap(transition["rowsEvaluatedBefore"] as? Int), 0,
                                 "The bad state must reenter after at least one actual predicate evaluation")
        }
        let record: [String: Any] = [
            "schema": 1, "fixture": fixture, "events": timeline.events, "rowsReads": rows.reads,
            "loadingAtEnd": ui.control("global-search-loading").exists,
            "finishedAt": Date().timeIntervalSince1970,
            "scope": "Synthetic UI-state boundary with real XCTest predicate/waiter on Linux; no app/UI"
        ]
        XCTAssertFalse(FileManager.default.fileExists(atPath: output))
        try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
            .write(to: URL(fileURLWithPath: output), options: .withoutOverwriting)
    }
}
@main
enum RejectionStabilityRunner {
    static func main() {
        XCTMain([testCase([
            ("testVerbatimOriginalRejectionStability", RejectionStabilityTests.testVerbatimOriginalRejectionStability)
        ])])
    }
}
