#!/usr/bin/env python3
"""Focused real SQLite/typed-envelope controls; no Apple or native body credit."""
import argparse, hashlib, json, os, pathlib, shutil, signal, subprocess, time
parser=argparse.ArgumentParser()
parser.add_argument('--repo',required=True);parser.add_argument('--work',required=True);parser.add_argument('--evidence',required=True)
args=parser.parse_args();repo=pathlib.Path(args.repo).resolve();work=pathlib.Path(args.work).resolve();evidence=pathlib.Path(args.evidence).resolve()
assert not work.exists() and not evidence.exists(), 'refuse to overwrite earlier execution'
work.mkdir(parents=True);evidence.mkdir(parents=True)
base='00b5c67120a9e76c98f87a49601fb26e84c0cc4c'
def git(*parts):
 p=subprocess.run(['runuser','-u','ubuntu','--','git','-C',str(repo),*parts],capture_output=True)
 assert p.returncode==0,p.stderr.decode();return p.stdout
def sha(data):return hashlib.sha256(data).hexdigest()
product=[
'Source/Otzaria/Actions/Sources/OtzariaActionCore/Contracts/ActionWireCodec.swift',
'Source/ChavrusaText/Annotations/Exchange/TorahAnnotationEnvelope.swift',
'Source/ChavrusaText/Annotations/Exchange/AnnotationExchangeLedger.swift',
'Source/ChavrusaText/Annotations/LocalEditor/AnnotationLocalEditorPersistence.swift',
'Source/ChavrusaText/Annotations/LocalEditor/AnnotationOriginalEditorMount.swift']
test=repo/'Tests/HQ/annotation-payload-budget'
paths=product+['Source/Core/Database/SQLiteDatabase.swift','Source/Core/CloudKit/SyncPendingStore.swift',
'Tests/HQ/sqlite/UnusedZstdBoundary.swift']+[str(p.relative_to(repo)) for p in test.glob('*.swift')]
before={p:{'bytes':len((repo/p).read_bytes()),'sha256':sha((repo/p).read_bytes())} for p in paths}
(evidence/'SOURCE_BEFORE.json').write_text(json.dumps(before,indent=2)+'\n')
# Copy complete original production files; no production function is extracted,
# replaced or projected. The v1 executable uses exact git blobs from the base.
for target,entry in [('LegacySeed','LegacySeeder.swift'),('BudgetAccept','BudgetAcceptance.swift')]:
 targetdir=work/'Sources'/target;targetdir.mkdir(parents=True)
 for path in ['Source/Core/Database/SQLiteDatabase.swift','Source/Core/CloudKit/SyncPendingStore.swift',
              'Tests/HQ/sqlite/UnusedZstdBoundary.swift']:
  (targetdir/pathlib.Path(path).name).write_bytes((repo/path).read_bytes())
 for name in ['BudgetOpenSSLDigest.swift','BudgetDatabaseEvidence.swift','PortableOriginalTestSupport.swift',entry]:
  (targetdir/name).write_bytes((test/name).read_bytes())
 for path in product[1:3]:
  data=git('show',base+':'+path) if target=='LegacySeed' else (repo/path).read_bytes()
  (targetdir/pathlib.Path(path).name).write_bytes(data)
for name,header,library in [('SQLite3','/usr/include/sqlite3.h','sqlite3'),('COpenSSL','/usr/include/openssl/sha.h','crypto')]:
 d=work/'Sources'/name;d.mkdir(parents=True)
 (d/'module.modulemap').write_text('module '+name+' [system] {\n header "'+header+'"\n link "'+library+'"\n export *\n}\n')
