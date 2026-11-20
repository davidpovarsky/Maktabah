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
@MainActor final class BoundaryBackend {
    var current = ActionBackendSnapshot(backend: .otzaria, generation: 7)
    var failure: ActionPortError?
    func currentBackendSnapshot() throws -> ActionBackendSnapshot {
        if let failure { throw failure }; return current
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
final class BoundaryIdentity { }
enum ControlFailure: Error { case failed(String) }
@MainActor final class ControlRecorder {
    var outcomes: [(String, Bool)] = []
    func run(_ name: String, _ body: () throws -> Void) {
        do { try body(); outcomes.append((name, true)); print("PASS " + name) }
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
    struct SceneEntry { let managerID: ObjectIdentifier }
    var scenes: [UIStableID: SceneEntry] = [:]
    var contexts: [UIStableID: ActionExecutionContext] = [:]
    let backend = BoundaryBackend()
    let directory = BoundaryDirectory()
    private var sourceObservation: HanlinSourceObservation!
    var sourceUnavailable = false
    fileprivate func hanlinSource(sceneID: UIStableID, entry: SceneEntry) throws -> HanlinSourceObservation {
        guard !sourceUnavailable else { throw ActionPortError.unavailable }
        return sourceObservation
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
        print("SUMMARY \(controls.outcomes.count) \(controls.outcomes.filter { $0.1 }.count) \(controls.outcomes.filter { !$0.1 }.count)")
        return controls.outcomes.allSatisfy { $0.1 }
    }
}

@main struct NativeJourneyBoundaryMain {
    @MainActor static func main() async {
        if !(await MaktabahNativeRoutingComposition.runControls()) { exit(1) }
    }
}
