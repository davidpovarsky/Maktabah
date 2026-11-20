#!/usr/bin/env python3
"""Prepare an isolated, inactive copy of the already executed extraction processor."""
from pathlib import Path
import ast
import copy
import difflib
import gzip
import hashlib
import json
import re
import shutil

ROOT = Path(__file__).resolve().parent
WORK = ROOT.parent
OLD = WORK / 'release96-capture-evidence-route-20261120/candidate'
RAW = WORK / 'native-study-sheet-44811999303-20261120'
CANDIDATE = ROOT / 'candidate'
BASE = ROOT / 'base'
EVIDENCE = ROOT / 'evidence'
PARENT = '28befd6ef09310eb4becc8ee64e43cba1dc3e00d'
OLD_STEM = 'release96-capture-evidence'
STEM = 'native-study-sheet-capture-evidence'


def sha(data): return hashlib.sha256(data).hexdigest()
def blob(data): return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data if isinstance(data, bytes) else data.encode())
def json_write(path, data): write(path, json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + '\n')
def unwrap(value):
    if isinstance(value, dict) and 'structuredContent' in value: return unwrap(value['structuredContent'])
    if isinstance(value, dict) and isinstance(value.get('content'), str): return json.loads(value['content'])
    return value
def read_raw(name): return unwrap(json.loads((RAW / name).read_bytes()))


assert not CANDIDATE.exists(), 'Do not overwrite an existing prepared route'
EVIDENCE.mkdir(parents=True, exist_ok=True)
run, jobs, artifacts = read_raw('FINAL_RUN.json'), read_raw('ROOT_JOBS_2142.json'), read_raw('FINAL_ARTIFACTS.json')
job = next(j for j in jobs['jobs'] if j['id'] == 136551383131)
artifact = next(a for a in artifacts['artifacts'] if a['id'] == 14671753925)
upload = next(s for s in job['steps'] if s['name'] == 'Retain original native result bundles and visual captures separately')
assert artifact['size_in_bytes'] == 576476315
assert artifact['digest'] == 'sha256:e996e2617478c5d9ee7be07fb11f17004d6ada55ef01e59b894a4b0eadde72f7'
assert run['id'] == 44811999303 and run['head_sha'] == 'a1d11a78152f9d6826c90646fcd72cf7711f12ff'
assert run['conclusion'] == job['conclusion'] == 'failure' and run['run_attempt'] == job['run_attempt'] == 1
assert upload['conclusion'] == 'success' and upload['number'] == 18
for name, value in [('SOURCE_RUN_METADATA.json', run), ('SOURCE_JOB_METADATA.json', job), ('SOURCE_ARTIFACT_METADATA.json', artifact)]:
    json_write(EVIDENCE / name, value)

runtime_path = RAW / 'ipad11_evidence/artifacts/runtime27/result.json'
runtime = json.loads(runtime_path.read_bytes())
failed = {r['case_id'] for r in runtime['case_outcomes'] if r['actual'] == 'Failed'}
assert len(runtime['case_outcomes']) == 11 and len(failed) == 9
log_path = RAW / 'ipad11_evidence/artifacts/runtime27/native-matrix-driver.log'
log_bytes = log_path.read_bytes()
groups, counts, current = {}, {}, None
for number, line in enumerate(log_bytes.decode().splitlines(), 1):
    match = re.fullmatch(r'Exported (\d+) attachments for: (.+)\(\):', line)
    if match:
        current = match[2]
        assert current not in groups
        groups[current], counts[current] = [], int(match[1])
        continue
    match = re.fullmatch(r'File: ([^,]+), suggested name: "(.*)"', line)
    if match:
        assert current
        groups[current].append({'path': 'visual-11-reader/' + match[1], 'caseId': current,
                                'purpose': match[2], 'exportLogLine': number})
