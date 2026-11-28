#if os(iOS)
import Foundation
import UIKit
import OtzariaUIRouting
import ChavrusaUIRoutingHost

/// One canonical Edit operation on the already-mounted ORIGINAL global list.
/// This owner neither creates an editor nor loads, changes or saves a record.
@MainActor final class MaktabahNativeAnnotationEditorOpening {
    typealias Record = NativeAnnotationSelectionIntentService.Record
    static let destination = NativeAnnotationEditorIntentService.destination

    struct ListState: Equatable {
        let editingAnnotation: Annotation?
        let blockedByOtherPresentation: Bool
    }
    @MainActor private final class ListHost {
        let owner: UUID
        var read: @MainActor () -> ListState
        var edit: @MainActor (Annotation, EditPermit) throws -> Void
        init(owner: UUID, read: @escaping @MainActor () -> ListState,
             edit: @escaping @MainActor (Annotation, EditPermit) throws -> Void) {
            self.owner = owner; self.read = read; self.edit = edit
        }
    }
    /// Private app-owned capability passed only to the captured original setter.
    /// Public input can never construct one or supply an executable callback.
    @MainActor final class EditPermit {
        private weak var binding: MaktabahNativeAnnotationEditorOpening?
        fileprivate let requestID: UUID
        fileprivate let sourceID: UUID
        fileprivate var setterEntered = false
        fileprivate var modalObserved = false
        fileprivate var setterCompleted = false
        fileprivate init(binding: MaktabahNativeAnnotationEditorOpening, requestID: UUID, sourceID: UUID) {
            self.binding = binding; self.requestID = requestID; self.sourceID = sourceID
        }
        func willSet(owner: UUID, annotation: Annotation) throws {
            guard let binding else { throw MaktabahNativeAnnotationEditorOpening.stale() }
            try binding.willSet(self, owner: owner, annotation: annotation)
        }
        func didPublish(owner: UUID) throws {
            guard let binding else { throw MaktabahNativeAnnotationEditorOpening.stale() }
            try binding.didPublish(self, owner: owner)
        }
        func didSet(owner: UUID, annotation: Annotation) throws {
            guard let binding else { throw MaktabahNativeAnnotationEditorOpening.stale() }
            try binding.didSet(self, owner: owner, annotation: annotation)
        }
    }
    @MainActor private final class Source {
        let id = UUID()
        let requestID: UUID
        let list: ListHost
        let record: MaktabahNativeAnnotationSelectionBinding.OriginalEditorRecord
        let window: MaktabahNativeWindowObservation
        let validateParent: @MainActor () throws -> Void
        var valid = true
        var applied = false
        var permit: EditPermit?
        var coverage: UUID?
        var covered = false
        var childIdentity: MaktabahNativeAnnotationEditorControls.OriginalPresentationIdentity?
        var child: MaktabahNativeAnnotationEditorControls.OriginalPresentedRecord?
        init(requestID: UUID, list: ListHost,
             record: MaktabahNativeAnnotationSelectionBinding.OriginalEditorRecord,
             window: MaktabahNativeWindowObservation,
             validateParent: @escaping @MainActor () throws -> Void) {
            self.requestID = requestID; self.list = list; self.record = record
            self.window = window; self.validateParent = validateParent
        }
        func invalidate() { valid = false; record.retire(); child?.retire() }
    }
    @MainActor private final class Pending {
        enum Phase { case ready, applying, publishing, setting, applied, reporting }
        let source: Source
        let validate: @MainActor () throws -> Void
        var phase = Phase.ready
        init(source: Source, validate: @escaping @MainActor () throws -> Void) {
            self.source = source; self.validate = validate
        }
    }

    let sceneID: UIStableID
    private let selection: MaktabahNativeAnnotationSelectionBinding
    private let editor: MaktabahNativeAnnotationEditorControls
    private let retainWindow: @MainActor () throws -> MaktabahNativeWindowObservation
    private let retainParent: @MainActor (UUID, Annotation, UUID) throws -> (@MainActor () throws -> Void)
    private let windowReady: @MainActor () -> Bool
    private var list: ListHost?
    private var retained: Source?
    private var pending: Pending?
    private var completed: Source?
    private var capturing: UUID?
    private var checkingSource = false
    private var checkingPending = false
    private var readingMetadata = false
    private var readingOriginalList = false
    private var retiring = false
    private var mounted = true
    private var changed: @MainActor () -> Void = {}
    private var invalidated: @MainActor () -> Void = {}

