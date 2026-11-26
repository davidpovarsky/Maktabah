import XCTest
import Foundation
import HanlinPlatformContracts
import HanlinHostContracts
import HanlinAgentCore
import OtzariaActionCore
@testable import OtzariaHanlinHostAdapter

private actor Fixture: ActionBackendStatePort, ActionResolverPort, ActionSearchPort,
    ActionCatalogAuthorsPort, ActionTableOfContentsPort, OtzariaHanlinNavigationAuthority {
    var binding: OtzariaHanlinBinding
    var reads = 0
    var searchReads = 0
    var metadataReads = 0
    var serveReadActions = false
    var wrongSearchWork = false
    var searchHold = false
    var searchEntered = false
    var searchBlocked: CheckedContinuation<Void, Never>?
    var searchObservedCancellation = false
    var lastSearchQuery: ActionSearchQuery?
    var authorityRevoked = false
    var unavailableActions = Set<String>()
    var hold = false
    var entered = false
    var blocked: CheckedContinuation<Void, Never>?
    var wrongReceipt = false
    var navigationCount = 0
    var queuedTransition = false
    var holdTransition = false
    var transitionEntered = false
    var transitionBlocked: CheckedContinuation<Void, Never>?
    var staleSuccessor = false
    var holdAuthority = false
    var authorityEntered = false
    var authorityBlocked: CheckedContinuation<Void, Never>?
    init(binding: OtzariaHanlinBinding) { self.binding = binding }
    func current(for session: HanlinHostSession) async throws -> OtzariaHanlinBinding {
        if holdAuthority {
            holdAuthority = false; authorityEntered = true
            await withCheckedContinuation { authorityBlocked = $0 }
        }
        guard !authorityRevoked else { throw HanlinHostError.staleContext }
        return binding
    }
    func current(for context: HanlinHostContext) async throws -> OtzariaHanlinBinding {
        guard !authorityRevoked else { throw HanlinHostError.staleContext }
        return binding
    }
    func snapshot() async throws -> ActionBackendSnapshot { binding.backend }
    func report(for backend: ActionBackendID) async throws -> ActionBackendReport {
        reads += 1
        if hold {
            hold = false; entered = true
            await withCheckedContinuation { blocked = $0 }
        }
        let names = ActionRegistry.implemented.union(["notes.save", "search.countOccurrences"])
        return .init(id: backend, operations: Dictionary(uniqueKeysWithValues: names.map {
            ($0, .init(registered: true, supported: true, availableNow: !unavailableActions.contains($0)))
        }))
    }
    func assess(action: String, arguments: ActionObject, invocation: ActionPortInvocation) async throws -> ActionCapabilityAssessment {
        .init(registered: true, supported: true, availableNow: true)
    }
    func resolveWork(_ query: ActionResolveWorkQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionWorkRef> {
        guard serveReadActions else { throw ActionPortError.unavailable }
        metadataReads += 1
        return .unique(query.workRef ?? .init(backend: query.backend, workKey: "book:2"))
    }
    func resolveReference(_ query: ActionResolveReferenceQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionTextRef> {
        guard serveReadActions else { throw ActionPortError.unavailable }
        metadataReads += 1
        return .unique(.init(backend: query.backend, workKey: query.workRef?.workKey ?? "book:2", position: .legacyLine(0)))
    }
    func catalogAuthors(backend: ActionBackendID, invocation: ActionPortInvocation) async throws -> [ActionCatalogAuthor] {
        metadataReads += 1
        return [.init(id: "fixture-author", name: "Fixture author")]
    }
    func tableOfContents(for work: ActionWorkRef, maximumEntries: Int,
                         invocation: ActionPortInvocation) async throws -> [ActionSourceSectionEntry] {
        metadataReads += 1
        return [.init(locator: .init(backend: work.backend, workKey: work.workKey, position: .legacyLine(0)),
                      title: "Fixture chapter")]
    }
    func validateDestination(_ destination: ActionReaderDestination, invocation: ActionPortInvocation) async throws -> ActionReaderDestination { throw ActionPortError.unavailable }
    func search(_ query: ActionSearchQuery, invocation: ActionPortInvocation) async throws -> ActionSearchPage {
        guard serveReadActions else { throw ActionPortError.unavailable }
        searchReads += 1; lastSearchQuery = query; searchEntered = true
        if searchHold { await withCheckedContinuation { searchBlocked = $0 } }
        searchObservedCancellation = Task.isCancelled
        let work = wrongSearchWork ? "book:2" : (query.scopeWorkRefs.first?.workKey ?? "book:1")
        return .init(hits: [.init(id: "fixture-hit", locator: .init(backend: query.backend, workKey: work, position: .legacyLine(0)),
            title: "Fixture work", snippet: wrongSearchWork ? "FORBIDDEN_OTHER_WORK" : "Allowed fixture excerpt")],
            total: 1, precision: .exact, nextOffset: nil)
    }
    func enableReadActions() { serveReadActions = true }
    func setSearchHold() { searchHold = true }
    func setWrongSearchWork() { wrongSearchWork = true }
    func releaseSearch() { searchBlocked?.resume(); searchBlocked = nil }
    func revokeAuthority() { authorityRevoked = true }
    func replaceSearchContext(_ context: ActionExecutionContext) {
        binding = .init(context: binding.context, executionContext: binding.executionContext, backend: binding.backend,
            catalogRevision: binding.catalogRevision, availableReadActions: binding.availableReadActions,
            searchExecutionContext: context)
    }
    func removeSearchGrant() {
        binding = .init(context: binding.context, executionContext: binding.executionContext, backend: binding.backend,
            catalogRevision: binding.catalogRevision, availableReadActions: binding.availableReadActions)
    }
    func waitForSearch() async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while !searchEntered {
            guard ContinuousClock.now < deadline else { throw NSError(domain: "SearchWasNotEntered", code: 1) }
            try await Task.sleep(for: .milliseconds(5))
        }
    }
    func open(_ destination: HanlinHostDestination, binding: OtzariaHanlinBinding) async throws -> HanlinHostNavigationResult {
        if wrongReceipt { return .presented(requestID: UUID(), context: destination.context,
            objectReference: destination.objectReference, blockReference: destination.blockReference) }
        return .queued(requestID: destination.requestID, context: destination.context)
    }
    func openWithContextTransition(_ destination: HanlinHostDestination,
        session: HanlinHostSession, binding: OtzariaHanlinBinding) async throws -> HanlinHostNavigationReceipt {
        navigationCount += 1
        if queuedTransition {
            return .init(originalSession: session,
                result: .queued(requestID: destination.requestID, context: destination.context))
        }
        if holdTransition {
            transitionEntered = true
            await withCheckedContinuation { transitionBlocked = $0 }
        }
        changeGeneration()
        let successor = HanlinHostSession(conversationID: session.conversationID, context: self.binding.context)
        let receipt = HanlinHostNavigationReceipt(originalSession: session,
            result: .presented(requestID: wrongReceipt ? UUID() : destination.requestID,
                context: destination.context, objectReference: destination.objectReference,
                blockReference: destination.blockReference), successorSession: successor)
        if staleSuccessor { changeGeneration() }
        return receipt
    }
    func setQueuedTransition() { queuedTransition = true }
    func setStaleSuccessor() { staleSuccessor = true }
    func setTransitionHold() { holdTransition = true }
    func waitForTransition() async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while !transitionEntered {
            guard ContinuousClock.now < deadline else { throw NSError(domain: "TransitionNotEntered", code: 1) }
            try await Task.sleep(for: .milliseconds(5))
        }
    }
    func releaseTransition() { transitionBlocked?.resume(); transitionBlocked = nil }
    func resetReads() { reads = 0 }
    func setUnavailable(_ actions: Set<String>) { unavailableActions = actions }
    func setHold() { hold = true }
    func setAuthorityHold() { holdAuthority = true }
    func waitForAuthority() async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while !authorityEntered {
            guard ContinuousClock.now < deadline else {
                throw NSError(domain: "AuthorityWasNotEntered", code: 1)
            }
            try await Task.sleep(for: .milliseconds(5))
        }
    }
    func releaseAuthority() { authorityBlocked?.resume(); authorityBlocked = nil }
    func waitForRead() async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while !entered {
            guard ContinuousClock.now < deadline else {
                throw NSError(domain: "CorePortWasNotEntered", code: 1)
            }
            try await Task.sleep(for: .milliseconds(5))
        }
    }
    func release() { blocked?.resume(); blocked = nil }
    func setWrongReceipt() { wrongReceipt = true }
    func changeGeneration() {
        let old = binding.context
        let context = HanlinHostContext(namespace: old.namespace, sceneID: old.sceneID, generation: UUID(),
            objectReference: old.objectReference, selectionReferences: old.selectionReferences,
            sourceRevision: old.sourceRevision)
        binding = .init(context: context, executionContext: binding.executionContext, backend: binding.backend,
            catalogRevision: binding.catalogRevision, availableReadActions: binding.availableReadActions,
            searchExecutionContext: binding.searchExecutionContext)
    }
}

