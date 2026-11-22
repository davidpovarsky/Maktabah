"""New synthetic admission boundaries only; no framework or native execution."""
import copy
import hashlib
import io
import json
from pathlib import Path
import runpy
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
CI = ROOT / 'candidate/Scripts/CI'
HELPER = runpy.run_path(str(CI / 'original_editor_continuation_admission.py'))
HQ = runpy.run_path(str(CI / 'hq-original-editor-distribution.py'))
FRAMEWORK = json.loads((ROOT / 'FRAMEWORK_PRODUCER.json').read_text())
DOTFILES = {FRAMEWORK['archive_omissions'][i]['distribution_path']: (ROOT / 'controls/original-dotfiles' / name).read_bytes()
            for i, name in enumerate(['app-gitattributes', 'hanlin-gitattributes'])}

def sha(raw): return hashlib.sha256(raw).hexdigest()

def fixtures():
    p = copy.deepcopy(FRAMEWORK)
    runtime = dict(repository=p['repository'], repository_id=p['repository_id'], control_sha='a'*40,
                   run_id=999001, run_attempt=1, workflow_path=HELPER['WORKFLOW'], head_branch=HELPER['BRANCH'],
                   job_name=HELPER['JOB_NAME'], job_id=999002, required_steps=copy.deepcopy(HELPER['RUNTIME_REQUIRED_STEPS']),
                   evidence_artifact=dict(id=999003, name='Otzaria-Original-Editor-Runtime-Continuation-'+('a'*40)+'-999001-1', size_in_bytes=50,
                   sha256='b'*64, path='build/sdk/runtime.zip', upload_step=HELPER['RUNTIME_UPLOAD_STEP']))
    config = {k:copy.deepcopy(p[k]) for k in ['repository','repository_id','source_sha','run_id','run_attempt','job_id','job_name','workflow_path','required_steps']}
    config.update(schema=2,framework_producer=p,runtime_qualification_producer=runtime,
                  framework_artifact={**p['framework_artifact'],'path':'build/sdk/framework.zip'},
                  evidence_artifact={**p['evidence_artifact'],'path':'build/sdk/original-evidence.zip'},
                  artifact_id=p['framework_artifact']['id'],archive_path='build/sdk/framework.zip',
                  archive_bytes=p['framework_artifact']['size_in_bytes'],archive_sha256=p['framework_artifact']['sha256'],
                  distribution_root='build/sdk/distribution', distribution_manifest_path='build/sdk/framework-distribution.json',
                  distribution_manifest_sha256=p['retained_input_sha256']['framework-distribution.json'],
                  hanlin_source_path='build/sdk/hanlin.json',hanlin_source_sha256=p['retained_input_sha256']['original-hanlin-snapshot.json'],
                  original_source_sha256=p['original_source_sha256'],qualification_path='build/sdk/runtime-qualification.json',
                  qualification_sha256='c'*64,qualification_member='runtime-qualification.json',qualification_wrapper=HELPER['RUNTIME_WRAPPER'])
    restoration = dict(status='EXACT_ORIGINAL_FULL_DISTRIBUTION_RESTORED_WITH_TWO_SOURCE_BOUND_DOTFILES',
                       historical_archive_sha256=p['framework_artifact']['sha256'],historical_archive_unchanged=True,
                       archive_product_members=2526,restored_product_members=2528,restored_product_bytes=1258249614,
                       omissions=copy.deepcopy(p['archive_omissions']),original_qualification_synthesized=False)
    qualification = dict(schema=2,kind='ORIGINAL_FRAMEWORK_RUNTIME_CONTINUATION',status=HELPER['QUALIFIED'],phase='COMPLETE',
        framework_source_sha=p['source_sha'],framework_producer=copy.deepcopy(p),
        runtime_qualification_producer={k:runtime[k] for k in HELPER['RUNTIME_IDENTITY_KEYS']},
        original_framework_build='REUSED_SUCCESSFUL_ORIGINAL_PRODUCER',source_controls_replayed=0,
        retained_source_controls_passed=245,external_consumer_build='PASS',same_toolchain_only=True,
        simulator_attempts=1,install_attempts=1,automatic_retry=False,swift=p['toolchain']['swift'],sdk=p['toolchain']['sdk_version'],
        preflight={'xcode':p['toolchain']['xcode']},compiled_consumer_api_probe_sha256=p['consumer_source_sha256'],
        owned_simulator_cleanup_completed=True,distribution_unchanged=True,
        distribution_manifest_sha256=config['distribution_manifest_sha256'],original_source_sha256=config['original_source_sha256'],
        hanlin_source_sha256=config['hanlin_source_sha256'],public_surface_producer={k:p[k] for k in ['source_sha','run_id','run_attempt']},
        original_clang_declarations={'manifest_sha256':p['clang_manifest_sha256']},
        verified_runtime_observations=[dict(language=lang,status='ACTUAL_IMPORT_LINK_RESOURCE_RUNTIME_PASS') for lang in ['en','he']],
        actual_public_surface={'fixture':'explicit synthetic public-surface value, not an actual compiler proof'},restoration=restoration)
    return config, qualification


