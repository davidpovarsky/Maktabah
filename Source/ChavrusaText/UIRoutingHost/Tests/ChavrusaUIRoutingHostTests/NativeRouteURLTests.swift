import Foundation
import XCTest
import OtzariaActionCore
import OtzariaUIRouting
@testable import ChavrusaUIRoutingHost

final class NativeRouteURLTests: XCTestCase {
    private func registry() throws -> UIDestinationRegistry { try .fixtures() }
    private func route() -> PublicRouteSpec {
        PublicRouteSpec(destination: UIDestinationID(rawValue: "fixture.reader")!, backend: .otzaria,
            content: ActionReaderDestination(sectionLocator: .init(backend: .otzaria, workKey: "ספר", position: .legacyLine(7))))
    }
    func testPublicHebrewReferenceRoundTripUsesCanonicalCodec() throws {
        let input = route(), registry = try registry()
        let url = try NativeRouteURL.encode(input, registry: registry)
        XCTAssertEqual(try NativeRouteURL.decode(url, registry: registry), .route(input))
    }
    func testLegacyLinksAreDelegatedUnchanged() throws {
        for value in ["maktabah://history?bkId=103&contentId=5", "maktabah://annotation?id=17"] {
            let url = URL(string: value)!
            XCTAssertEqual(try NativeRouteURL.decode(url, registry: registry()), .legacy(url))
        }
    }
    func testDebugSchemeIsExplicitAndReleaseDoesNotAcceptIt() throws {
        let url = URL(string: "maktabah-debug://history?bkId=103")!
        XCTAssertThrowsError(try NativeRouteURL.decode(url, registry: registry()))
        XCTAssertEqual(try NativeRouteURL.decode(url, scheme: "maktabah-debug", registry: registry()), .legacy(url))
    }
    func testRejectsUnknownAndContradictoryParameters() throws {
        let registry = try registry(), url = try NativeRouteURL.encode(route(), registry: registry)
        for suffix in ["&route=x", "&backend=sefaria", "&save=true", "&query=private", "#fragment"] {
            XCTAssertThrowsError(try NativeRouteURL.decode(URL(string: url.absoluteString + suffix)!, registry: registry))
        }
    }
    func testRejectsHostVersionPathAndCredentials() throws {
        let registry = try registry(), url = try NativeRouteURL.encode(route(), registry: registry).absoluteString
        for value in [url.replacingOccurrences(of: "/v1/", with: "/v2/"),
                      url.replacingOccurrences(of: "fixture.reader?", with: "fixture.notes?"),
                      url.replacingOccurrences(of: "//action", with: "//user@action"),
                      url.replacingOccurrences(of: "//action", with: "//action:80"),
                      url.replacingOccurrences(of: "//action", with: "//delete"),
                      url.replacingOccurrences(of: "/v1/", with: "//v1/")] {
            XCTAssertThrowsError(try NativeRouteURL.decode(URL(string: value)!, registry: registry))
        }
    }
    func testRejectsPaddingInvalidEncodingAndOversizedURL() throws {
        let registry = try registry(), url = try NativeRouteURL.encode(route(), registry: registry).absoluteString
        for value in [url + "=", "maktabah://action/v1/fixture.reader?route=a", "maktabah://action/v1/fixture.reader?route=" + String(repeating: "a", count: 6_145)] {
            XCTAssertThrowsError(try NativeRouteURL.decode(URL(string: value)!, registry: registry))
        }
    }
    func testPrivateRestorationCannotEnterPublicURL() throws {
        let registry = try registry()
        let data = Data("{\"version\":1,\"destination\":\"fixture.reader\",\"requestId\":\"\(UUID())\",\"state\":{\"privateState\":{\"draftNote\":\"secret\"}}}".utf8)
        let token = data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        XCTAssertThrowsError(try NativeRouteURL.decode(URL(string: "maktabah://action/v1/fixture.reader?route=" + token)!, registry: registry))
    }
    func testEmptyProductionRegistryDoesNotInstallFixtureRoutes() throws {
        let url = try NativeRouteURL.encode(route(), registry: registry())
        XCTAssertThrowsError(try NativeRouteURL.decode(url, registry: .init()))
    }
}
