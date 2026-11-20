import Foundation
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

private struct FixtureFailure: Error, CustomStringConvertible {
    let reason: String
    var description: String { reason }
}
@main struct NativeSurfacePollingAcceptance {
    @MainActor static func require(_ value: @autoclosure () -> Bool, _ reason: String) throws {
        if !value() { throw FixtureFailure(reason: reason) }
    }
    @MainActor static func pause(_ milliseconds: Int = 80) async throws {
        try await Task.sleep(for: .milliseconds(milliseconds))
    }
    @MainActor static func cleaned(_ f: SurfacePollingScenario) async throws {
        f.finishOriginal()
        try require(f.session.presentation.pendingWaiterCount == 0, "No retained original continuation")
        try require(f.session.presentation.submissionID == nil && f.session.submissionID == nil,
                    "Original endObservation must release its exact request")
        let reads = f.reads
        try await pause(80)
        try require(f.reads == reads, "No timer reads after the original wait has finished")
    }
    @MainActor static func deadlineFailure(_ result: Result<NativeSurfaceState, any Error>) throws {
        switch result {
        case .success: throw FixtureFailure(reason: "Unwitnessed surface unexpectedly acknowledged")
        case .failure(let error):
            try require((error as? UIRouteError)?.code == "deadline_exceeded",
                        "Expected original deadline, observed \(error)")
        }
    }
    @MainActor static func lateGeometry(_ raw: String, callback: Bool) async throws {
        let f = try SurfacePollingScenario(raw)
        f.layoutCallback()
        try require(f.callbacks == 1 && f.session.visible.isEmpty, "Initial appeared but clipped callback must be false")
        let waiter = f.startWait()
        try await pause()
        f.makeGeometryVisible()
        if callback { f.layoutCallback() }
        let result = await waiter.result
        let reads = f.reads
        try await cleaned(f)
        switch result {
        case .success(let actual):
            try require(actual == f.expected, "Return independently observed full surface, never a route echo")
            try require(f.callbacks == (callback ? 2 : 1), "No synthetic final layout callback")
            if !callback { try require(reads >= 3, "Original request must re-read actual geometry") }
        case .failure(let error): throw FixtureFailure(reason: "Final geometry lacked a callback: \(error)")
        }
        print("OBS \(raw) callbacks=\(f.callbacks) witnessReads=\(reads) returnedExactSurface=true")
    }
    @MainActor static func refused(_ raw: String, change: (SurfacePollingScenario) -> Void) async throws {
        let f = try SurfacePollingScenario(raw, deadlineMilliseconds: 250)
        f.layoutCallback()
        change(f)
        let result = await f.startWait().result
        try await cleaned(f)
        try deadlineFailure(result)
    }
    @MainActor static func main() async {
        var cases: [(String, @MainActor () async throws -> Void)] = []
        for (name, raw) in [("library", "native.library"), ("toc", "native.reader.toc")] {
            cases.append((name + "_late_geometry_without_callback", { try await lateGeometry(raw, callback: false) }))
        }
        for (name, raw) in [("library", "native.library"), ("toc", "native.reader.toc")] {
            cases.append((name + "_late_geometry_with_callback", { try await lateGeometry(raw, callback: true) }))
        }
        cases.append(("reader_existing_poll_waits_for_geometry", { try await lateGeometry("native.reader", callback: false) }))
        cases.append(("note_draft_existing_poll_waits_for_geometry", { try await lateGeometry("native.reader.noteDraft", callback: false) }))
        cases.append(("library_exact98_percent_remains_accepted", {
            let f = try SurfacePollingScenario("native.library")
            f.marker.convertedBounds = CGRect(x: 2, y: 0, width: 100, height: 100)
            f.layoutCallback()
            let result = await f.startWait().result
            try await cleaned(f)
            switch result {
            case .success(let actual): try require(actual == f.expected, "Exact98% must retain original inclusive boundary")
            case .failure(let error): throw error
            }
        }))
        cases.append(("library_below98_percent_remains_refused", {
            try await refused("native.library") { $0.marker.convertedBounds = CGRect(x: 3, y: 0, width: 100, height: 100) }
        }))
        cases.append(("toc_not_appeared_remains_refused", {
            try await refused("native.reader.toc") { $0.makeGeometryVisible(); $0.marker.hasAppeared = false }
        }))
        cases.append(("library_inactive_scene_remains_refused", {
            try await refused("native.library") { $0.makeGeometryVisible(); $0.window.windowScene?.activationState = .background }
        }))
        cases.append(("library_hidden_ancestor_remains_refused", {
            try await refused("native.library") { $0.makeGeometryVisible(); $0.ancestor.isHidden = true }
        }))
        cases.append(("library_low_alpha_remains_refused", {
            try await refused("native.library") { $0.makeGeometryVisible(); $0.marker.alpha = 0.94 }
        }))
        cases.append(("library_modal_above_remains_refused", {
            try await refused("native.library") {
                $0.makeGeometryVisible()
                $0.window.rootViewController?.presentedViewController = .init(view: UIView())
            }
        }))
        cases.append(("library_detached_window_remains_refused", {
            try await refused("native.library") { $0.makeGeometryVisible(); $0.rootView.attachedWindow = nil }
        }))
        cases.append(("library_empty_bounds_remains_refused", {
            try await refused("native.library") { $0.makeGeometryVisible(); $0.marker.bounds = .zero }
        }))
        cases.append(("library_foreign_scene_remains_refused", {
            try await refused("native.library") {
                $0.makeGeometryVisible(); $0.window.windowScene?.session.persistentIdentifier = "other.scene"
            }
        }))
        cases.append(("toc_old_submission_remains_refused", {
            try await refused("native.reader.toc") { $0.makeGeometryVisible(); $0.marker.submissionID = UUID() }
        }))
        cases.append(("library_wrong_surface_state_remains_refused", {
            try await refused("native.library") {
                $0.makeGeometryVisible()
                $0.marker.surface = .init(destination: $0.destination, presentation: .init(), content: nil,
                    state: .init(profileID: .init(rawValue: "different.profile")!), focus: nil)
            }
        }))
        cases.append(("library_deadline_stops_observation", {
            let f = try SurfacePollingScenario("native.library", deadlineMilliseconds: 150)
            f.layoutCallback()
            let result = await f.startWait().result
            f.makeGeometryVisible()
            try await cleaned(f)
            try deadlineFailure(result)
        }))
        cases.append(("toc_cancellation_stops_observation", {
            let f = try SurfacePollingScenario("native.reader.toc")
            f.layoutCallback()
            let waiter = f.startWait()
            try await pause()
            waiter.cancel()
            let result = await waiter.result
            f.makeGeometryVisible()
            try await cleaned(f)
            switch result {
            case .success: throw FixtureFailure(reason: "Cancelled request acknowledged")
            case .failure(let error): try require(error is CancellationError, "Original cancellation must propagate")
            }
        }))
        cases.append(("library_replaced_submission_cannot_borrow_poll", {
            let f = try SurfacePollingScenario("native.library")
            f.layoutCallback()
            let waiter = f.startWait()
            try await pause()
            f.session.presentation.revoke()
            // Boundary simulates the original same-actor publication of a new
            // command. Its real observer reservation still enforces request IDs.
            let oldRoute = f.command.route.route
            let route = RouteSpec(destination: f.destination, backend: .otzaria, state: oldRoute.state)
            let registry = try UIDestinationRegistry(descriptors: [
                .init(id: f.destination, title: "Next boundary surface", implementation: .implemented,
                      supportedBackends: [.otzaria], presentations: [.currentTab]),
            ])
            let next = try UISceneCommand(route: registry.validate(route),
                invocation: .init(requestId: route.requestId, snapshot: f.command.invocation.snapshot,
                                  deadlineUptimeNanoseconds: SystemActionClock().now() + 700_000_000),
                scene: f.command.scene)
            try f.session.beginFixtureSubmission(next)
            f.marker.submissionID = next.invocation.requestId
            let oldResult = await waiter.result
            let reads = f.reads
            f.makeGeometryVisible()
            try await pause()
            try require(f.reads == reads, "Old request must not poll a replaced submission")
            try require(f.session.presentation.submissionID == next.invocation.requestId,
                        "Old cancellation cannot clear the successor reservation")
            switch oldResult {
            case .success: throw FixtureFailure(reason: "Replaced request acknowledged successor")
            case .failure(let error):
                try require((error as? UIRouteError)?.code == "scene_lifetime_changed", "Original revocation must win")
            }
            f.layoutCallback()
            let actual = try await f.session.waitUntilVisible(next)
            try require(actual == f.expected, "Only the successor's own evidence can acknowledge it")
            f.session.endObservation(requestID: next.invocation.requestId)
            try await cleaned(f)
        }))
        cases.append(("toc_unmounted_owner_stops_observation", {
            let f = try SurfacePollingScenario("native.reader.toc")
            f.layoutCallback()
            let waiter = f.startWait()
            try await pause()
            f.session.mounted = false
            f.session.presentation.revoke()
            let result = await waiter.result
            f.makeGeometryVisible()
            try await cleaned(f)
            switch result {
            case .success: throw FixtureFailure(reason: "Unmounted owner acknowledged")
            case .failure(let error):
                try require((error as? UIRouteError)?.code == "scene_lifetime_changed", "Original lifetime revocation required")
            }
        }))
        for (name, raw) in [("search", "native.search"), ("search_results", "native.search.results"),
                            ("inspector", "native.reader.inspector"), ("settings", "native.settings")] {
            cases.append((name + "_unrelated_destination_not_polled", {
                let f = try SurfacePollingScenario(raw, deadlineMilliseconds: 200)
                f.layoutCallback()
                let waiter = f.startWait()
                try await pause()
                f.makeGeometryVisible()
                let result = await waiter.result
                try await cleaned(f)
                try deadlineFailure(result)
                try require(f.reads == 1 && f.callbacks == 1, "Unrelated destinations retain callback-only behavior")
            }))
        }
        cases.append(("reader_missing_rendered_evidence_remains_refused", {
            try await refused("native.reader") { $0.makeGeometryVisible(); $0.session.readerProjection.rendered = false }
        }))
        cases.append(("note_draft_invalid_editor_owner_remains_refused", {
            try await refused("native.reader.noteDraft") { $0.makeGeometryVisible(); $0.session.noteDraftBinding?.visible = false }
        }))
        var failed = 0
        for (name, run) in cases {
            do { try await run(); print("PASS \(name)") }
            catch { failed += 1; print("FAIL \(name) :: \(error)") }
        }
        print("TOTAL \(cases.count) PASS \(cases.count - failed) FAIL \(failed) NATIVE 0")
        exit(failed == 0 ? 0 : 1)
    }
}