package='''// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "OtzariaAnnotationPayloadBudget",
 dependencies: [.package(name: "OtzariaActionCore", path: %s)],
 targets: [
 .systemLibrary(name: "SQLite3"), .systemLibrary(name: "COpenSSL"),
 .executableTarget(name: "LegacySeed", dependencies: ["SQLite3", "COpenSSL", .product(name: "OtzariaActionCore", package: "OtzariaActionCore")]),
 .executableTarget(name: "BudgetAccept", dependencies: ["SQLite3", "COpenSSL", .product(name: "OtzariaActionCore", package: "OtzariaActionCore")])
 ], swiftLanguageModes: [.v6])
''' % json.dumps(str(repo/'Source/Otzaria/Actions'))
(work/'Package.swift').write_text(package)
for d,dirs,files in os.walk(work):
 os.chown(d,1001,1001)
 for name in files:os.chown(pathlib.Path(d)/name,1001,1001)
commands=[]
def run(name,argv,timeout):
 stdout=evidence/(name+'.stdout.log');stderr=evidence/(name+'.stderr.log')
 start=time.monotonic();timed=False
 with stdout.open('wb') as out,stderr.open('wb') as err:
  p=subprocess.Popen(['runuser','-u','ubuntu','--',*argv],stdout=out,stderr=err,start_new_session=True)
  try:code=p.wait(timeout=timeout)
  except subprocess.TimeoutExpired:
   timed=True;os.killpg(p.pid,signal.SIGTERM)
   try:code=p.wait(timeout=5)
   except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);code=p.wait(timeout=5)
  try:os.killpg(p.pid,0);remaining=True
  except ProcessLookupError:remaining=False
  if remaining:
   os.killpg(p.pid,signal.SIGKILL)
   for _ in range(50):
    try:os.killpg(p.pid,0)
    except ProcessLookupError:remaining=False;break
    time.sleep(0.1)
 rec={'name':name,'argv':argv,'returncode':code,'timed_out':timed,'elapsed_seconds':round(time.monotonic()-start,3),'process_group_drained':not remaining,
      'stdout_bytes':stdout.stat().st_size,'stdout_sha256':sha(stdout.read_bytes()),'stderr_bytes':stderr.stat().st_size,'stderr_sha256':sha(stderr.read_bytes())}
 commands.append(rec);(evidence/(name+'.command.json')).write_text(json.dumps(rec,indent=2)+'\n')
 assert code==0 and not timed and not remaining,rec
 return stdout.read_text()
result={'status':'FAILED_BEFORE_COMPLETION','scope':'Oracle Linux actual SQLite typed-envelope controls','base':base,'native_body_qualified':False,'apple_ui_qualified':False}
try:
 result['swift']=run('swift-version',['/usr/local/bin/swift','--version'],20).strip()
 run('compile',['/usr/local/bin/swift','build','--package-path',str(work),'--scratch-path',str(work/'build'),'--jobs','2'],450)
 bindir=pathlib.Path(run('bin-path',['/usr/local/bin/swift','build','--package-path',str(work),'--scratch-path',str(work/'build'),'--show-bin-path'],30).strip())
 result['binaries']={name:{'sha256':sha((bindir/name).read_bytes()),'bytes':(bindir/name).stat().st_size} for name in ['LegacySeed','BudgetAccept']}
 seedroot=work/'owned-fixtures';seedroot.mkdir();os.chown(seedroot,1001,1001)
 result['seeder']=json.loads(run('original-v1-seed',[str(bindir/'LegacySeed'),str(seedroot)],120))
 result['controls']=json.loads(run('candidate-controls',[str(bindir/'BudgetAccept'),str(seedroot)],180))
 result['status']='PASS'
except Exception as error:
 result['error']=str(error)
finally:
 after={p:{'bytes':len((repo/p).read_bytes()),'sha256':sha((repo/p).read_bytes())} for p in paths}
 result['sources_unchanged_during_execution']=before==after
 result['commands']=commands
 result['all_owned_process_groups_drained']=all(x['process_group_drained'] for x in commands)
 (evidence/'SOURCE_AFTER.json').write_text(json.dumps(after,indent=2)+'\n')
 (evidence/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps({'status':result['status'],'result_path':str(evidence/'RESULT.json'),'result_sha256':sha((evidence/'RESULT.json').read_bytes()),'commands':commands,'error':result.get('error'),'controls':result.get('controls')}),flush=True)
if result['status']!='PASS' or before!=after:raise SystemExit(1)
