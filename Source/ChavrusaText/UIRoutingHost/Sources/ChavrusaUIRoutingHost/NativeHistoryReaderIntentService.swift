import Foundation
import OtzariaActionCore
import OtzariaUIRouting

/// Resume an actual original history position. The separate record-reveal
/// service keeps its existing card-only meaning. These UUIDs are live metadata,
/// never a serialized locator, scene, permission or navigation grant.
@MainActor public final class NativeHistoryReaderIntentService {
    public struct Reference: Sendable, Equatable, Hashable {
        public let backend: ActionBackendID
        public let metadataID: UUID
        public init(backend: ActionBackendID, metadataID: UUID) {
            self.backend = backend; self.metadataID = metadataID
        }
        public var identifier: String {
            "maktabah.history-reader.v1.\(backend.rawValue).\(metadataID.uuidString.lowercased())"
        }
        public init(identifier: String) throws {
            let fields = identifier.split(separator: ".", omittingEmptySubsequences: false)
            guard identifier.utf8.count <= 160, fields.count == 5,
                  fields[0] == "maktabah", fields[1] == "history-reader", fields[2] == "v1",
                  let backend = ActionBackendID(rawValue: String(fields[3])),
                  let id = UUID(uuidString: String(fields[4])),
                  id.uuidString.lowercased() == fields[4] else {
                throw UIRouteError(.failed, "invalid_history_reader_reference")
            }
            self.init(backend: backend, metadataID: id)
            guard self.identifier == identifier else {
                throw UIRouteError(.failed, "invalid_history_reader_reference")
            }
        }
    }
    public struct Record: Sendable, Equatable, Identifiable {
        public let reference: Reference
        public let title: String
        /// Host-local metadata only; it is absent from the public entity ID.
        public let locator: ActionTextRef
        public var id: String { reference.identifier }
        public init(reference: Reference, title: String, locator: ActionTextRef) {
            self.reference = reference; self.title = title; self.locator = locator
        }
    }
    public struct OpenRequest: Sendable {
        public let record: Record
        public let window: NativeIntentService.Destination
        public let invocation: ActionPortInvocation
        public let newTab: Bool
        init(record: Record, window: NativeIntentService.Destination,
             invocation: ActionPortInvocation, newTab: Bool) {
            self.record = record; self.window = window
            self.invocation = invocation; self.newTab = newTab
        }
    }
    /// Retain actual original returns even if a later step refuses completion.
    public struct Execution: Sendable {
        public let coreResult: ActionResult?
        public let acknowledgement: UISceneAcknowledgement?
        /// The existing native Reader may produce a receipt before a later
        /// completion check refuses. Preserve it without inventing an ACK.
        public let nativeReceipt: UISceneReceipt?
        public init(coreResult: ActionResult?, acknowledgement: UISceneAcknowledgement?,
                    nativeReceipt: UISceneReceipt? = nil) {
            self.coreResult = coreResult; self.acknowledgement = acknowledgement
            self.nativeReceipt = nativeReceipt
        }
    }
    public struct Failure: Error, LocalizedError, Sendable {
        public let execution: Execution
        public let status: ActionStatus
        public let code: String
        public var errorDescription: String? { NativeIntentOutcome(status: status, code: code).errorDescription }
        public init(execution: Execution, underlying: any Error) {
            self.execution = execution
            let route = underlying as? UIRouteError
            status = route?.status ?? (underlying is CancellationError ? .cancelled : .failed)
            code = route?.code ?? (underlying is CancellationError ? "cancelled" : "native_effect_uncertain")
        }
    }
    public typealias Snapshot = @MainActor @Sendable () throws -> ActionBackendSnapshot
    public typealias Catalog = @MainActor @Sendable (ActionBackendSnapshot) throws -> [Record]
    public typealias Windows = @MainActor @Sendable () throws -> [NativeIntentService.Destination]
    public typealias Navigate = @MainActor @Sendable (OpenRequest) async throws -> Execution
    private let snapshot: Snapshot
    private let read: Catalog
    private let readWindows: Windows
    private let navigate: Navigate
    private let now: @MainActor @Sendable () -> UInt64

    public init(snapshot: @escaping Snapshot, catalog: @escaping Catalog,
                windows: @escaping Windows, navigate: @escaping Navigate,
                now: @escaping @MainActor @Sendable () -> UInt64 = { DispatchTime.now().uptimeNanoseconds }) {
        self.snapshot = snapshot; read = catalog; readWindows = windows
        self.navigate = navigate; self.now = now
    }

    public func records(identifiers: [String]? = nil, matching query: String? = nil) throws -> [Record] {
        try Task.checkCancellation(); try checkQuery(identifiers, query)
        let references = try identifiers?.map(Reference.init(identifier:))
        let before = try snapshot()
        var values = try catalog(before)
        if let references { values = values.filter { references.contains($0.reference) } }
        if let query, !query.isEmpty { values = values.filter { $0.title.localizedCaseInsensitiveContains(query) } }
        guard try snapshot() == before else {
            throw UIRouteError(.staleState, "history_reader_source_changed")
        }
        return Array(values.prefix(64))
    }

