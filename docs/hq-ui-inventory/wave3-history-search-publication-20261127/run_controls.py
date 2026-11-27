from pathlib import Path, PurePosixPath
import base64, hashlib, io, json, os, re, shutil, subprocess, tarfile, time, traceback

ROOT=Path('/home/ubuntu/otzaria-wave3-history-search-publication-controls-20261127')
CACHE=Path('/home/ubuntu/otzaria-wave3-saved-results-reveal-20261127/controls/attempt-1/module-cache')
OLD=Path('/home/ubuntu/otzaria-wave3-saved-results-reveal-20261127/controls')
SWIFT='/mnt/development/tooling/swiftly/toolchains/6.4.3/usr/bin/swiftc'
FLOOR=1342177280;CAP=100*1024*1024
sha=lambda b:hashlib.sha256(b).hexdigest()
steps=[]
def footprint():
 return sum(x.stat().st_blocks*512 for d in [ROOT,OLD] if d.exists()for x in d.rglob('*')if x.is_file())
def guard():
 assert shutil.disk_usage('/home/ubuntu').free>=FLOOR
 assert footprint()<=CAP
def run(name,args):
 guard();started=time.time()
 with (ROOT/(name+'.stdout')).open('wb')as o,(ROOT/(name+'.stderr')).open('wb')as e:
  p=subprocess.Popen(args,stdout=o,stderr=e);pid=p.pid
  code=p.wait(timeout=60)
 step={'name':name,'argv':args,'pid':pid,'exit':code,'started':started,'finished':time.time(),'free_after':shutil.disk_usage(ROOT).free,'task_bytes':footprint()}
 steps.append(step);(ROOT/'STATUS.json').write_text(json.dumps({'steps':steps},indent=2)+'\n');guard();return code

try:
 guard();ROOT.mkdir(exist_ok=False)
 assert sha(Path(SWIFT).read_bytes())=='39d41b0dc9eba623b0e37cea42c3145720168214ba4349d6fa3bd9db9b1e651a'
 data=base64.b64decode(PAYLOAD_BASE64,validate=True)
 assert len(data)==PAYLOAD_BYTES and sha(data)==PAYLOAD_SHA
 (ROOT/'INPUTS.tar.xz').write_bytes(data)
 with tarfile.open(fileobj=io.BytesIO(data),mode='r:xz')as t:
  ms=t.getmembers();assert len({x.name for x in ms})==len(ms)
  for m in ms:assert m.isfile()and not PurePosixPath(m.name).is_absolute()and '..'not in PurePosixPath(m.name).parts
  values={m.name:t.extractfile(m).read()for m in ms}
 manifest=json.loads(values.pop('INPUTS_MANIFEST.json'));assert set(values)=={r['path']for r in manifest['files']}
 for r in manifest['files']:
  b=values[r['path']];assert len(b)==r['bytes']and sha(b)==r['sha256']
  p=ROOT/'inputs'/r['path'];p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b)
 (ROOT/'INPUTS_MANIFEST.json').write_text(json.dumps(manifest,indent=2)+'\n')
 outputs=[]
 for variant in ['baseline','intermediate','candidate']:
  args=[SWIFT,'-swift-version','6','-strict-concurrency=complete','-parse-as-library','-module-cache-path',str(CACHE),str(ROOT/'inputs/BoundaryFixtures.swift'),str(ROOT/'inputs'/variant/'SessionCapsule.swift'),str(ROOT/'inputs/Controls.swift'),'-o',str(ROOT/(variant+'-controls'))]
  if run(variant+'-compile',args)!=0:raise RuntimeError(variant+' actual-source capsule failed to compile')
  code=run(variant+'-run',[str(ROOT/(variant+'-controls'))])
  stdout=(ROOT/(variant+'-run.stdout')).read_text();match=re.search(r'RESULT passed=(\d+) failed=(\d+)',stdout)
  assert match is not None
  outputs.append({'variant':variant,'exit':code,'passed':int(match[1]),'failed':int(match[2]),'failures':[s for s in stdout.splitlines()if s.startswith('FAIL ')]})
 assert outputs[0]['exit']==1 and any('Saved open-close ABA'in s for s in outputs[0]['failures'])
 assert outputs[1]['exit']==1 and len(outputs[1]['failures'])==1 and 'FIRST retirement callback'in outputs[1]['failures'][0]
 assert outputs[2]['exit']==0 and outputs[2]['failed']==0
 result={'status':'PASS_SOURCE_CONTROLS_ONLY','boundary':'Exact actual Session helper/callback/full caller/full unmount source; explicit stable app/UIKit/window/store/model boundaries. No old helper fabricated, no Core or native execution.','inputs_sha256':sha(data),'results':outputs,'steps':steps,'free_after':shutil.disk_usage(ROOT).free,'task_bytes':footprint()}
 (ROOT/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps({'status':result['status'],'results':outputs,'result_sha256':sha((ROOT/'RESULT.json').read_bytes()),'path':str(ROOT/'RESULT.json'),'free_after':result['free_after'],'task_bytes':result['task_bytes']}))
except BaseException as e:
 result={'status':'FAILED','error':repr(e),'traceback':traceback.format_exc(),'steps':steps}
 if ROOT.exists():(ROOT/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps(result));raise