assert len(groups) == 11 and failed <= set(groups)
assert all(len(rows) == counts[key] for key, rows in groups.items())
selected = [row for case, rows in groups.items() if case in failed for row in rows
            if Path(row['path']).suffix in {'.txt', '.json', '.png'}]
manifest_line = [(i + 1, line) for i, line in enumerate(log_bytes.decode().splitlines())
                 if line.startswith('Generated manifest file with attachment details: ')]
assert len(manifest_line) == 1 and manifest_line[0][1].endswith('/visual-11-reader/manifest.json')
selected.append({'path': 'visual-11-reader/manifest.json', 'caseId': 'ORIGINAL_ELEVEN_CASE_ATTACHMENT_MANIFEST',
                 'purpose': 'Original xcresult attachment manifest for all eleven executed iPad11 cases',
                 'exportLogLine': manifest_line[0][0]})
assert len(selected) == len({s['path'] for s in selected}) == 119
assert all(any(s['caseId'] == case and s['path'].endswith('.png') for s in selected) for case in failed)
assert all(any(s['caseId'] == case and s['path'].endswith('.txt') for s in selected) for case in failed)
for case in failed:
    assert any(s['caseId'] == case and s['purpose'].startswith('system-study-final-actual-views') for s in selected)
write(EVIDENCE / 'NATIVE_MATRIX_DRIVER.log.gz', gzip.compress(log_bytes, mtime=0))
write(EVIDENCE / 'ORIGINAL_RUNTIME_RESULT.json.gz', gzip.compress(runtime_path.read_bytes(), mtime=0))

old_contract = json.loads((OLD / f'Scripts/CI/{OLD_STEM}.json').read_bytes())
contract = copy.deepcopy(old_contract)
contract['scope'] = 'Read-only processing of original SideSheet iPad11 captures; 0 new Native/app/test executions.'
contract['limitations'] = [
    'Original iPad11 Native outcome remains 2 passed and 9 failed; this route does not change any acceptance result.',
    'All eleven original cases are represented by their original attachment manifest; exact selected captures cover the nine failed cases.',
    'Complete original archive SHA and all member CRCs are verified before any selected bytes are published.',
    'No video decoding, image editing, test rerun, simulator, app, Swift, or product execution occurs.',
]
contract['limits']['exactSelectedMembers'] = 119
contract['originalApplicationSource'] = runtime['test_source_commit']
contract['selectedMembers'] = selected
contract['sourceRun'] = {k: run[k] for k in old_contract['sourceRun']}
contract['sourceJob'] = {k: job[k] for k in old_contract['sourceJob']}
contract['sourceArtifact'] = {k: artifact[k] for k in old_contract['sourceArtifact']}
contract['uploadStep'] = {k: upload[k] for k in old_contract['uploadStep']}
contract['selectionProvenance'] = {
    'archiveRoot': 'Original upload common ancestor build/artifacts; exact visual-11-reader paths only',
    'exportLog': 'artifacts/runtime27/native-matrix-driver.log', 'exportLogSha256': sha(log_bytes),
    'sourceEvidenceArtifactId': 14672003494, 'sourceEvidenceArtifactSha256': next(a['digest'] for a in artifacts['artifacts'] if a['id'] == 14672003494),
    'originalElevenCaseOutcomes': runtime['case_outcomes'], 'failedCaseIds': sorted(failed),
    'selection': 'Every original .txt/.json/.png attachment of each failed case plus the original all-case manifest',
    'noBasenameFallback': True, 'noVideoSelected': True,
    'originalWorkflowArtifactPaths': old_contract['selectionProvenance']['originalWorkflowArtifactPaths'],
}
original_workflow_path = '.github/workflows/otzaria-native-study-sheet-native.yml'
source_before = json.loads((RAW / 'ipad11_evidence/artifacts/native-study-sheet-native/SOURCE_BEFORE.json').read_bytes())
original_workflow = (WORK / 'native-study-sheet-apple-route-20261120/candidate' / original_workflow_path).read_bytes()
assert blob(original_workflow) == source_before['execution_inputs'][original_workflow_path]['blob']
write(EVIDENCE / 'ORIGINAL_SOURCE_WORKFLOW.yml', original_workflow)
contract['selectionProvenance']['originalWorkflowBlob'] = blob(original_workflow)
json_write(CANDIDATE / f'Scripts/CI/{STEM}.json', contract)
json_write(EVIDENCE / 'EXPORT_MAPPING_PROVENANCE.json', {'export_sha256': sha(log_bytes), 'source_runtime_sha256': sha(runtime_path.read_bytes()),
            'total_original_export_groups': 11, 'failed_case_count': 9, 'selected_count': 119,
            'types': {suffix: sum(s['path'].endswith(suffix) for s in selected) for suffix in ['.txt', '.json', '.png']},
            'selected': selected, 'all_original_group_counts': counts})

