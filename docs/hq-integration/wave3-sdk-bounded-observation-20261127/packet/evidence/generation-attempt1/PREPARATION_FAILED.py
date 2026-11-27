from pathlib import Path
import hashlib,json,shutil

HERE=Path(__file__).parent
OLD=HERE/'launch-envelope'
NEW=HERE/'launch-envelope-bounded'
NEW.mkdir(exist_ok=False)
sha=lambda b:hashlib.sha256(b).hexdigest()
dump=lambda p,x:p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
manifest=json.loads((OLD/'LAUNCH_INPUTS.json').read_text())
assert sha((OLD/'LAUNCH_INPUTS.json').read_bytes())=='4d69b38000090f59e0fc3f12b4a46acfe36e55b7759a30c04df80833576ff317'
for row in manifest['files']:
 body=(OLD/row['path']).read_bytes();assert len(body)==row['bytes']and sha(body)==row['sha256']
 (NEW/row['path']).write_bytes(body)
changes=[]
def replace(name,text,old,new):
 assert text.count(old)==1,(name,old[:100],text.count(old))
 changes.append({'path':name,'old':old,'new':new})
 return text.replace(old,new,1)
def identity_body(text):
 start=text.index('def identity(pid):\n');end=text.index('\n\ndef ',start+1)
 return text[start:end+2]

helper=(HERE/'bounded-observer/sdk_process_observation.py').read_bytes()
(NEW/'sdk_process_observation.py').write_bytes(helper)
originalPins={}
for name in ['launch_owned.py','completion_watcher.py','supervisor.py']:
 body=(OLD/name).read_bytes();originalPins[name]={'bytes':len(body),'sha256':sha(body)}
 (NEW/('ORIGINAL_'+name+'.txt')).write_bytes(body)

name='supervisor.py';s=(OLD/name).read_text()
s=replace(name,s,'from pathlib import Path\n','from pathlib import Path\nfrom sdk_process_observation import free_bytes, require_launch_capacity, require_original_sdk_slot, require_compiler_slot\nrequire_launch_capacity()\n')
s=replace(name,s,"capture_output=True,check=True).stdout\nif git(","capture_output=True,check=True,timeout=30).stdout\nif git(")
original="procrows=subprocess.run(['ps','-axo','pid,ppid,command'],capture_output=True,text=True,check=True).stdout\nif any(str(root)in l and any(k in l for k in['run_framework_acceptance.py','prepare_local_execution.py','xcodebuild','swift-frontend'])for l in procrows.splitlines()):raise RuntimeError('SDK slot already active')\n"
s=replace(name,s,original,"sdkSlotObservation=require_original_sdk_slot(root)\nactiveCompilers=require_compiler_slot()\nrequire_launch_capacity()\n")
s=replace(name,s,"def free():return int(subprocess.run(['df','-k','/System/Volumes/Data'],capture_output=True,text=True,check=True).stdout.splitlines()[1].split()[3])*1024",'def free():return free_bytes()')
s=replace(name,s,"'steps':[],'newFullAppBuilds':0,'newMaktabahNativeTests':0}","'steps':[],'newFullAppBuilds':0,'newMaktabahNativeTests':0,'sdkSlotObservation':sdkSlotObservation,'activeCompilers':activeCompilers,'capacityObservation':'os.statvfs f_bavail times f_frsize'}")
(NEW/name).write_text(s);supervisorSHA=sha(s.encode())

name='completion_watcher.py';s=(OLD/name).read_text()
s=replace(name,s,'import time\n','import time\nfrom sdk_process_observation import identity, free_bytes, require_launch_capacity\n')
s=replace(name,s,identity_body(s),'')
s=replace(name,s,'def free():\n    p = subprocess.run(["/bin/df", "-k", "/System/Volumes/Data"],\n                       capture_output=True, text=True, check=True)\n    return int(p.stdout.splitlines()[1].split()[3]) * 1024\n','def free():\n    return free_bytes()\n')
s=replace(name,s,'    args = ap.parse_args()\n','    args = ap.parse_args()\n    require_launch_capacity()\n')
s=replace(name,s,'SUPERVISOR_SHA = "4720728f67862a003ed527a56ef1164eae6e063509eb3b619f7a26b346f6be2b"','SUPERVISOR_SHA = "'+supervisorSHA+'"')
s=replace(name,s,'"processSignalsIssued": 0}', '"sdkSupervisorSignalsIssuedByWatcher": 0,\n               "observerScope": "Pinned BSD reader may clean up only its own bounded helper; watcher never signals SDK supervisor"}')
for original in ['"processSignalsIssuedByWatcher": 0}', '"processSignalsIssuedByWatcher": 0,']:
 s=replace(name,s,original,original.replace('processSignalsIssuedByWatcher','sdkSupervisorSignalsIssuedByWatcher'))
(NEW/name).write_text(s)

