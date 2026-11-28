import os,stat,pathlib,hashlib,json,zipfile,io,subprocess,datetime,shutil
ROOT=pathlib.Path('/home/ubuntu/.codex/worktrees/Maktabah-wave3-integration-rootfs-20261127')
REL='docs/hq-integration/wave3-exact-actor-and-toc-recovery-20261128'
DEST=ROOT/REL
OUT=pathlib.Path('/home/ubuntu/otzaria-wave3-exact-recovery-checkpoint-intake-20261128')
BEFORE='f5a877a99a5952f5094a650c83042eb3166b7de8'
SOURCE='182dd74229c04959cecae82a59d16268dcbd80bc'
BRANCH='codex/otzaria-wave3-integration-20261127'
SPECS=json.loads("[{\"root\":\"/home/ubuntu/otzaria-wave3-inspector-app-source-recovery-20261128\",\"prefix\":\"inspector-actor\",\"files\":[{\"path\":\"EXACT_RECOVERY.patch\",\"bytes\":911,\"sha256\":\"90de5fc3540480da58f61f86011ddd656672e70b51f3f4a00b5aa7b7506d6e13\",\"mode\":33188,\"uid\":1001,\"gid\":1001,\"nlink\":1,\"allocated\":4096,\"mtimeNS\":\"1795833117216925940\",\"ctimeNS\":\"1795833117216925940\"},{\"path\":\"INPUT_READS.json\",\"bytes\":10936,\"sha256\":\"0e56f167367ad8407644def746551ecc1ec8bb62e94c9c6ee166ed0c8ffdd560\",\"mode\":33188,\"uid\":1001,\"gid\":1001,\"nlink\":1,\"allocated\":12288,\"mtimeNS\":\"1795833117220107799\",\"ctimeNS\":\"1795833117220107799\"},{\"path\":\"README.md\",\"bytes\":2262,\"sha256\":\"2c04a97ea1f18285836ed4b0e278136802a7d6c668e049cdfc18daca1dcd2c61\",\"mode\":33188,\"uid\":1001,\"gid\":1001,\"nlink\":1,\"allocated\":4096,\"mtimeNS\":\"1795833117225468670\",\"ctimeNS\":\"1795833117225468670\"},{\"path\":\"RECOVER.py\",\"bytes\":9378,\"sha256\":\"2e01a58036d8e95995739138fc3ce0743d960049ec64096b2067b96070c7551a\",\"mode\":33188,\"uid\":1001,\"gid\":1001,\"nlink\":1,\"allocated\":12288,\"mtimeNS\":\"1795833117222680934\",\"ctimeNS\":\"1795833117222680934\"},{\"path\":\"RECOVERY.json\",\"bytes\":5541,\"sha256\":\"6196bd0f2894d882252bcc6ffd8f64e51f4012de7b43d2b0855de0ff88b4385a\",\"mode\":33188,\"uid\":1001,\"gid\":1001,\"nlink\":1,\"allocated\":8192,\"mtimeNS\":\"1795833117231821627\",\"ctimeNS\":\"1795833117231821627\"},{\"path\":\"RECOVERY_MANIFEST.json\",\"bytes\":1630,\"sha256\":\"f0e3dc2768a445c57ef557c049c0ff1feefa0cdd0b35911a5bef6779eb8fd0fc\",\"mode\":33188,\"uid\":1001,\"gid\":1001,\"nlink\":1,\"allocated\":4096,\"mtimeNS\":\"1795833117236095291\",\"ctimeNS\":\"1795833117236095291\"},{\"path\":\"SOURCE_CAPSULE_MANIFEST.json\",\"bytes\":199173,\"sha256\":\"2f99156e4a3c4bd969342c2e30e42c529ed2c53b00794435ee69af1ca0eed737\",\"mode\":33188,\"uid\":1001,\"gid\":1001,\"nlink\":1,\"allocated\":200704,\"mtimeNS\":\"1795833117213109158\",\"ctimeNS\":\"1795833117213109158\"},{\"path\":\"baseline/MaktabahNativeInspectorSelection.swift\",\"bytes\":66789,\"sha256\":\"04565af26ebe46c6d8ea01c788043f9b4a900dc04c9c01c2794439ee5c47ab8b\",\"mode\":33188,\"uid\":1001,\"gid\":1001,\"nlink\":1,\"allocated\":69632,\"mtimeNS\":\"1795833117205938957\",\"ctimeNS\":\"1795833117205938957\"},{\"path\":\"candidate/MaktabahNativeInspectorSelection.swift\",\"bytes\":66811,\"sha256\":\"e718da5aef04543036e150278154b854611a75845514286beea5c91113be7c54\",\"mode\":33188,\"uid\":1001,\"gid\":1001,\"nlink\":1,\"allocated\":69632,\"mtimeNS\":\"1795833117209900100\",\"ctimeNS\":\"1795833117209900100\"}]},{\"root\":\"/home/ubuntu/otzaria-wave3-bookinfo-actor-source-recovery-20261128\",\"prefix\":\"bookinfo-actor\",\"files\":[{\"path\":\"EXACT_RECOVERY.patch\",\"bytes\":1724,\"sha256\":\"7b3537451f9ee6342e958296468e7457e4d94cbfe8bfea07a16beddfe9319544\",\"mode\":33188,\"uid\":1001,\"gid\":1001,\"nlink\":1,\"allocated\":4096,\"mtimeNS\":\"1795833614531197699\",\"ctimeNS\":\"1795833614531197699\"},{\"path\":\"INPUTS.json\",\"bytes\":7100,\"sha256\":\"f82eea6dc806600874baeffea214a2b82904bf07df3bd4bd7d4b821f66e11f7f\",\"mode\":33188,\"uid\":1001,\"gid\":1001,\"nlink\":1,\"allocated\":8192,\"mtimeNS\":\"1795833614533956475\",\"ctimeNS\":\"1795833614533956475\"},{\"path\":\"README.md\",\"bytes\":2493,\"sha256\":\"7265ef7daca162027c8262d83331af41112205450789420ee642524efe9f9abe\",\"mode\":33188,\"uid\":1001,\"gid\":1001,\"nlink\":1,\"allocated\":4096,\"mtimeNS\":\"1795833614539461187\",\"ctimeNS\":\"1795833614539461187\"},{\"path\":\"RECOVER.py\",\"bytes\":11068,\"sha256\":\"691563e8ac2ffa861a5ce8e5708f5ea8edb55a6abbc1c9564157040b9e0c83bf\",\"mode\":33188,\"uid\":1001,\"gid\":1001,\"nlink\":1,\"allocated\":12288,\"mtimeNS\":\"1795833614536739971\",\"ctimeNS\":\"1795833614536739971\"},{\"path\":\"RECOVERY.json\",\"bytes\":8086,\"sha256\":\"bacfc464a392440c402fc0be7aa1bc63b266d20c1316165711d17e86929c93fc\",\"mode\":33188,\"uid\":1001,\"gid\":1001,\"nlink\":1,\"allocated\":8192,\"mtimeNS\":\"1795833614546351067\",\"ctimeNS\":\"1795833614546351067\"},{\"path\":\"RECOVERY_MANIFEST.json\",\"bytes\":2082,\"sha256\":\"84ae2a4124e973044f158fecd2d4456c02a6deca6e3aaffc4f9b905a85aa20bf\",\"mode\":33188,\"uid\":1001,\"gid\":1001,\"nlink\":1,\"allocated\":4096,\"mtimeNS\":\"1795833614550678532\",\"ctimeNS\":\"1795833614550678532\"},{\"path\":\"SOURCE_CAPSULE_MANIFEST.json\",\"bytes\":199173,\"sha256\":\"2f99156e4a3c4bd969342c2e30e42c529ed2c53b00794435ee69af1ca0eed737\",\"mode\":33188,\"uid\":1001,\"gid\":1001,\"nlink\":1,\"allocated\":200704,\"mtimeNS\":\"1795833614527321316\",\"ctimeNS\":\"1795833614527321316\"},{\"path\":\"baseline/MaktabahNativeLibraryListPublication.swift\",\"bytes\":10530,\"sha256\":\"64b5b72a90a1e6734cbe5285537d70a9b1bf4121f2c91d06e076d7b8a084e065\",\"mode\":33188,\"uid\":1001,\"gid\":1001,\"nlink\":1,\"allocated\":12288,\"mtimeNS\":\"1795833614517168137\",\"ctimeNS\":\"1795833614517168137\"},{\"path\":\"candidate/MaktabahNativeLibraryListPublication.swift\",\"bytes\":10668,\"sha256\":\"839c4da8ddd9f7795b02046da7c5f778d5f85f744da14ace7819e24d2633558f\",\"mode\":33188,\"uid\":1001,\"gid\":1001,\"nlink\":1,\"allocated\":12288,\"mtimeNS\":\"1795833614520280635\",\"ctimeNS\":\"1795833614520280635\"},{\"path\":\"pattern-baseline/MaktabahNativeLibraryListPublication.swift\",\"bytes\":6985,\"sha256\":\"7f951ec90e3c9e7814e2875f6a074ee9f44d5b39089d8ec76bb1a329eee8df0f\",\"mode\":33188,\"uid\":1001,\"gid\":1001,\"nlink\":1,\"allocated\":8192,\"mtimeNS\":\"1795833614522660409\",\"ctimeNS\":\"1795833614522660409\"},{\"path\":\"pattern-recovered/MaktabahNativeLibraryListPublication.swift\",\"bytes\":7044,\"sha256\":\"3bcb93f70b9352eeeeb196a41e333da69fc7a9c19e314b4ba1198c2d1c217919\",\"mode\":33188,\"uid\":1001,\"gid\":1001,\"nlink\":1,\"allocated\":8192,\"mtimeNS\":\"1795833614525229544\",\"ctimeNS\":\"1795833614525229544\"}]},{\"root\":\"/home/ubuntu/otzaria-wave3-toc-embedded-source-lookup-20261128\",\"prefix\":\"toc-lookup\",\"files\":[{\"path\":\"DECODE_LEDGER.json\",\"bytes\":1219156,\"sha256\":\"89afdbea7165085409436c9d3bff8a0ff347cfd191f08d82f23a77de2c7852ec\",\"mode\":33188,\"uid\":1001,\"gid\":1001,\"nlink\":1,\"allocated\":1220608,\"mtimeNS\":\"1795834305090996222\",\"ctimeNS\":\"1795834305090996222\"},{\"path\":\"FINAL_HANDOFF.json\",\"bytes\":1831,\"sha256\":\"d8c0e916459bd219decc57abdcb3faf3f72273f56f478e9996a332594bfa5c05\",\"mode\":33188,\"uid\":1001,\"gid\":1001,\"nlink\":1,\"allocated\":4096,\"mtimeNS\":\"1795834354730798555\",\"ctimeNS\":\"1795834354730798555\"},{\"path\":\"INPUTS.json\",\"bytes\":1635,\"sha256\":\"56d1ea0f283903a68a4fb18b1dea9bd2aad5734687ef7ce58e7245bec0b28677\",\"mode\":33188,\"uid\":1001,\"gid\":1001,\"nlink\":1,\"allocated\":4096,\"mtimeNS\":\"1795834305035489739\",\"ctimeNS\":\"1795834305035489739\"},{\"path\":\"LOOKUP.py\",\"bytes\":18297,\"sha256\":\"1cd77b64c82e435bc05c04f06b288f593a2af1a5391fe56f5cfc1b47723b49cd\",\"mode\":33188,\"uid\":1001,\"gid\":1001,\"nlink\":1,\"allocated\":20480,\"mtimeNS\":\"1795834305041781816\",\"ctimeNS\":\"1795834305041781816\"},{\"path\":\"MANIFEST.json\",\"bytes\":1005,\"sha256\":\"992133a7e44ec49bf7750556c125d10063ae88d4fb66465b09637ec3313d5a90\",\"mode\":33188,\"uid\":1001,\"gid\":1001,\"nlink\":1,\"allocated\":4096,\"mtimeNS\":\"1795834305106912395\",\"ctimeNS\":\"1795834305106912395\"},{\"path\":\"README.md\",\"bytes\":1290,\"sha256\":\"17d5c0407276e80c8deb3468d094a078f213f8b1970c81cd4ced16f8fc6c6df6\",\"mode\":33188,\"uid\":1001,\"gid\":1001,\"nlink\":1,\"allocated\":4096,\"mtimeNS\":\"1795834305103982018\",\"ctimeNS\":\"1795834305103982018\"},{\"path\":\"RESULT.json\",\"bytes\":2765,\"sha256\":\"bd39db023dc546df1aa5590e3f9d160e761049b0961c7ae25ab92bbbd06326bf\",\"mode\":33188,\"uid\":1001,\"gid\":1001,\"nlink\":1,\"allocated\":4096,\"mtimeNS\":\"1795834305101495003\",\"ctimeNS\":\"1795834305101495003\"},{\"path\":\"TOOL_RETURN.json\",\"bytes\":23285,\"sha256\":\"ab5b0beaf4b4d47869e0759e389e96b5e60ee10bbb351f6fe07e8617016b4a33\",\"mode\":33188,\"uid\":1001,\"gid\":1001,\"nlink\":1,\"allocated\":24576,\"mtimeNS\":\"1795834354724852920\",\"ctimeNS\":\"1795834354724852920\"},{\"path\":\"TOP_LEVEL_MEMBERS.json\",\"bytes\":170621,\"sha256\":\"7007f2e163fbe4ea24c0ca0e80d83b97027bb3776b50a33d455d4f728ff1b113\",\"mode\":33188,\"uid\":1001,\"gid\":1001,\"nlink\":1,\"allocated\":172032,\"mtimeNS\":\"1795834305049059138\",\"ctimeNS\":\"1795834305049059138\"}]}]")
README="# Exact actor sources and bounded TOC recovery\n\nThis additive documentation checkpoint preserves all 29 files (2,070,269 raw bytes) from three closed recovery scopes. Application sources and package pins are not adopted by this commit. The original scopes remain intact.\n\n## Actor source recovery\n\nInspector: the 66,811-byte candidate SHA-256 e718da5aef04543036e150278154b854611a75845514286beea5c91113be7c54 is the exact previously recorded candidate. Its sole changes against the preserved predecessor are inline @MainActor annotations on the two original local Catalog and Source classes. The inverse patch reproduces the full predecessor. The original temporary staging script was unavailable and is not represented as recovered.\n\nBookInfo: the 10,668-byte publication candidate SHA-256 839c4da8ddd9f7795b02046da7c5f778d5f85f744da14ace7819e24d2633558f matches the full previously recorded candidate. Its two initialization changes follow the exact independently recovered Library pattern, preserved here with both pattern bodies. Its inverse reproduces the full BookInfo predecessor. The old UPDATE.json was unavailable; the newly generated RECOVERY.json is distinct and does not replace that old record.\n\nBoth recovered source candidates remain uncompiled and unintegrated. Original compiler failures and capacity refusals remain in earlier checkpoints. This recovery reports no new test pass.\n\n## Bounded TOC lookup\n\nThe raw lookup and its later handoff preserve the single search of two pinned archives: 668 top-level and 248 nested ZIP members, with bounded JSON, Python literal, base64 and gzip decoding. Neither missing exact candidate (binding 59f2b638..., field cf5fa395...) was recovered. The lookup reached 4,096 unique decoded nodes; 816 additional payloads were hash-checked without recursive inspection, and two gzip expansions reached their bound. This establishes only unavailability within that bounded lookup, not exhaustive or global absence.\n\nTOOL_RETURN.json retains the successful scan's actual exit 0 and the subsequent response parser failure caused by trailing Python SyntaxWarnings. The scan was not repeated. New TOC work is explicitly a new implementation from pinned current originals, not a reconstruction claimed to be either missing body.\n\n## Preservation and limits\n\nRECOVERY_RAW.zip contains every file byte-for-byte, including original manifests, controllers, source candidates, predecessor bodies, and failure evidence. INPUT_MANIFEST.json records original identities and full SHA-256 values. Intake reads every archive member back and compares every source again before committing. Binary Git reads are logged by byte length and hash rather than decoded as text.\n\nThis checkpoint changes no non-docs top-level Git tree, current ownership registry, Apple build input or release status. Oracle preservation controls have separately completed 11/11 PASS and an intended 57 != 70 omission-negative failure; Mac focused controls and the real Native116 rerun remain incomplete. No Archive, IPA, App Store Connect validation, TestFlight availability, or physical-device success is claimed.\n"
FLOOR=1593835520;RESERVE=8388608
assert shutil.disk_usage('/').free>=FLOOR+RESERVE
assert not DEST.exists() and not OUT.exists()
commands=[]
def sha(b):return hashlib.sha256(b).hexdigest()
def ident(s):return (s.st_dev,s.st_ino,s.st_mode,s.st_uid,s.st_gid,s.st_nlink,s.st_size,s.st_mtime_ns,s.st_ctime_ns)
def read(p,pin=None):
 assert p.resolve(strict=True)==p
 s=p.lstat();assert stat.S_ISREG(s.st_mode) and s.st_nlink==1 and s.st_size<=4194304
 fd=os.open(p,os.O_RDONLY|os.O_NOFOLLOW)
 try:
  assert ident(os.fstat(fd))==ident(s)
  with os.fdopen(os.dup(fd),'rb') as f:b=f.read(s.st_size+1)
  assert len(b)==s.st_size and ident(os.fstat(fd))==ident(s)
 finally:os.close(fd)
 assert ident(p.lstat())==ident(s)
 if pin:assert len(b)==pin['bytes'] and sha(b)==pin['sha256'],str(p)
 return b,s
