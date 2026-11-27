import Foundation
import ChavrusaUIRoutingHost
@MainActor struct ActualOriginalEditorSetter {
    let nativeControls: MaktabahNativeAnnotationEditorControls.Attachment?
    let nativeEditorViewID: UUID
    private func nativeEditorStateWillChange() {
        nativeControls?.controls.originalStateWillChange(viewID: nativeEditorViewID)
    }
    func nativeEditorBinding<Value>(_ original: Binding<Value>) -> Binding<Value> {
        guard nativeControls != nil else { return original }
        return Binding(get: { original.wrappedValue }, set: {
            nativeEditorStateWillChange()
            original.wrappedValue = $0
        })
    }
}
