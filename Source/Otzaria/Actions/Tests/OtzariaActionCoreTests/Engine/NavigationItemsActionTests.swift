import XCTest
@testable import OtzariaActionCore

private actor NavigationItemProvider: ActionBackendStatePort, ActionNavigationItemsPort {
    let entries: [ActionSourceSectionEntry]
    private(set) var requestedStructure: String?
    private(set) var maximumEntries: Int?

    init(_ entries: [ActionSourceSectionEntry]) { self.entries = entries }
    func snapshot() -> ActionBackendSnapshot { .init(backend: .sefaria, generation: 1) }
    func report(for backend: ActionBackendID) -> ActionBackendReport {
        .init(id: backend, operations: ["reader.navigationItems": .init(registered: true, supported: true, availableNow: true)])
    }
    func assess(action: String, arguments: ActionObject, invocation: ActionPortInvocation) -> ActionCapabilityAssessment {
        .init(registered: true, supported: true, availableNow: true)
    }
    func navigationItems(for work: ActionWorkRef, structureID: String?, maximumEntries: Int,
                         invocation: ActionPortInvocation) -> [ActionSourceSectionEntry] {
        requestedStructure = structureID
        self.maximumEntries = maximumEntries
        return entries
    }
}

final class NavigationItemsActionTests: XCTestCase, @unchecked Sendable {
    private func run(_ provider: NavigationItemProvider, scope: String = "Genesis") async throws -> ActionResult {
        let other = MockPorts()
        let executor = try ActionExecutor(state: provider, resolver: other, search: other)
        let work = ActionWorkRef(backend: .sefaria, workKey: "Genesis")
        let request = ActionRequest(action: "reader.navigationItems", arguments: [
            "workRef": try .encoded(work), "structureID": .string("Parasha"), "limit": .integer(1)
        ])
        return await executor.execute(request, context: .init(subjectID: "navigation-items", origin: .internalAI,
            allowedBackends: [.sefaria], contentRights: [.sefaria], scopes: [.contentRead],
            allowedWorkKeys: [.sefaria: [scope]]))
    }

    private func item(_ chapter: Int, work: String = "Genesis") -> ActionSourceSectionEntry {
        .init(locator: .init(backend: .sefaria, workKey: work, position: .canonicalRef("\(work) \(chapter)")), title: "פרק \(chapter)")
    }

    func testUsesOriginalStructureAndReturnsBoundedSourceOrder() async throws {
        let provider = NavigationItemProvider([item(3), item(1)])
        let result = try await run(provider)
        XCTAssertEqual(result.status, .completed)
        let items = try XCTUnwrap(result.data?["items"]?.decoded(as: [ActionSourceSectionEntry].self))
        XCTAssertEqual(items, [item(3)])
        XCTAssertEqual(result.data?["truncated"], .bool(true))
        let structure = await provider.requestedStructure
        let maximum = await provider.maximumEntries
        XCTAssertEqual(structure, "Parasha")
        XCTAssertEqual(maximum, 2)
    }

    func testRejectsForeignResultAndChecksScopeBeforeReading() async throws {
        let foreign = NavigationItemProvider([item(1, work: "Exodus")])
        let denied = try await run(foreign, scope: "Exodus")
        XCTAssertEqual(denied.error?.code, "permission_denied")
        let maximum = await foreign.maximumEntries
        XCTAssertNil(maximum)
        let invalid = try await run(foreign)
        XCTAssertEqual(invalid.error?.code, "invalid_backend_response")
    }
}
