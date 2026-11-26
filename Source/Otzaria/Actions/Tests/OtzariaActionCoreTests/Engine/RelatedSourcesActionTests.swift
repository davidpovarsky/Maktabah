import XCTest
@testable import OtzariaActionCore

private struct RelatedSourcesProvider: ActionBackendStatePort, ActionRelatedSourcesPort {
    let links: [ActionRelatedSource]

    func snapshot() async -> ActionBackendSnapshot { .init(backend: .otzaria, generation: 1) }
    func report(for backend: ActionBackendID) async -> ActionBackendReport { .init(id: backend, operations: [:]) }
    func assess(action: String, arguments: ActionObject, invocation: ActionPortInvocation) async -> ActionCapabilityAssessment {
        .init(registered: true, supported: true, availableNow: true)
    }
    func relatedSources(for locator: ActionTextRef, invocation: ActionPortInvocation) async -> [ActionRelatedSource] { links }
}

final class RelatedSourcesActionTests: XCTestCase, @unchecked Sendable {
    private let reference = ActionTextRef(backend: .otzaria, workKey: "book:1", position: .legacyLine(1))

    private func run(_ links: [ActionRelatedSource], allowed: Set<String>, read: Bool = true) async throws -> ActionResult {
        let other = MockPorts()
        let executor = try ActionExecutor(state: RelatedSourcesProvider(links: links), resolver: other, search: other)
        return await executor.execute(.init(action: "reader.relatedSources", arguments: [
            "sourceLocator": try .encoded(reference), "category": .string("commentary"), "limit": .integer(1)
        ]), context: .init(subjectID: "related-links", origin: .internalAI, allowedBackends: [.otzaria],
                            contentRights: [.otzaria], scopes: read ? [.contentRead] : [.discovery],
                            allowedWorkKeys: [.otzaria: allowed]))
    }

    func testOriginalOrderCategoryDeduplicationAndRestrictedResults() async throws {
        let first = ActionRelatedSource(locator: reference, displayRef: "דברים", category: "Commentary", relationshipType: "commentary")
        let second = ActionRelatedSource(locator: .init(backend: .otzaria, workKey: "book:1", position: .legacyLine(2)),
            displayRef: "דברים ב", category: "Commentary", relationshipType: "commentary")
        let outside = ActionRelatedSource(locator: .init(backend: .otzaria, workKey: "book:2", position: .legacyLine(1)),
            displayRef: "Restricted", category: "Commentary", relationshipType: "commentary")
        let plain = ActionRelatedSource(locator: reference, displayRef: "Related", category: "Sources", relationshipType: "reference")
        let result = try await run([outside, first, first, plain, second], allowed: ["book:1"])
        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(try result.data?["sources"]?.decoded(as: [ActionRelatedSource].self), [first])
        XCTAssertEqual(result.data?["truncated"], .bool(true))
    }

    func testForeignLocatorAndMissingContentReadAreRejected() async throws {
        let foreign = ActionRelatedSource(locator: .init(backend: .sefaria, workKey: "Deuteronomy", position: .canonicalRef("Deuteronomy 1")),
            displayRef: "Deuteronomy", category: "Commentary", relationshipType: "commentary")
        let invalid = try await run([foreign], allowed: ["book:1"])
        XCTAssertEqual(invalid.error?.code, "invalid_backend_response")
        let denied = try await run([], allowed: ["book:1"], read: false)
        XCTAssertEqual(denied.error?.code, "permission_denied")
    }
}