def metadata(role, item, framework):
    head=role['source_sha'] if framework else role['control_sha'];conclusion='failure' if framework else 'success'
    run=dict(id=role['run_id'],run_attempt=role['run_attempt'],head_sha=head,head_commit={'id':head},status='completed',conclusion=conclusion,event='push',
             path=role['workflow_path'],head_branch=role['head_branch'],repository={'id':role['repository_id'],'full_name':role['repository']},
             head_repository={'id':role['repository_id'],'full_name':role['repository']})
    start,end='2026-11-22T16:00:00Z','2026-11-22T16:10:00Z'
    steps=[dict(name=n,status='completed',conclusion='success',started_at=start,completed_at=end)
           for n in dict.fromkeys([*role['required_steps'],item['upload_step']])]
    if framework:steps.append(dict(name=role['failed_step'],status='completed',conclusion='failure',started_at=start,completed_at=end))
    job=dict(id=role['job_id'],name=role['job_name'],run_id=role['run_id'],run_attempt=role['run_attempt'],head_sha=head,
             head_branch=role['head_branch'],status='completed',conclusion=conclusion,steps=steps,started_at=start,completed_at=end)
    artifact={k:item[k] for k in ['id','name','size_in_bytes']}
    artifact.update(expired=False,digest='sha256:'+item['sha256'],created_at='2026-11-22T16:05:00Z',
                    workflow_run=dict(id=role['run_id'],head_sha=head,head_branch=role['head_branch'],repository_id=role['repository_id'],head_repository_id=role['repository_id']))
    return run,job,artifact


def payload(path, config, qualification, *, omit=None, alter=None, extra_outer=False):
    raw=json.dumps(qualification,sort_keys=True).encode();config['qualification_sha256']=sha(raw)
    inner=io.BytesIO()
    with zipfile.ZipFile(inner,'w',zipfile.ZIP_DEFLATED) as z:
        z.writestr('runtime-qualification.json',raw)
        z.writestr('RESTORATION.json',json.dumps(qualification['restoration']))
        for item in config['framework_producer']['archive_omissions']:
            if item['distribution_path']==omit:continue
            data=DOTFILES[item['distribution_path']]
            if item['distribution_path']==alter:data+=b'x'
            z.writestr(item['evidence_path'],data)
    with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED) as z:
        z.writestr(HELPER['RUNTIME_WRAPPER'],inner.getvalue())
        if extra_outer:z.writestr('UNEXPECTED',b'extra')