// The XCTest instance has no stored mutable test state; every fixture is an actor.
// No UI/main-thread work occurs in this portable contract suite.
final class OtzariaHanlinHostAdapterTests: XCTestCase, @unchecked Sendable {
    private func setup(rights: Bool = true, foreground: Bool = true, nativeSceneID: String? = nil,
                       additionalReadTools: Set<String> = []) async throws
        -> (Fixture, OtzariaHanlinHostAdapter, HanlinHostSession, HanlinHostCatalog) {
        let scene = UUID()
        let context = HanlinHostContext(namespace: try .init(app: "otzaria", account: "fixture-only",
            workspace: "fixture-workspace", space: "fixture-space"), sceneID: scene, generation: UUID(),
            objectReference: "otzaria|book:1", sourceRevision: "source-1")
        let execution = ActionExecutionContext(subjectID: "fixture-only", origin: .internalAI,
            allowedBackends: [.otzaria], contentRights: rights ? [.otzaria] : [],
            scopes: [.discovery, .contentRead, .navigation],
            foregroundSceneID: foreground ? (nativeSceneID ?? scene.uuidString) : nil, maxResultBytes: 65_536)
        let binding = OtzariaHanlinBinding(context: context, executionContext: execution,
            backend: .init(backend: .otzaria, generation: 9_007_199_254_740_993),
            catalogRevision: .init(7), availableReadActions: ActionRegistry.implemented
                .subtracting(["catalog.listAuthors", "reader.getTOC"])
                .union(["notes.save"]).union(additionalReadTools))
        let fixture = Fixture(binding: binding)
        let core = try ActionExecutor(state: fixture, resolver: fixture, search: fixture)
        let adapter = try OtzariaHanlinHostAdapter(core: core, authority: fixture)
        let session = HanlinHostSession(conversationID: UUID(), context: context)
        let catalog = try await adapter.catalog(for: context)
        // Admission/discovery is observed separately from the execution-count
        // assertions below; those still prove malformed/replayed calls do not execute.
        await fixture.resetReads()
        return (fixture, adapter, session, catalog)
    }
    private func invocation(_ session: HanlinHostSession, _ catalog: HanlinHostCatalog,
                            raw: String? = "{}", outputLimit: Int = 65_536,
                            guarantee: HanlinHostWriteGuarantee = .readOnly,
                            provider: String? = nil, revision: UInt64? = nil,
                            deadline: Date? = nil, toolID: String = "system.list-backends") throws -> HanlinHostInvocation {
        let tool = try XCTUnwrap(catalog.tools.first { $0.route.logicalToolID.localToolID.rawValue == toolID })
        let logical = HanlinLogicalToolID(providerInstanceID: try provider.map { try .init(validating: $0) }
            ?? tool.route.logicalToolID.providerInstanceID, localToolID: tool.route.logicalToolID.localToolID)
        let request = HanlinToolInvocationRequest(id: try .init(validating: "inv-" + UUID().uuidString.lowercased()),
            logicalToolID: logical, aliasUsed: tool.route.alias, descriptorRevision: tool.route.descriptorRevision,
            routingTableRevision: revision.map(HanlinCatalogRevision.init) ?? catalog.revision,
            arguments: .object([:]), origin: .assistantModel, deadline: deadline,
            limits: try .init(maximumOutputBytes: outputLimit))
        return .init(request: request, session: session, runID: UUID(), step: 0, providerCallID: "fixture",
            writeGuarantee: guarantee, expectedRevision: session.context.sourceRevision,
            originalArgumentsJSON: raw.map { Data($0.utf8) })
    }

    func testCatalogIsExactReadOnlyProjectionAndBackendQualified() async throws {
        let (_, _, _, catalog) = try await setup()
        XCTAssertEqual(catalog.tools.count, 4)
        XCTAssertTrue(catalog.tools.allSatisfy { $0.writeGuarantee == .readOnly })
        XCTAssertTrue(catalog.tools.allSatisfy { $0.route.logicalToolID.providerInstanceID.rawValue == "otzaria.actioncore.otzaria" })
        XCTAssertFalse(catalog.tools.contains { $0.route.logicalToolID.localToolID.rawValue.contains("reader") })
        XCTAssertTrue(catalog.tools.allSatisfy { $0.originalInputSchemaJSON != nil })
    }
    func testContentRightsHideSearchButPreserveCanonicalMetadataActions() async throws {
        let (_, _, _, catalog) = try await setup(rights: false)
        // ActionCore declares both catalog actions risk tier zero. Content
        // rights protect search content, not the original public work metadata.
        XCTAssertEqual(Set(catalog.tools.map { $0.route.logicalToolID.localToolID.rawValue }),
                       ["system.list-backends", "catalog.resolve-work", "catalog.resolve-reference"])
    }

