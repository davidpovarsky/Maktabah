import Foundation
import XCTest
import OtzariaActionCore
import OtzariaUIRouting
@testable import ChavrusaUIRoutingHost

// Actual package contracts and source are compiled. The catalog/native transports
// below are explicit doubles; these tests do not establish UIKit or Siri success.
@MainActor final class NativeSearchIntentServiceTests: XCTestCase, @unchecked Sendable {
    func testByteExactQueryAndQualifiedScopesReachOneOriginalActionRequest() async throws {
        let fixture = SearchIntentFixture(), service = fixture.service()
        let work = try NativeReaderIntentService.Work(reference: fixture.work, title: "Book")
        let query = "  \u{05D0}\u{05B0} \u{0065}\u{0301}\n"
        let result = try await service.open(query: query, scopeIdentifiers: [work.id],
            sort: .canonical, windowIdentifier: fixture.window("scene.B").id)
        guard case .acknowledged(let receipt) = result else { return XCTFail("Actual receipt required") }
        XCTAssertEqual(fixture.opened.count, 1)
        let request = try XCTUnwrap(fixture.opened.first)
        XCTAssertEqual(Array(request.query.search.text.utf8), Array(query.utf8))
        XCTAssertEqual(request.query.search.scopeWorkRefs, [fixture.work])
        XCTAssertEqual(request.query.search.sortOrder, .canonical)
        XCTAssertEqual(request.expectedSnapshot, fixture.source)
        XCTAssertEqual(request.window.sceneID.rawValue, "scene.B")
        XCTAssertEqual(receipt.sceneID.rawValue, "scene.B")
        XCTAssertEqual(receipt.requestId, request.requestId)
        let arguments = try request.query.actionArguments()
        XCTAssertEqual(try ActionSearchResultsQuery.arguments(arguments, backend: .otzaria), request.query)
        XCTAssertNil(arguments["searchQuery"]?.object?["offset"])
        XCTAssertNil(arguments["searchQuery"]?.object?["limit"])
        XCTAssertTrue(fixture.metadataRequests.isEmpty, "Execution leaves scope re-resolution with original search.openResults Core")
    }

    func testPresentHitAndCursorIncludingEmptyCannotBeDiscarded() async throws {
        for value in ["", "selected-result"] {
            for hit in [true, false] {
                let fixture = SearchIntentFixture(), service = fixture.service()
                do {
                    _ = try await service.open(query: "source",
                        selectedHit: hit ? value : nil, cursor: hit ? nil : value,
                        windowIdentifier: fixture.window("scene.A").id)
                    XCTFail("Unsupported semantic input was ignored")
                } catch {
                    XCTAssertEqual((error as? UIRouteError)?.status, .notSupported)
                    XCTAssertEqual((error as? UIRouteError)?.code,
                        hit ? "native_search_hit_not_supported" : "native_search_cursor_not_supported")
                }
                XCTAssertEqual(fixture.windowReads, 0)
                XCTAssertTrue(fixture.opened.isEmpty); XCTAssertTrue(fixture.metadataRequests.isEmpty)
            }
        }
    }

    func testOriginalUnsupportedModesAndMatchNeverNavigate() async throws {
        let inputs: [(ActionSearchQuery.Mode, ActionSearchQuery.Match, Int)] = [
            (.contains, .exact, 0), (.or, .exact, 0), (.near, .exact, 2),
            (.phrase, .hebrewLemmatized, 0), (.phrase, .exact, 1)
        ]
        for (mode, match, distance) in inputs {
            let fixture = SearchIntentFixture(), service = fixture.service()
            do {
                _ = try await service.open(query: "\u{05D0}", mode: mode, match: match,
                    wordDistance: distance, windowIdentifier: fixture.window("scene.A").id)
                XCTFail("Original native mode gate was bypassed")
            } catch { XCTAssertEqual((error as? UIRouteError)?.status, .notSupported) }
            XCTAssertTrue(fixture.opened.isEmpty)
        }
    }

