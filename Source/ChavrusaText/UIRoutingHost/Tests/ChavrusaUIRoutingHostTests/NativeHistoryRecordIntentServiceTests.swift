import Foundation
import XCTest
import OtzariaActionCore
import OtzariaUIRouting
@testable import ChavrusaUIRoutingHost

// Actual package contracts/service/identifier codec. Catalog and native receipt
// transport below are explicit doubles, never app, Core execution or UIKit proof.
@MainActor final class NativeHistoryRecordIntentServiceTests: XCTestCase, @unchecked Sendable {
    func testFullQualifiedIdentitySeparatesPositionBackendAndKind() throws {
        let f = try RecordIntentFixture()
        let translated = try f.record(title: "כותרת")
        XCTAssertEqual(translated.id, f.record.id)
        for value in [try f.record(position: 524), try f.record(backend: .sefaria), try f.record(kind: .favorite)] {
            XCTAssertNotEqual(value.id, f.record.id)
        }
        let decoded: NativeHistoryRecordIntentService.Reference = try NativeReaderEntityIdentifier.decode(
            f.record.id, prefix: "maktabah.history-record.v1.")
        XCTAssertEqual(decoded, f.record.reference)
        XCTAssertEqual(decoded.locator.catalogRevision, "v40")
        XCTAssertEqual(decoded.locator.dataRevision, "source-revision")
    }

    func testCatalogDiscoveryDoesNotNavigateAndUsesExactKind() throws {
        let f = try RecordIntentFixture(), favorite = try f.record(kind: .favorite)
        f.records.append(favorite)
        let s = f.service()
        XCTAssertEqual(try s.records(kind: .history, matching: "Source").map(\.id), [f.record.id])
        XCTAssertEqual(try s.records(kind: .favorite, identifiers: [favorite.id, favorite.id]), [favorite])
        XCTAssertThrowsError(try s.records(kind: .history, identifiers: [favorite.id]))
        XCTAssertTrue(f.opened.isEmpty)
    }

    func testCachedRemovedFavoriteHasNoLiveEntityAndCannotNavigate() async throws {
        let f = try RecordIntentFixture(), favorite = try f.record(kind: .favorite)
        f.records = [favorite]
        let s = f.service(), cached = try XCTUnwrap(s.records(kind: .favorite).first)
        f.records.removeAll()
        XCTAssertTrue(try s.records(kind: .favorite, identifiers: [cached.id]).isEmpty)
        do { _ = try await s.reveal(kind: .favorite, identifier: cached.id, windowIdentifier: f.window.id); XCTFail() }
        catch { XCTAssertEqual((error as? UIRouteError)?.code, "intent_record_no_longer_available") }
        XCTAssertTrue(f.opened.isEmpty)
    }

