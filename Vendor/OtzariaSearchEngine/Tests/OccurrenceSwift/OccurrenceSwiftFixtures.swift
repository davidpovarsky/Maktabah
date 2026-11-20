import Foundation

struct OccurrenceTestFailure: Error, CustomStringConvertible, Sendable {
    let description: String
}

func requireOccurrence(_ condition: Bool, _ message: String) throws {
    if !condition { throw OccurrenceTestFailure(description: message) }
}

/// Every index path is created here; there is no caller/user index parameter.
final class OccurrenceFixtureRegistry: @unchecked Sendable {
    static let shared = OccurrenceFixtureRegistry()
    private let lock = NSLock()
    private var directories: [URL] = []

    func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "otzaria-occurrence-swift-\(UUID().uuidString)", isDirectory: true
        )
        guard !FileManager.default.fileExists(atPath: directory.path) else {
            throw OccurrenceTestFailure(description: "Owned fixture UUID unexpectedly exists")
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        try Data("otzaria-occurrence-swift-disposable-v1\n".utf8)
            .write(to: directory.appendingPathComponent("OWNER"))
        lock.withLock { directories.append(directory) }
        return directory
    }

    func removeAll() -> [String] {
        let owned = lock.withLock { directories }
        var failures: [String] = []
        for directory in owned {
            do {
                let marker = try Data(contentsOf: directory.appendingPathComponent("OWNER"))
                guard marker == Data("otzaria-occurrence-swift-disposable-v1\n".utf8) else {
                    throw OccurrenceTestFailure(description: "Owned fixture marker mismatch")
                }
                try FileManager.default.removeItem(at: directory)
            } catch {
                failures.append("\(directory.path): \(error)")
            }
        }
        return failures
    }
}

final class OccurrenceFixture: @unchecked Sendable {
    let directory: URL
    let engine: OtzariaSearchEngineBridge

    init(text: String = "משה משה") throws {
        directory = try OccurrenceFixtureRegistry.shared.makeDirectory()
        engine = try OtzariaSearchEngineBridge(indexURL: directory.appendingPathComponent("index"))
        try add(id: 1, text: text, author: "a")
        try engine.commit()
    }

    func add(id: UInt32, text: String, author: String) throws {
        try engine.addTextBook(
            title: "Original Swift fixture \(id)", topics: "/fixtures",
            filePath: "otzaria-book:\(id)", catalogueOrder: id, generationOrder: 5,
            text: text, extraFacets: ["/book/\(id)", "/author/\(author)"]
        )
    }

    deinit { engine.close() }
}

/// A bounded blocking wait runs on a dispatch worker, never on the awaiting
/// Swift task. Its absolute deadline is evaluated by the caller before enqueue.
func occurrenceWait(
    _ semaphore: DispatchSemaphore, deadline: DispatchTime
) async -> Bool {
    await withCheckedContinuation { continuation in
        DispatchQueue.global(qos: .userInitiated).async {
            continuation.resume(returning: semaphore.wait(timeout: deadline) == .success)
        }
    }
}

func occurrenceEventually(
    deadline: DispatchTime, _ condition: @escaping @Sendable () -> Bool
) async throws {
    while !condition() {
        guard DispatchTime.now().uptimeNanoseconds < deadline.uptimeNanoseconds else {
            throw OccurrenceTestFailure(description: "Bounded observation deadline elapsed")
        }
        try await Task<Never, Never>.sleep(nanoseconds: 1_000_000)
    }
}

final class OccurrenceQueueBarrier: @unchecked Sendable {
    let entered = DispatchSemaphore(value: 0)
    let exited = DispatchSemaphore(value: 0)
    private let releaseSignal = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var released = false
    private var timedOut = false

    /// Called only from a synchronous original engine-queue scheduling hook.
    func block() {
        entered.signal()
        let expired = releaseSignal.wait(timeout: .now() + .seconds(8)) != .success
        lock.withLock { timedOut = expired }
        exited.signal()
    }

    func release() {
        let signal = lock.withLock {
            guard !released else { return false }
            released = true
            return true
        }
        if signal { releaseSignal.signal() }
    }

    func assertDidNotTimeOut() throws {
        try requireOccurrence(!lock.withLock({ timedOut }), "Queue fixture barrier timed out")
    }
}

enum ObservedOccurrence: Sendable {
    case success(OtzariaExactOccurrenceResult)
    case failure(OtzariaExactOccurrenceError)
    case unexpected(String)
}

final class OccurrenceObservation: @unchecked Sendable {
    let completed = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var result: ObservedOccurrence?

    func store(_ value: ObservedOccurrence) {
        lock.withLock {
            precondition(result == nil, "Test task completed more than once")
            result = value
        }
        completed.signal()
    }

    func value() throws -> ObservedOccurrence {
        guard let result = lock.withLock({ result }) else {
            throw OccurrenceTestFailure(description: "Task completion was not observed")
        }
        return result
    }

    func requireFailure(_ expected: OtzariaExactOccurrenceError) throws {
        guard case .failure(let actual) = try value(), actual == expected else {
            throw OccurrenceTestFailure(description: "Expected fixed failure \(expected), observed \(try value())")
        }
    }

    func requireCount(_ expected: UInt64) throws -> OtzariaExactOccurrenceResult {
        guard case .success(let result) = try value(), result.occurrences == expected else {
            throw OccurrenceTestFailure(description: "Expected count \(expected), observed \(try value())")
        }
        return result
    }
}

func launchOccurrence(
    engine: OtzariaSearchEngineBridge,
    request: OtzariaExactOccurrenceRequest,
    source: OtzariaExactOccurrenceSource
) -> (Task<Void, Never>, OccurrenceObservation) {
    let observation = OccurrenceObservation()
    let task = Task {
        do {
            observation.store(.success(try await engine.countExactTokenOccurrences(
                request: request, expectedSource: source
            )))
        } catch let failure as OtzariaExactOccurrenceError {
            observation.store(.failure(failure))
        } catch {
            observation.store(.unexpected(String(describing: error)))
        }
    }
    return (task, observation)
}

func expectOccurrenceFailure(
    _ expected: OtzariaExactOccurrenceError,
    operation: @escaping @Sendable () async throws -> OtzariaExactOccurrenceResult
) async throws {
    do {
        _ = try await operation()
        throw OccurrenceTestFailure(description: "Unexpected successful occurrence scalar")
    } catch let actual as OtzariaExactOccurrenceError {
        try requireOccurrence(actual == expected, "Expected \(expected), received \(actual)")
    }
}

struct OccurrenceCaseRecord: Codable, Sendable {
    let name: String
    let category: String
    let passed: Bool
    let seconds: Double
    let detail: String?
}

struct OccurrenceTestRunner {
    var records: [OccurrenceCaseRecord] = []

    mutating func run(
        _ name: String,
        category: String,
        _ body: @escaping @Sendable () async throws -> Void
    ) async {
        let started = Date()
        do {
            try await body()
            records.append(.init(name: name, category: category, passed: true,
                                 seconds: Date().timeIntervalSince(started), detail: nil))
            print("PASS \(name)")
        } catch {
            records.append(.init(name: name, category: category, passed: false,
                                 seconds: Date().timeIntervalSince(started), detail: String(describing: error)))
            print("FAIL \(name): \(error)")
        }
    }
}
