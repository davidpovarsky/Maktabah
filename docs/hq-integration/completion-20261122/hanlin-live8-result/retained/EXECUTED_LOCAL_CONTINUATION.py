from pathlib import Path,PurePosixPath
import subprocess,json,hashlib,datetime,zipfile,io,os,re,ast,uuid
ROOT=Path(r'C:\Users\DAVID\Code\Maktabah-completion-20261122')
OUT=Path(r'C:\Users\DAVID\AppData\Local\Temp\otzaria-hanlin-live8-artifact-20261122')
RUN=45000580919;HEAD='ce5d11335c4b4769a25e0e8f48ba1d6f7efc6749';APP='6aa953048453b64a0013621ce76e095770eb7e7d'
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

assert OUT.is_dir() and not (OUT/'extracted').exists() and not (OUT/'FILE_INDEX.json').exists()
ARTIFACT=strict((OUT/'artifact-api.json').read_bytes());cleanup=strict((OUT/'cleanup.json').read_bytes());absence=strict((OUT/'INDEPENDENT_SECRET_ABSENCE.json').read_bytes())
assert cleanup['run_id']==RUN and cleanup['checkout_sha']==HEAD and cleanup['delete_http_status']==204 and cleanup['after_http_status']==404 and absence['http_status']==404
raw=(OUT/'artifact-14746509686.zip').read_bytes()
assert len(raw)==88435 and sha(raw)=='6e2ab18309e97d12791db2d2ccafafb320c38ca549db7a6c76008741a4e859f4'
assert ARTIFACT['id']==14746509686 and ARTIFACT['workflow_run']['id']==RUN and ARTIFACT['workflow_run']['head_sha']==HEAD
assert strict((OUT/'DOWNLOAD.json').read_bytes())['attempt']==1
env=dict(os.environ)
for key in ['GEMINI_API_KEY','OTZARIA_HANLIN_LIVE_API_KEY','OTZARIA_LIVE_GEMINI_API_KEY']:env.pop(key,None)
def cmd(args,timeout=60):
 assert args[0]=='git','This continuation is local immutable source review only'
 return subprocess.run(args,cwd=ROOT,env=env,capture_output=True,timeout=timeout)
def write(name,value):(OUT/name).write_bytes((json.dumps(value,indent=2,ensure_ascii=False)+'\n').encode())
(OUT/'EXECUTED_LOCAL_CONTINUATION.py').write_bytes(Path(__file__).read_bytes())
write('ORIGINAL_INTAKE_JOB.json',json.loads("{\"id\":\"job_5b740ee1d64c\",\"type\":\"job_result\",\"source\":\"script_run@host_7ec8382e82747448\",\"severity\":\"warning\",\"tool\":\"script_run\",\"host\":\"host_7ec8382e82747448\",\"status\":\"failed\",\"exit_code\":1,\"created_at\":1795336867.6987004,\"started_at\":\"2026-11-22T08:41:07.812988+00:00\",\"finished_at\":\"2026-11-22T08:41:12.293648+00:00\",\"duration_s\":4.48,\"error\":null,\"output_truncated\":false,\"timeout_s\":240,\"read\":false,\"notified\":{\"telegram\":null,\"resend\":null},\"notify_spec\":{},\"output\":\"Traceback (most recent call last):\\r\\n  File \\\"C:\\\\ProgramData\\\\SentinelX\\\\uploads\\\\.sentinelx_uploads\\\\script_job_aadf8883c9fb4d659e6be695f7bb200c\\\\intake_live8_admitted_artifact.py\\\", line 91, in <module>\\r\\n    assert diagnostic['nonce']==owner['nonce']\\r\\n           ~~~~~~~~~~^^^^^^^^^\\r\\nKeyError: 'nonce'\"}"))
write('INTAKE_ERRATUM.json',{'schema':1,'original_job':'job_5b740ee1d64c','original_error':'KeyError nonce after original schema validation','cause':'Root intake incorrectly assumed a nonce field in the diagnostic payload. The reviewed production schema deliberately contains only schemaVersion, overflow and events; the nonce binds the private source filename, not payload.','correction':'Use the unchanged exact-source validator and preserve original source-bound private filename/ownership attestation; do not invent a payload field or weaken validation. Complete local extraction from the one already downloaded and digest-verified ZIP.','artifact_downloads_repeated':0,'CI_tests_repeated':0,'secret_deletions_repeated':0})

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
 assert report['connection_diagnostic_status']==('OVERFLOW' if diagnostic['overflow'] else 'OBSERVED')
paths=['Scripts/CI','Scripts/verify-otzaria-mini-parity.py','.github/workflows','tools','Maktabah-iOSUITests','docs/hq-integration/runtime27/R27_CASES.json']
listing=cmd(['git','-c','core.autocrlf=false','ls-tree','-r','-z',HEAD,'--',*paths])
assert listing.returncode==0
expected={}
for row in listing.stdout.split(b'\0'):
 if not row:continue
 meta,name=row.split(b'\t',1);mode,kind,blob=meta.decode().split()
 assert kind=='blob'
 expected[name.decode()]=blob
