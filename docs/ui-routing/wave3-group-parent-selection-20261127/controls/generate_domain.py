from pathlib import Path
import ast,hashlib,json

root=Path(__file__).resolve().parents[1]
previous=root.parent/'profile-group-implementation/controls'
original=root/'original-inputs'
candidate=root/'source'
out=root/'controls/domain-inputs';out.mkdir(exist_ok=True)
pins=[];segments=[]
text=(previous/'generate.py').read_text();tree=ast.parse(text)
function=next(x for x in tree.body if isinstance(x,ast.FunctionDef) and x.name=='block')
exec(compile(''.join(text.splitlines(keepends=True)[function.lineno-1:function.end_lineno]),'original-exact-extractor','exec'))
def take(path,which=original):
    b=(which/path).read_bytes();pins.append({'path':path,'origin':which.name,'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()});return b.decode()
def write(name,value): (out/name).write_text(value)
def unguard(s):
    assert s.startswith('#if os(iOS)\n') and s.endswith('#endif\n')
    return s[12:-7].replace('import SwiftUI\n','').replace('import UIKit\n','')

files=['Source/LibraryBackend/LibraryBackendModels.swift','Source/ChavrusaText/Navigation/BackendSessionIntegrityRepair.swift',
'Source/ChavrusaText/StudyWorkspace/StudyWorkspaceModels.swift','Source/ChavrusaText/StudyWorkspace/StudyWorkspacePersistence.swift',
'Source/ChavrusaText/StudyWorkspace/StudyWorkspaceStore.swift','Source/ChavrusaText/StudyWorkspace/StudyWorkspaceMappingOwnership.swift',
'Source/ChavrusaText/StudyWorkspace/StudyWorkspaceTabSelectionReservation.swift','Source/ChavrusaText/StudyWorkspace/StudyWorkspaceGroupSelectionReservation.swift',
'Source/ChavrusaText/StudyWorkspace/StudyWorkspacePreparedGroupSelection.swift','Source/ChavrusaText/Navigation/ReaderContentLoadCoordinator.swift',
'Source/Core/AppCoordinator/AppMode.swift','Source/ChavrusaText/Navigation/BackendNavigationAdapter.swift',
'Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeWorkspaceOwner.swift']
for p in files:
    value=take(p)
    if p.endswith('/AppMode.swift'):value=value.replace('    #if os(iOS)\n','').replace('    #endif\n','')
    write(Path(p).name,value)
a=take('Source/ChavrusaText/StudyWorkspace/StudyWorkspaceNavigationAdapter.swift')
a=a.replace('import SwiftUI\nimport Combine\n','import Foundation\nimport Observation\n',1)
old=(previous/'binding-inputs/ActualAdapterBoundary.swift').read_text()
fixture=old[old.index('// Explicit fixture attachment only;'):]
write('ActualAdapterBoundary.swift',a+'\n'+fixture)

manager=take('Source/UI/iOS/Managers/iOSNavigationManager.swift')
coordinator=take('Source/LibraryBackend/BackendCoordinator.swift')
t=(previous/'Boundary.template.swift').read_text()
substitutions={
'ACTUAL_PREPARED_BACKEND_TRANSITION':block(coordinator,'struct PreparedBackendTransition'),
'ACTUAL_BACKEND_TRANSITION_ERROR':block(coordinator,'enum BackendTransitionError'),
'ACTUAL_SNAPSHOT_PROTOCOL':block(coordinator,'protocol BackendSnapshotStaging'),
'ACTUAL_COMMIT_PREPARED':block(coordinator,'    func commitPreparedSameBackend('),
'ACTUAL_COMMITTED_TERMINAL':block(coordinator,'    private func performCommittedBackendPublication('),
'ACTUAL_SELECTED_BOOK':block(manager,'    var selectedBook: BooksData?'),
'ACTUAL_CURRENT_MODE':block(manager,'    var currentMode: AppMode'),
'ACTUAL_BOOK_METADATA':'    @ObservationIgnored private weak var activeReaderTabPresentation: ActiveReaderTabPresentation?\n    private(set) var selectedBookPresentationRevision: UInt64? = 0\n    private(set) var selectedBookPresentationMode: AppMode?',
'ACTUAL_OPEN_TABS':block(manager,'    var openTabs: [ReaderTab]'),
'ACTUAL_ACTIVE_TAB':block(manager,'    var activeTabId: UUID?'),
'ACTUAL_SHOWING_TABS':block(manager,'    var showingTabsList: Bool'),
'ACTUAL_SELECT_TAB':block(manager,'    func selectTab(id: UUID)')+'\n'+block(manager,'    private func presentOriginalSelectedTab(')+'\n'+block(manager,'    func retainActiveReaderTabPresentation(')+'\n'+block(manager,'    @MainActor final class ActiveReaderTabPresentation')+'\n'+block(manager,'    func switchToMode('),
'ACTUAL_CLOSE_TAB':block(manager,'    func closeTab(id: UUID)')}
for key,value in substitutions.items():assert t.count('// '+key)==1;t=t.replace('// '+key,value)
write('ExplicitDomainBoundary.swift',t)

entry=take('Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSearchEntry.swift')
projection=take('Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneProjection.swift')
t=(previous/'IntegrationBoundary.template.swift').read_text()
t=t.replace('import OtzariaUIRouting\n','import OtzariaUIRouting\nimport ChavrusaUIRoutingHost\n')
t=t.replace('enum iOSTab { case viewer, history, search }','''enum iOSTab: Equatable {
    case viewer, history, search
    var canonical: Self { self }
    var appMode: AppMode { switch self { case .viewer: .viewer; case .history: .history; case .search: .search } }
}''')
t=t.replace('// ACTUAL_ROOT_PUBLICATION_SOURCE',block(entry,'@MainActor\nfinal class MaktabahNativeRootPublicationSource'))
t=t.replace('// ACTUAL_SURFACE_ENUM',block(projection,'enum Surface'))
write('ExplicitIntegrationBoundary.swift',t)

session=take('Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneSession.swift',root/'baseline')
write('ActualWindowSource.swift','import Foundation\nimport OtzariaUIRouting\n'+block(session,'@MainActor final class MaktabahNativeWindowSource')+'\n')
write('ActualWindowObservation.swift',unguard(take('Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeWindowObservation.swift')))
for name in ['MaktabahNativeViewerParentContinuation.swift','MaktabahNativeWorkspaceSelectionBinding.swift']:
    write(name,unguard(take('Source/ChavrusaText/UIRoutingHost/Integration/'+name,candidate)))
baseline=unguard(take('Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeWorkspaceSelectionBinding.swift',root/'baseline'))
write('OriginalBeforeFeatureBinding.swift',baseline.replace('MaktabahNativeWorkspaceSelectionBinding','OriginalBeforeFeatureBinding'))

fixture=(previous/'GroupOwnerControls.swift').read_text().split('@main struct GroupOwnerControls')[0]
write('OriginalGroupFixture.swift',fixture)
for name in ['ParentBoundary.swift','ParentDomainControls.swift']:write(name,(root/'controls'/name).read_text())
manifest={'base':'37caafcfaa4eb9b7bcfd02857bcb7c3f62daa4be','scope':'Actual complete Group binding, Viewer owner, original Store/persistence/Adapter/same-backend terminal and exact original manager hooks; explicit Apple/resolver/Reader-rendering shells. No native acceptance.',
 'files':pins,'segments':segments,'transforms':['Only iOS guard and unavailable SwiftUI/UIKit imports removed for control compilation; Foundation/Observation boundaries declared.',
 'Complete original Adapter imports replaced by Foundation/Observation, plus preexisting explicit fixture-attachment extension.',
 'OriginalBeforeFeatureBinding differs only in class name and unavailable imports/outer OS guard. No original body change.',
 'Original selectTab, presentOriginalSelectedTab, ActiveReaderTabPresentation, switchToMode, closeTab and live setters are exact source segments.', 'AppMode original iOS cases enabled by removing only its conditional directives for the Linux boundary.']}
write('SOURCE_INPUTS.json',json.dumps(manifest,indent=2)+'\n')
print(json.dumps({'files':len(pins),'segments':len(segments),'bytes':sum(p.stat().st_size for p in out.iterdir())}))
