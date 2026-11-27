#!/usr/bin/env python3
"""Binary pipe only: fixed owned Mac source to fixed authorized Oracle sink."""
from pathlib import Path
import datetime
import hashlib
import json
import os
import shlex
import shutil
import subprocess
import threading
import time

ROOT = Path(r'C:\Users\DAVID\.codex\artifacts\otzaria-wave3-session-pair-preservation-20261127')
MAC = '/Users/m1/builds/otzaria-wave3-session-pair-preservation-20261127.dnwtgpgc'
ORACLE = '/mnt/development/projects/diagnostics/otzaria-wave3-session-pair-preservation-20261127'
HEADER_SHA = 'ce9ebccb6c36704448b659ee5354c44391e514a78f4df08073326eff18e6cf3b'
RECEIVER_SHA = '597683bca42bf9b4b82ff173f3a991c15b9cba949a8e749d45301bbad0353710'
RESERVE = 2415919104
SSH = ['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=8']


def utc(): return datetime.datetime.now(datetime.timezone.utc).isoformat()


def save(name, raw):
    if not isinstance(raw, bytes): raw = (json.dumps(raw, sort_keys=True) + '\n').encode()
    assert shutil.disk_usage(ROOT).free - len(raw) >= RESERVE
    with (ROOT / name).open('xb') as f:
        f.write(raw); f.flush(); os.fsync(f.fileno())
    return {'path': str(ROOT / name), 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}


class Drain(threading.Thread):
    def __init__(self, pipe):
        super().__init__(daemon=True); self.pipe = pipe; self.parts = []; self.count = 0; self.error = None
    def run(self):
        try:
            for block in iter(lambda: self.pipe.read(65536), b''):
                self.count += len(block)
                if self.count > 4 * 1024**2: raise RuntimeError('Unexpected bridge diagnostic volume')
                self.parts.append(block)
        except BaseException as error: self.error = repr(error)
    def output(self):
        self.join(30); assert not self.is_alive() and self.error is None, self.error
        return b''.join(self.parts)


def main():
    ROOT.mkdir(exist_ok=False)
    started = time.monotonic(); free_before = shutil.disk_usage(ROOT).free
    assert free_before >= RESERVE + 1024**2
    save('bridge_windows.py', Path(__file__).read_bytes())
    preflight_code = ("from pathlib import Path;import hashlib,shutil,json;"
                      "p=Path(" + repr(ORACLE + '/oracle_receiver_verify.py') + ");"
                      "assert hashlib.sha256(p.read_bytes()).hexdigest()==" + repr(RECEIVER_SHA) + ";"
                      "assert not(p.parent/'session-pair-differential.tar.gz').exists();"
                      "assert not(p.parent/'session-pair-differential.tar.gz.partial').exists();"
                      "print(json.dumps({'receiver_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'free':shutil.disk_usage(p.parent).free}))")
    check = subprocess.run(SSH + ['torah-social', '/usr/bin/python3 -c ' + shlex.quote(preflight_code)], capture_output=True, timeout=30)
    save('ORACLE_PREFLIGHT_STDOUT.json', check.stdout); save('ORACLE_PREFLIGHT_STDERR.txt', check.stderr)
    assert check.returncode == 0, check.stderr.decode(errors='replace')
    destination = subprocess.Popen(SSH + ['torah-social', '/usr/bin/python3 ' + shlex.quote(ORACLE + '/oracle_receiver_verify.py') + ' receive'],
                                   stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    source = subprocess.Popen(SSH + ['scaleway-mac', '/usr/bin/python3 ' + shlex.quote(MAC + '/session_pair.py')
                                    + ' stream ' + shlex.quote(MAC) + ' ' + HEADER_SHA],
                              stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    src_error = Drain(source.stderr); dst_output = Drain(destination.stdout); dst_error = Drain(destination.stderr)
    for thread in (src_error, dst_output, dst_error): thread.start()
    digest = hashlib.sha256(); count = 0; failure = None
    try:
        while True:
            block = source.stdout.read(1024**2)
            if not block: break
            assert destination.poll() is None, 'Oracle receiver exited while source is streaming'
            destination.stdin.write(block); digest.update(block); count += len(block)
        destination.stdin.close()
        source_code = source.wait(timeout=60); destination_code = destination.wait(timeout=60)
        stdout = dst_output.output(); stderr = dst_error.output(); source_stderr = src_error.output()
        save('RECEIVER_STDOUT.json', stdout); save('RECEIVER_STDERR.txt', stderr); save('SOURCE_STDERR.txt', source_stderr)
        assert source_code == destination_code == 0, (source_code, destination_code)
        receiver = json.loads(stdout)
        assert receiver['archive_bytes'] == count and receiver['archive_sha256'] == digest.hexdigest()
        read = subprocess.run(SSH + ['scaleway-mac', '/bin/cat ' + shlex.quote(MAC + '/STREAM_RESULT.json')],
                              capture_output=True, timeout=30)
        save('STREAM_RESULT.json', read.stdout); save('STREAM_READBACK_STDERR.txt', read.stderr)
        assert read.returncode == 0
        produced = json.loads(read.stdout)
        assert produced['header_sha256'] == HEADER_SHA
        assert produced['archive_bytes'] == count and produced['archive_sha256'] == digest.hexdigest()
        result = {'status': 'MAC_ORACLE_BINARY_STREAM_HASHES_EQUAL_NOT_YET_MEMBER_VERIFIED', 'utc': utc(),
                  'source': MAC, 'destination': receiver['archive'], 'archive_bytes': count,
                  'archive_sha256': digest.hexdigest(), 'header_sha256': HEADER_SHA,
                  'source_exit': source_code, 'destination_exit': destination_code,
                  'receiver_sha256': RECEIVER_SHA, 'windows_large_staging_bytes': 0,
                  'windows_free_before': free_before, 'windows_free_after': shutil.disk_usage(ROOT).free,
                  'oracle_free_after': receiver['free_after'], 'seconds': time.monotonic() - started,
                  'anything_deleted': False, 'native_acceptance': 0}
        result['receipt'] = save('BRIDGE_RESULT.json', result)
        print(json.dumps(result))
    except BaseException as error:
        failure = error
        try: destination.stdin.close()
        except Exception: pass
        # Only this invocation's own SSH transfer processes; never host jobs.
        for process in (source, destination):
            if process.poll() is None: process.terminate()
        for process in (source, destination):
            try: process.wait(timeout=30)
            except subprocess.TimeoutExpired: pass
        result = {'status': 'PAIR_STREAM_FAILED_SOURCES_NOT_RETIRED', 'utc': utc(),
                  'error': repr(error), 'bytes_piped': count, 'prefix_sha256': digest.hexdigest(),
                  'source_exit': source.poll(), 'destination_exit': destination.poll(),
                  'source_stderr': src_error.output().decode(errors='replace'),
                  'destination_stderr': dst_error.output().decode(errors='replace'),
                  'destination_stdout': dst_output.output().decode(errors='replace'), 'anything_deleted': False}
        save('BRIDGE_FAILURE.json', result); print(json.dumps(result))
        raise


if __name__ == '__main__': main()
