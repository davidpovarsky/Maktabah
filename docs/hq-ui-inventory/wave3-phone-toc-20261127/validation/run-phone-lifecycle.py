#!/usr/bin/env python3
"""Execute the actual phone binding with explicit app-domain boundary objects.
Actual shared Observation latch, original selectedBook setter, and phone source
are copied verbatim. This does not claim UIKit/SwiftUI/SDK/native execution.
"""
from pathlib import Path
import argparse,datetime,hashlib,json,subprocess
ap=argparse.ArgumentParser();ap.add_argument("--root",required=True);ap.add_argument("--out",required=True)
a=ap.parse_args();root=Path(a.root);out=Path(a.out);out.mkdir(parents=True,exist_ok=False)
def read(p):return (root/p).read_text() if (root/p).exists() else subprocess.run(["git","-C",str(root),"show","HEAD:"+p],capture_output=True,text=True,check=True).stdout
def block(s,mark):
 start=s.index(mark);start=s.rfind("\n",0,start)+1;opening=s.index("{",start);depth=1;i=opening+1
 while depth:
  if s[i]=="{":depth+=1
  elif s[i]=="}":depth-=1
  i+=1
 return s[start:i]
route=read("Source/Otzaria/UIRouting/Sources/OtzariaUIRouting/Contracts/RouteSpec.swift")
status=read("Source/Otzaria/Actions/Sources/OtzariaActionCore/Contracts/ActionRequest.swift")
manager=read("Source/UI/iOS/Managers/iOSNavigationManager.swift")
setter=block(manager,"var selectedBook: BooksData?")
phone=read("Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativePhoneTOCPresentation.swift")
latch=read("Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeComponentSourceObservation.swift")
contracts="import Foundation\n"+block(status,"public enum ActionStatus")+"\n"+block(route,"public struct UIStableID")+"\n"+block(route,"public struct UIRouteError")
boundary=r"""
import Foundation
import Observation
// Explicit app-domain boundaries. No SwiftUI, UIKit, or backend delivery is simulated.
// The test double for captureOriginalSource exercises revocation; its production
// implementation has a separate immutable source/Observation proof.
enum AppMode: Equatable { case viewer, history }
@MainActor enum MaktabahApp { static var isIpad=false }
@MainActor @Observable final class BooksData {
 var id:Int;var backendLocator:String?
 init(_ id:Int=3891) {self.id=id;backendLocator="otzaria|book:\(id)|line:523"}
}
@MainActor @Observable final class ReaderViewModel {
 var currentBook:BooksData?
 var isPopoverPresented=false
 var readerInspectorVisible=false
 var originalTOCRevision:UInt64=0
 init(book:BooksData){currentBook=book}
}
@MainActor @Observable final class iOSNavigationManager {
 struct ReaderTab {let id:UUID;let book:BooksData;let viewModel:ReaderViewModel}
 var activeTabId:UUID?
 var openTabs:[ReaderTab]=[]
 var selectedContentId:Int?=523
 var selectedBookForInfo:BooksData?
 var showingTabsList=false
 var currentMode:AppMode = .history
 var activeReaderViewModel:ReaderViewModel? {openTabs.first{$0.id==activeTabId}?.viewModel}
 __ORIGINAL_SETTER__
 private(set) var selectedBookPresentationMode:AppMode?
 private(set) var selectedBookPresentationRevision:UInt64?=0
}
@MainActor @Observable final class MappingSource {var event:UInt64=0}
struct MappingProjection:Equatable {let activeTabID:UUID?}
enum MappingCoverage {case liveNativeSetters;case unavailable}
@MainActor struct MappingObservation {
 let source:MappingSource;let owner:ObjectIdentifier;let scene:String
 let epoch:UInt64;let projection:MappingProjection;let coverage:MappingCoverage
}
@MainActor @Observable final class StudyWorkspaceNavigationAdapter {
 var attached=true
 var isSwitching=false
 let sceneID:String
 let mappingOwnershipSource=MappingSource()
 var epoch:UInt64=0
 var coverage:MappingCoverage = .liveNativeSetters
 let manager:iOSNavigationManager
 init(manager:iOSNavigationManager,sceneID:String){self.manager=manager;self.sceneID=sceneID}
 func mappingOwnershipObservation()->MappingObservation? {
  .init(source:mappingOwnershipSource,owner:ObjectIdentifier(manager),scene:sceneID,
    epoch:epoch,projection:.init(activeTabID:manager.activeTabId),coverage:coverage)
 }
}
@MainActor @Observable final class MaktabahNativeWorkspaceProjectionSource {
 var isAuthoritative=true
 var workspace:StudyWorkspaceNavigationAdapter?
 init(_ workspace:StudyWorkspaceNavigationAdapter){self.workspace=workspace}
 func read() throws -> StudyWorkspaceNavigationAdapter? {workspace}
}
typealias MaktabahNativeComponentSourceObservation = NativeComponentSourceObservation
@MainActor enum MaktabahNativeTOCComponents {
 enum Anchor {case contents}
 static func currentReader(_ manager:iOSNavigationManager)->ReaderViewModel? {
  let tabs=manager.openTabs.filter{$0.id==manager.activeTabId}
  return tabs.count==1 ? tabs[0].viewModel:nil
 }
 static func captureOriginalSource(_ anchor:Anchor,manager:iOSNavigationManager) throws -> @MainActor () throws -> Void {
  guard let reader=currentReader(manager) else{throw UIRouteError(.staleState,"boundary_reader")}
  let proof=NativeComponentSourceObservation {
   _=manager.activeTabId;_=manager.openTabs;_=reader.originalTOCRevision
  }
  return {try proof.validate();guard currentReader(manager) === reader else{throw UIRouteError(.staleState,"boundary_reader_changed")}}
 }
}
""".replace("__ORIGINAL_SETTER__",setter)
controls=r"""
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
"""
actual_phone=phone.replace("#if os(iOS)\n","",1).removesuffix("#endif\n").replace("import OtzariaUIRouting\n","")
actual_latch=latch.replace("import OtzariaUIRouting\n","")
parts={"ActualPhone.swift":actual_phone,"ActualObservation.swift":actual_latch,"ActualContracts.swift":contracts,
 "ActualOriginalSetter.swift":setter,"Boundary.swift":boundary,"Controls.swift":controls}
