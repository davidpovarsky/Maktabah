import Foundation
import SQLite3

// Only telemetry/log output is replaced. The original Reader, SQLite and
// dictionary ZSTD implementation are compiled unchanged by the existing driver.
struct OtzariaPerformanceTelemetry: Sendable {
    static let shared = Self()
    struct Interval { func end(extra: String) {} }
    func begin(_ name: String) -> Interval { .init() }
}
struct OtzariaFileLogger: Sendable {
    static let shared = Self()
    func log(_ value: String) {}
}

private struct StressFailure: Error, CustomStringConvertible {
    let description: String
}
private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw StressFailure(description: message) }
}
private func now() -> Double { ProcessInfo.processInfo.systemUptime }

// Test-only sharing deliberately exercises the original service's own locks.
// This does not add a production Sendable conformance or change its isolation.
private final class Owner: @unchecked Sendable {
    let database: SQLiteDatabase
    let reader: OtzariaReadingUnitService
    init(uri: String) throws {
        database = try SQLiteDatabase(path: uri,
            flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_FULLMUTEX, queryOnly: true)
        try require(sqlite3_db_readonly(database.dbPointer, "main") == 1, "database must be read-only")
        reader = OtzariaReadingUnitService(database: database)
    }
}

private final class Overlap: @unchecked Sendable {
    private let lock = NSLock()
    private var active = 0
    private(set) var maximum = 0
    func enter() { lock.withLock { active += 1; maximum = max(maximum, active) } }
    func leave() { lock.withLock { active -= 1 } }
}

// Actual SQLite progress/row callbacks are observation boundaries. A requested
// barrier is explicitly reported; no query, row, decoder or error is replaced.
private final class SQLProbe: @unchecked Sendable {
    private let lock = NSLock()
    private let release = DispatchSemaphore(value: 0)
    private let blockAtProgress: Int?
    private var progress = 0
    private var rows = 0
    private var tripped = false
    private var barrierTimedOut = false
    private var firstRowTime: Double?
    init(blockAtProgress: Int? = nil) { self.blockAtProgress = blockAtProgress }
    func step() -> Int32 {
        let shouldBlock = lock.withLock { () -> Bool in
            progress += 1
            guard let blockAtProgress, progress == blockAtProgress else { return false }
            tripped = true
            return true
        }
        if shouldBlock, release.wait(timeout: .now() + 10) != .success {
            lock.withLock { barrierTimedOut = true }
            return 1
        }
        return 0
    }
    func row() { lock.withLock { rows += 1; if firstRowTime == nil { firstRowTime = now() } } }
    var state: (progress: Int, rows: Int, tripped: Bool, timedOut: Bool, firstRow: Double?) {
        lock.withLock { (progress, rows, tripped, barrierTimedOut, firstRowTime) }
    }
    func resume() { release.signal() }
    func install(on owner: Owner) {
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        sqlite3_progress_handler(owner.database.dbPointer, 1_000, { context in
            Unmanaged<SQLProbe>.fromOpaque(context!).takeUnretainedValue().step()
        }, pointer)
        sqlite3_trace_v2(owner.database.dbPointer, UInt32(SQLITE_TRACE_ROW), { _, context, _, _ in
            Unmanaged<SQLProbe>.fromOpaque(context!).takeUnretainedValue().row()
            return 0
        }, pointer)
    }
    func uninstall(from owner: Owner) {
        sqlite3_progress_handler(owner.database.dbPointer, 0, nil, nil)
        sqlite3_trace_v2(owner.database.dbPointer, 0, nil, nil)
    }
}

private func waitFor(_ predicate: @Sendable () -> Bool) async throws {
    let deadline = now() + 10
    while !predicate() {
        try require(now() < deadline, "test observation timed out")
        try await Task.sleep(for: .milliseconds(1))
    }
}

