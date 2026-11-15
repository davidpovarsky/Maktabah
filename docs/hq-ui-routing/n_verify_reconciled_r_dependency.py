from pathlib import Path
import hashlib,json,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'docs/hq-ui-routing'
R='e8b81fe844a935109036f60252ab0f176065e877'; OLD='44f518fcccce6bd20127f39eea8462d7a7a9dd47'
BASE='0436775d85893225005f29baf0aa3a20d7b88317'
def git(*args): return subprocess.check_output(['git',*args],cwd=ROOT)
def source(ref,path): return git('show',ref+':'+path)
assert git('rev-parse',R+'^').decode().strip()==BASE
prefix='Source/ChavrusaText/StudyWorkspace/'
paths=[prefix+x for x in ['StudyWorkspaceMappingOwnership.swift','StudyWorkspaceStore.swift','StudyWorkspaceNavigationAdapter.swift']]
records={p:{'git_blob':git('rev-parse',R+':'+p).decode().strip(),'git_bytes_sha256':hashlib.sha256(source(R,p)).hexdigest()} for p in paths}
assert records[paths[0]]['git_blob']=='5ba997af025d29fb8fd354a39cbd41b145c0665e'
assert records[paths[1]]['git_blob']=='ed6dc3d685a103c733fd30b453ee36a39eae48e3'
assert records[paths[2]]['git_blob']=='0fc38aa9dd9ea44b6e00b9111734f2c1394b5124'
block=lambda data:data.split(b'// MARK: Native mapping producer',1)[1].split(b'// MARK: Workspace presentation',1)[0]
assert source(R,paths[0])==source(OLD,paths[0]) and source(R,paths[1])==source(OLD,paths[1])
assert block(source(R,paths[2]))==block(source(OLD,paths[2]))
proposal=source('4b68336f','docs/hq-ui-routing/N_APP_BINDING_R44_DEPENDENCY_UNAPPLIED.diff')
with tempfile.TemporaryDirectory(prefix='ne8proof-',dir='C:/Users/DAVID/.codex/tmp') as temp:
    for p in paths:
        dest=Path(temp)/p;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(source(R,p))
    patch=Path(temp)/'exact-N4b-dependency.diff';patch.write_bytes(proposal)
    check=subprocess.run(['git','apply','--reverse','--check',str(patch)],cwd=temp,capture_output=True,text=True);assert check.returncode==0,check.stderr
    applied=subprocess.run(['git','apply','--reverse',str(patch)],cwd=temp,capture_output=True,text=True);assert applied.returncode==0,applied.stderr
    reconstructed={}
    for p in paths[1:]:
        raw=(Path(temp)/p).read_bytes(); normalized=raw.replace(b'\r\n',b'\n')
        assert normalized==source(BASE,p),p
        reconstructed[p]={'raw_written_sha256':hashlib.sha256(raw).hexdigest(),
            'git_lf_sha256':hashlib.sha256(normalized).hexdigest(),'exact_base_git_bytes_after_only_CRLF_normalization':True}
    assert not (Path(temp)/paths[0]).exists()
adapter=source(R,paths[2]); approved_blob=git('rev-parse',BASE+':'+paths[2]).decode().strip()
assert approved_blob=='36dd25996aedf5610f4d5bf30982163f4777a62a'
patch_path='docs/hq-native-mapping-reconciliation/SOURCE_AND_TESTS_UNAPPLIED.diff'
official_patch=source(R,patch_path)
report={'R_dependency':R,'single_parent_base':BASE,'N_production_source':'a0409b932ea4f5125122026500ab374eefc0ec87',
    'sources':records,'policy_and_store_exact_R44':True,'producer_block_exact_R44':True,
    'producer_block_git_bytes_sha256':hashlib.sha256(block(adapter)).hexdigest(),
    'N4b_dependency_patch_reverse_check_exit':check.returncode,'reverse_application_reconstructs_base043_store_and_adapter_exactly':True,
    'reverse_reconstruction_git_form':reconstructed,
    'approved_startup_adapter_blob':approved_blob,'N4b_proposal_patch_git_sha256':hashlib.sha256(proposal).hexdigest(),
    'R_official_source_test_patch_git_sha256':hashlib.sha256(official_patch).hexdigest(),
    'R_reported_patch_sha256':'2583ad3ca6d9d6cd678c3d2db68406af4341ea7b10674cb1d8069eead7b35dde',
    'R_original_new_run_evidence':'69 Store +63 exact-native-boundary +30 startup +61 legacy; independently attributed to R, not N test counts',
    'workspace_R_files_modified':False,'app_source_dependency_applied':False,'native_hook_applied':False,'SDK_native':'NOT_RUN'}
(OUT/'N-app-reconciled-e8-source-proof.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print('Independent e8 three-blob / R44 producer identity / full approved043 startup reverse reconstruction PASS.')
print('R official committed patch SHA256: '+report['R_official_source_test_patch_git_sha256'])
