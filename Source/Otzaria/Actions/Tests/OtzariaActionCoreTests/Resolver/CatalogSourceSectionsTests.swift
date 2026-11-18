import Foundation
import XCTest
@testable import OtzariaActionCore

// Explicit source-shaped doubles, not a database, installed TOC or native UI.
final class CatalogSourceSectionsTests: XCTestCase, @unchecked Sendable {
    private let work = ActionWorkRef(backend: .otzaria, workKey: "book:7")
    private func invocation(deadline: UInt64 = .max) -> ActionPortInvocation {
        .init(requestId: UUID(), snapshot: .init(backend: .otzaria, generation: 3), deadlineUptimeNanoseconds: deadline)
    }
    private func entry(_ line: Int64, _ title: String = "פרק א") -> ActionSourceSectionEntry {
        .init(locator: .init(backend: .otzaria, workKey: "book:7", position: .legacyLine(line)), title: title)
    }
    private func resolve(_ entries: [ActionSourceSectionEntry], name: String = "פרק א") throws -> ActionResolution<ActionTextRef> {
        try CatalogActionResolver.sourceSectionCandidates(section: name, work: work, entries: entries, invocation: invocation())
    }

    func testSourceTitlePreservesZeroAndRevisionMetadata() throws {
        let selected = ActionWorkRef(backend: .otzaria, workKey: "book:7", catalogRevision: "catalog-source-3")
        let exact = ActionTextRef(backend: .otzaria, workKey: "book:7", position: .legacyLine(0),
                                  catalogRevision: selected.catalogRevision, dataRevision: "data-source-9")
        let actual = try CatalogActionResolver.sourceSectionCandidates(section: "פרק א", work: selected,
            entries: [.init(locator: exact, title: "פרק א")], invocation: invocation())
        XCTAssertEqual(actual, .unique(exact))
    }
    func testConservativeNamesDoNotInferChapterNumbersOrDropNiqqud() throws {
        let exact = entry(42, "פרק א״")
        XCTAssertEqual(try resolve([exact], name: " \nפרק   א\" "), .unique(exact.locator))
        XCTAssertEqual(try resolve([entry(42)], name: "פרק 1"), .notFound)
        XCTAssertEqual(try resolve([entry(42, "פֶּרֶק א")]), .notFound)
        XCTAssertEqual(try resolve([entry(42, "פרק אב")]), .notFound)
        XCTAssertEqual(try resolve([entry(42, "Café")], name: "Cafe\u{301}"), .unique(entry(42).locator))
    }
    func testRepeatedIdentityDeduplicatesButRepeatedTitleRemainsAmbiguous() throws {
        let first = entry(0), second = entry(27)
        XCTAssertEqual(try resolve([first, first]), .unique(first.locator))
        guard case .ambiguous(let values) = try resolve([first, first, second]) else {
            return XCTFail("Two source locators must never become a unique first match")
        }
        XCTAssertEqual(values.count, 2)
        XCTAssertEqual(try values.map { try ActionJSON.object($0.ref).decoded(as: ActionTextRef.self) }, [first.locator, second.locator])
        XCTAssertTrue(values.allSatisfy { $0.kind == .section && $0.confidenceBand == .exact && $0.title == "פרק א" })
    }
    func testInvalidSourceAfterAnExactMatchFailsInsteadOfTruncating() throws {
        let invalid: [ActionTextRef] = [
            .init(backend: .sefaria, workKey: "book:7", position: .canonicalRef("book:7 1")),
            .init(backend: .otzaria, workKey: "book:8", position: .legacyLine(1)),
            .init(backend: .otzaria, workKey: "book:7", position: .legacyLine(-1))
        ]
        for ref in invalid {
            XCTAssertThrowsError(try resolve([entry(0), .init(locator: ref, title: "another title")])) {
                XCTAssertEqual($0 as? ActionPortError, .invalidResponse)
            }
        }
        let selected = ActionWorkRef(backend: .otzaria, workKey: "book:7", catalogRevision: "selected")
        XCTAssertThrowsError(try CatalogActionResolver.sourceSectionCandidates(section: "פרק א", work: selected,
            entries: [entry(0)], invocation: invocation())) {
            XCTAssertEqual($0 as? ActionPortError, .invalidResponse)
        }
        XCTAssertThrowsError(try resolve([entry(0), entry(1, "\u{0}")])) {
            XCTAssertEqual($0 as? ActionPortError, .invalidResponse)
        }
    }
    func testEmptyAndOversizedSourcesNeverInventAUniqueReference() throws {
        XCTAssertEqual(try resolve([]), .notFound)
        XCTAssertThrowsError(try resolve(Array(repeating: entry(0), count: 100_001))) {
            XCTAssertEqual($0 as? ActionPortError, .unavailable)
        }
        XCTAssertThrowsError(try resolve((0...256).map { entry(Int64($0)) })) {
            XCTAssertEqual($0 as? ActionPortError, .unavailable)
        }
        XCTAssertThrowsError(try resolve([entry(0)], name: " \n ")) { XCTAssertTrue($0 is ActionContractError) }
        XCTAssertThrowsError(try resolve([entry(0)], name: String(repeating: "א", count: 513))) {
            XCTAssertTrue($0 is ActionContractError)
        }
    }
    func testDeadlineAndCancellationRemainExplicit() async throws {
        XCTAssertThrowsError(try CatalogActionResolver.sourceSectionCandidates(section: "פרק א", work: work,
            entries: [entry(0)], invocation: invocation(deadline: 0))) { XCTAssertTrue($0 is CancellationError) }
        let task = Task { [self] in
            withUnsafeCurrentTask { $0?.cancel() }
            return try resolve([entry(0)])
        }
        do { _ = try await task.value; XCTFail("Cancelled resolution") }
        catch { XCTAssertTrue(error is CancellationError) }
    }
}
