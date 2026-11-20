"""Bounded metadata/inverse verification; no Apple or Native execution."""
from pathlib import Path
import ast
import hashlib
import json
import runpy
import shutil
import yaml

R = Path(__file__).resolve().parent
B, C, P = R / 'base', R / 'candidate', R / 'prior-route'
G = runpy.run_path(str(C / 'Scripts/CI/reader-inspector-focused-native.py'))
proof = json.loads((R / 'evidence/REBIND_PROOF.json').read_text())
canonical = json.loads((R / 'CANONICAL_INPUTS.json').read_text())
checks = []


def check(name, condition):
    checks.append({'name': name, 'passed': bool(condition)})
    if not condition:
        raise ValueError(name)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def blob(raw):
    return hashlib.sha1(b'blob ' + str(len(raw)).encode() + bytes([0]) + raw).hexdigest()


commit = json.loads((R / 'M_COMMIT.json').read_text())
check('actual_canonical_M_parent_and_tree', commit['sha'] == G['BASE'] == canonical['source']
      and commit['tree']['sha'] == canonical['source_tree']
      and [x['sha'] for x in commit['parents']] == ['0bee8efe2c368182d075100327bae9f24a80656d'])
source_records = []
for entry in canonical['entries']:
    if entry['type'] != 'blob':
        continue
    raw = (B / entry['path']).read_bytes()
    check('canonical_input:' + entry['path'], blob(raw) == entry['sha'] and len(raw) == entry['size'])
    source_records.append({'path': entry['path'], 'bytes': len(raw), 'git_blob': blob(raw), 'sha256': sha(raw)})

new = (C / G['SELF']).read_text()
for replacement in reversed(proof['driver_replacements']):
    check('unique_inverse:' + replacement['after'], new.count(replacement['after']) == 1)
    new = new.replace(replacement['after'], replacement['before'])
check('whole_original_driver_body_inverse', new.encode() == (P / G['SELF']).read_bytes())
check('all_original27_controls_exact', (C / G['TESTS']).read_bytes() == (P / G['TESTS']).read_bytes())
old_workflow = (P / '.github/workflows/otzaria-reader-inspector-focused-native.yml').read_text()
workflow = (C / G['WORKFLOW']).read_text()
check('whole_workflow_inverse_only_branch', workflow.replace('codex/otzaria-reader-inspector-focused-native-v2-20261120',
      'codex/otzaria-reader-inspector-focused-native-20261120') == old_workflow)
w = yaml.load(workflow, Loader=yaml.BaseLoader)
check('exact_push_authority', w['on'] == {'push': {'branches': [G['REF'].removeprefix('refs/heads/')]}})
check('read_only_permissions', w['permissions'] == {'contents': 'read', 'actions': 'read'})
job = w['jobs']['original-four']
check('original_runner_job_budget_and_no_cancellation', job['runs-on'] == 'xcode-27'
      and job['timeout-minutes'] == '360' and w['concurrency']['cancel-in-progress'] == 'false')
steps = {x.get('name'): x for x in job['steps'] if 'name' in x}
check('original_full_app_executor', steps['Execute original full app build and four unchanged native cases']['run'] ==
      'python3 Scripts/CI/runtime27.py')
check('always_actual_source_and_result', steps['Bind post-execution source and actual four-case results']['if'] == 'always()')
for name in ['Retain real runtime evidence including failure', 'Retain original native result bundles and visual captures separately']:
    check('always_capture:' + name, steps[name]['if'] == 'always()')
check('no_continue_on_error', all('continue-on-error' not in x for x in job['steps']))

G['validate_manifest'](json.loads((C / G['MANIFEST']).read_text()), json.loads((B / G['MANIFEST']).read_text()))
check('original116_rows_plus3_retained_and_same4_selected', True)
G['validate_pins'](json.loads((C / G['INPUTS']).read_text()), json.loads((B / G['INPUTS']).read_text()),
                   (C / G['ADDITIONS']).read_bytes(), (B / G['ADDITIONS']).read_bytes(),
                   (C / G['RUNTIME']).read_bytes(), (B / G['RUNTIME']).read_bytes())
check('current_R27_project_and_all_remaining_input_inverses', True)
matrix = (B / 'Scripts/CI/run-faithful-ipad-matrix.py').read_text()
check('original600_second_case_deadlines', '"-default-test-execution-time-allowance", "600"' in matrix
      and '"-maximum-test-execution-time-allowance", "600"' in matrix)
check('unchanged_original_declaration_parser_invocation', '"Scripts/CI/verify-faithful-xctest.py"' in matrix
      and '["swiftc", "-frontend", "-dump-parse", "-D", "DEBUG", str(source)]' in
      (B / 'Scripts/CI/verify-faithful-xctest.py').read_text())

# These names are proven by the actual previous producer receipts; the v2
# wrapper retains these exact strings and the same original writer/reader code.
old_result_root = R.parent / 'reader-focused4-44786439788-20261120/evidence'
receipts = old_result_root / 'artifacts/reader-inspector-focused-native'
for name in ['SOURCE_BEFORE.json', 'SOURCE_AFTER.json', 'RESULT_BEFORE.json', 'RESULT_AFTER.json']:
    check('actual_prior_receipt:' + name, (receipts / name).is_file())
check('same_before_after_filename_case', 'SOURCE_' in new and 'args.phase.upper()' in new
      and 'build/artifacts/reader-inspector-focused-native/SOURCE_BEFORE.json' in new)
check('same_runtime_and_build_report_names', 'build/artifacts/runtime27/result.json' in new
      and 'build/hq-stage2/result.json' in new and 'verified-11-reader.summary.json' in new
      and 'verified-11-reader.tests.json' in new)

for path in [G['SELF'], G['TESTS'], G['RUNTIME']]:
    ast.parse((C / path).read_text())
    check('python_syntax:' + path, True)
control_log = (R / 'evidence/attempt2/controls.stderr.log').read_text()
control_receipt = json.loads((R / 'evidence/attempt2/controls.json').read_text())
check('actual_original27_pass', control_receipt['returncode'] == 0
      and control_log.count(' ... ok\n') == 27 and 'Ran 27 tests' in control_log and control_log.rstrip().endswith('OK'))
result = {'status': 'SOURCE_INVERSES_AND27_PYTHON_CONTROLS_PASS', 'source': G['BASE'], 'checks': checks,
          'source_inputs': source_records, 'python_controls_passed': 27, 'python_control_failures': 0,
          'swiftc_path': shutil.which('swiftc'), 'original_swift_declaration_check': 'NOT_RUN_LOCALLY; unchanged original Swift frontend remains mandatory on actual CI',
          'local_full_Git_source_gate': 'NOT_RUN: authenticated source projection, not a replacement Git checkout',
          'actual_Apple_build': 'NOT_RUN', 'native_executed': 0, 'full_phase_credit': False}
(R / 'evidence/VALIDATION.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({k: result[k] for k in ['status', 'source', 'python_controls_passed', 'swiftc_path', 'native_executed']}, indent=2))
print('Verified source/preservation assertions:', len(checks))
