#!/usr/bin/env python3
"""Read the authentic failed Apple archive; never compile, execute or extract it."""
import ast
import gzip
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import tarfile
import zipfile

ROOT = Path(__file__).resolve().parent
HEAD = '452a04c2b05150694d8120ed465afb48da190af3'
TREE = '29b001fbc86030179fe81c043e7c93dc57bb238e'
RUN = 44792622640
ARTIFACT = 14656519348
ZIP_SHA = '1e3fab2c767e19ef673c951e63dd05c50cf0a78bffd070b8d5be1acca9b2e116'
ROUTE = 'local-annotation-cloud-route/'
LOCAL = 'local-annotation-cloud-acceptance/'
EXCHANGE = 'local-annotation-cloud-exchange-regression/'


def require(value, message):
    if not value:
        raise RuntimeError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def blob(data):
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()


def safe(path):
    value = PurePosixPath(path)
    require(not value.is_absolute() and '..' not in value.parts and str(value) == path, 'Unsafe archive path')


def clean(text):
    return re.sub(r'\x1b\]8;;.*?\x1b\\', '', re.sub(r'\x1b\[[0-9;]*m', '', text))


def analyze(root):
    api = json.loads(gzip.decompress((root / 'ROOT_API_INPUT.json.gz').read_bytes()))
    git = json.loads(gzip.decompress((root / 'C_GIT_SOURCE_RECORDS.json.gz').read_bytes()))
    run = api['run']
    require((run['id'], run['run_attempt'], run['head_sha'], run['status'], run['conclusion'])
            == (RUN, 1, HEAD, 'completed', 'failure'), 'Actual run identity/outcome differs')
    require(run['head_branch'] == 'codex/otzaria-local-annotation-cloud-apple-reviewed-20261120'
            and run['event'] == 'push' and run['path'] == '.github/workflows/otzaria-local-annotation-cloud-apple.yml',
            'Actual frozen workflow differs')
    jobs = [j for j in api['jobs']['jobs'] if j['id'] == 136483943569]
    require(len(jobs) == 1 and jobs[0]['head_sha'] == HEAD and jobs[0]['conclusion'] == 'failure', 'Wrong actual job')
    require(next(s for s in jobs[0]['steps'] if s['name'] == 'Require complete raw results and unchanged original sources')['conclusion'] == 'failure',
            'Original final gate outcome differs')
    artifacts = [a for a in api['artifacts']['artifacts'] if a['id'] == ARTIFACT]
    require(len(artifacts) == 1, 'Artifact identity is ambiguous')
    artifact = artifacts[0]
    require(artifact['size_in_bytes'] == 995050 and artifact['digest'] == 'sha256:' + ZIP_SHA
            and artifact['workflow_run']['id'] == RUN and artifact['workflow_run']['head_sha'] == HEAD
            and artifact['workflow_run']['repository_id'] == artifact['workflow_run']['head_repository_id'] == 1280062128,
            'Artifact source/digest differs')
    raw_zip = (root / 'artifact-14656519348.zip').read_bytes()
    require(len(raw_zip) == 995050 and sha(raw_zip) == ZIP_SHA, 'Complete authentic ZIP differs')
    with zipfile.ZipFile(io.BytesIO(raw_zip)) as archive:
        require(len(archive.namelist()) == len(set(archive.namelist())) == 114 and archive.testzip() is None,
                'Archive count/CRC differs')
        raw = {}
        members = []
        for info in archive.infolist():
            safe(info.filename)
            require(not info.is_dir(), 'Unexpected directory member')
            data = archive.read(info.filename)
            raw[info.filename] = data
            members.append({'path': info.filename, 'bytes': len(data), 'sha256': sha(data), 'crc32': info.CRC})
    get = lambda name: json.loads(raw[name])
    before, after = get(ROUTE + 'before.json'), get(ROUTE + 'after.json')
    require(before['source'] == after['source'], 'Actual source observation changed')
    source = before['source']
    require(source['identity']['head_sha'] == HEAD and source['identity']['run_id'] == RUN
            and source['identity']['run_attempt'] == 1 and source['reviewed_source_sha'] == '57e4a1cb7cd0bee72e3042e2f4567972237e7e35',
            'Source admission differs')
    require(source['identity']['repository'] == 'davidpovarsky/Maktabah' and source['identity']['repository_id'] == 1280062128
            and source['identity']['ref'] == 'refs/heads/' + run['head_branch']
            and source['identity']['workflow'] == run['path'] and source['identity']['event'] == 'push',
            'Source authority differs')
    require(git['source_commit'] == HEAD and git['canonical_root_tree'] == TREE and git['full_tree_truncated'] is False
            and git['independently_refetched_from_github'] is True, 'Independent Git binding differs')
    records = {r['path']: r for r in git['files']}
    require(len(records) == len(source['files']) == 96 and set(records) == set(source['files']), 'Source closure differs')
    require(api['source_tree']['sha'] == TREE and api['source_tree']['files'] == git['files'], 'Root/C Git records disagree')
    require(source['core_tree_sha'] == git['application_trees']['Source/Otzaria/Actions']
            == '5d0ee482c8f10726fe3863792dac94c18e94d792', 'Core source differs')
    require(all(git['application_trees'][p] == h for p, h in source['application_trees'].items()), 'Application trees differ')
    archives = {}
    for phase, report in [('before', before), ('after', after)]:
        descriptor = report['raw_source_archive']
        compressed = raw[ROUTE + descriptor['file']]
        require(len(compressed) == descriptor['bytes'] and sha(compressed) == descriptor['sha256'] and descriptor['members'] == 96,
                'Actual source archive digest differs')
        with tarfile.open(fileobj=io.BytesIO(compressed), mode='r:gz') as tar:
            entries = tar.getmembers()
            require(len(entries) == len({e.name for e in entries}) == 96, 'Source archive membership differs')
            require({e.name for e in entries} == set(records), 'Source archive closure differs')
            archives[phase] = {}
            for entry in entries:
                safe(entry.name)
                require(entry.isfile() and not entry.issym() and not entry.islnk(), 'Source archive alias')
                data = tar.extractfile(entry).read()
                canonical, observed = records[entry.name], source['files'][entry.name]
                require(len(data) == canonical['size'] == observed['bytes'] and blob(data) == canonical['sha'] == observed['git_blob']
                        and sha(data) == observed['sha256'], 'Actual source is not canonical Git: ' + entry.name)
                archives[phase][entry.name] = data
    require(archives['before'] == archives['after'], 'Original source bytes changed')
    canonical = archives['before']
    local = get(LOCAL + 'RESULT.json')
    require(local['source_sha'] == HEAD and local['status'] == 'FAILED' and local['source_unchanged'] is True
            and local['source_before'] == local['source_after'], 'Local failure/source result differs')
    require(local['cases'] == local['cloud_cases'] == local['cold_processes'] == []
            and all(local[k] == 0 for k in ['passed_cases', 'failed_cases', 'cloud_passed_cases', 'cloud_failed_cases']),
            'Unexecuted local/cloud cases were credited')
    require(len(local['commands']) == 1 and local['commands'][0]['label'] == 'compile'
            and local['commands'][0]['exit_code'] == 1 and local['commands'][0]['timeout_seconds'] == 480,
            'Actual compile outcome/bound differs')
    require(local['commands'][0]['command'][-2:] == ['-j', '1'], 'Original serial build differs')
    compile_copies = []
    original_fixture = canonical['Tests/HQ/local-annotation-editor/LocalAnnotationEditorAcceptance.swift']
    marker = b'// The actual original SQLite driver calls this synchronous function inside the'
    require(original_fixture.count(marker) == 1, 'Original fixture marker differs')
    expected_prefix = original_fixture[:original_fixture.index(marker)]
    require(b'@main' not in expected_prefix and expected_prefix.count(b'struct LocalFixture') == 1, 'Prefix is not the original helper-only span')
    for target, mapping in local['compiled_copies_before'].items():
        prefix = LOCAL + PurePosixPath(local['owned_directory']).name + '/package/Sources/' + target + '/'
        whole = {p: h for p, h in mapping.items() if not p.startswith('generated:')}
        require(len(whole) == 23 and len({PurePosixPath(p).name for p in whole}) == 23, 'Whole compile closure differs')
        expected_names = {PurePosixPath(p).name for p in whole}
        for path, digest in whole.items():
            data = raw[prefix + PurePosixPath(path).name]
            require(data == canonical[path] and sha(data) == digest, 'Retained compile copy differs: ' + path)
        if target == 'LocalAnnotationCloudOwnershipAcceptance':
            expected_names.add('OriginalLocalFixture.swift')
            data = raw[prefix + 'OriginalLocalFixture.swift']
            require(data == expected_prefix and sha(data) == mapping['generated:exact_original_fixture_prefix'], 'Generated prefix differs')
        else:
            require(target == 'LocalAnnotationEditorAcceptance' and len(mapping) == 23, 'Unexpected executable target')
        require({p.removeprefix(prefix) for p in raw if p.startswith(prefix)} == expected_names, 'Compile-source membership differs')
        compile_copies.append({'target': target, 'whole_canonical_files': 23, 'exact_original_fixture_prefix': target == 'LocalAnnotationCloudOwnershipAcceptance'})
    require(len(compile_copies) == 2, 'Missing compile target')
    diagnostics = clean(raw[LOCAL + 'compile.log'].decode())
    error_sites = [line for line in diagnostics.splitlines() if re.search(r'\.swift:\d+:\d+: error:', line)]
    require(len(error_sites) == 1 and 'AnnotationLocalEditorCloudOwnership.swift:40:40:' in error_sites[0]
            and "'inout sending' parameter '$0'" in error_sites[0], 'Actual production compile cause differs')
    require(after['status'] == 'FAILED' and after['workflow_step_outcomes'] == {
        'controls': 'success', 'exchange': 'success', 'local': 'failure', 'toolchain': 'success'}, 'Final failure gate differs')
    require(all(after[k] == 0 for k in ['native_ui_executed', 'cloudkit_transport_executed', 'anytype_runtime_executed',
                                      'app_relaunch_executed', 'physical_device_executed']) and after['live_exchange_enabled'] is False,
            'Runtime scope overclaim')
    exchange = get(EXCHANGE + 'RESULT.json')
    require(exchange['source_sha'] == HEAD and exchange['status'] == 'PASS_ACTUAL_SQLITE_COMPONENT'
            and exchange['compile_exit'] == exchange['execute_exit'] == 0
            and exchange['passed_cases'] == 28 and exchange['failed_cases'] == 0
            and exchange['source_bytes_unchanged_during_run'] is True
            and exchange['source_files_before'] == exchange['source_files_after'], 'Original exchange result differs')
    cases = exchange['cases']
    require(len(cases) == len({r['name'] for r in cases}) == 28 and all(r['status'] == 'PASS' for r in cases)
            and [r['name'] for r in cases] == source['case_names']['exchange'], 'Original 28 exact leaves differ')
    require(re.findall(r'^PASS ([A-Za-z0-9_]+)$', raw[EXCHANGE + 'tests.log'].decode(), re.M) == [r['name'] for r in cases],
            'Raw exchange stdout differs from exact leaves')
    exchange_ast = ast.parse(canonical['tools/hq-annotation-exchange-acceptance.py'])
    assignments = [n for n in exchange_ast.body if isinstance(n, ast.Assign)
                   and any(isinstance(t, ast.Name) and t.id == 'SOURCES' for t in n.targets)]
    require(len(assignments) == 1, 'Original exchange source declaration differs')
    exchange_sources = ast.literal_eval(assignments[0].value)
    require(len(exchange_sources) == len(set(exchange_sources)) == 7, 'Original exchange compile closure differs')
    prefix = EXCHANGE + PurePosixPath(exchange['owned_directory']).name + '/package/Sources/ExchangeAcceptance/'
    require({p.removeprefix(prefix) for p in raw if p.startswith(prefix)}
            == {PurePosixPath(p).name for p in exchange_sources}, 'Original exchange copied membership differs')
    for path in exchange_sources:
        require(raw[prefix + PurePosixPath(path).name] == canonical[path], 'Original exchange compile copy differs')
    for path, digest in exchange['source_files_before'].items():
        require(sha(canonical[path]) == digest, 'Original exchange provenance differs')
    gates = exchange['process_termination_checks']
    require([g['phase'] for g in gates] == ['after', 'before'], 'Original process gates differ')
    for gate in gates:
        phase = gate['phase']
        require(gate['status'] == 'PASS' and gate['terminated_exit'] == gate['expected_terminated_exit'] == 73
                and gate['verify_exit'] == 0 and gate['actual_journal_observation'] == 'CRASH_JOURNAL_MODE wal; synchronous=2',
                'Actual process termination/reopen gate differs')
        require('CRASH_JOURNAL_MODE wal; synchronous=2' in raw[EXCHANGE + 'crash-' + phase + '.log'].decode()
                and 'PASS actual_process_termination_' + phase + '_commit_reopen' in raw[EXCHANGE + 'verify-crash-' + phase + '.log'].decode(),
                'Raw crash/reopen output differs')
    controls = get(ROUTE + 'python-controls/RESULT.json')
    leaves = re.findall(r'^(test_[^( ]+) \(([^)]+)\) \.\.\. ok$', raw[ROUTE + 'python-controls.log'].decode(), re.M)
    require(controls['status'] == 'PASS' and controls['tests'] == len(leaves) == len(set(leaves)) == 43
            and controls['errors'] == controls['failures'] == controls['skipped'] == 0, 'Actual Python controls differ')
    sql = get(ROUTE + 'sql-premises/RESULT.json')
    require(sql['status'] == 'PASS_SQLITE_PREMISES_ONLY' and sql['passed'] == 13 and sql['failed'] == 0
            and len(sql['cases']) == 13 and all(c['status'] == 'PASS' for c in sql['cases'])
            and [c['name'] for c in sql['cases']] == source['case_names']['sql']
            and sql['source_before'] == sql['source_after'], 'Actual SQLite premise controls differ')
    warnings = [line for line in clean(raw[EXCHANGE + 'compile.log'].decode()).splitlines()
                if re.search(r'\.swift:\d+:\d+: warning:', line)]
    require(len(warnings) == 5, 'Original warning inventory differs')
    return {'schema': 1, 'status': 'AUTHENTIC_FAILED_RUN_VERIFIED', 'run_id': RUN, 'attempt': 1,
            'source_head': HEAD, 'source_tree': TREE, 'reviewed_application_source': source['reviewed_source_sha'],
            'core_tree': source['core_tree_sha'], 'not_core194': True, 'artifact_id': ARTIFACT,
            'artifact_bytes': len(raw_zip), 'artifact_sha256': ZIP_SHA, 'artifact_members': members,
            'source_files_before_after_git_exact': 96, 'source_archives_payloads_identical': True,
            'compiled_source_copies': compile_copies, 'local43': 'NOT_RUN_COMPILE_FAILED',
            'local_cold2': 'NOT_RUN_COMPILE_FAILED', 'cloud48': 'NOT_RUN_COMPILE_FAILED',
            'local_compile_exit': 1, 'actual_error_sites': error_sites,
            'original_exchange28': 'PASS', 'original_crash_reopen2': 'PASS', 'exchange_cases': cases,
            'original_exchange_whole_compile_copies': 7,
            'python_controls_passed': 43, 'sqlite_premises_passed': 13,
            'python_sqlite_version': sql['sqlite_version'], 'swift_sqlite_version': exchange['sqlite_version'],
            'swift': local['swift'], 'sdk': local['sdk'], 'original_exchange_warnings': warnings,
            'native_ui': 'NOT_RUN', 'physical_device': 'NOT_RUN', 'anytype_mount': 'NOT_RUN',
            'live_cloudkit': 'NOT_RUN', 'live_exchange_enabled': False,
            'observer_correction_commit_pending_separate_qualification': '7af3a06d48ccbe77acef180cb99d120971c3804e'}


