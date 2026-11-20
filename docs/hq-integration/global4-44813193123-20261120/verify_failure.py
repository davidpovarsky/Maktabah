#!/usr/bin/env python3
"""Replay retained iPad11 evidence; no network, subprocess, simulator, or source writes."""
import argparse
import gzip
import hashlib
import json
import plistlib
import re
import zipfile
from pathlib import Path

F = 'e34ee7b30c7c000e0416b76b3e757b22bc121169'
M = 'cb252c143955d037ab0cef4df556b1e8fcd4c334'
TREE = '5691c61d9c347f91589e7b740a3f3340bbc91687'
RUN = '44813193123'
REF = 'refs/heads/codex/otzaria-global-tab-ownership-native-20261120'
ZIP_SHA = 'd6fa367192c1df3080ec8e6ea5fa9f12b9faa8ff64b78ba91d3d5331af59c52c'
CASES = [
    'FaithfulReaderUIAcceptanceTests/testCandidateGlobalSearchLandscapeMatchesOriginalNavigation',
    'FaithfulReaderUIAcceptanceTests/testCandidateGlobalSearchPortraitMatchesOriginalNavigation',
]
TREES = {
    'Source': '9aa3a513dcb4802988f6cba6fc0bcbad794de792',
    'Vendor': '4065c0e62af325e83a65fe0c70270985229807ae',
    'Maktabah.xcodeproj': 'ebf00ef1e0e466b083f476be9a9bf1a06c7d2b72',
    'Maktabah-iOSUITests': '9be9f4c91114f5daffceac8a8ded0e7314f29fb4',
}
CONTEXT = dict(repository='davidpovarsky/Maktabah', run_id=RUN, run_attempt='1', head=F, ref=REF)
DRIVER = 'Scripts/CI/global-tab-ownership-native.py'
WORKFLOW = '.github/workflows/otzaria-global-tab-ownership-native.yml'


def require(condition, message):
    if not condition:
        raise ValueError(message)


def blob(data):
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()


def load(path):
    data = path.read_bytes()
    return json.loads(gzip.decompress(data) if path.suffix == '.gz' else data)


def verify_tree(tree):
    require(tree['sha'] == TREE and tree['truncated'] is False, 'Canonical tree identity/truncation')
    entries = {row['path']: row for row in tree['tree']}
    require(len(entries) == len(tree['tree']), 'Duplicate canonical tree paths')
    children = {}
    for path, row in entries.items():
        parent, _, name = path.rpartition('/')
        children.setdefault(parent, []).append((name, row))
    calculated = {}
    for parent in sorted(children, key=lambda value: (value.count('/'), len(value)), reverse=True):
        records = children[parent]
        records.sort(key=lambda item: (item[0] + ('/' if item[1]['type'] == 'tree' else '')).encode())
        data = b''
        for name, row in records:
            mode = row['mode'].lstrip('0')
            data += mode.encode() + b' ' + name.encode() + b'\0' + bytes.fromhex(row['sha'])
        digest = hashlib.sha1(b'tree ' + str(len(data)).encode() + b'\0' + data).hexdigest()
        expected = TREE if parent == '' else entries[parent]['sha']
        require(digest == expected, 'Canonical Git tree object mismatch: ' + parent)
        calculated[parent] = digest
    require(calculated[''] == TREE, 'Missing root tree')
    require({path: entries[path]['sha'] for path in TREES} == TREES, 'Protected tree mismatch')
    return entries, len(calculated)


