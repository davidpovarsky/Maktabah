import Foundation
import OtzariaActionCore
import OtzariaUIRouting

/// A reference selects an actual, already published original Saved Results
/// node in one original window. It carries no saved query, folder path, SQL ID
/// or authority. Reload, replacement and source invalidation retire it.
@MainActor public final class NativeSavedResultIntentService {
    public enum Kind: String, Codable, Sendable, Hashable { case folder, result }
    public struct Reference: Codable, Sendable, Equatable {
        public let backend: ActionBackendID
        public let kind: Kind
        public let token: UUID
        public init(backend: ActionBackendID, kind: Kind, token: UUID) {
            self.backend = backend; self.kind = kind; self.token = token
        }
    }
    public struct Record: Sendable, Equatable, Identifiable {
        public let id: String
        public let reference: Reference
        public let title: String
        public let sceneID: UIStableID
        public let itemID: UIStableID
        public init(reference: Reference, title: String, sceneID: UIStableID) throws {
            guard reference.backend == .otzaria,
                  !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  title.unicodeScalars.count <= 256,
                  let itemID = UIStableID(rawValue: "saved-results." + reference.kind.rawValue + "." + reference.token.uuidString.lowercased()) else {
                throw UIRouteError(.failed, "invalid_saved_result_metadata")
            }
            id = try NativeReaderEntityIdentifier.encode(reference, prefix: "maktabah.saved-result.v1.")
            self.reference = reference; self.title = title; self.sceneID = sceneID; self.itemID = itemID
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

    /// Preserve the actual canonical return if cancellation or receipt-shape
    /// validation fails after the effect. This value is not a successful ACK.
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
        try validateQuery(identifiers, query)
        if let identifiers {
            for identifier in identifiers {
                let reference = try decode(identifier)
                guard reference.kind == kind else { throw UIRouteError(.failed, "saved_result_kind_mismatch") }
            }
        }
        let source = try catalog()
        var records = source.records.filter { $0.reference.kind == kind }
        if let identifiers { records = records.filter { identifiers.contains($0.id) } }
        if let query, !query.isEmpty { records = records.filter { $0.title.localizedCaseInsensitiveContains(query) } }
        return records
    }

    public func windows(identifiers: [String]? = nil, matching query: String? = nil) throws -> [NativeIntentService.Destination] {
        try Task.checkCancellation()
        try validateQuery(identifiers, query)
        let source = try catalog()
        var values = try windows(source.snapshot)
        if let identifiers { values = values.filter { identifiers.contains($0.id) } }
        if let query, !query.isEmpty { values = values.filter { $0.title.localizedCaseInsensitiveContains(query) } }
        guard try catalog().snapshot == source.snapshot else {
            throw UIRouteError(.staleState, "saved_result_backend_changed")
        }
        return values
    }

    /// Reveal the original folder page or result row. The original result
    /// button is never activated: no query is loaded and no data is changed.
    public func reveal(kind: Kind, identifier: String, windowIdentifier: String) async throws -> UISceneAcknowledgement {
        try Task.checkCancellation()
        let reference = try decode(identifier)
        guard reference.kind == kind, !windowIdentifier.isEmpty, windowIdentifier.utf8.count <= 512 else {
            throw UIRouteError(.failed, "invalid_saved_result_selection")
        }
        let source = try catalog()
        guard source.snapshot.backend == reference.backend else {
            throw UIRouteError(.requiresBackendSwitch, "saved_result_backend_mismatch")
        }
        let matches = source.records.filter { $0.id == identifier && $0.reference == reference }
        let selectedWindows = try windows(source.snapshot).filter { $0.id == windowIdentifier }
        guard matches.count == 1, let record = matches.first,
              selectedWindows.count == 1, let window = selectedWindows.first,
              record.sceneID == window.sceneID else {
            throw UIRouteError(.staleState, "saved_result_no_longer_available")
        }
        let current = try catalog()
        guard current.snapshot == source.snapshot, current.records.contains(record) else {
            throw UIRouteError(.staleState, "saved_result_source_changed")
        }
        let request = OpenRequest(record: record, window: window, snapshot: source.snapshot)
        // The original host retains the exact published tree, path, node,
        // window and source before its FIRST await; this metadata is no grant.
        let result = try await navigate(request)
        guard case .acknowledged(let receipt) = result else { return result }
        do {
            try Task.checkCancellation()
            guard receipt.requestId == request.requestID, receipt.route.requestId == request.requestID,
                  receipt.route.version == 1, receipt.route.state.version == 1,
                  receipt.backendSnapshot == request.expectedSnapshot,
                  receipt.sceneID == record.sceneID, receipt.sceneID == window.sceneID,
                  receipt.route.scene.kind == .specific, receipt.route.scene.sceneID == record.sceneID,
                  receipt.route.scene.expectedRevision == receipt.basedOnSceneRevision,
                  receipt.appliedSceneRevision > receipt.basedOnSceneRevision,
                  receipt.route.destination.rawValue == "native.savedResults",
                  receipt.route.backend == .otzaria, receipt.route.expectedBackendSnapshot == request.expectedSnapshot,
                  receipt.route.presentation.kind == .sheet, receipt.route.presentation.tabID == nil,
                  receipt.route.content == nil, receipt.route.focus == nil,
                  receipt.route.state.selectedItemID == record.itemID,
                  receipt.route.state.visibleComponents.isEmpty, receipt.route.state.expandedComponents.isEmpty,
                  receipt.route.state.sidebarVisible == nil, receipt.route.state.inspectorVisible == nil,
                  receipt.route.state.sheet == nil, receipt.route.state.scrollAnchor == nil,
                  receipt.route.state.privateState == nil, receipt.coreReceipt == nil else {
                throw UIRouteError(.failed, "native_effect_uncertain")
            }
        } catch { throw Failure(acknowledgement: result, underlying: error) }
        return result
    }

    private func decode(_ identifier: String) throws -> Reference {
        let reference: Reference = try NativeReaderEntityIdentifier.decode(identifier, prefix: "maktabah.saved-result.v1.")
        guard reference.backend == .otzaria else { throw UIRouteError(.notSupported, "saved_result_backend_unavailable") }
        return reference
    }
    private func validateQuery(_ identifiers: [String]?, _ query: String?) throws {
        guard identifiers == nil || identifiers!.count <= 64,
              query == nil || query!.utf8.count <= 512 else {
            throw UIRouteError(.failed, "invalid_saved_result_query")
        }
    }
    private func catalog() throws -> Catalog {
        let source = try read()
        guard source.records.count <= 1_000, Set(source.records.map(\.id)).count == source.records.count,
              Set(source.records.map(\.itemID)).count == source.records.count,
              source.records.allSatisfy({ $0.reference.backend == .otzaria && $0.reference.backend == source.snapshot.backend }) else {
            throw UIRouteError(.failed, "invalid_saved_result_catalog")
        }
        for record in source.records {
            guard try Record(reference: record.reference, title: record.title, sceneID: record.sceneID) == record else {
                throw UIRouteError(.failed, "invalid_saved_result_identity")
            }
        }
        return source
    }
    private func windows(_ snapshot: ActionBackendSnapshot) throws -> [NativeIntentService.Destination] {
        let values = try readWindows()
        guard values.count <= 128, Set(values.map(\.id)).count == values.count else {
            throw UIRouteError(.failed, "invalid_live_intent_catalog")
        }
        return values.filter { $0.backend == snapshot.backend && $0.destination.rawValue == "native.savedResults" && $0.component == nil }
    }
}
