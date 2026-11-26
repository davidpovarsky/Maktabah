import Foundation

@main struct TOCLoadLifecycleTests {
    struct Check: Codable { let name: String; let passed: Bool }
    @MainActor static var checks: [Check] = []
    @MainActor static func check(_ name: String, _ passed: Bool) {
        checks.append(Check(name: name, passed: passed))
    }
    @MainActor static func settle() async {
        for _ in 0..<25 { await Task.yield() }
        try? await Task.sleep(for: .milliseconds(20))
    }
    @MainActor static func wait(_ predicate: @MainActor () async -> Bool) async {
        for _ in 0..<500 {
            if await predicate() { return }
            try? await Task.sleep(for: .milliseconds(1))
        }
        fatalError("Fixture request did not reach its controlled boundary")
    }
    static func backendBook(_ key: String, work: String? = nil, backend: TextLocator.Backend = .sefaria) -> BooksData {
        .init(id: 1, book: key, backendLocator: .init(backend: backend, workKey: work ?? key, reference: key))
    }
    static func nativeBook(_ id: Int) -> BooksData { .init(id: id, book: "native-\(id)", backendLocator: nil) }
    static func tree(_ key: String) -> [LibraryNavigationStructure] {
        [.init(id: "primary", title: "Chapters", nodes: [
            .init(locator: .init(backend: .sefaria, workKey: key, reference: key + " 1"), title: key, children: [])
        ])]
    }
    @MainActor static func vm() -> BookTOCViewModel { BookTOCViewModel(connFactory: { BookConnection() }) }
    @MainActor static func waitBackend(_ key: String) async {
        await wait { BackendCoordinator.shared.structures[key] != nil }
    }
    @MainActor static func waitNative(_ id: Int) async {
        await wait { await NativeTOCBoundary.shared.has(id) }
    }

