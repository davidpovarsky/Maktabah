import datetime, hashlib, json, os, pathlib, shutil, signal, subprocess, time

ROOT = pathlib.Path('/home/ubuntu/.codex/diagnostics/otzaria-wave3-viewer-parent-controls-20261127/actual-modules-attempt-2')
TASK = ROOT.parent
FIRST = TASK / 'actual-modules-attempt-1'
CACHE = FIRST / 'module-cache'
RETAINED = pathlib.Path('/mnt/development/projects/worktrees/Maktabah-wave3-history-records-20261127/build/history-record-controls-20261127/cache-restoration/scratch/out')
REPO = '/home/ubuntu/.codex/worktrees/Maktabah-wave3-integration-rootfs-20261127'
BASE = '49f15cd68933b3e75ad8fe9074712c768f793566'
FLOOR = 1342177280
CAP = 104857600
SWIFT = '/usr/local/bin/swiftc'
MODULES = [
    ('OtzariaActionCore', 'Source/Otzaria/Actions/Sources/OtzariaActionCore', []),
    ('OtzariaUIRouting', 'Source/Otzaria/UIRouting/Sources/OtzariaUIRouting', ['OtzariaActionCore']),
    ('ChavrusaUIRoutingHost', 'Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost', ['OtzariaActionCore', 'OtzariaUIRouting']),
]

def now(): return datetime.datetime.now(datetime.timezone.utc).isoformat()
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def allocated(): return sum(p.lstat().st_blocks * 512 for p in TASK.rglob('*'))
def capacity():
    free = shutil.disk_usage('/home').free
    size = allocated()
    if free < FLOOR or size > CAP: raise RuntimeError(f'capacity stop: free={free}, own={size}')
    return {'free_rootfs_bytes': free, 'own_allocated_bytes': size}
def save(name, value):
    with (ROOT / name).open('x') as stream: json.dump(value, stream, sort_keys=True, indent=2)
def git(*args): return subprocess.check_output(['git', '-c', 'gc.auto=0', '-c', 'maintenance.auto=false', '-C', REPO, *args])

result = {'schema': 'otzaria.viewer-parent.actual-module-run.v1', 'started': now(), 'base': BASE,
          'floor_bytes': FLOOR, 'task_cap_bytes': CAP, 'steps': [], 'status': 'NOT_COMPLETE'}
