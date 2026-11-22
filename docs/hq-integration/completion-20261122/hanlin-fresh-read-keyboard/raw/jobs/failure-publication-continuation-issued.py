import json,hashlib,subprocess,re,datetime,time,shutil
from pathlib import Path
repo=Path(r"C:\Users\DAVID\Code\Maktabah-hanlin-fresh-read-keyboard-20261122")
temp=Path(r"C:\Users\DAVID\AppData\Local\Temp\otzaria-hanlin-fresh-read-keyboard-20261122")/"neutral-publication"
source=Path(r"C:\Users\DAVID\AppData\Local\Temp\fr450063\failure-packet-v1")
base="895bbcb54f86be0fc0463d7ed9d78f3599d6bdd2";branch="codex/otzaria-hanlin-fresh-read-keyboard-evidence-20261122"
rel="docs/hq-integration/completion-20261122/hanlin-fresh-read-terminal";dest=repo/rel
def sha(b):return hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(["git","-c","core.autocrlf=false",*a],cwd=repo,timeout=90)
assert git("rev-parse","HEAD").decode().strip()==base
check=(temp/"check.stdout").read_text(encoding="utf-8")
findings=[re.match(r"(.+?):(\d+): (.+)",s).groups() for s in check.splitlines() if re.match(r"(.+?):(\d+): (.+)",s)]
paths=sorted(set(p for p,n,msg in findings))
assert findings and all(msg=="space before tab in indent." for p,n,msg in findings)
assert all(p.startswith(rel+"/raw/primary/hq-stage2/") and p.endswith(".diff") for p in paths),paths
attr=dest/".gitattributes";old=attr.read_bytes()
(temp/"original.gitattributes").write_bytes(old)
new=old+b"packaging/** -text whitespace=cr-at-eol,-blank-at-eol,-blank-at-eof,-space-before-tab\n"
for path in paths:new+=(path.removeprefix(rel+"/")+" -text whitespace=cr-at-eol,-blank-at-eol,-blank-at-eof,-space-before-tab\n").encode()
attr.write_bytes(new)
correction={"status":"RETAINED_RAW_PATCH_CONTEXT_WHITESPACE","diagnosticCount":len(findings),"paths":paths,"allDiagnostics":"space before tab in indent","oldAttributesSha256":sha(old),"newAttributesSha256":sha(new),"rawPayloadBytesChanged":False,"testsOrParseRepeated":False}
(temp/"ATTRIBUTES_CORRECTION.json").write_text(json.dumps(correction,indent=2)+"\n",encoding="utf-8",newline="\n")
pack=dest/"packaging";pack.mkdir(exist_ok=False)
for n in ["first-issued.py","first-terminal.json","check.stdout","check.stderr","original.gitattributes","ATTRIBUTES_CORRECTION.json"]:shutil.copyfile(temp/n,pack/n)
git("add","-f","--",rel)
git("diff","--cached","--check")
idxbytes=(source/"FILE_INDEX.json").read_bytes();assert sha(idxbytes)=="20cf00a31cc7c70492380f7e4d02c0d0c8daab6d53b1760bd70385032940699a"
idx=json.loads(idxbytes)
staged={}
for line in git("ls-files","--stage","-z","--",rel).split(b"\0"):
 if not line:continue
 meta,p=line.split(b"\t",1);mode,oid,stage=meta.split();assert stage==b"0";staged[p.decode()]=oid.decode()
expected={rel+"/raw/"+r["path"] for r in idx["files"]}|{rel+"/raw/FILE_INDEX.json",rel+"/.gitattributes"}|{rel+"/packaging/"+n for n in ["first-issued.py","first-terminal.json","check.stdout","check.stderr","original.gitattributes","ATTRIBUTES_CORRECTION.json"]}
assert set(staged)==expected and len(staged)==91
rows=[]
for path in sorted(expected):
 b=(repo/path).read_bytes();oid=hashlib.sha1(b"blob "+str(len(b)).encode()+b"\0"+b).hexdigest();assert oid==staged[path]
 rows.append({"path":path,"bytes":len(b),"sha256":sha(b),"gitBlob":oid})
for row in idx["files"]:
 b=(dest/"raw"/row["path"]).read_bytes();assert sha(b)==row["sha256"] and len(b)==row["bytes"]
assert (dest/"raw/FILE_INDEX.json").read_bytes()==idxbytes
tree=git("write-tree").decode().strip();trees={}
for p in ["Source","Vendor","Maktabah.xcodeproj","Maktabah-iOSUITests"]:
 oldtree=git("rev-parse",base+":"+p).decode().strip();newtree=git("rev-parse",tree+":"+p).decode().strip();assert oldtree==newtree;trees[p]=newtree
git("commit","-m","docs: retain original fresh-read Native failure 450063")
head=git("rev-parse","HEAD").decode().strip();assert git("status","--porcelain=v1").decode()==""
receipt={"schema":"otzaria.fresh-read-failure-publication/1","status":"COMMITTED","base":base,"head":head,"branch":branch,"path":rel,"rawIndexSha256":sha(idxbytes),"frozenPayloadCount":83,"actualGitFiles":91,"sourceTreesUnchanged":trees,"files":rows,"testsExecuted":0,"originalRawWhitespaceFailureRetained":True,"created":datetime.datetime.now(datetime.timezone.utc).isoformat()}
(temp/"RESULT.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8",newline="\n")
cmd=["git","push","origin","HEAD:refs/heads/"+branch];t=time.monotonic()
with (temp/"push.stdout").open("wb") as so,(temp/"push.stderr").open("wb") as se:q=subprocess.run(cmd,cwd=repo,stdout=so,stderr=se,timeout=180)
receipt["push"]={"command":cmd,"returncode":q.returncode,"duration":time.monotonic()-t}
assert q.returncode==0
remote=subprocess.check_output(["git","ls-remote","origin","refs/heads/"+branch],cwd=repo,timeout=60).decode().split()
assert remote==[head,"refs/heads/"+branch]
receipt.update(status="PUBLISHED_NEUTRAL_EVIDENCE",remoteHead=head)
(temp/"RESULT.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8",newline="\n")
print(json.dumps({k:v for k,v in receipt.items() if k!="files"}))
