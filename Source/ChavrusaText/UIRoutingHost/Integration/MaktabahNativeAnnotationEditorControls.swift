#if os(iOS)
import Foundation
import Observation
import UIKit
import OtzariaUIRouting
import ChavrusaUIRoutingHost

/// Warm access to the ORIGINAL global-list annotation editor. No persistence,
/// editor construction, record lookup or backend selection lives in this owner.
@MainActor @Observable
final class MaktabahNativeAnnotationEditorControls {
    static let destination = UIDestinationID(rawValue: "native.annotations.editor")!
    enum Anchor: String, CaseIterable {
        case body = "native.annotations.editor.body"
        case tags = "native.annotations.editor.tags"
        case style = "native.annotations.editor.style"
        var id: UIDestinationID { UIDestinationID(rawValue: rawValue)! }
    }
    struct Snapshot: Equatable {
        let annotation: Annotation
        let note: String
        let nativeNote: String?
        let tags: String
        let color: String
        let underline: Bool
        let initialized: Bool
        let allowsPlainEditing: Bool
        let blocked: Bool
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.annotation == rhs.annotation && lhs.note.utf8.elementsEqual(rhs.note.utf8)
                && lhs.nativeNote.map { Array($0.utf8) } == rhs.nativeNote.map { Array($0.utf8) }
                && lhs.tags.utf8.elementsEqual(rhs.tags.utf8) && lhs.color.utf8.elementsEqual(rhs.color.utf8)
                && lhs.underline == rhs.underline && lhs.initialized == rhs.initialized
                && lhs.allowsPlainEditing == rhs.allowsPlainEditing && lhs.blocked == rhs.blocked
        }
    }
    /// Original List/Sheet-owned closures, never values decoded from a route.
    struct Attachment {
        let controls: MaktabahNativeAnnotationEditorControls
        let listOwner: UUID
        let parentCurrent: @MainActor () -> Bool
    }
    struct Access {
        let viewID: UUID
        let attachment: Attachment
        let snapshot: @MainActor () -> Snapshot
        let bodyTextView: @MainActor () -> UITextView?
    }
    @MainActor private final class Host {
        let token: UUID
        weak var view: UIView?
        var access: Access
        init(token: UUID, view: UIView, access: Access) {
            self.token = token; self.view = view; self.access = access
        }
    }
    @MainActor private final class Control {
        let token: UUID
        let viewID: UUID
        let anchor: Anchor
        weak var marker: UIView?
        weak var field: UIView?
        init(token: UUID, viewID: UUID, anchor: Anchor, marker: UIView, field: UIView?) {
            self.token = token; self.viewID = viewID; self.anchor = anchor
            self.marker = marker; self.field = field
        }
    }
    @MainActor private final class Source {
        let requestID: UUID
        let host: Host
        let revision: UInt64
        let snapshot: Snapshot
        let window: MaktabahNativeWindowObservation
        let observation: MaktabahNativeComponentSourceObservation
        let validateParent: @MainActor () throws -> Void
        var valid = true
        var applied = false
        var anchor: Anchor?
        var control: Control?
        weak var field: UIView?
        var fieldJoined = false
        var scrolled = false
        var focused = false
        init(requestID: UUID, host: Host, revision: UInt64, snapshot: Snapshot,
             window: MaktabahNativeWindowObservation, observation: MaktabahNativeComponentSourceObservation,
             validateParent: @escaping @MainActor () throws -> Void) {
            self.requestID = requestID; self.host = host; self.revision = revision; self.snapshot = snapshot
            self.window = window; self.observation = observation; self.validateParent = validateParent
        }
        func invalidate() { valid = false; observation.invalidate() }
    }
    @MainActor private final class Pending {
        enum Phase { case ready, applying, applied, rendering, reporting }
        let source: Source
        let validate: @MainActor () throws -> Void
        var phase = Phase.ready
        init(source: Source, validate: @escaping @MainActor () throws -> Void) {
            self.source = source; self.validate = validate
        }
    }

    let sceneID: UIStableID
    private(set) var layoutRevision: UInt64 = 0
    @ObservationIgnored let originalStatePublication = NativeComponentSourcePublication()
    // Opening a saved record retains the ORIGINAL editor State, independently
    // of warm-control request retirement. The original List's one coverage
    // callback retires warm controls, but it does not mutate this editor State.
    // This latch advances only before actual editor State/attachment writes.
    @ObservationIgnored private let originalRecordStatePublication = NativeComponentSourcePublication()
    @ObservationIgnored private var originalRecordRevision: UInt64? = 0
    @ObservationIgnored private let retainWindow: @MainActor () throws -> MaktabahNativeWindowObservation
    @ObservationIgnored private let retainParent: @MainActor (UUID) throws -> (@MainActor () throws -> Void)
    @ObservationIgnored private var host: Host?
    @ObservationIgnored private var controls: [UUID: [Anchor: Control]] = [:]
    @ObservationIgnored private var revision: UInt64? = 0
    @ObservationIgnored private var retained: Source?
    @ObservationIgnored private var completed: Source?
    @ObservationIgnored private var pending: Pending?
    @ObservationIgnored private var capturing: UUID?
    @ObservationIgnored private var validating = false
    @ObservationIgnored private var readingOriginalPresentation = false
    @ObservationIgnored private var mounted = true
    @ObservationIgnored private var changed: @MainActor () -> Void = {}
    @ObservationIgnored private var invalidated: @MainActor () -> Void = {}

    @ObservationIgnored private(set) lazy var componentOwner = MaktabahNativeComponentOwner(
        destination: Self.destination, presentation: .sheet,
        descriptors: [
            .init(anchor: Anchor.body.id, title: String(localized: "Annotation note body")),
            .init(anchor: Anchor.tags.id, title: String(localized: "Annotation tags")),
            .init(anchor: Anchor.style.id, title: String(localized: "Annotation style"))
        ], available: { [weak self] anchor in
            self?.isAvailable(anchor: Anchor(rawValue: anchor.rawValue)) == true
        }, captureSource: { [weak self] anchor in
            guard let self, let anchor = Anchor(rawValue: anchor.rawValue) else { throw Self.stale() }
            return try captureComponentSource(anchor)
        })

    init(sceneID: UIStableID,
         retainWindow: @escaping @MainActor () throws -> MaktabahNativeWindowObservation,
         retainParent: @escaping @MainActor (UUID) throws -> (@MainActor () throws -> Void)) {
        self.sceneID = sceneID; self.retainWindow = retainWindow; self.retainParent = retainParent
    }
    func install(changed: @escaping @MainActor () -> Void, invalidated: @escaping @MainActor () -> Void) {
        self.changed = changed; self.invalidated = invalidated
    }

    func isAvailable(anchor: Anchor? = nil) -> Bool {
        guard mounted, let host, let revision, let view = host.view, let window = view.window,
              host.access.attachment.controls === self,
              MaktabahNativeAnnotationEditorGeometry.ownsTopSheet(view, sceneID: sceneID) else { return false }
        let current = host.access.attachment.parentCurrent()
        let snapshot = host.access.snapshot()
        return self.host === host && self.revision == revision && view.window === window
            && MaktabahNativeAnnotationEditorGeometry.ownsTopSheet(view, sceneID: sceneID)
            && current && snapshot.initialized && !snapshot.blocked
            && (anchor == nil || snapshot.allowsPlainEditing)
    }
    var originalListOwner: UUID? { host?.access.attachment.listOwner }
    var isMounted: Bool { host?.view?.window != nil }

    /// Read-only identity of an ORIGINAL editor attachment. The opening owner
    /// may wait for this first attachment's initialization/layout, but a later
    /// host can never replace it under the same opening request.
    struct OriginalPresentationIdentity: Equatable {
        fileprivate let host: ObjectIdentifier
        fileprivate let token: UUID
        fileprivate let viewID: UUID
        fileprivate let listOwner: UUID
    }
    @MainActor final class OriginalPresentedRecord {
        private let check: @MainActor () throws -> Void
        private let invalidateSource: @MainActor () -> Void
        private var valid = true
        private var checking = false
        fileprivate init(check: @escaping @MainActor () throws -> Void,
                         invalidate: @escaping @MainActor () -> Void) {
            self.check = check; invalidateSource = invalidate
        }
        func validateVisible() throws {
            guard valid, !checking else { retire(); throw MaktabahNativeAnnotationEditorControls.stale() }
            checking = true; defer { checking = false }
            do {
                try check()
                guard valid else { throw MaktabahNativeAnnotationEditorControls.stale() }
            } catch { retire(); throw error }
        }
        func retire() { valid = false; invalidateSource() }
    }
    func originalPresentationIdentity(annotation: Annotation, listOwner: UUID,
                                      window: UIWindow) throws -> OriginalPresentationIdentity? {
        guard mounted, !readingOriginalPresentation else { throw Self.stale() }
        guard let host else { return nil }
        readingOriginalPresentation = true; defer { readingOriginalPresentation = false }
        let identity = OriginalPresentationIdentity(host: ObjectIdentifier(host), token: host.token,
            viewID: host.access.viewID, listOwner: host.access.attachment.listOwner)
        guard host.access.attachment.controls === self, identity.listOwner == listOwner,
              host.view?.window == nil || host.view?.window === window else { throw Self.stale() }
        let current = host.access.attachment.parentCurrent()
        let snapshot = host.access.snapshot()
        guard mounted, self.host === host, host.token == identity.token,
              host.access.viewID == identity.viewID, host.access.attachment.listOwner == listOwner,
              host.access.attachment.controls === self, current, snapshot.annotation == annotation,
              host.view?.window == nil || host.view?.window === window else { throw Self.stale() }
        return identity
    }
    func captureOriginalPresentedRecord(annotation: Annotation, listOwner: UUID, window: UIWindow,
                                        identity: OriginalPresentationIdentity) throws -> OriginalPresentedRecord? {
        guard mounted, !readingOriginalPresentation, let host, let revision = originalRecordRevision,
              ObjectIdentifier(host) == identity.host, host.token == identity.token,
              host.access.viewID == identity.viewID, identity.listOwner == listOwner else { throw Self.stale() }
        readingOriginalPresentation = true; defer { readingOriginalPresentation = false }
        let observation = MaktabahNativeComponentSourceObservation(publications: [originalRecordStatePublication]) {
            _ = host.access.attachment.parentCurrent(); _ = host.access.snapshot()
        }
        @MainActor func requireIdentity() throws {
            try observation.validate()
            guard self.mounted, self.host === host, self.originalRecordRevision == revision,
                  host.token == identity.token, host.access.viewID == identity.viewID,
                  host.access.attachment.controls === self, host.access.attachment.listOwner == listOwner else { throw Self.stale() }
        }
        do {
            try requireIdentity()
            let current = host.access.attachment.parentCurrent(), snapshot = host.access.snapshot()
            try requireIdentity()
            guard current, snapshot.annotation == annotation, !snapshot.blocked else { throw Self.stale() }
            // Initialization and actual original layout are allowed to finish;
            // no geometry or source evidence is synthesized while they do so.
            guard snapshot.initialized, let view = host.view, view.window === window,
                  MaktabahNativeAnnotationEditorGeometry.ownsTopSheet(view, sceneID: sceneID),
                  MaktabahNativeSavedResultsGeometry.isVisible(view, in: view, window: window, sceneID: sceneID) else {
                observation.invalidate(); return nil
            }
            try requireIdentity()
            let proof = OriginalPresentedRecord(check: { [weak self, weak view, weak window] in
                guard let self, let view, let window else { throw Self.stale() }
                try requireIdentity()
                let current = host.access.attachment.parentCurrent(), actual = host.access.snapshot()
                try requireIdentity()
                guard current, actual.annotation == annotation, actual.initialized, !actual.blocked,
                      host.view === view, view.window === window,
                      MaktabahNativeAnnotationEditorGeometry.ownsTopSheet(view, sceneID: self.sceneID),
                      MaktabahNativeSavedResultsGeometry.isVisible(view, in: view, window: window, sceneID: self.sceneID) else { throw Self.unavailable() }
                try requireIdentity()
            }, invalidate: { observation.invalidate() })
            try proof.validateVisible()
            return proof
        } catch { observation.invalidate(); throw error }
    }

    // Parent retention precedes generic component retention, before Core awaits.
    func retainSource(requestID: UUID) throws {
        guard retained == nil, pending == nil, capturing == nil, isAvailable(),
              let host, let revision else { throw Self.unavailable() }
        completed?.invalidate(); completed = nil
        componentOwner.retirePresentation()
        capturing = requestID
        defer { if capturing == requestID { capturing = nil } }
        let observation = MaktabahNativeComponentSourceObservation(publications: [originalStatePublication]) {
            _ = host.access.attachment.parentCurrent(); _ = host.access.snapshot()
        }
        do {
            let window = try retainWindow()
            let parent = try retainParent(host.access.attachment.listOwner)
            try observation.validate(); try parent()
            let snapshot = host.access.snapshot()
            guard capturing == requestID, self.host === host, self.revision == revision,
                  host.view?.window === (try window.validate()), isAvailable(),
                  snapshot.initialized, !snapshot.blocked else { throw Self.stale() }
            let source = Source(requestID: requestID, host: host, revision: revision, snapshot: snapshot,
                window: window, observation: observation, validateParent: parent)
            retained = source
            try validate(source)
        } catch {
            observation.invalidate()
            if retained?.requestID == requestID { retained?.invalidate(); retained = nil }
            throw error
        }
    }
    private func captureComponentSource(_ anchor: Anchor) throws -> (@MainActor () throws -> Void) {
        guard let source = retained, source.anchor == nil, pending == nil,
              source.snapshot.allowsPlainEditing else { throw Self.unavailable() }
        try validate(source)
        source.anchor = anchor
        source.control = controls[source.host.access.viewID]?[anchor]
        if let field = source.control?.field { source.field = field; source.fieldJoined = true }
        try validate(source)
        return { [weak self, weak source] in
            guard let self, let source else { throw Self.stale() }
            try validate(source)
        }
    }
    func validateSource(requestID: UUID) throws {
        guard let source = source(for: requestID) else { throw Self.stale() }
        try validate(source)
    }
    func begin(requestID: UUID, validate: @escaping @MainActor () throws -> Void) throws {
        guard pending == nil, let source = retained, source.requestID == requestID else { throw Self.stale() }
        let value = Pending(source: source, validate: validate)
        pending = value
        do { try check(value, phase: .ready) }
        catch { if pending === value { pending = nil }; source.invalidate(); throw error }
    }
    /// The original editor is already presented. This publishes no UI/data.
    func apply(requestID: UUID) throws {
        guard let value = pending, value.source.requestID == requestID, value.phase == .ready else { throw Self.stale() }
        value.phase = .applying
        try check(value, phase: .applying)
        value.source.applied = true
        value.phase = .applied
        try check(value, phase: .applied)
    }
    func isContinuingAppliedRequest(requestID: UUID) -> Bool {
        guard let value = pending, value.source === retained, value.source.requestID == requestID,
              value.source.valid, value.source.applied, self.host === value.source.host,
              self.revision == value.source.revision else { return false }
        return value.phase == .applied || value.phase == .rendering
    }

    /// Called solely by the original Form's generic component render. Scroll and
    /// focus are each consumed BEFORE their callback, with the same retained source.
    func reveal(anchor: UIDestinationID, viewID: UUID,
                scroll: @MainActor (Anchor) -> Void,
                focusTags: @MainActor () -> Void) -> NativeComponentRenderResult {
        guard let anchor = Anchor(rawValue: anchor.rawValue), let value = pending,
              value.phase == .applied, value.source.applied, value.source.anchor == anchor,
              value.source.host.access.viewID == viewID else { return .awaitingOriginalLayout }
        value.phase = .rendering
        do {
            try check(value, phase: .rendering)
            let source = value.source
            if !source.scrolled {
                source.scrolled = true
                scroll(anchor)
                try check(value, phase: .rendering)
            }
            guard try visibleControl(source, requireFocus: false) else {
                value.phase = .applied; return .awaitingOriginalLayout
            }
            try check(value, phase: .rendering)
            if anchor != .style && !source.focused {
                source.focused = true
                if anchor == .body {
                    guard let field = source.field as? UITextView else { throw Self.stale() }
                    _ = field.becomeFirstResponder()
                } else { focusTags() }
                try check(value, phase: .rendering)
            }
            let visible = try visibleControl(source, requireFocus: true)
            try check(value, phase: .rendering)
            value.phase = .applied
            return visible ? .rendered : .awaitingOriginalLayout
        } catch {
            value.source.invalidate()
            if pending === value { pending = nil }
            componentOwner.retirePresentation(); invalidated()
            return .awaitingOriginalLayout
        }
    }

    func validateVisible(requestID: UUID) throws {
        guard let source = source(for: requestID), source.applied else { throw Self.stale() }
        try validate(source)
        guard let view = source.host.view,
              MaktabahNativeSavedResultsGeometry.isVisible(view, in: view,
                  window: try source.window.validate(), sceneID: sceneID),
              try (source.anchor == nil || visibleControl(source, requireFocus: true)) else { throw Self.unavailable() }
        try validate(source)
    }
    /// Only the active original request may report. A completed geometry proof
    /// remains readable, but cannot be reused as an active report/admission.
    func withValidatedSurface(requestID: UUID, operation: @MainActor () throws -> Void) throws {
        guard let value = pending, value.source.requestID == requestID,
              value.phase == .applied else { throw Self.stale() }
        value.phase = .reporting
        do {
            try check(value, phase: .reporting)
            try validateVisible(requestID: requestID)
            try check(value, phase: .reporting)
            try operation()
            try check(value, phase: .reporting)
            try validateVisible(requestID: requestID)
            try check(value, phase: .reporting)
            value.phase = .applied
        } catch {
            value.source.invalidate()
            if pending === value { pending = nil }
            componentOwner.retirePresentation()
            throw error
        }
    }
    func finish(requestID: UUID, completed: Bool) {
        guard let value = pending, value.source.requestID == requestID else { return }
        if completed, value.phase == .applied, (try? validateVisible(requestID: requestID)) != nil,
           pending === value, retained === value.source {
            self.completed = value.source; pending = nil
        } else {
            value.source.invalidate(); pending = nil; componentOwner.retirePresentation()
        }
    }
    func releaseSource(requestID: UUID) {
        if capturing == requestID { capturing = nil }
        guard let source = retained, source.requestID == requestID else { return }
        retained = nil
        if completed !== source {
            source.invalidate()
            if pending?.source === source { pending = nil; componentOwner.retirePresentation(); invalidated() }
        }
    }

    func attach(access: Access, token: UUID, view: UIView) {
        guard mounted, access.attachment.controls === self else { return }
        if let host, host.token == token, host.view === view,
           host.access.viewID == access.viewID, host.access.attachment.listOwner == access.attachment.listOwner {
            host.access = access; return
        }
        advanceOriginalRecordStatePublication()
        retire()
        host = Host(token: token, view: view, access: access)
        controls = controls.filter { $0.key == access.viewID }
        changed()
    }
    func detach(viewID: UUID, token: UUID, view: UIView) {
        guard let host, host.access.viewID == viewID, host.token == token, host.view === view else { return }
        advanceOriginalRecordStatePublication()
        retire(); self.host = nil; controls.removeValue(forKey: viewID); changed()
    }
    /// Synchronous original setter/teardown hook. Equal writes invalidate too.
    func originalStateWillChange(viewID: UUID) {
        guard host?.access.viewID == viewID else { return }
        advanceOriginalRecordStatePublication()
        retire()
    }
    func observeControl(viewID: UUID, anchor: Anchor, token: UUID, marker: UIView, field: UIView?) {
        guard mounted, host == nil || host?.access.viewID == viewID else { return }
        let previous = controls[viewID]?[anchor]
        let control: Control
        if let previous, previous.token == token, previous.marker === marker {
            if previous.field !== field { revokeChangedControl(previous) }
            previous.field = field; control = previous
        } else {
            if let previous { revokeChangedControl(previous) }
            control = Control(token: token, viewID: viewID, anchor: anchor, marker: marker, field: field)
            controls[viewID, default: [:]][anchor] = control
        }
        if let source = retained, source.anchor == anchor, source.host.access.viewID == viewID,
           source.valid, !source.fieldJoined, let field {
            // No pre-apply attachment can be borrowed after a foreground await.
            guard source.applied, source.control == nil || source.control === control else {
                source.invalidate(); componentOwner.retirePresentation(); invalidated(); return
            }
            source.control = control; source.field = field; source.fieldJoined = true
        }
        componentOwner.observe(anchor: anchor.id, token: token) { [weak self, weak control] in
            guard let self, let control, self.controls[viewID]?[anchor] === control,
                  let source = self.completed ?? self.retained, source.anchor == anchor,
                  source.control === control, (try? self.visibleControl(source, requireFocus: true)) == true else { return nil }
            return .init(anchor: anchor.id, sceneID: self.sceneID, isVisible: true)
        }
    }
    func removeControl(viewID: UUID, anchor: Anchor, token: UUID) {
        guard let control = controls[viewID]?[anchor], control.token == token else { return }
        revokeChangedControl(control)
        controls[viewID]?.removeValue(forKey: anchor)
        componentOwner.remove(anchor: anchor.id, token: token)
    }
    func originalLayoutDidChange(viewID: UUID) {
        guard mounted, host?.access.viewID == viewID else { return }
        guard layoutRevision < .max else { unmount(); return }
        layoutRevision += 1
        componentOwner.geometryChanged(); changed()
    }
    func retire() {
        // Closed invalidation occurs before any arbitrary observer callback.
        originalStatePublication.invalidateRetainedSources()
        if let revision, revision < .max { self.revision = revision + 1 } else { revision = nil }
        capturing = nil
        let wasPending = pending != nil
        retained?.invalidate(); completed?.invalidate(); completed = nil; pending = nil
        componentOwner.retirePresentation()
        if wasPending { invalidated() }
    }
    func unmount() {
        advanceOriginalRecordStatePublication()
        retire(); mounted = false; host = nil; controls.removeAll()
    }

    private func advanceOriginalRecordStatePublication() {
        // Closed weak one-way invalidation precedes any original callback.
        // No source is recaptured and a retired child proof is never rearmed.
        originalRecordStatePublication.invalidateRetainedSources()
        guard let revision = originalRecordRevision, revision < .max else {
            originalRecordRevision = nil
            return
        }
        originalRecordRevision = revision + 1
    }

    private func source(for requestID: UUID) -> Source? {
        if retained?.requestID == requestID { return retained }
        if completed?.requestID == requestID { return completed }
        return nil
    }
    private func validate(_ source: Source) throws {
        guard !validating else { source.invalidate(); throw Self.stale() }
        validating = true; defer { validating = false }
        @MainActor func identity() throws {
            guard mounted, source.valid, (retained === source || completed === source),
                  host === source.host, revision == source.revision,
                  source.host.access.attachment.controls === self else { throw Self.stale() }
            let window = try source.window.validate()
            guard mounted, source.valid, (retained === source || completed === source),
                  host === source.host, revision == source.revision,
                  source.host.view?.window === window else { throw Self.stale() }
            if source.fieldJoined {
                guard let anchor = source.anchor, let control = source.control, let field = source.field,
                      controls[source.host.access.viewID]?[anchor] === control,
                      control.field === field, control.marker?.window === source.host.view?.window else { throw Self.stale() }
            }
        }
        do {
            try identity(); try source.observation.validate(); try source.validateParent(); try identity()
            let current = source.host.access.attachment.parentCurrent()
            let snapshot = source.host.access.snapshot()
            guard current, snapshot == source.snapshot, snapshot.initialized, !snapshot.blocked,
                  source.anchor == nil || snapshot.allowsPlainEditing else { throw Self.stale() }
            try source.observation.validate(); try identity()
        } catch { source.invalidate(); throw error }
    }
    private func check(_ value: Pending, phase: Pending.Phase) throws {
        guard pending === value, retained === value.source, value.phase == phase else { throw Self.stale() }
        try value.validate()
        guard pending === value, retained === value.source, value.phase == phase else { throw Self.stale() }
        try validate(value.source)
        guard pending === value, retained === value.source, value.phase == phase else { throw Self.stale() }
    }
    private func visibleControl(_ source: Source, requireFocus: Bool) throws -> Bool {
        try validate(source)
        guard let anchor = source.anchor, let control = source.control, let field = source.field,
              source.fieldJoined, let form = source.host.view, let marker = control.marker,
              control.field === field, source.snapshot.allowsPlainEditing else { return false }
        let window = try source.window.validate()
        guard MaktabahNativeSavedResultsGeometry.isVisible(marker, in: form, window: window, sceneID: sceneID),
              MaktabahNativeSavedResultsGeometry.isVisible(field, in: form, window: window, sceneID: sceneID) else { return false }
        let result: Bool
        switch anchor {
        case .body:
            guard let text = field as? UITextView, source.host.access.bodyTextView() === text else { return false }
            result = text.isEditable && text.isUserInteractionEnabled && (!requireFocus || text.isFirstResponder)
                && (text.text ?? "").utf8.elementsEqual(source.snapshot.nativeNote?.utf8 ?? source.snapshot.note.utf8)
        case .tags:
            guard let text = field as? UITextField else { return false }
            result = text.isEnabled && text.isUserInteractionEnabled && (!requireFocus || text.isFirstResponder)
                && (text.text ?? "").utf8.elementsEqual(source.snapshot.tags.utf8)
        case .style: result = field === marker
        }
        try validate(source)
        return result
    }
    private func revokeChangedControl(_ control: Control) {
        var revoked = false
        for source in [retained, completed].compactMap({ $0 }) where source.control === control && source.fieldJoined {
            source.invalidate(); revoked = true
        }
        if revoked { componentOwner.retirePresentation(); invalidated() }
    }
    private static func unavailable() -> UIRouteError { UIRouteError(.unavailable, "original_annotation_editor_unavailable") }
    private static func stale() -> UIRouteError { UIRouteError(.staleState, "original_annotation_editor_source_changed") }
}
#endif
