import json,hashlib,subprocess,datetime,plistlib
from pathlib import Path
root=Path(r"C:\Users\DAVID\AppData\Local\Temp\fr450063");e=root/"evidence"
repo=Path(r"C:\Users\DAVID\Code\Maktabah-hanlin-fresh-read-diagnostic-20261122")
head="997bc6872fed666daef8f720ddd1f847647be80c";source="7eb9d2a5c8ac7ccb184e3cc50fb36b6272475ff1"
selector="HanlinReaderConsumerAcceptanceTests/testOriginalIPadFreshCurrentWorkReadConnectionWithoutSending"
outdir=root/"independent"/"generated-privacy-continuation";outdir.mkdir(exist_ok=False)
def read(p):return json.loads((e/p).read_text(encoding="utf-8"))
def sha(b):return hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(["git",*a],cwd=repo)
first=json.loads((root/"independent/first-verification-failure/actual-terminal.json").read_text())
assert first["job"]["status"]=="failed"
first_output=first["job"]["output"]
assert "AssertionError: Source/PrivacyInfo.xcprivacy" in first_output
before=read("artifacts/continuation-focused/source-before.json");after=read("artifacts/continuation-focused/result.json")
assert before["checkout_sha"]==after["checkout_sha"]==head
assert before["application_source_sha"]==after["application_source_sha"]==source
assert before["execution_inputs"]==after["execution_inputs"] and len(before["execution_inputs"])==279
tree={}
for line in git("ls-tree","-rz",head).split(b"\0"):
 if not line:continue
 meta,p=line.split(b"\t",1);mode,kind,blob=meta.split();tree[p.decode()]=blob.decode()
actual=read("hq-stage2/actual-source-inputs.json");assert len(actual)==1012
mismatches={p:{"source":tree.get(p),"compiled":blob} for p,blob in actual.items() if tree.get(p)!=blob}
assert mismatches=={"Source/PrivacyInfo.xcprivacy":{"source":"c86c62cc12e3ceadea279ff9948a8891a0860577","compiled":"af80d26d37547b62412f5922bfd9cc601a7e9344"}},mismatches
hq=read("hq-stage2/result.json");assert len(hq["generated_configuration"])==1
g=hq["generated_configuration"][0];assert g["path"]=="Source/PrivacyInfo.xcprivacy"
original=(e/"hq-stage2/privacy-original.xcprivacy").read_bytes();compiled=(e/"hq-stage2/privacy-generated.xcprivacy").read_bytes()
assert git("cat-file","blob",g["original_git_blob"])==original
assert sha(original)==g["original_sha256"] and sha(compiled)==g["compiled_sha256"]
assert hashlib.sha1(b"blob "+str(len(compiled)).encode()+b"\0"+compiled).hexdigest()==actual[g["path"]]
o=plistlib.loads(original);c=plistlib.loads(compiled)
key="NSPrivacyAccessedAPITypes"
assert {k:v for k,v in o.items() if k!=key}=={k:v for k,v in c.items() if k!=key}
def reasons(v):
 out=set()
 for row in v.get(key,[]):
  assert set(row)=={"NSPrivacyAccessedAPIType","NSPrivacyAccessedAPITypeReasons"}
  assert len(row["NSPrivacyAccessedAPITypeReasons"])==len(set(row["NSPrivacyAccessedAPITypeReasons"]))
  for reason in row["NSPrivacyAccessedAPITypeReasons"]:out.add((row["NSPrivacyAccessedAPIType"],reason))
 return out
oreasons=reasons(o);creasons=reasons(c);assert oreasons<=creasons
added={(v["category"],v["reason"]) for v in g["added_reasons"]};assert creasons-oreasons==added and len(added)==6
dependencies={}
for row in g["added_reasons"]:
 assert row["dependency_inputs"]
 for d in row["dependency_inputs"]:
  b=(e/"hq-stage2"/d["artifact_path"]).read_bytes();assert sha(b)==d["sha256"]
  assert (row["category"],row["reason"]) in reasons(plistlib.loads(b))
  dependencies[d["sha256"]]={"path":d["artifact_path"],"bytes":len(b),"originalPath":d["path"]}
