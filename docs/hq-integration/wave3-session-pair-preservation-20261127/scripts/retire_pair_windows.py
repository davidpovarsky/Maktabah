#!/usr/bin/env python3
"""Current archive checks and durable ACK for ONLY the authorized fixed pair."""
from pathlib import Path
import base64
import datetime
import hashlib
import json
import os
import shlex
import shutil
import subprocess
import threading

ROOT = Path(r'C:\Users\DAVID\.codex\artifacts\otzaria-wave3-session-pair-preservation-20261127')
MAC = '/Users/m1/builds/otzaria-wave3-session-pair-preservation-20261127.dnwtgpgc'
ORACLE = '/mnt/development/projects/diagnostics/otzaria-wave3-session-pair-preservation-20261127'
SOURCE_ROOTS = [
    '/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl/session.ftqrs4Ju',
    '/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl/session.e9xp5UCf',
]
PROOF_SHA = '313e1e60aa516ae218bf709e8d106e7c5b8c64b8a72a61136a78394913e5909d'
SOURCE_SHA = '5834032a8d367869ccb57a251ce89c8da1daf3c8a32fae944063621b3263c2ae'
NEW_VERIFIED_SHA = '8ec65743855d522d25f7e8b63c71d24c472b7087b3ca3c061d7529faf6e791e3'
MAC_SCRIPT_SHA = 'c804523a661d55f29a62839e9fe6036cf03a01549838d25cf1ed539080c9255d'
RESERVE = 2415919104
SSH = ['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=8']


def utc(): return datetime.datetime.now(datetime.timezone.utc).isoformat()
def canonical(value): return (json.dumps(value, sort_keys=True, separators=(',', ':')) + '\n').encode()


def digest(p):
    h = hashlib.sha256()
    with p.open('rb') as f:
        for b in iter(lambda: f.read(1024**2), b''): h.update(b)
    return h.hexdigest()


def identity(p):
    assert not p.is_symlink()
    s = p.stat()
    return {'device': s.st_dev, 'inode': s.st_ino, 'bytes': s.st_size,
            'mtime_ns': s.st_mtime_ns, 'ctime_ns': s.st_ctime_ns}


def save(name, raw):
    if not isinstance(raw, bytes): raw = canonical(raw)
    assert shutil.disk_usage(ROOT).free - len(raw) >= RESERVE
    p = ROOT / name
    with p.open('xb') as f:
        f.write(raw); f.flush(); os.fsync(f.fileno())
    assert p.read_bytes() == raw
    return {'path': str(p), 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}


def oracle_current():
    code = '''from pathlib import Path
import hashlib,json,datetime
root=Path(ORACLE_ROOT)
def read(name,sha):
 p=root/name;b=p.read_bytes();assert hashlib.sha256(b).hexdigest()==sha;return json.loads(b)
p=read('COMPLETE_PRESERVATION_VERIFIED.json',PROOF_PIN)
s=read('SOURCE_REVERIFIED.json',SOURCE_PIN)
v=read('NEW_ARCHIVE_VERIFIED.json',VERIFIED_PIN)
a=Path(p['new_archive']);assert a.resolve()==a and not a.is_symlink() and a.is_file()
t=a.stat();actual={'device':t.st_dev,'inode':t.st_ino,'bytes':t.st_size,'mtime_ns':t.st_mtime_ns,'ctime_ns':t.st_ctime_ns}
assert actual==v['archive_identity']
assert p['new_archive_sha256']==v['archive_sha256'] and p['new_archive_bytes']==v['archive_bytes']
assert s['complete_preservation_receipt_sha256']==PROOF_PIN
print(json.dumps({'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'archive':str(a),'archive_sha256':p['new_archive_sha256'],'archive_bytes':p['new_archive_bytes'],'archive_identity':actual,'new_archive_verification_sha256':VERIFIED_PIN,'complete_preservation_sha256':PROOF_PIN,'source_reverified_sha256':SOURCE_PIN,'scope':'Current archive identity equals the actual full member/hash verification receipt; original full SHA is retained, not newly recomputed.'}))
'''
    code = 'ORACLE_ROOT=' + repr(ORACLE) + '\nPROOF_PIN=' + repr(PROOF_SHA) + '\nSOURCE_PIN=' + repr(SOURCE_SHA) + '\nVERIFIED_PIN=' + repr(NEW_VERIFIED_SHA) + '\n' + code
    result = subprocess.run(SSH + ['torah-social', '/usr/bin/python3 -c ' + shlex.quote(code)], capture_output=True, timeout=30)
    save('RETIREMENT_ORACLE_CURRENT_STDOUT.json', result.stdout)
    save('RETIREMENT_ORACLE_CURRENT_STDERR.txt', result.stderr)
    assert result.returncode == 0, result.stderr.decode(errors='replace')
    return json.loads(result.stdout)


