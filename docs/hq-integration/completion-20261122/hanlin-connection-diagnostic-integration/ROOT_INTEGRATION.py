import pathlib,json,hashlib,subprocess,datetime,copy
r=pathlib.Path(r'C:\Users\DAVID\Code\Maktabah-completion-20261122')
base='4287063689fb2f17ea9a8fcd436ed98e6985f21f';source='6aa953048453b64a0013621ce76e095770eb7e7d';binding='966f180d8ba2c2eb0f72624be76a99222f45371b';tip='5cd307d31b1d813f756014c9903a5808b9aacddd'
prefix='docs/hq-integration/completion-20261122/hanlin-connection-diagnostics'
sha=lambda b:hashlib.sha256(b).hexdigest()
def need(v,m):
 if not v:raise AssertionError(m)
def git(*a):return subprocess.check_output(['git','-c','core.autocrlf=false',*a],cwd=r,timeout=90)
def blob(ref,path):return git('show',ref+':'+path)
def batch(ref,paths):
 z=subprocess.run(['git','cat-file','--batch'],cwd=r,input=(''.join(ref+':'+p+'\n' for p in paths)).encode(),capture_output=True,check=True,timeout=90)
 out={};pos=0
 for p in paths:
  e=z.stdout.index(b'\n',pos);h=z.stdout[pos:e].decode().split();need(len(h)==3 and h[1]=='blob','blob '+p);n=int(h[2]);pos=e+1;b=z.stdout[pos:pos+n];pos+=n;need(z.stdout[pos:pos+1]==b'\n','delimiter');pos+=1;out[p]=(h[0],b)
 need(pos==len(z.stdout),'remainder');return out
need(git('rev-parse','HEAD').decode().strip()==base and not git('status','--porcelain=v1').strip(),'canonical changed')
ib=blob(tip,prefix+'/FILE_INDEX.json');need(sha(ib)=='6fe9d44ec4d6596851cdd55be689e8ab9956486a2ea15cae06e4107c49b1b748','final packet index')
idx=json.loads(ib);need(len(idx['files'])==82 and idx['applicationSource']==source and idx['bindingCommit']==binding,'packet schema')
paths=[prefix+'/'+x['path'] for x in idx['files']];need(len(set(paths))==82,'payload duplicate')
bs=batch(tip,paths)
for x in idx['files']:
 b=bs[prefix+'/'+x['path']][1];need(len(b)==x['bytes'] and sha(b)==x['sha256'],'payload '+x['path'])
decl=json.loads(blob(tip,prefix+'/validation/INPUTS.json'))['files']
expected_code={x['path'] for x in decl}|{'Scripts/CI/hq-stage2-focused-apple.inputs.json'}
delta=git('diff','--name-only',base,tip).decode().splitlines()
need({p for p in delta if not p.startswith(prefix+'/')}==expected_code,'full branch scope')
for x in decl:
 b=blob(source,x['path']);need(sha(b)==x['sha256'] and len(b)==x['bytes'] and sha(blob(base,x['path']))==x['preimageSHA256'],'candidate/source preimage')
need(git('diff','--name-only',source,binding).decode().splitlines()==['Scripts/CI/hq-stage2-focused-apple.inputs.json','Scripts/CI/runtime27-hanlin-live.py'],'binder scope')
old=blob(source,'Scripts/CI/runtime27-hanlin-live.py')
oldtoken=b'REVIEWED_SOURCE = "0ea7218331d1441d37d06d43333e579f267056e3"';newtoken=('REVIEWED_SOURCE = "'+source+'"').encode()
need(old.count(oldtoken)==1 and old.replace(oldtoken,newtoken)==blob(tip,'Scripts/CI/runtime27-hanlin-live.py'),'only reviewed source binding')
hq=json.loads(blob(source,'Scripts/CI/hq-stage2-focused-apple.inputs.json'));want=copy.deepcopy(hq)
want['application_source_sha']=source;want['application_trees']['Source']='91c1adf6c97cd8676e8b2c76860a40f78924b1ec'
need(json.loads(blob(tip,'Scripts/CI/hq-stage2-focused-apple.inputs.json'))==want,'only HQ source binding')
need(sha(blob(tip,prefix+'/validation/FILE_INDEX.json'))=='e4d3bd2d017f9ba74c9f7eddaff5415918255b2f69b6d44882278892e8773c98','frozen42 index')
need(sha(blob(tip,prefix+'/independent/ROOT_WINDOWS_REVIEW.json'))=='960d439df6f9d0dd775fbf2f89e44d1066f47bf21024fee21fb70ccf607c5649','root windows proof')
need(sha(blob(tip,prefix+'/independent/ROOT_LINUX_REVIEW.json'))=='5c32433e23ddbbe01a360e6993ab8b51c0cbb8c3001cb0dfa2d297a66019a8be','root linux proof')
trees={'Source':'91c1adf6c97cd8676e8b2c76860a40f78924b1ec','Vendor':'4065c0e62af325e83a65fe0c70270985229807ae','Maktabah.xcodeproj':'8c0fa1ccfbcfae01fae3c267512864e00efcf078','Maktabah-iOSUITests':'24345d612f8c70398f4590977f8b4696021ae413'}
for p,w in trees.items():
 for ref in [source,tip]:need(git('rev-parse',ref+':'+p).decode().strip()==w,'tree '+p)
