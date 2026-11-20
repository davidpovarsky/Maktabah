import Foundation

@_silgen_name("otzaria_search_engine_occurrence_request_new")
private func c_occurrenceRequestNew(
    _ bytes: UnsafePointer<UInt8>?, _ length: Int,
    _ error: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
) -> UInt64
@_silgen_name("otzaria_search_engine_occurrence_request_cancel")
private func c_occurrenceRequestCancel(_ token: UInt64) -> Bool
@_silgen_name("otzaria_search_engine_occurrence_request_release")
private func c_occurrenceRequestRelease(_ token: UInt64) -> Bool
@_silgen_name("otzaria_search_engine_count_occurrences_json")
private func c_occurrenceExecute(
    _ handle: UnsafeMutableRawPointer?, _ token: UInt64
) -> UnsafeMutablePointer<CChar>?
@_silgen_name("otzaria_search_engine_free_string")
private func c_occurrenceFreeString(_ value: UnsafeMutablePointer<CChar>?)

/// Owns one C request, never the engine pointer. A queued worker retains this
/// owner until cleanup, even after its awaiting task has received cancellation.
/// All mutable state below is protected by lock; callbacks/resumes occur outside
/// it. The deadline callback captures this owner weakly.
final class OtzariaExactOccurrenceOperation: @unchecked Sendable {
    typealias Outcome = Result<OtzariaExactOccurrenceResult, OtzariaExactOccurrenceError>

    let token: UInt64
    let deadline: DispatchTime
    private let request: OtzariaExactOccurrenceRequest
    private let expectedSource: OtzariaExactOccurrenceSource
    private let lock = NSLock()
    private var continuation: CheckedContinuation<OtzariaExactOccurrenceResult, Error>?
    private var installedContinuation = false
    private var outcome: Outcome?
    private var timer: DispatchSourceTimer?
    private var released = false

    private init(
        token: UInt64,
        request: OtzariaExactOccurrenceRequest,
        expectedSource: OtzariaExactOccurrenceSource,
        deadline: DispatchTime
    ) {
        self.token = token
        self.request = request
        self.expectedSource = expectedSource
        self.deadline = deadline
    }

    static func create(
        request: OtzariaExactOccurrenceRequest,
        expectedSource: OtzariaExactOccurrenceSource,
        deadline: DispatchTime
    ) throws -> OtzariaExactOccurrenceOperation {
        let data: Data
        do { data = try JSONEncoder().encode(request) }
        catch { throw OtzariaExactOccurrenceError.invalidRequest }
        guard data.count <= 512 * 1_024 else {
            throw OtzariaExactOccurrenceError.requestTooLarge
        }
        var errorPointer: UnsafeMutablePointer<CChar>?
        let token = data.withUnsafeBytes { bytes in
            c_occurrenceRequestNew(
                bytes.bindMemory(to: UInt8.self).baseAddress, bytes.count, &errorPointer
            )
        }
        guard token != 0 else {
            let body = try consume(errorPointer)
            throw OtzariaExactOccurrenceWire.creationFailure(body)
        }
        guard errorPointer == nil else {
            c_occurrenceFreeString(errorPointer)
            _ = c_occurrenceRequestRelease(token)
            throw OtzariaExactOccurrenceError.invalidResponse
        }
        return OtzariaExactOccurrenceOperation(
            token: token, request: request, expectedSource: expectedSource, deadline: deadline
        )
    }

    deinit { releaseAfterWorker() }

    func install(_ continuation: CheckedContinuation<OtzariaExactOccurrenceResult, Error>) {
        lock.lock()
        precondition(!installedContinuation, "One continuation per occurrence operation")
        installedContinuation = true
        let ready = outcome
        if ready == nil { self.continuation = continuation }
        lock.unlock()
        if let ready { continuation.resume(with: ready.mapError { $0 as Error }) }
    }

    func startDeadlineTimer() {
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .userInitiated))
        timer.setEventHandler { [weak self] in self?.cancel(.deadlineExceeded) }
        timer.schedule(deadline: deadline)
        lock.lock()
        let keep = !released && outcome == nil
        if keep { self.timer = timer }
        lock.unlock()
        // Always balance the source's initial suspension before releasing it,
        // including cancellation that raced with installing this source.
        timer.resume()
        if !keep { timer.cancel() }
    }

    var isComplete: Bool {
        lock.lock()
        defer { lock.unlock() }
        return outcome != nil
    }

    /// Called only by the original Bridge queue while that Bridge owns handle.
    /// The pointer is used synchronously here and is never retained by this owner.
    func execute(handle: UnsafeMutableRawPointer) throws -> OtzariaExactOccurrenceResult {
        let body = try Self.consume(c_occurrenceExecute(handle, token))
        return try OtzariaExactOccurrenceWire.decode(
            body, request: request, token: token, source: expectedSource
        )
    }

    func complete(_ outcome: Outcome) { finish(outcome, cancelNative: false) }

    func cancel(_ failure: OtzariaExactOccurrenceError) {
        finish(.failure(failure), cancelNative: true)
    }

    private func finish(_ proposed: Outcome, cancelNative: Bool) {
        lock.lock()
        guard outcome == nil else { lock.unlock(); return }
        let expired = DispatchTime.now().uptimeNanoseconds >= deadline.uptimeNanoseconds
        let selected: Outcome
        if case .success = proposed, expired {
            selected = .failure(.deadlineExceeded)
        } else {
            selected = proposed
        }
        outcome = selected
        let continuation = self.continuation
        self.continuation = nil
        let timer = self.timer
        self.timer = nil
        lock.unlock()

        if cancelNative || expired { _ = c_occurrenceRequestCancel(token) }
        timer?.cancel()
        continuation?.resume(with: selected.mapError { $0 as Error })
    }

    /// Only an unqueued rejection or the completing queue worker calls this.
    /// cancel()/deadline delivery never releases the capacity reservation.
    func releaseAfterWorker() {
        cancel(.internalError)
        lock.lock()
        guard !released else { lock.unlock(); return }
        released = true
        let timer = self.timer
        self.timer = nil
        lock.unlock()
        timer?.cancel()
        _ = c_occurrenceRequestRelease(token)
    }

    private static func consume(_ raw: UnsafeMutablePointer<CChar>?) throws -> Data {
        guard let raw else { throw OtzariaExactOccurrenceError.invalidResponse }
        defer { c_occurrenceFreeString(raw) }
        // The real C API owns a NUL-terminated allocation. Bound decoding rather
        // than constructing an unbounded String, and free every response once.
        let maximum = 1_024 * 1_024
        var length = 0
        while length <= maximum && raw[length] != 0 { length += 1 }
        guard length <= maximum else {
            throw OtzariaExactOccurrenceError.responseTooLarge
        }
        return Data(bytes: raw, count: length)
    }
}
