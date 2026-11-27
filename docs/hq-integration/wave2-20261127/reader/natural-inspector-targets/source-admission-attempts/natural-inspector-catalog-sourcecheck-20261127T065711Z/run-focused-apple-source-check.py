#!/usr/bin/env python3
"""One reserved source-only Apple compile/typecheck; no binary or UI execution."""
import datetime
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parent
INPUT = json.loads((ROOT / 'INPUT.json').read_bytes())
CORE = Path('/Users/m1/builds/otzaria-wave2-library-controls-20261127/inspector-generation-attempt-2/kit/Sources/TorahInspectorCore')
CACHE = ROOT / 'module-cache'
RESULT = {'schema': 1, 'status': 'ADMISSION_PENDING_NOT_COMPILED', 'steps': [],
    'sourceCommit': INPUT['sourceCommit'], 'sourceHashes': INPUT['sourceHashes'],
    'uiExecuted': 0, 'catalogExecuted': 0,
    'scope': 'Complete original Core and database services compile; whole registered Faithful XCTest typecheck. No app/SDK build, corpus read, simulator or native UI.'}

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def save():
    (ROOT / 'RESULT.json').write_text(json.dumps(RESULT, indent=2) + '\n')

def run(name, args, timeout=240):
    before = time.monotonic()
    result = subprocess.run(args, cwd=ROOT, capture_output=True, timeout=timeout)
    out, err = ROOT / (name + '.stdout.log'), ROOT / (name + '.stderr.log')
    out.write_bytes(result.stdout); err.write_bytes(result.stderr)
    RESULT['steps'].append({'name': name, 'command': args, 'exit': result.returncode,
        'seconds': time.monotonic() - before, 'stdoutSHA256': digest(out), 'stderrSHA256': digest(err)})
    save()
    if CACHE.exists():
        used = int(subprocess.check_output(['/usr/bin/du', '-sk', str(CACHE)]).split()[0]) * 1024
        RESULT['cacheAllocatedBytes'] = used; save()
        assert used <= 300 * 1024 * 1024, 'Stop at the specifically reserved 300 MiB cache bound'
    assert result.returncode == 0, name

