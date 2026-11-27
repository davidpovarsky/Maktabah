from pathlib import Path
import hashlib,json,re,shutil,zipfile
B=Path(__file__).resolve().parent
R=B.parent/'wave3-all-original-entry-wiring'
P='Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneSession.swift'
pins={
 'baseline':('preserved-before-history-search-publication','5d3c30b6a119ce445cc343b17ff7c3aad7e70a0bb49b9d56622007d6d3da91f8'),
 'intermediate':('preserved-before-unmount-order-fix','bbf93e364f006428f1db86de7845ab1f6ecb4a2bfca0366c3ea00246c65e3ea7'),
 'candidate':('candidate','a77dd4223cf3a9c8336d405e45690b02016a022031b9002a5b97bb795650a4d9')}
sha=lambda b:hashlib.sha256(b).hexdigest()
def method(s,name):
 hits=list(re.finditer(r'\bfunc\s+'+name+r'\s*\(',s));assert len(hits)==1,(name,len(hits))
 a=s.rfind('\n',0,hits[0].start())+1;j=s.index('{',hits[0].start())+1;d=1
 while d:
  if s[j]=='{':d+=1
  if s[j]=='}':d-=1
  j+=1
 return s[a:j]
inputs=B/'inputs';inputs.mkdir(exist_ok=True)
manifest=[]
for variant,(sub,pin)in pins.items():
 raw=(R/sub/P).read_bytes();assert sha(raw)==pin
 original=inputs/variant/'OriginalSession.swift';original.parent.mkdir(parents=True,exist_ok=True);original.write_bytes(raw)
 s=raw.decode();names=['observeSearchPresentation','originalSearchPresentationWillChange','removeSearchPresentation','captureHistoryReaderWindow','unmount']
 if variant!='baseline':names+=['advanceOriginalSearchPresentationPublication','retainHistorySearchPresentationObservation']
 else:assert 'retainHistorySearchPresentationObservation'not in s and 'searchPresentationPublicationRevision'not in s
 methods=[method(s,n)for n in names]
 out='import Foundation\n@MainActor final class MaktabahNativeSceneSession {\n'+(B/'SessionFields.swift').read_text()+'\n'+'\n\n'.join(methods)+'\n}\n'
 (inputs/variant/'SessionCapsule.swift').write_text(out)
 manifest.append({'variant':variant,'original':str(original.relative_to(inputs)),'original_bytes':len(raw),'original_sha256':pin,'capsule':variant+'/SessionCapsule.swift','capsule_sha256':sha(out.encode()),'methods':[{'name':n,'bytes':len(b.encode()),'sha256':sha(b.encode())}for n,b in zip(names,methods)],'baseline_note':'Actual old caller has no new helper; no synthetic baseline helper is compiled.'if variant=='baseline'else'Exact source helper and actual full caller/unmount.'})
for f in ['BoundaryFixtures.swift','Controls.swift','SessionFields.swift']:
 shutil.copyfile(B/f,inputs/f)
for f in ['HISTORY_SEARCH_PUBLICATION_EDITS.json','HISTORY_SEARCH_PUBLICATION_FIX.json','HISTORY_UNMOUNT_ORDER_FIX.json']:
 shutil.copyfile(R/f,inputs/f)
(inputs/'SOURCE_INPUTS.json').write_text(json.dumps({'sources':manifest,'boundary':'Exact Session helper/original callbacks/full captureHistoryReaderWindow/full unmount over explicit stable app/UIKit/window/store/model boundaries. No synthesized old helper; no native or Core effect.'},indent=2)+'\n')
rows=[]
for p in sorted(inputs.rglob('*')):
 if p.is_file():b=p.read_bytes();rows.append({'path':str(p.relative_to(inputs)),'bytes':len(b),'sha256':sha(b)})
(B/'INPUTS_MANIFEST.json').write_text(json.dumps({'files':rows},indent=2)+'\n')
with zipfile.ZipFile(B/'INPUTS.zip','w',zipfile.ZIP_DEFLATED,9)as z:
 for row in rows:z.writestr(row['path'],(inputs/row['path']).read_bytes())
 z.writestr('INPUTS_MANIFEST.json',(B/'INPUTS_MANIFEST.json').read_bytes())
b=(B/'INPUTS.zip').read_bytes();print(json.dumps({'bytes':len(b),'sha256':sha(b),'sources':[(r['variant'],r['original_sha256'])for r in manifest],'files':len(rows)}))
