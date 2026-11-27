
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