prior = json.loads((WORK / 'release96-capture-44783201113/raw/SOURCE_BEFORE.json').read_bytes())
prior_result = json.loads((WORK / 'release96-capture-44783201113/raw/RESULT.json').read_bytes())
assert prior_result['qualified'] is True and prior_result['nativeExecutions'] == 0
prior_inputs = {r['path']: r for r in prior['inputs']}
old_files = [f'Scripts/CI/{OLD_STEM}.py', f'Scripts/CI/test-{OLD_STEM}.py', f'Scripts/CI/{OLD_STEM}.json', f'.github/workflows/otzaria-{OLD_STEM}.yml']
for path in old_files:
    data = (OLD / path).read_bytes()
    assert sha(data) == prior_inputs[path]['sha256'] and blob(data) == prior_inputs[path]['gitBlob']
    write(BASE / path, data)
json_write(EVIDENCE / 'PRIOR_EXECUTED_PROCESSOR_SOURCE_BEFORE.json', prior)
json_write(EVIDENCE / 'PRIOR_EXECUTED_PROCESSOR_RESULT.json', prior_result)

driver = (BASE / old_files[0]).read_text()
driver = driver.replace(OLD_STEM, STEM).replace('Historical Release96', 'Original SideSheet').replace('historical Release96', 'original SideSheet')
driver = driver.replace('e603d8182a1c10c4b37b14c92b5f0bc3829edea8', PARENT)
driver = driver.replace('SELECTED_COUNT = 20', 'SELECTED_COUNT = 119')
driver = driver.replace('artifact-14647594631.zip', 'artifact-14671753925.zip')
driver = driver.replace('otzaria-release96-evidence-reader', 'otzaria-native-study-sheet-evidence-reader')
driver = driver.replace('Verify and select historical Release96 evidence.', 'Verify and select original SideSheet evidence.')
write(CANDIDATE / f'Scripts/CI/{STEM}.py', driver)

tests = (BASE / old_files[1]).read_text().replace(OLD_STEM, STEM)
replacements = {'44723918854': '44811999303', '44723918855': '44811999304',
                '60a57972acb28739ec738565083bf17fb7503028': run['head_sha'],
                'codex/otzaria-release96-signature-reviewed-20261120': run['head_branch'],
                '3271556396': '576476315', '3271556395': '576476314',
                '136270631606': '136551383132', '14647594631': '14671753925',
                '2026-11-20T16:29:07Z': '2026-11-20T21:41:07Z'}
for old, new in replacements.items(): tests = tests.replace(old, new)
old_video = '''    def test_video_selected_member_limit(self):
        path, contract = self.make()
'''
new_video = '''    def test_video_selected_member_limit(self):
        # This real selection contains no video; retain the original video-bound
        # refusal with an explicit synthetic selected payload in this control only.
        old = CONTRACT["selectedMembers"][0]["path"]
        video = "visual-11-reader/synthetic-control-only.mp4"
        self.payloads[video] = self.payloads.pop(old)
        path, contract = self.make()
        contract["selectedMembers"][0]["path"] = video
'''
assert tests.count(old_video) == 1
tests = tests.replace(old_video, new_video)
write(CANDIDATE / f'Scripts/CI/test-{STEM}.py', tests)

