import Foundation
import Glibc

private struct Failure: Error { let message: String }
@MainActor private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw Failure(message: message) }
}
@MainActor private func refuses(_ body: () throws -> Void) throws {
    var refused = false
    do { try body() } catch { refused = true }
    try require(refused, "Expected original source/lifetime refusal")
}
@MainActor private final class Harness {
    let manager: iOSNavigationManager
    let workspace: StudyWorkspaceNavigationAdapter
    let workspaceSource: MaktabahNativeWorkspaceProjectionSource
    let window = UIWindow()
    let request = UUID()
    let scene = UIStableID(rawValue: "original-scene")!
    let surface = UUID()
    var tab: iOSTab
    var settings = false
    var foreground = true
    var lifetime = true
    var modePublications = 0
    var onSelect: (() -> Void)?
    var field: UISearchTextField?
    lazy var bindings = MaktabahNativeSceneBindings(manager: manager,
        selectedTab: Binding(get: { [unowned self] in tab }, set: { [unowned self] in tab = $0; onSelect?() }),
        showSettings: Binding(get: { [unowned self] in settings }, set: { [unowned self] in settings = $0 }))
    lazy var entry = MaktabahNativeSearchEntryBinding(sceneID: scene, bindings: bindings, workspaceSource: workspaceSource,
        commonReady: { [unowned self] in foreground && !settings },
        windowReady: { [unowned self] in
            foreground && window.isKeyWindow && window.rootViewController?.presentedViewController == nil
                && window.rootViewController?.transitionCoordinator == nil
        }, parentVisible: { [unowned self] in tab == .search && manager.currentMode == .search && !settings })

    init(pad: Bool = false, tab: iOSTab = .viewer, reader: Bool = true,
         modeSeed: UInt64? = 0, bookSeed: UInt64? = 0) {
        MaktabahApp.isIpad = pad
        BackendCoordinator.shared.isTransitioning = false
        BackendCoordinator.shared.activeBackendID = .otzaria
        DonationManager.shared.showDonationSheet = false
        MaktabahNativeRootDestination.supported = true
        manager = iOSNavigationManager(modeSeed: modeSeed, bookSeed: bookSeed)
        self.tab = tab
        workspace = StudyWorkspaceNavigationAdapter(manager)
        workspaceSource = MaktabahNativeWorkspaceProjectionSource(workspace)
        if tab != .viewer { manager.currentMode = tab.appMode }
        let book = BooksData(), vm = ReaderViewModel(), id = UUID()
        vm.currentBook = book
        manager.openTabs = [.init(id: id, book: book, viewModel: vm)]
        manager.activeTabId = id
        if reader { manager.selectedBook = book }
        window.bounds = CGRect(x: 0, y: 0, width: 800, height: 900)
        window.rootViewController?.view.bounds = window.bounds
        window.rootViewController?.view.window = window
        window.rootViewController?.view.superview = window
    }
    func retain() throws {
        try entry.retainSource(requestID: request)
        try entry.owner.retainSource(requestID: request, anchor: MaktabahNativeSearchEntryBinding.anchor)
    }
    func begin() throws {
        let validate: @MainActor () throws -> Void = { [unowned self] in
            guard lifetime, foreground else { throw Failure(message: "original grant expired or foreground lost") }
        }
        try entry.begin(requestID: request, validate: validate)
        try entry.owner.begin(requestID: request, anchor: MaktabahNativeSearchEntryBinding.anchor, validate: validate)
    }
    func apply() throws {
        try entry.owner.apply(requestID: request)
        try entry.apply(requestID: request)
        entry.renderOriginalFieldIfReady()
    }
    func publishMode() {
        modePublications += 1
        manager.currentMode = tab.appMode
        entry.renderOriginalFieldIfReady()
    }
    @discardableResult func mount() -> UISearchTextField {
        let f = UISearchTextField()
        f.window = window; f.superview = window.rootViewController?.view
        f.text = manager.unifiedSearchSession.query
        field = f
        entry.observeOriginalPresentation(owner: surface)
        entry.attachOriginalField(f)
        entry.originalFieldDidLayout(f)
        return f
    }
    func prepareCold() throws { try retain(); try begin(); try apply() }
    func finish() throws {
        try require(entry.owner.actualFocus(in: scene)?.anchor == MaktabahNativeSearchEntryBinding.anchor, "No actual fixed-component focus")
        entry.owner.finish(requestID: request, completed: true)
        entry.finish(requestID: request, completed: true)
        entry.owner.releaseSource(requestID: request)
        entry.releaseSource(requestID: request)
    }
    func noFocus() throws { try require(entry.owner.actualFocus(in: scene) == nil, "Unproven focus escaped source gate") }
}

