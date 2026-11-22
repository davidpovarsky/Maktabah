import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// The two original continuation statements, extracted without edits. This
// response parameter is deliberately ignored exactly as the original callback.
func originalCompletion(response: URLResponse?, error: (any Error)?) async -> Result<Void, any Error> {
    await withCheckedContinuation { continuation in
                    if let error { continuation.resume(returning: .failure(error)) }
                    else { continuation.resume(returning: .success(())) }
    }
}
