
// Explicit local state storage boundary; phone branch of both actual setters.
// Native SwiftUI State presentation remains unexecuted.
struct Annotation {}
struct StudyPresentationBoundary { mutating func beginNote(id:UUID)->Bool {true} }
enum NoteHostBoundary {case reader;case compactStudy}
@MainActor final class OriginalWorkspaceStateBoundary {
 let nativePhoneTOCAttachment:MaktabahNativePhoneTOCViewAttachment
 let usesNativeStudySheet=false
 var nativeStudyPresentation=StudyPresentationBoundary()
 var showPanelSheet=false
 var fallbackNoteHost:NoteHostBoundary = .reader
 var nativeNoteEditorPresentationID=UUID()
 var editingAnnotation:Annotation?
 var noteErrorMessage:String?
 init(_ attachment:MaktabahNativePhoneTOCViewAttachment){nativePhoneTOCAttachment=attachment}
     private func setEditingAnnotation(_ value: Annotation?) {
        nativePhoneTOCAttachment.originalStateWillChange()
        // One identity per original sheet entry, including reopening the same
        // unsaved value. Callback closures capture this value, never a live getter.
        if value != nil {
            let presentationID = UUID()
            if usesNativeStudySheet {
                guard nativeStudyPresentation.beginNote(id: presentationID) else { return }
            } else {
                // The compact inspector is already a system sheet. Its note
                // editor must be owned by that sheet, not a sibling presenter.
                fallbackNoteHost = showPanelSheet ? .compactStudy : .reader
            }
            nativeNoteEditorPresentationID = presentationID
        }
        editingAnnotation = value
    }
    private func setNoteErrorMessage(_ value: String?) {
        nativePhoneTOCAttachment.originalStateWillChange()
        noteErrorMessage = value
    }
 func annotation(_ value:Annotation?){setEditingAnnotation(value)}
 func error(_ value:String?){setNoteErrorMessage(value)}
}

