import Foundation
import XCTest
@testable import OtzariaActionCore

// Portable source/editor fixtures only; these tests are not Native UI evidence.
@MainActor private final class NoteEditorFixture: ActionNoteDraftUICommandSink {
    let source: MockPorts
    let locator: ActionTextRef
    var sourceText = "לפני בחירה אחרי"
    var range = NSRange(location: 5, length: 5)
    var available = true
    var changedOnPrepare = false
    var changedOnPresent = false
    var invalidCompletion = false
    var failure: ActionPortError?
    var receiptMutation = 0
    var queueHandle: String?
    var prepared: ActionNoteDraftRequest?
    var commands: [ActionPrepareNoteDraftCommand] = []
    var preparations = 0
    var completions = 0
    init(_ source: MockPorts, backend: ActionBackendID = .otzaria) {
        self.source = source
        locator = .init(backend: backend, workKey: "fixture:work",
            position: backend == .otzaria ? .legacyLine(42) : .canonicalRef("Fixture 1:1"))
    }
    func canPrepareNoteDraft(in sceneID: String) -> Bool { available && sceneID == "fixture-scene" }
    func prepareNoteDraft(_ draft: ActionNoteDraftRequest, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws {
        preparations += 1
        if let failure { throw failure }
        _ = try ActionNoteDraftSelection.validate(draft, observedLocator: locator, sourceText: sourceText, originalRange: range)
        prepared = draft
        if changedOnPrepare { await source.bumpGeneration() }
    }
    func presentNoteDraft(_ command: ActionPrepareNoteDraftCommand) async throws -> ActionNoteDraftAcknowledgement {
        guard prepared == command.draft else { throw ActionPortError.invalidResponse }
        commands.append(command)
        if let queueHandle { return .queued(handle: queueHandle) }
        if changedOnPresent { await source.bumpGeneration() }
        let draft = receiptMutation == 4
            ? ActionNoteDraftRequest(locator: locator, selectedText: command.draft.selectedText, proposedText: "substituted")
            : command.draft
        return .acknowledged(.init(requestId: receiptMutation == 1 ? UUID() : command.invocation.requestId,
            snapshot: receiptMutation == 2 ? .init(backend: locator.backend, generation: 999) : command.invocation.snapshot,
            sceneID: receiptMutation == 3 ? "foreign-scene" : command.sceneID,
            draft: draft, isUnsaved: receiptMutation != 5))
    }
    func validateNoteDraftCompletion(_ receipt: ActionNoteDraftReceipt, invocation: ActionPortInvocation) throws {
        completions += 1
        guard !invalidCompletion, receipt.draft == prepared else { throw ActionPortError.staleState }
    }
    func open(_ command: ActionOpenReaderCommand) async throws -> ActionUIAcknowledgement { throw ActionPortError.notSupported }
}

@MainActor final class NoteDraftActionTests: XCTestCase, @unchecked Sendable {
    private func context(_ backend: ActionBackendID = .otzaria, scene: String? = "fixture-scene",
                         scopes: Set<ActionScope> = [.discovery, .navigation], works: Set<String>? = nil) -> ActionExecutionContext {
        .init(subjectID: "note-contract-fixture", origin: .inApp, allowedBackends: [backend], contentRights: [],
              scopes: scopes, allowedWorkKeys: works.map { [backend: $0] }, foregroundSceneID: scene)
    }
    private func request(_ editor: NoteEditorFixture, selected: String? = "בחירה", proposed: String? = "הצעה מקורית",
                         headless: Bool = false, id: UUID = UUID()) throws -> ActionRequest {
        var args: ActionObject = ["locator": try .encoded(editor.locator)]
        if let selected { args["selectedText"] = .string(selected) }
        if let proposed { args["proposedText"] = .string(proposed) }
        return .init(requestId: id, action: "notes.prepareDraft", arguments: args,
            expectedBackend: editor.locator.backend, requestedPresentation: headless ? .headless : .foreground)
    }
    private func executor(_ source: MockPorts, _ ui: (any ActionUICommandSink)?) throws -> ActionExecutor {
        try .init(state: source, resolver: source, search: source, ui: ui)
    }
    func testExactDraftAcrossSourcesReturnsUnsavedReceiptWithoutExportingText() async throws {
        for backend in ActionBackendID.allCases {
            let source = MockPorts(backend: backend), editor = NoteEditorFixture(source, backend: backend)
            let result = await (try executor(source, editor)).execute(try request(editor), context: context(backend))
            XCTAssertEqual(result.status, .completed, "\(backend): \(String(describing: result.error))")
            XCTAssertEqual(result.effects, ["note_draft_opened"])
            XCTAssertEqual(result.data?["saved"], .bool(false))
            XCTAssertEqual(result.data?["locator"], try .encoded(editor.locator))
            XCTAssertEqual(editor.commands.count, 1); XCTAssertEqual(editor.completions, 1)
            XCTAssertEqual(editor.commands.first?.draft.proposedText, "הצעה מקורית")
            let output = String(decoding: try ActionWireCodec.encodeResult(result), as: UTF8.self)
            XCTAssertFalse(output.contains("הצעה מקורית")); XCTAssertFalse(output.contains("בחירה"))
            let counts = await source.counts()
            XCTAssertEqual(counts.search, 0, "Preparing a note must not run any search")
        }
    }
    func testMissingProposalCreatesOnlyBlankEditableDraft() async throws {
        let source = MockPorts(), editor = NoteEditorFixture(source)
        let result = await (try executor(source, editor)).execute(try request(editor, selected: nil, proposed: nil), context: context())
        XCTAssertEqual(result.status, .completed); XCTAssertNil(editor.commands.first?.draft.proposedText)
        XCTAssertNil(editor.commands.first?.draft.selectedText)
    }
    func testMissingOriginalEditorIsNotAdvertisedOrExecuted() async throws {
        let source = MockPorts(), editor = NoteEditorFixture(source)
        let core = try executor(source, MockUI(ports: source))
        let result = await core.execute(try request(editor), context: context())
        XCTAssertEqual(result.status, .notSupported); XCTAssertEqual(result.error?.code, "note_draft_editor_unavailable")
        let counts = await source.counts(); XCTAssertEqual(counts.resolution, 0)
        let discovery = await core.execute(.init(action: "system.listBackends", arguments: ["includeReadiness": .bool(true)]), context: context())
        let active = discovery.data?["backends"]?.array?.first { $0.object?["id"] == .string("otzaria") }
        XCTAssertEqual(active?.object?["operations"]?.object?["notes.prepareDraft"]?.object?["supported"], .bool(false))
    }
    func testSelectionReadinessIsTruthfulAndUnavailableDoesNotResolveOrPresent() async throws {
        let source = MockPorts(), editor = NoteEditorFixture(source); editor.available = false
        let core = try executor(source, editor)
        let result = await core.execute(try request(editor), context: context())
        XCTAssertEqual(result.status, .unavailable); XCTAssertEqual(editor.preparations, 0); XCTAssertTrue(editor.commands.isEmpty)
        let discovery = await core.execute(.init(action: "system.listBackends", arguments: ["includeReadiness": .bool(true)]), context: context())
        let active = discovery.data?["backends"]?.array?.first { $0.object?["id"] == .string("otzaria") }
        let note = active?.object?["operations"]?.object?["notes.prepareDraft"]?.object
        XCTAssertEqual(note?["supported"], .bool(true)); XCTAssertEqual(note?["availableNow"], .bool(false))
        XCTAssertEqual(note?["reasonCode"], .string("exact_note_selection_unavailable"))
    }
    func testHeadlessMissingSceneAndScopeCannotPresentDraft() async throws {
        for mode in 0..<3 {
            let source = MockPorts(), editor = NoteEditorFixture(source)
            let ctx = context(scene: mode == 1 ? nil : "fixture-scene", scopes: mode == 2 ? [.discovery] : [.discovery, .navigation])
            let result = await (try executor(source, editor)).execute(try request(editor, headless: mode == 0), context: ctx)
            XCTAssertNotEqual(result.status, .completed); XCTAssertTrue(editor.commands.isEmpty); XCTAssertEqual(editor.preparations, 0)
        }
    }
    func testWorkPolicyRejectsBeforeSelectionOrPresentation() async throws {
        let source = MockPorts(), editor = NoteEditorFixture(source)
        let result = await (try executor(source, editor)).execute(try request(editor), context: context(works: ["fixture:other"]))
        XCTAssertNotEqual(result.status, .completed); XCTAssertEqual(editor.preparations, 0)
    }
    func testUnverifiedLocatorFailsBeforeEditorPreparation() async throws {
        let source = MockPorts(), editor = NoteEditorFixture(source)
        let foreign = ActionTextRef(backend: .otzaria, workKey: "fixture:unknown", position: .legacyLine(42))
        let req = ActionRequest(action: "notes.prepareDraft", arguments: ["locator": try .encoded(foreign)], expectedBackend: .otzaria)
        let result = await (try executor(source, editor)).execute(req, context: context())
        XCTAssertEqual(result.status, .failed); XCTAssertEqual(editor.preparations, 0)
    }
    func testSelectedTextCannotSubstituteOriginalSelection() async throws {
        let source = MockPorts(), editor = NoteEditorFixture(source)
        let result = await (try executor(source, editor)).execute(try request(editor, selected: "invented"), context: context())
        XCTAssertEqual(result.status, .staleState); XCTAssertTrue(editor.commands.isEmpty)
    }
    func testGenerationChangeDuringPreparationPreventsPresentation() async throws {
        let source = MockPorts(), editor = NoteEditorFixture(source); editor.changedOnPrepare = true
        let result = await (try executor(source, editor)).execute(try request(editor), context: context())
        XCTAssertEqual(result.status, .staleState); XCTAssertTrue(editor.commands.isEmpty)
    }
    func testGenerationChangeAfterActualEffectDoesNotClaimCompletion() async throws {
        let source = MockPorts(), editor = NoteEditorFixture(source); editor.changedOnPresent = true
        let result = await (try executor(source, editor)).execute(try request(editor), context: context())
        XCTAssertEqual(result.status, .staleState); XCTAssertEqual(editor.commands.count, 1)
    }
    func testFinalSourceOrVisibilityLossRefusesCompletion() async throws {
        let source = MockPorts(), editor = NoteEditorFixture(source); editor.invalidCompletion = true
        let result = await (try executor(source, editor)).execute(try request(editor), context: context())
        XCTAssertEqual(result.status, .staleState); XCTAssertEqual(editor.commands.count, 1); XCTAssertEqual(editor.completions, 1)
    }
    func testReceiptRequiresExactRequestSnapshotSceneDraftAndUnsavedState() async throws {
        for mutation in 1...5 {
            let source = MockPorts(), editor = NoteEditorFixture(source); editor.receiptMutation = mutation
            let result = await (try executor(source, editor)).execute(try request(editor), context: context())
            XCTAssertEqual(result.status, .failed, "Mutation \(mutation)"); XCTAssertEqual(result.error?.code, "native_effect_uncertain"); XCTAssertEqual(result.error?.retryable, false)
            XCTAssertEqual(editor.completions, 0)
        }
    }
    func testQueueIsNotSuccessfulPresentationAndHandleIsBounded() async throws {
        for (handle, expected) in [("fixture-queue-01", ActionStatus.uiQueued), ("arbitrary/unsafe", .failed)] {
            let source = MockPorts(), editor = NoteEditorFixture(source); editor.queueHandle = handle
            let result = await (try executor(source, editor)).execute(try request(editor), context: context())
            XCTAssertEqual(result.status, expected); XCTAssertEqual(editor.completions, 0)
        }
    }
    func testSameRequestIsIdempotentAndChangedProposalConflicts() async throws {
        let source = MockPorts(), editor = NoteEditorFixture(source), core = try executor(source, editor)
        let ctx = context(), req = try request(editor)
        let first = await core.execute(req, context: ctx), replay = await core.execute(req, context: ctx)
        XCTAssertEqual(first, replay); XCTAssertEqual(editor.commands.count, 1)
        let changed = await core.execute(try request(editor, proposed: "different", id: req.requestId), context: ctx)
        XCTAssertEqual(changed.error?.code, "request_replay_conflict"); XCTAssertEqual(editor.commands.count, 1)
    }
    func testProposalBoundsRejectBeforeAnyEditorOrResolverCall() async throws {
        let source = MockPorts(), editor = NoteEditorFixture(source)
        let result = await (try executor(source, editor)).execute(try request(editor, proposed: String(repeating: "a", count: 10_001)), context: context())
        XCTAssertEqual(result.status, .failed); XCTAssertEqual(editor.preparations, 0)
        let counts = await source.counts(); XCTAssertEqual(counts.resolution, 0)
    }
    func testOriginalUTF16RangeAndExactUnicodeAreRequired() throws {
        let ref = ActionTextRef(backend: .otzaria, workKey: "fixture:work", position: .legacyLine(42))
        let text = "אב e\u{301} 😀 סוף", wanted = "e\u{301} 😀"
        let valid = (text as NSString).range(of: wanted)
        XCTAssertEqual(try ActionNoteDraftSelection.validate(.init(locator: ref, selectedText: wanted), observedLocator: ref,
            sourceText: text, originalRange: valid), wanted)
        XCTAssertThrowsError(try ActionNoteDraftSelection.validate(.init(locator: ref, selectedText: "é 😀"), observedLocator: ref,
            sourceText: text, originalRange: valid), "Canonical-equivalent text must not substitute different original bytes")
        let other = ActionTextRef(backend: .otzaria, workKey: "fixture:work", position: .legacyLine(43))
        XCTAssertThrowsError(try ActionNoteDraftSelection.validate(.init(locator: other), observedLocator: ref, sourceText: text, originalRange: valid))
        XCTAssertNotEqual(ActionNoteDraftRequest(locator: ref, proposedText: "é"), .init(locator: ref, proposedText: "e\u{301}"))
    }
    func testInvalidMissingOversizedOrSplitUTF16SelectionCannotGuessFallback() throws {
        let ref = ActionTextRef(backend: .otzaria, workKey: "fixture:work", position: .legacyLine(42)), text = "😀abc"
        for range in [NSRange(location: NSNotFound, length: 1), .init(location: -1, length: 1), .init(location: 0, length: 0),
                      .init(location: 100, length: 1), .init(location: Int.max - 1, length: 8),
                      .init(location: 1, length: 1), .init(location: 0, length: 1)] {
            XCTAssertThrowsError(try ActionNoteDraftSelection.validate(.init(locator: ref), observedLocator: ref, sourceText: text, originalRange: range))
        }
        let large = String(repeating: "a", count: 10_001)
        XCTAssertThrowsError(try ActionNoteDraftSelection.validate(.init(locator: ref), observedLocator: ref, sourceText: large,
            originalRange: NSRange(location: 0, length: large.utf16.count)))
    }
}
