import subprocess,json,hashlib,gzip,base64
repo='/mnt/development/projects/worktrees/Maktabah-wave3-vendor-admission-private-20261127'
source='24cd9291dbc87d799c22a41f0bc73a82c6415bfa';historical='d3da55417a30e9a06b0255e2d0b561955034b260';integration='08f50a5646b7669d15f8c53cb13c84ac504a02bd'
engine='99f7927e4da72f2463417f5c2de2c4d20c6aa168';resource='70810eec46ad1fec6f30d983bf31e5f922dacb61'
rn='791f88f2d2ba643ec39718a5f8b06106ef4af08b';rpc='c19b672d0b33d1f52ea459e303bb1fa5b83dd323';ledger='49a28bcc8d900169a81289f88a0491b02db597c9';retained='29a731e273f9a757c743c49e182fece0e8047d46'
def git(*a):return subprocess.check_output(['runuser','-u','ubuntu','--','git','-C',repo,*a],timeout=90,stderr=subprocess.PIPE)
def sha(b):return hashlib.sha256(b).hexdigest()
def canonical(v):return sha(json.dumps(v,sort_keys=True,separators=(',',':')).encode())
def entries(rev,path):
 d={}
 for r in git('ls-tree','-r','-z',rev,'--',path).split(b'\0'):
  if r:
   m,n=r.decode().split('\t');mode,kind,obj=m.split();d[n]={'mode':mode,'kind':kind,'object':obj}
 return d
def obj(rev,path):
 row=git('ls-tree',rev,'--',path).decode().strip()
 if not row:return None
 m,n=row.split('\t');assert n==path;mode,kind,oid=m.split();d={'mode':mode,'kind':kind,'object':oid}
 if kind=='blob':
  raw=git('show',rev+':'+path);d.update(bytes=len(raw),sha256=sha(raw))
 return d
def patch(a,b,path):
 raw=git('diff','--binary','--full-index','--no-ext-diff',a,b,'--',path);return {'bytes':len(raw),'sha256':sha(raw)}
before,after=entries(historical,'Vendor'),entries(source,'Vendor')
paths=sorted(p for p in before.keys()|after.keys() if before.get(p)!=after.get(p))
rows=[]
for path in paths:
 comp=retained if path=='Vendor/HanlinSDK' else (ledger if path.startswith('Vendor/Zayit') else (rpc if path.endswith('/chavrusaRPCFacade.js') else rn))
 history=([rn,rpc] if path.endswith('/chavrusaRPCFacade.js') else ([rn] if path.startswith('Vendor/Sefaria') else ([ledger] if path.startswith('Vendor/Zayit') else [])))
 steps=[]
 for c in history:
  parent=git('rev-parse',c+'^').decode().strip()
  steps.append({'source':c,'parent':parent,'before':obj(parent,path),'after':obj(c,path),'patch':patch(parent,c,path)})
 rows.append({'path':path,'classification':'EXISTING_SHARED_SDK_GITLINK' if path=='Vendor/HanlinSDK' else 'DOWNSTREAM_INTEGRATION','historical':obj(historical,path),'accepted':obj(source,path),'component':comp,'historical_patch':patch(historical,source,path),'component_steps':steps})
scopes={}
for label,rev,path in [('zayit',engine,'Vendor/ZayitSearchPort'),('sefaria',resource,'Vendor/SefariaMobile')]:
 b,a=entries(rev,path),entries(source,path);delta=sorted(p for p in b.keys()|a.keys() if b.get(p)!=a.get(p));preserved={p:b[p] for p in b if p not in delta};assert all(a.get(p)==v for p,v in preserved.items())
 scopes[label]={'producer':rev,'root':path,'producer_tree':git('rev-parse',rev+':'+path).decode().strip(),'accepted_tree':git('rev-parse',source+':'+path).decode().strip(),'producer_entries':len(b),'accepted_entries':len(a),'preserved_entries':len(preserved),'preserved_entries_sha256':canonical(preserved),'changes':[{'path':p,'before':obj(rev,p),'after':obj(source,p),'patch':patch(rev,source,p)} for p in delta]}
common_fields={'application_source_sha','application_trees','hanlin_gitlink','otzaria_test_additions_sha256','final_product_source'}
legacy_raw=git('show',source+':Scripts/CI/hq-stage2-focused-apple.inputs.json')
base=json.loads(git('show',integration+':Scripts/CI/hq-stage2-focused-apple.inputs.json'));common={k:v for k,v in base.items() if k not in common_fields}
js=[p for p in paths if p.startswith('Vendor/SefariaMobile/Integration/JS/')]
expected=dict(common);expected['embedded_js_overlay_paths']=js
proof=[]
for revision,path in [(rn,'docs/ui-routing/wave3-sefaria-native-surface-20261127/SOURCE_PROVENANCE.json'),(rn,'docs/ui-routing/wave3-sefaria-native-surface-20261127/README.md'),(ledger,'docs/hq-integration/wave2-20261127/library/search-page-ledger/PRODUCT_SOURCES.json'),(ledger,'docs/hq-integration/wave2-20261127/library/search-page-ledger/provenance/PATH_PROVENANCE.json'),(ledger,'docs/hq-integration/wave2-20261127/library/search-page-ledger/README.md'),(rpc,'tools/test_sefaria_late_reply_diagnostic.swift'),(rpc,'tools/test_sefaria_late_reply_diagnostic_js.mjs')]:
 proof.append({'source':revision,'path':path,'object':obj(revision,path)})
value={'schema':'otzaria.reviewed-vendor-source/1','scope':'EXACT_DOWNSTREAM_SOURCE_IDENTITY_AND_PRODUCER_ATTRIBUTION_ONLY','native_qualified':False,'reviewed_product_source':source,'historical_source':historical,'integration_base':integration,'vendor_tree':git('rev-parse',source+':Vendor').decode().strip(),'entries':rows,'preserved_inventory':{'historical_entries':len(before),'accepted_entries':len(after),'unchanged_entries':len(before)-len([p for p in paths if p in before]),'sha256':canonical({p:before[p] for p in before if p not in paths})},'producer_scopes':scopes,'build_inputs':{'baseline_common':common,'baseline_canonical_sha256':canonical(common),'accepted_canonical_sha256':canonical(expected),'single_reviewed_field':'embedded_js_overlay_paths','before':common['embedded_js_overlay_paths'],'after':js},'legacy_input_fixture':{'source':source,'path':'Scripts/CI/hq-stage2-focused-apple.inputs.json','bytes':len(legacy_raw),'sha256':sha(legacy_raw),'application_source_sha':json.loads(legacy_raw)['application_source_sha']},'evidence':proof}
raw=(json.dumps(value,indent=2,sort_keys=True)+'\n').encode()
packet=json.dumps({'contract':raw.decode(),'legacy_inputs':legacy_raw.decode()},separators=(',',':')).encode();packed=gzip.compress(packet,mtime=0)
print(json.dumps({'contract_bytes':len(raw),'contract_sha256':sha(raw),'packet_bytes':len(packet),'packet_sha256':sha(packet),'packed_bytes':len(packed),'packed_sha256':sha(packed),'payload':base64.b64encode(packed).decode()},separators=(',',':')))
