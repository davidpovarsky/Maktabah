import Foundation
import XCTest
@testable import OtzariaActionCore

final class BackendSemanticsTests: XCTestCase {
    func testLoadedRuntimeContractRequiresExactSchemaNonceAndPositiveReadiness() {
        var proof: ActionObject = ["contract": .string("chavrusa.actions.search-fidelity.v1"),
            "searchFidelitySchema": .integer(1), "nonce": .string("fresh"),
            "catalogReady": .bool(true), "searchReady": .bool(true), "resourcesStable": .bool(true)]
        XCTAssertTrue(EmbeddedActionResponseProof.matchesRuntimeContract(.object(proof), nonce: "fresh"))
        XCTAssertFalse(EmbeddedActionResponseProof.matchesRuntimeContract(.object(proof), nonce: "old"))
        for field in ["contract", "searchFidelitySchema", "nonce", "catalogReady", "searchReady", "resourcesStable"] {
            var missing = proof; missing.removeValue(forKey: field)
            XCTAssertFalse(EmbeddedActionResponseProof.matchesRuntimeContract(.object(missing), nonce: "fresh"))
        }
        proof["searchReady"] = .bool(false)
        XCTAssertFalse(EmbeddedActionResponseProof.matchesRuntimeContract(.object(proof), nonce: "fresh"))
        proof["searchReady"] = .bool(true); proof["resourcesStable"] = .bool(false)
        XCTAssertFalse(EmbeddedActionResponseProof.matchesRuntimeContract(.object(proof), nonce: "fresh"))
    }
    private func evidence(_ backend: ActionBackendID) -> ActionBackendRuntimeEvidence {
        .init(snapshot: .init(backend: backend, generation: 3, rpcEpoch: backend == .sefariaEmbedded ? 9 : nil),
              registeredCapabilities: ["catalog", "navigation", "reading", "search", "versions", "offlineLibrary"],
              catalog: .ready, references: .ready, search: .ready, network: .ready,
              host: .ready, embeddedCatalog: .ready, embeddedSearch: .ready, embeddedPackages: .ready,
              embeddedResponseFidelity: .ready)
    }

    func testRegistrationDoesNotProveReadiness() throws {
        for backend in ActionBackendID.allCases {
            let unknown = ActionBackendRuntimeEvidence(snapshot: .init(backend: backend, generation: 1),
                registeredCapabilities: ["catalog", "search", "navigation"])
            let profile = ActionBackendSemanticProfile(backend: backend)
            let result = try profile.assess(action: "search.query", query: .init(backend: backend, text: "fixture"), evidence: unknown)
            XCTAssertTrue(result.registered); XCTAssertTrue(result.supported); XCTAssertFalse(result.availableNow)
            let count = try profile.assess(action: "search.countOccurrences", evidence: evidence(backend))
            XCTAssertFalse(count.supported); XCTAssertEqual(count.reasonCode, "exact_count_unavailable")
        }
    }

    func testInactiveBackendCannotBecomeAvailable() throws {
        let profile = ActionBackendSemanticProfile(backend: .sefaria)
        let result = try profile.assess(action: "search.query", query: .init(backend: .sefaria, text: "fixture"), evidence: evidence(.otzaria))
        XCTAssertFalse(result.availableNow); XCTAssertEqual(result.reasonCode, "backend_selection_required")
    }

    func testEmbeddedReadinessIsPerOperationAndEpoch() throws {
        let profile = ActionBackendSemanticProfile(backend: .sefariaEmbedded)
        let query = ActionSearchQuery(backend: .sefariaEmbedded, text: "fixture")
        var ready = evidence(.sefariaEmbedded)
        ready.embeddedSearch = .unavailable
        XCTAssertFalse(try profile.assess(action: "search.query", query: query, evidence: ready).availableNow)
        XCTAssertTrue(try profile.assess(action: "catalog.resolveWork", evidence: ready).availableNow)
        ready.embeddedSearch = .ready; ready.embeddedPackages = .unknown
        XCTAssertTrue(try profile.assess(action: "search.query", query: query, evidence: ready).availableNow)
        ready.embeddedResponseFidelity = .unknown
        XCTAssertEqual(try profile.assess(action: "search.query", query: query, evidence: ready).reasonCode,
                       "embedded_response_fidelity_unverified")
    }