def oracle_receipt(name, raw):
    assert name in ('RETIREMENT_PREDELETE.json', 'RETIREMENT_RESULT.json')
    expected = hashlib.sha256(raw).hexdigest()
    code = ("from pathlib import Path;import sys,hashlib,shutil,os,json;"
            "p=Path(" + repr(ORACLE + '/' + name) + ");b=sys.stdin.buffer.read(1024*1024);"
            "assert hashlib.sha256(b).hexdigest()==" + repr(expected) + ";"
            "assert shutil.disk_usage(p.parent).free-len(b)>=687865856;"
            "f=p.open('xb');f.write(b);f.flush();os.fsync(f.fileno());f.close();"
            "assert hashlib.sha256(p.read_bytes()).hexdigest()==" + repr(expected) + ";"
            "print(json.dumps({'path':str(p),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}))")
    result = subprocess.run(SSH + ['torah-social', '/usr/bin/python3 -c ' + shlex.quote(code)],
                            input=raw, capture_output=True, timeout=30)
    save(name + '.oracle-copy.json', result.stdout)
    assert result.returncode == 0, result.stderr.decode(errors='replace')


def main():
    proof_raw = (ROOT / 'COMPLETE_PRESERVATION_VERIFIED.json').read_bytes()
    source_raw = (ROOT / 'SOURCE_REVERIFIED.json').read_bytes()
    assert hashlib.sha256(proof_raw).hexdigest() == PROOF_SHA
    assert hashlib.sha256(source_raw).hexdigest() == SOURCE_SHA
    proof, source = json.loads(proof_raw), json.loads(source_raw)
    assert source['roots'] == SOURCE_ROOTS
    for row in proof['archive_bindings']:
        archive = Path(row['archive']); manifest = Path(row['manifest']); receipt = Path(row['full_member_receipt'])
        assert identity(archive) == row['archive_identity']
        assert identity(manifest) == row['manifest_identity']
        assert identity(receipt) == row['full_member_receipt_identity']
        assert digest(receipt) == row['full_member_receipt_sha256']
    current = {'status': 'ALL_CURRENT_ARCHIVE_AND_RECEIPT_IDENTITIES_MATCH', 'utc': utc(),
               'roots': SOURCE_ROOTS, 'complete_preservation_sha256': PROOF_SHA,
               'source_reverified_sha256': SOURCE_SHA, 'archive_bindings': proof['archive_bindings'],
               'new_archive': oracle_current(), 'windows_driver_sha256': digest(Path(__file__)),
               'scope': 'Current physical archive/manifest/receipt identities compared to full verified receipts; immutable whole-archive hashes retained.',
               'anything_deleted': False}
    current['utc'] = utc()
    current_raw = canonical(current); current_pin = save('RETIREMENT_CURRENT_BINDINGS.json', current_raw)
    check_code = ("from pathlib import Path;import hashlib;p=Path(" + repr(MAC + '/retire_pair.py')
                  + ");assert hashlib.sha256(p.read_bytes()).hexdigest()==" + repr(MAC_SCRIPT_SHA))
    checked = subprocess.run(SSH + ['scaleway-mac', '/usr/bin/python3 -c ' + shlex.quote(check_code)], capture_output=True, timeout=30)
    assert checked.returncode == 0, checked.stderr.decode(errors='replace')
    envelope = {'proof_base64': base64.b64encode(proof_raw).decode(),
                'source_base64': base64.b64encode(source_raw).decode(),
                'current_base64': base64.b64encode(current_raw).decode(), 'current_sha256': current_pin['sha256']}
    process = subprocess.Popen(SSH + ['scaleway-mac', '/usr/bin/python3 ' + shlex.quote(MAC + '/retire_pair.py')],
                               stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    errors = []
    def drain():
        for block in iter(lambda: process.stderr.read(65536), b''): errors.append(block)
    thread = threading.Thread(target=drain, daemon=True); thread.start()
    process.stdin.write(canonical(envelope)); process.stdin.flush()
    first = process.stdout.readline(1024**2)
    if not first:
        process.stdin.close(); code = process.wait(timeout=30); thread.join(30)
        failure = {'status': 'MAC_PREDELETE_CHECK_FAILED_WITHOUT_ACK', 'utc': utc(), 'exit': code,
                   'stderr': b''.join(errors).decode(errors='replace'), 'anything_deleted': False}
        save('RETIREMENT_PREDELETE_FAILURE.json', failure)
        raise RuntimeError(failure)
    pre = json.loads(first)
    assert pre['status'] == 'EXACT_PAIR_CURRENT_STATE_VERIFIED_AWAITING_DURABLE_OFFHOST_ACK'
    assert pre['roots'] == SOURCE_ROOTS and not pre['anything_deleted']
    assert pre['complete_preservation_sha256'] == PROOF_SHA and pre['source_reverified_sha256'] == SOURCE_SHA
    assert pre['current_archive_bindings_sha256'] == current_pin['sha256']
    assert pre['script_sha256'] == MAC_SCRIPT_SHA
    pin = save('RETIREMENT_PREDELETE.json', first)
    oracle_receipt('RETIREMENT_PREDELETE.json', first)
    ack = {'ack': 'DURABLE_OFFHOST_EXACT_PAIR_PREDELETE', 'sha256': pin['sha256'],
           'complete_preservation_sha256': PROOF_SHA, 'source_reverified_sha256': SOURCE_SHA,
           'current_archive_bindings_sha256': current_pin['sha256']}
    save('RETIREMENT_ACK.json', ack)
    process.stdin.write(canonical(ack)); process.stdin.flush(); process.stdin.close()
    final_raw = process.stdout.read(); code = process.wait(timeout=60); thread.join(30)
    save('RETIREMENT_STDERR.txt', b''.join(errors))
    final_pin = save('RETIREMENT_RESULT.json', final_raw)
    oracle_receipt('RETIREMENT_RESULT.json', final_raw)
    result = json.loads(final_raw)
    assert code == 0 and result['status'] == 'RETIRED_ONLY_EXACT_FULLY_PRESERVED_SESSION_PAIR'
    assert result['removed'] == SOURCE_ROOTS and result['full_absence_verified'] and result['protected_identities_unchanged']
    print(json.dumps({'status': result['status'], 'removed': result['removed'], 'receipt': final_pin,
                      'predelete': pin, 'oracle_receipt': ORACLE + '/RETIREMENT_RESULT.json',
                      'free_before': result['free_before'], 'free_after': result['free_after'],
                      'concurrent_free_delta_bytes': result['concurrent_free_delta_bytes'],
                      'protected_identities_unchanged': True, 'full_absence_verified': True,
                      'native_acceptance': 0, 'sdk_retry': False}))


if __name__ == '__main__': main()
