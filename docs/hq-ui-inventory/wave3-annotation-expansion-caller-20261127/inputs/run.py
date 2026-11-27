import pathlib, base64, hashlib, json, zipfile, shutil, subprocess, os, time, signal, traceback

TASK = pathlib.Path('/mnt/development/projects/diagnostics/otzaria-wave3-annotations-selection-20261127')
OWN = TASK / 'caller-followup-attempt-1'
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
    original_root = git('show',BASE + ':Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSearchEntry.swift').decode()
    first = original_root.index('@MainActor\nfinal class MaktabahNativeRootPublicationSource'); last = original_root.index('/// Expected publications',first)
    assert (OWN / 'inputs/controls/ActualOriginalRootPublication.swift').read_text() == 'import Foundation\n\n' + original_root[first:last].rstrip() + '\n'
    caller_proof = json.loads((OWN / 'inputs/SOURCE_INVERSE.json').read_text())
    actual_old_caller = subprocess.run(['git','-C','/home/ubuntu/otzaria-wave3-annotation-expansion-published-20261127/source','-c','gc.auto=0','-c','maintenance.auto=false','show',caller_proof['base'] + ':' + caller_proof['path']],capture_output=True,check=True).stdout
    assert sha(actual_old_caller) == caller_proof['before_sha256']
    actual_candidate = (OWN / 'inputs/candidate' / caller_proof['path']).read_text()
    assert sha(actual_candidate.encode()) == caller_proof['after_sha256']
    assert actual_candidate.replace(caller_proof['after'],caller_proof['before']).encode() == actual_old_caller
    def exact_method(source, signature):
        start = source.index(signature); cursor = source.index('{',start)+1; depth=1
        while depth:
            depth += (source[cursor]=='{')-(source[cursor]=='}'); cursor += 1
        return source[start:cursor]
    for name, source in [('OriginalCaller',actual_old_caller.decode()),('CandidateCaller',actual_candidate)]:
        capsule = (OWN / 'inputs/controls' / (name+'.swift')).read_text()
        for signature in ['    private func setOriginalGroupExpanded(', '    func nativeRoutingReveal(']:
            assert exact_method(capsule,signature) == exact_method(source,signature)
    transformed = []
    for name in ['MaktabahNativeAnnotationListPublication.swift','MaktabahNativeAnnotationSelectionBinding.swift']:
        path = OWN / 'inputs/candidate/Source/ChavrusaText/UIRoutingHost/Integration' / name
        raw = path.read_text(); assert raw.startswith('#if os(iOS)\n') and raw.endswith('#endif\n')
        raw = raw.removeprefix('#if os(iOS)\n').removesuffix('#endif\n').replace('import UIKit\n','').replace('@preconcurrency import Combine\n','')
        dest = OWN / 'original' / name; dest.write_text(raw); transformed.append(dest)
    controls = [OWN / 'inputs/controls' / name for name in ['ExplicitAnnotationBoundary.swift','ActualOriginalRootPublication.swift','ActualWindowObservation.swift','ActualBindingFixture.swift','CallerControls.swift']]
    original_caller = OWN / 'inputs/controls/OriginalCaller.swift'
    candidate_caller = OWN / 'inputs/controls/CandidateCaller.swift'
    run('actual-old-caller-typecheck',base + link + transformed + controls + [original_caller,'-typecheck'], expected=1)
    diagnostic = (OWN / 'actual-old-caller-typecheck.stderr').read_text()
    assert "escaping closure captures non-escaping parameter 'validate'" in diagnostic
    run('actual-candidate-caller-compile',base + link + transformed + controls + [candidate_caller,'-o',output / 'caller-controls'])
    run('actual-candidate-caller-controls',[output / 'caller-controls'])
    observed = json.loads((OWN / 'actual-candidate-caller-controls.stdout').read_text())
    assert observed['passed'] == 6 and observed['failed'] == 0
    for row in products: assert sha(pathlib.Path(row['path']).read_bytes()) == row['sha256']
    save('RESULT.json', {'status': 'PASS_SOURCE_CONTROLS_ONLY', 'base': BASE, 'steps': steps, 'reused_products': products, 'original_source_join': joined, 'inputs': manifest, 'original_caller_git_join': caller_proof, 'scope': 'Actual full binding, nativeRoutingReveal and expansion helper; original Core/UI value contracts with explicit UIKit/Combine/Store/backend/workspace fixtures. Old sealed caller genuine compile diagnostic retained. Six current caller ownership controls; no app/native/Core execution or actual geometry evidence.', 'passed': observed['passed'], 'failed': observed['failed'], 'task_bytes': footprint(), 'free': free(), 'root_free': root_free()})
except BaseException as error:
    save('RESULT.json', {'status': 'FAILED', 'steps': steps, 'error': repr(error), 'traceback': traceback.format_exc(), 'task_bytes': footprint(), 'free': free(), 'root_free': root_free()})
    raise
finally:
    result = OWN / 'RESULT.json'
    if result.exists():
        value = json.loads(result.read_text())
        print(json.dumps({'path': str(result), 'sha256': sha(result.read_bytes()), 'status': value['status'], 'steps': [{'name': x['name'], 'exit': x.get('exit')} for x in steps]}))
