import Foundation
import OtzariaActionCore
import OtzariaUIRouting

/// The actual new service links the unchanged original Core/UIRouting modules.
/// Native navigation is an explicit callback boundary, never native acceptance.
@main struct NativeReaderTabServiceControls {
    @MainActor static func main() async throws {
        var passed = 0, failed = 0
        func check(_ condition: Bool, _ name: String) {
            if condition { passed += 1; print("PASS \(name)") }
            else { failed += 1; print("FAIL \(name)") }
        }
        let scene = UIStableID(rawValue: "window-a")!, profile = UUID(), group = UUID()
        func tab(id: UUID = UUID(), sceneID: UIStableID? = nil, profileID: UUID? = nil,
                 groupID: UUID? = nil, backend: ActionBackendID = .otzaria,
                 title: String = "Same original book") -> NativeReaderTabIntentService.Tab {
            .init(sceneID: sceneID ?? scene, profileID: profileID ?? profile, groupID: groupID ?? group,
                  tabID: id, backend: backend, title: title, profileTitle: "Profile", groupTitle: "Group",
                  windowTitle: "Profile / Group — Window 1")
        }
        let a = tab(), b = tab()
        check(a.id != b.id, "duplicate book title remains two stable original tab identities")
        check(a.id != tab(id: a.tabID, sceneID: UIStableID(rawValue: "window-b")!).id,
              "same tab UUID in another original window is distinct")
        check(a.id != tab(id: a.tabID, profileID: UUID()).id, "profile membership qualifies identity")
        check(a.id != tab(id: a.tabID, groupID: UUID()).id, "group membership qualifies identity")
        check(a.id != tab(id: a.tabID, backend: .sefaria).id, "backend qualifies identity")
        check(a.id == tab(id: a.tabID, title: "Renamed title").id, "display name is not identity")
        check(!a.detail.contains(scene.rawValue) && a.detail.contains("Window 1"), "human label reuses original window title")
        var catalog = [a, b], navigations = 0, selected: UUID?
        var outcome = UISceneAcknowledgement.requiresForeground
        let service = NativeReaderTabIntentService(discover: { catalog }, navigate: { target, _ in
            navigations += 1; selected = target.tabID; return outcome
        })
        check(try service.tabs(matching: "Same original book").count == 2,
              "exact title ambiguity is preserved for system entity selection")
        check(try service.tabs(identifiers: [b.id, a.id]) == [b, a], "query resolves only actual catalog and preserves requested ID order")
        check(try service.tabs(identifiers: ["missing"]).isEmpty, "entity query does not synthesize missing tab")
        _ = try await service.open(identifier: b.id)
        check(navigations == 1 && selected == b.tabID, "one typed selection callback receives exact user-selected tab")
        catalog = [a]
        do { _ = try await service.open(identifier: b.id); check(false, "stale metadata must fail") }
        catch { check((error as? UIRouteError)?.status == .staleState && navigations == 1,
                      "stale selected tab fails before any native navigation callback") }
        catalog = [a, a]
        do { _ = try service.tabs(); check(false, "duplicate source catalog must fail") }
        catch { check((error as? UIRouteError)?.code == "native_reader_tab_catalog_invalid", "duplicate actual source IDs fail closed") }
        catalog = [a]
        for ids in [[a.id, a.id], Array(repeating: "x", count: 65), [""]] {
            do { _ = try service.tabs(identifiers: ids); check(false, "invalid query must fail") }
            catch { check((error as? UIRouteError)?.status == .notSupported, "bounded unique entity query enforced") }
        }
        do { _ = try service.tabs(matching: String(repeating: "a", count: 513)); check(false, "oversize search") }
        catch { check((error as? UIRouteError)?.status == .notSupported, "bounded string query enforced") }
        catalog = [tab(title: "שבת")]
        check(try service.tabs(matching: "שבת").count == 1, "Hebrew exact original title resolves")
        catalog = [a]
        let failure = ActionFailure(code: "original_failure", message: "Original failure")
        for value in [UISceneAcknowledgement.queued(handle: "original"),
                      .requiresForeground, .requiresBackendSwitch(.sefaria), .notSupported(failure),
                      .staleState(failure), .cancelled, .failed(failure)] {
            outcome = value
            let result = try await service.open(identifier: a.id)
            check(result == value, "noncompleted original outcome remains distinct")
        }
        let snapshot = ActionBackendSnapshot(backend: .otzaria, generation: 3, rpcEpoch: nil)
        let descriptor = UIDestinationDescriptor(id: NativeReaderTabIntentService.destination,
            title: "Reader tab", implementation: .implemented, supportedBackends: [.otzaria],
            presentations: [.currentTab], requiredCoreActions: [])
        let registry = try UIDestinationRegistry(descriptors: [descriptor])
        check(!descriptor.allowsPublicRoute && descriptor.publicNavigationV2 == nil,
              "typed private tab identity has no public URL variant")
        func acknowledgement(target: NativeReaderTabIntentService.Tab, request: UUID, variant: Int = 0) throws -> UISceneAcknowledgement {
            let wanted = variant == 1 ? UUID() : request
            let targetScene = variant == 2 ? UIStableID(rawValue: "other-window")! : target.sceneID
            let targetTab = variant == 3 ? UUID() : target.tabID
            let targetGroup = variant == 4 ? UUID() : target.groupID
            let targetProfile = variant == 5 ? UUID() : target.profileID
            let expected = variant == 8 ? ActionBackendSnapshot(backend: .otzaria, generation: 99, rpcEpoch: nil) : snapshot
            let route = RouteSpec(requestId: wanted,
                destination: variant == 6 ? UIDestinationID(rawValue: "native.library")! : NativeReaderTabIntentService.destination,
                backend: .otzaria, presentation: .init(kind: .currentTab, tabID: UIStableID(rawValue: targetTab.uuidString)),
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
        let exact = NativeReaderTabIntentService(discover: { [a] }, navigate: { target, request in
            try acknowledgement(target: target, request: request)
        })
        if case .acknowledged = try await exact.open(identifier: a.id) {
            check(true, "exact private selection shape passes real original registry command and receipt validation")
        } else { check(false, "exact private receipt") }
        for variant in 1...9 {
            let malformed = NativeReaderTabIntentService(discover: { [a] }, navigate: { target, request in
                try acknowledgement(target: target, request: request, variant: variant)
            })
            do { _ = try await malformed.open(identifier: a.id); check(false, "malformed receipt \(variant)") }
            catch {
                check((error as? NativeReaderTabIntentService.Failure)?.code == "native_reader_tab_receipt_mismatch",
                      "wrong request/window/tab/group/profile/root/extra-state/snapshot/revision receipt \(variant) rejected and retained")
            }
        }
        let cancelledAfterAck = Task { @MainActor () throws -> Bool in
            var actualReceipt: UISceneReceipt?
            let handoff = NativeReaderTabIntentService(discover: { [a] }, navigate: { target, request in
                let result = try acknowledgement(target: target, request: request)
                if case .acknowledged(let receipt) = result { actualReceipt = receipt }
                withUnsafeCurrentTask { $0?.cancel() }
                return result
            })
            do { _ = try await handoff.open(identifier: a.id); return false }
            catch let error as NativeReaderTabIntentService.Failure {
                return error.code == "native_effect_uncertain" && error.receipt == actualReceipt
            } catch { return false }
        }
        check(try await cancelledAfterAck.value,
              "cancellation after actual callback ACK retains the observed receipt without claiming completion")
        let cancelled = Task { @MainActor () throws -> Void in _ = try await service.open(identifier: a.id) }
        cancelled.cancel()
        do { try await cancelled.value; check(false, "cancelled selection") }
        catch { check(error is CancellationError, "cancelled intent has no completed substitution") }
        print(String(data: try JSONSerialization.data(withJSONObject: [
            "scope": "actual new service with exact original Core/UIRouting modules; explicit native callback boundary",
            "passed": passed, "failed": failed, "native": "NOT_RUN"
        ], options: [.sortedKeys]), encoding: .utf8)!)
        if failed != 0 { throw NSError(domain: "NativeReaderTabServiceControls", code: failed) }
    }
}
