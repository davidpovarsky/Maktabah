import Foundation
import XCTest
import OtzariaActionCore
import OtzariaUIRouting
@testable import ChavrusaUIRoutingHost

// Core responses/native acknowledgement are explicit doubles. Actual Core,
 // original app wiring and Apple system execution have separate gates.
@MainActor final class NativeReaderIntentServiceTests: XCTestCase, @unchecked Sendable {
    func testStableQualifiedIdentityPreservesZeroRevisionAndEntityKind() throws {
        let fixture = ReaderIntentFixture()
        let a = try NativeReaderIntentService.Work(reference: fixture.work, title: "Title")
        let b = try NativeReaderIntentService.Work(reference: fixture.work, title: "A translated title")
        XCTAssertEqual(a.id, b.id)
        let other = try NativeReaderIntentService.Work(reference: .init(backend: .sefaria, workKey: "book:7"), title: "Title")
        XCTAssertNotEqual(a.id, other.id)
        let exact = ActionTextRef(backend: .otzaria, workKey: "book:7", position: .legacyLine(0),
                                  catalogRevision: "catalog-v1", dataRevision: "source-v2")
        let id = try NativeReaderIntentService.Location(reference: exact, title: "Chapter").id
        let decoded: ActionTextRef = try NativeReaderEntityIdentifier.decode(id, prefix: "maktabah.location.v1.")
        XCTAssertEqual(decoded, exact)
        XCTAssertThrowsError(try NativeReaderEntityIdentifier.decode(id, prefix: "maktabah.work.v1.") as ActionWorkRef)
    }
    func testActualCoreMetadataRequestAndAmbiguityRemainSeparateChoices() async throws {
        let fixture = ReaderIntentFixture(), service = fixture.service()
        let found = try await service.works(matching: "Source title")
        XCTAssertEqual(found.map(\.reference), [fixture.work])
        XCTAssertEqual(fixture.requests[0].action, "catalog.resolveWork")
        XCTAssertEqual(fixture.requests[0].arguments["query"], .string("Source title"))
        XCTAssertEqual(fixture.requests[0].requestedPresentation, .headless)
        fixture.override = { request, snapshot in
            let refs = [fixture.work, ActionWorkRef(backend: .otzaria, workKey: "book:8")]
            return ActionResult(request: request, status: .needsDisambiguation,
                candidates: try refs.map { .init(ref: try ActionJSON.encoded($0).object!, title: "Source", kind: .work) },
                backend: snapshot.backend, backendGeneration: snapshot.generation)
        }
        let ambiguous = try await service.works(matching: "Source")
        XCTAssertEqual(ambiguous.count, 2); XCTAssertNotEqual(ambiguous[0].id, ambiguous[1].id)
        XCTAssertTrue(fixture.opened.isEmpty)
    }
    func testLocationQueryUsesSelectedWorkAndOriginalSection() async throws {
        let fixture = ReaderIntentFixture(), service = fixture.service()
        let work = try NativeReaderIntentService.Work(reference: fixture.work, title: "Book")
        let values = try await service.locations(matching: "פרק א", workIdentifier: work.id)
        XCTAssertEqual(values.map(\.reference), [fixture.locator])
        XCTAssertEqual(fixture.requests.last?.action, "catalog.resolveReference")
        XCTAssertEqual(fixture.requests.last?.arguments["section"], .string("פרק א"))
        XCTAssertEqual(try fixture.requests.last?.arguments["workRef"]?.decoded(as: ActionWorkRef.self), fixture.work)
    }
    func testCachedSourceRevalidatesBeforePassingExactSnapshotToOriginalHost() async throws {
        let fixture = ReaderIntentFixture(), service = fixture.service()
        let ids = try fixture.identifiers()
        let result = try await service.open(workIdentifier: ids.work, locationIdentifier: ids.location,
                                             windowIdentifier: "exact-user-selected-window", newTab: true)
        XCTAssertEqual(fixture.requests.count, 1)
        XCTAssertEqual(fixture.requests[0].action, "catalog.resolveReference")
        XCTAssertEqual(fixture.opened.count, 1)
        XCTAssertEqual(fixture.opened[0].locator, fixture.locator)
        XCTAssertEqual(fixture.opened[0].expectedSnapshot, fixture.snapshot)
        XCTAssertEqual(fixture.opened[0].windowIdentifier, "exact-user-selected-window")
        XCTAssertTrue(fixture.opened[0].newTab)
        XCTAssertEqual(result, .queued(handle: "fixture_only"))
        XCTAssertThrowsError(try NativeIntentOutcome.requireVisibleAcknowledgement(result))
    }
    func testChangedCachedSourceOrWrongBookCannotNavigate() async throws {
        let fixture = ReaderIntentFixture(), service = fixture.service(), ids = try fixture.identifiers()
        fixture.locator = .init(backend: .otzaria, workKey: "book:7", position: .legacyLine(99))
        do {
            _ = try await service.open(workIdentifier: ids.work, locationIdentifier: ids.location, windowIdentifier: "window", newTab: true)
            XCTFail("Source identity changed")
        } catch { XCTAssertEqual((error as? UIRouteError)?.status, .staleState) }
        XCTAssertTrue(fixture.opened.isEmpty)
        let other = try NativeReaderIntentService.Work(reference: .init(backend: .otzaria, workKey: "book:8"), title: "Other")
        let before = fixture.requests.count
        do {
            _ = try await service.open(workIdentifier: other.id, locationIdentifier: ids.location, windowIdentifier: "window", newTab: true)
            XCTFail("Book and passage mismatch")
        } catch { XCTAssertEqual((error as? UIRouteError)?.code, "intent_work_location_mismatch") }
        XCTAssertEqual(fixture.requests.count, before); XCTAssertTrue(fixture.opened.isEmpty)
    }
    func testCoreRequestAndGenerationMismatchAreRejected() async throws {
        for wrongRequest in [false, true] {
            let fixture = ReaderIntentFixture(), service = fixture.service()
            fixture.override = { request, snapshot in
                .init(request: wrongRequest ? .init(action: request.action) : request, status: .completed,
                    data: ["workRef": try ActionJSON.encoded(fixture.work)], backend: snapshot.backend,
                    backendGeneration: wrongRequest ? snapshot.generation : snapshot.generation + 1)
            }
            do { _ = try await service.works(matching: "Source"); XCTFail("Corrupt Core projection") }
            catch { XCTAssertTrue(error is UIRouteError) }
            XCTAssertTrue(fixture.opened.isEmpty)
        }
    }
    func testMissingSourceIsEmptyButUnavailableIsNeverAnEmptySuccess() async throws {
        let fixture = ReaderIntentFixture(), service = fixture.service()
        fixture.override = { request, _ in .init(request: request, status: .failed,
            error: .init(code: "not_found", message: "Source missing")) }
        let absent = try await service.works(matching: "Missing")
        XCTAssertTrue(absent.isEmpty)
        fixture.override = { request, _ in .init(request: request, status: .unavailable,
            error: .init(code: "backend_unavailable", message: "Fixture unavailable")) }
        do { _ = try await service.works(matching: "Missing"); XCTFail("Unavailable source became zero results") }
        catch { XCTAssertEqual((error as? NativeIntentOutcome)?.status, .unavailable) }
    }
    func testNoncanonicalAndMalformedEntitiesFailBeforeCore() async throws {
        let fixture = ReaderIntentFixture(), service = fixture.service()
        let payload = Data(#"{"backend":"otzaria","extra":"not-source","workKey":"book:7"}"#.utf8)
            .base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        for value in ["not-an-entity", "maktabah.work.v1.!!!!", "maktabah.work.v1." + payload] {
            do { _ = try await service.works(identifiers: [value]); XCTFail("Invalid identity") } catch {}
        }
        XCTAssertTrue(fixture.requests.isEmpty)
    }
    func testDuplicateStoredIDsRevalidateOnceAndDoNotCreateDuplicateEntities() async throws {
        let fixture = ReaderIntentFixture(), service = fixture.service(), ids = try fixture.identifiers()
        let works = try await service.works(identifiers: [ids.work, ids.work])
        XCTAssertEqual(works.count, 1); XCTAssertEqual(fixture.requests.count, 1)
        let locations = try await service.locations(identifiers: [ids.location, ids.location], workIdentifier: ids.work)
        XCTAssertEqual(locations.count, 1); XCTAssertEqual(fixture.requests.count, 2)
    }
    func testCancellationBeforeExecutionDoesNotCallCoreOrNativeHost() async throws {
        let fixture = ReaderIntentFixture(), service = fixture.service()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await service.works(matching: "Source")
        }
        do { _ = try await task.value; XCTFail("Cancelled query") } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertTrue(fixture.requests.isEmpty); XCTAssertTrue(fixture.opened.isEmpty)
    }
}
@MainActor private final class ReaderIntentFixture {
    let work = ActionWorkRef(backend: .otzaria, workKey: "book:7")
    var locator = ActionTextRef(backend: .otzaria, workKey: "book:7", position: .legacyLine(42))
    var snapshot = ActionBackendSnapshot(backend: .otzaria, generation: 9)
    var requests: [ActionRequest] = []
    var opened: [NativeReaderIntentService.OpenRequest] = []
    var override: ((ActionRequest, ActionBackendSnapshot) throws -> ActionResult)?
    func identifiers() throws -> (work: String, location: String) {
        (try NativeReaderIntentService.Work(reference: work, title: "Book").id,
         try NativeReaderIntentService.Location(reference: locator, title: "Chapter").id)
    }
    func service() -> NativeReaderIntentService {
        NativeReaderIntentService(execute: { [self] request in
            requests.append(request)
            let result = try override?(request, snapshot) ?? ActionResult(request: request, status: .completed,
                data: request.action == "catalog.resolveWork" ? ["workRef": try ActionJSON.encoded(work)] : ["locator": try ActionJSON.encoded(locator)],
                backend: snapshot.backend, backendGeneration: snapshot.generation)
            return .init(result: result, snapshot: snapshot)
        }, navigate: { [self] request in
            opened.append(request); return .queued(handle: "fixture_only")
        })
    }
}
