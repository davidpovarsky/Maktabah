import ast,base64,datetime,gzip,hashlib,json,os,shutil,signal,subprocess,textwrap,time,traceback
from pathlib import Path
SCOPE=Path('/home/ubuntu/.codex/artifacts/otzaria-wave3-profile-group-controls-20261127')
ROOT=Path('/home/ubuntu/.codex/worktrees/Maktabah-wave3-integration-rootfs-20261127')
BASE='37caafcfaa4eb9b7bcfd02857bcb7c3f62daa4be'
CORE=ROOT/'.git/search-continuation-integrated-controls-20261127/output'
PORTABLE=SCOPE/'group-parent-portable-attempt-2'
SWIFT=Path('/mnt/development/tooling/swiftly/toolchains/6.4.3/usr/bin/swiftc')
FLOOR=1342177280;CAP=300*1024*1024
sha=lambda b:hashlib.sha256(b).hexdigest()
def pin(p):
 b=Path(p).read_bytes();return {'bytes':len(b),'sha256':sha(b)}
def free():
 s=os.statvfs(SCOPE);return s.f_bavail*s.f_frsize
def allocated():
 seen=set();value=0
 for p in SCOPE.rglob('*'):
  s=p.lstat()
  if (s.st_dev,s.st_ino)not in seen:seen.add((s.st_dev,s.st_ino));value+=s.st_blocks*512
 return value
def proc_identity(pid):
 try:
  raw=Path('/proc',str(pid),'stat').read_text();v=raw[raw.rfind(')')+2:].split()
  return {'pid':pid,'parent':int(v[1]),'group':int(v[2]),'startTicks':int(v[19])}
 except(FileNotFoundError,ProcessLookupError):return None
def blob(p):return subprocess.check_output(['git','-C',str(ROOT),'show',BASE+':'+p])

attempt=SCOPE/'group-parent-boundaries-attempt-1'
assert not attempt.exists()
assert free()>FLOOR+32*1024*1024 and allocated()<CAP-64*1024*1024
attempt.mkdir(mode=0o750)
result={'status':'RUNNING','steps':[],'scope':'Actual Core/UIRouting/Host, Group/Viewer bindings, original Store/Adapter/persistence and exact manager publication bodies. Explicit source/native/geometry/Reader/resolver boundary objects. No app or native acceptance.',
        'nativeRuns':0,'AppleSDK':'NOT_RUN','started':datetime.datetime.now(datetime.timezone.utc).isoformat()}