need(git('rev-parse',tip+':.github')==git('rev-parse',base+':.github'),'workflow tree changed')
git('merge','--no-ff','--no-commit',tip)
for p,(oid,b) in bs.items():need((r/p).read_bytes()==b,'merged payload bytes '+p)
for p in expected_code:need((r/p).read_bytes()==blob(tip,p),'merged source '+p)
git('commit','-m','Merge validated original Hanlin connection diagnostics')
merge=git('rev-parse','HEAD').decode().strip();need(git('rev-list','--parents','-n','1',merge).decode().split()[1:]==[base,tip],'true merge parents')
closure=git('ls-tree','-r','-z','HEAD','--','Scripts/CI','Scripts/verify-otzaria-mini-parity.py','.github/workflows','tools','Maktabah-iOSUITests','docs/hq-integration/runtime27/R27_CASES.json')
inputs=[]
for row in closure.split(b'\0'):
 if not row:continue
 head,name=row.split(b'\t',1);mode,kind,oid=head.decode().split();need(kind=='blob','execution object');p=name.decode()
 b=(r/p).read_bytes();need(hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()==oid,'execution checkout '+p)
 inputs.append({'path':p,'blob':oid,'bytes':len(b),'sha256':sha(b)})
need(len(inputs)==281,'execution closure count')
outrel='docs/hq-integration/completion-20261122/hanlin-connection-diagnostic-integration';out=r/outrel;need(not out.exists(),'proof exists');out.mkdir()
proof={'schema':1,'status':'VERIFIED_SOURCE_AND_BOUNDED_CONTROLS_INTEGRATION','createdUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'canonicalParent':base,'incoming':tip,'applicationSource':source,'binding':binding,'merge':merge,'packetPayloads':82,'packetPayloadBytes':sum(x['bytes'] for x in idx['files']),'packetIndexBytes':len(ib),'packetIndexSHA256':sha(ib),'frozenValidationIndexSHA256':'e4d3bd2d017f9ba74c9f7eddaff5415918255b2f69b6d44882278892e8773c98','productTrees':trees,'exactWorkingExecutionInputs':len(inputs),'bindingChange':'Only HQ applicationSource/Source tree and Live REVIEWED_SOURCE; tested validator/capture/admission function bytes remain unchanged','sourceScope':'Four original Swift files add diagnostic hooks only; one existing Python driver adds strict private diagnostic admission. No guard/assertion/cleanup relaxation.','historicalNativeConsent':'44987561349/0ea remains a historical original prerequisite, not current source execution','passedNewControls':{'pythonPOSIX':34,'completeSwiftSyntaxOnly':4},'testsReplayed':0,'nativeOrLiveRun':False,'secretCreated':False,'finalNative116Release114Accepted':False,'scriptSHA256':sha(pathlib.Path(__file__).read_bytes())}
(out/'INTEGRATION.json').write_bytes((json.dumps(proof,indent=2)+'\n').encode())
(out/'EXECUTION_INPUTS.json').write_bytes((json.dumps({'schema':1,'checkout':merge,'inputs':inputs},indent=2)+'\n').encode())
(out/'README.md').write_bytes(('# Hanlin connection diagnostic integration\n\nThis true merge retains the exact source6aa953, binder966f and reviewed evidence5cd307. All82 payloads, the frozen42-file validation packet, root Windows/Linux reviews, five candidate/preimage pairs, four product trees and281 actual checkout execution inputs are verified.\n\nThe binding child changes only HQ application source/Source tree and the existing Live reviewed-source literal. The tested strict validator/capture/admission bodies remain unchanged. No existing Native or Live test was repeated for this merge.\n\nThe34 new Python boundary controls and4 complete Swift syntax parses retain their documented limits. Windows parses do not typecheck the Apple SDK or execute Simulator storage. Historical no-key consent449875 on0ea remains historical; it is not reattributed to this changed application. The next focused Live case must build and execute source6aa and preserve the original final-witness requirement. Full Native116/Release114 manifests are unchanged and not accepted.\n').encode())
report=r/'docs/hq-integration/completion-20261122/CONTINUATION_STATUS.md'
text=report.read_text(encoding='utf-8')
start=text.index('The canonical branch is ');end=text.index('\n\n| Product tree',start)
text=text[:start]+('The canonical branch is [codex/otzaria-completion-20261122](https://github.com/davidpovarsky/Maktabah/tree/codex/otzaria-completion-20261122). Current application source is [6aa953048453b64a0013621ce76e095770eb7e7d](https://github.com/davidpovarsky/Maktabah/commit/6aa953048453b64a0013621ce76e095770eb7e7d), with reviewed binding966f180d8ba2c2eb0f72624be76a99222f45371b. True merge'+merge+' joins canonical428706 and reviewed diagnostic evidence5cd307. Four existing Swift files add a private diagnostic journal/hooks, and the existing Live driver admits only its strict bounded JSON. Original business guards, UI test assertions, source/consent checks and cleanup remain unchanged. [Integration evidence](hanlin-connection-diagnostic-integration/INTEGRATION.json) records all82 payloads,281 execution inputs, source bindings and limits. Historical Native consent/Live7 results below remain bound to0ea; no current-source Native/Live result is inferred.')+text[end:]
text=text.replace('| Source | ac887bdbfbfce2d30d9591bb867d61b11da31cc6 |','| Source | 91c1adf6c97cd8676e8b2c76860a40f78924b1ec |',1)
marker='## Live7 terminal result and completed ownership'
pos=text.index(marker)
fresh='## Current diagnostic source and next focused Live execution\n\nThe new private diagnostic source is integrated at6aa, with34 actual Python boundary controls and4 complete Swift syntax parses PASS. Root verified all42 frozen validation payloads, actual Linux files/interpreter, Windows compiler identities, raw results and exact source preimages. [Complete diagnostic packet](hanlin-connection-diagnostics/README.md) retains both source/evidence packaging corrections without rewriting executed inputs. No new Live secret or CI run has been created at this source-integration checkpoint. One subsequent failed-Live-case repetition is justified by this added diagnostic dependency; passing Native/component cases are not replayed or relabelled.\n\nSince the preceding report checkpoint, Anytype producer44997870962/568d finished FAILURE with the single attributed Unsplash initialization diagnostic; exact two-line reorder431407 is undergoing a bounded semantic control. The separate Participant/Space composition ten new groups passed once, while its packaging correction and source seal remain in progress. Original Participant/Space plus published metadata/audit are now true-merged and published at Anytype403725a24422103b3562228a64061d24d639eabf. These remain component results. Full editor framework/runtime, native schema/transport/body/receipt/writer, Native116/Release114 and external signing/device gates remain open.\n\n'
text=text[:pos]+fresh+text[pos:]
report.write_bytes(text.encode())
git('add','--',outrel,report.relative_to(r).as_posix());git('diff','--cached','--check')
git('commit','-m','docs: bind original Hanlin diagnostics and current execution scope')
head=git('rev-parse','HEAD').decode().strip()
need(not git('status','--porcelain=v1').strip(),'dirty final')
for p,w in trees.items():need(git('rev-parse','HEAD:'+p).decode().strip()==w,'final tree')
result={'status':'PASS','head':head,'merge':merge,'source':source,'binder':binding,'incoming':tip,'payloadsVerified':82,'executionInputsVerified':281,'fourProductTrees':trees,'testsRun':0,'secretCreated':False,'reportSHA256':sha(report.read_bytes())}
dest=pathlib.Path(r'C:\Users\DAVID\AppData\Local\Temp\otzaria-continuation-20261122\hanlin_diagnostic_integration_result.json');need(not dest.exists(),'result exists');dest.write_bytes((json.dumps(result,indent=2)+'\n').encode());print(json.dumps(result))
