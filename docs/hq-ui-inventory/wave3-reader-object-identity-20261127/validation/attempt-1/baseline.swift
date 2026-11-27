import Foundation
import XCTest

final class IdentityGuardTests: XCTestCase, @unchecked Sendable {
    private struct Rejected: Error { let reason: String }
    private func demand(_ value: @autoclosure () -> Bool, _ reason: String) throws {
        guard value() else { XCTFail(reason); throw Rejected(reason: reason) }
    }
    private func fixture() throws -> ([String: Any], [String: Any]) {
        let path = try XCTUnwrap(ProcessInfo.processInfo.environment["READER_IDENTITY_FIXTURE_PATH"])
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path))) as? [String: Any])
        return (try XCTUnwrap(object["selection"] as? [String: Any]),
                try XCTUnwrap(object["report"] as? [String: Any]))
    }
    func testOriginalFreshRequestOwner() throws {
        let (selection, report) = try fixture()
        try demand(selection["textViewObject"] as? Int == report["object"] as? Int
            && selection["usesTextKit2BeforeObservation"] as? Bool == true
            && selection["usesTextKit2AfterObservation"] as? Bool == true
            && report["usesTextKit2BeforeObservation"] as? Bool == true
            && report["usesTextKit2AfterObservation"] as? Bool == true,
            "Observe one unchanged original TextKit 2 owner")
    }
    func testOriginalHeldGestureOwner() throws {
        let (selection, report) = try fixture()
        let request = "276BFED7-ACCF-42E9-A8D0-139FF36B25E2"
        let pid = 271127
        var requests = Set<String>()
            try demand(UUID(uuidString: request) != nil && requests.insert(request).inserted
                && selection["requestID"] as? String == request && selection["processID"] as? Int == pid
                && selection["textViewObject"] as? Int == report["object"] as? Int
                && selection["usesTextKit2BeforeObservation"] as? Bool == true
                && selection["usesTextKit2AfterObservation"] as? Bool == true,
                "Use fresh actual native samples from this original Reader/process during the real held gesture")
    }
}
@main
enum IdentityGuardRunner {
    static func main() {
        XCTMain([testCase([
            ("testOriginalFreshRequestOwner", IdentityGuardTests.testOriginalFreshRequestOwner),
            ("testOriginalHeldGestureOwner", IdentityGuardTests.testOriginalHeldGestureOwner)
        ])])
    }
}