def verify_privacy(zipped, entries, actual, build, after):
    differences = [path for path, oid in actual.items() if entries[path]['sha'] != oid]
    require(differences == ['Source/PrivacyInfo.xcprivacy'], 'Unexpected compiled source differences')
    original = zipped.read('hq-stage2/privacy-original.xcprivacy')
    generated = zipped.read('hq-stage2/privacy-generated.xcprivacy')
    require(blob(original) == entries[differences[0]]['sha'] and blob(generated) == actual[differences[0]],
            'Actual compiled privacy bytes differ')
    declared = build['generated_configuration']
    require(len(declared) == 1 and after['product_inputs']['generated_configuration'] == declared + declared,
            'Original two privacy observations differ')
    item = declared[0]
    require(item['path'] == differences[0] and item['origin'] == 'Original React Native CocoaPods privacy aggregation'
            and item['original_git_blob'] == entries[differences[0]]['sha']
            and item['original_sha256'] == hashlib.sha256(original).hexdigest()
            and item['compiled_sha256'] == hashlib.sha256(generated).hexdigest(), 'Privacy provenance mismatch')
    require(item['all_other_declarations_unchanged'] is True and item['all_original_reasons_retained'] is True,
            'Privacy preservation receipt differs')
    old, new = plistlib.loads(original), plistlib.loads(generated)
    access = 'NSPrivacyAccessedAPITypes'
    require({k: v for k, v in old.items() if k != access} == {k: v for k, v in new.items() if k != access},
            'Non-reason privacy data changed')
    def reasons(value):
        return {(r['NSPrivacyAccessedAPIType'], reason) for r in value[access]
                for reason in r['NSPrivacyAccessedAPITypeReasons']}
    old_reasons, new_reasons = reasons(old), reasons(new)
    require(old_reasons <= new_reasons and new_reasons - old_reasons
            == {(r['category'], r['reason']) for r in item['added_reasons']}, 'Unexplained privacy reason changes')
    for row in item['added_reasons']:
        require(bool(row['dependency_inputs']), 'Missing original dependency provenance')
        for dependency in row['dependency_inputs']:
            data = zipped.read('hq-stage2/' + dependency['artifact_path'])
            require(hashlib.sha256(data).hexdigest() == dependency['sha256']
                    and (row['category'], row['reason']) in reasons(plistlib.loads(data)), 'Dependency privacy mismatch')


