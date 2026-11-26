import XCTest
@testable import OtzariaActionCore

private actor TOCState: ActionBackendStatePort, ActionTableOfContentsPort {
    var calls = 0
    var generation: UInt64 = 1
    let wrongWork: Bool
    let changeGeneration: Bool

    init(wrongWork: Bool = false, changeGeneration: Bool = false) {
        self.wrongWork = wrongWork
        self.changeGeneration = changeGeneration
    }

    func snapshot() -> ActionBackendSnapshot { .init(backend: .otzaria, generation: generation) }

    func report(for backend: ActionBackendID) -> ActionBackendReport {
        .init(id: backend, operations: ["reader.getTOC": .init(registered: true, supported: true, availableNow: true)])
    }

    func assess(action: String, arguments: ActionObject, invocation: ActionPortInvocation) -> ActionCapabilityAssessment {
        .init(registered: true, supported: true, availableNow: true)
    }

    func tableOfContents(for work: ActionWorkRef, maximumEntries: Int,
                         invocation: ActionPortInvocation) -> [ActionSourceSectionEntry] {
        calls += 1
        if changeGeneration { generation += 1 }
        let entries: [ActionSourceSectionEntry] = [
            .init(locator: .init(backend: work.backend, workKey: wrongWork ? "book:2" : work.workKey,
                                 position: .legacyLine(41)), title: "פרק א"),
            .init(locator: .init(backend: work.backend, workKey: work.workKey, position: .legacyLine(107)), title: "פרק ב")
        ]
        return Array(entries.prefix(maximumEntries))
    }
}

final class TableOfContentsActionTests: XCTestCase, @unchecked Sendable {
    private let work = ActionWorkRef(backend: .otzaria, workKey: "book:1")

    private func request() throws -> ActionRequest {
        .init(action: "reader.getTOC", arguments: ["workRef": try .encoded(work), "limit": .integer(1)])
    }

    private func context(readRights: Set<ActionBackendID> = [.otzaria],
                         allowedWorks: Set<String> = ["book:1"]) -> ActionExecutionContext {
        .init(subjectID: "toc-fixture", origin: .guide, allowedBackends: [.otzaria],
              contentRights: readRights, scopes: [.discovery, .contentRead], allowedWorkKeys: [.otzaria: allowedWorks])
    }

    private func executor(_ state: any ActionBackendStatePort) throws -> ActionExecutor {
        let other = MockPorts()
        return try .init(state: state, resolver: other, search: other)
    }

    func testKeepsOriginalTitleAndLocatorAndReportsTruncation() async throws {
        let state = TOCState()
        let result = await (try executor(state)).execute(try request(), context: context())
        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(result.data?["truncated"], .bool(true))
        XCTAssertEqual(try result.data?["entries"]?.decoded(as: [ActionSourceSectionEntry].self), [
            .init(locator: .init(backend: .otzaria, workKey: "book:1", position: .legacyLine(41)), title: "פרק א")
        ])
    }

    func testNoReadsWithoutWorkAndContentRights() async throws {
        let state = TOCState(), core = try executor(state)
        let noContent = await core.execute(try request(), context: context(readRights: []))
        XCTAssertEqual(noContent.error?.code, "content_rights_required")
        let wrongWork = await core.execute(try request(), context: context(allowedWorks: ["book:2"]))
        XCTAssertEqual(wrongWork.error?.code, "permission_denied")
        let calls = await state.calls
        XCTAssertEqual(calls, 0)
    }

    func testRejectsAnotherWorkOrChangedBackendGeneration() async throws {
        let bad = await (try executor(TOCState(wrongWork: true))).execute(try request(), context: context())
        XCTAssertEqual(bad.error?.code, "invalid_backend_response")
        XCTAssertNil(bad.data)
        let stale = await (try executor(TOCState(changeGeneration: true))).execute(try request(), context: context())
        XCTAssertEqual(stale.status, .staleState)
        XCTAssertNil(stale.data)
    }

    func testMissingSourcePortIsNeverAdvertised() async throws {
        let actions = await (try executor(MockPorts())).advertisedActions(for: .otzaria, context: context())
        XCTAssertFalse(actions.contains { $0.id == "reader.getTOC" })
    }
}
