import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum ControlFailure: Error { case failed(String) }

@main struct CoreWorkerTerminationControls {
    static func main() throws {
        let url = URL(string: "https://fixture.invalid/worker")!
        let accepted = HTTPURLResponse(url: url, statusCode: 204, httpVersion: nil, headerFields: nil)!
        let rejected = HTTPURLResponse(url: url, statusCode: 503, httpVersion: nil, headerFields: nil)!
        let old = originalWorkerCallback(response: rejected, error: nil)
        guard old.error == nil && old.signaledOnce else { throw ControlFailure.failed("baseline did not reproduce wrong success") }
        var names: [String] = []
        let failure = candidateWorkerCallback(response: rejected, error: nil)
        guard failure.error as? AnnotationLocalEditorCloudWorkerResponse.Failure == .httpStatus(503),
              failure.signaledOnce else { throw ControlFailure.failed("HTTP error not recorded or semaphore not signaled once") }
        names.append("http_rejection_enters_original_error_state_once")
        let success = candidateWorkerCallback(response: accepted, error: nil)
        guard success.error == nil && success.signaledOnce else { throw ControlFailure.failed("accepted response changed") }
        names.append("accepted_response_preserves_original_completion_once")
        let missing = candidateWorkerCallback(response: nil, error: nil)
        guard missing.error as? AnnotationLocalEditorCloudWorkerResponse.Failure == .missingHTTPResponse,
              missing.signaledOnce else { throw ControlFailure.failed("missing response not recorded") }
        names.append("missing_response_enters_original_error_state_once")
        let transport = NSError(domain: "owned.fixture.transport", code: 73)
        let preserved = candidateWorkerCallback(response: accepted, error: transport)
        guard let error = preserved.error, (error as NSError) === transport,
              preserved.signaledOnce else { throw ControlFailure.failed("transport error identity lost") }
        names.append("transport_error_identity_and_signal_preserved")
        let report: [String: Any] = [
            "status": "PASS_EXACT_TERMINATION_CALLBACK_WIRING", "passed": names.count,
            "cases": names, "baseline": "HTTP_503_WRONG_SUCCESS_REPRODUCED",
            "network_requests": 0, "cloudkit_runtime_executed": 0, "native_ui_executed": 0,
            "scope": "Exact original/candidate @Sendable callback closures; actual Mutex/DispatchSemaphore/Foundation responses; unchanged classifier reused"
        ]
        let bytes = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        print(String(data: bytes, encoding: .utf8)!)
    }
}
