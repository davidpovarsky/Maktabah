from pathlib import Path
import subprocess,json,hashlib,datetime
ROOT=Path(r"C:\Users\DAVID\Code\Maktabah-native-followup-20261122")
OUT=ROOT/"build/native-consent-result-44987561349"
E=OUT/"evidence"
C=E/"artifacts/continuation-focused"
HEAD="64112a15b9fd1fb63d54b21b5d60cfc8bc96ba0b"
APP="0ea7218331d1441d37d06d43333e579f267056e3"
CASE="HanlinReaderConsumerAcceptanceTests/testOriginalIPadCurrentWorkConsentToggleWithoutConnection"
def read(path):return json.loads(path.read_bytes())
def sha(data):return hashlib.sha256(data).hexdigest()
def git(*args):return subprocess.check_output(["git",*args],cwd=ROOT,timeout=90)
before=read(C/"source-before.json");report=read(C/"result.json");selection=read(C/"selection.json")
build=read(E/"hq-stage2/result.json");post=read(C/"original-post-ui-input-audit.json")
strict=read(E/"artifacts/runtime27/verified-11-reader.json")
summary=read(E/"artifacts/runtime27/verified-11-reader.summary.json")
tests=read(E/"artifacts/runtime27/verified-11-reader.tests.json")
matrix=read(E/"artifacts/faithful-ipad-matrix.json")
assert before["checkout_sha"]==HEAD and before["application_source_sha"]==APP
assert all(report[k]==v for k,v in before.items())
assert report["status"]=="SELECTED_UI_EXECUTED_PASS" and report["scope"]=="FOCUSED_CONSENT_ONLY"
assert report["full_native116_acceptance"]is False and report["full_release114_acceptance"]is False
trees=before["application_trees"]
refs=[ref+":"+path for ref in [HEAD,APP]for path in trees]
actual=git("rev-parse",*refs).decode().splitlines()
assert actual==list(trees.values())*2
assert selection["source_test_commit"]==selection["app_source"]==selection["application_source_sha"]==APP
assert selection["execution_case_ids"]==report["required_case_ids"]==[CASE]
assert selection["execution_groups"]==[{"label":"11-reader","size":"11","hid_comparison":False,"case_ids":[CASE]}]
assert selection["hid_comparison"]is False and selection["required_nonzero_cases"]==1
records=before["execution_inputs"]
tracked={}
for row in git("ls-tree","-r","-z",HEAD,"--","Scripts/CI",".github/workflows","Maktabah-iOSUITests","tools").split(b"\0"):
 if not row:continue
 meta,name=row.split(b"\t",1);mode,kind,oid=meta.decode().split()
 if kind=="blob":tracked[name.decode()]=oid
assert set(tracked)==set(records)and len(records)==276
names=list(records)
requests=("\n".join(HEAD+":"+name for name in names)+"\n").encode()
process=subprocess.run(["git","cat-file","--batch"],input=requests,cwd=ROOT,capture_output=True,timeout=120)
assert process.returncode==0,process.stderr.decode(errors="replace")
raw=process.stdout;offset=0
for name in names:
 end=raw.index(b"\n",offset);oid,kind,size=raw[offset:end].decode().split();size=int(size);offset=end+1
 data=raw[offset:offset+size];offset+=size
 assert raw[offset:offset+1]==b"\n";offset+=1
 record=records[name]
 assert kind=="blob"and oid==tracked[name]==record["blob"],name
 assert size==record["bytes"]and sha(data)==record["sha256"],name
assert offset==len(raw)
for path,key in [("docs/hq-integration/runtime27/R27_CASES.json","native116_catalog_sha256"),("Scripts/CI/runtime27-release-manifest.json","release114_manifest_sha256")]:
 assert sha(git("show",HEAD+":"+path))==before[key]
