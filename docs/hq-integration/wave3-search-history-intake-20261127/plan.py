import subprocess,json,pathlib,hashlib,datetime,difflib
w=pathlib.Path('/mnt/development/projects/worktrees/Maktabah-wave3-integration-20261127')
out=w/'build/wave3-selective-intake-20261127-0820';out.mkdir(parents=True,exist_ok=False)
donors=['ff5e20977f9aef49492a6bf9ae1e5794862edfe9','6d6b45e28969c0f967bfdd4162f70fac879e6cb4','19dc53e3412c759cff18f74531e8953085289199','4f619cc45eb36c5c880c474d7360605908d2c258','8fd678b25784fa84fff9482f0c36fa9d1e8f20a0','1330c29fd259ce74d30b3e39b2e020b60bb57700','9b376a42234ebb176f36a0b3cca94de97e41869c','589f8bc4721c66ed74955a28cdc064dac54d009f','5aaa41505c03875af8850171cad837aa4bcee9a3','1a41a6e069cc2b42bcb26fb773f550249fd30ab9','bbaf530f8f3b9d1810c7375be924d4deb6324fab']
def g(*args):return subprocess.check_output(['git','-C',str(w),'-c','gc.auto=0','-c','maintenance.auto=false',*args])
assert g('rev-parse','HEAD').decode().strip()=='052d2a7f6d26da935a6d7847477e53d981f428cb'
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
   assert path=='Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeRoutingComposition.swift',('unreviewed-overlap',commit,path)
   assert all(x is not None for x in [current,base,incoming])
   d=out/'shared-composition';d.mkdir(exist_ok=True)
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
plan={'schema':1,'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'rootBase':'052d2a7f6d26da935a6d7847477e53d981f428cb','packets':packets,'merges':[{k:v for k,v in x.items() if k!='diff'}for x in merges],'interpretation':'Selective reviewed commits, not branch merge. Original evidence retains its actual source/execution identities; no native acceptance was rerun.'}
p=out/'PLAN.json';p.write_text(json.dumps(plan,indent=2)+'\n')
print(json.dumps({'plan':str(p),'planSHA256':sha(p.read_bytes()),'packets':[{'donor':x['donor'],'paths':len(x['files']),'bytes':sum(y['expectedBytes'] or 0 for y in x['files'])}for x in packets],'merges':merges}))
