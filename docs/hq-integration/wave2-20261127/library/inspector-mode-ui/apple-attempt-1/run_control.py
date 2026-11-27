import datetime
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

root = Path(__file__).resolve().parent
lane = root.parent
utc = lambda: datetime.datetime.now(datetime.timezone.utc).isoformat()
digest = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
report = {
    'startedUTC': utc(), 'status': 'RUNNING',
    'scope': 'Actual retained default Sefaria API source conversion with unchanged original models; Apple SDK UI-source typecheck only. No application or simulator UI execution.',
    'sourceContractRevision': '991526228533d6689c4ad9da8dbd3e9f82a7bea1',
    'sourceParentCommit': 'b5f4cb26cb7540f47871816bb1d10187792ab605',
    'inputs': {p.name: digest(p) for p in root.iterdir() if p.is_file() and p.suffix in ('.swift', '.json')},
    'freeBytesBefore': shutil.disk_usage(root).free, 'steps': [],
}
def save():
    (root/'RESULT.json').write_text(json.dumps(report, indent=2, sort_keys=True)+'\n')
def run(name, command, timeout=60):
    started=utc()
    with (root/(name+'.stdout.log')).open('wb') as out, (root/(name+'.stderr.log')).open('wb') as err:
        result = subprocess.run(command, cwd=root, stdout=out, stderr=err, timeout=timeout)
    report['steps'].append({'name': name, 'command': command, 'exitCode': result.returncode, 'startedUTC': started, 'finishedUTC': utc()})
    save()
    if result.returncode:
        raise RuntimeError(name+' failed')
try:
    save()
    assert report['freeBytesBefore'] >= 512*1024*1024, 'Small source lane requires 512 MiB free; no cleanup authorized here'
    ui_cache=lane/'ui-attempt-1/module-cache'
    foundation_cache=lane/'inspector-generation-attempt-2/module-cache'
    assert ui_cache.is_dir() and foundation_cache.is_dir(), 'Reuse existing owned caches; do not replace a missing shared reservation'
    run('compiler-version',['xcrun','swiftc','--version'])
    sdk='/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.0.sdk'
    original=[str(root/p) for p in ['LibraryBackendModels.swift','SefariaModels.swift','SefariaDTOs.swift']]
    run('source-oracle-compile',['xcrun','swiftc','-parse-as-library','-swift-version','6','-D','DEBUG',
        '-Xfrontend','-strict-concurrency=complete','-sdk',sdk,'-target','arm64-apple-ios17.0-macabi',
        '-F',sdk+'/System/iOSSupport/System/Library/Frameworks','-module-cache-path',str(foundation_cache)] +
        original+[str(root/'InspectorModeSourceOracle.swift'),'-o',str(root/'source-oracle')])
    output=root/'sefaria-inspector-default-mode-oracle.json'
    run('source-oracle-conversion',[str(root/'source-oracle'),str(root),str(output)],timeout=30)
    oracle=json.loads(output.read_text())
    assert oracle['status']=='ACTUAL_DEFAULT_SEFARIA_SOURCE_ORACLE_ONLY_NOT_UI' and oracle['uiExecuted'] is False
    assert len(oracle['segments'])==28 and set(oracle['modes'])=={'source','translation','both'}
    report['sourceOracle']={'path':str(output),'bytes':output.stat().st_size,'sha256':digest(output),'segmentCount':28,'modeCount':3,'uiExecuted':False}
    platform='/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer'
    command=['xcrun','swiftc','-typecheck','-parse-as-library','-swift-version','6','-target','arm64-apple-ios27.0-simulator',
        '-sdk',platform+'/SDKs/iPhoneSimulator27.0.sdk','-F',platform+'/Library/Frameworks','-I',platform+'/usr/lib',
        '-module-cache-path',str(ui_cache),'-module-name','Maktabah_iOSUITests','-D','DEBUG',
        '-enable-upcoming-feature','NonisolatedNonsendingByDefault','-enable-upcoming-feature','InferIsolatedConformances',
        '-enable-upcoming-feature','MemberImportVisibility']+[str(root/p)for p in
            ['MaktabahUITestBase.swift','OriginalSearchContextUI.swift','DeepLinkedCommentaryAcceptanceTests.swift']]
    run('whole-ui-file-typecheck',command)
    diagnostics=(root/'whole-ui-file-typecheck.stderr.log').read_text()
    report['warningDiagnosticCount']=diagnostics.count('warning:')
    report['errors']=[line for line in diagnostics.splitlines() if 'error:' in line]
    report['sourceInputsAfter']={name:digest(root/name) for name in report['inputs']}
    assert report['sourceInputsAfter']==report['inputs']
    report['status']='COMPLETE_SOURCE_ONLY'
except Exception as error:
    report['status']='FAILED_SOURCE_ONLY'
    report['error']=str(error)
finally:
    report['finishedUTC']=utc()
    report['freeBytesAfter']=shutil.disk_usage(root).free
    save()
