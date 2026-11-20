from pathlib import Path
import datetime, gzip, hashlib, importlib.util, json, zipfile

R=Path(__file__).resolve().parent
E=R/'extracted/cold-search-ownership'
def sha(b): return hashlib.sha256(b).hexdigest()
def read(n): return json.loads((E/n).read_bytes())
receipts=json.loads((R/'GITHUB_RECEIPTS.json').read_text())
run=receipts['run']; jobs=receipts['jobs']['jobs']; artifact=receipts['artifacts']['artifacts'][0]
assert run['id']==44770208643 and run['run_attempt']==1 and run['event']=='push'
assert run['head_sha']=='96f2b8a34259032c9328d972b8eacbdc94121e81'
assert run['head_branch']=='codex/otzaria-cold-search-ownership-v2-20261120'
assert run['status']=='completed' and run['conclusion']=='failure'
assert len(jobs)==1 and jobs[0]['id']==136405525120 and jobs[0]['conclusion']=='failure'
assert artifact['id']==14645498790 and artifact['workflow_run']['head_sha']==run['head_sha'] and artifact['workflow_run']['id']==run['id']
b=(R/'artifact-14645498790.zip').read_bytes()
assert len(b)==artifact['size_in_bytes']==1221829 and 'sha256:'+sha(b)==artifact['digest']
with zipfile.ZipFile(R/'artifact-14645498790.zip') as z:
    assert z.testzip() is None and len(z.namelist())==253
    for name in z.namelist():
        if not name.endswith('/'):
            assert z.read(name)==(R/'extracted'/name).read_bytes(),name
tree=json.loads((R/'ROOT_GIT_TREE.json').read_text())
assert tree['sha']=='57f85214a2ec1fc3591eae58c7a750900c680047' and not tree['truncated']
canonical={row['path']:row for row in tree['tree']}
result=read('RESULT.json')
assert result['status']=='FAIL_ACTUAL_OWNERSHIP_ACCEPTANCE'
assert result['github']['GITHUB_SHA']==run['head_sha'] and result['github']['GITHUB_RUN_ATTEMPT']=='1'
before=read('source-before.json'); assert before==read('source-after.json')
proof=[]
with zipfile.ZipFile(E/'SOURCE_INPUTS.zip') as z:
    assert z.testzip() is None
    for name in z.namelist():
        data=z.read(name); blob=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
        assert canonical[name]['sha']==blob,name
        proof.append({'path':name,'bytes':len(data),'sha256':sha(data),'git_blob':blob})
    manifest=json.loads(z.read('Tests/HQ/cold-search-ownership/OWNERSHIP_INPUTS.json'))
    assert sha(z.read('Tests/HQ/cold-search-ownership/OWNERSHIP_INPUTS.json'))==result['input_manifest_sha256']=='cdfae26afdc8854b8433a385ca3497d14c772db240529d0b4f43749f557dbfb9'
    for row in before:
        data=z.read(row['path']);assert len(data)==row['bytes'] and sha(data)==row['sha256'],row['path']
    driver=R/'original_driver.py';driver.write_bytes(z.read('tools/hq-cold-search-ownership.py'))
    preguard=gzip.decompress(z.read('Tests/HQ/cold-search-ownership/pre-publication-Repository.swift.gz'))
    product=z.read('Source/Otzaria/Search/OtzariaTantivySearchRepository.swift')
spec=importlib.util.spec_from_file_location('original_ownership_driver',driver)
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
stages={}
for name,names,source in [('pre-guard1',[manifest['baseline_case']],preguard),('candidate32',manifest['cases'],product)]:
    stage=result['stages'][name];checks=read(name+'.CHECKS.json')
    assert checks==stage['checks'] and [row['id'] for row in checks['checks']]==names
    assert stage['compile']['returncode']==0 and not stage['compile']['timed_out']
    assert stage['runtime']['returncode']==1 and not stage['runtime']['timed_out']
    assert read(name+'.source-before.json')==read(name+'.source-after.json')
    assert read(name+'.source-before.json')['OtzariaTantivySearchRepository.swift']==sha(source)
    for suffix,key in [('compile','compile'),('run','runtime')]:
        assert sha((E/(name+'.'+suffix+'.log')).read_bytes())==stage[key]['log_sha256']
    expected={case:('failed' if name=='pre-guard1' else 'passed') for case in names}
    qualified=module.qualify(checks,stage['runtime'],expected)
    assert qualified==stage['qualified']
    rows=checks['checks'];stages[name]={'completed':len(rows),'passed':sum(v['outcome']=='passed' for v in rows),'failures':[v for v in rows if v['outcome']!='passed'],'qualified':qualified,'compile_exit':0,'runtime_exit':1,'runtime_seconds':stage['runtime']['elapsed_seconds'],'source_unchanged':True,'refusal_mismatches':[v for v in checks.get('refusalObservations',[]) if v.get('expected')!=v.get('observed')]}
assert stages['candidate32']['passed']==31 and stages['candidate32']['failures']==[{'code':'wrong_or_missing_refusal','id':'missing_index_is_not_created','outcome':'failed'}]
assert stages['pre-guard1']['qualified'] is True and stages['candidate32']['qualified'] is False
report={'status':'ACTUAL_V2_FAILURE_INDEPENDENTLY_VERIFIED','reviewed_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'run':run['id'],'attempt':1,'head':run['head_sha'],'job':jobs[0]['id'],'started_at':jobs[0]['started_at'],'completed_at':jobs[0]['completed_at'],'artifact':artifact['id'],'bytes':len(b),'sha256':sha(b),'outer_crc_members':253,'canonical_source_members':len(proof),'stages':stages,'source_before_after_unchanged':True,'original_qualifier_replayed':True,'real_C_engine_executed':0,'Native_UI_executed':0,'v2_URL_observation':'Actual before-creation URL without directory hint differs from same-manager URL after creation. Original product exact guard retained.','cache_barrier_observation':result['stages']['candidate32']['checks']['fixtureSourceSetup'][11]}
(R/'ROOT_REVIEW.json').write_text(json.dumps(report,indent=2)+'\n')
(R/'SOURCE_GIT_PROOF.json').write_text(json.dumps(proof,indent=2)+'\n')
print(json.dumps(report,indent=2))
