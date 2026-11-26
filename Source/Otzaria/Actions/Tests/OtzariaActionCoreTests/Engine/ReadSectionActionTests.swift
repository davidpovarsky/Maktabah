import XCTest
@testable import OtzariaActionCore

private actor SectionState: ActionBackendStatePort, ActionSourceTextPort {
    enum Response { case original, foreignWork, overBudget, stale }
    private let response: Response
    private var generation: UInt64 = 1
    private(set) var reads = 0

    init(_ response: Response = .original) { self.response = response }

    func snapshot() -> ActionBackendSnapshot { .init(backend: .otzaria, generation: generation) }

    func report(for backend: ActionBackendID) -> ActionBackendReport {
        .init(id: backend, operations: ["reader.getSection": .init(registered: true, supported: true, availableNow: true)])
    }

    func assess(action: String, arguments: ActionObject, invocation: ActionPortInvocation) -> ActionCapabilityAssessment {
        .init(registered: true, supported: true, availableNow: true)
    }

    func section(at locator: ActionTextRef, maximumSegments: Int,
                 invocation: ActionPortInvocation) -> ActionSourceTextSection {
        reads += 1
        if response == .stale { generation += 1 }
        let section = ActionTextRef(backend: locator.backend, workKey: locator.workKey, position: .legacyLine(40))
        let segment = ActionTextRef(backend: locator.backend,
                                    workKey: response == .foreignWork ? "book:2" : locator.workKey,
                                    position: .legacyLine(42))
        let text = response == .overBudget ? String(repeating: "א", count: 1_000) : "בראשית"
        return .init(sectionLocator: section, displayRef: "בראשית א",
                     segments: [.init(locator: segment, sourceText: text)], truncated: maximumSegments == 1)
    }
}

final class ReadSectionActionTests: XCTestCase, @unchecked Sendable {
    private let locator = ActionTextRef(backend: .otzaria, workKey: "book:1", position: .legacyLine(42))

    private func request() throws -> ActionRequest {
        .init(action: "reader.getSection", arguments: ["sectionLocator": try .encoded(locator), "maxSegments": .integer(1)])
    }

    private func context(works: Set<String> = ["book:1"], byteLimit: Int = 65_536) -> ActionExecutionContext {
        .init(subjectID: "section-fixture", origin: .internalAI, allowedBackends: [.otzaria], contentRights: [.otzaria],
              scopes: [.discovery, .contentRead], allowedWorkKeys: [.otzaria: works], maxResultBytes: byteLimit)
    }

    private func executor(_ state: any ActionBackendStatePort) throws -> ActionExecutor {
        let other = MockPorts()
        return try .init(state: state, resolver: other, search: other)
    }

    func testPreservesSourceTextAndNativeLocators() async throws {
        let core = try executor(SectionState())
        let result = await core.execute(try request(), context: context())
        XCTAssertEqual(result.status, .completed)
        let section = try ActionJSON.object(XCTUnwrap(result.data)).decoded(as: ActionSourceTextSection.self)
        XCTAssertEqual(section.sectionLocator.position, .legacyLine(40))
        XCTAssertEqual(section.segments, [.init(locator: locator, sourceText: "בראשית")])
        XCTAssertTrue(section.truncated)
    }

    func testRejectsWrongWorkBeforeReadingAndForeignSegmentAfterReading() async throws {
        let state = SectionState(), core = try executor(state)
        let blocked = await core.execute(try request(), context: context(works: ["book:2"]))
        XCTAssertEqual(blocked.error?.code, "permission_denied")
        let reads = await state.reads
        XCTAssertEqual(reads, 0)
        let foreign = await (try executor(SectionState(.foreignWork))).execute(try request(), context: context())
        XCTAssertEqual(foreign.error?.code, "invalid_backend_response")
        XCTAssertNil(foreign.data)
    }

    func testDoesNotReturnPartialBytesFromOversizeOrStaleRead() async throws {
        let oversized = await (try executor(SectionState(.overBudget))).execute(try request(), context: context(byteLimit: 1_024))
        XCTAssertEqual(oversized.error?.code, "result_budget_exceeded")
        XCTAssertNil(oversized.data)
        let stale = await (try executor(SectionState(.stale))).execute(try request(), context: context())
        XCTAssertEqual(stale.status, .staleState)
        XCTAssertNil(stale.data)
    }

    func testUnavailableReaderIsNeverAdvertised() async throws {
        let actions = await (try executor(MockPorts())).advertisedActions(for: .otzaria, context: context())
        XCTAssertFalse(actions.contains { $0.id == "reader.getSection" })
    }
}
