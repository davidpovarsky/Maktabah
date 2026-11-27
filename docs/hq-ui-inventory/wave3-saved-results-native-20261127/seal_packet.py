from pathlib import Path
import difflib
import hashlib
import json
import re
import shutil
import zipfile

R = Path(__file__).resolve().parent
D = R / 'packet/docs/hq-ui-inventory/wave3-saved-results-native-20261127'
D.mkdir(parents=True, exist_ok=False)
prefix = (R / 'baseline/Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift').read_bytes()
suffix = (R / 'proposal/NATIVE_HELPER_ADDITION.swift').read_bytes()
combined = (R / 'candidate/Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift').read_bytes()
selectors = (R / 'candidate/Maktabah-iOSUITests/NativeSavedResultsAcceptanceTests.swift').read_bytes()
assert len(prefix) == 337724 and hashlib.sha256(prefix).hexdigest() == '3bf29c5fc7f3a434d605b8962f2954ca8afdd5521f16ae0b3eea2d1315a1c58f'
assert combined == prefix + suffix
old_names = set(re.findall(rb'\bfunc\s+(\w+)\s*\(', prefix))
new_names = set(re.findall(rb'\bfunc\s+(\w+)\s*\(', suffix))
assert not old_names & new_names
test_names = re.findall(rb'\bfunc\s+(test\w+)\s*\(', selectors)
assert len(test_names) == len(set(test_names)) == 6
assert not set(test_names) & old_names
for expression in [rb'\.perform\s*\(', rb'\.makeReference\s*\(', rb'service\.reveal\s*\(', rb'openInExistingProcess\s*\(']:
    assert not re.search(expression, suffix)
assert suffix.count(b'sqlite3_open_v2(') == 1
assert b'SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX' in suffix
for sql in [b'CREATE TABLE', b'INSERT INTO', b'UPDATE results', b'DELETE FROM', b'SQLITE_OPEN_READWRITE']:
    assert sql not in suffix
join = json.loads((R / 'DEPENDENCY_CURRENT_GIT_JOIN.json').read_text())
assert join['ref'] == '37caafcfaa4eb9b7bcfd02857bcb7c3f62daa4be' and all(x['matches_read_input'] for x in join['files'])
archive_receipt = json.loads((R / 'evidence/RAW_ARCHIVE_RECEIPT.json').read_text())
archive = (R / 'evidence/SOURCE_CONTROLS_ATTEMPT_1.zip').read_bytes()
assert len(archive) == archive_receipt['bytes'] and hashlib.sha256(archive).hexdigest() == archive_receipt['sha256']
with zipfile.ZipFile(R / 'evidence/SOURCE_CONTROLS_ATTEMPT_1.zip') as z:
    assert len(z.namelist()) == len(archive_receipt['files']) + 1 == 23
    for path in ['candidate/Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift', 'candidate/Maktabah-iOSUITests/NativeSavedResultsAcceptanceTests.swift', 'proposal/NATIVE_HELPER_ADDITION.swift']:
        assert z.read('inputs/' + path) == (R / path).read_bytes()
    result_bytes = z.read('RESULT.json')
    assert hashlib.sha256(result_bytes).hexdigest() == '9dd3bef6c6e4481bbf36b9c6a4f0f4a0fbc2db85643035d04bb59f18dd735c8e'
    result = json.loads(result_bytes)
    assert result['oracle_controls']['passed'] == 10 and result['oracle_controls']['failed'] == 0
    assert len(result['commands']) == 4 and all(x['exit_code'] == 0 for x in result['commands'])
inputs = json.loads((R / 'DEPENDENCY_READ_INPUTS.json').read_text())
sources = []
for item in inputs:
    p = R.parent / item['local']
    b = p.read_bytes()
    assert len(b) == item['bytes'] and hashlib.sha256(b).hexdigest() == item['sha256']
    # Preserve the referenced original behavior without copying both large
    # existing test files again; their exact full bytes remain in Git and the
    # source join. The native prefix is preserved in the raw control archive.
    if item['path'].startswith('Source/'):
        target = D / 'original-source' / item['path']
        target.parent.mkdir(parents=True, exist_ok=True); target.write_bytes(b)
    sources.append({k: item[k] for k in ['path', 'bytes', 'sha256']})
