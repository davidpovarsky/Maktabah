import Foundation
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

private struct FixtureFailure: Error { let reason: String }
@main struct NativeInspectorBindingAcceptance {
    @MainActor static func require(_ value: @autoclosure () -> Bool, _ reason: String) throws {
        if !value() { throw FixtureFailure(reason: reason) }
    }
    @MainActor static func rejects(_ expectedCode: String? = nil, _ operation: () throws -> Void) throws {
        do { try operation() }
        catch {
            if let expectedCode {
                let actual = (error as? UIRouteError)?.code ?? (error as? ActionNavigationError)?.code
                try require(actual == expectedCode, "Expected \(expectedCode), observed \(String(describing: error))")
            }
            return
        }
        throw FixtureFailure(reason: "Rejected boundary unexpectedly succeeded")
    }
    @MainActor static func main() async {
        var cases: [(String, @MainActor () async throws -> Void)] = []
        for backend in ActionBackendID.allCases {
            for inline in [true, false] {
                let label = "exact_\(backend.rawValue)_\(inline ? "inline" : "modal")_completion"
                cases.append((label, {
                    let f = try InspectorFixture(backend, origin: inline ? .deepLink : .appIntent)
                    let originalTab = f.manager.activeTabId, locator = f.reader.currentDestination
                    let selected = f.reader.selectedSegmentLocator, range = f.reader.readerState.selectedRange
                    let text = f.reader.contentText
                    let prepared = try await f.prepare()
                    try require(f.applied == 0 && !f.reader.readerInspectorVisible, "Binding must not open a panel")
                    try f.apply(prepared); try f.publishInspector(readerVisible: inline)
                    try f.complete(prepared)
                    try require(f.applied == 1 && f.reader.readerInspectorVisible, "Exactly one original panel effect")
                    try require(f.manager.openTabs.count == 1 && f.manager.activeTabId == originalTab
                        && f.manager.openTabs[0].viewModel === f.reader && f.reader.currentDestination == locator
                        && f.reader.selectedSegmentLocator == selected && f.reader.readerState.selectedRange == range
                        && f.reader.contentText == text, "Original Reader, private selection and source must survive")
                }))
            }
        }
        cases.append(("closed_reader_projects_observed_false", {
            let f = try InspectorFixture()
            let binding = try f.host.observePublicNavigationBinding(f.intent, requestId: f.invocation.requestId, sceneID: f.sceneID)
            try require(binding.inspectorVisible == false, "The actual closed Reader witness must project false, not nil")
            try require(f.applied == 0 && !f.reader.readerInspectorVisible, "Observation is read only")
        }))
        cases.append(("already_visible_original_inspector_completes", {
            let f = try InspectorFixture(); f.reader.readerInspectorVisible = true
            try f.session.publish(.reader, isVisible: false); try f.session.publish(.inspector, isVisible: true)
            let prepared = try await f.prepare(); try f.apply(prepared); try f.publishInspector(readerVisible: false)
            try f.complete(prepared); try require(f.applied == 1, "The original owner is used once")
        }))
        cases.append(("missing_both_native_witnesses_fails_before_effect", {
            let f = try InspectorFixture(); f.session.visible.removeAll(); f.session.visibilityChecks.removeAll()
            do { _ = try await f.prepare(); throw FixtureFailure(reason: "Unwitnessed Inspector bound") }
            catch is FixtureFailure { throw FixtureFailure(reason: "Unwitnessed Inspector bound") }
            catch { try require(f.applied == 0 && !f.reader.readerInspectorVisible, "No hidden effect") }
        }))
        cases.append(("presentation_blocker_fails_before_effect", {
            let f = try InspectorFixture(); f.session.isPresentationReady = false
            try rejects("native_presentation_in_progress") {
                _ = try f.host.observePublicNavigationBinding(f.intent, requestId: f.invocation.requestId, sceneID: f.sceneID)
            }
            try require(f.applied == 0, "No presentation under blocker")
        }))
        cases.append(("missing_navigation_scope_cannot_bind", {
            let f = try InspectorFixture(allowNavigation: false)
            do { _ = try await f.prepare(); throw FixtureFailure(reason: "Missing scope authorized") }
            catch is FixtureFailure { throw FixtureFailure(reason: "Missing scope authorized") }
            catch { try require(f.applied == 0 && !f.reader.readerInspectorVisible, "Policy denial preceded any effect") }
        }))
        cases.append(("model_visibility_without_inspector_witness_cannot_ack", {
            let f = try InspectorFixture(), prepared = try await f.prepare()
            try f.apply(prepared); try f.publishInspector(inspectorVisible: false)
            try rejects("scene_receipt_mismatch") { try f.complete(prepared) }
            try require(f.applied == 1 && f.reader.readerInspectorVisible, "Post-effect failure must not claim rollback")
        }))
        cases.append(("foreign_scene_inspector_witness_cannot_ack", {
            let f = try InspectorFixture(), prepared = try await f.prepare()
            try f.apply(prepared); try f.publishInspector(readerVisible: false, scene: .init(rawValue: "other-scene")!)
            try rejects("scene_receipt_mismatch") { try f.complete(prepared) }
        }))
        cases.append(("old_request_inspector_witness_cannot_ack", {
            let f = try InspectorFixture(), prepared = try await f.prepare()
            try f.apply(prepared); try f.publishInspector(submission: UUID())
            try rejects("scene_receipt_mismatch") { try f.complete(prepared) }
        }))
        cases.append(("private_selection_change_after_effect_stays_stale", {
            let f = try InspectorFixture(), prepared = try await f.prepare()
            try f.apply(prepared); try f.publishInspector()
            f.reader.readerState.selectedRange = .init(location: 9, length: 2)
            try rejects("native_inspector_reader_changed") { try f.complete(prepared) }
        }))
        cases.append(("reader_replacement_after_effect_stays_stale", {
            let f = try InspectorFixture(), prepared = try await f.prepare()
            try f.apply(prepared); try f.publishInspector()
            let tab = f.manager.openTabs[0]
            f.manager.openTabs = [.init(id: tab.id, book: tab.book, viewModel: ReaderViewModel())]
            try rejects("native_inspector_reader_changed") { try f.complete(prepared) }
        }))
        cases.append(("backend_generation_change_after_effect_cannot_ack", {
            let f = try InspectorFixture(), prepared = try await f.prepare()
            try f.apply(prepared); try f.publishInspector()
            f.backend.value = .init(backend: .otzaria, generation: 2)
            try rejects { try f.complete(prepared) }
        }))
        cases.append(("mapping_epoch_aba_revokes_original_admission", {
            let f = try InspectorFixture(), prepared = try await f.prepare()
            try f.apply(prepared); try f.publishInspector()
            let source = f.workspace.mappingOwnershipSource, old = source.event.epoch
            source.beginChange([.selection]); source.finishChange(available: true)
            try require(source.event.epoch != old, "Actual original mapping owner must advance")
            try rejects("native_context_unavailable") { try f.complete(prepared) }
        }))
        cases.append(("workspace_owner_replacement_cannot_borrow_old_grant", {
            let f = try InspectorFixture(), prepared = try await f.prepare()
            try f.apply(prepared); try f.publishInspector(); try f.owner.replace(with: nil)
            try rejects("native_context_unavailable") { try f.complete(prepared) }
        }))
        cases.append(("foreground_revocation_after_effect_cannot_ack", {
            let f = try InspectorFixture(), prepared = try await f.prepare()
            try f.apply(prepared); try f.publishInspector(); try f.authority.setForeground(false, lease: f.lease)
            try rejects { try f.complete(prepared) }
        }))
        cases.append(("expired_original_deadline_cannot_ack", {
            let f = try InspectorFixture(), prepared = try await f.prepare()
            try f.apply(prepared); try f.publishInspector(); f.clock.expire()
            try rejects("deadline_exceeded") { try f.complete(prepared) }
        }))
        cases.append(("cancelled_original_task_cannot_ack", {
            try await Task { @MainActor in
                let f = try InspectorFixture(), prepared = try await f.prepare()
                try f.apply(prepared); try f.publishInspector()
                withUnsafeCurrentTask { $0?.cancel() }
                do { try f.complete(prepared); throw FixtureFailure(reason: "Cancelled task acknowledged") }
                catch is CancellationError { try require(f.applied == 1, "Cancellation does not erase an effect") }
            }.value
        }))
        cases.append(("one_use_core_authorization_stays_one_use", {
            let f = try InspectorFixture(), prepared = try await f.prepare()
            let current = try f.directory.synchronousScene(sceneID: f.sceneID, context: f.context, backend: f.backend.value)
            try prepared.authorizeCommit(current: current)
            try rejects("navigation_preparation_consumed") { try prepared.authorizeCommit(current: current) }
            try require(f.applied == 0 && !f.reader.readerInspectorVisible, "A grant alone is not a UI effect")
        }))
        cases.append(("history_binding_keeps_absent_inspector_and_private_tab", {
            let f = try InspectorFixture()
            let history = PublicNavigationSpecV2(destination: .init(rawValue: "native.history")!, presentation: .currentTab)
            let binding = try f.host.observePublicNavigationBinding(history, requestId: f.invocation.requestId, sceneID: f.sceneID)
            try require(binding.inspectorVisible == nil && binding.tab == .absent, "Unrelated root contract changed")
            try require(f.applied == 0 && !f.reader.readerInspectorVisible, "Unrelated observation changed Reader")
        }))
        var passed = 0
        for (name, operation) in cases {
            do { try await operation(); passed += 1; print("PASS \(name)") }
            catch { print("FAIL \(name) :: \(error)") }
        }
        print("TOTAL \(cases.count) PASS \(passed) FAIL \(cases.count - passed)")
        exit(passed == cases.count ? 0 : 1)
    }
}