try:
    if (ROOT / 'STARTED.json').exists(): raise RuntimeError('fresh output required')
    result['before'] = capacity()
    save('STARTED.json', {'pid': os.getpid(), 'argv': [__file__], 'started': result['started'], 'before': result['before']})
    print(json.dumps({'started': result['started'], 'pid': os.getpid(), 'base': BASE, 'before': result['before']}), flush=True)
    source_manifest = json.loads((FIRST / 'PACKAGE_INPUTS.json').read_text())
    for row in source_manifest:
        if sha(FIRST / row['variant'] / 'source' / row['path']) != row['sha256']: raise RuntimeError('input drift')
    save('PACKAGE_INPUTS.json', source_manifest)
    result['package_inputs_sha256'] = sha(ROOT / 'PACKAGE_INPUTS.json')
    generated = []
    for variant in ['candidate1', 'candidate']:
        output = ROOT / variant / 'out'
        output.mkdir(parents=True, exist_ok=False)
        for module, relative, _ in MODULES[:2]:
            original = RETAINED / 'Intermediates.noindex' / (module + '.build') / 'Debug-linux-aarch64' / (module + '-t.build') / 'DerivedSources/resource_bundle_accessor.swift'
            target = ROOT / variant / (module + '-resource_bundle_accessor.swift')
            shutil.copyfile(original, target)
            if sha(original) != sha(target): raise RuntimeError('generated accessor mismatch')
            bundle = RETAINED / 'Products/Debug-linux-aarch64' / (module + '_' + module + '.bundle')
            for name in git('ls-tree', '-r', '--name-only', BASE, relative + '/Resources').decode().splitlines():
                original_bytes = git('show', BASE + ':' + name)
                actual = bundle / pathlib.Path(name).name
                if actual.read_bytes() != original_bytes: raise RuntimeError('original bundle resource mismatch')
            copied = output / bundle.name
            shutil.copytree(bundle, copied)
            for original_file in sorted(bundle.rglob('*')):
                if original_file.is_file():
                    copy = copied / original_file.relative_to(bundle)
                    if sha(copy) != sha(original_file): raise RuntimeError('bundle copy mismatch')
                    generated.append({'variant': variant, 'original': str(original_file), 'copy': str(copy), 'bytes': copy.stat().st_size, 'sha256': sha(copy)})
            generated.append({'variant': variant, 'original': str(original), 'copy': str(target), 'bytes': target.stat().st_size, 'sha256': sha(target)})
    save('ORIGINAL_GENERATED_INPUTS.json', generated)

    def run(name, argv, env=None, timeout=120):
        capacity()
        step = {'name': name, 'argv': argv, 'started': now(), 'before': capacity()}
        result['steps'].append(step)
        print(json.dumps({'step': name, 'started': step['started'], 'before': step['before']}), flush=True)
        with (ROOT / (name + '.stdout')).open('xb') as out, (ROOT / (name + '.stderr')).open('xb') as err:
            process = subprocess.Popen(argv, stdout=out, stderr=err, env=env, start_new_session=True)
            step['pid'] = process.pid
            started = time.monotonic()
            try:
                while process.poll() is None:
                    capacity()
                    if time.monotonic() - started > timeout: raise RuntimeError('bounded source-control timeout')
                    time.sleep(0.5)
            except BaseException:
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGTERM)
                    try: process.wait(timeout=5)
                    except subprocess.TimeoutExpired: os.killpg(process.pid, signal.SIGKILL); process.wait()
                raise
        step.update({'exit_code': process.returncode, 'finished': now(), 'after': capacity(),
                     'stdout_sha256': sha(ROOT / (name + '.stdout')), 'stderr_sha256': sha(ROOT / (name + '.stderr'))})
        print(json.dumps({'step': name, 'exit_code': process.returncode, 'after': step['after']}), flush=True)
        if process.returncode != 0: raise RuntimeError(f'{name} exit {process.returncode}')

    for variant in ['candidate1', 'candidate']:
        source, output = FIRST / variant / 'source', ROOT / variant / 'out'
        for module, relative, dependencies in MODULES:
            inputs = [str(p) for p in sorted((source / relative).rglob('*.swift'))]
            if module != 'ChavrusaUIRoutingHost': inputs.append(str(ROOT / variant / (module + '-resource_bundle_accessor.swift')))
            argv = [SWIFT, '-swift-version', '6', '-DDEBUG', '-parse-as-library', '-whole-module-optimization',
                    '-enable-testing', '-emit-library', '-emit-module', '-module-name', module,
                    '-module-cache-path', str(CACHE), '-I', str(output), '-L', str(output),
                    '-emit-module-path', str(output / (module + '.swiftmodule')), '-o', str(output / ('lib' + module + '.so'))]
            for dependency in dependencies: argv += ['-l' + dependency]
            run(variant + '-' + module, argv + inputs)
        harness = FIRST / 'inputs' / 'harness' / 'ContinuationControls.swift'
        binary = output / 'ContinuationControls'
        run(variant + '-harness-compile', [SWIFT, '-swift-version', '6', '-parse-as-library', '-module-cache-path', str(CACHE),
            '-I', str(output), '-L', str(output), '-lOtzariaActionCore', '-lOtzariaUIRouting', '-lChavrusaUIRoutingHost', str(harness), '-o', str(binary)])
        env = dict(os.environ); env['LD_LIBRARY_PATH'] = str(output)
        run(variant + '-controls', [str(binary)] + (['--candidate1'] if variant == 'candidate1' else []), env=env, timeout=35)
        result[variant] = json.loads((ROOT / (variant + '-controls.stdout')).read_text())
    for row in source_manifest:
        file = FIRST / row['variant'] / 'source' / row['path']
        if sha(file) != row['sha256']: raise RuntimeError('source changed during controls')
    result['status'] = 'PASS_SOURCE_CONTROLS'
except BaseException as error:
    result['error'] = repr(error)
finally:
    result['finished'] = now(); result['after'] = {'free_rootfs_bytes': shutil.disk_usage('/home').free, 'own_allocated_bytes': allocated()}
    save('RESULT.json', result)
    print(json.dumps({'status': result['status'], 'error': result.get('error'), 'finished': result['finished'], 'after': result['after'], 'result_sha256': sha(ROOT / 'RESULT.json')}), flush=True)
