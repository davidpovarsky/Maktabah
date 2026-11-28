import Foundation
import OtzariaActionCore
import OtzariaUIRouting

/// Thin semantic entry for the original global-list Edit operation. Discovery
/// reuses the SAME real annotation entity; opening supplies no raw ID or draft.
@MainActor public final class NativeAnnotationEditorIntentService {
    public static let destination = UIDestinationID(rawValue: "native.annotations.editor.record")!
    public typealias Record = NativeAnnotationSelectionIntentService.Record
    public typealias Catalog = NativeAnnotationSelectionIntentService.Catalog
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
    public typealias ValidateCompletion = @MainActor @Sendable (OpenRequest, UISceneReceipt) throws -> Void
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
    private let validateCompletion: ValidateCompletion
    public init(read: @escaping Read, windows: @escaping Windows, navigate: @escaping Open,
                validateCompletion: @escaping ValidateCompletion) {
        self.read = read; readWindows = windows; self.navigate = navigate
        self.validateCompletion = validateCompletion
    }

    public func open(identifier: String, windowIdentifier: String) async throws -> UISceneAcknowledgement {
        try Task.checkCancellation()
        let reference: NativeAnnotationSelectionIntentService.Reference = try NativeReaderEntityIdentifier.decode(
            identifier, prefix: "maktabah.annotation-selection.v1.")
        guard !windowIdentifier.isEmpty, windowIdentifier.utf8.count <= 512 else {
            throw UIRouteError(.failed, "invalid_annotation_editor_selection")
        }
        let source = try catalog()
        guard source.snapshot.backend == reference.backend else {
            throw UIRouteError(.requiresBackendSwitch, "annotation_editor_backend_mismatch")
        }
        let matches = source.records.filter { $0.id == identifier && $0.reference == reference }
        let windows = try readWindows()
        guard windows.count <= 128, Set(windows.map(\.id)).count == windows.count else {
            throw UIRouteError(.failed, "invalid_live_intent_catalog")
        }
        let matchingWindows = windows.filter {
            $0.id == windowIdentifier && $0.backend == source.snapshot.backend
                && $0.destination.rawValue == "native.annotations" && $0.component == nil
        }
        guard matches.count == 1, let record = matches.first,
              matchingWindows.count == 1, let window = matchingWindows.first,
              record.sceneID == window.sceneID else {
            throw UIRouteError(.staleState, "annotation_editor_record_no_longer_available")
        }
        let current = try catalog()
        guard current.snapshot == source.snapshot, current.records.contains(record) else {
            throw UIRouteError(.staleState, "annotation_editor_source_changed")
        }
        let request = OpenRequest(record: record, window: window, snapshot: source.snapshot)
        // Host captures the actual cached row, original List owner, exact window
        // and parent source BEFORE its first await, then uses the one Core path.
        let acknowledgement = try await navigate(request)
        guard case .acknowledged(let receipt) = acknowledgement else { return acknowledgement }
        do {
            try Task.checkCancellation()
            guard receipt.requestId == request.requestID, receipt.route.requestId == request.requestID,
                  receipt.route.version == 1, receipt.route.state.version == 1,
                  receipt.backendSnapshot == request.expectedSnapshot,
                  receipt.sceneID == record.sceneID, receipt.sceneID == window.sceneID,
                  receipt.route.scene.kind == .specific, receipt.route.scene.sceneID == record.sceneID,
                  receipt.route.scene.expectedRevision == receipt.basedOnSceneRevision,
                  receipt.appliedSceneRevision > receipt.basedOnSceneRevision,
                  receipt.route.destination == Self.destination,
                  receipt.route.backend == reference.backend,
                  receipt.route.expectedBackendSnapshot == request.expectedSnapshot,
                  receipt.route.presentation.kind == .sheet, receipt.route.presentation.tabID == nil,
                  receipt.route.content == nil, receipt.route.focus == nil,
                  receipt.route.state.selectedItemID == record.itemID,
                  receipt.route.state.visibleComponents.isEmpty, receipt.route.state.expandedComponents.isEmpty,
                  receipt.route.state.sidebarVisible == nil, receipt.route.state.inspectorVisible == nil,
                  receipt.route.state.sheet == nil, receipt.route.state.scrollAnchor == nil,
                  receipt.route.state.privateState == nil, receipt.coreReceipt == nil else {
                throw UIRouteError(.failed, "native_effect_uncertain")
            }
            // The old list catalog has legitimately retired when covered. Only
            // the host's SAME completed record/editor proof can validate here;
            // rediscovering a replacement list or editor is expressly forbidden.
            try validateCompletion(request, receipt)
            try Task.checkCancellation()
        } catch { throw Failure(acknowledgement: acknowledgement, underlying: error) }
        return acknowledgement
    }
    private func catalog() throws -> Catalog {
        let source = try read()
        guard source.records.count <= 1_000, Set(source.records.map(\.id)).count == source.records.count,
              Set(source.records.map(\.itemID)).count == source.records.count,
              source.records.allSatisfy({ $0.reference.backend == source.snapshot.backend }) else {
            throw UIRouteError(.failed, "invalid_annotation_selection_catalog")
        }
        for record in source.records {
            guard try Record(reference: record.reference, title: record.title, sceneID: record.sceneID) == record else {
                throw UIRouteError(.failed, "invalid_annotation_selection_identity")
            }
        }
        return source
    }
}