    @MainActor static func main() async {
        let backend = BackendCoordinator.shared
        let native = NativeTOCBoundary.shared

        do {
            let owner = vm()
            var events: [Bool] = []
            owner.onTOCLoadingStateChanged = { events.append($0) }
            owner.loadTOC(book: backendBook("complete"))
            check("loading_is_published_before_task_schedules", owner.isLoading && owner.loadingStatus == .loading)
            await waitBackend("complete")
            backend.finish("complete", tree("complete"))
            await settle()
            check("backend_success_publishes_tree_and_loaded", owner.tocNodes.first?.bab == "complete" && owner.loadingStatus == .loaded && !owner.isLoading)
            check("one_loading_start_and_finish", events == [true, false])
            let staleID = owner.tocNodes.first!.id
            owner.loadTOC(book: backendBook("replace"))
            check("new_request_removes_old_ranges_and_cache", owner.tocRanges.isEmpty && owner.findNodeById(staleID) == nil)
            await waitBackend("replace")
            backend.finish("replace", [])
            await wait { backend.fallbacks["replace"] != nil }
            backend.finishFallback("replace", [])
            await settle()
            check("empty_backend_finishes_as_loaded_empty", owner.tocNodes.isEmpty && owner.loadingStatus == .loaded && !owner.isLoading)
        }

        for errorKind in ["offline", "corrupt", "other"] {
            let owner = vm()
            owner.loadTOC(book: backendBook(errorKind))
            await waitBackend(errorKind)
            let error: Error = errorKind == "offline" ? LibraryBackendError.unavailableOffline
                : errorKind == "corrupt" ? LibraryBackendError.corruptData("fixture")
                : LibraryBackendError.invalidResponse("fixture")
            backend.fail(errorKind, error)
            await settle()
            let expected: BookTOCViewModel.LoadFailure = errorKind == "offline" ? .unavailableOffline : errorKind == "corrupt" ? .corruptData : .backend
            check("backend_\(errorKind)_failure_is_terminal", owner.loadFailure == expected && owner.loadingStatus == .failed(expected) && !owner.isLoading)
            owner.loadTOC(book: backendBook(errorKind + "-retry"))
            check("backend_\(errorKind)_retry_clears_failure", owner.loadFailure == nil && owner.loadingStatus == .loading)
            await waitBackend(errorKind + "-retry")
            backend.finish(errorKind + "-retry", tree("recovered"))
            await settle()
            check("backend_\(errorKind)_retry_loads", owner.loadingStatus == .loaded && owner.tocNodes.first?.bab == "recovered")
        }

        for sameWork in [false, true] {
            let old = sameWork ? "same-old" : "old"
            let next = sameWork ? "same-new" : "new"
            let owner = vm()
            var events: [Bool] = []
            owner.onTOCLoadingStateChanged = { events.append($0) }
            owner.loadTOC(book: backendBook(old, work: sameWork ? "shared" : nil))
            await waitBackend(old)
            owner.loadTOC(book: backendBook(next, work: sameWork ? "shared" : nil))
            await waitBackend(next)
            backend.finish(old, tree("stale"))
            await settle()
            check("cancelled_backend_cannot_end_\(sameWork ? "same_work" : "new_work")_loading", owner.isLoading && owner.loadingStatus == .loading && events == [true, true])
            check("cancelled_backend_cannot_publish_\(sameWork ? "same_work" : "new_work")_tree", owner.tocNodes.isEmpty)
            backend.finish(next, tree(next))
            await settle()
            check("current_\(sameWork ? "same_work" : "new_work")_tree_wins", owner.tocNodes.first?.bab == next && !owner.isLoading && events.last == false)
        }

        do {
            let owner = vm()
            var events: [Bool] = []
            owner.onTOCLoadingStateChanged = { events.append($0) }
            owner.loadTOC(book: backendBook("backend-to-native"))
            await waitBackend("backend-to-native")
            owner.loadTOC(book: nativeBook(101))
            await waitNative(101)
            backend.finish("backend-to-native", tree("stale"))
            await settle()
            check("backend_to_native_preserves_loading_owner", owner.isLoading && events == [true, true])
            await native.finish(101, [TOCNode(backendTitle: "native", level: 1, sub: 0, id: 101)])
            await settle()
            check("native_success_has_terminal_loaded_status", owner.loadingStatus == .loaded && !owner.isLoading && owner.tocNodes.first?.bab == "native")
        }

        for failOld in [false, true] {
            let id = failOld ? 103 : 102
            let key = failOld ? "after-native-failure" : "after-native-success"
            let owner = vm()
            var events: [Bool] = []
            owner.onTOCLoadingStateChanged = { events.append($0) }
            owner.loadTOC(book: nativeBook(id))
            await waitNative(id)
            owner.loadTOC(book: backendBook(key, backend: .sefariaEmbedded))
            await waitBackend(key)
            if failOld { await native.fail(id) } else { await native.finish(id, []) }
            await settle()
            check("stale_native_\(failOld ? "failure" : "success")_cannot_end_new_loading", owner.isLoading && owner.loadingStatus == .loading && events == [true, true] && owner.loadFailure == nil)
            backend.finish(key, tree(key))
            await settle()
            check("native_to_embedded_keeps_latest_tree_\(id)", owner.tocNodes.first?.bab == key && owner.loadingStatus == .loaded)
        }

        do {
            let owner = vm()
            owner.loadTOC(book: nativeBook(104))
            await waitNative(104)
            await native.fail(104)
            await settle()
            check("native_failure_exposes_retry_state", owner.loadingStatus == .failed(.backend) && owner.loadFailure == .backend && !owner.isLoading)
            owner.loadTOC(book: nativeBook(105))
            await waitNative(105)
            await native.finish(105, [])
            await settle()
            check("native_retry_empty_is_loaded_without_spinner", owner.loadingStatus == .loaded && owner.loadFailure == nil && !owner.isLoading && owner.tocNodes.isEmpty)
        }

        do {
            let owner = vm()
            owner.loadTOC(book: backendBook("cleanup"))
            await waitBackend("cleanup")
            owner.cleanUp()
            check("cleanup_finishes_current_loading", !owner.isLoading && owner.loadingStatus == .idle)
            backend.finish("cleanup", tree("stale"))
            await settle()
            check("cleanup_prevents_late_publication", owner.tocNodes.isEmpty && owner.navigationStructures.isEmpty && owner.loadingStatus == .idle)
            owner.loadTOC(book: backendBook("loaded-before-cleanup"))
            await waitBackend("loaded-before-cleanup")
            backend.finish("loaded-before-cleanup", tree("old"))
            await settle()
            owner.cleanUp()
            check("cleanup_clears_all_navigation_state", owner.navigationStructures.isEmpty && owner.selectedStructureID.isEmpty && owner.tocRanges.isEmpty && owner.loadFailure == nil && owner.loadingStatus == .idle)
        }

        do {
            let owner = vm()
            owner.loadTOC(book: backendBook("fallback-old"))
            await waitBackend("fallback-old")
            backend.finish("fallback-old", [])
            await wait { backend.fallbacks["fallback-old"] != nil }
            owner.loadTOC(book: backendBook("fallback-new"))
            await waitBackend("fallback-new")
            backend.finishFallback("fallback-old", [])
            await settle()
            check("cancelled_fallback_cannot_end_current_loading", owner.isLoading && owner.loadingStatus == .loading)
            backend.finish("fallback-new", tree("fallback-new"))
            await settle()
            check("current_tree_wins_after_fallback_cancellation", owner.tocNodes.first?.bab == "fallback-new")
        }

        let releases = await native.released
        check("every_native_acquire_is_released", releases.sorted() == [101, 102, 103, 104, 105])
        let bytes = try! JSONEncoder().encode(checks)
        print(String(decoding: bytes, as: UTF8.self))
        exit(checks.allSatisfy(\.passed) ? 0 : 1)
    }
}
