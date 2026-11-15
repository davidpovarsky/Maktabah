import Foundation
import XCTest
import OtzariaActionCore
@testable import OtzariaUIRouting

final class CodecTests: XCTestCase {
    private func fixture(_ name: String = "private-reader-v1") throws -> Data {
        try Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")))
    }
    private func changed(_ edit: (inout ActionObject) -> Void) throws -> Data {
        var object = try ActionWireCodec.decodeObject(fixture()); edit(&object)
        return try JSONEncoder().encode(ActionJSON.object(object))
    }
    private func rejects(_ data: Data, code: String? = nil, file: StaticString = #filePath, line: UInt = #line) throws {
        let registry = try UIDestinationRegistry.fixtures()
        XCTAssertThrowsError(try UIRouteCodec.decodePrivate(data, registry: registry), file: file, line: line) { error in
            if let code { XCTAssertEqual((error as? UIRouteError)?.code, code, file: file, line: line) }
        }
    }
    func testPrivateAndPublicGoldenCodecs() throws {
        let registry = try UIDestinationRegistry.fixtures()
        let decoded = try UIRouteCodec.decodePrivate(fixture(), registry: registry)
        XCTAssertNil(decoded.migration)
        let encoded = try UIRouteCodec.encodePrivate(decoded.route.route, registry: registry)
        XCTAssertEqual(try UIRouteCodec.decodePrivate(encoded, registry: registry), decoded)
        let publicRoute = try UIRouteCodec.decodePublic(fixture("public-reader-v1"), registry: registry)
        XCTAssertEqual(publicRoute.content, decoded.route.route.content)
        XCTAssertEqual(try UIRouteCodec.decodePublic(UIRouteCodec.encodePublic(publicRoute, registry: registry), registry: registry), publicRoute)
        XCTAssertThrowsError(try UIRouteCodec.decodePublic(encoded, registry: registry))
    }
    func testRenameRemovedUnknownAndFutureVersion() throws {
        let registry = try UIDestinationRegistry.fixtures()
        let migrated = try UIRouteCodec.decodePrivate(changed { $0["version"] = .integer(0); $0["destination"] = .string("fixture.legacyReader") }, registry: registry)
        XCTAssertEqual(try UIRouteCodec.decodePrivate(fixture("legacy-reader-v0"), registry: registry), migrated)
        XCTAssertEqual(migrated.route.route.destination.rawValue, "fixture.reader")
        XCTAssertEqual(migrated.migration?.from.rawValue, "fixture.legacyReader")
        try rejects(changed { $0["version"] = .integer(0); $0["destination"] = .string("fixture.removed") }, code: "removed_destination")
        try rejects(changed { $0["version"] = .integer(0) }, code: "unknown_legacy_destination")
        try rejects(changed { $0["destination"] = .string("unknown.reader") }, code: "unknown_destination")
        try rejects(changed { $0["version"] = .integer(2) }, code: "route_version_unsupported")
        try rejects(changed { $0.removeValue(forKey: "version") }, code: "route_version_unsupported")
        try rejects(changed { $0["state"] = .object(["version": .integer(2), "visibleComponents": .array([]), "expandedComponents": .array([])]) })
    }
    func testNoArbitrarySelectorsPathsAuthorityOrUnknownKeys() throws {
        for key in ["swiftType", "selector", "viewPath", "rpcMethod", "context", "permissions", "allowed", "ready"] {
            try rejects(changed { $0[key] = .string("injected") }, code: "invalid_route_shape")
        }
        for value in ["file:///private/book", "reader.open()", "../../reader", "fixture.reader\n", "fixture.רידר"] {
            try rejects(changed { $0["destination"] = .string(value) })
        }
        try rejects(changed { $0.removeValue(forKey: "requestId") })
        try rejects(changed { $0["requestId"] = .string("invalid") })
        try rejects(changed { $0["presentation"] = .object(["kind": .string("currentTab"), "tabID": .string("/private/path")]) })
        try rejects(changed { $0["scene"] = .object(["kind": .string("specific")]) }, code: "missing_scene_id")
        try rejects(changed { $0["scene"] = .object(["kind": .string("current"), "sceneID": .string("scene-1")]) }, code: "unexpected_scene_id")
    }
    func testDuplicateExactNumberAndBoundedIngress() throws {
        let original = String(decoding: try fixture(), as: UTF8.self)
        try rejects(Data(("{\"version\":1," + original.dropFirst()).utf8), code: "invalid_route_json")
        try rejects(Data(("{\"ver\\u0073ion\":1," + original.dropFirst()).utf8), code: "invalid_route_json")
        for token in ["1.00000000000000000001", "1e-9999", "true", "-1", "null"] {
            let text = original.replacingOccurrences(of: "\"version\": 1", with: "\"version\": \(token)")
            XCTAssertNotEqual(text, original)
            try rejects(Data(text.utf8))
        }
        let tooLarge = Data(repeating: 0x20, count: UIRouteCodec.maxPrivateBytes + 1)
        try rejects(tooLarge, code: "route_too_large")
        for bad in ["[]", "null", "{", String(repeating: "[", count: 18) + "0" + String(repeating: "]", count: 18)] { try rejects(Data(bad.utf8)) }
        try rejects(changed { $0["state"] = .object(["version": .integer(1), "visibleComponents": .array(Array(repeating: .string("fixture.reader.text"), count: 33)), "expandedComponents": .array([])]) })
    }
    func testPublicRejectsPrivateStateRevisionsAndPaths() throws {
        let registry = try UIDestinationRegistry.fixtures()
        let base = try ActionWireCodec.decodeObject(fixture("public-reader-v1"))
        for key in ["state", "scene", "focus", "workspaceID", "profileID", "tabID", "query", "draftNote", "selectedText", "expectedBackendSnapshot"] {
            var object = base; object[key] = .object([:])
            XCTAssertThrowsError(try UIRouteCodec.decodePublic(JSONEncoder().encode(ActionJSON.object(object)), registry: registry), key)
        }
        for key in ["catalogRevision", "dataRevision"] {
            var object = base, content = try XCTUnwrap(base["content"]?.object), ref = try XCTUnwrap(content["sectionLocator"]?.object)
            ref[key] = .string("private-revision"); content["sectionLocator"] = .object(ref); object["content"] = .object(content)
            XCTAssertThrowsError(try UIRouteCodec.decodePublic(JSONEncoder().encode(ActionJSON.object(object)), registry: registry))
        }
        for path in ["/private/book.db", "C:\\secret.db", "file:secret", "https://secret", "book?token=secret", "book#private"] {
            var object = base, content = try XCTUnwrap(base["content"]?.object), ref = try XCTUnwrap(content["sectionLocator"]?.object)
            ref["workKey"] = .string(path); content["sectionLocator"] = .object(ref); object["content"] = .object(content)
            XCTAssertThrowsError(try UIRouteCodec.decodePublic(JSONEncoder().encode(ActionJSON.object(object)), registry: registry))
        }
        XCTAssertThrowsError(try UIRouteCodec.decodePublic(Data(repeating: 32, count: 4097), registry: registry))
    }
    func testPublicEncodingCannotBypassValidationAndNormalizesOnlyBackend() throws {
        let registry = try UIDestinationRegistry.fixtures()
        let route = try UIRouteCodec.decodePublic(fixture("public-reader-v1"), registry: registry)
        let ref = try XCTUnwrap(route.content?.sectionLocator)
        let privateRef = ActionTextRef(backend: ref.backend, workKey: ref.workKey, position: ref.position, catalogRevision: "private", dataRevision: "private")
        XCTAssertThrowsError(try UIRouteCodec.encodePublic(.init(requestId: route.requestId, destination: route.destination, content: .init(sectionLocator: privateRef)), registry: registry))
        let implicit = PublicRouteSpec(requestId: route.requestId, destination: route.destination, content: route.content)
        let normalized = try UIRouteCodec.decodePublic(UIRouteCodec.encodePublic(implicit, registry: registry), registry: registry)
        XCTAssertEqual(normalized.backend, ref.backend)
        XCTAssertEqual(normalized.content, route.content)
        XCTAssertEqual(normalized.requestId, route.requestId)
    }
    func testExactUnsignedRevisionsAndFractionalRestorationFields() throws {
        let registry = try UIDestinationRegistry.fixtures()
        let data = try changed {
            $0["scene"] = .object(["kind": .string("current"), "expectedRevision": .unsigned(UInt64.max)])
            $0["expectedBackendSnapshot"] = .object(["backend": .string("otzaria"), "generation": .unsigned(UInt64.max)])
        }
        let decoded = try UIRouteCodec.decodePrivate(data, registry: registry)
        XCTAssertEqual(decoded.route.route.scene.expectedRevision, UInt64.max)
        XCTAssertEqual(decoded.route.route.expectedBackendSnapshot?.generation, UInt64.max)
        let text = String(decoding: data, as: UTF8.self)
        try rejects(Data(text.replacingOccurrences(of: "18446744073709551615", with: "1.00000000000000000001").utf8))
    }
}
