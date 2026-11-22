import json,hashlib,subprocess,datetime
from pathlib import Path
root=Path(r"C:\Users\DAVID\AppData\Local\Temp\fr450063");e=root/"evidence"
repo=Path(r"C:\Users\DAVID\Code\Maktabah-hanlin-fresh-read-diagnostic-20261122")
head="997bc6872fed666daef8f720ddd1f847647be80c";source="7eb9d2a5c8ac7ccb184e3cc50fb36b6272475ff1"
selector="HanlinReaderConsumerAcceptanceTests/testOriginalIPadFreshCurrentWorkReadConnectionWithoutSending"
outdir=root/"independent";outdir.mkdir(exist_ok=False)
def read(p):return json.loads((e/p).read_text(encoding="utf-8"))
def sha(b):return hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(["git",*a],cwd=repo)
before=read("artifacts/continuation-focused/source-before.json");after=read("artifacts/continuation-focused/result.json")
assert before["checkout_sha"]==after["checkout_sha"]==head
assert before["application_source_sha"]==after["application_source_sha"]==source
assert before["execution_inputs"]==after["execution_inputs"] and len(before["execution_inputs"])==279
trees={}
for p,h in before["application_trees"].items():
 assert h==after["application_trees"][p]
 assert git("rev-parse",head+":"+p).decode().strip()==git("rev-parse",source+":"+p).decode().strip()==h
 trees[p]=h
tree={}
for line in git("ls-tree","-rz",head).split(b"\0"):
 if not line:continue
 meta,p=line.split(b"\t",1);mode,kind,blob=meta.split();tree[p.decode()]=blob.decode()
inputs=before["execution_inputs"]
for p,row in inputs.items():assert tree.get(p)==row["blob"],p
unique=list(dict.fromkeys(row["blob"] for row in inputs.values()))
payload=git("cat-file","--batch") if False else subprocess.run(["git","cat-file","--batch"],cwd=repo,input=("\n".join(unique)+"\n").encode(),stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=True).stdout
pos=0;blobs={}
for want in unique:
 end=payload.index(b"\n",pos);oid,kind,n=payload[pos:end].split();assert oid.decode()==want and kind==b"blob"
 n=int(n);b=payload[end+1:end+1+n];assert payload[end+1+n:end+2+n]==b"\n";pos=end+2+n;blobs[want]=b
assert pos==len(payload)
for p,row in inputs.items():
 b=blobs[row["blob"]];assert len(b)==row["bytes"] and sha(b)==row["sha256"],p
actual=read("hq-stage2/actual-source-inputs.json");assert len(actual)==1012
for p,blob in actual.items():assert tree.get(p)==blob,p
summary=read("artifacts/runtime27/verified-11-reader.summary.json");tests=read("artifacts/runtime27/verified-11-reader.tests.json");verified=read("artifacts/runtime27/verified-11-reader.json")
assert sha(json.dumps(summary,sort_keys=True).encode())==verified["summary_sha256"]
assert sha(json.dumps(tests,sort_keys=True).encode())==verified["tests_sha256"]
cases=[]
def walk(x):
 if isinstance(x,dict):
  if x.get("nodeType")=="Test Case":cases.append(x)
  for v in x.values():walk(v)
 elif isinstance(x,list):
  for v in x:walk(v)
walk(tests)
assert len(cases)==1 and cases[0]["nodeIdentifier"]==selector+"()" and cases[0]["result"]=="Failed"
assert summary["totalTestCount"]==1 and summary["failedTests"]==1 and summary["passedTests"]==summary["skippedTests"]==0
assert verified["status"]=="FAIL" and after["executed_ui_fail"]==1 and after["executed_ui_pass"]==after["ui_not_run"]==0
assert after["required_case_ids"]==[selector] and not after["full_native116_acceptance"] and not after["full_release114_acceptance"]
matrix=read("artifacts/faithful-ipad-matrix.json");assert len(matrix["devices"])==1
d=matrix["devices"][0];assert d["requiredSuites"]==[selector] and d["ownedSimulatorCleanup"]=="PASS" and d["xcodebuildExitCode"]==65
assert d["failedPhase"]=="RUNNING_NATIVE_XCTEST"
binary=read("artifacts/continuation-focused/built-binaries.json")
assert binary==after["built_binary_sha256"] and after["compiled_image_bytes_unchanged"] is True
hq=read("hq-stage2/result.json");post=read("artifacts/continuation-focused/original-post-ui-input-audit.json")
assert hq["status"]==post["status"]=="SIMULATOR_BUILD_FOR_REAL_UI_PASS"
diff={k:{"before":hq.get(k),"after":post.get(k)} for k in hq.keys()|post.keys() if hq.get(k)!=post.get(k)}
assert set(diff)<= {"commands","generated_configuration"}
assert post["commands"][:len(hq["commands"])]==hq["commands"]
assert post["generated_configuration"]==hq["generated_configuration"]+hq["generated_configuration"]
host=read("artifacts/continuation-host48-reuse/result.json")
assert host["status"]=="VERIFIED_REUSE_OF_PRIOR_HOST48_PASS" and host["new_tests_executed"]==0
eidx=json.loads((root/"evidence.FILES.json").read_text())
for r in eidx["files"]:
 b=(e/r["path"]).read_bytes();assert len(b)==r["bytes"] and sha(b)==r["sha256"]
result={"schema":"otzaria.native-fresh-read-independent-verification/1","status":"VERIFIED_ACTUAL_FAILURE","created":datetime.datetime.now(datetime.timezone.utc).isoformat(),"runID":45006363282,"checkout":head,"applicationSource":source,"applicationTrees":trees,"primaryPayloadFilesVerified":len(eidx["files"]),"executionInputsGitBytesVerified":len(inputs),"buildSourceGitBindingsVerified":len(actual),"uniqueExecutedCases":1,"nativePassed":0,"nativeFailed":1,"nativeSkipped":0,"case":cases[0],"strictSummaryCanonicalHashVerified":True,"strictTestsCanonicalHashVerified":True,"binaryEvidence":{"beforeAfterThreeExecutableDigestsRecorded":binary,"actualBinaryPayloadsRetained":False,"scope":"Original runner recorded matching before/after executable digests; no independent binary-byte claim."},"buildPostUIDifferences":{"keys":sorted(diff),"oneAdditionalOriginalAuditCommand":len(post["commands"])==len(hq["commands"])+1,"sameOriginalPrivacyAggregationRecordRepeated":True},"ownedSimulatorCleanup":d["ownedSimulatorCleanup"],"host48":{"newTests":0,"reusedExactOriginalInputs":True,"priorRun":44940208007},"failureStage":"Existing unique native consent child non-hittable after manual normal form entry and four swipeUp gestures; Connect/reopen/revoke not reached.","providerRequestOrCredentialClaim":"This is the reviewed no-key/no-send route. No provider acceptance or complete network instrumentation is inferred.","productChanges":0,"newTestsExecutedByAudit":0}
(outdir/"VERIFICATION.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8",newline="\n")
(outdir/"BUILD_POST_UI_DIFF.json").write_text(json.dumps(diff,ensure_ascii=False,indent=2)+"\n",encoding="utf-8",newline="\n")
print(json.dumps({"status":result["status"],"path":str(outdir/"VERIFICATION.json"),"sha256":sha((outdir/"VERIFICATION.json").read_bytes()),"verifiedExecutionInputs":len(inputs),"verifiedBuildInputBindings":len(actual),"primaryPayloads":len(eidx["files"]),"nativeCounts":[0,1,0],"cleanup":d["ownedSimulatorCleanup"],"diffKeys":sorted(diff)},ensure_ascii=False))