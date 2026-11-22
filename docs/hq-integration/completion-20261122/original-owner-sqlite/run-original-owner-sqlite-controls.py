#!/usr/bin/env python3
"""Six new controls joining actual original Owner and actual original SQLite.
No original test suite, native SDK, RPC, identity writer or production schema.
"""
from pathlib import Path
import argparse, hashlib, json, os, platform, shutil, subprocess, sys, time, traceback

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
CONTROL=HERE/"OriginalOwnerSQLiteAcceptance.swift"
MANIFEST=HERE/"PRODUCTION_INPUTS.json"

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def write(path,value): path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+"\n",encoding="utf-8",newline="\n")

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--result-dir",type=Path,required=True)
    args=parser.parse_args()
    out=args.result_dir.resolve()
    out.mkdir(parents=True,exist_ok=False)
    build=HERE/"build"/out.name
    build.mkdir(parents=True,exist_ok=False)
    copies=build/"inputs";copies.mkdir()
    fixture=out/"fixtures";fixture.mkdir()
    manifest=json.loads(MANIFEST.read_bytes())
    inputs=[HERE/"inputs"/r["name"] for r in manifest["inputs"]]
    assert len(inputs)==9 and len({p.name for p in inputs})==9
    for path,row in zip(inputs,manifest["inputs"]):
        assert sha(path)==row["compiled_sha256"]
    closure=inputs+[CONTROL,MANIFEST,Path(__file__).resolve()]
    before={p.relative_to(ROOT).as_posix():sha(p) for p in closure}
    for path in inputs+[CONTROL]: shutil.copyfile(path,copies/path.name)
    compiled={p.name:sha(copies/p.name) for p in inputs+[CONTROL]}
    assert all(compiled[p.name]==sha(p) for p in inputs+[CONTROL])
    expected=[
        "current_owner_outer_commit_succeeds",
        "retirement_before_admission_denies_body",
        "account_retirement_after_admission_commits_without_publication",
        "retirement_after_commit_preserves_durable_fact",
        "deferred_fk_commit_failure_rolls_back",
        "owner_and_account_teardown_wait_for_actual_drain"
    ]
    env=os.environ.copy()
    compiler=shutil.which("swiftc")
    assert compiler,"original installed Swift compiler required"
    link=[]
    interop={}
    if os.name=="nt":
        sdkroot=Path(os.environ.get("ProgramFiles(x86)",r"C:\Program Files (x86)"))/"Windows Kits/10"
        sdk=next(p for p in sorted((sdkroot/"Include").glob("*"),reverse=True) if (p/"um/winsqlite/winsqlite3.h").is_file())
        header=sdk/"um/winsqlite/winsqlite3.h"
        module=build/"SQLite3";module.mkdir()
        modulemap=module/"module.modulemap"
        modulemap.write_text('module SQLite3 [system] { header '+json.dumps(header.as_posix())+' link "winsqlite3" export * }\n',encoding="utf-8",newline="\n")
        library=sdkroot/"Lib"/sdk.name/"um/x64/winsqlite3.lib"
        link=["-I",str(module),"-L",str(library.parent)]
        interop={"platform":"Windows SDK winsqlite3","header":str(header),"header_sha256":sha(header),"import_library":str(library),"import_library_sha256":sha(library),"modulemap":modulemap.read_text(),"modulemap_sha256":sha(modulemap)}
        runtime=Path(r"C:\Users\DAVID\AppData\Local\Programs\Swift\Runtimes\6.3.3\usr\bin")
        assert runtime.is_dir()
        env["PATH"]=str(runtime)+os.pathsep+env["PATH"]
    elif sys.platform=="darwin":
        link=["-lsqlite3"]
        interop={"platform":"original Apple SDK SQLite3; no custom module map"}
    else: raise RuntimeError("Only the original Windows/Apple toolchain is admitted")
    exe=build/("OriginalOwnerSQLiteAcceptance.exe" if os.name=="nt" else "OriginalOwnerSQLiteAcceptance")
    report={
        "status":"FAILED","platform":platform.platform(),"commands":[],
        "original_owner_source":manifest["original_owner_source"],"application_source":manifest["application_source"],
        "expected_controls":expected,"selected_controls":6,"original_suites_reexecuted":False,
        "actual_original_owner":True,"actual_original_sqlite":True,
        "fixture_only_document_permission_values":True,"fixture_only_tables":True,
        "native_rpc":0,"production_identity_write":0,"native_receipt":0,"ack":0,
        "interop":interop
    }
    write(out/"SOURCE_MANIFEST.json",{
        "head":subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip(),
        "inputs":before,"compiled_copies":compiled,
        "producer_provenance":manifest,"source_changes":"none; new fixture-only composition controls",
        "unchanged_old_suites_not_executed":["OwnerModal14","Core194","exchange28","Cloud48","Native","Live"]
    })
    def run(label,args,timeout):
        started=time.monotonic()
        with (out/(label+".stdout.log")).open("wb") as stdout,(out/(label+".stderr.log")).open("wb") as stderr:
            try: process=subprocess.run(args,cwd=ROOT,env=env,stdout=stdout,stderr=stderr,timeout=timeout)
            except subprocess.TimeoutExpired:
                report["commands"].append({"label":label,"command":args,"exit":None,"timeout":timeout,"seconds":time.monotonic()-started})
                raise
        report["commands"].append({"label":label,"command":args,"exit":process.returncode,"seconds":time.monotonic()-started})
        return process
    try:
        report["swift"]=subprocess.check_output([compiler,"--version"],env=env,text=True,encoding="utf-8").strip()
        command=[compiler,"-swift-version","5","-strict-concurrency=complete","-parse-as-library","-j","1","-whole-module-optimization","-Onone"]+link+[str(copies/p.name) for p in inputs+[CONTROL]]+["-o",str(exe)]
        result=run("compile",command,480)
        assert result.returncode==0,"actual original source compilation failed"
        report["executable_sha256"]=sha(exe)
        result=run("controls",[str(exe),"controls",str(fixture)],120)
        cases=json.loads((fixture/"CASES.json").read_bytes())
        report["cases"]=cases
        assert result.returncode==0 and [r["name"] for r in cases]==expected and all(r["status"]=="PASS" and r.get("error") is None for r in cases),"new Owner/SQLite controls failed"
        result=run("reopen",[str(exe),"reopen",str(fixture)],60)
        assert result.returncode==0,"new-process original SQLite readback failed"
        writer=json.loads((fixture/"WRITER.json").read_bytes());reopen=json.loads((fixture/"REOPEN.json").read_bytes())
        assert writer["pid"]!=reopen["pid"] and int(writer["pid"])>0 and int(reopen["pid"])>0
        assert writer["sqlite"]==reopen["sqlite"] and reopen["status"]=="PASS"
        assert all(writer[k]==reopen[k]=="0" for k in ["nativeRPC","productionIdentityWrites","nativeReceipts","ACK"])
        report["writer"]=writer;report["reopen"]=reopen
        report["status"]="PASS_ORIGINAL_OWNER_SQLITE6_DISTINCT_PROCESS_REOPEN"
    except Exception as error:
        report["error"]=repr(error)
        (out/"failure.log").write_text(traceback.format_exc(),encoding="utf-8",newline="\n")
    finally:
        report["sources_unchanged"]=before=={p.relative_to(ROOT).as_posix():sha(p) for p in closure}
        report["compiled_copies_unchanged"]=compiled=={p.name:sha(copies/p.name) for p in inputs+[CONTROL]}
        if not report["sources_unchanged"] or not report["compiled_copies_unchanged"]:report["status"]="FAILED"
        write(out/"RESULT.json",report)
        print(json.dumps({k:v for k,v in report.items() if k!="cases"},indent=2),flush=True)
    return 0 if report["status"]=="PASS_ORIGINAL_OWNER_SQLITE6_DISTINCT_PROCESS_REOPEN" else 1

if __name__=="__main__":sys.exit(main())
