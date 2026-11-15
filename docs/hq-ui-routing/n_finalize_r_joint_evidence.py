from pathlib import Path
import hashlib, json, re

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/hq-ui-routing'
names = ['N-R-actual-producer-initial-compile.log', 'N-R-actual-producer-second-compile.log',
    'N-R-actual-producer-initial-owner-fixture.log', 'N-R-actual-producer-focused.log', 'N-R-actual-producer-joint-full.log']
logs = []
for name in names:
    raw = (OUT / name).read_bytes(); text = raw.decode('utf-8-sig', errors='replace')
    rows = re.findall(r'Executed (\d+) tests?, with (\d+) failures?', text)
    methods = re.findall(r"Test Case '([^']+)' passed", text)
    logs.append({'file': name, 'sha256': hashlib.sha256(raw).hexdigest(),
        'xctest_final': {'methods': int(rows[-1][0]), 'failures': int(rows[-1][1])} if rows else None,
        'passed_method_names': methods, 'compiler_warnings': text.count('warning:'),
        'scope': 'Draft N fixture error; not a product result' if name in names[:3] else 'Executed portable tests'})
assert logs[-2]['xctest_final'] == {'methods': 6, 'failures': 0}
assert logs[-1]['xctest_final'] == {'methods': 93, 'failures': 0}
assert logs[-1]['compiler_warnings'] == 0
consumer = [x for x in logs[-1]['passed_method_names'] if x.startswith('NRActualProducerConsumerTests.')]
assert len(consumer) == 7
manifest = (OUT / 'N-R-actual-producer-inputs.json').read_bytes()
report = {'status': 'JOINT_PORTABLE_ACTUAL_PRODUCER_CONSUMPTION_PASS_NATIVE_HOLD',
    'N_P_joint': '98e6c7b94fd5e4c06b83cdda57cd6c9d9f41db6e',
    'N_fix': 'd9310293444c6fe9b49739c83d5b2d145960b3c0',
    'P_core': '050031fac1bb21f738048beb8b5d011d5d0a6b4d',
    'R_producer': '44f518fcccce6bd20127f39eea8462d7a7a9dd47',
    'input_manifest_sha256': hashlib.sha256(manifest).hexdigest(), 'logs': logs,
    'count_interpretation': 'Final93 = original84 Host + separate2 P review + new7 N actual-R consumer methods. Focused6 are an earlier subset/draft; do not sum.',
    'consumer_methods': consumer, 'R_original_test_counts_reexecuted': False,
    'actual_native_manager_setters': 'EXPLICIT_PROPOSED_HOOK_BOUNDARY_DOUBLE',
    'actual_R_store_policy_models_persistence': True, 'exact_actual_R_adapter_producer_body': True,
    'production_observer_activated': False, 'upstream_hook_applied': False, 'new_native_sdk_device_run': 'NOT_RUN',
    'v2_content_newTab_reservation': 'NOT_ENABLED', 'manager_independent_source_review': 'PENDING'}
(OUT / 'N-R-actual-producer-report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print('Final93/0/0 = Host84 + separateP2 + independentactualR7; actual native remains NOT_RUN.')
pair_raw = (OUT / 'N-v1-fca-P9f-pair-host.log').read_bytes()
pair_text = pair_raw.decode('utf-8-sig', errors='replace')
pair_rows = re.findall(r'Executed (\d+) tests?, with (\d+) failures?', pair_text)
assert pair_rows[-1] == ('58', '0') and 'warning:' not in pair_text
pair = {'status': 'MINIMAL_CURRENT_V1_N_P_PAIR_PORTABLE_PASS',
    'base': 'fca92176d48017ee0cd22831a1ae31f40958eed9',
    'P_current_v1': '9fadde58093d352fa2fa8b7cc18d07904382e880',
    'P_core_blob': 'fbe9db5962dde66685d272231d77e6257640ae54',
    'N_production_patch': 'N_V1_FCA_POST_GUARD_DRIVER_TOKEN_UNAPPLIED.diff',
    'N_test_patch': 'N_V1_FCA_REGRESSION_UNAPPLIED.diff',
    'combined_input_manifest_sha256': hashlib.sha256((OUT / 'N-v1-fca-P9f-pair-inputs.json').read_bytes()).hexdigest(),
    'actual_host_methods': 58, 'failures': 0, 'compiler_warnings': 0,
    'raw_log': 'N-v1-fca-P9f-pair-host.log', 'raw_log_sha256': hashlib.sha256(pair_raw).hexdigest(),
    'future_preparation_v2_dependencies': False, 'actual_native_sdk_device': 'NOT_RUN',
    'P_UI62_reexecuted_by_N': False, 'manager_application': 'Manager reports original-blob/check/apply of N exact v1 patches; N did not mutate manager branch'}
(OUT / 'N-v1-fca-P9f-pair-report.json').write_text(json.dumps(pair, indent=2) + '\n', encoding='utf-8')
print('Independent compatible minimal current-v1 N/P pair58/0/0, separate from future93.')