def git(*args,binary=False):
 cmd=['sudo','-u','ubuntu','-H','git','-c','gc.auto=0','-c','maintenance.auto=false','-c','user.name=ChatGPT','-c','user.email=chatgpt-agent@users.noreply.github.com','-C',str(ROOT),*args]
 p=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=90)
 row={'args':list(args),'exit':p.returncode,'stdoutBytes':len(p.stdout),'stdoutSHA256':sha(p.stdout),'stderrBytes':len(p.stderr),'stderrSHA256':sha(p.stderr)}
 if not binary and len(p.stdout)<=16384:row['stdout']=p.stdout.decode('utf-8','replace')
 if len(p.stderr)<=16384:row['stderr']=p.stderr.decode('utf-8','replace')
 commands.append(row)
 assert p.returncode==0,row
 return p.stdout
assert git('rev-parse','HEAD').decode().strip()==BEFORE
assert git('branch','--show-current').decode().strip()==BRANCH
assert git('remote','get-url','origin').decode().strip()=='https://github.com/davidpovarsky/Maktabah.git'
assert git('status','--porcelain=v1','-z')==b''
assert git('rev-parse','HEAD:Source').decode().strip()==SOURCE
top_before={x.split(b'\t',1)[1]:x.split(b'\t',1)[0]for x in git('ls-tree','-z','HEAD').split(b'\0')if x}
raw_files={};rows=[];memberships={}
for spec in SPECS:
 base=pathlib.Path(spec['root']);assert base.resolve(strict=True)==base and stat.S_ISDIR(base.lstat().st_mode)
 actual=set()
 def walk(d,depth=0):
  assert depth<=3
  entries=sorted(os.scandir(d),key=lambda e:e.name);assert len(entries)<=32
  for e in entries:
   p=pathlib.Path(e.path);s=p.lstat()
   if stat.S_ISDIR(s.st_mode):walk(p,depth+1)
   else:
    assert stat.S_ISREG(s.st_mode) and s.st_nlink==1
    actual.add(str(p.relative_to(base)))
 walk(base);expected={r['path']for r in spec['files']};assert actual==expected
 memberships[str(base)]=sorted(actual)
 for pin in spec['files']:
  p=base/pin['path'];b,s=read(p,pin)
  assert s.st_mode==pin['mode'] and s.st_uid==pin['uid'] and s.st_gid==pin['gid'] and str(s.st_mtime_ns)==pin['mtimeNS'] and str(s.st_ctime_ns)==pin['ctimeNS']
  name=spec['prefix']+'/'+pin['path'];assert name not in raw_files;raw_files[name]=b
  rows.append({'member':name,'originalPath':str(p),'bytes':len(b),'sha256':sha(b),'device':s.st_dev,'inode':s.st_ino,'mode':s.st_mode,'uid':s.st_uid,'gid':s.st_gid,'nlink':s.st_nlink,'allocatedBytes':s.st_blocks*512,'mtimeNS':str(s.st_mtime_ns),'ctimeNS':str(s.st_ctime_ns)})
