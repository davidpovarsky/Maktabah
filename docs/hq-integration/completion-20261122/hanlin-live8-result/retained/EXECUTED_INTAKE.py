from pathlib import Path,PurePosixPath
import subprocess,json,hashlib,datetime,zipfile,io,os,re,ast,uuid
ROOT=Path(r'C:\Users\DAVID\Code\Maktabah-completion-20261122')
LIFE=ROOT/'build/hanlin-live8-lifecycle'
OUT=Path(r'C:\Users\DAVID\AppData\Local\Temp\otzaria-hanlin-live8-artifact-20261122')
REPO='davidpovarsky/Maktabah';RUN=45000580919;HEAD='ce5d11335c4b4769a25e0e8f48ba1d6f7efc6749';APP='6aa953048453b64a0013621ce76e095770eb7e7d'
ARTIFACT=json.loads("{\"id\":14746509686,\"node_id\":\"MDg6QXJ0aWZhY3QxNDc0NjUwOTY4Ng==\",\"name\":\"otzaria-hanlin-live-native-evidence\",\"size_in_bytes\":88435,\"url\":\"https://api.github.com/repos/davidpovarsky/Maktabah/actions/artifacts/14746509686\",\"archive_download_url\":\"https://api.github.com/repos/davidpovarsky/Maktabah/actions/artifacts/14746509686/zip\",\"expired\":false,\"digest\":\"sha256:6e2ab18309e97d12791db2d2ccafafb320c38ca549db7a6c76008741a4e859f4\",\"created_at\":\"2026-11-22T08:39:44Z\",\"updated_at\":\"2026-11-22T08:39:44Z\",\"expires_at\":\"2027-02-20T07:57:53Z\",\"workflow_run\":{\"id\":45000580919,\"repository_id\":1280062128,\"head_repository_id\":1280062128,\"head_branch\":\"codex/otzaria-hanlin-live-20261121\",\"head_sha\":\"ce5d11335c4b4769a25e0e8f48ba1d6f7efc6749\"}}")
sha=lambda b:hashlib.sha256(b).hexdigest()
def strict(raw):
 def unique(pairs):
  r={}
  for k,v in pairs:
   assert k not in r,'Duplicate JSON key'
   r[k]=v
  return r
 def invalid(x):raise ValueError('Nonfinite JSON')
 return json.loads(raw,object_pairs_hook=unique,parse_constant=invalid)
life_bytes=(LIFE/'lifecycle.json').read_bytes();life=strict(life_bytes)
cleanup_bytes=(LIFE/'cleanup.json').read_bytes();cleanup=strict(cleanup_bytes)
assert life['state']=='DELETED_AND_ABSENCE_VERIFIED' and life['secret_cleanup_required'] is False
assert life['run_id']==RUN and life['checkout_sha']==HEAD and life['application_source_sha']==APP
assert cleanup['delete_http_status']==204 and cleanup['after_http_status']==404 and cleanup['run_id']==RUN and cleanup['checkout_sha']==HEAD
assert cleanup['before_metadata']==life['metadata'] and life['metadata']['created_at']==life['metadata']['updated_at']=='2026-11-22T07:57:46Z'
assert ARTIFACT['id']==14746509686 and ARTIFACT['size_in_bytes']==88435 and ARTIFACT['digest']=='sha256:6e2ab18309e97d12791db2d2ccafafb320c38ca549db7a6c76008741a4e859f4'
assert ARTIFACT['workflow_run']['id']==RUN and ARTIFACT['workflow_run']['head_sha']==HEAD
env=dict(os.environ)
for key in ['GEMINI_API_KEY','OTZARIA_HANLIN_LIVE_API_KEY','OTZARIA_LIVE_GEMINI_API_KEY']:env.pop(key,None)
def cmd(args,timeout=60):
 return subprocess.run(args,cwd=ROOT,env=env,capture_output=True,timeout=timeout)
