import Foundation
import XCTest
import OtzariaActionCore
import OtzariaUIRouting
@testable import ChavrusaUIRoutingHost

/// Actual service/codec/receipt contracts over an explicit synthetic catalog
/// and native callback boundary. No UIKit, system Intent or provider is run.
final class NativeSearchContinuationIntentServiceTests: XCTestCase, @unchecked Sendable {
    typealias Service = NativeSearchContinuationIntentService

    @MainActor func testRealMetadataIDsAreVersionedQualifiedAndPrivacyBounded() async throws {
        let fixture = try SearchReferenceFixture()
        for backend in ActionBackendID.allCases {
            for kind in Service.Kind.allCases {
                let target = fixture.target(kind, backend: backend)
                XCTAssertEqual(try Service.Reference(identifier: target.id), target.reference)
                XCTAssertEqual(try Service.Reference(publicIntent: target.reference.publicIntent), target.reference)
                for privateValue in [target.source.sceneID, target.source.sessionID.uuidString.lowercased(),
                                     target.source.modelID.uuidString.lowercased(), "private query", "3891", "offset"] {
                    XCTAssertFalse(target.id.contains(privateValue))
                }
            }
        }
        let original = fixture.values[0].id
        for invalid in ["", original.uppercased(), original + ".extra", original + "\n",
                        original.replacingOccurrences(of: ".v1.", with: ".v2."),
                        original.replacingOccurrences(of: ".otzaria.", with: ".unknown."),
                        String(repeating: "a", count: 161)] {
            XCTAssertThrowsError(try Service.Reference(identifier: invalid))
        }
    }

    @MainActor func testDiscoveryPreservesKindActualTitleAndBoundedIdentifierQueries() async throws {
        let fixture = try SearchReferenceFixture()
        fixture.values.append(fixture.target(.nextPage))
        let service = fixture.service()
        XCTAssertEqual(try service.targets(kind: .result), [fixture.values[0]])
        XCTAssertEqual(try service.targets(kind: .nextPage), [fixture.values[1]])
        XCTAssertEqual(try service.targets(matching: "משנה").count, 1)
        XCTAssertTrue(try service.targets(identifiers: [fixture.target().id]).isEmpty)
        for identifiers in [[fixture.values[0].id, fixture.values[0].id], Array(repeating: "bad", count: 65), ["invalid"]] {
            XCTAssertThrowsError(try service.targets(identifiers: identifiers))
        }
        XCTAssertThrowsError(try service.targets(matching: String(repeating: "a", count: 513)))
        XCTAssertEqual(fixture.navigationCalls, 0)
    }

    @MainActor func testUnqualifiedDuplicateOversizeAndWrongKindCatalogsFail() async throws {
        let fixture = try SearchReferenceFixture(), service = fixture.service()
        fixture.rawCatalog = { _ in Array(repeating: fixture.values[0], count: 65) }
        XCTAssertThrowsError(try service.targets())
        fixture.rawCatalog = { _ in [fixture.values[0], fixture.values[0]] }
        XCTAssertThrowsError(try service.targets())
        fixture.rawCatalog = { _ in [fixture.target(.nextPage)] }
        XCTAssertThrowsError(try service.targets(kind: .result))
        fixture.rawCatalog = { _ in [fixture.target(title: " ")] }
        XCTAssertThrowsError(try service.targets())
        fixture.rawCatalog = { _ in [fixture.target(title: String(repeating: "x", count: 2049))] }
        XCTAssertThrowsError(try service.targets())
        fixture.rawCatalog = { _ in [fixture.target(backend: .sefaria)] }
        XCTAssertThrowsError(try service.targets())
        XCTAssertEqual(fixture.navigationCalls, 0)
    }

    @MainActor func testBackendChangeDuringDiscoveryAndBeforeDeliveryCannotRetarget() async throws {
        let fixture = try SearchReferenceFixture(), service = fixture.service(), target = fixture.values[0]
        fixture.onQuery = { fixture.snapshot = .init(backend: .otzaria, generation: 8) }
        XCTAssertThrowsError(try service.targets())
        fixture.onQuery = nil; fixture.snapshot = .init(backend: .sefaria, generation: 7)
        do { _ = try await service.open(identifier: target.id, kind: .result); XCTFail("Silently switched library") }
        catch { XCTAssertEqual((error as? UIRouteError)?.status, .requiresBackendSwitch) }
        XCTAssertEqual(fixture.navigationCalls, 0)
    }

