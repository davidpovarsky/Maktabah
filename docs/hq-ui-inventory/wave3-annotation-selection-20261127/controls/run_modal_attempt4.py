import pathlib, base64, hashlib, json, zipfile, shutil, subprocess, os, time, signal, traceback

TASK = pathlib.Path('/mnt/development/projects/diagnostics/otzaria-wave3-annotations-selection-20261127')
OWN = TASK / 'attempt-4'
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
    prior = TASK / 'attempt-1'
    assert sha((prior / 'RESULT.json').read_bytes()) == 'c6319e70da38ad3751f46a104d6d9d4a6c4f277062cbb7fe2aea48952eccfd57'
    prior_result = json.loads((prior / 'RESULT.json').read_text())
    assert any(x['name'] == 'service-controls' and x['exit'] == 0 for x in prior_result['steps'])
    host_root = 'Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/'
    assert (prior / 'inputs/candidate' / host_root / 'NativeAnnotationSelectionIntentService.swift').read_bytes() == (OWN / 'inputs/candidate' / host_root / 'NativeAnnotationSelectionIntentService.swift').read_bytes()
    for path in (prior / 'original/Source/Otzaria/UIRouting/Sources/OtzariaUIRouting').rglob('*.swift'):
        rel = str(path.relative_to(prior / 'original'))
        assert git('show', BASE + ':' + rel) == path.read_bytes()
        joined.append({'path': rel, 'bytes': path.stat().st_size, 'sha256': sha(path.read_bytes()), 'use': 'read-only actual attempt1 compiled source'})
    for name in ['NativeIntentService.swift','NativeIntentOutcome.swift','NativeComponentSourceObservation.swift']:
        assert git('show',BASE + ':' + host_root + name) == (prior / 'original' / name).read_bytes()
    for name in ['OtzariaUIRouting.swiftmodule','libOtzariaUIRouting.so','ChavrusaUIRoutingHost.swiftmodule','libChavrusaUIRoutingHost.so']:
        path = prior / 'output' / name
        products.append({'path':str(path),'bytes':path.stat().st_size,'sha256':sha(path.read_bytes()),'use':'read-only actual attempt1 compiled source; 11 service controls passed'})
    output = OWN / 'output'
    base = [SWIFT,'-swift-version','6','-strict-concurrency=complete','-parse-as-library','-module-cache-path',prior / 'module-cache']
    link = ['-I',prior / 'output','-L',prior / 'output','-lChavrusaUIRoutingHost','-lOtzariaUIRouting','-Xlinker','-rpath','-Xlinker',prior / 'output','-I',CORE / 'output','-L',CORE / 'output','-lOtzariaActionCore','-Xlinker','-rpath','-Xlinker',CORE / 'output']
    run('full-ios-syntax-only',[SWIFT,'-frontend','-parse','-target','arm64-apple-ios27.0'] + list((OWN / 'inputs/candidate').rglob('*.swift')))
    shared = []
    changes = json.loads((OWN / 'inputs/proposal/shared/EXACT_SHARED_EDITS.json').read_text())
    for row in changes['files']:
        raw = git('show',BASE + ':' + row['path']); assert sha(raw) == row['before_sha256']
        current = raw.decode()
        for e in changes['edits']:
            if e['path'] == row['path']:
                assert current.count(e['before']) == e['occurrences']
                current = current.replace(e['before'],e['after'])
        assert sha(current.encode()) == row['after_sha256']
        dest = OWN / 'original/shared' / row['path']; dest.parent.mkdir(parents=True,exist_ok=True); dest.write_text(current); shared.append(dest)
    run('full-shared-ios-syntax-only',[SWIFT,'-frontend','-parse','-target','arm64-apple-ios27.0'] + shared)
    controls = [OWN / 'inputs/controls' / name for name in ['ExplicitAnnotationModalBoundary.swift','ActualClosedPublication.swift','AnnotationModalControls.swift']]
    candidate = OWN / 'inputs/controls/ActualAnnotationSessionCapsule.swift'
    run('actual-modal-controls-compile',base + link + controls + [candidate,'-o',output / 'modal-controls'])
    run('actual-modal-controls',[output / 'modal-controls'])
    historical = OWN / 'inputs/controls/OldHistoryCallerWithNewAnnotationFacet.swift'
    run('old-caller-new-facet-compile',base + link + controls + [historical,'-o',output / 'old-caller-controls'])
    run('old-caller-annotations-aba',[output / 'old-caller-controls','actual will callback detects'],expected=1)
    for row in products: assert sha(pathlib.Path(row['path']).read_bytes()) == row['sha256']
    save('RESULT.json', {'status': 'PASS_SOURCE_CONTROLS_ONLY', 'base': BASE, 'steps': steps, 'reused_products': products, 'original_source_join': joined, 'inputs': manifest, 'scope': 'Actual modal publication/read helper/full History window capture/full unmount and original List binding setter; actual closed RN publisher with explicit constant app/UIKit/domain boundaries. Old-caller counterexample combines verbatim historical capture with new facet, not a historical whole-app run. No Core/app/native execution.', 'task_bytes': footprint(), 'free': free(), 'root_free': root_free()})
except BaseException as error:
    save('RESULT.json', {'status': 'FAILED', 'steps': steps, 'error': repr(error), 'traceback': traceback.format_exc(), 'task_bytes': footprint(), 'free': free(), 'root_free': root_free()})
    raise
finally:
    result = OWN / 'RESULT.json'
    if result.exists():
        value = json.loads(result.read_text())
        print(json.dumps({'path': str(result), 'sha256': sha(result.read_bytes()), 'status': value['status'], 'steps': [{'name': x['name'], 'exit': x.get('exit')} for x in steps]}))
