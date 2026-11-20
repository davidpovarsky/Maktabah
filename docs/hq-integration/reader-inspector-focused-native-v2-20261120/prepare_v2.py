from pathlib import Path
import ast
import difflib
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parent
BASE = ROOT / 'base'
PRIOR = ROOT / 'prior-route'
CANDIDATE = ROOT / 'candidate'
M = '409519a6972783990a276ade0dbdc4703bb36ae4'
OLD_M = '8ff4e820970e6697eabff40ac46e2f6e61484f27'
NEW_BRANCH = 'codex/otzaria-reader-inspector-focused-native-v2-20261120'
OLD_BRANCH = 'codex/otzaria-reader-inspector-focused-native-20261120'
NEW_DOCS = 'docs/hq-integration/reader-inspector-focused-native-v2-20261120/'
OLD_DOCS = 'docs/hq-integration/reader-inspector-focused-native-20261120/'
NEW_WORKFLOW = '.github/workflows/otzaria-reader-inspector-focused-native-v2.yml'
OLD_WORKFLOW = '.github/workflows/otzaria-reader-inspector-focused-native.yml'
DRIVER = 'Scripts/CI/reader-inspector-focused-native.py'
TESTS = 'Scripts/CI/test-reader-inspector-focused-native.py'
MANIFEST = 'docs/hq-integration/runtime27/R27_CASES.json'
INPUTS = 'Scripts/CI/hq-stage2-focused-apple.inputs.json'
ADDITIONS = 'Scripts/CI/hq-stage2-otzaria-test-additions.json'
RUNTIME = 'Scripts/CI/runtime27.py'
OLD_R27 = '53f9db5b97784b9003eacf1bafc69e51bb64dd0580e426f0d8a17d32f4d9de9b'
PRIOR_R27 = '97d33e24844ea293a004d88379b95e5f534df123b58f76df1f0b6d4de059508f'
NEW_R27 = 'b81034f6e6f83089c9a2cf6294468abfde382af156879f8a7161599539bb87ed'
OLD_PROJECT = '2741615644741d39b0b19c6146f9c459323dabab'
NEW_PROJECT = '489fd95080cd47c8b2138f70bc9ab72e5e4879f0'


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def blob(raw):
    return hashlib.sha1(b'blob ' + str(len(raw)).encode() + bytes([0]) + raw).hexdigest()


def put(path, raw):
    target = CANDIDATE / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(raw)


def write_json(path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, indent=2, ensure_ascii=False) + '\n')


canonical = json.loads((ROOT / 'CANONICAL_INPUTS.json').read_text())
assert canonical['source'] == M and canonical['truncated'] is False
trees = {x['path']: x['sha'] for x in canonical['trees']}
entries = {x['path']: x for x in canonical['entries']}
prior_entries = {x['path']: x for x in canonical['old_entries']}
for path, item in entries.items():
    if item['type'] == 'blob':
        assert blob((BASE / path).read_bytes()) == item['sha'], path
for path in [DRIVER, TESTS, OLD_WORKFLOW]:
    assert blob((PRIOR / path).read_bytes()) == prior_entries[path]['sha'], path

# The reviewed original source/result guard body is unchanged. Only immutable
# source-tree/ref/documentation/workflow constants are rebound to M and v2.
old = (PRIOR / DRIVER).read_text()
new = old
replacements = [
    (OLD_M, M), (OLD_BRANCH, NEW_BRANCH), (OLD_DOCS, NEW_DOCS),
    (OLD_WORKFLOW, NEW_WORKFLOW), (PRIOR_R27, NEW_R27),
    ('"Source": "d4cc25409260ef275214db70ecd57711f24bcaef"', '"Source": "' + trees['Source'] + '"'),
    ('"Maktabah-iOSUITests": "e060cd09a096392cb73fa36bffe7fbf8758ffe50"',
     '"Maktabah-iOSUITests": "' + trees['Maktabah-iOSUITests'] + '"'),
]
for before, after in replacements:
    assert new.count(before) == 1, before
    new = new.replace(before, after)
inverse = new
for before, after in reversed(replacements):
    assert inverse.count(after) == 1, after
    inverse = inverse.replace(after, before)
assert inverse == old
ast.parse(new)
put(DRIVER, new.encode())
put(TESTS, (PRIOR / TESTS).read_bytes())

old_workflow = (PRIOR / OLD_WORKFLOW).read_text()
new_workflow = old_workflow.replace(OLD_BRANCH, NEW_BRANCH)
assert old_workflow.count(OLD_BRANCH) == 1
assert new_workflow.replace(NEW_BRANCH, OLD_BRANCH) == old_workflow
put(NEW_WORKFLOW, new_workflow.encode())