def verify(directory):
    archive = directory / 'raw/EVIDENCE.zip'
    data = archive.read_bytes()
    require(len(data) == 6474526 and hashlib.sha256(data).hexdigest() == ZIP_SHA, 'Artifact bytes differ')
    entries, tree_count = verify_tree(load(directory / 'raw/F_CANONICAL_TREE.json.gz'))
    commit = load(directory / 'raw/F_COMMIT.json')
    require(commit['sha'] == F and commit['tree']['sha'] == TREE, 'Commit/tree mismatch')
    require([p['sha'] for p in commit['parents']] == [M], 'Application parent mismatch')
    run = load(directory / 'raw/RUN_OBSERVED.json')
    require(str(run['id']) == RUN and run['head_sha'] == F and run['run_attempt'] == 1
            and 'refs/heads/' + run['head_branch'] == REF, 'Run identity mismatch')
    jobs = load(directory / 'raw/JOBS_OBSERVED.json')['jobs']
    job = next(j for j in jobs if j['id'] == 136554729770)
    require(job['status'] == 'completed' and job['conclusion'] == 'failure'
            and job['completed_at'] == '2026-11-20T21:38:29Z', 'Wrong terminal job')
    artifact = load(directory / 'raw/ARTIFACTS_OBSERVED.json')
    if isinstance(artifact, dict) and 'artifacts' in artifact:
        artifacts = artifact['artifacts']
    else:
        raise ValueError('Unexpected artifact metadata schema')
    record = next(a for a in artifacts if a['id'] == 14672078150)
    require(record['name'] == 'global-tab-ownership-native-evidence-ipad11'
            and record['size_in_bytes'] == len(data), 'Artifact metadata differs')
    with zipfile.ZipFile(archive) as zipped:
        names = zipped.namelist()
        require(len(names) == len(set(names)) == 134 and zipped.testzip() is None, 'ZIP inventory/CRC')
        require(all(not n.startswith('/') and '..' not in Path(n).parts for n in names), 'Unsafe ZIP path')
        read = lambda path: json.loads(zipped.read(path))
        prefix = 'artifacts/global-tab-ownership-native/'
        before, after = read(prefix + 'SOURCE_BEFORE.json'), read(prefix + 'SOURCE_AFTER.json')
        before_result, after_result = read(prefix + 'RESULT_BEFORE.json'), read(prefix + 'RESULT_AFTER.json')
        for observation, phase in [(before, 'before'), (after, 'after')]:
            require(observation['status'] == 'SOURCE_BOUND_ONLY' and observation['phase'] == phase
                    and observation['head'] == F and observation['application_and_tests'] == M
                    and observation['configuration'] == 'ipad11' and observation['context'] == CONTEXT
                    and observation['trees'] == TREES, 'Per-device source context differs')
            require(observation['native_pass_credit'] == 0 and observation['full_native116_acceptance'] is False
                    and observation['full_release114_acceptance'] is False, 'Invalid wider credit')
        require(before['execution_inputs'] == after['execution_inputs'], 'Execution inputs changed')
        canonical_inputs = {}
        for group in ['execution_inputs', 'product_inputs']:
            for path, item in before[group].items():
                require(path in entries and entries[path]['type'] == 'blob'
                        and entries[path]['sha'] == item['blob'] and entries[path]['size'] == item['bytes'],
                        'Noncanonical source input: ' + path)
                require(re.fullmatch('[0-9a-f]{64}', item['sha256']) is not None, 'Invalid source SHA')
                if path in canonical_inputs:
                    require(canonical_inputs[path] == item, 'Conflicting input observations')
                canonical_inputs[path] = item
        require(len(before['execution_inputs']) == 303 and len(before['product_inputs']) == 1032,
                'Unexpected source closure size')
        actual_build_inputs = read('hq-stage2/actual-source-inputs.json')
        require(len(actual_build_inputs) == 1004, 'Original build helper input count differs')
        build = read('hq-stage2/result.json')
        require(all(entries[path]['type'] == 'blob' for path in actual_build_inputs), 'Unexpected build input type')
        verify_privacy(zipped, entries, actual_build_inputs, build, after)
        require(build['status'] == 'SIMULATOR_BUILD_FOR_REAL_UI_PASS' and build['checkout_sha'] == F
                and build['application_source_sha'] == M and build['no_fixture_or_app_model_mocks'] is True,
                'No actual matching full app build')
        require(build['application_trees'] == {k: v for k, v in TREES.items() if k != 'Maktabah-iOSUITests'},
                'Original three-tree HQ schema differs')
        require(build['actual_source_inputs_verified'] == 1004
                and after['product_inputs']['original_helper_actual_source_count'] == 1004,
                'Build/post source audit differs')
        compiler = zipped.read('hq-stage2/simulator-build-for-testing.log').decode('utf-8')
        require('** TEST BUILD SUCCEEDED **' in compiler, 'Missing original actual build outcome')
        runtime = read('artifacts/runtime27/result.json')
        require(runtime['checkout_sha'] == F and runtime['test_source_commit'] == M
                and runtime['requested_ui_case_count'] == 2 and runtime['status'] == 'FAIL', 'Wrong runtime request')
        require(runtime['executed_ui_pass'] == runtime['executed_ui_fail'] == runtime['executed_ui_skip'] == 0
                and runtime['ui_not_run'] == 2, 'Unjustified UI execution credit')
        require([r['case_id'] for r in runtime['case_outcomes']] == CASES
                and all(r['actual'] == 'NOT_RUN' and r['device'] == 'ipad11'
                        and r['configuration_label'] == '11-reader' for r in runtime['case_outcomes']), 'Wrong leaves')
        require(not any(n.startswith('artifacts/runtime27/verified-') or '.xcresult/' in n for n in names),
                'Unexpected verified native result in pre-UI failure')
        matrix = read('artifacts/faithful-ipad-matrix.json')
        require(len(matrix['devices']) == 1, 'Unexpected device execution')
        device = matrix['devices'][0]
        require(device['failedPhase'] == 'PROVISIONING_NATIVE_FIXTURES' and device['ownedSimulatorCleanup'] == 'PASS'
                and len(device['installationAttempts']) == 1 and device['installationAttempts'][0]['status'] == 'INSTALLED',
                'Failure phase/cleanup differs')
        require(after_result['status'] == 'FAIL' and after_result['context'] == CONTEXT
                and 'verified-11-reader.summary.json' in after_result['error'], 'Expected missing native summary differs')
        apple55 = read('artifacts/sefaria-toc-apple55/RESULT.json')
        require(apple55['status'] == 'APPLE_FOUNDATION_55_PASS' and apple55['expectedSHA'] == F
                and apple55['executed'] == apple55['passed'] == 55 and apple55['driverReturncode'] == 0,
                'Earlier Foundation gate final receipt differs')
    log = gzip.decompress((directory / 'raw/JOB.log.gz').read_bytes()).decode('utf-8-sig')
    require('get_app_container' in log and 'data' in log and 'timed out after 45 seconds' in log,
            'Missing actual original provisioning timeout')
    cache_key = 'runtime27-derived-v2-8e8d194e26fadf4fae79d05b277a27651a741f403089600885d4bd371a9d6f34-7260612b736a058cb89a7e998719c8077111232162a341c7ca2702bc683d8573'
    require('Cache not found for input keys: ' + cache_key in log
            and 'Sent 1593847974 of 1593847974 (100.0%)' in log
            and '2026-11-20T21:38:16.4541760Z Cache saved with key: ' + cache_key in log,
            'Actual matching cache-save evidence differs')
    for name in [DRIVER, WORKFLOW]:
        data = (directory / 'source' / name).read_bytes()
        require(blob(data) == entries[name]['sha'], 'Review source differs from actual frozen Git: ' + name)
    driver = (directory / 'source' / DRIVER).read_text()
    require('context.get("run_attempt") == "1"' in driver
            and 'item.get("context") == context' in driver, 'Original attempt guards differ')
    return {
        'status': 'ACTUAL_PRE_UI_FAILURE_EVIDENCE_VERIFIED', 'run': int(RUN), 'run_attempt': 1,
        'job': job['id'], 'job_completed_at': job['completed_at'], 'head': F, 'application_and_tests': M,
        'canonical_tree': TREE, 'reconstructed_git_tree_objects': tree_count,
        'canonical_unique_inputs': len(canonical_inputs), 'execution_inputs_before_after_equal': 303,
        'canonical_product_inputs': 1032, 'original_build_helper_inputs': 1004,
        'canonical_unchanged_build_inputs': 1003, 'original_generated_privacy_replayed': True,
        'archive_bytes': 6474526, 'archive_sha256': ZIP_SHA, 'full_zip_crc_members': 134,
        'full_real_app_build': 'PASS', 'native_pass': 0, 'native_fail': 0, 'native_skip': 0,
        'native_not_run': 2, 'geometry_verdict': 'NOT_OBSERVED',
        'failure_phase': device['failedPhase'], 'owned_simulator_cleanup': 'PASS',
        'original_timeout_seconds': 45, 'cache_saved_bytes': 1593847974, 'cache_key': cache_key,
        'unchanged_attempt2_admission': 'REJECTED_BY_EXISTING_FIRST_ATTEMPT_GUARD',
        'cross_attempt_aggregate': 'REJECTED_BY_EXISTING_EXACT_CONTEXT_GUARD',
        'ipad13_and_whole_workflow': 'OUTSIDE_THIS_IPAD11_PACKET',
        'source_changes': False, 'retry_or_dispatch': False,
    }


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('directory', nargs='?', type=Path, default=Path(__file__).resolve().parent)
    args = parser.parse_args()
    print(json.dumps(verify(args.directory), ensure_ascii=False, indent=2))
