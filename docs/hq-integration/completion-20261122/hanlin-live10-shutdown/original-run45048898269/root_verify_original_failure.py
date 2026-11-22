from pathlib import Path
import hashlib
import json
import zipfile

HERE = Path(__file__).resolve().parent
sha = lambda b: hashlib.sha256(b).hexdigest()
read = lambda p: json.loads(p.read_bytes())
run = read(HERE / 'RUN.json')
assert run['id'] == 45048898269 and run['run_attempt'] == 1
assert run['head_sha'] == '4624635d0f29e3bda7ff1f0ecd1097f8b2d37db1'
assert run['status'] == 'completed' and run['conclusion'] == 'failure'
intake = read(HERE / 'INTAKE.json')
archive = (HERE / 'evidence.zip').read_bytes()
assert len(archive) == 79158 and sha(archive) == '110b05a270e90ac63706c58cdedab6816b2a94bc06c320b7fbea3a8ba5b2fec1'
artifact = read(HERE / 'ARTIFACTS.json')['artifacts']
assert len(artifact) == 1 and artifact[0]['id'] == 14767750188
assert artifact[0]['digest'] == 'sha256:' + sha(archive)
with zipfile.ZipFile(HERE / 'evidence.zip') as z:
    assert z.testzip() is None and len(z.namelist()) == len(set(z.namelist())) == 15
    assert set(z.namelist()) == {row['path'] for row in intake['files']}
    for row in intake['files']:
        raw = z.read(row['path'])
        assert raw == (HERE / 'evidence' / row['path']).read_bytes()
        assert len(raw) == row['bytes'] and sha(raw) == row['sha256']
e = HERE / 'evidence'
admission = read(e / 'admission.json')
assert admission['status'] == 'SCANNED_ALLOWLIST_ONLY'
assert set(admission['files']) == {row['path'] for row in intake['files']} - {'admission.json'}
for name, row in admission['files'].items():
    raw = (e / name).read_bytes()
    assert len(raw) == row['bytes'] and sha(raw) == row['sha256']
before = read(e / 'source-before.json')
assert (e / 'source-before.json').read_bytes() == (e / 'source-after.json').read_bytes()
assert before['checkout_sha'] == run['head_sha'] and before['reviewed_source_sha'] == before['application_source_sha'] == '3b4345bd0ae33b83c2ff4ae7697164343f0792b8'
assert len(before['execution_inputs']) == 281 and len(before['binaries']) == 5
source_files = []
for path in sorted((HERE / 'source').rglob('*.py')):
    relative = path.relative_to(HERE / 'source').as_posix()
    row = before['execution_inputs'][relative]
    raw = path.read_bytes()
    assert len(raw) == row['bytes'] and sha(raw) == row['sha256']
    assert hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest() == row['blob']
    source_files.append(relative)
assert len(source_files) == 7
result = read(e / 'result.json')
assert result['status'] == 'FAIL' and result['failure_phase'] == 'NATIVE_MATRIX'
assert result['verified_completed_provider_conversations'] == 0
assert result['private_input_staged'] is False and result['private_input_consumed'] is False
assert result['native116_acceptance'] is False and result['release114_acceptance'] is False
matrix = read(e / 'faithful-ipad-matrix.json')
assert len(matrix['devices']) == 1
device = matrix['devices'][0]
assert device['status'] == 'FAIL' and device['failedPhase'] == 'RECOVERING_VERIFIED_FIXTURE_CLEANUP_TIMEOUT'
assert device['ownedSimulatorCleanup'] == 'PASS'
assert device['udid'] == '06C41237-CB8E-455E-BF1A-B7777EBE53F9'
assert '239.9204655829999 seconds' in device['error']
assert 'testResults' not in device and result['connection_diagnostic_status'] == 'NOT_CAPTURED'
fixture = read(e / 'miniTest10-native-fixture-install-11.json')
assert fixture['passed'] is True and fixture['shaMatched'] is True and fixture['bookCount'] == 10 and fixture['lineCount'] == 18879
assert fixture['actualSHA256'] == fixture['expectedSHA256'] == 'e9e6dedd2ceaadbe46234612c359e5bd8add00c348be8eaeba85cf029fa5c4d3'
assert (e / 'miniTest10-native-fixture-install-11.json').read_bytes() == (e / 'miniTest10-native-fixture-install-11-before-reboot.json').read_bytes()
termination = read(e / 'miniTest10-native-fixture-termination-11.json')
assert termination['status'] == 'TIMEOUT' and termination['nativeValidationFailurePreserved'] is False
cleanup = read(HERE / 'OWNED_SECRET_CLEANUP.json')
lifecycle = read(HERE / 'TERMINAL_LIFECYCLE.json')
assert cleanup['state'] == lifecycle['state'] == 'DELETED_AND_ABSENCE_VERIFIED'
assert cleanup['delete_http_status'] == 204 and cleanup['after_http_status'] == 404
assert cleanup['run_id'] == lifecycle['run_id'] == run['id']
assert cleanup['checkout_sha'] == lifecycle['checkout_sha'] == run['head_sha']
assert lifecycle['secret_cleanup_required'] is False
assert cleanup['before_metadata'] == lifecycle['metadata']
log = (HERE / 'JOB_LOG_DECODED.txt').read_bytes()
assert sha(log) == '2ed8e94391afb968dc417da948d3cc4503eb384409189f791873160ac13545a7'
assert b'Faithful 11-inch: RECOVERING_VERIFIED_FIXTURE_CLEANUP_TIMEOUT' in log
assert b'No live private input was staged' in log
receipt = {
    'status': 'PASS_ORIGINAL_FAILURE_EVIDENCE_REVIEW',
    'run_id': run['id'], 'attempt': 1, 'head': run['head_sha'],
    'artifact_id': artifact[0]['id'], 'archive_sha256': sha(archive),
    'archive_members_verified': 15, 'admitted_payloads_verified': 14,
    'source_closure_reported_by_original_runner': 281,
    'independently_read_source_files': source_files,
    'before_after_source_and_five_binaries_identical': True,
    'actual_build_and_fixture_install': 'PASS',
    'failure': 'Fixture terminate60s, then parent shutdown recovery240s timeout before Live XCTest/private staging',
    'precise_child_shutdown_phase': 'UNOBSERVED; original helper emitted no bounded phase receipt',
    'budget_source_defect': 'Original helper permits45+180+45+45=315s while recovery parent permits240s',
    'budget_defect_causal_attribution': 'Plausible contributor; original logs do not identify which child operation was active',
    'native_case_executed': False, 'provider_conversations': 0,
    'matrix_reported_owned_simulator_cleanup': 'PASS; original report, not independent poststate inventory',
    'credential_lifecycle': cleanup,
    'native116': False, 'release114': False,
    'root_test_replays': 0, 'additional_actions_artifact_downloads': 0,
    'local_transfer_note': 'An initial local verification ran before curl had completed and reported file-not-found; the transfer then exited0 and all original bytes were verified without a second request.',
}
(HERE / 'ROOT_ORIGINAL_FAILURE_REVIEW.json').write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps({k:receipt[k] for k in ('status','archive_members_verified','admitted_payloads_verified','before_after_source_and_five_binaries_identical','native_case_executed','provider_conversations')}))
