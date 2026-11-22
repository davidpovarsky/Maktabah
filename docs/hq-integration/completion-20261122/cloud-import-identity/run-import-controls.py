#!/usr/bin/env python3
"""Compile the original Repository/SQLite and exercise owned CloudKit-import fixtures."""
from pathlib import Path
import argparse,hashlib,json,os,platform,shutil,subprocess,sys,time
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
SOURCES=[
 'Source/Features/Annotations/Models/Annotation.swift',
 'Source/Features/Annotations/Database/AnnotationRepository.swift',
 'Source/Core/Database/SQLiteDatabase.swift',
 'Source/Core/CloudKit/SyncPendingStore.swift',
 'Tests/HQ/sqlite/UnusedZstdBoundary.swift']
EXPECTED_FAILURES={'same_uuid_locator_and_context','legacy_different_backend','legacy_different_work',
 'legacy_different_position','legacy_negative_missing_locator','legacy_malformed_locator'}
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v): p.write_text(json.dumps(v,indent=2,ensure_ascii=False)+'\n',encoding='utf-8',newline='\n')
def logged(command,label,out,timeout=180,env=None):
 start=time.monotonic()
 r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,encoding='utf-8',timeout=timeout,env=env)
 (out/(label+'.stdout.log')).write_text(r.stdout,encoding='utf-8',newline='\n')
 (out/(label+'.stderr.log')).write_text(r.stderr,encoding='utf-8',newline='\n')
 row={'label':label,'command':command,'exit':r.returncode,'seconds':time.monotonic()-start}
 return r,row
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--phase',choices=['baseline','candidate'],required=True)
 ap.add_argument('--artifacts-dir',type=Path)
 args=ap.parse_args()
 out=args.artifacts_dir.resolve() if args.artifacts_dir else HERE/args.phase
 out.mkdir(parents=True,exist_ok=False)
 build=out/'build' if args.artifacts_dir else HERE/'build'/args.phase
 build.mkdir(parents=True,exist_ok=False)
 fixtures=out/'fixtures';fixtures.mkdir()
 source_paths=[ROOT/x for x in SOURCES]+[HERE/x for x in ['Boundary.swift','OriginalLocator.swift','OriginalLocalConnection.swift','CloudImportIdentityControls.swift']]
 helper=ROOT/'Source/ChavrusaText/Annotations/AnnotationCloudImportIdentity.swift'
 if args.phase=='candidate':
  assert helper.is_file()
  source_paths.append(helper)
 # The locator and lifetime pieces are exact source declarations, not doubles.
 actual=(ROOT/'Source/LibraryBackend/LibraryBackendModels.swift').read_text(encoding='utf-8')
 assert (HERE/'OriginalLocator.swift').read_text(encoding='utf-8')==actual[:actual.index('/// A canonical reader destination:')]
 actual=(ROOT/'Source/ChavrusaText/Annotations/LocalEditor/AnnotationLocalEditorModels.swift').read_text(encoding='utf-8')
 assert (HERE/'OriginalLocalConnection.swift').read_text(encoding='utf-8')=='import Foundation\nimport Synchronization\n\n'+actual[actual.index('enum AnnotationLocalEditorError:'):actual.index('struct AnnotationLocalEditorBodyFormat:')]
 provenance=source_paths+[ROOT/'Source/LibraryBackend/LibraryBackendModels.swift',ROOT/'Source/ChavrusaText/Annotations/LocalEditor/AnnotationLocalEditorModels.swift',HERE/'OSLogBoundary.swift',Path(__file__).resolve()]
 before={str(p.relative_to(ROOT)).replace('\\','/'):sha(p) for p in provenance}
 write(out/'SOURCE_MANIFEST.json',{'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'phase':args.phase,'sources':before,'whole_original_repository_annotation_sqlite_pending':True,'actual_locator_and_lifetime_declarations':True,'boundary':'logging (Windows only), catalog/title/UI helpers and unused compressed-blob decoder; no Store/CloudKit/Native'})
 report={'phase':args.phase,'status':'NOT_RUN','commands':[],'native_executed':0,'cloudkit_transport_executed':0}
 try:
  extra=[];env=os.environ.copy()
  if os.name=='nt':
   swift=['swiftc']
   support=HERE/'build/support';support.mkdir(parents=True,exist_ok=True)
   oslog=support/'OSLog.dll'
   oslog_identity=support/'OSLog.source.sha256'
   if not oslog.is_file():
    r,record=logged(swift+['-swift-version','6','-parse-as-library','-emit-library','-emit-module','-module-name','OSLog',str(HERE/'OSLogBoundary.swift'),'-emit-module-path',str(support/'OSLog.swiftmodule'),'-o',str(oslog)],'compile-oslog-boundary',out)
    report['commands'].append(record);assert r.returncode==0,'logging boundary compile failed'
    oslog_identity.write_text(sha(HERE/'OSLogBoundary.swift'))
   else:assert oslog_identity.read_text()==sha(HERE/'OSLogBoundary.swift')
   sdk_root=Path(os.environ.get('ProgramFiles(x86)',r'C:\Program Files (x86)'))/'Windows Kits/10'
   sdk=next(p for p in sorted((sdk_root/'Include').glob('*'),reverse=True) if (p/'um/winsqlite/winsqlite3.h').is_file())
   header=sdk/'um/winsqlite/winsqlite3.h'
   module=support/'SQLite3';module.mkdir(exist_ok=True)
   (module/'module.modulemap').write_text('module SQLite3 [system] { header '+json.dumps(header.as_posix())+' link "winsqlite3" export * }\n',encoding='utf-8',newline='\n')
   extra=['-I',str(support),'-I',str(module),'-L',str(support),'-lOSLog','-L',str(sdk_root/'Lib'/sdk.name/'um/x64')]
   env['PATH']=str(support)+os.pathsep+env.get('PATH','')
   report['sqlite_header']={'path':str(header),'sha256':sha(header)}
   report['logging']='explicit Windows OSLog boundary; original Repository source untouched'
   exe=build/'cloud-import-controls.exe'
  elif sys.platform=='darwin':
   swift=['xcrun','--sdk','macosx','swiftc']
   extra=['-target',platform.machine()+'-apple-macosx15.0','-lsqlite3']
   report['logging']='original Apple OSLog'
   report['sdk']=subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
   exe=build/'cloud-import-controls'
  else:raise RuntimeError('Use existing Windows SDK or actual Apple SDK, no compiler installation')
  report['toolchain']=subprocess.check_output(swift+['--version'],text=True).strip()
  command=swift+['-swift-version','6','-j','1','-parse-as-library',*extra,*map(str,source_paths),'-o',str(exe)]
  r,record=logged(command,'compile-original-repository',out,240);report['commands'].append(record)
  assert r.returncode==0,'original repository compile failed'
  report['executable_sha256']=sha(exe)
  runs=[]
  for mode in ['write','reopen']:
   r,record=logged([str(exe),mode,str(fixtures)],mode,out,60,env)
   report['commands'].append(record);assert r.returncode==0,mode+' process failed'
   observed=json.loads((fixtures/(mode+'.json')).read_text())
   assert observed['mode']==mode and len(observed['cases'])==9
   names=[v['name'] for v in observed['cases']]
   assert len(set(names))==9
   failed={v['name'] for v in observed['cases'] if v['status']!='PASS'}
   assert failed==(EXPECTED_FAILURES if args.phase=='baseline' else set()),mode+': unexpected cases '+str(failed)
   runs.append(observed)
  assert runs[0]['process_id']!=runs[1]['process_id']
  report['write']={k:runs[0][k] for k in ['process_id','sqlite_version','passed','failed','cases']}
  report['fresh_process_reopen']={k:runs[1][k] for k in ['process_id','sqlite_version','passed','failed','cases']}
  report['status']='BASELINE_DEFECTS_REPRODUCED' if args.phase=='baseline' else 'PASS_REAL_REPOSITORY_SQLITE'
 except Exception as e:
  report['status']='FAILED';report['error']=repr(e)
 finally:
  report['source_unchanged']=before=={str(p.relative_to(ROOT)).replace('\\','/'):sha(p) for p in provenance}
  if not report['source_unchanged']:report['status']='FAILED'
  write(out/'RESULT.json',report)
  print(json.dumps(report,indent=2))
 return 0 if report['status'] in ['BASELINE_DEFECTS_REPRODUCED','PASS_REAL_REPOSITORY_SQLITE'] else 1
if __name__=='__main__':sys.exit(main())
