import pathlib, base64, hashlib, json, zipfile, shutil, subprocess, os, time, signal, traceback

TASK = pathlib.Path('/mnt/development/projects/diagnostics/otzaria-wave3-annotations-selection-20261127')
OWN = TASK / 'attempt-1'
ROOT = pathlib.Path('/home/ubuntu/.codex/worktrees/Maktabah-wave3-integration-rootfs-20261127')
CORE = ROOT / '.git/search-continuation-integrated-controls-20261127'
SWIFT = pathlib.Path('/mnt/development/tooling/swiftly/toolchains/6.4.3/usr/bin/swiftc')
BASE = '37caafcfaa4eb9b7bcfd02857bcb7c3f62daa4be'
DATA_FLOOR = 2147483648
ROOT_FLOOR = 1342177280
CAP = 104857600

def sha(value): return hashlib.sha256(value).hexdigest()
def free(): return shutil.disk_usage(TASK.parent).free
def root_free(): return shutil.disk_usage(ROOT).free
def footprint(): return sum(p.stat().st_blocks * 512 for p in TASK.rglob('*') if p.is_file())
def save(name, value): (OWN / name).write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')
def git(*args):
    return subprocess.run(['git', '-C', str(ROOT), '-c', 'gc.auto=0', '-c', 'maintenance.auto=false', *args], capture_output=True, check=True).stdout

steps = []
def run(name, argv, expected=0):
    if free() <= DATA_FLOOR or root_free() <= ROOT_FLOOR or footprint() >= CAP:
        raise RuntimeError('shared capacity floor or own footprint')
    step = {'name': name, 'argv': list(map(str, argv)), 'started': time.time()}
    steps.append(step)
    with (OWN / (name + '.stdout')).open('wb') as out, (OWN / (name + '.stderr')).open('wb') as err:
        p = subprocess.Popen(list(map(str, argv)), stdout=out, stderr=err, start_new_session=True,
                             env={**os.environ, 'TMPDIR': str(OWN / 'tmp')})
        step['pid'] = p.pid
        step['startTicks'] = pathlib.Path('/proc/' + str(p.pid) + '/stat').read_text().split()[21]
        save('STATUS.json', {'steps': steps})
        deadline = time.monotonic() + 150
        while p.poll() is None:
            if free() < DATA_FLOOR or root_free() < ROOT_FLOOR or footprint() > CAP or time.monotonic() > deadline:
                step['guard'] = 'owned process capacity/deadline'
                os.killpg(p.pid, signal.SIGTERM)
                try: p.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(p.pid, signal.SIGKILL); p.wait()
                break
            time.sleep(.5)
        step.update(exit=p.returncode, finished=time.time(), free=free(), root_free=root_free(), task_bytes=footprint())
        save('STATUS.json', {'steps': steps})
    if expected is not None and p.returncode != expected:
        raise RuntimeError(name + ' exit ' + str(p.returncode))
    return p.returncode

if OWN.exists() or free() < DATA_FLOOR + 80 * 1024 * 1024 or root_free() < ROOT_FLOOR:
    raise RuntimeError('fresh output/capacity precondition')
