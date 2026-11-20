import Foundation
import OtzariaActionCore

// Explicit portable boundaries for UIKit/scene/workspace owners. The generator
// inserts the complete original composition members without rewriting them.
// Core contracts are linked from the separately verified original package.
// These controls do not simulate a visible native view or a successful app ACK.
struct UIStableID: Hashable { let rawValue: String }
struct BoundaryRoute: Equatable, ExpressibleByStringLiteral {
    var destination: UIStableID
    init(stringLiteral value: String) { destination = .init(rawValue: value) }
}
struct UIUTF16Range: Equatable { let location: Int; let length: Int }
// The app backend enum is a boundary; the three mapping value declarations and
// their synthesized equality are copied verbatim from the original app source.
typealias BackendID = ActionBackendID
/* ORIGINAL_MAPPING_TYPES */
enum MaktabahNativeSceneProjection {
    struct HanlinCurrentWorkReadSource: Equatable { let revision: UInt64 }
}
struct UISceneReceipt {
    var sceneID: UIStableID
    var backendSnapshot: ActionBackendSnapshot
    var coreReceipt: ActionUIReceipt?
    var appliedSceneRevision: UInt64
    var route: BoundaryRoute
}
struct BoundarySceneSnapshot {
    var revision: UInt64 = 9
    var visibleRoute: BoundaryRoute? = "native.reader"
    var backendSnapshot: ActionBackendSnapshot
}
@MainActor final class BoundaryBackend: ActionBackendStatePort, ActionResolverPort, ActionSearchPort {
    var current = ActionBackendSnapshot(backend: .otzaria, generation: 7)
    var failure: ActionPortError?
    var readCalls = 0
    func currentBackendSnapshot() throws -> ActionBackendSnapshot {
        if let failure { throw failure }; return current
    }
    func snapshot() async throws -> ActionBackendSnapshot { try currentBackendSnapshot() }
    func report(for backend: ActionBackendID) async throws -> ActionBackendReport {
        .init(id: backend, operations: [:])
    }
    func assess(action: String, arguments: ActionObject, invocation: ActionPortInvocation) async throws -> ActionCapabilityAssessment {
        .init(registered: true, supported: true, availableNow: true)
    }
    func resolveWork(_ query: ActionResolveWorkQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionWorkRef> {
        throw ActionPortError.notSupported
    }
    func resolveReference(_ query: ActionResolveReferenceQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionTextRef> {
        throw ActionPortError.notSupported
    }
    func validateDestination(_ destination: ActionReaderDestination, invocation: ActionPortInvocation) async throws -> ActionReaderDestination {
        throw ActionPortError.notSupported
    }
    func search(_ query: ActionSearchQuery, invocation: ActionPortInvocation) async throws -> ActionSearchPage {
        readCalls += 1
        throw ActionPortError.notSupported
    }
}
@MainActor final class BoundaryDirectory {
    var revision: UInt64 = 9
    var visibleRoute: BoundaryRoute? = "native.reader"
    var failure: ActionPortError?
    var scene: UIStableID?
    var context: ActionExecutionContext?
    var calls = 0
    func synchronousScene(sceneID: UIStableID, context: ActionExecutionContext,
                          backend: ActionBackendSnapshot) throws -> BoundarySceneSnapshot {
        calls += 1; scene = sceneID; self.context = context
        if let failure { throw failure }
        return .init(revision: revision, visibleRoute: visibleRoute, backendSnapshot: backend)
    }
}
final class BoundaryIdentity { var event = BoundarySourceEvent() }
// These are explicit portable UIKit ownership boundaries. They do not model
// rendering, native visibility, AppIntents system delivery, or save semantics.
struct UIRouteError: Error {
    let status: ActionStatus
    let code: String
    init(_ status: ActionStatus, _ code: String) { self.status = status; self.code = code }
}
enum NativeObservationDeadline {
    @MainActor static func run<T>(until: UInt64, clock: any ActionClock,
        operation: @MainActor () async throws -> T) async throws -> T { try await operation() }
}
typealias iOSNavigationManager = BoundaryIdentity
enum BoundarySourcePhase { case available, unavailable }
struct BoundarySourceEvent {
    var phase: BoundarySourcePhase = .available
    var epoch = StudyWorkspaceMappingEpoch(sourceID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, revision: 2)
}
enum BoundaryCoverage { case liveNativeSetters, incomplete }
struct BoundaryMapping {
    var coverage: BoundaryCoverage = .liveNativeSetters
    var scene: String
    var owner: ObjectIdentifier
    var source: BoundaryIdentity
    var epoch: StudyWorkspaceMappingEpoch
    var projection: StudyWorkspaceMappingProjection
}
@MainActor final class BoundaryWorkspace {
    var mapping: BoundaryMapping?
    init(_ mapping: BoundaryMapping) { self.mapping = mapping }
    func mappingOwnershipObservation() -> BoundaryMapping? { mapping }
}
@MainActor final class BoundaryProjectionSource {
    var isAuthoritative = true
    var workspace: BoundaryWorkspace?
    var failure: ActionPortError?
    init(_ workspace: BoundaryWorkspace) { self.workspace = workspace }
    func read() throws -> BoundaryWorkspace? {
        if let failure { throw failure }
        return workspace
    }
}
@MainActor final class BoundaryBinding {
    var workspace: BoundaryWorkspace
    var owns = true
    init(_ workspace: BoundaryWorkspace) { self.workspace = workspace }
    func ownsSource(_ current: BoundaryWorkspace) -> Bool { owns && current === workspace }
}
@MainActor final class BoundarySession {
    var mounted = true
    var foreground = true
    var workspaceProjectionSource: BoundaryProjectionSource?
}

enum ControlFailure: Error { case failed(String) }
@MainActor final class ControlRecorder {
    var outcomes: [(String, Bool)] = []
    func run(_ name: String, _ body: () throws -> Void) {
        do { try body(); outcomes.append((name, true)); print("PASS " + name) }
        catch { outcomes.append((name, false)); print("FAIL " + name + " " + String(describing: error)) }
    }
    func runAsync(_ name: String, _ body: () async throws -> Void) async {
        do { try await body(); outcomes.append((name, true)); print("PASS " + name) }
        catch { outcomes.append((name, false)); print("FAIL " + name + " " + String(describing: error)) }
    }
    func require(_ value: Bool, _ explanation: String = "assertion") throws {
        if !value { throw ControlFailure.failed(explanation) }
    }
    func refused(_ body: () throws -> Void) throws {
        do { try body() } catch is ActionPortError { return }
        throw ControlFailure.failed("original guard did not refuse")
    }
}

@MainActor final class MaktabahNativeRoutingComposition {
    struct Registration {
        let managerID: ObjectIdentifier
        var manager: iOSNavigationManager?
        var session: BoundarySession
        var publicBinding: BoundaryBinding?
        init(managerID: ObjectIdentifier, manager: iOSNavigationManager? = nil,
             session: BoundarySession = BoundarySession(), publicBinding: BoundaryBinding? = nil) {
            self.managerID = managerID; self.manager = manager; self.session = session; self.publicBinding = publicBinding
        }
    }
    typealias SceneEntry = Registration
    var scenes: [UIStableID: SceneEntry] = [:]
    var contexts: [UIStableID: ActionExecutionContext] = [:]
    let backend = BoundaryBackend()
    let directory = BoundaryDirectory()
    private var sourceObservation: HanlinSourceObservation!
    var sourceUnavailable = false
    fileprivate func hanlinSource(sceneID: UIStableID, entry: SceneEntry) throws -> HanlinSourceObservation {
        guard !sourceUnavailable else { throw ActionPortError.unavailable }
        // The original hanlinSource reads the backend synchronously on every
        // observation. Preserve that boundary behavior instead of echoing a
        // stale canned snapshot after a backend mutation.
        let value = sourceObservation!
        return .init(backend: try backend.currentBackendSnapshot(), source: value.source,
            epoch: value.epoch, projection: value.projection, readerContent: value.readerContent,
            currentWorkReadSource: value.currentWorkReadSource, selectedRange: value.selectedRange,
            locale: value.locale)
    }


    private lazy var core = try! ActionExecutor(state: backend, resolver: backend, search: backend)
    private var dispatched: [(ActionRequest, ActionExecutionContext)] = []
    private var nativeFailure: UIRouteError?
    private var failNote = false
    private var invalidateAfterReader = false
    private func deadline() -> UInt64 { UInt64.max }
    private func waitForMount(managerID: ObjectIdentifier) async throws -> UIStableID {
        guard let found = scenes.first(where: { $0.value.managerID == managerID }) else { throw ActionPortError.unavailable }
        return found.key
    }
    private func context(sceneID: UIStableID, origin: ActionOrigin, snapshot: ActionBackendSnapshot) -> ActionExecutionContext {
        .init(subjectID: "boundary-navigation", origin: origin, allowedBackends: [snapshot.backend],
              scopes: [.discovery, .navigation], foregroundSceneID: sceneID.rawValue)
    }
    // Dispatch doubles are deliberately explicit: the original factory and
    // journey own admission/continuation; these do not prove a UIKit ACK.
    private func openSearchResults(query: ActionSearchResultsQuery, manager: iOSNavigationManager,
                                   continuing: SemanticJourneyInvocation?) async throws -> ActionResult {
        guard let continuing else { throw ActionPortError.invalidResponse }
        dispatched.append((continuing.request, continuing.owner.context))
        throw ActionPortError.notSupported
    }
    private func openCommentary(baseLocator: ActionTextRef, workRef: ActionWorkRef?,
        commentaryQuery: String?, manager: iOSNavigationManager, continuing: SemanticJourneyInvocation?) async throws -> ActionResult {
        guard let continuing, manager === self.manager else { throw ActionPortError.invalidResponse }
        let owner = continuing.owner, request = continuing.request
        dispatched.append((request, owner.context))
        if let nativeFailure { throw nativeFailure }
        let observed = receipt(for: owner)
        try advanceSemanticJourney(owner, receipt: observed)
        contexts.removeValue(forKey: scene)
        owner.didAcknowledge?(observed)
        let destination = observed.coreReceipt!.destination
        let result = ActionResult(request: request, status: .completed,
            data: ["destination": try .encoded(destination), "locator": try .encoded(destination.focusLocator ?? destination.sectionLocator)],
            backend: backend.current.backend, backendGeneration: backend.current.generation)
        if invalidateAfterReader { sourceObservation = observation(epoch: 3) }
        return result
    }
    private func prepareNoteDraft(locator: ActionTextRef, selectedText: String?, proposedText: String?,
        manager: iOSNavigationManager, continuing: SemanticJourneyInvocation?) async throws -> ActionResult {
        guard let continuing, selectedText == nil, manager === self.manager else { throw ActionPortError.invalidResponse }
        let request = continuing.request
        dispatched.append((request, continuing.owner.context))
        if failNote { throw UIRouteError(.unavailable, "original_note_editor_not_visible") }
        return .init(request: request, status: .completed,
            data: ["locator": try .encoded(locator), "saved": .bool(false)],
            backend: backend.current.backend, backendGeneration: backend.current.generation)
    }
    private func postAwaitSetup() -> (owner: SemanticJourneyOwner, initial: HanlinSourceObservation, entry: Registration) {
        let initial = observation(locale: Locale.current.identifier)
        let target = StudyWorkspaceMappingTarget(backend: .otzaria, bookID: 2, workKey: "book:2", readerOwner: ObjectIdentifier(readerB))
        var targets = initial.projection.targets
        targets[otherID] = target
        let finalProjection = StudyWorkspaceMappingProjection(profileID: profileID, groupID: groupID,
            profileIDs: [profileID], groupIDs: [groupID], activeTabID: otherID, targets: targets)
        let observed = observation(epoch: 2, actualProjection: finalProjection,
            reader: .init(sectionLocator: section, focusLocator: focus, presentationMode: .newTab),
            locale: Locale.current.identifier)
        sourceObservation = observed
        sourceA.event = .init(phase: .available, epoch: observed.epoch)
        let mapping = BoundaryMapping(scene: scene.rawValue, owner: ObjectIdentifier(manager), source: sourceA,
            epoch: observed.epoch, projection: observed.projection)
        let workspace = BoundaryWorkspace(mapping)
        let session = BoundarySession()
        session.workspaceProjectionSource = BoundaryProjectionSource(workspace)
        let entry = Registration(managerID: ObjectIdentifier(manager), manager: manager,
            session: session, publicBinding: BoundaryBinding(workspace))
        scenes[scene] = entry
        let authority = context(sceneID: scene, origin: .appIntent, snapshot: backend.current)
        return (.init(sceneID: scene, managerID: ObjectIdentifier(manager), context: authority, observation: observed), initial, entry)
    }
    private func postMapping() -> BoundaryMapping {
        scenes[scene]!.session.workspaceProjectionSource!.workspace!.mapping!
    }
    private func updatePostMapping(_ update: (inout BoundaryMapping) -> Void) {
        let workspace = scenes[scene]!.session.workspaceProjectionSource!.workspace!
        var value = workspace.mapping!
        update(&value)
        workspace.mapping = value
    }
    private func adoptProjection(_ owner: SemanticJourneyOwner, _ projection: StudyWorkspaceMappingProjection) {
        updatePostMapping { $0.projection = projection }
        owner.observation = observation(epoch: owner.observation.epoch.revision,
            actualProjection: projection, locale: owner.observation.locale)
    }

    /* ORIGINAL_COMPOSITION_MEMBERS */

    private let manager = BoundaryIdentity()
    private let otherManager = BoundaryIdentity()
    private let sourceA = BoundaryIdentity()
    private let sourceB = BoundaryIdentity()
    private let readerA = BoundaryIdentity()
    private let readerB = BoundaryIdentity()
    private let epochSourceID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let profileID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private let groupID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    private let tabID = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
    private let otherID = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
    private let scene = UIStableID(rawValue: "boundary-scene")
    private let base = ActionTextRef(backend: .otzaria, workKey: "book:1", position: .legacyLine(1))
    private let section = ActionTextRef(backend: .otzaria, workKey: "book:2", position: .legacyLine(20))
    private let focus = ActionTextRef(backend: .otzaria, workKey: "book:2", position: .legacyLine(21))
    private var nativeContext: ActionExecutionContext {
        .init(subjectID: "boundary-navigation", origin: .inApp,
              allowedBackends: [.otzaria], scopes: [.discovery, .navigation], foregroundSceneID: scene.rawValue)
    }
    private func mappingProjection(version: UInt64 = 1, profile: UUID? = nil, group: UUID? = nil,
                                   profiles: Set<UUID>? = nil, groups: Set<UUID>? = nil,
                                   active: UUID? = nil, clearActive: Bool = false,
                                   target: StudyWorkspaceMappingTarget? = nil,
                                   additionalTarget: Bool = false) -> StudyWorkspaceMappingProjection {
        let actualTarget = target ?? .init(backend: .otzaria, bookID: Int(version),
            workKey: "book:\(version)", readerOwner: ObjectIdentifier(readerA))
        var targets = [tabID: actualTarget]
        if additionalTarget { targets[otherID] = actualTarget }
        return .init(profileID: profile ?? profileID, groupID: group ?? groupID,
            profileIDs: profiles ?? [profileID], groupIDs: groups ?? [groupID],
            activeTabID: clearActive ? nil : (active ?? tabID), targets: targets)
    }
    private func observation(epoch: UInt64 = 1, epochSource: UUID? = nil, projection: UInt64 = 1,
                             actualProjection: StudyWorkspaceMappingProjection? = nil, source: ObjectIdentifier? = nil,
                             reader: ActionReaderDestination? = nil, range: UIUTF16Range? = nil,
                             locale: String = "he", readRevision: UInt64 = 1,
                             hideReader: Bool = false, hideWorkSource: Bool = false) -> HanlinSourceObservation {
        .init(backend: backend.current, source: source ?? ObjectIdentifier(sourceA),
              epoch: .init(sourceID: epochSource ?? epochSourceID, revision: epoch),
              projection: actualProjection ?? mappingProjection(version: projection),
              readerContent: hideReader ? nil : (reader ?? .init(sectionLocator: base)),
              currentWorkReadSource: hideWorkSource ? nil : .init(revision: readRevision),
              selectedRange: range, locale: locale)
    }
    private func setup() -> SemanticJourneyOwner {
        let observed = observation()
        sourceObservation = observed
        scenes[scene] = .init(managerID: ObjectIdentifier(manager))
        return .init(sceneID: scene, managerID: ObjectIdentifier(manager), context: nativeContext, observation: observed)
    }
    private func request(text: String = "e\u{0301}", generation: UInt64 = 7,
                         action: String = "search.openResults", backend: ActionBackendID = .otzaria,
                         presentation: ActionPresentation = .foreground) -> ActionRequest {
        .init(action: action, arguments: ["text": .string(text), "scope": .string("book:1")],
              expectedBackend: backend, expectedGeneration: generation, requestedPresentation: presentation)
    }
    private func receipt(for owner: SemanticJourneyOwner) -> UISceneReceipt {
        let destination = ActionReaderDestination(sectionLocator: section, focusLocator: focus, presentationMode: .newTab)
        contexts[scene] = owner.context
        sourceObservation = observation(epoch: 2, projection: 2, reader: destination,
                                        range: .init(location: 5, length: 6))
        return .init(sceneID: scene, backendSnapshot: backend.current,
                     coreReceipt: .init(requestId: UUID(), snapshot: backend.current, sceneID: scene.rawValue, destination: destination),
                     appliedSceneRevision: 9, route: "native.reader")
    }
    private func searchReceipt(for owner: SemanticJourneyOwner) -> UISceneReceipt {
        contexts[scene] = owner.context
        // The original currentMode/global tab switch is absent from the mapping
        // projection. Search hides Viewer metadata; it cannot change its owner.
        sourceObservation = observation(hideReader: true, hideWorkSource: true)
        directory.visibleRoute = "native.search.results"
        return .init(sceneID: scene, backendSnapshot: backend.current, coreReceipt: nil,
                     appliedSceneRevision: 9, route: "native.search.results")
    }

    static func runControls() async -> Bool {
        let controls = ControlRecorder()
        controls.run("independent_call_preserves_original_request_and_context") {
            let f = Self(), owner = f.setup(), request = f.request(), context = f.nativeContext
            let result = try f.semanticJourneyInvocation(nil, fallback: request, context: context,
                                                        sceneID: f.scene, observed: owner.observation)
            try controls.require(result.0 == request && result.1 == context)
        }
        controls.run("continuation_preserves_original_request_id_and_owner_context") {
            let f = Self(), owner = f.setup(), original = f.request(), fallback = f.request()
            let result = try f.semanticJourneyInvocation(.init(owner: owner, request: original), fallback: fallback,
                context: f.nativeContext, sceneID: f.scene, observed: owner.observation)
            try controls.require(result.0.requestId == original.requestId && result.0.requestId != fallback.requestId)
            try controls.require(result.1 == owner.context)
        }
        for (name, mutate) in [
            ("source_epoch_aba", { (f: MaktabahNativeRoutingComposition) in f.sourceObservation = f.observation(epoch: 3) }),
            ("workspace_projection_change", { (f: MaktabahNativeRoutingComposition) in f.sourceObservation = f.observation(projection: 2) }),
            ("source_instance_change", { (f: MaktabahNativeRoutingComposition) in f.sourceObservation = f.observation(source: ObjectIdentifier(f.sourceB)) }),
            ("selection_change", { (f: MaktabahNativeRoutingComposition) in f.sourceObservation = f.observation(range: .init(location: 1, length: 2)) }),
            ("locale_change", { (f: MaktabahNativeRoutingComposition) in f.sourceObservation = f.observation(locale: "en") }),
            ("work_read_source_change", { (f: MaktabahNativeRoutingComposition) in f.sourceObservation = f.observation(readRevision: 2) }),
            ("scene_detached", { (f: MaktabahNativeRoutingComposition) in f.scenes.removeValue(forKey: f.scene) }),
            ("manager_replaced", { (f: MaktabahNativeRoutingComposition) in f.scenes[f.scene] = .init(managerID: ObjectIdentifier(f.otherManager)) }),
            ("other_invocation_busy", { (f: MaktabahNativeRoutingComposition) in f.contexts[f.scene] = f.nativeContext }),
            ("source_unavailable", { (f: MaktabahNativeRoutingComposition) in f.sourceUnavailable = true })
        ] {
            controls.run(name) {
                let f = Self(), owner = f.setup(); mutate(f)
                try controls.refused { try f.validateSemanticJourney(owner) }
            }
        }
        for (name, fallback) in [
            ("unicode_canonical_equivalence_is_not_byte_identity", { (f: MaktabahNativeRoutingComposition) in f.request(text: "\u{00e9}") }),
            ("generation_change", { (f: MaktabahNativeRoutingComposition) in f.request(generation: 8) }),
            ("action_change", { (f: MaktabahNativeRoutingComposition) in f.request(action: "notes.prepareDraft") }),
            ("backend_change", { (f: MaktabahNativeRoutingComposition) in f.request(backend: .sefaria) }),
            ("presentation_change", { (f: MaktabahNativeRoutingComposition) in f.request(presentation: .headless) })
        ] {
            controls.run(name) {
                let f = Self(), owner = f.setup(), original = f.request()
                try controls.refused {
                    _ = try f.semanticJourneyInvocation(.init(owner: owner, request: original), fallback: fallback(f),
                        context: f.nativeContext, sceneID: f.scene, observed: owner.observation)
                }
            }
        }
        controls.run("other_scene_cannot_reuse_continuation") {
            let f = Self(), owner = f.setup(), request = f.request()
            try controls.refused {
                _ = try f.semanticJourneyInvocation(.init(owner: owner, request: request), fallback: request,
                    context: f.nativeContext, sceneID: .init(rawValue: "other-scene"), observed: owner.observation)
            }
        }
        controls.run("changed_scope_cannot_reuse_continuation") {
            let f = Self(), owner = f.setup(), request = f.request()
            var arguments = request.arguments; arguments["scope"] = .string("book:2")
            let other = ActionRequest(action: request.action, arguments: arguments, expectedBackend: .otzaria,
                                      expectedGeneration: 7, requestedPresentation: .foreground)
            try controls.refused {
                _ = try f.semanticJourneyInvocation(.init(owner: owner, request: request), fallback: other,
                    context: f.nativeContext, sceneID: f.scene, observed: owner.observation)
            }
        }
        controls.run("acknowledged_reader_advances_only_after_exact_directory_observation") {
            let f = Self(), owner = f.setup(), receipt = f.receipt(for: owner)
            try f.advanceSemanticJourney(owner, receipt: receipt)
            try controls.require(owner.observation == f.sourceObservation)
            try controls.require(f.directory.calls == 1 && f.directory.scene == f.scene && f.directory.context == owner.context)
            try controls.refused { try f.validateSemanticJourney(owner) } // Original pending operation still owns the scene.
            f.contexts.removeValue(forKey: f.scene)
            try f.validateSemanticJourney(owner)
        }
        for (name, mutate) in [
            ("receipt_wrong_scene", { (f: MaktabahNativeRoutingComposition, r: inout UISceneReceipt) in r.sceneID = .init(rawValue: "other-scene") }),
            ("receipt_wrong_backend", { (f: MaktabahNativeRoutingComposition, r: inout UISceneReceipt) in r.backendSnapshot = .init(backend: .otzaria, generation: 8) }),
            ("receipt_without_core_ack", { (f: MaktabahNativeRoutingComposition, r: inout UISceneReceipt) in r.coreReceipt = nil }),
            ("directory_revision_changed", { (f: MaktabahNativeRoutingComposition, r: inout UISceneReceipt) in f.directory.revision += 1 }),
            ("directory_reader_hidden", { (f: MaktabahNativeRoutingComposition, r: inout UISceneReceipt) in f.directory.visibleRoute = nil }),
            ("directory_other_route", { (f: MaktabahNativeRoutingComposition, r: inout UISceneReceipt) in f.directory.visibleRoute = "native.search" }),
            ("directory_refuses_current_owner", { (f: MaktabahNativeRoutingComposition, r: inout UISceneReceipt) in f.directory.failure = .staleState }),
            ("backend_changes_at_final_boundary", { (f: MaktabahNativeRoutingComposition, r: inout UISceneReceipt) in f.backend.current = .init(backend: .otzaria, generation: 8) }),
            ("model_focus_does_not_match_receipt", { (f: MaktabahNativeRoutingComposition, r: inout UISceneReceipt) in f.sourceObservation = f.observation(reader: .init(sectionLocator: f.section)) }),
            ("same_tab_cannot_advance_journey", { (f: MaktabahNativeRoutingComposition, r: inout UISceneReceipt) in
                r.coreReceipt = .init(requestId: UUID(), snapshot: f.backend.current, sceneID: f.scene.rawValue,
                    destination: .init(sectionLocator: f.section, focusLocator: f.focus, presentationMode: .sameTab))
            })
        ] {
            controls.run(name) {
                let f = Self(), owner = f.setup(); let original = owner.observation
                var receipt = f.receipt(for: owner); mutate(f, &receipt)
                try controls.refused { try f.advanceSemanticJourney(owner, receipt: receipt) }
                try controls.require(owner.observation == original, "rejected receipt changed the retained source")
            }
        }
        controls.run("source_change_after_reader_ack_blocks_next_step") {
            let f = Self(), owner = f.setup(), receipt = f.receipt(for: owner)
            try f.advanceSemanticJourney(owner, receipt: receipt)
            f.contexts.removeValue(forKey: f.scene)
            f.sourceObservation = f.observation(epoch: 3, projection: 3, reader: receipt.coreReceipt!.destination)
            try controls.refused { try f.validateSemanticJourney(owner) }
        }
        controls.run("exact_search_receipt_advances_source_without_creating_read_rights") {
            let f = Self(), owner = f.setup(), receipt = f.searchReceipt(for: owner)
            let context = owner.context
            try f.advanceSemanticSearchJourney(owner, receipt: receipt)
            f.contexts.removeValue(forKey: f.scene)
            try f.validateSemanticJourney(owner)
            try controls.require(owner.context == context && !owner.context.scopes.contains(.contentRead))
            try controls.require(owner.context.contentRights.isEmpty)
        }
        for (name, mutate) in [
            ("search_receipt_wrong_scene", { (f: MaktabahNativeRoutingComposition, r: inout UISceneReceipt) in r.sceneID = .init(rawValue: "other-scene") }),
            ("search_receipt_wrong_destination", { (f: MaktabahNativeRoutingComposition, r: inout UISceneReceipt) in r.route = "native.library"; f.directory.visibleRoute = "native.library" }),
            ("search_receipt_cannot_borrow_reader_ack", { (f: MaktabahNativeRoutingComposition, r: inout UISceneReceipt) in
                r.coreReceipt = .init(requestId: UUID(), snapshot: f.backend.current, sceneID: f.scene.rawValue, destination: .init(sectionLocator: f.base))
            }),
            ("search_model_only_without_visible_route", { (f: MaktabahNativeRoutingComposition, r: inout UISceneReceipt) in f.directory.visibleRoute = nil }),
            ("search_source_instance_replacement", { (f: MaktabahNativeRoutingComposition, r: inout UISceneReceipt) in f.sourceObservation = f.observation(epoch: 2, projection: 2, source: ObjectIdentifier(f.sourceB)) }),
            ("search_backend_changed_after_ack", { (f: MaktabahNativeRoutingComposition, r: inout UISceneReceipt) in f.backend.current = .init(backend: .otzaria, generation: 8) }),
            ("search_directory_revision_changed_after_ack", { (f: MaktabahNativeRoutingComposition, r: inout UISceneReceipt) in f.directory.revision += 1 })
        ] {
            controls.run(name) {
                let f = Self(), owner = f.setup(); let original = owner.observation
                var receipt = f.searchReceipt(for: owner); mutate(f, &receipt)
                try controls.refused { try f.advanceSemanticSearchJourney(owner, receipt: receipt) }
                try controls.require(owner.observation == original)
            }
        }
        for (name, mutate) in [
            ("search_source_epoch_revision_aba_refused", { (f: MaktabahNativeRoutingComposition) in f.observation(epoch: 3) }),
            ("search_source_epoch_source_id_refused", { (f: MaktabahNativeRoutingComposition) in f.observation(epochSource: f.otherID) }),
            ("search_profile_identity_change_refused", { (f: MaktabahNativeRoutingComposition) in f.observation(actualProjection: f.mappingProjection(profile: f.otherID)) }),
            ("search_group_identity_change_refused", { (f: MaktabahNativeRoutingComposition) in f.observation(actualProjection: f.mappingProjection(group: f.otherID)) }),
            ("search_profile_membership_change_refused", { (f: MaktabahNativeRoutingComposition) in f.observation(actualProjection: f.mappingProjection(profiles: [f.profileID, f.otherID])) }),
            ("search_group_membership_change_refused", { (f: MaktabahNativeRoutingComposition) in f.observation(actualProjection: f.mappingProjection(groups: [f.groupID, f.otherID])) }),
            ("search_active_tab_change_refused", { (f: MaktabahNativeRoutingComposition) in f.observation(actualProjection: f.mappingProjection(active: f.otherID, additionalTarget: true)) }),
            ("search_active_tab_disappearance_refused", { (f: MaktabahNativeRoutingComposition) in f.observation(actualProjection: f.mappingProjection(clearActive: true)) }),
            ("search_tab_membership_change_refused", { (f: MaktabahNativeRoutingComposition) in f.observation(actualProjection: f.mappingProjection(additionalTarget: true)) }),
            ("search_target_book_identity_change_refused", { (f: MaktabahNativeRoutingComposition) in f.observation(actualProjection: f.mappingProjection(target: .init(backend: .otzaria, bookID: 2, workKey: "book:1", readerOwner: ObjectIdentifier(f.readerA)))) }),
            ("search_target_work_identity_change_refused", { (f: MaktabahNativeRoutingComposition) in f.observation(actualProjection: f.mappingProjection(target: .init(backend: .otzaria, bookID: 1, workKey: "book:2", readerOwner: ObjectIdentifier(f.readerA)))) }),
            ("search_target_backend_change_refused", { (f: MaktabahNativeRoutingComposition) in f.observation(actualProjection: f.mappingProjection(target: .init(backend: .sefaria, bookID: 1, workKey: "book:1", readerOwner: ObjectIdentifier(f.readerA)))) }),
            ("search_target_reader_lifetime_change_refused", { (f: MaktabahNativeRoutingComposition) in f.observation(actualProjection: f.mappingProjection(target: .init(backend: .otzaria, bookID: 1, workKey: "book:1", readerOwner: ObjectIdentifier(f.readerB)))) }),
            ("search_target_reader_disappearance_refused", { (f: MaktabahNativeRoutingComposition) in f.observation(actualProjection: f.mappingProjection(target: .init(backend: .otzaria, bookID: 1, workKey: "book:1", readerOwner: nil))) }),
            ("search_locale_change_refused", { (f: MaktabahNativeRoutingComposition) in f.observation(locale: "en") }),
            ("search_visible_reader_content_change_refused", { (f: MaktabahNativeRoutingComposition) in f.observation(reader: .init(sectionLocator: f.section)) }),
            ("search_visible_work_source_change_refused", { (f: MaktabahNativeRoutingComposition) in f.observation(readRevision: 2) }),
            ("search_visible_selection_change_refused", { (f: MaktabahNativeRoutingComposition) in f.observation(range: .init(location: 7, length: 2)) })
        ] {
            controls.run(name) {
                let f = Self(), owner = f.setup(), original = owner.observation
                let receipt = f.searchReceipt(for: owner)
                f.sourceObservation = mutate(f)
                try controls.refused { try f.advanceSemanticSearchJourney(owner, receipt: receipt) }
                try controls.require(owner.observation == original, "unrelated source change replaced the retained owner")
            }
        }
        controls.run("search_same_projection_all_visible_metadata_preserved") {
            let f = Self(), owner = f.setup(), original = owner.observation
            let receipt = f.searchReceipt(for: owner)
            f.sourceObservation = original
            try f.advanceSemanticSearchJourney(owner, receipt: receipt)
            try controls.require(owner.observation == original)
        }
        controls.run("search_own_transition_hides_only_viewer_metadata") {
            let f = Self(), owner = f.setup()
            owner.observation = f.observation(range: .init(location: 3, length: 8))
            f.sourceObservation = owner.observation
            let original = owner.observation, context = owner.context
            let receipt = f.searchReceipt(for: owner)
            try f.advanceSemanticSearchJourney(owner, receipt: receipt)
            try controls.require(owner.observation.epoch == original.epoch)
            try controls.require(owner.observation.projection == original.projection)
            try controls.require(owner.observation.readerContent == nil && owner.observation.currentWorkReadSource == nil && owner.observation.selectedRange == nil)
            try controls.require(owner.context == context && owner.context.contentRights.isEmpty && !owner.context.scopes.contains(.contentRead))
        }
        let cancelled = Task { @MainActor in
            let f = Self(), owner = f.setup()
            do { try f.validateSemanticJourney(owner); return false }
            catch is CancellationError { return true }
            catch { return false }
        }
        cancelled.cancel()
        let cancelledCorrectly = await cancelled.value
        controls.run("pre_cancelled_task_never_admits_continuation") { try controls.require(cancelledCorrectly) }

        controls.run("intent_post_accepts_exact_own_new_tab_with_original_targets") {
            let f = Self(), value = f.postAwaitSetup()
            try f.validateReaderIntentJourneyOwner(value.owner, initial: value.initial, entry: value.entry, manager: f.manager)
            try controls.require(value.owner.context.origin == .appIntent)
            try controls.require(value.owner.observation.projection.targets.count == value.initial.projection.targets.count + 1)
        }
        for (name, mutate) in [
            ("intent_post_scene_removed", { (f: MaktabahNativeRoutingComposition) in f.scenes.removeValue(forKey: f.scene) }),
            ("intent_post_session_replaced", { (f: MaktabahNativeRoutingComposition) in f.scenes[f.scene]!.session = BoundarySession() }),
            ("intent_post_manager_replaced", { (f: MaktabahNativeRoutingComposition) in f.scenes[f.scene]!.manager = f.otherManager }),
            ("intent_post_manager_id_replaced", { (f: MaktabahNativeRoutingComposition) in let e = f.scenes[f.scene]!; f.scenes[f.scene] = .init(managerID: ObjectIdentifier(f.otherManager), manager: f.manager, session: e.session, publicBinding: e.publicBinding) }),
            ("intent_post_window_unmounted", { (f: MaktabahNativeRoutingComposition) in f.scenes[f.scene]!.session.mounted = false }),
            ("intent_post_window_background", { (f: MaktabahNativeRoutingComposition) in f.scenes[f.scene]!.session.foreground = false }),
            ("intent_post_other_invocation_busy", { (f: MaktabahNativeRoutingComposition) in f.contexts[f.scene] = f.nativeContext }),
            ("intent_post_backend_generation_changed", { (f: MaktabahNativeRoutingComposition) in f.backend.current = .init(backend: .otzaria, generation: 8) }),
            ("intent_post_projection_source_missing", { (f: MaktabahNativeRoutingComposition) in f.scenes[f.scene]!.session.workspaceProjectionSource = nil }),
            ("intent_post_projection_not_authoritative", { (f: MaktabahNativeRoutingComposition) in f.scenes[f.scene]!.session.workspaceProjectionSource!.isAuthoritative = false }),
            ("intent_post_workspace_missing", { (f: MaktabahNativeRoutingComposition) in f.scenes[f.scene]!.session.workspaceProjectionSource!.workspace = nil }),
            ("intent_post_workspace_read_failed", { (f: MaktabahNativeRoutingComposition) in f.scenes[f.scene]!.session.workspaceProjectionSource!.failure = .unavailable }),
            ("intent_post_binding_missing", { (f: MaktabahNativeRoutingComposition) in f.scenes[f.scene]!.publicBinding = nil }),
            ("intent_post_binding_replaced", { (f: MaktabahNativeRoutingComposition) in f.scenes[f.scene]!.publicBinding = BoundaryBinding(f.scenes[f.scene]!.session.workspaceProjectionSource!.workspace!) }),
            ("intent_post_binding_lost_workspace", { (f: MaktabahNativeRoutingComposition) in f.scenes[f.scene]!.publicBinding!.owns = false }),
            ("intent_post_mapping_missing", { (f: MaktabahNativeRoutingComposition) in f.scenes[f.scene]!.session.workspaceProjectionSource!.workspace!.mapping = nil }),
            ("intent_post_mapping_coverage_incomplete", { (f: MaktabahNativeRoutingComposition) in f.updatePostMapping { $0.coverage = .incomplete } }),
            ("intent_post_mapping_wrong_scene", { (f: MaktabahNativeRoutingComposition) in f.updatePostMapping { $0.scene = "other-scene" } }),
            ("intent_post_mapping_wrong_owner", { (f: MaktabahNativeRoutingComposition) in f.updatePostMapping { $0.owner = ObjectIdentifier(f.otherManager) } }),
            ("intent_post_mapping_source_unavailable", { (f: MaktabahNativeRoutingComposition) in f.sourceA.event.phase = .unavailable }),
            ("intent_post_mapping_event_epoch_stale", { (f: MaktabahNativeRoutingComposition) in f.sourceA.event.epoch = .init(sourceID: f.epochSourceID, revision: 3) }),
            ("intent_post_mapping_source_replaced", { (f: MaktabahNativeRoutingComposition) in f.sourceB.event = f.sourceA.event; f.updatePostMapping { $0.source = f.sourceB } }),
            ("intent_post_mapping_epoch_changed", { (f: MaktabahNativeRoutingComposition) in f.updatePostMapping { $0.epoch = .init(sourceID: f.epochSourceID, revision: 3) }; f.sourceA.event.epoch = f.postMapping().epoch }),
            ("intent_post_mapping_projection_changed", { (f: MaktabahNativeRoutingComposition) in f.updatePostMapping { $0.projection = f.mappingProjection(version: 7) } })
        ] {
            controls.run(name) {
                let f = Self(), value = f.postAwaitSetup()
                mutate(f)
                try controls.refused { try f.validateReaderIntentJourneyOwner(value.owner, initial: value.initial, entry: value.entry, manager: f.manager) }
            }
        }
        for (name, mutate) in [
            ("intent_post_coherently_adopted_profile_change_refused", { (f: MaktabahNativeRoutingComposition, p: inout StudyWorkspaceMappingProjection) in p = .init(profileID: f.otherID, groupID: p.groupID, profileIDs: p.profileIDs, groupIDs: p.groupIDs, activeTabID: p.activeTabID, targets: p.targets) }),
            ("intent_post_coherently_adopted_group_change_refused", { (f: MaktabahNativeRoutingComposition, p: inout StudyWorkspaceMappingProjection) in p = .init(profileID: p.profileID, groupID: f.otherID, profileIDs: p.profileIDs, groupIDs: p.groupIDs, activeTabID: p.activeTabID, targets: p.targets) }),
            ("intent_post_coherently_adopted_profile_membership_refused", { (f: MaktabahNativeRoutingComposition, p: inout StudyWorkspaceMappingProjection) in p = .init(profileID: p.profileID, groupID: p.groupID, profileIDs: [f.profileID, f.otherID], groupIDs: p.groupIDs, activeTabID: p.activeTabID, targets: p.targets) }),
            ("intent_post_coherently_adopted_group_membership_refused", { (f: MaktabahNativeRoutingComposition, p: inout StudyWorkspaceMappingProjection) in p = .init(profileID: p.profileID, groupID: p.groupID, profileIDs: p.profileIDs, groupIDs: [f.groupID, f.otherID], activeTabID: p.activeTabID, targets: p.targets) }),
            ("intent_post_original_base_target_replaced_refused", { (f: MaktabahNativeRoutingComposition, p: inout StudyWorkspaceMappingProjection) in var targets = p.targets; targets[f.tabID] = .init(backend: .otzaria, bookID: 1, workKey: "book:1", readerOwner: ObjectIdentifier(f.readerB)); p = .init(profileID: p.profileID, groupID: p.groupID, profileIDs: p.profileIDs, groupIDs: p.groupIDs, activeTabID: p.activeTabID, targets: targets) }),
            ("intent_post_original_base_target_removed_refused", { (f: MaktabahNativeRoutingComposition, p: inout StudyWorkspaceMappingProjection) in var targets = p.targets; targets.removeValue(forKey: f.tabID); p = .init(profileID: p.profileID, groupID: p.groupID, profileIDs: p.profileIDs, groupIDs: p.groupIDs, activeTabID: p.activeTabID, targets: targets) })
        ] {
            controls.run(name) {
                let f = Self(), value = f.postAwaitSetup()
                var projection = f.postMapping().projection
                mutate(f, &projection)
                f.adoptProjection(value.owner, projection)
                try controls.refused { try f.validateReaderIntentJourneyOwner(value.owner, initial: value.initial, entry: value.entry, manager: f.manager) }
            }
        }

        controls.run("intent_post_coherent_source_namespace_aba_refused") {
            let f = Self(), value = f.postAwaitSetup()
            value.owner.observation = f.observation(epoch: 2, epochSource: f.otherID,
                actualProjection: value.owner.observation.projection, locale: Locale.current.identifier)
            f.updatePostMapping { $0.epoch = value.owner.observation.epoch }
            f.sourceA.event.epoch = value.owner.observation.epoch
            try controls.refused { try f.validateReaderIntentJourneyOwner(value.owner, initial: value.initial, entry: value.entry, manager: f.manager) }
        }
        controls.run("intent_post_coherent_locale_change_refused") {
            let f = Self(), value = f.postAwaitSetup()
            value.owner.observation = f.observation(epoch: 2,
                actualProjection: value.owner.observation.projection, locale: "changed-locale")
            try controls.refused { try f.validateReaderIntentJourneyOwner(value.owner, initial: value.initial, entry: value.entry, manager: f.manager) }
        }
        await controls.runAsync("factory_public_forwarder_retains_in_app_navigation_without_read") {
            let f = Self(); _ = f.setup()
            let journey = try await f.semanticJourneys(manager: f.manager)
            let result = await journey.commentaryThenPrepareDraft(baseLocator: f.base, proposedText: "proposal")
            try controls.require(result.isComplete && f.dispatched.count == 2)
            try controls.require(f.dispatched.allSatisfy { $0.1.origin == .inApp && $0.1.contentRights.isEmpty && !$0.1.scopes.contains(.contentRead) })
        }
        await controls.runAsync("factory_app_intent_owner_preserves_exact_context_and_two_steps") {
            let f = Self(); _ = f.setup()
            let context = f.context(sceneID: f.scene, origin: .appIntent, snapshot: f.backend.current)
            let owner = SemanticJourneyOwner(sceneID: f.scene, managerID: ObjectIdentifier(f.manager),
                context: context, observation: f.sourceObservation)
            let journey = f.semanticJourneys(owner: owner, manager: f.manager)
            let result = await journey.commentaryThenPrepareDraft(baseLocator: f.base, workRef: .init(backend: .otzaria, workKey: "book:2"), proposedText: "e\u{0301}")
            try controls.require(result.isComplete && f.dispatched.count == 2)
            try controls.require(f.dispatched.allSatisfy { $0.1 == context })
            try controls.require(f.dispatched.map { $0.0.action } == ["reader.openCommentary", "notes.prepareDraft"])
            try controls.require(f.dispatched[1].0.arguments["locator"] == (try .encoded(f.focus)))
            try controls.require(Array(f.dispatched[1].0.arguments["proposedText"]!.string!.utf8) == Array("e\u{0301}".utf8))
        }
        await controls.runAsync("factory_note_failure_retains_actual_first_step_result") {
            let f = Self(), owner = f.setup(); f.failNote = true
            let result = await f.semanticJourneys(owner: owner, manager: f.manager)
                .commentaryThenPrepareDraft(baseLocator: f.base, proposedText: "proposal")
            try controls.require(!result.isComplete && result.steps.count == 2 && f.dispatched.count == 2)
            try controls.require(result.steps[0].status == .completed && result.steps[1].status == .unavailable)
            try controls.require(result.steps[1].error?.code == "original_note_editor_not_visible")
            try controls.require(try result.steps[0].data?["locator"]?.decoded(as: ActionTextRef.self) == f.focus)
        }
        await controls.runAsync("factory_source_aba_after_reader_stops_note_and_retains_reader") {
            let f = Self(), owner = f.setup(); f.invalidateAfterReader = true
            let result = await f.semanticJourneys(owner: owner, manager: f.manager)
                .commentaryThenPrepareDraft(baseLocator: f.base, proposedText: "proposal")
            try controls.require(!result.isComplete && result.steps.count == 2 && f.dispatched.count == 1)
            try controls.require(result.steps[0].status == .completed && result.steps[1].status == .staleState)
        }
        await controls.runAsync("factory_backend_change_before_dispatch_refused") {
            let f = Self(), owner = f.setup()
            let journey = f.semanticJourneys(owner: owner, manager: f.manager)
            f.backend.current = .init(backend: .otzaria, generation: 8)
            let result = await journey.commentaryThenPrepareDraft(baseLocator: f.base)
            try controls.require(!result.isComplete && result.steps.count == 1 && result.steps[0].status == .staleState && f.dispatched.isEmpty)
        }
        await controls.runAsync("factory_native_typed_failure_preserves_status_and_code") {
            let f = Self(), owner = f.setup(); f.nativeFailure = .init(.cancelled, "cancelled")
            let result = await f.semanticJourneys(owner: owner, manager: f.manager)
                .commentaryThenPrepareDraft(baseLocator: f.base)
            try controls.require(result.steps.count == 1 && result.steps[0].status == .cancelled)
            try controls.require(result.steps[0].error?.code == "cancelled" && f.dispatched.count == 1)
        }
        await controls.runAsync("factory_missing_read_authority_cannot_count_or_dispatch") {
            let f = Self(), owner = f.setup()
            let result = await f.semanticJourneys(owner: owner, manager: f.manager)
                .countThenOpenResults(.init(backend: .otzaria, text: "word"))
            try controls.require(result.steps.count == 1 && result.steps[0].status == .unavailable)
            try controls.require(result.steps[0].error?.code == "trusted_read_authority_unavailable")
            try controls.require(f.dispatched.isEmpty && f.backend.readCalls == 0)
        }
        await controls.runAsync("factory_read_authority_for_other_scene_refused") {
            let f = Self(), owner = f.setup()
            let other = ActionExecutionContext(subjectID: "boundary-read", origin: .inApp, allowedBackends: [.otzaria],
                contentRights: [.otzaria], scopes: [.discovery, .contentRead], foregroundSceneID: "other-scene")
            let journey = f.semanticJourneys(owner: owner, manager: f.manager, readAuthority: { other })
            let result = await journey.countThenOpenResults(.init(backend: .otzaria, text: "word"))
            try controls.require(result.steps.count == 1 && result.steps[0].status == .staleState)
            try controls.require(f.dispatched.isEmpty && f.backend.readCalls == 0)
        }
        await controls.runAsync("factory_unknown_native_code_uses_original_public_sanitization") {
            let f = Self(), owner = f.setup(); f.nativeFailure = .init(.cancelled, "unknown_boundary_code")
            let result = await f.semanticJourneys(owner: owner, manager: f.manager)
                .commentaryThenPrepareDraft(baseLocator: f.base)
            try controls.require(result.steps.count == 1 && result.steps[0].status == .cancelled)
            try controls.require(result.steps[0].error?.code == "native_ui_failed")
            try controls.require(result.steps[0].error?.retryable == false && f.dispatched.count == 1)
        }
        print("SUMMARY \(controls.outcomes.count) \(controls.outcomes.filter { $0.1 }.count) \(controls.outcomes.filter { !$0.1 }.count)")
        return controls.outcomes.allSatisfy { $0.1 }
    }
}

@main struct NativeJourneyBoundaryMain {
    @MainActor static func main() async {
        if !(await MaktabahNativeRoutingComposition.runControls()) { exit(1) }
    }
}
