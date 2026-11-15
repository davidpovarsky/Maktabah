from pathlib import Path
import hashlib,json,re,subprocess
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'docs/hq-ui-routing'
SOURCE='a0409b932ea4f5125122026500ab374eefc0ec87'
prior=json.loads((OUT/'N-app-owner-correction-report.json').read_text())
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()==SOURCE
assert not subprocess.check_output(['git','diff','--name-only',SOURCE,'--','Source'],cwd=ROOT,text=True).strip()
for p,v in prior['sources'].items():
    assert subprocess.check_output(['git','rev-parse',SOURCE+':'+p],cwd=ROOT,text=True).strip()==v['expected_git_blob']
raw=(OUT/'N-app-owner-edge-full.log').read_bytes(); text=raw.decode('utf-8-sig',errors='replace')
rows=re.findall(r'Executed (\d+) tests?, with (\d+) failures?',text)
assert rows[-1]==('113','0') and text.count('warning:')==0
methods=re.findall(r"Test Case '(NActualAppBindingAdapterTests\.[^']+)' passed",text); assert len(methods)==20
report={'status':'UNCHANGED_CANONICAL_OWNER_SOURCE_EDGE_CASES_PORTABLE_PASS_REAL_CONNECTION_UNAPPLIED',
    'production_source':SOURCE,'source_blobs_verified':prior['sources'],'source_changes':False,
    'actual_full_methods':113,'actual_app_methods':20,'failures':0,'compiler_warnings':0,
    'method_names':methods,'raw_log':'N-app-owner-edge-full.log','raw_log_sha256':hashlib.sha256(raw).hexdigest(),
    'input_manifest_sha256':hashlib.sha256((OUT/'N-app-owner-edge-inputs.json').read_bytes()).hexdigest(),
    'scope':'Prior93 + app20; overlapping111/110/107 not added. Exact actual mount/refresh+canonical source/adapter over explicitly doubled native shells.',
    'new_edges':['Equal-selection old adapter externally retained with still-valid actual R observation',
        'Different canonical owner of same adapter rejected as provenance mismatch',
        'Canonical owner ABA with distinct operation/admission between writes',
        'Late old cleanup does not remove new observer or third admission',
        'Nil/inpublication source+binding reads fail closed in actual synchronous invalidation callback'],
    'actual_lifecycle_producer_patch_applied':False,'new_native_sdk_device':'NOT_RUN','public_enablement':False,
    'R_reconciliation_or_frozen043_touched':False,'manager_independent_review':'PENDING'}
(OUT/'N-app-owner-edge-report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print('Immutable a040 production unchanged; actual extended full113/app20/0fail/0warnings verified.')
