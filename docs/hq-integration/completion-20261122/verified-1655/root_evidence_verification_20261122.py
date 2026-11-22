"""Read retained evidence only. Does not execute product tests or download artifacts."""
import base64
import collections
import hashlib
import json
import pathlib
import re
import zipfile
from datetime import datetime, timezone

ROOT = pathlib.Path(__file__).resolve().parent
def sha(data):
    return hashlib.sha256(data).hexdigest()
def read(path):
    return json.loads(path.read_text(encoding='utf-8'))
def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
def indexed_payloads(folder):
    index = read(folder / 'EVIDENCE_INDEX.json')['files']
    for item in index:
        data = (folder / item['path']).read_bytes()
        assert len(data) == item['bytes'] and sha(data) == item['sha256'], item['path']
    commands = read(folder / 'COMMANDS.json')
    for command in commands:
        for stream in ('stdout', 'stderr'):
            assert sha((folder / command[stream]).read_bytes()) == command[stream + '_sha256']
        assert command['status'] == 'TERMINAL' and not command['timed_out']
        assert any(x.get('drained') for x in command['cleanup'])
    return index, commands

now = datetime.now(timezone.utc).isoformat()
sdk = ROOT / 'sdk_run_45041382512/evidence'
compact = sdk / 'compact-terminal-evidence.zip'
with zipfile.ZipFile(compact) as z:
    assert z.testzip() is None
    members = [x for x in z.infolist() if not x.is_dir()]
    assert len(members) == 38
    for item in members:
        assert (sdk / item.filename).read_bytes() == z.read(item)
controls = read(sdk / 'source-controls-result.json')
assert controls['tests_run'] == controls['expected_count'] == 245
ids = controls['expected_ids']
assert len(ids) == len(set(ids)) == 245
for key in ('started_ids', 'passed_ids', 'discovered_ids'):
    assert collections.Counter(controls[key]) == collections.Counter(ids)
for key in ('errors', 'failures', 'skipped', 'expected_failures', 'unexpected_successes'):
    assert not controls[key]
assert sha((sdk / 'source-controls-result.json').read_bytes()) == '67ef0aeb21ad307f0e396192106c2043998e66941613e5e953df61c5cae42ed5'
assert (sdk / 'source-before.json').read_bytes() == (sdk / 'source-after.json').read_bytes()
public = read(sdk / 'actual-public-surface.json')
assert public['reviewed_host_and_spi_requirements_observed'] == 38
assert public['public_host_scope_verified'] and public['qualification_spi_scope_verified']
assert not public['public_original_editor_or_writer_declarations']
clang = read(sdk / 'clang-declaration-export.json')
assert sha((sdk / 'clang-declaration-export.json').read_bytes()) == 'a579907fcccffaf59bbacb6ee236b19961f31f1d937ca6c5da57d6a9b9f3a840'
assert len(clang['files']) == 1394 and len(clang['module_maps']) == len(clang['header_search_paths']) == 19
assert collections.Counter(x['transformation'] for x in clang['module_map_provenance']) == {'EXACT_DECLARATION_PATH_RELOCATION': 13, 'EXACT_ORIGINAL_TRACKED_BYTES': 6}
distribution = read(sdk / 'framework-distribution.json')
assert len(distribution['files']) == 2528
assert sum(v['bytes'] for v in distribution['files'].values()) == distribution['bytes'] == 1258249614
for name in ('framework-build', 'external-consumer-build', 'external-consumer-signature', 'boot-owned-simulator', 'boot-status'):
    command = read(sdk / (name + '.command.json'))
    assert command['returncode'] == 0 and not command['timed_out']