    init(sceneID: UIStableID, selection: MaktabahNativeAnnotationSelectionBinding,
         editor: MaktabahNativeAnnotationEditorControls,
         retainWindow: @escaping @MainActor () throws -> MaktabahNativeWindowObservation,
         retainParent: @escaping @MainActor (UUID, Annotation, UUID) throws -> (@MainActor () throws -> Void),
         windowReady: @escaping @MainActor () -> Bool) {
        self.sceneID = sceneID; self.selection = selection; self.editor = editor
        self.retainWindow = retainWindow; self.retainParent = retainParent; self.windowReady = windowReady
    }
    func install(changed: @escaping @MainActor () -> Void, invalidated: @escaping @MainActor () -> Void) {
        self.changed = changed; self.invalidated = invalidated
    }
    var isAvailable: Bool {
        guard mounted, !retiring, !readingMetadata, let list else { return false }
        readingMetadata = true; defer { readingMetadata = false }
        guard selection.isAvailable, !editor.isMounted else { return false }
        let actual = list.read()
        return mounted && !retiring && self.list === list && actual.editingAnnotation == nil
            && !actual.blockedByOtherPresentation && selection.isAvailable && !editor.isMounted
    }
    func attachList(owner: UUID, read: @escaping @MainActor () -> ListState,
                    edit: @escaping @MainActor (Annotation, EditPermit) throws -> Void) {
        guard mounted, !retiring else { return }
        if let list, list.owner == owner { list.read = read; list.edit = edit; return }
        retire()
        guard mounted, !retiring else { return }
        list = ListHost(owner: owner, read: read, edit: edit)
        changed()
    }

    /// Called before the FIRST foreground/Core await. The old cached identity
    /// is resolved once; neither a replacement record nor a later catalog joins.
    func retain(record: Record, requestID: UUID) throws {
        guard capturing == nil, retained == nil, pending == nil,
              isAvailable, let list, record.sceneID == sceneID else { throw Self.unavailable() }
        capturing = requestID
        defer { if capturing == requestID { capturing = nil } }
        completed?.invalidate(); completed = nil
        let row = try selection.captureOriginalEditorRecord(record)
        do {
            guard row.listOwner == list.owner else { throw Self.stale() }
            let window = try retainWindow()
            _ = try window.validate()
            let parent = try retainParent(list.owner, row.annotation, requestID)
            guard mounted, !retiring, capturing == requestID, self.list === list,
                  retained == nil, pending == nil, !editor.isMounted else { throw Self.stale() }
            let source = Source(requestID: requestID, list: list, record: row,
                window: window, validateParent: parent)
            retained = source
            try validate(source)
        } catch { row.retire(); retire(); throw error }
    }
    func validateSource(requestID: UUID) throws {
        guard let source = source(for: requestID) else { throw Self.stale() }
        try validate(source)
    }
    func selectedItem(requestID: UUID) throws -> UIStableID {
        guard let source = source(for: requestID) else { throw Self.stale() }
        try validate(source); return source.record.record.itemID
    }
    func begin(requestID: UUID, validate: @escaping @MainActor () throws -> Void) throws {
        guard pending == nil, let source = retained, source.requestID == requestID else { throw Self.stale() }
        let value = Pending(source: source, validate: validate)
        pending = value
        do {
            try check(value, phase: .ready)
            try requireOriginalList(source)
            try check(value, phase: .ready)
        } catch { retire(); throw error }
    }
    func apply(requestID: UUID) throws {
        guard let value = pending, value.source === retained, value.source.requestID == requestID,
              value.phase == .ready else { throw Self.stale() }
        value.phase = .applying // consume before original validation/getters
        do {
            try check(value, phase: .applying); try requireOriginalList(value.source)
            try check(value, phase: .applying)
            let permit = EditPermit(binding: self, requestID: requestID, sourceID: value.source.id)
            value.source.permit = permit
            try value.source.list.edit(value.source.record.annotation, permit)
            guard permit.setterCompleted, value.source.applied else { throw Self.stale() }
            try check(value, phase: .applied)
            changed()
            try check(value, phase: .applied)
        } catch { retire(); throw error }
    }

