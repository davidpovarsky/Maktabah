from pathlib import Path
import json,hashlib,re,difflib
B=Path(__file__).parent; E=B/'evidence';E.mkdir(exist_ok=True)
def sha(b):return hashlib.sha256(b).hexdigest()
def body(s,name):
 matches=list(re.finditer(r'\bfunc\s+'+re.escape(name)+r'\s*\(',s));assert len(matches)==1,(name,len(matches))
 a=matches[0].start();i=s.index('{',a);j=i+1;depth=1
 while depth:
  if s[j]=='{':depth+=1
  elif s[j]=='}':depth-=1
  j+=1
 return s[a:j]
rows=[]
for relative,names in [
('Source/Features/Bookmarks/iOS/iOSSavedResultsView.swift',['commitRename','loadResult','folder','result','newFolder']),
('Source/Features/Search/iOS/SearchModeView.swift',['submitSearch','compactFilterView','searchRegularEmptyState','searchResultsView','ftsMigrationBanner'])]:
 before=(B/'baseline'/relative).read_text();after=(B/'candidate'/relative).read_text()
 for n in names:
  a=body(before,n).encode();b=body(after,n).encode();assert a==b,(relative,n)
  rows.append({'path':relative,'method':n,'bytes':len(a),'sha256':sha(a),'byte_identical':True})
# Whole original shared owner/loads reconstruct exactly by removing ONLY metadata.
p='Source/Features/Bookmarks/ViewModel/ResultsViewModel.swift';b=(B/'candidate'/p).read_bytes();a=(B/'baseline'/p).read_bytes()
assert b.replace(b'    let nativeLoadLifetime = OriginalSavedResultsLoadLifetime()\n',b'')==a
rows.append({'path':p,'inverse':'remove one passive metadata member','bytes':len(a),'sha256':sha(a),'byte_identical_inverse':True})
p='Source/Features/Bookmarks/ViewModel/Extensions/Results+Load.swift';b=(B/'candidate'/p).read_bytes();a=(B/'baseline'/p).read_bytes();pair=b'        let nativeLoad = nativeLoadLifetime.beginOriginalLoad()\n        defer { nativeLoadLifetime.endOriginalLoad(nativeLoad, cancelled: Task.isCancelled) }\n'
assert b.count(pair)==2 and b.replace(pair,b'')==a
rows.append({'path':p,'inverse':'remove exactly two begin/defer metadata brackets','bytes':len(a),'sha256':sha(a),'byte_identical_inverse':True})
# All unmodified copied model files are original exact bytes, not product changes.
for p in sorted((B/'baseline/Source/Features/Bookmarks/Models').glob('*.swift')):
 relative=p.relative_to(B/'baseline');assert p.read_bytes()==(B/'candidate'/relative).read_bytes()
 rows.append({'path':str(relative),'bytes':p.stat().st_size,'sha256':sha(p.read_bytes()),'unchanged_whole_file':True})
(E/'ORIGINAL_EFFECTS.json').write_text(json.dumps(rows,indent=2)+'\n')
changes=[];diff=[]
for p in sorted((B/'candidate').rglob('*.swift')):
 relative=p.relative_to(B/'candidate');before=B/'baseline'/relative;a=before.read_bytes() if before.exists() else None;b=p.read_bytes()
 if a==b:continue
 row={'path':str(relative),'new':a is None,'bytes':len(b),'sha256':sha(b)}
 if a is not None:row.update(before_bytes=len(a),before_sha256=sha(a))
 upstream=B/'upstream'/relative
 if upstream.exists():row.update(upstream_ref='4203de5fd77beb119e5826e039be1a61325f7be0',upstream_sha256=sha(upstream.read_bytes()),baseline_matches_upstream=a==upstream.read_bytes())
 changes.append(row)
 diff+=difflib.unified_diff((a or b'').decode().splitlines(True),b.decode().splitlines(True),fromfile='a/'+str(relative),tofile='b/'+str(relative))
assert len(changes)==10 and sum(x['new']for x in changes)==6
(E/'PRODUCT_SOURCE_MANIFEST.json').write_text(json.dumps({'base':'24cd9291dbc87d799c22a41f0bc73a82c6415bfa','source_tree':'23cdfce49553927656ef79c6db10f654c889e2fc','files':changes},indent=2)+'\n')
(E/'PRODUCT_SOURCE.patch').write_text(''.join(diff))
# Shared Source remains proposed; the callback of interest is byte-unchanged.
P='Source/ChavrusaText/UIRoutingHost/Integration/';s=B/'shared-proposals'
base=(s/'baseline'/P/'MaktabahNativeSceneSession.swift').read_text();candidate=(s/'candidate'/P/'MaktabahNativeSceneSession.swift').read_text()
name='originalSearchPresentationWillChange';a=body(base,name);b=body(candidate,name);assert a==b
notes=body(candidate,'originalNoteEditorStateWillChange');assert 'savedResultsBinding?.retire()' in notes and 'savedResultsBinding' not in a
component_path=E/'remote/original-callback/NativeComponentRevealOwner.swift'
component_bytes=component_path.read_bytes()
assert sha(component_bytes)=='eacf05d1d8d2ec6599bc2f2b1f88c5478059a7cdc37befbfb6c7a7f32b0f4345'
component=component_bytes.decode()
search=(B/'original-write-paths'/P/'MaktabahNativeSearchEntry.swift').read_text()
proof={'base':'24cd9291dbc87d799c22a41f0bc73a82c6415bfa','session_sha256':sha(candidate.encode()),'original_search_callback':{'method':name,'sha256':sha(a.encode()),'body':a,'byte_unchanged':True},'notes_only_added_retire':{'body':notes,'sha256':sha(notes.encode())},'search_entry_original_callbacks':[{'name':n,'body':body(search,n),'sha256':sha(body(search,n).encode())}for n in ['originalPresentationWillChange','retire']],'original_component_retire':{'body':body(component,'retirePresentation'),'sha256':sha(body(component,'retirePresentation').encode()),'reference_path':'Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeComponentRevealOwner.swift','reference_kind':'retained source excerpt; original24cd Git join checked in final evidence transfer'},'history_session_callback_guard':'guard let self, retainedHistoryRecord else { return }','own_path_callback':'sheetStateDidPublish calls renderOriginalContainer and changed; Session changed notifies directory/graph without calling Saved retire','scope':'Exact source callback trace. Full SwiftUI/Session runtime remains unrun.'}
proof['original_component_retire'].update(reference_kind='Exact original24cd Git blob independently retrieved and byte-verified',full_source_sha256=sha(component_bytes),full_source_bytes=len(component_bytes),retained_source=str(component_path.relative_to(B)))
(E/'SHARED_CALLBACK_TRACE.json').write_text(json.dumps(proof,indent=2)+'\n')
print(json.dumps({'product_paths':len(changes),'new':sum(x['new']for x in changes),'preserved_methods':10,'exact_inverses':2,'unchanged_models':3,'manifest_sha256':sha((E/'PRODUCT_SOURCE_MANIFEST.json').read_bytes()),'callback_sha256':sha((E/'SHARED_CALLBACK_TRACE.json').read_bytes())}))
