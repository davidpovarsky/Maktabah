from pathlib import Path
import ast
import copy
import difflib
import hashlib
import json
import shutil

R = Path(__file__).resolve().parent
P = R.parent / 'annotation-disconnect-apple-v3-20261120'
C = R / 'candidate'
M = 'c1e0d33117154d578206195ef021d41fc2fa2b12'
OLD = '1e55f6012a1b8cedd674349106f27b0e0e476a0b'
BRANCH = 'codex/otzaria-annotation-disconnect-apple-v4-reviewed-20261120'
OLD_BRANCH = 'codex/otzaria-annotation-disconnect-apple-v3-reviewed-20261120'
DRIVER = 'Scripts/CI/annotation-disconnect-apple.py'
BINDING = 'Scripts/CI/annotation-disconnect-apple.inputs.json'
ORIGINAL = 'Scripts/CI/local-annotation-cloud-apple.inputs.json'
TESTS = 'Scripts/CI/test-annotation-disconnect-apple.py'
SELECTOR = 'Scripts/CI/select-runtime27-toolchain.py'
WORKFLOW = '.github/workflows/otzaria-annotation-disconnect-apple.yml'
SOURCE = 'Source/Core/CloudKit/CloudKitCoreManager.swift'

def api(path):
    value = json.loads(path.read_text())
    return json.loads(value['structuredContent']['content']) if 'structuredContent' in value else value

def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + '\n')

def record(raw):
    return {'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest(),
            'git_blob': hashlib.sha1(b'blob ' + str(len(raw)).encode() + bytes([0]) + raw).hexdigest()}

tree = api(R / 'ROOT_SOURCE_ACTUAL_0.json')
commit = api(R / 'ROOT_SOURCE_ACTUAL_1.json')
oldtree = api(P / 'ROOT_SOURCE_TREE_ACTUAL.json')
assert tree['sha'] == commit['tree']['sha'] == 'ba04f752ae54fe1898207323259dc3fb51e0df20'
assert commit['sha'] == M and [x['sha'] for x in commit['parents']] == [OLD]
assert not tree['truncated'] and not oldtree['truncated']
actual = {x['path']: (x['mode'], x['type'], x['sha']) for x in tree['tree'] if x['type'] != 'tree'}
expected = {x['path']: (x['mode'], x['type'], x['sha']) for x in oldtree['tree'] if x['type'] != 'tree'}
source_raw = (R / 'source' / SOURCE).read_bytes()
source_record = record(source_raw)
expected[SOURCE] = ('100644', 'blob', source_record['git_blob'])
assert expected == actual
trees = {x['path']: x['sha'] for x in tree['tree'] if x['path'] in ('Source', 'Tests', 'tools', 'Maktabah.xcodeproj')}
for path in (P / 'candidate').rglob('*'):
    relative = path.relative_to(P / 'candidate')
    if path.is_file() and relative.parts[0] != 'docs' and '__pycache__' not in relative.parts:
        destination = C / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, destination)
(C / SOURCE).write_bytes(source_raw)
repository_fixture = 'docs/hq-integration/annotation-repository-disconnect-20261120/compile-types-v3/REPOSITORY_API.json'
metadata_raw = (P / 'candidate' / repository_fixture).read_bytes()
assert hashlib.sha256(metadata_raw).hexdigest() == '25393d84b6d5f0e2048ccd6562fe558b6599633d2612877611e11cce820ca5d6'
(C / repository_fixture).parent.mkdir(parents=True, exist_ok=True)
(C / repository_fixture).write_bytes(metadata_raw)

old_driver = (P / 'candidate' / DRIVER).read_text()
replacements = [
    (OLD_BRANCH, BRANCH),
    ('SOURCE_M = "' + OLD + '"', 'PREVIOUS_COMPILER_M = "' + OLD + '"\nSOURCE_M = "' + M + '"'),
    ('    require(git(root, "show", "-s", "--format=%P", SOURCE_M).decode().strip() == PREVIOUS_SOURCE_M\n'
     '            and git(root, "show", "-s", "--format=%P", PREVIOUS_SOURCE_M).decode().strip() == BASE,\n'
     '            "Compiler repair must be the exact child of the reviewed Repository source and Cloud base")\n'
     '    repair_delta = git(root, "diff", "--name-status", PREVIOUS_SOURCE_M, SOURCE_M).decode().splitlines()',
     '    require(git(root, "show", "-s", "--format=%P", SOURCE_M).decode().strip() == PREVIOUS_COMPILER_M\n'
     '            and git(root, "show", "-s", "--format=%P", PREVIOUS_COMPILER_M).decode().strip() == PREVIOUS_SOURCE_M\n'
     '            and git(root, "show", "-s", "--format=%P", PREVIOUS_SOURCE_M).decode().strip() == BASE,\n'
     '            "Compiler repairs must preserve the exact reviewed source ancestry")\n'
     '    callback_delta = git(root, "diff", "--name-status", PREVIOUS_COMPILER_M, SOURCE_M).decode().splitlines()\n'
     '    require(callback_delta == ["M\\tSource/Core/CloudKit/CloudKitCoreManager.swift"],\n'
     '            "Explicit upload completion repair changed other source")\n'
     '    repair_delta = git(root, "diff", "--name-status", PREVIOUS_SOURCE_M, PREVIOUS_COMPILER_M).decode().splitlines()')]
