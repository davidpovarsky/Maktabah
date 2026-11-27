import Foundation
import OtzariaActionCore
import OtzariaUIRouting

/// Two explicit system actions over the original catalog and native Core
/// routes. A book/location entity is source metadata, never an execution grant.
/// The existing combined book/commentary/draft intent keeps its own contract.
@MainActor public final class NativeReaderToolIntentService {
    public enum Operation: Sendable, Equatable {
        case commentary(ActionWorkRef)
        case noteDraft(String?)

        public var action: String {
            switch self {
            case .commentary: "reader.openCommentary"
            case .noteDraft: "notes.prepareDraft"
            }
        }
    }

    public struct Start: Sendable {
        public let locator: ActionTextRef
        public let operation: Operation
        public let windowIdentifier: String
        public let invocation: ActionPortInvocation
    }

    public struct Request: Sendable {
        public let start: Start
        public let resolved: NativeReaderIntentService.OpenRequest

        public func arguments() throws -> ActionObject {
            switch start.operation {
            case .commentary(let work):
                return ["baseLocator": try .encoded(start.locator), "workRef": try .encoded(work)]
            case .noteDraft(let proposal):
                var values: ActionObject = ["locator": try .encoded(start.locator)]
                if let proposal { values["proposedText"] = .string(proposal) }
                return values
            }
        }
    }

    /// The real Core return and the actually observed native receipt are kept
    /// separately. A partial native effect is retained even when Core refuses.
    public struct Execution: Sendable {
        public let request: ActionRequest
        public let result: ActionResult
        public let nativeReceipt: UISceneReceipt?
        public init(request: ActionRequest, result: ActionResult, nativeReceipt: UISceneReceipt?) {
            self.request = request; self.result = result; self.nativeReceipt = nativeReceipt
        }
    }

    public struct Failure: Error, LocalizedError, Sendable {
        public let execution: Execution
        public let status: ActionStatus
        public let code: String
        public init(execution: Execution, underlying: any Error) {
            self.execution = execution
            if let route = underlying as? UIRouteError { status = route.status; code = route.code }
            else if underlying is CancellationError { status = .cancelled; code = "cancelled" }
            else { status = .failed; code = "native_effect_uncertain" }
        }
        public var errorDescription: String? {
            NativeIntentOutcome(status: status, code: code).errorDescription
        }
    }

    /// A private in-process source lease, supplied only by the original scene
    /// owner before any metadata await. It grants no Core/UI permission and has
    /// no Codable or URL representation. One execution consumes it permanently.
    @MainActor public final class RetainedWindow {
        public let sceneID: UIStableID
        private let check: @MainActor @Sendable () throws -> Void
        private let execute: @MainActor @Sendable (Request) async throws -> Execution
        private let cleanup: @MainActor @Sendable () -> Void
        private enum Phase { case retained, executing, finished, released }
        private var phase = Phase.retained

        public init(sceneID: UIStableID,
                    validate: @escaping @MainActor @Sendable () throws -> Void,
                    execute: @escaping @MainActor @Sendable (Request) async throws -> Execution,
                    release: @escaping @MainActor @Sendable () -> Void) {
            self.sceneID = sceneID; check = validate; self.execute = execute; cleanup = release
        }
        func validate() throws {
            guard case .retained = phase else { throw UIRouteError(.staleState, "reader_tool_source_consumed") }
            try check()
            guard case .retained = phase else { throw UIRouteError(.staleState, "reader_tool_source_consumed") }
        }
        func perform(_ request: Request) async throws -> Execution {
            try validate()
            phase = .executing
            do {
                let result = try await execute(request)
                guard case .executing = phase else {
                    throw Failure(execution: result,
                        underlying: UIRouteError(.staleState, "reader_tool_source_consumed"))
                }
                phase = .finished
                return result
            } catch {
                if case .executing = phase { phase = .finished }
                throw error
            }
        }
        func release() {
            if case .released = phase { return }
            phase = .released
            cleanup()
        }
        isolated deinit { if case .released = phase {} else { cleanup() } }
    }

    public typealias Snapshot = @MainActor @Sendable () throws -> ActionBackendSnapshot
    public typealias Retain = @MainActor @Sendable (Start) throws -> RetainedWindow
    private let snapshot: Snapshot
    private let executeMetadata: NativeReaderIntentService.Execute
    private let retain: Retain
    private let now: @MainActor @Sendable () -> UInt64
    @MainActor private final class ObservedExecution { var actual: Execution? }

    public init(snapshot: @escaping Snapshot, execute: @escaping NativeReaderIntentService.Execute,
                retain: @escaping Retain,
                now: @escaping @MainActor @Sendable () -> UInt64 = { DispatchTime.now().uptimeNanoseconds }) {
        self.snapshot = snapshot; executeMetadata = execute; self.retain = retain; self.now = now
    }

