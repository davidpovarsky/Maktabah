#!/usr/bin/env python3
"""One real full-helper serialization experiment: failure, repair, adverse rollback.

Authentic generated project and actual Xcodeproj 1.28.1. No SDK framework, shell
embed phase, compiler or simulator is executed. Existing token/context controls
are not rerun. The injected nonselected setting change exists only in this test.
"""
import datetime
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent.parent
BASE = ROOT.parent
TERMINAL = BASE / '45167025321/terminal'
RESULTS = ROOT / 'control-results'
RESULTS.mkdir(exist_ok=False)
SOURCE = ROOT / 'source'
GEMS = ROOT / 'portable-gems'
INSTALL = json.loads((GEMS / 'RUNTIME_INSTALL.json').read_text())
assert json.loads((GEMS / 'RUNTIME_INSTALL_ATTEMPT2.json').read_text())['status'] == 'INSTALLED'
RUBY = GEMS / 'runtime-root/usr/bin/ruby3.2'
PROJECT = TERMINAL / 'review/generated-Maktabah-project.pbxproj'
PLAN = TERMINAL / 'review/app-target-plan.json'
DIAGNOSIS = json.loads((TERMINAL / 'review/SETTINGS_SERIALIZATION_DIAGNOSIS.json').read_text())
TARGET = DIAGNOSIS['target_uuid']
CONFIG = DIAGNOSIS['configuration_uuid']
EXPECTED = DIAGNOSIS['expected_settings']
KEYS = ['OTHER_SWIFT_FLAGS', 'SWIFT_INCLUDE_PATHS']
EXPECTED_TOKENS = {key: EXPECTED[key] for key in KEYS}
CANONICAL = dict(EXPECTED)
for key in KEYS:
    CANONICAL[key] = ' '.join(EXPECTED[key])
SPEC = importlib.util.spec_from_file_location('original_pbx_source', SOURCE / 'original_pbx_source.py')
PBX = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PBX)
ASSERTIONS = []
COMMANDS = []
CASES = []

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def check(condition, label):
    if not condition:
        raise AssertionError(label)
    ASSERTIONS.append(label)

def read_project(path):
    return PBX.loads(path.read_text())

def unchanged_objects(before, after, label):
    old, new = before['objects'], after['objects']
    ids = [key for key in old if key not in [TARGET, CONFIG]]
    check(len(ids) == 2358, label + ': original unrelated object count')
    check(all(new.get(key) == old[key] for key in ids), label + ': every unrelated object exact')
    check({k: v for k, v in before.items() if k != 'objects'} == {k: v for k, v in after.items() if k != 'objects'}, label + ': original project metadata exact')
    phases = set(new) - set(old)
    check(len(phases) == 1 and set(old) <= set(new), label + ': exactly one new phase object')
    phase = next(iter(phases))
    check(new[TARGET]['buildPhases'] == old[TARGET]['buildPhases'] + [phase], label + ': phase appended after original phases')
    check({k: v for k, v in old[TARGET].items() if k != 'buildPhases'} == {k: v for k, v in new[TARGET].items() if k != 'buildPhases'}, label + ': original target identity and dependencies exact')
    check({k: v for k, v in old[CONFIG].items() if k != 'buildSettings'} == {k: v for k, v in new[CONFIG].items() if k != 'buildSettings'}, label + ': original config identity exact')
    return phase