    @MainActor func testMissingReferenceWrongKindAndForeignReceivingSceneRefuseBeforeNavigation() async throws {
        let fixture = try SearchReferenceFixture(), service = fixture.service(), target = fixture.values[0]
        do { _ = try await service.open(identifier: fixture.target().id, kind: .result); XCTFail("Invented result") } catch {}
        do { _ = try await service.open(identifier: target.id, kind: .nextPage); XCTFail("Changed operation kind") } catch {}
        do {
            _ = try await service.open(public: target.reference.publicIntent,
                receivingSceneID: .init(rawValue: "another-window")!)
            XCTFail("Imported window identity")
        } catch { XCTAssertEqual((error as? UIRouteError)?.code, "native_search_reference_scene_mismatch") }
        XCTAssertEqual(fixture.navigationCalls, 0)
    }

    @MainActor func testActualCommandAndSelectedHitAreJoinedToTheRetainedRequest() async throws {
        let fixture = try SearchReferenceFixture(), service = fixture.service(), target = fixture.values[0]
        let receipt = try await service.open(identifier: target.id, kind: .result)
        let request = try XCTUnwrap(fixture.lastRequest)
        XCTAssertEqual(request.target, target); XCTAssertEqual(request.origin, .appIntent)
        XCTAssertEqual(request.invocation.deadlineUptimeNanoseconds, fixture.clock + 5_000_000_000)
        XCTAssertEqual(receipt.requestID, request.invocation.requestId)
        XCTAssertTrue(target.source.matches(receipt.before))
        guard case .hitSelectionApplied(let hit) = receipt.effects.first else { return XCTFail("No original hit effect") }
        XCTAssertTrue(try XCTUnwrap(target.hit).matches(hit))
        XCTAssertEqual(fixture.navigationCalls, 1)
    }

    @MainActor func testNextPageKeepsTheOriginalPageArithmeticAndEffectOrder() async throws {
        let fixture = try SearchReferenceFixture(), target = fixture.target(.nextPage)
        fixture.values = [target]
        let receipt = try await fixture.service().open(identifier: target.id, kind: .nextPage)
        XCTAssertEqual(receipt.after.pageRevision, receipt.before.pageRevision + 1)
        XCTAssertEqual(receipt.after.paginationRevision, receipt.before.paginationRevision + 1)
        guard receipt.effects.count == 2, case .pageRequested(let request) = receipt.effects[0],
              case .pageCommitted(let page) = receipt.effects[1] else { return XCTFail("Missing actual page evidence") }
        XCTAssertEqual(request, page.attemptID); XCTAssertEqual(page.cursorBefore, page.requestOffset)
        XCTAssertNil(receipt.visible.rowID); XCTAssertNil(receipt.visible.identity)
    }

    @MainActor func testForeignCommandAndForeignHitCannotDonateSuccess() async throws {
        for change in 0..<4 {
            let fixture = try SearchReferenceFixture(), target = fixture.values[0]
            var raw: Service.Execution?
            fixture.navigate = { request in
                let original = fixture.success(request)
                let invocation = ActionPortInvocation(requestId: change == 0 ? UUID() : request.invocation.requestId,
                    snapshot: request.invocation.snapshot,
                    deadlineUptimeNanoseconds: request.invocation.deadlineUptimeNanoseconds + (change == 1 ? 1 : 0))
                let source = change == 2
                    ? fixture.originalSource(target.source, scene: "foreign-window") : original.command.source
                guard case .acknowledged(let returned) = original.outcome else { throw ActionPortError.invalidResponse }
                let selfConsistentForeign = ActionSearchContinuationReceipt(requestID: invocation.requestId,
                    before: source, after: source, operation: original.command.operation,
                    effects: returned.effects, visible: returned.visible)
                var result = Service.Execution(command: .init(source: source,
                    operation: original.command.operation, invocation: invocation), outcome: .acknowledged(selfConsistentForeign))
                if change == 3 {
                    let hit = ActionLoadedSearchHit(token: fixture.operationToken, stableID: "foreign-hit",
                        locator: "foreign", versionTitle: nil, language: nil, identity: Data("foreign".utf8))
                    let receipt = ActionSearchContinuationReceipt(requestID: request.invocation.requestId,
                        before: original.command.source, after: original.command.source, operation: original.command.operation,
                        effects: [.hitSelectionApplied(hit)], visible: .init(witnessID: UUID(), listID: UUID(), rowID: UUID(),
                            layoutRevision: 1, identity: hit.identity))
                    result = .init(command: original.command, outcome: .acknowledged(receipt))
                }
                raw = result; return result
            }
            do { _ = try await fixture.service().open(identifier: target.id, kind: .result); XCTFail("Foreign return accepted") }
            catch let error as Service.Failure {
                XCTAssertEqual(error.code, "native_effect_uncertain")
                XCTAssertEqual(error.execution.command, raw?.command); XCTAssertEqual(error.execution.outcome, raw?.outcome)
            }
        }
    }

