from pathlib import Path, PurePosixPath
import datetime,hashlib,json,os,shlex,shutil,stat,subprocess,tarfile,time
SOURCE="/mnt/development/artifacts/otzaria-retained-20261125/retained-products-v1"
DEST=Path(r"C:\Users\DAVID\Code\Codex-Agent-HQ\artifacts\otzaria-retained-20261125\retained-products-v1")
ARCHIVE="retained-products.tar.gz"
EXPECTED_SIZE=5447045120
EXPECTED_SHA="9acb16c572f787929692bd86fabd2fbb982d0d85cff682daf545f13c8998c8a3"
MANIFEST_SHA="8726cd1d47144d4e5a90ca31d24df036ba52838bb4e1195879b028ddf856dafa"
OS_MARGIN=2*1024**3
FOREIGN_GROWTH=256*1024**2
SSH=["ssh","-o","BatchMode=yes","-o","ConnectTimeout=8","-o","ServerAliveInterval=15","-o","ServerAliveCountMax=3","torah-social"]
def utc():return datetime.datetime.now(datetime.timezone.utc).isoformat()
def digest(p):
 h=hashlib.sha256()
 with p.open("rb") as f:
  for b in iter(lambda:f.read(4*1024**2),b""):h.update(b)
 return h.hexdigest()
def remote_read(code,timeout=60):
 r=subprocess.run(SSH+[shlex.join(["python3","-c",code])],capture_output=True,timeout=timeout,check=True)
 return r.stdout
metadata=json.loads(remote_read("from pathlib import Path;import json,hashlib;p=Path("+repr(SOURCE)+");names=['MANIFEST.json','VERIFIED.json','RETIREMENT.json','PROTECTED_PROOFS.json','TRANSFER.json','TARGETS.txt','verify_archive.py'];print(json.dumps([{'name':n,'bytes':(p/n).stat().st_size,'sha256':hashlib.sha256((p/n).read_bytes()).hexdigest()} for n in names]))"))
assert next(x for x in metadata if x["name"]=="MANIFEST.json")["sha256"]==MANIFEST_SHA
assert DEST.parent.parent.parent.is_dir(),"Existing HQ artifacts root required"
assert not DEST.exists(),"Never overwrite a prior archival attempt"
needed=EXPECTED_SIZE+sum(x["bytes"] for x in metadata)+OS_MARGIN+FOREIGN_GROWTH
free_before=shutil.disk_usage(DEST.parent.parent.parent).free
assert free_before>=needed,{"status":"BLOCKED_SPACE_BEFORE_COPY","free":free_before,"required":needed}
DEST.mkdir(parents=True)
started=utc();total_remaining=EXPECTED_SIZE+sum(x["bytes"] for x in metadata)
def save_state(phase,received=0):
 data={"schema":"otzaria.retained-products-relocation/1","status":phase,"started_at":started,"updated_at":utc(),"source_directory":SOURCE,"destination_directory":str(DEST),"archive_bytes":EXPECTED_SIZE,"archive_sha256":EXPECTED_SHA,"received_current_file":received,"free_bytes":shutil.disk_usage(DEST).free,"pending_bytes":total_remaining,"oracle_deleted":False}
 (DEST/"COPY_PROGRESS.json").write_text(json.dumps(data,indent=2)+"\n")
