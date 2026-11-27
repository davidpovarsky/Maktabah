import Foundation
import Observation
import XCTest
import OtzariaActionCore
import OtzariaUIRouting
@testable import ChavrusaUIRoutingHost

/// Actual Catalog + actual Metadata + actual one-shot Observation latch.
/// The original UIKit/window/provider domain is an explicit test boundary.
final class SearchReferenceCatalogControls: XCTestCase, @unchecked Sendable {
    @MainActor func testRealPublicationKeepsStableIDsKindTitlesAndBoundedDiscovery() throws {
        let f = CatalogFixture(), catalog = f.catalog()
        let first = try catalog.targets(f.query()), second = try catalog.targets(f.query())
        XCTAssertEqual(first, second); XCTAssertEqual(first.count, 3); XCTAssertEqual(f.captures, 1)
        XCTAssertTrue(first[0].title.contains("Original book 0")); XCTAssertTrue(first[0].title.contains("Original window"))
        XCTAssertEqual(try catalog.targets(f.query(kind: .nextPage)).map(\.reference.kind), [.nextPage])
        XCTAssertEqual(try catalog.targets(f.query(matching: "book 1")).map(\.id), [first[1].id])
        XCTAssertEqual(try catalog.targets(f.query(references: [first[0].reference])).map(\.id), [first[0].id])
        let many = CatalogFixture(); many.hitCount = 80
        XCTAssertEqual(try many.catalog().targets(many.query()).count, 64)
    }

    @MainActor func testPublicIDNeverContainsPrivateOriginalSourceOrOperationToken() throws {
        let f = CatalogFixture(), catalog = f.catalog(), targets = try catalog.targets(f.query())
        for target in targets {
            for secret in [f.state!.query, target.source.sceneID, target.source.sessionID.uuidString.lowercased(),
                           target.source.modelID.uuidString.lowercased(), "original-item-", "3891"] {
                XCTAssertFalse(target.id.contains(secret))
            }
            XCTAssertEqual(try Service.Reference(identifier: target.id), target.reference)
        }
    }

    @MainActor func testRetainConsumesExactReferenceAndFinishCannotRearmIt() throws {
        let f = CatalogFixture(), catalog = f.catalog(), targets = try catalog.targets(f.query())
        let request = f.request(targets[0]), selection = try catalog.retain(request)
        XCTAssertTrue(catalog.ownsSelection(requestID: request.invocation.requestId))
        XCTAssertThrowsError(try catalog.retain(request)); XCTAssertTrue(try catalog.targets(f.query()).isEmpty)
        selection.finish(); selection.finish()
        XCTAssertFalse(catalog.ownsSelection(requestID: request.invocation.requestId))
        XCTAssertThrowsError(try catalog.retain(request))
        XCTAssertEqual(try catalog.targets(f.query()).map(\.id), Array(targets.dropFirst()).map(\.id))
        XCTAssertThrowsError(try selection.validate()); XCTAssertThrowsError(try selection.choose(f.observation(targets[0])))
    }

    @MainActor func testUnknownTamperedForeignSceneAndBackendRequestsNeverRetain() throws {
        let f = CatalogFixture(), catalog = f.catalog(), target = try XCTUnwrap(catalog.targets(f.query()).first)
        let unknown = Service.Target(reference: .init(backend: .otzaria, kind: .result, metadataID: UUID()),
            title: target.title, source: target.source, hit: target.hit)
        let changedTitle = Service.Target(reference: target.reference, title: "Other row", source: target.source, hit: target.hit)
        for value in [unknown, changedTitle] { XCTAssertThrowsError(try catalog.retain(f.request(value))) }
        XCTAssertThrowsError(try catalog.retain(f.request(target, origin: .deepLink(receivingSceneID: .init(rawValue: "other-window")!))))
        XCTAssertThrowsError(try catalog.retain(f.request(target, snapshot: .init(backend: .sefaria, generation: 7))))
        XCTAssertNoThrow(try catalog.retain(f.request(target)).finish())
    }