private func field(_ object: Any, _ name: String) throws -> Any {
    guard let value = Mirror(reflecting: object).children.first(where: { $0.label == name })?.value else {
        throw StressFailure(description: "source cache field missing: \(name)")
    }
    return value
}
private func count(_ object: Any, _ name: String) throws -> Int {
    Mirror(reflecting: try field(object, name)).children.count
}
private struct CacheSnapshot: Codable, Sendable {
    let indexEntries: Int
    let summariesEntries: Int
    let indexCost: Int
    let summariesCost: Int
    let generation: UInt64
    let decoderPresent: Bool
    init(_ reader: OtzariaReadingUnitService) throws {
        // Called only after the participating tasks have joined.
        indexEntries = try count(reader, "indexCache")
        summariesEntries = try count(reader, "summariesCache")
        indexCost = try field(reader, "indexCacheCost") as! Int
        summariesCost = try field(reader, "summariesCacheCost") as! Int
        generation = try field(reader, "cacheGeneration") as! UInt64
        decoderPresent = try count(reader, "contentDecoder") != 0
        try require(indexEntries <= 20 && indexCost <= 100_000, "index retention exceeded source bound")
        try require(summariesEntries <= 50 && summariesCost <= 200_000, "summary retention exceeded source bound")
    }
}

@main struct FullSourceReaderStress {
    struct Book: Decodable, Sendable {
        let id: Int
        let first: Int
        let middle: Int
    }
    struct Input: Decodable, Sendable {
        let uri: String
        let books: [Book]
        let cacheBooks: [Book]
    }
    struct Sample: Codable, Sendable {
        let name: String
        let bookID: Int
        let mode: String
        let rows: Int
        let milliseconds: Double
    }
    private struct Report: Codable {
        var status = "STARTED"
        var sourceReadonly = true
        var sqliteVersion = String(cString: sqlite3_libversion())
        var nativeUIExecuted = 0
        var physicalDeviceExecuted = 0
        var samples: [Sample] = []
        var sharedMaximumOverlap = 0
        var independentMaximumOverlap = 0
        var cacheSnapshots: [CacheSnapshot] = []
        var clearDuringActiveQueryGeneration: [UInt64] = []
        var preCancelledOutcome = "NOT_RUN"
        var activeCancellationOutcome = "NOT_RUN"
        var activeCancellationRowsBeforeBarrier = 0
        var activeCancellationMilliseconds = 0.0
        var queuedCancellationOutcome = "NOT_RUN"
        var queuedCancellationMilliseconds = 0.0
        var queuedCancellationArtificialDelay = false
        var sideCacheEntries = 0
        var sideCacheEstimatedBytes = 0
        var oversizedUnitEstimatedBytes = 0
        var oversizedUnitRetained = false
        var statementCacheEntries = 0
        var failed: String?
    }

    private static func record(_ unit: OtzariaReadingUnit, name: String,
                               milliseconds: Double, output: URL) throws -> Sample {
        try require(unit.sourceLineIndices == unit.lineAnchors.map(\.lineIndex), "anchor identity changed")
        let text = unit.plainText as NSString
        for anchor in unit.lineAnchors {
            try require(NSMaxRange(anchor.range) <= text.length, "anchor outside UTF16 text")
            try require(text.substring(with: anchor.range) == anchor.text, "anchor text mismatch")
        }
        let record: [String: Any] = ["book_id": unit.bookId, "source_indices": unit.sourceLineIndices,
            "anchors": unit.lineAnchors.map { ["id": $0.id, "index": $0.lineIndex,
                "he_ref": $0.heRef as Any? ?? NSNull()] as [String: Any] }]
        try unit.html.write(to: output.appendingPathComponent(name + ".html"), atomically: true, encoding: .utf8)
        try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
            .write(to: output.appendingPathComponent(name + ".json"))
        return Sample(name: name, bookID: unit.bookId, mode: unit.mode.rawValue,
            rows: unit.sourceLineIndices.count, milliseconds: milliseconds)
    }