    @MainActor func testJoinedRefusalRetainsActualPartialEffects() async throws {
        let fixture = try SearchReferenceFixture(), target = fixture.values[0]
        var raw: Service.Execution?
        fixture.navigate = { request in
            let original = fixture.success(request)
            guard case .acknowledged(let receipt) = original.outcome else { throw ActionPortError.invalidResponse }
            let refused = ActionSearchContinuationOutcome.refused(.init(requestID: request.invocation.requestId,
                reason: .staleSource, effects: receipt.effects, source: original.command.source, operation: original.command.operation))
            let result = Service.Execution(command: original.command, outcome: refused); raw = result; return result
        }
        do { _ = try await fixture.service().open(identifier: target.id, kind: .result); XCTFail("Partial refusal became success") }
        catch let error as Service.Failure {
            XCTAssertEqual(error.status, .staleState); XCTAssertEqual(error.execution.outcome, raw?.outcome)
            guard case .refused(let refusal) = error.execution.outcome else { return XCTFail("Lost refusal") }
            XCTAssertEqual(refusal.effects.count, 1)
        }
    }

    @MainActor func testUnqualifiedNestedResponseAndMalformedReceiptRemainInspectible() async throws {
        for nested in [false, true] {
            let fixture = try SearchReferenceFixture(), target = fixture.values[0]
            var raw: Service.Execution?
            fixture.navigate = { request in
                let original = fixture.success(request)
                let returned: ActionSearchContinuationOutcome
                if nested {
                    returned = .unqualified(command: original.command,
                        originalResponse: .unqualified(command: original.command, originalResponse: original.outcome))
                } else {
                    guard case .acknowledged(let receipt) = original.outcome else { throw ActionPortError.invalidResponse }
                    returned = .acknowledged(.init(requestID: receipt.requestID, before: receipt.before, after: receipt.after,
                        operation: receipt.operation, effects: receipt.effects,
                        visible: .init(witnessID: UUID(), listID: UUID(), rowID: nil, layoutRevision: 0, identity: nil)))
                }
                let result = Service.Execution(command: original.command, outcome: returned); raw = result; return result
            }
            do { _ = try await fixture.service().open(identifier: target.id, kind: .result); XCTFail("Unqualified return accepted") }
            catch let error as Service.Failure { XCTAssertEqual(error.execution.outcome, raw?.outcome) }
        }
    }

    @MainActor func testLateDeadlineAndBackendRefusalKeepTheActualAcknowledgement() async throws {
        for backendChanges in [false, true] {
            let fixture = try SearchReferenceFixture(), target = fixture.values[0]
            fixture.navigate = { request in
                let observed = fixture.success(request)
                if backendChanges { fixture.snapshot = .init(backend: .otzaria, generation: 8) }
                else { fixture.clock = request.invocation.deadlineUptimeNanoseconds }
                return observed
            }
            do { _ = try await fixture.service().open(identifier: target.id, kind: .result); XCTFail("Late handoff accepted") }
            catch let error as Service.Failure {
                guard case .acknowledged(let receipt) = error.execution.outcome else { return XCTFail("Actual return discarded") }
                XCTAssertEqual(receipt.effects.count, 1)
                XCTAssertEqual(error.status, backendChanges ? .staleState : .cancelled)
            }
        }
    }

    @MainActor func testActualTaskCancellationAtAcknowledgementHandoffPreservesReturn() async throws {
        let fixture = try SearchReferenceFixture(), target = fixture.values[0]
        fixture.navigate = { request in
            let observed = fixture.success(request)
            withUnsafeCurrentTask { $0?.cancel() }
            return observed
        }
        let task = Task { @MainActor in try await fixture.service().open(identifier: target.id, kind: .result) }
        do { _ = try await task.value; XCTFail("Cancelled handoff accepted") }
        catch let error as Service.Failure {
            XCTAssertEqual(error.status, .cancelled)
            guard case .acknowledged(let receipt) = error.execution.outcome else { return XCTFail("Lost actual receipt") }
            XCTAssertEqual(receipt.effects.count, 1)
        }
        XCTAssertFalse(Task.isCancelled)
    }

