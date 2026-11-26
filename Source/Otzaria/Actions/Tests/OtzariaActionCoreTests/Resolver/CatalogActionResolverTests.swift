import Foundation
import XCTest
@testable import OtzariaActionCore

// Source-shaped fixtures, not production catalog/RPC/DB or Apple acceptance.
private actor ResolverSource: ActionResolverDataPort, ActionBackendStatePort {
    var current: ActionBackendSnapshot
    var entries: [ActionCatalogEntry] = []
    var response: ActionResolution<ActionTextRef> = .notFound
    var namedSections: [String: [String: ActionResolution<ActionTextRef>]] = [:]
    var verified = Set<ActionTextRef>()
    var substitute: ActionTextRef?
    var failure: ActionPortError?
    var rawFailure = false
    var hook: (@Sendable (String) async throws -> Void)?
    var calls: [String] = []
    var queries: [ActionResolveReferenceQuery] = []
    init(_ backend: ActionBackendID) {
        current = .init(backend: backend, generation: 3, rpcEpoch: backend == .sefariaEmbedded ? 8 : nil)
    }
    func setup(_ entries: [ActionCatalogEntry], response: ActionResolution<ActionTextRef> = .notFound,
               verified: Set<ActionTextRef> = [], substitute: ActionTextRef? = nil,
               failure: ActionPortError? = nil, rawFailure: Bool = false,
               hook: (@Sendable (String) async throws -> Void)? = nil) {
        self.entries = entries; self.response = response; self.verified = verified
        self.substitute = substitute; self.failure = failure; self.rawFailure = rawFailure; self.hook = hook
    }
    func setNamedSections(_ values: [String: [String: ActionResolution<ActionTextRef>]]) { namedSections = values }
    func replaceSnapshot(_ value: ActionBackendSnapshot) { current = value }
    func invocation(deadline: UInt64 = 1_000) -> ActionPortInvocation {
        .init(requestId: UUID(), snapshot: current, deadlineUptimeNanoseconds: deadline)
    }
    func snapshot() async throws -> ActionBackendSnapshot { current }
    func report(for backend: ActionBackendID) async throws -> ActionBackendReport { .init(id: backend, operations: [:]) }
    func assess(action: String, arguments: ActionObject, invocation: ActionPortInvocation) async throws -> ActionCapabilityAssessment {
        .init(registered: true, supported: true, availableNow: true)
    }
    func catalog(for backend: ActionBackendID, invocation: ActionPortInvocation) async throws -> [ActionCatalogEntry] {
        try await touch("catalog"); return entries
    }
    func referenceCandidates(_ query: ActionResolveReferenceQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionTextRef> {
        queries.append(query)
        try await touch("reference")
        if let work = query.workRef, let section = query.section, let responses = namedSections[work.workKey] {
            return responses[section] ?? .notFound
        }
        return response
    }
    func validate(_ ref: ActionTextRef, invocation: ActionPortInvocation) async throws -> ActionTextRef {
        try await touch("validate")
        if let substitute { return substitute }
        guard verified.contains(ref) else { throw ActionPortError.notFound }
        return ref
    }
    private func touch(_ stage: String) async throws {
        calls.append(stage); try await hook?(stage)
        if let failure { throw failure }
        if rawFailure { throw NSError(domain: "private/sql/path/token", code: 1) }
    }
}

private final class ResolverClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: UInt64 = 100
    private var reads = 0
    private let expireAfter: Int?
    init(expireAfter: Int? = nil) { self.expireAfter = expireAfter }
    func read() -> UInt64 {
        lock.withLock {
            reads += 1
            return expireAfter.map { reads >= $0 } == true ? 1_000 : value
        }
    }
    func expire() { lock.withLock { value = 1_000 } }
}

