import hashlib,json,os,re,subprocess
from pathlib import Path
from datetime import datetime,timezone
ROOT=Path(r"C:\Users\DAVID\Code\Maktabah-hanlin-live9-20261122")
BASE=ROOT/"build/hanlin-live9-lifecycle"
OUT=BASE/"continuation-1"
SHA="4624635d0f29e3bda7ff1f0ecd1097f8b2d37db1"
REPO="davidpovarsky/Maktabah"
SECRET="OTZARIA_LIVE_GEMINI_API_KEY"
ENDPOINT="repos/"+REPO+"/actions/secrets/"+SECRET
PREDECESSOR={'job_id': 'job_cac67a7fd3cb', 'status': 'succeeded', 'exit_code': 0, 'finished_at': '2026-11-22T18:15:45.580610+00:00', 'timeout_seconds': 3600, 'terminal_lifecycle': {'repository': 'davidpovarsky/Maktabah', 'secret_name': 'OTZARIA_LIVE_GEMINI_API_KEY', 'source_environment_name': 'GEMINI_API_KEY', 'checkout_sha': '4624635d0f29e3bda7ff1f0ecd1097f8b2d37db1', 'application_source_sha': '3b4345bd0ae33b83c2ff4ae7697164343f0792b8', 'trigger_branch': 'codex/otzaria-hanlin-live-20261121', 'started_utc': '2026-11-22T17:19:27.467988+00:00', 'credential_in_argv': False, 'credential_value_written_to_evidence': False, 'secret_cleanup_required': True, 'controller_sha256': '9718a5eb04e50f83df9cc83f7c8b284e251ddefbd12ad20fd6ea646bfd4ff93a', 'native_prerequisite': {'id': 45041601629, 'head_sha': '6591bba49d2b5a28d02b763c4360406843fce4cf', 'run_attempt': 1, 'status': 'completed', 'conclusion': 'success', 'updated_at': '2026-11-22T17:01:04Z', 'html_url': 'https://github.com/davidpovarsky/Maktabah/actions/runs/45041601629'}, 'native_prerequisite_application_source': '3b4345bd0ae33b83c2ff4ae7697164343f0792b8', 'native_prerequisite_raw': {'artifact_id': 14763633318, 'archive_sha256': 'e86d64c98c774b3e6e01611d46b2ab753c7c8b145643d6b654abfc6c2fb1b2b6', 'summary_sha256': 'a9835434a6c0885a028fb0154f34e7b60873cb3d4651bc512837fd691d605979', 'case_tree_sha256': '94d1d080d6fac749561d00ac181bcb49d17c778258a146cb65db38509f41aa29', 'actual_cases': 1, 'pass': 1, 'fail': 0, 'skip': 0, 'additional_artifact_downloads': 0}, 'native_prerequisite_scope': 'Actual original fresh current-work read connection without Send, on the same application/test product trees', 'execution_reason': 'One failed Live8 selector with reviewed accessibility correction and actually available replacement model; passing Native/component cases are not replayed', 'diagnostic_source_review': {'source': '6aa953048453b64a0013621ce76e095770eb7e7d', 'scope': 'Historical exact-source control evidence; new complete product trees require the actual Native prerequisite', 'evidence_payloads_verified': 82, 'root_review_sha256': '960d439df6f9d0dd775fbf2f89e44d1066f47bf21024fee21fb70ccf607c5649', 'python_controls': 34, 'swift_syntax_only_files': 4}, 'provider_availability': {'model': 'gemini-3.5-flash-lite', 'result_sha256': '18fd35c6c6976b11c4ae10ec6579e1f89c9a5ca5ee1921e5616c6f6d8bc0e91d', 'scope': 'Separate actual availability probe, not native app acceptance', 'additional_requests': 0}, 'prior_absent': True, 'execution_inputs_verified': 281, 'state': 'OBSERVER_WINDOW_ENDED_CI_STILL_ACTIVE', 'secret_set_started_utc': '2026-11-22T17:20:26.059788+00:00', 'metadata': {'name': 'OTZARIA_LIVE_GEMINI_API_KEY', 'created_at': '2026-11-22T17:20:27Z', 'updated_at': '2026-11-22T17:20:27Z'}, 'push_started_utc': '2026-11-22T17:20:28.469204+00:00', 'push_exit_code': 0, 'dispatch_started_utc': '2026-11-22T17:20:34.861669+00:00', 'run_id': 45048898269, 'run_attempt': 1, 'run_url': 'https://github.com/davidpovarsky/Maktabah/actions/runs/45048898269', 'watch_timed_out': True, 'observed_run': {'id': 45048898269, 'head_sha': '4624635d0f29e3bda7ff1f0ecd1097f8b2d37db1', 'run_attempt': 1, 'status': 'in_progress', 'conclusion': None, 'updated_at': '2026-11-22T17:39:25Z', 'html_url': 'https://github.com/davidpovarsky/Maktabah/actions/runs/45048898269'}}}
assert PREDECESSOR["job_id"]=="job_cac67a7fd3cb" and PREDECESSOR["status"]=="succeeded" and PREDECESSOR["exit_code"]==0
previous_bytes=(BASE/"lifecycle.json").read_bytes()
previous=json.loads(previous_bytes)
assert previous==PREDECESSOR["terminal_lifecycle"]
assert previous["state"]=="OBSERVER_WINDOW_ENDED_CI_STILL_ACTIVE" and previous["watch_timed_out"] is True
assert previous["run_id"]==45048898269 and previous["run_attempt"]==1 and previous["checkout_sha"]==SHA
assert previous["secret_cleanup_required"] is True and previous["prior_absent"] is True
assert not OUT.exists(),"Preserve existing successor observer ownership"
OUT.mkdir()
(OUT/"PREDECESSOR_TERMINAL.json").write_text(json.dumps(PREDECESSOR,indent=2)+"\n",encoding="utf-8")
(OUT/"PREDECESSOR_LIFECYCLE.json").write_bytes(previous_bytes)
env={k:v for k,v in os.environ.items() if k not in {"GEMINI_API_KEY","OTZARIA_LIVE_GEMINI_API_KEY","OTZARIA_HANLIN_LIVE_API_KEY"}}
record=dict(previous)
record.update(state="SUCCESSOR_OWNERSHIP_PREPARED",previous_observer_job_id=PREDECESSOR["job_id"],previous_observer_finished_at=PREDECESSOR["finished_at"],previous_lifecycle_sha256=hashlib.sha256(previous_bytes).hexdigest(),previous_watch_timed_out=True,watch_timed_out=False,observer_window=2,continuation_started_utc=datetime.now(timezone.utc).isoformat(),controller_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),additional_dispatches=0,additional_provider_requests=0,additional_artifact_downloads=0)


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
    assert git("rev-parse","HEAD")==SHA and not git("status","--porcelain"),"Live source worktree changed"
    status,metadata=secret_http()
    assert status==200 and metadata==record["metadata"],"Owned secret metadata changed; do not alter it"
    run=api("repos/"+REPO+"/actions/runs/45048898269")
    assert run["id"]==45048898269 and run["head_sha"]==SHA and run["run_attempt"]==1
    assert run["head_branch"]==record["trigger_branch"] and run["event"]=="push"
    record["state"]="OBSERVING_SAME_ORIGINAL_RUN"
    save()
    (BASE/"ownership-current.json").write_text(json.dumps({"current_lifecycle":str(OUT/"lifecycle.json"),"previous_observer":PREDECESSOR["job_id"],"previous_finished_at":PREDECESSOR["finished_at"],"run_id":45048898269,"secret_cleanup_required":True},indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"state":record["state"],"run_id":45048898269,"observer_window":2,"previous_observer_terminal":True,"additional_dispatches":0}),flush=True)
    if run["status"]!="completed":
        with (OUT/"watch.log").open("wb") as log:
            try:
                watch=subprocess.run(["gh","run","watch","45048898269","--repo",REPO,"--interval","30","--exit-status"],cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=3300)
                record["watch_exit_code"]=watch.returncode
            except subprocess.TimeoutExpired:
                record["watch_timed_out"]=True
    final=api("repos/"+REPO+"/actions/runs/45048898269")
    assert final["head_sha"]==SHA and final["run_attempt"]==1
    record["observed_run"]={k:final[k] for k in ["id","head_sha","run_attempt","status","conclusion","updated_at","html_url"]}
    if final["status"]=="completed":
        cleanup()
    else:
        record["state"]="OBSERVER_WINDOW_ENDED_CI_STILL_ACTIVE"
        save()
    (BASE/"ownership-current.json").write_text(json.dumps({"current_lifecycle":str(OUT/"lifecycle.json"),"run_id":45048898269,"state":record["state"],"secret_cleanup_required":record["secret_cleanup_required"]},indent=2)+"\n",encoding="utf-8")
    print(json.dumps(record),flush=True)
except BaseException as error:
    record.update(state="SUCCESSOR_REQUIRES_REVIEW",error_kind=type(error).__name__,error=str(error))
    save()
    print(json.dumps(record),flush=True)
    raise SystemExit(1)
