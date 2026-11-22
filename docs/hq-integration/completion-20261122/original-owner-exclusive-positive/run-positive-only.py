#!/usr/bin/env python3
"""Only the unresolved positive assertion, plus two fresh-process readbacks.
The entire initial RED packet and its successful negative assertion stay frozen.
"""
from pathlib import Path
import argparse,hashlib,json,os,platform,shutil,subprocess,sys,time,traceback
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
BORROWED=HERE.parent/"original-owner-sqlite"
INITIAL=HERE.parent/"original-owner-exclusive-sqlite"
PRIOR=INITIAL/"validation/windows-exclusive-two-20261122"
ENTRY=HERE/"PositiveOnly.swift"
FRAGMENT=INITIAL/"OriginalOwnerExclusiveSQLiteControls.swift"
FIXTURE=BORROWED/"OriginalOwnerSQLiteAcceptance.swift"
MANIFEST=BORROWED/"PRODUCTION_INPUTS.json"
POSITIVE="exclusive_read_allows_explicit_local_read_scope_commit"
NEGATIVE="exclusive_read_refuses_default_mutation_before_sql"
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def digest(b):return hashlib.sha256(b).hexdigest()
def write(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+"\n",encoding="utf-8",newline="\n")
def git(*args):return subprocess.check_output(["git",*args],cwd=ROOT,timeout=60)
def bounded(data,start,end):
    assert data.count(start)==1 and data.count(end)==1
    return data[data.index(start):data.index(end)]