    @MainActor func testOnlyFreshOriginalObservationTokensReachBothFiniteOperations() throws {
        for kind in Service.Kind.allCases {
            let f = CatalogFixture(), catalog = f.catalog(), target = try XCTUnwrap(catalog.targets(f.query(kind: kind)).first)
            let selection = try catalog.retain(f.request(target)), fresh = f.observation(target)
            let chosen = try selection.choose(fresh)
            if kind == .result {
                XCTAssertEqual(chosen, .revealLoadedHit(token: fresh.loadedHits[0].token))
                XCTAssertNotEqual(fresh.loadedHits[0].token, target.reference.metadataID)
            } else {
                XCTAssertEqual(chosen, .nextOriginalPage(token: try XCTUnwrap(fresh.nextPageToken)))
                XCTAssertNotEqual(fresh.nextPageToken, target.reference.metadataID)
            }
            XCTAssertThrowsError(try selection.choose(fresh)); XCTAssertNoThrow(try selection.validate())
        }
    }

    @MainActor func testEveryOriginalSourceFieldIsBoundBeforeFreshTokenJoin() throws {
        for changed in ["scene", "backend", "backendGeneration", "session", "model", "generation", "source",
                        "submission", "cancellation", "pagination", "page", "configuration"] {
            let f = CatalogFixture(), catalog = f.catalog(), target = try XCTUnwrap(catalog.targets(f.query()).first)
            let selection = try catalog.retain(f.request(target))
            XCTAssertThrowsError(try selection.choose(f.observation(target, changed: changed)), changed)
            XCTAssertThrowsError(try selection.validate(), changed)
            XCTAssertThrowsError(try catalog.retain(f.request(target)), changed)
        }
    }

    @MainActor func testMissingDuplicateAndDifferentOriginalHitsCannotJoin() throws {
        for mutation in ["missing", "duplicate", "locator", "language", "identity"] {
            let f = CatalogFixture(), catalog = f.catalog(), target = try XCTUnwrap(catalog.targets(f.query()).first)
            let selection = try catalog.retain(f.request(target)), original = f.observation(target)
            var hits = original.loadedHits
            if mutation == "missing" { hits = [] }
            else if mutation == "duplicate" { hits += hits }
            else {
                let hit = hits[0]
                hits = [.init(token: hit.token, stableID: hit.stableID,
                    locator: mutation == "locator" ? "foreign locator" : hit.locator,
                    versionTitle: hit.versionTitle, language: mutation == "language" ? "en" : hit.language,
                    identity: mutation == "identity" ? Data("foreign identity".utf8) : hit.identity)]
            }
            XCTAssertThrowsError(try selection.choose(.init(source: original.source, loadedHits: hits, nextPageToken: original.nextPageToken)), mutation)
        }
    }

    @MainActor func testOwnedPageMayChangeRowsOnlyAfterOriginalSourceJoin() throws {
        let f = CatalogFixture(), catalog = f.catalog(), target = try XCTUnwrap(catalog.targets(f.query(kind: .nextPage)).first)
        let selection = try catalog.retain(f.request(target)); _ = try selection.choose(f.observation(target))
        f.state!.rowsRevision += 1
        XCTAssertNoThrow(try selection.validate())
        f.state!.query = "another query"; f.state!.query = "private original query"
        XCTAssertThrowsError(try selection.validate())
        let before = CatalogFixture(), other = before.catalog(), old = try XCTUnwrap(other.targets(before.query()).first)
        before.state!.rowsRevision += 1
        XCTAssertThrowsError(try other.retain(before.request(old)))
    }

    @MainActor func testActualOneShotObservationRejectsQueryBackendAndWindowABA() throws {
        for field in ["query", "backend", "window"] {
            let f = CatalogFixture(), catalog = f.catalog(), target = try XCTUnwrap(catalog.targets(f.query()).first)
            let selection = try catalog.retain(f.request(target)), state = try XCTUnwrap(f.state)
            switch field {
            case "query": let old = state.query; state.query = "different"; state.query = old
            case "backend": let old = state.snapshot; state.snapshot = .init(backend: .sefaria, generation: 7); state.snapshot = old
            default: let old = state.window; state.window = UUID(); state.window = old
            }
            XCTAssertThrowsError(try selection.validateBefore(), field)
            XCTAssertThrowsError(try selection.choose(f.observation(target)), field)
        }
    }

