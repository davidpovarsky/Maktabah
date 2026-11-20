import Foundation

// Explicit boundary doubles. These tests run the extracted original app owner,
// callback and setter; they do not import UIKit/SwiftUI or present a native sheet.
@MainActor final class UITextView {}
@MainActor final class ReaderViewModel {}
struct Annotation: Equatable { var id: Int64?; var note: String? }
enum ActionPortError: Error { case staleState }
@MainActor struct Binding<Value> {
    let get: () -> Value
    let set: (Value) -> Void
    var wrappedValue: Value {
        get { get() }
        nonmutating set { set(newValue) }
    }
}

@MainActor final class MaktabahNativeNoteEditorOwner {
    let id: UUID
    weak var reader: ReaderViewModel?
    private let annotation: Binding<Annotation?>
    private let presentationID: @MainActor () -> UUID
    private var retiredPresentationID: UUID?
    weak var textView: UITextView?
    private(set) var presentationActive = false
    @discardableResult
    func observeTextView(_ value: UITextView?, presentationID: UUID) -> Bool {
        // Reader ownership survives sheet dismissal/reopening. Only the
        // presentation captured by this original editor may publish a view.
        guard current != nil, self.presentationID() == presentationID,
              retiredPresentationID != presentationID else { return false }
        if value == nil {
            // onDisappear closes this presentation even when its asynchronous
            // onCreated callback has not arrived. Late creation cannot revive it.
            retiredPresentationID = presentationID
        }
        textView = value
        if value != nil { presentationActive = true }
        return true
    }
    func didDismiss() {
        guard current == nil else { return }
        retiredPresentationID = presentationID()
        presentationActive = false
        textView = nil
    }
    init(id: UUID, reader: ReaderViewModel, annotation: Binding<Annotation?>,
         presentationID: @escaping @MainActor () -> UUID) {
        self.id = id; self.reader = reader; self.annotation = annotation
        self.presentationID = presentationID
    }
    var current: Annotation? { annotation.wrappedValue }
    func present(_ draft: Annotation) throws {
        guard current == nil, draft.id == nil else { throw ActionPortError.staleState }
        presentationActive = true
        annotation.wrappedValue = draft
    }
}


@MainActor final class WorkspaceBoundaryDouble {
    var editingAnnotation: Annotation?
    var nativeNoteEditorPresentationID = UUID()
        func setEditingAnnotation(_ value: Annotation?) {
        // One identity per original sheet entry, including reopening the same
        // unsaved value. Callback closures capture this value, never a live getter.
        if value != nil { nativeNoteEditorPresentationID = UUID() }
        editingAnnotation = value
    }
}

@MainActor final class SceneBoundaryDouble {
    var noteEditorOwner: MaktabahNativeNoteEditorOwner?
    private(set) var revision = 0
    init(_ owner: MaktabahNativeNoteEditorOwner) { noteEditorOwner = owner }
    func nativeStateChanged() throws { revision += 1 }
        func noteEditorTextViewChanged(id: UUID, reader: ReaderViewModel, presentationID: UUID, textView: UITextView?) {
        guard let owner = noteEditorOwner, owner.id == id, owner.reader === reader else { return }
        guard owner.observeTextView(textView, presentationID: presentationID) else { return }
        try? nativeStateChanged()
    }
}

@MainActor final class World {
    let workspace: WorkspaceBoundaryDouble
    let reader: ReaderViewModel
    let owner: MaktabahNativeNoteEditorOwner
    let scene: SceneBoundaryDouble
    init() {
        let workspace = WorkspaceBoundaryDouble(), reader = ReaderViewModel()
        self.workspace = workspace; self.reader = reader
        let annotation = Binding(get: { workspace.editingAnnotation },
                                 set: { workspace.setEditingAnnotation($0) })
#if BOUND_PRESENTATION
        let owner = MaktabahNativeNoteEditorOwner(id: UUID(), reader: reader, annotation: annotation,
            presentationID: { workspace.nativeNoteEditorPresentationID })
#else
        // Historical API adapter: the original owner and callback have no
        // presentation argument. No lifecycle guard is supplied by this double.
        let owner = MaktabahNativeNoteEditorOwner(id: UUID(), reader: reader, annotation: annotation)
#endif
        self.owner = owner; scene = SceneBoundaryDouble(owner)
    }
    @discardableResult func begin(_ annotation: Annotation = .init(id: nil, note: "same draft")) -> UUID {
#if !BOUND_PRESENTATION
        // Test input labels distinguish two native presentations even when the
        // old app only receives the same Reader workspace ID and same value.
        workspace.nativeNoteEditorPresentationID = UUID()
#endif
        workspace.setEditingAnnotation(annotation)
        return workspace.nativeNoteEditorPresentationID
    }
    func callback(_ view: UITextView?, presentation: UUID, ownerID: UUID? = nil, reader: ReaderViewModel? = nil) {
#if BOUND_PRESENTATION
        scene.noteEditorTextViewChanged(id: ownerID ?? owner.id, reader: reader ?? self.reader,
            presentationID: presentation, textView: view)
#else
        scene.noteEditorTextViewChanged(id: ownerID ?? owner.id, reader: reader ?? self.reader, textView: view)
#endif
    }
    func dismiss() {
        workspace.setEditingAnnotation(nil)
        owner.didDismiss()
    }
}

