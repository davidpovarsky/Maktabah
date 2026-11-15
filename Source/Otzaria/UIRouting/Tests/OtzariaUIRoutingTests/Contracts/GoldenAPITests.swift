import Foundation
import XCTest
import OtzariaActionCore
@testable import OtzariaUIRouting

final class GoldenAPITests: XCTestCase {
    func testGoldenPrivateAndPublicDTOs() throws {
        let privateData = try XCTUnwrap(Bundle.module.url(forResource: "private-reader-v1", withExtension: "json", subdirectory: "Fixtures"))
        let route = try JSONDecoder().decode(RouteSpec.self, from: Data(contentsOf: privateData))
        XCTAssertEqual(route.version, 1); XCTAssertEqual(route.content?.sectionLocator.position, .legacyLine(42))
        XCTAssertEqual(try JSONDecoder().decode(RouteSpec.self, from: JSONEncoder().encode(route)), route)
        let publicData = try XCTUnwrap(Bundle.module.url(forResource: "public-reader-v1", withExtension: "json", subdirectory: "Fixtures"))
        let shared = try JSONDecoder().decode(PublicRouteSpec.self, from: Data(contentsOf: publicData))
        XCTAssertEqual(shared.destination, route.destination)
        XCTAssertEqual(try ActionJSON.encoded(shared).object?["state"], nil)
    }
    func testIDsAndSendableContracts() throws {
        XCTAssertNil(UIDestinationID(rawValue: "UIViewController")); XCTAssertNil(UIDestinationID(rawValue: "fixture.reader/selector"))
        XCTAssertNil(UIStableID(rawValue: "/private/path"))
        let id = try XCTUnwrap(UIDestinationID(rawValue: "fixture.reader"))
        func sendable<T: Sendable>(_: T) {}
        sendable(RouteSpec(destination: id)); sendable(SceneTarget()); sendable(UIStateSpec())
    }
}