    func testMalformedNoncanonicalAndOversizedQueriesStopBeforeRead() async throws {
        let f = try RecordIntentFixture(), s = f.service()
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(f.record.reference)) as! [String: Any]
        var extra = json; extra["callerAuthority"] = "not accepted"
        let noncanonical = "maktabah.history-record.v1." + (try JSONSerialization.data(withJSONObject: extra, options: .sortedKeys))
            .base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        for invalid in ["not-an-entity", "maktabah.history-record.v1.!!!", noncanonical,
                        "maktabah.history-record.v1." + String(repeating: "a", count: 9_000)] {
            XCTAssertThrowsError(try s.records(kind: .history, identifiers: [invalid]))
            do { _ = try await s.reveal(kind: .history, identifier: invalid, windowIdentifier: f.window.id); XCTFail() } catch {}
        }
        XCTAssertThrowsError(try s.records(kind: .history, identifiers: Array(repeating: f.record.id, count: 65)))
        XCTAssertThrowsError(try s.records(kind: .history, matching: String(repeating: "א", count: 257)))
        XCTAssertEqual(f.readCount, 0); XCTAssertTrue(f.opened.isEmpty)
    }

    func testDuplicateRecordOrItemIdentityCannotHideBehindFilter() throws {
        let f = try RecordIntentFixture(), s = f.service()
        f.records.append(f.record)
        XCTAssertThrowsError(try s.records(kind: .favorite))
        let another = try f.record(position: 524, item: f.record.itemID)
        f.records = [f.record, another]
        XCTAssertThrowsError(try s.records(kind: .history, identifiers: [f.record.id]))
        XCTAssertTrue(f.opened.isEmpty)
    }

    func testWindowMetadataKeepsExactScenesAndExcludesControlsAndOtherBackends() throws {
        let f = try RecordIntentFixture(), other = NativeIntentService.Destination(backend: .otzaria,
            destination: f.window.destination, title: "History — Window 2", sceneID: .init(rawValue: "scene.B")!)
        let control = NativeIntentService.Destination(backend: .otzaria, destination: f.window.destination,
            title: "Control", sceneID: f.window.sceneID, component: .init(rawValue: "native.history.control")!)
        let foreign = NativeIntentService.Destination(backend: .sefaria, destination: f.window.destination,
            title: "History — Foreign", sceneID: .init(rawValue: "scene.C")!)
        f.windows = [f.window, other, control, foreign]
        let s = f.service()
        XCTAssertEqual(try s.windows(), [f.window, other])
        XCTAssertEqual(try s.windows(identifiers: [other.id]), [other])
        f.windows.append(other)
        XCTAssertThrowsError(try s.windows(identifiers: [f.window.id]))
        XCTAssertTrue(f.opened.isEmpty)
    }

    func testRecordOrBackendChangeDuringWindowReadCannotReachHost() async throws {
        for changeBackend in [false, true] {
            let f = try RecordIntentFixture()
            f.onWindows = {
                if changeBackend { f.snapshot = .init(backend: .otzaria, generation: 10) }
                else { f.records.removeAll() }
            }
            do { _ = try await f.service().reveal(kind: .history, identifier: f.record.id, windowIdentifier: f.window.id); XCTFail() }
            catch { XCTAssertEqual((error as? UIRouteError)?.code, "intent_source_generation_changed") }
            XCTAssertTrue(f.opened.isEmpty)
        }
    }

    func testExactLiveRecordIsPassedWithFreshRequestAndExplicitWindow() async throws {
        let f = try RecordIntentFixture(), s = f.service()
        let first = try await s.reveal(kind: .history, identifier: f.record.id, windowIdentifier: f.window.id)
        let second = try await s.reveal(kind: .history, identifier: f.record.id, windowIdentifier: f.window.id)
        XCTAssertEqual(first, .queued(handle: "explicit-transport-double")); XCTAssertEqual(first, second)
        XCTAssertThrowsError(try NativeIntentOutcome.requireVisibleAcknowledgement(first))
        XCTAssertEqual(f.opened.count, 2); XCTAssertNotEqual(f.opened[0].requestID, f.opened[1].requestID)
        XCTAssertEqual(f.opened[0].record, f.record); XCTAssertEqual(f.opened[0].window, f.window)
        XCTAssertEqual(f.opened[0].expectedSnapshot, f.snapshot)
    }

    func testExactSyntheticAcknowledgementSatisfiesOnlyServiceShape() async throws {
        let f = try RecordIntentFixture()
        f.response = { request in .acknowledged(f.receipt(request)) }
        let result = try await f.service().reveal(kind: .history, identifier: f.record.id, windowIdentifier: f.window.id)
        guard case .acknowledged(let receipt) = result else { return XCTFail() }
        XCTAssertEqual(receipt.route.state.selectedItemID, f.record.itemID)
        XCTAssertEqual(receipt.sceneID, f.window.sceneID)
        XCTAssertNil(receipt.route.content, "This slice reveals a card; it is not Reader opening")
    }

    func testRootReceiptAndWrongItemCannotSatisfyRecordReveal() async throws {
        for variant in ["rootOnly", "wrongItem"] {
            let f = try RecordIntentFixture()
            f.response = { .acknowledged(f.receipt($0, variant: variant)) }
            do { _ = try await f.service().reveal(kind: .history, identifier: f.record.id, windowIdentifier: f.window.id); XCTFail(variant) }
            catch let error as NativeHistoryRecordIntentService.Failure {
                XCTAssertEqual(error.code, "native_effect_uncertain")
                guard case .acknowledged = error.acknowledgement else { return XCTFail("Observed receipt was lost") }
            }
        }
    }

    func testUnrelatedReceiptStateAndRequestWindowBackendMismatchAreRefused() async throws {
        for variant in ["request", "routeRequest", "scene", "routeScene", "revision", "sceneRevision", "backend", "snapshot",
                        "destination", "presentation", "tab", "version", "stateVersion", "focus", "component", "expanded",
                        "sidebar", "inspector", "sheet", "privateState", "scroll", "content"] {
            let f = try RecordIntentFixture()
            f.response = { .acknowledged(f.receipt($0, variant: variant)) }
            do { _ = try await f.service().reveal(kind: .history, identifier: f.record.id, windowIdentifier: f.window.id); XCTFail(variant) }
            catch let error as NativeHistoryRecordIntentService.Failure {
                XCTAssertEqual(error.code, "native_effect_uncertain", variant)
                guard case .acknowledged = error.acknowledgement else { return XCTFail("Observed receipt was lost") }
            }
        }
    }

    func testCancellationBeforeReadAndAfterHostAckDoesNotBecomeSuccess() async throws {
        let f = try RecordIntentFixture(), s = f.service()
        let first = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            return try s.records(kind: .history)
        }
        do { _ = try await first.value; XCTFail() } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(f.readCount, 0)
        f.response = { request in
            withUnsafeCurrentTask { $0?.cancel() }
            return .acknowledged(f.receipt(request))
        }
        let second = Task { @MainActor in
            try await s.reveal(kind: .history, identifier: f.record.id, windowIdentifier: f.window.id)
        }
        do { _ = try await second.value; XCTFail() }
        catch let error as NativeHistoryRecordIntentService.Failure { XCTAssertEqual(error.status, .cancelled) }
    }
}