for name,text in parts.items():(out/name).write_text(text+"\n")
combined="import Foundation\nimport Observation\nimport Synchronization\n"+contracts+"\n"+boundary+"\n"+actual_latch+"\n"+actual_phone+"\n"+controls
(out/"Combined.swift").write_text(combined)
binary=Path("/mnt/development/projects/diagnostics/otzaria-wave3-toc-oracle-20261127")/("phone-lifecycle-"+out.name)
cmd=["/usr/local/bin/swiftc","-swift-version","6","-strict-concurrency=complete","-parse-as-library",str(out/"Combined.swift"),"-o",str(binary)]
compile=subprocess.run(cmd,capture_output=True,text=True);(out/"compile.log").write_text(compile.stdout+compile.stderr)
run=None
if compile.returncode==0:
 run=subprocess.run([str(binary)],capture_output=True,text=True);(out/"execution.log").write_text(run.stdout+run.stderr)
result={"at":datetime.datetime.now(datetime.timezone.utc).isoformat(),"scope":"Actual phone lifecycle source + actual shared Observation + exact original manager setter; explicit app-domain storage/source/transport boundaries; NOT Apple SDK/UI/backend test","product_source_sha256":hashlib.sha256(phone.encode()).hexdigest(),"parts":{n:hashlib.sha256((out/n).read_bytes()).hexdigest() for n in parts},"transformations":["remove outer iOS conditional on Oracle","remove OtzariaUIRouting import; exact contracts compiled in same source","app-domain collaborators explicitly provided by Boundary.swift; actual original TOC source has separate proof"],"command":cmd,"compileExit":compile.returncode,"runExit":None if run is None else run.returncode,"output":"" if run is None else run.stdout,"nativeUIExecuted":0,"physicalExecuted":0}
(out/"RESULT.json").write_text(json.dumps(result,indent=2)+"\n")
print(json.dumps(result))
