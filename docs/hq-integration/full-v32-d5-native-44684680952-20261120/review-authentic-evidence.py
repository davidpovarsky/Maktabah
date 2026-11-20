import pathlib,subprocess,json,hashlib,zipfile,datetime,re
wt=pathlib.Path(r"C:\Users\DAVID\Code\Maktabah-v32-occurrence-probe-20261120")
out=wt/"build/full-v32-d5-44684680952/collection";z=zipfile.ZipFile(out/"full-v32-native-prebuilt-evidence-14611023544.zip")
head="b07f229e85fe894722566ad9444de31d0ba4490f";app="2e6f08659b347a755aef4e4fe6c00d9592ba700d"
def git(*a):return subprocess.run(["git",*a],cwd=wt,capture_output=True,check=True).stdout
def h(b):return hashlib.sha256(b).hexdigest()
def get(name):return json.loads(z.read(name))
run=get("hq-v32-prebuilt-native/run.json");stage=get("hq-stage2/result.json");install=get("hq-v32-prebuilt-native/reports/otzaria-prebuilt-install.json");reopen=get("hq-v32-prebuilt-native/reports/otzaria-prebuilt-reopen.json")
assert run["checkout_sha"]==stage["checkout_sha"]==head and run["application_source_sha"]==stage["application_source_sha"]==app
assert run["status"]=="FULL_V32_ORIGINAL_APP_INSTALL_QUERY_RELAUNCH_PASS" and stage["status"]=="SIMULATOR_BUILD_FOR_REAL_UI_PASS"
bound={}
for path,key in [
 ("Scripts/CI/hq-v32-prebuilt-native.py","driver_sha256"),
 ("Scripts/run-otzaria-prebuilt-acceptance.sh","native_launcher_sha256"),
 ("Source/Otzaria/Search/Distribution/OtzariaPrebuiltSearchAcceptanceRunner.swift","native_runner_sha256"),
 (".github/workflows/otzaria-search-artifacts.yml","workflow_sha256")]:
 b=git("show",head+":"+path);digest=h(b);assert digest==run[key],(path,digest,run[key]);bound[path]=digest
for path in ["Source","Vendor","Maktabah.xcodeproj"]:
 tree=git("rev-parse",app+":"+path).decode().strip()
 assert tree==git("rev-parse",head+":"+path).decode().strip()==stage["application_trees"][path]
for name,digest in run["report_sha256"].items():assert h(z.read("hq-v32-prebuilt-native/reports/"+name))==digest,name
log=z.read("hq-v32-prebuilt-native/native-prebuilt.log");assert h(log)==run["raw_log_sha256"]
assert run["source_database_unchanged"] is True and run["actual_app_database_sha256"]=="2f4dcd72e8bdb1fc5c0516ae9705e57759c017ec2981b49c35115625c3d3f765"
pin=out/"pinned-validation-inputs";paths=[
 "Scripts/CI/hq-v32-prebuilt-native.py",
 "docs/hq-integration/index-read-qualification-20261120/QUALIFICATION_REVIEW.json",
 "docs/hq-integration/index-read-qualification-20261120/raw/full-sql-global-oracle/attempt4-partitioned/RESULT.json.gz",
 "docs/hq-integration/full-v32-native-20261119/otzaria-search-manifest.json"]
inputs={}
for path in paths:
 b=git("show",head+":"+path);p=pin/path;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b);inputs[path]={"bytes":len(b),"sha256":h(b)}
driver=pin/paths[0];namespace={"__name__":"_authentic_native_report_review","__file__":str(driver)}
exec(compile(driver.read_bytes(),str(driver),"exec"),namespace)
verification=namespace["validate_reports"](install,reopen,log.decode("utf-8"))
assert verification==run["verification"],(verification,run["verification"])
container=get("hq-v32-prebuilt-native/reports/otzaria-prebuilt-container.json")
assert container==run["app_container_witness"]
verified_path=namespace["validated_container_witness"](container,run["simulator"]["udid"],"com.davidpovarsky.chavrusatext",run["app_container_witness"]["invocation_nonce"])
assert verified_path==container["data_container"]
assert run["original_launcher_exit_code"]==0 and run["owned_simulator_cleanup"]["exit_code"]==0
assert run["ui_xctest_cases_executed"]==0 and run["physical_device"]=="NOT_RUN" and run["publication"] is False and run["reindex"] is False
phases=[]
for x in [install,reopen]:
 phases.append({"phase":x["phase"],"passed":x["passed"],"documentCount":x["documentCount"],"sourceCount":x["sourceCount"],"consumerCommit":x["consumerBuild"]["upstreamCommit"],"artifactProducer":x["artifactProducer"],"nativeDownloadRan":x["nativeDownloadRan"],"resumedDownloadBytes":x["resumedDownloadBytes"],"localIndexingRan":x["localIndexingRan"],"original_modes":x["checks"],"golden_count":len(x["golden"]["orderedResultIDs"]),"exactOccurrences":x["exactOccurrences"]})
r={"status":"VERIFIED_AUTHENTIC_NATIVE_REPORTS_ONLY","observed_utc":datetime.datetime.now(datetime.timezone.utc).isoformat(),"checkout_sha":head,"application_source_sha":app,"artifact_id":14611023544,"archive_sha256":h((out/"full-v32-native-prebuilt-evidence-14611023544.zip").read_bytes()),"validation":"Unmodified exact-checkout original Python validate_reports/load_occurrence_oracle and container validation executed against authenticated ZIP reports and exact Git source oracle; no new Native run","original_validator_and_native_source_sha256":bound,"pinned_read_inputs":inputs,"verification":verification,"phases":phases,"source_database_unchanged":True,"actual_app_database_sha256":run["actual_app_database_sha256"],"report_sha256":run["report_sha256"],"native_log_sha256":run["raw_log_sha256"],"build":{"xcode":stage["xcode"],"swift":stage["swift"],"sdk":stage["sdk_version"],"source_inputs_verified":stage["actual_source_inputs_verified"],"hanlin_gitlink":stage["hanlin_gitlink"],"scope":stage["scope"],"device":stage["device"],"signing":stage["signing"],"framework_inputs":[{"id":v["id"],"sha256":v["verified_sha256"],"producer":v.get("verified_producer")} for v in stage["artifact_inputs"][:2]]},"simulator":run["simulator"],"scope":run["scope"],"publication":False,"reindex":False,"xctest_ui_cases":0,"physical_device":"NOT_RUN","original_owned_simulator_cleanup_exit":0}
(out/"AUTHENTIC_REPORT_REVIEW.json").write_text(json.dumps(r,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
print(json.dumps({"status":r["status"],"report_sha256":h((out/"AUTHENTIC_REPORT_REVIEW.json").read_bytes()),"verification":verification,"inputs_verified":len(inputs),"source_hash_bindings":bound,"phase_counts":[{"phase":x["phase"],"counts":[{k:c["result"][k] for k in ["occurrences","matchingLiveDocuments"]} for c in x["exactOccurrences"]]} for x in phases]},ensure_ascii=False))
