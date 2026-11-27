import Foundation
@testable import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

// Actual original Core/UIRouting/Host modules; ONLY runtime authorities,
// native window/layout and feature effects below are explicit test boundaries.
// These controls are not an app build or UIKit/native acceptance.
final class ControlClock: ActionClock, @unchecked Sendable {
    private let lock = NSLock()
    private var value: UInt64 = 100
    func now() -> UInt64 { lock.withLock { value } }
    func expire() { lock.withLock { value = 5_000_000_100 } }
    func sleep(until deadline: UInt64) async throws { try await Task.sleep(nanoseconds: 60_000_000_000) }
}

@MainActor final class Source: ActionNavigationAuthority, ActionSynchronousBackendStatePort {
    var context = ActionExecutionContext(subjectID: "source-control", origin: .inApp,
        allowedBackends: [.otzaria], scopes: [.navigation, .discovery], foregroundSceneID: "scene.A")
    var value = ActionBackendSnapshot(backend: .otzaria, generation: 1)
    var lifetime = UUID(), revision: UInt64 = 1, active = true
    var onBackend: (@MainActor () -> Void)?
    var onNative: (@MainActor () -> Void)?
    func currentBackendSnapshot() throws -> ActionBackendSnapshot { onBackend?(); return value }
    func snapshot() async throws -> ActionBackendSnapshot { value }
    func report(for backend: ActionBackendID) async throws -> ActionBackendReport { .init(id: backend, operations: [:]) }
    func assess(action: String, arguments: ActionObject, invocation: ActionPortInvocation) async throws -> ActionCapabilityAssessment {
        .init(registered: true, supported: true, availableNow: true)
    }
    func navigationState(sceneID: String) throws -> ActionNavigationState {
        onNative?()
        return .init(context: context, sceneID: "scene.A", lifetimeID: lifetime, authorityRevision: revision, active: active)
    }
    func preparation(clock: ControlClock) throws -> (ActionNavigationPreparation, ActionPortInvocation) {
        let invocation = ActionPortInvocation(requestId: UUID(), snapshot: value, deadlineUptimeNanoseconds: 5_000_000_100)
        return (try .init(authority: self, backendAuthority: self, invocation: invocation, sceneID: "scene.A",
                          context: context, destination: nil, clock: clock), invocation)
    }
}
struct Ports: ActionResolverPort, ActionSearchPort {
    func resolveWork(_ query: ActionResolveWorkQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionWorkRef> { .notFound }
    func resolveReference(_ query: ActionResolveReferenceQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionTextRef> { .notFound }
    func validateDestination(_ destination: ActionReaderDestination, invocation: ActionPortInvocation) async throws -> ActionReaderDestination { throw ActionPortError.notSupported }
    func search(_ query: ActionSearchQuery, invocation: ActionPortInvocation) async throws -> ActionSearchPage { throw ActionPortError.notSupported }
}

@MainActor final class Driver: NativeParentSelectionSceneDriver {
    let sceneID = UIStableID(rawValue: "scene.A")!
    let backend: Source
    var command: UISceneCommand?
    var parents = 0, selections = 0, singles = 0, ends = 0, parentChecks = 0
    var witness = UUID(), activation = UUID(), parentValid = true, staged = true, wrongFinal = false
    var afterParent: (@MainActor () throws -> Void)?
    var afterParentWait: (@MainActor () throws -> Void)?
    var onParentCheck: (@MainActor (Int) -> Void)?
    var afterSelection: (@MainActor () throws -> Void)?
    var waitForParent: (@MainActor () async throws -> Void)?
    init(backend: Source) { self.backend = backend }
    var surface: NativeSurfaceState {
        if let command, selections + singles > 0 {
            let route = command.route.route
            return .init(destination: wrongFinal ? .init(rawValue: "native.history")! : route.destination,
                presentation: route.presentation, content: nil, state: route.state, focus: nil)
        }
        return .init(destination: .init(rawValue: parents > 0 ? "native.library" : "native.history")!,
            presentation: .init(kind: .currentTab), content: nil, state: .init(), focus: nil)
    }
    var observation: NativeSceneDirectory.Observation {
        .init(isForeground: true, isMounted: true,
              visibleRoute: parents + selections + singles > 0 ? command.map { surface.observedRoute(for: $0, backend: backend.value) } : nil,
              surface: surface)
    }
    func validateSurface(_ command: UISceneCommand) throws {}
    func beginObservation(_ command: UISceneCommand) throws { self.command = command }
    func apply(_ command: UISceneCommand) throws { singles += 1 }
    func waitUntilVisible(_ command: UISceneCommand) async throws -> NativeSurfaceState { surface }
    func endObservation(requestID: UUID) { ends += 1; command = nil }
    func originalParentSelectionKind(for command: UISceneCommand) throws -> UIOriginalParentSelectionKind? { staged ? .readerTab : nil }
    func applyOriginalParent(_ command: UISceneCommand) throws { parents += 1; try afterParent?() }
    func waitUntilOriginalParentReady(_ command: UISceneCommand) async throws -> NativeOriginalParentObservation {
        try await waitForParent?()
        try afterParentWait?()
        return .init(requestID: command.invocation.requestId, sceneID: sceneID,
                     activationID: activation, witnessID: witness, presentationRevision: 1)
    }
    func validateOriginalParent(_ observation: NativeOriginalParentObservation, for command: UISceneCommand) throws {
        parentChecks += 1; onParentCheck?(parentChecks)
        guard parentValid, observation.requestID == command.invocation.requestId,
              observation.sceneID == sceneID, observation.witnessID == witness,
              observation.activationID == activation else { throw UIRouteError(.staleState, "test_original_parent_changed") }
    }
    func applyOriginalSelection(_ command: UISceneCommand) throws { selections += 1; try afterSelection?() }
}

@MainActor struct Fixture {
    let source: Source, driver: Driver, clock: ControlClock
    let authority: NativeNavigationAuthority, lease: NativeNavigationAuthority.Lease
    let directory: NativeSceneDirectory, orchestrator: NativeSceneNavigationOrchestrator
    let command: UISceneCommand
    static func make(staged: Bool = true) async throws -> Fixture {
        let source = Source(), clock = ControlClock(), driver = Driver(backend: source)
        driver.staged = staged
        let authority = try NativeNavigationAuthority(), lease = try authority.mount(sceneID: driver.sceneID, foreground: true)
        let directory = try NativeSceneDirectory(authority: source, clock: clock)
        _ = try directory.mount(sceneID: driver.sceneID, observe: { driver.observation }, validateLifetime: { _ in })
        let core = try ActionExecutor(state: source, resolver: Ports(), search: Ports(), clock: clock, navigationAuthority: authority)
        let orchestrator = try NativeSceneNavigationOrchestrator(core: core, backend: source, authority: authority, directory: directory, clock: clock)
        try orchestrator.register(driver)
        let invocation = ActionPortInvocation(requestId: UUID(), snapshot: source.value, deadlineUptimeNanoseconds: 5_000_000_100)
        let scene = try await directory.currentScene(sceneID: driver.sceneID, context: source.context, invocation: invocation)
        let descriptor = UIDestinationDescriptor(id: .init(rawValue: staged ? "native.reader.tab" : "native.settings")!,
            title: "EXPLICIT SYNTHETIC native boundary", implementation: .implemented, supportedBackends: [.otzaria],
            presentations: [.currentTab], requiredCoreActions: [])
        let registry = try UIDestinationRegistry(descriptors: [descriptor])
        let route = RouteSpec(requestId: invocation.requestId, destination: descriptor.id, backend: .otzaria,
            presentation: .init(kind: .currentTab, tabID: staged ? .init(rawValue: "tab.A")! : nil),
            state: staged ? .init(workspaceID: .init(rawValue: "group.A")!, profileID: .init(rawValue: "profile.A")!) : .init(),
            scene: .init(kind: .specific, sceneID: driver.sceneID, expectedRevision: scene.revision))
        let command = try UISceneCommand(route: registry.validate(route), invocation: invocation, scene: scene)
        return .init(source: source, driver: driver, clock: clock, authority: authority, lease: lease,
                     directory: directory, orchestrator: orchestrator, command: command)
    }
    func run() async throws -> UISceneAcknowledgement { try await orchestrator.commit(command, context: source.context) }
}

@main struct Controls {
    @MainActor static var rows: [[String: Any]] = []
    @MainActor static func record(_ name: String, _ pass: Bool, _ facts: [String: Any] = [:]) {
        rows.append(["name": name, "pass": pass, "facts": facts])
    }
    @MainActor static func refuses(_ operation: () throws -> Void) -> Bool { do { try operation(); return false } catch { return true } }
    static func acknowledged(_ value: UISceneAcknowledgement) -> Bool { if case .acknowledged = value { return true }; return false }
    static func uncertain(_ value: UISceneAcknowledgement) -> Bool {
        switch value { case .failed(let f), .staleState(let f), .unavailable(let f): return f.code == "native_effect_uncertain"; default: return false }
    }
    @MainActor static func core() throws {
        do {
            let s = Source(), clock = ControlClock(), (p, i) = try s.preparation(clock: clock)
            let c = try p.authorizeParentSelection(invocation: i, sceneID: "scene.A")
            record("parent_only_cannot_complete", refuses { try p.validateCompletion() })
            record("parent_excludes_original", refuses { try p.authorizeCommit(invocation: i, sceneID: "scene.A") })
            try c.authorizeSelection(invocation: i, sceneID: "scene.A"); try p.validateCompletion()
            record("same_preparation_terminal_then_completion", true)
            record("terminal_is_one_use", refuses { try c.authorizeSelection(invocation: i, sceneID: "scene.A") })
            c.retire(); try p.validateCompletion()
            record("completed_source_check_after_capability_retirement", true)
        }
        for mode in ["old_to_parent", "old_to_old", "parent_to_old"] {
            let s = Source(), (p, i) = try s.preparation(clock: ControlClock())
            var nestedAccepted = false, fired = false
            s.onNative = {
                guard !fired else { return }; fired = true
                if mode == "old_to_parent" { nestedAccepted = (try? p.authorizeParentSelection(invocation: i, sceneID: "scene.A")) != nil }
                else { nestedAccepted = !refuses { try p.authorizeCommit(invocation: i, sceneID: "scene.A") } }
            }
            if mode == "parent_to_old" { _ = try p.authorizeParentSelection(invocation: i, sceneID: "scene.A") }
            else { try p.authorizeCommit(invocation: i, sceneID: "scene.A") }
            record(mode + "_reentry_refused", fired && !nestedAccepted, ["callback_fired": fired, "nested_accepted": nestedAccepted])
        }
        do {
            let s = Source(), (p, i) = try s.preparation(clock: ControlClock())
            s.active = false; let rejected = refuses { try p.authorizeCommit(invocation: i, sceneID: "scene.A") }
            s.active = true; try p.authorizeCommit(invocation: i, sceneID: "scene.A")
            record("original_failed_guard_retry_semantics_preserved", rejected)
        }
        do {
            let s = Source(), (p, i) = try s.preparation(clock: ControlClock())
            s.active = false; let rejected = refuses { _ = try p.authorizeParentSelection(invocation: i, sceneID: "scene.A") }
            s.active = true
            record("failed_parent_never_rearms", rejected && refuses { _ = try p.authorizeParentSelection(invocation: i, sceneID: "scene.A") })
        }
        for change in ["backend", "authority_ABA", "lifetime", "deadline", "retire"] {
            let s = Source(), clock = ControlClock(), (p, i) = try s.preparation(clock: clock)
            let c = try p.authorizeParentSelection(invocation: i, sceneID: "scene.A")
            if change == "backend" { s.value = .init(backend: .otzaria, generation: 2) }
            if change == "authority_ABA" { s.revision += 2 }
            if change == "lifetime" { s.lifetime = UUID() }
            if change == "deadline" { clock.expire() }
            if change == "retire" { c.retire() }
            record(change + "_prevents_terminal", refuses { try c.authorizeSelection(invocation: i, sceneID: "scene.A") }
                && refuses { try p.validateCompletion() })
        }
        do {
            let s = Source(), (p, i) = try s.preparation(clock: ControlClock())
            let c = try p.authorizeParentSelection(invocation: i, sceneID: "scene.A")
            var fired = false
            s.onNative = { if !fired { fired = true; c.retire() } }
            record("retirement_inside_terminal_guard_prevents_effect", refuses { try c.authorizeSelection(invocation: i, sceneID: "scene.A") } && fired)
        }
        do {
            let s = Source(), (p, i) = try s.preparation(clock: ControlClock())
            let c = try p.authorizeParentSelection(invocation: i, sceneID: "scene.A")
            var fired = false, nestedAccepted = false
            s.onNative = { if !fired { fired = true; nestedAccepted = !refuses { try c.authorizeSelection(invocation: i, sceneID: "scene.A") } } }
            try c.authorizeSelection(invocation: i, sceneID: "scene.A")
            record("terminal_reentry_refused", fired && !nestedAccepted)
        }
        do {
            let s = Source(), (p, i) = try s.preparation(clock: ControlClock())
            let c = try p.authorizeParentSelection(invocation: i, sceneID: "scene.A")
            let foreign = ActionPortInvocation(requestId: UUID(), snapshot: i.snapshot, deadlineUptimeNanoseconds: i.deadlineUptimeNanoseconds)
            record("terminal_exact_invocation_and_scene", refuses { try c.authorizeSelection(invocation: foreign, sceneID: "scene.A") }
                && refuses { try c.authorizeSelection(invocation: i, sceneID: "scene.B") })
        }
    }
    @MainActor static func host() async throws {
        do {
            let f = try await Fixture.make(); let result = try await f.run()
            record("actual_host_parent_and_selection_once", acknowledged(result) && f.driver.parents == 1 && f.driver.selections == 1 && f.driver.singles == 0 && f.driver.ends == 1,
                   ["result": String(describing: result), "parents": f.driver.parents, "selections": f.driver.selections])
            let replay = try await f.run()
            record("completed_request_replay_refused", !acknowledged(replay) && f.driver.parents == 1 && f.driver.selections == 1)
        }
        do {
            let f = try await Fixture.make(staged: false); let result = try await f.run()
            record("original_single_apply_path_preserved", acknowledged(result) && f.driver.singles == 1 && f.driver.parents == 0 && f.driver.selections == 0)
        }
        do {
            let f = try await Fixture.make()
            var fired = false
            // After the second exact parent check, the next source read is
            // INSIDE the terminal Core guard. Scene/admission stay unchanged.
            f.driver.onParentCheck = { count in
                if count == 2 { f.source.onBackend = { if !fired { fired = true; f.driver.parentValid = false; f.source.onBackend = nil } } }
            }
            let result = try await f.run()
            record("parent_replaced_inside_terminal_core_guard", fired && uncertain(result) && f.driver.parents == 1 && f.driver.selections == 0,
                   ["callback_fired": fired, "parents": f.driver.parents, "selections": f.driver.selections, "result": String(describing: result)])
        }
        for change in ["parent_detached", "witness_replaced", "backend", "authority_ABA", "driver_detached", "deadline"] {
            let f = try await Fixture.make()
            f.driver.afterParentWait = {
                switch change {
                case "parent_detached": f.driver.parentValid = false
                case "witness_replaced": f.driver.onParentCheck = { _ in f.driver.witness = UUID() }
                case "backend": f.source.value = .init(backend: .otzaria, generation: 2)
                case "authority_ABA": try f.authority.invalidate(f.lease)
                case "driver_detached": f.orchestrator.unregister(f.driver)
                default: f.clock.expire()
                }
            }
            let result = try await f.run()
            record("host_" + change + "_cannot_select", uncertain(result) && f.driver.parents == 1 && f.driver.selections == 0 && f.driver.ends == 1,
                   ["result": String(describing: result)])
        }
        do {
            let f = try await Fixture.make(); f.driver.wrongFinal = true
            let result = try await f.run()
            record("selection_requires_exact_final_surface", uncertain(result) && f.driver.selections == 1)
        }
        do {
            let f = try await Fixture.make(); f.driver.afterSelection = { try f.authority.invalidate(f.lease) }
            let result = try await f.run()
            record("post_effect_revocation_is_not_completion_or_rollback", uncertain(result) && f.driver.selections == 1)
        }
        do {
            let f = try await Fixture.make()
            let (events, signal) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
            f.driver.waitForParent = { signal.yield(()); try await Task.sleep(nanoseconds: 60_000_000_000) }
            let task = Task { defer { signal.finish() }; return try await f.run() }
            var iterator = events.makeAsyncIterator(); _ = await iterator.next(); task.cancel()
            let result = try await task.value; signal.finish()
            record("cancelled_parent_wait_drained_without_selection", uncertain(result) && f.driver.parents == 1 && f.driver.selections == 0 && f.driver.ends == 1)
        }
    }
    @MainActor static func main() async {
        do { try core(); try await host() }
        catch { record("unexpected_harness_error", false, ["error": String(describing: error)]) }
        let failures = rows.filter { !($0["pass"] as! Bool) }.map { $0["name"] as! String }
        let expected = CommandLine.arguments.contains("--candidate1")
            ? Set(["old_to_parent_reentry_refused", "old_to_old_reentry_refused", "parent_replaced_inside_terminal_core_guard"]) : Set<String>()
        let validExperiment = Set(failures) == expected
        let output: [String: Any] = ["schema": "otzaria.viewer-parent.actual-module-controls.v1", "rows": rows,
            "pass_count": rows.count - failures.count, "fail_count": failures.count,
            "expected_historical_failures": Array(expected).sorted(), "experiment_matched": validExperiment,
            "boundary": "Actual original Core/UIRouting/Host; synthetic backend/native/layout boundaries; UIKit/App/native NOT_RUN"]
        print(String(data: try! JSONSerialization.data(withJSONObject: output, options: [.sortedKeys]), encoding: .utf8)!)
        if !validExperiment { exit(1) }
    }
}
