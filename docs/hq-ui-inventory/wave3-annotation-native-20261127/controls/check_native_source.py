from pathlib import Path
import base64, hashlib, json, os, re, shutil, subprocess, time, traceback, zipfile

BASE = 'b463ffd03a76026cea06c79c608df97d00094152'
ROOT = Path('/home/ubuntu/.codex/worktrees/Maktabah-wave3-integration-rootfs-20261127')
TASK = Path('/mnt/development/projects/diagnostics/otzaria-wave3-annotations-selection-20261127')
OWN = TASK / 'native-selectors-attempt-1'
SWIFT = Path('/mnt/development/tooling/swiftly/toolchains/6.4.3/usr/bin/swiftc')
PREFIX = 'Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift'
SELECTOR = 'Maktabah-iOSUITests/NativeAnnotationSelectionAcceptanceTests.swift'
DATA_FLOOR = 2147483648
ROOT_FLOOR = 1342177280

def sha(data): return hashlib.sha256(data).hexdigest()
def write(path, data):
    destination = OWN / path
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(data)
    return destination
def save(path, value): return write(path, (json.dumps(value, indent=2, sort_keys=True) + '\n').encode())
def capacity():
    if shutil.disk_usage(TASK).free < DATA_FLOOR or shutil.disk_usage(ROOT).free < ROOT_FLOOR:
        raise RuntimeError('shared capacity floor')
    if sum(p.stat().st_blocks * 512 for p in TASK.rglob('*') if p.is_file()) > 104857600:
        raise RuntimeError('owned task 100 MiB cap')
def git(*args):
    return subprocess.run(['git', '-C', str(ROOT), '-c', 'gc.auto=0', '-c', 'maintenance.auto=false', *args],
                          capture_output=True, check=True).stdout

capacity()
if OWN.exists(): raise RuntimeError('fresh native source output required')
OWN.mkdir()
result = {'schema': 'otzaria.original.annotation-native-source-check.v1', 'base': BASE,
          'native': 'NOT_RUN', 'apple_sdk_typecheck': 'NOT_RUN', 'started': time.time(), 'steps': []}