    private func willSet(_ permit: EditPermit, owner: UUID, annotation: Annotation) throws {
        guard let value = exact(permit), value.phase == .applying, !permit.setterEntered,
              owner == value.source.list.owner, annotation == value.source.record.annotation else {
            retire(); throw Self.stale()
        }
        permit.setterEntered = true // one use BEFORE any live callback
        do {
            try check(value, phase: .applying); try requireOriginalList(value.source)
            try check(value, phase: .applying)
            value.phase = .publishing
        } catch { retire(); throw error }
    }
    /// Session calls this before its unchanged original modal prepublication.
    /// An ordinary UI setter always proceeds; only automation metadata retires.
    func originalModalWillChange(owner: UUID) {
        guard list?.owner == owner else { return }
        guard let value = pending, value.source === retained, value.source.valid,
              value.phase == .publishing, let permit = value.source.permit,
              permit.setterEntered, !permit.modalObserved, !permit.setterCompleted else { retire(); return }
        permit.modalObserved = true
    }
    private func didPublish(_ permit: EditPermit, owner: UUID) throws {
        guard let value = exact(permit), value.phase == .publishing, permit.modalObserved,
              !permit.setterCompleted, owner == value.source.list.owner else { retire(); throw Self.stale() }
        do {
            try check(value, phase: .publishing)
            value.phase = .setting
            // The Session's real prepublication must already have advanced,
            // before the original State assignment is allowed to execute.
            try check(value, phase: .setting)
        } catch { retire(); throw error }
    }
    private func didSet(_ permit: EditPermit, owner: UUID, annotation: Annotation) throws {
        guard let value = exact(permit), value.phase == .setting, permit.modalObserved,
              !permit.setterCompleted, owner == value.source.list.owner,
              annotation == value.source.record.annotation else { retire(); throw Self.stale() }
        do {
            let actual = value.source.list.read()
            guard exact(permit) === value, value.phase == .setting,
                  actual.editingAnnotation == annotation, !actual.blockedByOtherPresentation else { throw Self.stale() }
            permit.setterCompleted = true; value.source.applied = true; value.phase = .applied
            try check(value, phase: .applied)
        } catch { retire(); throw error }
    }

    /// Passive one-use allowance for the REAL List onDisappear caused by its
    /// just-applied original sheet. The original remove body/counter still run.
    func originalListWillDisappear(owner: UUID, annotation: Annotation?) -> UUID? {
        guard let value = pending, value.source === retained, value.source.list.owner == owner,
              value.phase == .applied, value.source.applied,
              value.source.permit?.setterCompleted == true, value.source.coverage == nil,
              !value.source.covered, annotation == value.source.record.annotation else {
            if list?.owner == owner { retire() }
            return nil
        }
        do {
            try check(value, phase: .applied)
            let token = UUID()
            value.source.coverage = token // consumed before original removal callbacks
            return token
        } catch { retire(); return nil }
    }
    func originalListDidDisappear(owner: UUID, coverage: UUID?) {
        guard let coverage, let value = pending, value.source === retained,
              value.source.list.owner == owner, value.phase == .applied,
              value.source.coverage == coverage, !value.source.covered else {
            if list?.owner == owner { retire(); list = nil }
            return
        }
        do {
            try check(value, phase: .applied)
            value.source.covered = true
            try check(value, phase: .applied)
        } catch { retire() }
    }
    /// Read-only arithmetic facet for the Session's exact captured owner/revision.
    /// No callback, source capture, state mutation or effect authority lives here.
    func allowsOriginalPresentationRevision(requestID: UUID, owner: UUID,
                                            initial: UInt64, current: UInt64?) -> Bool {
        if capturing == requestID, mounted, !retiring, list?.owner == owner,
           retained == nil, pending == nil { return current == initial }
        guard let source = source(for: requestID), source.valid, list === source.list,
              source.list.owner == owner, let current else { return false }
        let phase = pending?.source === source ? pending?.phase : nil
        if source.permit?.modalObserved != true { return current == initial }
        let (afterEdit, overflow) = initial.addingReportingOverflow(1)
        guard !overflow else { return false }
        if phase == .publishing { return current == initial || current == afterEdit }
        guard source.permit?.setterEntered == true else { return false }
        if source.coverage != nil {
            let (afterCoverage, overflow) = afterEdit.addingReportingOverflow(1)
            guard !overflow else { return false }
            return current == afterCoverage || (!source.covered && current == afterEdit)
        }
        return current == afterEdit
    }
    /// Finite read-only original State facet for the Session's retained modal
    /// proof. It does not call the admission or parent validator recursively.
    func originalListIsEditing(requestID: UUID, owner: UUID, annotation: Annotation) throws -> Bool {
        guard mounted, !retiring, !readingOriginalList, let list, list.owner == owner else { throw Self.stale() }
        readingOriginalList = true; defer { readingOriginalList = false }
        let source = source(for: requestID)
        @MainActor func sameCapture() -> Bool {
            guard self.mounted, !self.retiring, self.list === list else { return false }
            if let source {
                return source.valid && self.source(for: requestID) === source
                    && source.list === list && source.record.annotation == annotation
            }
            return self.capturing == requestID && self.retained == nil && self.pending == nil
        }
        guard sameCapture() else { throw Self.stale() }
        let actual = list.read()
        guard sameCapture(), !actual.blockedByOtherPresentation else { throw Self.stale() }
        if source?.applied == true {
            guard actual.editingAnnotation == annotation else { throw Self.stale() }
        } else if pending?.source === source, pending?.phase == .setting {
            guard actual.editingAnnotation == nil || actual.editingAnnotation == annotation else { throw Self.stale() }
        } else {
            guard actual.editingAnnotation == nil else { throw Self.stale() }
        }
        return actual.editingAnnotation != nil
    }
    func isContinuingAppliedRequest(requestID: UUID) -> Bool {
        guard let value = pending, value.source === retained, value.source.valid,
              value.source.requestID == requestID, value.source.applied,
              value.source.permit?.setterCompleted == true, list === value.source.list else { return false }
        return value.phase == .applied || value.phase == .reporting
    }

