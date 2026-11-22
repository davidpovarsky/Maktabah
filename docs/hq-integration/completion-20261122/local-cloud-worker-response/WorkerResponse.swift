import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Transport completion for the existing optional worker notification only.
/// HTTP rejection is an actual failure even when URLSession has no error.
/// No response URL, body, account identity or configured request is diagnosed.
enum AnnotationLocalEditorCloudWorkerResponse {
    enum Failure: Error, Sendable, Equatable {
        case missingHTTPResponse
        case httpStatus(Int)
    }

    static func result(response: URLResponse?, error: (any Error)?) -> Result<Void, any Error> {
        if let error { return .failure(error) }
        guard let response = response as? HTTPURLResponse else {
            return .failure(Failure.missingHTTPResponse)
        }
        guard (200..<300).contains(response.statusCode) else {
            return .failure(Failure.httpStatus(response.statusCode))
        }
        return .success(())
    }
}