try:
    payload = json.loads(base64.b64decode(PAYLOAD_B64))
    save('PAYLOAD.json', payload)
    original_rows = []
    for row in payload['dependencies']:
        raw = git('show', BASE + ':' + row['path'])
        if len(raw) != row['bytes'] or sha(raw) != row['sha256']:
            raise RuntimeError('actual original dependency changed: ' + row['path'])
        write('original/' + row['path'], raw)
        original_rows.append({**row, 'base': BASE,
            'git_blob': git('rev-parse', BASE + ':' + row['path']).decode().strip()})
    for path in payload['additional_original_paths']:
        raw = git('show', BASE + ':' + path)
        write('original/' + path, raw)
        original_rows.append({'path': path, 'bytes': len(raw), 'sha256': sha(raw), 'base': BASE,
            'git_blob': git('rev-parse', BASE + ':' + path).decode().strip()})
    original = (OWN / 'original' / PREFIX).read_bytes()
    suffix = base64.b64decode(payload['suffix_b64'])
    selector = base64.b64decode(payload['selector_b64'])
    if len(original) != 375434 or sha(original) != '2157fe667fc215e3ac46e8115a1b1731dc96874cf06bb8d4ee880e5d35f9b74e':
        raise RuntimeError('immutable original helper prefix')
    if len(suffix) != 31681 or sha(suffix) != '9f6af6530cd8ead9d2747a9a6c3a5b1f7f33e95fc2d29781eff8523116be8dc0':
        raise RuntimeError('frozen suffix')
    if len(selector) != 1664 or sha(selector) != '2f7e720a2cd85112158553816d3fa1ac5ffb12861d9475767eefecc46bd472d2':
        raise RuntimeError('frozen selector')
    combined = original + suffix
    if sha(combined) != '93fade04cfeb99c75870f886d211d7144fc20e952ac0c8b56eb385cabc24b01f':
        raise RuntimeError('combined original prefix and suffix')
    write('NATIVE_HELPER_ADDITION.swift', suffix)
    write('candidate/' + PREFIX, combined)
    write('candidate/' + SELECTOR, selector)
    for path, encoded in payload['preserved'].items(): write('preserved/' + path, base64.b64decode(encoded))
    before_methods = set(re.findall(rb'\bfunc\s+([A-Za-z_][A-Za-z0-9_]*)', original))
    after_methods = set(re.findall(rb'\bfunc\s+([A-Za-z_][A-Za-z0-9_]*)', suffix))
    if before_methods & after_methods: raise RuntimeError('method collision')
    methods = re.findall(rb'\bfunc\s+(test\w+)', selector)
    if len(methods) != 6 or len(set(methods)) != 6: raise RuntimeError('exact six additive methods')
    if any(word in suffix for word in [b'.perform(', b'performSearch', b'OTZARIA_NATIVE_ROUTE_PROBE']):
        raise RuntimeError('unapproved direct execution path')
    pbx_path = 'Maktabah.xcodeproj/project.pbxproj'
    pbx = git('show', BASE + ':' + pbx_path)
    group = re.search(rb'\bF30578032FA46222005732C6 /\* Maktabah-iOSUITests \*/ = \{.*?\n\s*\};', pbx, re.S)
    target = re.search(rb'\bF30578012FA46222005732C6 /\* Maktabah-iOSUITests \*/ = \{.*?\n\s*\};', pbx, re.S)
    if group is None or target is None: raise RuntimeError('original synchronized target/group')
    if b'isa = PBXFileSystemSynchronizedRootGroup;' not in group[0] or b'path = "Maktabah-iOSUITests";' not in group[0]:
        raise RuntimeError('original synchronized source directory')
    if b'fileSystemSynchronizedGroups' not in target[0] or b'F30578032FA46222005732C6' not in target[0]:
        raise RuntimeError('original synchronized target attachment')
    save('MEMBERSHIP.json', {'base': BASE, 'path': pbx_path, 'bytes': len(pbx), 'sha256': sha(pbx),
        'git_blob': git('rev-parse', BASE + ':' + pbx_path).decode().strip(),
        'group': group[0].decode(), 'target': target[0].decode(),
        'policy': 'Inherited original filesystem-synchronized UI-test inclusion. No manual PBX entry. Apple discovery/build not run.'})
    if sha(SWIFT.read_bytes()) != '39d41b0dc9eba623b0e37cea42c3145720168214ba4349d6fa3bd9db9b1e651a':
        raise RuntimeError('original compiler identity')
    capacity()
    argv = [str(SWIFT), '-frontend', '-parse', '-target', 'arm64-apple-ios27.0',
            str(OWN / 'candidate' / PREFIX), str(OWN / 'candidate' / SELECTOR)]
    step = {'name': 'two-complete-native-source-files-syntax-only', 'argv': argv, 'started': time.time()}
    result['steps'].append(step)
    with (OWN / 'syntax.stdout').open('wb') as out, (OWN / 'syntax.stderr').open('wb') as err:
        process = subprocess.Popen(argv, stdout=out, stderr=err, start_new_session=True)
        step['pid'] = process.pid
        step['start_ticks'] = Path('/proc/' + str(process.pid) + '/stat').read_text().split()[21]
        step['exit'] = process.wait(timeout=60)
    step['finished'] = time.time()
    if step['exit'] != 0: raise RuntimeError('native syntax parse; raw output preserved')
    capacity()
    save('ORIGINAL_SOURCE_JOIN.json', {'base': BASE, 'files': original_rows})
    result.update(status='PASS_SOURCE_JOIN_AND_SYNTAX_ONLY', source_proof=payload['source_proof'],
        original_dependencies=len(original_rows), selector_declarations=[x.decode() for x in methods],
        test_execution_count=0, immutable_prefix_exact=True, collisions=[],
        scope='Two complete Swift files parsed for iOS only. Original Git/UI/store/AppIntent dependencies rejoined; no Apple SDK typecheck, actual system Intent, UIKit, SQLite instance or native execution.')
except BaseException as error:
    result.update(status='FAILED', error=repr(error), traceback=traceback.format_exc())
finally:
    result.update(finished=time.time(), data_free=shutil.disk_usage(TASK).free,
                  root_free=shutil.disk_usage(ROOT).free)
    p = save('RESULT.json', result)
    members = []
    for path in sorted(OWN.rglob('*')):
        if path.is_file() and path.name not in {'RAW.zip', 'RAW_MANIFEST.json'}:
            raw = path.read_bytes()
            members.append({'path': str(path.relative_to(OWN)), 'bytes': len(raw), 'sha256': sha(raw)})
    save('RAW_MANIFEST.json', members)
    with zipfile.ZipFile(OWN / 'RAW.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
        for row in members: archive.write(OWN / row['path'], row['path'])
        archive.write(OWN / 'RAW_MANIFEST.json', 'RAW_MANIFEST.json')
    raw = (OWN / 'RAW.zip').read_bytes()
    print(json.dumps({'path': str(p), 'sha256': sha(p.read_bytes()), 'status': result['status'],
        'raw_zip': str(OWN / 'RAW.zip'), 'raw_bytes': len(raw), 'raw_sha256': sha(raw),
        'raw_members': len(members), 'steps': result['steps'], 'error': result.get('error')}))
if result['status'] != 'PASS_SOURCE_JOIN_AND_SYNTAX_ONLY': raise SystemExit(1)
