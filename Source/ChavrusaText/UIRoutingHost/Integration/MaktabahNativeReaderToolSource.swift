#if os(iOS)
import Foundation
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

/// A single original scene/source captured before catalog awaits. This owns no
/// navigation grant or view. Its one handoff occurs at the existing Core sink,
/// immediately before the original Reader/draft reservation.
@MainActor final class MaktabahNativeReaderToolSource {
    let start: NativeReaderToolIntentService.Start
    let sceneID: UIStableID
    private let readSource: @MainActor () throws -> Void
    private let selection: MaktabahNativeReaderToolSelection?
    private enum Phase: Equatable { case retained, checking, claiming, handedOff, checkingSelection, released }
    private var phase = Phase.retained

    init(start: NativeReaderToolIntentService.Start, sceneID: UIStableID,
         selection: MaktabahNativeReaderToolSelection?, validate: @escaping @MainActor () throws -> Void) throws {
        self.start = start; self.sceneID = sceneID; self.selection = selection; readSource = validate
        try self.validate()
    }
    var isHandedOff: Bool { if case .handedOff = phase { return true }; return false }
    func validate() throws {
        try check(from: .retained, during: .checking, then: .retained, selectionOnly: false)
    }
    func handOff(_ invocation: ActionPortInvocation) throws {
        guard invocation.requestId == start.invocation.requestId,
              invocation.snapshot == start.invocation.snapshot,
              invocation.deadlineUptimeNanoseconds <= start.invocation.deadlineUptimeNanoseconds,
              DispatchTime.now().uptimeNanoseconds < invocation.deadlineUptimeNanoseconds else {
            throw UIRouteError(.staleState, "reader_tool_original_request_changed")
        }
        try check(from: .retained, during: .claiming, then: .handedOff, selectionOnly: false)
    }
    /// The original note binding keeps this same selection fence during its
    /// own Core/presentation awaits. Presenting its unsaved editor is permitted;
    /// changing the underlying Reader/selection is permanently refused.
    func validateSelection() throws {
        try check(from: .handedOff, during: .checkingSelection, then: .handedOff, selectionOnly: true)
    }
    private func check(from expected: Phase, during checking: Phase, then completed: Phase, selectionOnly: Bool) throws {
        guard phase == expected else {
            throw UIRouteError(.staleState, "reader_tool_original_source_retired")
        }
        // Consume this phase BEFORE any original source read/callback. A
        // reentrant prepare cannot steal the source from its own validator.
        phase = checking
        do {
            try Task.checkCancellation()
            guard DispatchTime.now().uptimeNanoseconds < start.invocation.deadlineUptimeNanoseconds else {
                throw UIRouteError(.unavailable, "deadline_exceeded")
            }
            if !selectionOnly { try readSource() }
            try selection?.validate()
            try Task.checkCancellation()
            guard phase == checking,
                  DispatchTime.now().uptimeNanoseconds < start.invocation.deadlineUptimeNanoseconds else {
                throw UIRouteError(.staleState, "reader_tool_original_source_retired")
            }
            phase = completed
        } catch {
            if phase == checking { phase = .released }
            throw error
        }
    }
    func release() { phase = .released }
}

/// Source identity is obtained only from the original renderer-owned selection.
/// The one-way original Observation guard prevents A→B→A from renewing it.
/// No Annotation is constructed until the existing Core preparation callback.
@MainActor final class MaktabahNativeReaderToolSelection {
    private let manager: iOSNavigationManager
    private let owner: MaktabahNativeNoteEditorOwner
    private let reader: ReaderViewModel
    private let inspector: MaktabahNativeInspectorBinding
    private let observation: MaktabahNativeComponentSourceObservation
    private let initialContent: ReaderInitialContentSourceObservation
    private let range: NSRange
    private let source: String

    init(manager: iOSNavigationManager, owner: MaktabahNativeNoteEditorOwner, locator: ActionTextRef) throws {
        // Retain the ORIGINAL coordinator before reading renderer selection.
        // A new initial request can exist before any loaded field changes.
        guard let originalReader = MaktabahNativeInspectorBinding.currentReader(in: manager),
              let initialContent = originalReader.contentLoadCoordinator.initialContentSourceObservation(),
              initialContent.pendingRequestID == nil, initialContent.isCurrent else {
            throw UIRouteError(.unavailable, "reader_tool_original_content_pending")
        }
        let (reader, selected, range, text) = try MaktabahNativeNoteDraftBinding.sourceSelection(manager: manager, owner: owner)
        guard reader === originalReader, initialContent.isCurrent,
              try ActionAppIdentityBridge.actionRef(selected) == locator else {
            throw UIRouteError(.staleState, "reader_tool_original_selection_changed")
        }
        self.manager = manager; self.owner = owner; self.reader = reader
        self.initialContent = initialContent
        inspector = try MaktabahNativeInspectorBinding(manager: manager)
        self.range = range; source = text
        observation = MaktabahNativeComponentSourceObservation {
            _ = manager.openTabs; _ = manager.activeTabId; _ = manager.currentMode
            _ = manager.selectedBook; _ = manager.selectedContentId
            _ = reader.state; _ = reader.currentDestination; _ = reader.currentContentId
            _ = reader.currentReaderTextMode; _ = reader.contentText
            _ = reader.backendSection; _ = reader.backendRenderModel
            _ = reader.selectedSegmentLocator; _ = reader.selectedSegmentRange
            _ = reader.otzariaSelectedLineAnchor; _ = reader.readerState.selectedRange
        }
        try validate()
    }
    func validate() throws {
        guard initialContent.isCurrent else {
            throw UIRouteError(.staleState, "reader_tool_original_content_changed")
        }
        try observation.validate()
        try inspector.validate()
        guard owner.reader === reader,
              MaktabahNativeInspectorBinding.currentReader(in: manager) === reader,
              reader.selectedSegmentRange == range,
              reader.contentText.utf8.elementsEqual(source.utf8) else {
            throw UIRouteError(.staleState, "reader_tool_original_selection_changed")
        }
        try observation.validate()
        guard initialContent.isCurrent else {
            throw UIRouteError(.staleState, "reader_tool_original_content_changed")
        }
    }
}
#endif
