import Foundation
import Observation
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

@main struct ParentDomainControls {
    @MainActor static var rows: [[String: Any]] = []
    @MainActor static func require(_ value: Bool, _ reason: String) throws {
        if !value { throw ControlFailure.expected(reason) }
    }
    @MainActor static func refuses(_ body: () throws -> Void) -> Bool { do { try body(); return false } catch { return true } }
    @MainActor static func test(_ name: String, _ body: @MainActor () async throws -> Void) async {
        do { try await body(); rows.append(["name":name,"pass":true]) }
        catch { rows.append(["name":name,"pass":false,"error":String(describing:error)]) }
    }
    @MainActor static func execute() async {
        if CommandLine.arguments.contains("--original-before-feature") {
            for profile in [false,true] {
                await test(profile ? "original_profile_search_parent_gap" : "original_group_history_parent_gap") {
                    let f = try ParentFixture(profile: profile, from: profile ? .search : .history)
                    let bound = try f.retainBeforeFeature(); defer { bound.release() }
                    try require(bound.isReserved == false, "same intended original source must be retainable before parent")
                }
            }
            return
        }
        let onlyVisibility = CommandLine.arguments.contains("--visibility-counterfactual")
        if !onlyVisibility {
            for config in [(false,false,false,iOSTab.history), (false,true,false,.search), (false,false,true,.search),
                           (true,false,false,.history), (true,false,true,.search)] {
                let (empty,profile,phone,from)=config
                await test("original_\(profile ? "profile" : "group")_\(empty ? "empty" : "loaded")_\(phone ? "phone" : "ipad")_from_\(from)") {
                    let f = try ParentFixture(empty:empty,profile:profile,phone:phone,from:from)
                    let bound=try f.retain();defer{bound.release()}
                    let before=f.base.fixture.store.snapshot
                    let rootBefore=f.base.root.selectionRevision!,modeBefore=f.base.fixture.manager.nativeModePresentationRevision!
                    let settingsBefore=f.base.root.settingsRevision
                    let command=try await f.prepare(bound)
                    let kind=try bound.originalParentSelectionKind()
                    try require(kind == .workspaceSelection(profileID:UIStableID(rawValue:f.base.fixture.targetProfile.uuidString)!,
                        workspaceID:UIStableID(rawValue:f.base.fixture.g2.uuidString)!,activeTabID:bound.target.activeDocumentID.flatMap{UIStableID(rawValue:$0.uuidString)}),"exact original staged selection")
                    let observation=try await f.present(bound,command:command)
                    try require(f.base.fixture.store.snapshot==before && !bound.isApplied,"parent cannot perform Store effect or complete selection")
                    try require(try bound.selectionSurface(from:f.base.originalProjection())==nil,"parent alone is not final Group projection")
                    try bound.viewerParent!.beginSelection(observation,command:command)
                    try bound.apply()
                    try require(bound.isApplied && f.base.fixture.workspace.group?.id==f.base.fixture.g2,"original group selected")
                    try require(f.base.fixture.workspace.profile?.id==f.base.fixture.targetProfile,"original profile selected")
                    try require(f.base.root.selectionRevision==rootBefore+1 && f.base.fixture.manager.nativeModePresentationRevision==modeBefore+1
                        && f.base.root.settingsRevision==settingsBefore,"one root, one original onChange mode, zero Settings writes")
                    let projection=try bound.selectionSurface(from:f.base.originalProjection())
                    try require(projection?.destination==MaktabahNativeWorkspaceSelectionBinding.destination,"independent original final model projection required; no native ACK claimed")
                    if empty {
                        try require(bound.observedSurface==(phone ? .library : .emptyReader) && f.base.fixture.manager.openTabs.isEmpty
                            && f.base.fixture.manager.activeTabId==nil && projection?.presentation.tabID==nil,"actual empty result, no fabricated Reader")
                    } else {
                        try require(f.base.fixture.manager.openTabs[0].viewModel === f.base.fixture.targetTabs[0].viewModel
                            && f.base.fixture.manager.selectedBook === f.base.fixture.targetTabs[0].book,"original retained Reader and book")
                    }
                    let after=f.base.fixture.store.snapshot
                    try require(refuses{try bound.apply()} && f.base.fixture.store.snapshot==after,"terminal cannot replay")
                }
            }
            await test("current_viewer_original_path_stays_single_terminal") {
                let f=try GroupBindingFixture();let b=try f.retain();defer{b.release()}
                try await f.prepare(b);try require(try b.originalParentSelectionKind()==nil,"no staged path for already visible Viewer")
                try f.apply(b);try require(b.isApplied && f.fixture.workspace.group?.id==f.fixture.g2,"original terminal")
            }
            await test("nil_group_target_requires_exact_empty_prepared_stage") {
                let f=try ParentFixture(empty:true);let b=try f.retain();defer{b.release()};_ = try await f.prepare(b)
                guard let r=f.base.fixture.workspace.fixtureGroupReservation() else{throw ControlFailure.expected("real reservation")}
                r.prepared.staged=[f.base.fixture.oldTabs[0]]
                try require(refuses{_ = try b.originalParentSelectionKind()},"wire nil cannot substitute mismatched original stage")
            }
            await test("selection_before_same_parent_ready_is_refused") {
                let f=try ParentFixture();let b=try f.retain();defer{b.release()};_ = try await f.prepare(b)
                let before=f.base.fixture.store.snapshot
                try require(refuses{try b.apply()} && f.base.fixture.store.snapshot==before,"no renderer or source validator grants terminal")
            }
            for change in ["settings_ABA","root_ABA","equal_mode","backend_ABA"] {
                await test(change+"_before_parent_is_permanently_stale") {
                    let f=try ParentFixture();let b=try f.retain();defer{b.release()}
                    let before=f.base.fixture.store.snapshot
                    switch change {
                    case "settings_ABA":f.base.bindings.showSettings.wrappedValue=true;f.base.bindings.showSettings.wrappedValue=false
                    case "root_ABA":f.base.bindings.selectedTab.wrappedValue = .search;f.base.bindings.selectedTab.wrappedValue = .history
                    case "equal_mode":f.base.fixture.manager.switchToMode(.history)
                    default:BackendCoordinator.shared.activeBackendID = .sefaria;BackendCoordinator.shared.activeBackendID = .otzaria
                    }
                    try require(refuses{try b.reserve()} && f.base.fixture.store.snapshot==before,"original source history retained")
                }
            }
            for change in ["window_ABA","host_replacement","host_detach","lease_cancelled","read_callback_release"] {
                await test(change+"_after_parent_prevents_store") {
                    let f=try ParentFixture();let b=try f.retain();defer{b.release()};_ = try await f.ready(b)
                    let before=f.base.fixture.store.snapshot
                    switch change {
                    case "window_ABA":
                        f.view.window=nil;f.windowSource.observe(nil,from:f.view)
                        f.view.window=f.window;f.windowSource.observe(f.window,from:f.view)
                    case "host_replacement":
                        let replacement=MaktabahNativeViewerParentWitness.Controller();replacement.window=f.window
                        f.host.attach(replacement,manager:f.base.fixture.manager)
                    case "host_detach":f.host.detach(f.controller)
                    case "lease_cancelled":f.base.leaseValid=false
                    default:f.controller.onRead={b.release()}
                    }
                    try require(refuses{try b.apply()} && f.base.fixture.store.snapshot==before,"retired source cannot become unowned terminal")
                }
            }
            await test("completed_group_proof_still_requires_original_visible_parent") {
                let f=try ParentFixture();let b=try f.retain();defer{b.release()};_ = try await f.ready(b);try b.apply()
                f.controller.visible=false
                try require(refuses{_ = try b.selectionSurface(from:f.base.originalProjection())},"no stale post-effect proof")
            }
            await test("cold_legacy_and_hidden_active_phone_remain_explicit_unavailable") {
                let legacy=try GroupBindingFixture(warm:false,qualified:false)
                try require(try !legacy.catalog().contains{$0.groupID==legacy.fixture.g2},"no synthetic pre-token issuer")
                let hidden=try GroupBindingFixture(phone:true,sameGroup:true);hidden.fixture.manager.selectedBook=nil
                try require(try !hidden.catalog().contains{$0.groupID==hidden.fixture.g1},"original same-active no-op does not reopen Reader")
            }
        }
        await test("postflush_same_counters_hidden_parent_prevents_original_store") {
            let f=try ParentFixture();let b=try f.retain();defer{b.release()};_ = try await f.ready(b)
            let before=f.base.fixture.store.snapshot
            let snapshots=SnapshotProbe(f.base.fixture.directory.appendingPathComponent("backend"))
            snapshots.flushHook={f.controller.visible=false}
            BackendCoordinator.shared.activeSessionSnapshots=snapshots
            try require(refuses{try b.apply()} && f.base.fixture.store.snapshot==before
                && f.base.fixture.manager.openTabs.map(\.id)==f.base.fixture.oldTabs.map(\.id),"fresh SAME visible parent after flush, before any Store/native effect")
            try require(snapshots.events==["sync-begin","flush"],"original snapshot rollback completes inside synchronous scope")
        }
        await test("poststore_hidden_parent_keeps_real_partial_effect_and_blocks_native") {
            let f=try ParentFixture();let b=try f.retain();defer{b.release()};_ = try await f.ready(b)
            let probe=PassiveStoreProbe();probe.did={f.controller.visible=false}
            let token=f.base.fixture.store.observeSnapshotPublication(probe)
            defer{f.base.fixture.store.removeSnapshotPublicationObserver(token)}
            try require(refuses{try b.apply()} && f.base.fixture.manager.openTabs.map(\.id)==f.base.fixture.oldTabs.map(\.id),"post-Store callback cannot publish native selection")
            try require(f.base.fixture.workspace.group?.id==f.base.fixture.g2 && !b.isApplied,"real durable Store effect is retained, not relabeled rollback or ACK")
        }
    }
    @MainActor static func main() async {
        await execute()
        let failures=rows.filter{!($0["pass"] as! Bool)}.count
        print(String(data:try! JSONSerialization.data(withJSONObject:["rows":rows,"pass":rows.count-failures,"fail":failures,
            "scope":"Actual original Group/Viewer/Store/persistence/Adapter/manager publications and source policy; explicit domain/UIKit/Resolver/Reader-rendering boundaries. No native or app SDK claim."],options:[.sortedKeys]),encoding:.utf8)!)
        if failures != 0 {exit(1)}
    }
}
