#!/usr/bin/env python3
"""Replay authentic source and original result gates; executes no Swift tests."""
from pathlib import Path
import collections
import datetime
import gzip
import hashlib
import importlib.util
import json
import re
import zipfile

ROOT = Path(__file__).resolve().parent
HEAD = '798d31869e8ad4160aa30b0e6dc8d552701c40ec'
RUN = 44765478132
ARTIFACT = 14645640415
def load(p):
    if p.exists(): return json.loads(p.read_text())
    return json.loads(gzip.decompress(p.with_suffix(p.suffix+'.gz').read_bytes()))
def sha(b): return hashlib.sha256(b).hexdigest()
def blob(b): return hashlib.sha1(b'blob ' + str(len(b)).encode() + b'\0' + b).hexdigest()
def save(p,x): p.write_text(json.dumps(x,indent=2,sort_keys=True)+'\n')

def main():
    meta=load(ROOT/'GITHUB_RECEIPTS.json');run=meta['run'];a=meta['artifacts']['artifacts'][0]
    assert run['id']==RUN and run['head_sha']==HEAD and run['run_attempt']==1
    assert run['status']=='completed' and run['conclusion']=='success' and run['event']=='push'
    assert run['path']=='.github/workflows/otzaria-cold-search-core-validation.yml'
    assert a['id']==ARTIFACT and not a['expired'] and a['workflow_run']['id']==RUN
    assert a['workflow_run']['head_sha']==HEAD
    jobs=load(ROOT/'GITHUB_JOBS.json')['jobs']; assert len(jobs)==1
    assert jobs[0]['id']==136388828011 and jobs[0]['head_sha']==HEAD and jobs[0]['conclusion']=='success'
    archive=ROOT/f'artifact-{ARTIFACT}.zip';data=archive.read_bytes()
    assert len(data)==a['size_in_bytes']==246344
    assert a['digest']=='sha256:'+sha(data)
    assert sha(data)=='da326ae5f77d1974334521c2af7b8ff2c1283376676f2cb50dd10bbf34fef9ad'
    raw=ROOT/'extracted'
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None and len(z.namelist())==17
        for name in z.namelist(): assert z.read(name)==(raw/name).read_bytes()
    raw=raw/'cold-search-core-apple';source=ROOT/'source-inputs';source.mkdir(exist_ok=True)
    authority={x['path']:x['sha'] for x in meta['base_tree']['tree'] if x['type']=='blob'}
    compare=meta['v2_compare'];assert compare['base_commit']['sha']=='a826e66ab2710f1d3c05342da5b39b79e8c30c44'
    assert compare['commits'][-1]['sha']==HEAD and len(compare['files'])==20
    authority.update({x['filename']:x['sha'] for x in compare['files']})
    source_rows=[]
    with zipfile.ZipFile(raw/'SOURCE_INPUTS.zip') as z:
        assert z.testzip() is None and len(z.namelist())==61
        for name in z.namelist():
            p=Path(name);assert not p.is_absolute() and '..' not in p.parts
            b=z.read(name);assert blob(b)==authority[name],name
            q=source/p;q.parent.mkdir(parents=True,exist_ok=True);q.write_bytes(b)
            source_rows.append({'path':name,'bytes':len(b),'sha256':sha(b),'git_blob':blob(b)})
    driverpath=source/'tools/hq-cold-search-core-acceptance.py'
    spec=importlib.util.spec_from_file_location('original_core_driver',driverpath)
    driver=importlib.util.module_from_spec(spec);spec.loader.exec_module(driver)
    manifest=load(source/driver.INPUTS);before=driver.verify_inputs(source,manifest)
    assert before==load(raw/'source-before.json')==load(raw/'source-after.json')
    result=load(raw/'RESULT.json');assert result['status']=='PASS_APPLE_CORE_194_WITH_BASELINE20_RED'
    assert result['git_head']==HEAD and result['github']['GITHUB_RUN_ID']==str(RUN)
    assert result['github']['GITHUB_RUN_ATTEMPT']=='1' and result['github']['GITHUB_REF']==driver.BRANCH
    assert result['inputs_sha256']==sha((source/driver.INPUTS).read_bytes())=='34469214c2fbcdd9058e0c8a614163c766114219fc484177341676b2873611ff'
    assert result['native_ui_executed']==result['actual_c_engine_executed']==0
    expected_red={c:'passed' for c in manifest['baseline_expected_pass']}
    expected_red.update({c:'failed' for c in manifest['baseline_expected_fail']})
    expected_green={c:'passed' for c in manifest['original_cases']+manifest['added_cases']}
    reports={}
    for name,expected in [('baseline20',expected_red),('candidate194',expected_green)]:
        stage=load(raw/(name+'.result.json'));assert stage==result['stages'][name]
        log=(raw/(name+'.log')).read_bytes();assert sha(log)==stage['process']['log_sha256']
        replay=driver.classify_run(stage['process'],driver.parse_xctest(log.decode()),expected)
        assert replay['qualified']
        for key,value in replay.items(): assert stage[key]==value,(name,key)
        sources={x['path']:x['sha256'] for x in manifest['core_inputs']}
        if name=='baseline20':sources[driver.EXECUTOR]=manifest['baseline_executor']['sha256']
        assert load(raw/(name+'.source-before.json'))==sources==load(raw/(name+'.source-after.json'))
        assert stage['source_unchanged']
        reports[name]={k:stage[k] for k in ['actual_completed','passed','failed','skipped','qualified','final_summary']}
        reports[name]['process']=stage['process']
    raw_job=(load(ROOT/'JOB_LOG_INPUT.json')['content'] if (ROOT/'JOB_LOG_INPUT.json').exists()
             else gzip.decompress((ROOT/'job-136388828011.log.gz').read_bytes()).decode())
    (ROOT/'job-136388828011.log.gz').write_bytes(gzip.compress(raw_job.encode(),mtime=0))
    controls=[l for l in raw_job.splitlines() if re.search(r'test\w+ \(.+\) \.\.\. ok$',l)]
    assert len(controls)==13 and 'Ran 13 tests in ' in raw_job
    versions={}
    for key in ['swift','xcode']:
        log=(raw/(key+'-version.log')).read_bytes();assert sha(log)==result[key+'_identity']['log_sha256']
        assert result[key+'_identity']['returncode']==0 and not result[key+'_identity']['timed_out']
        versions[key]=log.decode().strip()
    old_original=load(ROOT/'FIRST_RUN_RESULT.json')
    assert old_original['stages']['candidate194']['passed']==193 and old_original['stages']['candidate194']['failed']==1
    review={'reviewed_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'run':RUN,'head':HEAD,'attempt':1,'artifact':{'id':ARTIFACT,'bytes':len(data),'sha256':sha(data),'outer_members':17,'source_members':61},'actual_original_XCTest_cases':174,'actual_added_cases':20,'candidate_passed':194,'candidate_failed':0,'candidate_skipped':0,'baseline_scope':'Original19b Executor with shared candidate types and20 new controls, including repaired selection helper; not a whole original19b package run','stages':reports,'all_source_inputs_equal_canonical_Git':True,'before_after_source_identical':True,'all_starts_leaves_and_exit_classes_replayed_with_original_driver':True,'actual_Mac_Python_verifier_controls':13,'versions':versions,'original193_of194_failure_retained':True,'replay_executed_Swift':0,'app_compilation':'NOT_ESTABLISHED','Darwin_ownership':'SEPARATE_GATE','actual_C_engine':'NOT_RUN','Native':'NOT_RUN','unknown_Windows_job':'job_ed394b183ed4'}
    save(ROOT/'ROOT_REVIEW.json',review);save(ROOT/'SOURCE_GIT_PROOF.json',source_rows)
    print(json.dumps({'candidate':reports['candidate194'],'baseline':reports['baseline20'],'source_inputs':61,'Mac_verifier_controls':13,'versions':versions},indent=2))

if __name__=='__main__':main()
