import subprocess,json,pathlib,hashlib,datetime
w=pathlib.Path('/mnt/development/projects/worktrees/Maktabah-wave3-integration-20261127')
out=w/'build/wave3-late-reply-capacity-intake-20261127-0856';out.mkdir(parents=True,exist_ok=False)
donors=['f03802af54b36bed1a326c6c0b197f60a6a04d34','8b5381ad1b1c4ff254b5db17ca1b8e34fd8e3129','e751ee7f3a751d78fb817daa8d0c31411a883244']
def g(*args):return subprocess.check_output(['git','-C',str(w),'-c','gc.auto=0','-c','maintenance.auto=false',*args])
assert g('rev-parse','HEAD').decode().strip()=='95a8e41c69da9add6e260d6b5afb20fe316fcfe4'
assert not g('status','--porcelain=v1')
cat=subprocess.Popen(['git','-C',str(w),'cat-file','--batch'],stdin=subprocess.PIPE,stdout=subprocess.PIPE)
def blob(spec):
 cat.stdin.write((spec+'\n').encode());cat.stdin.flush();h=cat.stdout.readline()
 if h.endswith(b' missing\n'):return None
 parts=h.split();assert parts[1]==b'blob',h
 n=int(parts[2]);b=cat.stdout.read(n);assert cat.stdout.read(1)==b'\n';return b
def sha(b):return hashlib.sha256(b).hexdigest()if b is not None else None
virtual={};packets=[]
for commit in donors:
 files=[]
 for path in g('diff-tree','--no-commit-id','--name-only','-r',commit).decode().splitlines():
  current=virtual[path]if path in virtual else blob('HEAD:'+path)
  base=blob(commit+'^:'+path);incoming=blob(commit+':'+path)
  assert current==base or current==incoming,('unreviewed-overlap',commit,path)
  virtual[path]=incoming
  files.append({'path':path,'mode':'exact-donor'if current==base else 'already-identical','beforeSHA256':sha(current),'baseSHA256':sha(base),'donorSHA256':sha(incoming),'expectedSHA256':sha(incoming),'expectedBytes':len(incoming)if incoming is not None else None})
 packets.append({'donor':commit,'files':files})
checks=[]
for commit,root,manifest,sizekey in [
 (donors[1],'docs/ui-routing/wave3-sefaria-late-reply-20261127','EVIDENCE_MANIFEST.json','size'),
 (donors[2],'docs/hq-integration/wave3-owned-capacity-20261127','PACKET_FILES.json','bytes')]:
 m=blob(commit+':'+root+'/'+manifest);records=json.loads(m)['files']
 assert len({r['path']for r in records})==len(records)
 for r in records:
  assert not pathlib.PurePosixPath(r['path']).is_absolute()and '..'not in pathlib.PurePosixPath(r['path']).parts
  raw=blob(commit+':'+root+'/'+r['path'])
  assert len(raw)==r[sizekey]and sha(raw)==r['sha256'],r['path']
 checks.append({'path':root+'/'+manifest,'sha256':sha(m),'verifiedFiles':len(records)})
intake=json.loads(blob(donors[1]+':docs/ui-routing/wave3-sefaria-late-reply-20261127/INTAKE.json'))
for f in intake['sourceFiles']:
 raw=blob(donors[0]+':'+f['path']);assert len(raw)==f['size']and sha(raw)==f['sha256']
p='tools/test_chavrusa_text_components.swift';old=blob(donors[0]+'^:'+p);new=blob(donors[0]+':'+p)
assert new.count(b'            let activeResponseEpoch = await bridge.sessionEpoch\n')==2
reconstructed=new.replace(b'            let activeResponseEpoch = await bridge.sessionEpoch\n',b'').replace(b'generation: activeResponseEpoch',b'generation: 1')
assert reconstructed==old
for p in ['Source/SefariaEmbedded/Runtime/SefariaRuntimeManager.swift','Source/SefariaEmbedded/Bridge/SefariaRPCModels.swift','Vendor/SefariaMobile/Integration/JS/ChavrusaRoot.js']:
 assert blob('HEAD:'+p)==blob(donors[0]+':'+p)==blob(donors[0]+'^:'+p)
cat.stdin.close();cat.wait()
plan={'schema':1,'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'rootBase':'95a8e41c69da9add6e260d6b5afb20fe316fcfe4','packets':packets,'manifestsVerified':checks,'originalHarnessExactReconstruction':True,'unmodifiedRuntimeModelsRNForwarding':True,'nativeRuns':0,'interpretation':'Selective root source-reviewed commits; actual Oracle controls/evidence retain original source identities. No native/Hermes acceptance inferred.'}
p=out/'PLAN.json';p.write_text(json.dumps(plan,indent=2)+'\n')
print(json.dumps({'path':str(p),'sha256':sha(p.read_bytes()),'packets':[{'donor':x['donor'],'files':len(x['files'])}for x in packets],'manifests':checks}))
