func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw FixtureError(message: message) }
}

@main struct InspectorFixtures {
    static func bridge() -> OtzariaMaktabahBridge {
        OtzariaLineSourcesService.clearCategoryCache()
        OtzariaLineContentDecoder.decoded = 0
        OtzariaLineContentDecoder.fail = false
        return OtzariaMaktabahBridge(database: SQLiteDatabase(path: CommandLine.arguments[3]))
    }

    static func main() async {
        do { try await run() }
        catch { print("FAIL \(error)"); exit(1) }
    }

    static func run() async throws {
        let only = ProcessInfo.processInfo.environment["HQ_INSPECTOR_CASE"]
        if only == "scope" { try await noteScopeFixtures(); return }
        if only == "tap" { try await tapFixtures(); return }
        if only == "notes" { try await notesLoadingFixtures(); return }
        for count in [100, 500, 2000] {
            let bridge = bridge()
            // Duplicated, reversed, sparse indexes exercise exact windowing and
            // deduplication across the 400-line SQL chunk boundary.
            let indexes = (0..<count).map { $0 * 2 }
            let sources = try bridge.getLinksMetadataForReadingUnit(
                OtzariaReadingUnit(bookId: 1, sourceLineIndices: indexes.reversed() + indexes)
            )
            try expect(sources.count == count, "metadata count \(count)")
            try expect(Set(sources.map(\.id)) == Set(1...count), "every relationship ID, no gaps or coverage duplicates")
            try expect(sources.last?.linkedLineIndex == count - 1, "last link remains navigable")
            try expect(sources.allSatisfy { $0.content.isEmpty }, "metadata must not carry eager content")
            try expect(OtzariaLineContentDecoder.decoded == 0, "zero initial decodes")
            try expect(bridge.database.metadataQueries == (count + 399) / 400, "bounded metadata SQL batches")
            let grouped = OtzariaLinkedSourceGrouping.indexGroups(from: sources)
            try expect(grouped.reduce(0) { $0 + $1.count } == count, "index groups preserve counts")
            let books = grouped.flatMap { OtzariaLinkedSourceGrouping.bookGroups(from: $0.sources) }
            try expect(Set(books.flatMap(\.sources).map(\.id)) == Set(1...count), "all grouped links preserved")

            let visible = sources.suffix(12).map { TorahLinkedSource(id: String($0.id), sourceRef: "otzaria:v1:2:\($0.linkedLineIndex)") }
            let snippets = try bridge.fetchSnippets(for: visible)
            try expect(snippets.count == 12 && snippets[String(count)] == "snippet \(count - 1)", "visible/last snippets hydrated")
            try expect(OtzariaLineContentDecoder.decoded == 12, "decode visible rows only")
            let all = sources.map { TorahLinkedSource(id: String($0.id), sourceRef: "otzaria:v1:2:\($0.linkedLineIndex)") }
            let allSnippets = try bridge.fetchSnippets(for: all)
            try expect(allSnippets.count == count, "all snippets remain available")
            for i in 0..<count { try expect(allSnippets[String(i + 1)] == "snippet \(i)", "exact snippet \(i)") }
            print("PASS links=\(count) exact IDs/group counts/last navigation/zero eager decode/visible and full snippets")
        }

        for split in [false, true] {
            let bridge = bridge()
            bridge.database.splitContent = split
            let sources = try bridge.getLinksMetadataForLineIndices(bookID: 1, sourceLineIndices: [0])
            try expect(sources.count == 1 && sources[0].id == 1, "segment must not load entire section")
            let eager = try bridge.fetchLinksForLine(OtzariaLineAnchor(id: 1, bookId: 1, lineIndex: 0, heRef: nil, text: "", range: .init(location: 0, length: 0)))
            try expect(eager.count == 1 && eager[0].text == "snippet 0", "existing eager API still supplies content")
            let snippets = try bridge.fetchSnippets(for: [
                TorahLinkedSource(id: "a", sourceRef: "otzaria:v1:2:0"),
                TorahLinkedSource(id: "b", sourceRef: "otzaria:v1:2:0"),
                TorahLinkedSource(id: "missing", sourceRef: "otzaria:v1:2:9999"),
                TorahLinkedSource(id: "foreign", sourceRef: "Genesis 1:1"),
            ])
            try expect(snippets == ["a": "snippet 0", "b": "snippet 0"], "duplicate locators fan out; missing/foreign remain absent")
            let special = try bridge.getLinksMetadataForLineIndices(bookID: 1, sourceLineIndices: [9001])
            try expect(Set(special.map(\.id)) == [9100, 9103], "inverse/range/suppressed sides")
            print("PASS splitContent=\(split) segment scope/point content/partial snippets/range+inverse suppression")
        }

        do {
            let bridge = bridge()
            let empty = try bridge.getLinksMetadataForLineIndices(bookID: 1, sourceLineIndices: [8888])
            try expect(empty.isEmpty, "valid no-links window returns loadedEmpty")
            bridge.database.brokenMetadata = true
            do {
                _ = try bridge.getLinksMetadataForLineIndices(bookID: 1, sourceLineIndices: [0])
                throw FixtureError(message: "SQL failure was swallowed")
            } catch let error as FixtureError {
                try expect(error.message.contains("no such table"), "actual SQL error must reach caller")
            }
            bridge.database.brokenMetadata = false
            let retried = try bridge.getLinksMetadataForLineIndices(bookID: 1, sourceLineIndices: [0])
            try expect(retried.count == 1, "retry after SQL failure")
            OtzariaLineContentDecoder.fail = true
            do {
                _ = try bridge.fetchSnippets(for: [TorahLinkedSource(id: "x", sourceRef: "otzaria:v1:2:0")])
                throw FixtureError(message: "decode failure was swallowed")
            } catch let error as FixtureError { try expect(error.message == "fixture decode failure", "decode failure distinct from empty") }
            OtzariaLineContentDecoder.fail = false
            print("PASS loadedEmpty versus SQL/decode failure and retry")
        }

        // Every cancellation case runs in a separate task, using deterministic
        // cancellation at the boundary rather than timing/sleep races.
        try await Task.detached {
            let bridge = bridge()
            withUnsafeCurrentTask { $0?.cancel() }
            do {
                _ = try bridge.getLinksMetadataForLineIndices(bookID: 1, sourceLineIndices: [0])
                throw FixtureError(message: "cancelled metadata request succeeded")
            } catch is CancellationError {}
            do {
                _ = try bridge.fetchSnippets(for: [])
                throw FixtureError(message: "cancelled empty hydration succeeded")
            } catch is CancellationError {}
            try expect(bridge.database.queryCount == 0, "pre-cancel never opens SQL")
        }.value
        try await Task.detached {
            let bridge = bridge()
            bridge.database.cancelAtMetadataRow = 7
            do {
                _ = try bridge.getLinksMetadataForLineIndices(bookID: 1, sourceLineIndices: (0..<500).map { $0 * 2 })
                throw FixtureError(message: "mid-row metadata cancellation ignored")
            } catch is CancellationError {}
            try expect(bridge.database.metadataRowCount == 7, "metadata row processing stops promptly")
        }.value
        try await Task.detached {
            let bridge = bridge()
            bridge.database.cancelAfterMetadataBatch = true
            do {
                _ = try bridge.getLinksMetadataForLineIndices(bookID: 1, sourceLineIndices: (0..<2000).map { $0 * 2 })
                throw FixtureError(message: "between-batch cancellation ignored")
            } catch is CancellationError {}
            try expect(bridge.database.metadataQueries == 1, "no second SQL chunk after cancellation")
        }.value
        try await Task.detached {
            let bridge = bridge()
            bridge.database.cancelAtSnippetRow = 7
            do {
                _ = try bridge.fetchSnippets(for: (0..<500).map { TorahLinkedSource(id: String($0), sourceRef: "otzaria:v1:2:\($0)") })
                throw FixtureError(message: "hydration cancellation ignored")
            } catch is CancellationError {}
            try expect(OtzariaLineContentDecoder.decoded == 6, "hydration stops before seventh decode")
        }.value
        print("PASS cancellation before SQL, during metadata, between chunks, during hydration")
        try await noteScopeFixtures()
        try await tapFixtures()
        try await notesLoadingFixtures()
        print("ALL INSPECTOR FIXTURES PASSED (portable boundaries; no physical/production performance claim)")
    }