    func testSourceFeaturesSurviveWithoutEnablingStagedActions() throws {
        for backend in ActionBackendID.allCases {
            let profile = ActionBackendSemanticProfile(backend: backend)
            XCTAssertEqual(profile.sourceFeatures.globalAuthors, backend == .otzaria)
            XCTAssertEqual(profile.sourceFeatures.versionProvider, backend != .otzaria)
            XCTAssertEqual(profile.sourceFeatures.packageProvider, backend != .otzaria)
            if backend == .otzaria {
                XCTAssertEqual(profile.sourceFeatures.alternateStructures, .defaultOnly)
                XCTAssertEqual(profile.sourceFeatures.topics, .stub)
            } else if backend == .sefariaEmbedded {
                XCTAssertEqual(profile.sourceFeatures.versions, .partial)
                XCTAssertEqual(profile.sourceFeatures.alternateStructures, .partial)
                XCTAssertEqual(profile.sourceFeatures.packages, .runtimeDependent)
            }
            let report = try profile.report(evidence: evidence(backend))
            XCTAssertEqual(report.operations.count, 29)
            XCTAssertEqual(try XCTUnwrap(report.operations["reader.listVersions"]).availableNow, backend == .sefaria)
            for action in ["notes.saveDraft", "packages.install", "packages.list", "system.selectBackend"] {
                XCTAssertFalse(try XCTUnwrap(report.operations[action]).availableNow)
            }
        }
    }

    func testIgnoredModesAndSortsAreRejected() throws {
        for backend in [ActionBackendID.otzaria, .sefariaEmbedded] {
            for mode in [ActionSearchQuery.Mode.contains, .or, .near] {
                let query = ActionSearchQuery(backend: backend, text: "fixture", searchMode: mode, wordDistance: mode == .near ? 3 : 0)
                XCTAssertNotNil(ActionSearchSemantics.unsupportedReason(query))
            }
            XCTAssertNotNil(ActionSearchSemantics.unsupportedReason(.init(backend: backend, text: "fixture", sortOrder: .chronological)))
        }
        let legacy = ActionSearchQuery(backend: .sefaria, text: "משה", searchMode: .near, matchMode: .hebrewLemmatized, wordDistance: 4)
        XCTAssertNil(ActionSearchSemantics.unsupportedReason(legacy))
        XCTAssertNotNil(ActionSearchSemantics.unsupportedReason(.init(backend: .sefaria, text: "a b", searchMode: .or, sortOrder: .canonical)))
    }

    func testLegacyDownloadedReadingDoesNotEnableOfflineSearch() throws {
        var runtime = evidence(.sefaria)
        runtime.network = .unavailable
        let profile = ActionBackendSemanticProfile(backend: .sefaria)
        XCTAssertTrue(try profile.assess(action: "catalog.resolveWork", evidence: runtime).availableNow)
        XCTAssertEqual(try profile.assess(action: "search.query", query: .init(backend: .sefaria, text: "fixture"), evidence: runtime).reasonCode,
                       "search_requires_network")
    }

    func testOtzariaScopeUsesOnlyProvenCanonicalBookFilters() throws {
        let refs = [ActionWorkRef(backend: .otzaria, workKey: "book:7"), .init(backend: .otzaria, workKey: "book:8")]
        let query = ActionSearchQuery(backend: .otzaria, text: "fixture", scopeWorkRefs: refs)
        XCTAssertEqual(try ActionSearchScopeMapping.filters(for: query, catalog: refs.map { .init(workRef: $0) }), ["book:7", "book:8"])
        XCTAssertThrowsError(try ActionSearchScopeMapping.filters(for: query, catalog: [.init(workRef: refs[0])]))
        for invalid in ["book:0", "book:-1", "book:007", "book:9223372036854775808", "display title"] {
            let ref = ActionWorkRef(backend: .otzaria, workKey: invalid)
            XCTAssertThrowsError(try ActionSearchScopeMapping.filters(for: .init(backend: .otzaria, text: "fixture", scopeWorkRefs: [ref]),
                catalog: [.init(workRef: ref)]))
        }
    }