    @MainActor func testMetadataDoesNotKeepRetiredOriginalOwnerAlive() throws {
        let f = CatalogFixture(), catalog = f.catalog(), target = try XCTUnwrap(catalog.targets(f.query()).first)
        let selection = try catalog.retain(f.request(target))
        weak var original = f.state
        f.state = nil
        XCTAssertNil(original); XCTAssertThrowsError(try selection.validateBefore())
    }

    @MainActor func testRetainConsumesBeforeReentrantValidationAndDiscovery() throws {
        let f = CatalogFixture(), catalog = f.catalog(), target = try XCTUnwrap(catalog.targets(f.query()).first)
        let request = f.request(target); var nestedRejected = false, hidden = false
        f.beforeCallback = {
            do { _ = try catalog.retain(request) } catch { nestedRejected = true }
            hidden = try catalog.targets(f.query()).isEmpty
        }
        let selection = try catalog.retain(request)
        XCTAssertTrue(nestedRejected); XCTAssertTrue(hidden); XCTAssertNoThrow(try selection.validateBefore())
    }

    @MainActor func testChooseConsumesPhaseBeforeReentrantValidator() throws {
        let f = CatalogFixture(), catalog = f.catalog(), target = try XCTUnwrap(catalog.targets(f.query()).first)
        let request = f.request(target), selection = try catalog.retain(request), observation = f.observation(target)
        var recursiveRejected = false, recursiveValidatorRejected = false
        f.beforeCallback = {
            XCTAssertTrue(catalog.ownsSelection(requestID: request.invocation.requestId))
            do { _ = try selection.choose(observation) } catch { recursiveRejected = true }
            do { try selection.validate() } catch { recursiveValidatorRejected = true }
        }
        XCTAssertNoThrow(try selection.choose(observation))
        XCTAssertTrue(recursiveRejected); XCTAssertTrue(recursiveValidatorRejected)
    }

    @MainActor func testRetirementAndReplacementInsideCallbackCannotAdoptOrFinishNewOwner() throws {
        let f = CatalogFixture(), catalog = f.catalog(), target = try XCTUnwrap(catalog.targets(f.query()).first)
        let oldRequest = f.request(target), old = try catalog.retain(oldRequest)
        var replacement: MaktabahNativeSearchContinuationCatalog.Selection?
        f.beforeCallback = {
            catalog.retire()
            let newTarget = try XCTUnwrap(catalog.targets(f.query()).first)
            XCTAssertNotEqual(newTarget.id, target.id)
            replacement = try catalog.retain(f.request(newTarget))
        }
        XCTAssertThrowsError(try old.choose(f.observation(target)))
        let next = try XCTUnwrap(replacement)
        old.finish()
        XCTAssertTrue(catalog.ownsSelection(requestID: next.request.invocation.requestId))
        XCTAssertNoThrow(try next.validateBefore()); XCTAssertThrowsError(try old.validate())
    }

    @MainActor func testCaptureRetirementReentryCannotPublishOldSource() throws {
        let f = CatalogFixture(), catalog = f.catalog(); var recursiveEmpty = false
        f.captureCallback = { catalog.retire(); recursiveEmpty = try catalog.targets(f.query()).isEmpty }
        XCTAssertThrowsError(try catalog.targets(f.query())); XCTAssertTrue(recursiveEmpty)
        XCTAssertEqual(try catalog.targets(f.query()).count, 3)
    }

