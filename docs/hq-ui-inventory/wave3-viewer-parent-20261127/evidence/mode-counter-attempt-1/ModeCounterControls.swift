import Foundation
import Observation

enum AppMode: Equatable { case viewer, history, search }

@MainActor @Observable final class OriginalModeOwner {
    var currentMode: AppMode = .viewer {
        willSet {
            // Observe every original mode publication, including equal writes.
            // This metadata neither selects a mode nor replaces TabView's owner.
            if let revision = nativeModePresentationRevision, revision < .max {
                nativeModePresentationRevision = revision + 1
            } else {
                nativeModePresentationRevision = nil
            }
        }
    }
    private(set) var nativeModePresentationRevision: UInt64? = 0
}

@MainActor @Observable final class IgnoredModeOwner {
    var currentMode: AppMode = .viewer {
        willSet {
            // Observe every original mode publication, including equal writes.
            // This metadata neither selects a mode nor replaces TabView's owner.
            if let revision = nativeModePresentationRevision, revision < .max {
                nativeModePresentationRevision = revision + 1
            } else {
                nativeModePresentationRevision = nil
            }
        }
    }
    @ObservationIgnored private(set) var nativeModePresentationRevision: UInt64? = 0
}

@MainActor final class Writes {
    var value = 0
    var reentered = false
}
@main struct Controls {
    @MainActor static func main() throws {
        var rows: [[String: Any]] = []
        func report(_ name: String, _ pass: Bool, _ details: [String: Any]) {
            rows.append(["name": name, "pass": pass, "details": details])
        }
        do {
            let owner = OriginalModeOwner(), writes = Writes()
            withObservationTracking { _ = owner.nativeModePresentationRevision } onChange: {
                MainActor.assumeIsolated {
                    if !writes.reentered {
                        writes.reentered = true; writes.value += 1; owner.currentMode = .viewer
                    }
                }
            }
            writes.value += 1; owner.currentMode = .history
            report("original.counter-observer-reentry-counts-every-setter", owner.nativeModePresentationRevision == UInt64(writes.value),
                   ["actualSetters": writes.value, "revision": owner.nativeModePresentationRevision as Any,
                    "reentered": writes.reentered, "finalMode": String(describing: owner.currentMode)])
        }
        do {
            let owner = IgnoredModeOwner(), writes = Writes()
            withObservationTracking { _ = owner.nativeModePresentationRevision } onChange: {
                MainActor.assumeIsolated {
                    if !writes.reentered {
                        writes.reentered = true; writes.value += 1; owner.currentMode = .viewer
                    }
                }
            }
            writes.value += 1; owner.currentMode = .history
            report("candidate.passive-counter-has-no-reentrant-callback", !writes.reentered && writes.value == 1 && owner.nativeModePresentationRevision == 1,
                   ["actualSetters": writes.value, "revision": owner.nativeModePresentationRevision as Any,
                    "reentered": writes.reentered])
        }
        do {
            let owner = OriginalModeOwner(), writes = Writes()
            withObservationTracking { _ = owner.currentMode } onChange: {
                MainActor.assumeIsolated {
                    if !writes.reentered {
                        writes.reentered = true; writes.value += 1; owner.currentMode = .search
                    }
                }
            }
            writes.value += 1; owner.currentMode = .history
            report("original.actual-mode-observer-reentry-is-counted", writes.value == 2 && owner.nativeModePresentationRevision == 2,
                   ["actualSetters": writes.value, "revision": owner.nativeModePresentationRevision as Any])
        }
        do {
            let owner = IgnoredModeOwner(), writes = Writes()
            withObservationTracking { _ = owner.currentMode } onChange: {
                MainActor.assumeIsolated {
                    if !writes.reentered {
                        writes.reentered = true; writes.value += 1; owner.currentMode = .search
                    }
                }
            }
            writes.value += 1; owner.currentMode = .history
            report("candidate.actual-mode-observer-reentry-is-counted", writes.value == 2 && owner.nativeModePresentationRevision == 2,
                   ["actualSetters": writes.value, "revision": owner.nativeModePresentationRevision as Any])
        }
        do {
            let original = OriginalModeOwner(), candidate = IgnoredModeOwner()
            original.currentMode = .viewer; original.currentMode = .viewer
            candidate.currentMode = .viewer; candidate.currentMode = .viewer
            report("original.equal-mode-publications-count", original.nativeModePresentationRevision == 2,
                   ["revision": original.nativeModePresentationRevision as Any])
            report("candidate.equal-mode-publications-count", candidate.nativeModePresentationRevision == 2,
                   ["revision": candidate.nativeModePresentationRevision as Any])
            candidate.currentMode = .history; candidate.currentMode = .viewer
            report("candidate.ABA-publications-count", candidate.currentMode == .viewer && candidate.nativeModePresentationRevision == 4,
                   ["revision": candidate.nativeModePresentationRevision as Any])
        }
        let data = try JSONSerialization.data(withJSONObject: ["schema": "otzaria.viewer-parent.mode-counter.source-controls.v1",
            "boundary": "Verbatim original currentMode/counter declarations over an explicit minimal AppMode substitute; not the app, UIKit or native acceptance.",
            "rows": rows], options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: data, as: UTF8.self))
        // The original counterexample is intentionally reported as a failure;
        // process success requires that exact failure and all candidate/other
        // controls succeed. Never relabel the baseline failure as a PASS.
        let baselineFailed = rows.first?["pass"] as? Bool == false
        let restPassed = rows.dropFirst().allSatisfy { $0["pass"] as? Bool == true }
        if !baselineFailed || !restPassed { exit(1) }
    }
}