    func testLegacyScopeNeverInventsPathsOrEntersUnboundedFallback() throws {
        let ref = ActionWorkRef(backend: .sefaria, workKey: "Genesis")
        let query = ActionSearchQuery(backend: .sefaria, text: "fixture", scopeWorkRefs: [ref])
        XCTAssertThrowsError(try ActionSearchScopeMapping.filters(for: query, catalog: [.init(workRef: ref)]))
        XCTAssertEqual(try ActionSearchScopeMapping.filters(for: query,
            catalog: [.init(workRef: ref, authoritativeFilter: "Tanakh/Torah/Genesis")]), ["Tanakh/Torah/Genesis"])
        XCTAssertThrowsError(try ActionSearchScopeMapping.filters(for: .init(backend: .sefariaEmbedded, text: "fixture",
            scopeWorkRefs: [.init(backend: .sefariaEmbedded, workKey: "Genesis")]), catalog: []))
    }

    func testArgumentProjectionRefusesTypeCoercionsAndCrossBackendScope() throws {
        let value = try ActionSearchArgumentMapping.query(["text": .string("fixture")], backend: .otzaria)
        XCTAssertEqual(value.wordDistance, 0); XCTAssertEqual(value.matchMode, .exact)
        XCTAssertThrowsError(try ActionSearchArgumentMapping.query(["text": .string("fixture"), "offset": .bool(true)], backend: .otzaria))
        XCTAssertThrowsError(try ActionSearchArgumentMapping.query(["text": .string("fixture"), "searchMode": .string("invented")], backend: .otzaria))
        XCTAssertThrowsError(try ActionSearchSemantics.validateBounds(.init(backend: .otzaria, text: "fixture",
            scopeWorkRefs: [.init(backend: .sefaria, workKey: "Genesis")])))
    }

    func testStateAssessmentTargetsEveryQualifiedReferenceBeforeProbing() throws {
        let ref: ActionJSON = .object(["backend": .string("sefariaEmbedded"), "workKey": .string("Genesis")])
        XCTAssertEqual(try ActionBackendArgumentTarget.resolve(["workRef": ref], fallback: .otzaria), .sefariaEmbedded)
        XCTAssertThrowsError(try ActionBackendArgumentTarget.resolve(["backend": .string("otzaria"), "workRef": ref], fallback: .otzaria))
        XCTAssertThrowsError(try ActionBackendArgumentTarget.resolve(["scopeWorkRefs": .array([ref]),
            "sectionLocator": .object(["backend": .string("sefaria"), "workKey": .string("Genesis")])], fallback: .otzaria))
        XCTAssertThrowsError(try ActionBackendArgumentTarget.resolve(["workRef": .object(["workKey": .string("Genesis")])], fallback: .otzaria))
    }

