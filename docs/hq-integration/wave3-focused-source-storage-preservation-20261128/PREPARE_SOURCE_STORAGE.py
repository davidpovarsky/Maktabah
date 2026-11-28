if not __debug__: raise RuntimeError('Optimized preparation refused')
import os,stat,pathlib,hashlib,json,zipfile,io,datetime,shutil,ast,base64
ROOT=pathlib.Path('/home/ubuntu/otzaria-wave3-native116-v3-focused-controls-20261128')
CAP=4194304; FLOOR=1593835520; FUTURE_RESERVE=32768
SEAL_SHA='91310e5dd7f4e72289c6575f4e07d47853b28d48beab460f88caecf26c555b09'
EXPECTED_PHASE_PINS=json.loads("{\"runs/accounting-candidate/DISPATCH_RESULT.json\":{\"bytes\":5974,\"sha256\":\"7bfabf7336d7a2a7526cb8a6add58a611d63e2c29ae3c7ef0034738899b2e5ba\"},\"runs/accounting-candidate/worker.PROCESS.json\":{\"bytes\":256,\"sha256\":\"7d2c6c6a6ce7067fece1ae67586edac8ddcd30267075f2d4cc940dce0f1668c3\"},\"runs/accounting-candidate/worker.TERMINAL.json\":{\"bytes\":1249,\"sha256\":\"02176ace8ecfb39b534d381ca86af6657a35e1b1b231814feece74349b368438\"},\"runs/accounting-candidate/worker.stderr\":{\"bytes\":0,\"sha256\":\"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855\"},\"runs/accounting-candidate/worker.stdout\":{\"bytes\":12364,\"sha256\":\"106ab58b2e5aa61b1d52a30b647cb77153962ab1d73f8a789c75e6374bd7e024\"},\"runs/accounting-omit-first/DISPATCH_RESULT.json\":{\"bytes\":3362,\"sha256\":\"d02ce1002dff39f4116de588fd495737389c62a589911fe598fe30e84aef151f\"},\"runs/accounting-omit-first/worker.PROCESS.json\":{\"bytes\":256,\"sha256\":\"7cd6d80b3a53a6c3bf2af17542fac7af5f82d590a8c15b7d253fd0cbba2d35a8\"},\"runs/accounting-omit-first/worker.TERMINAL.json\":{\"bytes\":1248,\"sha256\":\"c8ce87529565091ff8b39a758ae41f9a46a24d395754e14cdf4fe7973918cd70\"},\"runs/accounting-omit-first/worker.stderr\":{\"bytes\":0,\"sha256\":\"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855\"},\"runs/accounting-omit-first/worker.stdout\":{\"bytes\":3242,\"sha256\":\"1a6680d41485b5100898505dbf15e4c25cf9b9de34c7ac71304cfdb8ecef25be\"},\"runs/mac-baseline/DISPATCH_RESULT.json\":{\"bytes\":3168,\"sha256\":\"d91d88e9fc136b255ad311227d531745178d7abd95c8891be0779e15857c7dbe\"},\"runs/mac-baseline/worker.stdout\":{\"bytes\":4389,\"sha256\":\"9df6f19c7be22df94514e4869f139a2c963a64b3deae2de0ac1031072cb6292c\"},\"runs/mac-baseline/worker.stderr\":{\"bytes\":0,\"sha256\":\"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855\"},\"runs/mac-baseline/worker.PROCESS.json\":{\"bytes\":459,\"sha256\":\"d75c2593d8e4ce5c85a771ca5cd9c0858d109c1e53984fca8ccabe8a8061f21a\"},\"runs/mac-baseline/worker.TERMINAL.json\":{\"bytes\":1230,\"sha256\":\"cff66291275b0e6f02458e56e82a452278860e0bcc776231f84cf0253b5aedf0\"},\"runs/mac-baseline/alias/DISPATCH_RESULT.json\":{\"bytes\":152,\"sha256\":\"47fc8d8759d3367b80af10b3005a2632c3fdd68ededa700a5090e2eaf1346eff\"},\"runs/mac-baseline/alias/worker.stdout\":{\"bytes\":4154,\"sha256\":\"aca467b95283f63f7ffa4dd62f957af9940b41d6cf612016cfc6de6c04dd02e7\"},\"runs/mac-baseline/alias/worker.stderr\":{\"bytes\":72,\"sha256\":\"d0e14941dee288cc8de19e48436cdf3c2e7939d4b98136c44d954b5f8be73d8a\"},\"runs/mac-baseline/alias/worker.PROCESS.json\":{\"bytes\":314,\"sha256\":\"2fd526bc9848081c2ca6ba3b2214b94d977a2df71bbddc64422c9bf7fdef8bf5\"},\"runs/mac-baseline/alias/worker.TERMINAL.json\":{\"bytes\":1240,\"sha256\":\"644f630736b88f6d2cff38beb65ea8f766a4a8c2fb063eb3033b0f812829f538\"}}")
RESOLVER_TEMPLATE="\"\"\"Pinned storage resolver for fourteen preserved historical focused-control sources.\nOnly the documented source-read storage boundary changes. Original dispatcher,\nworkers, tests, protocol, allocation guards, process handling and output caps stay exact.\n\"\"\"\nif not __debug__: raise RuntimeError(\"Optimized storage resolver refused\")\nimport argparse,base64,hashlib,io,json,os,stat,sys,types,zipfile\nfrom pathlib import Path\nROOT=Path('/home/ubuntu/otzaria-wave3-native116-v3-focused-controls-20261128')\nARCHIVE=ROOT/'HISTORICAL_SOURCES.zip'\nARCHIVE_BYTES=__ARCHIVE_BYTES__\nARCHIVE_SHA='__ARCHIVE_SHA__'\nMANIFEST_BYTES=__MANIFEST_BYTES__\nMANIFEST_SHA='__MANIFEST_SHA__'\nSEAL_SHA='91310e5dd7f4e72289c6575f4e07d47853b28d48beab460f88caecf26c555b09'\nDISPATCH_SHA='698a39e097827e596c98ccb9afee193fcf08aa6f7405cfe5db114ac3a5a8aa48'\ndef need(ok,message):\n    if not ok: raise RuntimeError(message)\ndef sha(b): return hashlib.sha256(b).hexdigest()\ndef ident(s):\n    return (s.st_dev,s.st_ino,s.st_mode,s.st_uid,s.st_gid,s.st_nlink,s.st_size,s.st_mtime_ns,s.st_ctime_ns)\ndef exact(path,limit):\n    need(path.resolve(strict=True)==path,'Exact unsymlinked storage path')\n    before=path.lstat()\n    need(stat.S_ISREG(before.st_mode) and before.st_nlink==1 and before.st_size<=limit,'Bounded single regular storage')\n    fd=os.open(path,os.O_RDONLY|os.O_NOFOLLOW)\n    try:\n        need(ident(os.fstat(fd))==ident(before),'Storage open identity')\n        with os.fdopen(os.dup(fd),'rb') as stream: raw=stream.read(limit+1)\n        need(len(raw)==before.st_size and ident(os.fstat(fd))==ident(before),'Complete stable storage read')\n    finally: os.close(fd)\n    need(ident(path.lstat())==ident(before),'Storage path identity')\n    return raw\ndef main():\n    parser=argparse.ArgumentParser(description=__doc__)\n    parser.add_argument('--resolver-sha256',required=True)\n    parser.add_argument('--source-seal-sha256',required=True)\n    parser.add_argument('--phase',choices=('mac-candidate','close'),required=True)\n    args=parser.parse_args()\n    need(sys.flags.isolated==1 and sys.dont_write_bytecode and os.geteuid()==1001,'Original isolated owner runtime')\n    need(ROOT.resolve(strict=True)==ROOT and stat.S_ISDIR(ROOT.lstat().st_mode),'Fixed owned controls root')\n    own=Path(__file__)\n    need(own==ROOT/'resolve_preserved_sources.py','Fixed resolver source')\n    need(sha(exact(own,16384))==args.resolver_sha256,'Root-pinned resolver source')\n    need(args.source_seal_sha256==SEAL_SHA,'Original reporting seal unchanged')\n    seal_raw=exact(ROOT/'SOURCE_SEAL_REVIEW3.json',65536)\n    need(sha(seal_raw)==SEAL_SHA,'Exact original seal')\n    seal=json.loads(seal_raw)\n    need(seal['schema']=='otzaria.native116-focused-control-reporting-seal/3' and seal['root']==str(ROOT),'Original seal schema')\n    historical=seal['originalFourteen']\n    need(len(historical)==14 and all(Path(n).name==n for n in historical),'Closed fourteen historical names')\n    need(sum(p['bytes'] for p in historical.values())==275022,'Closed historical logical bytes')\n    paths={str(ROOT/name):name for name in historical}\n    def archive_members():\n        need(all(not os.path.lexists(ROOT/name) for name in historical),'Archived raw source path reappeared')\n        raw=exact(ARCHIVE,131072)\n        need(len(raw)==ARCHIVE_BYTES and sha(raw)==ARCHIVE_SHA,'Pinned complete source archive')\n        out={}\n        with zipfile.ZipFile(io.BytesIO(raw)) as z:\n            infos=z.infolist()\n            need(len(infos)==15 and {i.filename for i in infos}==set(historical)|{'MANIFEST.json'},'Exact archive members without duplicates')\n            for info in infos:\n                need(not info.is_dir() and info.compress_type==zipfile.ZIP_DEFLATED and not info.flag_bits&1,'Closed regular unencrypted member')\n                need(stat.S_ISREG(info.external_attr>>16),'Original regular member type')\n                pin={'bytes':MANIFEST_BYTES,'sha256':MANIFEST_SHA} if info.filename=='MANIFEST.json' else historical[info.filename]\n                need(info.file_size==pin['bytes'] and info.file_size<=65536,'Bounded declared member length')\n                with z.open(info) as f:\n                    body=f.read(pin['bytes']+1)\n                    need(f.read(1)==b'','Complete member EOF')\n                need(len(body)==pin['bytes'] and sha(body)==pin['sha256'],'Complete original member byte/hash pin')\n                out[info.filename]=body\n        manifest=json.loads(out.pop('MANIFEST.json'))\n        need(manifest['schema']=='otzaria.focused-legacy-source-archive/1' and manifest['root']==str(ROOT),'Archive metadata schema/root')\n        need(manifest['sourceSealSHA256']==SEAL_SHA and manifest['originalFourteen']==historical,'Original fourteen bindings')\n        rows=manifest['entries']\n        need(len(rows)==14 and {r['name'] for r in rows}==set(historical),'Exact metadata membership')\n        for row in rows:\n            pin=historical[row['name']]\n            need(row['bytes']==pin['bytes'] and row['sha256']==pin['sha256'] and stat.S_ISREG(row['mode']) and row['nlink']==1,'Original metadata bindings')\n        return out\n    archive_members()\n    dispatcher_path=ROOT/'dispatch_focused_controls_review3.py'\n    body=exact(dispatcher_path,65536)\n    need(len(body)==32825 and sha(body)==DISPATCH_SHA,'Original dispatcher body unchanged')\n    module=types.ModuleType('focused_dispatcher_preserved_storage')\n    module.__file__=str(dispatcher_path)\n    exec(compile(body,str(dispatcher_path),'exec'),module.__dict__)\n    original_read=module.read_fixed\n    def preserved_read(path,limit,single=True):\n        name=paths.get(str(path))\n        if name is None: return original_read(path,limit,single=single)\n        need(type(limit) is int and limit>=0 and historical[name]['bytes']<=limit,'Original requested source-read limit')\n        return archive_members()[name]\n    module.read_fixed=preserved_read\n    print(json.dumps({'kind':'EXPLICIT_PRESERVED_SOURCE_STORAGE','phase':args.phase,'resolverSHA256':args.resolver_sha256,\n                      'archiveBytes':ARCHIVE_BYTES,'archiveSHA256':ARCHIVE_SHA,'historicalMembers':14,\n                      'originalDispatcherSHA256':DISPATCH_SHA,'originalSealSHA256':SEAL_SHA,\n                      'testOrProtocolBodiesChanged':False,'allocationAndOutputCapsChanged':False},separators=(',',':')),flush=True)\n    sys.argv=[str(dispatcher_path),'--source-seal-sha256',SEAL_SHA,'--phase',args.phase]\n    module.main()\nif __name__=='__main__': main()\n"
README="# Explicit preservation of historical focused-control sources\n\nFourteen historical source and proof files are preserved byte-for-byte in HISTORICAL_SOURCES.zip with complete original metadata. The eight current revision-3 source/proof files, original dispatcher, all test methods, protocol sources, output limits and the 4 MiB guard remain unchanged.\n\nThe preparation step only adds a verified archive, a strict source-storage resolver and receipts. Original raw files remain until a separate Root operation verifies a durable Git copy, rechecks exact bytes and identities, and records the precise retirement. The resolver refuses to operate while any of the fourteen raw paths still exists. It substitutes archive-backed reads only for these fourteen exact absolute paths; every other read delegates to the unchanged dispatcher. The original source seal and all SEALED rechecks still verify the same source bytes.\n\nThis storage change is necessary because three completed phases occupy 4,009,984 bytes and the final Mac phase plus its unchanged allocation guard would exceed 4 MiB by 32,768 bytes. Existing output is preserved. No test, guard or output allowance is weakened. The earlier measurement's reporting-only base64 return refusal was not a test or protocol failure; its corrected numeric measurement produced an in-memory 87,711-byte ZIP. This preparation captures fresh metadata and binds its own archive hash.\n\nMac baseline: two intended defects reproduced, with one assertion failure and one NameError. Oracle candidate: 11 PASS. Omission counterfactual: one intended 57 != 70 failure. Candidate17, closure, real Native116 and release qualification remain pending at preparation time.\n"
def need(ok,message):
 if not ok:raise RuntimeError(message)