def execute(label, helper, fault=False):
    folder = RESULTS / label
    project = folder / 'Maktabah.xcodeproj/project.pbxproj'
    project.parent.mkdir(parents=True)
    project.write_bytes(PROJECT.read_bytes())
    receipt = folder / 'helper-receipt.json'
    gem_receipt = folder / 'actual-gems.json'
    env = os.environ.copy()
    env.pop('RUBYOPT', None)
    env.update(INSTALL['environment'])
    env['OTZARIA_HELPER_GEM_RECEIPT'] = str(gem_receipt)
    env['OTZARIA_FIRST_SAVE'] = str(folder / 'first-actual-save.pbxproj')
    args = [str(RUBY), '-r', str(ROOT / 'controls/pin_actual_gems.rb')]
    if fault:
        args += ['-r', str(ROOT / 'controls/inject_post_save_corruption.rb')]
    args += [str(helper), str(project), str(PLAN), str(receipt)]
    out, err = folder / 'command.stdout', folder / 'command.stderr'
    started = time.monotonic()
    timed = False
    with out.open('wb') as stdout, err.open('wb') as stderr:
        process = subprocess.Popen(args, cwd=folder, env=env, stdout=stdout, stderr=stderr, start_new_session=True)
        try:
            code = process.wait(timeout=45)
        except subprocess.TimeoutExpired:
            timed = True
            os.killpg(process.pid, signal.SIGTERM)
            try:
                code = process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                code = process.wait(timeout=5)
    try:
        os.killpg(process.pid, 0)
        drained = False
    except ProcessLookupError:
        drained = True
    command = {'case': label, 'argv': args, 'exit': code, 'timed_out': timed,
               'child_reaped': process.poll() is not None, 'owned_group_drained': drained,
               'elapsed_seconds': time.monotonic() - started,
               'stdout': {'path': str(out.relative_to(ROOT)), 'size': out.stat().st_size, 'sha256': digest(out)},
               'stderr': {'path': str(err.relative_to(ROOT)), 'size': err.stat().st_size, 'sha256': digest(err)}}
    COMMANDS.append(command)
    (folder / 'COMMAND.json').write_text(json.dumps(command, indent=2) + '\n')
    check(not timed and drained and process.poll() is not None, label + ': bounded command reaped and drained')
    actual_gems = json.loads(gem_receipt.read_text())
    expected_gems = {row['name']: row['version'] for row in json.loads((GEMS / 'PACKAGES_INTAKE.json').read_text())['packages']}
    check({row['name']: row['version'] for row in actual_gems['gems']} == expected_gems, label + ': all nine actual exact gem versions')
    check(actual_gems['ruby_sha256'] == 'bbea1a842298c961c1ad29d359f2b45eff1b25ae546d59e72590846c039efac2' and actual_gems['xcodeproj_version'] == '1.28.1', label + ': retained actual Ruby and Xcodeproj identity')
    return folder, project, receipt, code, err.read_text()

result = {'scope': 'One full genuine-Xcodeproj serialization experiment with three leaves; no Apple compiler, SDK binary, embed, simulator or UI claim',
          'started_at': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'status': 'FAIL',
          'baseline_source': 'fa816b14d25a4ced0031b1a9c972040b89cb451e',
          'old_controls': 'Previously accepted flag/context controls retained by exact source correspondence, not rerun'}