workflow = (BASE / old_files[3]).read_text().replace(OLD_STEM, STEM)
workflow = workflow.replace('Recover original Release96 layout and input evidence', 'Recover original SideSheet failure evidence')
workflow = workflow.replace('exactly twenty evidence files', 'exactly 119 original evidence files')
for oldpath, newpath in [(old_files[0], f'Scripts/CI/{STEM}.py'), (old_files[1], f'Scripts/CI/test-{STEM}.py'), (old_files[2], f'Scripts/CI/{STEM}.json')]:
    workflow = workflow.replace(sha((BASE / oldpath).read_bytes()), sha((CANDIDATE / newpath).read_bytes()))
write(CANDIDATE / f'.github/workflows/otzaria-{STEM}.yml', workflow)

def functions(source):
    lines = source.splitlines(keepends=True)
    return {n.name: ''.join(lines[n.lineno-1:n.end_lineno]) for n in ast.parse(source).body if isinstance(n, (ast.FunctionDef, ast.ClassDef))}
old_functions = functions((BASE / old_files[0]).read_text())
new_functions = functions(driver)
body_changes = [name for name in old_functions if old_functions[name] != new_functions[name]]
assert body_changes == ['GitHubReader', 'main']
assert old_functions['GitHubReader'].replace('otzaria-release96-evidence-reader', 'otzaria-native-study-sheet-evidence-reader') == new_functions['GitHubReader']
assert old_functions['main'].replace('artifact-14647594631.zip', 'artifact-14671753925.zip') == new_functions['main']
old_methods = sorted(n.name for n in ast.walk(ast.parse((BASE / old_files[1]).read_text())) if isinstance(n, ast.FunctionDef) and n.name.startswith('test_'))
new_methods = sorted(n.name for n in ast.walk(ast.parse(tests)) if isinstance(n, ast.FunctionDef) and n.name.startswith('test_'))
assert old_methods == new_methods and len(old_methods) == 45
json_write(EVIDENCE / 'PRESERVATION_PROOF.json', {'status': 'EXACT_BODY_PRESERVATION', 'prior_actual_run': 44783201113,
    'prior_processor_head': prior['head'], 'parent': PARENT, 'candidate': 'UNACTIVATED',
    'all_transport_archive_metadata_source_gate_bodies_identical': True,
    'only_function_body_metadata_changes': {'GitHubReader': 'User-Agent value only', 'main': 'owned cached archive filename only'},
    'original_45_control_method_names_retained': old_methods, 'test_video_control': 'synthetic selected video added only to preserve the existing rejection because the real119-file selection contains no videos',
    'processing_deadline_seconds': 900, 'job_minutes': 20, 'max_selected_total_bytes': 134217728,
    'max_other_selected_bytes': 8388608, 'original_full_zip_hash_and_every_crc': True,
    'source_product_native_changes': False, 'native_executions': 0})
patch = ''
for oldpath, newpath in zip(old_files, [f'Scripts/CI/{STEM}.py', f'Scripts/CI/test-{STEM}.py', f'Scripts/CI/{STEM}.json', f'.github/workflows/otzaria-{STEM}.yml']):
    patch += ''.join(difflib.unified_diff((BASE / oldpath).read_text().splitlines(True), (CANDIDATE / newpath).read_text().splitlines(True), fromfile='prior/' + oldpath, tofile='candidate/' + newpath))
write(ROOT / 'PROPOSED.patch', patch)
print(json.dumps({'candidate': str(CANDIDATE), 'selected': 119, 'failed_cases': 9, 'original_controls': 45,
                  'driver_sha256': sha(driver.encode()), 'manifest_sha256': sha((CANDIDATE / f'Scripts/CI/{STEM}.json').read_bytes())}, indent=2))
