#!/usr/bin/env python3
"""Whole original Swift adapter/RPC/parser with explicit Hermes startup boundary.
Never reads user data or opens a database/index. All five server payloads are
retained original bytes with provenance. Windows is portable evidence only.
"""
import argparse,datetime as dt,hashlib,json,os,shutil,subprocess,sys,time
from pathlib import Path

PRODUCTION = [
 "Source/LibraryBackend/LibraryBackendModels.swift",
 "Source/LibraryBackend/LibraryBackendProtocols.swift",
 "Source/LibraryBackend/LibraryPresentationPolicy+Display.swift",
 "Source/Sefaria/Domain/SefariaModels.swift",
 "Source/Sefaria/Domain/SefariaNavigationParser.swift",
 "Source/Sefaria/Network/SefariaDTOs.swift",
 "Source/Sefaria/Offline/SefariaExportModels.swift",
 "Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift",
 "Source/ChavrusaText/Localization/TalmudHebrewAddressFormatter.swift",
 "Source/SefariaEmbedded/Bridge/SefariaRPCModels.swift",
 "Source/SefariaEmbedded/Bridge/SefariaJSRPCBridge.swift",
 "Source/SefariaEmbedded/Adapters/SefariaEmbeddedNavigationAdapter.swift",
]
TEST_ROOT = "Tests/HQ/sefaria-mobile-navigation"
def sha(data): return hashlib.sha256(data).hexdigest()
def utc(): return dt.datetime.now(dt.timezone.utc).isoformat()
def git(root,*args): return subprocess.check_output(["git","-C",str(root),*args])
def main():
 parser=argparse.ArgumentParser()
 parser.add_argument("--root",type=Path,default=Path(__file__).resolve().parents[1])
 parser.add_argument("--output",type=Path,required=True)
 parser.add_argument("--module-cache",type=Path,required=True)
 parser.add_argument("--baseline-ref")
 args=parser.parse_args()
 root=args.root.resolve(); output=args.output.resolve()
 if output.exists(): raise RuntimeError("Distinct attempt directory required")
 if not args.module_cache.is_dir(): raise RuntimeError("Existing module cache required")
 output.mkdir(parents=True); inputs=output/"inputs";inputs.mkdir()
 record={"startedAt":utc(),"head":git(root,"rev-parse","HEAD").decode().strip(),
         "baselineRef":args.baseline_ref,"native":"NOT_RUN","appleSDK":"NOT_RUN",
         "wholeProductionFiles":PRODUCTION,"productionExtraction":"NONE",
         "boundary":"Only RuntimeManager UIKit/Expo startup and JS transport are fixture boundaries; original entire RPC bridge, parser, models, adapter execute.",
         "freeBytesBefore":shutil.disk_usage(root).free}
 copied=[]; observed={};start=time.monotonic()
 def copy(rel,baseline=False,dest=None):
  source=root/rel
  raw=git(root,"show",args.baseline_ref+":"+rel) if baseline else source.read_bytes()
  target=inputs/(dest or rel);target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)
  copied.append({"path":rel,"snapshot":str(target.relative_to(inputs)),"bytes":len(raw),"sha256":sha(raw),
                 "canonicalLFSHA256":sha(raw.replace(b"\r\n",b"\n"))})
  if not baseline: observed[rel]=sha(raw)
  return str(target)
 try:
  sources=[copy(p,baseline=bool(args.baseline_ref)) for p in PRODUCTION]
  for name in ["Boundary.swift","MobileNavigationAcceptance.swift"]: sources.append(copy(TEST_ROOT+"/"+name))
  inventory=json.loads((root/TEST_ROOT/"CASES.json").read_bytes())
  copy(TEST_ROOT+"/CASES.json",dest="CASES.json")
  provenance=json.loads((root/TEST_ROOT/"Fixtures/PROVENANCE.json").read_bytes())
  copy(TEST_ROOT+"/Fixtures/PROVENANCE.json",dest="Fixtures/PROVENANCE.json")
  for item in provenance["payloads"]:
   raw=(root/TEST_ROOT/"Fixtures"/item["file"]).read_bytes()
   if sha(raw)!=item["sha256"] or len(raw)!=item["bytes"]:raise RuntimeError("Original input digest mismatch")
   copy(TEST_ROOT+"/Fixtures/"+item["file"],dest="Fixtures/"+item["file"])
  compiler=shutil.which("swiftc")
  if not compiler:raise RuntimeError("swiftc unavailable")
  record["toolchain"]=subprocess.check_output([compiler,"--version"],text=True)
  exe=output/("sefaria-mobile-navigation.exe" if os.name=="nt" else "sefaria-mobile-navigation")
  cmd=[compiler,"-j1","-swift-version","6","-strict-concurrency=complete","-module-cache-path",str(args.module_cache)]
  if not args.baseline_ref:cmd+=["-D","MOBILE_LANGUAGE_CASES"]
  cmd+=sources+["-o",str(exe)]
  commands={"compile":cmd,"compileTimeoutSeconds":240,"execute":[str(exe)],"runtimeTimeoutSeconds":90}
  (output/"COMMANDS.json").write_text(json.dumps(commands,indent=2),encoding="utf-8")
  (output/"INPUTS.json").write_text(json.dumps(copied,indent=2),encoding="utf-8")
  t=time.monotonic()
  with (output/"compile.stdout.log").open("wb") as stdout,(output/"compile.stderr.log").open("wb") as stderr:
   ran=subprocess.run(cmd,cwd=inputs,stdout=stdout,stderr=stderr,timeout=240)
  record["compile"]={"returncode":ran.returncode,"elapsedSeconds":time.monotonic()-t}
  if ran.returncode:
   record["status"]="COMPILE_FAILED";record["executed"]=0
   return 2
  record["executable"]={"bytes":exe.stat().st_size,"sha256":sha(exe.read_bytes())}
  t=time.monotonic()
  with (output/"runtime.stdout.log").open("wb") as stdout,(output/"runtime.stderr.log").open("wb") as stderr:
   ran=subprocess.run([str(exe)],cwd=inputs,stdout=stdout,stderr=stderr,timeout=90)
  record["runtime"]={"returncode":ran.returncode,"elapsedSeconds":time.monotonic()-t}
  rows=json.loads((output/"runtime.stdout.log").read_bytes())
  expected=inventory["shared"]+([] if args.baseline_ref else inventory["lang"])
  names=[r["name"] for r in rows]
  if names!=expected or len(set(names))!=len(expected):raise RuntimeError("Exact case inventory/order mismatch")
  if any(type(r["passed"]) is not bool or r["passed"]!=(r["actual"]==r["expected"]) for r in rows):raise RuntimeError("Inconsistent result row")
  failed=[r["name"] for r in rows if not r["passed"]]
  if ran.returncode!=(1 if failed else 0):raise RuntimeError("Exit code disagrees with cases")
  record.update({"executed":len(rows),"passed":sum(r["passed"] for r in rows),"failed":failed,"status":"FAIL" if failed else "PASS",
                 "sharedExecuted":len(inventory["shared"]),"candidateOnlyLanguageExecuted":0 if args.baseline_ref else len(inventory["lang"])})
  (output/"CASES.json").write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding="utf-8")
  return 1 if failed else 0
 except Exception as e:
  record["status"]="ERROR";record["error"]=str(e);raise
 finally:
  record["currentSourceUnchanged"]=all(sha((root/rel).read_bytes())==digest for rel,digest in observed.items())
  record["snapshotInputsUnchanged"]=all(sha((inputs/x["snapshot"]).read_bytes())==x["sha256"] for x in copied)
  record["finishedAt"]=utc();record["elapsedSeconds"]=time.monotonic()-start
  record["freeBytesAfter"]=shutil.disk_usage(root).free
  (output/"RESULT.json").write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding="utf-8")
  print(json.dumps(record,ensure_ascii=False))
  if not record["currentSourceUnchanged"] or not record["snapshotInputsUnchanged"]:raise RuntimeError("Inputs changed while running")
if __name__=="__main__":sys.exit(main())
