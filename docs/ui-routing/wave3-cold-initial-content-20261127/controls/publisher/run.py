import ast,base64,datetime,gzip,hashlib,json,os,shutil,signal,subprocess,textwrap,time,traceback
from pathlib import Path
SCOPE=Path('/mnt/development/projects/diagnostics/otzaria-wave3-cold-initial-content-20261127')
PRIOR=Path('/home/ubuntu/.codex/artifacts/otzaria-wave3-profile-group-controls-20261127')
REPO=Path('/home/ubuntu/.codex/worktrees/Maktabah-wave3-integration-rootfs-20261127')
BASE='ce4fe5a327168524f6f1fef1e7792a275ece0ebe'
SWIFT=Path('/mnt/development/tooling/swiftly/toolchains/6.4.3/usr/bin/swiftc')
FLOOR=687865856;ROOT_FLOOR=1342177280;CAP=300*1024*1024
sha=lambda b:hashlib.sha256(b).hexdigest()
def pin(p):
 b=Path(p).read_bytes();return {'bytes':len(b),'sha256':sha(b)}
def free():
 s=os.statvfs(SCOPE);return s.f_bavail*s.f_frsize
def rootfree():
 s=os.statvfs(PRIOR);return s.f_bavail*s.f_frsize
def allocated():
 seen=set();value=0
 for base in [SCOPE,PRIOR]:
  for p in base.rglob('*'):
   s=p.lstat()
   if (s.st_dev,s.st_ino)not in seen:seen.add((s.st_dev,s.st_ino));value+=s.st_blocks*512
 return value
def proc_identity(pid):
 try:
  raw=Path('/proc',str(pid),'stat').read_text();v=raw[raw.rfind(')')+2:].split()
  return {'pid':pid,'parent':int(v[1]),'group':int(v[2]),'startTicks':int(v[19])}
 except(FileNotFoundError,ProcessLookupError):return None
assert os.statvfs(SCOPE.parent).f_bavail*os.statvfs(SCOPE.parent).f_frsize>FLOOR+64*1024*1024
assert rootfree()>ROOT_FLOOR+64*1024*1024
SCOPE.mkdir(mode=0o750,exist_ok=True)
attempt=SCOPE/'publisher-followup-attempt-1';assert not attempt.exists();attempt.mkdir(mode=0o750)
result={'status':'RUNNING','base':BASE,'steps':[],'nativeRuns':0,'AppleSDK':'NOT_RUN',
 'started':datetime.datetime.now(datetime.timezone.utc).isoformat(),
 'scope':'Actual complete original publisher and cold load body; explicit iOS/macOS conditional selection over domain/backend/state boundary shells. First35 unchanged and separate; no app SDK/native.'}
def save():(attempt/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
driver=PRIOR/'public-search-portable-runner-attempt-2.py'
assert pin(driver)['sha256']=='ff27bc9c964c9a86c0869e83f679e105ff773807a73777fc32241f36538c9b0c'
s=driver.read_text();outer=next(x for x in ast.parse(s).body if isinstance(x,ast.FunctionDef)and x.name=='main')
fn=next(x for x in outer.body if isinstance(x,ast.FunctionDef)and x.name=='run')
run_source=textwrap.dedent(''.join(s.splitlines(keepends=True)[fn.lineno-1:fn.end_lineno]))
exec(compile(run_source,str(driver)+':exact-bounded-run-body','exec'),globals())
result['runner']={'file':pin(driver),'exactFunctionSHA256':sha(run_source.encode())}
try:
 payload=json.loads(gzip.decompress(base64.b64decode(PAYLOAD_B64)))
 inputs=attempt/'inputs';output=attempt/'output';output.mkdir()
 result['inputs']=[]
 for row in payload['files']:
  relative=Path(row['path']);assert not relative.is_absolute() and '..'not in relative.parts
  b=gzip.decompress(base64.b64decode(row['gzipBase64']));assert len(b)==row['bytes']and sha(b)==row['sha256']
  p=inputs/relative;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b)
  result['inputs'].append({k:v for k,v in row.items()if k!='gzipBase64'})
 result['sourceJoins']=[]
 for row in payload['originals']:
  b=subprocess.check_output(['git','-C',str(REPO),'show',BASE+':'+row['path']])
  assert len(b)==row['bytes']and sha(b)==row['sha256'];result['sourceJoins'].append(row)
 result['compiler']={'path':str(SWIFT),**pin(SWIFT)}
 assert result['compiler']['sha256']=='39d41b0dc9eba623b0e37cea42c3145720168214ba4349d6fa3bd9db9b1e651a'
 cache=PRIOR/'module-cache-local';writers=[]
 for proc in Path('/proc').iterdir():
  if not proc.name.isdigit():continue
  try:
   cmd=(proc/'cmdline').read_bytes().replace(b'\0',b' ').decode(errors='replace')
   exe=os.readlink(proc/'exe')
   if 'swift' in Path(exe).name and str(cache) in cmd:writers.append({'pid':proc.name,'command':cmd})
  except(OSError,PermissionError):pass
 result['cacheWritersBefore']=writers;assert not writers
 common=[str(SWIFT),'-swift-version','6','-strict-concurrency=complete','-parse-as-library','-module-cache-path',str(cache)]
 commonFiles=[str(p)for p in sorted((inputs/'compiled/common').glob('*.swift'))]
 for platform in ['ios','macos']:
  for variant in ['before','candidate']:
   assert rootfree()>ROOT_FLOOR
   name=platform+'-'+variant
   files=[str(p)for p in sorted((inputs/('compiled/'+variant)).glob('*.swift'))]
   run('compile-'+name,common+['-D','PUBLISHER_'+platform.upper()]+commonFiles+files+['-o',str(output/name)],timeout=120)
   try:run('run-'+name,[str(output/name)],timeout=40)
   except RuntimeError:
    if variant!='before' or result['steps'][-1].get('exit')!=1:raise
   counts=json.loads((attempt/('run-'+name+'.stdout')).read_text());result[name]=counts;save()
   assert counts['fail']==({'ios':7,'macos':2}[platform] if variant=='before'else 0)
 for p in sorted((inputs/'candidate').rglob('*.swift'))+[inputs/'proposal/SESSION.swift']:
  for configuration in ['debug','release']:
   flags=['-D','DEBUG']if configuration=='debug'else[]
   run('parse-'+p.name+'-'+configuration,[str(SWIFT),'-frontend','-parse','-target','arm64-apple-ios27.0-simulator']+flags+[str(p)],timeout=25)
 result['status']='PASS'
except BaseException as error:
 result['status']='FAILED';result['error']=repr(error);result['traceback']=traceback.format_exc()
finally:
 result['freeFinal']=free();result['rootFreeFinal']=rootfree();result['allocatedFinal']=allocated()
 result['finished']=datetime.datetime.now(datetime.timezone.utc).isoformat();save()
 print(json.dumps({'status':result['status'],'result':str(attempt/'RESULT.json'),**pin(attempt/'RESULT.json'),
  'error':result.get('error'),'counts':{k:{x:result[k][x]for x in ['pass','fail']}for k in ['ios-before','ios-candidate','macos-before','macos-candidate']if k in result},
  'free':result['freeFinal'],'rootFree':result['rootFreeFinal'],'allocated':result['allocatedFinal']}))