install = read(sdk / 'install-external-consumer.command.json')
assert install['timed_out'] and install['timeout_seconds'] == 60 and install['returncode'] == -15
execution = read(sdk / 'execution.json')
assert execution['source_sha'] == 'edce5b975b173059522f90adb71271fb95adf963'
assert int(execution['run_id']) == 45041382512 and int(execution['run_attempt']) == 1
assert execution['status'] == 'FAIL' and not execution['verified_runtime_observations']
cleanup = read(sdk / 'owned-simulator-cleanup.json')
assert all(x['returncode'] == 0 for x in cleanup if x['operation'] == 'delete')
sdk_receipt = {'schema': 'otzaria.root-sdk-v13-evidence-review/1', 'verified_at': now,
    'run': 45041382512, 'source': execution['source_sha'],
    'compact_archive_sha256': sha(compact.read_bytes()), 'compact_members_exact': 38,
    'full_archive_independent_host_verification_job': 'job_02954cf5f125',
    'full_archive_sha256': 'a6f21a226f4cdedd60d674551c3ca3af0125f646be0d73c5ebf06d0b73f20409',
    'full_archive_bytes': 15563205, 'full_archive_members': 571,
    'source_controls_pass': 245, 'public_spi_requirements_pass': 38,
    'clang_files': 1394, 'module_maps': 19, 'header_roots': 19,
    'framework_build': 'PASS', 'external_consumer_compile_link_and_signature': 'PASS',
    'owned_simulator_boot': 'PASS', 'install': 'TIMEOUT_60_SECONDS',
    'runtime_observations': 0, 'qualified_sdk': False,
    'new_product_tests': 0, 'new_github_artifact_downloads': 0}
save(sdk / 'ROOT_EVIDENCE_REVIEW.json', sdk_receipt)

heart_root = ROOT / 'heart_completion/schema_registration'
heart = heart_root / 'extracted_diagnostic'
archive = heart_root / 'Heart_Schema_Missing_Attachment_45042110729.zip'
assert sha(archive.read_bytes()) == '270b824b9c0210cd1cd584db0315215678bfa04c29c4251692527c57e403fd6e'
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    for item in z.infolist():
        if not item.is_dir():
            assert (heart / item.filename).read_bytes() == z.read(item), item.filename
index, commands = indexed_payloads(heart)
assert len(index) == 48 and len(commands) == 18
assert all(x['returncode'] == 0 for x in commands[:-1]) and commands[-1]['returncode'] == 1
native = read(heart / 'RESULT.json')['tests']['native']
assert native['compiled'] and native['execution_started'] and not native['pass'] and not native['unexpected']
case = 'TestOtzariaAnnotationSchemaRegistration/MissingAttachmentUsesOneNativeApply'
assert native['started'] == ['TestOtzariaAnnotationSchemaRegistration', case]
assert native['terminal'][case] == 'fail'
pairs = []
for file in sorted(heart.glob('missing-attachment-*.json')):
    pair = read(file)
    assert pair['diagnostic_only'] and pair['details_equal'] and not pair['blocks_equal']
    assert pair['different_block_ids'] == ['dataview'] and not pair['different_detail_keys']
    left, right = pair['live'], pair['persisted']
    assert left['heads'] == right['heads']
    assert left['details_json'] == right['details_json']
    # Proto Equal is observed in the native diagnostic; retain full wire hashes separately.
    blocks_l = {b['id']: b for b in left['blocks']}
    blocks_r = {b['id']: b for b in right['blocks']}
    assert blocks_l.keys() == blocks_r.keys()
    for block_id, l in blocks_l.items():
        r = blocks_r[block_id]
        lb, rb = base64.b64decode(l['protobuf']), base64.b64decode(r['protobuf'])
        assert sha(lb) == l['sha256'] and sha(rb) == r['sha256']
        if block_id != 'dataview':
            assert lb == rb and l['json'] == r['json']
        else:
            lj, rj = dict(l['json']), dict(r['json'])
            assert lj.pop('restrictions') == {} and 'restrictions' not in rj
            assert lj == rj and lb[:10] == rb[:10]
            assert lb[10:12] == b'\x1a\x00' and lb[12:] == rb[10:]
    pairs.append({'stage': pair['stage'], 'only_difference': 'top-level Restrictions nil versus empty message',
        'wire_difference': 'loaded has 1a00 at byte offset 10', 'all_other_complete_block_bytes_identical': True})