    /// Invoked from the existing original editor owner's attach/detach/layout
    /// callback. First-host identity comes from that actual lifecycle, not a
    /// later polling pass that could silently borrow a replacement host.
    func originalEditorHostDidChange() {
        guard let source = pending?.source ?? completed else { return }
        guard source.applied, source.permit?.setterCompleted == true else {
            if editor.isMounted { retire() }
            return
        }
        do {
            try validate(source)
            let identity = try editor.originalPresentationIdentity(annotation: source.record.annotation,
                listOwner: source.list.owner, window: source.window.validate())
            try validate(source)
            if let first = source.childIdentity {
                guard identity == first else { throw Self.stale() }
            } else if let identity { source.childIdentity = identity }
        } catch { retire() }
    }

    func hasVisibleSurface(requestID: UUID) -> Bool {
        guard let source = source(for: requestID), source.applied else { return false }
        do { try requireVisible(source); return true } catch { return false }
    }
    func observedItem(requestID: UUID) -> UIStableID? {
        guard let source = source(for: requestID), source.applied else { return nil }
        do { try requireVisible(source); return source.record.record.itemID } catch { return nil }
    }
    func withValidatedSurface(requestID: UUID, operation: @MainActor () throws -> Void) throws {
        guard let value = pending, value.source.requestID == requestID, value.phase == .applied else { throw Self.stale() }
        value.phase = .reporting
        do {
            try check(value, phase: .reporting); try requireVisible(value.source)
            try check(value, phase: .reporting)
            try operation()
            try check(value, phase: .reporting); try requireVisible(value.source)
            try check(value, phase: .reporting)
            value.phase = .applied
        } catch { retire(); throw error }
    }
    func validateCompletedSurface(requestID: UUID) throws {
        guard let source = completed, source.requestID == requestID else { throw Self.stale() }
        try requireVisible(source)
    }
    func finish(requestID: UUID, completed success: Bool) {
        guard let value = pending, value.source.requestID == requestID else { return }
        if success, value.phase == .applied, (try? requireVisible(value.source)) != nil,
           pending === value, retained === value.source, value.source.valid {
            completed = value.source; pending = nil
        } else { retire() }
    }
    func releaseSource(requestID: UUID) {
        if capturing == requestID { capturing = nil }
        guard let source = retained, source.requestID == requestID else { return }
        if completed !== source || pending != nil { retire() }
        if retained === source { retained = nil }
    }
    func clearCompletedProof() { completed?.invalidate(); completed = nil }
    func retire() {
        guard !retiring else { return }
        retiring = true; defer { retiring = false }
        let active = capturing != nil || retained != nil || pending != nil || completed != nil
        capturing = nil
        retained?.invalidate(); completed?.invalidate()
        retained = nil; pending = nil; completed = nil
        if active { invalidated() }
    }
    /// Closed pre-unmount invalidation, before Session's original publications
    /// can synchronously notify any observer. It invokes no app callback.
    func originalSessionWillUnmount() {
        mounted = false; capturing = nil
        retained?.invalidate(); completed?.invalidate()
    }
    func unmount() { mounted = false; retire(); list = nil; changed = {}; invalidated = {} }

