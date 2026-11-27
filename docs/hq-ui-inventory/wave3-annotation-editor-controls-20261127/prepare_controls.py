from pathlib import Path
import hashlib,json,base64,zlib
P=Path(__file__).parent
def sha(b):return hashlib.sha256(b).hexdigest()
def body(text,signature):
    start=text.index(signature);a=text.index('{',start);depth=1;i=a+1
    while depth:
        if text[i]=='{':depth+=1
        elif text[i]=='}':depth-=1
        i+=1
    return text[start:i]
binding=(P/'baseline/Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeComponentBinding.swift').read_text()
a=binding.index('typealias MaktabahNativeComponentDescriptor');b=binding.index('/// A passive view',a)
source='import Foundation\nimport ChavrusaUIRoutingHost\nimport OtzariaUIRouting\n\n'+binding[a:b]
(P/'controls/ActualComponentSourceObservation.swift').write_text(source)
sheet=(P/'candidate/Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift').read_text()
original_functions=[body(sheet,'    private func nativeEditorStateWillChange()'),body(sheet,'    private func nativeEditorBinding<Value>')]
capsule='''import Foundation
import ChavrusaUIRoutingHost
@MainActor struct ActualOriginalEditorSetter {
    let nativeControls: MaktabahNativeAnnotationEditorControls.Attachment?
    let nativeEditorViewID: UUID
'''+original_functions[0]+'\n'+original_functions[1].replace('private func nativeEditorBinding','func nativeEditorBinding')+'\n}\n'
(P/'controls/ActualOriginalEditorSetter.swift').write_text(capsule)
window=Path('viewer-parent-implementation/source/Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeWindowObservation.swift').read_bytes()
(P/'controls/OriginalWindowObservation.swift').write_bytes(window)
files={}
for folder in ['candidate','controls','proposal/candidate']:
    for file in sorted((P/folder).rglob('*.swift')):files[str(file.relative_to(P))]=file.read_bytes()
for name in ['SOURCE_INPUTS.json','SOURCE_ORIENTATION.json','ORIGINAL_HOOK_EDITS.json','ORIGINAL_HOOKS.diff','CONTRACT.md','prepare_original_hooks.py','prepare_controls.py','prepare_shared.py','prepare_scene_controls.py','proposal/SHARED_EDITS.json','proposal/SHARED.patch','controls/SCENE_EXTRACTION.json']:
    files[name]=(P/name).read_bytes()
for name in ['MaktabahNativeAnnotationEditorControls.swift','MaktabahNativeAnnotationEditorViews.swift']:
    files['preserved-owner-draft-1/'+name]=(P/'evidence/owner-draft-1'/name).read_bytes()
for path in ['Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift','Source/Features/Annotations/iOS/AnnotationListView.swift']:
    files['original/'+path]=(P/'baseline'/path).read_bytes()
meta={'files':[{'path':p,'bytes':len(b),'sha256':sha(b),'text':b.decode()} for p,b in sorted(files.items())],
      'original_functions':[{'bytes':len(x.encode()),'sha256':sha(x.encode())} for x in original_functions],
      'component_fragment_sha256':sha(source.encode()),'window_sha256':sha(window)}
raw=json.dumps(meta).encode();(P/'CONTROL_PAYLOAD.json').write_text(json.dumps({'bytes':len(raw),'sha256':sha(raw),'zlib_base64':base64.b64encode(zlib.compress(raw,9)).decode()}))
print(json.dumps({'files':len(files),'input_bytes':sum(map(len,files.values())),'transport_bytes':(P/'CONTROL_PAYLOAD.json').stat().st_size,
                 'component_fragment_sha256':sha(source.encode()),'window_sha256':sha(window)}))
