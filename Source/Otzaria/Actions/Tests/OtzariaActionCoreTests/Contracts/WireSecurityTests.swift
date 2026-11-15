import Foundation
import XCTest
@testable import OtzariaActionCore

final class WireSecurityTests: XCTestCase {
    let prefix = #"{"apiVersion":1,"requestId":"00000000-0000-4000-8000-000000000001","action":"system.listBackends","arguments":{}}"#
    func testDuplicateDecodedKeysRejected() throws {
        for json in [
            prefix.replacingOccurrences(of: #""action":"system.listBackends""#, with: #""action":"system.listBackends","action":"notes.saveDraft""#),
            prefix.replacingOccurrences(of: #""apiVersion":1"#, with: #""apiVersion":1,"apiVersion":2"#),
            prefix.replacingOccurrences(of: #""action":"system.listBackends""#, with: #""action":"system.listBackends","act\u0069on":"notes.saveDraft""#),
            prefix.replacingOccurrences(of: #""arguments":{}"#, with: #""arguments":{"includeModes":true,"includeModes":false}"#)
        ] {
            XCTAssertThrowsError(try ActionWireCodec.decodeRequest(Data(json.utf8))) { XCTAssertEqual($0 as? ActionContractError, .duplicateKey) }
        }
    }
    func testEnvelopeTypeBoundsAndUnknownFields() throws {
        let replacements = [
            (#""apiVersion":1"#, #""apiVersion":true"#),
            (#""apiVersion":1"#, #""apiVersion":2"#),
            (#""arguments":{}"#, #""arguments":{},"scopes":["notes.write"]"#),
            (#""arguments":{}"#, #""arguments":{},"expectedGeneration":true"#),
            (#""arguments":{}"#, #""arguments":{},"expectedGeneration":0.5"#),
            (#""arguments":{}"#, #""arguments":{},"expectedBackend":"sefariaLegacy""#),
            (#""arguments":{}"#, #""arguments":{},"expectedBackend":null"#),
            (#""arguments":{}"#, #""arguments":{},"deadlineMs":99"#),
            (#""arguments":{}"#, #""arguments":{},"deadlineMs":60001"#),
            (#""arguments":{}"#, #""arguments":{},"expectedGeneration":18446744073709551616"#)
        ]
        for (from, to) in replacements { XCTAssertThrowsError(try ActionWireCodec.decodeRequest(Data(prefix.replacingOccurrences(of: from, with: to).utf8)), to) }
        let max = prefix.replacingOccurrences(of: #""arguments":{}"#, with: #""arguments":{},"expectedGeneration":18446744073709551615"#)
        XCTAssertEqual(try ActionWireCodec.decodeRequest(Data(max.utf8)).expectedGeneration, UInt64.max)
        XCTAssertThrowsError(try JSONDecoder().decode(ActionRequest.self, from: Data(prefix.replacingOccurrences(of: #""arguments":{}"#, with: #""arguments":{},"origin":"inApp""#).utf8)))
    }
    func testByteDepthAndInvalidGrammarBudgets() throws {
        XCTAssertThrowsError(try ActionWireCodec.decodeRequest(Data(repeating: 32, count: 65_537)))
        let nested = String(repeating: "[", count: 30) + "0" + String(repeating: "]", count: 30)
        XCTAssertThrowsError(try ActionWireCodec.decodeRequest(Data(prefix.replacingOccurrences(of: #""arguments":{}"#, with: #""arguments":{"value":\#(nested)}"#).utf8)))
        let nodes = "[" + Array(repeating: "0", count: 10_001).joined(separator: ",") + "]"
        XCTAssertThrowsError(try ActionWireCodec.decodeRequest(Data(prefix.replacingOccurrences(of: #""arguments":{}"#, with: #""arguments":{"value":\#(nodes)}"#).utf8))) {
            XCTAssertEqual($0 as? ActionContractError, .inputTooLarge)
        }
        for text in [prefix + "{}", prefix + " NaN", prefix.replacingOccurrences(of: ":1,", with: ":01,"), prefix.replacingOccurrences(of: ":1,", with: ":1e999,")] {
            XCTAssertThrowsError(try ActionWireCodec.decodeRequest(Data(text.utf8)))
        }
    }
    func testFrozenCatalogAndElevenExamplesProject() throws {
        let registry = try ActionRegistry()
        XCTAssertEqual(registry.descriptors.count, 29)
        XCTAssertEqual(ActionRegistry.implemented.count, 5)
        let examples = try JSONDecoder().decode(ActionJSON.self, from: ActionRegistry.resource("examples.v1.json"))
        let cases = try XCTUnwrap(examples.object?["cases"]?.array)
        XCTAssertEqual(cases.count, 11)
        for fixture in cases {
            let requestJSON = try XCTUnwrap(fixture.object?["request"])
            let request = try ActionWireCodec.decodeRequest(JSONEncoder().encode(requestJSON))
            _ = try ActionValidation.request(request, registry: registry)
            let resultJSON = try XCTUnwrap(fixture.object?["result"])
            try ActionSchemaValidator.validate(resultJSON, schema: ActionRegistry.schema("action-result.v1.schema.json"))
            let result = try resultJSON.decoded(as: ActionResult.self)
            // UUID textual case is immaterial; preserve all other wire fields.
            var expected = try XCTUnwrap(resultJSON.object)
            var actual = try XCTUnwrap(ActionJSON.encoded(result).object)
            XCTAssertEqual(UUID(uuidString: try XCTUnwrap(expected.removeValue(forKey: "requestId")?.string)), result.requestId)
            actual.removeValue(forKey: "requestId")
            XCTAssertEqual(actual, expected)
        }
    }
    func testExactNumericTokenClassificationBeforeFoundationCoercion() throws {
        for token in ["1.000000000000000000000000000000000000001", "1e-999", "9007199254740993.1"] {
            let key = token.hasPrefix("1.000") ? "apiVersion" : "expectedGeneration"
            let json = key == "apiVersion" ? prefix.replacingOccurrences(of: #""apiVersion":1"#, with: "\"apiVersion\":\(token)")
                : prefix.replacingOccurrences(of: #""arguments":{}"#, with: "\"arguments\":{},\"expectedGeneration\":\(token)")
            XCTAssertThrowsError(try ActionWireCodec.decodeRequest(Data(json.utf8)), token)
        }
        for (token, expected) in [("90071992547409930e-1", UInt64(9_007_199_254_740_993)), ("18446744073709551615.000", UInt64.max), ("1.0e2", UInt64(100))] {
            let json = prefix.replacingOccurrences(of: #""arguments":{}"#, with: "\"arguments\":{},\"expectedGeneration\":\(token)")
            XCTAssertEqual(try ActionWireCodec.decodeRequest(Data(json.utf8)).expectedGeneration, expected)
        }
        for token in ["1.0", "10e-1", "0.1e1"] {
            let json = prefix.replacingOccurrences(of: #""apiVersion":1"#, with: "\"apiVersion\":\(token)")
            XCTAssertEqual(try ActionWireCodec.decodeRequest(Data(json.utf8)).apiVersion, 1)
        }
        let registry = try ActionRegistry()
        for (action, field) in [("search.query", "offset"), ("search.query", "limit"), ("search.query", "wordDistance")] {
            let json = "{\"apiVersion\":1,\"requestId\":\"00000000-0000-4000-8000-000000000001\",\"action\":\"\(action)\",\"arguments\":{\"text\":\"fixture\",\"\(field)\":1.000000000000000000000000000000000000001}}"
            let parsed = try ActionWireCodec.decodeRequest(Data(json.utf8))
            XCTAssertThrowsError(try ActionValidation.request(parsed, registry: registry), "fractional argument classification must survive DTO construction")
        }
    }
    func testWireKeysDoNotAcquireUnicodeNormalizationAliases() throws {
        let alias = "idempotency\u{212A}ey"
        XCTAssertEqual(alias, "idempotencyKey") // Actual Swift canonical equality.
        XCTAssertNotEqual(Array(alias.utf8), Array("idempotencyKey".utf8))
        let json = prefix.replacingOccurrences(of: #""arguments":{}"#, with: "\"arguments\":{},\"\(alias)\":\"fixture-key-1234567890\"")
        XCTAssertThrowsError(try ActionWireCodec.decodeRequest(Data(json.utf8)))
        let nested = ActionRequest(action: "catalog.resolveWork", arguments: ["workRef": .object([
            "backend": .string("otzaria"), "work\u{212A}ey": .string("fixture:work")])])
        XCTAssertThrowsError(try ActionValidation.request(nested, registry: ActionRegistry()))
    }
}
