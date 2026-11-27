import base64, datetime, hashlib, importlib.util, json, os, pathlib, shutil, subprocess, time, zlib

payload = json.loads(zlib.decompress(base64.b64decode(os.environ['READER_CONTINUOUS_CHECK_PAYLOAD'])))
root = pathlib.Path('/Users/m1/builds/otzaria-wave2-reader-controls-20261127')
assert root.is_dir() and root.resolve() == root
assert shutil.disk_usage(root).free >= 4 * 1024**3
work = root / ('continuous-pull-source-' + datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ'))
work.mkdir()
for name, text in payload['files'].items():
    assert pathlib.Path(name).name == name and name.endswith(('.swift', '.py'))
    (work / name).write_text(text)
(work / 'INPUT.json').write_text(json.dumps(payload, ensure_ascii=False, indent=2))
records = []
def run(name, command, timeout=90):
    started = time.monotonic()
    result = subprocess.run(command, cwd=work, capture_output=True, text=True, timeout=timeout,
                            env={**os.environ, 'PYTHONDONTWRITEBYTECODE': '1'})
    (work / (name + '.stdout')).write_text(result.stdout)
    (work / (name + '.stderr')).write_text(result.stderr)
    records.append({'name': name, 'command': command, 'exit': result.returncode,
                    'seconds': time.monotonic()-started,
                    'stdoutSHA256': hashlib.sha256(result.stdout.encode()).hexdigest(),
                    'stderrSHA256': hashlib.sha256(result.stderr.encode()).hexdigest()})
    return result
tool_root = pathlib.Path('/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl/original-native116-prebuilt-evidence.X0L7wYFd/local-tool-temporary.q6D5fNUv/r27-hid-tools-73pnzxjb')
spec = importlib.util.spec_from_file_location('host', work/'reader-continuous-pull-host.py')
host = importlib.util.module_from_spec(spec)
spec.loader.exec_module(host)
tools = host.verify_tools(tool_root)
(work/'PINNED_TOOLS.json').write_text(json.dumps(tools,indent=2))
run('host-source-controls', [tools['python'], '-B', 'host-source-controls.py'])
ios = subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
platform = str(pathlib.Path(ios).parents[2])
cache = root/'full-v40-observation-admission/module-cache'
cache_existed = cache.exists()
flags = ['-swift-version','6','-D','DEBUG','-Xfrontend','-strict-concurrency=complete',
         '-module-cache-path',str(cache)]
run('whole-native-tests-parse', ['xcrun','swiftc','-parse','Build8401SevenDefectsAcceptanceTests.swift'])
run('whole-native-tests-xctest-typecheck', ['xcrun','swiftc','-parse-as-library','-typecheck',*flags,
    '-sdk',ios,'-target','arm64-apple-ios27.0-simulator','-F',platform+'/Developer/Library/Frameworks',
    '-I',platform+'/Developer/usr/lib','OriginalMaktabahUITestBase.swift','OriginalSearchContextUI.swift',
    'Build8401SevenDefectsAcceptanceTests.swift'])
report = {'schema':1,'status':'SOURCE_CHECKS_RECORDED_NOT_NATIVE_UI','records':records,
    'directory':str(work),'sourceBase':payload['sourceBase'],
    'sourceHashes':{name:hashlib.sha256((work/name).read_bytes()).hexdigest() for name in payload['files']},
    'originalTestPrefixSHA256':payload['originalTestPrefixSHA256'],
    'xcode':subprocess.check_output(['xcodebuild','-version'],text=True).strip(),
    'swift':subprocess.check_output(['xcrun','swiftc','--version'],text=True).strip(),
    'sdk':ios,'moduleCache':str(cache),'moduleCacheExisted':cache_existed,
    'simulatorConnections':0,'touchesSent':0,'uiExecuted':0,'appBuilds':0}
(work/'RESULT.json').write_text(json.dumps(report,indent=2))
print(json.dumps({'result':report,'tools':tools,'textFiles':{p.name:p.read_text() for p in work.iterdir()
    if p.suffix in ('.stdout','.stderr') or p.name in ('RESULT.json','PINNED_TOOLS.json')}},ensure_ascii=False))
