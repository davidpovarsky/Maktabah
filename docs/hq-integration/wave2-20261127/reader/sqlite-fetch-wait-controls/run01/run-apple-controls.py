"""Owned, small actual Apple source controls; never an application/UI benchmark."""
import base64, datetime, hashlib, json, os, pathlib, shutil, subprocess, sys, time, zlib

payload = json.loads(zlib.decompress(sys.stdin.buffer.read()))
root = pathlib.Path('/Users/m1/builds/otzaria-wave2-reader-controls-20261127')
assert root.is_dir() and root.resolve() == root
free_before = shutil.disk_usage(root).free
assert free_before >= 4 * 1024**3, 'Tiny source controls require four GiB free at admission'
cache = root/'full-v40-observation-admission/module-cache'
assert cache.is_dir(), 'Reuse the already owned cache; do not copy dependencies'
work = root/('sqlite-fetch-wait-'+datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ'))
work.mkdir()
for name, value in payload['files'].items():
    assert pathlib.Path(name).name == name and name.endswith('.swift')
    data = base64.b64decode(value['base64'], validate=True)
    assert hashlib.sha256(data).hexdigest() == value['sha256']
    (work/name).write_bytes(data)
(work/'INPUT.json').write_text(json.dumps(payload, ensure_ascii=False, indent=2)+'\n')
records=[]
def run(name, command, *, timeout=120, opt_in=None):
    started=time.monotonic()
    env=os.environ.copy();env.pop('CHAVRUSA_FULL_V32_SOURCE_OBSERVATION',None)
    if opt_in is not None:env['CHAVRUSA_FULL_V32_SOURCE_OBSERVATION']=opt_in
    try:
        result=subprocess.run(command,cwd=work,env=env,capture_output=True,timeout=timeout)
        code,stdout,stderr=result.returncode,result.stdout,result.stderr
    except subprocess.TimeoutExpired as error:
        code,stdout,stderr=124,error.stdout or b'',error.stderr or b''
    (work/(name+'.stdout')).write_bytes(stdout)
    (work/(name+'.stderr')).write_bytes(stderr)
    row={'name':name,'command':command,'exit':code,'seconds':time.monotonic()-started,
         'optIn':opt_in,'stdoutSHA256':hashlib.sha256(stdout).hexdigest(),
         'stderrSHA256':hashlib.sha256(stderr).hexdigest()}
    if code==0 and name.startswith(('candidate-run-','baseline-run-','catalyst-run-','release-run-')):
        row['componentResult']=json.loads(stdout)
    records.append(row)
    return code
mac=subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
ios=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
common=['-parse-as-library','-swift-version','6','-Xfrontend','-strict-concurrency=complete','-module-cache-path',str(cache)]
debug=[*common,'-D','DEBUG']
dependencies=['UnusedZstdBoundary.swift','SQLiteFetchWaitControls.swift']
baseline=run('baseline-compile',['xcrun','swiftc',*debug,'-D','ORIGINAL_BASELINE','-sdk',mac,
    'OriginalSQLiteDatabase.swift',*dependencies,'-o','BaselineControls'])
if baseline==0:
    for name in ('basic','recursive','held-wait','cancel-wait','cancel-before','errors'):
        run('baseline-run-'+name,[str(work/'BaselineControls'),name,str(work/('baseline-fixture-'+name))],timeout=30,opt_in='1')
candidate=run('candidate-compile',['xcrun','swiftc',*debug,'-sdk',mac,
    'CandidateSQLiteDatabase.swift',*dependencies,'-o','CandidateControls'])
if candidate==0:
    for name in ('basic','recursive','held-wait','cancel-wait','cancel-before','errors','ring-bound','connection-bound','active-bound','non-file-identity'):
        run('candidate-run-'+name,[str(work/'CandidateControls'),name,str(work/('candidate-fixture-'+name))],timeout=30,opt_in='1')
    run('candidate-run-disabled-absent',[str(work/'CandidateControls'),'disabled',str(work/'candidate-fixture-disabled-absent')],timeout=30)
    run('candidate-run-disabled-false',[str(work/'CandidateControls'),'disabled',str(work/'candidate-fixture-disabled-false')],timeout=30,opt_in='0')
release=run('release-compile',['xcrun','swiftc',*common,'-sdk',mac,
    'CandidateSQLiteDatabase.swift',*dependencies,'-o','ReleaseControls'])
if release==0:
    run('release-run-opt-in-ignored',[str(work/'ReleaseControls'),'release',str(work/'release-fixture')],timeout=30,opt_in='1')
shared=['AppTypeBoundaries.swift','OriginalHighlightSnapshot.swift','OriginalTextDeltaEvent.swift',
        'OriginalArabicRenderResult.swift','ReaderSelectionRangeMapper.swift']
run('whole-observer-ios-sdk-typecheck',['xcrun','swiftc',*debug,'-typecheck','-sdk',ios,
    '-target','arm64-apple-ios27.0-simulator',*shared,'UnusedZstdBoundary.swift',
    'CandidateSQLiteDatabase.swift','CandidateObserver.swift'])
catalyst=run('whole-observer-catalyst-compile',['xcrun','swiftc',*debug,'-sdk',mac,
    '-target','arm64-apple-ios17.0-macabi','-F',mac+'/System/iOSSupport/System/Library/Frameworks',
    *shared,'UnusedZstdBoundary.swift','CandidateSQLiteDatabase.swift','CandidateObserver.swift',
    'SQLiteFetchWaitControls.swift','-o','CatalystControls'])
if catalyst==0:
    run('catalyst-run-companion-export',[str(work/'CatalystControls'),'companion-export',str(work/'catalyst-companion-fixture')],timeout=30,opt_in='1')
report={'schema':1,'status':'ACTUAL_APPLE_COMPONENT_CONTROLS_RECORDED_NOT_UI_OR_PERFORMANCE_ACCEPTANCE',
    'sourceBind':payload['sourceBind'],'inputSHA256':{name:value['sha256'] for name,value in payload['files'].items()},
    'directory':str(work),'records':records,'allCommandsPassed':all(r['exit']==0 for r in records),
    'componentControlCount':sum('componentResult' in r for r in records),'applicationUIExecuted':0,
    'productionCorpusOpened':False,'simulatorCreated':False,'freeBytesBefore':free_before,
    'freeBytesAfter':shutil.disk_usage(root).free,'moduleCache':str(cache),
    'sdk':{'macOS':mac,'iOSSimulator':ios},
    'xcode':subprocess.check_output(['xcodebuild','-version'],text=True).strip(),
    'swift':subprocess.check_output(['xcrun','swiftc','--version'],text=True).strip(),
    'scope':'Original whole SQLiteDatabase baseline versus exact candidate with actual Apple SQLite. UIKit SDK typecheck uses explicit unexecuted application boundaries; Catalyst executes only the real companion exporter. active-bound is separately labeled synthetic recorder admission, never a database timing or application acceptance.'}
(work/'RESULT.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'result':report,'stderr':{p.name:p.read_text(errors='replace') for p in work.glob('*.stderr') if p.stat().st_size}},ensure_ascii=False))