OWN.mkdir(parents=True)
for name in ['tmp', 'original', 'output', 'module-cache']: (OWN / name).mkdir()
try:
    payload = base64.b64decode(PAYLOAD_B64)
    assert sha(payload) == PAYLOAD_SHA
    (OWN / 'INPUTS.zip').write_bytes(payload)
    with zipfile.ZipFile(OWN / 'INPUTS.zip') as z:
        for name in z.namelist():
            assert not pathlib.PurePosixPath(name).is_absolute() and '..' not in pathlib.PurePosixPath(name).parts
        z.extractall(OWN / 'inputs')
    manifest = json.loads((OWN / 'inputs/INPUTS.json').read_text())
    for row in manifest:
        raw = (OWN / 'inputs' / row['path']).read_bytes()
        assert len(raw) == row['bytes'] and sha(raw) == row['sha256']
    assert sha(SWIFT.read_bytes()) == '39d41b0dc9eba623b0e37cea42c3145720168214ba4349d6fa3bd9db9b1e651a'
    assert sha((CORE / 'RESULT.json').read_bytes()) == 'adade63bed54c1b527e41d0d68f81ac652c6916d878235d82081c20f0f942d96'
    joined = []
    for row in json.loads((CORE / 'INPUTS.json').read_text())['files']:
        if row['path'].startswith('Source/Otzaria/Actions/Sources/OtzariaActionCore/'):
            raw = git('show', BASE + ':' + row['path'])
            assert len(raw) == row['bytes'] and sha(raw) == row['sha256'], row['path']
            joined.append(row)
    assert joined
    products = []
    for name in ['OtzariaActionCore.swiftmodule', 'libOtzariaActionCore.so']:
        path = CORE / 'output' / name
        products.append({'path': str(path), 'bytes': path.stat().st_size, 'sha256': sha(path.read_bytes()), 'use': 'read-only'})
    ui_root = 'Source/Otzaria/UIRouting/Sources/OtzariaUIRouting/'
    ui_paths = [p for p in git('ls-tree', '-r', '--name-only', BASE, '--', ui_root).decode().splitlines() if p.endswith('.swift')]
    ui = []
    for path in ui_paths:
        raw = git('show', BASE + ':' + path); dest = OWN / 'original' / path
        dest.parent.mkdir(parents=True, exist_ok=True); dest.write_bytes(raw); ui.append(dest)
        joined.append({'path': path, 'bytes': len(raw), 'sha256': sha(raw), 'use': 'compiled actual base source'})
    host_root = 'Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/'
    host = []
    for name in ['NativeIntentService.swift', 'NativeIntentOutcome.swift', 'NativeComponentSourceObservation.swift']:
        raw = git('show', BASE + ':' + host_root + name); path = OWN / 'original' / name
        path.write_bytes(raw); host.append(path)
        joined.append({'path': host_root + name, 'bytes': len(raw), 'sha256': sha(raw), 'use': 'compiled actual base source'})
    utility = git('show', BASE + ':' + host_root + 'NativeReaderIntentService.swift').decode()
    expected = 'import Foundation\nimport OtzariaUIRouting\n\n' + utility[utility.index('enum NativeReaderEntityIdentifier {'):]
    assert (OWN / 'inputs/controls/ActualNativeReaderEntityIdentifier.swift').read_text() == expected
    host += [OWN / 'inputs/controls/ActualNativeReaderEntityIdentifier.swift', OWN / 'inputs/candidate' / host_root / 'NativeAnnotationSelectionIntentService.swift']
    output = OWN / 'output'
    base = [SWIFT, '-swift-version', '6', '-strict-concurrency=complete', '-parse-as-library', '-module-cache-path', OWN / 'module-cache']
    core_link = ['-I', CORE / 'output', '-L', CORE / 'output', '-lOtzariaActionCore', '-Xlinker', '-rpath', '-Xlinker', CORE / 'output']
    own_link = ['-I', output, '-L', output, '-lOtzariaUIRouting', '-Xlinker', '-rpath', '-Xlinker', output] + core_link
    run('full-ios-syntax-only', [SWIFT, '-frontend', '-parse', '-target', 'arm64-apple-ios27.0'] + list((OWN / 'inputs/candidate').rglob('*.swift')))
    run('actual-ui-module-compile', base + core_link + ['-emit-library', '-emit-module', '-module-name', 'OtzariaUIRouting'] + ui + ['-o', output / 'libOtzariaUIRouting.so', '-emit-module-path', output / 'OtzariaUIRouting.swiftmodule'])
    run('actual-host-service-compile', base + own_link + ['-emit-library', '-emit-module', '-module-name', 'ChavrusaUIRoutingHost'] + host + ['-o', output / 'libChavrusaUIRoutingHost.so', '-emit-module-path', output / 'ChavrusaUIRoutingHost.swiftmodule'])
    link = ['-lChavrusaUIRoutingHost'] + own_link
    run('service-controls-compile', base + link + [OWN / 'inputs/controls/AnnotationServiceControls.swift', '-o', output / 'service-controls'])
    run('service-controls', [output / 'service-controls'])
    original = OWN / 'inputs/candidate/Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeAnnotationListPublication.swift'
    raw = original.read_text()
    assert raw.startswith('#if os(iOS)\n') and raw.endswith('#endif\n')
    text = raw.removeprefix('#if os(iOS)\n').removesuffix('#endif\n')
    text += '\n// TEST-ONLY exhaustion stimulus; never part of production.\nextension MaktabahNativeAnnotationListPublication { func controlSetRevision(_ value: UInt64) { revision = value } }\n'
    publication = OWN / 'original/ActualPublication.swift'; publication.write_text(text)
    run('publication-controls-compile', base + link + [publication, OWN / 'inputs/controls/ActualSearchSetterCapsule.swift', OWN / 'inputs/controls/PublicationControls.swift', '-o', output / 'publication-controls'])
    run('publication-controls', [output / 'publication-controls'])
    run('original-setter-counterexample-compile', base + link + [publication, OWN / 'inputs/controls/ActualOriginalSearchSetterCapsule.swift', OWN / 'inputs/controls/PublicationControls.swift', '-o', output / 'original-setter-controls'])
    run('original-setter-counterexample', [output / 'original-setter-controls', 'original equal search setter'], expected=1)
    for row in products: assert sha(pathlib.Path(row['path']).read_bytes()) == row['sha256']
    save('RESULT.json', {'status': 'PASS_SOURCE_CONTROLS_ONLY', 'base': BASE, 'steps': steps, 'reused_products': products, 'original_source_join': joined, 'inputs': manifest, 'scope': 'Actual portable service and original UI/Core value contracts; exact publication and original search setter bodies. Explicit navigation/domain boundary; no Core execution, Combine/UIKit/app/Apple/native qualification.', 'task_bytes': footprint(), 'free': free(), 'root_free': root_free()})
except BaseException as error:
    save('RESULT.json', {'status': 'FAILED', 'steps': steps, 'error': repr(error), 'traceback': traceback.format_exc(), 'task_bytes': footprint(), 'free': free(), 'root_free': root_free()})
    raise
finally:
    result = OWN / 'RESULT.json'
    if result.exists():
        value = json.loads(result.read_text())
        print(json.dumps({'path': str(result), 'sha256': sha(result.read_bytes()), 'status': value['status'], 'steps': [{'name': x['name'], 'exit': x.get('exit')} for x in steps]}))
