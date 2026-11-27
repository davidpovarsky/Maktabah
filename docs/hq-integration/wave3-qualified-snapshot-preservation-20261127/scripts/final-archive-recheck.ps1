$OutputEncoding=[Console]::OutputEncoding=New-Object System.Text.UTF8Encoding($false)
@'
from pathlib import Path
import json,hashlib,shutil,datetime,time
p=Path(r'C:\Users\DAVID\.codex\artifacts\otzaria-wave3-qualified-snapshot-preservation-20261127')
def digest(f):
 h=hashlib.sha256()
 with f.open('rb') as x:
  for b in iter(lambda:x.read(1024**2),b''):h.update(b)
 return h.hexdigest()
def identity(f):
 s=f.stat();return {'bytes':s.st_size,'device':s.st_dev,'inode':s.st_ino,'mtime_ns':s.st_mtime_ns,'ctime_ns':s.st_ctime_ns}
receipt=p/'VERIFIED_DIFFERENTIAL.json'
assert digest(receipt)=='1be15f9c4f63809eaedbadfbabfad49ea3283673e71c31906c50d524f7be5fd9'
v=json.loads(receipt.read_bytes())
assert v['status']=='COMPLETE_QUALIFIED_SNAPSHOT_DIFFERENTIAL_AND_ALL_REFERENCES_VERIFIED_NOT_RETIRED'
receive=json.loads((p/'RECEIVE_RESULT.json').read_bytes())
rows=list(v['base_archives'])+[{'id':'qualified-snapshot-differential','archive':v['archive'],'archive_sha256':v['archive_sha256'],'archive_bytes':v['archive_bytes'],'archive_identity':receive['archive_identity']}]
started=time.monotonic();before=shutil.disk_usage(p).free;assert before>=2415919104
checked=[]
for r in rows:
 f=Path(r['archive']);a=identity(f);assert a==r['archive_identity']
 h=digest(f);assert h==r['archive_sha256'] and a['bytes']==r['archive_bytes'] and identity(f)==a
 checked.append({'id':r['id'],'path':str(f),'sha256':h,'bytes':a['bytes'],'identity':a})
assert digest(receipt)=='1be15f9c4f63809eaedbadfbabfad49ea3283673e71c31906c50d524f7be5fd9'
assert all(identity(Path(r['path']))==r['identity'] for r in checked)
after=shutil.disk_usage(p).free;assert after>=2415919104
r={'status':'ALL_FOUR_VERIFIED_ARCHIVES_REHASHED_UNCHANGED_BEFORE_EXACT_RETIREMENT','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source_root':v['source_root'],'manifest_sha256':v['manifest_sha256'],'member_verification_receipt_sha256':digest(receipt),'base_archives_proof_sha256':v['base_archives_proof_sha256'],'reference_plan_sha256':v['reference_plan_sha256'],'archives':checked,'free_before':before,'free_after':after,'seconds':time.monotonic()-started,'anything_deleted':False}
b=(json.dumps(r,sort_keys=True,separators=(',',':'))+'\n').encode()
with (p/'FINAL_ARCHIVE_BINDINGS.json').open('xb') as f:f.write(b)
print(json.dumps({'receipt':r,'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()}))
'@ | py -3 -
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