    static func main() async throws {
        let input = try JSONDecoder().decode(Input.self,
            from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
        let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        var report = Report()
        func save() throws {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(report).write(to: output.appendingPathComponent("RESULT.json"))
        }
        do {
            let shared = try Owner(uri: input.uri)
            let smallBooks = input.books.filter { [103, 28, 3152].contains($0.id) }
            try require(smallBooks.count == 3 && input.cacheBooks.count == 60, "pinned stress catalog missing")
            let overlap = Overlap()
            // Eight tasks share the ORIGINAL connection, statement cache and
            // decoder. A ninth clears service caches while those tasks execute.
            report.samples += try await withThrowingTaskGroup(of: [Sample].self) { group in
                for worker in 0..<8 {
                    group.addTask {
                        var samples: [Sample] = []
                        for iteration in 0..<12 {
                            let book = smallBooks[(worker + iteration) % smallBooks.count]
                            let mode = [OtzariaUnitMode.line, .paragraph, .chapter][iteration % 3]
                            let index = iteration % 2 == 0 ? book.first : book.middle
                            overlap.enter()
                            let started = now()
                            let unit: OtzariaReadingUnit?
                            do {
                                unit = try shared.reader.readingUnit(bookId: book.id, containingLineIndex: index, mode: mode)
                            } catch { overlap.leave(); throw error }
                            overlap.leave()
                            guard let unit else { throw StressFailure(description: "shared read returned nil") }
                            samples.append(try record(unit, name: "shared-\(worker)-\(iteration)",
                                milliseconds: (now() - started) * 1_000, output: output))
                            await Task.yield()
                        }
                        return samples
                    }
                }
                group.addTask {
                    for _ in 0..<24 { shared.reader.clearCaches(); try await Task.sleep(for: .milliseconds(2)) }
                    return []
                }
                var result: [Sample] = []
                for try await samples in group { result += samples }
                return result
            }
            report.sharedMaximumOverlap = overlap.maximum
            try require(overlap.maximum >= 2, "shared readers did not overlap")
            report.cacheSnapshots.append(try CacheSnapshot(shared.reader))
            print("PASS shared connection: 96 real Reader outputs with overlapping cache clears")
            try save()

            let independentOverlap = Overlap()
            report.samples += try await withThrowingTaskGroup(of: [Sample].self) { group in
                for worker in 0..<4 {
                    group.addTask {
                        let owner = try Owner(uri: input.uri)
                        var result: [Sample] = []
                        for iteration in 0..<6 {
                            let book = smallBooks[(worker + iteration) % smallBooks.count]
                            independentOverlap.enter()
                            let started = now()
                            let unit: OtzariaReadingUnit?
                            do { unit = try owner.reader.readingUnit(bookId: book.id,
                                containingLineIndex: book.middle, mode: .paragraph) }
                            catch { independentOverlap.leave(); throw error }
                            independentOverlap.leave()
                            guard let unit else { throw StressFailure(description: "independent read returned nil") }
                            result.append(try record(unit, name: "independent-\(worker)-\(iteration)",
                                milliseconds: (now() - started) * 1_000, output: output))
                        }
                        return result
                    }
                }
                var result: [Sample] = []
                for try await samples in group { result += samples }
                return result
            }
            report.independentMaximumOverlap = independentOverlap.maximum
            try require(independentOverlap.maximum >= 2, "independent readers did not overlap")
            print("PASS four independent read-only connections and decoders: 24 real Reader outputs")

            shared.reader.clearCaches()
            for book in input.cacheBooks {
                for mode in [OtzariaUnitMode.paragraph, .chapter] {
                    let descriptor = try shared.reader.firstDescriptor(bookId: book.id, mode: mode)
                    try require(descriptor != nil, "cache fill did not use a genuine descriptor")
                    report.cacheSnapshots.append(try CacheSnapshot(shared.reader))
                }
            }
            shared.reader.clearCaches()
            let cleared = try CacheSnapshot(shared.reader)
            try require(cleared.indexEntries == 0 && cleared.summariesEntries == 0 &&
                cleared.indexCost == 0 && cleared.summariesCost == 0 && !cleared.decoderPresent,
                "clearCaches retained source cache state")
            report.cacheSnapshots.append(cleared)

            // Suspend at an actual SQLite VM boundary while an old-generation
            // index is loading, clear the caches, then allow the original call
            // to finish. Only cache publication is tested; this is not a UI swap.
            let generationOwner = try Owner(uri: input.uri)
            let gate = SQLProbe(blockAtProgress: 1)
            gate.install(on: generationOwner)
            let generationTask = Task.detached {
                try generationOwner.reader.firstDescriptor(bookId: 28, mode: .paragraph)
            }
            try await waitFor { gate.state.tripped }
            generationOwner.reader.clearCaches()
            gate.resume()
            _ = try await generationTask.value
            gate.uninstall(from: generationOwner)
            try require(!gate.state.timedOut, "generation barrier timed out")
            let generationSnapshot = try CacheSnapshot(generationOwner.reader)
            try require(generationSnapshot.indexEntries == 0 && generationSnapshot.summariesEntries == 0,
                "old generation repopulated cleared caches")
            report.clearDuringActiveQueryGeneration = [0, generationSnapshot.generation]
            print("PASS source cache capacities, budgets, clear and in-flight generation publication fence")
            try save()

            let preStart = DispatchSemaphore(value: 0)
            let preCancelled = Task.detached { () throws -> Bool in
                _ = preStart.wait(timeout: .now() + 10)
                return try shared.reader.readingUnit(bookId: 28, containingLineIndex: 0, mode: .line) != nil
            }
            preCancelled.cancel(); preStart.signal()
            do { _ = try await preCancelled.value; throw StressFailure(description: "pre-cancelled task returned content") }
            catch is CancellationError { report.preCancelledOutcome = "CancellationError; no content returned" }

            let heavyOwner = try Owner(uri: input.uri)
            guard let heavy = try heavyOwner.reader.descriptor(bookId: 5869,
                containingLineIndex: 95_380, mode: .chapter) else {
                throw StressFailure(description: "pinned large source chapter missing")
            }
            try require(heavy.sourceLineIndices.count >= 50_000, "large workload unexpectedly changed")
            // Warm schema/dictionary setup, then cancel after real rows and VM
            // instructions in the large source fetch, without sqlite3_interrupt.
            _ = try heavyOwner.reader.readingUnit(bookId: 28, containingLineIndex: 0, mode: .line)
            let cancellationProbe = SQLProbe(blockAtProgress: 5)
            cancellationProbe.install(on: heavyOwner)
            let active = Task.detached { try heavyOwner.reader.buildUnit(from: heavy) }
            try await waitFor { cancellationProbe.state.tripped }
            report.activeCancellationRowsBeforeBarrier = cancellationProbe.state.rows
            try require(cancellationProbe.state.rows > 0, "cancellation was not inside an active source read")
            let activeCancelledAt = now()
            active.cancel(); cancellationProbe.resume()
            do { _ = try await active.value; throw StressFailure(description: "active cancellation returned partial content") }
            catch is CancellationError { report.activeCancellationOutcome = "CancellationError; no partial content returned" }
            report.activeCancellationMilliseconds = (now() - activeCancelledAt) * 1_000
            cancellationProbe.uninstall(from: heavyOwner)
            try require(!cancellationProbe.state.timedOut, "cancellation barrier timed out")
            _ = try heavyOwner.reader.readingUnit(bookId: 28, containingLineIndex: 0, mode: .line)
            print("PASS active cancellation and same-connection recovery after \(report.activeCancellationRowsBeforeBarrier) actual rows")

            // A natural large decode owns SQLiteDatabase's lock. Cancel a second
            // reader while it waits; report latency honestly, without a pause or
            // a claim that the lock wait is cancellable or runs off MainActor.
            let naturalProbe = SQLProbe()
            naturalProbe.install(on: heavyOwner)
            let heavyStarted = now()
            let heavyTask = Task.detached { try heavyOwner.reader.buildUnit(from: heavy) }
            try await waitFor { naturalProbe.state.rows > 0 }
            let queuedStarted = DispatchSemaphore(value: 0)
            let queued = Task.detached { () throws -> OtzariaReadingUnit? in
                queuedStarted.signal()
                return try heavyOwner.reader.readingUnit(bookId: 28, containingLineIndex: 0, mode: .line)
            }
            try require(queuedStarted.wait(timeout: .now() + 5) == .success, "queued reader did not start")
            try await Task.sleep(for: .milliseconds(20))
            let queuedCancelledAt = now()
            queued.cancel()
            do { _ = try await queued.value; throw StressFailure(description: "queued cancelled reader returned content") }
            catch is CancellationError { report.queuedCancellationOutcome = "CancellationError; no content returned" }
            report.queuedCancellationMilliseconds = (now() - queuedCancelledAt) * 1_000
            guard let heavyUnit = try await heavyTask.value else { throw StressFailure(description: "large source unit missing") }
            naturalProbe.uninstall(from: heavyOwner)
            report.samples.append(try record(heavyUnit, name: "oversized-cache-source",
                milliseconds: (now() - heavyStarted) * 1_000, output: output))

            let side = OtzariaReadingUnitSideCache.shared
            side.clear()
            for book in input.cacheBooks {
                guard let unit = try shared.reader.readingUnit(bookId: book.id,
                    containingLineIndex: book.first, mode: .line) else {
                    throw StressFailure(description: "side cache real source line missing")
                }
                side.set(unit, mode: .line)
            }
            report.sideCacheEntries = try count(side, "units")
            report.sideCacheEstimatedBytes = try field(side, "currentCost") as! Int
            try require(report.sideCacheEntries == 50 && report.sideCacheEstimatedBytes <= 20 * 1024 * 1024,
                "side cache retention exceeded limits")
            let first = input.cacheBooks[0], last = input.cacheBooks[59]
            try require(side.unit(bookId: first.id, contentId: first.first, mode: .line) == nil, "LRU failed to evict oldest")
            try require(side.unit(bookId: last.id, contentId: last.first, mode: .line) != nil, "LRU dropped newest")
            report.oversizedUnitEstimatedBytes = OtzariaReadingUnitSideCache.retainedCost(of: heavyUnit)
            try require(report.oversizedUnitEstimatedBytes > 20 * 1024 * 1024, "real large unit did not exercise byte cap")
            side.set(heavyUnit, mode: heavyUnit.mode)
            report.oversizedUnitRetained = side.unit(bookId: heavyUnit.bookId,
                contentId: heavyUnit.startLineIndex, mode: heavyUnit.mode) != nil
            try require(!report.oversizedUnitRetained, "oversized actual unit was retained")
            side.clear()
            let clearedSideEntries = try count(side, "units")
            try require(clearedSideEntries == 0, "side cache clear failed")

            // Exercise the original LRU with more than 100 actual read-only
            // statements, then reuse an evicted query and verify its value.
            for index in 0..<140 {
                let values = try shared.database.fetch(query: "SELECT id FROM book WHERE id = ? /* stress \(index) */",
                    parameters: [28]) { $0.int(at: 0) }
                try require(values == [28], "statement parameters or lifetime corrupted")
            }
            report.statementCacheEntries = try count(shared.database, "statementCache")
            try require(report.statementCacheEntries == 100, "statement cache limit changed")
            let value = try shared.database.fetch(query: "SELECT id FROM book WHERE id = ? /* stress 0 */",
                parameters: [103]) { $0.int(at: 0) }
            try require(value == [103], "evicted statement returned stale binding")
            print("PASS actual side-cache LRU/20MiB rejection and 100-entry prepared-statement eviction")
            report.status = "ACTUAL_FULL_V32_STRESS_PASS_NOT_UI"
            try save()
        } catch {
            report.status = "FAILED"; report.failed = String(describing: error)
            try save()
            throw error
        }
    }
}