assert len(expected)==281 and set(expected)==set(source['execution_inputs'])
specs=[HEAD+':'+p for p in expected]
pr=subprocess.run(['git','-c','core.autocrlf=false','cat-file','--batch'],cwd=ROOT,env=env,input=('\n'.join(specs)+'\n').encode(),capture_output=True,timeout=60)
assert pr.returncode==0
stream=io.BytesIO(pr.stdout);verified=[]
for name,blob in expected.items():
 header=stream.readline().decode().strip().split();assert len(header)==3 and header[1]=='blob' and header[0]==blob
 data=stream.read(int(header[2]));assert stream.read(1)==b'\n'
 record=source['execution_inputs'][name]
 assert record=={'blob':blob,'bytes':len(data),'sha256':sha(data)},name
 verified.append({'path':name,**record})
assert stream.read()==b''
trees={}
for name in ['Source','Vendor','Maktabah.xcodeproj','Maktabah-iOSUITests']:
 a=cmd(['git','rev-parse',HEAD+':'+name]);b=cmd(['git','rev-parse',APP+':'+name]);assert a.returncode==b.returncode==0 and a.stdout==b.stdout
 trees[name]=a.stdout.decode().strip()
 if name in source['application_trees']:assert trees[name]==source['application_trees'][name]
build=strict(payloads['original-build-result.json'])
assert build['checkout_sha']==HEAD and build['application_source_sha']==APP and build['status']=='SIMULATOR_BUILD_FOR_REAL_UI_PASS'
assert build['application_trees']==source['application_trees']
summary=strict(payloads['verified-11.summary.json']);detail=strict(payloads['original-test-details.json'])
assert summary['totalTestCount']==1 and summary['passedTests']==0 and summary['failedTests']==1 and summary['skippedTests']==0
assert detail['testIdentifier']==report['selector']+'()' and detail['testResult']=='Failed'
assert len(source['binaries'])==5
verification={'schema':1,'run':RUN,'attempt':1,'checkout':HEAD,'application_source':APP,'product_trees':trees,'source_before_after_byte_identical':True,'execution_inputs_verified':281,'execution_inputs':verified,'recorded_binary_digests':source['binaries'],'binary_verification_boundary':'Five unchanged runner-recorded before/after digests; binary payloads excluded by the original allowlist. No independent local binary-byte verification.','recorded_build_source_count':build['actual_source_inputs_verified'],'case_counts':{'total':1,'passed':0,'failed':1,'skipped':0},'case_duration_seconds':detail['durationInSeconds'],'diagnostic_events':len(diagnostic['events']) if diagnostic else 0,'diagnostic_nonce_binding':'Journal payload intentionally contains no nonce. The original reviewed capture selects the exact private nonce-qualified filename, validates it, and admits it under the generic connection-stages.json name. Root independently checks exact schema and one inputConsumed event; ownership/filename linkage remains the source-bound runner attestation.','native116_acceptance':False,'release114_acceptance':False,'new_executions':0}
write('SOURCE_VERIFICATION.json',verification)

extracted=OUT/'extracted';extracted.mkdir()
for name,data in payloads.items():(extracted/name).write_bytes(data)
receipt={'schema':1,'status':'ADMITTED_EXACT_FAILED_LIVE8_ARTIFACT_NO_ACCEPTANCE','run':RUN,'attempt':1,'checkout':HEAD,'application_source':APP,'artifact_id':ARTIFACT['id'],'artifact_sha256':sha(raw),'artifact_bytes':len(raw),'download_count':1,'zip_crc_members':len(payloads),'admitted_payloads':len(admission['files']),'source_before_after_byte_identical':True,'recorded_execution_inputs':len(source['execution_inputs']),'execution_inputs_independent_git_verification':281,'secret_cleanup_delete_http_status':204,'secret_absence_http_status':404,'private_input_removed':True,'producer_credential_scan':'Original exact-source allowlist and credential/canary scanner; root does not claim an independent credential-value rescan','original_connection_diagnostic_validated':diagnostic is not None,'result':report,'diagnostic':diagnostic}
write('INTAKE.json',receipt)
files=[{'path':str(p.relative_to(OUT)).replace('\\','/'),'bytes':p.stat().st_size,'sha256':sha(p.read_bytes())} for p in sorted(OUT.rglob('*')) if p.is_file()]
write('FILE_INDEX.json',{'schema':1,'files':files,'count':len(files),'scope':'Original admitted failed Live8 artifact and exact cleanup; no test/build/rerun'})
print(json.dumps({'status':receipt['status'],'out':str(OUT),'artifact_id':ARTIFACT['id'],'artifact_sha256':sha(raw),'members':len(payloads),'result':report,'diagnostic':diagnostic,'cleanup':cleanup,'independent_absence':absence,'file_index_sha256':sha((OUT/'FILE_INDEX.json').read_bytes())},ensure_ascii=False))