p=cmd(['gh','api','repos/'+REPO+'/actions/runs/'+str(RUN)])
assert p.returncode==0
run_bytes=p.stdout;run=strict(run_bytes)
assert run['head_sha']==HEAD and run['run_attempt']==1 and run['status']=='completed' and run['conclusion']=='failure'
q=cmd(['gh','api','-i','repos/'+REPO+'/actions/secrets/OTZARIA_LIVE_GEMINI_API_KEY'])
status=re.search(rb'^HTTP/\S+\s+(\d{3})',q.stdout,re.M)
assert status and status.group(1)==b'404','Temporary secret absence not confirmed'
absence={'http_status':404,'checked_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'method':'independent read-only GitHub secret metadata request','secret_value_read':False,'delete_repeated':False}
assert not OUT.exists(),'Preserve existing intake; never repeat artifact download'
OUT.mkdir()
def write(name,value):(OUT/name).write_bytes((json.dumps(value,indent=2,ensure_ascii=False)+'\n').encode())
(OUT/'EXECUTED_INTAKE.py').write_bytes(Path(__file__).read_bytes())
(OUT/'lifecycle-final.json').write_bytes(life_bytes);(OUT/'cleanup.json').write_bytes(cleanup_bytes)
(OUT/'run-api.json').write_bytes(run_bytes);write('artifact-api.json',ARTIFACT);write('INDEPENDENT_SECRET_ABSENCE.json',absence)
download={'artifact_id':ARTIFACT['id'],'started_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'attempt':1,'state':'REQUESTED'}
write('DOWNLOAD.json',download)
p=cmd(['gh','api','repos/'+REPO+'/actions/artifacts/'+str(ARTIFACT['id'])+'/zip'],timeout=120)
download.update(returncode=p.returncode,finished_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),state='RESPONSE_RECEIVED')
write('DOWNLOAD.json',download)
assert p.returncode==0,'Artifact download failed; preserve receipt and inspect before retry'
raw=p.stdout;archive=OUT/('artifact-'+str(ARTIFACT['id'])+'.zip');archive.write_bytes(raw)
assert len(raw)==ARTIFACT['size_in_bytes'] and sha(raw)==ARTIFACT['digest'].split(':')[1]
allowed=set(('source-before.json source-after.json selection.json declarations.json ownership.json artifact-isolation.json fixture-container.json fixture-query.json fixture-after.json native-witness.json connection-stages.json original-build-result.json app-group-resolver-interface.json python-oracle-environment.json faithful-ipad-matrix.json test-simulator-11.log test-case-execution-11.json miniTest10-native-fixture-install-11.json miniTest10-native-fixture-install-11-attempt-1.json miniTest10-native-fixture-install-11-before-reboot.json miniTest10-native-fixture-termination-11.json miniTest10-native-fixture-termination-11-before-reboot.json verified-11.json verified-11.summary.json verified-11.tests.json fixture-oracle-11.json original-test-details.json result.json admission.json').split())
payloads={}
with zipfile.ZipFile(io.BytesIO(raw)) as z:
 assert z.testzip() is None
 infos=z.infolist();assert 1<len(infos)<=len(allowed)
 assert sum(i.file_size for i in infos)<=64*1024*1024
 for i in infos:
  name=i.filename;p=PurePosixPath(name)
  assert name in allowed and not p.is_absolute() and len(p.parts)==1 and '\\' not in name
  assert name not in payloads and not i.is_dir() and ((i.external_attr>>16)&0o170000)!=0o120000
  assert 0<=i.file_size<=32*1024*1024 and not (i.flag_bits&1)
  payloads[name]=z.read(i)
admission=strict(payloads['admission.json'])
assert admission['status']=='SCANNED_ALLOWLIST_ONLY'
for key in ['private_input_removed','provider_file_excluded','raw_xcresult_and_attachments_excluded','raw_video_excluded']:assert admission[key] is True
assert set(admission['files'])==set(payloads)-{'admission.json'}
for name,info in admission['files'].items():assert len(payloads[name])==info['bytes'] and sha(payloads[name])==info['sha256']
report=strict(payloads['result.json'])
assert report['native116_acceptance'] is False and report['release114_acceptance'] is False
assert report['credential_in_test_arguments'] is False and report['credential_in_child_environment'] is False
assert report['raw_container_or_result_bundle_published'] is False and report['private_input_removed'] is True
assert report['selector']=='HanlinLiveProviderAcceptanceTests/testOriginalLiveProviderUsesCanonicalCoreAndRevokesReadConsent'
owner=strict(payloads['ownership.json']);assert owner['run_id']==str(RUN) and owner['run_attempt']=='1'
assert str(uuid.UUID(owner['nonce'])).upper()==owner['nonce']
assert payloads['source-before.json']==payloads['source-after.json']
source=strict(payloads['source-before.json'])
assert source['checkout_sha']==HEAD and source['application_source_sha']==source['reviewed_source_sha']==APP
assert source['original_build_status']=='SIMULATOR_BUILD_FOR_REAL_UI_PASS' and len(source['execution_inputs'])==281
diagnostic=None
if 'connection-stages.json' in payloads:
 sourcecode=cmd(['git','-c','core.autocrlf=false','show',HEAD+':Scripts/CI/runtime27-hanlin-live.py'])
 assert sourcecode.returncode==0
 tree=ast.parse(sourcecode.stdout)
 names={'CONNECTION_DIAGNOSTIC_STAGES','CONNECTION_DIAGNOSTIC_REASONS','CONNECTION_DIAGNOSTIC_FLAGS'}
 selected=[n for n in tree.body if (isinstance(n,ast.FunctionDef) and n.name in {'require','validate_connection_diagnostic'}) or (isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id in names for t in n.targets))]
 assert len(selected)==5
 namespace={'json':json,'uuid':uuid}
 exec(compile(ast.Module(body=selected,type_ignores=[]),'frozen-live-diagnostic-validator','exec'),namespace)
 diagnostic=namespace['validate_connection_diagnostic'](payloads['connection-stages.json'])
 assert diagnostic['nonce']==owner['nonce']
 assert report['connection_diagnostic_status']==('OVERFLOW' if diagnostic['overflow'] else 'OBSERVED')