    public func openCommentary(workIdentifier: String, locationIdentifier: String,
                               commentaryWorkIdentifier: String, windowIdentifier: String) async throws -> Execution {
        let work: ActionWorkRef = try NativeReaderEntityIdentifier.decode(commentaryWorkIdentifier, prefix: "maktabah.work.v1.")
        return try await open(workIdentifier: workIdentifier, locationIdentifier: locationIdentifier,
            windowIdentifier: windowIdentifier, operation: .commentary(work))
    }

    public func prepareDraft(workIdentifier: String, locationIdentifier: String,
                             windowIdentifier: String, proposedText: String?) async throws -> Execution {
        if let proposedText {
            guard proposedText.unicodeScalars.count <= 10_000, proposedText.utf8.count <= 40_000 else {
                throw UIRouteError(.failed, "invalid_intent_note_proposal")
            }
        }
        return try await open(workIdentifier: workIdentifier, locationIdentifier: locationIdentifier,
            windowIdentifier: windowIdentifier, operation: .noteDraft(proposedText))
    }

    private func open(workIdentifier: String, locationIdentifier: String,
                      windowIdentifier: String, operation: Operation) async throws -> Execution {
        try Task.checkCancellation()
        let (end, overflow) = now().addingReportingOverflow(5_000_000_000)
        guard !overflow else { throw UIRouteError(.unavailable, "deadline_exceeded") }
        guard !windowIdentifier.isEmpty, windowIdentifier.utf8.count <= 512 else {
            throw UIRouteError(.failed, "invalid_intent_window")
        }
        let work: ActionWorkRef = try NativeReaderEntityIdentifier.decode(workIdentifier, prefix: "maktabah.work.v1.")
        let locator: ActionTextRef = try NativeReaderEntityIdentifier.decode(locationIdentifier, prefix: "maktabah.location.v1.")
        guard work.backend == locator.backend, work.workKey == locator.workKey,
              work.catalogRevision == locator.catalogRevision else {
            throw UIRouteError(.failed, "intent_work_location_mismatch")
        }
        if case .commentary(let commentary) = operation, commentary.backend != work.backend {
            throw UIRouteError(.failed, "intent_commentary_backend_mismatch")
        }
        let expected = try snapshot()
        guard expected.backend == locator.backend else {
            throw UIRouteError(.requiresBackendSwitch, "reader_tool_backend_mismatch")
        }
        let start = Start(locator: locator, operation: operation, windowIdentifier: windowIdentifier,
            invocation: .init(requestId: UUID(), snapshot: expected, deadlineUptimeNanoseconds: end))
        let window = try retain(start)
        defer { window.release() }
        try validate(start, window: window)
        let observed = ObservedExecution()

        // Reuse the original entity parser, exact work/location relationship and
        // Core-backed cached-location re-resolution. Only its typed callback is
        // different; this does not open a base Reader as a hidden first action.
        let original = NativeReaderIntentService(execute: { [self, window] request in
            try validate(start, window: window)
            let remaining = try remainingMilliseconds(end)
            let bounded = ActionRequest(apiVersion: request.apiVersion, requestId: request.requestId,
                action: request.action, arguments: request.arguments, expectedBackend: request.expectedBackend,
                expectedGeneration: request.expectedGeneration, idempotencyKey: request.idempotencyKey,
                requestedPresentation: request.requestedPresentation,
                deadlineMs: min(request.deadlineMs ?? remaining, remaining))
            let response = try await executeMetadata(bounded)
            try validate(start, window: window)
            guard response.snapshot == expected else { throw UIRouteError(.staleState, "reader_tool_source_changed") }
            return response
        }, navigate: { [self, window, observed] resolved in
            try validate(start, window: window)
            guard resolved.locator == locator, resolved.expectedSnapshot == expected,
                  resolved.windowIdentifier == windowIdentifier, resolved.newTab,
                  resolved.commentaryDraft == nil else { throw UIRouteError(.staleState, "reader_tool_metadata_changed") }
            let request = Request(start: start, resolved: resolved)
            let actual = try await window.perform(request)
            observed.actual = actual
            // Capture first. A wrong/late/partial return is never discarded by
            // the following checks or promoted to a successful native result.
            let receipt = try qualify(actual, request: request, sceneID: window.sceneID)
            return .acknowledged(receipt)
        })
        do {
            if case .commentary(let commentary) = operation {
                let identifier = try NativeReaderEntityIdentifier.encode(commentary, prefix: "maktabah.work.v1.")
                let matches = try await original.works(identifiers: [identifier])
                guard matches.count == 1, matches[0].reference == commentary else {
                    throw UIRouteError(.staleState, "intent_commentary_no_longer_available")
                }
            }
            _ = try await original.open(workIdentifier: workIdentifier, locationIdentifier: locationIdentifier,
                windowIdentifier: windowIdentifier, newTab: true)
            guard let actual = observed.actual else { throw UIRouteError(.failed, "reader_tool_missing_execution") }
            try Task.checkCancellation()
            guard try snapshot() == expected, now() < end else {
                throw UIRouteError(.staleState, "reader_tool_completion_changed")
            }
            return actual
        } catch let failure as Failure { throw failure }
        catch {
            if let actual = observed.actual { throw Failure(execution: actual, underlying: error) }
            throw error
        }
    }