def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--result-dir",type=Path,required=True)
    args=parser.parse_args()
    assert os.name=="nt","this path-recovery continuation is scoped to the retained Windows evidence"
    out=args.result_dir.resolve();out.mkdir(parents=True,exist_ok=False)
    build=HERE/"build"/out.name;build.mkdir(parents=True,exist_ok=False)
    copies=build/"inputs";copies.mkdir()
    fixture=out/"fixtures";fixture.mkdir()
    positive_db=fixture/(POSITIVE+".sqlite")
    assert len(str(positive_db)+"-journal")<=240,"use a shorter owned fixture directory before invoking SQLite"
    manifest=json.loads(MANIFEST.read_bytes())
    dependencies=[BORROWED/"inputs"/r["name"]for r in manifest["inputs"]]
    assert len(dependencies)==9
    for p,r in zip(dependencies,manifest["inputs"]):assert sha(p)==r["compiled_sha256"]
    assert sha(FIXTURE)=="f922db58646a0c7f5714d487df8f31bef70acdbf49902843c2ddb954a6fef7ea"
    assert sha(FRAGMENT)=="5d4cb2744a4d03d8a46808618ccd78052d316ab7dedffd462cf22bdaf42066ed"
    helper=FIXTURE.read_bytes().split(b"@main\n@MainActor\nprivate enum OriginalOwnerSQLiteAcceptance",1)[0]
    assert len(helper)==6694 and digest(helper)=="e70be884090dd1f52bdc63a7ffe0a3b527d059e67cb1b960671114687c3a30ff"
    fragment=FRAGMENT.read_bytes()
    observation=bounded(fragment,b"@MainActor\nprivate final class ExclusiveReadObservation",b"@MainActor\nprivate extension OriginalOwnerExclusiveSQLiteAcceptance")
    positive=bounded(fragment,b"    static func explicitReadScopeCommit(",b"    static func defaultMutationIsRefused(")
    negative=bounded(fragment,b"    static func defaultMutationIsRefused(",b"    static func exclusiveReopen(")
    combined=helper+observation+ENTRY.read_bytes()+b"\n@MainActor\nprivate extension OriginalOwnerExclusiveSQLiteAcceptance {\n"+positive+b"}\n"
    assert b"static func defaultMutationIsRefused("not in combined and b"static func currentOwner("not in combined
    derivation={"helper_prefix_bytes":len(helper),"helper_prefix_sha256":digest(helper),"observation_bytes":len(observation),"observation_sha256":digest(observation),"unchanged_positive_function_bytes":len(positive),"unchanged_positive_function_sha256":digest(positive),"retained_negative_function_sha256":digest(negative),"entrypoint_sha256":sha(ENTRY),"combined_sha256":digest(combined),"negative_assertion_compiled":False,"prior_six_assertions_compiled":False}
    prior=json.loads((PRIOR/"RESULT.json").read_bytes())
    prior_sources=json.loads((PRIOR/"SOURCE_MANIFEST.json").read_bytes())
    assert prior_sources["head"]=="f81213dc5bba73272c9d0aa9873a7ef1e05e1528"
    assert prior["status"]=="FAILED" and prior["sources_unchanged"]and prior["compiled_copies_unchanged"]
    assert prior["cases"][0]["name"]==POSITIVE and prior["cases"][0]["status"]=="FAIL" and prior["cases"][0]["events"]==[]
    retained=prior["cases"][1]
    assert retained["name"]==NEGATIVE and retained["status"]=="PASS"and retained["durableRows"]==0
    for rel,value in prior_sources["inputs"].items():assert sha(ROOT/rel)==value
    negative_db=PRIOR/"fixtures"/(NEGATIVE+".sqlite")
    observation_file=INITIAL/"evidence/FAILED_PATH_OBSERVATION.json"
    path_proof=json.loads(observation_file.read_bytes())
    old_negative=next(r for r in path_proof["paths"]if r["name"]==NEGATIVE)
    assert sha(negative_db)==old_negative["sha256"]and negative_db.stat().st_size==old_negative["bytes"]
    inputs=dependencies+[MANIFEST,FIXTURE,FRAGMENT,INITIAL/"run-exclusive-owner-sqlite-controls.py",ENTRY,Path(__file__).resolve()]
    historical=[PRIOR/"RESULT.json",PRIOR/"SOURCE_MANIFEST.json",PRIOR/"fixtures/CASES.json",PRIOR/"fixtures/WRITER.json",observation_file]
    assert len(inputs)==15 and len(historical)==5
    before={p.relative_to(ROOT).as_posix():sha(p)for p in inputs+historical}
    head=git("rev-parse","HEAD").decode().strip()
    for p in inputs+historical:assert p.read_bytes()==git("show",head+":"+p.relative_to(ROOT).as_posix())
    for p in dependencies:shutil.copyfile(p,copies/p.name)
    control=copies/"PositiveOnly.swift";control.write_bytes(combined)
    compiled={p.name:sha(copies/p.name)for p in dependencies};compiled[control.name]=sha(control)
    sdkroot=Path(os.environ.get("ProgramFiles(x86)",r"C:\Program Files (x86)"))/"Windows Kits/10"
    sdk=next(p for p in sorted((sdkroot/"Include").glob("*"),reverse=True)if (p/"um/winsqlite/winsqlite3.h").is_file())
    header=sdk/"um/winsqlite/winsqlite3.h";library=sdkroot/"Lib"/sdk.name/"um/x64/winsqlite3.lib"
    module=build/"SQLite3";module.mkdir()
    modulemap=module/"module.modulemap"
    modulemap.write_text('module SQLite3 [system] { header '+json.dumps(header.as_posix())+' link "winsqlite3" export * }\n',encoding="utf-8",newline="\n")
    env=os.environ.copy();runtime=Path(r"C:\Users\DAVID\AppData\Local\Programs\Swift\Runtimes\6.3.3\usr\bin")
    assert runtime.is_dir();env["PATH"]=str(runtime)+os.pathsep+env["PATH"]
    compiler=shutil.which("swiftc");assert compiler
    exe=build/"PositiveOnly.exe"
    report={"status":"FAILED","platform":platform.platform(),"source_head":head,"original_owner_source":manifest["original_owner_source"],"application_source":manifest["application_source"],"commands":[],"selected_new_controls":1,"reused_negative_control":retained,"negative_control_reexecuted":False,"old_six_controls_reexecuted":False,"derivation":derivation,"positive_sqlite_filename":str(positive_db),"positive_filename_characters":len(str(positive_db)),"positive_journal_filename_characters":len(str(positive_db)+"-journal"),"retained_negative_db":{"path":str(negative_db),"sha256":sha(negative_db),"bytes":negative_db.stat().st_size},"interop":{"platform":"original Windows SDK winsqlite3","header":str(header),"header_sha256":sha(header),"import_library":str(library),"import_library_sha256":sha(library),"modulemap_sha256":sha(modulemap)},"native_rpc":0,"native_receipt":0,"production_identity_write":0,"ack":0}
    write(out/"SOURCE_MANIFEST.json",{"head":head,"source_inputs":{p.relative_to(ROOT).as_posix():sha(p)for p in inputs},"historical_evidence_inputs":{p.relative_to(ROOT).as_posix():sha(p)for p in historical},"compiled_copies":compiled,"derivation":derivation,"negative_database":report["retained_negative_db"]})
    def run(label,command,timeout):
        started=time.monotonic()
        with (out/(label+".stdout.log")).open("wb")as stdout,(out/(label+".stderr.log")).open("wb")as stderr:
            process=subprocess.run(command,cwd=ROOT,env=env,stdout=stdout,stderr=stderr,timeout=timeout)
        report["commands"].append({"label":label,"command":command,"exit":process.returncode,"seconds":time.monotonic()-started})
        assert process.returncode==0,label+" failed"
    try:
        report["swift"]=subprocess.check_output([compiler,"--version"],env=env,text=True,encoding="utf-8").strip()
        command=[compiler,"-swift-version","5","-strict-concurrency=complete","-parse-as-library","-j","1","-whole-module-optimization","-Onone","-I",str(module),"-L",str(library.parent)]+[str(copies/p.name)for p in dependencies]+[str(control),"-o",str(exe)]
        run("compile",command,480);report["executable_sha256"]=sha(exe)
        run("positive",[str(exe),"positive",str(fixture)],120)
        cases=json.loads((fixture/"CASES.json").read_bytes());report["cases"]=cases
        assert len(cases)==1 and cases[0]["name"]==POSITIVE and cases[0]["status"]=="PASS"and cases[0].get("error")is None and cases[0]["durableRows"]==1
        run("reopen-positive",[str(exe),"reopen-positive",str(fixture)],60)
        run("reopen-retained-negative",[str(exe),"reopen-retained-negative",str(PRIOR/"fixtures"),str(out)],60)
        writer=json.loads((fixture/"WRITER.json").read_bytes());positive_reopen=json.loads((fixture/"REOPEN.json").read_bytes())
        negative_reopen=json.loads((out/"RETAINED_NEGATIVE_REOPEN.json").read_bytes())
        old_writer=json.loads((PRIOR/"fixtures/WRITER.json").read_bytes())
        assert len({writer["pid"],positive_reopen["pid"],negative_reopen["pid"],old_writer["pid"]})==4
        assert positive_reopen["writerPID"]==writer["pid"]and negative_reopen["writerPID"]==old_writer["pid"]
        assert positive_reopen["status"]=="PASS"and negative_reopen["status"]=="PASS_REOPEN_OF_RETAINED_NEGATIVE"
        assert negative_reopen["originalNegativeControlReexecuted"]=="false"
        assert len({x["sqlite"]for x in [writer,positive_reopen,negative_reopen,old_writer]})==1
        assert all(x[k]=="0"for x in [writer,positive_reopen,negative_reopen,old_writer]for k in ["nativeRPC","productionIdentityWrites","nativeReceipts","ACK"])
        report.update(writer=writer,positive_reopen=positive_reopen,negative_reopen=negative_reopen,prior_writer=old_writer,status="PASS_POSITIVE_AND_REUSED_NEGATIVE_WITH_DISTINCT_PROCESS_READBACKS")
    except Exception as error:
        report["error"]=repr(error);(out/"failure.log").write_text(traceback.format_exc(),encoding="utf-8",newline="\n")
    finally:
        report["sources_and_historical_evidence_unchanged"]=before=={p.relative_to(ROOT).as_posix():sha(p)for p in inputs+historical}
        report["compiled_copies_unchanged"]=compiled=={p.name:sha(copies/p.name)for p in dependencies+[control]}
        report["retained_negative_db_unchanged"]=sha(negative_db)==report["retained_negative_db"]["sha256"]
        if not all(report[x]for x in ["sources_and_historical_evidence_unchanged","compiled_copies_unchanged","retained_negative_db_unchanged"]):report["status"]="FAILED"
        write(out/"RESULT.json",report);print(json.dumps({k:v for k,v in report.items()if k not in ["cases","reused_negative_control"]},indent=2),flush=True)
    return 0 if report["status"]=="PASS_POSITIVE_AND_REUSED_NEGATIVE_WITH_DISTINCT_PROCESS_READBACKS"else 1
if __name__=="__main__":sys.exit(main())