    func testOriginalBackendSortRestrictionsRemainExplicit() async throws {
        for (backend, sort) in [(ActionBackendID.otzaria, ActionSearchQuery.Sort.chronological),
                                (.sefariaEmbedded, .canonical), (.sefariaEmbedded, .chronological)] {
            let fixture = SearchIntentFixture(backend: backend), service = fixture.service()
            do {
                _ = try await service.open(query: "source", sort: sort, windowIdentifier: fixture.window("scene.A").id)
                XCTFail("Unsupported sort was dropped")
            } catch {
                XCTAssertEqual((error as? UIRouteError)?.status, .notSupported)
                XCTAssertEqual((error as? UIRouteError)?.code, "search_sort_not_supported")
            }
            XCTAssertTrue(fixture.opened.isEmpty)
        }
        let legacy = SearchIntentFixture(backend: .sefaria)
        _ = try await legacy.service().open(query: "source", sort: .chronological,
            windowIdentifier: legacy.window("scene.A").id)
        XCTAssertEqual(legacy.opened.first?.query.search.sortOrder, .chronological)
    }

    func testAllThreeBackendsUseTheirOwnSnapshotForSupportedPhrase() async throws {
        for backend in ActionBackendID.allCases {
            let fixture = SearchIntentFixture(backend: backend)
            _ = try await fixture.service().open(query: "source", windowIdentifier: fixture.window("scene.A").id)
            XCTAssertEqual(fixture.opened.first?.query.search.backend, backend)
            XCTAssertEqual(fixture.opened.first?.expectedSnapshot, fixture.source)
        }
    }

    func testNonOtzariaScopesAndCatalogRevisionsAreNotSilentlyDropped() async throws {
        for backend in [ActionBackendID.sefaria, .sefariaEmbedded] {
            let fixture = SearchIntentFixture(backend: backend), service = fixture.service()
            let scope = try NativeReaderIntentService.Work(reference: .init(backend: backend, workKey: "Source"), title: "Source")
            do {
                _ = try await service.open(query: "source", scopeIdentifiers: [scope.id],
                    windowIdentifier: fixture.window("scene.A").id)
                XCTFail("Native scope gate bypassed")
            } catch { XCTAssertEqual((error as? UIRouteError)?.status, .notSupported) }
            XCTAssertTrue(fixture.opened.isEmpty)
        }
        let fixture = SearchIntentFixture(), service = fixture.service()
        let versioned = try NativeReaderIntentService.Work(
            reference: .init(backend: .otzaria, workKey: "book:7", catalogRevision: "retained-version"), title: "Source")
        do {
            _ = try await service.open(query: "source", scopeIdentifiers: [versioned.id],
                windowIdentifier: fixture.window("scene.A").id)
            XCTFail("Unsupported scope revision")
        } catch { XCTAssertEqual((error as? UIRouteError)?.code, "scope_revision_not_supported") }
        XCTAssertTrue(fixture.opened.isEmpty)
    }

    func testCrossBackendScopeDoesNotSelectOrSwitchTheLibrary() async throws {
        let fixture = SearchIntentFixture(), service = fixture.service()
        let other = try NativeReaderIntentService.Work(reference: .init(backend: .sefaria, workKey: "Source"), title: "Source")
        do {
            _ = try await service.open(query: "source", scopeIdentifiers: [other.id],
                windowIdentifier: fixture.window("scene.A").id)
            XCTFail("Cross-backend scope")
        } catch { XCTAssertEqual((error as? UIRouteError)?.status, .requiresBackendSwitch) }
        XCTAssertEqual(fixture.source.backend, .otzaria)
        XCTAssertTrue(fixture.opened.isEmpty)
    }

