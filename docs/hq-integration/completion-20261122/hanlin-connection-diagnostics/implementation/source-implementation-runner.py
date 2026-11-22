from pathlib import Path
import hashlib,json,subprocess,time,datetime,sys
common=Path(r"C:\Users\DAVID\Code\Maktabah-completion-20261122")
work=Path(r"C:\Users\DAVID\Code\Maktabah-hanlin-diagnostics-20261122")
temp=Path(r"C:\Users\DAVID\AppData\Local\Temp\otzaria-hanlin-live7-diagnostic-implementation-20261122")
proposal=Path(r"C:\Users\DAVID\AppData\Local\Temp\otzaria-hanlin-live7-diagnostic-proposal-20261122")
validation=Path(r"C:\Users\DAVID\AppData\Local\Temp\otzaria-hanlin-live7-diagnostic-validation-20261122")
base="4287063689fb2f17ea9a8fcd436ed98e6985f21f"
branch="codex/otzaria-hanlin-connection-diagnostics-20261122"
assert not work.exists() and not temp.exists()
temp.mkdir()
(temp/"source-implementation-runner.py").write_bytes(Path(__file__).read_bytes())
commands=[]
def git(args,cwd=work,timeout=120):
    t=time.monotonic()
    p=subprocess.run(["git",*args],cwd=cwd,capture_output=True,timeout=timeout)
    row={"command":["git",*args],"cwd":str(cwd),"exitCode":p.returncode,"elapsedSeconds":time.monotonic()-t,"stdout":p.stdout.decode("utf-8","replace"),"stderr":p.stderr.decode("utf-8","replace")}
    commands.append(row)
    (temp/"SOURCE_COMMANDS.json").write_text(json.dumps(commands,indent=2)+"\n",encoding="utf-8")
    assert p.returncode==0,row
    return p.stdout
assert git(["rev-parse","HEAD"],common).decode().strip()==base
assert not git(["status","--porcelain=v1","--untracked-files=all"],common)
assert subprocess.run(["git","show-ref","--verify","--quiet","refs/heads/"+branch],cwd=common).returncode==1
for dirname,indexsha in [(proposal,"d776979563668e1766a3e94377a0b1880ce6d954019ae462a392aa9cf1999193"),(validation,"e4d3bd2d017f9ba74c9f7eddaff5415918255b2f69b6d44882278892e8773c98")]:
    raw=(dirname/"FILE_INDEX.json").read_bytes()
    assert hashlib.sha256(raw).hexdigest()==indexsha
    for row in json.loads(raw)["files"]:
        body=(dirname/row["path"]).read_bytes()
        assert len(body)==row["bytes"] and hashlib.sha256(body).hexdigest()==row["sha256"]
git(["worktree","add","-b",branch,str(work),base],common,timeout=180)
assert git(["rev-parse","HEAD"]).decode().strip()==base
assert not git(["status","--porcelain=v1","--untracked-files=all"])
receipt=json.loads((proposal/"PROPOSAL_RECEIPT.json").read_bytes())
changed=[]
for row in receipt["files"]:
    path=row["path"]
    before=git(["show",base+":"+path])
    assert len(before)==row["preimageBytes"] and hashlib.sha256(before).hexdigest()==row["preimageSHA256"]
    assert (work/path).read_bytes()==before,path
    candidate=(proposal/"candidate"/path).read_bytes()
    assert len(candidate)==row["candidateBytes"] and hashlib.sha256(candidate).hexdigest()==row["candidateSHA256"]
    (work/path).write_bytes(candidate)
    changed.append(path)
assert set(git(["diff","--name-only"]).decode().splitlines())==set(changed)
git(["diff","--check"])
diff=git(["diff","--binary","--",*changed])
(temp/"SOURCE.diff").write_bytes(diff)
git(["add","--",*changed])
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
result={"schemaVersion":1,"status":"SOURCE_COMMITTED_LOCAL_ONLY","createdUTC":datetime.datetime.now(datetime.timezone.utc).isoformat(),"base":base,"source":source,"branch":branch,"worktree":str(work),"changedFiles":receipt["files"],"trees":trees,"diffSHA256":hashlib.sha256(diff).hexdigest(),"allFiveExactReviewedCandidateBytes":True,"clean":True,"validationPacketIndexSHA256":"e4d3bd2d017f9ba74c9f7eddaff5415918255b2f69b6d44882278892e8773c98","noPushNoSecretNoCI":True}
(temp/"SOURCE_RECEIPT.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
print(json.dumps(result))
