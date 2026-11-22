import collections
import datetime
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
NOW = datetime.datetime.now(datetime.timezone.utc).isoformat()

def read(path):
    return json.loads(path.read_bytes())

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

# Review existing evidence only. No test runner, compiler, network or subprocess.
schema = ROOT / 'stageb-schema2'
result = read(schema / 'evidence/controls-v1/RESULT.json')
assert sha(schema / 'evidence/controls-v1/RESULT.json') == '36f385fcf538aedf38df55ee97bf4fbe0b4af93ee88c9ab3cad0b2cb89ca025d'
assert result['tests_run'] == 20 and result['status'] == 'PASS_20_NEW_SCHEMA2_ADMISSION_BOUNDARIES'
for key in ['expected_ids', 'started_ids', 'passed_ids']:
    assert len(result[key]) == len(set(result[key])) == 20
    assert set(result[key]) == set(result['expected_ids'])
assert not result['failures'] and not result['errors'] and not result['skipped']
assert result['framework_builds'] == result['simulator_attempts'] == result['prior_controls_replayed'] == 0
assert result['source_inputs'] == read(schema / 'evidence/controls-v1/SOURCE_INPUTS.json')
for row in result['source_inputs']:
    path = schema / row['path']
    assert path.stat().st_size == row['bytes'] and sha(path) == row['sha256']
command_root = schema / 'evidence/controls-v1-command'
command = read(command_root / 'COMMAND.json')
assert command['exit_code'] == 0 and command['automatic_retries'] == 0
for stream in command['streams']:
    path = command_root / stream['path']
    assert path.stat().st_size == stream['bytes'] and sha(path) == stream['sha256']
raw = (command_root / 'stderr.log').read_text()
assert raw.count(' ... ok\n') == 20 and 'Ran 20 tests' in raw and raw.rstrip().endswith('OK')
schema_review = {
    'schema': 'otzaria.root-stageb-schema2-reviewed-scope/1', 'at_utc': NOW,
    'source_commit': 'b09c95f3eee6aa3b8fe363cfac76a89025c15abe',
    'reviewed_complete_four_file_diff': True, 'reviewed_complete_new_helper': True,
    'reviewed_all_twenty_control_bodies': True, 'retained_actual_controls_passed': 20,
    'source_input_hashes_verified': len(result['source_inputs']),
    'source_files': read(schema / 'candidate/SOURCE_MANIFEST.json'),
    'scope': 'Strict original failed framework role and separately successful runtime role; authenticated artifacts/upload windows, exact two original dotfiles, unchanged full product inventory and separate immutable qualification sidecar.',
    'remaining_integration_dependencies': [
        'The upstream toolchain selector still admits only schema1; StageB agent preparing a narrow schema2 branch.',
        'The app consumer needs the authentic 19 Clang module maps and 19 header roots; Clang agent preparing a schema2-only integration.',
        'Actual successful SDK runtime qualification and immutable artifact pins are still required.'
    ],
    'stageb_activation_authorized_by_this_review': False,
    'new_test_executions': 0, 'new_artifact_downloads': 0
}
save(schema / 'ROOT_SCHEMA2_SCOPE_REVIEW.json', schema_review)

native = ROOT / 'native450416/root-review'
visual = {
    'schema': 'otzaria.root-native450416-original-capture-review/1', 'at_utc': NOW,
    'run': 45041601629, 'viewed_original_pngs': [
        {'path': 'DEABA939-9527-4D58-B104-A7287DEEA8EF.png', 'sha256': sha(native / 'DEABA939-9527-4D58-B104-A7287DEEA8EF.png'),
         'observation': 'Reopened Study chat visibly shows Book search: ספר החינוך and End book access; message field is empty and send control disabled.'},
        {'path': '0D697DED-8AEA-436C-9583-7CEE9F53AAB8.png', 'sha256': sha(native / '0D697DED-8AEA-436C-9583-7CEE9F53AAB8.png'),
         'observation': 'Returned to the original Hebrew reader; the original selected text remains visible and chat sheet is dismissed.'}
    ],
    'ax_observation': 'Parent otzaria-hanlin-book-access is Other and nested End book access button independently has otzaria-hanlin-end-book-access.',
    'images_modified': False, 'test_reexecutions': 0,
    'scope': 'Visual corroboration of the original actual selected-case PASS; no full Native116 or Release114 claim.'
}
save(native / 'ROOT_VISUAL_REVIEW.json', visual)