assert build["status"]=="SIMULATOR_BUILD_FOR_REAL_UI_PASS"
assert build["checkout_sha"]==HEAD and build["application_source_sha"]==APP
assert all(build["application_trees"][p]==trees[p]for p in ["Source","Vendor","Maktabah.xcodeproj"])
assert set(build)==set(post)
assert [k for k in build if build[k]!=post[k]]==["commands","generated_configuration"]
assert post["commands"][:-1]==build["commands"]
assert post["commands"][-1]==[build["commands"][0][0],"Scripts/CI/prepare-hanlin-sdk.py","--sha",build["hanlin_gitlink"],"--output","/Users/runner/work/Maktabah/Maktabah/build/hq-stage2/hanlin-sdk-inputs-after.json","--verify-only"]
assert len(build["generated_configuration"])==1
assert post["generated_configuration"]==build["generated_configuration"]*2
assert report["built_binary_sha256"]==read(C/"built-binaries.json")and len(report["built_binary_sha256"])==3
assert report["compiled_image_bytes_unchanged"]is True
assert strict["status"]=="EXECUTED_PASS"and strict["executed_total"]==strict["required_ui_passed"]==1
assert strict["required_ui_cases"]==[CASE]and set(strict["cases"])=={CASE}
assert strict["cases"][CASE]["status"]=="Passed"and strict["failed"]==strict["skipped"]==0
assert sha(json.dumps(summary,sort_keys=True).encode())==strict["summary_sha256"]
assert sha(json.dumps(tests,sort_keys=True).encode())==strict["tests_sha256"]
assert summary["result"]=="Passed"and summary["totalTestCount"]==summary["passedTests"]==1
assert summary["failedTests"]==summary["skippedTests"]==summary["expectedFailures"]==0
assert not summary["testFailures"]
nodes=[]
def walk(value):
 if isinstance(value,dict):
  if value.get("nodeType")=="Test Case":nodes.append(value)
  for child in value.get("children",[]):walk(child)
for node in tests["testNodes"]:walk(node)
assert len(nodes)==1 and nodes[0]["nodeIdentifier"]==CASE+"()"and nodes[0]["result"]=="Passed"
assert len(matrix["devices"])==1
device=matrix["devices"][0]
assert device["label"]=="11-reader"and device["size"]=="11"
assert device["status"]=="EXECUTED_PASS"and device["ownedSimulatorCleanup"]=="PASS"
assert device["xcodebuildExitCode"]==0 and device["recordedXCTestCount"]==device["executedXCTestCount"]==device["passedXCTestCount"]==1
assert device["failedXCTestCount"]==device["skippedXCTestCount"]==0
assert device["requiredSuites"]==[CASE]and not device["missingOrFailedSuites"]
assert len(summary["devicesAndConfigurations"])==1 and tests["devices"]==[summary["devicesAndConfigurations"][0]["device"]]
actual_device=tests["devices"][0]
assert actual_device["deviceId"]==device["udid"]and actual_device["osVersion"]=="27.2"
assert report["executed_ui_pass"]==1 and report["executed_ui_fail"]==report["executed_ui_skip"]==report["ui_not_run"]==0
assert len(report["case_outcomes"])==1 and report["case_outcomes"][0]["case_id"]==CASE and report["case_outcomes"][0]["actual"]=="Passed"
result={"status":"INDEPENDENT_SOURCE_AND_SINGLE_XCRESULT_PASS_VERIFIED","at":datetime.datetime.now(datetime.timezone.utc).isoformat(),"run_id":44987561349,"checkout_sha":HEAD,"application_source_sha":APP,"application_trees":trees,"execution_input_git_blobs_independently_verified":len(records),"original_auditor_actual_source_inputs_verified":build["actual_source_inputs_verified"],"build_status":build["status"],"compiled_images_unchanged":True,"build_and_post_UI_source_fields_equal":True,"post_UI_only_additions":["Exact original Hanlin --verify-only command","Byte-identical privacy aggregation receipt repeated"],"strict_status":strict["status"],"summary_canonical_sha256":strict["summary_sha256"],"tests_canonical_sha256":strict["tests_sha256"],"counts":{"passed":1,"failed":0,"skipped":0,"not_run":0},"case":nodes[0],"device":actual_device,"cleanup":"PASS","installation_attempts":device["installationAttempts"],"matrix_running_native_phase_at":device["phaseStartedAt"],"summary_started_at":datetime.datetime.fromtimestamp(summary["startTime"],datetime.timezone.utc).isoformat(),"summary_finished_at":datetime.datetime.fromtimestamp(summary["finishTime"],datetime.timezone.utc).isoformat(),"xcode":build["xcode"],"swift":build["swift"],"full_native116_acceptance":False,"full_release114_acceptance":False,"live_provider_acceptance":False,"verification_reexecuted_tests":False}
(OUT/"independent-verification.py").write_bytes(Path(__file__).read_bytes())
(OUT/"INDEPENDENT_VERIFICATION.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8",newline="\n")
print(json.dumps(result))
