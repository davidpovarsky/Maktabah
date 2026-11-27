import Foundation

@main struct ColdContentControls {
    @MainActor static var rows: [[String: String]] = []
    @MainActor static func check(_ name: String, _ condition: Bool) {
        rows.append(["name": name, "pass": condition ? "true" : "false"])
    }
    static func line(_ index: Int, work: String = "1") -> TextLocator { .init(backend: .otzaria, workKey: work, position: .legacyLine(index)) }
    static func destination(_ index: Int) -> LibraryReaderDestination { .init(sectionLocator: line(index), focusLocator: nil) }
    @MainActor static func fresh() async -> ReaderViewModel {
        BackendCoordinator.shared.drain(); QualifiedLocatorStore.shared.resume([])
        for _ in 0..<10 { await Task.yield() }
        BackendCoordinator.shared.activeBackendID = .otzaria; BackendCoordinator.shared.generation = 0
        BackendCoordinator.shared.holdNavigation = false; BackendCoordinator.shared.navReads = 0
        BackendCoordinator.shared.navigation = [.init(locator: line(1), title: "Original", index: 0)]
        BackendCoordinator.shared.sectionReads = []
        QualifiedLocatorStore.shared.hold = false; QualifiedLocatorStore.shared.reads = 0
        QualifiedLocatorStore.shared.result = []
        LegacyIdentityRegistry.shared.locators = [:]; BookPageCache.shared.writes = []
        return ReaderViewModel(BooksData(locator: line(0)))
    }
    @MainActor static func until(_ predicate: () -> Bool) async -> Bool {
        for _ in 0..<5000 { if predicate() { return true }; await Task.yield() }
        return predicate()
    }
    @MainActor static func settle() async { for _ in 0..<60 { await Task.yield() } }

    @MainActor static func originalFailureCases() async {
        var reader = await fresh()
        QualifiedLocatorStore.shared.hold = true
        reader.loadInitialContent()
        check("history_wait_reached", await until { !QualifiedLocatorStore.shared.continuations.isEmpty })
        reader.loadBackendContent(destination(2))
        let newerToken = reader.contentLoadCoordinator.currentRequestToken()
        QualifiedLocatorStore.shared.resume([.init(locator: line(1))]); await settle()
        check("cancelled_history_cannot_replace_destination_or_token", reader.currentDestination?.sectionLocator == line(2)
            && reader.contentLoadCoordinator.currentRequestToken() == newerToken)

        reader = await fresh(); BackendCoordinator.shared.holdNavigation = true
        reader.loadInitialContent()
        check("navigation_wait_reached", await until { !BackendCoordinator.shared.navContinuations.isEmpty })
        reader.loadBackendContent(destination(2)); let navigationToken = reader.contentLoadCoordinator.currentRequestToken()
        BackendCoordinator.shared.resumeNavigation([.init(locator: line(1), title: "old", index: 0)]); await settle()
        check("cancelled_navigation_cannot_clear_new_task_or_publish_old_items", reader.currentDestination?.sectionLocator == line(2)
            && reader.contentLoadCoordinator.currentRequestToken() == navigationToken
            && reader.navigationItems.isEmpty && reader.backendLoadTask != nil)

        reader = await fresh()
        let reentrantReader = reader
        reader.tocViewModel.callback = { reentrantReader.loadBackendContent(destination(2)) }
        reader.loadBackendContent(destination(1)); await settle()
        check("reentrant_TOC_cannot_resume_outer_handoff", reader.currentDestination?.sectionLocator == line(2)
            && reader.contentLoadCoordinator.currentRequestToken()?.sectionLocator == line(2))

        reader = await fresh(); let publishingReader = reader
        reader.loadBackendContent(destination(1))
        check("section_wait_reached", await until { BackendCoordinator.shared.sectionReads.contains(line(1)) })
        reader.contentHook = { publishingReader.loadBackendContent(destination(2)) }
        BackendCoordinator.shared.resumeSection(line(1)); await settle()
        check("original_content_callback_keeps_new_loading_state_and_task", reader.currentDestination?.sectionLocator == line(2)
            && reader.state == .loading && reader.backendLoadTask != nil)
    }

