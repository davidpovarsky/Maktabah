#!/usr/bin/env python3
"""Read-only result replay; executes no download, Swift, app, or Native case."""
import argparse, gzip, hashlib, importlib.util, json, pathlib, zipfile

p = argparse.ArgumentParser()
p.add_argument('--root', type=pathlib.Path, required=True)
a = p.parse_args()
root = a.root.resolve()
doc = pathlib.Path(__file__).resolve().parent
manifest = json.loads((doc / 'MANIFEST.json').read_bytes())
for f in manifest['files']:
    data = (doc / f['path']).read_bytes()
    assert len(data) == f['bytes'] and hashlib.sha256(data).hexdigest() == f['sha256'], f['path']
run = json.loads((doc / 'PROCESSOR_RUN.json').read_bytes())
jobs = json.loads((doc / 'PROCESSOR_JOBS.json').read_bytes())
git = json.loads((doc / 'PROCESSOR_SOURCE.json').read_bytes())
assert run['id'] == 44783201113 and run['head_sha'] == '6339dfd55001b4be7073d6a1cfbc01183002eceb'
assert run['event'] == 'push' and run['run_attempt'] == 1 and run['conclusion'] == 'success'
assert run['repository']['id'] == 1280062128 and len(jobs['jobs']) == 1
job = jobs['jobs'][0]
assert job['id'] == 136451045539 and job['head_sha'] == run['head_sha'] and job['conclusion'] == 'success'
assert all(s['conclusion'] == 'success' for s in job['steps'])
for f in git['inputs']:
    data = (root / f['path']).read_bytes()
    assert len(data) == f['bytes'] and hashlib.sha256(data).hexdigest() == f['sha256']
    assert hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest() == f['gitBlob']
meta = json.loads((doc / 'ARTIFACT_METADATA.json').read_bytes())
blob = (doc / 'raw/artifact.zip').read_bytes()
assert meta['id'] == 14652429659 and meta['workflow_run']['head_sha'] == run['head_sha']
assert len(blob) == 12285444 == meta['size_in_bytes']
assert hashlib.sha256(blob).hexdigest() == '0715dcfc3e64e39bd1c549201951185928f93622807fb25947fa217fcbda277b'
assert meta['digest'] == 'sha256:' + hashlib.sha256(blob).hexdigest()
driver = root / 'Scripts/CI/release96-capture-evidence.py'
spec = importlib.util.spec_from_file_location('historical_processor', driver)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
contract = json.loads(driver.with_suffix('.json').read_bytes())
with zipfile.ZipFile(doc / 'raw/artifact.zip') as z:
    assert len(z.namelist()) == len(set(z.namelist())) == 33 and z.testzip() is None
    read = lambda name: json.loads(z.read(name))
    result = read('RESULT.json')
    before = read('SOURCE_BEFORE.json')
    after = read('SOURCE_AFTER.json')
    assert before == after and before['head'] == run['head_sha'] and before['tree'] == git['tree']
    assert str(before['runId']) == str(run['id']) and before['attempt'] == 1
    assert len(before['inputs']) == 4 and {f['path']: f for f in before['inputs']} == {f['path']: f for f in git['inputs']}
    for when in ['BEFORE', 'AFTER']:
        m.validate_metadata(*(read('SOURCE_' + k + '_' + when + '.json') for k in ['RUN', 'ARTIFACT', 'JOB']), contract)
    assert result['qualified'] is True and result['nativeExecutions'] == result['applicationTestExecutions'] == 0
    assert result['sourceRunConclusion'] == 'failure' and result['sourceRunId'] == 44723918854
    proof = read('EXTRACTION_PROOF.json')
    assert result['extraction'] == proof
    entries = read('FULL_ARCHIVE_MEMBER_VERIFICATION.json')
    assert len(entries) == proof['archiveMemberCount'] == 4763 and all(e['crcVerified'] for e in entries)
    index = {e['path']: e for e in entries}
    assert len(index) == len(entries)
    assert proof['archiveBytes'] == 3271556396
    assert proof['archiveSha256'] == 'ea8232db03a3f78c9fd722a1f5777e43f638bef7f4d115a7c0eef9a6319f2457'
    assert proof['fullArchiveHashVerifiedBeforeAndAfter'] and proof['allMembersCRCVerified']
    assert {e['path'] for e in proof['selected']} == {e['path'] for e in contract['selectedMembers']}
    assert len(proof['selected']) == 20 and sum(e['bytes'] for e in proof['selected']) == proof['selectedPayloadBytes'] == 12309479
    for e in proof['selected']:
        data = z.read('entries/' + e['path'])
        assert len(data) == e['bytes'] and hashlib.sha256(data).hexdigest() == e['sha256'] and index[e['path']] == e
    receipt = read('DOWNLOAD_RECEIPT.json')
    assert receipt['bytes'] == 3271556396 and receipt['sha256'] == proof['archiveSha256']
    assert receipt['authorizationForwardedToStorage'] is False
    controls = z.read('python-controls.log').decode()
    assert 'Ran 45 tests' in controls and controls.rstrip().endswith('OK')
log = gzip.decompress((doc / 'PROCESSOR_JOB.log.gz').read_bytes())
assert len(log) == 22691 and hashlib.sha256(log).hexdigest() == '1c33e4c283b0a245ef9b87d5dc1f42d5052567a5f1a430bc239a3461874ef73e'
print(json.dumps({'sealed_files': len(manifest['files']), 'processor_run': run['id'], 'output_zip_crc': 33, 'canonical_processor_inputs': 4, 'ci_original_archive_verified_bytes': 3271556396, 'ci_original_members_crc': 4763, 'selected_original_files': 20, 'new_native_executions': 0, 'original_native_conclusion': 'failure', 'scope': 'Result/provenance replay only; original 3 GB archive verification was performed by recorded CI, not repeated by this replay.'}, sort_keys=True))