    @MainActor func testDeadlineBeforeAndAfterCallbacksCannotBeRenewed() throws {
        for phase in ["retain", "choose", "after"] {
            let f = CatalogFixture(), catalog = f.catalog(), target = try XCTUnwrap(catalog.targets(f.query()).first)
            let request = f.request(target)
            if phase == "retain" {
                f.beforeCallback = { f.clock = request.invocation.deadlineUptimeNanoseconds }
                XCTAssertThrowsError(try catalog.retain(request))
            } else {
                let selection = try catalog.retain(request)
                if phase == "choose" {
                    f.beforeCallback = { f.clock = request.invocation.deadlineUptimeNanoseconds }
                    XCTAssertThrowsError(try selection.choose(f.observation(target)))
                } else {
                    _ = try selection.choose(f.observation(target)); f.clock = request.invocation.deadlineUptimeNanoseconds
                    XCTAssertThrowsError(try selection.validate())
                }
            }
            XCTAssertFalse(catalog.ownsSelection(requestID: request.invocation.requestId))
        }
    }

    @MainActor func testUnmountPermanentlyRetiresPendingAndFutureDiscovery() throws {
        let f = CatalogFixture(), catalog = f.catalog(), target = try XCTUnwrap(catalog.targets(f.query()).first)
        let request = f.request(target), selection = try catalog.retain(request)
        catalog.unmount(); XCTAssertFalse(catalog.ownsSelection(requestID: request.invocation.requestId))
        XCTAssertThrowsError(try selection.validate()); XCTAssertThrowsError(try catalog.retain(request))
        XCTAssertTrue(try catalog.targets(f.query()).isEmpty)
    }

    @MainActor func testMonotonicPublicationOverflowRemainsPermanentlyRefused() throws {
        let f = CatalogFixture(), catalog = f.catalog()
        _ = try catalog.targets(f.query())
        catalog.testOnlySetRevisionAtOverflowBoundary()
        catalog.retire()
        XCTAssertThrowsError(try catalog.targets(f.query()))
        catalog.retire()
        XCTAssertThrowsError(try catalog.targets(f.query()))
    }

    @MainActor func testDuplicateOriginalRowsAndOversizeMetadataNeverPublish() throws {
        for mode in ["identity", "stableID", "many", "window", "title"] {
            let f = CatalogFixture(); f.invalid = mode
            if mode == "many" { f.hitCount = 10_001 }
            XCTAssertThrowsError(try f.catalog().targets(f.query()), mode)
        }
    }

    @MainActor func testCancellationAcrossActualAwaitRefusesRetainedSelection() async throws {
        let f = CatalogFixture(), catalog = f.catalog(), target = try XCTUnwrap(catalog.targets(f.query()).first)
        let selection = try catalog.retain(f.request(target))
        let task = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            await Task.yield()
            do { try selection.validateBefore(); return false } catch is CancellationError { return true } catch { return false }
        }
        let cancelled = await task.value
        XCTAssertTrue(cancelled)
        selection.finish(); XCTAssertThrowsError(try catalog.retain(f.request(target)))
    }
}

private typealias Service = NativeSearchContinuationIntentService

@MainActor @Observable private final class OriginalSearchDomainBoundary {
    var query = "private original query"
    var snapshot = ActionBackendSnapshot(backend: .otzaria, generation: 7)
    var window = UUID()
    var rowsRevision: UInt64 = 3
    let session = UUID(), model = UUID()
}

@MainActor private final class CatalogFixture {
    var state: OriginalSearchDomainBoundary? = .init()
    var clock: UInt64 = 10
    var captures = 0, hitCount = 2
    var invalid: String?
    var captureCallback: (@MainActor () throws -> Void)?
    var beforeCallback: (@MainActor () throws -> Void)?
    var foreignCallback: (@MainActor () throws -> Void)?
    let scene = UIStableID(rawValue: "original-search-scene")!