class Schema2Boundaries(unittest.TestCase):
    def test_separate_roles_are_accepted_without_relabeling(self):
        c,q=fixtures();r=HELPER['validate_qualification'](c,q)
        self.assertEqual(r['framework_producer']['run_id'],45041382512)
        self.assertNotEqual(r['runtime_qualification_producer']['run_id'],45041382512)
    def test_flat_framework_alias_cannot_claim_new_control(self):
        c,q=fixtures();c['source_sha']=c['runtime_qualification_producer']['control_sha']
        with self.assertRaises(RuntimeError):HELPER['validate_configuration'](c)
    def test_any_change_to_fixed_framework_contract_is_rejected(self):
        c,q=fixtures();c['framework_producer']['required_steps']=[]
        with self.assertRaises(RuntimeError):HELPER['validate_configuration'](c)
    def test_failed_runtime_receipt_is_rejected(self):
        c,q=fixtures();q['status']='FAIL'
        with self.assertRaises(RuntimeError):HELPER['validate_qualification'](c,q)
    def test_new_head_cannot_be_old_framework_head(self):
        c,q=fixtures();c['runtime_qualification_producer']['control_sha']=c['source_sha']
        with self.assertRaises(RuntimeError):HELPER['validate_configuration'](c)
    def test_runtime_metadata_must_succeed(self):
        c,q=fixtures();r=c['runtime_qualification_producer'];a=r['evidence_artifact'];run,job,artifact=metadata(r,a,False);run['conclusion']='failure'
        with self.assertRaises(RuntimeError):HELPER['verify_role_metadata'](r,run,job,artifact,a,framework=False)
    def test_old_failed_producer_remains_explicitly_failed(self):
        c,q=fixtures();r=c['framework_producer'];a=r['framework_artifact'];run,job,artifact=metadata(r,a,True)
        HELPER['verify_role_metadata'](r,run,job,artifact,a,framework=True)
        run['conclusion']='success'
        with self.assertRaises(RuntimeError):HELPER['verify_role_metadata'](r,run,job,artifact,a,framework=True)
    def test_artifact_cannot_cross_producer_roles(self):
        c,q=fixtures();r=c['runtime_qualification_producer'];a=r['evidence_artifact'];run,job,artifact=metadata(r,a,False);artifact['workflow_run']['id']=c['run_id']
        with self.assertRaises(RuntimeError):HELPER['verify_role_metadata'](r,run,job,artifact,a,framework=False)
    def test_artifact_must_be_created_inside_own_upload(self):
        c,q=fixtures();r=c['runtime_qualification_producer'];a=r['evidence_artifact'];run,job,artifact=metadata(r,a,False);artifact['created_at']='2026-11-22T16:20:00Z'
        with self.assertRaises(RuntimeError):HELPER['verify_role_metadata'](r,run,job,artifact,a,framework=False)
    def test_qualification_cannot_be_inside_product_inventory(self):
        c,q=fixtures();c['qualification_path']=c['distribution_root']+'/QUALIFICATION.json'
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaises(RuntimeError):HELPER['validate_paths'](Path(d),c,HQ)
    def test_changed_sidecar_is_detected_with_unchanged_products(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);distribution=root/'build/distribution';distribution.mkdir(parents=True);(distribution/'native').write_bytes(b'unchanged explicit fixture')
            config=root/'Scripts/CI/input.json';config.parent.mkdir(parents=True);config.write_bytes(b'{}')
            sidecar=root/'build/runtime.json';sidecar.write_bytes(b'first')
            r=dict(schema=2,admission_path='Scripts/CI/input.json',admission_sha256=HQ['digest'](config),distribution_root='build/distribution',
                   distribution_files=HQ['inventory'](distribution),qualification_path='build/runtime.json',qualification_sha256=HQ['digest'](sidecar))
            HQ['require_unchanged'](root,r);sidecar.write_bytes(b'changed')
            with self.assertRaises(RuntimeError):HQ['require_unchanged'](root,r)
    def test_exact_wrapper_and_original_dotfile_bytes_are_read(self):
        c,q=fixtures()
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/'evidence.zip';payload(path,c,q);raw,restored,supplements=HELPER['runtime_payload'](path,c)
            self.assertEqual(supplements,DOTFILES);self.assertEqual(json.loads(raw)['framework_producer'],FRAMEWORK)
    def test_extra_outer_wrapper_member_is_rejected(self):
        c,q=fixtures()
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/'evidence.zip';payload(path,c,q,extra_outer=True)
            with self.assertRaises(RuntimeError):HELPER['runtime_payload'](path,c)
    def test_missing_source_bound_dotfile_is_rejected(self):
        c,q=fixtures()
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/'evidence.zip';payload(path,c,q,omit=next(iter(DOTFILES)))
            with self.assertRaises(RuntimeError):HELPER['runtime_payload'](path,c)
    def test_changed_source_bound_dotfile_is_rejected(self):
        c,q=fixtures()
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/'evidence.zip';payload(path,c,q,alter=next(iter(DOTFILES)))
            with self.assertRaises(RuntimeError):HELPER['runtime_payload'](path,c)
    def test_reused_framework_cannot_claim_new_build(self):
        c,q=fixtures();q['original_framework_build']='PASS'
        with self.assertRaises(RuntimeError):HELPER['validate_qualification'](c,q)
    def test_toolchain_change_is_rejected(self):
        c,q=fixtures();q['preflight']['xcode']='other Xcode'
        with self.assertRaises(RuntimeError):HELPER['validate_qualification'](c,q)
    def test_missing_hebrew_runtime_observation_is_rejected(self):
        c,q=fixtures();q['verified_runtime_observations']=q['verified_runtime_observations'][:1]
        with self.assertRaises(RuntimeError):HELPER['validate_qualification'](c,q)
    def test_cleanup_acknowledgement_is_not_completed_cleanup(self):
        c,q=fixtures();q['owned_simulator_cleanup_completed']=False
        with self.assertRaises(RuntimeError):HELPER['validate_qualification'](c,q)
    def test_boolean_counts_cannot_replace_integer_attempts(self):
        c,q=fixtures();q['install_attempts']=True
        with self.assertRaises(RuntimeError):HELPER['validate_qualification'](c,q)
        c,q=fixtures();c['runtime_qualification_producer']['run_attempt']=True
        with self.assertRaises(RuntimeError):HELPER['validate_configuration'](c)

if __name__=='__main__': unittest.main(verbosity=2)