    func testMalformedAndNoncanonicalScopeCannotReachTheHost() async throws {
        let bytes = Data(#"{"backend":"otzaria","extra":"ignored","workKey":"book:7"}"#.utf8)
        let extra = "maktabah.work.v1." + bytes.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        for identifier in ["wrong", "maktabah.work.v1.!!!!", extra] {
            let fixture = SearchIntentFixture()
            do {
                _ = try await fixture.service().open(query: "source", scopeIdentifiers: [identifier],
                    windowIdentifier: fixture.window("scene.A").id)
                XCTFail("Malformed identity")
            } catch {}
            XCTAssertTrue(fixture.opened.isEmpty); XCTAssertTrue(fixture.metadataRequests.isEmpty)
        }
    }

    func testBoundsAndDuplicateScopesFailBeforeWindowResolution() async throws {
        for text in ["", " \n", String(repeating: "x", count: 1_001), String(repeating: "\u{0301}", count: 2_001)] {
            let fixture = SearchIntentFixture()
            do {
                _ = try await fixture.service().open(query: text, windowIdentifier: fixture.window("scene.A").id)
                XCTFail("Unbounded or blank query")
            } catch { XCTAssertEqual((error as? UIRouteError)?.code, "invalid_intent_query") }
            XCTAssertEqual(fixture.windowReads, 0); XCTAssertTrue(fixture.opened.isEmpty)
        }
        let fixture = SearchIntentFixture(), service = fixture.service()
        let id = try NativeReaderIntentService.Work(reference: fixture.work, title: "Source").id
        for ids in [[id, id], Array(repeating: id, count: 201)] {
            do {
                _ = try await service.open(query: "source", scopeIdentifiers: ids, windowIdentifier: fixture.window("scene.A").id)
                XCTFail("Duplicate or unbounded scope")
            } catch { XCTAssertEqual((error as? UIRouteError)?.code, "invalid_intent_search_scope") }
        }
        XCTAssertEqual(fixture.windowReads, 0); XCTAssertTrue(fixture.opened.isEmpty)
    }

    func testSearchWindowMetadataDoesNotIncludeComponentsOrOtherRoots() throws {
        let fixture = SearchIntentFixture(), service = fixture.service()
        let a = fixture.window("scene.A")
        fixture.windowOverride = [a, fixture.window("scene.B"),
            .init(backend: .otzaria, destination: a.destination, title: "Query field", sceneID: a.sceneID,
                  component: UIDestinationID(rawValue: "native.search.query")!),
            .init(backend: .otzaria, destination: UIDestinationID(rawValue: "native.library")!, title: "Library", sceneID: a.sceneID)]
        XCTAssertEqual(try service.windows().map(\.id), [a.id, fixture.window("scene.B").id])
        XCTAssertEqual(try service.windows(identifiers: [a.id]), [a])
        XCTAssertEqual(try service.windows(matching: "scene.B").map(\.sceneID.rawValue), ["scene.B"])
        XCTAssertTrue(fixture.metadataRequests.isEmpty); XCTAssertTrue(fixture.opened.isEmpty)
    }

    func testMissingWindowDoesNotChooseTheOtherAvailableScene() async throws {
        let fixture = SearchIntentFixture(), service = fixture.service()
        let removed = fixture.window("scene.A")
        fixture.windowOverride = [fixture.window("scene.B")]
        do {
            _ = try await service.open(query: "source", windowIdentifier: removed.id)
            XCTFail("A different window was chosen")
        } catch { XCTAssertEqual((error as? UIRouteError)?.code, "intent_window_no_longer_available") }
        XCTAssertTrue(fixture.opened.isEmpty)
    }

    func testDuplicateCatalogCannotBeHiddenBySelectedWindowFilter() async throws {
        let fixture = SearchIntentFixture(), service = fixture.service()
        let a = fixture.window("scene.A"), b = fixture.window("scene.B")
        fixture.windowOverride = [a, a, b]
        do { _ = try service.windows(identifiers: [b.id]); XCTFail("Corrupt catalog") }
        catch { XCTAssertEqual((error as? UIRouteError)?.code, "invalid_live_intent_catalog") }
        do {
            _ = try await service.open(query: "source", windowIdentifier: b.id)
            XCTFail("Corrupt catalog")
        } catch { XCTAssertEqual((error as? UIRouteError)?.code, "invalid_live_intent_catalog") }
        XCTAssertTrue(fixture.opened.isEmpty)
    }

    func testWindowMetadataBoundsNeverInvokeOriginalHost() throws {
        let fixture = SearchIntentFixture(), service = fixture.service()
        XCTAssertThrowsError(try service.windows(identifiers: Array(repeating: "id", count: 65)))
        XCTAssertThrowsError(try service.windows(matching: String(repeating: "x", count: 513)))
        XCTAssertEqual(fixture.windowReads, 0)
    }

    func testScopeEntityMetadataUsesExistingCoreAndPreservesMissingVsUnavailable() async throws {
        let fixture = SearchIntentFixture(), service = fixture.service()
        let values = try await service.scopeBooks(matching: "Source")
        XCTAssertEqual(values.map(\.reference), [fixture.work])
        XCTAssertEqual(fixture.metadataRequests.first?.action, "catalog.resolveWork")
        XCTAssertEqual(fixture.metadataRequests.first?.requestedPresentation, .headless)
        XCTAssertEqual(fixture.metadataRequests.first?.arguments["query"], .string("Source"))
        fixture.metadataOverride = { request, source in
            .init(result: .init(request: request, status: .failed,
                  error: .init(code: "not_found", message: "")), snapshot: source)
        }
        let missing = try await service.scopeBooks(identifiers: values.map(\.id))
        XCTAssertTrue(missing.isEmpty)
        fixture.metadataOverride = { request, source in
            .init(result: .init(request: request, status: .unavailable,
                  error: .init(code: "backend_unavailable", message: "")), snapshot: source)
        }
        do { _ = try await service.scopeBooks(matching: "Source"); XCTFail("Unavailable became empty success") }
        catch { XCTAssertEqual((error as? NativeIntentOutcome)?.status, .unavailable) }
        XCTAssertTrue(fixture.opened.isEmpty)
    }

    func testUnsupportedScopeMetadataDoesNotAdvertiseAnotherBackend() async throws {
        for backend in [ActionBackendID.sefaria, .sefariaEmbedded] {
            let fixture = SearchIntentFixture(backend: backend), service = fixture.service()
            let matching = try await service.scopeBooks(matching: "Source")
            let cached = try await service.scopeBooks(identifiers: ["cached-id"])
            XCTAssertTrue(matching.isEmpty)
            XCTAssertTrue(cached.isEmpty)
            XCTAssertTrue(fixture.metadataRequests.isEmpty); XCTAssertTrue(fixture.opened.isEmpty)
        }
        let fixture = SearchIntentFixture(), service = fixture.service()
        fixture.metadataWork = .init(backend: .otzaria, workKey: "book:7", catalogRevision: "unsupported-version")
        let versioned = try await service.scopeBooks(matching: "Source")
        XCTAssertTrue(versioned.isEmpty)
    }

    func testBackendABAWhileCoreMetadataAwaitsCannotPublishOldEntity() async throws {
        let fixture = SearchIntentFixture(), service = fixture.service()
        fixture.metadataOverride = { request, old in
            fixture.source = .init(backend: .sefaria, generation: old.generation + 1)
            fixture.source = .init(backend: .otzaria, generation: old.generation + 2)
            return .init(result: .init(request: request, status: .completed,
                data: ["workRef": try ActionJSON.encoded(fixture.work)],
                backend: old.backend, backendGeneration: old.generation), snapshot: old)
        }
        do { _ = try await service.scopeBooks(matching: "Source"); XCTFail("ABA accepted") }
        catch { XCTAssertEqual((error as? UIRouteError)?.code, "intent_source_generation_changed") }
        XCTAssertTrue(fixture.opened.isEmpty)
    }

    func testEveryNoncompletionKeepsTheOriginalResultAndNeverAcknowledges() async throws {
        let statuses: [ActionStatus] = [.uiQueued, .requiresForeground, .requiresBackendSwitch,
            .requiresConfirmation, .needsDisambiguation, .notSupported, .unavailable, .staleState, .cancelled, .failed]
        for status in statuses {
            let fixture = SearchIntentFixture(), service = fixture.service()
            fixture.navigationOverride = { request in
                let raw = ActionResult(request: fixture.coreRequest(request), status: status,
                    error: .init(code: "original_refusal", message: ""),
                    backend: request.expectedSnapshot.backend, backendGeneration: request.expectedSnapshot.generation,
                    effects: ["original_observed_effect"])
                return .init(result: raw, receipt: nil)
            }
            do {
                _ = try await service.open(query: "source", windowIdentifier: fixture.window("scene.A").id)
                XCTFail("Noncompletion became success: \(status)")
            } catch let failure as NativeSearchIntentService.Failure {
                XCTAssertEqual(failure.status, status)
                XCTAssertEqual(failure.code, "original_refusal")
                XCTAssertEqual(failure.observation.result.status, status)
                XCTAssertEqual(failure.observation.result.effects, ["original_observed_effect"])
            }
        }
    }

    func testCompletedCoreResultWithoutActualNativeReceiptIsUncertain() async throws {
        let fixture = SearchIntentFixture(), service = fixture.service()
        fixture.navigationOverride = { request in
            let good = fixture.observation(request)
            return .init(result: good.result, receipt: nil)
        }
        do {
            _ = try await service.open(query: "source", windowIdentifier: fixture.window("scene.A").id)
            XCTFail("No native acknowledgement")
        } catch let failure as NativeSearchIntentService.Failure {
            XCTAssertEqual(failure.status, .failed); XCTAssertEqual(failure.code, "native_effect_uncertain")
            XCTAssertEqual(failure.observation.result.status, .completed)
        }
    }

    func testCorruptReceiptOrCoreIdentityCannotBeAcknowledged() async throws {
        for mutation in SearchIntentFixture.Mutation.allCases {
            let fixture = SearchIntentFixture(), service = fixture.service()
            fixture.navigationOverride = { fixture.observation($0, mutation: mutation) }
            do {
                _ = try await service.open(query: "source", windowIdentifier: fixture.window("scene.A").id)
                XCTFail("Accepted mismatched result: \(mutation)")
            } catch let failure as NativeSearchIntentService.Failure {
                XCTAssertEqual(failure.status, .failed, "\(mutation)")
                XCTAssertEqual(failure.code, "native_effect_uncertain", "\(mutation)")
                XCTAssertNotNil(failure.observation.receipt)
            }
        }
    }

    func testFreshBackendAndRPCEpochAreCheckedAfterNativeAwait() async throws {
        for epochOnly in [false, true] {
            let fixture = SearchIntentFixture(backend: epochOnly ? .sefariaEmbedded : .otzaria), service = fixture.service()
            fixture.navigationOverride = { request in
                let old = request.expectedSnapshot
                fixture.source = .init(backend: old.backend,
                    generation: epochOnly ? old.generation : old.generation + 1,
                    rpcEpoch: epochOnly ? (old.rpcEpoch! + 1) : nil)
                return fixture.observation(request)
            }
            do {
                _ = try await service.open(query: "source", windowIdentifier: fixture.window("scene.A").id)
                XCTFail("Stale native snapshot")
            } catch let failure as NativeSearchIntentService.Failure {
                XCTAssertEqual(failure.status, .staleState)
                XCTAssertNotNil(failure.observation.receipt)
            }
        }
    }

    func testCancellationBeforeExecutionNeverCallsMetadataOrNativeHost() async throws {
        let fixture = SearchIntentFixture(), service = fixture.service()
        let task = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            return try await service.open(query: "source", windowIdentifier: fixture.window("scene.A").id)
        }
        do { _ = try await task.value; XCTFail("Cancelled request") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertTrue(fixture.opened.isEmpty); XCTAssertTrue(fixture.metadataRequests.isEmpty)
        XCTAssertEqual(fixture.windowReads, 0)
    }

    func testCancellationDuringNativeAwaitRetainsObservedEffect() async throws {
        let fixture = SearchIntentFixture(), service = fixture.service()
        fixture.navigationOverride = { request in
            withUnsafeCurrentTask { $0?.cancel() }
            return fixture.observation(request)
        }
        let task = Task { @MainActor in
            try await service.open(query: "source", windowIdentifier: fixture.window("scene.A").id)
        }
        do { _ = try await task.value; XCTFail("Cancelled completion") }
        catch let failure as NativeSearchIntentService.Failure {
            XCTAssertEqual(failure.status, .cancelled)
            XCTAssertEqual(failure.observation.result.status, .completed)
            XCTAssertNotNil(failure.observation.receipt)
        }
    }

    func testRepeatedInvocationsUseIndependentRequestIdentity() async throws {
        let fixture = SearchIntentFixture(), service = fixture.service()
        for _ in 0..<2 {
            _ = try await service.open(query: "source", windowIdentifier: fixture.window("scene.A").id)
        }
        XCTAssertEqual(fixture.opened.count, 2)
        XCTAssertNotEqual(fixture.opened[0].requestId, fixture.opened[1].requestId)
    }
}

@MainActor private final class SearchIntentFixture {
    enum Mutation: CaseIterable, Equatable {
        case resultRequest, action, resultBackend, resultGeneration, effects
        case receiptRequest, routeRequest, receiptBackend, receiptScene, routeBackend
        case routeSnapshot, destination, presentation, sceneTarget, routeRevision, appliedRevision
    }
    var source: ActionBackendSnapshot
    let work = ActionWorkRef(backend: .otzaria, workKey: "book:7")
    var metadataWork: ActionWorkRef?
    var metadataRequests: [ActionRequest] = []
    var opened: [NativeSearchIntentService.OpenRequest] = []
    var windowReads = 0
    var windowOverride: [NativeIntentService.Destination]?
    var metadataOverride: (@MainActor (ActionRequest, ActionBackendSnapshot) async throws -> NativeReaderIntentService.CoreObservation)?
    var navigationOverride: (@MainActor (NativeSearchIntentService.OpenRequest) async throws -> NativeSearchIntentService.Observation)?
    init(backend: ActionBackendID = .otzaria) {
        source = .init(backend: backend, generation: 9, rpcEpoch: backend == .sefariaEmbedded ? 4 : nil)
    }
    func window(_ scene: String) -> NativeIntentService.Destination {
        .init(backend: source.backend, destination: UIDestinationID(rawValue: "native.search")!,
            title: "Search " + scene, sceneID: UIStableID(rawValue: scene)!)
    }
    func coreRequest(_ request: NativeSearchIntentService.OpenRequest) -> ActionRequest {
        .init(requestId: request.requestId, action: "search.openResults",
            arguments: (try? request.query.actionArguments()) ?? [:],
            expectedBackend: request.expectedSnapshot.backend,
            expectedGeneration: request.expectedSnapshot.generation, requestedPresentation: .foreground)
    }
    func observation(_ request: NativeSearchIntentService.OpenRequest, mutation: Mutation? = nil)
        -> NativeSearchIntentService.Observation {
        let original = request.expectedSnapshot
        let other = ActionBackendSnapshot(backend: .sefaria, generation: original.generation + 1)
        let core = ActionRequest(requestId: mutation == .resultRequest ? UUID() : request.requestId,
            action: mutation == .action ? "reader.open" : "search.openResults")
        let result = ActionResult(request: core, status: .completed,
            backend: mutation == .resultBackend ? .sefaria : original.backend,
            backendGeneration: mutation == .resultGeneration ? original.generation + 1 : original.generation,
            effects: mutation == .effects ? ["only_queued"] : ["search_results_opened"])
        let scene = request.window.sceneID
        let route = RouteSpec(requestId: mutation == .routeRequest ? UUID() : request.requestId,
            destination: UIDestinationID(rawValue: mutation == .destination ? "native.search" : "native.search.results")!,
            backend: mutation == .routeBackend ? .sefaria : original.backend,
            presentation: .init(kind: mutation == .presentation ? .sheet : .currentTab),
            scene: .init(kind: .specific,
                sceneID: mutation == .sceneTarget ? UIStableID(rawValue: "scene.foreign")! : scene,
                expectedRevision: mutation == .routeRevision ? 2 : 1),
            expectedBackendSnapshot: mutation == .routeSnapshot ? other : original)
        let receipt = UISceneReceipt(requestId: mutation == .receiptRequest ? UUID() : request.requestId,
            route: route, backendSnapshot: mutation == .receiptBackend ? other : original,
            sceneID: mutation == .receiptScene ? UIStableID(rawValue: "scene.foreign")! : scene,
            basedOnSceneRevision: 1, appliedSceneRevision: mutation == .appliedRevision ? 1 : 2)
        return .init(result: result, receipt: receipt)
    }
    func service() -> NativeSearchIntentService {
        let reader = NativeReaderIntentService(execute: { [self] request in
            metadataRequests.append(request)
            if let metadataOverride { return try await metadataOverride(request, source) }
            return .init(result: .init(request: request, status: .completed,
                data: ["workRef": try ActionJSON.encoded(metadataWork ?? work)],
                backend: source.backend, backendGeneration: source.generation), snapshot: source)
        }, navigate: { _ in XCTFail("Search metadata cannot open a reader"); return .requiresForeground })
        return NativeSearchIntentService(snapshot: { [self] in source },
            windows: { [self] in windowReads += 1; return windowOverride ?? [window("scene.A"), window("scene.B")] },
            reader: reader, navigate: { [self] request in
                opened.append(request)
                if let navigationOverride { return try await navigationOverride(request) }
                return observation(request)
            })
    }
}
