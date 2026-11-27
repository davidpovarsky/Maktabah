import Foundation
import Observation
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

@main struct HiddenGroupControls {
    @MainActor static var rows: [[String: Any]] = []
    @MainActor static func require(_ value: Bool, _ reason: String) throws {
        if !value { throw ControlFailure.expected(reason) }
    }
    @MainActor static func refuses(_ body: () throws -> Void) -> Bool { do { try body(); return false } catch { return true } }
    @MainActor static func test(_ name: String, _ body: @MainActor () async throws -> Void) async {
        if let only = CommandLine.arguments.first(where: { $0.hasPrefix("--only=") }), only != "--only=" + name { return }
        FileHandle.standardError.write(Data(("START " + name + "\n").utf8))
        do { try await body(); rows.append(["name":name,"pass":true]) }
        catch { rows.append(["name":name,"pass":false,"error":String(describing:error)]) }
        FileHandle.standardError.write(Data(("END " + name + "\n").utf8))
    }
    // One explicit synchronous caller event, consumed before it reenters an
    // actual observed setter. Observation's onChange must not turn the test's
    // intended single nested user write into unbounded test recursion.
    @MainActor final class OneShotFixtureCallback {
        var action: (@MainActor () -> Void)?
        init(_ action: @escaping @MainActor () -> Void) { self.action = action }
        func run() { let callback = action; action = nil; callback?() }
    }
    @MainActor static func watch<T>(_ read: @MainActor () -> T, then action: @escaping @MainActor () -> Void) {
        let callback = OneShotFixtureCallback(action)
        withObservationTracking { _ = read() } onChange: { MainActor.assumeIsolated { callback.run() } }
    }
    @MainActor static func hidden() throws -> GroupBindingFixture {
        let f = try GroupBindingFixture(phone:true,sameGroup:true)
        f.fixture.manager.selectedBook = nil
        return f
    }
    @MainActor static func selected(_ f: GroupBindingFixture) throws -> iOSNavigationManager.ReaderTab {
        guard let tab = f.fixture.manager.openTabs.first(where:{$0.id==f.fixture.manager.activeTabId}) else { throw ControlFailure.expected("actual active tab") }
        return tab
    }
    @MainActor static func execute() async {
        let baseline = CommandLine.arguments.contains("--baseline")
        let counter = CommandLine.arguments.contains("--source-counterfactual")
        if CommandLine.arguments.contains("--annotation-fixture") {
            await test("explicit_annotation_boundary_nil_to_nil_does_not_emit") {
                let f=try hidden(),tab=try selected(f);var calls=0
                watch({tab.viewModel.annotationEvent}){calls += 1}
                tab.viewModel.annotationEvent=nil
                try require(calls==0,"actual Observation equal optional Int fixture does not emit")
            }
            await test("explicit_annotation_boundary_existing_event_clear_emits_once") {
                let f=try hidden(),tab=try selected(f);var calls=0
                tab.viewModel.annotationEvent=91
                watch({tab.viewModel.annotationEvent}){calls += 1}
                tab.viewModel.annotationEvent=nil
                try require(calls==1,"existing fixture event clear invokes exactly one callback")
            }
            return
        }
        if !counter {
            for profile in [false,true] {
                await test("hidden_same_active_\(profile ? "profile" : "group")_uses_original_presentation_once") {
                    let f=try hidden(),tab=try selected(f)
                    tab.viewModel.annotationEvent=91;tab.viewModel.searchEvent=92;tab.viewModel.needsScrollRestore=false
                    let before=f.fixture.manager.selectedBookPresentationRevision!,root=f.root.selectionRevision,mode=f.fixture.manager.nativeModePresentationRevision
                    let bound=try f.retain(profile:profile);defer{bound.release()}
                    try require(f.fixture.manager.selectedBook==nil && f.fixture.manager.persistCalls.isEmpty,"capture has no effect")
                    try await f.prepare(bound)
                    try require(f.fixture.manager.selectedBook==nil && f.fixture.manager.persistCalls.isEmpty,"stage has no presentation effect")
                    try f.apply(bound)
                    try require(bound.isApplied && f.fixture.manager.selectedBook === tab.book && f.fixture.manager.selectedBookPresentationMode == .viewer,"same original book presented")
                    try require(f.fixture.manager.activeTabId==tab.id && f.fixture.manager.openTabs.last?.viewModel === tab.viewModel,"no replacement or different active tab")
                    try require(f.fixture.manager.selectedBookPresentationRevision==before+1 && f.root.selectionRevision==root && f.fixture.manager.nativeModePresentationRevision==mode,"exact +1 book and +0 root/mode")
                    try require(tab.viewModel.annotationEvent==nil && tab.viewModel.searchEvent==nil && tab.viewModel.needsScrollRestore && f.fixture.manager.selectedContentId==tab.viewModel.currentContentId,"all original presentation assignments")
                    try require(f.fixture.manager.persistCalls==[false,true],"original helper persistence then original Group final persistence")
                    try require(try bound.selectionSurface(from:f.originalProjection())?.destination==MaktabahNativeWorkspaceSelectionBinding.destination,"original model witness required; no native ACK claimed")
                    let saved=f.fixture.store.snapshot
                    try require(refuses{try bound.apply()} && f.fixture.store.snapshot==saved && f.fixture.manager.selectedBookPresentationRevision==before+1,"same operation cannot replay")
                }
            }
            for profile in [false,true] {
                await test("hidden_same_active_\(profile ? "profile_search" : "group_history")_keeps_one_original_parent") {
                    let f=try ParentFixture(profile:profile,phone:true,from:profile ? .search:.history,sameGroup:true)
                    f.base.fixture.manager.selectedBook=nil
                    let tab=try selected(f.base),rev=f.base.fixture.manager.selectedBookPresentationRevision!
                    let root=f.base.root.selectionRevision!,mode=f.base.fixture.manager.nativeModePresentationRevision!
                    let bound=try f.retain();defer{bound.release()}
                    let command=try await f.prepare(bound),store=f.base.fixture.store.snapshot
                    let observation=try await f.present(bound,command:command)
                    try require(f.base.fixture.manager.selectedBook==nil && f.base.fixture.store.snapshot==store,"parent alone neither selects book nor commits group")
                    try bound.viewerParent!.beginSelection(observation,command:command);try bound.apply()
                    try require(bound.isApplied && f.base.fixture.manager.selectedBook === tab.book && f.base.fixture.manager.selectedBookPresentationRevision==rev+1,"same original tab after real source boundary")
                    try require(f.base.root.selectionRevision==root+1 && f.base.fixture.manager.nativeModePresentationRevision==mode+1,"one original root and original onChange mode publication")
                    try require(try bound.selectionSurface(from:f.base.originalProjection()) != nil,"final original Reader projection still separate")
                }
            }
            if baseline { return }
            await test("ordinary_selectTab_same_active_early_return_is_unchanged") {
                let f=try hidden(),tab=try selected(f);tab.viewModel.annotationEvent=4;tab.viewModel.searchEvent=5
                let rev=f.fixture.manager.selectedBookPresentationRevision
                f.fixture.manager.selectTab(id:tab.id)
                try require(f.fixture.manager.selectedBook==nil && f.fixture.manager.selectedBookPresentationRevision==rev && f.fixture.manager.persistCalls.isEmpty && tab.viewModel.annotationEvent==4 && tab.viewModel.searchEvent==5,"ordinary original no-op preserved")
            }
            await test("already_presented_phone_group_keeps_zero_book_publications") {
                let f=try GroupBindingFixture(phone:true,sameGroup:true);let rev=f.fixture.manager.selectedBookPresentationRevision
                let b=try f.retain();defer{b.release()};try await f.prepare(b);try f.apply(b)
                try require(f.fixture.manager.selectedBookPresentationRevision==rev && f.fixture.manager.persistCalls==[true],"no redundant presentation")
            }
            await test("ipad_same_active_does_not_acquire_phone_presentation") {
                let f=try GroupBindingFixture(sameGroup:true);f.fixture.manager.selectedBook=nil
                let rev=f.fixture.manager.selectedBookPresentationRevision
                let b=try f.retain();defer{b.release()};try await f.prepare(b);try f.apply(b)
                try require(f.fixture.manager.selectedBook==nil && f.fixture.manager.selectedBookPresentationRevision==rev && f.fixture.manager.persistCalls==[true],"original iPad path unchanged")
            }
            await test("different_phone_group_uses_original_selectTab") {
                let f=try GroupBindingFixture(phone:true);let rev=f.fixture.manager.selectedBookPresentationRevision!
                let b=try f.retain();defer{b.release()};try await f.prepare(b);try f.apply(b)
                try require(f.fixture.manager.selectedBook === f.fixture.targetTabs[0].book && f.fixture.manager.selectedBookPresentationRevision==rev+1 && f.fixture.manager.persistCalls==[false,true],"original changing-tab sequence unchanged")
            }
            await test("empty_phone_group_keeps_original_close_sequence") {
                let f=try GroupBindingFixture(empty:true,phone:true);let rev=f.fixture.manager.selectedBookPresentationRevision!
                let b=try f.retain();defer{b.release()};try await f.prepare(b);try f.apply(b)
                try require(b.isEmpty && f.fixture.manager.openTabs.isEmpty && f.fixture.manager.selectedBook==nil && f.fixture.manager.selectedBookPresentationRevision==rev+1 && f.fixture.manager.persistCalls==[true,true,true],"no presentation for empty stage")
            }
            for fault in ["foreign_book","overflow","exhausted"] {
                await test("hidden_catalog_refuses_"+fault) {
                    let f=try hidden()
                    switch fault {
                    case "foreign_book":f.fixture.manager.selectedBook=f.fixture.oldTabs[0].book
                    case "overflow":f.fixture.manager.fixtureBookRevision(.max)
                    default:f.fixture.manager.fixtureBookRevision(nil)
                    }
                    try require(try !f.catalog().contains{$0.groupID==f.fixture.g1},"unavailable source, not generic nil allowance")
                }
            }
            await test("equal_nil_book_during_catalog_await_retires_before_store") {
                let f=try hidden(),b=try f.retain();defer{b.release()};let before=f.fixture.store.snapshot
                ChavrusaTextTargetBackendBookResolver.shared.duringCatalog={f.fixture.manager.selectedBook=nil}
                var rejected=false;do{try await f.prepare(b)}catch{rejected=true}
                try require(rejected && f.fixture.store.snapshot==before && f.fixture.manager.selectedBook==nil,"one-shot original publisher detects equal write")
            }
            await test("same_id_cached_replacement_reader_refuses_before_store") {
                let f=try hidden(),tab=try selected(f)
                let replacement=ReaderViewModel(book:tab.book);replacement.seedLoaded(tab.viewModel.currentLocator!)
                let alternate=iOSNavigationManager.ReaderTab(id:tab.id,book:tab.book,initialContentId:tab.initialContentId,viewModel:replacement)
                f.fixture.workspace.fixtureCache([alternate],groupID:f.fixture.g1)
                let b=try f.retain();defer{b.release()};let before=f.fixture.store.snapshot
                var rejected=false;do{try await f.prepare(b)}catch{rejected=true}
                try require(rejected && f.fixture.store.snapshot==before && f.fixture.manager.openTabs.last?.viewModel === tab.viewModel,"ID alone never proves retained Reader")
            }
            await test("binding_release_during_original_annotation_callback_stops_book") {
                let f=try hidden(),tab=try selected(f)
                tab.viewModel.annotationEvent=91
                let b=try f.retain();defer{b.release()};try await f.prepare(b)
                watch({_ = tab.viewModel.annotationEvent}){b.release()}
                try require(refuses{try f.apply(b)} && f.fixture.manager.selectedBook==nil && f.fixture.manager.persistCalls.isEmpty,"released owned source cannot fall through ordinary publisher")
            }
            await test("reentrant_equal_book_setter_is_not_second_owned_publication") {
                let f=try hidden(),b=try f.retain();defer{b.release()};try await f.prepare(b)
                let tab=try selected(f),revision=f.fixture.manager.selectedBookPresentationRevision!
                watch({f.fixture.manager.selectedBook}){f.fixture.manager.selectedBook=tab.book}
                try require(refuses{try f.apply(b)} && !b.isApplied && f.fixture.manager.selectedBookPresentationRevision==revision+2 && f.fixture.manager.persistCalls.isEmpty,"actual nested setter remains visible but invalidates both permits")
            }
            await test("release_after_book_didSet_preserves_partial_effect_and_blocks_persistence") {
                let f=try hidden(),tab=try selected(f),b=try f.retain();defer{b.release()};try await f.prepare(b)
                watch({f.fixture.manager.selectedContentId}){b.release()}
                try require(refuses{try f.apply(b)} && f.fixture.manager.selectedBook === tab.book && !b.isApplied && f.fixture.manager.persistCalls.isEmpty,"actual book effect is not fabricated rollback or successful ACK")
            }
            await test("completed_source_cannot_survive_later_original_book_ABA") {
                let f=try hidden(),b=try f.retain();defer{b.release()};try await f.prepare(b);try f.apply(b)
                let book=f.fixture.manager.selectedBook;f.fixture.manager.selectedBook=nil;f.fixture.manager.selectedBook=book
                try require(refuses{try b.validate()},"completed proof remains source-bound")
            }
            await test("released_helper_does_not_strand_later_genuine_request") {
                let f=try hidden(),b=try f.retain();try await f.prepare(b);try f.apply(b);b.release()
                f.fixture.manager.selectedBook=nil
                let next=try f.retain();defer{next.release()};try await f.prepare(next);try f.apply(next)
                try require(next.isApplied && f.fixture.manager.selectedBook != nil,"new request captures fresh original owner; old permit not rearmed")
            }
        }
        for fault in ["settings_ABA","deadline"] {
            await test("original_annotation_callback_"+fault+"_prevents_later_book") {
                let f=try hidden(),tab=try selected(f)
                tab.viewModel.annotationEvent=91
                let b=try f.retain();defer{b.release()};try await f.prepare(b)
                watch({tab.viewModel.annotationEvent}) {
                    if fault=="settings_ABA" { f.bindings.showSettings.wrappedValue=true;f.bindings.showSettings.wrappedValue=false }
                    else { f.leaseValid=false }
                }
                try require(refuses{try f.apply(b)} && f.fixture.manager.selectedBook==nil && f.fixture.manager.persistCalls.isEmpty,"same source/deadline must be fresh between original assignments")
            }
        }
        await test("same_parent_becomes_hidden_during_original_restore_prevents_book") {
            let f=try ParentFixture(phone:true,sameGroup:true);f.base.fixture.manager.selectedBook=nil
            let tab=try selected(f.base),b=try f.retain();defer{b.release()};_ = try await f.ready(b)
            watch({tab.viewModel.needsScrollRestore}){f.controller.visible=false}
            try require(refuses{try b.apply()} && f.base.fixture.manager.selectedBook==nil,"unchanged mode/root counters cannot replace same actual parent visibility")
        }
    }
    @MainActor static func main() async {
        await execute()
        let failures=rows.filter{!($0["pass"]as!Bool)}.count
        print(String(data:try!JSONSerialization.data(withJSONObject:["rows":rows,"pass":rows.count-failures,"fail":failures,
            "scope":"Actual complete Group policy/Adapter/Binding, original Manager presentation and setter bodies, Store/persistence, original Viewer/window sources and coordinator. Explicit native geometry, Reader/backend and session-persistence shells. No app SDK/native execution."],options:[.sortedKeys]),encoding:.utf8)!)
        if failures != 0 { exit(1) }
    }
}
