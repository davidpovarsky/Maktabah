import ast, hashlib, json, os, re, subprocess, time, traceback, zipfile
from datetime import datetime, timezone
from pathlib import Path

ROOT=Path(r"C:\Users\DAVID\Code\Maktabah-hanlin-live10-20261122")
OUT=ROOT/"build/hanlin-live10-lifecycle"
SHA="9533a8017adadecf770b19811e72b495f32e90f7"
APP="3b4345bd0ae33b83c2ff4ae7697164343f0792b8"
DIAGNOSTIC_APP="6aa953048453b64a0013621ce76e095770eb7e7d"
NATIVE_ARCHIVE=Path(r"C:\Users\DAVID\AppData\Local\Temp\otzaria-continuation-root-20261122\native450416\evidence.zip")
NATIVE_ARCHIVE_SHA256="e86d64c98c774b3e6e01611d46b2ab753c7c8b145643d6b654abfc6c2fb1b2b6"
NATIVE_ARTIFACT_ID=14763633318
NATIVE_RUN=45041601629
NATIVE_HEAD="6591bba49d2b5a28d02b763c4360406843fce4cf"
MODEL="gemini-3.5-flash-lite"
OLD="4624635d0f29e3bda7ff1f0ecd1097f8b2d37db1"
BRANCH="codex/otzaria-hanlin-live-20261121"
REPO="davidpovarsky/Maktabah"
SECRET="OTZARIA_LIVE_GEMINI_API_KEY"
ENDPOINT="repos/"+REPO+"/actions/secrets/"+SECRET
assert not OUT.exists(), "Preserve existing lifecycle and its sole observer"
OUT.mkdir(parents=True)
env={k:v for k,v in os.environ.items() if k not in {"GEMINI_API_KEY","OTZARIA_LIVE_GEMINI_API_KEY","OTZARIA_HANLIN_LIVE_API_KEY"}}
record={"repository":REPO,"secret_name":SECRET,"source_environment_name":"GEMINI_API_KEY","checkout_sha":SHA,
        "application_source_sha":APP,"trigger_branch":BRANCH,"started_utc":datetime.now(timezone.utc).isoformat(),
        "credential_in_argv":False,"credential_value_written_to_evidence":False,"secret_cleanup_required":False,
        "controller_sha256":hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
def save():
    (OUT/"lifecycle.json").write_bytes((json.dumps(record,indent=2)+"\n").encode())
def command(args,timeout=60,input=None):
    return subprocess.run(args,cwd=ROOT,env=env,input=input,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=timeout)
def git(*args):
    r=command(["git","-c","core.autocrlf=false",*args])
    assert r.returncode==0,"Git command failed: "+args[0]
    return r.stdout.decode().strip()
def api(path):
    r=command(["gh","api",path])
    assert r.returncode==0,"GitHub metadata API failed"
    return json.loads(r.stdout)
def secret_http(method="GET"):
    r=command(["gh","api","--include","--method",method,ENDPOINT])
    raw=r.stdout.decode("utf-8",errors="strict")
    codes=re.findall(r"^HTTP/\S+\s+(\d+)",raw,re.M)
    assert codes,"Missing explicit metadata HTTP status"
    code=int(codes[-1])
    data=json.loads(raw[raw.index("{"):]) if code==200 else None
    return code,data
def cleanup():
    status, metadata=secret_http()
    assert status==200 and metadata==record["metadata"],"Secret metadata changed; preserve other owner's value"
    deleted,_=secret_http("DELETE")
    assert deleted==204,"Secret deletion was not acknowledged"
    absent,_=secret_http()
    assert absent==404,"Secret absence not verified"
    receipt={"state":"DELETED_AND_ABSENCE_VERIFIED","before_metadata":metadata,"delete_http_status":deleted,
             "after_http_status":absent,"checkout_sha":SHA,"run_id":record.get("run_id"),
             "finished_at":datetime.now(timezone.utc).isoformat()}
    (OUT/"cleanup.json").write_bytes((json.dumps(receipt,indent=2)+"\n").encode())
    record.update(state=receipt["state"],secret_cleanup_required=False,cleanup_receipt=str(OUT/"cleanup.json"))
    save()
save()
try:
    previous=api("repos/"+REPO+"/actions/runs/45048898269")
    assert previous["head_sha"]==OLD and previous["run_attempt"]==1 and previous["status"]=="completed" and previous["conclusion"]=="failure", "Previous Live9 is not the exact terminal failure"
    packet=ROOT/"docs/hq-integration/completion-20261122/hanlin-live10-shutdown"
    prior=packet/"original-run45048898269"
    raw=(prior/"evidence.zip").read_bytes()
    assert len(raw)==79158 and hashlib.sha256(raw).hexdigest()=="110b05a270e90ac63706c58cdedab6816b2a94bc06c320b7fbea3a8ba5b2fec1"
    intake=json.loads((prior/"INTAKE.json").read_bytes())
    import io
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        assert archive.testzip() is None and len(archive.namelist())==15
        for row in intake["files"]:
            data=archive.read(row["path"])
            assert len(data)==row["bytes"] and hashlib.sha256(data).hexdigest()==row["sha256"]
        old_result=json.loads(archive.read("result.json"))
    assert old_result["status"]=="FAIL" and old_result["private_input_staged"] is False and old_result["verified_completed_provider_conversations"]==0
    old_cleanup=json.loads((prior/"OWNED_SECRET_CLEANUP.json").read_bytes())
    assert old_cleanup["run_id"]==45048898269 and old_cleanup["state"]=="DELETED_AND_ABSENCE_VERIFIED" and old_cleanup["delete_http_status"]==204 and old_cleanup["after_http_status"]==404
    peer=json.loads((packet/"HEART_SOURCE_REVIEW.json").read_bytes())
    assert peer["status"]=="SOURCE_REVIEW_CLEAR_NO_EXECUTION" and peer["matrix_delta_exact_two_recovery_timeouts_240_to_300"] is True
    controls=json.loads((packet/"CONTROL_EXECUTION_OBSERVATION.json").read_bytes())
    assert controls["status"]=="PASS_FOUR_NEW_BUDGET_AND_PHASE_CONTROLS" and controls["cases"]==4 and controls["exit_code"]==0 and controls["old_controls_replayed"]==0
    for row in controls["source_files"]:
        data=(packet/row["path"]).read_bytes()
        assert len(data)==row["bytes"] and hashlib.sha256(data).hexdigest()==row["sha256"]
        if row["path"].startswith("candidate/"):
            assert (ROOT/row["path"].removeprefix("candidate/")).read_bytes()==data
    assert hashlib.sha256((packet/"CONTROL_EXECUTION_TOOL_OUTPUT.txt").read_bytes()).hexdigest()==controls["tool_output_sha256"]
    record["previous_failed_live"]={"run_id":45048898269,"head":OLD,"artifact_id":14767750188,"archive_sha256":hashlib.sha256(raw).hexdigest(),"case_executed":False,"temporary_credential_clean":True,"old_payloads_verified":15,"source_controls":4,"new_requests":0}
    save()
    assert re.fullmatch(r"[0-9a-f]{64}",NATIVE_ARCHIVE_SHA256) and NATIVE_ARTIFACT_ID>0, "Native archive binding is not finalized"
    prerequisite=api("repos/"+REPO+"/actions/runs/"+str(NATIVE_RUN))
    assert prerequisite["head_sha"]==NATIVE_HEAD and prerequisite["run_attempt"]==1, "Native prerequisite source or attempt changed"
    assert prerequisite["status"]=="completed" and prerequisite["conclusion"]=="success", "The original fresh read connection prerequisite has not passed"
    record["native_prerequisite"]={k:prerequisite[k] for k in ["id","head_sha","run_attempt","status","conclusion","updated_at","html_url"]}
    record["native_prerequisite_application_source"]=APP
    artifact=api("repos/"+REPO+"/actions/artifacts/"+str(NATIVE_ARTIFACT_ID))
    assert not artifact["expired"] and artifact["workflow_run"]["id"]==NATIVE_RUN and artifact["workflow_run"]["head_sha"]==NATIVE_HEAD
    assert artifact["digest"]=="sha256:"+NATIVE_ARCHIVE_SHA256
    archive_bytes=NATIVE_ARCHIVE.read_bytes()
    assert len(archive_bytes)==artifact["size_in_bytes"] and hashlib.sha256(archive_bytes).hexdigest()==NATIVE_ARCHIVE_SHA256
    with zipfile.ZipFile(NATIVE_ARCHIVE) as archive:
        def member(suffix):
            names=[name for name in archive.namelist() if name.endswith(suffix)]
            assert len(names)==1, "Exact original Native result member is missing or ambiguous"
            return archive.read(names[0])
        summary_bytes=member("artifacts/runtime27/verified-11-reader.summary.json")
        cases_bytes=member("artifacts/runtime27/verified-11-reader.tests.json")
    summary=json.loads(summary_bytes)
    assert summary["result"]=="Passed" and summary["passedTests"]==1 and summary["failedTests"]==0 and summary["skippedTests"]==0
    def leaves(nodes):
        result=[]
        for node in nodes:
            if node.get("nodeType")=="Test Case":result.append(node)
            result.extend(leaves(node.get("children",[])))
        return result
    cases=leaves(json.loads(cases_bytes)["testNodes"])
    assert len(cases)==1 and cases[0]["nodeIdentifier"]=="HanlinReaderConsumerAcceptanceTests/testOriginalIPadFreshCurrentWorkReadConnectionWithoutSending()"
    assert cases[0]["result"]=="Passed" and cases[0]["durationInSeconds"]>0
    record["native_prerequisite_raw"]={"artifact_id":NATIVE_ARTIFACT_ID,"archive_sha256":NATIVE_ARCHIVE_SHA256,
        "summary_sha256":hashlib.sha256(summary_bytes).hexdigest(),"case_tree_sha256":hashlib.sha256(cases_bytes).hexdigest(),
        "actual_cases":1,"pass":1,"fail":0,"skip":0,"additional_artifact_downloads":0}
    record["native_prerequisite_scope"]="Actual original fresh current-work read connection without Send, on the same application/test product trees"
    record["execution_reason"]="Continue the unexecuted Live9 selector after reviewed owned-shutdown budget/phase correction; actual fixture failure retained and passing Native/component cases are not replayed"
    save()
    assert git("rev-parse","HEAD")==SHA and git("status","--porcelain=v1")=="","Live source not clean and exact"
    for path in ["Source","Vendor","Maktabah.xcodeproj","Maktabah-iOSUITests"]:
        assert git("rev-parse","HEAD:"+path)==git("rev-parse",APP+":"+path)
    packet=ROOT/"docs/hq-integration/completion-20261122/hanlin-connection-diagnostics"
    index_bytes=(packet/"FILE_INDEX.json").read_bytes()
    assert hashlib.sha256(index_bytes).hexdigest()=="6fe9d44ec4d6596851cdd55be689e8ab9956486a2ea15cae06e4107c49b1b748","Diagnostic evidence changed"
    index=json.loads(index_bytes)
    assert index["applicationSource"]==DIAGNOSTIC_APP and len(index["files"])==82
    for item in index["files"]:
        raw=(packet/item["path"]).read_bytes()
        assert len(raw)==item["bytes"] and hashlib.sha256(raw).hexdigest()==item["sha256"],"Diagnostic evidence payload changed"
    review=json.loads((packet/"independent/ROOT_WINDOWS_REVIEW.json").read_bytes())
    assert review["status"]=="PASS" and review["source"]==DIAGNOSTIC_APP and review["pythonCasesVerified"]==34 and review["swiftCompleteFileSyntaxParses"]==4
    integration=json.loads((ROOT/"docs/hq-integration/completion-20261122/hanlin-connection-diagnostic-integration/INTEGRATION.json").read_bytes())
    assert integration["applicationSource"]==DIAGNOSTIC_APP and integration["incoming"]=="5cd307d31b1d813f756014c9903a5808b9aacddd"
    record["diagnostic_source_review"]={"source":DIAGNOSTIC_APP,"scope":"Historical exact-source control evidence; new complete product trees require the actual Native prerequisite","evidence_payloads_verified":82,"root_review_sha256":hashlib.sha256((packet/"independent/ROOT_WINDOWS_REVIEW.json").read_bytes()).hexdigest(),"python_controls":34,"swift_syntax_only_files":4}
    pins=json.loads((ROOT/"Scripts/CI/hq-stage2-focused-apple.inputs.json").read_bytes())
    assert pins["application_source_sha"]==APP
    for name in ["Scripts/CI/runtime27-hanlin-live.py","Scripts/CI/runtime27-live-paragraph-oracle.py"]:
        ast.parse((ROOT/name).read_text(encoding="utf-8"))
    live_source=ast.parse((ROOT/"Scripts/CI/runtime27-hanlin-live.py").read_text(encoding="utf-8"))
    literals={node.targets[0].id:ast.literal_eval(node.value) for node in live_source.body
              if isinstance(node,ast.Assign) and len(node.targets)==1 and isinstance(node.targets[0],ast.Name)
              and node.targets[0].id in {"MODEL","REVIEWED_SOURCE","ENDPOINT"}}
    assert literals=={"MODEL":MODEL,"REVIEWED_SOURCE":APP,"ENDPOINT":"https://generativelanguage.googleapis.com/v1beta/openai/"}
    provider_result=ROOT/"docs/hq-integration/completion-20261122/hanlin-live9-accessibility/provider-access/current-model/RESULT.json"
    provider_bytes=provider_result.read_bytes()
    assert hashlib.sha256(provider_bytes).hexdigest()=="18fd35c6c6976b11c4ae10ec6579e1f89c9a5ca5ee1921e5616c6f6d8bc0e91d"
    provider=json.loads(provider_bytes)
    assert provider["model"]==MODEL and provider["response_model"]==MODEL and provider["http_status"]==200 and provider["exact_constant_reply"] is True
    assert provider["native_acceptance"] is False and provider["new_repository_secret_created"] is False
    record["provider_availability"]={"model":MODEL,"result_sha256":hashlib.sha256(provider_bytes).hexdigest(),
        "scope":"Separate actual availability probe, not native app acceptance","additional_requests":0}
    closure=command(["git","ls-tree","-r","-z","HEAD","--","Scripts/CI","Scripts/verify-otzaria-mini-parity.py",
                     ".github/workflows","tools","Maktabah-iOSUITests","docs/hq-integration/runtime27/R27_CASES.json"])
    assert closure.returncode==0
    checked=0
    for row in closure.stdout.split(b"\0"):
        if not row:continue
        meta,name=row.split(b"\t",1);mode,kind,expected=meta.decode().split()
        assert kind=="blob"
        p=ROOT/name.decode()
        raw=os.readlink(p).encode() if mode=="120000" and p.is_symlink() else p.read_bytes()
        assert hashlib.sha1(b"blob "+str(len(raw)).encode()+b"\0"+raw).hexdigest()==expected, "Dirty exact execution input: "+name.decode()
        checked+=1
    assert checked==281,"Unexpected actual execution input closure"
    assert git("ls-remote","origin","refs/heads/"+BRANCH).split()[0]==OLD,"Concurrent live branch changed"
    runs=api("repos/"+REPO+"/actions/workflows/otzaria-hanlin-live-native.yml/runs?branch="+BRANCH+"&per_page=20")["workflow_runs"]
    assert all(run["status"]=="completed" for run in runs),"An existing live run is active"
    status,_=secret_http()
    assert status==404,"Temporary live secret already exists; do not replace another owner"
    key=os.environ.get("GEMINI_API_KEY")
    if not key:
        import winreg
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER,"Environment") as registry:
            key=winreg.QueryValueEx(registry,"GEMINI_API_KEY")[0]
    assert isinstance(key,str) and 20<=len(key)<=4096 and all(32<ord(ch)<127 for ch in key),"Configured provider credential unavailable"
    record.update(prior_absent=True,execution_inputs_verified=checked,state="PREPARED_SOURCE_BOUND")
    save()
    record.update(secret_cleanup_required=True,state="SECRET_SET_REQUESTED",secret_set_started_utc=datetime.now(timezone.utc).isoformat())
    save()
    try:
        set_result=command(["gh","secret","set",SECRET,"--repo",REPO],input=key.encode())
    finally:
        key=None
    assert set_result.returncode==0,"Unable to configure temporary live secret"
    record.update(secret_cleanup_required=True,state="SECRET_CONFIGURED_METADATA_PENDING")
    save()
    status,metadata=secret_http()
    assert status==200 and metadata["name"]==SECRET,"Temporary secret metadata unavailable"
    record.update(metadata=metadata,state="SECRET_OWNED")
    save()
    record["push_started_utc"]=datetime.now(timezone.utc).isoformat()
    save()
    pushed=command(["git","push","origin",SHA+":refs/heads/"+BRANCH],timeout=120)
    record["push_exit_code"]=pushed.returncode
    save()
    assert pushed.returncode==0,"Single non-force Live push failed; inspect whether server accepted it"
    record.update(state="PUSHED_AWAITING_EXACT_RUN",dispatch_started_utc=datetime.now(timezone.utc).isoformat())
    save()
    found=[]
    for attempt in range(12):
        runs=api("repos/"+REPO+"/actions/workflows/otzaria-hanlin-live-native.yml/runs?head_sha="+SHA+"&per_page=10")["workflow_runs"]
        found=[r for r in runs if r["head_sha"]==SHA and r["head_branch"]==BRANCH and r["event"]=="push"]
        if found:break
        time.sleep(3)
    assert len(found)==1 and found[0]["run_attempt"]==1,"Exact single Live run not identified"
    run=found[0]
    record.update(state="RUNNING",run_id=run["id"],run_attempt=1,run_url=run["html_url"])
    save()
    print(json.dumps({"state":record["state"],"run_id":run["id"],"run_url":run["html_url"],
                      "checkout_sha":SHA,"execution_inputs_verified":checked,"sole_observer":True}),flush=True)
    with (OUT/"watch.log").open("wb") as log:
        try:
            watch=subprocess.run(["gh","run","watch",str(run["id"]),"--repo",REPO,"--interval","30","--exit-status"],
                                 cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=3300)
            record["watch_exit_code"]=watch.returncode
        except subprocess.TimeoutExpired:
            record["watch_timed_out"]=True
    final=api("repos/"+REPO+"/actions/runs/"+str(run["id"]))
    assert final["head_sha"]==SHA and final["run_attempt"]==1,"Run source/attempt changed"
    record["observed_run"]={k:final[k] for k in ["id","head_sha","run_attempt","status","conclusion","updated_at","html_url"]}
    if final["status"]=="completed":
        cleanup()
    else:
        record["state"]="OBSERVER_WINDOW_ENDED_CI_STILL_ACTIVE"
        save()
    print(json.dumps(record),flush=True)
except BaseException as error:
    record.update(state="LIFECYCLE_REQUIRES_REVIEW",error_kind=type(error).__name__,error=str(error))
    # Before a push, no workflow can own this scoped value. After a possible
    # push, preserve it until exact terminal run state has been inspected.
    if record.get("secret_cleanup_required") and record.get("metadata") and "push_started_utc" not in record:
        try: cleanup()
        except Exception as cleanup_error:record["cleanup_error_kind"]=type(cleanup_error).__name__
    save()
    print(json.dumps(record),flush=True)
    raise SystemExit(1)