    public func windows(identifiers: [String]? = nil, matching query: String? = nil) throws
        -> [NativeIntentService.Destination] {
        try Task.checkCancellation(); try checkQuery(identifiers, query)
        let before = try snapshot()
        guard !(try catalog(before)).isEmpty else { return [] }
        var values = try windows(before)
        if let identifiers { values = values.filter { identifiers.contains($0.id) } }
        if let query, !query.isEmpty { values = values.filter { $0.title.localizedCaseInsensitiveContains(query) } }
        guard try snapshot() == before else {
            throw UIRouteError(.staleState, "history_reader_source_changed")
        }
        return values
    }

    public func open(identifier: String, windowIdentifier: String, newTab: Bool) async throws -> Execution {
        try Task.checkCancellation()
        let (end, overflow) = now().addingReportingOverflow(5_000_000_000)
        guard !overflow else { throw UIRouteError(.unavailable, "deadline_exceeded") }
        let reference = try Reference(identifier: identifier)
        guard !windowIdentifier.isEmpty, windowIdentifier.utf8.count <= 512 else {
            throw UIRouteError(.failed, "invalid_intent_window")
        }
        let before = try snapshot()
        guard reference.backend == before.backend else {
            throw UIRouteError(.requiresBackendSwitch, "history_reader_backend_mismatch")
        }
        let records = try catalog(before).filter { $0.reference == reference }
        let windows = try windows(before).filter { $0.id == windowIdentifier }
        guard records.count == 1, let record = records.first,
              windows.count == 1, let window = windows.first,
              try snapshot() == before, now() < end else {
            throw UIRouteError(.staleState, "history_reader_no_longer_available")
        }
        let request = OpenRequest(record: record, window: window,
            invocation: .init(requestId: UUID(), snapshot: before, deadlineUptimeNanoseconds: end), newTab: newTab)
        let result = try await navigate(request)
        do {
            try Task.checkCancellation()
            guard now() < end, try snapshot() == before else {
                throw UIRouteError(.staleState, "history_reader_completion_changed")
            }
            guard let acknowledgement = result.acknowledgement else {
                throw UIRouteError(.failed, "native_effect_uncertain")
            }
            guard case .acknowledged(let receipt) = acknowledgement else { return result }
            guard let core = result.coreResult, core.status == .completed,
                  core.action == "reader.open", core.requestId == request.invocation.requestId,
                  core.backend == before.backend, core.backendGeneration == before.generation,
                  receipt.requestId == request.invocation.requestId,
                  receipt.backendSnapshot == before, receipt.sceneID == window.sceneID,
                  receipt.route.requestId == receipt.requestId, receipt.route.version == 1,
                  receipt.route.destination.rawValue == "native.reader",
                  receipt.route.backend == before.backend, receipt.route.expectedBackendSnapshot == before,
                  receipt.route.scene.kind == .specific, receipt.route.scene.sceneID == window.sceneID,
                  receipt.route.scene.expectedRevision == receipt.basedOnSceneRevision,
                  receipt.appliedSceneRevision > receipt.basedOnSceneRevision,
                  let native = receipt.coreReceipt, native.requestId == receipt.requestId,
                  native.sceneID == window.sceneID.rawValue, native.snapshot == before,
                  receipt.route.content == native.destination,
                  native.destination.presentationMode == (newTab ? .newTab : .sameTab),
                  (native.destination.focusLocator ?? native.destination.sectionLocator) == record.locator else {
                throw UIRouteError(.failed, "native_effect_uncertain")
            }
        } catch { throw Failure(execution: result, underlying: error) }
        return result
    }

    private func catalog(_ expected: ActionBackendSnapshot) throws -> [Record] {
        let values = try read(expected)
        guard values.count <= 500, Set(values.map(\.id)).count == values.count,
              values.allSatisfy({ $0.reference.backend == expected.backend && $0.locator.backend == expected.backend }) else {
            throw UIRouteError(.failed, "invalid_history_reader_catalog")
        }
        return values
    }
    private func windows(_ expected: ActionBackendSnapshot) throws -> [NativeIntentService.Destination] {
        let values = try readWindows()
        guard values.count <= 128, Set(values.map(\.id)).count == values.count else {
            throw UIRouteError(.failed, "invalid_history_reader_windows")
        }
        return values.filter {
            $0.backend == expected.backend && $0.destination.rawValue == "native.library" && $0.component == nil
        }
    }
    private func checkQuery(_ identifiers: [String]?, _ query: String?) throws {
        guard identifiers == nil || identifiers!.count <= 64,
              query == nil || query!.utf8.count <= 512 else {
            throw UIRouteError(.failed, "invalid_history_reader_query")
        }
    }
}