try:
    check(digest(PROJECT) == 'fcac6c6d17d98edf2b34712efaae5a52e5c8e3c84a3fc1fd038cfe4a9335245c', 'Authentic original generated PBX fixture')
    check(digest(SOURCE / 'hq-original-editor-app-target.before.rb') == '92a591a8b02fb1e789cdc95febcbd760451584749f4708fa723297f5c34b898a', 'Exact failed source helper')
    check(digest(SOURCE / 'hq-original-editor-app-target.after.rb') == 'ada86a8a7e4bf3f38abf7366614a341183cedaf80d1febc41f45717249ca291e', 'Exact proposed candidate helper')
    before = read_project(PROJECT)
    folder, project, receipt, code, stderr = execute('original_failure_and_rollback', SOURCE / 'hq-original-editor-app-target.before.rb')
    check(code != 0 and 'SDK app settings were not retained exactly' in stderr, 'Original actual helper reproduces precise serialization refusal')
    check(not receipt.exists() and project.read_bytes() == PROJECT.read_bytes(), 'Original failure leaves no success receipt and exact original rollback')
    rejected = read_project(Path(str(receipt) + '.rejected-project.pbxproj'))
    unchanged_objects(before, rejected, 'original rejected project')
    check(rejected['objects'][CONFIG]['buildSettings'] == CANONICAL, 'Original failure differs only by the two exact serialized settings')
    CASES.append({'name': 'original_failure_and_rollback', 'status': 'PASS'})
    folder, project, receipt, code, stderr = execute('candidate_roundtrip', SOURCE / 'hq-original-editor-app-target.after.rb')
    check(code == 0 and receipt.is_file(), 'Candidate actual helper succeeds')
    saved = read_project(project)
    phase = unchanged_objects(before, saved, 'candidate saved project')
    actual = json.loads(receipt.read_text())
    check(actual['status'] == 'APP_TARGET_ONLY_CONFIGURED', 'Candidate original status retained')
    check(actual['serialized_array_setting_tokens'] == EXPECTED_TOKENS, 'Both original ordered arrays retained completely')
    check(actual['app_build_settings'] == CANONICAL and saved['objects'][CONFIG]['buildSettings'] == CANONICAL, 'Every selected and nonselected saved setting exactly equals expected canonical full hash')
    check({k: v for k, v in actual['app_build_settings'].items() if k not in KEYS} == {k: v for k, v in EXPECTED.items() if k not in KEYS}, 'All nonselected expected settings unchanged')
    check(actual['original_build_settings'] == before['objects'][CONFIG]['buildSettings'], 'Original complete settings retained')
    check(actual['before_project_sha256'] == digest(PROJECT) and actual['after_project_sha256'] == digest(project), 'Actual before/after bytes bound in helper receipt')
    check(actual['phase_uuid'] == phase, 'Actual saved phase identity bound')
    CASES.append({'name': 'candidate_roundtrip', 'status': 'PASS'})
    folder, project, receipt, code, stderr = execute('candidate_nonselected_corruption_rollback', SOURCE / 'hq-original-editor-app-target.after.rb', fault=True)
    check(code != 0 and 'SDK app settings were not retained exactly' in stderr, 'Candidate still rejects an actually saved nonselected setting change')
    check(not receipt.exists() and project.read_bytes() == PROJECT.read_bytes(), 'Adverse candidate leaves no success receipt and exact original rollback')
    first = read_project(folder / 'first-actual-save.pbxproj')
    rejected = read_project(Path(str(receipt) + '.rejected-project.pbxproj'))
    unchanged_objects(before, rejected, 'adverse rejected project')
    check(first['objects'][CONFIG]['buildSettings'] == CANONICAL, 'Actual first save had exact candidate settings before fault')
    fault_settings = dict(CANONICAL)
    fault_settings['CODE_SIGN_STYLE'] = 'OWNED_TEST_CORRUPTION'
    check(rejected['objects'][CONFIG]['buildSettings'] == fault_settings, 'Rejected saved project preserves the exact single injected nonselected fault')
    normalized = json.loads(json.dumps(rejected))
    normalized['objects'][CONFIG]['buildSettings']['CODE_SIGN_STYLE'] = CANONICAL['CODE_SIGN_STYLE']
    check(normalized == first, 'Test injection changed only the chosen setting, with all other structure exact')
    CASES.append({'name': 'candidate_nonselected_corruption_rollback', 'status': 'PASS'})
    result['status'] = 'PASS'
except Exception as error:
    result['error'] = repr(error)
finally:
    result.update(finished_at=datetime.datetime.now(datetime.timezone.utc).isoformat(), assertions=ASSERTIONS,
                  assertion_count=len(ASSERTIONS), cases=CASES, commands=COMMANDS,
                  required_cases=3, passed_cases=len(CASES),
                  fixture_sha256=digest(PROJECT), plan_sha256=digest(PLAN),
                  helper_sha256=digest(SOURCE / 'hq-original-editor-app-target.after.rb'),
                  driver_sha256=digest(Path(__file__)))
    (RESULTS / 'RESULT.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({k: result[k] for k in ['status', 'required_cases', 'passed_cases', 'assertion_count', 'helper_sha256', 'driver_sha256']}))
if result['status'] != 'PASS':
    print(result.get('error'))
    sys.exit(1)