try:
    assert ROOT.resolve(strict=True) == ROOT and not CACHE.exists()
    RESULT['freeBytesBefore'] = shutil.disk_usage(ROOT).free
    assert RESULT['freeBytesBefore'] > 4 * 1024**3, 'No claim on other owners reserved SDK space'
    process_output = subprocess.check_output(['/bin/ps', '-ww', '-axo', 'pid=,ppid=,command='], text=True)
    (ROOT / 'actual-process-admission.txt').write_text(process_output)
    active = []
    for line in process_output.splitlines():
        if 'run-focused-apple-source-check.py' in line: continue
        fields = line.split(None, 2)
        command = fields[2] if len(fields) == 3 else ''
        executable = Path(command.split(None, 1)[0]).name if command else ''
        if executable in {'xcodebuild', 'swift-build', 'swift-frontend', 'swiftc', 'clang', 'clang++',
                'cmake', 'ninja', 'make', 'metal', 'metallib', 'xctrace'}:
            active.append(line)
        elif executable == 'xcrun' and re.search(r'\b(swiftc|swift-frontend|clang|metal|xctrace)\b', command):
            active.append(line)
    RESULT['activeBuildAdmissionMatches'] = active
    assert not active, 'Another SDK/App/compiler process is active; do not consume its reservation'
    for name, expected in INPUT['sourceHashes'].items():
        assert digest(ROOT / name) == expected, name
    manifest = json.loads((ROOT / 'TORAH_INSPECTOR_CORE_CANONICAL_BLOBS.json').read_bytes())
    assert manifest['commit'] == '23db0f84e88d9ee9c7053c49de86903fc7bb5785'
    core_sources = []
    for name, expected in sorted(manifest['sources'].items()):
        path = CORE / Path(name).name; data = path.read_bytes()
        assert digest(path) == expected['sha256'] and len(data) == expected['bytes']
        assert hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\x00' + data).hexdigest() == expected['gitBlob']
        core_sources.append(str(path))
    RESULT['actualCoreSources'] = {p: digest(Path(p)) for p in core_sources}
    RESULT['status'] = 'ADMITTED_SOURCE_CHECKS_RUNNING'; save()
    run('xcode-version', ['xcodebuild', '-version'], timeout=20)
    run('swift-version', ['xcrun', 'swiftc', '--version'], timeout=20)
    mac = subprocess.check_output(['xcrun', '--sdk', 'macosx', '--show-sdk-path'], text=True).strip()
    ios = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True).strip()
    platform = str(Path(ios).parents[2])
    RESULT['sdk'] = {'macOS': mac, 'iOSSimulator': ios}
    flags = ['-parse-as-library', '-swift-version', '6', '-Xfrontend', '-strict-concurrency=complete',
        '-sdk', mac, '-module-cache-path', str(CACHE)]
    run('pinned-core-compile', ['xcrun', 'swiftc'] + flags + ['-emit-module', '-emit-library', '-module-name', 'TorahInspectorCore']
        + core_sources + ['-emit-module-path', str(ROOT / 'TorahInspectorCore.swiftmodule'),
            '-Xlinker', '-install_name', '-Xlinker', str(ROOT / 'libTorahInspectorCore.dylib'),
            '-o', str(ROOT / 'libTorahInspectorCore.dylib')])
    zstd = (Path(subprocess.check_output(['brew', '--prefix', 'zstd'], text=True).strip()) / 'lib/libzstd.dylib').resolve(strict=True)
    RESULT['zstd'] = {'path': str(zstd), 'sha256': digest(zstd)}
    run('whole-original-services-catalog-compile', ['xcrun', 'swiftc'] + flags + ['-O', '-I', str(ROOT),
        '-L', str(ROOT), '-lTorahInspectorCore', '-L', str(zstd.parent), '-lzstd',
        '-Xlinker', '-rpath', '-Xlinker', str(zstd.parent)]
        + [str(ROOT / p) for p in INPUT['compiledSourcePaths']]
        + [str(ROOT / 'OriginalMaktabahTorahInspectorFormatting.swift'), str(ROOT / 'FullV40InspectorNaturalTargets.swift'), '-o', str(ROOT / 'original-natural-inspector-catalog')])
    run('whole-faithful-xctest-typecheck', ['xcrun', 'swiftc', '-parse-as-library', '-typecheck', '-swift-version', '6',
        '-D', 'DEBUG', '-Xfrontend', '-strict-concurrency=complete', '-module-cache-path', str(CACHE),
        '-sdk', ios, '-target', 'arm64-apple-ios27.0-simulator',
        '-F', platform + '/Developer/Library/Frameworks', '-I', platform + '/Developer/usr/lib',
        str(ROOT / 'MaktabahUITestBase.swift'), str(ROOT / 'FaithfulReaderUIAcceptanceTests.swift')])
    for name, expected in INPUT['sourceHashes'].items(): assert digest(ROOT / name) == expected
    for name, expected in RESULT['actualCoreSources'].items(): assert digest(Path(name)) == expected
    RESULT['binaries'] = {p.name: {'path': str(p), 'sha256': digest(p), 'bytes': p.stat().st_size}
        for p in [ROOT / 'original-natural-inspector-catalog', ROOT / 'libTorahInspectorCore.dylib']}
    RESULT['status'] = 'SOURCE_COMPILE_AND_WHOLE_XCTEST_TYPECHECK_PASS_NOT_NATIVE_ACCEPTANCE'
except Exception as error:
    RESULT['status'] = 'SOURCE_CHECK_STOPPED_OR_FAILED_NO_NATIVE_ACCEPTANCE'
    RESULT['error'] = repr(error)
finally:
    RESULT['freeBytesAfter'] = shutil.disk_usage(ROOT).free
    RESULT['finishedUTC'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    save()
    print(json.dumps({'status': RESULT['status'], 'directory': str(ROOT), 'error': RESULT.get('error')}), flush=True)
