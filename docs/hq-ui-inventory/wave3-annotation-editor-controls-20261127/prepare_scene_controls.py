from pathlib import Path
import hashlib,json
P=Path(__file__).parent
def sha(b):return hashlib.sha256(b).hexdigest()
def body(text,signature):
    start=text.index(signature);a=text.index('{',start);depth=1;i=a+1
    while depth:
        if text[i]=='{':depth+=1
        elif text[i]=='}':depth-=1
        i+=1
    return text[start:i]
source=(P/'proposal/candidate/Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneSession.swift').read_text()
signatures=[
'    func observeAnnotationPresentation(',
'    func originalAnnotationPresentationWillChange(',
'    func removeAnnotationPresentation(',
'    private func advanceOriginalAnnotationPresentationPublication(',
'    func retainOriginalAnnotationPresentationObservation(',
'    private func retainOriginalAnnotationEditorPresentationObservation(',
'    func observeSearchPresentation(',
'    func originalSearchPresentationWillChange(',
'    func removeSearchPresentation(',
'    private func advanceOriginalSearchPresentationPublication(',
'    private func retainHistorySearchPresentationObservation(',
'    private var isOriginalAnnotationEditorRootReady:',
'    func captureHistoryReaderWindow()',
'    private func captureHistoryReaderWindow(',
'    private func captureAnnotationEditorWindow(']
parts=[body(source,s) for s in signatures]
capsule='import Foundation\nimport OtzariaUIRouting\nimport ChavrusaUIRoutingHost\n@MainActor final class MaktabahNativeSceneSession {\n'+(P/'controls/EditorSceneFields.swift').read_text()+'\n\n'+'\n\n'.join(parts)+'\n}\n'
(P/'controls/ActualEditorSessionCapsule.swift').write_text(capsule)
sheet=(P/'candidate/Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift').read_text()
old=(P/'evidence/before-original-created-hook/iOSAnnotationEditorSheet.swift').read_text()
def created(t):
    at=t.index('iOSAutoDirectionTextView(text:');a=t.index('onCreated: {',at)+len('onCreated: ');b=t.index('\n                    })',a)+len('\n                    }');return t[a:b]
new_created=created(sheet);old_created=created(old)
assert new_created.replace('                        nativeEditorStateWillChange()\n','')==old_created
prefix='''import Foundation
@MainActor struct ActualOriginalEditorCreated {
    let nativeControls: MaktabahNativeAnnotationEditorControls.Attachment?
    let nativeEditorViewID: UUID
    @OriginalEditorState var editorTextView: UITextView? = nil
    var onNativeTextView: (@MainActor (UITextView) -> Void)?
    init(nativeControls: MaktabahNativeAnnotationEditorControls.Attachment?, viewID: UUID) {
        self.nativeControls=nativeControls; nativeEditorViewID=viewID
    }
'''+body(sheet,'    private func nativeEditorStateWillChange()')+'''
    func created() -> @MainActor (UITextView) -> Void {
        return '''
for name,text in [('ActualOriginalEditorCreated.swift',new_created),('OldOriginalEditorCreated.swift',old_created)]:
    (P/'controls'/name).write_text(prefix+text+'\n    }\n}\n')
fixture=(P/'controls/EditorControls.swift').read_text().split('@main struct EditorControlRunner')[0]
(P/'controls/EditorFixture.swift').write_text(fixture)
report={'session_sha256':sha(source.encode()),'capsule_sha256':sha(capsule.encode()),'actual_methods':[{'signature':s,'bytes':len(t.encode()),'sha256':sha(t.encode())}for s,t in zip(signatures,parts)],'created_original_sha256':sha(old_created.encode()),'created_candidate_sha256':sha(new_created.encode()),'created_inverse':'EXACT_AFTER_REMOVING_ONE_PREPUBLICATION_LINE','boundary':'Full actual Session root capture and modal callbacks; explicit app/UI/store/window boundaries. Actual editor owner/source bridge is linked separately.'}
(P/'controls/SCENE_EXTRACTION.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