assert len(pairs) == 6
semantic = heart_root / 'semantic_fix_v1'
for item in read(semantic / 'SOURCE_INDEX.json'):
    data = (semantic / item['path']).read_bytes()
    assert len(data) == item['bytes'] and sha(data) == item['sha256']
    assert hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest() == item['gitblob']
test = (semantic / 'native/core/pinkha/annotationschema/native_block_semantics_test.go').read_text()
first = read(heart / 'missing-attachment-00-registered.json')
for name, side in [('recordedLoadedBlock','live'), ('recordedPersistedBlock','persisted')]:
    encoded = re.search(r'const '+name+r' = "([^"]+)"', test).group(1)
    original = next(b for b in first[side]['blocks'] if b['id'] == 'dataview')
    assert encoded == original['protobuf']
heart_receipt = {'schema':'otzaria.root-missing-attachment-diagnostic-review/1','verified_at':now,
    'run':45042110729,'archive_sha256':sha(archive.read_bytes()),'indexed_payloads_verified':48,
    'command_streams_verified':18,'actual_selected_child':'FAIL','prior_passing_cases_reexecuted':0,
    'pairs':pairs,'semantic_fix_complete_source_hashes_verified':True,'two_recorded_test_fixtures_exact':True,
    'source_review':'Only nil top-level restrictions defaulted on full deep copies, followed by full proto.Equal. Other fields and nonzero restrictions remain compared.',
    'new_semantic_controls_executed':False,'new_github_artifact_downloads':0}
save(heart_root / 'ROOT_DIAGNOSTIC_AND_SEMANTIC_SOURCE_REVIEW.json',heart_receipt)

import_root = ROOT / 'native-import-compile/evidence/run-45044056210'
imp = import_root / 'downloaded-evidence'
index, commands = indexed_payloads(imp)
result = read(imp / 'RESULT.json')
assert len(index) == 28 and len(commands) == 11
assert len([p for p in imp.rglob('*') if p.is_file()]) == 29  # index itself is not self-hashed
assert all(x['returncode'] == 0 for x in commands[:-1])
assert commands[-1]['label'] == 'compile-original-importer' and commands[-1]['returncode'] == 1
assert 'test' in commands[-1]['argv'] and '-c' in commands[-1]['argv']
stderr = (imp / commands[-1]['stderr']).read_bytes()
assert sha(stderr) == 'ef96f2cc5e6b746110f056cfc54b702cd3381abc329bee236301d1653ac57cda'
assert stderr.count(b'too few values in struct literal of type ImportRequest') == 10
assert result['tests_executed'] == result['native_imports_executed'] == 0 and not result['test_binary_executed']
assert result['prior_unit_cases_not_replayed'] == 50 and result['owned_compiler_temp_removed']
assert sha((imp / 'RESULT.json').read_bytes()) == 'd77a84669d85033b37023df83c18ddc7fc3310e1cda9b0953a051d5e6b43baf8'
import_receipt = {'schema':'otzaria.root-original-importer-compile-review/1','verified_at':now,
    'run':45044056210,'head':result['control_head'],'indexed_payloads_verified':28,'retained_files_including_index':29,'command_streams_verified':11,
    'source_setup_gofmt_tantivy_dependency_capture':'PASS','compile':'FAIL',
    'actual_cause':'Original positional ImportRequest literals no longer match the changed public struct layout',
    'compiler_stderr_sha256':sha(stderr),'actual_reported_source_errors':10,'tests_executed':0,
    'native_imports_executed':0,'prior_unit_cases_preserved':50,'new_github_artifact_downloads':0}
save(import_root / 'ROOT_COMPILE_FAILURE_REVIEW.json',import_receipt)
print(json.dumps({'sdk':sdk_receipt,'heart':heart_receipt,'importer':import_receipt},ensure_ascii=False,indent=2))