copies = [
    ('README.delivery.md', 'README.md'),
    ('proposal/NATIVE_HELPER_ADDITION.swift', 'NATIVE_HELPER_ADDITION.swift'),
    ('DEPENDENCY_CURRENT_GIT_JOIN.json', 'DEPENDENCY_CURRENT_GIT_JOIN.json'),
    ('BASELINE.json', 'BASELINE_INITIAL_READ.json'),
    ('controls/OriginalSQLiteOracleControls.swift', 'controls/OriginalSQLiteOracleControls.swift'),
    ('controls/SOURCE_EXTRACT.json', 'controls/SOURCE_EXTRACT.json'),
    ('build_oracle_controls.py', 'controls/build_oracle_controls.py'),
    ('run_source_controls.py', 'controls/run_source_controls.template.py'),
    ('evidence/EXECUTED_SOURCE_CONTROLLER.py', 'controls/EXECUTED_SOURCE_CONTROLLER.py'),
    ('evidence/RESULT.remote-original.json', 'controls/RESULT.json'),
    ('evidence/CONTROL_JOB.json', 'controls/CONTROL_JOB.json'),
    ('evidence/SOURCE_CONTROLS_ATTEMPT_1.zip', 'controls/SOURCE_CONTROLS_ATTEMPT_1.zip'),
    ('evidence/RAW_ARCHIVE_RECEIPT.json', 'controls/RAW_ARCHIVE_RECEIPT.json'),
    ('evidence/INITIAL_BACK_DELETE_DRAFT.swift', 'review/INITIAL_BACK_DELETE_DRAFT.swift'),
    ('evidence/DELETION_SETUP_REVIEW.json', 'review/DELETION_SETUP_REVIEW.json'),
    ('evidence/READ_TRANSPORT_ATTEMPT_1.json', 'review/READ_TRANSPORT_ATTEMPT_1.json'),
]
for src, dst in copies:
    p = D / dst; p.parent.mkdir(parents=True, exist_ok=True); p.write_bytes((R / src).read_bytes())
transfer = json.loads((R / 'evidence/ARCHIVE_TRANSFER_CHUNKS.json').read_text())
for row in transfer: row.pop('base64')
(D / 'controls/VERIFIED_TRANSFER.json').write_text(json.dumps({'archive_sha256': archive_receipt['sha256'], 'chunks': transfer,
    'verified_raw_members': 22, 'verified_total_members': 23, 'native': 'NOT_RUN'}, indent=2) + '\n')
patch = ''.join(difflib.unified_diff(prefix.decode().splitlines(True), combined.decode().splitlines(True),
    fromfile='a/Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift', tofile='b/Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift'))
(D / 'NATIVE_HELPER_ADDITION.patch').write_text(patch)
proof = {'schema': 'otzaria.saved-results.native-source-packet.v1',
    'base': join['ref'], 'original_prefix': {'bytes': len(prefix), 'sha256': hashlib.sha256(prefix).hexdigest()},
    'unchanged_original_prefix': True, 'helper_collisions': [],
    'new_test_declarations': [x.decode() for x in test_names], 'native_selected_or_passed_count': None,
    'source_control_boundary': {'actual_sqlite_oracle': {'passed': 10, 'failed': 0}, 'frontend_syntax': 2,
        'apple_sdk_typecheck': 'NOT_RUN', 'native': 'NOT_RUN'},
    'product_files_changed': [], 'test_files': [
        {'path': p, 'bytes': len(b), 'sha256': hashlib.sha256(b).hexdigest()}
        for p, b in [('Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift', combined),
                     ('Maktabah-iOSUITests/NativeSavedResultsAcceptanceTests.swift', selectors)]],
    'helper_suffix': {'bytes': len(suffix), 'sha256': hashlib.sha256(suffix).hexdigest()},
    'membership': {'kind': 'inherited synchronized root group', 'target': 'F30578012FA46222005732C6',
        'group': 'F30578032FA46222005732C6', 'manual_pbx_change': False, 'apple_discovery': 'NOT_RUN'},
    'limitations': ['warm mounted tree only', 'miniTest10 only', 'no cold cached node', 'no cross-root Saved route',
        'no execute-saved-search journey', 'no new selected-item log field', 'no production or physical acceptance',
        'original GLOBAL_SEARCH_TEST_QUERY required; no fallback', 'English UI with actual original query']}
(D / 'SOURCE_PACKET.json').write_text(json.dumps(proof, indent=2) + '\n')
(D / 'SOURCE_DEPENDENCIES.json').write_text(json.dumps(sources, indent=2) + '\n')
shutil.copyfile(__file__, D / 'seal_packet.py')
manifest = []
for p in sorted(D.rglob('*')):
    if p.is_file():
        b = p.read_bytes(); manifest.append({'path': str(p.relative_to(D)), 'bytes': len(b), 'sha256': hashlib.sha256(b).hexdigest()})
(D / 'MANIFEST.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(json.dumps({'docs': str(D), 'files_excluding_manifest': len(manifest), 'manifest_sha256': hashlib.sha256((D/'MANIFEST.json').read_bytes()).hexdigest(), 'source_packet': proof}))