@MainActor private final class RecordIntentFixture {
    typealias Service = NativeHistoryRecordIntentService
    var snapshot = ActionBackendSnapshot(backend: .otzaria, generation: 9)
    let window = NativeIntentService.Destination(backend: .otzaria, destination: .init(rawValue: "native.history")!,
        title: "History — Window 1", sceneID: .init(rawValue: "scene.A")!)
    let record: Service.Record
    var records: [Service.Record]
    var windows: [NativeIntentService.Destination] = []
    var readCount = 0
    var opened: [Service.OpenRequest] = []
    var onWindows: (() -> Void)?
    var response: ((Service.OpenRequest) throws -> UISceneAcknowledgement)?
    init() throws {
        record = try Service.Record(reference: .init(kind: .history, locator: .init(backend: .otzaria,
            workKey: "book:3891", position: .legacyLine(523), catalogRevision: "v40", dataRevision: "source-revision")),
            title: "Source title", itemID: .init(rawValue: "history.history.fixture523")!)
        records = [record]; windows = [window]
    }
    func record(kind: Service.Kind = .history, backend: ActionBackendID = .otzaria,
                position: Int = 523, title: String = "Source title", item: UIStableID? = nil) throws -> Service.Record {
        try .init(reference: .init(kind: kind, locator: .init(backend: backend, workKey: "book:3891",
            position: .legacyLine(Int64(position)), catalogRevision: "v40", dataRevision: "source-revision")),
            title: title, itemID: item ?? .init(rawValue: "history.\(kind.rawValue).fixture\(position)")!)
    }
    func service() -> Service {
        .init(read: { [self] in readCount += 1; return .init(snapshot: snapshot, records: records) },
            windows: { [self] in onWindows?(); return windows }, navigate: { [self] request in
                opened.append(request)
                return try response?(request) ?? .queued(handle: "explicit-transport-double")
            })
    }
    func receipt(_ request: Service.OpenRequest, variant: String = "valid") -> UISceneReceipt {
        let other = UIStableID(rawValue: "other.identity")!
        let locator = record.reference.locator
        let state = UIStateSpec(version: variant == "stateVersion" ? 2 : 1,
            selectedItemID: variant == "rootOnly" ? nil : variant == "wrongItem" ? other : record.itemID,
            visibleComponents: variant == "component" ? [.init(rawValue: "native.history.extra")!] : [],
            expandedComponents: variant == "expanded" ? [.init(rawValue: "native.history.extra")!] : [],
            sidebarVisible: variant == "sidebar" ? false : nil,
            inspectorVisible: variant == "inspector" ? false : nil,
            sheet: variant == "sheet" ? .init(rawValue: "native.settings") : nil,
            scrollAnchor: variant == "scroll" ? locator : nil,
            privateState: variant == "privateState" ? .init(draftNote: "explicit-double") : nil)
        let route = RouteSpec(version: variant == "version" ? 2 : 1,
            requestId: variant == "routeRequest" ? UUID() : request.requestID,
            destination: .init(rawValue: variant == "destination" ? "native.library" : "native.history")!,
            backend: variant == "backend" ? .sefaria : snapshot.backend,
            content: variant == "content" ? .init(sectionLocator: locator, presentationMode: .sameTab) : nil,
            presentation: .init(kind: variant == "presentation" ? .sheet : .currentTab, tabID: variant == "tab" ? other : nil),
            state: state, focus: variant == "focus" ? .init(kind: .component, anchor: .init(rawValue: "native.history.extra")) : nil,
            scene: .init(kind: .specific, sceneID: variant == "routeScene" ? other : window.sceneID,
                         expectedRevision: variant == "sceneRevision" ? 6 : 7),
            expectedBackendSnapshot: snapshot)
        return .init(requestId: variant == "request" ? UUID() : request.requestID, route: route,
            backendSnapshot: variant == "snapshot" ? .init(backend: .otzaria, generation: 10) : snapshot,
            sceneID: variant == "scene" ? other : window.sceneID, basedOnSceneRevision: 7,
            appliedSceneRevision: variant == "revision" ? 7 : 8)
    }
}