    func catalog() -> MaktabahNativeSearchContinuationCatalog {
        .init(sceneID: scene, capture: { [weak self] in
            guard let self else { throw ActionPortError.staleState }
            return try self.capture()
        }, now: { [weak self] in self?.clock ?? .max })
    }
    func query(kind: Service.Kind? = nil, references: [Service.Reference]? = nil,
               matching: String? = nil) -> Service.Query {
        .init(snapshot: state?.snapshot ?? .init(backend: .otzaria, generation: 7),
              kind: kind, references: references, matching: matching)
    }
    func capture() throws -> MaktabahNativeSearchContinuationCatalog.Captured {
        captures += 1
        guard let original = state else { throw ActionPortError.staleState }
        let latch = NativeComponentSourceObservation {
            _ = original.query; _ = original.snapshot; _ = original.window
        }
        let rowRevision = original.rowsRevision
        let source = Service.Source(sceneID: scene.rawValue, snapshot: original.snapshot,
            sessionID: original.session, modelID: original.model, generation: 3, sourceRevision: 5,
            submissionRevision: 1, cancellationRevision: 0, paginationRevision: 0,
            pageRevision: rowRevision, configuration: Data(original.query.utf8))
        let hits = (0..<hitCount).map { index in
            MaktabahNativeSearchContinuationBinding.MetadataHit(
                title: invalid == "title" ? String(repeating: "x", count: 2_049) : "Original book \(index)",
                hit: .init(stableID: "original-item-\(invalid == "stableID" ? 0 : index)",
                    locator: "otzaria|3891|\(523 + index)", versionTitle: "Original edition", language: "he",
                    identity: Data("actual original identity \(invalid == "identity" ? 0 : index)".utf8)))
        }
        let metadata = MaktabahNativeSearchContinuationBinding.Metadata(source: source, hits: hits, hasNextPage: true,
            before: { [weak self, weak original] in
                try latch.validate()
                guard let original, original.rowsRevision == rowRevision else { throw ActionPortError.staleState }
                let callback = self?.beforeCallback; self?.beforeCallback = nil
                try callback?(); try latch.validate()
                guard original.rowsRevision == rowRevision else { throw ActionPortError.staleState }
            }, foreign: { [weak self, weak original] in
                try latch.validate(); guard original != nil else { throw ActionPortError.staleState }
                let callback = self?.foreignCallback; self?.foreignCallback = nil
                try callback?(); try latch.validate()
                guard original != nil else { throw ActionPortError.staleState }
            })
        let callback = captureCallback; captureCallback = nil; try callback?()
        return .init(metadata: metadata, windowTitle: invalid == "window" ? String(repeating: "w", count: 513) : "Original window")
    }
    func request(_ target: Service.Target, origin: Service.Origin = .appIntent,
                 snapshot: ActionBackendSnapshot? = nil) -> Service.OpenRequest {
        .init(target: target, invocation: .init(requestId: UUID(), snapshot: snapshot ?? target.source.snapshot,
            deadlineUptimeNanoseconds: clock + 5_000_000_000), origin: origin)
    }
    func observation(_ target: Service.Target, changed: String? = nil) -> ActionSearchContinuationObservation {
        let v = target.source
        let source = ActionSearchContinuationSource(observationID: UUID(),
            sceneID: changed == "scene" ? "other scene" : v.sceneID,
            snapshot: changed == "backend" ? .init(backend: .sefaria, generation: 7)
                : changed == "backendGeneration" ? .init(backend: .otzaria, generation: 8) : v.snapshot,
            sessionID: changed == "session" ? UUID() : v.sessionID,
            modelID: changed == "model" ? UUID() : v.modelID,
            generation: v.generation + (changed == "generation" ? 1 : 0),
            sourceRevision: v.sourceRevision + (changed == "source" ? 1 : 0),
            submissionRevision: v.submissionRevision + (changed == "submission" ? 1 : 0),
            cancellationRevision: v.cancellationRevision + (changed == "cancellation" ? 1 : 0),
            paginationRevision: v.paginationRevision + (changed == "pagination" ? 1 : 0),
            pageRevision: v.pageRevision + (changed == "page" ? 1 : 0),
            configuration: changed == "configuration" ? Data("other query".utf8) : v.configuration)
        let hits = target.hit.map { hit in [ActionLoadedSearchHit(token: UUID(), stableID: hit.stableID,
            locator: hit.locator, versionTitle: hit.versionTitle, language: hit.language, identity: hit.identity)] } ?? []
        return .init(source: source, loadedHits: hits, nextPageToken: UUID())
    }
}
