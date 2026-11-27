
@MainActor final class Harness {
 let manager=iOSNavigationManager()
 let book=BooksData()
 let reader:ReaderViewModel
 let tab:iOSNavigationManager.ReaderTab
 let workspace:StudyWorkspaceNavigationAdapter
 let projection:MaktabahNativeWorkspaceProjectionSource
 let requestID=UUID()
 var token=UUID()
 var owner:MaktabahNativePhoneTOCPresentationBinding!
 var requested=false,blocked=false,admitted=true
 var readerCalls=0,presentCalls=0,changedCalls=0,invalidatedCalls=0
 var duringReader:(@MainActor () throws -> Void)?
 var duringOriginal:(@MainActor () throws -> Void)?
 var duringAdmission:(@MainActor () throws -> Void)?
 init(warm:Bool=false,wrongMode:Bool=false) {
  reader=ReaderViewModel(book:book)
  tab = .init(id:UUID(),book:book,viewModel:reader)
  manager.openTabs=[tab];manager.activeTabId=tab.id
  workspace=StudyWorkspaceNavigationAdapter(manager:manager,sceneID:"scene-1")
  projection=MaktabahNativeWorkspaceProjectionSource(workspace)
  if warm {
   manager.currentMode = wrongMode ? .history:.viewer
   manager.selectedBook=book
   manager.currentMode = .history
  }
  owner=MaktabahNativePhoneTOCPresentationBinding(sceneID:UIStableID(rawValue:"scene-1")!,
    manager:manager,workspaceSource:projection,presentReader:{[weak self] retained in
     guard let self,retained.id==self.tab.id,retained.book === self.book,
       retained.viewModel === self.reader else{throw UIRouteError(.staleState,"boundary_wrong_reader")}
     self.readerCalls+=1
     self.manager.currentMode = .viewer
     if self.manager.selectedBook !== retained.book || self.manager.selectedBookPresentationMode != .viewer {
      self.manager.selectedBook=retained.book
     }
     try self.duringReader?()
    })
  owner.install(changed:{[weak self] in self?.changedCalls+=1},
    invalidated:{[weak self] in self?.invalidatedCalls+=1})
 }
 func begin() throws {
  try owner.retainSource(requestID:requestID)
  try owner.begin(requestID:requestID){[weak self] in
   guard let self,self.admitted else{throw UIRouteError(.staleState,"boundary_expired")}
   try self.duringAdmission?()
  }
 }
 func apply() throws {try owner.apply(requestID:requestID)}
 func attach(_ token:UUID?=nil) {
  let chosen=token ?? self.token
  owner.attach(token:chosen,tabID:tab.id,book:book,reader:reader,workspace:workspace,
    requested:{[weak self] in self?.requested==true},
    blocked:{[weak self] in self?.blocked != false},
    present:{[weak self] in
     guard let self,self.owner.isRenderingOriginalContents(token:chosen) else{throw UIRouteError(.staleState,"boundary_not_original_render")}
     self.presentCalls+=1
     try self.duringOriginal?()
     self.requested=true
    })
 }
 func render(){owner.render(token:token)}
 func complete() {owner.finish(requestID:requestID,completed:true);owner.releaseSource(requestID:requestID)}
}
@main struct Controls {
 @MainActor static func main() throws {
  var passed=0,failed=0
  func check(_ name:String,_ value:@autoclosure()->Bool) {
   if value(){passed+=1;print("PASS "+name)}else{failed+=1;print("FAIL "+name)}
  }
  func rejects(_ body:()throws->Void)->Bool{do{try body();return false}catch{return true}}
  do {
   let h=Harness();try h.begin();let proof=try h.owner.captureComponentSource()
   try h.apply()
   check("cold canonical apply has no original contents callback before mount",h.readerCalls==1 && h.presentCalls==0 && !h.owner.isMounted)
   h.attach();h.render();h.complete()
   check("first exact original cold mount renders once and retains source",h.presentCalls==1 && h.owner.isPresented && !rejects{try proof()})
   h.owner.originalStateWillChange(token:h.token)
   check("ordinary original close permanently retires completed source",rejects{try proof()})
  }
  do {
   let h=Harness(warm:true);let before=h.manager.selectedBookPresentationRevision
   try h.begin();try h.apply();h.attach();h.render()
   check("same Viewer-owned book permits exactly zero book setter writes",h.manager.selectedBookPresentationRevision==before && h.presentCalls==1)
  }
  do {
   let h=Harness(warm:true,wrongMode:true);let before=h.manager.selectedBookPresentationRevision!
   try h.begin();try h.apply();h.attach();h.render()
   check("same book owned by another stack needs exactly one original setter write",h.manager.selectedBookPresentationRevision==before+1 && h.presentCalls==1)
  }
  do {
   let h=Harness();try h.begin();h.manager.selectedBook=h.book;h.manager.selectedBook=nil
   check("selectedBook ABA before apply prevents original navigation",rejects{try h.apply()} && h.readerCalls==0)
  }
  do {
   let h=Harness();try h.begin();h.reader.originalTOCRevision=1;h.reader.originalTOCRevision=0
   check("original TOC source ABA cannot be restored",rejects{try h.apply()} && h.readerCalls==0)
  }
  do {
   let h=Harness();try h.begin();h.workspace.isSwitching=true;h.workspace.isSwitching=false
   check("workspace transition ABA permanently revokes original source",rejects{try h.apply()} && h.readerCalls==0)
  }
  do {
   let h=Harness();try h.begin();h.manager.showingTabsList=true;h.manager.showingTabsList=false
   check("blocking original overlay ABA prevents late navigation",rejects{try h.apply()} && h.readerCalls==0)
  }
  do {
   let h=Harness();try h.begin();h.admitted=false
   check("expired original admission prevents canonical apply",rejects{try h.apply()} && h.readerCalls==0)
  }
  do {
   let h=Harness();try h.begin();h.duringAdmission={h.owner.retire()}
   check("reentrant admission retirement prevents canonical setter",rejects{try h.apply()} && h.readerCalls==0)
  }
  do {
   let h=Harness();try h.begin();h.duringReader={h.manager.selectedBook=nil;h.manager.selectedBook=h.book}
   check("reentrant extra book writes cannot hide inside canonical apply",rejects{try h.apply()} && h.presentCalls==0)
  }
  do {
   let h=Harness();try h.begin();try h.apply();h.owner.releaseSource(requestID:h.requestID);h.attach();h.render()
   check("released request cannot join a late first mount",h.presentCalls==0)
  }
  do {
   let h=Harness();try h.begin();try h.apply();h.attach()
   let before=h.owner.stateRevision,changed=h.changedCalls
   h.attach()
   check("same exact attachment refresh does not loop publication",h.owner.stateRevision==before && h.changedCalls==changed)
   h.render();h.render()
   check("one original contents callback per retained request",h.presentCalls==1)
  }
  do {
   let h=Harness();try h.begin();try h.apply();h.attach();h.attach(UUID());h.render()
   check("replacement original view token revokes old request",h.presentCalls==0 && h.invalidatedCalls==1)
  }
  do {
   let h=Harness();try h.begin();try h.apply();h.attach();h.owner.detach(token:UUID());h.render()
   check("stale detach cannot remove another exact mounted owner",h.presentCalls==1)
  }
  do {
   let h=Harness();try h.begin();try h.apply();h.attach();h.owner.detach(token:h.token);h.render()
   check("exact original detach prevents late contents callback",h.presentCalls==0 && !h.owner.isMounted)
  }
  do {
   let h=Harness();try h.begin();try h.apply();h.attach();h.duringAdmission={h.owner.retire()};h.render()
   check("reentrant render validation cannot mutate original UI",h.presentCalls==0 && h.invalidatedCalls==1)
  }
  do {
   let h=Harness();try h.begin();try h.apply();h.attach();h.duringOriginal={h.owner.originalStateWillChange(token:h.token)};h.render()
   check("reentrant user event during original callback cannot preserve source",rejects{try h.owner.validateSource(requestID:h.requestID)} && h.invalidatedCalls==1)
  }
  do {
   let h=Harness();try h.begin();let proof=try h.owner.captureComponentSource();try h.apply();h.attach();h.render()
   h.owner.finish(requestID:h.requestID,completed:false);h.owner.releaseSource(requestID:h.requestID)
   check("uncompleted original transaction cannot retain component proof",rejects{try proof()})
  }
  do {
   let h=Harness();try h.begin();try h.apply();h.attach();h.owner.unmount();h.render()
   check("scene unmount drops original registration and prevents callback",!h.owner.isMounted && h.presentCalls==0)
  }
  do {
   let h=Harness();h.projection.workspace=StudyWorkspaceNavigationAdapter(manager:h.manager,sceneID:"scene-2")
   check("wrong original scene is unavailable",!h.owner.isAvailable())
  }
  do {
   let h=Harness();h.manager.openTabs.append(h.tab)
   check("duplicate actual active tabs are unavailable",!h.owner.isAvailable())
  }
  do {
   let h=Harness();try h.begin();try h.apply()
   let attachment=MaktabahNativePhoneTOCViewAttachment();h.token=attachment.token;attachment.use(h.owner)
   h.attach();attachment.disappeared()
   check("original Group child change preserves exact workspace lifetime",h.owner.isMounted)
   h.manager.currentMode = .history;attachment.disappeared()
   check("actual stack ownership departure detaches original workspace",!h.owner.isMounted)
  }
  print("RESULT passed=\(passed) failed=\(failed)")
  if failed>0{exit(1)}
 }
}