    @MainActor static func noteScopeFixtures() throws {
        let notes = NoteScopeFixture()
        notes.otzariaUnitsByReference["otzaria:unit"] = OtzariaReadingUnit(bookId: 1, sourceLineIndices: [0, 2, 4])
        let section = TorahInspectorSelection(providerID: "otzaria", canonicalRef: "unit", scope: .section)
        let segment = TorahInspectorSelection(providerID: "otzaria", canonicalRef: "unit", scope: .segment)
        let own = TextLocator(backend: .otzaria, workKey: "book:1", position: .legacyLine(2))
        try expect(notes.contains(own, in: section), "section includes exact member")
        try expect(!notes.contains(own, in: segment), "segment cannot include all section notes")
        try expect(!notes.contains(TextLocator(backend: .otzaria, workKey: "book:1", position: .legacyLine(1)), in: section), "sparse gap excluded")
        try expect(!notes.contains(TextLocator(backend: .otzaria, workKey: "book:2", position: .legacyLine(2)), in: section), "other book excluded")
        try expect(!notes.contains(TextLocator(backend: .sefaria, workKey: "book:1", position: .legacyLine(2)), in: section), "other backend excluded")
        let sefaria = TorahInspectorSelection(providerID: "sefaria", canonicalRef: "Genesis 1", scope: .section)
        try expect(notes.contains(TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 1:2")), in: sefaria), "Sefaria section notes unchanged")
        print("PASS actual note membership: segment/section/backend/book/sparse gaps/Sefaria section")
    }

    @MainActor static func tapFixtures() async throws {
        let own = TextLocator(backend: .otzaria, workKey: "book:1", position: .legacyLine(2))
        let viewModel = ReaderViewModel()
        let anchor = OtzariaLineAnchor(id: 1, bookId: 1, lineIndex: 0, heRef: nil, text: "base", range: .init(location: 0, length: 4))
        OtzariaMaktabahBridge.shared.cachedAnchor = anchor
        let stale = Task<Void, Never> { try? await Task.sleep(nanoseconds: 10_000_000_000) }
        viewModel.otzariaSourcesLoadTask = stale
        viewModel.didTapReaderText(at: 0)
        try expect(stale.isCancelled, "cached tap cancels stale anchor work")
        try expect(viewModel.readerInspectorVisible && viewModel.otzariaSelectedLineAnchor == anchor, "tap opens shell with exact selection")
        try expect(viewModel.otzariaSourcesLoadTask == nil && !viewModel.otzariaSourcesIsLoading, "tap does not schedule duplicate eager fetch")
        try expect(OtzariaMaktabahBridge.shared.database.queryCount == 0, "no SQL/payload decode from tap")
        viewModel.didTapReaderText(at: 0)
        try expect(!viewModel.readerInspectorVisible, "same selected line toggles inspector closed")
        let mappedTask = Task<Void, Never> { try? await Task.sleep(nanoseconds: 10_000_000_000) }
        viewModel.otzariaSourcesLoadTask = mappedTask
        viewModel.backendRenderModel = FixtureRenderModel(mapping: FixtureMapping(locator: own))
        viewModel.didTapReaderText(at: 0)
        try expect(mappedTask.isCancelled && viewModel.selectedSegmentLocator == own, "mapped tap cancels stale anchor task and keeps newest selection")
        print("PASS actual reader tap paths: shell/no eager SQL/stale cancellation")
    }

    @MainActor static func notesLoadingFixtures() async throws {
        let viewModel = ReaderViewModel()
        let locator = TextLocator(backend: .otzaria, workKey: "book:1", position: .legacyLine(0))
        viewModel.selectedSegmentLocator = locator
        let session = NoteScopeFixture()
        session.readerViewModel = viewModel
        let selection = TorahInspectorSelection(providerID: "otzaria", canonicalRef: locator.persistenceKey, scope: .segment)
        let annotation = Annotation(
            id: 1, bkId: 1, contentId: 0, range: NSRange(location: 0, length: 4),
            rangeDiacritics: NSRange(location: 0, length: 4), colorHex: "#ffff00", type: .highlight,
            note: "persisted", createdAt: 1, context: "base", page: 1, part: 1, backendLocator: locator
        )
        AnnotationManager.shared.rows = [annotation]
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        let timedOut = FixtureFlag()
        AnnotationManager.shared.onLoad = {
            entered.signal()
            if release.wait(timeout: .now() + 2) != .success { timedOut.set() }
        }
        let request = Task { @MainActor in try await session.notes(for: selection) }
        let heartbeat = Task.detached {
            guard entered.wait(timeout: .now() + 3) == .success else { throw FixtureError(message: "notes loader did not start") }
            _ = await MainActor.run { release.signal() }
        }
        let result = try await request.value
        try await heartbeat.value
        try expect(!timedOut.value, "cold notes loader must leave MainActor responsive")
        try expect(result.count == 1 && result[0].note == "persisted", "persisted notes preserved")

        for stale in ["generation", "backend", "book", "cancel"] {
            let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
            AnnotationManager.shared.onLoad = {
                entered.signal()
                _ = release.wait(timeout: .now() + 3)
            }
            BackendCoordinator.shared.activeBackendID = .otzaria
            viewModel.currentBook = FixtureBook(id: 1)
            let request = Task { @MainActor in try await session.notes(for: selection) }
            let started = await Task.detached { entered.wait(timeout: .now() + 3) == .success }.value
            try expect(started, "stale test loader started")
            switch stale {
            case "generation": BackendCoordinator.shared.generation += 1
            case "backend": BackendCoordinator.shared.activeBackendID = .sefaria
            case "book": viewModel.currentBook = FixtureBook(id: 2)
            default: request.cancel()
            }
            release.signal()
            do {
                _ = try await request.value
                throw FixtureError(message: "stale \(stale) notes applied")
            } catch is CancellationError {}
        }
        AnnotationManager.shared.onLoad = {}
        AnnotationManager.shared.rows = []
        BackendCoordinator.shared.activeBackendID = .otzaria
        viewModel.currentBook = FixtureBook(id: 1)
        var local = annotation
        local.id = nil
        local.note = "unsaved"
        viewModel.currentAnnotations = [local]
        let localResult = try await session.notes(for: selection)
        try expect(localResult.count == 1 && localResult[0].note == "unsaved", "unsaved notes preserved after background load")
        print("PASS actual notes loader: MainActor heartbeat, persisted/unsaved notes, stale generation/backend/book and cancellation")
    }
}
