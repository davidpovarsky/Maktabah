#!/usr/bin/env python3
"""Durable off-host handshake for the two exact authorized Mac roots."""
from pathlib import Path
import base64
import hashlib
import json
import os
import shlex
import shutil
import subprocess
import sys

ROOT = Path(r'C:\Users\DAVID\.codex\artifacts\otzaria-wave3-covered-scopes-preservation-20261127')
RESERVE = 2415919104


def save(path, raw):
    assert shutil.disk_usage(str(ROOT)).free - len(raw) >= RESERVE
    with path.open('xb') as f:
        f.write(raw); f.flush(); os.fsync(f.fileno())


def main(expected_manifest, expected_proof):
    body = (ROOT / 'covered_scopes.py').read_bytes()
    body_sha = hashlib.sha256(body).hexdigest()
    manifest = (ROOT / 'MANIFEST.json').read_bytes()
    proof = (ROOT / 'VERIFIED_PRESERVATION.json').read_bytes()
    assert hashlib.sha256(manifest).hexdigest() == expected_manifest
    assert hashlib.sha256(proof).hexdigest() == expected_proof
    assert json.loads(manifest)['script_sha256'] == body_sha
    assert json.loads(proof)['manifest_sha256'] == expected_manifest
    assert shutil.disk_usage(str(ROOT)).free - 16 * 1024**2 >= RESERVE
    source = 'EXECUTED_SCRIPT_SHA256 = ' + repr(body_sha) + '\n' + body.decode()
    command = '/usr/bin/python3 -c ' + shlex.quote(source) + ' retire'
    envelope = {'manifest_base64': base64.b64encode(manifest).decode(), 'manifest_sha256': expected_manifest,
                'proof_base64': base64.b64encode(proof).decode(), 'proof_sha256': expected_proof}
    with (ROOT / 'RETIREMENT.stderr').open('xb') as errors:
        p = subprocess.Popen(['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=8', 'scaleway-mac', command],
                             stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=errors)
        p.stdin.write((json.dumps(envelope) + '\n').encode()); p.stdin.flush()
        first = p.stdout.readline(8 * 1024**2)
        if not first:
            code = p.wait(timeout=20)
            raise RuntimeError('Mac emitted no pre-delete receipt; exit=' + str(code))
        before = json.loads(first)
        assert before['status'] == 'TWO_EXACT_SCOPES_FULLY_REVERIFIED_AWAITING_DURABLE_ACK'
        assert before['manifest_sha256'] == expected_manifest and before['windows_proof_sha256'] == expected_proof
        assert not before['anything_deleted'] and before['roots'] == json.loads(manifest)['roots']
        save(ROOT / 'RETIREMENT_PREDELETE.json', first)
        ack = {'ack': 'DURABLE_PREDELETE_RECORD', 'sha256': hashlib.sha256(first).hexdigest(),
               'manifest_sha256': expected_manifest, 'proof_sha256': expected_proof}
        p.stdin.write((json.dumps(ack) + '\n').encode()); p.stdin.flush(); p.stdin.close()
        final = p.stdout.readline(8 * 1024**2)
        if final: save(ROOT / 'RETIREMENT_RESULT.json', final)
        code = p.wait(timeout=30)
    assert final, 'No final receipt; inspect exact target existence before any retry'
    result = json.loads(final)
    print(json.dumps({'exit': code, 'path': str(ROOT / 'RETIREMENT_RESULT.json'), 'bytes': len(final),
                      'sha256': hashlib.sha256(final).hexdigest(),
                      'predelete_sha256': hashlib.sha256(first).hexdigest(),
                      'result': {k: v for k, v in result.items() if k not in ('protected_before', 'protected_after')}}))
    assert code == 0 and result['status'] == 'RETIRED_ONLY_TWO_EXACT_FULLY_PRESERVED_SCOPES'


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
