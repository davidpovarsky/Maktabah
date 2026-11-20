#!/usr/bin/env python3
"""Verify the four retained Global4 artifacts and their distinct execution limits."""
import gzip
import hashlib
import json
import zipfile
from pathlib import Path
from verify_failure import CONTEXT, F, M, TREE, TREES, CASES, load, require, verify, verify_tree, verify_privacy

ARTIFACTS = {
    14672078150: ('EVIDENCE.zip', 6474526, 'd6fa367192c1df3080ec8e6ea5fa9f12b9faa8ff64b78ba91d3d5331af59c52c', 134),
    14672617447: ('ipad13-EVIDENCE.zip', 1930647, 'f9c2778c1cea47e025f76095d8d00be2a36b314813edfd9f8d1a221bbecf50cf', 132),
    14672587483: ('ipad13-CAPTURES.zip', 162, '4cbc904306b14bd02781f5fe69396eff446388c0d0c5060931629249cea4c8e0', 1),
    14673280582: ('AGGREGATE.zip', 136046, '987d6624c0ba898a94e071781e8717904df81726c4bb9ec78ae67e5551926858', 1),
}


def verify_terminal(directory):
    ipad11 = verify(directory)
    entries, _ = verify_tree(load(directory / 'raw/F_CANONICAL_TREE.json.gz'))
    api = load(directory / 'raw/ARTIFACTS_OBSERVED.json')['artifacts']
    require({a['id'] for a in api} == set(ARTIFACTS), 'Different final artifact inventory')
    for item in api:
        filename, size, digest, members = ARTIFACTS[item['id']]
        require(item['size_in_bytes'] == size and item['digest'] == 'sha256:' + digest
                and item['workflow_run']['id'] == 44813193123
                and item['workflow_run']['head_sha'] == F, 'Artifact API lineage mismatch')
        archive = directory / 'raw' / filename
        data = archive.read_bytes()
        require(len(data) == size and hashlib.sha256(data).hexdigest() == digest, 'Archive bytes mismatch')
        with zipfile.ZipFile(archive) as z:
            require(len(z.namelist()) == len(set(z.namelist())) == members and z.testzip() is None, 'ZIP CRC/inventory')
    run = load(directory / 'raw/RUN_OBSERVED.json')
    jobs = load(directory / 'raw/JOBS_OBSERVED.json')['jobs']
    require(run['status'] == 'completed' and run['conclusion'] == 'failure', 'Workflow not terminal failure')
    job13 = next(j for j in jobs if j['id'] == 136554730176)
    aggregate_job = next(j for j in jobs if j['id'] == 136588695117)
    require(job13['status'] == 'completed' and job13['conclusion'] == 'cancelled'
            and job13['completed_at'] == '2026-11-20T21:45:15Z', 'iPad13 terminal status differs')
    require(aggregate_job['conclusion'] == 'failure' and aggregate_job['completed_at'] == '2026-11-20T21:45:37Z',
            'Aggregate terminal status differs')
    with zipfile.ZipFile(directory / 'raw/ipad13-EVIDENCE.zip') as z:
        names = z.namelist()
        read = lambda path: json.loads(z.read(path))
        prefix = 'artifacts/global-tab-ownership-native/'
        before, after = read(prefix + 'SOURCE_BEFORE.json'), read(prefix + 'SOURCE_AFTER.json')
        for observation, phase in [(before, 'before'), (after, 'after')]:
            require(observation['status'] == 'SOURCE_BOUND_ONLY' and observation['phase'] == phase
                    and observation['head'] == F and observation['application_and_tests'] == M
                    and observation['configuration'] == 'ipad13' and observation['context'] == CONTEXT
                    and observation['trees'] == TREES, 'iPad13 source receipt differs')
        require(before['execution_inputs'] == after['execution_inputs'] and len(before['execution_inputs']) == 303,
                'iPad13 execution closure changed')
        combined_inputs = {**before['execution_inputs'], **before['product_inputs']}
        require(len(before['product_inputs']) == 1032 and len(combined_inputs) == 1315, 'iPad13 source count differs')
        for path, row in combined_inputs.items():
            require(entries[path]['sha'] == row['blob'] and entries[path]['size'] == row['bytes'], 'iPad13 canonical input differs')
        build = read('hq-stage2/result.json')
        require(build['status'] == 'SIMULATOR_BUILD_FOR_REAL_UI_PASS' and build['checkout_sha'] == F
                and build['application_source_sha'] == M and build['actual_source_inputs_verified'] == 1004,
                'iPad13 full app build identity/status differs')
        require(build['application_trees'] == {k: v for k, v in TREES.items() if k != 'Maktabah-iOSUITests'}, 'iPad13 HQ schema differs')
        actual = read('hq-stage2/actual-source-inputs.json')
        require(len(actual) == 1004, 'iPad13 original helper count')
        verify_privacy(z, entries, actual, build, after)
        require('** TEST BUILD SUCCEEDED **' in z.read('hq-stage2/simulator-build-for-testing.log').decode(), 'iPad13 build log outcome absent')
        require('artifacts/runtime27/result.json' not in names
                and not any(n.startswith('artifacts/runtime27/verified-') for n in names), 'Unexpected complete Native result')
        matrix = read('artifacts/faithful-ipad-matrix.json')
        require(len(matrix['devices']) == 1, 'iPad13 matrix identity')
        device = matrix['devices'][0]
        require(device['label'] == '13' and device['phase'] == 'RUNNING_NATIVE_XCTEST'
                and device['phaseDetails']['suites'] == CASES, 'Unexpected last matrix observation')
        require(device['phaseStartedAt'] == '2026-11-20T21:40:12.809168+00:00', 'iPad13 observed phase time differs')
        test_log = z.read('artifacts/test-simulator-13.log').decode()
        require('Test Case' not in test_log and 'Test Suite' not in test_log
                and 'Checking out' in test_log, 'Unexpected test execution evidence')
        post_result = read(prefix + 'RESULT_AFTER.json')
        require(post_result['status'] == 'FAIL' and 'artifacts/runtime27/result.json' in post_result['error'], 'iPad13 qualification failure differs')
    with zipfile.ZipFile(directory / 'raw/ipad13-CAPTURES.zip') as z:
        require(z.namelist() == ['runtime27/native-13.mp4']
                and all(not i.is_dir() and i.file_size == 0 and i.CRC == 0 for i in z.infolist()),
                'Capture ZIP differs from the observed zero-byte recording')
        empty_capture_entries = z.namelist()
    with zipfile.ZipFile(directory / 'raw/AGGREGATE.zip') as z:
        require(z.namelist() == ['AGGREGATE.json'], 'Unexpected aggregate artifact')
        aggregate = json.loads(z.read('AGGREGATE.json'))
        require(aggregate['status'] == 'FAIL' and aggregate['context'] == CONTEXT
                and aggregate['head'] == F and aggregate['application_and_tests'] == M
                and aggregate['requested_case_executions'] == 4, 'Aggregate identity/status differs')
        require({e['configuration'] for e in aggregate['errors']} == {'ipad11', 'ipad13'}
                and set(aggregate['observed_runtime_reports']) == {'ipad11'}, 'Invalid partial evidence accounting')
        raw11 = aggregate['observed_runtime_reports']['ipad11']
        require(raw11['qualification'] == 'UNQUALIFIED_RAW_OBSERVATION' and raw11['observed']['ui_not_run'] == 2,
                'Aggregate mislabeled partial execution')
    log13 = gzip.decompress((directory / 'raw/ipad13-JOB.log.gz').read_bytes()).decode('utf-8-sig')
    require('2026-11-20T21:38:16.2574080Z ##[error]The operation was canceled.' in log13, 'Missing cancellation observation')
    require('file changed as we read it' in log13 and 'Cache save failed.' in log13, 'Missing actual iPad13 cache failure')
    require('Terminate orphan process:' in log13 and '(xcodebuild)' in log13 and '(simctl)' in log13, 'Missing cleanup observation')
    return {
        'status': 'ACTUAL_TERMINAL_EVIDENCE_VERIFIED_NOT_NATIVE_PASS', 'run': 44813193123, 'run_attempt': 1,
        'head': F, 'application_and_tests': M, 'workflow': 'FAILURE',
        'ipad11': ipad11,
        'ipad13': {
            'job': job13['id'], 'api_conclusion': 'CANCELLED', 'job_completed_at': job13['completed_at'],
            'full_app_build': 'PASS', 'canonical_unique_inputs': 1315, 'original_build_helper_inputs': 1004,
            'original_generated_privacy_replayed': True, 'runtime_result': 'ABSENT', 'verified_xcresult_leaves': 0,
            'test_start_or_end_lines': 0, 'last_matrix_phase': 'RUNNING_NATIVE_XCTEST',
            'last_test_stdout': 'PACKAGE_RESOLUTION', 'requested_cases': 2,
            'execution_count': 'UNCONFIRMED_AFTER_INTERRUPTION', 'empty_capture_entries': empty_capture_entries,
            'cancellation_actor_and_cause': 'UNPROVEN', 'cache_save': 'FAILED_FILE_CHANGED_DURING_TAR',
        },
        'whole_requested': 4, 'whole_verified_pass': 0, 'whole_verified_fail': 0,
        'confirmed_not_run': 2, 'unverified_after_interruption': 2, 'geometry_verdict': 'NOT_OBSERVED',
        'full_zip_crc_members': 268, 'aggregate': 'FAIL_CLOSED',
        'unchanged_attempt2_admission': 'REJECTED_FIRST_ATTEMPT_ONLY',
        'cross_attempt_aggregation': 'REJECTED_EXACT_CONTEXT',
        'product_or_timeout_changes': False, 'retry_or_dispatch': False,
    }


if __name__ == '__main__':
    print(json.dumps(verify_terminal(Path(__file__).resolve().parent), ensure_ascii=False, indent=2))
