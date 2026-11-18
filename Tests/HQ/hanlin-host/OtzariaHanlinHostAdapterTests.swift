import XCTest
import Foundation
import HanlinPlatformContracts
import HanlinHostContracts
import OtzariaActionCore
@testable import OtzariaHanlinHostAdapter

private actor Fixture: ActionBackendStatePort, ActionResolverPort, ActionSearchPort, OtzariaHanlinHostAuthority {
    var binding: OtzariaHanlinBinding
    var reads = 0
    var unavailableActions = Set<String>()
    var hold = false
    var entered = false
    var blocked: CheckedContinuation<Void, Never>?
    var wrongReceipt = false
    var holdAuthority = false
    var authorityEntered = false
    var authorityBlocked: CheckedContinuation<Void, Never>?
    init(binding: OtzariaHanlinBinding) { self.binding = binding }
    func current(for session: HanlinHostSession) async throws -> OtzariaHanlinBinding {
        if holdAuthority {
            holdAuthority = false; authorityEntered = true
            await withCheckedContinuation { authorityBlocked = $0 }
        }
        return binding
    }
    func current(for context: HanlinHostContext) async throws -> OtzariaHanlinBinding { binding }
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
    func resolveWork(_ query: ActionResolveWorkQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionWorkRef> { throw ActionPortError.unavailable }
    func resolveReference(_ query: ActionResolveReferenceQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionTextRef> { throw ActionPortError.unavailable }
    func validateDestination(_ destination: ActionReaderDestination, invocation: ActionPortInvocation) async throws -> ActionReaderDestination { throw ActionPortError.unavailable }
    func search(_ query: ActionSearchQuery, invocation: ActionPortInvocation) async throws -> ActionSearchPage { throw ActionPortError.unavailable }
    func open(_ destination: HanlinHostDestination, binding: OtzariaHanlinBinding) async throws -> HanlinHostNavigationResult {
        if wrongReceipt { return .presented(requestID: UUID(), context: destination.context,
            objectReference: destination.objectReference, blockReference: destination.blockReference) }
        return .queued(requestID: destination.requestID, context: destination.context)
    }
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
            catalogRevision: binding.catalogRevision, availableReadActions: binding.availableReadActions)
    }
}

// The XCTest instance has no stored mutable test state; every fixture is an actor.
// No UI/main-thread work occurs in this portable contract suite.
final class OtzariaHanlinHostAdapterTests: XCTestCase, @unchecked Sendable {
    private func setup(rights: Bool = true, foreground: Bool = true, nativeSceneID: String? = nil) async throws
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
            catalogRevision: .init(7), availableReadActions: ActionRegistry.implemented.union(["notes.save"]))
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
                            deadline: Date? = nil) throws -> HanlinHostInvocation {
        let tool = try XCTUnwrap(catalog.tools.first { $0.route.logicalToolID.localToolID.rawValue == "system.list-backends" })
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
}