assert len(dependencies)==5
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

result={"schema":"otzaria.native-fresh-read-independent-verification/1","status":"VERIFIED_ACTUAL_FAILURE","created":datetime.datetime.now(datetime.timezone.utc).isoformat(),"runID":45006363282,"checkout":head,"applicationSource":source,"applicationTrees":before["application_trees"],"primaryPayloadFilesVerified":len(eidx["files"]),"executionInputsGitBytesVerified":279,"executionInputVerificationEvidence":"First issued verifier completed all 279 Git blob, length and SHA checks before its retained later assertion rejected the known CocoaPods generated privacy file. This continuation does not replay those byte checks.","firstVerifierFailureRetained":True,"buildSourceBindings":{"total":len(actual),"unchangedGitBlobs":1011,"generatedPrivacyBlobAndBytesVerified":True,"allNonReasonDeclarationsUnchanged":True,"allOriginalReasonsRetained":True,"addedDependencyReasons":sorted([list(v) for v in added]),"dependencyInputs":dependencies},"uniqueExecutedCases":1,"nativePassed":0,"nativeFailed":1,"nativeSkipped":0,"case":cases[0],"strictSummaryCanonicalHashVerified":True,"strictTestsCanonicalHashVerified":True,"binaryEvidence":{"beforeAfterThreeExecutableDigestsRecorded":binary,"actualBinaryPayloadsRetained":False,"scope":"Original runner recorded matching before/after executable digests. The separate compiled-image record reports three images (five unique paths across both records); no independent binary-byte verification is claimed."},"buildPostUIDifferences":{"keys":sorted(diff),"oneAdditionalOriginalAuditCommand":len(post["commands"])==len(hq["commands"])+1,"sameOriginalPrivacyAggregationRecordRepeated":True},"ownedSimulatorCleanup":d["ownedSimulatorCleanup"],"host48":{"newTests":0,"reusedExactOriginalInputs":True,"priorRun":44940208007},"failureStage":"Existing unique native consent child non-hittable after manual normal form entry and four swipeUp gestures; consent tap, Connect, reopen and revoke assertion not reached.","axEvidence":{"path":"captures/visual-11-reader/D6DD0481-8830-4F76-AD60-F2BF50762000.txt","sha256":"3c1acd6364e664eeb40f9a8cd9e757f21b09927e909c0438c46305ae04fa0406","focusedSecureField":True,"keyboardFrame":[0,461,1210,370],"nativeSwitchFrame":[798,528.5,63,28],"realHideKeyboardButton":True,"screenshotLimitation":"The teardown screenshot taken 0.410 seconds after the AX attachment does not visibly display the keyboard. No screenshot-based keyboard or exact injected-tap-coordinate claim is made."},"providerRequestOrCredentialClaim":"Reviewed no-key/no-send diagnostic. No provider acceptance or complete network instrumentation is inferred.","productChangesByAudit":0,"newTestsExecutedByAudit":0}
(outdir/"VERIFICATION.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8",newline="\n")
(outdir/"BUILD_POST_UI_DIFF.json").write_text(json.dumps(diff,ensure_ascii=False,indent=2)+"\n",encoding="utf-8",newline="\n")
print(json.dumps({"status":result["status"],"path":str(outdir/"VERIFICATION.json"),"sha256":sha((outdir/"VERIFICATION.json").read_bytes()),"verifiedExecutionInputsFromPreservedFirstPrefix":279,"verifiedBuildInputBindings":len(actual),"primaryPayloads":len(eidx["files"]),"nativeCounts":[0,1,0],"cleanup":d["ownedSimulatorCleanup"],"diffKeys":sorted(diff)},ensure_ascii=False))
