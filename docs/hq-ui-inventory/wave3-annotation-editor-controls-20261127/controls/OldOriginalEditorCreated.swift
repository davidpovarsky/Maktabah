import Foundation
@MainActor struct ActualOriginalEditorCreated {
    let nativeControls: MaktabahNativeAnnotationEditorControls.Attachment?
    let nativeEditorViewID: UUID
    @OriginalEditorState var editorTextView: UITextView? = nil
    var onNativeTextView: (@MainActor (UITextView) -> Void)?
    init(nativeControls: MaktabahNativeAnnotationEditorControls.Attachment?, viewID: UUID) {
        self.nativeControls=nativeControls; nativeEditorViewID=viewID
    }
    private func nativeEditorStateWillChange() {
        nativeControls?.controls.originalStateWillChange(viewID: nativeEditorViewID)
    }
    func created() -> @MainActor (UITextView) -> Void {
        return {
                        self.editorTextView = $0
                        onNativeTextView?($0)
                    }
    }
}
