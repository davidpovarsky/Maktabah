import pathlib,subprocess,json,hashlib,zipfile,datetime,traceback
r=pathlib.Path(r"C:\Users\DAVID\Code\anytype-original-editor-package-seal-20261121")
d=r/"docs/pinkha/torah-integration/evidence/original-editor-indentation-visibility-20261122"
prior=pathlib.Path(r"C:\Users\DAVID\AppData\Local\Temp\otzaria-continuation-20261122\visibility71-root-admission")
out=prior/"path-case-continuation";assert not out.exists();out.mkdir()
(out/"ACTUAL_REVIEW_SCRIPT.py").write_bytes(pathlib.Path(__file__).read_bytes())
def sha(b):return hashlib.sha256(b).hexdigest()
def git(*args):
 p=subprocess.run(["git","-c","core.autocrlf=false",*args],cwd=r,capture_output=True,timeout=30);p.check_returncode();return p.stdout
def j(name):return json.loads((d/name).read_bytes())
result={"schema":1,"status":"STARTED","started_at":datetime.datetime.now(datetime.timezone.utc).isoformat(),"tests_executed":0,"artifact_downloads":0,"source_mutations":0}
try:
 assert sha((prior/"ROOT_ADMISSION.json").read_bytes())=="4265578535bfe28e71072b5948db35cd242debb8dd6b660eb9f4e7526626486c"
 first=json.loads((prior/"ROOT_ADMISSION.json").read_bytes())
 assert first["status"]=="FAIL" and 'assert len(matches)==1,matches' in first["error"] and "AssertionError: []" in first["error"]
 bindings=json.loads((prior/"GIT_BLOB_BINDINGS.json").read_bytes())
 assert len(bindings)==71 and len({x["path"] for x in bindings})==71
 idx=j("INDEX.json");assert idx["count"]==len(idx["files"])==70
 indexed={x["path"]:x for x in idx["files"]}
 for x in bindings:
  n=x["path"].split("/original-editor-indentation-visibility-20261122/",1)[1]
  if n=="INDEX.json":assert x["sha256"]==sha((d/"INDEX.json").read_bytes())
  else:assert x["sha256"]==indexed[n]["sha256"] and x["bytes"]==indexed[n]["bytes"]
 head="5c1d08e327bb8155248885e496cf64200932a812"
 assert git("rev-parse","HEAD").decode().strip()==head and not git("status","--porcelain=v1").strip()
 inputs=j("COMPILER_INPUTS_V2.json")
 gates=[x for x in j("DEPENDENCY_PROVENANCE.json")["sources"] if x["path"].endswith("/framework_products.py")]
 assert len(gates)==1
 gate=gates[0];b=git("show",head+":"+gate["path"])
 assert b==git("show",inputs["source_ref"]+":"+gate["path"])==(d/"dependency-3-framework_products.py").read_bytes()
 assert sha(b)==gate["sha256"]=="11ca6a3128fdc2c47cd9f63cd274e8896b5633af8753acfdb37fb02396fc0ebd"
 assert sha(pathlib.Path(inputs["compiler"]["path"]).read_bytes())==inputs["compiler"]["sha256"]
 ex=j("COMPILER_EXECUTION_V2.json")
 assert ex["runner_sha256"]==sha((d/"run_visibility_boundary_v2.py").read_bytes())==inputs["runner_sha256"]
 assert ex["inputs_sha256"]==sha((d/"COMPILER_INPUTS_V2.json").read_bytes())
 commands=ex["commands"]
 assert [x["label"] for x in commands]==["complete-original-candidate-syntax","portable-original-candidate-module","expected-external-visibility-rejection-v2"]
 assert [x["returncode"] for x in commands]==[0,0,1]
 for x in commands:
  assert x["phase"]=="TERMINAL" and not x["timed_out"] and x["all_inputs_unchanged"] and x["child_pid"]>0
  for stream in ["stdout","stderr"]:
   assert sha((d/(x["label"]+"."+stream+".log")).read_bytes())==x[stream+"_sha256"]
 errors=[s for s in (d/"expected-external-visibility-rejection-v2.stderr.log").read_text(encoding="utf-8").splitlines() if " error: " in s]
 assert len(errors)==1 and "cannot find type 'BlockIndentationStyle' in scope" in errors[0],errors
 red=j("COMPILER_EXECUTION.json");assert len(red["commands"])==1 and red["commands"][0]["returncode"]==1 and not red["commands"][0]["timed_out"]
 assert sha((d/"complete-original-candidate-module.stderr.log").read_bytes())==red["commands"][0]["stderr_sha256"]
 assert b"no such module 'CoreFoundation'" in (d/"complete-original-candidate-module.stderr.log").read_bytes()
 module=j("ACTUAL_COMPILER_MODULE.json")
 assert sha((d/"actual-visibility-compiler-module.zip").read_bytes())==module["archive_sha256"]
 with zipfile.ZipFile(d/"actual-visibility-compiler-module.zip") as z:
  assert z.testzip() is None and len(z.infolist())==len(module["files"])==3
  for x in module["files"]:
   b=z.read(x["name"]);assert sha(b)==x["sha256"] and len(b)==x["bytes"]
 oldbuild=j("prior-7b59/selected/framework-build.command.json")
 assert oldbuild["returncode"]==0 and not oldbuild["timed_out"]
 assert j("prior-7b59/selected/macro-trust/macro-restoration.json")["status"]=="EXACT_ORIGINAL_MACRO_TRUST_RESTORED"
 assert sha((d/"prior-7b59/github-artifact-14747819041.zip").read_bytes())==inputs["prior_actual_apple_graph"]["archive_sha256"]
 assert git("rev-parse","HEAD").decode().strip()==head and not git("status","--porcelain=v1").strip()
 result.update(status="PASS",head=head,payload_count=70,exact_git_blobs=71,payload_bytes=sum(x["bytes"] for x in indexed.values()),index_sha256=sha((d/"INDEX.json").read_bytes()),first_completed_scope="Initial script independently rehashed all70payloads+index,matched71actualGitblobs,3originalGitinputs,productkeywordinverse and2portableimportinverses before the reviewer-only lowercase tools path lookup failed. Its exact script/error/Git bindings are preserved.",first_failure_sha256=sha((prior/"ROOT_ADMISSION.json").read_bytes()),git_bindings_sha256=sha((prior/"GIT_BLOB_BINDINGS.json").read_bytes()),new_compiler_commands_verified=3,module_files_independently_rehashed=3,raw_first_control_red_preserved=True,strict_surface_gate_unchanged=True,strict_surface_gate_path=gate["path"],prior_apple_framework_build={"returncode":0,"started_at":oldbuild["started_at"],"finished_at":oldbuild["finished_at"]},limits=["Windows projected imports compile genuine Foundation types; no Apple graph/Native UI pass is inferred.","Actual prior Apple framework build PASS has separate public-graph failure and external consumer NOT_RUN.","No native/Swift/compiler test was replayed; this is byte/receipt verification only."])
except Exception:result.update(status="FAIL",error=traceback.format_exc())
finally:
 result["finished_at"]=datetime.datetime.now(datetime.timezone.utc).isoformat()
 b=(json.dumps(result,indent=2)+"\n").encode("utf-8");(out/"ROOT_ADMISSION.json").write_bytes(b)
 print(json.dumps({"receipt":str(out/"ROOT_ADMISSION.json"),"receipt_sha256":sha(b),"result":result}))
if result["status"]!="PASS":raise SystemExit(1)
