import pathlib,base64,hashlib,json,zipfile,shutil,subprocess,os,time,signal,traceback
TASK=pathlib.Path('/home/ubuntu/otzaria-wave3-saved-results-reveal-20261127')
ROOT=pathlib.Path('/home/ubuntu/.codex/worktrees/Maktabah-wave3-integration-rootfs-20261127')
OWN=TASK/'controls/attempt-6'
PEER=pathlib.Path('/mnt/development/projects/worktrees/Maktabah-wave3-history-reader-controls-20261127')
CORE=ROOT/'.git/search-continuation-integrated-controls-20261127'
SWIFT=pathlib.Path('/mnt/development/tooling/swiftly/toolchains/6.4.3/usr/bin/swiftc')
BASE='24cd9291dbc87d799c22a41f0bc73a82c6415bfa'
FLOOR=1342177280;CAP=104857600

def sha(b):return hashlib.sha256(b).hexdigest()
def free():return shutil.disk_usage(TASK).free
def footprint():return sum(p.stat().st_blocks*512 for p in (TASK/'controls').rglob('*') if p.is_file())
def save(name,data):(OWN/name).write_text(json.dumps(data,indent=2,sort_keys=True)+'\n')
def git(*args):return subprocess.run(['git','-C',str(ROOT),'-c','gc.auto=0','-c','maintenance.auto=false',*args],capture_output=True,check=True).stdout
steps=[]
def run(name,argv,expected=0):
 assert free()>FLOOR and footprint()<CAP
 step={'name':name,'argv':list(map(str,argv)),'started':time.time()};steps.append(step)
 with (OWN/(name+'.stdout')).open('wb') as out,(OWN/(name+'.stderr')).open('wb') as err:
  p=subprocess.Popen(list(map(str,argv)),stdout=out,stderr=err,start_new_session=True,env={**os.environ,'TMPDIR':str(OWN/'tmp')})
  step['pid']=p.pid;step['startTicks']=pathlib.Path('/proc/'+str(p.pid)+'/stat').read_text().split()[21]
  save('STATUS.json',{'steps':steps})
  limit=time.time()+150
  while p.poll() is None:
   if free()<FLOOR or footprint()>CAP or time.time()>limit:
    step['guard']='owned process capacity/deadline';os.killpg(p.pid,signal.SIGTERM)
    try:p.wait(timeout=5)
    except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);p.wait()
    break
   time.sleep(.5)
  step.update(exit=p.returncode,finished=time.time(),free=free(),task_control_bytes=footprint())
  save('STATUS.json',{'steps':steps})
 if expected is not None and step['exit']!=expected:raise RuntimeError(name+' exit '+str(step['exit']))
 return p.returncode
