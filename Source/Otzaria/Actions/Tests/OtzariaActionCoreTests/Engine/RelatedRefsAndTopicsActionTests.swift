import XCTest
@testable import OtzariaActionCore

private struct RelatedMetadataProvider: ActionBackendStatePort, ActionRelatedRefsPort, ActionRelatedTopicsPort {
    var refs: [ActionTextRef] = []
    var topics: [ActionRelatedTopic] = []

    func snapshot() async -> ActionBackendSnapshot { .init(backend: .sefaria, generation: 1) }
    func report(for backend: ActionBackendID) async -> ActionBackendReport { .init(id: backend, operations: [:]) }
    func assess(action: String, arguments: ActionObject, invocation: ActionPortInvocation) async -> ActionCapabilityAssessment {
        .init(registered: true, supported: true, availableNow: true)
    }
    func relatedRefs(for locator: ActionTextRef, invocation: ActionPortInvocation) async -> [ActionTextRef] { refs }
    func relatedTopics(for locator: ActionTextRef, invocation: ActionPortInvocation) async -> [ActionRelatedTopic] { topics }
}

final class RelatedRefsAndTopicsActionTests: XCTestCase, @unchecked Sendable {
    private let source = ActionTextRef(backend: .sefaria, workKey: "Deuteronomy", position: .canonicalRef("Deuteronomy 1"))

    private func run(_ action: String, state: RelatedMetadataProvider, limit: Int? = nil,
                     read: Bool = true) async throws -> ActionResult {
        let original = MockPorts()
        let engine = try ActionExecutor(state: state, resolver: original, search: original)
        var arguments: ActionObject = ["sourceLocator": try .encoded(source)]
        if let limit { arguments["limit"] = .integer(Int64(limit)) }
        return await engine.execute(.init(action: action, arguments: arguments),
            context: .init(subjectID: "related-metadata", origin: .internalAI, allowedBackends: [.sefaria],
                           contentRights: [.sefaria], scopes: read ? [.contentRead] : [.discovery],
                           allowedWorkKeys: [.sefaria: ["Deuteronomy"]]))
    }

    func testRefsPreserveOriginalOrderAndFilterOutsideTheScopedWork() async throws {
        let allowed = ActionTextRef(backend: .sefaria, workKey: "Deuteronomy", position: .canonicalRef("Deuteronomy 2"))
        let outside = ActionTextRef(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 1"))
        let result = try await run("reader.relatedRefs", state: .init(refs: [outside, allowed, allowed, source]))
        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(try result.data?["locators"]?.decoded(as: [ActionTextRef].self), [allowed, source])
        XCTAssertEqual(result.data?["truncated"], .bool(false))
    }

    func testTopicsDeduplicateNativeSlugsAndRespectLimitAndContentRead() async throws {
        let topic = ActionRelatedTopic(slug: "covenant", titleHe: "ברית", titleEn: "Covenant")
        let duplicate = ActionRelatedTopic(slug: "covenant", titleEn: "Alternate")
        let other = ActionRelatedTopic(slug: "moses", titleHe: "משה")
        let state = RelatedMetadataProvider(topics: [topic, duplicate, other])
        let result = try await run("reader.relatedTopics", state: state, limit: 1)
        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(try result.data?["topics"]?.decoded(as: [ActionRelatedTopic].self), [topic])
        XCTAssertEqual(result.data?["truncated"], .bool(true))
        let denied = try await run("reader.relatedTopics", state: state, read: false)
        XCTAssertEqual(denied.error?.code, "permission_denied")
    }

    func testMalformedTopicAndForeignLocatorAreRejected() async throws {
        let bad = try await run("reader.relatedTopics", state: .init(topics: [.init(slug: " ")]))
        XCTAssertEqual(bad.error?.code, "invalid_backend_response")
        let foreign = ActionTextRef(backend: .otzaria, workKey: "book:1", position: .legacyLine(1))
        let wrongBackend = try await run("reader.relatedRefs", state: .init(refs: [foreign]))
        XCTAssertEqual(wrongBackend.error?.code, "invalid_backend_response")
    }
}
