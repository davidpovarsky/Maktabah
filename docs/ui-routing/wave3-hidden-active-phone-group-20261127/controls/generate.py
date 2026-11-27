from pathlib import Path
import ast,hashlib,json,shutil
root=Path(__file__).resolve().parents[1];original=root/'original-inputs';out=root/'controls/inputs';out.mkdir(exist_ok=True)
previous=root.parent/'profile-group-parent-implementation/controls/domain-inputs'
basegen=(root.parent/'profile-group-implementation/controls/generate.py').read_text();tree=ast.parse(basegen);function=next(x for x in tree.body if isinstance(x,ast.FunctionDef)and x.name=='block')
segments=[];exec(compile(''.join(basegen.splitlines(keepends=True)[function.lineno-1:function.end_lineno]),'exact-existing-source-extractor','exec'))
pins=[]
def take(path,source=original):
 b=(source/path).read_bytes();pins.append({'path':path,'origin':source.name,'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()});return b.decode()
def write(n,v):q=out/n;q.parent.mkdir(parents=True,exist_ok=True);q.write_text(v)
def unguard(v):
 assert v.startswith('#if os(iOS)\n')and v.endswith('#endif\n');return v[12:-7].replace('import SwiftUI\n','').replace('import UIKit\n','')
files=['Source/LibraryBackend/LibraryBackendModels.swift','Source/ChavrusaText/Navigation/BackendSessionIntegrityRepair.swift',
'Source/ChavrusaText/StudyWorkspace/StudyWorkspaceModels.swift','Source/ChavrusaText/StudyWorkspace/StudyWorkspacePersistence.swift',
'Source/ChavrusaText/StudyWorkspace/StudyWorkspaceStore.swift','Source/ChavrusaText/StudyWorkspace/StudyWorkspaceMappingOwnership.swift',
'Source/ChavrusaText/StudyWorkspace/StudyWorkspaceTabSelectionReservation.swift','Source/ChavrusaText/StudyWorkspace/StudyWorkspacePreparedGroupSelection.swift',
'Source/ChavrusaText/Navigation/ReaderContentLoadCoordinator.swift','Source/ChavrusaText/Navigation/ReaderInitialContentRequest.swift',
'Source/Core/AppCoordinator/AppMode.swift','Source/ChavrusaText/Navigation/BackendNavigationAdapter.swift',
'Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeWorkspaceOwner.swift',
'Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeComponentSourceObservation.swift']
for p in files:
 value=take(p)
 if p.endswith('/AppMode.swift'):value=value.replace('    #if os(iOS)\n','').replace('    #endif\n','')
 write('common/'+Path(p).name,value)
for origin in ['baseline','candidate']:
 for p in ['Source/ChavrusaText/StudyWorkspace/StudyWorkspaceGroupSelectionReservation.swift','Source/ChavrusaText/StudyWorkspace/StudyWorkspaceNavigationAdapter.swift','Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeWorkspaceSelectionBinding.swift']:
  value=take(p,root/origin)
  if p.endswith('/StudyWorkspaceNavigationAdapter.swift'):
   value=value.replace('import SwiftUI\nimport Combine\n','import Foundation\nimport Observation\n',1)
   fixture=(previous/'ActualAdapterBoundary.swift').read_text();fixture=fixture[fixture.index('// Explicit fixture attachment only;'):];value+='\n'+fixture
  elif p.endswith('/MaktabahNativeWorkspaceSelectionBinding.swift'):value=unguard(value)
  write(origin+'/'+Path(p).name,value)
manager=take('Source/UI/iOS/Managers/iOSNavigationManager.swift');coordinator=take('Source/LibraryBackend/BackendCoordinator.swift')
t=(root.parent/'profile-group-implementation/controls/Boundary.template.swift').read_text()
sub={
'ACTUAL_PREPARED_BACKEND_TRANSITION':block(coordinator,'struct PreparedBackendTransition'),
'ACTUAL_BACKEND_TRANSITION_ERROR':block(coordinator,'enum BackendTransitionError'),
'ACTUAL_SNAPSHOT_PROTOCOL':block(coordinator,'protocol BackendSnapshotStaging'),
'ACTUAL_COMMIT_PREPARED':block(coordinator,'    func commitPreparedSameBackend('),
'ACTUAL_COMMITTED_TERMINAL':block(coordinator,'    private func performCommittedBackendPublication('),
'ACTUAL_SELECTED_BOOK':block(manager,'    var selectedBook: BooksData?'),
'ACTUAL_CURRENT_MODE':'    @ObservationIgnored let nativeModePresentationPublication = NativeComponentSourcePublication()\n'+block(manager,'    var currentMode: AppMode'),
'ACTUAL_BOOK_METADATA':'    @ObservationIgnored private weak var activeReaderTabPresentation: ActiveReaderTabPresentation?\n    private(set) var selectedBookPresentationRevision: UInt64? = 0\n    private(set) var selectedBookPresentationMode: AppMode?',
'ACTUAL_OPEN_TABS':block(manager,'    var openTabs: [ReaderTab]'),
'ACTUAL_ACTIVE_TAB':block(manager,'    var activeTabId: UUID?'),
'ACTUAL_SHOWING_TABS':block(manager,'    var showingTabsList: Bool'),
'ACTUAL_SELECT_TAB':'\n'.join(block(manager,start)for start in ['    func selectTab(id: UUID)','    private func presentOriginalSelectedTab(','    func retainActiveReaderTabPresentation(','    @MainActor final class ActiveReaderTabPresentation','    func switchToMode(']),
'ACTUAL_CLOSE_TAB':block(manager,'    func closeTab(id: UUID)')}
for k,v in sub.items():assert t.count('// '+k)==1;t=t.replace('// '+k,v)
# Existing Reader/render/backend boundaries stay explicit. Cold load execution
# is not covered here; accidental use fails instead of fabricating completion.
t=t.replace('    func loadBackendContent(_ locator: TextLocator) {','    func loadBackendContent(_ locator: TextLocator, continuing: ReaderInitialContentRequest? = nil) {\n        precondition(continuing == nil, "Cold execution outside hidden-loaded controls")')
t=t.replace('    func loadInitialContent(initialContentId: Int?) { loadCalls += 1 }','    func loadInitialContent(initialContentId: Int?, continuing: ReaderInitialContentRequest? = nil) { preconditionFailure("Cold initial execution outside hidden-loaded controls") }')
content=take('Source/Features/Reader/ViewModel/Extensions/Reader+Content.swift')
start='    func loadTOC(book: BooksData) { let callback = duringTOC; duringTOC = nil; callback?() }'
assert t.count(start)==1
t=t.replace(start,'\n'.join(block(content,s)for s in ['    func makeInitialContentRequest(','    func makeBackendContentRequest(','    private func contentRequestSource(','    private func makeContentRequest('])+'\n'+start)
t=t.replace('    func id(for locator: TextLocator) -> Int { 523 }','    func id(for locator: TextLocator) -> Int { 523 }\n    func locator(for id: Int) -> TextLocator? { nil }')
write('common/ExplicitDomainBoundary.swift',t)
# Current exact native root/scene/Viewer bodies, over the previously declared
# geometry boundary. A geometry value here is never native runtime evidence.
t=(previous/'ExplicitIntegrationBoundary.swift').read_text()
entry=take('Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSearchEntry.swift')
old=block(t,'@MainActor\nfinal class MaktabahNativeRootPublicationSource');new=block(entry,'@MainActor\nfinal class MaktabahNativeRootPublicationSource');t=t.replace(old,new)
projection=take('Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneProjection.swift');old=block(t,'enum Surface');t=t.replace(old,block(projection,'enum Surface'))
write('common/ExplicitIntegrationBoundary.swift',t)
session=take('Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneSession.swift')
write('common/ActualWindowSource.swift','import Foundation\nimport OtzariaUIRouting\n'+block(session,'@MainActor final class MaktabahNativeWindowSource')+'\n')
for n in ['MaktabahNativeWindowObservation.swift','MaktabahNativeViewerParentContinuation.swift']:
 write('common/'+n,unguard(take('Source/ChavrusaText/UIRoutingHost/Integration/'+n)))
write('common/OriginalGroupFixture.swift',(previous/'OriginalGroupFixture.swift').read_text())
t=(previous/'ParentBoundary.swift').read_text()
t=t.replace('from: iOSTab = .history) throws {','from: iOSTab = .history, sameGroup: Bool = false) throws {')
t=t.replace('base = try GroupBindingFixture(empty: empty, profile: profile, phone: phone)','base = try GroupBindingFixture(empty: empty, profile: profile && !sameGroup, phone: phone, sameGroup: sameGroup)')
a=t.index('    func retainBeforeFeature()');b=t.index('    func prepare(',a);t=t[:a]+t[b:]
write('common/ParentBoundary.swift',t)
write('common/HiddenGroupControls.swift',(root/'controls/HiddenGroupControls.swift').read_text())
write('SOURCE_INPUTS.json',json.dumps({'base':'b463ffd03a76026cea06c79c608df97d00094152','files':pins,'segments':segments,
 'scope':'Actual complete three product files, original Manager select/presentation/setters, Store/persistence/mapping, coordinator/request, complete Viewer binding and window source. Declared UIKit/SwiftUI/domain/resolver/Reader rendering and session persistence boundaries; no app/SDK/native qualification.',
 'transforms':['Only iOS outer guards and unavailable Apple imports removed; original complete Adapter adds prior fixture-connect/cache/read-only reservation accessors.',
 'Actual original Manager methods and setters compiled verbatim over explicit storage shell; session persistence method is an explicit call recorder, not file/native proof.',
 'Actual original Reader initial handle factory helpers compiled verbatim; cold execution intentionally fatal at explicit Reader shell and not covered in this capsule.',
 'Baseline/candidate use SAME controls and exact current Manager. Existing Group fixtures preserved; Parent fixture only adds sameGroup construction.']},indent=2)+'\n')
print(json.dumps({'pins':len(pins),'segments':len(segments),'files':len(list(out.rglob('*.swift')))}))