def sha(b):return hashlib.sha256(b).hexdigest()
def canon(o):return (json.dumps(o,sort_keys=True,separators=(',',':'),ensure_ascii=True)+'\n').encode('ascii')
def identity(s):return(s.st_dev,s.st_ino,s.st_mode,s.st_uid,s.st_gid,s.st_nlink,s.st_size,s.st_mtime_ns,s.st_ctime_ns)
def read(p,limit=1048576,single=True):
 s=p.lstat();need(stat.S_ISREG(s.st_mode) and (s.st_nlink==1 or not single) and s.st_size<=limit,'Bounded original regular file')
 fd=os.open(p,os.O_RDONLY|os.O_NOFOLLOW)
 try:
  need(identity(os.fstat(fd))==identity(s),'Original open identity')
  with os.fdopen(os.dup(fd),'rb') as f:b=f.read(limit+1)
  need(len(b)==s.st_size and identity(os.fstat(fd))==identity(s),'Stable full original read')
 finally:os.close(fd)
 need(identity(p.lstat())==identity(s),'Original path identity')
 return b,s
def inventory():
 rows={};allocated=0
 def walk(p,depth=0):
  nonlocal allocated
  need(depth<=12 and len(rows)<2048,'Finite owned scope')
  s=p.lstat();rel=str(p.relative_to(ROOT));allocated+=s.st_blocks*512
  row={'path':rel,'device':s.st_dev,'inode':s.st_ino,'mode':s.st_mode,'uid':s.st_uid,'gid':s.st_gid,'nlink':s.st_nlink,'bytes':s.st_size,'blocks':s.st_blocks}
  if rel!='.':row.update(mtimeNS=str(s.st_mtime_ns),ctimeNS=str(s.st_ctime_ns))
  else:row.pop('bytes');row.pop('blocks')
  if stat.S_ISREG(s.st_mode):row['sha256']=sha(read(p,single=False)[0])
  elif stat.S_ISLNK(s.st_mode):row['targetBase64']=base64.b64encode(os.fsencode(os.readlink(p))).decode('ascii')
  else:need(stat.S_ISDIR(s.st_mode),'Closed scope node types')
  rows[rel]=row
  if stat.S_ISDIR(s.st_mode):
   for e in sorted(os.scandir(p),key=lambda e:e.name):walk(pathlib.Path(e.path),depth+1)
 walk(ROOT)
 return rows,allocated
