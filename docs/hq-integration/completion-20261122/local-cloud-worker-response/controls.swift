import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
enum ControlFailure: Error { case invariant(String) }
enum TransportProbeError: Error, Equatable { case offline }
func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw ControlFailure.invariant(message) }
}
func response(_ status: Int) -> HTTPURLResponse {
    HTTPURLResponse(url: URL(string: "https://qualification.invalid/worker")!,
                    statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
}
@main struct WorkerResponseControls {
    static func main() async throws {
        var passed: [String] = []
        let before = await originalCompletion(response: response(500), error: nil)
        guard case .success = before else { throw ControlFailure.invariant("expected original observed false success for HTTP500") }
        for status in [200, 202, 204, 299] {
            guard case .success = AnnotationLocalEditorCloudWorkerResponse.result(response: response(status), error: nil) else {
                throw ControlFailure.invariant("successful worker HTTP status refused: \(status)")
            }
            passed.append("http_\(status)_accepted")
        }
        for status in [199, 300, 401, 403, 429, 500, 503] {
            let outcome = AnnotationLocalEditorCloudWorkerResponse.result(response: response(status), error: nil)
            guard case .failure(let error) = outcome else {
                throw ControlFailure.invariant("rejected worker HTTP status accepted: \(status)")
            }
            try require(error as? AnnotationLocalEditorCloudWorkerResponse.Failure == .httpStatus(status),
                        "actual HTTP rejection status lost")
            passed.append("http_\(status)_failure_retained")
        }
        for (label, observed) in [
            ("missing", nil as URLResponse?),
            ("non_http", URLResponse(url: URL(string: "https://qualification.invalid/worker")!,
                                    mimeType: "application/octet-stream", expectedContentLength: 0, textEncodingName: nil))
        ] {
            guard case .failure(let error) = AnnotationLocalEditorCloudWorkerResponse.result(response: observed, error: nil) else {
                throw ControlFailure.invariant("missing HTTP result accepted")
            }
            try require(error as? AnnotationLocalEditorCloudWorkerResponse.Failure == .missingHTTPResponse,
                        "missing HTTP response category lost")
            passed.append(label + "_response_refused")
        }
        for status in [200, 500] {
            let outcome = AnnotationLocalEditorCloudWorkerResponse.result(response: response(status), error: TransportProbeError.offline)
            guard case .failure(let error) = outcome else { throw ControlFailure.invariant("transport error became HTTP success") }
            try require(error as? TransportProbeError == .offline, "original transport error replaced")
            passed.append("transport_error_preserved_with_http_\(status)")
        }
        guard case .failure(let cancellation) = AnnotationLocalEditorCloudWorkerResponse.result(response: nil, error: CancellationError()),
              cancellation is CancellationError else { throw ControlFailure.invariant("actual cancellation replaced") }
        passed.append("original_cancellation_preserved")
        let report: [String: Any] = ["schema": 1, "baseline_http500": "WRONG_SUCCESS_REPRODUCED_FROM_ORIGINAL_CALLBACK",
            "after": "PASS", "count": passed.count, "passed": passed,
            "scope": "exact extracted production classifier and real Foundation URLResponse/HTTPURLResponse; no network or CloudKit"]
        print(String(data: try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]), encoding: .utf8)!)
    }
}