    #if !BASELINE
    @MainActor static func requestCases() async {
        var reader = await fresh()
        let stable = reader.contentLoadCoordinator.initialContentSourceObservation()
        check("no_pending_loaded_owner_has_current_observation", stable?.isCurrent == true && stable?.pendingRequestID == nil)
        reader.contentText = "already rendered original fields"
        let oldFields = (reader.contentText, reader.state, reader.currentDestination)
        let first = reader.makeInitialContentRequest(initialContentId: 1)!
        check("original_start_retires_old_observation_before_callback", stable?.isCurrent == false && first.state?.phase == .reserved)
        check("pre_token_start_does_not_need_a_render_publication", reader.contentText == oldFields.0
            && reader.state == oldFields.1 && reader.currentDestination == oldFields.2)
        let alreadyPending = reader.contentLoadCoordinator.initialContentSourceObservation()!
        check("already_pending_capture_is_current_but_not_idle", alreadyPending.isCurrent
            && alreadyPending.pendingRequestID == first.id && alreadyPending.pendingRequestID != nil)
        reader.contentText = ""
        let beforeSecond = reader.contentLoadCoordinator.initialContentSourceObservation()!
        let second = reader.makeInitialContentRequest(initialContentId: 1)!
        check("equal_restart_irrevocably_retires_first", !first.isCurrent && !beforeSecond.isCurrent && second.isCurrent)
        reader.loadInitialContent(initialContentId: 1, continuing: first)
        check("retired_handle_cannot_claim_or_mutate", second.state?.phase == .reserved && reader.currentDestination == nil)
        reader.loadInitialContent(initialContentId: 1, continuing: second)
        reader.loadInitialContent(initialContentId: 1, continuing: second)
        await settle()
        check("same_handle_claim_and_token_are_single_use", BackendCoordinator.shared.sectionReads == [line(1)] && second.issuedToken?.generation == 1)
        let token = second.issuedToken
        check("second_issuer_handoff_refused", reader.contentLoadCoordinator.beginRequest(continuing: second,
            backend: .otzaria, workKey: "1", sectionLocator: line(1)) == nil && second.issuedToken == token)
        BackendCoordinator.shared.resumeSection(line(1)); await settle()
        let complete = reader.contentLoadCoordinator.initialContentSourceObservation()
        check("real_completion_keeps_token_and_stable_no_pending_observation", second.state?.phase == .completed
            && reader.state == .loaded && complete?.pendingRequestID == nil && complete?.isCurrent == true)

        let pending = reader.makeInitialContentRequest(initialContentId: 2)!
        let beforeDirect = reader.contentLoadCoordinator.initialContentSourceObservation()!
        _ = reader.contentLoadCoordinator.beginRequest(backend: .otzaria, workKey: "1", sectionLocator: line(3))
        check("original_direct_token_issuer_retires_pre_token_source", !pending.isCurrent && !beforeDirect.isCurrent)
        let beforeInvalidate = reader.contentLoadCoordinator.initialContentSourceObservation()!
        reader.contentLoadCoordinator.invalidate()
        check("original_invalidate_retires_stable_source", !beforeInvalidate.isCurrent)

        reader = await fresh(); QualifiedLocatorStore.shared.hold = true
        let request = reader.makeInitialContentRequest()!
        reader.loadInitialContent(continuing: request)
        _ = await until { !QualifiedLocatorStore.shared.continuations.isEmpty }
        let originalBook = reader.currentBook!
        reader.currentBook = BooksData(2, locator: line(0, work: "2")); reader.currentBook = originalBook
        QualifiedLocatorStore.shared.resume([.init(locator: line(1))]); await settle()
        check("actual_Observable_book_ABA_retires_pending_source", !request.isCurrent && BackendCoordinator.shared.sectionReads.isEmpty)

        reader = await fresh(); QualifiedLocatorStore.shared.hold = true
        reader.loadInitialContent(); _ = await until { !QualifiedLocatorStore.shared.continuations.isEmpty }
        BackendCoordinator.shared.activeBackendID = .sefaria; BackendCoordinator.shared.generation += 1
        BackendCoordinator.shared.activeBackendID = .otzaria; BackendCoordinator.shared.generation += 1
        QualifiedLocatorStore.shared.resume([.init(locator: line(1))]); await settle()
        check("backend_generation_ABA_blocks_old_resume", BackendCoordinator.shared.sectionReads.isEmpty && reader.currentDestination == nil)

        reader = await fresh()
        LegacyIdentityRegistry.shared.locators[9] = line(1, work: "foreign")
        reader.loadInitialContent(initialContentId: 9); await settle()
        check("foreign_registered_ID_cannot_change_original_work", reader.currentDestination == nil && BackendCoordinator.shared.sectionReads.isEmpty)

        reader = await fresh(); reader.loadInitialContent(initialContentId: 0); await settle()
        check("original_explicit_line_zero_is_not_first_heading", BackendCoordinator.shared.sectionReads == [line(0)]
            && QualifiedLocatorStore.shared.reads == 0 && BackendCoordinator.shared.navReads == 0)

        reader = await fresh(); let ordinary = reader.makeInitialContentRequest(initialContentId: 1)!
        check("ordinary_UI_has_no_native_deadline", ordinary.deadlineUptimeNanoseconds == nil)
        let expired = reader.makeInitialContentRequest(initialContentId: 1, deadlineUptimeNanoseconds: 0)
        check("expired_competing_start_cannot_preserve_old_source", expired == nil && !ordinary.isCurrent)

        reader = await fresh(); reader.contentLoadCoordinator.testingSetInitialRevisionToMax()
        let exhaustedBefore = reader.contentLoadCoordinator.initialContentSourceObservation()!
        let exhausted = reader.makeInitialContentRequest(initialContentId: 1)
        check("revision_overflow_permanently_refuses", exhausted == nil && !exhaustedBefore.isCurrent
            && reader.contentLoadCoordinator.initialContentSourceObservation() == nil)
        reader.contentLoadCoordinator.invalidate()
        check("overflow_never_resets", reader.makeInitialContentRequest(initialContentId: 1) == nil)
    }

