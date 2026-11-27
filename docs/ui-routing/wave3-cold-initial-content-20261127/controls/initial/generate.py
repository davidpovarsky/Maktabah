from pathlib import Path
import hashlib,json

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'controls/inputs'
OUT.mkdir(exist_ok=True)
pins=[]
def record(path, kind, destination=None, transform=None):
    b=path.read_bytes();value=b if transform is None else transform(b.decode()).encode()
    target=OUT/(destination or path.name);target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(value)
    pins.append({'path':str(path.relative_to(ROOT)) if path.is_relative_to(ROOT) else str(path),
        'kind':kind,'sourceBytes':len(b),'sourceSHA256':hashlib.sha256(b).hexdigest(),
        'compiledPath':target.relative_to(OUT).as_posix(),'compiledBytes':len(value),'compiledSHA256':hashlib.sha256(value).hexdigest()})
def prefix(value):
    return value[:value.index('    func fetchBookInfo(')]+'}\n'
for which in ['baseline','candidate']:
    folder=ROOT/which
    record(folder/'Source/ChavrusaText/Navigation/ReaderContentLoadCoordinator.swift',which,
        which+'/ReaderContentLoadCoordinator.swift')
    record(folder/'Source/Features/Reader/ViewModel/Extensions/Reader+Content.swift',which,
        which+'/Reader+Content.swift',lambda s:prefix(s).replace('import OSLog\n',''))
record(ROOT/'candidate/Source/ChavrusaText/Navigation/ReaderInitialContentRequest.swift','candidate',
    'candidate/ReaderInitialContentRequest.swift')
# One explicit overflow fixture appended in the original coordinator's own file
# scope; no production source is altered or assertion disabled.
p=OUT/'candidate/ReaderContentLoadCoordinator.swift'
p.write_text(p.read_text()+'''\n// TEST-ONLY private-state overflow fixture; production prefix byte-exact.
extension ReaderContentLoadCoordinator {
    func testingSetInitialRevisionToMax() {
        lock.lock(); defer { lock.unlock() }; initialContentRevision = .max
    }
}
''')
pins[-3]['overflowFixtureAppended']=True
pins[-3]['compiledBytes']=p.stat().st_size
pins[-3]['compiledSHA256']=hashlib.sha256(p.read_bytes()).hexdigest()
adapter=ROOT/'candidate/Source/ChavrusaText/StudyWorkspace/StudyWorkspaceNavigationAdapter.swift'
record(adapter,'actual reservation class','candidate/ActualReaderSourceReservation.swift',lambda s:
    'import Foundation\n'+s[s.index('@MainActor final class StudyWorkspaceNativeGroupSelectionReservation {'):
    s.index('/// The R owner retains the actual original objects.')])
record(ROOT/'read-only/Source/ChavrusaText/Navigation/ReaderDestinationResolver.swift','original','common/ReaderDestinationResolver.swift')
record(ROOT.parent/'profile-group-parent-implementation/original-inputs/Source/LibraryBackend/LibraryBackendModels.swift',
    'original','common/LibraryBackendModels.swift')
for name in ['Boundary.swift','Controls.swift']:
    record(ROOT/'controls'/name,'explicit fixture','common/'+name)
record(ROOT/'controls/GroupBoundary.swift','explicit fixture','candidate/GroupBoundary.swift')
manifest={'base':'ce4fe5a327168524f6f1fef1e7792a275ece0ebe','files':pins,
    'scope':'Actual touched Reader content functions, coordinator/request, original model/resolver and complete Group Reader-source reservation. Explicit MainActor Reader/backend/Task suspension/rendering/Store/UI shells. No app SDK or native result.',
    'transforms':['Only unavailable OSLog import and unrelated fetchBookInfo/macOS tail omitted from the unchanged exact content prefix.',
        'Complete Group Reader-source reservation extracted verbatim; all other Store/native behavior is an explicit boundary.',
        'Test-only overflow accessor appended to coordinator; production prefix exact.',
        'Resolver SefariaRef parser is an explicit boundary; controls exercise Otzaria source only.']}
(OUT/'SOURCE_INPUTS.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps({'files':len(pins),'bytes':sum(p.stat().st_size for p in OUT.rglob('*')if p.is_file())}))
