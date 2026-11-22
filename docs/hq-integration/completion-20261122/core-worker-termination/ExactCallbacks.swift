import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Synchronization
import Dispatch

struct WorkerCallbackProbe {
    let error: (any Error)?
    let signaledOnce: Bool
}

func originalWorkerCallback(response: URLResponse?, error: (any Error)?) -> WorkerCallbackProbe {
    let semaphore = DispatchSemaphore(value: 0)
    let errorState = Mutex<(any Error)?>(nil)
    let callback: @Sendable (Data?, URLResponse?, (any Error)?) -> Void = { _, _, error in
            errorState.withLock { $0 = error }
            semaphore.signal()
        }
    callback(nil, response, error)
    let first = semaphore.wait(timeout: .now())
    let second = semaphore.wait(timeout: .now())
    return WorkerCallbackProbe(error: errorState.withLock { $0 }, signaledOnce: first == .success && second == .timedOut)
}

func candidateWorkerCallback(response: URLResponse?, error: (any Error)?) -> WorkerCallbackProbe {
    let semaphore = DispatchSemaphore(value: 0)
    let errorState = Mutex<(any Error)?>(nil)
    let callback: @Sendable (Data?, URLResponse?, (any Error)?) -> Void = { _, response, error in
            if case .failure(let failure) = AnnotationLocalEditorCloudWorkerResponse.result(
                response: response, error: error
            ) {
                errorState.withLock { $0 = failure }
            }
            semaphore.signal()
        }
    callback(nil, response, error)
    let first = semaphore.wait(timeout: .now())
    let second = semaphore.wait(timeout: .now())
    return WorkerCallbackProbe(error: errorState.withLock { $0 }, signaledOnce: first == .success && second == .timedOut)
}

