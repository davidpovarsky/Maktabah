import ast, hashlib, json, os, re, subprocess, time, traceback
from datetime import datetime, timezone
from pathlib import Path

ROOT=Path(r"C:\Users\DAVID\Code\Maktabah-completion-20261122")
OUT=ROOT/"build/hanlin-live8-lifecycle"
SHA="ce5d11335c4b4769a25e0e8f48ba1d6f7efc6749"
APP="6aa953048453b64a0013621ce76e095770eb7e7d"
OLD="77c7df82ef5f822bf0b1dd7e08ff2b4b98d425d2"
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
    prerequisite=api("repos/"+REPO+"/actions/runs/44987561349")
    assert prerequisite["head_sha"]=="64112a15b9fd1fb63d54b21b5d60cfc8bc96ba0b" and prerequisite["run_attempt"]==1, "Native prerequisite source or attempt changed"
    assert prerequisite["status"]=="completed" and prerequisite["conclusion"]=="success", "The one original no-key consent prerequisite has not passed"
    record["native_prerequisite"]={k:prerequisite[k] for k in ["id","head_sha","run_attempt","status","conclusion","updated_at","html_url"]}
    record["native_prerequisite_application_source"]="0ea7218331d1441d37d06d43333e579f267056e3"
    record["native_prerequisite_scope"]="Historical original no-key consent prerequisite, not acceptance of the new diagnostic application source"
    record["execution_reason"]="One repetition of failed Live7 selector with newly validated private connection diagnostics; no passing Native/component case replay"
    save()
    assert git("rev-parse","HEAD")==SHA and git("status","--porcelain=v1")=="","Live source not clean and exact"
    for path in ["Source","Vendor","Maktabah.xcodeproj","Maktabah-iOSUITests"]:
        assert git("rev-parse","HEAD:"+path)==git("rev-parse",APP+":"+path)
    packet=ROOT/"docs/hq-integration/completion-20261122/hanlin-connection-diagnostics"
    index_bytes=(packet/"FILE_INDEX.json").read_bytes()
    assert hashlib.sha256(index_bytes).hexdigest()=="6fe9d44ec4d6596851cdd55be689e8ab9956486a2ea15cae06e4107c49b1b748","Diagnostic evidence changed"
    index=json.loads(index_bytes)
    assert index["applicationSource"]==APP and len(index["files"])==82
    for item in index["files"]:
        raw=(packet/item["path"]).read_bytes()
        assert len(raw)==item["bytes"] and hashlib.sha256(raw).hexdigest()==item["sha256"],"Diagnostic evidence payload changed"
    review=json.loads((packet/"independent/ROOT_WINDOWS_REVIEW.json").read_bytes())
    assert review["status"]=="PASS" and review["source"]==APP and review["pythonCasesVerified"]==34 and review["swiftCompleteFileSyntaxParses"]==4
    integration=json.loads((ROOT/"docs/hq-integration/completion-20261122/hanlin-connection-diagnostic-integration/INTEGRATION.json").read_bytes())
    assert integration["applicationSource"]==APP and integration["incoming"]=="5cd307d31b1d813f756014c9903a5808b9aacddd"
    record["diagnostic_source_review"]={"source":APP,"evidence_payloads_verified":82,"root_review_sha256":hashlib.sha256((packet/"independent/ROOT_WINDOWS_REVIEW.json").read_bytes()).hexdigest(),"python_controls":34,"swift_syntax_only_files":4}
    pins=json.loads((ROOT/"Scripts/CI/hq-stage2-focused-apple.inputs.json").read_bytes())
    assert pins["application_source_sha"]==APP
    for name in ["Scripts/CI/runtime27-hanlin-live.py","Scripts/CI/runtime27-live-paragraph-oracle.py"]:
        ast.parse((ROOT/name).read_text(encoding="utf-8"))
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