    func testInvocationGenerationEpochDeadlineAndCancellation() async throws {
        let before = ActionBackendSnapshot(backend: .sefariaEmbedded, generation: 5, rpcEpoch: 7)
        let invocation = ActionPortInvocation(requestId: UUID(), snapshot: before, deadlineUptimeNanoseconds: 100)
        XCTAssertThrowsError(try ActionBackendInvocationGuard.check(invocation, current: before, target: .sefariaEmbedded, uptime: 100))
        XCTAssertThrowsError(try ActionBackendInvocationGuard.check(invocation,
            current: .init(backend: .sefariaEmbedded, generation: 5, rpcEpoch: 8), target: .sefariaEmbedded, uptime: 1))
        XCTAssertThrowsError(try ActionBackendInvocationGuard.check(invocation, current: before, target: .otzaria, uptime: 1))
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            do { try ActionBackendInvocationGuard.check(invocation, current: before, target: .sefariaEmbedded, uptime: 1); return false }
            catch is CancellationError { return true }
            catch { return false }
        }
        let cancelled = await task.value
        XCTAssertTrue(cancelled)
    }

    func testActualEmbeddedHandlerFixtures() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<7 { root.deleteLastPathComponent() }
        let document = try JSONDecoder().decode(ActionJSON.self,
            from: Data(contentsOf: root.appendingPathComponent("docs/hq-actions-bridge/embedded-handler-fixtures.json")))
        let cases = try XCTUnwrap(document.object?["cases"]?.array)
        XCTAssertEqual(cases.count, 11)
        for entry in cases {
            let object = try XCTUnwrap(entry.object), name = try XCTUnwrap(object["name"]?.string)
            let query = ActionSearchQuery(backend: .sefariaEmbedded, text: "fixture",
                offset: Int(try XCTUnwrap(object["offset"]?.integer)), limit: Int(try XCTUnwrap(object["limit"]?.integer)))
            let body = try XCTUnwrap(object["result"])
            switch name {
            case "eq_more_with_grouping", "eq_in_place_processing":
                let result = try EmbeddedActionResponseProof.searchPage(body, query: query)
                XCTAssertEqual(result.hits.count, 2); XCTAssertEqual(result.nextOffset, 13)
                XCTAssertEqual(result.precision, .unknown)
            case "eq_empty":
                let result = try EmbeddedActionResponseProof.searchPage(body, query: query)
                XCTAssertTrue(result.hits.isEmpty); XCTAssertNil(result.nextOffset)
            case "explicit_cursor":
                XCTAssertEqual(try EmbeddedActionResponseProof.searchPage(body, query: query).nextOffset, 17)
            default:
                XCTAssertThrowsError(try EmbeddedActionResponseProof.searchPage(body, query: query), name)
            }
        }
    }

    func testEmbeddedReferenceNeedsActualRefsNotEchoOrTrim() throws {
        let ref = ActionTextRef(backend: .sefariaEmbedded, workKey: "Genesis", position: .canonicalRef("Genesis 1:1"))
        let body: ActionJSON = .object(["textContent": .object(["sectionRef": .string("Genesis 1"),
            "content": .array([.object(["ref": .string("Genesis 1:1"), "he": .string("fixture")])])])])
        XCTAssertNoThrow(try EmbeddedActionResponseProof.validateText(body, ref: ref))
        XCTAssertThrowsError(try EmbeddedActionResponseProof.validateText(.object([:]), ref: ref))
        let fabricated: ActionJSON = .object(["textContent": .object(["sectionRef": .string("Genesis 1"),
            "content": .array([.object(["segmentNumber": .string("1"), "he": .string("fixture")])])])])
        XCTAssertThrowsError(try EmbeddedActionResponseProof.validateText(fabricated, ref: ref))
        XCTAssertThrowsError(try EmbeddedActionResponseProof.validateText(body,
            ref: .init(backend: .sefariaEmbedded, workKey: "Exodus", position: .canonicalRef("Genesis 1:1"))))
    }

    func testEmbeddedCatalogRejectsPartialParseAndPreservesSourceAliases() throws {
        let invocation = ActionPortInvocation(requestId: UUID(), snapshot: .init(backend: .sefariaEmbedded, generation: 1, rpcEpoch: 2),
                                             deadlineUptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + 5_000_000_000)
        let valid: ActionJSON = .array([.object(["category": .string("Torah"), "contents": .array([
            .object(["title": .string("Genesis"), "heTitle": .string("בראשית")]),
            .object(["title": .string("Exodus"), "heTitle": .string("שמות")])])])])
        let entries = try EmbeddedActionResponseProof.catalogEntries(valid, invocation: invocation)
        XCTAssertEqual(entries.map(\.title), ["Genesis", "Exodus"])
        XCTAssertEqual(entries[0].aliases, ["בראשית"])
        XCTAssertEqual(entries[0].workRef.backend, .sefariaEmbedded)
        XCTAssertThrowsError(try EmbeddedActionResponseProof.catalogEntries(.array([]), invocation: invocation))
        XCTAssertThrowsError(try EmbeddedActionResponseProof.catalogEntries(.array([
            .object(["title": .string("Genesis")]), .object(["unexpected": .bool(true)])]), invocation: invocation))
        XCTAssertThrowsError(try EmbeddedActionResponseProof.catalogEntries(.array([
            .object(["category": .string("Torah")])]), invocation: invocation))
    }
}
