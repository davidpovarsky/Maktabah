import Foundation
import OtzariaActionCore
import OtzariaUIRouting

/// Typed local identities for actual published original History/Favorites
/// records. A cached entity is metadata, never a scene or navigation grant.
@MainActor public final class NativeHistoryRecordIntentService {
    public enum Kind: String, Codable, Sendable { case history, favorite }
    public struct Reference: Codable, Sendable, Equatable {
        public let kind: Kind
        public let locator: ActionTextRef
        public init(kind: Kind, locator: ActionTextRef) { self.kind = kind; self.locator = locator }
    }
    public struct Record: Sendable, Equatable, Identifiable {
        public let id: String
        public let reference: Reference
        public let title: String
        public let itemID: UIStableID
        public init(reference: Reference, title: String, itemID: UIStableID) throws {
            id = try NativeReaderEntityIdentifier.encode(reference, prefix: "maktabah.history-record.v1.")
            self.reference = reference; self.title = title; self.itemID = itemID
        }
    }
    public struct Catalog: Sendable {
        public let snapshot: ActionBackendSnapshot
        public let records: [Record]
        public init(snapshot: ActionBackendSnapshot, records: [Record]) {
            self.snapshot = snapshot; self.records = records
        }
    }
    public struct OpenRequest: Sendable {
        public let requestID: UUID
        public let record: Record
        public let window: NativeIntentService.Destination
        public let expectedSnapshot: ActionBackendSnapshot
        init(record: Record, window: NativeIntentService.Destination, snapshot: ActionBackendSnapshot) {
            requestID = UUID(); self.record = record; self.window = window; expectedSnapshot = snapshot
        }
    }
    public typealias Read = @MainActor @Sendable () throws -> Catalog
    public typealias Windows = @MainActor @Sendable () throws -> [NativeIntentService.Destination]
    public typealias Open = @MainActor @Sendable (OpenRequest) async throws -> UISceneAcknowledgement
    /// A later refusal cannot erase an acknowledgement already returned by the
    /// canonical orchestrator. Consumers may inspect it without treating it as
    /// a successful final typed-record result.
    public struct Failure: Error, Sendable {
        public let acknowledgement: UISceneAcknowledgement
        public let status: ActionStatus
        public let code: String
        public init(acknowledgement: UISceneAcknowledgement, underlying: any Error) {
            self.acknowledgement = acknowledgement
            let route = underlying as? UIRouteError
            status = route?.status ?? (underlying is CancellationError ? .cancelled : .failed)
            code = route?.code ?? (underlying is CancellationError ? "cancelled" : "native_effect_uncertain")
        }
    }
    private let read: Read
    private let readWindows: Windows
    private let navigate: Open
    public init(read: @escaping Read, windows: @escaping Windows, navigate: @escaping Open) {
        self.read = read; readWindows = windows; self.navigate = navigate
    }

    public func records(kind: Kind, identifiers: [String]? = nil, matching query: String? = nil) throws -> [Record] {
        try Task.checkCancellation()
        guard identifiers == nil || identifiers!.count <= 64,
              query == nil || query!.utf8.count <= 512 else {
            throw UIRouteError(.failed, "invalid_intent_record_query")
        }
        if let identifiers {
            for id in identifiers {
                let reference: Reference = try NativeReaderEntityIdentifier.decode(id, prefix: "maktabah.history-record.v1.")
                guard reference.kind == kind else { throw UIRouteError(.failed, "intent_record_kind_mismatch") }
            }
        }
        let source = try catalog()
        var values = source.records.filter { $0.reference.kind == kind }
        if let identifiers { values = values.filter { identifiers.contains($0.id) } }
        if let query, !query.isEmpty { values = values.filter { $0.title.localizedCaseInsensitiveContains(query) } }
        return values
    }

    public func windows(identifiers: [String]? = nil, matching query: String? = nil) throws
        -> [NativeIntentService.Destination] {
        try Task.checkCancellation()
        guard identifiers == nil || identifiers!.count <= 64,
              query == nil || query!.utf8.count <= 512 else {
            throw UIRouteError(.failed, "invalid_intent_record_query")
        }
        let source = try catalog()
        var values = try windows(source.snapshot)
        if let identifiers { values = values.filter { identifiers.contains($0.id) } }
        if let query, !query.isEmpty { values = values.filter { $0.title.localizedCaseInsensitiveContains(query) } }
        let current = try catalog()
        guard current.snapshot == source.snapshot else {
            throw UIRouteError(.staleState, "intent_source_generation_changed")
        }
        return values
    }

