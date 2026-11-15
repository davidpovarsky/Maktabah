import Foundation

private enum ReaderFixtureError: Error { case sourceUnavailable, navigationUnavailable }

@main struct BridgeTests {
    static func main() async throws {
        let cache = OtzariaReadingUnitSideCache.shared
        let bridge = OtzariaMaktabahBridge(database: SQLiteDatabase())
        cache.clear()
        let loaded = bridge.getFirstReadingUnit(bookId: 103, mode: .paragraph)!
        precondition(cache.unit(bookId: 103, contentId: 0, mode: .paragraph) != nil)
        bridge.resetConnection()
        _ = bridge.makeBookContent(from: loaded)
        precondition(cache.unit(bookId: 103, contentId: 0, mode: .paragraph) == nil, "conversion must not republish old unit")

        for cancel in [false, true] {
            bridge.database = SQLiteDatabase()
            let started = DispatchSemaphore(value: 0)
            let release = DispatchSemaphore(value: 0)
            let worker = Task.detached {
                bridge.withCachedReadingUnit { service in
                    let unit = try? service.firstReadingUnit(bookId: 103, mode: .paragraph)
                    started.signal()
                    precondition(release.wait(timeout: .now() + 10) == .success)
                    return unit
                }
            }
            precondition(started.wait(timeout: .now() + 10) == .success)
            if cancel { worker.cancel() } else { bridge.resetConnection() }
            release.signal()
            let result = await worker.value
            precondition(result == nil, "reset/cancelled unit must not escape")
            precondition(cache.unit(bookId: 103, contentId: 0, mode: .paragraph) == nil, "reset/cancelled unit must not enter cache")
        }
        bridge.database = SQLiteDatabase()
        let anchor = await bridge.lineAnchorAsync(bookId: 103, contentId: 0, characterIndex: 0)
        precondition(anchor?.id == 100, "async anchor keeps actual ID")
        let cancelled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await bridge.lineAnchorAsync(bookId: 103, contentId: 0, characterIndex: 0)
        }
        let cancelledAnchor = await cancelled.value
        precondition(cancelledAnchor == nil)

        bridge.resetConnection()
        bridge.database = SQLiteDatabase()
        bridge.onRequireDatabase = {
            bridge.onRequireDatabase = nil
            bridge.resetConnection()
            bridge.database = SQLiteDatabase()
        }
        let replacedBeforeLease = await bridge.lineAnchorAsync(bookId: 103, contentId: 0, characterIndex: 0)
        precondition(replacedBeforeLease == nil, "anchor request started before DB replacement must not adopt the new DB lease")

        let shared = OtzariaMaktabahBridge.shared
        shared.resetConnection()
        let empty = SQLiteDatabase()
        empty.lines = []; empty.mappings = []; empty.entries = []
        shared.database = empty
        let multiline = "ראשון\n\n😀 second\nשלישי"
        shared.fallbackContent = BookContent(id: 41, nash: multiline, page: 41, part: 1, heRef: nil)
        let requested = TextLocator(backend: .otzaria, workKey: "book:103", position: .legacyLine(0))
        let fallback = try await OtzariaGenericBackendAdapter().section(at: requested)
        precondition(fallback.segments.count == 1 && fallback.segments[0].primaryText == multiline)
        precondition(fallback.segments[0].locator.position == .legacyLine(41), "newlines never fabricate locators")

        shared.resetConnection()
        shared.database = SQLiteDatabase()
        OtzariaInspectorDocumentMapper.onMap = { shared.resetConnection() }
        do {
            _ = try await OtzariaGenericBackendAdapter().section(at: requested)
            preconditionFailure("reset during mapping must cancel final response")
        } catch is CancellationError {}
        OtzariaInspectorDocumentMapper.onMap = nil
        shared.resetConnection()
        let broken = SQLiteDatabase()
        broken.sourceError = ReaderFixtureError.sourceUnavailable
        shared.database = broken
        shared.fallbackContent = BookContent(id: 0, nash: "misleading partial fallback", page: 0, part: 1, heRef: nil)
        do {
            _ = try await OtzariaGenericBackendAdapter().section(at: requested)
            preconditionFailure("source read failure must reach the reader, never become a partial fallback")
        } catch ReaderFixtureError.sourceUnavailable {}
        shared.resetConnection()
        shared.currentReadingUnitMode = .line
        let brokenNavigation = SQLiteDatabase()
        brokenNavigation.onFetch = {
            if brokenNavigation.sourceFetches > 0 { throw ReaderFixtureError.navigationUnavailable }
        }
        shared.database = brokenNavigation
        do {
            _ = try await OtzariaGenericBackendAdapter().section(at: requested)
            preconditionFailure("adjacent metadata error must not hide the next or previous unit")
        } catch ReaderFixtureError.navigationUnavailable {}
        let adapter = OtzariaGenericBackendAdapter()
        let numeric = try await adapter.normalizedLocator(for: "103|41")
        precondition(numeric.position == .legacyLine(41))
        for invalid in ["", "|103", "103|", "103|wrong", "103|-1", "-103|1", "0|1", "103|1|2"] {
            do {
                _ = try await adapter.normalizedLocator(for: invalid)
                preconditionFailure("invalid locator accepted: \(invalid)")
            } catch LibraryBackendError.invalidLocator {}
        }
        print("bridge: PASS — actual publication/reset/adapter methods; cancellation; reset-before-lease anchor rejected; multiline locator; reset during mapping; source and adjacent SQL errors propagated; malformed locators rejected")
    }
}
