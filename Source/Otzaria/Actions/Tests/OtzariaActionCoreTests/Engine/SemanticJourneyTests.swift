import Foundation
import XCTest
@testable import OtzariaActionCore

/// Actual Core, catalog/TOC/link resolver, policy and one-use grants; explicit
/// source/editor doubles. These are not native UI or production corpus counts.
@MainActor private final class JourneyFixture: ActionSynchronousBackendStatePort, ActionResolverDataPort,
    ActionCommentaryDataPort, ActionSearchPort, ActionOccurrenceCountPort, ActionNavigationAuthority,
    ActionCommentaryUICommandSink, ActionNoteDraftUICommandSink, ActionSearchResultsUICommandSink {
    let baseWork: ActionWorkRef
    let commentaryWork: ActionWorkRef
    let base: ActionTextRef
    let section: ActionTextRef
    let focus: ActionTextRef
    var current = ActionBackendSnapshot(backend: .otzaria, generation: 7)
    var navigationContext = ActionExecutionContext(subjectID: "journey-fixture-native", origin: .inApp,
        allowedBackends: [.otzaria], scopes: [.discovery, .navigation], foregroundSceneID: "fixture-scene")
    var readContext = ActionExecutionContext(subjectID: "journey-fixture-explicit-read", origin: .inApp,
        allowedBackends: [.otzaria], contentRights: [.otzaria], scopes: [.discovery, .contentRead], foregroundSceneID: "fixture-scene")
    let lifetime = UUID()
    var nativeRevision: UInt64 = 1
    var sourceEpoch: UInt64 = 1
    var readRevision: UInt64 = 1
    var active = true
    var entries: [ActionCatalogEntry] = []
    var toc: [ActionSourceSectionEntry] = []
    var links: [ActionCommentaryLink] = []
    var verified: Set<ActionTextRef> = []
    var countCalls = 0, headlessSearchCalls = 0, readerCalls = 0, noteCalls = 0, resultsCalls = 0
    var countFailure: ActionOccurrenceFailure?
    var zero = false, stallCount = false
    var afterCount: (@MainActor () -> Void)?
    var afterNative: (@MainActor (String) -> Void)?
    var countQuery: ActionOccurrenceQuery?
    var resultsQuery: ActionSearchResultsQuery?
    var preparedReader: ActionReaderDestination?
    var openedReader: ActionReaderDestination?
    var selectedLocator: ActionTextRef?
    var preparedDraft: ActionNoteDraftRequest?
    var displayedDraft: ActionNoteDraftRequest?
    var notesAvailable = true, noteVisible = true, resultsVisible = true
    var wrongResultsReceipt = false, wrongReaderReceipt = false, savedNoteReceipt = false
    var queueResults = false
    var nativeRequests: [ActionRequest] = []

    init(catalogRevision: String? = nil) {
        baseWork = .init(backend: .otzaria, workKey: "book:1", catalogRevision: catalogRevision)
        commentaryWork = .init(backend: .otzaria, workKey: "book:2", catalogRevision: catalogRevision)
        base = .init(backend: .otzaria, workKey: "book:1", position: .legacyLine(12), catalogRevision: catalogRevision, dataRevision: "fixture-data")
        section = .init(backend: .otzaria, workKey: "book:2", position: .legacyLine(20), catalogRevision: catalogRevision, dataRevision: "fixture-data")
        focus = .init(backend: .otzaria, workKey: "book:2", position: .legacyLine(21), catalogRevision: catalogRevision, dataRevision: "fixture-data")
        entries = [.init(workRef: baseWork, title: "דברים", aliases: ["Deuteronomy"], provenance: "fixture:catalog"),
            .init(workRef: commentaryWork, title: "כלי יקר על דברים", aliases: ["Kli Yakar on Deuteronomy"], kind: .commentary, provenance: "fixture:catalog")]
        toc = [.init(locator: base, title: "פרק א")]
        links = [.init(baseLocator: base, destination: .init(sectionLocator: section, focusLocator: focus), title: "כלי יקר", aliases: ["Kli Yakar"])]
        verified = [base, section, focus]
    }
    func snapshot() async throws -> ActionBackendSnapshot { current }
    func currentBackendSnapshot() throws -> ActionBackendSnapshot { current }
    func report(for backend: ActionBackendID) async throws -> ActionBackendReport {
        .init(id: backend, operations: Dictionary(uniqueKeysWithValues: ActionRegistry.implemented.map {
            ($0, .init(registered: true, supported: true, availableNow: true))
        }))
    }
    func assess(action: String, arguments: ActionObject, invocation: ActionPortInvocation) async throws -> ActionCapabilityAssessment {
        .init(registered: true, supported: true, availableNow: true)
    }
    func catalog(for backend: ActionBackendID, invocation: ActionPortInvocation) async throws -> [ActionCatalogEntry] { entries }
    func referenceCandidates(_ query: ActionResolveReferenceQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionTextRef> {
        guard let work = query.workRef, let section = query.section else { return .notFound }
        return try CatalogActionResolver.sourceSectionCandidates(section: section, work: work, entries: toc, invocation: invocation)
    }
    func validate(_ ref: ActionTextRef, invocation: ActionPortInvocation) async throws -> ActionTextRef {
        guard verified.contains(ref) else { throw ActionPortError.notFound }; return ref
    }
    func commentaryLinks(for baseLocator: ActionTextRef, invocation: ActionPortInvocation) async throws -> [ActionCommentaryLink] { links }
    func search(_ query: ActionSearchQuery, invocation: ActionPortInvocation) async throws -> ActionSearchPage {
        headlessSearchCalls += 1; return .init(hits: [], total: 0, precision: .exact)
    }
    func countOccurrences(_ query: ActionOccurrenceQuery, invocation: ActionPortInvocation) async throws -> ActionExactOccurrenceCount {
        countCalls += 1; countQuery = query
        if stallCount { try await Task.sleep(nanoseconds: 5_000_000_000) }
        if let countFailure { throw countFailure }
        afterCount?()
        let digest = String(repeating: "a", count: 64)
        return .init(requestId: invocation.requestId, snapshot: invocation.snapshot, query: query,
            count: zero ? 0 : 2, matchingDocuments: zero ? 0 : 1, normalizedToken: "משה",
            evidence: .init(contract: ActionOccurrenceEvidence.requiredContract, engineRevision: ActionOccurrenceEvidence.requiredEngineRevision,
                engineSnapshotSHA256: digest, artifactIdentity: digest, databaseSHA256: digest,
                expectedIndexedDocuments: 100, observedIndexedDocuments: 100, visitedDocuments: 1, visitedPositions: 2,
                completeManagedArtifact: true))
    }
    func navigationState(sceneID: String) throws -> ActionNavigationState {
        .init(context: navigationContext, sceneID: "fixture-scene", lifetimeID: lifetime, authorityRevision: nativeRevision, active: active)
    }
    func prepareCommentaryReader(_ destination: ActionReaderDestination, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws {
        preparedReader = destination
    }
    func open(_ command: ActionOpenReaderCommand) async throws -> ActionUIAcknowledgement {
        guard preparedReader == command.destination, let grant = command.navigationAuthorization else { throw ActionPortError.invalidResponse }
        try grant.authorizeCommit(invocation: command.invocation, sceneID: command.sceneID, destination: command.destination)
        readerCalls += 1; openedReader = command.destination; selectedLocator = command.destination.focusLocator
        let target = wrongReaderReceipt ? ActionReaderDestination(sectionLocator: section, presentationMode: .newTab) : command.destination
        return .acknowledged(.init(requestId: command.invocation.requestId, snapshot: command.invocation.snapshot,
            sceneID: command.sceneID, destination: target))
    }
    func canPrepareNoteDraft(in sceneID: String) -> Bool { notesAvailable && selectedLocator != nil && sceneID == "fixture-scene" }
    func prepareNoteDraft(_ draft: ActionNoteDraftRequest, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws {
        guard let selectedLocator else { throw ActionPortError.unavailable }
        _ = try ActionNoteDraftSelection.validate(draft, observedLocator: selectedLocator,
            sourceText: "לפני בחירה אחרי", originalRange: NSRange(location: 5, length: 5))
        preparedDraft = draft
    }
    func presentNoteDraft(_ command: ActionPrepareNoteDraftCommand) async throws -> ActionNoteDraftAcknowledgement {
        guard preparedDraft == command.draft, let grant = command.navigationAuthorization else { throw ActionPortError.invalidResponse }
        try grant.authorizeCommit(invocation: command.invocation, sceneID: command.sceneID, noteDraft: command.draft)
        noteCalls += 1; displayedDraft = command.draft
        return .acknowledged(.init(requestId: command.invocation.requestId, snapshot: command.invocation.snapshot,
            sceneID: command.sceneID, draft: command.draft, isUnsaved: !savedNoteReceipt))
    }
    func validateNoteDraftCompletion(_ receipt: ActionNoteDraftReceipt, invocation: ActionPortInvocation) throws {
        guard noteVisible, displayedDraft == receipt.draft else { throw ActionPortError.staleState }
    }
    func canOpenSearchResults(in sceneID: String) -> Bool { sceneID == "fixture-scene" }
    func prepareSearchResults(_ query: ActionSearchResultsQuery, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws { resultsQuery = query }
    func openSearchResults(_ command: ActionOpenSearchResultsCommand) async throws -> ActionSearchResultsAcknowledgement {
        if queueResults { return .queued(handle: "fixture-queue-1") }
        guard resultsQuery == command.query, let grant = command.navigationAuthorization else { throw ActionPortError.invalidResponse }
        try grant.authorizeCommit(invocation: command.invocation, sceneID: command.sceneID, searchQuery: command.query)
        resultsCalls += 1
        return .acknowledged(.init(requestId: command.invocation.requestId, snapshot: command.invocation.snapshot,
            sceneID: command.sceneID, query: command.query, submissionRevision: wrongResultsReceipt ? 0 : resultsCalls))
    }
    func validateSearchResultsCompletion(_ command: ActionOpenSearchResultsCommand, receipt: ActionSearchResultsReceipt) throws {
        guard resultsVisible, resultsQuery == command.query else { throw ActionPortError.staleState }
    }
    func makeCore() throws -> ActionExecutor {
        try .init(state: self, resolver: CatalogActionResolver(data: self, state: self), search: self, ui: self, navigationAuthority: self)
    }
    func journey(readEnabled: Bool = true) throws -> ActionSemanticJourneys {
        let core = try makeCore(), epoch = sourceEpoch, read = readRevision
        let readAuthority: ActionSemanticJourneys.Authority?
        if readEnabled {
            readAuthority = { [self] in
                guard sourceEpoch == epoch, readRevision == read else { throw ActionPortError.staleState }
                return ActionJourneyAuthority(context: readContext, snapshot: current)
            }
        } else { readAuthority = nil }
        return .init(core: core, navigationAuthority: { [self] in
            guard sourceEpoch == epoch else { throw ActionPortError.staleState }
            return .init(context: navigationContext, snapshot: current)
        }, readAuthority: readAuthority) { [self] request, authority in
            nativeRequests.append(request)
            let result = await core.execute(request, context: authority.context)
            afterNative?(request.action)
            return result
        }
    }
    func query(text: String = "משה", scope: [ActionWorkRef]? = nil) -> ActionOccurrenceQuery {
        .init(backend: .otzaria, text: text, scopeWorkRefs: scope ?? [baseWork])
    }
}

@MainActor final class SemanticJourneyTests: XCTestCase, @unchecked Sendable {
    func testCountOpensByteExactOriginalQueryWithSameScopeAndDistinctDocumentCount() async throws {
        let f = JourneyFixture(), query = f.query(text: "e\u{0301}")
        let result = await (try f.journey()).countThenOpenResults(query)
        XCTAssertTrue(result.isComplete, String(describing: result.steps)); XCTAssertEqual(result.steps.count, 2)
        XCTAssertEqual(try result.steps[0].data?["count"]?.decoded(as: UInt64.self), 2)
        XCTAssertEqual(try result.steps[0].data?["matchingDocuments"]?.decoded(as: UInt64.self), 1)
        XCTAssertEqual(f.countQuery, query); XCTAssertEqual(f.resultsQuery?.search.scopeWorkRefs, query.scopeWorkRefs)
        let openedQuery = try XCTUnwrap(f.resultsQuery, String(describing: result.steps))
        XCTAssertEqual(Array(openedQuery.search.text.utf8), Array(query.text.utf8))
        XCTAssertNotEqual(f.resultsQuery?.search.text, "משה")
        XCTAssertEqual(f.resultsQuery?.search.searchMode, .phrase); XCTAssertEqual(f.resultsQuery?.search.matchMode, .exact)
        XCTAssertEqual(f.resultsQuery?.search.wordDistance, 0); XCTAssertEqual(f.resultsQuery?.search.sortOrder, .relevance)
        XCTAssertEqual(f.headlessSearchCalls, 0); XCTAssertEqual(f.resultsCalls, 1)
        XCTAssertEqual(f.nativeRequests.first?.expectedGeneration, 7)
    }
    func testRevisionBoundCountCannotDropRevisionToBypassOriginalResultsRefusal() async throws {
        let f = JourneyFixture(catalogRevision: "fixture-catalog")
        let query = f.query(), result = await (try f.journey()).countThenOpenResults(f.query())
        XCTAssertFalse(result.isComplete); XCTAssertEqual(result.steps.count, 2)
        XCTAssertEqual(result.steps[0].status, .completed)
        XCTAssertEqual(result.steps[1].error?.code, "scope_revision_not_supported")
        let arguments = try XCTUnwrap(f.nativeRequests.first?.arguments)
        let forwarded = try ActionSearchResultsQuery.arguments(arguments, backend: .otzaria)
        XCTAssertEqual(forwarded.search.scopeWorkRefs, query.scopeWorkRefs)
        XCTAssertEqual(f.countCalls, 1); XCTAssertEqual(f.resultsCalls, 0)
    }
    func testMissingReadAuthorityCannotCountOrOpen() async throws {
        let f = JourneyFixture(); let result = await (try f.journey(readEnabled: false)).countThenOpenResults(f.query())
        XCTAssertFalse(result.isComplete); XCTAssertEqual(result.steps.first?.error?.code, "trusted_read_authority_unavailable")
        XCTAssertEqual(f.countCalls, 0); XCTAssertEqual(f.resultsCalls, 0)
    }
    func testAbsentRightsRemainDeniedByOriginalCore() async throws {
        let f = JourneyFixture()
        f.readContext = .init(subjectID: "denied", origin: .inApp, allowedBackends: [.otzaria], scopes: [.discovery, .contentRead], foregroundSceneID: "fixture-scene")
        let result = await (try f.journey()).countThenOpenResults(f.query())
        XCTAssertEqual(result.steps.first?.error?.code, "content_rights_required")
        XCTAssertEqual(f.countCalls, 0); XCTAssertTrue(f.nativeRequests.isEmpty)
    }
    func testExplicitWorkReadAuthorityCannotBecomeGlobalScope() async throws {
        let f = JourneyFixture()
        f.readContext = .init(subjectID: "scoped", origin: .inApp, allowedBackends: [.otzaria], contentRights: [.otzaria],
            scopes: [.discovery, .contentRead], allowedWorkKeys: [.otzaria: ["book:1"]], foregroundSceneID: "fixture-scene")
        let result = await (try f.journey()).countThenOpenResults(f.query(scope: []))
        XCTAssertEqual(result.steps.first?.error?.code, "scope_required"); XCTAssertEqual(f.countCalls, 0); XCTAssertTrue(f.nativeRequests.isEmpty)
    }
    func testReadGrantForOtherSceneCannotReachCount() async throws {
        let f = JourneyFixture()
        f.readContext = .init(subjectID: "other-scene", origin: .inApp, allowedBackends: [.otzaria], contentRights: [.otzaria],
            scopes: [.discovery, .contentRead], foregroundSceneID: "another-scene")
        let result = await (try f.journey()).countThenOpenResults(f.query())
        XCTAssertEqual(result.steps.first?.status, .staleState); XCTAssertEqual(f.countCalls, 0)
    }
    func testRevokedReadAuthorityDiscardsCompletedProviderNumberBeforePublication() async throws {
        let f = JourneyFixture(); f.afterCount = { f.readRevision += 1 }
        let result = await (try f.journey()).countThenOpenResults(f.query())
        XCTAssertEqual(f.countCalls, 1); XCTAssertEqual(result.steps.first?.status, .staleState)
        XCTAssertNil(result.steps.first?.data); XCTAssertTrue(f.nativeRequests.isEmpty)
    }
    func testSourceABAEpochDiscardsCountEvenWhenBackendSnapshotIsIdentical() async throws {
        let f = JourneyFixture(); let original = f.current
        f.afterCount = { f.sourceEpoch += 2 }
        let result = await (try f.journey()).countThenOpenResults(f.query())
        XCTAssertEqual(f.current, original); XCTAssertEqual(result.steps.first?.status, .staleState)
        XCTAssertNil(result.steps.first?.data); XCTAssertEqual(f.resultsCalls, 0)
    }
    func testCredentialContextReplacementCannotReuseCompletedRead() async throws {
        let f = JourneyFixture()
        f.afterCount = { f.readContext = .init(subjectID: f.readContext.subjectID, origin: .inApp,
            allowedBackends: [.otzaria], contentRights: [.otzaria], scopes: [.discovery, .contentRead], foregroundSceneID: "fixture-scene") }
        let result = await (try f.journey()).countThenOpenResults(f.query())
        XCTAssertEqual(result.steps.first?.status, .staleState); XCTAssertNil(result.steps.first?.data); XCTAssertEqual(f.resultsCalls, 0)
    }
    func testBackendGenerationChangeNeverOpensOldCountQuery() async throws {
        let f = JourneyFixture(); f.afterCount = { f.current = .init(backend: .otzaria, generation: 8) }
        let result = await (try f.journey()).countThenOpenResults(f.query())
        XCTAssertEqual(result.steps.first?.status, .staleState); XCTAssertNil(result.steps.first?.data); XCTAssertEqual(f.resultsCalls, 0)
    }
    func testReadScopeDoesNotSupplyMissingNavigationPermission() async throws {
        let f = JourneyFixture()
        f.navigationContext = .init(subjectID: "no-navigation", origin: .inApp, allowedBackends: [.otzaria], scopes: [.discovery], foregroundSceneID: "fixture-scene")
        let result = await (try f.journey()).countThenOpenResults(f.query())
        XCTAssertEqual(result.steps[0].status, .completed); XCTAssertFalse(result.isComplete)
        XCTAssertEqual(result.steps[1].error?.code, "permission_denied"); XCTAssertEqual(f.resultsCalls, 0)
    }
    func testUnqualifiedCountFailureDoesNotBecomeZeroOrSearchFallback() async throws {
        let f = JourneyFixture(); f.countFailure = .incompleteCoverage
        let result = await (try f.journey()).countThenOpenResults(f.query())
        XCTAssertEqual(result.steps.first?.error?.code, "occurrence_coverage_unavailable"); XCTAssertNil(result.steps.first?.data)
        XCTAssertEqual(f.resultsCalls, 0); XCTAssertEqual(f.headlessSearchCalls, 0)
    }
    func testProvenZeroStillOpensTheSameSearch() async throws {
        let f = JourneyFixture(); f.zero = true
        let result = await (try f.journey()).countThenOpenResults(f.query())
        XCTAssertTrue(result.isComplete); XCTAssertEqual(try result.steps[0].data?["count"]?.decoded(as: UInt64.self), 0)
        XCTAssertEqual(f.resultsCalls, 1); XCTAssertEqual(f.resultsQuery?.search.text, "משה")
    }
    func testUnsupportedCountUnitNeverInvokesResultsUI() async throws {
        let f = JourneyFixture()
        let result = await (try f.journey()).countThenOpenResults(.init(backend: .otzaria, text: "משה", countUnit: .matchingDocuments))
        XCTAssertEqual(result.steps.first?.status, .notSupported); XCTAssertEqual(f.countCalls, 0); XCTAssertEqual(f.resultsCalls, 0)
    }
    func testCancellationOfInflightCountNeverPublishesOrOpens() async throws {
        let f = JourneyFixture(); f.stallCount = true
        let journey = try f.journey(), query = f.query()
        let task = Task { @MainActor in await journey.countThenOpenResults(query) }
        let deadline = Date().addingTimeInterval(2)
        while f.countCalls == 0 && Date() < deadline { await Task.yield() }
        XCTAssertEqual(f.countCalls, 1); task.cancel()
        let result = await task.value
        XCTAssertEqual(result.steps.first?.status, .cancelled); XCTAssertNil(result.steps.first?.data); XCTAssertEqual(f.resultsCalls, 0)
    }
    func testWrongNativeReceiptLeavesTheCountButDoesNotCompleteJourney() async throws {
        let f = JourneyFixture(); f.wrongResultsReceipt = true
        let result = await (try f.journey()).countThenOpenResults(f.query())
        XCTAssertFalse(result.isComplete); XCTAssertEqual(result.steps[0].status, .completed)
        XCTAssertEqual(result.steps[1].error?.code, "native_effect_uncertain"); XCTAssertEqual(result.steps[1].error?.retryable, false)
        XCTAssertEqual(f.resultsCalls, 1)
    }
    func testQueuedResultsAreNotSuccessfulJourney() async throws {
        let f = JourneyFixture(); f.queueResults = true
        let result = await (try f.journey()).countThenOpenResults(f.query())
        XCTAssertFalse(result.isComplete); XCTAssertEqual(result.steps.last?.status, .uiQueued); XCTAssertEqual(f.resultsCalls, 0)
    }
    func testOriginalFinalResultsVisibilityGuardRemainsMandatory() async throws {
        let f = JourneyFixture(); f.resultsVisible = false
        let result = await (try f.journey()).countThenOpenResults(f.query())
        XCTAssertFalse(result.isComplete); XCTAssertEqual(result.steps.last?.error?.code, "native_effect_uncertain"); XCTAssertEqual(f.resultsCalls, 1)
    }
    func testReadRevokedDuringResultsPresentationDiscardsNumberButPreservesNativeEffect() async throws {
        let f = JourneyFixture(); f.afterNative = { if $0 == "search.openResults" { f.readRevision += 1 } }
        let result = await (try f.journey()).countThenOpenResults(f.query())
        XCTAssertFalse(result.isComplete); XCTAssertEqual(result.steps.count, 2)
        XCTAssertEqual(result.steps[0].status, .staleState); XCTAssertNil(result.steps[0].data)
        XCTAssertEqual(result.steps[1].status, .completed); XCTAssertEqual(f.resultsCalls, 1)
    }
    func testSourceChangedDuringResultsPresentationDiscardsNumberButDoesNotEraseReceipt() async throws {
        let f = JourneyFixture(); f.afterNative = { if $0 == "search.openResults" { f.sourceEpoch += 2 } }
        let result = await (try f.journey()).countThenOpenResults(f.query())
        XCTAssertFalse(result.isComplete); XCTAssertEqual(result.steps.count, 2)
        XCTAssertEqual(result.steps[0].status, .staleState); XCTAssertNil(result.steps[0].data)
        XCTAssertEqual(result.steps[1].status, .completed); XCTAssertEqual(f.resultsCalls, 1)
    }
    func testCommentaryDraftUsesExactAcknowledgedFocusAndOriginalUnsavedEditor() async throws {
        let f = JourneyFixture(); let proposal = "הערה e\u{0301}"
        let result = await (try f.journey()).commentaryThenPrepareDraft(baseLocator: f.base, commentaryQuery: "כלי יקר", proposedText: proposal)
        XCTAssertTrue(result.isComplete); XCTAssertEqual(f.openedReader?.presentationMode, .newTab)
        XCTAssertEqual(f.displayedDraft?.locator, f.focus); XCTAssertNotEqual(f.displayedDraft?.locator, f.base)
        XCTAssertEqual(Array(f.displayedDraft!.proposedText!.utf8), Array(proposal.utf8))
        XCTAssertNil(f.displayedDraft?.selectedText); XCTAssertEqual(result.steps.last?.data?["saved"], .bool(false))
        XCTAssertEqual(f.readerCalls, 1); XCTAssertEqual(f.noteCalls, 1); XCTAssertEqual(f.headlessSearchCalls, 0)
    }
    func testAmbiguousCommentaryNeverChoosesFirstTargetOrOpensDraft() async throws {
        let f = JourneyFixture(); let other = ActionTextRef(backend: .otzaria, workKey: "book:2", position: .legacyLine(22), catalogRevision: f.focus.catalogRevision, dataRevision: "fixture-data")
        f.verified.insert(other); f.links.append(.init(baseLocator: f.base, destination: .init(sectionLocator: f.section, focusLocator: other), title: "כלי יקר"))
        let result = await (try f.journey()).commentaryThenPrepareDraft(baseLocator: f.base, commentaryQuery: "כלי יקר")
        XCTAssertEqual(result.steps.first?.status, .needsDisambiguation); XCTAssertEqual(result.steps.first?.candidates?.count, 2)
        XCTAssertEqual(f.readerCalls, 0); XCTAssertEqual(f.noteCalls, 0)
    }
    func testMissingOrInvisibleOriginalSelectionDoesNotInventNoteRange() async throws {
        let f = JourneyFixture(); f.notesAvailable = false
        let result = await (try f.journey()).commentaryThenPrepareDraft(baseLocator: f.base, commentaryQuery: "כלי יקר")
        XCTAssertFalse(result.isComplete); XCTAssertEqual(result.steps[0].status, .completed)
        XCTAssertEqual(result.steps[1].error?.code, "exact_note_selection_unavailable"); XCTAssertEqual(f.readerCalls, 1); XCTAssertEqual(f.noteCalls, 0)
    }
    func testSectionOnlyRelationshipCannotInventSelectedSegmentForDraft() async throws {
        let f = JourneyFixture(); f.links = [.init(baseLocator: f.base, destination: .init(sectionLocator: f.section), title: "כלי יקר")]
        let result = await (try f.journey()).commentaryThenPrepareDraft(baseLocator: f.base, commentaryQuery: "כלי יקר")
        XCTAssertEqual(result.steps[0].status, .completed); XCTAssertFalse(result.isComplete)
        XCTAssertNil(f.selectedLocator); XCTAssertEqual(f.noteCalls, 0)
    }
    func testSourceChangeAfterReaderReceiptStopsBeforeDraftAndRetainsFirstEffect() async throws {
        let f = JourneyFixture(); f.afterNative = { if $0 == "reader.openCommentary" { f.sourceEpoch += 1 } }
        let result = await (try f.journey()).commentaryThenPrepareDraft(baseLocator: f.base, commentaryQuery: "כלי יקר")
        XCTAssertFalse(result.isComplete); XCTAssertEqual(result.steps[0].status, .completed); XCTAssertEqual(result.steps[0].effects, ["reader_opened"])
        XCTAssertEqual(result.steps[1].status, .staleState); XCTAssertEqual(f.readerCalls, 1); XCTAssertEqual(f.noteCalls, 0)
    }
    func testWrongCommentaryReceiptCannotPrepareAnyDraft() async throws {
        let f = JourneyFixture(); f.wrongReaderReceipt = true
        let result = await (try f.journey()).commentaryThenPrepareDraft(baseLocator: f.base, commentaryQuery: "כלי יקר")
        XCTAssertFalse(result.isComplete); XCTAssertEqual(result.steps.count, 1); XCTAssertEqual(f.noteCalls, 0)
    }
    func testNoteReceiptMustStillBeUnsavedAndActuallyVisible() async throws {
        for saved in [false, true] {
            let f = JourneyFixture(); f.savedNoteReceipt = saved; f.noteVisible = saved
            let result = await (try f.journey()).commentaryThenPrepareDraft(baseLocator: f.base, commentaryQuery: "כלי יקר")
            XCTAssertFalse(result.isComplete); XCTAssertEqual(result.steps[0].status, .completed)
            XCTAssertEqual(result.steps[1].error?.code, "native_effect_uncertain"); XCTAssertEqual(f.noteCalls, 1)
        }
    }
    func testActualCatalogTOCAndLinksFeedOneExactFourStepJourney() async throws {
        let f = JourneyFixture()
        let result = await (try f.journey()).resolveCommentaryThenPrepareDraft(backend: .otzaria, baseWorkQuery: "דברים",
            section: "פרק א", commentaryQuery: "כלי יקר", proposedText: "הצעה")
        XCTAssertTrue(result.isComplete); XCTAssertEqual(result.steps.map(\.action), result.plannedActions)
        XCTAssertEqual(try result.steps[0].data?["workRef"]?.decoded(as: ActionWorkRef.self), f.baseWork)
        XCTAssertEqual(try result.steps[1].data?["locator"]?.decoded(as: ActionTextRef.self), f.base)
        XCTAssertEqual(f.displayedDraft?.locator, f.focus); XCTAssertEqual(f.readerCalls, 1); XCTAssertEqual(f.noteCalls, 1)
    }
    func testUnknownTOCSectionStopsWithoutGuessingLineZero() async throws {
        let f = JourneyFixture()
        let result = await (try f.journey()).resolveCommentaryThenPrepareDraft(backend: .otzaria, baseWorkQuery: "דברים",
            section: "invented section", commentaryQuery: "כלי יקר")
        XCTAssertFalse(result.isComplete); XCTAssertEqual(result.steps.count, 2); XCTAssertEqual(result.steps.last?.error?.code, "not_found")
        XCTAssertEqual(f.readerCalls, 0); XCTAssertEqual(f.noteCalls, 0)
    }
    func testUnknownCommentatorIsNotInventedFromBaseTitle() async throws {
        let f = JourneyFixture()
        let result = await (try f.journey()).resolveCommentaryThenPrepareDraft(backend: .otzaria, baseWorkQuery: "דברים",
            section: "פרק א", commentaryQuery: "Kli Ykr")
        XCTAssertFalse(result.isComplete); XCTAssertEqual(result.steps.count, 3); XCTAssertEqual(result.steps.last?.error?.code, "not_found")
        XCTAssertEqual(f.readerCalls, 0); XCTAssertEqual(f.noteCalls, 0)
    }
    func testAmbiguousBaseCatalogStopsBeforeTOCOrNativeAction() async throws {
        let f = JourneyFixture()
        f.entries.append(.init(workRef: .init(backend: .otzaria, workKey: "book:3", catalogRevision: "fixture-catalog"), title: "דברים", provenance: "fixture:second-edition"))
        let result = await (try f.journey()).resolveCommentaryThenPrepareDraft(backend: .otzaria, baseWorkQuery: "דברים",
            section: "פרק א", commentaryQuery: "כלי יקר")
        XCTAssertEqual(result.steps.first?.status, .needsDisambiguation); XCTAssertEqual(result.steps.count, 1)
        XCTAssertTrue(f.nativeRequests.isEmpty)
    }
    func testCanonicalSearchProjectionPreservesAllFieldsAndRejectsPaging() throws {
        let f = JourneyFixture(catalogRevision: "fixture-catalog")
        let search = ActionSearchQuery(backend: .otzaria, text: "e\u{0301}", scopeWorkRefs: [f.baseWork], sortOrder: .canonical)
        let query = try ActionSearchResultsQuery(search), arguments = try query.actionArguments()
        XCTAssertEqual(try ActionSearchResultsQuery.arguments(arguments, backend: .otzaria), query)
        XCTAssertNil(arguments["searchQuery"]?.object?["offset"]); XCTAssertNil(arguments["searchQuery"]?.object?["limit"])
        XCTAssertEqual(arguments["searchQuery"]?.object?["sortOrder"], .string("canonical"))
        XCTAssertThrowsError(try ActionSearchResultsQuery(.init(backend: .otzaria, text: "word", offset: 20)))
        var paged = arguments["searchQuery"]!.object!; paged["offset"] = .integer(0)
        XCTAssertThrowsError(try ActionSearchResultsQuery.arguments(["searchQuery": .object(paged)], backend: .otzaria))
    }
    func testOriginalHeadlessReadRemainsIndependentOfJourneys() async throws {
        let f = JourneyFixture(), core = try f.makeCore()
        let result = await core.execute(.init(action: "search.query", arguments: ["text": .string("ordinary query")], expectedBackend: .otzaria), context: f.readContext)
        XCTAssertEqual(result.status, .completed); XCTAssertEqual(f.headlessSearchCalls, 1)
        XCTAssertEqual(f.countCalls + f.readerCalls + f.noteCalls + f.resultsCalls, 0)
    }
}