    /// Reveal the exact existing original card only. This does not open a book,
    /// restore its remembered position, change favorites, or perform a GET write.
    public func reveal(kind: Kind, identifier: String, windowIdentifier: String) async throws
        -> UISceneAcknowledgement {
        try Task.checkCancellation()
        let reference: Reference = try NativeReaderEntityIdentifier.decode(identifier, prefix: "maktabah.history-record.v1.")
        guard reference.kind == kind, !windowIdentifier.isEmpty, windowIdentifier.utf8.count <= 512 else {
            throw UIRouteError(.failed, "invalid_intent_record_selection")
        }
        let source = try catalog()
        guard source.snapshot.backend == reference.locator.backend else {
            throw UIRouteError(.requiresBackendSwitch, "intent_record_backend_mismatch")
        }
        let matches = source.records.filter { $0.id == identifier && $0.reference == reference }
        let selectedWindows = try windows(source.snapshot).filter { $0.id == windowIdentifier }
        guard matches.count == 1, let record = matches.first,
              selectedWindows.count == 1, let window = selectedWindows.first else {
            throw UIRouteError(.staleState, "intent_record_no_longer_available")
        }
        let current = try catalog()
        guard current.snapshot == source.snapshot, current.records.contains(record) else {
            throw UIRouteError(.staleState, "intent_source_generation_changed")
        }
        // The host retains the exact original publication, card and window
        // before its first await, then uses the original Core/orchestrator.
        let request = OpenRequest(record: record, window: window, snapshot: source.snapshot)
        let result = try await navigate(request)
        guard case .acknowledged(let receipt) = result else { return result }
        do {
        try Task.checkCancellation()
        guard receipt.requestId == request.requestID, receipt.route.requestId == request.requestID,
              receipt.route.version == 1, receipt.route.state.version == 1,
              receipt.backendSnapshot == request.expectedSnapshot,
              receipt.sceneID == window.sceneID, receipt.route.scene.kind == .specific,
              receipt.route.scene.sceneID == window.sceneID,
              receipt.route.scene.expectedRevision == receipt.basedOnSceneRevision,
              receipt.appliedSceneRevision > receipt.basedOnSceneRevision,
              receipt.route.destination.rawValue == "native.history",
              receipt.route.backend == request.expectedSnapshot.backend,
              receipt.route.expectedBackendSnapshot == request.expectedSnapshot,
              receipt.route.presentation.kind == .currentTab,
              receipt.route.presentation.tabID == nil,
              receipt.route.content == nil, receipt.route.focus == nil,
              receipt.route.state.selectedItemID == record.itemID,
              receipt.route.state.visibleComponents.isEmpty,
              receipt.route.state.expandedComponents.isEmpty,
              receipt.route.state.sidebarVisible == nil, receipt.route.state.inspectorVisible == nil,
              receipt.route.state.sheet == nil,
              receipt.route.state.scrollAnchor == nil, receipt.route.state.privateState == nil,
              receipt.coreReceipt == nil else {
            throw UIRouteError(.failed, "native_effect_uncertain")
        }
        } catch { throw Failure(acknowledgement: result, underlying: error) }
        return result
    }

    private func catalog() throws -> Catalog {
        let value = try read()
        guard value.records.count <= 1_000, Set(value.records.map(\.id)).count == value.records.count,
              Set(value.records.map(\.itemID)).count == value.records.count,
              value.records.allSatisfy({ $0.reference.locator.backend == value.snapshot.backend }) else {
            throw UIRouteError(.failed, "invalid_live_record_catalog")
        }
        for record in value.records {
            guard try NativeReaderEntityIdentifier.encode(record.reference, prefix: "maktabah.history-record.v1.") == record.id else {
                throw UIRouteError(.failed, "invalid_live_record_identity")
            }
        }
        return value
    }
    private func windows(_ source: ActionBackendSnapshot) throws -> [NativeIntentService.Destination] {
        let values = try readWindows()
        guard values.count <= 128, Set(values.map(\.id)).count == values.count else {
            throw UIRouteError(.failed, "invalid_live_intent_catalog")
        }
        return values.filter { $0.backend == source.backend && $0.destination.rawValue == "native.history" && $0.component == nil }
    }
}
