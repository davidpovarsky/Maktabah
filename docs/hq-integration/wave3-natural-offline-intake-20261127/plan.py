import subprocess,json,pathlib,hashlib,datetime,difflib
w=pathlib.Path('/mnt/development/projects/worktrees/Maktabah-wave3-integration-20261127')
out=w/'build/wave3-natural-offline-intake-20261127-0832-attempt3';out.mkdir(parents=True,exist_ok=False)
donors=["c0f6371bc68d29b60faa76f643dc0a06879c11b8","883660701dd57c049de6da6fcf51a4027675409c","ec834a5f4fe109726c91b137bb8b7c33e2ca299e","a1c32faca292e0ce1d7cbe2948fefc9a29cc7a72"]
def g(*args):return subprocess.check_output(['git','-C',str(w),'-c','gc.auto=0','-c','maintenance.auto=false',*args])
assert g('rev-parse','HEAD').decode().strip()=='54fd5d5b7c3ebacb563c713778d8df92598e79ee'
assert not g('status','--porcelain=v1')
cat=subprocess.Popen(['git','-C',str(w),'cat-file','--batch'],stdin=subprocess.PIPE,stdout=subprocess.PIPE)
def blob(spec):
 cat.stdin.write((spec+'\n').encode());cat.stdin.flush();h=cat.stdout.readline()
 if h.endswith(b' missing\n'):return None
 parts=h.split(); assert parts[1]==b'blob',h
 n=int(parts[2]); b=cat.stdout.read(n);assert cat.stdout.read(1)==b'\n';return b
def sha(b):return hashlib.sha256(b).hexdigest() if b is not None else None
virtual={};packets=[];merges=[]
for commit in donors:
 paths=g('diff-tree','--no-commit-id','--name-only','-r',commit).decode().splitlines()
 files=[]
 for path in paths:
  current=virtual[path] if path in virtual else blob('HEAD:'+path)
  base=blob(commit+'^:'+path); incoming=blob(commit+':'+path)
  if current==base: expected=incoming;kind='exact-donor'
  elif current==incoming: expected=current;kind='already-identical'
  else:
   assert path=='Maktabah-iOSUITests/FaithfulReaderUIAcceptanceTests.swift',('unreviewed-overlap',commit,path)
   assert all(x is not None for x in [current,base,incoming])
   d=out/'shared-faithful';d.mkdir(exist_ok=True)
   for name,data in [('root.swift',current),('base.swift',base),('donor.swift',incoming)]: (d/name).write_bytes(data)
   r=subprocess.run(['git','merge-file','-p',str(d/'root.swift'),str(d/'base.swift'),str(d/'donor.swift')],capture_output=True)
   (d/'merge.stderr').write_bytes(r.stderr)
   assert r.returncode==0,r.stderr
   expected=r.stdout;(d/'expected.swift').write_bytes(expected);kind='reviewed-three-way'
   diff=''.join(difflib.unified_diff(current.decode().splitlines(True),expected.decode().splitlines(True),fromfile='root/'+path,tofile='integrated/'+path))
   (d/'integration.diff').write_text(diff)
   merges.append({'path':path,'commit':commit,'root':sha(current),'base':sha(base),'donor':sha(incoming),'expected':sha(expected),'bytes':len(expected),'diff':diff})
  virtual[path]=expected
  files.append({'path':path,'mode':kind,'beforeSHA256':sha(current),'baseSHA256':sha(base),'donorSHA256':sha(incoming),'expectedSHA256':sha(expected),'expectedBytes':len(expected) if expected is not None else None})
 packets.append({'donor':commit,'files':files})
cat.stdin.close();cat.wait()
plan={'schema':1,'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'rootBase':'54fd5d5b7c3ebacb563c713778d8df92598e79ee','packets':packets,'merges':[{k:v for k,v in x.items() if k!='diff'}for x in merges],'interpretation':'Selective reviewed commits, not branch merge. Original evidence retains its actual source/execution identities; no native acceptance was rerun.'}
p=out/'PLAN.json';p.write_text(json.dumps(plan,indent=2)+'\n')
print(json.dumps({'plan':str(p),'planSHA256':sha(p.read_bytes()),'packets':[{'donor':x['donor'],'paths':len(x['files']),'bytes':sum(y['expectedBytes'] or 0 for y in x['files'])}for x in packets],'merges':merges}))
