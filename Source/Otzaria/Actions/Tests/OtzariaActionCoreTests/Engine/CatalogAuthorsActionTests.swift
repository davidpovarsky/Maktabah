import XCTest
@testable import OtzariaActionCore

private struct AuthorsProvider: ActionBackendStatePort, ActionCatalogAuthorsPort {
    let authors: [ActionCatalogAuthor]

    func snapshot() async -> ActionBackendSnapshot { .init(backend: .otzaria, generation: 1) }
    func report(for backend: ActionBackendID) async -> ActionBackendReport {
        .init(id: backend, operations: ["catalog.listAuthors": .init(registered: true, supported: true, availableNow: true)])
    }
    func assess(action: String, arguments: ActionObject, invocation: ActionPortInvocation) async -> ActionCapabilityAssessment {
        .init(registered: true, supported: true, availableNow: true)
    }
    func catalogAuthors(backend: ActionBackendID, invocation: ActionPortInvocation) async -> [ActionCatalogAuthor] {
        authors
    }
}

final class CatalogAuthorsActionTests: XCTestCase, @unchecked Sendable {
    private func run(_ authors: [ActionCatalogAuthor], query: String = "רמב") async throws -> ActionResult {
        let other = MockPorts()
        let executor = try ActionExecutor(state: AuthorsProvider(authors: authors), resolver: other, search: other)
        return await executor.execute(.init(action: "catalog.listAuthors", arguments: [
            "backend": .string("otzaria"), "query": .string(query), "limit": .integer(1)
        ]), context: .init(subjectID: "catalog-authors", origin: .internalAI,
                            allowedBackends: [.otzaria], scopes: [.discovery]))
    }

    func testReturnsOriginalAuthorNamesAndStableIDsInOrder() async throws {
        let original: [ActionCatalogAuthor] = [
            .init(id: "otzaria-author:7", name: "רַמב״ם"), .init(id: "otzaria-author:2", name: "רמב״ן"),
            .init(id: "otzaria-author:9", name: "רש״י")
        ]
        let result = try await run(original)
        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(try result.data?["authors"]?.decoded(as: [ActionCatalogAuthor].self), [original[0]])
        XCTAssertEqual(result.data?["truncated"], .bool(true))
    }

    func testRejectsRepeatedSourceIdentity() async throws {
        let original: [ActionCatalogAuthor] = [
            .init(id: "otzaria-author:2", name: "רמב״ן"), .init(id: "otzaria-author:2", name: "רש״י")
        ]
        let result = try await run(original)
        XCTAssertEqual(result.error?.code, "invalid_backend_response")
    }
}
