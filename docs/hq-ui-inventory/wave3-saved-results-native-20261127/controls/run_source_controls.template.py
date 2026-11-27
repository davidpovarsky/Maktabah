import base64
import gzip
import hashlib
import json
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess
import sys
import time

# The dispatcher supplies only exact local inputs. No repository/app mutation.
INPUT_PAYLOAD = '__INPUT_PAYLOAD__'
inputs = json.loads(gzip.decompress(base64.b64decode(INPUT_PAYLOAD)))
root = Path('/home/ubuntu/otzaria-wave3-saved-results-native-20261127/controls/attempt-1')
cache = Path('/home/ubuntu/otzaria-wave3-saved-results-reveal-20261127/controls/attempt-1/module-cache')
swift = Path('/mnt/development/tooling/swiftly/toolchains/6.4.3/usr/bin/swiftc')
floor = 1342177280
cap = 25 * 1024 * 1024
free_before = shutil.disk_usage('/home/ubuntu').free
assert free_before >= floor + cap
assert cache.is_dir() and Path('/usr/include/sqlite3.h').is_file()
assert hashlib.sha256(swift.read_bytes()).hexdigest() == '39d41b0dc9eba623b0e37cea42c3145720168214ba4349d6fa3bd9db9b1e651a'
root.mkdir(parents=True, exist_ok=False)
rows = []
for item in inputs:
    data = base64.b64decode(item['base64'])
    assert len(data) == item['bytes'] and hashlib.sha256(data).hexdigest() == item['sha256']
    path = root / 'inputs' / item['path']
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    rows.append({k: item[k] for k in ['path', 'bytes', 'sha256']})
(root / 'INPUTS.json').write_text(json.dumps(rows, indent=2) + '\n')
commands = []
result = {'schema': 'otzaria.saved-results-native-source-controls.v1', 'start': time.time(),
          'source_only': True, 'apple_sdk_typecheck': 'NOT_RUN', 'native': 'NOT_RUN',
          'free_before': free_before, 'floor': floor, 'task_cap': cap, 'commands': commands}

def run(name, argv, timeout=90):
    assert shutil.disk_usage(root).free >= floor
    item = {'name': name, 'argv': [str(x) for x in argv], 'start': time.time()}
    commands.append(item)
    (root / 'STARTED.json').write_text(json.dumps(result, indent=2) + '\n')
    completed = subprocess.run(item['argv'], cwd=root, capture_output=True, timeout=timeout)
    for key, value in [('stdout', completed.stdout), ('stderr', completed.stderr)]:
        path = root / (name + '.' + key)
        path.write_bytes(value)
        item[key] = {'path': path.name, 'bytes': len(value), 'sha256': hashlib.sha256(value).hexdigest()}
    item.update(exit_code=completed.returncode, end=time.time())
    if completed.returncode:
        raise RuntimeError(name + ' failed with ' + str(completed.returncode))
    return completed.stdout

try:
    for name in ['NativeRoutingAcceptanceTests.swift', 'NativeSavedResultsAcceptanceTests.swift']:
        run('parse-' + name, [swift, '-frontend', '-parse', '-target', 'arm64-apple-ios27.0',
                             root / 'inputs/candidate/Maktabah-iOSUITests' / name])
    module = root / 'modules/SQLite3'
    module.mkdir(parents=True)
    (module / 'module.modulemap').write_text('module SQLite3 [system] {\n header "/usr/include/sqlite3.h"\n link "sqlite3"\n export *\n}\n')
    fixture = root / 'fixtures'
    fixture.mkdir()
    connection = sqlite3.connect(fixture / 'original.sqlite')
    connection.executescript('''
    CREATE TABLE folders(id INTEGER PRIMARY KEY, name TEXT, parent INTEGER, ckRecordId TEXT, lastModified INTEGER, parentCkRecordId TEXT);
    CREATE TABLE results(id INTEGER PRIMARY KEY, folder_id INTEGER, name TEXT, query TEXT, archives INTEGER, bkId INTEGER,
        contentId TEXT, ckRecordId, lastModified INTEGER, folder_ckrecord_id TEXT, search_mode INTEGER, near_distance INTEGER, floatProbe REAL);
    ''')
    connection.executemany('INSERT INTO folders VALUES(?,?,?,?,?,?)', [(2, 'child', 1, 'child-cloud', 2, 'parent-cloud'), (1, 'parent', None, '', 1, None)])
    connection.executemany('INSERT INTO results VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)', [
        (9, 2, 'other', 'other query', 7, 8, '9', None, 2, None, 1, 10, 0.5),
        (4, 2, 'owned', 'בראשית\0exact', 3, 4, '12,15', sqlite3.Binary(bytes([0,255,17])), 9007199254740993, '', 0, 10, 0.125)])
    connection.commit(); connection.close()
    connection = sqlite3.connect(fixture / 'missing-results.sqlite')
    connection.execute('CREATE TABLE folders(id INTEGER PRIMARY KEY)'); connection.commit(); connection.close()
    (root / 'FIXTURES_BEFORE.json').write_text(json.dumps([
        {'path': str(p.relative_to(root)), 'bytes': p.stat().st_size, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
        for p in sorted(fixture.iterdir())], indent=2) + '\n')
    run('oracle-compile', [swift, '-swift-version', '6', '-parse-as-library',
        '-module-cache-path', cache, '-I', module.parent,
        root / 'inputs/controls/OriginalSQLiteOracleControls.swift', '-o', root / 'oracle-controls'])
    stdout = run('oracle-execute', [root / 'oracle-controls', fixture])
    report = json.loads(stdout)
    assert report['passed'] == 10 and report['failed'] == 0
    result.update(status='PASSED_SOURCE_ONLY', oracle_controls=report)
except Exception as error:
    result.update(status='FAILED', error=str(error))
finally:
    result['free_after'] = shutil.disk_usage(root).free
    result['task_bytes'] = sum(p.stat().st_size for p in root.rglob('*') if p.is_file())
    result['end'] = time.time()
    if result['task_bytes'] > cap or result['free_after'] < floor:
        result['status'] = 'FAILED'; result['budget_violation'] = True
    path = root / 'RESULT.json'
    path.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'root': str(root), 'result': result, 'result_sha256': hashlib.sha256(path.read_bytes()).hexdigest()}))
if result['status'] != 'PASSED_SOURCE_ONLY':
    sys.exit(1)
