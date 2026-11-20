#!/usr/bin/env python3
"""Read-only integrity/metadata replay; no downloads, app or Native tests."""
import gzip
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
REPOSITORY = ROOT.parents[2]
manifest = json.loads((ROOT / 'ARTIFACTS.json').read_bytes())
for item in manifest['files']:
    body = (ROOT / item['path']).read_bytes()
    assert len(body) == item['bytes'], item['path']
    assert hashlib.sha256(body).hexdigest() == item['sha256'], item['path']
    if 'uncompressed_sha256' in item:
        raw = gzip.decompress(body)
        assert len(raw) == item['uncompressed_bytes'], item['path']
        assert hashlib.sha256(raw).hexdigest() == item['uncompressed_sha256'], item['path']
for item in manifest['source_outputs']:
    body = (REPOSITORY / item['path']).read_bytes()
    assert len(body) == item['bytes'], item['path']
    assert hashlib.sha256(body).hexdigest() == item['sha256'], item['path']
    assert hashlib.sha1(b'blob ' + str(len(body)).encode() + b'\0' + body).hexdigest() == item['gitBlob'], item['path']

prior = json.loads((ROOT / 'PRIOR_PROCESSOR_SOURCE_BEFORE.json').read_bytes())
for item in prior['inputs']:
    raw = gzip.decompress((ROOT / 'prior-successful-source' / (item['path'] + '.gz')).read_bytes())
    assert len(raw) == item['bytes']
    assert hashlib.sha256(raw).hexdigest() == item['sha256']
    assert hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest() == item['gitBlob']

source = REPOSITORY / 'Scripts/CI/release96-capture-evidence.py'
spec = importlib.util.spec_from_file_location('release_evidence', source)
driver = importlib.util.module_from_spec(spec)
spec.loader.exec_module(driver)
contract = json.loads((REPOSITORY / driver.MANIFEST).read_bytes())
metadata = [json.loads((ROOT / name).read_bytes()) for name in (
    'SOURCE_RUN_METADATA.json', 'SOURCE_ARTIFACT_METADATA.json', 'SOURCE_JOB_METADATA.json')]
driver.validate_metadata(*metadata, contract)
raw_log = gzip.decompress((ROOT / 'release-native-matrix-driver.log.gz').read_bytes())
assert hashlib.sha256(raw_log).hexdigest() == contract['selectionProvenance']['exportLogSha256']
lines = raw_log.decode().splitlines()
for item in contract['selectedMembers']:
    line = lines[item['exportLogLine'] - 1]
    assert line == 'File: ' + Path(item['path']).name + ', suggested name: "' + item['purpose'] + '"'
    previous = next(line for line in reversed(lines[:item['exportLogLine'] - 1]) if line.startswith('Exported '))
    assert previous.endswith('for: ' + item['caseId'] + '():')
original_workflow = gzip.decompress((ROOT / 'ORIGINAL_RELEASE_WORKFLOW.yml.gz').read_bytes())
assert hashlib.sha1(b'blob ' + str(len(original_workflow)).encode() + b'\0' + original_workflow).hexdigest() == contract['selectionProvenance']['originalWorkflowBlob']
print(json.dumps({'sealed_payloads': len(manifest['files']), 'source_files': len(manifest['source_outputs']),
                  'prior_verified_source_inputs': len(prior['inputs']),
                  'exact_export_mappings': len(contract['selectedMembers']), 'metadata_replay': 'PASS',
                  'full_archive_download': 'NOT_RUN', 'native_executions': 0}, sort_keys=True))
