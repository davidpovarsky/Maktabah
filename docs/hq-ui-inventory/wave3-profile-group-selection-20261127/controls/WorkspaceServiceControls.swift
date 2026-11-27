import Foundation
import OtzariaActionCore
import OtzariaUIRouting

/// Actual service and ORIGINAL Core/UIRouting contracts. The native callback
/// below is an explicit boundary; none of these controls is an installed UI test.
@main struct WorkspaceSelectionServiceControls {
    @MainActor static func main() async throws {
        var passed = 0, failed = 0
        func check(_ condition: Bool, _ name: String) {
            if condition { passed += 1; print("PASS " + name) }
            else { failed += 1; print("FAIL " + name) }
        }
        typealias Service = NativeWorkspaceSelectionIntentService
        let scene = UIStableID(rawValue: "actual-window-a")!, profile = UUID(), group = UUID(), active = UUID()
        func selection(_ kind: Service.Kind = .group, sceneID: UIStableID? = nil,
                       profileID: UUID? = nil, groupID: UUID? = nil, tabID: UUID? = active,
                       backend: ActionBackendID = .otzaria, title: String = "Original group") -> Service.Selection {
            .init(kind: kind, sceneID: sceneID ?? scene, backend: backend,
                  profileID: profileID ?? profile, groupID: groupID ?? group, activeDocumentID: tabID,
                  title: title, profileTitle: "Original profile", groupTitle: title, windowTitle: "Original window")
        }
        let p = selection(.profile, title: "Original profile"), g = selection(), empty = selection(groupID: UUID(), tabID: nil)
        check(p.id != g.id, "profile and group are distinct finite entity kinds")
        check(p.id == selection(.profile, groupID: UUID()).id, "profile identity survives original first ordered group change")
        check(g.id != selection(groupID: UUID()).id, "group entity retains exact original group UUID")
        check(g.id != selection(profileID: UUID()).id, "group identity retains original profile membership")
        check(g.id != selection(sceneID: UIStableID(rawValue: "other-window")!).id, "actual original scene qualifies selection")
        check(g.id != selection(backend: .sefaria).id, "current original backend qualifies selection")
        check(g.id == selection(title: "Renamed title").id, "display title is not executable authority")
        check(g.id == selection(tabID: UUID()).id, "group identity does not freeze a stale selected document")
        var catalog = [p, g, empty], calls = 0, selected: Service.Selection?
        var outcome = UISceneAcknowledgement.requiresForeground
        let service = Service(discover: { catalog }, navigate: { target, _ in
            calls += 1; selected = target; return outcome
        })
        check(try service.selections(kind: .profile) == [p], "profile query cannot return group entities")
        check(try service.selections(kind: .group).count == 2, "group query preserves same-name ambiguity")
        check(try service.selections(kind: .group, identifiers: [empty.id, g.id]) == [empty, g], "exact live identifier query retains order")
        check(try service.selections(kind: .group, identifiers: [p.id]).isEmpty, "foreign entity kind is never silently reinterpreted")
        check(try service.selections(kind: .group, identifiers: ["missing"]).isEmpty, "missing original entity is not synthesized")
        _ = try await service.open(kind: .group, identifier: empty.id)
        check(calls == 1 && selected == empty, "empty group uses exact declared original target with no synthetic tab")
        let changedFirst = selection(.profile, groupID: UUID(), tabID: UUID(), title: "Original profile")
        catalog = [changedFirst]
        _ = try await service.open(kind: .profile, identifier: p.id)
        check(calls == 2 && selected == changedFirst, "cached profile resolves actual first group freshly before first await")
        do { _ = try await service.open(kind: .group, identifier: g.id); check(false, "stale group") }
        catch { check((error as? UIRouteError)?.status == .staleState && calls == 2, "removed group refuses before navigation") }
        do { _ = try await service.open(kind: .group, identifier: p.id); check(false, "wrong entity kind") }
        catch { check((error as? UIRouteError)?.status == .staleState && calls == 2, "profile token cannot invoke group action") }
        catalog = [g, g]
        do { _ = try service.selections(kind: .group); check(false, "ambiguous identity") }
        catch { check((error as? UIRouteError)?.code == "native_workspace_selection_catalog_invalid", "duplicate actual identifiers fail closed") }
        catalog = [selection(title: " ")]
        do { _ = try service.selections(kind: .group); check(false, "empty original title") }
        catch { check((error as? UIRouteError)?.status == .unavailable, "empty title is not invented by service") }
        catalog = [g]
        for ids in [[g.id, g.id], Array(repeating: "x", count: 65), [""]] {
            do { _ = try service.selections(kind: .group, identifiers: ids); check(false, "invalid query") }
            catch { check((error as? UIRouteError)?.status == .notSupported, "bounded unique query input") }
        }
        do { _ = try service.selections(kind: .group, matching: String(repeating: "a", count: 513)); check(false, "oversize title search") }
        catch { check((error as? UIRouteError)?.status == .notSupported, "oversize query is not truncated") }
        catalog = [selection(title: "שבת"), selection(groupID: UUID(), title: "שבת א")]
        check(try service.selections(kind: .group, matching: "שבת").count == 1, "Hebrew exact match precedes broader title matches")
        catalog = [g]
        let failure = ActionFailure(code: "original_failure", message: "Original failure")
        for value in [UISceneAcknowledgement.queued(handle: "original"), .requiresForeground,
                      .requiresBackendSwitch(.sefaria), .notSupported(failure), .staleState(failure), .cancelled, .failed(failure)] {
            outcome = value
            check(try await service.open(kind: .group, identifier: g.id) == value, "noncompleted original outcome is not relabelled success")
        }
        let snapshot = ActionBackendSnapshot(backend: .otzaria, generation: 7, rpcEpoch: nil)
        let descriptor = UIDestinationDescriptor(id: Service.destination, title: "Original workspace selection",
            implementation: .implemented, supportedBackends: [.otzaria], presentations: [.currentTab], requiredCoreActions: [])
        let registry = try UIDestinationRegistry(descriptors: [descriptor])
        check(!descriptor.allowsPublicRoute && descriptor.publicNavigationV2 == nil,
              "private original selection does not expand public URL schema")
        func acknowledgement(_ target: Service.Selection, _ request: UUID, variant: Int = 0) throws -> UISceneAcknowledgement {
            let wanted = variant == 1 ? UUID() : request
            let targetScene = variant == 2 ? UIStableID(rawValue: "other-window")! : target.sceneID
            let targetTab = variant == 3 ? UUID() : target.activeDocumentID
            let targetGroup = variant == 4 ? UUID() : target.groupID
            let targetProfile = variant == 5 ? UUID() : target.profileID
            let expected = variant == 8 ? ActionBackendSnapshot(backend: .otzaria, generation: 88, rpcEpoch: nil) : snapshot
            let route = RouteSpec(requestId: wanted,
                destination: variant == 6 ? UIDestinationID(rawValue: "native.library")! : Service.destination,
                backend: .otzaria,
                presentation: .init(kind: .currentTab, tabID: targetTab.flatMap { UIStableID(rawValue: $0.uuidString) }),
                state: .init(workspaceID: UIStableID(rawValue: targetGroup.uuidString),
                             profileID: UIStableID(rawValue: targetProfile.uuidString),
                             selectedItemID: variant == 7 ? UIStableID(rawValue: "unrequested-item")! : nil),
                scene: .init(kind: .specific, sceneID: targetScene, expectedRevision: 4), expectedBackendSnapshot: expected)
            if variant == 0 {
                let invocation = ActionPortInvocation(requestId: request, snapshot: snapshot, deadlineUptimeNanoseconds: .max)
                let command = try UISceneCommand(route: registry.validate(route), invocation: invocation,
                    scene: .init(sceneID: targetScene, revision: 4, backendSnapshot: snapshot))
                let receipt = UISceneReceipt(requestId: request, route: route, backendSnapshot: snapshot,
                    sceneID: targetScene, basedOnSceneRevision: 4, appliedSceneRevision: 5)
                try receipt.validate(for: command, observed: .init(sceneID: targetScene, revision: 5,
                    backendSnapshot: snapshot, visibleRoute: route))
                return .acknowledged(receipt)
            }
            return .acknowledged(.init(requestId: wanted, route: route, backendSnapshot: snapshot,
                sceneID: targetScene, basedOnSceneRevision: 4, appliedSceneRevision: variant == 9 ? 4 : 5))
        }
        for target in [g, p, empty] {
            let exact = Service(discover: { [target] }, navigate: { target, request in try acknowledgement(target, request) })
            if case .acknowledged = try await exact.open(kind: target.kind, identifier: target.id) {
                check(true, "group/profile/empty exact route passes actual original registry and receipt validation")
            } else { check(false, "original exact receipt") }
        }
        for variant in 1...9 {
            let malformed = Service(discover: { [g] }, navigate: { target, request in
                try acknowledgement(target, request, variant: variant)
            })
            do { _ = try await malformed.open(kind: .group, identifier: g.id); check(false, "malformed receipt \(variant)") }
            catch { check((error as? Service.Failure)?.code == "native_workspace_selection_receipt_mismatch",
                          "wrong request/scene/tab/group/profile/root/state/snapshot/revision \(variant) refused with receipt retained") }
        }
        let cancelledAfterAck = Task { @MainActor () throws -> Bool in
            var actual: UISceneReceipt?
            let handoff = Service(discover: { [g] }, navigate: { target, request in
                let result = try acknowledgement(target, request)
                if case .acknowledged(let receipt) = result { actual = receipt }
                withUnsafeCurrentTask { $0?.cancel() }
                return result
            })
            do { _ = try await handoff.open(kind: .group, identifier: g.id); return false }
            catch let error as Service.Failure { return error.code == "native_effect_uncertain" && error.receipt == actual }
            catch { return false }
        }
        check(try await cancelledAfterAck.value, "cancellation at observed ACK handoff retains actual receipt")
        let cancelled = Task { @MainActor () throws -> Void in _ = try await service.open(kind: .group, identifier: g.id) }
        cancelled.cancel()
        do { try await cancelled.value; check(false, "cancelled selection") }
        catch { check(error is CancellationError, "cancelled action is not silently substituted") }
        print(String(data: try JSONSerialization.data(withJSONObject: ["passed": passed, "failed": failed,
            "scope": "actual service with original Core/UIRouting modules; explicit native callback boundary", "native": "NOT_RUN"], options: [.sortedKeys]), encoding: .utf8)!)
        if failed != 0 { throw NSError(domain: "WorkspaceSelectionServiceControls", code: failed) }
    }
}
