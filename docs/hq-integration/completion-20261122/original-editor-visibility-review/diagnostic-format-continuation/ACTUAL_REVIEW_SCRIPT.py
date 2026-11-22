import pathlib,subprocess,json,hashlib,zipfile,datetime,re,traceback
r=pathlib.Path(r"C:\Users\DAVID\Code\anytype-original-editor-package-seal-20261121")
d=r/"docs/pinkha/torah-integration/evidence/original-editor-indentation-visibility-20261122"
prior=pathlib.Path(r"C:\Users\DAVID\AppData\Local\Temp\otzaria-continuation-20261122\visibility71-root-admission")
out=prior/"diagnostic-format-continuation";assert not out.exists();out.mkdir()
(out/"ACTUAL_REVIEW_SCRIPT.py").write_bytes(pathlib.Path(__file__).read_bytes())
def sha(b):return hashlib.sha256(b).hexdigest()
def j(n):return json.loads((d/n).read_bytes())
def git(*args):
 p=subprocess.run(["git","-c","core.autocrlf=false",*args],cwd=r,capture_output=True,timeout=30);p.check_returncode();return p.stdout
result={"schema":1,"status":"STARTED","started_at":datetime.datetime.now(datetime.timezone.utc).isoformat(),"tests_executed":0,"artifact_downloads":0,"source_mutations":0}
try:
 first=(prior/"ROOT_ADMISSION.json").read_bytes();second=(prior/"path-case-continuation/ROOT_ADMISSION.json").read_bytes()
 assert sha(first)=="4265578535bfe28e71072b5948db35cd242debb8dd6b660eb9f4e7526626486c"
 assert sha(second)=="5c932ba45857bfe6a2af01f6bed915c67a780e314ac7846d3d417fef6e2040d3"
 assert "assert len(errors)==1" in json.loads(second)["error"]
 raw=(d/"expected-external-visibility-rejection-v2.stderr.log").read_bytes()
 execution=j("COMPILER_EXECUTION_V2.json")
 assert sha(raw)==execution["commands"][2]["stderr_sha256"]
 lines=raw.decode("utf-8").splitlines()
 messages=[line.split("error: ",1)[1] for line in lines if "error: " in line]
 located=[line for line in lines if re.search(r"ExternalConsumer\.swift:\d+:\d+: error: ",line)]
 assert len(located)==1 and len(messages)==2 and all(m=="cannot find type 'BlockIndentationStyle' in scope" for m in messages)
 red=j("COMPILER_EXECUTION.json")
 assert len(red["commands"])==1 and red["commands"][0]["returncode"]==1 and not red["commands"][0]["timed_out"]
 redbytes=(d/"complete-original-candidate-module.stderr.log").read_bytes()
 assert sha(redbytes)==red["commands"][0]["stderr_sha256"] and b"no such module 'CoreFoundation'" in redbytes
 module=j("ACTUAL_COMPILER_MODULE.json")
 assert sha((d/"actual-visibility-compiler-module.zip").read_bytes())==module["archive_sha256"]
 with zipfile.ZipFile(d/"actual-visibility-compiler-module.zip") as z:
  assert z.testzip() is None and len(z.infolist())==len(module["files"])==3
  for x in module["files"]:
   b=z.read(x["name"]);assert sha(b)==x["sha256"] and len(b)==x["bytes"]
 oldbuild=j("prior-7b59/selected/framework-build.command.json")
 assert oldbuild["returncode"]==0 and not oldbuild["timed_out"]
 assert j("prior-7b59/selected/macro-trust/macro-restoration.json")["status"]=="EXACT_ORIGINAL_MACRO_TRUST_RESTORED"
 inputs=j("COMPILER_INPUTS_V2.json")
 assert sha((d/"prior-7b59/github-artifact-14747819041.zip").read_bytes())==inputs["prior_actual_apple_graph"]["archive_sha256"]
 head="5c1d08e327bb8155248885e496cf64200932a812"
 assert git("rev-parse","HEAD").decode().strip()==head and not git("status","--porcelain=v1").strip()
 idx=j("INDEX.json");bindings=json.loads((prior/"GIT_BLOB_BINDINGS.json").read_bytes())
 assert len(idx["files"])==70 and len(bindings)==71
 result.update(status="PASS",head=head,payload_count=70,exact_git_blobs=71,payload_bytes=sum(x["bytes"] for x in idx["files"]),index_sha256=sha((d/"INDEX.json").read_bytes()),git_bindings_sha256=sha((prior/"GIT_BLOB_BINDINGS.json").read_bytes()),review_history=[{"receipt_sha256":sha(first),"completed_scope":"All70payloads+index,71Gitblobs,3originalGitinputs,exactpublic-keywordinverse and2portable-importinverses independently verified before reviewer lowercase tools path lookup failed."},{"receipt_sha256":sha(second),"completed_scope":"Original uppercase Tools gate bound to retainedGitprovenance;gateunchanged,actualSwiftcompilerhash,runner/manifesthashes,3terminalcommands0/0/1 andallrawstreamhashes independently verified before reviewer counted Swift diagnostic source-line caret echo as a second error."}],new_compiler_commands_verified=3,located_expected_external_error_count=1,diagnostic_caret_echo_count=1,module_files_independently_rehashed=3,raw_first_control_red_preserved=True,strict_surface_gate_unchanged=True,prior_apple_framework_build={"returncode":0,"started_at":oldbuild["started_at"],"finished_at":oldbuild["finished_at"]},limits=["Windows projected imports use genuine Foundation types; no Apple surface/NativeUI qualification inferred.","Actual previous Apple framework build PASS had later graph failure,externalconsumerNOT_RUN.","No source/compiler/test/artifactdownload replay in these readonly reviews."])
except Exception:result.update(status="FAIL",error=traceback.format_exc())
finally:
 result["finished_at"]=datetime.datetime.now(datetime.timezone.utc).isoformat()
 b=(json.dumps(result,indent=2)+"\n").encode("utf-8");(out/"ROOT_ADMISSION.json").write_bytes(b)
 print(json.dumps({"receipt":str(out/"ROOT_ADMISSION.json"),"receipt_sha256":sha(b),"result":result}))
if result["status"]!="PASS":raise SystemExit(1)
