import Foundation
import Observation

@main struct OriginalPublisherControls {
    @MainActor static var rows: [[String: String]] = []
    @MainActor static func check(_ name: String, _ result: Bool) {
        rows.append(["name": name, "pass": result ? "true" : "false"])
    }
    static func line(_ value: Int) -> TextLocator { .init(backend: .otzaria, workKey: "1", position: .legacyLine(value)) }
    static func destination(_ value: Int) -> LibraryReaderDestination { .init(sectionLocator: line(value), focusLocator: nil) }
    static func resolved(_ value: Int) -> LibraryReaderDestination { .init(sectionLocator: line(value), focusLocator: line(value)) }
    @MainActor static func settle() async { for _ in 0..<80 { await Task.yield() } }
    @MainActor static func until(_ predicate: () -> Bool) async -> Bool {
        for _ in 0..<5000 { if predicate() { return true }; await Task.yield() }
        return predicate()
    }
    @MainActor static func fresh() async -> ReaderViewModel {
        BackendCoordinator.shared.drain(); QualifiedLocatorStore.shared.resume([]); await settle()
        BackendCoordinator.shared.activeBackendID = .otzaria; BackendCoordinator.shared.generation = 0
        BackendCoordinator.shared.holdNavigation = false; BackendCoordinator.shared.navigation = [.init(locator: line(1), title: "Original", index: 0)]
        BackendCoordinator.shared.sectionReads = []
        QualifiedLocatorStore.shared.hold = false; QualifiedLocatorStore.shared.result = []; QualifiedLocatorStore.shared.records = []
        LegacyIdentityRegistry.shared.locators = [:]
        return ReaderViewModel(BooksData(locator: line(0)))
    }
    @MainActor static func load(_ reader: ReaderViewModel) async {
        reader.loadBackendContent(destination(1))
        check("actual_section_wait_reached", await until { BackendCoordinator.shared.sectionReads.contains(line(1)) })
    }
    @MainActor static func sourceCases() async {
        var reader = await fresh(); await load(reader)
        let observedReader = reader
        withObservationTracking { _ = observedReader.contentText } onChange: {
            MainActor.assumeIsolated { observedReader.loadBackendContent(destination(2)) }
        }
        BackendCoordinator.shared.resumeSection(line(1)); await settle()
        check("actual_contentText_observer_stops_later_original_ids_history_annotations", reader.currentContentId == 40
            && reader.currentID == 43 && reader.currentPart == 42 && reader.currentPage == 41
            && reader.annotationLoads == 0 && QualifiedLocatorStore.shared.records.isEmpty
            && reader.currentDestination == resolved(2) && reader.state == .loading && reader.backendLoadTask != nil)

        reader = await fresh(); BackendCoordinator.shared.holdNavigation = true
        reader.loadInitialContent(); _ = await until { !BackendCoordinator.shared.navContinuations.isEmpty }
        let navigationHandle = reader.contentLoadCoordinator.initialContentSourceObservation()!
        BackendCoordinator.shared.rejectNavigation(CancellationError()); await settle()
        check("uncancelled_task_navigation_cancellation_retires_only_its_pending_metadata",
            !navigationHandle.isCurrent && reader.contentLoadCoordinator.initialContentSourceObservation()?.pendingRequestID == nil)

        reader = await fresh(); await load(reader)
        let sectionHandle = reader.contentLoadCoordinator.initialContentSourceObservation()!
        BackendCoordinator.shared.rejectSection(line(1), CancellationError()); await settle()
        check("uncancelled_task_section_cancellation_retires_pending_metadata",
            !sectionHandle.isCurrent && reader.contentLoadCoordinator.initialContentSourceObservation()?.pendingRequestID == nil)

        reader = await fresh(); await load(reader)
        let staleHandle = reader.contentLoadCoordinator.initialContentSourceObservation()!
        BackendCoordinator.shared.rejectSection(line(1), LibraryBackendError.staleRequest); await settle()
        check("uncancelled_task_stale_backend_response_retires_pending_metadata",
            !staleHandle.isCurrent && reader.contentLoadCoordinator.initialContentSourceObservation()?.pendingRequestID == nil)

        reader = await fresh(); QualifiedLocatorStore.shared.hold = true
        reader.loadInitialContent(); _ = await until { !QualifiedLocatorStore.shared.continuations.isEmpty }
        let oldBackend = reader.contentLoadCoordinator.initialContentSourceObservation()!
        BackendCoordinator.shared.activeBackendID = .sefaria; BackendCoordinator.shared.generation += 1
        BackendCoordinator.shared.activeBackendID = .otzaria; BackendCoordinator.shared.generation += 1
        QualifiedLocatorStore.shared.resume([.init(locator: line(1))]); await settle()
        check("retired_backend_source_does_not_leave_ordinary_pending_metadata",
            !oldBackend.isCurrent && reader.contentLoadCoordinator.initialContentSourceObservation()?.pendingRequestID == nil
            && BackendCoordinator.shared.sectionReads.isEmpty)

        reader = await fresh(); await load(reader)
        reader.loadBackendContent(destination(2)); let current = reader.contentLoadCoordinator.initialContentSourceObservation()!
        BackendCoordinator.shared.rejectSection(line(1), CancellationError()); await settle()
        check("late_old_terminal_error_cannot_retire_replacement_handle", current.isCurrent
            && reader.contentLoadCoordinator.currentRequestToken()?.sectionLocator == line(2) && reader.backendLoadTask != nil)

        reader = await fresh(); await load(reader)
        BackendCoordinator.shared.resumeSection(line(1)); await settle()
        check("ordinary_current_source_still_publishes_complete_content", reader.currentContentId == 1 && reader.state == .loaded
            && reader.annotationLoads == 1 && QualifiedLocatorStore.shared.records == [line(1)]
            && reader.contentLoadCoordinator.initialContentSourceObservation()?.pendingRequestID == nil)
    }
    @MainActor static func publisherCases() async {
        #if PUBLISHER_IOS
        var reader = await fresh(); await load(reader)
        let annotationReader = reader
        reader.contentHook = { annotationReader.loadBackendContent(destination(2)) }
        BackendCoordinator.shared.resumeSection(line(1)); await settle()
        check("actual_loadAnnotations_callback_stops_later_original_ReaderState", reader.annotationLoads == 1
            && reader.readerState.currentID == 901 && reader.readerState.currentPart == 902
            && reader.readerState.selectedRange == NSRange(location: 13, length: 14)
            && reader.limitUpdates == 0 && reader.currentDestination == resolved(2))

        reader = await fresh(); await load(reader)
        let stateReader = reader
        withObservationTracking { _ = stateReader.readerState.currentID } onChange: {
            MainActor.assumeIsolated { stateReader.loadBackendContent(destination(2)) }
        }
        BackendCoordinator.shared.resumeSection(line(1)); await settle()
        check("actual_nested_state_publication_stops_later_scroll_selection_clears", reader.readerState.currentPart == 902
            && reader.readerState.selectedRange == NSRange(location: 13, length: 14)
            && reader.lineClears == 0 && reader.limitUpdates == 0 && reader.currentDestination == resolved(2))

        reader = await fresh()
        reader.updateContentState(with: .init(id: 9, nash: "ordinary direct publication", backendLocator: nil))
        check("default_nil_preserves_original_iOS_publication", reader.currentContentId == 9
            && reader.readerState.currentID == 9 && reader.readerState.currentPart == 8
            && reader.readerState.currentPage == 7 && reader.readerState.selectedRange == nil
            && reader.readerState.scrollPosition == nil && reader.lineClears == 1 && reader.limitUpdates == 1)
        #endif
        #if PUBLISHER_MACOS
        var reader = await fresh(); await load(reader)
        let payloadReader = reader
        reader.onPayloadChanged = { _ in payloadReader.loadBackendContent(destination(2)) }
        BackendCoordinator.shared.resumeSection(line(1)); await settle()
        check("actual_mac_payload_callback_stops_later_original_ids", reader.currentContentId == 40
            && reader.annotationLoads == 0 && reader.currentDestination == resolved(2))

        reader = await fresh(); await load(reader)
        let contentReader = reader
        reader.onContentChanged = { _ in contentReader.loadBackendContent(destination(2)) }
        BackendCoordinator.shared.resumeSection(line(1)); await settle()
        check("actual_mac_content_callback_stops_later_original_window_publication", reader.windowTitleUpdates == 0
            && reader.currentDestination == resolved(2) && reader.state == .loading)

        reader = await fresh(); reader.updateContentState(with: .init(id: 9, nash: "ordinary direct publication", backendLocator: nil))
        check("default_nil_preserves_original_mac_publication", reader.currentContentId == 9
            && reader.contentPayload.text == "ordinary direct publication" && reader.windowTitleUpdates == 1)
        #endif
    }
    @MainActor static func main() async {
        #if PUBLISHER_IOS
        await sourceCases()
        #endif
        await publisherCases()
        BackendCoordinator.shared.drain(); QualifiedLocatorStore.shared.resume([]); await settle()
        let fail = rows.filter { $0["pass"] == "false" }.count
        let result: [String: Any] = ["pass": rows.count - fail, "fail": fail, "rows": rows,
            "scope": "Actual original/candidate updateContentState body and cold content/coordinator; iOS/macOS conditionals explicitly selected over declared domain/backend/ReaderState shells. No Apple SDK, renderer, UIKit, or native acceptance."]
        print(String(decoding: try! JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]), as: UTF8.self))
        if fail > 0 { exit(1) }
    }
}
