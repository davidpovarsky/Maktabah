#!/usr/bin/env python3
"""Validate the sealed source-only packet; no Swift, app or Native execution."""
import gzip
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
REPOSITORY = ROOT.parents[2]
manifest = json.loads((ROOT / 'ARTIFACTS.json').read_bytes())
for record in manifest['files']:
    body = (ROOT / record['path']).read_bytes()
    assert len(body) == record['bytes'], record['path']
    assert hashlib.sha256(body).hexdigest() == record['sha256'], record['path']
    if 'uncompressed_sha256' in record:
        raw = gzip.decompress(body)
        assert len(raw) == record['uncompressed_bytes'], record['path']
        assert hashlib.sha256(raw).hexdigest() == record['uncompressed_sha256'], record['path']
for record in manifest['source_outputs']:
    body = (REPOSITORY / record['path']).read_bytes()
    assert len(body) == record['bytes'], record['path']
    assert hashlib.sha256(body).hexdigest() == record['sha256'], record['path']
    assert hashlib.sha1(b'blob ' + str(len(body)).encode() + b'\0' + body).hexdigest() == record['gitBlob'], record['path']
subprocess.run([sys.executable, str(ROOT / 'verify_source.py')], check=True, timeout=30)
print(json.dumps({'sealed_documents': len(manifest['files']),
                  'candidate_source_files': len(manifest['source_outputs']),
                  'source_base': manifest['source_base'],
                  'swift_apple_native': 'NOT_RUN'}, sort_keys=True))