@main private struct Controls {
    @MainActor static func main() {
        var passed = 0, failed = 0
        func test(_ name: String, _ body: () throws -> Void) {
            do { try body(); passed += 1; print("PASS " + name) }
            catch { failed += 1; print("FAIL \(name): \(error)") }
        }
        test("cold_phone_retains_one_parent_publication_and_original_field") {
            let h = Harness(), beforeBook = h.manager.selectedBookPresentationRevision
            try h.prepareCold()
            try require(h.tab == .search && h.manager.currentMode == .viewer, "Must await original TabView publisher")
            try require(h.manager.selectedBook == nil && h.manager.selectedBookPresentationRevision == beforeBook.map { $0 + 1 }, "Exactly one original phone pop")
            let f = h.mount(); try require(f.focusCalls == 0, "No focus before original mode")
            h.publishMode(); try h.finish()
            try require(f.focusCalls == 1 && h.modePublications == 1, "One retained focus and publisher")
        }
        test("cold_ipad_preserves_original_selected_book") {
            let h = Harness(pad: true), original = h.manager.selectedBook, before = h.manager.selectedBookPresentationRevision
            try h.prepareCold(); h.publishMode(); h.mount(); try h.finish()
            try require(h.manager.selectedBook === original && h.manager.selectedBookPresentationRevision == before, "iPad book owner changed")
        }
        test("warm_visible_field_uses_zero_mode_or_book_publications") {
            let h = Harness(tab: .search, reader: false), f = h.mount()
            let mode = h.manager.nativeModePresentationRevision, book = h.manager.selectedBookPresentationRevision
            try h.prepareCold(); try h.finish()
            try require(f.focusCalls == 1 && h.manager.nativeModePresentationRevision == mode && h.manager.selectedBookPresentationRevision == book, "Redundant parent write")
        }
        test("private_query_scope_and_filters_survive_parent_then_focus") {
            let h = Harness(tab: .history, reader: false)
            h.manager.unifiedSearchSession.query = "  בראשית בדיקה  "
            h.manager.unifiedSearchSession.scope = .advanced
            h.manager.unifiedSearchSession.selectedBookIds = [17]
            h.manager.searchViewModel.selectedBookIds = [17]
            let before = h.manager.unifiedSearchSession.requestConfiguration
            try h.prepareCold(); h.publishMode(); let f = h.mount(); try h.finish()
            try require(f.text == "  בראשית בדיקה  " && h.manager.unifiedSearchSession.requestConfiguration == before, "Input reset")
            try require(h.manager.unifiedSearchSession.submissionRevision == 0 && h.manager.unifiedSearchSession.paginationRevision == 0, "Focus submitted search")
        }
        test("field_mount_before_canonical_apply_revokes") {
            let h = Harness(); try h.retain(); h.mount(); try refuses { try h.begin() }; try h.noFocus()
        }
        test("query_ABA_before_begin_revokes") {
            let h = Harness(); try h.retain(); h.manager.unifiedSearchSession.query = "changed"; h.manager.unifiedSearchSession.query = ""
            try refuses { try h.begin() }
        }
        test("scope_ABA_before_begin_revokes") {
            let h = Harness(); try h.retain(); h.manager.unifiedSearchSession.scope = .advanced; h.manager.unifiedSearchSession.scope = .exact
            try refuses { try h.begin() }
        }
        test("private_filter_ABA_before_begin_revokes") {
            let h = Harness(); try h.retain(); h.manager.searchViewModel.filterText = "changed"; h.manager.searchViewModel.filterText = ""
            try refuses { try h.begin() }
        }
        test("selected_books_ABA_before_begin_revokes") {
            let h = Harness(); try h.retain(); h.manager.unifiedSearchSession.selectedBookIds = [1]; h.manager.unifiedSearchSession.selectedBookIds = []
            try refuses { try h.begin() }
        }
        test("search_model_identity_ABA_revokes") {
            let h = Harness(), original = h.manager.searchViewModel
            try h.retain(); h.manager.searchViewModel = SearchViewModel(); h.manager.searchViewModel = original
            try refuses { try h.begin() }
        }
        test("workspace_identity_ABA_revokes") {
            let h = Harness(); try h.retain(); h.workspaceSource.current = StudyWorkspaceNavigationAdapter(h.manager); h.workspaceSource.current = h.workspace
            try refuses { try h.begin() }
        }
        test("workspace_mapping_publication_ABA_revokes") {
            let h = Harness(); try h.retain(); h.workspace.mappingOwnershipSource.event = 2; h.workspace.mappingOwnershipSource.event = 1
            try refuses { try h.begin() }
        }
        test("aborted_backend_publication_revokes_same_generation") {
            let h = Harness(); try h.retain(); BackendCoordinator.shared.objectWillChange.send(())
            try refuses { try h.begin() }
        }
        test("original_Combine_match_mode_ABA_revokes") {
            let h = Harness(); try h.retain(); h.manager.unifiedSearchSession.zayitSession.model.matchMode = "exact"
            h.manager.unifiedSearchSession.zayitSession.model.matchMode = "flexible"
            try refuses { try h.begin() }
        }
        test("equal_original_mode_publication_before_begin_revokes") {
            let h = Harness(); try h.retain(); h.manager.currentMode = .viewer
            try refuses { try h.begin() }
        }
        test("mode_ABA_before_begin_revokes") {
            let h = Harness(); try h.retain(); h.manager.currentMode = .history; h.manager.currentMode = .viewer
            try refuses { try h.begin() }
        }
        test("original_selection_ABA_before_delayed_mode_publication_revokes") {
            let h = Harness(); try h.retain()
            h.bindings.selectedTab.wrappedValue = .history
            h.bindings.selectedTab.wrappedValue = .viewer
            try require(h.modePublications == 0, "The source boundary must not invent a delayed TabView callback")
            try refuses { try h.begin() }
        }
        test("original_selection_ABA_after_apply_before_mode_publication_revokes") {
            let h = Harness(); try h.prepareCold()
            h.bindings.selectedTab.wrappedValue = .history
            h.bindings.selectedTab.wrappedValue = .search
            h.publishMode(); let field = h.mount()
            try h.noFocus(); try require(field.focusCalls == 0, "Competing original selection reused admission")
        }
        test("original_Settings_binding_ABA_before_mount_revokes") {
            let h = Harness(); try h.retain()
            h.bindings.showSettings.wrappedValue = true
            h.bindings.showSettings.wrappedValue = false
            try refuses { try h.begin() }
        }
        test("mode_counter_exhaustion_is_permanent") {
            let h = Harness(modeSeed: .max); try refuses { try h.retain() }
            h.manager.currentMode = .viewer
            try require(h.manager.nativeModePresentationRevision == nil, "Overflow recycled")
            h.manager.currentMode = .search
            try require(h.manager.nativeModePresentationRevision == nil, "Overflow reset")
        }
        test("one_expected_mode_then_equal_extra_write_revokes") {
            let h = Harness(); try h.prepareCold(); h.publishMode(); h.manager.currentMode = .search
            let f = h.mount(); try h.noFocus(); try require(f.focusCalls == 0, "Extra publisher accepted")
        }
        test("already_search_equal_mode_write_is_not_owned") {
            let h = Harness(tab: .search, reader: false); try h.retain(); h.manager.currentMode = .search
            try refuses { try h.begin() }
        }
        test("extra_phone_book_setter_during_parent_apply_revokes") {
            let h = Harness(); try h.retain(); try h.begin()
            h.onSelect = { h.manager.selectedBook = nil }
            try refuses { try h.apply() }; try h.noFocus()
        }
        test("existing_Settings_is_not_dismissed_or_bypassed") {
            let h = Harness(); h.settings = true
            try refuses { try h.retain() }; try require(h.settings && h.tab == .viewer, "Settings changed")
        }
        test("Settings_opened_after_admission_blocks_original_setter") {
            let h = Harness(); try h.retain(); try h.begin(); h.settings = true
            try refuses { try h.apply() }; try require(h.settings && h.tab == .viewer, "Settings dismissed")
        }
        test("foreign_modal_does_not_produce_focus") {
            let h = Harness(); try h.prepareCold(); h.publishMode(); h.window.rootViewController?.presentedViewController = UIViewController()
            let f = h.mount(); try h.noFocus(); try require(f.focusCalls == 0, "Focused behind modal")
        }
        test("original_advanced_options_sheet_requested_before_mount_is_unavailable") {
            let h = Harness(); h.manager.unifiedSearchSession.showsAdvancedOptions = true
            try refuses { try h.retain() }
            try require(h.manager.unifiedSearchSession.showsAdvancedOptions && h.tab == .viewer, "Original sheet request changed")
        }
        test("original_advanced_options_sheet_ABA_revokes") {
            let h = Harness(); try h.retain()
            h.manager.unifiedSearchSession.showsAdvancedOptions = true
            h.manager.unifiedSearchSession.showsAdvancedOptions = false
            try refuses { try h.begin() }
        }
        test("deadline_expiry_before_actual_layout_revokes") {
            let h = Harness(); try h.prepareCold(); h.publishMode(); h.lifetime = false
            let f = h.mount(); try h.noFocus(); try require(f.focusCalls == 0, "Borrowed expired lifetime")
        }
        test("foreground_loss_before_actual_layout_revokes") {
            let h = Harness(); try h.prepareCold(); h.publishMode(); h.foreground = false
            let f = h.mount(); try h.noFocus(); try require(f.focusCalls == 0, "Focused background scene")
        }
        test("replacement_original_field_cannot_inherit_request") {
            let h = Harness(tab: .search, reader: false); h.mount(); try h.retain(); try h.begin()
            let f = h.mount(); try refuses { try h.apply() }; try h.noFocus(); try require(f.focusCalls == 0, "Replacement field inherited")
        }
        test("same_UIView_window_detach_reattach_revokes") {
            let h = Harness(tab: .search, reader: false), f = h.mount(); try h.retain(); try h.begin()
            f.window = nil; h.entry.originalFieldStateDidChange(f)
            f.window = h.window; h.entry.originalFieldStateDidChange(f)
            try refuses { try h.apply() }; try h.noFocus()
        }
        test("release_before_finish_revokes_pending_render") {
            let h = Harness(); try h.prepareCold(); h.entry.owner.releaseSource(requestID: h.request); h.entry.releaseSource(requestID: h.request)
            h.publishMode(); let f = h.mount(); try h.noFocus(); try require(f.focusCalls == 0, "Released source resumed")
        }
        test("original_local_overlay_ABA_retires_before_value_change") {
            let h = Harness(tab: .search, reader: false); h.mount(); try h.retain(); try h.begin()
            h.entry.originalPresentationWillChange(owner: h.surface)
            try refuses { try h.apply() }; try h.noFocus()
        }
        test("replacement_original_view_owner_revokes") {
            let h = Harness(tab: .search, reader: false); h.mount(); try h.retain(); try h.begin()
            h.entry.observeOriginalPresentation(owner: UUID())
            try refuses { try h.apply() }; try h.noFocus()
        }
        test("wrong_scene_field_never_acknowledges") {
            let h = Harness(); try h.prepareCold(); h.publishMode(); h.window.windowScene?.session.persistentIdentifier = "foreign-scene"
            let f = h.mount(); try h.noFocus(); try require(f.focusCalls == 0, "Foreign scene focused")
        }
        test("clipped_original_ancestor_never_acknowledges") {
            let h = Harness(); try h.prepareCold(); h.publishMode()
            h.window.rootViewController?.view.clipsToBounds = true
            h.window.rootViewController?.view.bounds.size.width = 100
            let f = h.mount(); try h.noFocus(); try require(f.focusCalls == 0, "Clipped input focused")
        }
        test("translucent_original_ancestor_never_acknowledges") {
            let h = Harness(); try h.prepareCold(); h.publishMode(); h.window.rootViewController?.view.alpha = 0.4
            let f = h.mount(); try h.noFocus(); try require(f.focusCalls == 0, "Covered input focused")
        }
        test("reentrant_retirement_during_become_first_responder_revokes") {
            let h = Harness(tab: .search, reader: false), f = h.mount(); try h.retain(); try h.begin()
            f.beforeFocus = { h.entry.retire() }
            try h.apply(); try h.noFocus()
        }
        test("reentrant_query_mutation_during_focus_revokes") {
            let h = Harness(tab: .search, reader: false), f = h.mount(); try h.retain(); try h.begin()
            f.beforeFocus = { h.manager.unifiedSearchSession.query = "changed" }
            try h.apply(); try h.noFocus()
        }
        test("reentrant_deadline_loss_during_focus_revokes") {
            let h = Harness(tab: .search, reader: false), f = h.mount(); try h.retain(); try h.begin()
            f.beforeFocus = { h.lifetime = false }
            try h.apply(); try h.noFocus()
        }
        test("completed_original_proof_does_not_survive_query_ABA") {
            let h = Harness(tab: .search, reader: false); h.mount(); try h.prepareCold(); try h.finish()
            h.manager.unifiedSearchSession.query = "changed"; h.manager.unifiedSearchSession.query = ""
            try h.noFocus()
        }
        test("completed_original_proof_does_not_survive_local_overlay") {
            let h = Harness(tab: .search, reader: false); h.mount(); try h.prepareCold(); try h.finish()
            h.entry.originalPresentationWillChange(owner: h.surface); try h.noFocus()
        }
        test("legacy_focus_token_is_not_silently_aliased") {
            let h = Harness(); try h.entry.retainSource(requestID: h.request)
            try refuses { try h.entry.owner.retainSource(requestID: h.request, anchor: UIDestinationID(rawValue: "native.search.query")!) }
            try h.noFocus()
        }
        print("SUMMARY \(passed) PASS / \(failed) FAIL; source/domain controls only; native=0")
        exit(failed == 0 ? 0 : 1)
    }
}