final class CatalogActionResolverTests: XCTestCase, @unchecked Sendable {
    private func work(_ backend: ActionBackendID, _ id: Int = 1) -> ActionWorkRef {
        .init(backend: backend, workKey: backend == .otzaria ? "book:\(id)" : "Work \(id)")
    }
    private func entry(_ ref: ActionWorkRef, title: String = "בראשית", aliases: [String] = []) -> ActionCatalogEntry {
        .init(workRef: ref, title: title, aliases: aliases, provenance: "fixture:source-catalog")
    }
    private func text(_ ref: ActionWorkRef, _ line: Int64 = 0) -> ActionTextRef {
        .init(backend: ref.backend, workKey: ref.workKey, position: ref.backend == .otzaria ? .legacyLine(line) : .canonicalRef("\(ref.workKey) 1:\(line + 1)"))
    }
    private func resolver(_ source: ResolverSource, cap: Int = 100_000, candidateCap: Int = 256,
                          uptime: @escaping @Sendable () -> UInt64 = { 100 }) -> CatalogActionResolver {
        .init(data: source, state: source, maximumCatalogEntries: cap, maximumReferenceCandidates: candidateCap, uptime: uptime)
    }
    private func assertError(_ expected: ActionPortError, _ action: () async throws -> Void,
                             file: StaticString = #filePath, line: UInt = #line) async {
        do { try await action(); XCTFail("expected \(expected)", file: file, line: line) }
        catch { XCTAssertEqual(error as? ActionPortError, expected, file: file, line: line) }
    }
    private func assertInvalid(_ action: () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async {
        do { try await action(); XCTFail("expected invalid input", file: file, line: line) }
        catch { XCTAssertTrue(error is ActionContractError, "\(error)", file: file, line: line) }
    }
    private func assertCancelled(_ action: () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async {
        do { try await action(); XCTFail("expected cancellation", file: file, line: line) }
        catch { XCTAssertTrue(error is CancellationError, "\(error)", file: file, line: line) }
    }

    func testThreeBackendsAndExactSectionFocus() async throws {
        for backend in ActionBackendID.allCases {
            let source = ResolverSource(backend), ref = work(backend)
            let section = text(ref), focus = text(ref, 2)
            await source.setup([entry(ref, aliases: ["Genesis"])], response: .unique(focus), verified: [section, focus])
            let r = resolver(source), invocation = await source.invocation()
            let found = try await r.resolveWork(.init(backend: backend, query: "Genesis"), invocation: invocation)
            XCTAssertEqual(found, .unique(ref))
            let reference = try await r.resolveReference(.init(backend: backend, text: "source ref", workRef: ref), invocation: invocation)
            XCTAssertEqual(reference, .unique(focus))
            let destination = ActionReaderDestination(sectionLocator: section, focusLocator: focus, presentationMode: .newTab)
            let result = try await r.validateDestination(destination, invocation: invocation)
            XCTAssertEqual(result, destination)
            let calls = await source.calls
            XCTAssertEqual(calls.filter { $0 == "validate" }.count, 3)
        }
    }

    func testSourceNormalizationPreservesNikudAndCase() async throws {
        let source = ResolverSource(.otzaria), ref = work(.otzaria)
        await source.setup([entry(ref, title: "רש\"י על דברים", aliases: ["Cafe\u{301}", "בְּרֵאשִׁית"])])
        let r = resolver(source), i = await source.invocation()
        for query in ["  רש״י\n על   דברים ", "Café", "בְּרֵאשִׁית"] {
            let result = try await r.resolveWork(.init(backend: .otzaria, query: query), invocation: i)
            XCTAssertEqual(result, .unique(ref))
        }
        for query in ["בראשית", "café", "Rashi", "invented alias"] {
            let result = try await r.resolveWork(.init(backend: .otzaria, query: query), invocation: i)
            XCTAssertEqual(result, .notFound)
        }
    }

    func testNamedOtzariaReferenceUsesLongestCatalogAliasAndOriginalSection() async throws {
        let source = ResolverSource(.otzaria), short = work(.otzaria, 1), commentary = work(.otzaria, 2)
        let result = text(commentary, 512)
        await source.setup([entry(short, title: "כלי"), entry(commentary, title: "כלי יקר על התורה", aliases: ["כלי יקר"])],
                           verified: [result])
        await source.setNamedSections([commentary.workKey: ["דברים": .unique(result)]])
        let r = resolver(source), invocation = await source.invocation()
        let resolved = try await r.resolveReference(.init(backend: .otzaria, text: " כלי   יקר על דברים "), invocation: invocation)
        XCTAssertEqual(resolved, .unique(result))
        let requests = await source.queries
        XCTAssertEqual(requests.dropFirst().map(\.workRef), [commentary, commentary])
        XCTAssertEqual(requests.dropFirst().map(\.section), ["על דברים", "דברים"])
    }

    func testNamedOtzariaReferenceRetainsEditionAmbiguityAndRejectsWrongWork() async throws {
        let source = ResolverSource(.otzaria), first = work(.otzaria, 1), second = work(.otzaria, 2)
        let one = text(first, 20), two = text(second, 30)
        await source.setup([entry(second, title: "כלי יקר"), entry(first, title: "כלי יקר")], verified: [one, two])
        await source.setNamedSections([first.workKey: ["דברים": .unique(one)], second.workKey: ["דברים": .unique(two)]])
        let r = resolver(source), invocation = await source.invocation()
        let query = ActionResolveReferenceQuery(backend: .otzaria, text: "כלי יקר דברים")
        guard case .ambiguous(let result) = try await r.resolveReference(query, invocation: invocation) else {
            return XCTFail("Two original source editions must remain ambiguous")
        }
        XCTAssertEqual(result.map { $0.ref["workKey"]?.string }, [first.workKey, second.workKey])
        await source.setNamedSections([first.workKey: ["דברים": .unique(two)], second.workKey: ["דברים": .unique(two)]])
        await assertError(.invalidResponse) { _ = try await r.resolveReference(query, invocation: invocation) }
    }

    func testDuplicateTitlesEditionsAliasesAndLimitOne() async throws {
        let source = ResolverSource(.otzaria), refs = (1...35).map { work(.otzaria, $0) }
        var entries = refs.reversed().map { entry($0, aliases: ["Shared"]) }
        entries.append(entries[0])
        await source.setup(entries)
        let r = resolver(source), i = await source.invocation()
        for limit in [1, 25] {
            let result = try await r.resolveWork(.init(backend: .otzaria, query: "Shared", limit: limit), invocation: i)
            guard case .ambiguous(let candidates) = result else { return XCTFail("ambiguity lost") }
            XCTAssertEqual(candidates.count, limit)
            XCTAssertEqual(candidates[0].ref["workKey"], .string("book:1"))
            XCTAssertEqual(candidates[0].confidenceBand, .alias)
            XCTAssertTrue(candidates[0].reason?.contains("fixture:source-catalog") == true)
        }
        let selected = try await r.resolveWork(.init(backend: .otzaria, query: "Shared", workRef: refs[10]), invocation: i)
        XCTAssertEqual(selected, .unique(refs[10]))
        await assertInvalid { _ = try await r.resolveWork(.init(backend: .otzaria, query: "conflict", workRef: refs[10]), invocation: i) }
    }

    func testMalformedAndCrossBackendInputsBeforeProvider() async throws {
        let source = ResolverSource(.otzaria), r = resolver(source), i = await source.invocation()
        for query in [ActionResolveWorkQuery(backend: .otzaria), .init(backend: .otzaria, query: "  "),
                      .init(backend: .otzaria, query: "x", limit: 0), .init(backend: .otzaria, query: "x", limit: 26),
                      .init(backend: .sefaria, query: "x"), .init(backend: .otzaria, workRef: work(.sefaria)),
                      .init(backend: .otzaria, workRef: .init(backend: .otzaria, workKey: "book:-1")),
                      .init(backend: .otzaria, query: String(repeating: "x", count: 513)), .init(backend: .otzaria, query: "x\u{0}")] {
            await assertInvalid { _ = try await r.resolveWork(query, invocation: i) }
        }
        await assertInvalid { _ = try await r.validateDestination(.init(sectionLocator: text(work(.otzaria)), focusLocator: text(work(.sefaria))), invocation: i) }
        let invalid = ActionTextRef(backend: .otzaria, workKey: "book:1", position: .canonicalRef("Genesis"))
        await assertInvalid { _ = try await r.validateDestination(.init(sectionLocator: invalid), invocation: i) }
        let calls = await source.calls
        XCTAssertTrue(calls.isEmpty)
    }

    func testMissingVersusUnavailableAndRedactedFailure() async throws {
        let source = ResolverSource(.otzaria), r = resolver(source), i = await source.invocation()
        let empty = try await r.resolveWork(.init(backend: .otzaria, query: "missing"), invocation: i)
        XCTAssertEqual(empty, .notFound)
        await source.setup([], failure: .unavailable)
        await assertError(.unavailable) { _ = try await r.resolveWork(.init(backend: .otzaria, query: "x"), invocation: i) }
        await source.setup([], rawFailure: true)
        await assertError(.unavailable) { _ = try await r.resolveWork(.init(backend: .otzaria, query: "x"), invocation: i) }
    }

    func testReferenceFidelityUnknownEmbeddedAndWrongWork() async throws {
        let source = ResolverSource(.sefariaEmbedded), ref = work(.sefariaEmbedded), locator = text(work(.sefariaEmbedded))
        let r = resolver(source), i = await source.invocation()
        let query = ActionResolveReferenceQuery(backend: .sefariaEmbedded, text: " בְּרֵאשִׁית ״ 1:1 ", workRef: ref, section: " 1 ")
        await source.setup([entry(ref)], response: .unique(locator))
        let missing = try await r.resolveReference(query, invocation: i)
        XCTAssertEqual(missing, .notFound)
        let queries = await source.queries
        XCTAssertEqual(queries, [query])
        let wrong = text(work(.sefariaEmbedded, 2))
        await source.setup([entry(ref), entry(work(.sefariaEmbedded, 2))], response: .unique(wrong), verified: [wrong])
        await assertError(.invalidResponse) { _ = try await r.resolveReference(query, invocation: i) }
        await source.setup([entry(ref)], response: .notFound)
        let zero = try await r.resolveReference(query, invocation: i)
        XCTAssertEqual(zero, .notFound)
    }

    func testSourceSubstitutionAndMalformedCatalogRejected() async throws {
        let source = ResolverSource(.otzaria), ref = work(.otzaria), section = text(work(.otzaria))
        let r = resolver(source), i = await source.invocation()
        await source.setup([entry(ref)], verified: [section], substitute: text(ref, 1))
        await assertError(.invalidResponse) { _ = try await r.validateDestination(.init(sectionLocator: section), invocation: i) }
        await source.setup([entry(work(.sefaria))])
        await assertError(.invalidResponse) { _ = try await r.resolveWork(.init(backend: .otzaria, query: "x"), invocation: i) }
        await source.setup([.init(workRef: ref, title: "x", provenance: "")])
        await assertError(.invalidResponse) { _ = try await r.resolveWork(.init(backend: .otzaria, query: "x"), invocation: i) }
    }

    func testReferenceAmbiguityIsStableCappedAndFullyValidated() async throws {
        let source = ResolverSource(.sefaria), ref = work(.sefaria), refs = (0..<30).map { text(work(.sefaria), Int64($0)) }
        let candidates = try refs.reversed().map { ActionCandidate(ref: try ActionJSON.encoded($0).object!, title: "source position", kind: .segment) }
        await source.setup([entry(ref)], response: .ambiguous(candidates), verified: Set(refs))
        let r = resolver(source), i = await source.invocation()
        let result = try await r.resolveReference(.init(backend: .sefaria, text: "ambiguous"), invocation: i)
        guard case .ambiguous(let output) = result else { return XCTFail("ambiguity lost") }
        XCTAssertEqual(output.count, 25)
        let calls = await source.calls
        XCTAssertEqual(calls.filter { $0 == "validate" }.count, 30)
        await source.setup([entry(ref)], response: .ambiguous([]))
        await assertError(.invalidResponse) { _ = try await r.resolveReference(.init(backend: .sefaria, text: "x"), invocation: i) }
        await source.setup([entry(ref)], response: .ambiguous([candidates[0]]), verified: [refs.last!])
        let single = try await r.resolveReference(.init(backend: .sefaria, text: "x"), invocation: i)
        guard case .ambiguous(let capped) = single else { return XCTFail("ambiguity promoted") }
        XCTAssertEqual(capped.count, 1)
    }

    func testBudgetsFailWithoutSearchingOnlyPrefix() async throws {
        let source = ResolverSource(.otzaria), r = resolver(source, cap: 1), i = await source.invocation()
        await source.setup([entry(work(.otzaria)), entry(work(.otzaria, 2))])
        await assertError(.invalidResponse) { _ = try await r.resolveWork(.init(backend: .otzaria, query: "בראשית"), invocation: i) }
        await source.setup([.init(workRef: work(.otzaria), title: "x", aliases: Array(repeating: "a", count: 65), provenance: "fixture")])
        await assertError(.invalidResponse) { _ = try await r.resolveWork(.init(backend: .otzaria, query: "x"), invocation: i) }
    }

    func testDuplicateReferencesShareExistenceProofWithoutCollapsingAmbiguity() async throws {
        for backend in ActionBackendID.allCases {
            let source = ResolverSource(backend), ref = work(backend), locator = text(work(backend))
            let candidate = ActionCandidate(ref: try ActionJSON.encoded(locator).object!, title: "source position", kind: .segment)
            await source.setup([entry(ref)], response: .ambiguous(Array(repeating: candidate, count: 256)), verified: [locator])
            let r = resolver(source), i = await source.invocation()
            let result = try await r.resolveReference(.init(backend: backend, text: "source ambiguity"), invocation: i)
            guard case .ambiguous(let candidates) = result else { return XCTFail("source ambiguity promoted") }
            XCTAssertEqual(candidates, [candidate])
            let calls = await source.calls
            XCTAssertEqual(calls.filter { $0 == "validate" }.count, 1, "one proof per identical qualified reference")
        }
    }

    func testIdenticalSectionAndFocusShareExistenceProof() async throws {
        for backend in ActionBackendID.allCases {
            let source = ResolverSource(backend), ref = work(backend), locator = text(work(backend))
            await source.setup([entry(ref)], verified: [locator])
            let r = resolver(source), i = await source.invocation()
            let destination = ActionReaderDestination(sectionLocator: locator, focusLocator: locator, presentationMode: .newTab)
            let result = try await r.validateDestination(destination, invocation: i)
            XCTAssertEqual(result, destination)
            let calls = await source.calls
            XCTAssertEqual(calls.filter { $0 == "validate" }.count, 1)
        }
    }

    func testProofDeduplicationKeepsDataRevisionsDistinct() async throws {
        let source = ResolverSource(.sefaria), ref = work(.sefaria)
        let first = ActionTextRef(backend: .sefaria, workKey: ref.workKey, position: .canonicalRef("Work 1 1"), dataRevision: "a")
        let second = ActionTextRef(backend: .sefaria, workKey: ref.workKey, position: first.position, dataRevision: "b")
        let candidates = try [first, second, first].map { ActionCandidate(ref: try ActionJSON.encoded($0).object!, title: "source position", kind: .segment) }
        await source.setup([entry(ref)], response: .ambiguous(candidates), verified: [first, second])
        let r = resolver(source), i = await source.invocation()
        let result = try await r.resolveReference(.init(backend: .sefaria, text: "ambiguous revisions"), invocation: i)
        guard case .ambiguous(let output) = result else { return XCTFail("revisions collapsed") }
        XCTAssertEqual(output.count, 2)
        let calls = await source.calls
        XCTAssertEqual(calls.filter { $0 == "validate" }.count, 2)
    }

    func testExistenceProofsNeverSurviveTheInvocation() async throws {
        let source = ResolverSource(.sefariaEmbedded), ref = work(.sefariaEmbedded), locator = text(work(.sefariaEmbedded))
        let candidate = ActionCandidate(ref: try ActionJSON.encoded(locator).object!, title: "source position", kind: .segment)
        let response = ActionResolution<ActionTextRef>.ambiguous([candidate, candidate])
        await source.setup([entry(ref)], response: response, verified: [locator])
        let r = resolver(source), first = await source.invocation()
        _ = try await r.resolveReference(.init(backend: .sefariaEmbedded, text: "source ambiguity"), invocation: first)
        // Even an unchanged snapshot never carries proof into another request.
        await source.setup([entry(ref)], response: response, verified: [])
        let second = await source.invocation()
        await assertError(.invalidResponse) {
            _ = try await r.resolveReference(.init(backend: .sefariaEmbedded, text: "source ambiguity"), invocation: second)
        }
    }

    func testGenerationBackendAndEpochChangeAcrossEveryDataAwait() async throws {
        for mutation in ["generation", "backend", "epoch"] {
            for stage in ["catalog", "reference", "validate"] {
                let source = ResolverSource(.sefariaEmbedded), ref = work(.sefariaEmbedded), locator = text(work(.sefariaEmbedded))
                let i = await source.invocation()
                await source.setup([entry(ref)], response: .unique(locator), verified: [locator], hook: { at in
                    if at == stage { await source.replaceSnapshot(.init(backend: mutation == "backend" ? .otzaria : .sefariaEmbedded,
                        generation: mutation == "generation" ? 4 : 3, rpcEpoch: mutation == "epoch" ? 9 : 8)) }
                })
                let r = resolver(source)
                await assertError(.staleState) { _ = try await r.resolveReference(.init(backend: .sefariaEmbedded, text: "x"), invocation: i) }
            }
        }
    }

    func testDeadlineAndCancellationBeforeAndDuringSourceAwait() async throws {
        let source = ResolverSource(.otzaria), r = resolver(source), i = await source.invocation(deadline: 100)
        await assertCancelled { _ = try await r.resolveWork(.init(backend: .otzaria, query: "x"), invocation: i) }
        var calls = await source.calls
        XCTAssertTrue(calls.isEmpty)
        let valid = await source.invocation()
        await source.setup([entry(work(.otzaria))], hook: { _ in withUnsafeCurrentTask { $0?.cancel() } })
        let task = Task { try await r.resolveWork(.init(backend: .otzaria, query: "בראשית"), invocation: valid) }
        await assertCancelled { _ = try await task.value }
        calls = await source.calls
        XCTAssertEqual(calls, ["catalog"])
        let before = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await r.resolveWork(.init(backend: .otzaria, query: "בראשית"), invocation: valid)
        }
        await assertCancelled { _ = try await before.value }
        let after = await source.calls
        XCTAssertEqual(after, calls)
    }

    func testDeadlineExpiresAcrossEachAwaitAndUnknownRPCEpoch() async throws {
        for stage in ["catalog", "reference", "validate"] {
            let source = ResolverSource(.otzaria), clock = ResolverClock(), ref = work(.otzaria), locator = text(work(.otzaria))
            await source.setup([entry(ref)], response: .unique(locator), verified: [locator], hook: { at in
                if at == stage { clock.expire() }
            })
            let r = resolver(source, uptime: { clock.read() }), i = await source.invocation(deadline: 500)
            await assertCancelled { _ = try await r.resolveReference(.init(backend: .otzaria, text: "x"), invocation: i) }
        }
        let source = ResolverSource(.sefariaEmbedded)
        await source.replaceSnapshot(.init(backend: .sefariaEmbedded, generation: 3))
        let r = resolver(source), i = await source.invocation()
        await assertError(.unavailable) { _ = try await r.resolveWork(.init(backend: .sefariaEmbedded, query: "x"), invocation: i) }
        let calls = await source.calls
        XCTAssertTrue(calls.isEmpty)
    }

    func testRevisionIdentityAndOpaqueKeyOrderingAreNotConcatenated() async throws {
        let source = ResolverSource(.sefaria)
        let a = ActionWorkRef(backend: .sefaria, workKey: "A", catalogRevision: "B|C")
        let b = ActionWorkRef(backend: .sefaria, workKey: "A|B", catalogRevision: "C")
        await source.setup([entry(b), entry(a)])
        let r = resolver(source), i = await source.invocation()
        let result = try await r.resolveWork(.init(backend: .sefaria, query: "בראשית"), invocation: i)
        guard case .ambiguous(let candidates) = result else { return XCTFail("editions hidden") }
        XCTAssertEqual(candidates.first?.ref["workKey"], .string("A"))
        let missing = try await r.resolveWork(.init(backend: .sefaria, workRef: .init(backend: .sefaria, workKey: "A", catalogRevision: "old")), invocation: i)
        XCTAssertEqual(missing, .notFound)
        let section = ActionTextRef(backend: .sefaria, workKey: "A", position: .canonicalRef("A 1"), catalogRevision: "B|C", dataRevision: "d1")
        let wrongFocus = ActionTextRef(backend: .sefaria, workKey: "A", position: .canonicalRef("A 1:1"), catalogRevision: "B|C", dataRevision: "d2")
        await assertInvalid { _ = try await r.validateDestination(.init(sectionLocator: section, focusLocator: wrongFocus), invocation: i) }
    }

    func testMalformedReferenceCandidatesAndCandidateBudgetFailClosed() async throws {
        let source = ResolverSource(.sefaria), ref = work(.sefaria), locator = text(work(.sefaria))
        let good = try ActionJSON.encoded(locator).object!
        var extra = good; extra["unexpected"] = .bool(true)
        var huge = good; huge["workKey"] = .string(String(repeating: "x", count: 5_000))
        let r = resolver(source), i = await source.invocation()
        for object in [extra, huge, ["position": .object(["kind": .string("canonicalRef"), "value": .array([])])]] {
            await source.setup([entry(ref)], response: .ambiguous([.init(ref: object, title: "position", kind: .segment)]), verified: [locator])
            await assertError(.invalidResponse) { _ = try await r.resolveReference(.init(backend: .sefaria, text: "x"), invocation: i) }
        }
        let candidates = [ActionCandidate(ref: good, title: "position", kind: .segment), .init(ref: good, title: "position", kind: .segment)]
        await source.setup([entry(ref)], response: .ambiguous(candidates), verified: [locator])
        let bounded = resolver(source, candidateCap: 1)
        await assertError(.invalidResponse) { _ = try await bounded.resolveReference(.init(backend: .sefaria, text: "x"), invocation: i) }
    }

    func testLargeCatalogLastMatchAndDeadlineDuringActorScan() async throws {
        let source = ResolverSource(.otzaria)
        let entries = (1...2_000).map { entry(work(.otzaria, $0), title: $0 == 2_000 ? "LAST" : "other") }
        await source.setup(entries)
        let i = await source.invocation(deadline: 500)
        let r = resolver(source)
        let result = try await r.resolveWork(.init(backend: .otzaria, query: "LAST", limit: 1), invocation: i)
        XCTAssertEqual(result, .unique(work(.otzaria, 2_000)))
        let clock = ResolverClock(expireAfter: 300)
        let bounded = resolver(source, uptime: { clock.read() })
        await assertCancelled { _ = try await bounded.resolveWork(.init(backend: .otzaria, query: "LAST"), invocation: i) }
        let calls = await source.calls
        XCTAssertEqual(calls, ["catalog", "catalog"])
    }
}