def guard(addition=0):
 need(shutil.disk_usage('/').free>=FLOOR+CAP,'Root floor plus full controls reserve')
 rows,used=inventory();need(used+addition+8192<=CAP,'Original 4MiB cap with allocation guard')
 return rows,used
need(ROOT.resolve(strict=True)==ROOT and ROOT.lstat().st_uid==1001,'Exact owned root')
before,used=guard()
need(used==4009984 and len(before)==938,'Exact reviewed completed-phase scope')
need('runs/mac-candidate' not in before,'Candidate not started')
closure,_=read(ROOT/'CONTROLS_CLOSED.json')
need(len(closure)==65536 and closure==bytes(65536),'Original closure reservation remains open')
seal_raw,_=read(ROOT/'SOURCE_SEAL_REVIEW3.json');need(sha(seal_raw)==SEAL_SHA,'Original revision3 seal')
seal=json.loads(seal_raw);historical=seal['originalFourteen']
need(len(historical)==14 and sum(p['bytes']for p in historical.values())==275022,'Closed original14')
current={**historical,**seal['files'],'SOURCE_SEAL_REVIEW3.json':{'bytes':len(seal_raw),'sha256':SEAL_SHA},'SOURCE_READBACK_REVIEW3.json':{'bytes':3131,'sha256':'4a45daa8445ab39848c607ec999bb5b9b8abd81e8f874e885afcf2d8d3c69f22'}}
need(len(current)==22,'All original source leaves')
for name,pin in current.items():
 b,_=read(ROOT/name);need(len(b)==pin['bytes'] and sha(b)==pin['sha256'],'Original22 source pin')
