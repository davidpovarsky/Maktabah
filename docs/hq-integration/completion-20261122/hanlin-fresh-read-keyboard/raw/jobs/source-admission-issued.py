import pathlib,subprocess,sys,json,hashlib,os,datetime,time,shutil,traceback
root=pathlib.Path(r"C:\Users\DAVID\Code\Maktabah-hanlin-fresh-read-keyboard-20261122")
base=pathlib.Path(r"C:\Users\DAVID\AppData\Local\Temp\otzaria-hanlin-fresh-read-keyboard-20261122")
out=base/"admission"
out.mkdir(exist_ok=False)
shutil.copyfile(__file__,out/"actual-admission.py")
head="aec8162c34598c859c9dc61b6e8b298b5d5d36e6"
source="d49cedb3d5c163b7a008248d94b80a2eda28e3ce"
def sha(b): return hashlib.sha256(b).hexdigest()
def git(*args): return subprocess.check_output(["git","-c","core.autocrlf=false",*args],cwd=root,timeout=90).decode("utf-8").strip()
def utc(): return datetime.datetime.now(datetime.timezone.utc).isoformat()
def write(p,v): p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+"\n",encoding="utf-8",newline="\n")
env=os.environ.copy();env.update(PYTHONUTF8="1",EXPECTED_CHECKOUT_SHA=head)
report={"schema":"otzaria.fresh-read-keyboard-source-admission/1","status":"RUNNING","started":utc(),"checkout":head,"applicationSource":source,"newTestsExecuted":0,"nativeExecuted":False,"providerRequests":False,"commands":[],"inputs":{}}
for name in ["Scripts/CI/completion-focused-native.py",".github/workflows/otzaria-completion-focused-native.yml","Scripts/CI/hq-stage2-focused-apple.py","Scripts/CI/hq-stage2-focused-apple.inputs.json","Scripts/CI/reuse-host48.py","Maktabah-iOSUITests/HanlinConsumerAcceptanceTests.swift"]:
 raw=(root/name).read_bytes();report["inputs"][name]={"bytes":len(raw),"sha256":sha(raw)}
report["python"]={"path":sys.executable,"sha256":sha(pathlib.Path(sys.executable).read_bytes()),"version":sys.version}
write(out/"INPUTS.json",report)
try:
 assert git("rev-parse","HEAD")==head
 assert git("status","--porcelain")==""
 commands=[("focused-prepare",[sys.executable,"Scripts/CI/completion-focused-native.py","prepare"],180),("hq-preflight",[sys.executable,"Scripts/CI/hq-stage2-focused-apple.py","--preflight-only"],180),("host48-reuse",[sys.executable,"Scripts/CI/reuse-host48.py"],180)]
 for label,command,budget in commands:
  record={"label":label,"command":command,"timeoutSeconds":budget,"started":utc(),"environmentOverrides":{"PYTHONUTF8":"1","EXPECTED_CHECKOUT_SHA":head}}
  t=time.monotonic()
  with (out/(label+".stdout")).open("wb") as so,(out/(label+".stderr")).open("wb") as se:
   try:
    result=subprocess.run(command,cwd=root,env=env,stdout=so,stderr=se,timeout=budget)
    record["returncode"]=result.returncode
   except subprocess.TimeoutExpired:
    record.update(returncode=None,timedOut=True);raise
   finally:
    record.update(finished=utc(),durationSeconds=round(time.monotonic()-t,6))
    for suffix in ("stdout","stderr"):
     b=(out/(label+"."+suffix)).read_bytes();record[suffix]={"path":label+"."+suffix,"bytes":len(b),"sha256":sha(b)}
    report["commands"].append(record);write(out/"EXECUTION.json",report)
  if result.returncode!=0: raise RuntimeError(label+" returned "+str(result.returncode))
 for rel in ["build/artifacts/continuation-focused/declarations.json","build/artifacts/continuation-focused/selection.json","build/artifacts/continuation-focused/source-before.json","build/artifacts/continuation-host48-reuse/result.json"]:
  src=root/rel;dst=out/"outputs"/rel;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)
 ctx=json.loads((root/"build/artifacts/continuation-focused/source-before.json").read_text(encoding="utf-8"))
 selection=json.loads((root/"build/artifacts/continuation-focused/selection.json").read_text(encoding="utf-8"))
 decl=json.loads((root/"build/artifacts/continuation-focused/declarations.json").read_text(encoding="utf-8"))
 reuse=json.loads((root/"build/artifacts/continuation-host48-reuse/result.json").read_text(encoding="utf-8"))
 selected=["HanlinReaderConsumerAcceptanceTests/testOriginalIPadFreshCurrentWorkReadConnectionWithoutSending"]
 assert selection["execution_case_ids"]==selected and selection["required_nonzero_cases"]==1 and selection["native_cases_executed"]==0
 assert ctx["checkout_sha"]==head and ctx["application_source_sha"]==source
 assert decl["status"]=="DECLARATIONS_MATCH"
 assert reuse["status"]=="VERIFIED_REUSE_OF_PRIOR_HOST48_PASS" and reuse["new_tests_executed"]==0
 assert git("rev-parse","HEAD")==head and git("status","--porcelain")==""
 report.update(status="PASS_SOURCE_ADMISSION_ONLY",selectedCases=selected,executionInputCount=len(ctx["execution_inputs"]),trees=ctx["application_trees"],hostReuse={"originalRun":reuse["prior_run_url"],"originalTestsPassed":reuse["original_tests_passed"],"newTestsExecuted":0})
except Exception as e:
 report.update(status="FAIL_SOURCE_ADMISSION",error=type(e).__name__+": "+str(e),traceback=traceback.format_exc())
finally:
 report["finished"]=utc()
 report["retainedOutputs"]=[{"path":p.relative_to(out).as_posix(),"bytes":p.stat().st_size,"sha256":sha(p.read_bytes())} for p in sorted((out/"outputs").rglob("*")) if p.is_file()] if (out/"outputs").exists() else []
 write(out/"RESULT.json",report)
 print(json.dumps({"status":report["status"],"resultPath":str(out/"RESULT.json"),"resultSHA256":sha((out/"RESULT.json").read_bytes()),"commands":report["commands"],"executionInputCount":report.get("executionInputCount"),"error":report.get("error")},ensure_ascii=False))
sys.exit(0 if report["status"]=="PASS_SOURCE_ADMISSION_ONLY" else 1)