import_root = ROOT / 'native-import-request-compat/evidence/run-45047489968'
evidence = import_root / 'retained/downloaded-evidence'
result = read(evidence / 'RESULT.json')
index = read(evidence / 'EVIDENCE_INDEX.json')['files']
assert len({row['path'] for row in index}) == len(index)
for row in index:
    path = evidence / row['path']
    assert path.is_file() and path.stat().st_size == row['bytes'] and sha(path) == row['sha256'], row['path']
assert {p.name for p in evidence.iterdir() if p.is_file()} == {x['path'] for x in index} | {'EVIDENCE_INDEX.json'}
commands = read(evidence / 'COMMANDS.json')
assert len(commands) == result['commands'] == 12
for command in commands:
    assert command['status'] == 'TERMINAL' and command['returncode'] == command['effective_returncode'] == 0
    assert command['timed_out'] is False and command['start_new_session'] is True
    assert command['cleanup'][-1]['drained'] is True
    for stream in ['stdout', 'stderr']:
        assert sha(evidence / command[stream]) == command[stream + '_sha256']
assert result['status'] == 'PASS_COMPILE_ONLY'
assert result['control_head'] == '32adc5c78db70a586a81c761de19efc46298bb06'
assert result['origin_commit'] == '13f63c2dff32ff8ca6b864748843822fcdd0d004'
assert result['execution_manifest_sha256'] == '7fbd330f47fe6651022e28d0d0e03ff139d13d19c0c68c6ef9d0fe9c0af68118'
assert result['tests_executed'] == result['native_imports_executed'] == 0 and result['test_binary_executed'] is False
assert result['prior_unit_cases_not_replayed'] == 50 and result['post_compile_input_recheck'] is True
assert result['owned_compiler_temp_removed'] is True
compile_command = next(x for x in commands if x['label'] == 'compile-original-importer')
assert compile_command['argv'] == result['compile_command'] and compile_command['argv'][1:3] == ['test', '-c']
assert compile_command['duration_seconds'] > 0
assert result['go']['version'] == (evidence / '01-go-version.stdout').read_text().strip() == 'go version go1.26.5 darwin/arm64'
assert sha(evidence / 'DECLARED_NATIVE_INPUTS.json') == result['declared_native_inputs_sha256']
declared = read(evidence / 'DECLARED_NATIVE_INPUTS.json')
assert len(declared['files']) == result['declared_native_input_count'] == 9821
assert (evidence / 'TANTIVY_INPUTS_BEFORE.json').read_bytes() == (evidence / 'TANTIVY_INPUTS_AFTER.json').read_bytes()
binary = result['compiled_binary']
assert binary['bytes'] == 118947778 and binary['sha256'] == 'e4248632b5bc641c57620cef5a8394dac57a19b4b8a206fb1ba246d1858b7d12' and not binary['executed']
assert len(result['gate_input_readback']) == len(result['origin_input_readback']) == 8
assert result['gofmt']['six_source_files_unchanged'] is True
stderr = (evidence / '11-compile-original-importer.stderr').read_text()
assert stderr.splitlines() == ['# github.com/anyproto/anytype-heart/core/block/import.test', "ld: warning: ignoring duplicate libraries: '-ldl', '-lm', '-ltantivy_go'"]
import_review = {
    'schema': 'otzaria.root-original-importer-compile-pass-review/1', 'at_utc': NOW,
    'run': 45047489968, 'head': result['control_head'], 'status': result['status'],
    'result_sha256': sha(evidence / 'RESULT.json'), 'indexed_payloads_verified': len(index),
    'actual_commands_and_streams_verified': 12, 'declared_native_inputs_committed': 9821,
    'actual_compile_and_link_seconds': compile_command['duration_seconds'],
    'go': result['go']['version'], 'xcode': (evidence / '02-xcode-version.stdout').read_text().strip(),
    'original_tantivy_inputs_unchanged': True, 'original_module_compatibility': 'PASS',
    'compiled_binary': binary, 'tests_executed': 0, 'imports_executed': 0,
    'prior_fifty_and_seven_control_replays': 0,
    'new_github_artifact_downloads': 0,
    'scope': 'Original module compile/link compatibility; runner-observed binary metadata. No native import, operation lifetime, mapping authority, persistence/readback or ACK acceptance.'
}
save(import_root / 'ROOT_COMPILE_PASS_REVIEW.json', import_review)
print(json.dumps({'schema_controls': 20, 'native_visual_captures': 2, 'importer': import_review}, ensure_ascii=False))
