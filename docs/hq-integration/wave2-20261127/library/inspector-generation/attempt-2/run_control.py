import datetime, hashlib, json, os, pathlib, subprocess, sys

root = pathlib.Path(__file__).resolve().parent
sdk = '/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.0.sdk'
flags = ['-parse-as-library', '-swift-version', '6', '-D', 'DEBUG', '-Xfrontend', '-strict-concurrency=complete',
         '-sdk', sdk, '-target', 'arm64-apple-ios17.0-macabi', '-F', sdk + '/System/iOSSupport/System/Library/Frameworks',
         '-module-cache-path', str(root / 'module-cache')]
report = {'startedUTC': datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'scope': 'Mac Catalyst component controls plus whole-source host typecheck, not iPhone/simulator UI or corpus acceptance',
          'steps': [], 'sources': {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
                                  for p in root.rglob('*.swift')}}
def save():
    (root / 'RESULT.json').write_text(json.dumps(report, indent=2, sort_keys=True))
def run(name, command, timeout=180):
    started = datetime.datetime.now(datetime.timezone.utc).isoformat()
    with (root / (name + '.stdout.log')).open('wb') as out, (root / (name + '.stderr.log')).open('wb') as err:
        result = subprocess.run(command, stdout=out, stderr=err, timeout=timeout, cwd=root)
    report['steps'].append({'name': name, 'command': command, 'startedUTC': started,
                            'finishedUTC': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'exitCode': result.returncode})
    save()
    if result.returncode != 0: raise RuntimeError(name + ' failed')
try:
    run('compiler-version', ['xcrun', 'swiftc', '--version'])
    core = sorted(str(p) for p in (root / 'kit/Sources/TorahInspectorCore').glob('*.swift'))
    run('core-build', ['xcrun', 'swiftc'] + flags + ['-emit-module', '-emit-library', '-module-name', 'TorahInspectorCore']
        + core + ['-emit-module-path', str(root / 'TorahInspectorCore.swiftmodule'),
                  '-Xlinker', '-install_name', '-Xlinker', str(root / 'libTorahInspectorCore.dylib'),
                  '-o', str(root / 'libTorahInspectorCore.dylib')])
    bundle = root / 'BundleModuleBoundary.swift'
    bundle.write_text('import Foundation\nextension Bundle { static var module: Bundle { .main } }\n')
    ui = sorted(str(p) for p in (root / 'kit/Sources/TorahInspectorUI').glob('*.swift'))
    run('ui-module', ['xcrun', 'swiftc'] + flags + ['-I', str(root), '-emit-module', '-module-name', 'TorahInspectorUI']
        + ui + [str(bundle), '-emit-module-path', str(root / 'TorahInspectorUI.swiftmodule')])
    support = sorted(str(p) for p in (root / 'Source').rglob('*.swift'))
    support += [str(root / 'InspectorGenerationBoundaries.swift')]
    for kind in ['baseline', 'candidate']:
        adapter = root / (kind + '-adapter.swift')
        host = root / (kind + '-host.swift')
        run(kind + '-host-typecheck', ['xcrun', 'swiftc'] + flags + ['-typecheck', '-D', 'INSPECTOR_HOST_TYPECHECK', '-I', str(root)]
            + support + [str(adapter), str(host)])
        binary = root / (kind + '-controls')
        run(kind + '-compile', ['xcrun', 'swiftc'] + flags + ['-I', str(root), '-L', str(root), '-lTorahInspectorCore']
            + support + [str(adapter), str(root / 'InspectorGenerationControls.swift'), '-o', str(binary)])
        run(kind + '-run', [str(binary), str(root / (kind + '-cases.json'))], timeout=30)
        report[kind] = json.loads((root / (kind + '-cases.json')).read_text())
    report['status'] = 'COMPLETE'
except Exception as error:
    report['status'] = 'FAILED'
    report['error'] = str(error)
finally:
    report['finishedUTC'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    save()
