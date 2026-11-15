import Foundation
import XCTest
@testable import OtzariaActionCore

final class ContractAPITests: XCTestCase {
    func testWirePositionAndSendableAPI() throws {
        let reference = ActionTextRef(backend: .otzaria, workKey: "book:103", position: .legacyLine(42))
        let json = try ActionJSON.encoded(reference)
        XCTAssertEqual(json.object?["position"], .object(["kind": .string("legacyLine"), "value": .integer(42)]))
        XCTAssertEqual(try json.decoded(as: ActionTextRef.self), reference)
        func requireSendable<T: Sendable>(_: T) {}
        requireSendable(reference)
        requireSendable(ActionRequest(action: "system.listBackends"))
    }
    func testPositionKindValueMismatchRejected() throws {
        for value in [#"{"kind":"legacyLine","value":"42"}"#, #"{"kind":"canonicalRef","value":42}"#, #"{"kind":"legacyLine","value":true}"#] {
            XCTAssertThrowsError(try JSONDecoder().decode(ActionTextPosition.self, from: Data(value.utf8)))
        }
    }
}
