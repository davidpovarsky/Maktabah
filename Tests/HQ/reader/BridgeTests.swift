import Foundation

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
        let adapter = OtzariaGenericBackendAdapter()
        let numeric = try await adapter.normalizedLocator(for: "103|41")
        precondition(numeric.position == .legacyLine(41))
        for invalid in ["", "|103", "103|", "103|wrong", "103|-1", "-103|1", "0|1", "103|1|2"] {
            do {
                _ = try await adapter.normalizedLocator(for: invalid)
                preconditionFailure("invalid locator accepted: \(invalid)")
            } catch LibraryBackendError.invalidLocator {}
        }
        print("bridge: PASS — actual publication/reset/conversion/adapter methods; cancellation; async exact anchor; multiline locator; reset during mapping; malformed locators rejected")
    }
}