    private func source(for requestID: UUID) -> Source? {
        if retained?.requestID == requestID { return retained }
        if completed?.requestID == requestID { return completed }
        return nil
    }
    private func exact(_ permit: EditPermit) -> Pending? {
        guard let value = pending, value.source === retained, value.source.valid,
              value.source.requestID == permit.requestID, value.source.id == permit.sourceID,
              value.source.permit === permit, list === value.source.list else { return nil }
        return value
    }
    private func identity(_ source: Source) throws {
        guard mounted, !retiring, source.valid, retained === source || completed === source,
              list === source.list else { throw Self.stale() }
    }
    private func validate(_ source: Source) throws {
        guard !checkingSource else { source.invalidate(); throw Self.stale() }
        checkingSource = true; defer { checkingSource = false }
        do {
            try identity(source); try source.record.validate(); _ = try source.window.validate()
            try source.validateParent(); try identity(source)
            let actual = source.list.read()
            try identity(source)
            guard !actual.blockedByOtherPresentation else { throw Self.stale() }
            if source.applied {
                guard actual.editingAnnotation == source.record.annotation else { throw Self.stale() }
            } else if pending?.source === source, pending?.phase == .setting {
                guard actual.editingAnnotation == nil || actual.editingAnnotation == source.record.annotation else { throw Self.stale() }
            } else {
                guard actual.editingAnnotation == nil else { throw Self.stale() }
            }
            try source.record.validate(); _ = try source.window.validate()
            try source.validateParent(); try identity(source)
        } catch { source.invalidate(); throw error }
    }
    private func check(_ value: Pending, phase: Pending.Phase) throws {
        guard !checkingPending, pending === value, retained === value.source,
              value.phase == phase else { throw Self.stale() }
        checkingPending = true; defer { checkingPending = false }
        try identity(value.source)
        try value.validate()
        guard pending === value, retained === value.source, value.phase == phase else { throw Self.stale() }
        try validate(value.source)
        guard pending === value, retained === value.source, value.phase == phase else { throw Self.stale() }
    }
    private func requireOriginalList(_ source: Source) throws {
        try validate(source)
        guard !source.applied, windowReady(), !editor.isMounted else { throw Self.unavailable() }
        try source.record.validateVisibleList(in: source.window.validate())
        try validate(source)
    }
    private func requireVisible(_ source: Source) throws {
        try validate(source)
        guard source.applied, source.permit?.setterCompleted == true else { throw Self.stale() }
        if let value = pending, value.source === source {
            guard value.phase == .applied || value.phase == .reporting else { throw Self.stale() }
            // No new grant. The original bounded command remains alive while
            // this first actual attachment finishes original initialization.
            try check(value, phase: value.phase)
        }
        let window = try source.window.validate()
        let identity = try editor.originalPresentationIdentity(annotation: source.record.annotation,
            listOwner: source.list.owner, window: window)
        try validate(source)
        guard let identity, let first = source.childIdentity else { throw Self.unavailable() }
        guard first == identity else { source.invalidate(); throw Self.stale() }
        if source.child == nil {
            let child = try editor.captureOriginalPresentedRecord(annotation: source.record.annotation,
                listOwner: source.list.owner, window: window, identity: identity)
            try validate(source)
            source.child = child
        }
        guard let child = source.child else { throw Self.unavailable() }
        try child.validateVisible(); try validate(source)
    }
    private static func unavailable() -> UIRouteError {
        .init(.unavailable, "original_annotation_editor_opening_unavailable")
    }
    private static func stale() -> UIRouteError {
        .init(.staleState, "original_annotation_editor_opening_source_changed")
    }
}
#endif
