import Foundation
import Observation
import OtzariaActionCore
import OtzariaUIRouting

enum GroupBindingControls {
    @MainActor static func run() async -> (Int, Int) {
        var passed = 0, failed = 0
        func require(_ value: Bool, _ reason: String) throws { if !value { throw ControlFailure.expected(reason) } }
        func refuses(_ body: () throws -> Void) -> Bool { do { try body(); return false } catch { return true } }
        func test(_ name: String, _ body: @MainActor () async throws -> Void) async {
            do { try await body(); passed += 1; print("PASS binding: " + name) }
            catch { failed += 1; print("FAIL binding: \(name): \(error)") }
        }
        await test("warm group retains one original stage through original terminal and actual model projection") {
            let f = try GroupBindingFixture(); let bound = try f.retain(); defer { bound.release() }
            let old = f.fixture.manager.openTabs
            try require(try bound.selectionSurface(from: f.originalProjection()) == nil, "no observation before apply")
            try await f.prepare(bound); try f.apply(bound)
            try require(bound.isApplied && f.fixture.manager.openTabs[0].viewModel === f.fixture.targetTabs[0].viewModel,
                        "same original cached Reader")
            let result = try bound.selectionSurface(from: f.originalProjection())
            try require(result?.destination == MaktabahNativeWorkspaceSelectionBinding.destination
                && result?.state.workspaceID?.rawValue == f.fixture.g2.uuidString
                && result?.presentation.tabID?.rawValue == f.fixture.targetTabs[0].id.uuidString,
                "source-only projection from actual changed objects; no native ACK")
            try require(old[0].viewModel.saveCalls == 0 && f.originalEffects == 1, "single canonical terminal")
        }
        await test("profile selects original first group and retains original target profile") {
            let f = try GroupBindingFixture(profile: true); let bound = try f.retain(profile: true); defer { bound.release() }
            try await f.prepare(bound); try f.apply(bound)
            try require(f.fixture.workspace.selection?.profileID == f.fixture.p2
                && f.fixture.workspace.selection?.groupID == f.fixture.g2, "actual Store owner changed together")
            try require(try bound.selectionSurface(from: f.originalProjection())?.state.profileID?.rawValue == f.fixture.p2.uuidString,
                        "private projection uses observed target profile")
        }
        for phone in [false, true] {
            await test("empty group retains actual \(phone ? "phone Library" : "iPad placeholder") surface only") {
                let f = try GroupBindingFixture(empty: true, phone: phone); let bound = try f.retain(); defer { bound.release() }
                try await f.prepare(bound); try f.apply(bound)
                try require(bound.isEmpty && bound.observedSurface == (phone ? .library : .emptyReader), "actual original empty surface kind")
                let result = try bound.selectionSurface(from: f.originalProjection())
                try require(result?.presentation.tabID == nil && result?.content == nil && f.fixture.manager.openTabs.isEmpty,
                            "no synthetic Reader/tab for empty group")
                let foreign = NativeSurfaceState(destination: UIDestinationID(rawValue: "native.reader")!,
                    presentation: .init(), content: nil, state: result!.state, focus: nil)
                try require(try bound.selectionSurface(from: foreign) == nil, "generic Reader cannot proxy empty target")
            }
        }
        await test("foreign backend group is unavailable in finite actual catalog") {
            let f = try GroupBindingFixture(foreign: true)
            try require(try !f.catalog().contains { $0.groupID == f.fixture.g2 }, "no silent backend switch promise")
        }
        await test("legacy cold unqualified documents remain unavailable") {
            let f = try GroupBindingFixture(warm: false, qualified: false)
            try require(try !f.catalog().contains { $0.groupID == f.fixture.g2 }, "no invented cold content token")
        }
        await test("qualified cold original load remains pending until actual original Reader state is loaded") {
            let f = try GroupBindingFixture(warm: false); let bound = try f.retain(); defer { bound.release() }
            try await f.prepare(bound); try f.apply(bound)
            try require(try bound.selectionSurface(from: f.originalProjection()) == nil, "model request is not a loaded surface")
            let selected = f.fixture.manager.openTabs.first { $0.id == f.fixture.manager.activeTabId }!
            selected.viewModel.state = .loaded; selected.viewModel.contentText = "boundary original rendered model output"
            try require(try bound.selectionSurface(from: f.originalProjection()) != nil,
                        "source projection permits original completed token; native witness remains independent and unrun")
        }
        await test("phone same active tab hidden behind Library is unavailable") {
            let f = try GroupBindingFixture(phone: true, sameGroup: true)
            f.fixture.manager.selectedBook = nil
            try require(try !f.catalog().contains { $0.groupID == f.fixture.g1 }, "original no-op selectTab is not a fake parent opener")
        }
        await test("foreign global root is refused without selection or mode writes") {
            let f = try GroupBindingFixture(); f.bindings.selectedTab.wrappedValue = .search
            f.fixture.manager.currentMode = .search
            let before = f.fixture.store.snapshot
            try require(refuses { _ = try f.retain() } && f.fixture.store.snapshot == before, "current Viewer slice only")
        }
        await test("original Settings true-false publication before reservation revokes") {
            let f = try GroupBindingFixture(); let bound = try f.retain(); defer { bound.release() }
            f.bindings.showSettings.wrappedValue = true; f.bindings.showSettings.wrappedValue = false
            try require(refuses { try bound.reserve() }, "same final Settings flag cannot revive captured request")
        }
        await test("original root tab A-B-A before delayed mode publication revokes") {
            let f = try GroupBindingFixture(); let bound = try f.retain(); defer { bound.release() }
            f.bindings.selectedTab.wrappedValue = .history; f.bindings.selectedTab.wrappedValue = .viewer
            try require(f.fixture.manager.currentMode == .viewer && refuses { try bound.reserve() }, "actual original root counter closes coalescing gap")
        }
        await test("actual equal currentMode publication before reserve revokes") {
            let f = try GroupBindingFixture(); let bound = try f.retain(); defer { bound.release() }
            f.fixture.manager.currentMode = .viewer
            try require(refuses { try bound.reserve() }, "ignored counter is compared directly plus original mode observed")
        }
        await test("original selectedBook A-B-A before reserve revokes") {
            let f = try GroupBindingFixture(); let bound = try f.retain(); defer { bound.release() }
            let book = f.fixture.manager.selectedBook; f.fixture.manager.selectedBook = nil; f.fixture.manager.selectedBook = book
            try require(refuses { try bound.reserve() }, "pre-reservation setter history retained")
        }
        await test("original overview A-B-A before reserve revokes") {
            let f = try GroupBindingFixture(); let bound = try f.retain(); defer { bound.release() }
            f.fixture.manager.showingTabsList = true; f.fixture.manager.showingTabsList = false
            try require(refuses { try bound.reserve() }, "adapter lifetime publication counter retained before await")
        }
        await test("original backend equal publication before reserve revokes") {
            let f = try GroupBindingFixture(); let bound = try f.retain(); defer { bound.release() }
            BackendCoordinator.shared.pendingBackendID = nil
            try require(refuses { try bound.reserve() }, "same backend observer exists before reservation")
        }
        await test("original workspace reference A-B-A before reserve revokes") {
            let f = try GroupBindingFixture(); let bound = try f.retain(); defer { bound.release() }
            try f.owner.replace(with: nil); try f.owner.replace(with: f.fixture.workspace)
            try require(refuses { try bound.reserve() }, "actual original observable owner read is one-shot")
        }
        await test("original inactive Store A-B-A before reserve revokes") {
            let f = try GroupBindingFixture(); let bound = try f.retain(); defer { bound.release() }
            let index = f.fixture.store.snapshot!.groups.firstIndex { $0.id == f.fixture.g2 }!
            let name = f.fixture.store.snapshot!.groups[index].name
            try f.fixture.store.transaction { $0.groups[index].name = "Changed" }
            try f.fixture.store.transaction { $0.groups[index].name = name }
            try require(refuses { try bound.reserve() }, "full original Store publication revision retained")
        }
        await test("warm original Reader state A-B-A during async stage revokes") {
            let f = try GroupBindingFixture(); let bound = try f.retain(); defer { bound.release() }
            ChavrusaTextTargetBackendBookResolver.shared.duringCatalog = {
                f.fixture.targetTabs[0].viewModel.state = .loading
                f.fixture.targetTabs[0].viewModel.state = .loaded
            }
            var refused = false; do { try await f.prepare(bound) } catch { refused = true }
            try require(refused && f.fixture.workspace.group?.id == f.fixture.g1, "same Reader state cannot renew captured source")
        }
        await test("newly hydrated original modal A-B-A before apply revokes") {
            let f = try GroupBindingFixture(warm: false); let bound = try f.retain(); defer { bound.release() }
            try await f.prepare(bound)
            let reader = f.fixture.workspace.fixtureGroupReservation()!.prepared.staged[0].viewModel
            reader.isPopoverPresented = true; reader.isPopoverPresented = false
            try require(refuses { try f.apply(bound) }, "new original object gets one observation without rearming old source")
        }
        await test("expired original preparation lifetime produces no Store publication") {
            let f = try GroupBindingFixture(); let bound = try f.retain(); defer { bound.release() }
            let before = f.fixture.store.snapshot
            ChavrusaTextTargetBackendBookResolver.shared.duringCatalog = { f.leaseValid = false }
            var refused = false; do { try await f.prepare(bound) } catch { refused = true }
            try require(refused && f.fixture.store.snapshot == before, "same deadline only; no new grant")
        }
        await test("expired canonical lifetime refuses terminal after complete original staging") {
            let f = try GroupBindingFixture(); let bound = try f.retain(); defer { bound.release() }
            try await f.prepare(bound); let before = f.fixture.store.snapshot; f.leaseValid = false
            try require(refuses { try f.apply(bound) } && f.fixture.store.snapshot == before, "staged objects alone are not effect permission")
        }
        await test("one canonical apply cannot replay Store or native effects") {
            let f = try GroupBindingFixture(); let bound = try f.retain(); defer { bound.release() }
            try await f.prepare(bound); try f.apply(bound); let before = f.fixture.store.snapshot
            try require(refuses { try bound.apply() } && f.fixture.store.snapshot == before, "single-use complete original terminal")
        }
        await test("wrong observed group cannot become the private selected surface") {
            let f = try GroupBindingFixture(); let bound = try f.retain(); defer { bound.release() }
            try await f.prepare(bound); try f.apply(bound); let actual = f.originalProjection()
            let wrong = NativeSurfaceState(destination: actual.destination, presentation: actual.presentation,
                content: actual.content, state: .init(workspaceID: UIStableID(rawValue: UUID().uuidString),
                                                    profileID: actual.state.profileID), focus: nil)
            try require(try bound.selectionSurface(from: wrong) == nil, "retained target is not copied into foreign evidence")
        }
        await test("original viewport checkpoint remains allowed under exact committed identities") {
            let f = try GroupBindingFixture(); let bound = try f.retain(); defer { bound.release() }
            try await f.prepare(bound); try f.apply(bound)
            f.fixture.manager.openTabs[0].viewModel.readerState.scrollPosition = CGPoint(x: 0, y: 1201)
            f.fixture.workspace.synchronize(f.fixture.manager)
            try bound.validate()
            try require(f.fixture.workspace.group?.tabs[0].session.scrollPosition?.y == 1201, "actual original checkpoint persists")
        }
        return (passed, failed)
    }
}
