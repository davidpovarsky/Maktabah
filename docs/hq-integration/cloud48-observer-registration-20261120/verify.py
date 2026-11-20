#!/usr/bin/env python3
from pathlib import Path
import gzip,hashlib,json,difflib
r=Path(__file__).resolve().parent
m=json.loads((r/'MANIFEST.json').read_bytes())
for x in m['files']:
 d=(r/x['path']).read_bytes();assert len(d)==x['bytes'] and hashlib.sha256(d).hexdigest()==x['sha256']
p=json.loads((r/'SOURCE_PROOF.json').read_bytes())
before=gzip.decompress((r/'base.swift.gz').read_bytes()); after=gzip.decompress((r/'candidate.swift.gz').read_bytes())
assert hashlib.sha256(before).hexdigest()==p['base_sha256'] and hashlib.sha256(after).hexdigest()==p['candidate_sha256']
patch=''.join(difflib.unified_diff(before.decode().splitlines(True),after.decode().splitlines(True),fromfile='a/'+p['path'],tofile='b/'+p['path'])).encode()
assert patch==(r/'PROPOSED.patch').read_bytes() and hashlib.sha256(patch).hexdigest()==p['patch_sha256']
old="        let token = center.addObserver(forName: changedNotification, object: nil, queue: nil) { _ in\n            lifetime.retire()\n        }\n        observer.withLock { $0 = token }\n"
new="        observer.withLock { value in\n            value = center.addObserver(forName: changedNotification, object: nil, queue: nil) { _ in\n                lifetime.retire()\n            }\n        }\n"
assert before.count(old.encode())==after.count(new.encode())==1 and after.replace(new.encode(),old.encode(),1)==before
log=gzip.decompress((r/'actual-failed-compile.log.gz').read_bytes());assert hashlib.sha256(log).hexdigest()==p['actual_failure']['compile_log_sha256']
assert b'inout sending' in log and b'observer.withLock { $0 = token }' in log
assert p['source_commit']=='7af3a06d48ccbe77acef180cb99d120971c3804e' and p['swift_typecheck']=='NOT_RUN'
print(json.dumps({'status':'PASS_SOURCE_INVERSE_AND_RETAINED_COMPILE_FAILURE','source':p['source_commit'],'files':len(m['files']),'actual_swift_candidate_executed':0}))