def save():(attempt/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
driver=SCOPE/'public-search-portable-runner-attempt-2.py'
assert pin(driver)['sha256']=='ff27bc9c964c9a86c0869e83f679e105ff773807a73777fc32241f36538c9b0c'
s=driver.read_text();outer=next(x for x in ast.parse(s).body if isinstance(x,ast.FunctionDef)and x.name=='main')
fn=next(x for x in outer.body if isinstance(x,ast.FunctionDef)and x.name=='run')
run_source=textwrap.dedent(''.join(s.splitlines(keepends=True)[fn.lineno-1:fn.end_lineno]))
exec(compile(run_source,str(driver)+':exact-bounded-run-body','exec'),globals())
result['runner']={'file':pin(driver),'exactFunctionSHA256':sha(run_source.encode())}
try:
 payload=json.loads(gzip.decompress(base64.b64decode(PAYLOAD_B64)))
 inputs=attempt/'inputs';output=attempt/'output';inputs.mkdir();output.mkdir()
 result['inputFiles']=[]
 for row in payload['files']:
  relative=Path(row['path']);assert not relative.is_absolute()and'..'not in relative.parts
  b=gzip.decompress(base64.b64decode(row['gzipBase64']));assert len(b)==row['bytes']and sha(b)==row['sha256']
  p=inputs/relative;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b)
  result['inputFiles'].append({k:v for k,v in row.items()if k!='gzipBase64'})
 prior=json.loads((PORTABLE/'RESULT.json').read_text())
 assert any(s['name']=='compile-actual-host'and s.get('exit')==0 for s in prior['steps'])
 result['readOnlyModuleReuse']={'priorResult':pin(PORTABLE/'RESULT.json'),'originalCoreResult':prior['originalCoreResult'],
  'coreJoins':prior['coreSourceJoins'],'UIcompile':prior['priorTimeout'],'packageSources':prior['packageInputs'],'artifacts':[]}
 for row in prior['packageInputs']:
  p=PORTABLE/'inputs/package'/row['path'];assert pin(p)=={k:row[k]for k in ['bytes','sha256']}
  assert sha(blob(row['path']))==row['originalSHA256']
 for row in prior['coreSourceJoins']:assert sha(blob(row['path']))==row['sha256']
 for folder,names in [(CORE,['OtzariaActionCore.swiftmodule','libOtzariaActionCore.so']),
  (PORTABLE/'output',['OtzariaUIRouting.swiftmodule','libOtzariaUIRouting.so','ChavrusaUIRoutingHost.swiftmodule','libChavrusaUIRoutingHost.so'])]:
  for name in names:result['readOnlyModuleReuse']['artifacts'].append({'path':str(folder/name),**pin(folder/name)})
 source=json.loads((inputs/'domain/SOURCE_INPUTS.json').read_text())
 result['sourceJoins']=[]
 for row in source['files']:
  if row['origin']=='source':p=PORTABLE/'inputs/source'/row['path'];assert pin(p)=={k:row[k]for k in ['bytes','sha256']}
  else:assert sha(blob(row['path']))==row['sha256']
  result['sourceJoins'].append(row)
 shutil.copytree(CORE/'OtzariaActionCore_OtzariaActionCore.bundle',output/'OtzariaActionCore_OtzariaActionCore.bundle')
 common=[str(SWIFT),'-swift-version','6','-strict-concurrency=complete','-parse-as-library','-module-cache-path',str(SCOPE/'module-cache-local')]
 links=['-I',str(CORE),'-L',str(CORE),'-lOtzariaActionCore','-Xlinker','-rpath','-Xlinker',str(CORE),
  '-I',str(PORTABLE/'output'),'-L',str(PORTABLE/'output'),'-lOtzariaUIRouting','-lChavrusaUIRoutingHost','-Xlinker','-rpath','-Xlinker',str(PORTABLE/'output')]
 result['compiler']={'path':str(SWIFT),**pin(SWIFT)}
 assert result['compiler']['sha256']=='39d41b0dc9eba623b0e37cea42c3145720168214ba4349d6fa3bd9db9b1e651a'
 run('compile-portable-controls',common+links+[str(inputs/'PortableControls.swift'),'-o',str(output/'portable-controls')])
 run('run-portable-controls',[str(output/'portable-controls')],timeout=30)
 result['portable']=json.loads((attempt/'run-portable-controls.stdout').read_text());assert result['portable']['fail']==0
 files=[str(p)for p in sorted((inputs/'domain').glob('*.swift'))]
 run('compile-original-domain-controls',common+links+files+['-o',str(output/'domain-controls')])
 for name,args,expected in [('original-before-feature',['--original-before-feature'],2),('candidate',[],0)]:
  try:run('run-'+name,[str(output/'domain-controls')]+args,timeout=45)
  except RuntimeError:
   if not(expected and result['steps'][-1].get('exit')==1):raise
  result[name]=json.loads((attempt/('run-'+name+'.stdout')).read_text());assert result[name]['fail']==expected
 # ONLY omit the newly required actual-parent reread. Other original body
 # guards remain exact, so unchanged counters cannot masquerade as geometry.
 viewer=inputs/'domain/MaktabahNativeViewerParentContinuation.swift'
 b=viewer.read_text();start=b.index('    func validateWorkspaceSelectionSource() throws {');end=b.index('\n    func release()',start)
 negative=b[:start]+'    func validateWorkspaceSelectionSource() throws { try validateRoot() }\n'+b[end:]
 counter=inputs/'COUNTERFACTUAL-ViewerParent.swift';counter.write_text(negative)
 result['counterfactual']={'original':pin(viewer),'negative':pin(counter),'change':'Replace only Group visible-parent source method with original root-counter check.'}
 run('compile-visible-parent-counterfactual',common+links+[str(counter)if p==str(viewer)else p for p in files]+['-o',str(output/'negative-controls')])
 try:run('run-visible-parent-counterfactual',[str(output/'negative-controls'),'--visibility-counterfactual'],timeout=30)
 except RuntimeError:
  if result['steps'][-1].get('exit')!=1:raise
 result['visibilityNegative']=json.loads((attempt/'run-visible-parent-counterfactual.stdout').read_text());assert result['visibilityNegative']['fail']==2
 for row in prior['submittedInputs']:
  if row['path'].endswith('.swift')and row['path'].startswith(('source/','proposal-candidate/')):
   run('syntax-'+Path(row['path']).stem,[str(SWIFT),'-frontend','-parse','-target','arm64-apple-ios27.0-simulator','-D','DEBUG',str(PORTABLE/'inputs'/row['path'])],timeout=30)
 result['status']='PASS_ACTUAL_SOURCE_CONTROLS_AND_MEANINGFUL_NEGATIVES_NOT_NATIVE'
 result['products']=[{'path':p.relative_to(attempt).as_posix(),**pin(p)}for p in sorted(output.iterdir())if p.is_file()]
except BaseException as error:
 result['status']='FAILED';result['error']=repr(error);result['traceback']=traceback.format_exc()
finally:
 result['freeFinal']=free();result['allocatedFinal']=allocated();result['finished']=datetime.datetime.now(datetime.timezone.utc).isoformat();save()
 print(json.dumps({'path':str(attempt),'result':pin(attempt/'RESULT.json'),'status':result['status'],'error':result.get('error'),'steps':[{'name':s['name'],'exit':s.get('exit')}for s in result['steps']]}))
