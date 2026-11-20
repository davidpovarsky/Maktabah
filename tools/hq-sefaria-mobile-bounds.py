#!/usr/bin/env python3
"""Whole-source bounds controls; baseline is the verified previous run snapshot."""
import argparse, datetime as dt, hashlib, importlib.util, json, shutil, subprocess, sys, time
from pathlib import Path

def sha(raw): return hashlib.sha256(raw).hexdigest()
def utc(): return dt.datetime.now(dt.timezone.utc).isoformat()
def main():
    p=argparse.ArgumentParser()
    p.add_argument("--root",type=Path,default=Path(__file__).resolve().parents[1])
    p.add_argument("--output",type=Path,required=True)
    p.add_argument("--module-cache",type=Path,required=True)
    p.add_argument("--baseline-inputs",type=Path)
    a=p.parse_args();root=a.root.resolve();out=a.output.resolve()
    if out.exists() or not a.module_cache.is_dir(): raise RuntimeError("Need new output and existing cache")
    spec=importlib.util.spec_from_file_location("original_language_driver",root/"tools/hq-sefaria-navigation-language.py")
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    out.mkdir(parents=True); inputs=out/"inputs"; inputs.mkdir()
    baseline={}
    if a.baseline_inputs:
        baseline={r["path"]:r for r in json.loads((a.baseline_inputs.parent/"INPUTS.json").read_text(encoding="utf-8"))}
    rows=[]; paths=[]; original=[]
    for rel in module.PRODUCTION+["Tests/HQ/sefaria-mobile-navigation/MobileBoundAcceptance.swift"]:
        use_old=a.baseline_inputs is not None and rel.startswith("Source/")
        source=a.baseline_inputs/rel if use_old else root/rel
        raw=source.read_bytes()
        if use_old and sha(raw)!=baseline[rel]["sha256"]: raise RuntimeError("Baseline snapshot hash mismatch: "+rel)
        target=inputs/rel;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw);paths.append(str(target))
        rows.append({"path":rel,"bytes":len(raw),"sha256":sha(raw),"baselineSnapshot":use_old})
        original.append((source,sha(raw)))
    (out/"INPUTS.json").write_text(json.dumps(rows,indent=2),encoding="utf-8")
    result={"startedAt":utc(),"baselineInputs":str(a.baseline_inputs) if a.baseline_inputs else None,
            "productionExtraction":"NONE","native":"NOT_RUN","appleSDK":"NOT_RUN"}
    try:
        exe=out/"mobile-bounds.exe"
        cmd=[shutil.which("swiftc"),"-j1","-swift-version","6","-strict-concurrency=complete",
             "-module-cache-path",str(a.module_cache),*paths,"-o",str(exe)]
        (out/"COMMANDS.json").write_text(json.dumps({"compile":cmd,"compileTimeout":180,"runtimeTimeout":30},indent=2),encoding="utf-8")
        start=time.monotonic();r=subprocess.run(cmd,capture_output=True,timeout=180)
        result["compile"]={"returncode":r.returncode,"seconds":time.monotonic()-start}
        (out/"compile.stdout.log").write_bytes(r.stdout);(out/"compile.stderr.log").write_bytes(r.stderr)
        if r.returncode: raise RuntimeError("compile failure")
        start=time.monotonic();r=subprocess.run([str(exe)],capture_output=True,timeout=30)
        result["runtime"]={"returncode":r.returncode,"seconds":time.monotonic()-start}
        (out/"runtime.stdout.log").write_bytes(r.stdout);(out/"runtime.stderr.log").write_bytes(r.stderr)
        cases=json.loads(r.stdout.decode("utf-8"));expected=["depth-one.original-scalar-addresses","depth-one.ambiguous-array-rejected",
             "named-leaves.valid-canonical-membership","named-leaves.every-child-consumes-budget"]
        if [c["name"] for c in cases]!=expected: raise RuntimeError("Exact unique cases changed")
        (out/"CASES.json").write_text(json.dumps(cases,ensure_ascii=False,indent=2),encoding="utf-8")
        result.update(executed=len(cases),passed=sum(c["passed"] for c in cases),failed=[c["name"] for c in cases if not c["passed"]])
        result["status"]="PASS" if r.returncode==0 and not result["failed"] else "FAIL"
        result["executableSHA256"]=sha(exe.read_bytes())
    except Exception as error:
        result["status"]="ERROR";result["error"]=str(error);result.setdefault("executed",0)
    result["inputHashesUnchanged"]=all(sha(source.read_bytes())==digest for source,digest in original)
    result["finishedAt"]=utc()
    if not result["inputHashesUnchanged"]:result["status"]="ERROR"
    (out/"RESULT.json").write_text(json.dumps(result,indent=2),encoding="utf-8")
    print(json.dumps(result,indent=2));return 0 if result["status"]=="PASS" else 1
if __name__=="__main__":sys.exit(main())