prior_root = ROOT.parent / 'release-reader-focused-native-20261120/candidate'
original = json.loads((BASE / MANIFEST).read_bytes())
manifest = json.loads((prior_root / MANIFEST).read_bytes())
assert manifest['cases'] == original['cases']
assert manifest['supplemental_cases'][:-3] == original['supplemental_cases']
assert len(original['cases'] + original['supplemental_cases']) == 116
for key in ['source_test_commit', 'app_source', 'application_source_sha']:
    assert manifest[key] == OLD_M
    manifest[key] = M
history = manifest['reader_inspector_diagnostic_20261120']
assert history['source_snapshot'] == OLD_M
history['source_snapshot'] = M
assert history['previous_manifest_sha256'] == sha((BASE / MANIFEST).read_bytes())
write_json(CANDIDATE / MANIFEST, manifest)

old_runtime = (BASE / RUNTIME).read_bytes()
assert old_runtime.count(OLD_R27.encode()) == 1
runtime = old_runtime.replace(OLD_R27.encode(), NEW_R27.encode())
prior_runtime = (prior_root / RUNTIME).read_bytes()
assert prior_runtime.count(PRIOR_R27.encode()) == 1
assert runtime == prior_runtime.replace(PRIOR_R27.encode(), NEW_R27.encode())
assert sha((BASE / 'Maktabah-iOSUITests/R27NativeInteractionAcceptanceTests.swift').read_bytes()) == NEW_R27
put(RUNTIME, runtime)

old_additions = (BASE / ADDITIONS).read_bytes()
assert old_additions.count(OLD_PROJECT.encode()) == 1
additions = old_additions.replace(OLD_PROJECT.encode(), NEW_PROJECT.encode())
assert additions == (prior_root / ADDITIONS).read_bytes()
assert blob((BASE / 'Maktabah.xcodeproj/project.pbxproj').read_bytes()) == NEW_PROJECT
put(ADDITIONS, additions)

inputs = json.loads((BASE / INPUTS).read_bytes())
inputs['application_source_sha'] = M
inputs['application_trees'] = {key: trees[key] for key in ['Source', 'Vendor', 'Maktabah.xcodeproj']}
inputs['otzaria_test_additions_sha256'] = sha(additions)
write_json(CANDIDATE / INPUTS, inputs)

patch = ''.join(difflib.unified_diff(old.splitlines(True), new.splitlines(True),
                                   'prior-F4/' + DRIVER, 'candidate/' + DRIVER))
patch += ''.join(difflib.unified_diff(old_workflow.splitlines(True), new_workflow.splitlines(True),
                                    'prior-F4/' + OLD_WORKFLOW, 'candidate/' + NEW_WORKFLOW))
(ROOT / 'REBIND_ONLY.patch').write_text(patch)
proof = {
    'status': 'SOURCE_REBOUND_NATIVE_NOT_RUN',
    'application_and_test_source': M,
    'source_tree': canonical['source_tree'],
    'prior_reviewed_F4': canonical['old_f'],
    'prior_reviewed_M': OLD_M,
    'new_branch': NEW_BRANCH,
    'protected_trees': trees,
    'driver_whole_file_inverse': inverse == old,
    'driver_replacements': [{'before': a, 'after': b} for a, b in replacements],
    'driver_old_sha256': sha(old.encode()), 'driver_new_sha256': sha(new.encode()),
    'unchanged_original27_control_source_sha256': sha((PRIOR / TESTS).read_bytes()),
    'workflow_inverse_exact_branch_only': True,
    'unchanged_runtime_except_original_single_R27_digest': True,
    'runtime_matches_prior_F4_except_single_current_R27_digest': True,
    'runtime_sha256': sha(runtime), 'prior_F4_R27_source_sha256': PRIOR_R27,
    'R27_source_sha256': NEW_R27,
    'unchanged_test_additions_except_original_single_project_blob': True,
    'additions_matches_prior_F4_exactly': True, 'additions_sha256': sha(additions),
    'preserved_original_native_rows': 116,
    'preserved_extra_existing_release_rows': 3,
    'selected_four_case_ids': manifest['execution_case_ids'],
    'all_case_deadlines_seconds': 600,
    'job_minutes': 360,
    'source_or_ui_mutations_by_this_route': 0,
    'native_executions': 0,
    'full_native116_or_release114_credit': False,
    'note': 'Root separately changed only Motion evidence capture in M. This route preserves the original selected methods and acceptance oracles; it does not claim Motion source byte identity to the failed F4.'
}
write_json(ROOT / 'evidence/REBIND_PROOF.json', proof)
print(json.dumps({key: proof[key] for key in ['status', 'application_and_test_source', 'new_branch',
                                           'preserved_original_native_rows', 'native_executions']}, indent=2))