private struct FixtureFailure: Error {}
@main @MainActor struct NoteEditorOwnershipFixtures {
    static var failures = 0
    static func require(_ condition: @autoclosure () -> Bool) throws {
        if !condition() { throw FixtureFailure() }
    }
    static func check(_ name: String, _ body: () throws -> Void) {
        do { try body(); print("PASS \(name)") }
        catch { failures += 1; print("FAIL \(name)") }
    }
    static func main() {
        check("live_original_editor_attaches") {
            let w = World(), view = UITextView(), id = w.begin()
            w.callback(view, presentation: id)
            try require(w.owner.textView === view && w.owner.presentationActive && w.scene.revision == 1)
        }
        check("old_disappearance_cannot_clear_new_editor") {
            let w = World(), old = UITextView(), current = UITextView(), oldID = w.begin()
            w.callback(old, presentation: oldID); w.dismiss()
            let currentID = w.begin(); w.callback(current, presentation: currentID)
            w.callback(nil, presentation: oldID)
            try require(w.owner.textView === current && w.owner.presentationActive)
        }
        check("old_creation_cannot_replace_new_editor") {
            let w = World(), old = UITextView(), current = UITextView(), oldID = w.begin()
            w.callback(old, presentation: oldID); w.dismiss()
            let currentID = w.begin(); w.callback(current, presentation: currentID)
            w.callback(old, presentation: oldID)
            try require(w.owner.textView === current && w.owner.presentationActive)
        }
        check("late_creation_after_dismissal_stays_inactive") {
            let w = World(), old = UITextView(), oldID = w.begin()
            w.callback(old, presentation: oldID); w.dismiss()
            w.callback(old, presentation: oldID)
            try require(w.owner.current == nil && w.owner.textView == nil && !w.owner.presentationActive)
        }
        check("disappearance_before_creation_is_terminal") {
            let w = World(), delayed = UITextView(), id = w.begin()
            w.callback(nil, presentation: id)
            let revision = w.scene.revision
            w.callback(delayed, presentation: id)
            try require(w.owner.textView == nil && !w.owner.presentationActive && w.scene.revision == revision)
        }
        check("stale_callbacks_do_not_invalidate_scene") {
            let w = World(), old = UITextView(), current = UITextView(), oldID = w.begin()
            w.callback(old, presentation: oldID); w.dismiss()
            let currentID = w.begin(); w.callback(current, presentation: currentID)
            let revision = w.scene.revision
            w.callback(nil, presentation: oldID); w.callback(old, presentation: oldID)
            try require(w.scene.revision == revision && w.owner.textView === current)
        }
        check("identical_unsaved_values_have_distinct_presentations") {
            let w = World(), old = UITextView(), current = UITextView()
            let draft = Annotation(id: nil, note: "same draft"), oldID = w.begin(draft)
            w.callback(old, presentation: oldID); w.dismiss()
            let currentID = w.begin(draft); w.callback(current, presentation: currentID)
            try require(currentID != oldID && w.owner.current == draft)
            w.callback(nil, presentation: oldID)
            try require(w.owner.textView === current)
        }
        check("new_presentation_is_accepted_after_retirement") {
            let w = World(), current = UITextView(), oldID = w.begin()
            w.callback(nil, presentation: oldID); w.dismiss()
            let currentID = w.begin(); w.callback(current, presentation: currentID)
            try require(w.owner.textView === current && w.owner.presentationActive)
        }
        check("owner_replacement_ignores_old_owner_id") {
            let w = World(), view = UITextView(), id = w.begin()
            w.callback(view, presentation: id, ownerID: UUID())
            try require(w.owner.textView == nil && w.scene.revision == 0)
        }
        check("reader_replacement_ignores_old_reader") {
            let w = World(), view = UITextView(), id = w.begin(), other = ReaderViewModel()
            w.callback(view, presentation: id, reader: other)
            try require(w.owner.textView == nil && w.scene.revision == 0)
        }
        check("current_sheet_blocks_until_dismissal") {
            let w = World(), view = UITextView(), id = w.begin()
            w.callback(view, presentation: id); w.callback(nil, presentation: id)
            try require(w.owner.textView == nil && w.owner.presentationActive)
            w.dismiss()
            try require(w.owner.current == nil && !w.owner.presentationActive)
        }
        check("present_keeps_original_unsaved_binding_and_rejects_saved_annotation") {
            let w = World(), draft = Annotation(id: nil, note: "unsaved"), view = UITextView()
            try w.owner.present(draft)
            try require(w.workspace.editingAnnotation == draft && w.owner.current == draft && w.owner.presentationActive)
            w.callback(view, presentation: w.workspace.nativeNoteEditorPresentationID)
            try require(w.owner.textView === view)
            w.dismiss()
            do { try w.owner.present(.init(id: 1, note: "saved")); throw FixtureFailure() }
            catch ActionPortError.staleState {}
            try require(w.owner.current == nil && !w.owner.presentationActive)
        }
        check("dismissal_does_not_clear_live_new_draft") {
            let w = World(), view = UITextView(), id = w.begin()
            w.callback(view, presentation: id); w.owner.didDismiss()
            try require(w.owner.textView === view && w.owner.presentationActive && w.owner.current != nil)
        }
        print("RESULT \(13 - failures)/13 passed")
        if failures != 0 { exit(1) }
    }
}