    func testAuthorizedAuthorDiscoveryUsesSameOriginalCatalogWithoutContentRights() async throws {
        let (fixture, adapter, session, catalog) = try await setup(rights: false,
            additionalReadTools: ["catalog.listAuthors", "reader.getTOC"])
        let names = Set(catalog.tools.map { $0.route.logicalToolID.localToolID.rawValue })
        XCTAssertTrue(names.contains("catalog.list-authors"))
        XCTAssertFalse(names.contains("reader.get-toc"))
        let request = try invocation(session, catalog, toolID: "catalog.list-authors")
        let response = try await adapter.execute(request) { _ in }
        let reads = await fixture.metadataReads
        XCTAssertEqual(reads, 1)
        guard case .completed(let output) = response.result.outcome,
              case .text(let json) = output.first else { return XCTFail("The original author query did not complete") }
        XCTAssertTrue(json.contains("Fixture author"))
    }

    func testExplicitContentRightsUnlockNativeTableOfContentsWithTypedWorkReference() async throws {
        let (fixture, adapter, session, catalog) = try await setup(additionalReadTools: ["reader.getTOC"])
        let request = try invocation(session, catalog,
            raw: #"{"workRef":{"backend":"otzaria","workKey":"book:2"}}"#, toolID: "reader.get-toc")
        let response = try await adapter.execute(request) { _ in }
        let reads = await fixture.metadataReads
        XCTAssertEqual(reads, 1)
        guard case .completed(let output) = response.result.outcome,
              case .text(let json) = output.first else { return XCTFail("The original table of contents did not complete") }
        XCTAssertTrue(json.contains("Fixture chapter"))
        XCTAssertTrue(json.contains("book:2"))
    }

    func testCatalogUsesSamePolicyAsOriginalCoreWithoutContentRights() async throws {
        let (fixture, _, session, catalog) = try await setup(rights: false)
        let core = try ActionExecutor(state: fixture, resolver: fixture, search: fixture)
        let binding = try await fixture.current(for: session)
        let original = await core.advertisedActions(for: binding.backend.backend, context: binding.executionContext)
        let names = ["system.listBackends": "system.list-backends",
                     "catalog.resolveWork": "catalog.resolve-work",
                     "catalog.resolveReference": "catalog.resolve-reference",
                     "search.query": "search.query"]
        let expected = Set(original.compactMap { names[$0.id] })
        XCTAssertEqual(expected, ["system.list-backends", "catalog.resolve-work", "catalog.resolve-reference"])
        XCTAssertEqual(Set(catalog.tools.map { $0.route.logicalToolID.localToolID.rawValue }), expected)
    }

    func testCatalogUsesCanonicalAvailabilityAndDoesNotExposeMetadataOnlyActions() async throws {
        let (fixture, adapter, session, _) = try await setup()
        await fixture.setUnavailable(["catalog.resolveWork", "catalog.resolveReference", "search.query"])
        let catalog = try await adapter.catalog(for: session.context)
        XCTAssertEqual(catalog.tools.map { $0.route.logicalToolID.localToolID.rawValue }, ["system.list-backends"])
        XCTAssertFalse(catalog.tools.contains { $0.route.logicalToolID.localToolID.rawValue.contains("save") })
        XCTAssertFalse(catalog.tools.contains { $0.route.logicalToolID.localToolID.rawValue.contains("count") })
    }

    func testCanonicalCatalogReadRevalidatesOriginalHostAfterAwait() async throws {
        let (fixture, adapter, session, _) = try await setup()
        await fixture.setHold()
        let work = Task { try await adapter.catalog(for: session.context) }
        do { try await fixture.waitForRead() }
        catch { work.cancel(); await fixture.release(); throw error }
        await fixture.changeGeneration()
        await fixture.release()
        do { _ = try await work.value; XCTFail("Revoked catalog escaped the original host authority") }
        catch let error as HanlinHostError { XCTAssertEqual(error, .staleContext) }
    }
    func testRealCoreExecutionPreservesGenerationBeyondDoublePrecision() async throws {
        let (fixture, adapter, session, catalog) = try await setup()
        let call = try invocation(session, catalog)
        let result = try await adapter.execute(call) { _ in }
        guard case .completed(let content) = result.result.outcome, case .text(let text) = content.first else {
            return XCTFail("Actual ActionCore result was not returned")
        }
        let core = try JSONDecoder().decode(ActionResult.self, from: Data(text.utf8))
        XCTAssertEqual(core.requestId, call.resultID)
        XCTAssertEqual(core.backendGeneration, 9_007_199_254_740_993)
        XCTAssertEqual(core.action, "system.listBackends")
        XCTAssertEqual(core.status, .completed)
        XCTAssertEqual(result.effectState, .confirmedNoEffect)
        let count = await fixture.reads; XCTAssertEqual(count, 1)
    }
    func testMissingOriginalArgumentsAndDuplicateKeysNeverReachCorePorts() async throws {
        let (fixture, adapter, session, catalog) = try await setup()
        for raw: String? in [nil, "{\"includeReadiness\":true,\"includeReadiness\":false}"] {
            do { _ = try await adapter.execute(invocation(session, catalog, raw: raw)) { _ in }; XCTFail("Invalid raw input accepted") }
            catch {}
        }
        let count = await fixture.reads; XCTAssertEqual(count, 0)
    }
    func testCanonicalSchemaRejectionNeverBecomesCompleted() async throws {
        let (fixture, adapter, session, catalog) = try await setup()
        let result = try await adapter.execute(invocation(session, catalog, raw: "{\"unexpected\":true}")) { _ in }
        guard case .failed = result.result.outcome else { return XCTFail("Canonical failure was relabeled success") }
        let count = await fixture.reads; XCTAssertEqual(count, 0)
    }
    func testForeignProviderAndStaleCatalogAreRejected() async throws {
        let (fixture, adapter, session, catalog) = try await setup()
        let calls = [try invocation(session, catalog, provider: "foreign.provider"),
                     try invocation(session, catalog, revision: 8)]
        for call in calls {
            do { _ = try await adapter.execute(call) { _ in }; XCTFail("Foreign/stale request accepted") }
            catch let error as HanlinHostError { XCTAssertEqual(error, .unknownTool) }
        }
        let count = await fixture.reads; XCTAssertEqual(count, 0)
    }
    func testMutationGuaranteeIsRejectedBeforeDispatch() async throws {
        let (fixture, adapter, session, catalog) = try await setup()
        do { _ = try await adapter.execute(invocation(session, catalog, guarantee: .hostManagedMutation)) { _ in }; XCTFail("Mutation accepted") }
        catch let error as HanlinHostError { XCTAssertEqual(error, .unsupportedConditionalWrite) }
        let count = await fixture.reads; XCTAssertEqual(count, 0)
    }
    func testReplayDoesNotExecuteAgain() async throws {
        let (fixture, adapter, session, catalog) = try await setup()
        let call = try invocation(session, catalog)
        _ = try await adapter.execute(call) { _ in }
        do { _ = try await adapter.execute(call) { _ in }; XCTFail("Replay accepted") }
        catch let error as HanlinHostError { XCTAssertEqual(error, .duplicateInvocation) }
        let count = await fixture.reads; XCTAssertEqual(count, 1)
    }
    func testContextRevocationDuringReadSuppressesResult() async throws {
        let (fixture, adapter, session, catalog) = try await setup()
        let call = try invocation(session, catalog)
        await fixture.setHold()
        let work = Task { try await adapter.execute(call) { _ in } }
        try await fixture.waitForRead(); await fixture.changeGeneration(); await fixture.release()
        do { _ = try await work.value; XCTFail("Stale result exposed") }
        catch let error as HanlinHostError { XCTAssertEqual(error, .staleContext) }
    }
    func testExplicitCancellationReachesOriginalCoreTask() async throws {
        let (fixture, adapter, session, catalog) = try await setup()
        let call = try invocation(session, catalog)
        await fixture.setHold()
        let work = Task { try await adapter.execute(call) { _ in } }
        try await fixture.waitForRead(); await adapter.cancel(call.request.id); await fixture.release()
        let result = try await work.value
        guard case .failed(let error) = result.result.outcome else { return XCTFail("Cancellation became success") }
        XCTAssertEqual(error.code, .cancelled)
    }
    func testCancellationDuringAuthorityLookupNeverReachesCore() async throws {
        let (fixture, adapter, session, catalog) = try await setup()
        let call = try invocation(session, catalog)
        await fixture.setAuthorityHold()
        let work = Task { try await adapter.execute(call) { _ in } }
        try await fixture.waitForAuthority()
        await adapter.cancel(call.request.id)
        await fixture.releaseAuthority()
        do { _ = try await work.value; XCTFail("Cancelled admission reached execution") }
        catch is CancellationError {}
        let count = await fixture.reads; XCTAssertEqual(count, 0)
    }
    func testOutputLimitAndExpiredDeadlineAreEnforced() async throws {
        let (_, adapter, session, catalog) = try await setup()
        do { _ = try await adapter.execute(invocation(session, catalog, outputLimit: 1)) { _ in }; XCTFail("Oversized output accepted") }
        catch let error as HanlinHostError { XCTAssertEqual(error, .outputLimitExceeded) }
        do { _ = try await adapter.execute(invocation(session, catalog, deadline: .distantPast)) { _ in }; XCTFail("Expired request accepted") }
        catch let error as HanlinHostError { XCTAssertEqual(error, .deadlineExceeded) }
    }
    func testQueuedNavigationIsNotPresentedAndForeignReceiptIsRejected() async throws {
        let (fixture, adapter, session, _) = try await setup()
        let destination = HanlinHostDestination(context: session.context, objectReference: "native.history")
        let queued = try await adapter.open(destination)
        XCTAssertFalse(queued.presentationAcknowledged)
        await fixture.setWrongReceipt()
        do { _ = try await adapter.open(destination); XCTFail("Foreign receipt accepted") }
        catch let error as HanlinHostError { XCTAssertEqual(error, .resultMismatch) }
    }
    func testOpaqueNativeSceneIDIsNotReinterpretedAsSDKSceneUUID() async throws {
        let (_, adapter, session, _) = try await setup(nativeSceneID: "original-native-scene-owner")
        let result = try await adapter.open(.init(context: session.context, objectReference: "native.history"))
        // Exact same authority seam returns queued, never an invented UI receipt.
        XCTAssertFalse(result.presentationAcknowledged)
        guard case .queued(_, let context) = result else { return XCTFail("Unexpected presentation receipt") }
        XCTAssertEqual(context, session.context)
    }

    func testEmptyNativeForegroundIdentityIsDenied() async throws {
        let (_, adapter, session, _) = try await setup(nativeSceneID: "")
        do {
            _ = try await adapter.open(.init(context: session.context, objectReference: "native.history"))
            XCTFail("Empty native scene identity accepted")
        } catch let error as HanlinHostError { XCTAssertEqual(error, .denied) }
    }

    func testBackgroundNavigationIsDenied() async throws {
        let (_, adapter, session, _) = try await setup(foreground: false)
        do { _ = try await adapter.open(.init(context: session.context, objectReference: "native.history")); XCTFail("Background navigation accepted") }
        catch let error as HanlinHostError { XCTAssertEqual(error, .denied) }
    }
    func testAPI12TransitionReturnsLiveCorrelatedSuccessor() async throws {
        let (fixture, adapter, session, _) = try await setup()
        XCTAssertEqual(adapter.apiVersion.minor, 2)
        let destination = HanlinHostDestination(context: session.context, objectReference: "native.history")
        let receipt = try await adapter.openWithContextTransition(destination, session: session)
        try receipt.validate(for: destination, session: session)
        XCTAssertTrue(receipt.presentationAcknowledged)
        let successor = try XCTUnwrap(receipt.successorSession)
        XCTAssertNotEqual(successor.id, session.id)
        XCTAssertNotEqual(successor.context.generation, session.context.generation)
        let current = try await adapter.context(for: successor)
        XCTAssertEqual(current, successor.context)
        let count = await fixture.navigationCount; XCTAssertEqual(count, 1)
    }

    func testAPI12QueuedReceiptNeverIssuesSuccessorOrRepeats() async throws {
        let (fixture, adapter, session, _) = try await setup()
        await fixture.setQueuedTransition()
        let destination = HanlinHostDestination(context: session.context, objectReference: "native.history")
        let receipt = try await adapter.openWithContextTransition(destination, session: session)
        XCTAssertFalse(receipt.presentationAcknowledged)
        XCTAssertNil(receipt.successorSession)
        do { _ = try await adapter.openWithContextTransition(destination, session: session); XCTFail("Queued route repeated") }
        catch let error as HanlinHostError { XCTAssertEqual(error, .duplicateInvocation) }
        let count = await fixture.navigationCount; XCTAssertEqual(count, 1)
    }

    func testAPI12RejectsMismatchedNativeAcknowledgement() async throws {
        let (fixture, adapter, session, _) = try await setup()
        await fixture.setWrongReceipt()
        let destination = HanlinHostDestination(context: session.context, objectReference: "native.history")
        do { _ = try await adapter.openWithContextTransition(destination, session: session); XCTFail("Foreign acknowledgement escaped") }
        catch let error as HanlinHostError { XCTAssertEqual(error, .resultMismatch) }
        let retained = await adapter.navigationReceipt(for: destination.requestID, session: session)
        XCTAssertNil(retained)
    }

    func testAPI12RetainsReceiptWhenSuccessorWasRevoked() async throws {
        let (fixture, adapter, session, _) = try await setup()
        await fixture.setStaleSuccessor()
        let destination = HanlinHostDestination(context: session.context, objectReference: "native.history")
        do { _ = try await adapter.openWithContextTransition(destination, session: session); XCTFail("Stale successor escaped") }
        catch let error as HanlinHostError { XCTAssertEqual(error, .staleContext) }
        let retained = await adapter.navigationReceipt(for: destination.requestID, session: session)
        XCTAssertTrue(try XCTUnwrap(retained).presentationAcknowledged)
    }

    func testAPI12CancellationBeforeAuthorityReturnHasNoNativeEffect() async throws {
        let (fixture, adapter, session, _) = try await setup()
        let destination = HanlinHostDestination(context: session.context, objectReference: "native.history")
        await fixture.setAuthorityHold()
        let work = Task { try await adapter.openWithContextTransition(destination, session: session) }
        try await fixture.waitForAuthority(); work.cancel(); await fixture.releaseAuthority()
        do { _ = try await work.value; XCTFail("Cancelled navigation entered") }
        catch is CancellationError {}
        let count = await fixture.navigationCount; XCTAssertEqual(count, 0)
    }

    func testAPI12CancellationAfterEntryRetainsReceiptWithoutClaimingRollback() async throws {
        let (fixture, adapter, session, _) = try await setup()
        let destination = HanlinHostDestination(context: session.context, objectReference: "native.history")
        await fixture.setTransitionHold()
        let work = Task { try await adapter.openWithContextTransition(destination, session: session) }
        try await fixture.waitForTransition(); work.cancel(); await fixture.releaseTransition()
        do { _ = try await work.value; XCTFail("Cancelled result was delivered") }
        catch is CancellationError {}
        let retained = await adapter.navigationReceipt(for: destination.requestID, session: session)
        XCTAssertTrue(try XCTUnwrap(retained).presentationAcknowledged)
        let count = await fixture.navigationCount; XCTAssertEqual(count, 1)
    }

    func testAPI12DeniesBackgroundBeforeNativeEffect() async throws {
        let (fixture, adapter, session, _) = try await setup(foreground: false)
        let destination = HanlinHostDestination(context: session.context, objectReference: "native.history")
        do { _ = try await adapter.openWithContextTransition(destination, session: session); XCTFail("Background route entered") }
        catch let error as HanlinHostError { XCTAssertEqual(error, .denied) }
        let count = await fixture.navigationCount; XCTAssertEqual(count, 0)
    }

    func testSDKDispatcherAcceptsHostTransitionAndRetiresOriginalSession() async throws {
        let (fixture, adapter, session, _) = try await setup()
        let dispatcher = HanlinHostDispatcher(host: adapter)
        let destination = HanlinHostDestination(context: session.context, objectReference: "native.history")
        let receipt = try await dispatcher.openWithContextTransition(destination, session: session)
        let successor = try XCTUnwrap(receipt.successorSession)
        XCTAssertTrue(receipt.presentationAcknowledged)
        let current = try await adapter.context(for: successor)
        XCTAssertEqual(current, successor.context)
        do { _ = try await dispatcher.open(destination, session: session); XCTFail("Retired original session reused") }
        catch let error as HanlinHostError { XCTAssertEqual(error, .staleContext) }
        let retained = await dispatcher.navigationReceipts(for: session)
        XCTAssertEqual(retained, [receipt])
        let count = await fixture.navigationCount; XCTAssertEqual(count, 1)
    }

    func testSDKDispatcherDoesNotRepeatQueuedHostTransition() async throws {
        let (fixture, adapter, session, _) = try await setup()
        await fixture.setQueuedTransition()
        let dispatcher = HanlinHostDispatcher(host: adapter)
        let destination = HanlinHostDestination(context: session.context, objectReference: "native.history")
        let receipt = try await dispatcher.openWithContextTransition(destination, session: session)
        XCTAssertFalse(receipt.presentationAcknowledged)
        do { _ = try await dispatcher.openWithContextTransition(destination, session: session); XCTFail("Queued source click was repeated") }
        catch let error as HanlinHostError { XCTAssertEqual(error, .duplicateInvocation) }
        let count = await fixture.navigationCount; XCTAssertEqual(count, 1)
    }

    // The following tests execute the original Core, actual downstream issuer /
    // adapter, and where named the unmodified original SDK dispatcher. Backend
    // contents and native source observations are explicit fixture doubles.
    private func scopedSetup() async throws
        -> (Fixture, OtzariaHanlinHostAdapter, HanlinHostSession, HanlinHostCatalog, ActionExecutionContext) {
        let context = HanlinHostContext(namespace: try .init(app: "otzaria", account: "fixture-profile",
            workspace: "fixture-group", space: "otzaria"), sceneID: UUID(), generation: UUID(),
            objectReference: "fixture-original-reader", sourceRevision: "fixture-source-and-configuration")
        let metadata = ActionExecutionContext(subjectID: "fixture-native-owner", origin: .internalAI,
            allowedBackends: [.otzaria], scopes: [.discovery, .navigation], foregroundSceneID: "fixture-native-scene")
        let scope = try OtzariaHanlinCurrentWorkReadScope(workRef: .init(backend: .otzaria, workKey: "book:1"), title: "Fixture book")
        let binding = OtzariaHanlinBinding(context: context, executionContext: metadata,
            backend: .init(backend: .otzaria, generation: 73), catalogRevision: .init(73),
            availableReadActions: ["system.listBackends", "catalog.resolveWork", "catalog.resolveReference", "search.query"],
            searchExecutionContext: try scope.searchContext(from: metadata))
        let fixture = Fixture(binding: binding)
        await fixture.enableReadActions()
        let core = try ActionExecutor(state: fixture, resolver: fixture, search: fixture)
        let adapter = try OtzariaHanlinHostAdapter(core: core, authority: fixture)
        let session = HanlinHostSession(conversationID: UUID(), context: context)
        let catalog = try await adapter.catalog(for: context)
        await fixture.resetReads()
        return (fixture, adapter, session, catalog, metadata)
    }

    private var scopedQuery: String {
        #"{"backend":"otzaria","text":"fixture","scopeWorkRefs":[{"backend":"otzaria","workKey":"book:1"}],"limit":2}"#
    }

    private func completedAction(_ result: HanlinHostExecutionResult) throws -> ActionResult {
        guard case .completed(let blocks) = result.result.outcome, case .text(let value) = blocks.first else {
            XCTFail("Expected actual Core completion"); throw HanlinHostError.invalidRecord
        }
        return try JSONDecoder().decode(ActionResult.self, from: Data(value.utf8))
    }

    func testScopedReadIssuerRejectsUnknownBackendAndNoncanonicalWork() throws {
        for backend in [ActionBackendID.sefaria, .sefariaEmbedded] {
            XCTAssertThrowsError(try OtzariaHanlinCurrentWorkReadScope(workRef: .init(backend: backend, workKey: "book:1"), title: "Fixture"))
        }
        for key in ["book:0", "book:-1", "book:01", "book:1extra", "Genesis", ""] {
            XCTAssertThrowsError(try OtzariaHanlinCurrentWorkReadScope(workRef: .init(backend: .otzaria, workKey: key), title: "Fixture"))
        }
        XCTAssertThrowsError(try OtzariaHanlinCurrentWorkReadScope(workRef: .init(backend: .otzaria, workKey: "book:1", catalogRevision: "guessed"), title: "Fixture"))
        XCTAssertThrowsError(try OtzariaHanlinCurrentWorkReadScope(workRef: .init(backend: .otzaria, workKey: "book:1"), title: " "))
    }

    func testScopedReadIssuerKeepsMetadataContextAndBoundsOnlySearch() async throws {
        let (fixture, _, session, _, originalMetadata) = try await scopedSetup()
        let binding = try await fixture.current(for: session)
        XCTAssertEqual(binding.executionContext, originalMetadata)
        XCTAssertTrue(binding.executionContext.contentRights.isEmpty)
        XCTAssertNil(binding.executionContext.allowedWorkKeys)
        let read = try XCTUnwrap(binding.searchExecutionContext)
        XCTAssertEqual(read.contentRights, [.otzaria])
        XCTAssertEqual(read.allowedBackends, [.otzaria])
        XCTAssertEqual(read.allowedWorkKeys, [.otzaria: ["book:1"]])
        XCTAssertEqual(read.scopes, [.discovery, .contentRead])
        XCTAssertEqual(read.foregroundSceneID, originalMetadata.foregroundSceneID)
        XCTAssertEqual(read.maxActions, 20)
        XCTAssertEqual(read.maxResultBytes, 32_768)
    }

    func testScopedReadIssuerRejectsMissingForegroundOrForeignOrigin() throws {
        let scope = try OtzariaHanlinCurrentWorkReadScope(workRef: .init(backend: .otzaria, workKey: "book:1"), title: "Fixture")
        for context in [
            ActionExecutionContext(subjectID: "fixture", origin: .internalAI, allowedBackends: [.otzaria], scopes: [.discovery]),
            ActionExecutionContext(subjectID: "fixture", origin: .mcp, allowedBackends: [.otzaria], scopes: [.discovery], foregroundSceneID: "scene"),
            ActionExecutionContext(subjectID: "fixture", origin: .internalAI, allowedBackends: [.otzaria, .sefaria], scopes: [.discovery], foregroundSceneID: "scene")
        ] { XCTAssertThrowsError(try scope.searchContext(from: context)) }
    }

    func testAllowedScopedSearchExecutesOriginalCoreAndPreservesExactQuery() async throws {
        let (fixture, adapter, session, catalog, _) = try await scopedSetup()
        XCTAssertEqual(Set(catalog.tools.map { $0.route.logicalToolID.localToolID.rawValue }),
            ["system.list-backends", "catalog.resolve-work", "catalog.resolve-reference", "search.query"])
        let value = try await adapter.execute(invocation(session, catalog, raw: scopedQuery, toolID: "search.query")) { _ in }
        let result = try completedAction(value)
        XCTAssertEqual(result.action, "search.query")
        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(result.backendGeneration, 73)
        XCTAssertEqual(value.effectState, .confirmedNoEffect)
        let observed = await fixture.lastSearchQuery
        XCTAssertEqual(observed?.scopeWorkRefs, [.init(backend: .otzaria, workKey: "book:1")])
        XCTAssertEqual(observed?.limit, 2)
        let count = await fixture.searchReads; XCTAssertEqual(count, 1)
    }

    func testScopedSearchRejectsMissingAndBroaderScopeBeforeBackendRead() async throws {
        let (fixture, adapter, session, catalog, _) = try await scopedSetup()
        for raw in [
            #"{"backend":"otzaria","text":"fixture"}"#,
            #"{"backend":"otzaria","text":"fixture","scopeWorkRefs":[]}"#,
            #"{"backend":"otzaria","text":"fixture","scopeWorkRefs":[{"backend":"otzaria","workKey":"book:2"}]}"#,
            #"{"backend":"otzaria","text":"fixture","scopeWorkRefs":[{"backend":"otzaria","workKey":"book:1"},{"backend":"otzaria","workKey":"book:2"}]}"#
        ] {
            let value = try await adapter.execute(invocation(session, catalog, raw: raw, toolID: "search.query")) { _ in }
            guard case .failed = value.result.outcome else { return XCTFail("Out-of-scope search completed") }
        }
        let count = await fixture.searchReads; XCTAssertEqual(count, 0)
    }

    func testModelArgumentsCannotChooseContentContextOrBackend() async throws {
        let (fixture, adapter, session, catalog, _) = try await scopedSetup()
        for raw in [
            #"{"backend":"sefaria","text":"fixture","scopeWorkRefs":[{"backend":"sefaria","workKey":"book:1"}]}"#,
            #"{"backend":"otzaria","text":"fixture","scopeWorkRefs":[{"backend":"otzaria","workKey":"book:1"}],"contentRights":["otzaria"]}"#,
            #"{"backend":"otzaria","text":"fixture","scopeWorkRefs":[{"backend":"otzaria","workKey":"book:1"}],"searchExecutionContext":"unrestricted"}"#
        ] {
            let value = try await adapter.execute(invocation(session, catalog, raw: raw, toolID: "search.query")) { _ in }
            guard case .failed = value.result.outcome else { return XCTFail("Model supplied host authority") }
        }
        let count = await fixture.searchReads; XCTAssertEqual(count, 0)
    }

    func testRevokedReadGrantIsHiddenAndForcedOldToolCannotRead() async throws {
        let (fixture, adapter, session, oldCatalog, _) = try await scopedSetup()
        await fixture.removeSearchGrant()
        let current = try await adapter.catalog(for: session.context)
        XCTAssertEqual(Set(current.tools.map { $0.route.logicalToolID.localToolID.rawValue }),
            ["system.list-backends", "catalog.resolve-work", "catalog.resolve-reference"])
        let value = try await adapter.execute(invocation(session, oldCatalog, raw: scopedQuery, toolID: "search.query")) { _ in }
        guard case .failed = value.result.outcome else { return XCTFail("Removed read authority accepted an old descriptor") }
        let count = await fixture.searchReads; XCTAssertEqual(count, 0)
    }

    func testScopedSearchUsesActualCoreAvailabilityWithoutHidingOldMetadata() async throws {
        let (fixture, adapter, session, _, _) = try await scopedSetup()
        await fixture.setUnavailable(["search.query"])
        let current = try await adapter.catalog(for: session.context)
        XCTAssertEqual(Set(current.tools.map { $0.route.logicalToolID.localToolID.rawValue }),
            ["system.list-backends", "catalog.resolve-work", "catalog.resolve-reference"])
    }

    func testScopedReadDoesNotRestrictOriginalMetadataForAnotherWork() async throws {
        let (fixture, adapter, session, catalog, _) = try await scopedSetup()
        let requests: [(String, String)] = [
            ("system.list-backends", "{}"),
            ("catalog.resolve-work", #"{"backend":"otzaria","workRef":{"backend":"otzaria","workKey":"book:2"}}"#),
            ("catalog.resolve-reference", #"{"backend":"otzaria","workRef":{"backend":"otzaria","workKey":"book:2"},"section":"fixture"}"#)
        ]
        for (name, raw) in requests {
            let value = try await adapter.execute(invocation(session, catalog, raw: raw, toolID: name)) { _ in }
            XCTAssertEqual(try completedAction(value).status, .completed, name)
        }
        let metadata = await fixture.metadataReads; XCTAssertEqual(metadata, 2)
        let searches = await fixture.searchReads; XCTAssertEqual(searches, 0)
    }

    func testOriginalCoreRejectsBackendResponseOutsideAuthorizedWork() async throws {
        let (fixture, adapter, session, catalog, _) = try await scopedSetup()
        await fixture.setWrongSearchWork()
        let value = try await adapter.execute(invocation(session, catalog, raw: scopedQuery, toolID: "search.query")) { _ in }
        guard case .failed = value.result.outcome else { return XCTFail("Foreign work excerpt escaped") }
        XCTAssertFalse(String(decoding: try JSONEncoder().encode(value), as: UTF8.self).contains("FORBIDDEN_OTHER_WORK"))
        let count = await fixture.searchReads; XCTAssertEqual(count, 1)
    }

    func testGrantRevocationDuringSearchSuppressesEvenCompletedBackendResult() async throws {
        let (fixture, adapter, session, catalog, _) = try await scopedSetup()
        await fixture.setSearchHold()
        let call = try invocation(session, catalog, raw: scopedQuery, toolID: "search.query")
        let work = Task { try await adapter.execute(call) { _ in } }
        do { try await fixture.waitForSearch() }
        catch { work.cancel(); await fixture.releaseSearch(); throw error }
        await fixture.removeSearchGrant()
        await fixture.releaseSearch()
        do { _ = try await work.value; XCTFail("Revoked read result escaped") }
        catch let error as HanlinHostError { XCTAssertEqual(error, .staleContext) }
    }

    func testScopedSearchCancellationReachesOriginalCoreWorker() async throws {
        let (fixture, adapter, session, catalog, _) = try await scopedSetup()
        await fixture.setSearchHold()
        let call = try invocation(session, catalog, raw: scopedQuery, toolID: "search.query")
        let work = Task { try await adapter.execute(call) { _ in } }
        do { try await fixture.waitForSearch() }
        catch { work.cancel(); await fixture.releaseSearch(); throw error }
        await adapter.cancel(call.request.id)
        await fixture.releaseSearch()
        let value = try await work.value
        guard case .failed(let error) = value.result.outcome else { return XCTFail("Cancelled search completed") }
        XCTAssertEqual(error.code, .cancelled)
        let cancelled = await fixture.searchObservedCancellation; XCTAssertTrue(cancelled)
    }

    func testOriginalSDKDispatcherConsumesScopedSearchWithoutSDKChanges() async throws {
        let (fixture, adapter, session, catalog, _) = try await scopedSetup()
        let tool = try XCTUnwrap(catalog.tools.first { $0.route.logicalToolID.localToolID.rawValue == "search.query" })
        let dispatcher = HanlinHostDispatcher(host: adapter)
        let value = try await dispatcher.dispatch(alias: tool.route.alias, argumentsJSON: scopedQuery,
            providerCallID: "fixture-scoped-call", runID: UUID(), step: 0, session: session, catalog: catalog,
            limits: .init(maximumOutputBytes: 65_536))
        XCTAssertEqual(try completedAction(value).status, .completed)
        let count = await fixture.searchReads; XCTAssertEqual(count, 1)
    }

    func testOriginalSDKInvalidationCancelsAndSuppressesInFlightScopedRead() async throws {
        let (fixture, adapter, session, catalog, _) = try await scopedSetup()
        await fixture.setSearchHold()
        let tool = try XCTUnwrap(catalog.tools.first { $0.route.logicalToolID.localToolID.rawValue == "search.query" })
        let dispatcher = HanlinHostDispatcher(host: adapter)
        let query = scopedQuery
        let work = Task {
            try await dispatcher.dispatch(alias: tool.route.alias, argumentsJSON: query,
                providerCallID: "fixture-revoked-call", runID: UUID(), step: 0, session: session, catalog: catalog,
                limits: .init(maximumOutputBytes: 65_536))
        }
        do { try await fixture.waitForSearch() }
        catch { work.cancel(); await fixture.releaseSearch(); throw error }
        await fixture.revokeAuthority()
        await dispatcher.invalidate(session)
        await fixture.releaseSearch()
        do { _ = try await work.value; XCTFail("Retired SDK session exposed content") }
        catch let error as HanlinHostError { XCTAssertEqual(error, .staleContext) }
        let cancelled = await fixture.searchObservedCancellation; XCTAssertTrue(cancelled)
    }

    // Actual consent state uses the full native observation; this explicit
    // portable witness tests lifecycle without claiming UIKit/scene execution.
    private struct ConsentSource: Equatable {
        var backendGeneration = 7
        var rpcEpoch = 3
        var profile = "profile"
        var group = "group"
        var source = "original-source"
        var sourceRevision = 8
        var tab = "original-tab"
        var work = "book:1"
        var selection = "none"
    }

    @MainActor
    func testConsentConsumesOnlyOnceForExactDismissalSourceAndConfiguration() async throws {
        let context = HanlinHostContext(namespace: try .init(app: "otzaria", account: "fixture", workspace: "group", space: "otzaria"),
            sceneID: UUID(), generation: UUID())
        let session = HanlinHostSession(conversationID: UUID(), context: context)
        let scope = try OtzariaHanlinCurrentWorkReadScope(workRef: .init(backend: .otzaria, workKey: "book:1"), title: "Fixture")
        let id = UUID(), source = ConsentSource()
        let consent = OtzariaHanlinCurrentWorkReadConsent(session: session, scope: scope, configurationID: id, source: source)
        XCTAssertEqual(try consent.consume(dismissedSessionID: session.id, currentSource: source,
            namespace: context.namespace, configurationID: id), scope)
        XCTAssertThrowsError(try consent.consume(dismissedSessionID: session.id, currentSource: source,
            namespace: context.namespace, configurationID: id))
    }

    @MainActor
    func testConsentRejectsEveryChangedSourceDimensionWithoutGrant() async throws {
        let context = HanlinHostContext(namespace: try .init(app: "otzaria", account: "fixture", workspace: "group", space: "otzaria"),
            sceneID: UUID(), generation: UUID())
        let session = HanlinHostSession(conversationID: UUID(), context: context)
        let scope = try OtzariaHanlinCurrentWorkReadScope(workRef: .init(backend: .otzaria, workKey: "book:1"), title: "Fixture")
        let id = UUID(), source = ConsentSource()
        var changed: [ConsentSource] = []
        var v = source; v.backendGeneration += 1; changed.append(v)
        v = source; v.rpcEpoch += 1; changed.append(v)
        v = source; v.profile = "other"; changed.append(v)
        v = source; v.group = "other"; changed.append(v)
        v = source; v.source = "replacement"; changed.append(v)
        v = source; v.sourceRevision += 1; changed.append(v)
        v = source; v.tab = "other"; changed.append(v)
        v = source; v.work = "book:2"; changed.append(v)
        v = source; v.selection = "changed"; changed.append(v)
        for candidate in changed {
            let consent = OtzariaHanlinCurrentWorkReadConsent(session: session, scope: scope, configurationID: id, source: source)
            XCTAssertThrowsError(try consent.consume(dismissedSessionID: session.id, currentSource: candidate,
                namespace: context.namespace, configurationID: id))
            XCTAssertThrowsError(try consent.consume(dismissedSessionID: session.id, currentSource: source,
                namespace: context.namespace, configurationID: id), "Rejected witness must not become usable after a later source restoration")
        }
    }

    @MainActor
    func testConsentRejectsChangedConfigurationOrNamespaceAndRevocation() async throws {
        let context = HanlinHostContext(namespace: try .init(app: "otzaria", account: "fixture", workspace: "group", space: "otzaria"),
            sceneID: UUID(), generation: UUID())
        let session = HanlinHostSession(conversationID: UUID(), context: context)
        let scope = try OtzariaHanlinCurrentWorkReadScope(workRef: .init(backend: .otzaria, workKey: "book:1"), title: "Fixture")
        let id = UUID(), source = ConsentSource()
        let foreign = try HanlinConversationNamespace(app: "otzaria", account: "other-account", workspace: "group", space: "otzaria")
        for mode in 0..<3 {
            let consent = OtzariaHanlinCurrentWorkReadConsent(session: session, scope: scope, configurationID: id, source: source)
            if mode == 2 { consent.revoke() }
            XCTAssertThrowsError(try consent.consume(dismissedSessionID: session.id, currentSource: source,
                namespace: mode == 1 ? foreign : context.namespace, configurationID: mode == 0 ? UUID() : id))
        }
    }

    @MainActor
    func testSupersededDismissalCannotConsumeCurrentConsentEvenWhileDismissing() async throws {
        let context = HanlinHostContext(namespace: try .init(app: "otzaria", account: "fixture", workspace: "group", space: "otzaria"),
            sceneID: UUID(), generation: UUID())
        let current = HanlinHostSession(conversationID: UUID(), context: context)
        let scope = try OtzariaHanlinCurrentWorkReadScope(workRef: .init(backend: .otzaria, workKey: "book:1"), title: "Fixture")
        let id = UUID(), source = ConsentSource()
        let consent = OtzariaHanlinCurrentWorkReadConsent(session: current, scope: scope, configurationID: id, source: source)
        XCTAssertThrowsError(try consent.consume(dismissedSessionID: UUID(), currentSource: source,
            namespace: context.namespace, configurationID: id))
        XCTAssertEqual(try consent.consume(dismissedSessionID: current.id, currentSource: source,
            namespace: context.namespace, configurationID: id), scope)
    }

    func testSeparateReadContextWithoutContentRightsStaysClosed() async throws {
        let (fixture, adapter, session, oldCatalog, metadata) = try await scopedSetup()
        let denied = ActionExecutionContext(subjectID: metadata.subjectID, correlationID: metadata.correlationID,
            origin: .internalAI, allowedBackends: [.otzaria], contentRights: [], scopes: [.discovery, .contentRead],
            allowedWorkKeys: [.otzaria: ["book:1"]], foregroundSceneID: metadata.foregroundSceneID)
        await fixture.replaceSearchContext(denied)
        let current = try await adapter.catalog(for: session.context)
        XCTAssertEqual(current.tools.count, 3)
        XCTAssertFalse(current.tools.contains { $0.route.logicalToolID.localToolID.rawValue == "search.query" })
        let value = try await adapter.execute(invocation(session, oldCatalog, raw: scopedQuery, toolID: "search.query")) { _ in }
        guard case .failed(let error) = value.result.outcome else { return XCTFail("Missing content rights were inferred") }
        XCTAssertEqual(error.details, .object(["actionStatus": .string("failed"), "actionCode": .string("content_rights_required")]))
        let count = await fixture.searchReads; XCTAssertEqual(count, 0)
    }

    func testSeparateReadContextCannotBelongToAnotherSceneOrSubject() async throws {
        for foreignScene in [false, true] {
            let (fixture, adapter, session, _, metadata) = try await scopedSetup()
            let foreign = ActionExecutionContext(subjectID: foreignScene ? metadata.subjectID : "foreign-subject",
                correlationID: metadata.correlationID, origin: .internalAI, allowedBackends: [.otzaria],
                contentRights: [.otzaria], scopes: [.discovery, .contentRead], allowedWorkKeys: [.otzaria: ["book:1"]],
                foregroundSceneID: foreignScene ? "foreign-scene" : metadata.foregroundSceneID)
            await fixture.replaceSearchContext(foreign)
            do { _ = try await adapter.catalog(for: session.context); XCTFail("Foreign content context accepted") }
            catch let error as HanlinHostError { XCTAssertEqual(error, .denied) }
            let count = await fixture.searchReads; XCTAssertEqual(count, 0)
        }
    }

}
