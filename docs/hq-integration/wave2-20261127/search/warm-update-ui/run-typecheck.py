import datetime, hashlib, json, pathlib, subprocess, time

work = pathlib.Path(__file__).resolve().parent
inputs = json.loads((work / 'INPUT.json').read_text())
for name, expected in inputs['hashes'].items():
    assert hashlib.sha256((work / name).read_bytes()).hexdigest() == expected
sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True, timeout=15).strip()
platform = pathlib.Path(sdk).parents[2]
cache = pathlib.Path('/Users/m1/builds/otzaria-wave2-search-20261127/post-update-ui-typecheck/module-cache')
records = []

def run(name, command):
    started = time.monotonic()
    result = subprocess.run(command, cwd=work, capture_output=True, timeout=120)
    for suffix, data in [('stdout.log', result.stdout), ('stderr.log', result.stderr)]:
        (work / (name + '.' + suffix)).write_bytes(data)
    records.append({'name': name, 'command': command, 'exit': result.returncode,
        'seconds': time.monotonic() - started,
        'stdoutSHA256': hashlib.sha256(result.stdout).hexdigest(),
        'stderrSHA256': hashlib.sha256(result.stderr).hexdigest(),
        'warnings': result.stderr.count(b'warning:'), 'errors': result.stderr.count(b'error:')})
    (work / 'COMPILE_RUN.json').write_text(json.dumps(records, indent=2))

run('whole-file-parse', ['xcrun', 'swiftc', '-parse', 'GlobalSearchNativeAcceptanceTests.swift'])
run('actual-xctest-typecheck', ['xcrun', 'swiftc', '-parse-as-library', '-typecheck',
    '-swift-version', '6', '-D', 'DEBUG', '-Xfrontend', '-strict-concurrency=complete',
    '-sdk', sdk, '-target', 'arm64-apple-ios27.0-simulator',
    '-F', str(platform / 'Developer/Library/Frameworks'), '-I', str(platform / 'Developer/usr/lib'),
    '-module-cache-path', str(cache), 'MaktabahUITestBase.swift', 'ExtractedPublishedContextTests.swift'])
report = {'schemaVersion': 1, 'status': 'SOURCE_TYPECHECK_ONLY_NOT_NATIVE_UI',
    'completedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'scope': inputs['scope'], 'sourceHashes': inputs['hashes'],
    'baselineCommit': inputs['baselineCommit'], 'originalTestSHA256': inputs['originalTestSHA256'],
    'xcode': subprocess.check_output(['xcodebuild', '-version'], text=True, timeout=15).strip(),
    'swift': subprocess.check_output(['xcrun', 'swiftc', '--version'], text=True, timeout=15).strip(),
    'sdk': sdk, 'records': records, 'nativeExecutions': 0, 'appBuilds': 0}
(work / 'RESULT.json').write_text(json.dumps(report, indent=2))
print(json.dumps(report))