raws={};metadata=[];alloc14=0
for name,pin in sorted(historical.items()):
 p=ROOT/name;s=p.lstat()
 need(stat.S_ISREG(s.st_mode) and stat.S_IMODE(s.st_mode)==0o644 and s.st_nlink==1,'Original single regular0644 source')
 attrs=[{'nameBase64':base64.b64encode(os.fsencode(n)).decode('ascii'),'valueBase64':base64.b64encode(os.getxattr(p,n,follow_symlinks=False)).decode('ascii')}for n in sorted(os.listxattr(p,follow_symlinks=False))]
 need(sum(len(a['valueBase64'])for a in attrs)<=65536,'Bounded source xattrs')
 b,s2=read(p);need(identity(s)==identity(s2) and len(b)==pin['bytes'] and sha(b)==pin['sha256'],'Exact historical source')
 attrs2=[{'nameBase64':base64.b64encode(os.fsencode(n)).decode('ascii'),'valueBase64':base64.b64encode(os.getxattr(p,n,follow_symlinks=False)).decode('ascii')}for n in sorted(os.listxattr(p,follow_symlinks=False))]
 need(attrs==attrs2,'Stable complete source xattrs')
 raws[name]=b;alloc14+=s.st_blocks*512
 metadata.append({'name':name,'originalPath':str(p),'bytes':len(b),'sha256':sha(b),'device':s.st_dev,'inode':s.st_ino,'mode':s.st_mode,'uid':s.st_uid,'gid':s.st_gid,'nlink':s.st_nlink,'blocks':s.st_blocks,'allocatedBytes':s.st_blocks*512,'atimeNS':str(s.st_atime_ns),'mtimeNS':str(s.st_mtime_ns),'ctimeNS':str(s.st_ctime_ns),'xattrs':attrs})
