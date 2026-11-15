from pathlib import Path
import hashlib,json,re,subprocess
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/hq-ui-routing'
SOURCE='a0409b932ea4f5125122026500ab374eefc0ec87'
R='e8b81fe844a935109036f60252ab0f176065e877'
assert not subprocess.check_output(['git','diff','--name-only',SOURCE,'--','Source'],cwd=ROOT,text=True).strip()
prior=json.loads((OUT/'N-app-owner-edge-report.json').read_text())
for p,v in prior['source_blobs_verified'].items():
    assert subprocess.check_output(['git','hash-object','--path',p,p],cwd=ROOT,text=True).strip()==v['expected_git_blob']
raw=(OUT/'N-app-reconciled-e8-full.log').read_bytes();text=raw.decode('utf-8-sig',errors='replace')
rows=re.findall(r'Executed (\d+) tests?, with (\d+) failures?',text)
assert rows[-1]==('114','0') and 'warning:' not in text
startup=re.findall(r'PASS STARTUP\[(\d+)\]',text);assert startup==[str(x) for x in range(1,31)]
app=re.findall(r"Test Case '(NActualAppBindingAdapterTests\.[^']+)' passed",text);assert len(app)==20
manifest=json.loads((OUT/'N-app-reconciled-e8-inputs.json').read_text());assert manifest['R']==R
assert manifest['R_dependency_base']=='0436775d85893225005f29baf0aa3a20d7b88317'
report={'status':'RECONCILED_E8_DEPENDENCY_CONSUMPTION_PORTABLE_PASS_REAL_OWNER_NATIVE_GATES_OPEN',
    'N_production':SOURCE,'N_production_changed':False,'R_dependency':R,'R_base':manifest['R_dependency_base'],
    'R_three_source_proof':'N-app-reconciled-e8-source-proof.json',
    'R_source_proof_sha256':hashlib.sha256((OUT/'N-app-reconciled-e8-source-proof.json').read_bytes()).hexdigest(),
    'actual_xctest_methods':114,'actual_N_app_methods':20,'failures':0,'compiler_warnings':0,
    'actual_R_startup_assertions_in_one_method':30,'app_method_names':app,
    'raw_log_sha256':hashlib.sha256(raw).hexdigest(),'input_manifest_sha256':hashlib.sha256((OUT/'N-app-reconciled-e8-inputs.json').read_bytes()).hexdigest(),
    'count_scope':'Prior113 repeated against e8 plus1 exact R startup wrapper;30 nested assertions not added as30 methods; R69/63/61 separate attributed evidence',
    'actual_R_portable_sources_and_producer_startup_methods_compiled':True,'native_boundaries':'Explicit R/N owner/UIKit/SwiftUI/catalog/hydration/backend doubles',
    'R_source_writes_or_app_dependency_application':False,'canonical_owner_producer_connection_applied':False,
    'project_or_native_hook_applied':False,'public_enablement':False,'SDK_native_device':'NOT_RUN','manager_source_acceptance':'PENDING'}
(OUT/'N-app-reconciled-e8-report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print('Actual immutable reconciled dependency full114/0/0 +30 startup assertions in1 method; unchanged N production verified.')