new_driver = old_driver
for before, after in replacements:
    assert new_driver.count(before) == 1
    new_driver = new_driver.replace(before, after)
inverse = new_driver
for before, after in reversed(replacements):
    assert inverse.count(after) == 1
    inverse = inverse.replace(after, before)
assert inverse == old_driver
(C / DRIVER).write_text(new_driver)

old_c = json.loads((P / 'candidate' / ORIGINAL).read_text())
new_c = copy.deepcopy(old_c)
new_c['reviewed_source_sha'] = M
new_c['application_trees'] = trees
new_c['source_pins'][SOURCE] = source_record
write(C / ORIGINAL, new_c)
old_binding = json.loads((P / 'candidate' / BINDING).read_text())
binding = copy.deepcopy(old_binding)
binding['application_source'] = M
binding['application_trees'] = trees
binding['route']['branch'] = BRANCH
binding['source_pins'][SOURCE] = source_record
binding['source_pins'][ORIGINAL] = record((C / ORIGINAL).read_bytes())
write(C / BINDING, binding)
for key in ('counts', 'case_names', 'original_repository', 'core_tree', 'source_base'):
    assert old_binding[key] == binding[key]
assert (C / TESTS).read_bytes() == (P / 'candidate' / TESTS).read_bytes()
assert (C / 'Scripts/CI/local-annotation-cloud-apple.py').read_bytes() == (P / 'candidate/Scripts/CI/local-annotation-cloud-apple.py').read_bytes()

bootstrap = {p: record((C / p).read_bytes())['sha256'] for p in (DRIVER, BINDING, TESTS, SELECTOR)}
workflow_old = (P / 'candidate' / WORKFLOW).read_text()
workflow = workflow_old.replace(OLD_BRANCH, BRANCH)
assert workflow.count('fetch-depth: 4') == 1
workflow = workflow.replace('fetch-depth: 4', 'fetch-depth: 5')
old_line = next(x for x in workflow.splitlines() if x.startswith('          expected = '))
old_bootstrap = ast.literal_eval(old_line.split(' = ', 1)[1])
new_line = '          expected = ' + repr(bootstrap)
workflow = workflow.replace(old_line, new_line)
workflow_inverse = workflow.replace(new_line, old_line).replace('fetch-depth: 5', 'fetch-depth: 4').replace(BRANCH, OLD_BRANCH)
assert workflow_inverse == workflow_old
(C / WORKFLOW).write_text(workflow)
for p in (DRIVER, TESTS):
    ast.parse((C / p).read_text())
canonical_pins = 0
for p, value in binding['source_pins'].items():
    assert record((C / p).read_bytes()) == value, p
    if p != ORIGINAL:
        assert actual[p][2] == value['git_blob'], p
        canonical_pins += 1
all_paths = sorted(p.relative_to(C).as_posix() for p in C.rglob('*') if p.is_file() and '__pycache__' not in p.parts)
before = {p: record((C / p).read_bytes()) for p in all_paths}
write(R / 'controls/INPUTS_BEFORE.json', before)
proof = {'source_m': M, 'source_tree': tree['sha'], 'previous_compiler_m': OLD,
         'source_trees': trees, 'branch': BRANCH, 'source_chain': [M, OLD, '939eaf3a5b56fe604354b235579cf7aa4a60e3d4', '7af3a06d48ccbe77acef180cb99d120971c3804e'],
         'whole_driver_inverse': True, 'driver_replacements': replacements,
         'whole_workflow_inverse_except_branch_depth_and_bootstrap': True,
         'bootstrap': bootstrap, 'counts_and_cases_unchanged': True,
         'original26_and43_control_sources_unchanged': True,
         'all_original_runtime_drivers_and_deadlines_unchanged': True,
         'canonical_M_source_pins': canonical_pins,
         'local_fixture_files': len(before), 'actual_full_Git_source_gate': 'NOT_RUN_LOCALLY',
         'actual_Swift_execution': 0, 'actual_Native_execution': 0}
write(R / 'METADATA_PREPARATION.json', proof)
delta = ''
for p in (DRIVER, BINDING, ORIGINAL, WORKFLOW):
    delta += ''.join(difflib.unified_diff((P / 'candidate' / p).read_text().splitlines(True),
                                        (C / p).read_text().splitlines(True), fromfile='v3/' + p, tofile='v4/' + p))
(R / 'CI_DELTA.patch').write_text(delta)
print(json.dumps({k: proof[k] for k in ('source_m', 'source_tree', 'source_trees', 'canonical_M_source_pins', 'local_fixture_files')}))