def main():
    index = json.loads((ROOT / 'PACKET_INDEX.json').read_bytes())
    require(index['scope'] == 'ACTUAL_APPLE_FAILURE_WITH_SEPARATE_EXCHANGE_COMPONENT_PASS', 'Wrong packet scope')
    for row in index['files']:
        safe(row['path'])
        data = (ROOT / row['path']).read_bytes()
        require(len(data) == row['bytes'] and sha(data) == row['sha256'], 'Sealed payload differs: ' + row['path'])
    observed = analyze(ROOT)
    require(observed == json.loads((ROOT / 'REVIEW.json').read_bytes()), 'Independent raw review differs')
    print(json.dumps({'status': 'SEALED_ACTUAL_FAILURE_REPLAY_PASS', 'run_conclusion': 'FAILURE',
                      'sealed_payloads': len(index['files']), 'zip_members': 114, 'canonical_sources': 96,
                      'whole_compile_sources_per_executable': 23, 'executed_local': 0, 'executed_cloud': 0,
                      'cold_reopens': 0, 'original_exchange_passed': 28, 'original_crash_reopens_passed': 2,
                      'python_passed': 43, 'sqlite_premises_passed': 13, 'swift_rerun': False}, sort_keys=True))


if __name__ == '__main__':
    main()