assert not OWN.exists() and free()>FLOOR+60*1024*1024
OWN.mkdir();(OWN/'tmp').mkdir();(OWN/'original').mkdir()
try:
 payload=base64.b64decode(PAYLOAD_B64);assert sha(payload)==PAYLOAD_SHA
 (OWN/'INPUTS.zip').write_bytes(payload)
 with zipfile.ZipFile(OWN/'INPUTS.zip') as z:
  for n in z.namelist():assert not pathlib.PurePosixPath(n).is_absolute() and '..' not in pathlib.PurePosixPath(n).parts
  z.extractall(OWN/'inputs')
 manifest=json.loads((OWN/'inputs/INPUTS.json').read_text())
 for row in manifest:
  raw=(OWN/'inputs'/row['path']).read_bytes();assert sha(raw)==row['sha256'] and len(raw)==row['bytes']
 assert sha(SWIFT.read_bytes())=='39d41b0dc9eba623b0e37cea42c3145720168214ba4349d6fa3bd9db9b1e651a'
 assert sha((CORE/'RESULT.json').read_bytes())=='adade63bed54c1b527e41d0d68f81ac652c6916d878235d82081c20f0f942d96'
 assert sha((PEER/'RESULT.json').read_bytes())=='e547715ea4e70a8be52c63724be1acdc2c70e18fd8d8610be671b11d2b8c212e'
 reuse=[]
 for receipt in [CORE/'INPUTS.json',PEER/'INPUTS.json']:
  value=json.loads(receipt.read_text())
  for row in value['files']:
   if row['path'].startswith('Source/Otzaria/Actions/Sources/OtzariaActionCore/') or row['path'].startswith('Source/Otzaria/UIRouting/Sources/OtzariaUIRouting/'):
    raw=git('show',BASE+':'+row['path']);assert len(raw)==row['bytes'] and sha(raw)==row['sha256']
    reuse.append(row)
 products=[]
 for folder,names in [(CORE/'output',['OtzariaActionCore.swiftmodule','libOtzariaActionCore.so']),(PEER/'output',['OtzariaUIRouting.swiftmodule','libOtzariaUIRouting.so'])]:
  for name in names:
   p=folder/name;products.append({'path':str(p),'bytes':p.stat().st_size,'sha256':sha(p.read_bytes()),'use':'readonly'})
 host=[];hostroot='Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/'
 for name in ['NativeIntentService.swift','NativeIntentOutcome.swift','NativeComponentSourceObservation.swift']:
  raw=git('show',BASE+':'+hostroot+name);p=OWN/'original'/name;p.write_bytes(raw);host.append(p)
 utility=git('show',BASE+':'+hostroot+'NativeReaderIntentService.swift').decode()
 expected='import Foundation\nimport OtzariaUIRouting\n\n'+utility[utility.index('enum NativeReaderEntityIdentifier {'):]
 assert (OWN/'inputs/controls/ActualNativeReaderEntityIdentifier.swift').read_text()==expected
 host.append(OWN/'inputs/controls/ActualNativeReaderEntityIdentifier.swift')
 cache=TASK/'controls/attempt-1/module-cache'
 base=[SWIFT,'-swift-version','6','-strict-concurrency=complete','-parse-as-library','-module-cache-path',cache]
 link=['-I',CORE/'output','-L',CORE/'output','-lOtzariaActionCore','-Xlinker','-rpath','-Xlinker',CORE/'output','-I',PEER/'output','-L',PEER/'output','-lOtzariaUIRouting','-Xlinker','-rpath','-Xlinker',PEER/'output']
 prior=TASK/'controls/attempt-4'
 prior_result=json.loads((prior/'RESULT.json').read_text())
 assert any(x['name']=='candidate-service-controls' and x['exit']==0 for x in prior_result['steps'])
 prior_service=prior/'inputs/candidate'/hostroot/'NativeSavedResultIntentService.swift'
 assert prior_service.read_bytes()==(OWN/'inputs/candidate'/hostroot/'NativeSavedResultIntentService.swift').read_bytes()
 for name in ['NativeIntentService.swift','NativeIntentOutcome.swift','NativeComponentSourceObservation.swift']:
  assert (prior/'original'/name).read_bytes()==(OWN/'original'/name).read_bytes()
 service_output=prior/'candidate'
 for name in ['ChavrusaUIRoutingHost.swiftmodule','libChavrusaUIRoutingHost.so']:
  p=service_output/name;products.append({'path':str(p),'bytes':p.stat().st_size,'sha256':sha(p.read_bytes()),'use':'readonly actual attempt4 compiled Host; 12 service controls passed'})
 original_root=git('show',BASE+':Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSearchEntry.swift').decode()
 first=original_root.index('@MainActor\nfinal class MaktabahNativeRootPublicationSource');last=original_root.index('/// Expected publications',first)
 assert (OWN/'inputs/controls/ActualOriginalRootPublication.swift').read_text()=='import Foundation\n\n'+original_root[first:last].rstrip()+'\n'
 original_tree=git('show',BASE+':Source/Features/Bookmarks/ViewModel/Extensions/Results+Tree.swift').decode()
 assert (OWN/'inputs/controls/ActualOriginalFolderIndex.swift').read_text().removeprefix('import Foundation\nextension ResultsViewModel {\n').removesuffix('\n}\n') in original_tree
 transformed=[]
 for name in ['MaktabahNativeSavedResultsSource.swift','MaktabahNativeSavedResultsBinding.swift']:
  original=OWN/'inputs/candidate/Source/ChavrusaText/UIRoutingHost/Integration'/name
  raw=original.read_text();assert raw.startswith('#if os(iOS)\n') and raw.endswith('#endif\n')
  text=raw.removeprefix('#if os(iOS)\n').removesuffix('#endif\n').replace('import UIKit\n','')
  p=OWN/'original'/name;p.write_text(text);transformed.append(p)
 candidate=OWN/'candidate';candidate.mkdir()
 ownlink=['-I',service_output,'-L',service_output,'-lChavrusaUIRoutingHost','-Xlinker','-rpath','-Xlinker',service_output]+link
 controls=[OWN/'inputs/controls'/n for n in ['ExplicitAppBoundary.swift','ActualOriginalStateHooks.swift','ActualWindowObservation.swift','ActualOriginalRootPublication.swift','ActualOriginalFolderIndex.swift','SavedResultsOwnerControls.swift']]
 controls+=[OWN/'inputs/candidate/Source/Features/Bookmarks/Models'/n for n in ['FolderNode.swift','ResultNode.swift','SavedResultsItem.swift']]
 controls+=[OWN/'inputs/candidate/Source/ChavrusaText/Bookmarks/OriginalSavedResultsLoadLifetime.swift',OWN/'inputs/candidate/Source/Features/Bookmarks/ViewModel/Extensions/Results+Load.swift']
 run('actual-owner-control-compile',base+ownlink+controls+transformed+['-o',candidate/'owner-controls'])
 run('completed-warm-catalog-controls',[candidate/'owner-controls','completed receipt source remains exact until a later original edit'])
 source=list((OWN/'inputs/candidate').rglob('*.swift'))+list((OWN/'inputs/shared-proposals/candidate').rglob('*.swift'))+[OWN/'inputs/shared-proposals/shortcut-parse/MaktabahNativeIntents.swift']
 run('parse-candidate-apple-syntax-only',[SWIFT,'-frontend','-parse','-target','arm64-apple-ios27.0']+source)
 for p in products:assert sha(pathlib.Path(p['path']).read_bytes())==p['sha256']
 save('RESULT.json',{'status':'PASS_SOURCE_CONTROLS_ONLY','steps':steps,'reused_source_rows':reuse,'reused_products':products,'new_source_inputs':manifest,'reused_owner_full_result':{'path':str(TASK/'controls/attempt-5/RESULT.json'),'sha256':sha((TASK/'controls/attempt-5/RESULT.json').read_bytes()),'scope':'28 owner cases PASS; this targeted run strengthens the existing completed-source case with actual post-release catalog identity'},'reused_service_result':{'path':str(prior/'RESULT.json'),'sha256':sha((prior/'RESULT.json').read_bytes()),'scope':'12 actual service controls PASS; whole attempt4 remains FAILED for two earlier domain-fixture stimuli'},'scope':'Actual portable service/owner/tree/state-hook source, original Core/UIRouting value contracts, explicit app/UIKit/database/backend-publisher fixtures; no Core execution or Apple/native acceptance','task_control_bytes':footprint(),'free_after':free()})
except BaseException as error:
 save('RESULT.json',{'status':'FAILED','steps':steps,'error':repr(error),'traceback':traceback.format_exc(),'task_control_bytes':footprint(),'free_after':free()})
 raise
finally:
 p=OWN/'RESULT.json'
 if p.exists():print(json.dumps({'path':str(p),'sha256':sha(p.read_bytes()),'status':json.loads(p.read_text())['status'],'steps':[{'name':s['name'],'exit':s.get('exit')}for s in steps]}))
