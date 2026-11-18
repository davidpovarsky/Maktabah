import Foundation
import XCTest
import OtzariaActionCore
import OtzariaUIRouting
@testable import ChavrusaUIRoutingHost

final class NativePublicNavigationURLV2Tests: XCTestCase {
    private func registry() throws -> UIDestinationRegistry {
        try .init(descriptors: [
            .init(id: .init(rawValue: "native.reader")!, title: "Reader", implementation: .implemented,
                  supportedBackends: ActionBackendID.allCases, presentations: [.currentTab],
                  requiredCoreActions: ["reader.open"], requiresContent: true,
                  publicNavigationV2: .init(rules: [.init(presentation: .currentTab)]))
        ])
    }
    private func intent(_ backend: ActionBackendID = .otzaria) -> PublicNavigationSpecV2 {
        let ref = ActionTextRef(backend: backend, workKey: backend == .otzaria ? "book:1" : "Genesis",
                                position: backend == .otzaria ? .legacyLine(7) : .canonicalRef("Genesis 1"))
        return .init(destination: .init(rawValue: "native.reader")!, backend: backend,
                     content: .init(sectionLocator: ref, focusLocator: backend == .otzaria ? ref : nil))
    }
    func testExactReferenceRoundTripAllBackendsAndExplicitSchemes() throws {
        let registry = try registry()
        for backend in ActionBackendID.allCases {
            for scheme in ["maktabah", "maktabah-debug"] {
                let original = intent(backend), url = try NativePublicNavigationURLV2.encode(original, scheme: scheme, registry: registry)
                XCTAssertEqual(try NativePublicNavigationURLV2.decode(url, scheme: scheme, registry: registry), original)
                XCTAssertThrowsError(try NativeRouteURL.decode(url, scheme: scheme, registry: registry))
            }
        }
    }
    func testV1PayloadRelabelledV2RemainsRejected() throws {
        let bytes = try JSONSerialization.data(withJSONObject: ["version": 1, "requestId": UUID().uuidString,
            "destination": "native.reader", "backend": "otzaria", "presentation": "currentTab"])
        XCTAssertThrowsError(try NativePublicNavigationURLV2.decode(envelope(bytes), registry: registry()))
    }
    func testLocalAuthorityAndUnknownFieldsCannotCrossPublicBoundary() throws {
        let encoded = try UIRouteCodec.encodePublicV2(intent(), registry: registry())
        for (key, value) in [("sceneID", "foreign"), ("requestId", UUID().uuidString),
                             ("tabID", "foreign"), ("permissions", "all"), ("query", "private")] {
            var fields = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
            fields[key] = value
            XCTAssertThrowsError(try NativePublicNavigationURLV2.decode(envelope(JSONSerialization.data(withJSONObject: fields)), registry: registry()))
        }
    }
    func testNoncanonicalEnvelopeAndConflictingDestinationAreRejected() throws {
        let registry = try registry(), base = try NativePublicNavigationURLV2.encode(intent(), registry: registry).absoluteString
        for value in [base + "&route=x", base + "#fragment", base + "=", base + "&backend=sefaria",
                      base.replacingOccurrences(of: "native.reader?", with: "native.settings?"),
                      base.replacingOccurrences(of: "//action", with: "//user@action"),
                      base.replacingOccurrences(of: "//action", with: "//action:80"),
                      base.replacingOccurrences(of: "/v2/", with: "//v2/"),
                      base.replacingOccurrences(of: "/v2/", with: "/v1/")] {
            XCTAssertThrowsError(try NativePublicNavigationURLV2.decode(URL(string: value)!, registry: registry))
        }
    }
    func testUninstalledVariantAndRegistryNeverBecomeAvailableByDecode() throws {
        let original = intent(), registry = try registry()
        let newTab = PublicNavigationSpecV2(destination: original.destination, backend: original.backend,
            content: .init(sectionLocator: original.content!.sectionLocator, focusLocator: original.content!.focusLocator, presentationMode: .newTab),
            presentation: .newTab)
        XCTAssertThrowsError(try NativePublicNavigationURLV2.encode(newTab, registry: registry))
        let url = try NativePublicNavigationURLV2.encode(original, registry: registry)
        XCTAssertThrowsError(try NativePublicNavigationURLV2.decode(url, registry: .init()))
        XCTAssertThrowsError(try NativePublicNavigationURLV2.encode(original, scheme: "https", registry: registry))
    }
    private func envelope(_ bytes: Data) -> URL {
        let token = bytes.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        return URL(string: "maktabah://action/v2/native.reader?route=" + token)!
    }
}