need(alloc14==307200,'Exact original14 allocation')
manifest=canon({'schema':'otzaria.focused-legacy-source-archive/1','root':str(ROOT),'sourceSealSHA256':SEAL_SHA,'originalFourteen':historical,'entries':metadata,'atimeCapturedBeforeContentRead':True,'atimeExcludedFromStability':True,'originalBytes':275022,'originalAllocatedBytes':alloc14})
need(len(manifest)<=16384,'Bounded complete metadata')
zipbuf=io.BytesIO()
with zipfile.ZipFile(zipbuf,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6,allowZip64=False)as z:
 for name,b in sorted({**raws,'MANIFEST.json':manifest}.items()):
  info=zipfile.ZipInfo(name,(1980,1,1,0,0,0));info.create_system=3;info.external_attr=(stat.S_IFREG|0o644)<<16;info.compress_type=zipfile.ZIP_DEFLATED
  z.writestr(info,b,compress_type=zipfile.ZIP_DEFLATED,compresslevel=6)
archive=zipbuf.getvalue();need(len(archive)<=131072,'Bounded complete archive')
with zipfile.ZipFile(io.BytesIO(archive))as z:
 need(len(z.infolist())==15 and set(z.namelist())==set(raws)|{'MANIFEST.json'},'Exact archived membership')
 for name,b in {**raws,'MANIFEST.json':manifest}.items():need(z.read(name)==b,'Full member readback')
resolver=RESOLVER_TEMPLATE.replace('__ARCHIVE_BYTES__',str(len(archive))).replace('__ARCHIVE_SHA__',sha(archive)).replace('__MANIFEST_BYTES__',str(len(manifest))).replace('__MANIFEST_SHA__',sha(manifest)).encode()
need(len(resolver)<=16384 and b'__ARCHIVE_' not in resolver and b'__MANIFEST_'not in resolver,'Complete resolver source')
ast.parse(resolver,filename='resolve_preserved_sources.py')
own=pathlib.Path(__file__).read_bytes();need(len(own)<=24576,'Bounded preserved preparer')
phasepins=[]
for phase in ['accounting-candidate','accounting-omit-first','mac-baseline']:
 d=ROOT/'runs'/phase
 paths=[p for p in d.rglob('*')if p.is_file()]
 need(len(paths)==(10 if phase=='mac-baseline' else 5),'Exact phase file membership')
 for p in sorted(paths):
  b,s=read(p);ep=EXPECTED_PHASE_PINS[str(p.relative_to(ROOT))];need(len(b)==ep['bytes'] and sha(b)==ep['sha256'],'Completed phase exact raw pin');phasepins.append({'path':str(p.relative_to(ROOT)),'bytes':len(b),'sha256':sha(b),'allocatedBytes':s.st_blocks*512})
