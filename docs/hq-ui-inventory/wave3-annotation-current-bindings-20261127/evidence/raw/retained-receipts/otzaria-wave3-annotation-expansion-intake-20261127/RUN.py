import gzip,hashlib,io,json,pathlib,shutil,subprocess,traceback,zipfile
ROOT=pathlib.Path('/home/ubuntu/.codex/worktrees/Maktabah-wave3-integration-rootfs-20261127')
BASE='b463ffd03a76026cea06c79c608df97d00094152'
PARENT='fd1407823dc346ea800cfba20523b56b98de8f08'
COMMITS=['56a6ff0c4d9437924479444660b51ce62e59db7e','2914be3e5ad4c2d857a962d526b5e2c6ec8dde32','7f8223232a82b25502090617860459674cc49f2a','d2a9d19fdecd57636cbb3896b2e96f33c1a72acd']
DONOR='/home/ubuntu/otzaria-wave3-annotation-expansion-caller-published-20261127/source'
BRANCH='codex/otzaria-wave3-integration-20261127'
PRODUCT='Source/Features/Annotations/iOS/iOSAnnotationViewController.swift'
FOLDERS=['docs/hq-ui-inventory/wave3-annotation-expansion-20261127','docs/hq-ui-inventory/wave3-annotation-expansion-caller-20261127']
PROOF='docs/hq-integration/wave3-annotation-expansion-intake-20261127'
RUN=pathlib.Path(__file__).parent
sha=lambda b:hashlib.sha256(b).hexdigest()
events=[]
def dump(p,x):p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
def git(*a):
 p=subprocess.run(['git','-c','gc.auto=0','-c','maintenance.auto=false','-C',str(ROOT),*a],capture_output=True)
 events.append({'args':a,'exit':p.returncode,'stdoutBytes':len(p.stdout),'stdoutSHA256':sha(p.stdout),'stderr':p.stderr.decode(errors='replace')});dump(RUN/'EVENTS.json',events)
 if p.returncode:raise RuntimeError('Git failure '+repr(a))
 return p.stdout
def rev(r):return git('rev-parse',r).decode().strip()
def show(r,p):return git('show',r+':'+p)
def pin(b,row):assert len(b)==row['bytes']and sha(b)==row['sha256'],row.get('path','unnamed')
def apply(text,edits,before,after):
 for e in edits:assert text.count(e[before])==1;text=text.replace(e[before],e[after],1)
 return text
