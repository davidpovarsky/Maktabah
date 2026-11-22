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
def compiler_inputs():
 core=ROOT/"Source/Otzaria/Actions"
 core_files=[p for p in sorted((core/"Sources").rglob("*")) if p.is_file()]+[core/"Package.swift"]
 return [ROOT/p for p in SOURCES]+core_files+[CONTROL,Path(__file__).resolve()]
def main():
 parser=argparse.ArgumentParser();parser.add_argument("--result-dir",type=Path,required=True)
 parser.add_argument("--reuse-build-dir",type=Path)
 parser.add_argument("--compile-timeout",type=int,default=900)
 parser.add_argument("--suite",choices=["controls","uuid-red","uuid-affected","all-controls"],default="controls")
 parser.add_argument("--refresh-copied-inputs",action="store_true")
 args=parser.parse_args();out=args.result_dir.resolve()
 out.mkdir(parents=True,exist_ok=False)
 build=(args.reuse_build_dir or HERE/"build"/out.name).resolve()
 if args.reuse_build_dir:
  assert build.is_relative_to((HERE/"build").resolve()) and build.is_dir(),"only an existing owned build may be resumed"
 else:build.mkdir(parents=True,exist_ok=False)
 package=build/"package";target=package/"Sources/NativeCreationFenceAcceptance"
 if not args.reuse_build_dir:target.mkdir(parents=True)
 fixtures=out/"fixtures";fixtures.mkdir()
 core=ROOT/"Source/Otzaria/Actions"
 inputs=compiler_inputs()
 before={p.relative_to(ROOT).as_posix():sha(p) for p in inputs}
 names=re.findall(r'await run\("([a-z0-9_]+)"',CONTROL.read_text(encoding="utf-8"))
 assert len(names)==18 and len(set(names))==18
 uuid_names=re.findall(r'await runUUID\("([a-z0-9_]+)"',CONTROL.read_text(encoding="utf-8"))
 assert len(uuid_names)==6 and len(set(uuid_names))==6
 expected=names if args.suite=="controls" else names+uuid_names if args.suite=="all-controls" else uuid_names[:1] if args.suite=="uuid-red" else names[5:]+uuid_names
 copied_deltas=[]
 for p in [ROOT/s for s in SOURCES]+[CONTROL]:
  if args.reuse_build_dir and sha(p)!=sha(target/p.name):
   assert args.refresh_copied_inputs,"changed compiler inputs require explicit reviewed refresh"
   copied_deltas.append({"path":p.relative_to(ROOT).as_posix(),"before":sha(target/p.name),"after":sha(p)})
   shutil.copyfile(p,target/p.name)
  elif not args.reuse_build_dir:shutil.copyfile(p,target/p.name)
 copy_hashes={p.name:sha(target/p.name) for p in [ROOT/s for s in SOURCES]+[CONTROL]}
 assert all(copy_hashes[p.name]==sha(p) for p in [ROOT/s for s in SOURCES]+[CONTROL])
 linker=[];sqlite_target="";sqlite_dep=""
 if os.name=="nt":
  sdk_root=Path(os.environ.get("ProgramFiles(x86)",r"C:\Program Files (x86)"))/"Windows Kits/10"
  sdk=next(p for p in sorted((sdk_root/"Include").glob("*"),reverse=True) if (p/"um/winsqlite/winsqlite3.h").is_file())
  module=package/"Sources/SQLite3";module.mkdir(exist_ok=bool(args.reuse_build_dir))
  module_text='module SQLite3 [system] { header '+json.dumps((sdk/"um/winsqlite/winsqlite3.h").as_posix())+' link "winsqlite3" export * }\n'
  if args.reuse_build_dir:assert (module/"module.modulemap").read_text(encoding="utf-8")==module_text
  else:(module/"module.modulemap").write_text(module_text,encoding="utf-8",newline="\n")
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
 if args.reuse_build_dir:assert (package/"Package.swift").read_text(encoding="utf-8")==manifest
 else:(package/"Package.swift").write_text(manifest,encoding="utf-8",newline="\n")
 write(out/"SOURCE_MANIFEST.json",{"head":subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip(),"sources":before,"whole_original_sqlite_queue_envelope_ledger":True,"core_dependency_fresh_current_source":True,"compiled_copies":copy_hashes,"test_support_reused_unchanged":SOURCES[-1],"scope":{"suite":args.suite,"selected_cases":expected,"crash_reopen_pairs":0 if args.suite=="uuid-red" else 3,"no_original28_or_Core194":True},"copied_input_deltas":copied_deltas,"boundary":"Original fixture schema/digest/test support and unused ZSTD boundary; identity rows seeded by explicit fixture-only SQL, not SDK proof."})
 report={"status":"FAILED","platform":platform.platform(),"commands":[],"original_suites_reexecuted":False,"native_sdk":0,"rpc":0,"transport":0,"cloudkit_network":0,"identity_production_write":0,"ack_from_new_component":0,"crash_processes":[]}
 def run(label,args,timeout):
  started=time.monotonic()
  stdout=out/(label+".stdout.log");stderr=out/(label+".stderr.log")
  with stdout.open("w",encoding="utf-8",newline="\n") as output,stderr.open("w",encoding="utf-8",newline="\n") as errors:
   try:p=subprocess.run(args,cwd=ROOT,text=True,stdout=output,stderr=errors,encoding="utf-8",timeout=timeout)
   except subprocess.TimeoutExpired:
    report["commands"].append({"label":label,"command":args,"exit":None,"timeout":timeout,"seconds":time.monotonic()-started})
    raise
  p.stdout=stdout.read_text(encoding="utf-8");p.stderr=stderr.read_text(encoding="utf-8")
  report["commands"].append({"label":label,"command":args,"exit":p.returncode,"seconds":time.monotonic()-started})
  return p
 try:
  report["swift"]=subprocess.check_output(["swift","--version"],text=True,encoding="utf-8").strip()
  cmd=["swift","build","--package-path",str(package),"--scratch-path",str(build/"swift-build"),"-j","2"]
  report["reused_owned_build"]=bool(args.reuse_build_dir)
  report["suite"]=args.suite;report["selected_cases"]=expected;report["copied_input_deltas"]=copied_deltas
  p=run("compile",cmd,args.compile_timeout);assert p.returncode==0,"whole-source compilation failed"
  location=run("binary-path",cmd+["--show-bin-path"],60);assert location.returncode==0
  exe=Path(location.stdout.strip())/("NativeCreationFenceAcceptance.exe" if os.name=="nt" else "NativeCreationFenceAcceptance")
  report["executable_sha256"]=sha(exe)
  p=run("controls",[str(exe),args.suite,str(fixtures)],120)
  cases=[]
  if args.suite in ["controls","uuid-affected","all-controls"]:cases+=json.loads((fixtures/"CASES.json").read_bytes())
  if args.suite!="controls":cases+=json.loads((fixtures/"UUID_CASES.json").read_bytes())
  report["cases"]=cases
  assert p.returncode==0 and len(cases)==len(expected) and {x["name"] for x in cases}==set(expected) and all(x["status"]=="PASS" and x.get("error") is None for x in cases),"new SQLite controls failed"
  for phase in ([] if args.suite=="uuid-red" else ["prepared","marked","nested"]):
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