name='launch_owned.py';s=(OLD/name).read_text()
s=replace(name,s,'import subprocess\n','import subprocess\nfrom sdk_process_observation import identity, require_launch_capacity, require_original_sdk_slot, require_compiler_slot\n')
s=replace(name,s,identity_body(s),'')
s=replace(name,s,'capture_output=True, check=True).stdout','capture_output=True, check=True, timeout=30).stdout')
s=replace(name,s,'    ap.parse_args()\n','    ap.parse_args()\n    require_launch_capacity()\n')
start=s.index('    ps = subprocess.run(');end=s.index('    claim = ',start)
s=replace(name,s,s[start:end],'    sdk_slot_observation = require_original_sdk_slot(SDK)\n    active_compilers = require_compiler_slot()\n    available = require_launch_capacity()\n')
s=replace(name,s,'"freeBefore": available, "rawDf": df, "retryAuthorized": False}', '"freeBefore": available, "capacityObservation": "os.statvfs f_bavail times f_frsize",\n             "sdkSlotObservation": sdk_slot_observation, "retryAuthorized": False}')

addendum={'schema':'otzaria.sdk.bounded-observation-envelope.v1','status':'PREPARED_NOT_EXECUTED','baseManifestSHA256':'4d69b38000090f59e0fc3f12b4a46acfe36e55b7759a30c04df80833576ff317','originalControllers':originalPins,'sourceSHA':manifest['sourceSHA'],'recipeSHA256':'677c18318f52912e188c8c48501333462932a330ef7584160adb2f8fb2566490','sourceGuardCount':17,'sourceGuardChanges':0,'admissionBytes':15032385536,'liveStopBytes':2415919104,'unchanged':['Original SDK command recipe and fresh execution paths','17 original source guards','3,000 second full original framework deadline','180 second original macro restore deadline and finally','Original two-second stop reserve sampling and exact child group signaling','Original queued SDK root plus four argument-marker predicate','No automatic retry, no prior execution identity or acceptance reuse'],'changes':['Capacity refusal precedes process/source observations','Reuse existing qualified BSD metadata reader for own identity and global compiler names','Original queued-SDK ps read has five-second timeout and refuses malformed/empty/error observations','Capacity reads use os.statvfs without a child process','Local Git metadata reads have30second timeout','Watcher signal claim is scoped to SDK supervisor; bounded observer helper cleanup is explicit'],'bsdAdapterSHA256':'24e4bc3832d2e12d66f36c45c749e66687211e514d21362940078801f359229c','bsdBinarySHA256':'b849e2066b9a41f26bdc25816fe53603957ca43d9c099b93c594877244b5a013','newBSDReaderCompilation':False,'nativeRuns':0,'SDKBuilds':0,'historicalDocuments':'PROPOSAL, COMPLETE_PLAN and original contracts remain unmodified historical inputs; this addendum and exact current manifest identify the new observation-only envelope.'}
dump(NEW/'BOUNDED_OBSERVATION_ADDENDUM.json',addendum)
manifest['approvedSupervisorSHA256']=supervisorSHA
manifest['originalControllerSources']['boundedObservationBase']=originalPins
manifest['originalControllerSources']['watcherProcessOwnershipObservationAndWaitUnchanged']=False
manifest['originalControllerSources']['watcherChanges']+=addendum['changes']
manifest['originalControllerSources']['watcherIssuesProcessSignals']=False
manifest['originalControllerSources']['watcherSignalScope']='No signals to SDK supervisor; existing BSD helper may clean up its own timed-out diagnostic child.'
manifest['observationAddendum']='BOUNDED_OBSERVATION_ADDENDUM.json'
names=[r['path']for r in manifest['files']]+['sdk_process_observation.py','BOUNDED_OBSERVATION_ADDENDUM.json']+['ORIGINAL_'+n+'.txt'for n in originalPins]
manifest['files']=[{'path':n,'bytes':(NEW/n).stat().st_size,'sha256':sha((NEW/n).read_bytes())}for n in names]
dump(NEW/'LAUNCH_INPUTS.json',manifest);manifestSHA=sha((NEW/'LAUNCH_INPUTS.json').read_bytes())
s=replace(name,s,'EXPECTED_MANIFEST = "4d69b38000090f59e0fc3f12b4a46acfe36e55b7759a30c04df80833576ff317"','EXPECTED_MANIFEST = "'+manifestSHA+'"')
(NEW/name).write_text(s)
for name in ['launch_owned.py','completion_watcher.py','supervisor.py']:
 current=(NEW/name).read_text();inverse=current
 for edit in reversed([e for e in changes if e['path']==name]):
  assert inverse.count(edit['new'])==1,(name,'inverse',edit['new'][:80])
  inverse=inverse.replace(edit['new'],edit['old'],1)
 assert inverse==(OLD/name).read_text()
 compile(current,str(NEW/name),'exec')
compile(helper,str(NEW/'sdk_process_observation.py'),'exec')
dump(NEW/'EXACT_CONTROLLER_EDITS.json',changes)
print(json.dumps({'folder':str(NEW),'manifestSHA256':manifestSHA,'supervisorSHA256':supervisorSHA,'launcherSHA256':sha((NEW/'launch_owned.py').read_bytes()),'hunks':len(changes),'totalBytes':sum(p.stat().st_size for p in NEW.iterdir()),'SDKRuns':0}))
