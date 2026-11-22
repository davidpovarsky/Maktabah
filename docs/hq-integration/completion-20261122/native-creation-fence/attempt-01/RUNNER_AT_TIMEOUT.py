#!/usr/bin/env python3
"""New native-create fence controls on whole original SQLite/ledger/Core sources.
No original test suite, native SDK, RPC or transport is run.
"""
from pathlib import Path
import argparse,datetime,hashlib,json,os,platform,re,shutil,subprocess,sys,time,traceback
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
SOURCES=[
 "Source/Core/Database/SQLiteDatabase.swift",
 "Source/Core/CloudKit/SyncPendingStore.swift",
 "Source/ChavrusaText/Annotations/Exchange/TorahAnnotationEnvelope.swift",
 "Source/ChavrusaText/Annotations/Exchange/AnnotationExchangeLedger.swift",
 "Tests/HQ/sqlite/UnusedZstdBoundary.swift",
 "Tests/HQ/annotation-exchange/AnnotationExchangeTestSupport.swift",
]
CONTROL=HERE/"NativeCreationFenceAcceptance.swift"
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,value):p.write_text(json.dumps(value,ensure_ascii=False,indent=2)+"\n",encoding="utf-8",newline="\n")
def main():
 parser=argparse.ArgumentParser();parser.add_argument("--result-dir",type=Path,required=True)
 args=parser.parse_args();out=args.result_dir.resolve()
 out.mkdir(parents=True,exist_ok=False)
 build=HERE/"build"/out.name
 build.mkdir(parents=True,exist_ok=False)
 package=build/"package";target=package/"Sources/NativeCreationFenceAcceptance";target.mkdir(parents=True)
 fixtures=out/"fixtures";fixtures.mkdir()
 core=ROOT/"Source/Otzaria/Actions"
 core_files=[p for p in sorted((core/"Sources").rglob("*")) if p.is_file()]+[core/"Package.swift"]
 inputs=[ROOT/p for p in SOURCES]+core_files+[CONTROL,Path(__file__).resolve()]
 before={p.relative_to(ROOT).as_posix():sha(p) for p in inputs}
 names=re.findall(r'await run\("([a-z0-9_]+)"',CONTROL.read_text(encoding="utf-8"))
 assert len(names)==18 and len(set(names))==18
 for p in [ROOT/s for s in SOURCES]+[CONTROL]:shutil.copyfile(p,target/p.name)
 copy_hashes={p.name:sha(target/p.name) for p in [ROOT/s for s in SOURCES]+[CONTROL]}
 assert all(copy_hashes[p.name]==sha(p) for p in [ROOT/s for s in SOURCES]+[CONTROL])
 linker=[];sqlite_target="";sqlite_dep=""
 if os.name=="nt":
  sdk_root=Path(os.environ.get("ProgramFiles(x86)",r"C:\Program Files (x86)"))/"Windows Kits/10"
  sdk=next(p for p in sorted((sdk_root/"Include").glob("*"),reverse=True) if (p/"um/winsqlite/winsqlite3.h").is_file())
  module=package/"Sources/SQLite3";module.mkdir()
  (module/"module.modulemap").write_text('module SQLite3 [system] { header '+json.dumps((sdk/"um/winsqlite/winsqlite3.h").as_posix())+' link "winsqlite3" export * }\n',encoding="utf-8",newline="\n")
  sqlite_target='.systemLibrary(name:"SQLite3"),';sqlite_dep='"SQLite3",'
  linker=['.unsafeFlags(["-L",'+json.dumps((sdk_root/"Lib"/sdk.name/"um/x64").as_posix())+'])','.linkedLibrary("bcrypt")']
 elif sys.platform=="darwin":linker=['.linkedLibrary("sqlite3")']
 else:raise RuntimeError("Use existing Windows or Apple toolchain")
 manifest="""// swift-tools-version: 6.0
import PackageDescription
let package=Package(name:"NativeCreationFenceAcceptance",platforms:[.macOS(.v14)],
 dependencies:[.package(path:CORE_PATH)],targets:[
 SQLITE_TARGET
 .executableTarget(name:"NativeCreationFenceAcceptance",
  dependencies:[SQLITE_DEP.product(name:"OtzariaActionCore",package:"actions")],
  swiftSettings:[.unsafeFlags(["-strict-concurrency=complete"])],
  linkerSettings:[LINKER])
 ],swiftLanguageModes:[.v6])
"""
 manifest=manifest.replace("CORE_PATH",json.dumps(core.as_posix())).replace("SQLITE_TARGET",sqlite_target).replace("SQLITE_DEP",sqlite_dep).replace("LINKER",",".join(linker))
 (package/"Package.swift").write_text(manifest,encoding="utf-8",newline="\n")
 write(out/"SOURCE_MANIFEST.json",{"head":subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip(),"sources":before,"whole_original_sqlite_queue_envelope_ledger":True,"core_dependency_fresh_current_source":True,"compiled_copies":copy_hashes,"test_support_reused_unchanged":SOURCES[-1],"scope":"18 new SQLite controls and three abrupt termination/separate reopen boundaries; no original28 or Core194 suite runs","boundary":"Original fixture schema/digest/test support and unused ZSTD boundary; identity rows seeded by explicit fixture-only SQL, not SDK proof."})
 report={"status":"FAILED","platform":platform.platform(),"commands":[],"original_suites_reexecuted":False,"native_sdk":0,"rpc":0,"transport":0,"cloudkit_network":0,"identity_production_write":0,"ack_from_new_component":0,"crash_processes":[]}
 def run(label,args,timeout):
  started=time.monotonic();p=subprocess.run(args,cwd=ROOT,text=True,capture_output=True,encoding="utf-8",timeout=timeout)
  (out/(label+".stdout.log")).write_text(p.stdout,encoding="utf-8",newline="\n")
  (out/(label+".stderr.log")).write_text(p.stderr,encoding="utf-8",newline="\n")
  report["commands"].append({"label":label,"command":args,"exit":p.returncode,"seconds":time.monotonic()-started})
  return p
 try:
  report["swift"]=subprocess.check_output(["swift","--version"],text=True,encoding="utf-8").strip()
  cmd=["swift","build","--package-path",str(package),"--scratch-path",str(build/"swift-build"),"-j","2"]
  p=run("compile",cmd,300);assert p.returncode==0,"whole-source compilation failed"
  location=run("binary-path",cmd+["--show-bin-path"],60);assert location.returncode==0
  exe=Path(location.stdout.strip())/("NativeCreationFenceAcceptance.exe" if os.name=="nt" else "NativeCreationFenceAcceptance")
  report["executable_sha256"]=sha(exe)
  p=run("controls",[str(exe),"controls",str(fixtures)],120)
  cases=json.loads((fixtures/"CASES.json").read_bytes());report["cases"]=cases
  assert p.returncode==0 and len(cases)==18 and {x["name"] for x in cases}==set(names) and all(x["status"]=="PASS" and x.get("error") is None for x in cases),"new SQLite controls failed"
  for phase in ["prepared","marked","nested"]:
   killed=run("crash-"+phase,[str(exe),"crash-"+phase,str(fixtures)],30)
   assert killed.returncode==73,"writer did not terminate abruptly at the required boundary"
   reopened=run("reopen-"+phase,[str(exe),"reopen-"+phase,str(fixtures)],30);assert reopened.returncode==0,"fresh process reopen failed"
   writer=json.loads((fixtures/("writer-"+phase+".json")).read_bytes());result=json.loads((fixtures/("reopen-"+phase+".json")).read_bytes())
   assert result["status"]=="PASS" and writer["pid"]!=result["pid"] and all(result[k]=="0" for k in ["nativeRPC","identityWrite","ACK"])
   report["crash_processes"].append({"phase":phase,"writer":writer,"reopen":result,"abrupt_exit":killed.returncode})
  report["status"]="PASS_NEW_NATIVE_CREATION_FENCE_SQLITE"
 except Exception as error:
  report["error"]=repr(error);(out/"failure.log").write_text(traceback.format_exc(),encoding="utf-8",newline="\n")
 finally:
  report["sources_unchanged"]=before=={p.relative_to(ROOT).as_posix():sha(p) for p in inputs}
  report["copied_sources_unchanged"]=copy_hashes=={p.name:sha(target/p.name) for p in [ROOT/s for s in SOURCES]+[CONTROL]}
  if not report["sources_unchanged"] or not report["copied_sources_unchanged"]:report["status"]="FAILED"
  write(out/"RESULT.json",report)
  print(json.dumps({k:v for k,v in report.items() if k!="cases"},ensure_ascii=False,indent=2),flush=True)
 return 0 if report["status"]=="PASS_NEW_NATIVE_CREATION_FENCE_SQLITE" else 1
if __name__=="__main__":sys.exit(main())
