from pathlib import Path
import hashlib,json,re,shutil,sys
root=Path(__file__).resolve().parents[1]
source=root/'source'
binding_mode='--binding' in sys.argv
out=root/'controls'/('binding-inputs' if binding_mode else 'candidate-inputs')
out.mkdir(exist_ok=True)
pins=[];segments=[]
def take(path):
 b=(source/path).read_bytes();pins.append({'path':path,'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()});return b.decode()
def block(text,start):
 a=text.index(start);begin=a;parens=0;state='code'
 while begin<len(text):
  c=text[begin]
  if state=='string':
   if c=='\\':begin+=1
   elif c=='\"':state='code'
  elif c=='\"':state='string'
  elif c=='(':parens+=1
  elif c==')':parens-=1
  elif c=='{' and parens==0:break
  begin+=1
 depth=0;i=begin;state='code'
 while i<len(text):
  c=text[i];n=text[i:i+2]
  if state=='line':
   if c=='\n':state='code'
  elif state=='comment':
   if n=='*/':state='code';i+=1
  elif state=='string':
   if c=='\\':i+=1
   elif c=='"':state='code'
  else:
   if n=='//':state='line';i+=1
   elif n=='/*':state='comment';i+=1
   elif c=='"':state='string'
   elif c=='{':depth+=1
   elif c=='}':
    depth-=1
    if depth==0:
     result=text[a:i+1];segments.append({'start':start,'sha256':hashlib.sha256(result.encode()).hexdigest(),'bytes':len(result.encode())});return result
  i+=1
 raise ValueError(start)
models={'Source/LibraryBackend/LibraryBackendModels.swift':'020-LibraryBackendModels.swift', 'Source/ChavrusaText/Navigation/BackendSessionIntegrityRepair.swift':'011-BackendSessionIntegrityRepair.swift'}
for path,peer in models.items():
 f=source/path
 if not f.exists():f.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(root/'peer-controls'/peer,f)
files=['Source/LibraryBackend/LibraryBackendModels.swift','Source/ChavrusaText/Navigation/BackendSessionIntegrityRepair.swift','Source/ChavrusaText/StudyWorkspace/StudyWorkspaceModels.swift','Source/ChavrusaText/StudyWorkspace/StudyWorkspacePersistence.swift','Source/ChavrusaText/StudyWorkspace/StudyWorkspaceStore.swift','Source/ChavrusaText/StudyWorkspace/StudyWorkspaceMappingOwnership.swift','Source/ChavrusaText/StudyWorkspace/StudyWorkspaceTabSelectionReservation.swift','Source/ChavrusaText/StudyWorkspace/StudyWorkspaceGroupSelectionReservation.swift','Source/ChavrusaText/StudyWorkspace/StudyWorkspacePreparedGroupSelection.swift','Source/ChavrusaText/Navigation/ReaderContentLoadCoordinator.swift','Source/Core/AppCoordinator/AppMode.swift','Source/ChavrusaText/Navigation/BackendNavigationAdapter.swift']
for path in files:(out/Path(path).name).write_text(take(path))
a=take('Source/ChavrusaText/StudyWorkspace/StudyWorkspaceNavigationAdapter.swift')
a=a.replace('import SwiftUI\nimport Combine\n','import Foundation\nimport Observation\n',1)
a+='''\n// Explicit fixture attachment only; does not replace the original native selection functions.\nextension StudyWorkspaceNavigationAdapter {\n    func fixtureConnect(_ manager: iOSNavigationManager, groupID: UUID) {\n        bindMappingOwner(manager); attached = true\n        setMappingLiveContext(groupID: groupID, backend: BackendCoordinator.shared.activeBackendID, manager: manager)\n    }\n    func fixtureCache(_ tabs: [iOSNavigationManager.ReaderTab], groupID: UUID) { cache[groupID, default: [:]][BackendCoordinator.shared.activeBackendID] = tabs }\n}\n'''
if binding_mode:
 a+='''\nextension StudyWorkspaceNavigationAdapter {\n    func fixtureGroupReservation() -> StudyWorkspaceNativeGroupSelectionReservation? { groupSelectionReservation }\n}\n'''
(out/'ActualAdapterBoundary.swift').write_text(a)
manager=take('Source/UI/iOS/Managers/iOSNavigationManager.swift')
coordinator=take('Source/LibraryBackend/BackendCoordinator.swift')
t=(root/'controls'/'Boundary.template.swift').read_text()
substitutions={
'ACTUAL_PREPARED_BACKEND_TRANSITION':block(coordinator,'struct PreparedBackendTransition'),
'ACTUAL_BACKEND_TRANSITION_ERROR':block(coordinator,'enum BackendTransitionError'),
'ACTUAL_SNAPSHOT_PROTOCOL':block(coordinator,'protocol BackendSnapshotStaging'),
'ACTUAL_COMMIT_PREPARED':block(coordinator,'    func commitPreparedSameBackend('),
'ACTUAL_COMMITTED_TERMINAL':block(coordinator,'    private func performCommittedBackendPublication('),
'ACTUAL_SELECTED_BOOK':block(manager,'    var selectedBook: BooksData?'),
'ACTUAL_CURRENT_MODE':block(manager,'    var currentMode: AppMode'),
'ACTUAL_BOOK_METADATA':'    private(set) var selectedBookPresentationRevision: UInt64? = 0\n    private(set) var selectedBookPresentationMode: AppMode?',
'ACTUAL_OPEN_TABS':block(manager,'    var openTabs: [ReaderTab]'),
'ACTUAL_ACTIVE_TAB':block(manager,'    var activeTabId: UUID?'),
'ACTUAL_SHOWING_TABS':block(manager,'    var showingTabsList: Bool'),
'ACTUAL_SELECT_TAB':block(manager,'    func selectTab(id: UUID)'),
'ACTUAL_CLOSE_TAB':block(manager,'    func closeTab(id: UUID)')}
for marker,value in substitutions.items():
 assert t.count('// '+marker)==1,marker
 t=t.replace('// '+marker,value)
(out/'ExplicitDomainBoundary.swift').write_text(t)
if binding_mode:
 for path in ['Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeWorkspaceOwner.swift',
              'Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeSurfaceState.swift',
              'Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeComponentSourceObservation.swift',
              'Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeWorkspaceSelectionIntentService.swift']:
  (out/Path(path).name).write_text(take(path))
 path='Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeWorkspaceSelectionBinding.swift'
 b=take(path);assert b.startswith('#if os(iOS)\n') and b.endswith('#endif\n')
 b=b[len('#if os(iOS)\n'):-len('#endif\n')].replace('import SwiftUI\n','').replace('import ChavrusaUIRoutingHost\n','')
 (out/'ActualWorkspaceSelectionBinding.swift').write_text(b)
 original=take('Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSearchEntry.swift')
 projection=take('Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneProjection.swift')
 t=(root/'controls'/'IntegrationBoundary.template.swift').read_text()
 t=t.replace('// ACTUAL_ROOT_PUBLICATION_SOURCE',block(original,'@MainActor\nfinal class MaktabahNativeRootPublicationSource'))
 t=t.replace('// ACTUAL_SURFACE_ENUM',block(projection,'enum Surface'))
 (out/'ExplicitIntegrationBoundary.swift').write_text(t)
 (out/'GroupBindingControls.swift').write_text((root/'controls'/'GroupBindingControls.swift').read_text())
 t=(root/'controls'/'GroupOwnerControls.swift').read_text()
 marker='        print("RESULT "'
 assert t.count(marker)==1
 t=t.replace(marker,'        let additional = await GroupBindingControls.run(); passed += additional.0; failed += additional.1\n'+marker)
 (out/'GroupOwnerControls.swift').write_text(t)
else:
 (out/'GroupOwnerControls.swift').write_text((root/'controls'/'GroupOwnerControls.swift').read_text())
(out/'SOURCE_INPUTS.json').write_text(json.dumps({'base':'aa5092cd9452c242a21b49442398e4c645a0d757','scope':'actual source; explicit Apple/Combine/resolver/rendering boundaries; not app/native','files':pins,'segments':segments},indent=2)+'\n')
print(json.dumps({'inputs':len(pins),'segments':len(segments),'bytes':sum(p.stat().st_size for p in out.iterdir())}))