receipt={'schema':'otzaria.focused-source-storage-preparation/1','status':'ADDITIVE_SOURCE_PREPARATION_NO_RAW_RETIREMENT','root':str(ROOT),'originalSealSHA256':SEAL_SHA,'originalSourcePins':current,'archive':{'path':'HISTORICAL_SOURCES.zip','bytes':len(archive),'sha256':sha(archive),'members':15},'manifest':{'bytes':len(manifest),'sha256':sha(manifest)},'resolver':{'path':'resolve_preserved_sources.py','bytes':len(resolver),'sha256':sha(resolver)},'preparer':{'path':'PREPARE_SOURCE_STORAGE.py','bytes':len(own),'sha256':sha(own)},'originalScopeEntries':len(before),'originalScopeAllocatedBytes':used,'originalScopeFingerprintSHA256':sha(canon(before)),'sourceStatStabilityExcludesAtime':True,'rootDirectoryTimesSizeBlocksExcludedFromFingerprint':True,'preservedHistoricalRawBytes':275022,'retirableAllocatedBytes':alloc14,'phaseEvidencePins':phasepins,'futureMigrationReserveBytes':FUTURE_RESERVE,'originalArchiveOutputAndControlCapsUnchanged':True,'testsRun':0,'nativeEnumeration':0,'archiveUpload':False,'rawSourcesRetired':False,'at':datetime.datetime.now(datetime.timezone.utc).isoformat()}
files={'HISTORICAL_SOURCES.zip':archive,'resolve_preserved_sources.py':resolver,'PREPARE_SOURCE_STORAGE.py':own,'SOURCE_STORAGE_PREPARED.json':canon(receipt),'SOURCE_STORAGE_README.md':README.encode()}
need(all(not os.path.lexists(ROOT/name)for name in files),'Exclusive additive source preparation')
estimated=sum(((len(b)+4095)//4096)*4096 for b in files.values())
need(estimated+FUTURE_RESERVE<=172032 and used+estimated+FUTURE_RESERVE+8192<=CAP,'Complete preparation and later-migration allocation admission')
for name,b in files.items():
 guard(((len(b)+4095)//4096)*4096+FUTURE_RESERVE)
 fd=os.open(ROOT/name,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o644)
 try:
  v=memoryview(b)
  while v:
   n=os.write(fd,v);need(n>0,'Complete source write');v=v[n:]
  os.fsync(fd);os.fchown(fd,1001,1001)
 finally:os.close(fd)
 need(read(ROOT/name)[0]==b,'Full prepared file readback')
fd=os.open(ROOT,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW)
try:os.fsync(fd)
finally:os.close(fd)
after,used_after=guard(FUTURE_RESERVE)
need(set(after)==set(before)|set(files),'Closed additive membership')
for p,row in before.items():need(after[p]==row,'Existing source/fixture/evidence changed during preparation: '+p)
actual_added=used_after-used
need(actual_added+FUTURE_RESERVE<=172032,'Actual full added allocation and migration reserve')
print(json.dumps({'status':'SOURCE_STORAGE_PREPARED_RAW14_INTACT','root':str(ROOT),'files':[{'path':n,'bytes':len(b),'sha256':sha(b),'allocatedBytes':(ROOT/n).lstat().st_blocks*512}for n,b in files.items()],'originalScopeEntries':len(before),'originalScopeSHA256':sha(canon(before)),'existingSourceFixturesAndEvidenceUnchanged':True,'addedAllocatedBytes':actual_added,'futureMigrationReserveBytes':FUTURE_RESERVE,'scopeAllocatedBytes':used_after,'projectedCandidateGuardAfterRetirement':used_after+FUTURE_RESERVE-307200+208896+8192,'archiveSHA256':sha(archive),'resolverSHA256':sha(resolver),'preparedSHA256':sha(files['SOURCE_STORAGE_PREPARED.json']),'testsRun':0,'rawSourcesRetired':False,'nativeActions':0}))
