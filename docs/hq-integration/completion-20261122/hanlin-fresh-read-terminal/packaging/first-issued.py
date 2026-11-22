import json,hashlib,shutil,subprocess,datetime,time
from pathlib import Path
repo=Path(r"C:\Users\DAVID\Code\Maktabah-hanlin-fresh-read-keyboard-20261122")
temp=Path(r"C:\Users\DAVID\AppData\Local\Temp\otzaria-hanlin-fresh-read-keyboard-20261122")/"neutral-publication";temp.mkdir(exist_ok=False)
source=Path(r"C:\Users\DAVID\AppData\Local\Temp\fr450063\failure-packet-v1")
base="895bbcb54f86be0fc0463d7ed9d78f3599d6bdd2";branch="codex/otzaria-hanlin-fresh-read-keyboard-evidence-20261122"
rel="docs/hq-integration/completion-20261122/hanlin-fresh-read-terminal";dest=repo/rel
def sha(b):return hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(["git","-c","core.autocrlf=false",*a],cwd=repo,timeout=90)
assert git("rev-parse","HEAD").decode().strip()==base and git("status","--porcelain=v1").decode()==""
assert git("branch","--show-current").decode().strip()==branch
assert not dest.exists();dest.mkdir(parents=True)
idxbytes=(source/"FILE_INDEX.json").read_bytes();assert sha(idxbytes)=="20cf00a31cc7c70492380f7e4d02c0d0c8daab6d53b1760bd70385032940699a"
idx=json.loads(idxbytes);assert len(idx["files"])==83
for row in idx["files"]:
 b=(source/row["path"]).read_bytes();assert sha(b)==row["sha256"] and len(b)==row["bytes"]
 out=dest/"raw"/row["path"];out.parent.mkdir(parents=True,exist_ok=True);out.write_bytes(b)
(dest/"raw/FILE_INDEX.json").write_bytes(idxbytes)
(dest/".gitattributes").write_bytes(b"raw/** -text whitespace=cr-at-eol,-blank-at-eol,-blank-at-eof\n")
git("add","-f","--",rel)
names=git("diff","--cached","--name-only","-z").decode().split("\0");names=[p for p in names if p]
expected={rel+"/raw/"+r["path"] for r in idx["files"]}|{rel+"/raw/FILE_INDEX.json",rel+"/.gitattributes"}
assert set(names)==expected and len(names)==85
rows=[]
for p in names:
 b=(repo/p).read_bytes();staged=git("show",":"+p);assert b==staged
 rows.append({"path":p,"bytes":len(b),"sha256":sha(b),"gitBlob":hashlib.sha1(b"blob "+str(len(b)).encode()+b"\0"+b).hexdigest()})
git("diff","--cached","--check")
tree=git("write-tree").decode().strip();trees={}
for p in ["Source","Vendor","Maktabah.xcodeproj","Maktabah-iOSUITests"]:
 old=git("rev-parse",base+":"+p).decode().strip();new=git("rev-parse",tree+":"+p).decode().strip();assert old==new;trees[p]=new
git("commit","-m","docs: retain original fresh-read Native failure 450063")
head=git("rev-parse","HEAD").decode().strip();assert git("status","--porcelain=v1").decode()==""
receipt={"schema":"otzaria.fresh-read-failure-publication/1","status":"COMMITTED","base":base,"head":head,"branch":branch,"path":rel,"rawIndexSha256":sha(idxbytes),"frozenPayloadCount":83,"actualGitFiles":85,"sourceTreesUnchanged":trees,"files":rows,"testsExecuted":0,"created":datetime.datetime.now(datetime.timezone.utc).isoformat()}
(temp/"RESULT.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8",newline="\n")
cmd=["git","push","origin","HEAD:refs/heads/"+branch];t=time.monotonic()
with (temp/"push.stdout").open("wb") as so,(temp/"push.stderr").open("wb") as se:
 q=subprocess.run(cmd,cwd=repo,stdout=so,stderr=se,timeout=180)
receipt["push"]={"command":cmd,"returncode":q.returncode,"duration":time.monotonic()-t}
assert q.returncode==0
remote=subprocess.check_output(["git","ls-remote","origin","refs/heads/"+branch],cwd=repo,timeout=60).decode().split()
assert remote==[head,"refs/heads/"+branch]
receipt.update(status="PUBLISHED_NEUTRAL_EVIDENCE",remoteHead=head)
(temp/"RESULT.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8",newline="\n")
print(json.dumps({k:v for k,v in receipt.items() if k!="files"}))