def capacity():assert shutil.disk_usage(ROOT).free>=1342177280 and shutil.disk_usage(RUN).free>=2147483648
try:
 assert rev('HEAD')==BASE and not git('status','--porcelain');capacity()
 assert git('symbolic-ref','--short','HEAD').decode().strip()==BRANCH
 remote=['-c','credential.helper=!gh auth git-credential','ls-remote','origin','refs/heads/'+BRANCH]
 assert git(*remote).decode().split()[0]==BASE
 git('fetch','--no-tags','--no-write-fetch-head',DONOR,COMMITS[-1])
 for p,c in zip([PARENT]+COMMITS,COMMITS):assert rev(c+'^')==p
 assert show(BASE,PRODUCT)==show(PARENT,PRODUCT)
 manifests=[];rawCounts=[];inputCounts=[]
 for commit,folder,count,digest,rawCount in [(COMMITS[1],FOLDERS[0],29,'75c78c28fe41862358a8d1e690214b52f55a499e1cac4fdd7c31421cd7141e09',13),(COMMITS[3],FOLDERS[1],47,'c292a58a28e9446ada2d58e12cf04c16b990362d54cde67520ce55321e576b48',18)]:
  index=show(commit,folder+'/MANIFEST.json');assert sha(index)==digest;rows=json.loads(index)['files'];assert len(rows)==count
  paths=git('diff-tree','--no-commit-id','--name-only','-r',commit).decode().splitlines()
  assert set(paths)=={folder+'/'+r['path']for r in rows}|{folder+'/MANIFEST.json'}
  for row in rows:pin(show(commit,folder+'/'+row['path']),row)
  rawRows=json.loads(show(commit,folder+'/evidence/raw/RAW_MANIFEST.json'));assert len(rawRows)==rawCount
  for row in rawRows:pin(show(commit,folder+'/evidence/raw/'+row['path']),row)
  with zipfile.ZipFile(io.BytesIO(show(commit,folder+'/evidence/RAW.zip')))as z:
   assert set(z.namelist())=={r['path']for r in rawRows}|{'RAW_MANIFEST.json'}
   for row in rawRows:pin(z.read(row['path']),row)
   assert z.read('RAW_MANIFEST.json')==show(commit,folder+'/evidence/raw/RAW_MANIFEST.json')
  inputs=json.loads(show(commit,folder+'/inputs/INPUTS.json'))
  for row in inputs:pin(show(commit,folder+'/inputs/'+row['path']),row)
  inputCounts.append(len(inputs));rawCounts.append(rawCount);manifests.append({'commit':commit,'path':folder+'/MANIFEST.json','rows':count,'sha256':digest})
 for commit in [COMMITS[0],COMMITS[2]]:
  assert git('diff-tree','--no-commit-id','--name-only','-r',commit).decode().splitlines()==[PRODUCT]
  git('diff','--check',commit+'^',commit)
 first=json.loads(show(COMMITS[1],FOLDERS[0]+'/SOURCE_INVERSE.json'))
 second=json.loads(show(COMMITS[3],FOLDERS[1]+'/SOURCE_INVERSE.json'))
 assert first['path']==second['path']==PRODUCT and len(first['edits'])==2
 old=show(BASE,PRODUCT);middle=show(COMMITS[0],PRODUCT);new=show(COMMITS[2],PRODUCT)
 assert sha(old)==first['before_sha256']=='bf7bc1ea1bb559e02a7904dad3508fab1c265ecd07e1592365cab045aecbc714'
 assert sha(middle)==first['after_sha256']==second['before_sha256']=='e38eafa86b8aebdf34166da0d9fe3b182ac44fdcdf5c2549fea8f0d9026a14cd'
 assert sha(new)==second['after_sha256']=='a6577cf5d2060b3849ab06634c9e52915e9048260feda7814c02cf926965bd1c'
 assert apply(old.decode(),first['edits'],'before','after').encode()==middle
 assert apply(middle.decode(),list(reversed(first['edits'])),'after','before').encode()==old
 assert apply(middle.decode(),[second],'before','after').encode()==new
 assert apply(new.decode(),[second],'after','before').encode()==middle
 helperRaw=show(COMMITS[1],FOLDERS[0]+'/evidence/raw/RESULT.json');assert sha(helperRaw)=='1e23d72f21802c9a12e2b35d07586dec71c70cdec420e6e157e8e67f3e8e73f0'
 helper=json.loads(helperRaw);assert helper['baseline']=={'passed':3,'failed':8}and helper['candidate']=={'passed':11,'failed':0}
 for label,counts in [('OriginalExpansion',(3,8)),('CandidateExpansion',(11,0))]:
  r=json.loads(show(COMMITS[1],FOLDERS[0]+'/evidence/raw/'+label+'-controls.stdout'));assert(r['passed'],r['failed'])==counts
 callerPath=FOLDERS[1]+'/evidence/raw/caller-followup-attempt-2/'
 callerRaw=show(COMMITS[3],callerPath+'RESULT.json');assert sha(callerRaw)=='63415a94517b961fea07adc7688dc68a21a1d29b548feaf3f8b9e4c893b9c1fe'
 caller=json.loads(callerRaw);assert caller['passed']==6 and caller['failed']==0 and caller['status']=='PASS_SOURCE_CONTROLS_ONLY'
 assert [(s['name'],s['exit'])for s in caller['steps']]==[('full-ios-syntax-only',0),('actual-old-caller-compile',1),('actual-candidate-caller-compile',0),('actual-candidate-caller-controls',0)]
 assert b'escaping closure captures non-escaping parameter' in show(COMMITS[3],callerPath+'actual-old-caller-compile.stderr')
 actual=json.loads(show(COMMITS[3],callerPath+'actual-candidate-caller-controls.stdout'));assert actual['passed']==6 and actual['failed']==0
 for row in caller['original_source_join']:pin(show(BASE,row['path']),row)
 for row in caller['reused_products']:pin(pathlib.Path(row['path']).read_bytes(),row)
 checked=[]
 for p in git('ls-tree','-r','--name-only',COMMITS[3],FOLDERS[1]+'/inputs/candidate/Source').decode().splitlines():
  original=p.split('/inputs/candidate/',1)[1];expected=new if original==PRODUCT else show(BASE,original)
  assert show(COMMITS[3],p)==expected;checked.append(original)
 assert len(checked)==8
 failedTypecheck=show(COMMITS[3],FOLDERS[1]+'/evidence/raw/caller-followup-attempt-1/RESULT.json')
 # Preserve exact raw patch-context/compiler fixture bytes. The product diffs
 # above and this new intake proof still must pass their normal checks.
 rawWhitespace=[]
 for a,b,length,digest in [(COMMITS[0],COMMITS[1],802,'97f6315bf590dbec3c20c758857f1419cd480193cb85778fba36080155c21c81'),(COMMITS[2],COMMITS[3],134,'49dd3b84e1bdc8725c5ec1834194dcceafc58f589fc026a11e01ca136dc6f180')]:
  p=subprocess.run(['git','-C',str(ROOT),'diff','--check',a,b],capture_output=True)
  assert p.returncode==2 and p.stderr==b''and len(p.stdout)==length and sha(p.stdout)==digest
  rawWhitespace.append({'from':a,'to':b,'exit':2,'bytes':length,'sha256':digest,'stdout':p.stdout.decode(),'scope':'Only immutable raw unified-diff context or compiled fixture EOF; no product/source or Git policy change.'})
 protected=['Source/Otzaria','Source/ChavrusaText','Vendor','Scripts','.github','docs/architecture','Maktabah-iOSUITests','Maktabah.xcodeproj','Source/Localizable.xcstrings']
 trees={p:rev(BASE+':'+p)for p in protected}
 assert rev('HEAD')==BASE and not git('status','--porcelain');capacity()
 picked=[]
 for commit in COMMITS:
  git('-c','user.name=ChatGPT','-c','user.email=chatgpt-agent@users.noreply.github.com','cherry-pick','-x',commit)
  picked.append({'donor':commit,'intake':rev('HEAD')});assert not git('status','--porcelain')
 assert (ROOT/PRODUCT).read_bytes()==new
 assert git('diff','--name-only',BASE,'HEAD','--','Source').decode().splitlines()==[PRODUCT]
 for p,h in trees.items():assert rev('HEAD:'+p)==h
 proof=ROOT/PROOF;proof.mkdir(parents=True,exist_ok=False)
 (proof/'INTAKE.py.gz').write_bytes(gzip.compress(pathlib.Path(__file__).read_bytes(),mtime=0))
 (proof/'RAW_ARTIFACT_WHITESPACE.json.gz').write_bytes(gzip.compress((json.dumps(rawWhitespace,indent=2)+'\n').encode(),mtime=0))
 result={'schema':'otzaria.wave3.annotation-expansion-intake.v1','base':BASE,'picked':picked,'sourceTree':rev('HEAD:Source'),'vendorTree':rev('HEAD:Vendor'),'productPaths':1,'docsPaths':78,'manifests':manifests,'originalExpansionEdits':2,'retainedCallerSignatureEdits':1,'wholeFileInverse':True,'helperSourceControls':{'original':helper['baseline'],'candidate':helper['candidate'],'resultSHA256':sha(helperRaw)},'actualFullCallerSourceControls':{'passed':6,'failed':0,'originalCompileExit':1,'candidateCompileExit':0,'resultSHA256':sha(callerRaw),'preservedTypecheckAttemptSHA256':sha(failedTypecheck),'scope':caller['scope']},'verifiedRawFiles':sum(rawCounts),'verifiedInputRows':inputCounts,'currentSourceProductsMatched':checked,'originalModuleSourcePinsVerified':len(caller['original_source_join']),'newTestExecutions':0,'protectedTrees':trees,'AppleSDK':'NOT_RUN','nativeRuns':0,'open':['Actual native annotation cell geometry and foreground/background/cached-entity acceptance','Original annotation editor and filter semantics','Final production/real-owner/target merge/TestFlight']}
 dump(proof/'RESULT.json',result)
 git('add','--sparse','--',PROOF);git('diff','--cached','--check');git('-c','user.name=ChatGPT','-c','user.email=chatgpt-agent@users.noreply.github.com','commit','-m','Record original annotation expansion and complete caller compile evidence')
 head=rev('HEAD');assert not git('status','--porcelain')and git(*remote).decode().split()[0]==BASE
 git('-c','remote.origin.mirror=false','-c','credential.helper=!gh auth git-credential','push','origin','HEAD:refs/heads/'+BRANCH);assert git(*remote).decode().split()[0]==head
 terminal={'ok':True,'head':head,'picked':picked,'sourceTree':rev('HEAD:Source'),'vendorTree':rev('HEAD:Vendor'),'resultSHA256':sha((proof/'RESULT.json').read_bytes()),'nativeRuns':0,'rootFree':shutil.disk_usage(ROOT).free,'dataFree':shutil.disk_usage(RUN).free};dump(RUN/'TERMINAL.json',terminal);print(json.dumps(terminal))
except BaseException as error:
 dump(RUN/'FAILURE.json',{'error':repr(error),'traceback':traceback.format_exc()});raise