    @MainActor func testCanonicalCustomAndVerifiedHTTPSUseSameCodecWithoutPrivateData() async throws {
        let fixture = try SearchReferenceFixture(), target = fixture.values[0]
        let service = fixture.service(), custom = try service.link(identifier: target.id)
        XCTAssertEqual(custom.scheme, "maktabah")
        XCTAssertEqual(try NativePublicNavigationURLV2.decode(custom, registry: fixture.registry), target.reference.publicIntent)
        let components = try XCTUnwrap(URLComponents(url: custom, resolvingAgainstBaseURL: false))
        let universal = try XCTUnwrap(URL(string: "https://davidpovarsky.github.io/chavrusatext/action"
            + components.percentEncodedPath + "?" + (components.percentEncodedQuery ?? "")))
        let mapped = try XCTUnwrap(NativePublicNavigationURLV2.customURL(forUniversalLink: universal, scheme: "maktabah"))
        XCTAssertEqual(mapped, custom)
        XCTAssertFalse(custom.absoluteString.contains("private query")); XCTAssertFalse(custom.absoluteString.contains("cursor"))
        let receipt = try await service.open(public: NativePublicNavigationURLV2.decode(mapped, registry: fixture.registry),
            receivingSceneID: .init(rawValue: target.source.sceneID)!)
        XCTAssertEqual(receipt.requestID, fixture.lastRequest?.invocation.requestId)
        XCTAssertEqual(fixture.lastRequest?.origin, .deepLink(receivingSceneID: .init(rawValue: target.source.sceneID)!))
        XCTAssertEqual(fixture.navigationCalls, 1)
    }

    @MainActor func testMixedURLPayloadsAndChangedLinkSourceCannotBePublished() async throws {
        let fixture = try SearchReferenceFixture(), target = fixture.values[0], service = fixture.service()
        let original = try service.link(identifier: target.id)
        for suffix in ["&query=private", "&route=duplicate", "#fragment", "&searchReference=other"] {
            XCTAssertThrowsError(try NativePublicNavigationURLV2.decode(XCTUnwrap(URL(string: original.absoluteString + suffix)), registry: fixture.registry))
        }
        let conflict = original.absoluteString.replacingOccurrences(of: "/native.search.result?", with: "/native.search.nextPage?")
        XCTAssertThrowsError(try NativePublicNavigationURLV2.decode(XCTUnwrap(URL(string: conflict)), registry: fixture.registry))
        let before = fixture.queryCalls
        fixture.onQuery = {
            if fixture.queryCalls >= before + 2 { fixture.values = [] }
        }
        XCTAssertThrowsError(try service.link(identifier: target.id))
        XCTAssertEqual(fixture.navigationCalls, 0)
    }

    @MainActor func testDeadlineOverflowAndExpiryBeforeCallbackHaveNoEffect() async throws {
        let fixture = try SearchReferenceFixture(), target = fixture.values[0], service = fixture.service()
        fixture.clock = UInt64.max - 1
        do { _ = try await service.open(identifier: target.id, kind: .result); XCTFail("Overflow renewed deadline") } catch {}
        fixture.clock = 10
        fixture.onQuery = { fixture.clock = 5_000_000_010 }
        do { _ = try await service.open(identifier: target.id, kind: .result); XCTFail("Expired before dispatch") } catch {}
        XCTAssertEqual(fixture.navigationCalls, 0)
    }
}

