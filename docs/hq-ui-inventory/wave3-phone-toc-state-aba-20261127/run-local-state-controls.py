#!/usr/bin/env python3
from pathlib import Path
import argparse,hashlib,json,subprocess,datetime
ap=argparse.ArgumentParser();ap.add_argument("--root",required=True);ap.add_argument("--out",required=True)
a=ap.parse_args();root=Path(a.root);out=Path(a.out);out.mkdir(parents=True,exist_ok=False)
def block(s,mark):
 start=s.index(mark);start=s.rfind("\n",0,start)+1;opening=s.index("{",start);depth=1;i=opening+1
 while depth:
  if s[i]=="{":depth+=1
  elif s[i]=="}":depth-=1
  i+=1
 return s[start:i]
prior=root/"docs/hq-ui-inventory/wave3-phone-toc-20261127/validation/phone-lifecycle-attempt-2"
receipt=json.loads((prior/"RESULT.json").read_text())
parts=[]
for name in ["ActualContracts.swift","Boundary.swift","ActualObservation.swift"]:
 data=(prior/name).read_bytes();assert hashlib.sha256(data).hexdigest()==receipt["parts"][name];parts.append(data.decode())
actual_phone=(root/"Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativePhoneTOCPresentation.swift").read_bytes()
phone_text=actual_phone.decode()
parts.append(phone_text.replace("#if os(iOS)\n","",1).removesuffix("#endif\n").replace("import OtzariaUIRouting\n",""))
(out/"CurrentActualPhone.swift").write_text(parts[-1])
original=(root/"Source/Features/Reader/iOS/iOSReaderWorkspaceView.swift").read_text()
methods="\n".join(block(original,x) for x in ["private func setEditingAnnotation","private func setNoteErrorMessage"])
assert methods.count("nativePhoneTOCAttachment.originalStateWillChange()")==2
(prior/"Controls.swift").read_text()
fixture=block((prior/"Controls.swift").read_text(),"@MainActor final class Harness")
boundary=r"""
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
 __METHODS__
 func annotation(_ value:Annotation?){setEditingAnnotation(value)}
 func error(_ value:String?){setNoteErrorMessage(value)}
}
""".replace("__METHODS__",methods)
controls=r"""
@main struct StateControls {
 @MainActor static func main() throws {
  var passed=0,failed=0
  func check(_ name:String,_ value:@autoclosure()->Bool){
   if value(){passed+=1;print("PASS "+name)}else{failed+=1;print("FAIL "+name)}
  }
  func rejects(_ action:()throws->Void)->Bool{do{try action();return false}catch{return true}}
  func fresh() throws -> (Harness,OriginalWorkspaceStateBoundary) {
   let h=Harness(warm:true);h.manager.currentMode = .viewer
   let attachment=MaktabahNativePhoneTOCViewAttachment()
   h.token=attachment.token;attachment.use(h.owner);h.attach()
   let local=OriginalWorkspaceStateBoundary(attachment)
   try h.begin()
   return (h,local)
  }
  do {
   let (h,state)=try fresh();let oldPresentation=state.nativeNoteEditorPresentationID
   state.annotation(Annotation());state.annotation(nil)
   check("original annotation setter ABA keeps original Notes behavior and retires source",
    state.editingAnnotation==nil && state.nativeNoteEditorPresentationID != oldPresentation
     && rejects{try h.apply()} && h.readerCalls==0)
  }
  do {
   let (h,state)=try fresh()
   state.error("Original note validation error");state.error(nil)
   check("original error alert set-clear ABA cannot regain pending source",
    state.noteErrorMessage==nil && rejects{try h.apply()} && h.readerCalls==0)
  }
  do {
   let (h,state)=try fresh()
   state.annotation(nil)
   check("equal original annotation setter cannot preserve a captured callback",
    state.editingAnnotation==nil && rejects{try h.apply()} && h.readerCalls==0)
  }
  do {
   let (h,state)=try fresh()
   let before=h.owner.isContinuingOriginalReaderPresentation(requestID:h.requestID)
   var observed:[Bool]=[],appliedTransitions:[Bool]=[]
   h.duringAdmission={
    observed.append(h.owner.isContinuingOriginalReaderPresentation(requestID:h.requestID))
    appliedTransitions.append(h.owner.isTransitioning)
   }
   try h.apply()
   check("only exact post-Reader proof admits its own unsettled push before applied",
    !before && observed == [false,true] && appliedTransitions == [false,false]
     && h.owner.isContinuingOriginalReaderPresentation(requestID:h.requestID))
   let wrong=h.owner.isContinuingOriginalReaderPresentation(requestID:UUID())
   h.owner.retire()
   check("presentation facet rejects wrong request and retired source without Session recursion",
    !wrong && !h.owner.isContinuingOriginalReaderPresentation(requestID:h.requestID))
   withExtendedLifetime(state) {}
  }
  print("RESULT passed=\(passed) failed=\(failed)")
  if failed>0{exit(1)}
 }
}
"""
(out/"ActualOriginalWorkspaceSetters.swift").write_text(methods+"\n")
(out/"LocalStateBoundary.swift").write_text(boundary+"\n")
(out/"Controls.swift").write_text(controls+"\n")
combined="import Foundation\nimport Observation\nimport Synchronization\n"+"\n".join(parts)+"\n"+fixture+"\n"+boundary+"\n"+controls
negative=combined.replace(methods,methods.replace("        nativePhoneTOCAttachment.originalStateWillChange()\n",""))
results=[]
for name,text in [("Actual",combined),("NegativeWithoutTwoHooks",negative)]:
 path=out/(name+".swift");path.write_text(text)
 binary=Path("/mnt/development/projects/diagnostics/otzaria-wave3-toc-oracle-20261127")/("phone-state-"+name+"-"+out.name)
 cmd=["/usr/local/bin/swiftc","-swift-version","6","-strict-concurrency=complete","-parse-as-library",str(path),"-o",str(binary)]
 c=subprocess.run(cmd,capture_output=True,text=True);(out/(name+"-compile.log")).write_text(c.stdout+c.stderr)
 r=None
 if c.returncode==0:r=subprocess.run([str(binary)],capture_output=True,text=True);(out/(name+"-execution.log")).write_text(r.stdout+r.stderr)
 results.append({"variant":name,"command":cmd,"compileExit":c.returncode,"runExit":None if r is None else r.returncode,"output":"" if r is None else r.stdout})
syntax=["/usr/local/bin/swiftc","-frontend","-parse","-target","arm64-apple-ios27.0-simulator",str(root/"Source/Features/Reader/iOS/iOSReaderWorkspaceView.swift")]
r=subprocess.run(syntax,capture_output=True,text=True);(out/"iOS27-syntax.log").write_text(r.stdout+r.stderr)
record={"at":datetime.datetime.now(datetime.timezone.utc).isoformat(),"scope":"Actual original setter fragments + actual full phone class/shared Observation with explicit storage/domain boundaries; not SwiftUI UI or Apple SDK execution","workspaceSHA256":hashlib.sha256(original.encode()).hexdigest(),"phoneSourceSHA256":hashlib.sha256(actual_phone).hexdigest(),"prior_actual_parts_sha256":{name:receipt["parts"][name] for name in ["ActualContracts.swift","Boundary.swift","ActualObservation.swift"]},"results":results,"iOS27Syntax":{"command":syntax,"exit":r.returncode},"nativeUIExecuted":0,"physicalExecuted":0}
(out/"RESULT.json").write_text(json.dumps(record,indent=2)+"\n")
print(json.dumps(record))