    private func validate(_ start: Start, window: RetainedWindow) throws {
        try Task.checkCancellation()
        guard now() < start.invocation.deadlineUptimeNanoseconds, try snapshot() == start.invocation.snapshot else {
            throw UIRouteError(.staleState, "reader_tool_source_changed")
        }
        try window.validate()
        try Task.checkCancellation()
        guard now() < start.invocation.deadlineUptimeNanoseconds, try snapshot() == start.invocation.snapshot else {
            throw UIRouteError(.staleState, "reader_tool_source_changed")
        }
    }

    private func remainingMilliseconds(_ end: UInt64) throws -> Int {
        let current = now()
        guard current < end else { throw UIRouteError(.unavailable, "deadline_exceeded") }
        let milliseconds = (end - current) / 1_000_000
        guard milliseconds > 0 else { throw UIRouteError(.unavailable, "deadline_exceeded") }
        return Int(min(milliseconds, 5_000))
    }

    private func qualify(_ actual: Execution, request: Request, sceneID: UIStableID) throws -> UISceneReceipt {
        let start = request.start, invocation = start.invocation, sent = actual.request, result = actual.result
        try Task.checkCancellation()
        guard now() < invocation.deadlineUptimeNanoseconds, try snapshot() == invocation.snapshot else {
            throw UIRouteError(.staleState, "reader_tool_completion_changed")
        }
        guard sent.apiVersion == 1, sent.requestId == invocation.requestId, sent.action == start.operation.action,
              sent.expectedBackend == invocation.snapshot.backend, sent.expectedGeneration == invocation.snapshot.generation,
              sent.requestedPresentation == .foreground, sent.idempotencyKey == nil,
              let budget = sent.deadlineMs, (1...5_000).contains(budget), sent.arguments == (try request.arguments()),
              result.apiVersion == 1, result.requestId == sent.requestId, result.action == sent.action,
              result.backend == invocation.snapshot.backend, result.backendGeneration == invocation.snapshot.generation else {
            throw UIRouteError(.failed, "native_effect_uncertain")
        }
        guard result.status == .completed else {
            throw UIRouteError(result.status, result.error?.code ?? "reader_tool_not_completed")
        }
        guard let receipt = actual.nativeReceipt,
              receipt.requestId == invocation.requestId, receipt.backendSnapshot == invocation.snapshot,
              receipt.sceneID == sceneID, receipt.route.version == 1, receipt.route.requestId == receipt.requestId,
              receipt.route.backend == invocation.snapshot.backend, receipt.route.expectedBackendSnapshot == invocation.snapshot,
              receipt.route.scene.kind == .specific, receipt.route.scene.sceneID == sceneID,
              receipt.route.scene.expectedRevision == receipt.basedOnSceneRevision,
              receipt.appliedSceneRevision > receipt.basedOnSceneRevision else {
            throw UIRouteError(.failed, "native_effect_uncertain")
        }
        switch start.operation {
        case .commentary(let work):
            let effectiveLocator = receipt.coreReceipt.map {
                $0.destination.focusLocator ?? $0.destination.sectionLocator
            }
            guard let native = receipt.coreReceipt,
                  receipt.route.destination.rawValue == "native.reader", receipt.route.presentation.kind == .newTab,
                  native.requestId == receipt.requestId, native.snapshot == invocation.snapshot,
                  native.sceneID == sceneID.rawValue, native.destination.presentationMode == .newTab,
                  receipt.route.content == native.destination,
                  native.destination.sectionLocator.backend == work.backend,
                  native.destination.sectionLocator.workKey == work.workKey,
                  native.destination.sectionLocator.catalogRevision == work.catalogRevision,
                  effectiveLocator?.backend == work.backend,
                  effectiveLocator?.workKey == work.workKey,
                  effectiveLocator?.catalogRevision == work.catalogRevision,
                  try result.data?["destination"]?.decoded(as: ActionReaderDestination.self) == native.destination,
                  try result.data?["locator"]?.decoded(as: ActionTextRef.self)
                    == effectiveLocator else {
                throw UIRouteError(.failed, "native_effect_uncertain")
            }
        case .noteDraft(let proposal):
            guard ActionNoteDraftRequest(locator: start.locator, proposedText: proposal)
                    == ActionNoteDraftRequest(locator: start.locator, proposedText: sent.arguments["proposedText"]?.string),
                  receipt.route.destination.rawValue == "native.reader.noteDraft",
                  receipt.route.presentation.kind == .sheet, receipt.coreReceipt == nil,
                  receipt.route.content == nil, receipt.route.focus == nil,
                  try result.data?["locator"]?.decoded(as: ActionTextRef.self) == start.locator,
                  result.data?["saved"] == .bool(false) else {
                throw UIRouteError(.failed, "native_effect_uncertain")
            }
        }
        return receipt
    }
}