@MainActor private final class SearchReferenceFixture {
    typealias Service = NativeSearchContinuationIntentService
    var snapshot = ActionBackendSnapshot(backend: .otzaria, generation: 7)
    var clock: UInt64 = 10
    var values: [Service.Target] = []
    var queryCalls = 0, navigationCalls = 0
    var lastRequest: Service.OpenRequest?
    var onQuery: (@MainActor () throws -> Void)?
    var rawCatalog: (@MainActor (Service.Query) throws -> [Service.Target])?
    var navigate: (@MainActor (Service.OpenRequest) async throws -> Service.Execution)?
    let operationToken = UUID(), sessionID = UUID(), modelID = UUID()
    let registry: UIDestinationRegistry
    init() throws {
        registry = try .init(descriptors: Service.Kind.allCases.map {
            .init(id: $0.destination, title: $0.rawValue, implementation: .implemented,
                  supportedBackends: ActionBackendID.allCases, presentations: [.currentTab],
                  publicNavigationV2: .init(rules: [.init(presentation: .currentTab, allowsRoot: false)], searchReferenceKind: $0))
        })
        values = [target()]
    }
    func target(_ kind: Service.Kind = .result, backend: ActionBackendID = .otzaria,
                title: String? = nil) -> Service.Target {
        .init(reference: .init(backend: backend, kind: kind, metadataID: UUID()),
              title: title ?? (kind == .result ? "משנה — Original window" : "Next page — Original window"),
              source: .init(sceneID: "original-window-a", snapshot: .init(backend: backend, generation: 7,
                    rpcEpoch: backend == .sefariaEmbedded ? 9 : nil), sessionID: sessionID, modelID: modelID,
                  generation: 3, sourceRevision: 5, submissionRevision: 1, cancellationRevision: 0,
                  paginationRevision: 0, pageRevision: 1, configuration: Data("private query configuration".utf8)),
              hit: kind == .result ? .init(stableID: "original-hit", locator: "otzaria|3891|523", versionTitle: "Original version",
                  language: "he", identity: Data("exact original item identity".utf8)) : nil)
    }
    func service() -> Service {
        Service(snapshot: { self.snapshot }, catalog: { query in
            self.queryCalls += 1; try self.onQuery?()
            if let raw = self.rawCatalog { return try raw(query) }
            return self.values.filter {
                (query.kind == nil || $0.reference.kind == query.kind)
                    && (query.references == nil || query.references!.contains($0.reference))
                    && (query.matching == nil || query.matching!.isEmpty || $0.title.localizedCaseInsensitiveContains(query.matching!))
            }
        }, navigate: { request in
            self.navigationCalls += 1; self.lastRequest = request
            if let navigate = self.navigate { return try await navigate(request) }
            return self.success(request)
        }, registry: registry, now: { self.clock })
    }
    func originalSource(_ value: Service.Source, scene: String? = nil,
                        observationID: UUID = UUID(), pageAdvance: Int = 0) -> ActionSearchContinuationSource {
        .init(observationID: observationID, sceneID: scene ?? value.sceneID, snapshot: value.snapshot,
              sessionID: value.sessionID, modelID: value.modelID, generation: value.generation,
              sourceRevision: value.sourceRevision, submissionRevision: value.submissionRevision,
              cancellationRevision: value.cancellationRevision, paginationRevision: value.paginationRevision + pageAdvance,
              pageRevision: value.pageRevision + UInt64(pageAdvance), configuration: value.configuration)
    }
    func success(_ request: Service.OpenRequest) -> Service.Execution {
        let source = originalSource(request.target.source)
        let operation: ActionSearchContinuationOperation
        let effects: [ActionSearchContinuationEffect]
        let visible: ActionSearchVisibleReceipt
        let after: ActionSearchContinuationSource
        switch request.target.reference.kind {
        case .result:
            operation = .revealLoadedHit(token: operationToken)
            let item = request.target.hit!
            let hit = ActionLoadedSearchHit(token: operationToken, stableID: item.stableID, locator: item.locator,
                versionTitle: item.versionTitle, language: item.language, identity: item.identity)
            effects = [.hitSelectionApplied(hit)]; after = source
            visible = .init(witnessID: UUID(), listID: UUID(), rowID: UUID(), layoutRevision: 4, identity: item.identity)
        case .nextPage:
            operation = .nextOriginalPage(token: operationToken)
            let attempt = UUID()
            let page = ActionSearchOriginalPageReceipt(attemptID: attempt, modelID: source.modelID, generation: source.generation,
                pageRevision: source.pageRevision + 1, request: Data("original page request".utf8), requestOffset: 20,
                requestLimit: 20, rawRowCount: 2, mappedRowCount: 2, consumedBefore: 20, consumedAfter: 22,
                cursorBefore: 20, rawNextOffset: 22, normalizedNextOffset: 22, hasMore: true, sourceEvidence: nil)
            effects = [.pageRequested(attemptID: attempt), .pageCommitted(page)]
            after = originalSource(request.target.source, observationID: source.observationID, pageAdvance: 1)
            visible = .init(witnessID: UUID(), listID: UUID(), rowID: nil, layoutRevision: 4, identity: nil)
        }
        let command = ActionSearchContinuationCommand(source: source, operation: operation, invocation: request.invocation)
        return .init(command: command, outcome: .acknowledged(.init(requestID: request.invocation.requestId,
            before: source, after: after, operation: operation, effects: effects, visible: visible)))
    }
}