    @MainActor static func groupCases() async throws {
        var reader = await fresh()
        func setup(_ reader: ReaderViewModel, locator: TextLocator? = nil, contentID: Int? = nil) throws
            -> (StudyWorkspaceNativeGroupSelectionReservation, iOSNavigationManager.ReaderTab) {
            let tab = iOSNavigationManager.ReaderTab(id: UUID(), book: reader.currentBook!, viewModel: reader)
            let prepared = StudyWorkspacePreparedGroupSelection(tab: tab, locator: locator, contentID: contentID)
            let owner = StudyWorkspaceNativeGroupSelectionReservation(policy: .init(), prepared: prepared, backendObservation: .init())
            try owner.captureOriginalReaderSources()
            try owner.bindInitialContentDeadline(DispatchTime.now().uptimeNanoseconds + 5_000_000_000)
            owner.policy.phase = .publishing
            return (owner, tab)
        }
        QualifiedLocatorStore.shared.hold = true
        let (owner, tab) = try setup(reader)
        let request = try owner.willLoadOriginal(tab: tab)
        reader.loadInitialContent(continuing: request); try owner.didLoadOriginal(tab: tab)
        check("group_keeps_own_request_while_token_does_not_exist", request.issuedToken == nil
            && (try? owner.validateOriginalReaderSources()) != nil)
        _ = await until { !QualifiedLocatorStore.shared.continuations.isEmpty }
        QualifiedLocatorStore.shared.resume([.init(locator: line(7))]); await settle()
        check("group_adopts_only_its_original_issuer_token", request.issuedToken?.sectionLocator == line(7)
            && (try? owner.validateOriginalReaderSources()) != nil)
        BackendCoordinator.shared.resumeSection(line(7)); await settle()
        check("group_original_reader_loaded_source_validates", reader.state == .loaded
            && (try? owner.validateOriginalReaderSources()) != nil)
        reader.loadBackendContent(destination(7)); await settle()
        check("group_cannot_borrow_later_equal_token", (try? owner.validateOriginalReaderSources()) == nil)

        reader = await fresh(); let (direct, directTab) = try setup(reader, locator: line(3))
        let directRequest = try direct.willLoadOriginal(tab: directTab)
        reader.loadBackendContent(line(3), continuing: directRequest); try direct.didLoadOriginal(tab: directTab)
        check("qualified_original_locator_path_keeps_real_token", directRequest.issuedToken?.sectionLocator == line(3)
            && (try? direct.validateOriginalReaderSources()) != nil)
        check("group_duplicate_original_load_is_refused", (try? direct.willLoadOriginal(tab: directTab)) == nil)

        reader = await fresh(); QualifiedLocatorStore.shared.hold = true
        let (cancelled, cancelledTab) = try setup(reader)
        let cancelledRequest = try cancelled.willLoadOriginal(tab: cancelledTab)
        reader.loadInitialContent(continuing: cancelledRequest); try cancelled.didLoadOriginal(tab: cancelledTab)
        _ = await until { !QualifiedLocatorStore.shared.continuations.isEmpty }
        cancelled.invalidateOriginalLoads(); QualifiedLocatorStore.shared.resume([.init(locator: line(4))]); await settle()
        check("group_release_failure_cancels_exact_pending_work", !cancelledRequest.isCurrent && BackendCoordinator.shared.sectionReads.isEmpty)

        reader = await fresh(); QualifiedLocatorStore.shared.hold = true
        let short = reader.makeInitialContentRequest(deadlineUptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + 2_000_000)!
        reader.loadInitialContent(continuing: short); _ = await until { !QualifiedLocatorStore.shared.continuations.isEmpty }
        while DispatchTime.now().uptimeNanoseconds < short.deadlineUptimeNanoseconds! { await Task.yield() }
        QualifiedLocatorStore.shared.resume([.init(locator: line(5))]); await settle()
        check("same_native_absolute_end_blocks_late_initial_resume", !short.isCurrent && BackendCoordinator.shared.sectionReads.isEmpty)

        reader = await fresh(); let book = reader.currentBook!
        reader = ReaderViewModel(BooksData(locator: nil)); reader.loadInitialContent(initialContentId: 6)
        check("unqualified_original_archive_UI_still_loads_without_deadline", reader.contentText == "legacy"
            && reader.contentLoadCoordinator.initialContentSourceObservation()?.pendingRequestID == nil)
        _ = book
    }
    #endif

    @MainActor static func main() async {
        await originalFailureCases()
        #if !BASELINE
        await requestCases()
        do { try await groupCases() } catch { rows.append(["name": "unexpected_group_error", "pass": "false", "error": String(describing: error)]) }
        #endif
        BackendCoordinator.shared.drain(); QualifiedLocatorStore.shared.resume([]); await settle()
        let failed = rows.filter { $0["pass"] == "false" }.count
        let value: [String: Any] = ["scope": "Actual original content functions/coordinator/issuer and actual Group reader-source reservation; explicit domain, async transport, rendering and UI boundaries. No native/Apple acceptance.",
            "pass": rows.count - failed, "fail": failed, "rows": rows]
        print(String(decoding: try! JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]), as: UTF8.self))
        if failed != 0 { exit(1) }
    }
}