def copy_one(name,size,expected_sha):
 global total_remaining
 target=DEST/name;partial=DEST/(name+".partial")
 assert not target.exists() and not partial.exists()
 code="""from pathlib import Path
import hashlib,sys,json
p=Path(%r)
assert p.is_file() and not p.is_symlink()
s=p.stat();assert s.st_size==%d
h=hashlib.sha256()
with p.open('rb') as f:
 for b in iter(lambda:f.read(4*1024**2),b''):
  h.update(b);sys.stdout.buffer.write(b)
sys.stdout.buffer.flush()
t=p.stat()
assert (s.st_dev,s.st_ino,s.st_size,s.st_mtime_ns)==(t.st_dev,t.st_ino,t.st_size,t.st_mtime_ns)
assert h.hexdigest()==%r
sys.stderr.write(json.dumps({'size':s.st_size,'sha256':h.hexdigest(),'source_unchanged':True})+'\\n')
"""%(SOURCE+"/"+name,size,expected_sha)
 proc=subprocess.Popen(SSH+[shlex.join(["python3","-c",code])],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
 h=hashlib.sha256();received=0;last=0
 try:
  with partial.open("xb") as out:
   for block in iter(lambda:proc.stdout.read(4*1024**2),b""):
    assert received+len(block)<=size,"Oversized source"
    free=shutil.disk_usage(DEST).free
    assert free>=total_remaining+OS_MARGIN+128*1024**2,{"status":"LIVE_STORAGE_GUARD","free":free,"pending":total_remaining}
    out.write(block);h.update(block);received+=len(block);total_remaining-=len(block)
    if received-last>=64*1024**2:
     save_state("COPYING_"+name,received);last=received
   out.flush();os.fsync(out.fileno())
  stderr=proc.stderr.read().decode("utf-8","replace")
  assert proc.wait(timeout=60)==0,stderr[-2000:]
  proof=json.loads(stderr)
  assert proof=={"size":size,"sha256":expected_sha,"source_unchanged":True}
  assert received==size and h.hexdigest()==expected_sha
  assert digest(partial)==expected_sha,"Written bytes hash mismatch"
  partial.rename(target)
 except BaseException:
  if proc.poll() is None:proc.terminate()
  try:proc.wait(timeout=10)
  except subprocess.TimeoutExpired:proc.kill();proc.wait()
  if partial.exists():partial.unlink()
  raise
 return {"name":name,"bytes":size,"sha256":expected_sha}
try:
 receipts=[]
 for item in metadata:receipts.append(copy_one(item["name"],item["bytes"],item["sha256"]))
 receipts.append(copy_one(ARCHIVE,EXPECTED_SIZE,EXPECTED_SHA))
 save_state("VERIFYING_ALL_ARCHIVE_MEMBERS")
 raw=(DEST/"MANIFEST.json").read_bytes();assert hashlib.sha256(raw).hexdigest()==MANIFEST_SHA
 expected=json.loads(raw)["files"]
 archive=DEST/ARCHIVE;seen=set();regular=set();hardlinks={};total=0;verify_started=time.monotonic()
 with tarfile.open(archive,"r:gz") as tf:
  for member in tf:
   name=member.name.rstrip("/")
   assert name in expected and name not in seen and not name.startswith("/") and ".." not in PurePosixPath(name).parts,name
   row=expected[name];seen.add(name)
   assert stat.S_IMODE(member.mode)==row["mode"],name+" mode"
   if member.isdir():assert row["kind"]=="directory",name
   elif member.issym():assert row["kind"]=="symlink" and member.linkname==row["target"],name
   elif member.islnk():
    assert row["kind"]=="file" and member.linkname in expected,name
    dest=expected[member.linkname]
    assert dest["kind"]=="file" and (dest["bytes"],dest["sha256"])==(row["bytes"],row["sha256"]),name
    hardlinks[name]=member.linkname
   elif member.isfile():
    assert row["kind"]=="file" and member.size==row["bytes"],name
    h=hashlib.sha256();count=0
    with tf.extractfile(member) as f:
     for block in iter(lambda:f.read(4*1024**2),b""):h.update(block);count+=len(block)
    assert count==row["bytes"] and h.hexdigest()==row["sha256"],name+" content"
    regular.add(name);total+=count
   else:raise AssertionError("Unexpected member "+name)
  while tf.fileobj.read(4*1024**2):pass
 assert seen==set(expected)
 for name,target in hardlinks.items():
  trail={name}
  while target not in regular:
   assert target in hardlinks and target not in trail,name+" dangling hardlink"
   trail.add(target);target=hardlinks[target]
 assert digest(archive)==EXPECTED_SHA
 result={"schema":"otzaria.retained-products-relocation/1","status":"PASS_EXACT_WINDOWS_COPY_ALL_MEMBERS_BYTES_MODES_SYMLINKS_GZIP_CRC","started_at":started,"finished_at":utc(),"source_directory":SOURCE,"authoritative_archive_path":str(archive),"archive_bytes":EXPECTED_SIZE,"archive_sha256":EXPECTED_SHA,"manifest_sha256":MANIFEST_SHA,"verified_members":len(seen),"regular_file_members":len(regular),"hardlinks":len(hardlinks),"verified_stored_regular_bytes":total,"verification_seconds":time.monotonic()-verify_started,"free_before":free_before,"free_after":shutil.disk_usage(DEST).free,"files":receipts,"oracle_deleted":False,"remote_source_modified":False}
 with (DEST/"WINDOWS_VERIFIED.json").open("x") as f:f.write(json.dumps(result,indent=2)+"\n");f.flush();os.fsync(f.fileno())
 print(json.dumps(result))
except BaseException as e:
 save_state("FAILED_"+type(e).__name__)
 print(json.dumps({"status":"FAILED","type":type(e).__name__,"error":str(e)[-1000:],"oracle_deleted":False}))
 raise