extracted=OUT/'extracted';extracted.mkdir()
for name,data in payloads.items():(extracted/name).write_bytes(data)
receipt={'schema':1,'status':'ADMITTED_EXACT_FAILED_LIVE8_ARTIFACT_NO_ACCEPTANCE','run':RUN,'attempt':1,'checkout':HEAD,'application_source':APP,'artifact_id':ARTIFACT['id'],'artifact_sha256':sha(raw),'artifact_bytes':len(raw),'download_count':1,'zip_crc_members':len(payloads),'admitted_payloads':len(admission['files']),'source_before_after_byte_identical':True,'recorded_execution_inputs':len(source['execution_inputs']),'execution_inputs_independent_git_verification':'pending separate review','secret_cleanup_delete_http_status':204,'secret_absence_http_status':404,'private_input_removed':True,'producer_credential_scan':'Original exact-source allowlist and credential/canary scanner; root does not claim an independent credential-value rescan','original_connection_diagnostic_validated':diagnostic is not None,'result':report,'diagnostic':diagnostic}
write('INTAKE.json',receipt)
files=[{'path':str(p.relative_to(OUT)).replace('\\','/'),'bytes':p.stat().st_size,'sha256':sha(p.read_bytes())} for p in sorted(OUT.rglob('*')) if p.is_file()]
write('FILE_INDEX.json',{'schema':1,'files':files,'count':len(files),'scope':'Original admitted failed Live8 artifact and exact cleanup; no test/build/rerun'})
print(json.dumps({'status':receipt['status'],'out':str(OUT),'artifact_id':ARTIFACT['id'],'artifact_sha256':sha(raw),'members':len(payloads),'result':report,'diagnostic':diagnostic,'cleanup':cleanup,'independent_absence':absence,'file_index_sha256':sha((OUT/'FILE_INDEX.json').read_bytes())},ensure_ascii=False))
