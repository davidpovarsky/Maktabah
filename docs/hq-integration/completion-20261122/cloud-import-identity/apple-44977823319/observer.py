from pathlib import Path, PurePosixPath
import datetime,hashlib,json,os,shutil,subprocess,time,zipfile
root=Path.cwd();run_id=44977823319
head='385fffafb5b014f0777b3100151b5b6d0e75eed9'
app='5d0a11f6a799bee9deb23dc91b29e832bec14335'
repository='davidpovarsky/Maktabah'
out=root/'build/cloud-import-identity-observer'/str(run_id)
out.mkdir(parents=True,exist_ok=False)
(out/'observer.py').write_bytes(Path(__file__).read_bytes())
def now():return datetime.datetime.now(datetime.timezone.utc).isoformat()
def write(name,value):(out/name).write_text(json.dumps(value,indent=2,sort_keys=True)+'\n',encoding='utf-8',newline='\n')
def api(endpoint):
 r=subprocess.run(['gh','api',endpoint],capture_output=True,text=True,encoding='utf-8',timeout=45)
 if r.returncode:raise RuntimeError('GitHub API failed: '+endpoint+' '+r.stderr[:1000])
 return json.loads(r.stdout)
summary={'run_id':run_id,'head':head,'application_source':app,'started_at':now(),'status':'OBSERVING','polls':0}
write('OBSERVER.json',summary)
deadline=time.monotonic()+2100
try:
 run=None
 while time.monotonic()<deadline:
  try:
   observed=api('repos/'+repository+'/actions/runs/'+str(run_id))
  except Exception as error:
   summary['last_api_error']=repr(error);write('OBSERVER.json',summary);time.sleep(30);continue
  assert observed['head_sha']==head and observed['head_branch']=='codex/otzaria-cloud-import-identity-apple-20261122'
  assert observed['event']=='push' and observed['run_attempt']==1 and observed['repository']['id']==1280062128
  summary['polls']+=1;summary['last_status']=observed['status'];summary['observed_at']=now()
  write('latest-run.json',observed);write('OBSERVER.json',summary)
  if observed['status']=='completed':run=observed;break
  time.sleep(30)
 if run is None:
  summary['status']='BOUNDED_OBSERVER_EXPIRED';raise RuntimeError('Run did not finish within the owned 35 minute observation budget')
 write('run.json',run)
 jobs=api('repos/'+repository+'/actions/runs/'+str(run_id)+'/jobs?per_page=100')
 write('jobs.json',jobs)
 log=subprocess.run(['gh','run','view',str(run_id),'--repo',repository,'--log'],capture_output=True,text=True,encoding='utf-8',timeout=90)
 (out/'actions.log').write_text(log.stdout,encoding='utf-8',newline='\n')
 (out/'actions-log.stderr').write_text(log.stderr,encoding='utf-8',newline='\n')
 artifacts=api('repos/'+repository+'/actions/runs/'+str(run_id)+'/artifacts?per_page=100')
 write('artifacts.json',artifacts)
 found=[x for x in artifacts['artifacts'] if x['name']=='cloud-import-identity-apple-evidence' and not x['expired']]
 summary['github_conclusion']=run['conclusion'];summary['logs_exit_code']=log.returncode
 if not found:
  summary['status']='TERMINAL_WITHOUT_EVIDENCE_ARTIFACT'
 elif len(found)!=1:raise RuntimeError('Duplicate evidence artifacts')
 else:
  artifact=found[0];assert 0<artifact['size_in_bytes']<30000000
  archive=out/('artifact-'+str(artifact['id'])+'.zip')
  with archive.open('wb') as stream:
   r=subprocess.run(['gh','api','repos/'+repository+'/actions/artifacts/'+str(artifact['id'])+'/zip'],stdout=stream,stderr=subprocess.PIPE,timeout=180)
  assert r.returncode==0,r.stderr.decode(errors='replace')[:1000]
  summary['artifact_id']=artifact['id'];summary['artifact_sha256']=hashlib.sha256(archive.read_bytes()).hexdigest()
  summary['artifact_zip_bytes']=archive.stat().st_size
  extracted=out/'evidence';extracted.mkdir()
  with zipfile.ZipFile(archive) as package:
   assert package.testzip() is None
   for info in package.infolist():
    name=PurePosixPath(info.filename.replace('\\','/'))
    assert not name.is_absolute() and '..' not in name.parts
    assert ((info.external_attr>>16)&0o170000)!=0o120000
    path=(extracted/Path(*name.parts)).resolve()
    assert path.is_relative_to(extracted.resolve())
    if info.is_dir():path.mkdir(parents=True,exist_ok=True)
    else:path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(package.read(info))
  candidates=[]
  for path in extracted.rglob('RESULT.json'):
   value=json.loads(path.read_text())
   if 'core194_tests_executed' in value:candidates.append((path,value))
  if len(candidates)==1:
   result_path,result=candidates[0]
   summary['reported_result']=result
   if result.get('status')=='PASS_APPLE_CLOUD48_AND_ORIGINAL_IMPORT9_REOPEN9':
    assert result['checkout_sha']==head and result['application_source']==app
    assert [result['cloud48_passed'],result['import_passed'],result['reopen_passed']]==[48,9,9]
    before=json.loads((result_path.parent/'SOURCE_BEFORE.json').read_text())
    after=json.loads((result_path.parent/'SOURCE_AFTER.json').read_text())
    binding=json.loads(subprocess.check_output(['git','show',head+':Scripts/CI/cloud-import-identity-apple.inputs.json'],text=True,timeout=30))
    assert before['files']==binding['source_pins'] and before['run_id']==str(run_id) and before['run_attempt']=='1'
    assert after=={key:before[key] for key in after}
    summary['exact_source_inputs']=len(before['files'])
    summary['status']='VERIFIED_APPLE_PASS' if run['conclusion']=='success' else 'COMPONENT_PASS_WORKFLOW_FAILURE'
   else:summary['status']='VERIFIED_TERMINAL_FAILURE'
  else:
   summary['status']='TERMINAL_ARTIFACT_WITHOUT_UNIQUE_RESULT'
except Exception as error:
 summary['error']=repr(error)
 if summary['status']=='OBSERVING':summary['status']='OBSERVER_FAILED'
finally:
 summary['finished_at']=now();write('OBSERVER.json',summary);print(json.dumps(summary,indent=2),flush=True)
