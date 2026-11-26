import XCTest
@testable import OtzariaActionCore

private actor StructureProvider: ActionBackendStatePort, ActionNavigationStructurePort {
    let structures: [ActionNavigationStructure]
    private(set) var observedWork: ActionWorkRef?

    init(_ structures: [ActionNavigationStructure]) { self.structures = structures }
    func snapshot() -> ActionBackendSnapshot { .init(backend: .sefaria, generation: 1) }
    func report(for backend: ActionBackendID) -> ActionBackendReport {
        .init(id: backend, operations: ["reader.getNavigationStructures": .init(registered: true, supported: true, availableNow: true)])
    }
    func assess(action: String, arguments: ActionObject, invocation: ActionPortInvocation) -> ActionCapabilityAssessment {
        .init(registered: true, supported: true, availableNow: true)
    }
    func navigationStructures(for work: ActionWorkRef, invocation: ActionPortInvocation) -> [ActionNavigationStructure] {
        observedWork = work
        return structures
    }
}

final class NavigationStructuresActionTests: XCTestCase, @unchecked Sendable {
    private let work = ActionWorkRef(backend: .sefaria, workKey: "Genesis")

    private func execute(_ provider: StructureProvider, scope: Set<String> = ["Genesis"]) async throws -> ActionResult {
        let other = MockPorts()
        let engine = try ActionExecutor(state: provider, resolver: other, search: other)
        let request = ActionRequest(action: "reader.getNavigationStructures", arguments: ["workRef": try .encoded(work)])
        return await engine.execute(request, context: .init(subjectID: "navigation-structures", origin: .internalAI,
            allowedBackends: [.sefaria], contentRights: [.sefaria], scopes: [.contentRead],
            allowedWorkKeys: [.sefaria: scope]))
    }

    func testReportsOnlyOriginalStructureIDsAndTitlesInSourceOrder() async throws {
        let actual = [ActionNavigationStructure(id: "default", title: "Contents"),
                      .init(id: "Parasha", title: "פרשיות")]
        let provider = StructureProvider(actual)
        let result = try await execute(provider)
        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(try result.data?["structures"]?.decoded(as: [ActionNavigationStructure].self), actual)
        let read = await provider.observedWork
        XCTAssertEqual(read, work)
        let defaultOnly = try await execute(StructureProvider(Array(actual.prefix(1))))
        XCTAssertEqual(defaultOnly.data?["structures"]?.array?.count, 1)
    }

    func testRejectsUnpermittedWorkBeforeReadingAndAmbiguousStructureIDsAfterReading() async throws {
        let provider = StructureProvider([.init(id: "default", title: "Contents"), .init(id: "default", title: "Duplicate")])
        let denied = try await execute(provider, scope: ["Exodus"])
        XCTAssertEqual(denied.error?.code, "permission_denied")
        let deniedRead = await provider.observedWork
        XCTAssertNil(deniedRead)
        let invalid = try await execute(provider)
        XCTAssertEqual(invalid.error?.code, "invalid_backend_response")
        XCTAssertNil(invalid.data)
    }
}
