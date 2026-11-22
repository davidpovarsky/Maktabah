from pathlib import Path
import hashlib,json,subprocess,time,datetime
work=Path(r"C:\Users\DAVID\Code\Maktabah-hanlin-diagnostics-20261122")
temp=Path(r"C:\Users\DAVID\AppData\Local\Temp\otzaria-hanlin-live7-diagnostic-implementation-20261122")
proposal=Path(r"C:\Users\DAVID\AppData\Local\Temp\otzaria-hanlin-live7-diagnostic-proposal-20261122")
base="4287063689fb2f17ea9a8fcd436ed98e6985f21f"
branch="codex/otzaria-hanlin-connection-diagnostics-20261122"
assert not (temp/"SOURCE_RECEIPT.json").exists()
(temp/"FIRST_ATTEMPT_FAILURE.json").write_text("{\n  \"id\": \"job_66c3ca31aff5\",\n  \"type\": \"job_result\",\n  \"source\": \"script_run@host_7ec8382e82747448\",\n  \"severity\": \"warning\",\n  \"tool\": \"script_run\",\n  \"host\": \"host_7ec8382e82747448\",\n  \"status\": \"failed\",\n  \"exit_code\": 1,\n  \"created_at\": 1795332885.3999093,\n  \"started_at\": \"2026-11-22T07:34:45.468813+00:00\",\n  \"finished_at\": \"2026-11-22T07:35:39.108080+00:00\",\n  \"duration_s\": 53.64,\n  \"error\": null,\n  \"output_truncated\": false,\n  \"timeout_s\": 300,\n  \"read\": false,\n  \"notified\": {\n    \"telegram\": null,\n    \"resend\": null\n  },\n  \"notify_spec\": {},\n  \"output\": \"Traceback (most recent call last):\\r\\n  File \\\"C:\\\\ProgramData\\\\SentinelX\\\\uploads\\\\.sentinelx_uploads\\\\script_job_fad31bb83e404a42a1ce126627635b36\\\\script.py\\\", line 40, in <module>\\r\\n    assert (work/path).read_bytes()==before,path\\r\\n           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^\\r\\nAssertionError: Source/ChavrusaText/HanlinHostAdapter/OtzariaHanlinChatSession.swift\"\n}"+"\n",encoding="utf-8")
(temp/"source-continuation-runner.py").write_bytes(Path(__file__).read_bytes())
commands=[]
def git(args,timeout=120):
    t=time.monotonic()
    p=subprocess.run(["git",*args],cwd=work,capture_output=True,timeout=timeout)
    row={"command":["git",*args],"cwd":str(work),"exitCode":p.returncode,"elapsedSeconds":time.monotonic()-t,"stdout":p.stdout.decode("utf-8","replace"),"stderr":p.stderr.decode("utf-8","replace")}
    commands.append(row)
    (temp/"SOURCE_CONTINUATION_COMMANDS.json").write_text(json.dumps(commands,indent=2)+"\n",encoding="utf-8")
    assert p.returncode==0,row
    return p.stdout
assert git(["rev-parse","HEAD"]).decode().strip()==base
assert git(["branch","--show-current"]).decode().strip()==branch
assert not git(["status","--porcelain=v1","--untracked-files=all"])
assert git(["config","--get","core.autocrlf"]).decode().strip()=="true"
diagnosis=json.loads((temp/"CHECKOUT_EOL_DIAGNOSIS.json").read_bytes())
by_path={r["path"]:r for r in diagnosis["files"]}
receipt=json.loads((proposal/"PROPOSAL_RECEIPT.json").read_bytes())
changed=[]
for row in receipt["files"]:
    path=row["path"]
    before=git(["show",base+":"+path])
    assert len(before)==row["preimageBytes"] and hashlib.sha256(before).hexdigest()==row["preimageSHA256"]
    checked=(work/path).read_bytes()
    expected=by_path[path]
    assert len(checked)==expected["worktreeBytes"] and hashlib.sha256(checked).hexdigest()==expected["worktreeSHA256"]
    assert checked.replace(b"\r\n",b"\n")==before and b"\r" not in checked.replace(b"\r\n",b"\n")
    candidate=(proposal/"candidate"/path).read_bytes()
    assert len(candidate)==row["candidateBytes"] and hashlib.sha256(candidate).hexdigest()==row["candidateSHA256"]
    (work/path).write_bytes(candidate)
    changed.append(path)
assert set(git(["diff","--name-only"]).decode().splitlines())==set(changed)
git(["diff","--check"])
diff=git(["diff","--binary","--",*changed])
(temp/"SOURCE.diff").write_bytes(diff)
git(["-c","core.autocrlf=false","add","--",*changed])
for row in receipt["files"]:
    blob=git(["show",":"+row["path"]])
    assert len(blob)==row["candidateBytes"] and hashlib.sha256(blob).hexdigest()==row["candidateSHA256"]
assert set(git(["diff","--cached","--name-only"]).decode().splitlines())==set(changed)
git(["commit","-m","Add bounded private Hanlin connection diagnostics"])
source=git(["rev-parse","HEAD"]).decode().strip()
assert git(["rev-parse","HEAD^"]).decode().strip()==base
assert not git(["status","--porcelain=v1","--untracked-files=all"])
trees={p:git(["rev-parse",source+":"+p]).decode().strip() for p in ["Source","Vendor","Maktabah.xcodeproj","Maktabah-iOSUITests"]}
for p in ["Vendor","Maktabah.xcodeproj","Maktabah-iOSUITests"]:
    assert trees[p]==git(["rev-parse",base+":"+p]).decode().strip()
for row in receipt["files"]:
    actual=git(["show",source+":"+row["path"]])
    assert len(actual)==row["candidateBytes"] and hashlib.sha256(actual).hexdigest()==row["candidateSHA256"]
result={"schemaVersion":1,"status":"SOURCE_COMMITTED_LOCAL_ONLY","createdUTC":datetime.datetime.now(datetime.timezone.utc).isoformat(),"base":base,"source":source,"branch":branch,"worktree":str(work),"changedFiles":receipt["files"],"trees":trees,"diffSHA256":hashlib.sha256(diff).hexdigest(),"allFiveExactReviewedCandidateBytes":True,"clean":True,"validationPacketIndexSHA256":"e4d3bd2d017f9ba74c9f7eddaff5415918255b2f69b6d44882278892e8773c98","originalFailedAttemptRetained":True,"checkoutNormalization":"Initial clean checkout had only documented core.autocrlf=true CRLF smudging. Original Git blobs independently matched. Applied reviewed LF candidate bytes; staged with per-command core.autocrlf=false and verified every immutable blob. No global config mutation.","noPushNoSecretNoCI":True}
(temp/"SOURCE_RECEIPT.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
print(json.dumps(result))