assert len(raw_files)==29 and sum(map(len,raw_files.values()))==2070269
for prefix,manifest_name in [('inspector-actor','RECOVERY_MANIFEST.json'),('bookinfo-actor','RECOVERY_MANIFEST.json')]:
 m=json.loads(raw_files[prefix+'/'+manifest_name])
 listed=m.get('files',m.get('files_excluding_manifest'))
 assert isinstance(listed,list)
 for row in listed:
  b=raw_files[prefix+'/'+row['path']]
  assert len(b)==row['bytes'] and sha(b)==row['sha256']
 assert {row['path']for row in listed}|{manifest_name}=={n[len(prefix)+1:]for n in raw_files if n.startswith(prefix+'/')}
handoff=json.loads(raw_files['toc-lookup/FINAL_HANDOFF.json'])
assert handoff['status']=='NO_EXACT_TARGET_IN_BOUNDED_LOOKUP' and handoff['actual_exit_code']==0 and handoff['not_global_or_exhaustive_absence']
assert len(handoff['files_excluding_handoff'])==8
for row in handoff['files_excluding_handoff']:
 b=raw_files['toc-lookup/'+row['path']]
 assert len(b)==row['bytes'] and sha(b)==row['sha256']
blob=io.BytesIO()
with zipfile.ZipFile(blob,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
 for row in sorted(rows,key=lambda r:r['member']):
  zi=zipfile.ZipInfo(row['member'],(1980,1,1,0,0,0));zi.create_system=3;zi.external_attr=row['mode']<<16;zi.compress_type=zipfile.ZIP_DEFLATED
  z.writestr(zi,raw_files[row['member']])
archive=blob.getvalue();assert len(archive)<=2097152
with zipfile.ZipFile(io.BytesIO(archive)) as z:
 assert z.testzip() is None and len(z.infolist())==29 and set(z.namelist())==set(raw_files)
 for row in rows:
  b=z.read(row['member']);assert b==raw_files[row['member']] and read(pathlib.Path(row['originalPath']))[0]==b
controller=pathlib.Path(__file__).read_bytes();assert len(controller)<=32768
proof={'schema':'otzaria.exact-actor-toc-recovery-intake/1','status':'EXACT_DOCUMENTATION_PREPARED_FOR_COMMIT','before':BEFORE,'source':SOURCE,'fileCount':29,'originalBytes':2070269,'archiveBytes':len(archive),'archiveSHA256':sha(archive),'rawMembersReadBack':29,'originalFilesRejoined':29,'originalScopesUnchanged':True,'actorCandidatesIntegrated':False,'newTests':0,'boundedLookupNotGlobalAbsence':True,'productChanges':0,'releaseQualified':False,'at':datetime.datetime.now(datetime.timezone.utc).isoformat()}
files={'RECOVERY_RAW.zip':archive,'INPUT_MANIFEST.json':(json.dumps({'files':rows,'memberships':memberships},indent=2,sort_keys=True)+'\n').encode(),'ROOT_INTAKE_PROOF.json':(json.dumps(proof,indent=2,sort_keys=True)+'\n').encode(),'README.md':README.encode(),'INTAKE.py':controller}
OUT.mkdir(mode=0o750);os.chown(OUT,1001,1001)
def write_new(p,b):
 created=[];q=p.parent
 while not q.exists():created.append(q);q=q.parent
 for d in reversed(created):d.mkdir(mode=0o750);os.chown(d,1001,1001)
 fd=os.open(p,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o640)
 try:
  view=memoryview(b)
  while view:
   n=os.write(fd,view);assert n>0;view=view[n:]
  os.fsync(fd);os.fchown(fd,1001,1001)
 finally:os.close(fd)
 assert read(p)[0]==b
try:
 for name,b in files.items():write_new(DEST/name,b)
 assert shutil.disk_usage('/').free>=FLOOR+RESERVE
 expected=[REL+'/'+k for k in sorted(files)]
 git('add','--sparse','-f','--',*expected)
 staged=[x for x in git('diff','--cached','--name-only','-z').decode().split('\0')if x]
 assert sorted(staged)==expected
 git('diff','--cached','--check')
 for name,b in files.items():assert git('show',':'+REL+'/'+name,binary=True)==b
 git('commit','-m','docs: preserve exact actor source recovery and bounded TOC lookup')
 after=git('rev-parse','HEAD').decode().strip()
 assert git('rev-parse','HEAD^').decode().strip()==BEFORE
 top_after={x.split(b'\t',1)[1]:x.split(b'\t',1)[0]for x in git('ls-tree','-z','HEAD').split(b'\0')if x}
 assert set(top_before)==set(top_after) and all(top_before[k]==top_after[k]for k in top_before if k!=b'docs')
 assert git('rev-parse','HEAD:Source').decode().strip()==SOURCE
 assert git('status','--porcelain=v1','-z')==b''
 git('-c','remote.origin.mirror=false','-c','credential.helper=!gh auth git-credential','push','origin','HEAD:refs/heads/'+BRANCH)
 remote=git('-c','credential.helper=!gh auth git-credential','ls-remote','--heads','origin','refs/heads/'+BRANCH).decode().strip()
 assert remote.split()[0]==after
 result={'schema':'otzaria.exact-actor-toc-recovery-commit/1','status':'COMMITTED_PUSHED_READ_BACK','before':BEFORE,'after':after,'sourceUnchanged':SOURCE,'allNonDocsTopTreesUnchanged':True,'branch':BRANCH,'files':len(files),'rawFilesPreserved':29,'proofSHA256':sha(files['ROOT_INTAKE_PROOF.json']),'inputManifestSHA256':sha(files['INPUT_MANIFEST.json']),'archiveSHA256':sha(archive),'controllerSHA256':sha(controller),'testsRun':0,'remote':remote,'rootFree':shutil.disk_usage('/').free,'completedAt':datetime.datetime.now(datetime.timezone.utc).isoformat()}
 write_new(OUT/'RESULT.json',(json.dumps(result,indent=2,sort_keys=True)+'\n').encode())
 write_new(OUT/'COMMANDS.json',(json.dumps(commands,indent=2,sort_keys=True)+'\n').encode())
 print(json.dumps(result))
except BaseException as e:
 write_new(OUT/'FAILED.json',(json.dumps({'type':type(e).__name__,'error':str(e),'commands':commands,'at':datetime.datetime.now(datetime.timezone.utc).isoformat()},indent=2,sort_keys=True)+'\n').encode())
 raise
